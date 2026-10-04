<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Models\LoginCode;
use App\Models\TrustedBrowser;
use App\Models\User;
use App\Services\Auth\AccessRevoker;
use App\Services\Auth\LoginCodeService;
use App\Support\Actor;
use Illuminate\Support\Carbon;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/** Dashboard sign-in with a 6-digit code by e-mail; a confirmed browser is trusted for 15 days (decision 2026-10-05). */
final class LoginCodeTest extends TestCase
{
    private const SPA = ['Origin' => 'http://localhost:3000'];

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = $this->staff($this->restaurant(), RoleSlug::Owner, ['email' => 'anna@example.com', 'locale' => 'de']);
    }

    private function password(?string $cookie = null): TestResponse
    {
        $this->app['auth']->forgetGuards();
        $request = $cookie !== null ? $this->withCredentials()->withCookie(LoginCodeService::COOKIE, $cookie) : $this;

        return $request->postJson('/api/v1/auth/login', ['email' => 'anna@example.com', 'password' => 'Password123!'], self::SPA);
    }

    private function code(string $login, string $code): TestResponse
    {
        return $this->postJson('/api/v1/auth/login/code', ['login' => $login, 'code' => $code], self::SPA);
    }

    private function sentCount(): int
    {
        return count(app('mailer')->getSymfonyTransport()->messages());
    }

    public function test_the_password_alone_does_not_sign_in_the_code_from_the_email_does(): void
    {
        $first = $this->password()->assertStatus(202)
            ->assertJsonPath('data.code_required', true)
            ->assertJsonPath('data.email', 'a•••@example.com')
            ->assertJsonPath('data.expires_in', 600);
        $this->getJson('/api/v1/auth/me', self::SPA)->assertUnauthorized();

        $code = $this->lastLoginCode('anna@example.com');
        $this->assertMatchesRegularExpression('/^\d{6}$/', $code);
        $mail = app('mailer')->getSymfonyTransport()->messages()->last()->getOriginalMessage();
        $this->assertSame("{$code} ist Ihr Anmeldecode für GiftCard Pro", $mail->getSubject());
        // Only a keyed hash is stored.
        $this->assertStringNotContainsString($code, json_encode(LoginCode::query()->get()->toArray(), JSON_THROW_ON_ERROR));

        $this->code((string) $first->json('data.login'), substr($code, 0, 3).' '.substr($code, 3))
            ->assertOk()->assertJsonPath('data.email', 'anna@example.com')
            ->assertCookie(LoginCodeService::COOKIE);
        $this->getJson('/api/v1/auth/me', self::SPA)->assertOk();
        $this->assertDatabaseHas('audit_logs', ['action' => 'auth.login', 'user_id' => $this->user->id]);

        // Single use.
        $this->code((string) $first->json('data.login'), $code)->assertUnprocessable();
    }

    public function test_a_trusted_browser_signs_in_with_the_password_for_15_days(): void
    {
        $first = $this->password();
        $cookie = $this->code((string) $first->json('data.login'), $this->lastLoginCode('anna@example.com'))->getCookie(LoginCodeService::COOKIE)?->getValue();
        $this->assertIsString($cookie);
        $sent = $this->sentCount();

        $this->password($cookie)->assertOk()->assertJsonPath('data.email', 'anna@example.com');
        $this->assertSame($sent, $this->sentCount(), 'no code for a trusted browser');

        $this->travel(16)->days();
        $this->password($cookie)->assertStatus(202);
    }

    public function test_a_trusted_browser_of_someone_else_or_a_forged_cookie_does_not_count(): void
    {
        $other = $this->staff($this->user->restaurant, RoleSlug::Manager, ['email' => 'ben@example.com']);
        $login = $this->postJson('/api/v1/auth/login', ['email' => 'ben@example.com', 'password' => 'Password123!'], self::SPA);
        $cookie = $this->code((string) $login->json('data.login'), $this->lastLoginCode('ben@example.com'))->getCookie(LoginCodeService::COOKIE)?->getValue();
        $this->assertSame(1, TrustedBrowser::query()->where('user_id', $other->id)->count());

        $this->password($cookie)->assertStatus(202);
        [$id] = explode('|', (string) $cookie);
        $this->password($id.'|forged-secret')->assertStatus(202);
        $this->password('not-a-cookie')->assertStatus(202);
    }

    public function test_five_wrong_codes_end_the_sign_in(): void
    {
        $login = (string) $this->password()->json('data.login');
        $code = $this->lastLoginCode('anna@example.com');
        $wrong = $code === '000000' ? '111111' : '000000';
        for ($i = 0; $i < 4; $i++) {
            $this->code($login, $wrong)->assertUnprocessable()->assertJsonValidationErrors('code');
        }
        $this->code($login, $wrong)->assertUnprocessable();
        $this->code($login, $code)->assertUnprocessable();
        $this->getJson('/api/v1/auth/me', self::SPA)->assertUnauthorized();
        $this->assertDatabaseHas('security_events', ['type' => 'auth.sign_in', 'reason' => 'code_attempts_exceeded']);
    }

    public function test_a_code_expires_after_ten_minutes(): void
    {
        $login = (string) $this->password()->json('data.login');
        $code = $this->lastLoginCode('anna@example.com');
        $this->travel(11)->minutes();
        $this->code($login, $code)->assertUnprocessable();
    }

    public function test_a_new_code_waits_30_seconds_replaces_the_old_one_and_is_limited(): void
    {
        $login = (string) $this->password()->json('data.login');
        $old = $this->lastLoginCode('anna@example.com');
        $this->postJson('/api/v1/auth/login/code/resend', ['login' => $login], self::SPA)->assertUnprocessable();

        $this->travel(31)->seconds();
        $this->postJson('/api/v1/auth/login/code/resend', ['login' => $login], self::SPA)->assertOk();
        $new = $this->lastLoginCode('anna@example.com');
        if ($new !== $old) {
            $this->code($login, $old)->assertUnprocessable();
        }
        $this->code($login, $new)->assertOk();

        // At most 4 e-mails per sign-in.
        $this->app['auth']->forgetGuards();
        $again = (string) $this->password()->json('data.login');
        for ($i = 0; $i < 3; $i++) {
            $this->travel(31)->seconds();
            $this->postJson('/api/v1/auth/login/code/resend', ['login' => $again], self::SPA)->assertOk();
        }
        $this->travel(31)->seconds();
        $this->postJson('/api/v1/auth/login/code/resend', ['login' => $again], self::SPA)->assertUnprocessable();
    }

    public function test_a_new_sign_in_kills_the_earlier_code(): void
    {
        $first = (string) $this->password()->json('data.login');
        $code = $this->lastLoginCode('anna@example.com');
        $this->password();
        $this->code($first, $code)->assertUnprocessable();
    }

    public function test_signing_out_everywhere_forgets_every_trusted_browser(): void
    {
        $first = $this->password();
        $cookie = $this->code((string) $first->json('data.login'), $this->lastLoginCode('anna@example.com'))->getCookie(LoginCodeService::COOKIE)?->getValue();

        app(AccessRevoker::class)->revokeEverywhere($this->user, new Actor($this->user), 'password_reset');

        $this->assertSame(0, TrustedBrowser::query()->count());
        $this->password($cookie)->assertStatus(202);
    }

    public function test_the_waiter_app_signs_in_without_a_code(): void
    {
        $this->staff($this->user->restaurant, RoleSlug::Waiter, ['email' => 'kellner@example.com']);
        $sent = $this->sentCount();
        $this->postJson('/api/v1/auth/token', [
            'email' => 'kellner@example.com', 'password' => 'Password123!',
            'device_id' => '6f0f3c1e-2b5d-4c7a-9e1f-0a1b2c3d4e5f', 'device_name' => 'Kasse', 'platform' => 'android',
        ])->assertCreated();
        $this->assertSame($sent, $this->sentCount());
    }

    public function test_the_code_e_mail_follows_the_users_language(): void
    {
        $this->user->forceFill(['locale' => 'bs'])->save();
        $this->password()->assertStatus(202);
        $mail = app('mailer')->getSymfonyTransport()->messages()->last()->getOriginalMessage();
        $this->assertStringEndsWith('je vaš kod za prijavu u GiftCard Pro', $mail->getSubject());
        Carbon::setTestNow();
    }
}
