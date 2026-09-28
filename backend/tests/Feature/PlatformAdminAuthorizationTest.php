<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Models\Restaurant;
use App\Models\User;
use Laravel\Sanctum\Sanctum;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * Every platform administration endpoint is reserved for platform administrators: restaurant staff of any
 * role get 403 (also for their own restaurant), guests 401, and nothing changes.
 */
final class PlatformAdminAuthorizationTest extends TestCase
{
    /** @return list<array{0: string, 1: string}> */
    private function endpoints(Restaurant $restaurant, User $user): array
    {
        $r = $restaurant->id;

        return [
            ['GET', '/api/v1/admin/stats'],
            ['GET', '/api/v1/admin/restaurants'],
            ['POST', '/api/v1/admin/restaurants'],
            ['GET', "/api/v1/admin/restaurants/{$r}"],
            ['PATCH', "/api/v1/admin/restaurants/{$r}"],
            ['POST', "/api/v1/admin/restaurants/{$r}/suspend"],
            ['POST', "/api/v1/admin/restaurants/{$r}/reactivate"],
            ['POST', "/api/v1/admin/restaurants/{$r}/archive"],
            ['POST', "/api/v1/admin/restaurants/{$r}/restore"],
            ['DELETE', "/api/v1/admin/restaurants/{$r}"],
            ['POST', "/api/v1/admin/restaurants/{$r}/invitation"],
            ['POST', "/api/v1/admin/restaurants/{$r}/users/{$user->id}/invitation"],
            ['GET', '/api/v1/admin/audit-logs'],
            ['GET', '/api/v1/admin/system-settings'],
            ['PUT', '/api/v1/admin/system-settings'],
            ['GET', '/api/v1/admin/mail'],
            ['POST', '/api/v1/admin/mail/test'],
        ];
    }

    /** @return array<string, array{0: RoleSlug}> */
    public static function restaurantRoles(): array
    {
        return [
            'owner' => [RoleSlug::Owner],
            'manager' => [RoleSlug::Manager],
            'waiter' => [RoleSlug::Waiter],
        ];
    }

    #[DataProvider('restaurantRoles')]
    public function test_restaurant_staff_cannot_use_platform_administration(RoleSlug $role): void
    {
        $restaurant = $this->restaurant(['name' => 'Own Restaurant']);
        $user = $this->actingAsStaff($restaurant, $role);

        foreach ($this->endpoints($restaurant, $user) as [$method, $uri]) {
            $this->json($method, $uri, ['confirm' => $restaurant->slug, 'reason' => 'x', 'name' => 'Hijack', 'owner' => ['name' => 'X', 'email' => 'x@x.test']])
                ->assertForbidden();
            // Also not "acting" inside their own restaurant.
            $this->withHeader('X-Restaurant-Id', $restaurant->id)->json($method, $uri, ['confirm' => $restaurant->slug])->assertForbidden();
        }

        $this->assertDatabaseHas('restaurants', ['id' => $restaurant->id, 'name' => 'Own Restaurant', 'deleted_at' => null, 'status' => 'active']);
        $this->assertDatabaseMissing('users', ['email' => 'x@x.test']);
    }

    public function test_guests_are_rejected(): void
    {
        $restaurant = $this->restaurant();
        $user = $this->staff($restaurant, RoleSlug::Owner);

        foreach ($this->endpoints($restaurant, $user) as [$method, $uri]) {
            $this->json($method, $uri)->assertUnauthorized();
        }
    }

    public function test_deactivated_platform_admin_is_rejected(): void
    {
        $admin = User::factory()->platformAdmin()->inactive()->create();
        Sanctum::actingAs($admin, ['*']);

        $this->getJson('/api/v1/admin/restaurants')->assertUnauthorized();
    }

    public function test_platform_admin_is_allowed(): void
    {
        Sanctum::actingAs(User::factory()->platformAdmin()->create(), ['*']);

        $this->getJson('/api/v1/admin/restaurants')->assertOk();
        $this->getJson('/api/v1/admin/mail')->assertOk();
    }
}
