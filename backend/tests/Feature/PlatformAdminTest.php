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
        $this->issueCard($restaurant, 5000);

        $this->getJson('/api/v1/admin/restaurants')
            ->assertOk()
            ->assertJsonPath('data.0.gift_cards_count', 1)
            ->assertJsonPath('data.0.outstanding_balance', 5000);

        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/suspend", ['reason' => 'Contract ended'])
            ->assertOk()->assertJsonPath('data.status', 'suspended');

        $owner = $this->staff($restaurant, RoleSlug::Owner);
        Sanctum::actingAs($owner, ['*']);
        $this->getJson('/api/v1/cards')->assertForbidden()->assertJsonPath('code', 'RESTAURANT_SUSPENDED');

        $this->actingAsAdmin();
        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/reactivate")->assertOk()->assertJsonPath('data.status', 'active');
    }

    public function test_admin_can_act_inside_a_restaurant_explicitly(): void
    {
        $this->actingAsAdmin();
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);

        $this->getJson('/api/v1/cards')->assertForbidden()->assertJsonPath('code', 'TENANT_NOT_RESOLVED');
        $this->withHeader('X-Restaurant-Id', $restaurant->id)->getJson('/api/v1/cards')
            ->assertOk()->assertJsonPath('data.0.id', $card->id);
    }

    public function test_platform_stats_and_audit(): void
    {
        $this->actingAsAdmin();
        $this->issueCard($this->restaurant(), 5000);

        $this->getJson('/api/v1/admin/stats')->assertOk()->assertJsonPath('data.cards_total', 1)->assertJsonPath('data.volume_sold_this_month', 5000);
        $this->getJson('/api/v1/admin/audit-logs')->assertOk()->assertJsonPath('data.0.action', 'gift_card.issued');
    }

    public function test_restaurant_data_is_never_deleted(): void
    {
        $this->actingAsAdmin();
        $restaurant = $this->restaurant();

        $this->deleteJson("/api/v1/admin/restaurants/{$restaurant->id}")->assertStatus(405);
        $this->assertTrue(Restaurant::query()->whereKey($restaurant->id)->exists());
    }
}
