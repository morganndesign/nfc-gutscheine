<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Models\Role;
use App\Models\User;
use Illuminate\Routing\Route as RoutingRoute;
use Illuminate\Support\Facades\Route;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Data-driven guard for the whole permission matrix: route list x role -> allow/deny.
 *
 * It exists so a new /api/v1 route cannot be shipped without the right protection: either it is one of
 * a short, explicit list of public or shared-authenticated routes, or it carries a `can:<ability>` gate,
 * and every role reaches exactly the routes its permissions allow.
 */
final class PermissionMatrixTest extends TestCase
{
    /** Routes reachable without authentication. */
    private const PUBLIC_ROUTES = [
        'GET api/v1/app/config',
        'GET api/v1/health/operations',
        'POST api/v1/auth/login',
        'POST api/v1/auth/login/code',
        'POST api/v1/auth/login/code/resend',
        'POST api/v1/auth/token',
        'POST api/v1/auth/token/code',
        'POST api/v1/auth/token/code/resend',
        'POST api/v1/auth/forgot-password',
        'POST api/v1/auth/reset-password',
        // Online sales (decision 2026-10-06): a restaurant's public shop, the buyer's order status (with its
        // secret), and Stripe's signed webhook.
        'GET api/v1/shop/{slug}',
        'GET api/v1/shop/{slug}/logo',
        'POST api/v1/shop/{slug}/orders',
        'GET api/v1/shop/orders/{order}',
        'POST api/v1/webhooks/stripe',
    ];

    /** Authenticated routes with no ability gate: any signed-in user of any role may call them. */
    private const SHARED_AUTH_ROUTES = [
        'GET api/v1/auth/me',
        'POST api/v1/auth/logout',
        'POST api/v1/auth/logout-everywhere',
        'PUT api/v1/auth/profile',
        'PUT api/v1/auth/language',
        'PUT api/v1/auth/password',
        'GET api/v1/devices/current',
        'GET api/v1/restaurant/logo',
        // Card authentication for the waiter app; guarded by throttle and the device token, not an ability.
        'POST api/v1/presentments/cards',
        'POST api/v1/presentments/cards/{authentication}',
    ];

    /**
     * Every /api/v1 route must be public, shared-authenticated, or protected by a `can:` ability.
     * A new route added without a gate fails here.
     */
    public function test_every_api_route_is_public_shared_or_ability_gated(): void
    {
        $unprotected = [];
        foreach ($this->apiRoutes() as $key => $route) {
            if (in_array($key, self::PUBLIC_ROUTES, true) || in_array($key, self::SHARED_AUTH_ROUTES, true)) {
                continue;
            }
            if ($this->abilityOf($route) === null) {
                $unprotected[] = $key;
            }
        }

        $this->assertSame([], $unprotected, 'These /api/v1 routes have no can:<ability> gate and are not on the public/shared allowlist: '.implode(', ', $unprotected));
    }

    /**
     * Public routes never require authentication: a guest reaches them (never 401/403).
     */
    public function test_public_routes_reachable_by_guest(): void
    {
        foreach ($this->apiRoutes() as $key => $route) {
            if (! in_array($key, self::PUBLIC_ROUTES, true)) {
                continue;
            }
            $status = $this->callRoute($route);
            $this->assertNotContains($status, [401, 403], "Public route {$key} should not require auth, got {$status}.");
        }
    }

    /**
     * Guests are refused every authenticated route (401), whatever the ability.
     */
    public function test_guest_is_refused_every_authenticated_route(): void
    {
        foreach ($this->apiRoutes() as $key => $route) {
            if (in_array($key, self::PUBLIC_ROUTES, true)) {
                continue;
            }
            $status = $this->callRoute($route);
            $this->assertSame(401, $status, "Authenticated route {$key} must refuse a guest with 401, got {$status}.");
        }
    }

    /**
     * For every collection / action route (no {parameter}, so route-model binding cannot interfere),
     * each role reaches exactly the routes its permissions and tenant allow. A role that reaches a route
     * it should not, or is blocked from one it should reach, fails here.
     */
    public function test_role_matrix_on_non_parameterized_routes(): void
    {
        $restaurant = $this->restaurant();
        $actors = [
            RoleSlug::Waiter->value => User::factory()->forRestaurant($restaurant)->waiter()->create(),
            RoleSlug::Manager->value => User::factory()->forRestaurant($restaurant)->manager()->create(),
            RoleSlug::Owner->value => User::factory()->forRestaurant($restaurant)->owner()->create(),
            RoleSlug::PlatformAdmin->value => User::factory()->platformAdmin()->create(),
        ];
        $permissions = [];
        foreach (array_keys($actors) as $slug) {
            $permissions[$slug] = Role::findBySlug(RoleSlug::from($slug))->permissionSlugs();
        }

        $failures = [];
        foreach ($this->apiRoutes() as $key => $route) {
            if (in_array($key, self::PUBLIC_ROUTES, true)) {
                continue;
            }
            if (str_contains($route->uri(), '{')) {
                continue; // parameterized: binding runs before the gate; covered by the static + behavioural tests
            }
            if ($key === 'PUT api/v1/auth/password') {
                continue; // gated on the auth mechanism (browser session only, ChangePasswordRequest), not on a role
            }
            $ability = $this->abilityOf($route);
            $needsTenant = in_array('tenant.required', $route->gatherMiddleware(), true);

            foreach ($actors as $slug => $user) {
                Sanctum::actingAs($user, ['*']);
                $hasAbility = $ability === null || ! array_diff($ability, $permissions[$slug]);
                $hasTenant = $slug !== RoleSlug::PlatformAdmin->value;
                $expectAllow = $hasAbility && ($hasTenant || ! $needsTenant);

                $status = $this->callRoute($route);
                $reached = ! in_array($status, [401, 403], true);
                if ($reached !== $expectAllow) {
                    $failures[] = sprintf('%s %s expected %s got %d', $slug, $key, $expectAllow ? 'ALLOW' : 'DENY', $status);
                }
            }
        }

        $this->assertSame([], $failures, "Permission matrix mismatches:\n".implode("\n", $failures));
    }

    /**
     * A parameterized, ability-gated route denies a role that lacks the ability with 403 even when the
     * target row exists in the caller's own tenant (so route-model binding succeeds first). Uses a voucher
     * action a waiter may not perform.
     */
    public function test_denied_role_gets_403_on_existing_in_tenant_resource(): void
    {
        $restaurant = $this->restaurant();
        $voucher = $this->issueVoucher($restaurant);
        $waiter = User::factory()->forRestaurant($restaurant)->waiter()->create();
        Sanctum::actingAs($waiter, ['*']);

        // Waiter lacks vouchers.block / vouchers.refund; the row exists, so binding passes and the gate denies.
        $this->postJson("/api/v1/vouchers/{$voucher->id}/block", ['reason' => 'nope'])->assertForbidden();
        $this->postJson("/api/v1/vouchers/{$voucher->id}/refund", [], $this->idempotency())->assertForbidden();
        // And still reaches its own permitted action (not 403/401).
        $this->getJson('/api/v1/auth/me')->assertOk();
    }

    /**
     * @return array<string, RoutingRoute>
     */
    private function apiRoutes(): array
    {
        $routes = [];
        foreach (Route::getRoutes() as $route) {
            $uri = $route->uri();
            if (! str_starts_with($uri, 'api/v1')) {
                continue;
            }
            foreach ($route->methods() as $method) {
                if (in_array($method, ['HEAD', 'OPTIONS'], true)) {
                    continue;
                }
                $routes["{$method} {$uri}"] = $route;
            }
        }

        return $routes;
    }

    /**
     * The abilities required by a route's can: gates, or null if it has none.
     *
     * @return list<string>|null
     */
    private function abilityOf(RoutingRoute $route): ?array
    {
        $abilities = [];
        foreach ($route->gatherMiddleware() as $middleware) {
            if (is_string($middleware) && str_starts_with($middleware, 'can:')) {
                $abilities[] = explode(',', substr($middleware, 4))[0];
            }
        }

        return $abilities === [] ? null : $abilities;
    }

    /** Calls a route with a non-existent id for every parameter and a minimal body; returns the status. */
    private function callRoute(RoutingRoute $route): int
    {
        $method = $route->methods()[0];
        // Each parameter gets a non-existent value that satisfies its route pattern, so routing matches
        // and the middleware pipeline (auth + gate) runs - the thing under test.
        $uri = '/'.preg_replace_callback('/\{(\w+)\??\}/', static function (array $m): string {
            return match ($m[1]) {
                'card' => 'B-9999-9999-9999',
                'authentication', 'personalization', 'alert' => '0000000000000000000000000A',
                'idempotencyKey' => 'matrixtestkey123456',
                'key' => 'voucher_issued',
                default => '01a00000-0000-7000-8000-000000000001',
            };
        }, $route->uri());

        return $this->json($method, $uri, [], $this->idempotency() + ['X-Device-Id' => 'matrix-test-device-01'])->baseResponse->getStatusCode();
    }
}
