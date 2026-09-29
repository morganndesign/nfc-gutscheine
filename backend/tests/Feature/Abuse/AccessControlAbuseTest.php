<?php

declare(strict_types=1);

namespace Tests\Feature\Abuse;

use App\Enums\RoleSlug;
use App\Jobs\SendPasswordResetLink;
use App\Models\Device;
use App\Models\PersonalAccessToken;
use App\Models\User;
use App\Notifications\StaffInvitation;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\Queue;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * The authentication findings of the audit (S1–S6, F3, L1) tried from the attacker's side.
 */
final class AccessControlAbuseTest extends TestCase
{
    private const DEVICE = 'b9f1c2d3-4e5f-4a6b-8c7d-9e0f1a2b3c4d';

    /** The dashboard's origin: Sanctum treats these requests as browser sessions. */
    private const SPA = ['Origin' => 'http://localhost:3000'];

    /** S1: a remembered sign-in is refused on a new device id and after the device was revoked. */
    public function test_a_remember_me_cookie_only_works_on_a_known_active_device(): void
    {
        $restaurant = $this->restaurant();
        $manager = $this->staff($restaurant, RoleSlug::Manager);

        // First sign-in with "remember me" on a known device.
        $this->withHeaders(self::SPA + ['X-Device-Id' => self::DEVICE])->postJson('/api/v1/auth/login', ['email' => $manager->email, 'password' => 'Password123!', 'remember' => true])->assertOk();
        $this->withHeaders(self::SPA + ['X-Device-Id' => self::DEVICE])->getJson('/api/v1/devices/current')->assertOk();
        $recaller = $manager->id.'|'.$manager->refresh()->getRememberToken().'|'.$manager->getAuthPassword();

        // The session is gone and only the recaller cookie remains: on the known device it works …
        $this->restoreFromRecaller($recaller);
        $this->withHeaders(self::SPA + ['X-Device-Id' => self::DEVICE])->getJson('/api/v1/auth/me')->assertOk();

        // … with a fresh device id it is refused (and the refused cookie is dead from then on).
        $this->restoreFromRecaller($recaller);
        $this->withHeaders(self::SPA + ['X-Device-Id' => 'ffffffff-0000-4000-8000-000000000000'])->getJson('/api/v1/auth/me')
            ->assertUnauthorized();
        $this->restoreFromRecaller($recaller);
        $this->withHeaders(self::SPA + ['X-Device-Id' => self::DEVICE])->getJson('/api/v1/auth/me')->assertUnauthorized();

        // Signed in again with "remember me" on the known device …
        $this->app['auth']->forgetGuards();
        $this->flushSession();
        $this->withHeaders(self::SPA + ['X-Device-Id' => self::DEVICE])->postJson('/api/v1/auth/login', ['email' => $manager->email, 'password' => 'Password123!', 'remember' => true])->assertOk();
        $recaller = $manager->id.'|'.$manager->refresh()->getRememberToken().'|'.$manager->getAuthPassword();

        // … until the device is revoked: the remember token is rotated, the old cookie is dead everywhere.
        $device = Device::query()->withoutGlobalScopes()->sole();
        Sanctum::actingAs($this->staff($restaurant, RoleSlug::Owner), ['*']);
        $this->postJson("/api/v1/devices/{$device->id}/revoke")->assertOk();
        $this->assertNotSame(explode('|', $recaller)[1], $manager->refresh()->getRememberToken());

        $this->restoreFromRecaller($recaller);
        $this->withHeaders(self::SPA + ['X-Device-Id' => self::DEVICE])->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    /** S2: platform administrators have no tokens; they can list and revoke every restaurant's tokens. */
    public function test_platform_admins_cannot_hold_tokens_but_can_revoke_any(): void
    {
        $admin = User::factory()->platformAdmin()->create();
        $restaurant = $this->restaurant();
        $owner = $this->staff($restaurant, RoleSlug::Owner);

        Sanctum::actingAs($admin, ['*']);
        $this->postJson('/api/v1/api-tokens', ['name' => 'God mode', 'abilities' => ['platform.restaurants.manage']])->assertForbidden();

        // A token that somehow exists for an administrator does not authenticate.
        $plain = $admin->createToken('legacy', ['*'])->plainTextToken;
        $this->app['auth']->forgetGuards();
        $this->withToken($plain)->getJson('/api/v1/admin/stats')->assertUnauthorized();

        Sanctum::actingAs($owner, ['*']);
        $created = $this->postJson('/api/v1/api-tokens', ['name' => 'POS', 'abilities' => ['vouchers.redeem']])->assertCreated();

        $this->app['auth']->forgetGuards();
        Sanctum::actingAs($admin, ['*']);
        $this->getJson("/api/v1/admin/api-tokens?active=1&restaurant_id={$restaurant->id}")->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $created->json('data.id'))
            ->assertJsonPath('data.0.restaurant.id', $restaurant->id)
            ->assertJsonPath('data.0.kind', 'integration');
        $this->postJson("/api/v1/admin/api-tokens/{$created->json('data.id')}/revoke")->assertOk()->assertJsonPath('data.active', false);

        $this->app['auth']->forgetGuards();
        $this->withToken((string) $created->json('plain_text_token'))->postJson('/api/v1/presentments', ['purpose' => 'spend', 'method' => 'printable_qr', 'credential' => 'x'])
            ->assertUnauthorized();
    }

    /** S3: resetting or changing the password revokes every token and remembered browser. */
    public function test_a_password_reset_locks_every_token_out(): void
    {
        $restaurant = $this->restaurant();
        $owner = $this->staff($restaurant, RoleSlug::Owner, ['email' => 'owner@example.com', 'last_login_at' => now(), 'password_changed_at' => now()]);
        $integration = $owner->createToken('POS', ['vouchers.redeem']);
        $rememberBefore = $owner->getRememberToken();

        $token = Password::broker('users')->createToken($owner);
        $this->postJson('/api/v1/auth/reset-password', ['email' => 'owner@example.com', 'token' => $token, 'password' => 'NewPassword123', 'password_confirmation' => 'NewPassword123'])
            ->assertOk();

        $this->assertNotNull(PersonalAccessToken::query()->findOrFail($integration->accessToken->getKey())->revoked_at);
        $this->assertNotSame($rememberBefore, $owner->refresh()->getRememberToken());
        $this->assertDatabaseHas('audit_logs', ['action' => 'auth.access_revoked', 'auditable_id' => $owner->id]);

        $this->app['auth']->forgetGuards();
        $this->withToken($integration->plainTextToken)->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    public function test_a_password_change_revokes_tokens(): void
    {
        $restaurant = $this->restaurant();
        $owner = $this->staff($restaurant, RoleSlug::Owner);
        $integration = $owner->createToken('POS', ['vouchers.redeem']);

        Sanctum::actingAs($owner, ['*']);
        $this->putJson('/api/v1/auth/password', ['current_password' => 'Password123!', 'password' => 'Another123456', 'password_confirmation' => 'Another123456'])->assertOk();

        $this->assertNotNull(PersonalAccessToken::query()->findOrFail($integration->accessToken->getKey())->revoked_at);
    }

    /** S5: the reset endpoint answers identically for unknown addresses and wrong tokens. */
    public function test_reset_answers_do_not_reveal_accounts(): void
    {
        $restaurant = $this->restaurant();
        $this->staff($restaurant, RoleSlug::Waiter, ['email' => 'real@example.com']);
        $body = ['token' => 'invalid-token', 'password' => 'NewPassw0rd!!', 'password_confirmation' => 'NewPassw0rd!!'];

        $unknown = $this->postJson('/api/v1/auth/reset-password', ['email' => 'ghost@example.com'] + $body)->assertStatus(422);
        $known = $this->postJson('/api/v1/auth/reset-password', ['email' => 'real@example.com'] + $body)->assertStatus(422);
        $this->assertSame($unknown->json(), $known->json());

        Queue::fake();
        $a = $this->postJson('/api/v1/auth/forgot-password', ['email' => 'ghost@example.com'])->assertOk();
        $b = $this->postJson('/api/v1/auth/forgot-password', ['email' => 'real@example.com'])->assertOk();
        $this->assertSame($a->json(), $b->json());
        Queue::assertPushed(SendPasswordResetLink::class, 2);
    }

    /** S6: "forgot password" never touches a pending invitation. */
    public function test_forgot_password_cannot_invalidate_an_invitation(): void
    {
        Notification::fake();
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $this->postJson('/api/v1/users', ['name' => 'New Waiter', 'email' => 'new@example.com', 'role' => 'waiter'])->assertCreated();
        $invited = User::query()->where('email', 'new@example.com')->sole();

        $invitation = null;
        Notification::assertSentTo($invited, StaffInvitation::class, static function (StaffInvitation $n) use (&$invitation): bool {
            $invitation = $n->token();

            return true;
        });

        $this->app['auth']->forgetGuards();
        Auth::forgetUser();
        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'new@example.com'])->assertOk();

        Notification::assertNotSentTo($invited, ResetPassword::class);
        $this->assertTrue(Password::broker('invitations')->tokenExists($invited, (string) $invitation));
        $this->assertDatabaseCount('password_reset_tokens', 0);
    }

    /** F3b and L1: a mail outage never turns "forgot password" into an error; links carry the token in the fragment. */
    public function test_forgot_password_survives_a_mail_outage_and_keeps_the_token_out_of_urls_sent_to_servers(): void
    {
        $restaurant = $this->restaurant();
        $user = $this->staff($restaurant, RoleSlug::Manager, ['email' => 'mia@example.com', 'last_login_at' => now(), 'password_changed_at' => now()]);

        Mail::shouldReceive('send')->andThrow(new \RuntimeException('Connection timed out'));
        Queue::fake();
        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'mia@example.com'])->assertOk();
        Queue::assertPushed(SendPasswordResetLink::class);

        Notification::fake();
        (new SendPasswordResetLink('mia@example.com'))->handle();
        Notification::assertSentTo($user, ResetPassword::class, static function (ResetPassword $n) use ($user): bool {
            $url = (string) $n->toMail($user)->actionUrl;

            return str_contains($url, '/reset-password#') && ! str_contains((string) parse_url($url, PHP_URL_QUERY), 'token');
        });
    }

    private function restoreFromRecaller(string $recaller): void
    {
        $this->app['auth']->forgetGuards();
        Auth::forgetUser();
        $this->flushSession();
        $this->withCredentials()->withCookie(Auth::guard('web')->getRecallerName(), $recaller);
    }
}
