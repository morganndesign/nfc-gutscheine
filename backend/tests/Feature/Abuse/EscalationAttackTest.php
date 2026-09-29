<?php

declare(strict_types=1);

namespace Tests\Feature\Abuse;

use App\Enums\RoleSlug;
use App\Models\Customer;
use App\Models\Device;
use App\Models\Restaurant;
use App\Models\User;
use App\Models\Voucher;
use Laravel\Sanctum\Sanctum;
use Tests\Support\WithCards;
use Tests\TestCase;

/**
 * Penetration tests for privilege escalation and cross-tenant access: staff of restaurant A (every role) and
 * platform staff try to reach restaurant B's cards, batches, devices, staff and money, or to raise their own
 * rights. Foreign objects answer 404 (their existence is not revealed); missing rights answer 403.
 */
final class EscalationAttackTest extends TestCase
{
    use WithCards;

    private Restaurant $mine;

    private Restaurant $theirs;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpCardKeystore();
        $this->mine = $this->restaurant(['name' => 'Mine']);
        $this->theirs = $this->restaurant(['name' => 'Theirs']);
    }

    protected function tearDown(): void
    {
        $this->tearDownCardKeystore();
        parent::tearDown();
    }

    public function test_another_restaurants_cards_batches_and_devices_are_out_of_reach(): void
    {
        [$card, $voucher] = $this->activeCardVoucher($this->theirs, 7000);
        [$batch] = $this->deliveredCards($this->theirs, 1);
        $device = Device::factory()->create(['restaurant_id' => $this->theirs->id]);
        $this->actingAsStaff($this->mine, RoleSlug::Owner);

        $this->getJson("/api/v1/cards/{$card->card_number}")->assertNotFound();
        $this->postJson("/api/v1/cards/{$card->card_number}/suspend", ['reason' => 'mine now'])->assertNotFound();
        $this->postJson("/api/v1/cards/{$card->card_number}/replacement", ['presentment_id' => fake()->uuid(), 'reason' => 'mine now'])->assertNotFound();
        $this->getJson('/api/v1/cards')->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/card-batches')->assertOk()->assertJsonCount(0, 'data');
        $this->postJson("/api/v1/card-batches/{$batch->id}/receipt", ['count' => 1, 'presentment_id' => fake()->uuid()])->assertNotFound();
        $this->patchJson("/api/v1/devices/{$device->id}", ['name' => 'x'])->assertNotFound();
        $this->postJson("/api/v1/devices/{$device->id}/revoke")->assertNotFound();

        // Their card tapped at my till is refused, their voucher untouched.
        $this->tapCard($this->chip($card), 'spend')->assertUnprocessable()->assertJsonPath('context.reason', 'other_restaurant');
        $this->assertSame(7000, $voucher->refresh()->balance);
    }

    public function test_ids_smuggled_in_bodies_and_protected_fields_are_ignored(): void
    {
        $voucher = $this->issueVoucher($this->mine, 5000);
        $this->actingAsStaff($this->mine, RoleSlug::Owner);

        $this->patchJson("/api/v1/vouchers/{$voucher->id}", [
            'notes' => 'fine',
            'balance' => 999999,
            'total_loaded' => 999999,
            'status' => 'active',
            'kind' => 'card',
            'restaurant_id' => $this->theirs->id,
            'voucher_number' => '0000000000000000',
        ])->assertOk();
        $fresh = Voucher::query()->withoutGlobalScopes()->findOrFail($voucher->id);
        $this->assertSame(5000, $fresh->balance);
        $this->assertSame($this->mine->id, $fresh->restaurant_id);
        $this->assertSame($voucher->voucher_number, $fresh->voucher_number);

        $id = $this->postJson('/api/v1/customers', ['first_name' => 'Eve', 'email' => 'eve@example.com', 'restaurant_id' => $this->theirs->id])
            ->assertCreated()->json('data.id');
        $this->assertSame($this->mine->id, Customer::query()->withoutGlobalScopes()->findOrFail($id)->restaurant_id);

        // A sale cannot be booked into another restaurant by header or body.
        $this->withHeaders(['X-Restaurant-Id' => $this->theirs->id])
            ->postJson('/api/v1/vouchers', ['value' => 1000, 'form' => 'printable', 'payment' => ['method' => 'cash'], 'restaurant_id' => $this->theirs->id], $this->idempotency())
            ->assertCreated();
        $this->assertSame(0, Voucher::query()->withoutGlobalScopes()->where('restaurant_id', $this->theirs->id)->count());
    }

    public function test_nobody_raises_their_own_rights(): void
    {
        $manager = $this->actingAsStaff($this->mine, RoleSlug::Manager);
        $this->patchJson("/api/v1/users/{$manager->id}", ['role' => 'owner'])->assertForbidden();
        $this->postJson('/api/v1/users', ['name' => 'Sock', 'email' => 'sock@example.com', 'role' => 'owner'])->assertForbidden();
        $this->postJson('/api/v1/api-tokens', ['name' => 'Backdoor', 'abilities' => ['vouchers.sell_complimentary']])->assertForbidden();
        $this->putJson('/api/v1/settings/vouchers', ['max_voucher_balance' => 10000000])->assertForbidden();

        $owner = $this->actingAsStaff($this->mine, RoleSlug::Owner);
        foreach ([
            $this->patchJson("/api/v1/users/{$owner->id}", ['role' => 'waiter']),
            $this->postJson('/api/v1/users', ['name' => 'Root', 'email' => 'root@example.com', 'role' => 'platform_admin']),
            $this->postJson('/api/v1/api-tokens', ['name' => 'Platform', 'abilities' => ['platform.restaurants.manage']]),
        ] as $refused) {
            $this->assertContains($refused->status(), [403, 422]);
        }
        $this->assertSame(RoleSlug::Owner, $owner->refresh()->roleSlug());
        $this->getJson('/api/v1/admin/restaurants')->assertForbidden();
        $this->getJson('/api/v1/admin/card-batches')->assertForbidden();
        $this->getJson('/api/v1/admin/station/batches')->assertForbidden();
    }

    public function test_a_narrow_api_token_stays_narrow_even_for_an_owner(): void
    {
        $voucher = $this->issueVoucher($this->mine, 5000);
        $owner = User::factory()->forRestaurant($this->mine)->role(RoleSlug::Owner)->create();
        Sanctum::actingAs($owner, ['vouchers.view']);

        $this->getJson("/api/v1/vouchers/{$voucher->id}")->assertOk();
        $this->postJson("/api/v1/vouchers/{$voucher->id}/reloads", ['amount' => 100, 'payment' => ['method' => 'cash']], $this->idempotency())->assertForbidden();
        $this->postJson("/api/v1/vouchers/{$voucher->id}/block", ['reason' => 'nope'])->assertForbidden();
        $this->getJson('/api/v1/users')->assertForbidden();
        $this->assertSame(5000, $voucher->refresh()->balance);
    }

    public function test_a_demoted_user_loses_the_rights_at_once(): void
    {
        $voucher = $this->issueVoucher($this->mine, 5000);
        $manager = User::factory()->forRestaurant($this->mine)->role(RoleSlug::Manager)->create();
        $token = $manager->createToken('till', ['*'])->plainTextToken;

        $this->withToken($token)->getJson("/api/v1/vouchers/{$voucher->id}")->assertOk();
        $this->actingAsStaff($this->mine, RoleSlug::Owner);
        $this->patchJson("/api/v1/users/{$manager->id}", ['role' => 'waiter'])->assertOk();

        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson("/api/v1/vouchers/{$voucher->id}")->assertForbidden();
    }

    public function test_platform_staff_never_touch_vouchers_or_money(): void
    {
        $voucher = $this->issueVoucher($this->theirs, 5000);
        Sanctum::actingAs(User::factory()->platformAdmin()->create(), ['*']);

        foreach ([
            ['GET', '/api/v1/vouchers'],
            ['GET', "/api/v1/vouchers/{$voucher->id}"],
            ['POST', "/api/v1/vouchers/{$voucher->id}/reloads"],
            ['POST', '/api/v1/vouchers'],
            ['GET', '/api/v1/cards'],
            ['GET', '/api/v1/transactions'],
        ] as [$method, $uri]) {
            $status = $this->json($method, $uri, ['amount' => 100, 'value' => 100, 'payment' => ['method' => 'cash']], $this->idempotency())->status();
            $this->assertContains($status, [403, 404, 409, 422], "{$method} {$uri} → {$status}");
        }
        $this->assertSame(5000, $voucher->refresh()->balance);
    }
}
