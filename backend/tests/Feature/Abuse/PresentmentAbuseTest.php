<?php

declare(strict_types=1);

namespace Tests\Feature\Abuse;

use App\Enums\MediumRole;
use App\Enums\MediumStatus;
use App\Enums\MediumType;
use App\Enums\RoleSlug;
use App\Enums\VoucherKind;
use App\Models\AuditLog;
use App\Models\Medium;
use App\Models\Voucher;
use App\Models\VoucherTransaction;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Every rule of presentments (architecture §10.1, §10.6, invariant 1) tried from the forbidden side.
 */
final class PresentmentAbuseTest extends TestCase
{
    private const DEVICE_A = 'device-aaaa-0000-1111-2222';

    private const DEVICE_B = 'device-bbbb-0000-1111-2222';

    public function test_a_redemption_without_a_presentment_is_impossible(): void
    {
        $restaurant = $this->restaurant();
        $voucher = $this->issueVoucher($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $redeem = fn (array $body) => $this->withHeaders($this->idempotency())->postJson("/api/v1/vouchers/{$voucher->id}/redemptions", $body);

        $redeem(['amount' => 100])->assertStatus(422)->assertJsonValidationErrors('presentment_id');
        $redeem(['amount' => 100, 'presentment_id' => (string) Str::uuid()])
            ->assertStatus(422)->assertJsonPath('code', 'PRESENTMENT_INVALID')->assertJsonPath('context.reason', 'not_found');
        // The voucher id or number is never a credential (decision 24).
        $redeem(['amount' => 100, 'presentment_id' => $voucher->id])
            ->assertStatus(422)->assertJsonPath('context.reason', 'not_found');

        $this->assertSame(5000, $voucher->refresh()->balance);
        $this->assertTrue(AuditLog::query()->where('action', 'presentment.rejected')->exists());
    }

    public function test_voucher_number_id_or_garbage_are_not_credentials(): void
    {
        $restaurant = $this->restaurant();
        $voucher = $this->issueVoucher($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        foreach ([$voucher->voucher_number, $voucher->id, 'GCPV1.'.str_repeat('A', 43), 'https://example.com/c/'.$voucher->id, ''] as $credential) {
            $response = $this->postJson('/api/v1/presentments', ['purpose' => 'spend', 'method' => 'printable_qr', 'credential' => $credential]);
            $this->assertContains($response->status(), [422], (string) $response->getContent());
        }
        $this->assertSame(4, AuditLog::query()->where('action', 'presentment.failed')->count());
    }

    public function test_a_presentment_is_single_use(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $presentment = $this->present($sale->printable->payload)->json('data.id');
        $redeem = fn () => $this->withHeaders($this->idempotency())->postJson("/api/v1/vouchers/{$sale->voucher->id}/redemptions", ['amount' => 100, 'presentment_id' => $presentment]);

        $redeem()->assertCreated();
        $redeem()->assertStatus(422)->assertJsonPath('context.reason', 'already_used');
        $this->assertSame(4900, $sale->voucher->refresh()->balance);
    }

    public function test_a_presentment_expires_after_60_seconds(): void
    {
        Carbon::setTestNow('2026-10-01 12:00:00');
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $presentment = $this->present($sale->printable->payload)->assertJsonPath('data.expires_in', 60)->json('data.id');

        Carbon::setTestNow('2026-10-01 12:01:00');
        $this->withHeaders($this->idempotency())->postJson("/api/v1/vouchers/{$sale->voucher->id}/redemptions", ['amount' => 100, 'presentment_id' => $presentment])
            ->assertStatus(422)->assertJsonPath('context.reason', 'expired');
    }

    public function test_a_presentment_belongs_to_its_user_and_device(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant);
        $waiterA = $this->staff($restaurant, RoleSlug::Waiter);
        $waiterB = $this->staff($restaurant, RoleSlug::Waiter);

        Sanctum::actingAs($waiterA, ['*']);
        $presentment = $this->present($sale->printable->payload, ['X-Device-Id' => self::DEVICE_A])->assertCreated()->json('data.id');
        $body = ['amount' => 100, 'presentment_id' => $presentment];
        $url = "/api/v1/vouchers/{$sale->voucher->id}/redemptions";

        // Another device of the same user.
        $this->withHeaders(['X-Device-Id' => self::DEVICE_B] + $this->idempotency())->postJson($url, $body)
            ->assertStatus(422)->assertJsonPath('context.reason', 'other_device');
        // No device at all (null-safe binding).
        $this->withHeaders(['X-Device-Id' => ''] + $this->idempotency())->postJson($url, $body)
            ->assertStatus(422)->assertJsonPath('context.reason', 'other_device');

        // Another user on the same device.
        Sanctum::actingAs($waiterB, ['*']);
        $this->withHeaders(['X-Device-Id' => self::DEVICE_A] + $this->idempotency())->postJson($url, $body)
            ->assertStatus(422)->assertJsonPath('context.reason', 'other_user');

        Sanctum::actingAs($waiterA, ['*']);
        $this->withHeaders(['X-Device-Id' => self::DEVICE_A] + $this->idempotency())->postJson($url, $body)->assertCreated();
    }

    public function test_an_unknown_outcome_is_resolved_by_key_without_sending_the_debit_again(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant);
        $other = $this->sell($restaurant);
        $waiterA = $this->staff($restaurant, RoleSlug::Waiter);
        $waiterB = $this->staff($restaurant, RoleSlug::Waiter);
        $key = (string) Str::uuid();
        $url = fn (Voucher $v, string $k) => "/api/v1/vouchers/{$v->id}/redemptions/{$k}";

        Sanctum::actingAs($waiterA, ['*']);
        $this->getJson($url($sale->voucher, $key))->assertOk()->assertExactJson(['data' => ['status' => 'not_booked']]);

        $this->redeemWithQr($sale->voucher, $sale->printable->payload, 1250, $key)->assertCreated();
        $this->getJson($url($sale->voucher, $key))->assertOk()
            ->assertHeader('Cache-Control', 'no-store, private')
            ->assertJsonPath('data.status', 'booked')
            ->assertJsonPath('data.transaction.amount', -1250)
            ->assertJsonPath('data.voucher.balance', 3750);

        // Only for the voucher it was booked on, and only for the user who booked it.
        $this->getJson($url($other->voucher, $key))->assertOk()->assertJsonPath('data.status', 'not_booked');
        Sanctum::actingAs($waiterB, ['*']);
        $this->getJson($url($sale->voucher, $key))->assertOk()->assertJsonPath('data.status', 'not_booked');

        // Asking never books anything.
        $this->assertSame(1, VoucherTransaction::query()->where('voucher_id', $sale->voucher->id)->where('type', 'redemption')->count());
        $this->assertSame(3750, $sale->voucher->refresh()->balance);
    }

    public function test_a_presentment_only_pays_for_its_own_voucher(): void
    {
        $restaurant = $this->restaurant();
        $mine = $this->sell($restaurant);
        $other = $this->issueVoucher($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $presentment = $this->present($mine->printable->payload)->json('data.id');
        $this->withHeaders($this->idempotency())->postJson("/api/v1/vouchers/{$other->id}/redemptions", ['amount' => 100, 'presentment_id' => $presentment])
            ->assertStatus(422)->assertJsonPath('context.reason', 'wrong_voucher');
        $this->assertSame(5000, $other->refresh()->balance);
    }

    public function test_a_qr_of_another_restaurant_is_not_recognized(): void
    {
        $foreign = $this->sell($this->restaurant());
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $this->present($foreign->printable->payload)->assertStatus(422)->assertJsonPath('code', 'MEDIUM_NOT_RECOGNIZED');
    }

    public function test_a_revoked_qr_can_no_longer_pay_even_with_an_earlier_presentment(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $presentment = $this->present($sale->printable->payload)->json('data.id');

        Medium::query()->where('voucher_id', $sale->voucher->id)->update(['status' => MediumStatus::Revoked->value]);

        $this->withHeaders($this->idempotency())->postJson("/api/v1/vouchers/{$sale->voucher->id}/redemptions", ['amount' => 100, 'presentment_id' => $presentment])
            ->assertStatus(422)->assertJsonPath('context.reason', 'medium_revoked');
        $this->present($sale->printable->payload)->assertStatus(422)->assertJsonPath('code', 'MEDIUM_NOT_RECOGNIZED');
    }

    /** Decision 26: a card voucher is never spent with a QR, whatever medium row exists. */
    public function test_a_card_voucher_cannot_be_spent_with_a_qr(): void
    {
        $restaurant = $this->restaurant();
        $voucher = Voucher::factory()->create(['restaurant_id' => $restaurant->id, 'kind' => VoucherKind::Card, 'balance' => 5000]);
        $secret = random_bytes(32);
        $qr = 'GCPV1.'.rtrim(strtr(base64_encode($secret), '+/', '-_'), '=');
        $medium = new Medium;
        $medium->forceFill([
            'restaurant_id' => $restaurant->id, 'voucher_id' => $voucher->id, 'type' => MediumType::PrintableQr,
            'role' => MediumRole::Spend, 'status' => MediumStatus::Active, 'secret_hash' => hash('sha256', $secret),
        ])->save();
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $this->present($qr)->assertStatus(422)->assertJsonPath('code', 'PRESENTMENT_METHOD_NOT_ALLOWED');
        $this->assertSame(0, VoucherTransaction::query()->count());
    }

    /** A card is presented only through its two-step live authentication (POST /presentments/cards). */
    public function test_a_card_is_never_presented_through_the_scan_endpoint(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $this->postJson('/api/v1/presentments', ['purpose' => 'spend', 'method' => 'live_auth', 'credential' => 'anything'])
            ->assertStatus(422)->assertJsonPath('code', 'PRESENTMENT_METHOD_UNAVAILABLE');
        // A printable QR only ever pays.
        $this->postJson('/api/v1/presentments', ['purpose' => 'bind', 'method' => 'printable_qr', 'credential' => 'x'])
            ->assertStatus(422)->assertJsonPath('code', 'PRESENTMENT_METHOD_UNAVAILABLE');
    }

    /** Audit S7: failed scans lock out this user on this device only, never everyone behind the same IP. */
    public function test_failed_scans_lock_out_only_the_same_user_and_device(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant);
        $waiterA = $this->staff($restaurant, RoleSlug::Waiter);
        $waiterB = $this->staff($restaurant, RoleSlug::Waiter);

        Sanctum::actingAs($waiterA, ['*']);
        for ($i = 0; $i < 10; $i++) {
            $this->present('GCPV1.'.str_repeat('B', 43), ['X-Device-Id' => self::DEVICE_A])->assertStatus(422);
        }
        $this->present($sale->printable->payload, ['X-Device-Id' => self::DEVICE_A])
            ->assertStatus(429)->assertJsonPath('code', 'PRESENTMENT_THROTTLED');

        // Same IP, other device or other user: unaffected.
        $this->present($sale->printable->payload, ['X-Device-Id' => self::DEVICE_B])->assertCreated();
        Sanctum::actingAs($waiterB, ['*']);
        $this->present($sale->printable->payload, ['X-Device-Id' => self::DEVICE_A])->assertCreated();
    }

    public function test_waiters_can_present_and_redeem_but_nothing_else(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $this->present($sale->printable->payload)->assertCreated()
            ->assertJsonPath('data.voucher.balance', 5000)
            ->assertJsonPath('data.voucher.actions.redeem', true)
            ->assertJsonMissingPath('data.voucher.customer');
        $this->getJson("/api/v1/vouchers/{$sale->voucher->id}")->assertForbidden();
        $this->withHeaders($this->idempotency())->postJson("/api/v1/vouchers/{$sale->voucher->id}/reloads", ['amount' => 100, 'payment' => $this->cashPayment()])->assertForbidden();
        $this->withHeaders($this->idempotency())->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment()])->assertForbidden();
    }
}
