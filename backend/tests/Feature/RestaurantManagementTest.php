<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Models\AuditLog;
use App\Models\Customer;
use App\Models\Device;
use App\Models\NotificationLog;
use App\Models\NotificationTemplate;
use App\Models\Restaurant;
use App\Models\RestaurantSetting;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Notification;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Platform admin: restaurant create / edit / disable / archive / restore / delete.
 */
final class RestaurantManagementTest extends TestCase
{
    private function actingAsAdmin(): User
    {
        $admin = User::factory()->platformAdmin()->create(['name' => 'Platform Admin']);
        Sanctum::actingAs($admin, ['*']);

        return $admin;
    }

    /** @return array{0: Restaurant, 1: User} */
    private function onboard(string $name = 'Café Central', string $ownerEmail = 'owner@central.test'): array
    {
        $id = $this->postJson('/api/v1/admin/restaurants', [
            'name' => $name,
            'owner' => ['name' => 'Olga Owner', 'email' => $ownerEmail],
        ])->assertCreated()->json('data.id');

        $restaurant = Restaurant::withTrashed()->findOrFail($id);

        return [$restaurant, User::query()->where('email', $ownerEmail)->firstOrFail()];
    }

    public function test_list_shows_owner_email_status_and_invitation(): void
    {
        Notification::fake();
        $this->actingAsAdmin();
        [$restaurant] = $this->onboard();

        $this->getJson('/api/v1/admin/restaurants')
            ->assertOk()
            ->assertJsonPath('data.0.id', $restaurant->id)
            ->assertJsonPath('data.0.status', 'active')
            ->assertJsonPath('data.0.archived_at', null)
            ->assertJsonPath('data.0.owner.name', 'Olga Owner')
            ->assertJsonPath('data.0.owner.email', 'owner@central.test')
            ->assertJsonPath('data.0.owner.invitation.status', 'pending')
            ->assertJsonPath('data.0.owner.invitation.delivery', 'sent');

        // Search also finds the restaurant by its owner's e-mail address.
        $this->getJson('/api/v1/admin/restaurants?search=owner@central')->assertOk()->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/admin/restaurants?search=nobody')->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_admin_edits_restaurant_including_plan_and_currency(): void
    {
        Notification::fake();
        $this->actingAsAdmin();
        [$restaurant] = $this->onboard();

        $this->patchJson("/api/v1/admin/restaurants/{$restaurant->id}", [
            'name' => 'Café Central Wien',
            'city' => 'Wien',
            'plan' => 'pro',
            'currency' => 'CHF',
        ])->assertOk()
            ->assertJsonPath('data.name', 'Café Central Wien')
            ->assertJsonPath('data.plan', 'pro')
            ->assertJsonPath('data.currency', 'CHF')
            ->assertJsonPath('data.owner.email', 'owner@central.test');

        $this->assertDatabaseHas('audit_logs', ['action' => 'restaurant.updated', 'restaurant_id' => $restaurant->id]);
        $this->patchJson("/api/v1/admin/restaurants/{$restaurant->id}", ['currency' => 'XYZ'])->assertUnprocessable();
    }

    public function test_currency_is_locked_once_vouchers_exist(): void
    {
        $this->actingAsAdmin();
        $restaurant = $this->restaurant(['currency' => 'EUR']);
        $this->issueVoucher($restaurant);

        $this->patchJson("/api/v1/admin/restaurants/{$restaurant->id}", ['currency' => 'CHF'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('currency');
        $this->patchJson("/api/v1/admin/restaurants/{$restaurant->id}", ['currency' => 'EUR', 'plan' => 'pro'])->assertOk();
    }

    public function test_disable_and_enable(): void
    {
        $this->actingAsAdmin();
        $restaurant = $this->restaurant();

        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/suspend", [])->assertUnprocessable();
        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/suspend", ['reason' => 'Unpaid invoice'])
            ->assertOk()->assertJsonPath('data.status', 'suspended')->assertJsonPath('data.suspension_reason', 'Unpaid invoice');
        $this->getJson('/api/v1/admin/restaurants?status=suspended')->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/admin/restaurants?status=active')->assertJsonCount(0, 'data');
        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/reactivate")->assertOk()->assertJsonPath('data.status', 'active');
    }

    public function test_archive_locks_out_users_and_restore_brings_everything_back(): void
    {
        $this->actingAsAdmin();
        $restaurant = $this->restaurant();
        $voucher = $this->issueVoucher($restaurant, 2500);
        $owner = $this->staff($restaurant, RoleSlug::Owner);

        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/archive", ['reason' => 'Closed down'])
            ->assertOk()->assertJsonPath('data.archived_at', fn ($v) => is_string($v));

        $this->assertSoftDeleted('restaurants', ['id' => $restaurant->id]);
        $this->assertDatabaseHas('audit_logs', ['action' => 'restaurant.archived', 'restaurant_id' => $restaurant->id]);
        $this->getJson('/api/v1/admin/restaurants')->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/admin/restaurants?status=archived')->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $restaurant->id);
        $this->getJson("/api/v1/admin/restaurants/{$restaurant->id}")->assertOk()->assertJsonPath('business_data.vouchers', 1);

        // Archived restaurants cannot be edited or disabled, only viewed, restored or deleted.
        $this->patchJson("/api/v1/admin/restaurants/{$restaurant->id}", ['name' => 'X'])->assertNotFound();

        // Staff of an archived restaurant are locked out.
        Sanctum::actingAs($owner, ['*']);
        $this->getJson('/api/v1/vouchers')->assertUnauthorized();

        $this->actingAsAdmin();
        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/restore")->assertOk()->assertJsonPath('data.archived_at', null);
        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/restore")->assertStatus(409);
        $this->assertDatabaseHas('audit_logs', ['action' => 'restaurant.restored', 'restaurant_id' => $restaurant->id]);

        Sanctum::actingAs($owner->fresh(), ['*']);
        $this->getJson('/api/v1/vouchers')->assertOk()->assertJsonPath('data.0.id', $voucher->id)->assertJsonPath('data.0.balance', 2500);
    }

    public function test_delete_requires_typed_confirmation(): void
    {
        Notification::fake();
        $this->actingAsAdmin();
        [$restaurant] = $this->onboard();

        $this->deleteJson("/api/v1/admin/restaurants/{$restaurant->id}")->assertUnprocessable()->assertJsonValidationErrors('confirm');
        $this->deleteJson("/api/v1/admin/restaurants/{$restaurant->id}", ['confirm' => 'something-else'])
            ->assertUnprocessable()->assertJsonValidationErrors('confirm');
        $this->assertDatabaseHas('restaurants', ['id' => $restaurant->id]);
    }

    public function test_delete_removes_an_empty_restaurant_with_its_accounts_and_keeps_the_audit_trail(): void
    {
        Notification::fake();
        $this->actingAsAdmin();
        [$restaurant, $owner] = $this->onboard();
        $waiter = $this->staff($restaurant, RoleSlug::Waiter);
        $device = Device::factory()->create(['restaurant_id' => $restaurant->id, 'last_user_id' => $waiter->id]);
        $waiter->createToken('app');
        DB::table('sessions')->insert(['id' => 'sess-1', 'user_id' => $owner->id, 'payload' => '', 'last_activity' => time()]);
        NotificationTemplate::query()->create([
            'restaurant_id' => $restaurant->id, 'key' => 'voucher_issued', 'channel' => 'mail', 'locale' => 'en',
            'subject' => 'S', 'body' => 'B', 'is_active' => true,
        ]);

        $this->deleteJson("/api/v1/admin/restaurants/{$restaurant->id}", ['confirm' => strtoupper($restaurant->slug)])
            ->assertOk()->assertJsonPath('message', 'Café Central was deleted.');

        $this->assertDatabaseMissing('restaurants', ['id' => $restaurant->id]);
        $this->assertDatabaseMissing('users', ['id' => $owner->id]);
        $this->assertDatabaseMissing('users', ['id' => $waiter->id]);
        $this->assertDatabaseMissing('devices', ['id' => $device->id]);
        $this->assertDatabaseMissing('personal_access_tokens', ['tokenable_id' => $waiter->id]);
        $this->assertDatabaseMissing('sessions', ['id' => 'sess-1']);
        $this->assertDatabaseMissing('invitation_tokens', ['email' => $owner->email]);
        $this->assertSame(0, RestaurantSetting::query()->where('restaurant_id', $restaurant->id)->count());
        $this->assertSame(0, NotificationTemplate::query()->withoutGlobalScopes()->where('restaurant_id', $restaurant->id)->count());

        // The append-only trail stays untouched, with the deleted restaurant's id, and the deletion itself is logged.
        $deleted = AuditLog::query()->withoutGlobalScopes()->where('action', 'restaurant.deleted')->firstOrFail();
        $this->assertSame($restaurant->id, $deleted->metadata['restaurant_id']);
        $this->assertSame(2, $deleted->metadata['users_deleted']);
        $this->assertTrue(AuditLog::query()->withoutGlobalScopes()->where('action', 'restaurant.created')->where('restaurant_id', $restaurant->id)->exists());
        $this->artisan('giftcard:verify-chains')->assertSuccessful();
        $this->assertTrue(NotificationLog::query()->where('recipient', 'owner@central.test')->whereNull('restaurant_id')->exists());

        // The e-mail address is free again.
        $this->onboard('Café Central', 'owner@central.test');
    }

    public function test_delete_is_refused_with_customers_and_works_for_archived_empty_restaurants(): void
    {
        $this->actingAsAdmin();
        $withCustomer = $this->restaurant();
        Customer::factory()->create(['restaurant_id' => $withCustomer->id]);

        $this->deleteJson("/api/v1/admin/restaurants/{$withCustomer->id}", ['confirm' => $withCustomer->slug])
            ->assertStatus(409)->assertJsonPath('code', 'RESTAURANT_NOT_DELETABLE')->assertJsonPath('context.customers', 1);

        $empty = $this->restaurant();
        $this->postJson("/api/v1/admin/restaurants/{$empty->id}/archive")->assertOk();
        $this->deleteJson("/api/v1/admin/restaurants/{$empty->id}", ['confirm' => $empty->slug])->assertOk();
        $this->assertDatabaseMissing('restaurants', ['id' => $empty->id]);
    }

    public function test_stats_count_archived_restaurants(): void
    {
        $this->actingAsAdmin();
        $restaurant = $this->restaurant();
        $this->restaurant();
        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/archive")->assertOk();

        $this->getJson('/api/v1/admin/stats')
            ->assertOk()
            ->assertJsonPath('data.restaurants_total', 1)
            ->assertJsonPath('data.restaurants_archived', 1);
    }
}
