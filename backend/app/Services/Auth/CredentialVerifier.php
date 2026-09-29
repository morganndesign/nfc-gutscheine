<?php

declare(strict_types=1);

namespace App\Services\Auth;

use App\Enums\RoleSlug;
use App\Exceptions\Domain\AccountDeactivatedException;
use App\Exceptions\Domain\RestaurantSuspendedException;
use App\Models\User;
use App\Services\Audit\AuditLogger;
use App\Support\Actor;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Checks e-mail + password for every sign-in channel (web session and waiter app token) with the same
 * lockout, timing and account-state rules, so no channel is easier to attack than another.
 */
final class CredentialVerifier
{
    /** Pre-computed bcrypt hash used to keep timing identical for unknown e-mail addresses. */
    private const DUMMY_HASH = '$2y$12$wW.0dFZ1Hc2SUFVfXc/am.LR/cZrHgVhSSlWEILLPHenurYNk9JTO';

    public function __construct(private readonly AuditLogger $audit) {}

    /**
     * @param  bool  $deviceClient  The native waiter app gets 401 ACCOUNT_DEACTIVATED for a deactivated account
     *                              (the web app keeps its field error).
     */
    public function verify(Request $request, string $email, string $password, bool $deviceClient = false): User
    {
        /** @var User|null $user */
        $user = User::query()->with(['role', 'restaurant'])->where('email', Str::lower($email))->first();

        // Always hash, and answer a locked account exactly like a wrong password: neither the response nor its
        // timing may reveal whether the account exists, is locked, or whether a guess was right (audit S4).
        $valid = Hash::check($password, $user->password ?? self::DUMMY_HASH);

        if ($user !== null && $user->isLocked()) {
            $this->audit->log('auth.locked_attempt', $this->actor($request), $user, restaurantId: $user->restaurant_id);

            throw $this->failed();
        }

        if ($user === null || ! $valid) {
            if ($user !== null) {
                $this->registerFailure($user, $request);
            }

            throw $this->failed();
        }

        if (! $user->isActive()) {
            throw $deviceClient
                ? new AccountDeactivatedException
                : ValidationException::withMessages(['email' => 'This account has been deactivated.']);
        }

        if ($user->roleSlug() !== RoleSlug::PlatformAdmin && ($user->restaurant === null || ! $user->restaurant->isActive())) {
            throw new RestaurantSuspendedException;
        }

        if (Hash::needsRehash($user->password)) {
            $user->forceFill(['password' => $password]);
        }
        $user->forceFill([
            'last_login_at' => Carbon::now(),
            'last_login_ip' => $request->ip(),
            'failed_login_attempts' => 0,
            'locked_until' => null,
        ])->save();

        return $user;
    }

    private function failed(): ValidationException
    {
        return ValidationException::withMessages(['email' => 'The e-mail address or password is incorrect. After too many attempts the account is locked for a few minutes.']);
    }

    private function actor(Request $request): Actor
    {
        return new Actor(null, null, $request->ip(), mb_substr((string) $request->userAgent(), 0, 500), $request->attributes->get('request_id'));
    }

    private function registerFailure(User $user, Request $request): void
    {
        $threshold = (int) config('giftcard.security.login_lockout_threshold');

        // Atomic increment: parallel guessing attempts must all be counted.
        User::query()->whereKey($user->getKey())->increment('failed_login_attempts');
        $attempts = (int) User::query()->whereKey($user->getKey())->value('failed_login_attempts');

        if ($attempts >= $threshold) {
            $user->forceFill(['locked_until' => Carbon::now()->addMinutes((int) config('giftcard.security.login_lockout_minutes'))])->save();
            Log::warning('Account locked after repeated failed logins', ['user_id' => $user->getKey(), 'ip' => $request->ip(), 'attempts' => $attempts]);
        }

        $this->audit->log(
            $attempts >= $threshold ? 'auth.locked' : 'auth.failed',
            $this->actor($request),
            $user,
            metadata: ['attempts' => $attempts],
            restaurantId: $user->restaurant_id,
        );
    }
}
