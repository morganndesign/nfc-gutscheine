<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Models\Restaurant;
use App\Models\User;
use App\Notifications\StaffInvitation;
use Illuminate\Support\Facades\Notification;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

final class PlatformAdminTest extends TestCase
{
    private function actingAsAdmin(): User
    {
        $admin = User::factory()->platformAdmin()->create();
        Sanctum::actingAs($admin, ['*']);

        return $admin;
    }

    public function test_admin_onboards_a_restaurant_with_owner_invitation(): void
    {
        Notification::fake();
        $this->actingAsAdmin();

        $response = $this->postJson('/api/v1/admin/restaurants', [
            'name' => 'Zum Schwarzen Kameel',
            'city' => 'Wien',
            'currency' => 'EUR',
            'timezone' => 'Europe/Vienna',
            'owner' => ['name' => 'Eva Maier', 'email' => 'eva@kameel.test'],
        ])->assertCreated()
            ->assertJsonPath('data.slug', 'zum-schwarzen-kameel')
            ->assertJsonPath('data.settings.allow_reload', true)
            ->assertJsonPath('owner.role.slug', 'owner');

        $owner = User::query()->where('email', 'eva@kameel.test')->firstOrFail();
        $this->assertSame($response->json('data.id'), $owner->restaurant_id);
        Notification::assertSentTo($owner, StaffInvitation::class);
    }

    public function test_admin_lists_and_suspends_restaurants(): void
    {
        $this->actingAsAdmin();
        $restaurant = $this->restaurant();
        $this->issueVoucher($restaurant, 5000);

        $this->getJson('/api/v1/admin/restaurants')
            ->assertOk()
            ->assertJsonPath('data.0.vouchers_count', 1)
            ->assertJsonPath('data.0.outstanding_balance', 5000);

        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/suspend", ['reason' => 'Contract ended'])
            ->assertOk()->assertJsonPath('data.status', 'suspended');

        $owner = $this->staff($restaurant, RoleSlug::Owner);
        Sanctum::actingAs($owner, ['*']);
        $this->getJson('/api/v1/vouchers')->assertForbidden()->assertJsonPath('code', 'RESTAURANT_SUSPENDED');

        $this->actingAsAdmin();
        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/reactivate")->assertOk()->assertJsonPath('data.status', 'active');
    }

    /** Architecture §13.1: platform staff operate the platform, never vouchers, in no restaurant. */
    public function test_admin_never_acts_inside_a_restaurant(): void
    {
        $this->actingAsAdmin();
        $restaurant = $this->restaurant();
        $voucher = $this->issueVoucher($restaurant);

        $this->getJson('/api/v1/vouchers')->assertForbidden();
        $this->withHeader('X-Restaurant-Id', $restaurant->id)->getJson('/api/v1/vouchers')->assertForbidden();
        $this->withHeader('X-Restaurant-Id', $restaurant->id)->getJson("/api/v1/vouchers/{$voucher->id}")->assertForbidden();
        $this->withHeader('X-Restaurant-Id', $restaurant->id)->postJson('/api/v1/presentments', ['purpose' => 'spend', 'method' => 'printable_qr', 'credential' => 'x'])->assertForbidden();
    }

    public function test_platform_stats_and_audit(): void
    {
        $this->actingAsAdmin();
        $this->issueVoucher($this->restaurant(), 5000);

        $this->getJson('/api/v1/admin/stats')->assertOk()->assertJsonPath('data.vouchers_total', 1)->assertJsonPath('data.volume_sold_this_month', 5000);
        $this->assertContains('voucher.sold', array_column($this->getJson('/api/v1/admin/audit-logs')->assertOk()->json('data'), 'action'));
    }

    public function test_restaurant_business_data_is_never_deleted(): void
    {
        $this->actingAsAdmin();
        $restaurant = $this->restaurant();
        $this->issueVoucher($restaurant, 5000);

        $this->deleteJson("/api/v1/admin/restaurants/{$restaurant->id}", ['confirm' => $restaurant->slug])
            ->assertStatus(409)
            ->assertJsonPath('code', 'RESTAURANT_NOT_DELETABLE')
            ->assertJsonPath('context.vouchers', 1)
            ->assertJsonPath('context.transactions', 1);
        $this->assertTrue(Restaurant::query()->whereKey($restaurant->id)->exists());
    }
}
