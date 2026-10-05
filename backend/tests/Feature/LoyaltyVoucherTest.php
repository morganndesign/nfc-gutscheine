<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Data\IssueVoucherData;
use App\Data\PaymentData;
use App\Enums\PaymentMethod;
use App\Enums\RoleSlug;
use App\Models\Payment;
use App\Models\User;
use App\Services\Vouchers\VoucherService;
use App\Support\Actor;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * Loyalty (decision 2026-10-05): a voucher is a loyalty voucher from its sale on — sold without payment, always with
 * a reason — and only a loyalty voucher takes further loyalty value. A paid voucher never becomes one. Owners give
 * loyalty; a manager only when the owner allowed that manager.
 */
final class LoyaltyVoucherTest extends TestCase
{
    private const DEVICE = 'b1a2c3d4-e5f6-4711-8899-aabbccddeeff';

    private function sellLoyalty(int $value = 5000): TestResponse
    {
        return $this->postJson('/api/v1/vouchers', [
            'value' => $value, 'form' => 'printable', 'payment' => ['method' => 'complimentary', 'reason' => 'Freund des Hauses'],
        ], $this->idempotency());
    }

    /** @param array<string, mixed> $payment */
    private function reload(string $voucherId, int $amount, array $payment): TestResponse
    {
        return $this->postJson("/api/v1/vouchers/{$voucherId}/reloads", ['amount' => $amount, 'payment' => $payment], $this->idempotency());
    }

    private function loyaltyPayment(): array
    {
        return ['method' => 'complimentary', 'reason' => 'Stammgast Oktober'];
    }

    public function test_a_voucher_sold_as_loyalty_is_loyalty_and_takes_loyalty_and_paid_top_ups(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $id = (string) $this->sellLoyalty()->assertCreated()->assertJsonPath('data.loyalty', true)->json('data.id');

        $this->reload($id, 2500, $this->loyaltyPayment())->assertCreated();
        $this->reload($id, 1000, $this->cashPayment())->assertCreated();

        $this->getJson("/api/v1/vouchers/{$id}")->assertOk()->assertJsonPath('data.loyalty', true)->assertJsonPath('data.balance', 8500);
        $this->assertSame([$id], array_column($this->getJson('/api/v1/vouchers?loyalty=1')->assertOk()->json('data'), 'id'));
    }

    public function test_a_paid_voucher_never_takes_loyalty_value_and_never_becomes_loyalty(): void
    {
        $restaurant = $this->restaurant();
        $paid = $this->sell($restaurant, 3000);
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $payments = Payment::query()->withoutGlobalScopes()->count();

        $this->reload($paid->voucher->id, 2000, $this->loyaltyPayment())
            ->assertUnprocessable()->assertJsonPath('code', 'LOYALTY_VOUCHER_ONLY');

        $this->getJson("/api/v1/vouchers/{$paid->voucher->id}")->assertOk()->assertJsonPath('data.loyalty', false)->assertJsonPath('data.balance', 3000);
        $this->assertSame($payments, Payment::query()->withoutGlobalScopes()->count(), 'nothing was booked');
        $this->assertSame([], $this->getJson('/api/v1/vouchers?loyalty=1')->assertOk()->json('data'));
        // A paid top-up of a paid voucher is unchanged.
        $this->reload($paid->voucher->id, 2000, $this->cashPayment())->assertCreated();
    }

    public function test_the_till_learns_whether_a_presented_voucher_is_loyalty(): void
    {
        $restaurant = $this->restaurant();
        $owner = $this->staff($restaurant, RoleSlug::Owner);
        $paid = $this->sell($restaurant, 3000);
        $gift = $this->asTenant($restaurant, fn () => app(VoucherService::class)->sell(new Actor($owner), new IssueVoucherData(
            value: 3000, payment: new PaymentData(PaymentMethod::Complimentary, reason: 'Regular'), idempotencyKey: (string) Str::uuid(),
        )));
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->present($paid->printable->payload)->assertCreated()->assertJsonPath('data.voucher.loyalty', false);
        $this->present($gift->printable->payload)->assertCreated()->assertJsonPath('data.voucher.loyalty', true);
    }

    public function test_a_manager_gives_loyalty_only_while_the_owner_allows_it(): void
    {
        $restaurant = $this->restaurant();
        $owner = $this->staff($restaurant, RoleSlug::Owner);
        $manager = $this->staff($restaurant, RoleSlug::Manager);

        $this->actingAs($manager);
        $this->sellLoyalty()->assertForbidden()->assertJsonPath('code', 'COMPLIMENTARY_NOT_ALLOWED');
        $this->assertNotContains('vouchers.sell_complimentary', $this->getJson('/api/v1/auth/me')->json('data.permissions'));

        $this->actingAs($owner);
        $list = collect($this->getJson('/api/v1/users')->assertOk()->json('data'))->keyBy('id');
        $this->assertFalse($list[$manager->id]['can_give_loyalty']);
        $this->assertNull($list[$owner->id]['can_give_loyalty'], 'owners have it by role');
        $this->putJson("/api/v1/users/{$manager->id}/loyalty", ['allowed' => true])->assertOk()->assertJsonPath('data.can_give_loyalty', true);
        $this->assertDatabaseHas('audit_logs', ['action' => 'user.loyalty_allowed', 'user_id' => $owner->id, 'auditable_id' => $manager->id]);

        $this->actingAs($manager->refresh());
        $this->assertContains('vouchers.sell_complimentary', $this->getJson('/api/v1/auth/me')->json('data.permissions'));
        $this->sellLoyalty()->assertCreated()->assertJsonPath('data.loyalty', true);

        $this->actingAs($owner);
        $this->putJson("/api/v1/users/{$manager->id}/loyalty", ['allowed' => false])->assertOk()->assertJsonPath('data.can_give_loyalty', false);
        $this->assertDatabaseHas('audit_logs', ['action' => 'user.loyalty_revoked', 'auditable_id' => $manager->id]);

        $this->actingAs($manager->refresh());
        $this->sellLoyalty()->assertForbidden()->assertJsonPath('code', 'COMPLIMENTARY_NOT_ALLOWED');
    }

    public function test_only_the_owner_allows_loyalty_and_only_for_managers(): void
    {
        $restaurant = $this->restaurant();
        $owner = $this->staff($restaurant, RoleSlug::Owner);
        $coOwner = $this->staff($restaurant, RoleSlug::Owner);
        $manager = $this->staff($restaurant, RoleSlug::Manager);
        $other = $this->staff($restaurant, RoleSlug::Manager);
        $waiter = $this->staff($restaurant, RoleSlug::Waiter);

        // A manager cannot allow themselves or a colleague.
        $this->actingAs($manager);
        $this->putJson("/api/v1/users/{$manager->id}/loyalty", ['allowed' => true])->assertForbidden();
        $this->putJson("/api/v1/users/{$other->id}/loyalty", ['allowed' => true])->assertForbidden();

        $this->actingAs($owner);
        $this->putJson("/api/v1/users/{$waiter->id}/loyalty", ['allowed' => true])->assertForbidden()->assertJsonPath('code', 'ROLE_ASSIGNMENT_FORBIDDEN');
        $this->putJson("/api/v1/users/{$coOwner->id}/loyalty", ['allowed' => true])->assertForbidden();
        $this->putJson("/api/v1/users/{$manager->id}/loyalty", ['allowed' => 'yes'])->assertUnprocessable();

        // Another restaurant's owner does not even see the manager.
        $foreign = $this->staff($this->restaurant(), RoleSlug::Owner);
        $this->actingAs($foreign);
        $this->putJson("/api/v1/users/{$manager->id}/loyalty", ['allowed' => true])->assertNotFound();

        $this->assertFalse($waiter->refresh()->can_give_loyalty);
        $this->assertFalse($manager->refresh()->can_give_loyalty);
    }

    public function test_a_new_role_starts_without_the_grant(): void
    {
        $restaurant = $this->restaurant();
        $owner = $this->staff($restaurant, RoleSlug::Owner);
        $manager = $this->staff($restaurant, RoleSlug::Manager);
        $this->actingAs($owner);
        $this->putJson("/api/v1/users/{$manager->id}/loyalty", ['allowed' => true])->assertOk();

        $this->patchJson("/api/v1/users/{$manager->id}", ['role' => 'waiter'])->assertOk();
        $this->assertFalse($manager->refresh()->can_give_loyalty);
        $this->patchJson("/api/v1/users/{$manager->id}", ['role' => 'manager'])->assertOk()->assertJsonPath('data.can_give_loyalty', false);
    }

    public function test_the_grant_reaches_a_signed_in_app_at_once_and_ends_at_once(): void
    {
        $restaurant = $this->restaurant();
        $manager = $this->staff($restaurant, RoleSlug::Manager, ['email' => 'mia@example.com']);
        $token = (string) $this->appSignIn([
            'email' => 'mia@example.com', 'password' => 'Password123!', 'device_id' => self::DEVICE, 'device_name' => 'iPhone', 'platform' => 'ios',
        ], 'GiftCardWaiter/2.0.20 (iOS 18; iPhone)')->assertCreated()->json('data.token');
        $app = fn (): self => $this->bearer($token);

        $app()->sellLoyalty()->assertForbidden();

        $this->setLoyalty($manager, true);
        $this->assertContains('vouchers.sell_complimentary', $app()->getJson('/api/v1/auth/me')->json('data.permissions'));
        $app()->sellLoyalty()->assertCreated();

        $this->setLoyalty($manager, false);
        $this->assertNotContains('vouchers.sell_complimentary', $app()->getJson('/api/v1/auth/me')->json('data.permissions'));
        $app()->sellLoyalty()->assertForbidden();
    }

    /** The owner's switch in Team, meanwhile in the dashboard (the HTTP side is covered above). */
    private function setLoyalty(User $manager, bool $allowed): void
    {
        $manager->forceFill(['can_give_loyalty' => $allowed])->save();
    }

    private function bearer(string $token): self
    {
        $this->app['auth']->forgetGuards();

        return $this->withHeaders(['Authorization' => 'Bearer '.$token, 'X-Device-Id' => self::DEVICE]);
    }
}
