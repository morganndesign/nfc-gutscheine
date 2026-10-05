<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Models\PersonalAccessToken;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * Waiter app sign-in with the e-mailed code (decision 2026-10-06): every app sign-in needs the code, from the
 * phone that asked for it, and the token lasts only until the app is updated. Audit S1/S3.
 */
final class AppSignInCodeTest extends TestCase
{
    private const DEVICE = 'b1a2c3d4-e5f6-4711-8899-aabbccddeeff';

    private const APP = 'GiftCardWaiter/2.0.20 (iOS 18; iPhone)';

    private Restaurant $restaurant;

    private User $owner;

    protected function setUp(): void
    {
        parent::setUp();
        $this->restaurant = $this->restaurant();
        $this->owner = $this->staff($this->restaurant, RoleSlug::Owner, ['email' => 'otto@example.com', 'locale' => 'de']);
    }

    /** @return array<string, string> */
    private function body(array $overrides = []): array
    {
        return array_merge(['email' => 'otto@example.com', 'password' => 'Password123!', 'device_id' => self::DEVICE, 'device_name' => 'iPhone', 'platform' => 'ios'], $overrides);
    }

    private function password(array $overrides = []): TestResponse
    {
        return $this->withHeaders(['User-Agent' => self::APP])->postJson('/api/v1/auth/token', $this->body($overrides));
    }

    private function code(string $login, string $code, array $overrides = []): TestResponse
    {
        return $this->withHeaders(['User-Agent' => self::APP])->postJson('/api/v1/auth/token/code', ['login' => $login, 'code' => $code] + $this->body($overrides));
    }

    private function bearer(string $token, string $userAgent = self::APP): self
    {
        $this->app['auth']->forgetGuards();

        return $this->withHeaders(['Authorization' => 'Bearer '.$token, 'X-Device-Id' => self::DEVICE, 'User-Agent' => $userAgent]);
    }

    public function test_the_password_alone_gives_no_token_the_code_from_the_email_does(): void
    {
        $login = (string) $this->password()->assertStatus(202)
            ->assertJsonPath('data.code_required', true)
            ->assertJsonPath('data.email', 'o•••@example.com')
            ->assertJsonMissingPath('data.token')
            ->json('data.login');
        $this->assertSame(0, PersonalAccessToken::query()->count());

        $code = $this->lastLoginCode('otto@example.com');
        $mail = app('mailer')->getSymfonyTransport()->messages()->last()->getOriginalMessage();
        $this->assertStringContainsString('in der App GiftCard Waiter ein', (string) $mail->getTextBody());
        $this->assertStringContainsString('bis die App aktualisiert wird', (string) $mail->getTextBody());

        $token = (string) $this->code($login, $code)->assertCreated()->assertJsonPath('data.user.id', $this->owner->id)->json('data.token');
        $this->assertSame('2.0.20', PersonalAccessToken::query()->sole()->app_version);
        $this->bearer($token)->getJson('/api/v1/auth/me')->assertOk();

        // Single use.
        $this->code($login, $code)->assertUnprocessable()->assertJsonPath('code', 'LOGIN_CODE_REJECTED')->assertJsonPath('context.reason', 'expired');
    }

    public function test_the_code_works_only_on_the_phone_that_asked_and_never_in_the_dashboard(): void
    {
        $login = (string) $this->password()->assertStatus(202)->json('data.login');
        $code = $this->lastLoginCode('otto@example.com');

        $this->code($login, $code, ['device_id' => 'ffffffff-e5f6-4711-8899-aabbccddeeff'])->assertUnprocessable()->assertJsonPath('context.reason', 'expired');
        $this->postJson('/api/v1/auth/login/code', ['login' => $login, 'code' => $code], ['Origin' => 'http://localhost:3000'])->assertUnprocessable();
        $this->assertSame(0, PersonalAccessToken::query()->count());

        // A dashboard sign-in's code does not issue an app token either.
        $web = (string) $this->postJson('/api/v1/auth/login', ['email' => 'otto@example.com', 'password' => 'Password123!'], ['Origin' => 'http://localhost:3000'])->assertStatus(202)->json('data.login');
        $this->code($web, $this->lastLoginCode('otto@example.com'))->assertUnprocessable();
        $this->assertSame(0, PersonalAccessToken::query()->count());
    }

    public function test_a_new_code_for_the_app_waits_30_seconds(): void
    {
        $login = (string) $this->password()->assertStatus(202)->json('data.login');
        $this->postJson('/api/v1/auth/token/code/resend', ['login' => $login])->assertUnprocessable()->assertJsonPath('context.reason', 'wait');
        $this->travel(31)->seconds();
        $this->postJson('/api/v1/auth/token/code/resend', ['login' => $login])->assertOk();
        $this->code($login, $this->lastLoginCode('otto@example.com'))->assertCreated();
    }

    public function test_who_may_not_use_the_app_gets_no_code(): void
    {
        $this->owner->restaurant()->dissociate()->save();
        $sent = count(app('mailer')->getSymfonyTransport()->messages());

        $this->password()->assertForbidden();
        $this->assertSame($sent, count(app('mailer')->getSymfonyTransport()->messages()));
    }

    public function test_an_updated_app_signs_in_again(): void
    {
        $token = (string) $this->appSignIn($this->body(), self::APP)->assertCreated()->json('data.token');
        $this->bearer($token)->getJson('/api/v1/auth/me')->assertOk();

        $this->bearer($token, 'GiftCardWaiter/2.0.21 (iOS 18; iPhone)')->getJson('/api/v1/auth/me')
            ->assertUnauthorized()->assertJsonPath('code', 'APP_UPDATED');
        // The token is gone for good, also for the old version.
        $this->bearer($token)->getJson('/api/v1/auth/me')->assertUnauthorized();
        $this->assertNotNull(PersonalAccessToken::query()->sole()->revoked_at);

        $this->flushHeaders();
        $this->appSignIn($this->body(), 'GiftCardWaiter/2.0.21 (iOS 18; iPhone)')->assertCreated();
    }

    public function test_a_token_from_before_the_codes_signs_in_again(): void
    {
        $token = (string) $this->appSignIn($this->body(), self::APP)->assertCreated()->json('data.token');
        PersonalAccessToken::query()->update(['app_version' => null]);

        $this->bearer($token)->getJson('/api/v1/auth/me')->assertUnauthorized()->assertJsonPath('code', 'APP_UPDATED');
    }

    public function test_fifteen_wrong_codes_within_an_hour_lock_the_account_and_raise_an_alert(): void
    {
        $reasons = [];
        for ($round = 0; $round < 3; $round++) {
            $login = (string) $this->password()->assertStatus(202)->json('data.login');
            for ($i = 0; $i < 5; $i++) {
                $reasons[] = $this->code($login, '000000')->assertUnprocessable()->json('context.reason');
            }
        }
        $this->assertSame(['wrong', 'wrong', 'wrong', 'wrong', 'expired'], array_slice($reasons, 0, 5));
        $this->assertSame('locked', end($reasons));
        $this->owner->refresh();
        $this->assertTrue($this->owner->isLocked());
        $this->assertTrue($this->owner->locked_until->greaterThan(Carbon::now()->addMinutes(55)));
        $this->assertDatabaseHas('security_events', ['type' => 'auth.sign_in', 'reason' => 'code_lockout']);

        // Locked: the right password does not even send a code.
        $this->password()->assertStatus(422);

        $this->artisan('giftcard:monitor-security-events')->assertSuccessful();
        $this->assertDatabaseHas('security_alerts', ['rule' => 'auth.code_guessing', 'subject' => 'user:'.$this->owner->id]);
    }
}
