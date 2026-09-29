<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\PresentmentMethod;
use App\Enums\PresentmentPurpose;
use App\Enums\RoleSlug;
use App\Models\Presentment;
use App\Models\VoucherTransaction;
use App\Services\Presentments\PresentmentService;
use App\Services\Vouchers\VoucherService;
use App\Support\Actor;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Tests\TestCase;

final class IdempotencyAndConcurrencyTest extends TestCase
{
    public function test_retried_redemption_is_not_charged_twice(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $presentment = $this->present($sale->printable->payload)->json('data.id');
        $key = (string) Str::uuid();
        $body = ['amount' => 1500, 'presentment_id' => $presentment];

        $this->withHeaders($this->idempotency($key))->postJson("/api/v1/vouchers/{$sale->voucher->id}/redemptions", $body)
            ->assertCreated()->assertJsonPath('replayed', false);
        // The response was lost; the app retries with the same key and the same (now consumed) presentment.
        $this->withHeaders($this->idempotency($key))->postJson("/api/v1/vouchers/{$sale->voucher->id}/redemptions", $body)
            ->assertOk()->assertJsonPath('replayed', true)->assertJsonPath('data.voucher.balance', 3500);

        $this->assertSame(3500, $sale->voucher->refresh()->balance);
        $this->assertSame(2, VoucherTransaction::query()->where('voucher_id', $sale->voucher->id)->count());
    }

    /**
     * Audit P2: a retry that arrives while the first attempt holds the lock must replay the first attempt's
     * result after the lock, never answer "declined". The first attempt is run at the moment the retry takes
     * its first lock, i.e. after the retry's pre-lock key lookup found nothing.
     */
    public function test_a_retry_waiting_on_the_lock_replays_the_first_attempt(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant, 5000);
        $waiter = $this->staff($restaurant, RoleSlug::Waiter);
        $actor = new Actor($waiter);
        $key = (string) Str::uuid();

        $result = $this->asTenant($restaurant, function () use ($actor, $sale, $key) {
            $service = app(VoucherService::class);
            $presentment = app(PresentmentService::class)->present($actor, PresentmentPurpose::Spend, PresentmentMethod::PrintableQr, $sale->printable->payload);

            $armed = true;
            Presentment::retrieved(static function () use (&$armed, $service, $actor, $sale, $presentment, $key): void {
                if ($armed) {
                    $armed = false;
                    // The first attempt: books the full balance while the retry waits.
                    $service->redeem($actor, $sale->voucher, 5000, $presentment->getKey(), $key);
                }
            });

            return $service->redeem($actor, $sale->voucher, 5000, $presentment->getKey(), $key);
        });

        $this->assertTrue($result->replayed);
        $this->assertSame(0, $result->voucher->balance);
        $this->assertSame(1, VoucherTransaction::query()->withoutGlobalScopes()->where('idempotency_key', $key)->count());
    }

    public function test_reusing_a_key_for_a_different_request_is_rejected(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $key = (string) Str::uuid();

        $this->redeemWithQr($sale->voucher, $sale->printable->payload, 1000, $key)->assertCreated();
        $this->redeemWithQr($sale->voucher, $sale->printable->payload, 2000, $key)
            ->assertStatus(409)->assertJsonPath('code', 'IDEMPOTENCY_CONFLICT');

        $this->assertSame(4000, $sale->voucher->refresh()->balance);
    }

    public function test_money_endpoints_require_an_idempotency_key(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $presentment = $this->present($sale->printable->payload)->json('data.id');

        $this->postJson("/api/v1/vouchers/{$sale->voucher->id}/redemptions", ['amount' => 100, 'presentment_id' => $presentment])
            ->assertStatus(400)->assertJsonPath('code', 'IDEMPOTENCY_KEY_REQUIRED');
        $this->postJson("/api/v1/vouchers/{$sale->voucher->id}/reloads", ['amount' => 100, 'payment' => $this->cashPayment()])
            ->assertStatus(400)->assertJsonPath('code', 'IDEMPOTENCY_KEY_REQUIRED');
        $this->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment()])
            ->assertStatus(400)->assertJsonPath('code', 'IDEMPOTENCY_KEY_REQUIRED');
        $this->withHeaders(['Idempotency-Key' => 'short'])->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment()])
            ->assertStatus(400);
    }

    public function test_a_retried_sale_replays_and_shows_a_fresh_qr_to_the_same_seller(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $key = $this->idempotency();
        $body = ['value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment()];

        $first = $this->withHeaders($key)->postJson('/api/v1/vouchers', $body)->assertCreated();
        $retry = $this->withHeaders($key)->postJson('/api/v1/vouchers', $body)
            ->assertOk()
            ->assertJsonPath('replayed', true)
            ->assertJsonPath('data.id', $first->json('data.id'));

        // The first QR was never seen (its response was lost): it is revoked, only the new one works.
        $this->assertNotSame($first->json('printable.payload'), $retry->json('printable.payload'));
        $this->present((string) $first->json('printable.payload'))->assertStatus(422)->assertJsonPath('code', 'MEDIUM_NOT_RECOGNIZED');
        $this->present((string) $retry->json('printable.payload'))->assertCreated();

        $this->withHeaders($key)->postJson('/api/v1/vouchers', ['value' => 6000] + $body)
            ->assertStatus(409)->assertJsonPath('code', 'IDEMPOTENCY_CONFLICT');
        $this->assertSame(1, VoucherTransaction::query()->where('idempotency_key', $key['Idempotency-Key'])->count());
    }

    public function test_a_retry_is_answered_with_its_sale_even_after_the_limits_changed(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $key = $this->idempotency();
        $body = ['value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment()];
        $first = $this->withHeaders($key)->postJson('/api/v1/vouchers', $body)->assertCreated();

        // The answer was lost; meanwhile the owner lowered the maximum value.
        $restaurant->settings->forceFill(['max_voucher_balance' => 2000])->save();
        $this->withHeaders($key)->postJson('/api/v1/vouchers', $body)
            ->assertOk()->assertJsonPath('replayed', true)->assertJsonPath('data.id', $first->json('data.id'));
    }

    public function test_a_late_or_foreign_sale_retry_never_shows_the_qr_again(): void
    {
        Carbon::setTestNow('2026-10-01 12:00:00');
        $restaurant = $this->restaurant();
        $seller = $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $key = $this->idempotency();
        $body = ['value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment()];
        $this->withHeaders($key)->postJson('/api/v1/vouchers', $body)->assertCreated();

        Carbon::setTestNow('2026-10-01 12:16:00');
        $this->withHeaders($key)->postJson('/api/v1/vouchers', $body)->assertOk()->assertJsonPath('printable', null);

        Carbon::setTestNow('2026-10-01 12:01:00');
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->withHeaders($key)->postJson('/api/v1/vouchers', $body)->assertOk()->assertJsonPath('printable', null);
        unset($seller);
    }

    public function test_sequential_redemptions_can_never_overdraw(): void
    {
        $restaurant = $this->restaurant();
        $restaurant->settings->forceFill(['max_redemptions_per_voucher_per_hour' => 0])->save();
        $sale = $this->sell($restaurant, 1000);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $ok = 0;
        for ($i = 0; $i < 5; $i++) {
            $status = $this->redeemWithQr($sale->voucher, $sale->printable->payload, 300)->status();
            $ok += $status === 201 ? 1 : 0;
        }

        $this->assertSame(3, $ok);
        $this->assertSame(100, $sale->voucher->refresh()->balance);
        $this->assertLedgerConsistent($sale->voucher);
    }

    public function test_velocity_limit_stops_rapid_repeated_redemptions(): void
    {
        $restaurant = $this->restaurant();
        $restaurant->settings->forceFill(['max_redemptions_per_voucher_per_hour' => 2])->save();
        $sale = $this->sell($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $this->redeemWithQr($sale->voucher, $sale->printable->payload, 100)->assertCreated();
        $this->redeemWithQr($sale->voucher, $sale->printable->payload, 100)->assertCreated();
        $this->redeemWithQr($sale->voucher, $sale->printable->payload, 100)
            ->assertStatus(429)->assertJsonPath('code', 'VELOCITY_LIMIT_EXCEEDED');
    }
}
