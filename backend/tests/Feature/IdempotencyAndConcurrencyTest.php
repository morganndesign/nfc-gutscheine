<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Exceptions\Domain\IdempotencyConflictException;
use App\Exceptions\Domain\InsufficientBalanceException;
use App\Models\GiftCardTransaction;
use App\Services\GiftCards\GiftCardService;
use App\Support\Actor;
use Illuminate\Support\Carbon;
use Tests\TestCase;

final class IdempotencyAndConcurrencyTest extends TestCase
{
    public function test_retried_redemption_is_not_charged_twice(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $headers = $this->idempotency('c3d7a0c0-0000-4000-8000-000000000001');

        $first = $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 2000], $headers)->assertCreated();
        $second = $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 2000], $headers)->assertOk();

        $this->assertTrue($second->json('replayed'));
        $this->assertSame($first->json('data.transaction.id'), $second->json('data.transaction.id'));
        $this->assertSame(3000, $card->refresh()->balance);
        $this->assertSame(1, GiftCardTransaction::query()->withoutGlobalScopes()->where('gift_card_id', $card->id)->where('type', 'redemption')->count());
    }

    public function test_reusing_a_key_for_a_different_request_is_rejected(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $headers = $this->idempotency();

        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 2000], $headers)->assertCreated();
        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 2500], $headers)
            ->assertStatus(409)->assertJsonPath('code', 'IDEMPOTENCY_CONFLICT');
    }

    public function test_money_endpoints_require_an_idempotency_key(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 100])
            ->assertStatus(400)->assertJsonPath('code', 'IDEMPOTENCY_KEY_REQUIRED');
        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 100], ['Idempotency-Key' => "'; DROP TABLE--"])
            ->assertStatus(400);
    }

    public function test_sequential_redemptions_can_never_overdraw(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 1000);
        $waiter = $this->staff($restaurant, RoleSlug::Waiter);
        $service = app(GiftCardService::class);

        $this->asTenant($restaurant, function () use ($service, $waiter, $card): void {
            // Two "stale" in-memory copies of the same card, as two waiters would hold them.
            $copyA = $card->fresh();
            $copyB = $card->fresh();

            $service->redeem(new Actor($waiter), $copyA, 800, 'key-aaaaaaaa');

            try {
                $service->redeem(new Actor($waiter), $copyB, 800, 'key-bbbbbbbb');
                $this->fail('Second redemption must fail even though its in-memory copy still shows 10.00.');
            } catch (InsufficientBalanceException) {
                // expected: the service re-reads the locked row, not the stale model
            }
        });

        $this->assertSame(200, $card->refresh()->balance);
        $this->assertLedgerConsistent($card);
    }

    public function test_idempotency_is_scoped_per_card_and_type(): void
    {
        $restaurant = $this->restaurant();
        $a = $this->issueCard($restaurant, 5000);
        $b = $this->issueCard($restaurant, 5000);
        $waiter = $this->staff($restaurant, RoleSlug::Manager);
        $service = app(GiftCardService::class);

        $this->asTenant($restaurant, function () use ($service, $waiter, $a, $b): void {
            $service->redeem(new Actor($waiter), $a, 100, 'shared-key-123');

            $this->expectException(IdempotencyConflictException::class);
            $service->redeem(new Actor($waiter), $b, 100, 'shared-key-123');
        });
    }

    public function test_velocity_limit_stops_rapid_repeated_redemptions(): void
    {
        $restaurant = $this->restaurant();
        $restaurant->settings->forceFill(['max_redemptions_per_card_per_hour' => 2])->save();
        $card = $this->issueCard($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        Carbon::setTestNow(Carbon::now()->subMinutes(20));
        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 100], $this->idempotency())->assertCreated();
        Carbon::setTestNow(Carbon::now()->addMinutes(10));
        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 100], $this->idempotency())->assertCreated();
        Carbon::setTestNow(Carbon::now()->addMinutes(10));

        // The first redemption leaves the one-hour window in 40 minutes.
        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 100], $this->idempotency())
            ->assertStatus(429)
            ->assertJsonPath('code', 'VELOCITY_LIMIT_EXCEEDED')
            ->assertJsonPath('context.retry_after', 40 * 60);

        Carbon::setTestNow(Carbon::now()->addMinutes(41));
        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 100], $this->idempotency())->assertCreated();
        Carbon::setTestNow();
    }
}
