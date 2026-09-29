<?php

declare(strict_types=1);

namespace App\Services\Auth;

use App\Enums\SecurityEventType;
use App\Models\PersonalAccessToken;
use App\Models\User;
use App\Services\Audit\AuditLogger;
use App\Services\Security\SecurityEventRecorder;
use App\Support\Actor;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

/**
 * Ends a person's access everywhere after a password reset or change and after a device revocation
 * (audit S1, S3):
 *  - every personal access token (waiter app device tokens and integration tokens) is revoked;
 *  - the "remember me" token is rotated, so remembered browsers must sign in again.
 * Browser sessions end on their own: Sanctum's AuthenticateSession compares the password hash in each session.
 */
final class AccessRevoker
{
    public function __construct(
        private readonly AuditLogger $audit,
        private readonly SecurityEventRecorder $events,
    ) {}

    public function revokeEverywhere(User $user, Actor $actor, string $reason, ?PersonalAccessToken $except = null): int
    {
        $revoked = PersonalAccessToken::query()
            ->where('tokenable_type', $user->getMorphClass())
            ->where('tokenable_id', $user->getKey())
            ->whereNull('revoked_at')
            ->when($except !== null, static fn ($q) => $q->whereKeyNot($except?->getKey()))
            ->update(['revoked_at' => Carbon::now(), 'revoked_by' => $actor->userId() ?? $user->getKey()]);

        $user->forceFill(['remember_token' => Str::random(60)])->saveQuietly();

        $this->audit->log('auth.access_revoked', $actor, $user, null, null, [
            'reason' => $reason,
            'tokens_revoked' => $revoked,
        ], restaurantId: $user->restaurant_id);
        $this->events->record(SecurityEventType::AccessRevoke, $actor, subject: $user, data: [
            'cause' => $reason,
            'tokens' => $revoked,
        ], restaurantId: $user->restaurant_id);

        return $revoked;
    }

    /** Rotates the "remember me" token only (a revoked device may still hold the user's recaller cookie). */
    public function forgetRememberedBrowsers(User $user): void
    {
        $user->forceFill(['remember_token' => Str::random(60)])->saveQuietly();
    }
}
