<?php

declare(strict_types=1);

namespace Tests\Probe;

use App\Enums\RoleSlug;
use App\Exceptions\Domain\AccountLockedException;
use App\Services\Auth\CredentialVerifier;
use App\Services\Users\UserService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

final class S4S6AuthTest extends TestCase
{
    public function test_S4_lockout_mechanics(): void
    {
        config(['giftcard.security.login_lockout_threshold' => 10]);
        $restaurant = $this->restaurant();
        $user = $this->staff($restaurant, RoleSlug::Waiter, ['email' => 'victim@bellavista.test', 'password' => bcrypt('Password123!')]);
        $verifier = app(CredentialVerifier::class);
        $req = Request::create('/api/v1/auth/login', 'POST', server: ['REMOTE_ADDR' => '127.0.0.1']);

        // 10 wrong-password attempts (verify() throws each time)
        $thrown = [];
        for ($i = 1; $i <= 10; $i++) {
            try { $verifier->verify($req, 'victim@bellavista.test', 'wrong'); }
            catch (\Throwable $e) { $thrown[$i] = class_basename($e); }
        }
        fwrite(STDERR, "\n[S4] 10 wrong-pw -> ".implode(',', array_unique($thrown))."\n");

        // Correct password now -> should be AccountLockedException (423)
        $lockedType = null;
        try { $verifier->verify($req, 'victim@bellavista.test', 'Password123!'); }
        catch (\Throwable $e) { $lockedType = class_basename($e); }
        fwrite(STDERR, "[S4] CORRECT password while locked -> ".$lockedType." (status ".(new AccountLockedException(60))->status().")\n");
        $this->assertSame('AccountLockedException', $lockedType);

        // Unknown e-mail: never locks, generic ValidationException (422)
        $unknownType = null;
        for ($i = 1; $i <= 15; $i++) {
            try { $verifier->verify($req, 'ghost@nowhere.test', 'wrong'); }
            catch (\Throwable $e) { $unknownType = class_basename($e); }
        }
        fwrite(STDERR, "[S4] unknown e-mail x15 -> ".$unknownType." (locked-known=423 vs unknown=422 => account enumeration)\n");
        $this->assertSame('ValidationException', $unknownType);
    }

    public function test_S5_reset_password_enumeration(): void
    {
        $restaurant = $this->restaurant();
        $this->staff($restaurant, RoleSlug::Waiter, ['email' => 'real@bellavista.test']);

        RateLimiter::clear('127.0.0.1');
        $r1 = $this->postJson('/api/v1/auth/reset-password', ['email' => 'ghost@nowhere.test', 'token' => 'x', 'password' => 'NewPassw0rd!!', 'password_confirmation' => 'NewPassw0rd!!']);
        $r2 = $this->postJson('/api/v1/auth/reset-password', ['email' => 'real@bellavista.test', 'token' => 'invalid-token', 'password' => 'NewPassw0rd!!', 'password_confirmation' => 'NewPassw0rd!!']);
        fwrite(STDERR, "\n[S5] unknown-email  -> ".$r1->getStatusCode()." errors=".json_encode($r1->json('errors'))."\n");
        fwrite(STDERR, "[S5] known+badtoken -> ".$r2->getStatusCode()." errors=".json_encode($r2->json('errors'))."\n");
        $this->assertTrue(true);
    }

    public function test_S6_forgot_password_overwrites_invitation_token(): void
    {
        $restaurant = $this->restaurant();
        $invited = $this->staff($restaurant, RoleSlug::Waiter, ['email' => 'invitee@bellavista.test', 'password' => bcrypt('temp')]);
        $invited->forceFill(['password_changed_at' => null, 'last_login_at' => null])->save();
        fwrite(STDERR, "\n[S6] isPendingInvitation=".var_export(UserService::isPendingInvitation($invited->fresh()), true)."\n");

        $invitationToken = Password::broker('invitations')->createToken($invited);
        $validBefore = Password::broker('invitations')->tokenExists($invited->fresh(), $invitationToken);
        fwrite(STDERR, "[S6] invitation token valid BEFORE forgot-password = ".var_export($validBefore, true)."\n");

        RateLimiter::clear('127.0.0.1');
        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'invitee@bellavista.test'])->assertOk();

        $validAfter = Password::broker('invitations')->tokenExists($invited->fresh(), $invitationToken);
        fwrite(STDERR, "[S6] invitation token valid AFTER anon forgot-password = ".var_export($validAfter, true)." (false => onboarding link broken)\n");
        $this->assertTrue($validBefore);
        $this->assertFalse($validAfter);
    }
}
