<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use Tests\TestCase;

/**
 * Loyalty (decision 2026-10-05): the owner gives regulars value without payment — at the sale or by topping up
 * whenever they like. Owner only, always with a reason, never revenue, never paid out.
 */
final class LoyaltyVoucherTest extends TestCase
{
    public function test_an_owner_tops_up_a_regular_and_the_voucher_is_marked_loyalty(): void
    {
        $restaurant = $this->restaurant();
        $paid = $this->sell($restaurant, 3000);
        $gift = $this->sell($restaurant, 2000);
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $this->getJson("/api/v1/vouchers/{$gift->voucher->id}")->assertOk()->assertJsonPath('data.loyalty', false);
        $this->postJson("/api/v1/vouchers/{$gift->voucher->id}/reloads", [
            'amount' => 2500, 'payment' => ['method' => 'complimentary', 'reason' => 'Stammgast Oktober'],
        ], $this->idempotency())->assertCreated();

        $this->getJson("/api/v1/vouchers/{$gift->voucher->id}")->assertOk()->assertJsonPath('data.loyalty', true)->assertJsonPath('data.balance', 4500);
        $list = $this->getJson('/api/v1/vouchers?loyalty=1')->assertOk();
        $this->assertSame([$gift->voucher->id], array_column($list->json('data'), 'id'));
        $all = collect($this->getJson('/api/v1/vouchers')->json('data'))->keyBy('id');
        $this->assertFalse($all[$paid->voucher->id]['loyalty']);
        $this->assertTrue($all[$gift->voucher->id]['loyalty']);
    }

    public function test_a_loyalty_voucher_sold_without_payment_is_loyalty_from_the_start(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $this->postJson('/api/v1/vouchers', [
            'value' => 5000, 'form' => 'printable', 'payment' => ['method' => 'complimentary', 'reason' => 'Freund des Hauses'],
        ], $this->idempotency())->assertCreated()->assertJsonPath('data.loyalty', true);
    }

    public function test_a_manager_cannot_give_loyalty_value(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant, 2000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->postJson("/api/v1/vouchers/{$sale->voucher->id}/reloads", [
            'amount' => 1000, 'payment' => ['method' => 'complimentary', 'reason' => 'Stammgast'],
        ], $this->idempotency())->assertForbidden()->assertJsonPath('code', 'COMPLIMENTARY_NOT_ALLOWED');
        $this->getJson("/api/v1/vouchers/{$sale->voucher->id}")->assertOk()->assertJsonPath('data.loyalty', false);
    }
}
