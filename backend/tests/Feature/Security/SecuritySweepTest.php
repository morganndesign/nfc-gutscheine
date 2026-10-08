<?php

declare(strict_types=1);

namespace Tests\Feature\Security;

use App\Enums\RoleSlug;
use App\Enums\VoucherStatus;
use App\Models\Card;
use App\Models\Customer;
use App\Models\Device;
use App\Models\PartnerConnection;
use App\Models\PartnerLinkCode;
use App\Models\Restaurant;
use App\Models\User;
use App\Models\Voucher;
use App\Models\VoucherTransaction;
use App\Services\ApiTokens\ApiTokenService;
use App\Services\Partners\PartnerService;
use App\Support\Actor;
use Illuminate\Routing\Route as RoutingRoute;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use PHPUnit\Framework\Attributes\Group;
use Tests\Support\WithCards;
use Tests\TestCase;

/**
 * Security sweep over the whole route list (security/README.md). Data-driven like the permission matrix, so a new
 * route is swept automatically and a new route parameter fails until it is added here:
 *
 *  - every route with a record in its path hides another restaurant's record (403/404, nothing changes),
 *  - no route answers malformed input with a server error,
 *  - no answer carries a password, key or token hash,
 *  - fields that grant power (role, restaurant, platform admin) are ignored in request bodies,
 *  - every route that can be called without a session is rate-limited.
 */
#[Group('security')]
final class SecuritySweepTest extends TestCase
{
    use WithCards;

    /** Route parameters that are not a record of a restaurant, and why they are not swept for tenant isolation. */
    private const NOT_A_TENANT_RECORD = [
        'key' => 'notification template key: always resolved inside the caller\'s own restaurant',
        'idempotencyKey' => 'looked up under {voucher}, which is swept',
        'authentication' => 'a live card authentication, bound to its device (tests/Feature/Cards)',
        'slug' => 'public shop page',
        'order' => 'public order status (secret token) or platform card order (platform permission)',
        'personalization' => 'platform card station (platform permission)',
        'alert' => 'platform security alert (platform permission)',
        'partner' => 'platform POS partner (platform permission)',
    ];

    protected function tearDown(): void
    {
        $this->tearDownCardKeystore();
        parent::tearDown();
    }

    public function test_every_route_with_a_record_hides_another_restaurants_record(): void
    {
        $this->setUpCardKeystore();
        $a = $this->restaurant(['name' => 'Restaurant A']);
        $ownerA = $this->staff($a, RoleSlug::Owner);
        $records = $this->recordsOf($a, $ownerA);
        $before = $this->snapshot($records);

        $b = $this->restaurant(['name' => 'Restaurant B']);
        $ownerB = $this->staff($b, RoleSlug::Owner);

        $leaks = [];
        $unknown = [];
        foreach ($this->apiRoutes() as $key => [$method, $route]) {
            $parameters = $route->parameterNames();
            if ($parameters === [] || array_diff($parameters, array_keys(self::NOT_A_TENANT_RECORD)) === []) {
                continue;
            }
            $path = $route->uri();
            foreach ($parameters as $name) {
                if (isset($records[$name])) {
                    $path = str_replace('{'.$name.'}', $records[$name], $path);
                } elseif (isset(self::NOT_A_TENANT_RECORD[$name])) {
                    $path = str_replace('{'.$name.'}', (string) Str::uuid(), $path);
                } else {
                    $unknown[] = "{$key}: {{$name}}";
                }
            }
            Sanctum::actingAs($ownerB, ['*']);
            $response = $this->json($method, '/'.$path, $this->anyBody(), $this->idempotency());
            if (! in_array($response->status(), [403, 404], true)) {
                $leaks[] = "{$key} → {$response->status()} ".substr((string) $response->getContent(), 0, 120);
            }
            $this->app['auth']->forgetGuards();
        }

        $this->assertSame([], $unknown, 'New route parameters: add a record for them in recordsOf() or explain them in NOT_A_TENANT_RECORD.');
        $this->assertSame([], $leaks, "Another restaurant's owner reached a record:\n".implode("\n", $leaks));
        $this->assertSame($before, $this->snapshot($records), 'A record of restaurant A changed.');
    }

    public function test_no_route_answers_malformed_input_with_a_server_error(): void
    {
        $this->setUpCardKeystore();
        $a = $this->restaurant();
        $owner = $this->staff($a, RoleSlug::Owner);
        $records = $this->recordsOf($a, $owner);
        $admin = User::factory()->platformAdmin()->create();

        $bodies = [
            'empty' => [],
            'wrong types' => ['amount' => 'zehn', 'value' => ['x'], 'email' => 42, 'name' => ['a' => 'b'], 'reason' => true, 'code' => null, 'per_page' => 'all'],
            'out of range' => ['amount' => -1, 'value' => PHP_INT_MAX, 'max_amount' => 1e30, 'validity_months' => -5, 'page' => -1],
            'very long' => ['name' => str_repeat('A', 100_000), 'reason' => str_repeat('ü', 20_000), 'email' => str_repeat('a', 300).'@example.com'],
            'deep nesting' => ['data' => $this->nested(64), 'items' => array_fill(0, 2_000, ['x' => 1])],
            'control characters' => ['name' => "a\u{0000}b\u{202E}c", 'reason' => "\r\nX-Injected: 1", 'note' => "\xC3\x28"],
        ];
        $queries = ['?page=-1&per_page=100000', '?search[]=x&status[]=y', '?sort=%27&direction=sideways', '?from=gestern&to=2026-13-45', '?per_page=0'];

        // Takes no input, and its web-session branch needs a real browser session (tests/Feature/AuthenticationTest).
        $noInput = ['POST api/v1/auth/logout'];
        $errors = [];
        foreach ($this->apiRoutes() as $key => [$method, $route]) {
            if (in_array($key, $noInput, true)) {
                continue;
            }
            $path = '/'.$route->uri();
            foreach ($route->parameterNames() as $name) {
                $path = str_replace('{'.$name.'}', $records[$name] ?? 'x', $path);
            }
            $user = str_contains($path, '/admin/') ? $admin : $owner;
            foreach ($method === 'GET' ? $queries : $bodies as $label => $input) {
                Sanctum::actingAs($user, ['*']);
                $response = $method === 'GET'
                    ? $this->getJson($path.$input)
                    : $this->json($method, $path, $input, $this->idempotency());
                $status = $response->baseResponse->getStatusCode();
                // The operations health check answers 503 by design while the scheduler and worker are not running.
                if ($status >= 500 && ! ($key === 'GET api/v1/health/operations' && $status === 503)) {
                    $errors[] = "{$key} ({$label}) → {$response->baseResponse->getStatusCode()} ".substr((string) $response->baseResponse->getContent(), 0, 160);
                }
                $this->app['auth']->forgetGuards();
            }
        }

        $this->assertSame([], $errors, "Server errors on malformed input:\n".implode("\n", $errors));
    }

    public function test_no_answer_carries_a_secret(): void
    {
        $this->setUpCardKeystore();
        $a = $this->restaurant();
        $owner = $this->staff($a, RoleSlug::Owner);
        $records = $this->recordsOf($a, $owner);
        $admin = User::factory()->platformAdmin()->create();
        app(PartnerService::class)->create('Sweep Kasse', null);

        $found = [];
        foreach ($this->apiRoutes() as $key => [$method, $route]) {
            if ($method !== 'GET' || str_contains($route->uri(), 'export')) {
                continue;
            }
            $path = '/'.$route->uri();
            foreach ($route->parameterNames() as $name) {
                $path = str_replace('{'.$name.'}', $records[$name] ?? 'x', $path);
            }
            Sanctum::actingAs(str_contains($path, '/admin/') ? $admin : $owner, ['*']);
            $body = (string) $this->getJson($path)->getContent();
            if (preg_match('/"(password|remember_token|key_hash|token_hash|code_hash|secret|two_factor_secret)"\s*:|\$2y\$\d\d\$|gcp[pc]_[A-Za-z0-9]{20,}/', $body, $m) === 1) {
                $found[] = "{$key}: {$m[0]}";
            }
            $this->app['auth']->forgetGuards();
        }

        $this->assertSame([], $found, "Secrets in answers:\n".implode("\n", $found));
    }

    public function test_fields_that_grant_power_are_ignored_in_request_bodies(): void
    {
        $a = $this->restaurant();
        $b = $this->restaurant();
        $owner = $this->staff($a, RoleSlug::Owner);
        $waiter = $this->staff($a, RoleSlug::Waiter);
        $power = [
            'role' => 'platform_admin', 'role_id' => 1, 'role_slug' => 'owner', 'restaurant_id' => $b->id,
            'is_platform_admin' => true, 'permissions' => ['platform.settings.manage'], 'status' => 'active',
            'can_give_loyalty' => true, 'email_verified_at' => now()->toIso8601String(),
        ];

        Sanctum::actingAs($waiter, ['*']);
        $this->putJson('/api/v1/auth/profile', ['name' => 'Anna'] + $power);
        $this->putJson('/api/v1/auth/language', ['locale' => 'de'] + $power);
        $waiter->refresh();
        $this->assertSame($a->id, $waiter->restaurant_id);
        $this->assertNotTrue($waiter->is_platform_admin);
        $this->assertSame(RoleSlug::Waiter, $waiter->role->slug);
        $this->assertFalse((bool) $waiter->can_give_loyalty);

        Sanctum::actingAs($owner, ['*']);
        $this->patchJson("/api/v1/users/{$waiter->id}", ['name' => 'Anna H.'] + array_diff_key($power, ['role' => 1, 'role_slug' => 1]));
        $this->putJson('/api/v1/settings/restaurant', ['name' => 'A'] + $power);
        $waiter->refresh();
        $this->assertSame($a->id, $waiter->restaurant_id);
        $this->assertNotTrue($waiter->is_platform_admin);
        $this->assertSame($a->id, $owner->refresh()->restaurant_id);
        $this->getJson('/api/v1/admin/restaurants')->assertForbidden();
    }

    public function test_every_route_reachable_without_a_session_is_rate_limited(): void
    {
        $unthrottled = [];
        foreach ($this->apiRoutes(includePartner: true) as $key => [$method, $route]) {
            $middleware = $route->gatherMiddleware();
            $guarded = array_filter($middleware, static fn (string $m): bool => str_starts_with($m, 'auth:') || $m === 'auth' || str_starts_with($m, 'partner.auth'));
            $throttled = array_filter($middleware, static fn (string $m): bool => str_starts_with($m, 'throttle'));
            // Webhooks are verified by signature; health and config are cached, read-only answers.
            $exempt = in_array($key, ['POST api/v1/webhooks/stripe', 'GET api/v1/health/operations', 'GET api/v1/app/config'], true);
            if (($guarded === [] || $method !== 'GET') && $throttled === [] && ! $exempt) {
                $unthrottled[] = $key;
            }
        }

        $this->assertSame([], $unthrottled, 'Routes without a rate limit: '.implode(', ', $unthrottled));
    }

    /**
     * One record of every kind a route can name, in restaurant A, by route parameter.
     *
     * @return array<string, string>
     */
    private function recordsOf(Restaurant $restaurant, User $owner): array
    {
        $voucher = $this->issueVoucher($restaurant, 5000, $owner);
        [, $cards] = $this->shippedCards($restaurant, 1);
        $partners = app(PartnerService::class);
        [$partner] = $partners->create('Kasse '.Str::random(4), null);
        $link = $this->asTenant($restaurant, fn () => $partners->createLinkCode(new Actor($owner), $restaurant));
        [$connection] = $partners->connect($partner, Actor::system(), $link['code']);
        $openCode = $this->asTenant($restaurant, function () use ($partners, $owner, $restaurant): string {
            $partners->createLinkCode(new Actor($owner), $restaurant);

            return (string) PartnerLinkCode::query()->whereNull('used_at')->latest('created_at')->value('id');
        });
        $token = app(ApiTokenService::class)->create(new Actor($owner), $owner, 'Kasse', ['vouchers.redeem'], null);

        return [
            'voucher' => (string) $voucher->id,
            'transaction' => (string) VoucherTransaction::query()->withoutGlobalScopes()->where('voucher_id', $voucher->id)->value('id'),
            'customer' => (string) Customer::factory()->create(['restaurant_id' => $restaurant->id])->id,
            'user' => (string) $this->staff($restaurant, RoleSlug::Waiter)->id,
            'device' => (string) Device::factory()->create(['restaurant_id' => $restaurant->id])->id,
            'card' => $cards[0]->card_number,
            'batch' => (string) $cards[0]->card_batch_id,
            'connection' => (string) $connection->id,
            'code' => $openCode,
            'token' => (string) $token->accessToken->getKey(),
            'restaurant' => (string) $restaurant->id,
        ];
    }

    /**
     * What a cross-tenant request could change, to prove nothing did.
     *
     * @param  array<string, string>  $records
     * @return array<string, mixed>
     */
    private function snapshot(array $records): array
    {
        $voucher = Voucher::query()->withoutGlobalScopes()->findOrFail($records['voucher']);

        return [
            'voucher' => [$voucher->balance, $voucher->status instanceof VoucherStatus ? $voucher->status->value : $voucher->status],
            'transactions' => VoucherTransaction::query()->withoutGlobalScopes()->where('voucher_id', $voucher->id)->count(),
            'customer' => Customer::query()->withoutGlobalScopes()->findOrFail($records['customer'])->only(['first_name', 'last_name', 'email']),
            'user' => User::query()->findOrFail($records['user'])->only(['name', 'status', 'role_id']),
            'device' => Device::query()->withoutGlobalScopes()->findOrFail($records['device'])->only(['name', 'status']),
            'card' => Card::query()->withoutGlobalScopes()->where('card_number', $records['card'])->value('state'),
            'connection' => PartnerConnection::query()->withoutGlobalScopes()->findOrFail($records['connection'])->status,
            'code' => PartnerLinkCode::query()->withoutGlobalScopes()->findOrFail($records['code'])->expires_at->toIso8601String(),
        ];
    }

    /** A body that passes most validation, so a missing tenant check is not hidden behind a 422. */
    private function anyBody(): array
    {
        return [
            'reason' => 'Prüfung', 'amount' => 100, 'name' => 'Neu', 'note' => 'x', 'status' => 'active',
            'presentment_id' => (string) Str::uuid(), 'payment' => ['method' => 'cash'], 'enabled' => true,
        ];
    }

    /** @return array<string, mixed> */
    private function nested(int $depth): array
    {
        $value = ['leaf' => 1];
        for ($i = 0; $i < $depth; $i++) {
            $value = ['n' => $value];
        }

        return $value;
    }

    /** @return array<string, array{string, RoutingRoute}> */
    private function apiRoutes(bool $includePartner = false): array
    {
        $routes = [];
        foreach (Route::getRoutes() as $route) {
            $uri = $route->uri();
            if (! str_starts_with($uri, 'api/v1') && ! ($includePartner && str_starts_with($uri, 'api/partner/v1'))) {
                continue;
            }
            foreach ($route->methods() as $method) {
                if (! in_array($method, ['HEAD', 'OPTIONS'], true)) {
                    $routes["{$method} {$uri}"] = [$method, $route];
                }
            }
        }

        return $routes;
    }
}
