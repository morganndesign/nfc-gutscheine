<?php

declare(strict_types=1);

namespace App\Services\ApiTokens;

use App\Enums\SecurityEventType;
use App\Exceptions\Domain\RoleAssignmentException;
use App\Models\PersonalAccessToken;
use App\Models\User;
use App\Services\Audit\AuditLogger;
use App\Services\Security\SecurityEventRecorder;
use App\Support\Actor;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\NewAccessToken;

/**
 * Integration tokens (POS systems, accounting exports). A token acts as the user who created
 * it, restricted to the abilities selected at creation time (a subset of that user's permissions).
 */
final class ApiTokenService
{
    public function __construct(
        private readonly AuditLogger $audit,
        private readonly SecurityEventRecorder $events,
    ) {}

    /**
     * @param  list<string>  $abilities
     */
    public function create(Actor $actor, User $user, string $name, array $abilities, ?Carbon $expiresAt): NewAccessToken
    {
        // Audit S2: a platform administrator's token would be a long-lived credential across every restaurant.
        if ($user->isPlatformAdmin() || $user->restaurant_id === null) {
            throw new RoleAssignmentException('Integration tokens belong to a restaurant. Platform administrators cannot create them.');
        }

        // Never more than the caller holds right now: the role in the dashboard, the role and the abilities of the
        // token when a token creates a token (a token with only api_tokens.manage must not mint a wider one).
        $allowed = $user->effectivePermissions();
        $invalid = array_diff($abilities, $allowed);
        if ($invalid !== []) {
            throw new RoleAssignmentException('Tokens cannot have abilities you do not have: '.implode(', ', $invalid));
        }

        $maxDays = config('giftcard.security.api_token_max_days');
        if ($maxDays !== null) {
            $limit = Carbon::now()->addDays((int) $maxDays);
            if ($expiresAt === null || $expiresAt->greaterThan($limit)) {
                $expiresAt = $limit;
            }
        }

        $token = $user->createToken($name, array_values(array_unique($abilities)), $expiresAt);

        /** @var PersonalAccessToken $model */
        $model = $token->accessToken;
        $model->forceFill(['restaurant_id' => $user->restaurant_id])->save();

        $this->audit->log('api_token.created', $actor, $model, null, [
            'name' => $name,
            'abilities' => $abilities,
            'expires_at' => $expiresAt,
        ], restaurantId: $user->restaurant_id);
        $this->events->record(SecurityEventType::IntegrationTokenCreate, $actor, subject: $user, data: [
            'abilities' => array_values(array_unique($abilities)),
        ], restaurantId: $user->restaurant_id);

        return $token;
    }

    public function revoke(Actor $actor, PersonalAccessToken $token): PersonalAccessToken
    {
        if (! $token->isRevoked()) {
            $token->forceFill(['revoked_at' => Carbon::now(), 'revoked_by' => $actor->userId()])->save();
            $this->audit->log('api_token.revoked', $actor, $token, null, ['name' => $token->name], restaurantId: $token->restaurant_id);
            $this->events->record(SecurityEventType::IntegrationTokenRevoke, $actor, restaurantId: $token->restaurant_id);
        }

        return $token;
    }
}
