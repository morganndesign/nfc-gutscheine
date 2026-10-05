<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Data\IssueVoucherData;
use App\Data\PaymentData;
use App\Enums\PaymentMethod;
use App\Enums\RoleSlug;
use App\Http\Middleware\BindRememberedSignIn;
use App\Models\LoginCode;
use App\Models\TrustedBrowser;
use App\Services\Vouchers\VoucherService;
use App\Support\Actor;
use App\Support\Heartbeat;
use Illuminate\Support\Str;
use Tests\TestCase;

/** Audit 2026-10-06, package 1: e-mail outage, e-mail changes, integration tokens and loyalty top-up alerts. */
final class SecurityHardeningTest extends TestCase
{
    public function test_production_with_a_log_mailer_reports_degraded_health(): void
    {
        Heartbeat::beat(Heartbeat::SCHEDULER);
        Heartbeat::beat(Heartbeat::WORKER);
        $this->get('/api/v1/health/operations')->assertOk();

        $this->app['env'] = 'production';
        config(['mail.default' => 'log']);
        $this->get('/api/v1/health/operations')->assertStatus(503)->assertSeeText('degraded');

        config(['mail.default' => 'smtp']);
        $this->get('/api/v1/health/operations')->assertOk();
    }

    public function test_the_server_command_hands_out_the_code_of_a_waiting_sign_in_when_email_is_down(): void
    {
        $owner = $this->staff($this->restaurant(), RoleSlug::Owner, ['email' => 'otto@example.com']);
        $this->artisan('auth:login-code', ['email' => 'otto@example.com'])->assertFailed();

        $login = (string) $this->postJson('/api/v1/auth/login', ['email' => 'otto@example.com', 'password' => 'Password123!'], ['Origin' => 'http://localhost:3000'])
            ->assertStatus(202)->json('data.login');
        $mailed = $this->lastLoginCode('otto@example.com');

        $this->artisan('auth:login-code', ['email' => 'otto@example.com'])->assertSuccessful()->expectsOutputToContain('Sign-in code for otto@example.com');
        $code = (string) LoginCode::query()->sole()->getKey();
        $this->assertSame($login, $code);
        $this->assertDatabaseHas('audit_logs', ['action' => 'auth.login_code_console', 'auditable_id' => $owner->id]);

        // The e-mailed code no longer works; only the printed one would.
        $this->postJson('/api/v1/auth/login/code', ['login' => $login, 'code' => $mailed], ['Origin' => 'http://localhost:3000'])->assertUnprocessable();
    }

    public function test_an_email_change_ends_every_sign_in_of_that_person(): void
    {
        $restaurant = $this->restaurant();
        $owner = $this->staff($restaurant, RoleSlug::Owner);
        $manager = $this->staff($restaurant, RoleSlug::Manager, ['email' => 'mia@example.com']);
        TrustedBrowser::query()->forceCreate(['user_id' => $manager->id, 'secret_hash' => str_repeat('a', 64), 'expires_at' => now()->addDays(10)]);
        $spa = ['Origin' => 'http://localhost:3000'];

        // The manager's open browser session (signed in a minute ago).
        $this->actingAs($manager, 'web')->withSession([BindRememberedSignIn::SIGNED_IN_AT => time() - 60]);
        $this->getJson('/api/v1/auth/me', $spa)->assertOk();

        $this->app['auth']->forgetGuards();
        $this->actingAs($owner, 'web');
        $this->patchJson("/api/v1/users/{$manager->id}", ['email' => 'mia.neu@example.com'], $spa)->assertOk();
        $this->assertNotNull($manager->refresh()->sessions_revoked_at);
        $this->assertSame(0, TrustedBrowser::query()->where('user_id', $manager->id)->count());

        $this->app['auth']->forgetGuards();
        $this->actingAs($manager, 'web')->withSession([BindRememberedSignIn::SIGNED_IN_AT => time() - 60]);
        $this->getJson('/api/v1/auth/me', $spa)->assertUnauthorized();

        // Signing in again works.
        $this->app['auth']->forgetGuards();
        $this->actingAs($manager->refresh(), 'web')->withSession([BindRememberedSignIn::SIGNED_IN_AT => time() + 1]);
        $this->getJson('/api/v1/auth/me', $spa)->assertOk();
    }

    public function test_changing_ones_own_email_needs_the_current_password(): void
    {
        $owner = $this->staff($this->restaurant(), RoleSlug::Owner, ['email' => 'otto@example.com']);
        $this->actingAs($owner);

        $this->patchJson("/api/v1/users/{$owner->id}", ['email' => 'evil@example.com'])->assertUnprocessable()->assertJsonValidationErrors('current_password');
        $this->patchJson("/api/v1/users/{$owner->id}", ['email' => 'evil@example.com', 'current_password' => 'wrong'])->assertUnprocessable();
        $this->assertSame('otto@example.com', $owner->refresh()->email);

        $this->patchJson("/api/v1/users/{$owner->id}", ['email' => 'otto.neu@example.com', 'current_password' => 'Password123!'])->assertOk();
        // The name alone needs no password.
        $this->patchJson("/api/v1/users/{$owner->id}", ['name' => 'Otto N.'])->assertOk();
    }

    public function test_integration_tokens_never_sell_give_loyalty_refund_or_manage_people(): void
    {
        $this->actingAsStaff($this->restaurant(), RoleSlug::Owner);
        foreach (['vouchers.sell', 'vouchers.sell_complimentary', 'vouchers.refund', 'users.manage', 'api_tokens.manage'] as $ability) {
            $this->postJson('/api/v1/api-tokens', ['name' => 'POS', 'abilities' => ['vouchers.redeem', $ability]])
                ->assertUnprocessable()->assertJsonValidationErrors('abilities.1');
        }
        $this->postJson('/api/v1/api-tokens', ['name' => 'POS', 'abilities' => ['vouchers.redeem', 'vouchers.view', 'vouchers.export', 'transactions.view', 'transactions.export']])
            ->assertCreated();
    }

    public function test_many_loyalty_top_ups_by_one_person_raise_an_alert(): void
    {
        $restaurant = $this->restaurant();
        $owner = $this->staff($restaurant, RoleSlug::Owner);
        $sale = $this->asTenant($restaurant, fn () => app(VoucherService::class)->sell(new Actor($owner), new IssueVoucherData(
            value: 1000, payment: new PaymentData(PaymentMethod::Complimentary, reason: 'Regular'), idempotencyKey: (string) Str::uuid(),
        )));
        $this->actingAs($owner);
        for ($i = 0; $i < 5; $i++) {
            $this->postJson("/api/v1/vouchers/{$sale->voucher->id}/reloads", ['amount' => 500, 'payment' => ['method' => 'complimentary', 'reason' => 'Stammgast']], $this->idempotency())
                ->assertCreated();
        }

        $this->artisan('giftcard:monitor-security-events')->assertSuccessful();
        $this->assertDatabaseHas('security_alerts', ['rule' => 'money.loyalty_topups', 'subject' => 'user:'.$owner->id]);
    }
}
