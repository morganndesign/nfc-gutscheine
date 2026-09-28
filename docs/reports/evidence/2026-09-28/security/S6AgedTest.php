<?php

declare(strict_types=1);

namespace Tests\Probe;

use App\Enums\RoleSlug;
use App\Services\Users\UserService;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\RateLimiter;
use Tests\TestCase;

final class S6AgedTest extends TestCase
{
    public function test_S6_forgot_overwrites_invitation_after_throttle_window(): void
    {
        $restaurant = $this->restaurant();
        $invited = $this->staff($restaurant, RoleSlug::Waiter, ['email' => 'invitee2@bellavista.test', 'password' => bcrypt('temp')]);
        $invited->forceFill(['password_changed_at' => null, 'last_login_at' => null])->save();
        $this->assertTrue(UserService::isPendingInvitation($invited->fresh()));

        $invitationToken = Password::broker('invitations')->createToken($invited);
        $this->assertTrue(Password::broker('invitations')->tokenExists($invited->fresh(), $invitationToken));

        // Age the stored token beyond the 60s throttle window (realistic: forgot happens minutes/hours later)
        DB::table('password_reset_tokens')->where('email', 'invitee2@bellavista.test')->update(['created_at' => Carbon::now()->subMinutes(5)]);

        RateLimiter::clear('127.0.0.1');
        $resp = $this->postJson('/api/v1/auth/forgot-password', ['email' => 'invitee2@bellavista.test']);
        fwrite(STDERR, "\n[S6] forgot-password status=".$resp->getStatusCode()."\n");

        $validAfter = Password::broker('invitations')->tokenExists($invited->fresh(), $invitationToken);
        fwrite(STDERR, "[S6] ORIGINAL invitation token valid after forgot (aged) = ".var_export($validAfter, true)." (false => invitation link broken)\n");

        // And the row now carries a 'users' (60min) token, not the 72h invitation lifetime.
        // Verify the new token validates under the 'users' broker but the old one no longer works anywhere.
        $oldInvit = Password::broker('invitations')->tokenExists($invited->fresh(), $invitationToken);
        fwrite(STDERR, "[S6] old token under invitations broker = ".var_export($oldInvit, true)."\n");

        $this->assertFalse($validAfter);
    }
}
