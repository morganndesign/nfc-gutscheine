<?php

declare(strict_types=1);

namespace App\Services\Security;

use App\Enums\SecurityEventType;
use App\Models\User;
use App\Support\Actor;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

/**
 * Security events of the sign-in channels (web session and waiter app token), so both channels are observed
 * the same way. Attempts on unknown accounts are recorded with a keyed hash of the e-mail address only.
 */
final class AuthEvents
{
    public function __construct(private readonly SecurityEventRecorder $events) {}

    public function signedIn(Request $request, User $user, string $channel): void
    {
        $this->events->record(SecurityEventType::SignIn, Actor::fromRequest($request)->withUser($user), subject: $user, data: [
            'channel' => $channel,
        ]);
    }

    public function signInRefused(Request $request, string $email, ?User $user, string $reason, string $channel, ?int $attempts = null): void
    {
        $this->events->refused(SecurityEventType::SignIn, self::anonymous($request), $reason, $user, data: array_filter([
            'channel' => $channel,
            'email_hash' => $this->events->emailHash($email),
            'attempts' => $attempts,
        ], static fn (mixed $v): bool => $v !== null), restaurantId: $user?->restaurant_id);
    }

    public function accountLocked(Request $request, User $user, int $attempts, int $minutes): void
    {
        $this->events->record(SecurityEventType::AccountLock, self::anonymous($request), subject: $user, data: [
            'attempts' => $attempts,
            'minutes' => $minutes,
        ], restaurantId: $user->restaurant_id);
    }

    /**
     * The sign-in rate limiter answered 429. Recorded at most once per address and account per minute, so a
     * flood of requests leaves a trace without turning into a flood of rows.
     */
    public function signInThrottled(Request $request, int $retryAfter): void
    {
        $email = (string) $request->input('email');
        $channel = $request->is('api/*/auth/token') ? 'app' : 'web';
        $emailHash = $this->events->emailHash($email);
        if (! Cache::add('security-events:sign-in-throttle:'.sha1($request->ip().'|'.$emailHash), true, 60)) {
            return;
        }

        $this->events->record(SecurityEventType::SignInThrottle, self::anonymous($request), data: [
            'channel' => $channel,
            'email_hash' => $emailHash,
            'retry_after' => $retryAfter,
        ]);
    }

    private static function anonymous(Request $request): Actor
    {
        return new Actor(null, null, $request->ip(), mb_substr((string) $request->userAgent(), 0, 500), $request->attributes->get('request_id'));
    }
}
