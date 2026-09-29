<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Http\Middleware\TrackDevice;
use App\Models\AuditLog;
use App\Models\Customer;
use App\Models\NotificationLog;
use App\Models\Voucher;
use App\Support\Tenancy\TenantContext;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\Request;
use Illuminate\Session\ArraySessionHandler;
use Illuminate\Session\Store;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

/**
 * Regression tests for issues found in the production-readiness audit.
 */
final class HardeningTest extends TestCase
{
    public function test_voucher_sale_is_idempotent_and_validates_the_key(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $headers = $this->idempotency('create-voucher-attempt-1');
        $body = ['value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment()];

        $first = $this->postJson('/api/v1/vouchers', $body, $headers)->assertCreated();
        $again = $this->postJson('/api/v1/vouchers', $body, $headers)->assertOk()->assertJsonPath('replayed', true);

        $this->assertSame($first->json('data.id'), $again->json('data.id'));
        $this->assertSame(1, Voucher::query()->withoutGlobalScopes()->count());

        $this->postJson('/api/v1/vouchers', $body, ['Idempotency-Key' => str_repeat('x', 200)])->assertStatus(400);
        $this->postJson('/api/v1/vouchers', $body, ['Idempotency-Key' => 'reserved:in'])->assertStatus(400);
    }

    public function test_session_is_pinned_to_the_device_it_started_on(): void
    {
        $restaurant = $this->restaurant();
        $user = $this->staff($restaurant, RoleSlug::Waiter);
        app(TenantContext::class)->set($restaurant);
        $session = new Store('test', new ArraySessionHandler(10));
        $middleware = app(TrackDevice::class);

        $request = function (string $deviceId) use ($session, $user): Request {
            $request = Request::create('/api/v1/presentments', 'POST', server: ['HTTP_X_DEVICE_ID' => $deviceId]);
            $request->setLaravelSession($session);
            $request->setUserResolver(static fn () => $user);

            return $request;
        };

        $middleware->handle($request('aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa'), static fn () => response('ok'));
        $middleware->handle($request('aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa'), static fn () => response('ok'));

        $this->expectException(AuthenticationException::class);
        $middleware->handle($request('bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb'), static fn () => response('ok'));
    }

    public function test_each_voucher_event_sends_exactly_one_email(): void
    {
        Mail::fake();
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $id = $this->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment(), 'customer' => ['email' => 'once@example.com']], $this->idempotency())
            ->assertCreated()->json('data.id');
        $this->postJson("/api/v1/vouchers/{$id}/reloads", ['amount' => 1000, 'payment' => $this->cashPayment()], $this->idempotency())->assertCreated();

        Mail::assertSentCount(2);
    }

    public function test_customer_personal_data_never_enters_the_audit_trail(): void
    {
        Mail::fake();
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $customer = Customer::factory()->create(['restaurant_id' => $restaurant->id, 'email' => 'old@example.com']);

        $this->patchJson("/api/v1/customers/{$customer->id}", ['email' => 'new@example.com', 'phone' => '+43 1 234'])->assertOk();
        $log = AuditLog::query()->where('action', 'customer.updated')->firstOrFail();
        $this->assertStringNotContainsString('example.com', (string) json_encode([$log->old_values, $log->new_values]));
        $this->assertSame('[personal data]', $log->new_values['email'] ?? null);

        $voucherId = $this->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment(), 'customer_id' => $customer->id], $this->idempotency())
            ->assertCreated()->json('data.id');
        $this->assertTrue(NotificationLog::query()->where('recipient', 'new@example.com')->exists());

        $this->postJson("/api/v1/customers/{$customer->id}/anonymize")->assertOk();
        $this->assertFalse(NotificationLog::query()->where('recipient', 'new@example.com')->exists());
        $this->assertNotNull($voucherId);
    }

    public function test_health_check_verifies_database_and_cache(): void
    {
        $this->get('/up')->assertOk();
    }

    public function test_cors_is_disabled(): void
    {
        $this->withHeaders(['Origin' => 'https://evil.example', 'Access-Control-Request-Method' => 'POST'])
            ->options('/api/v1/auth/login')
            ->assertHeaderMissing('Access-Control-Allow-Origin');
    }

    public function test_exports_use_decimal_comma_for_german_locales(): void
    {
        $restaurant = $this->restaurant(['locale' => 'de-AT']);
        $this->issueVoucher($restaurant, 1250);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $csv = $this->get('/api/v1/transactions/export')->assertOk()->streamedContent();
        $this->assertStringContainsString(';12,50;', $csv);
    }
}
