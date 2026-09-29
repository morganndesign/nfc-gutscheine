<?php

declare(strict_types=1);

namespace App\Services\Security;

use App\Enums\SecurityActorKind;
use App\Enums\SecurityEventOutcome;
use App\Enums\SecurityEventType;
use App\Exceptions\Domain\DomainException;
use App\Models\SecurityEvent;
use App\Support\Actor;
use App\Support\Tenancy\TenantContext;
use BackedEnum;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use LogicException;

/**
 * Writes the security event stream (ADR-003). Two rules keep it complete and truthful:
 *
 * - A **succeeded** event is written inside the transaction of the action it describes: it exists exactly when
 *   the action committed.
 * - A **refused** event is written after the refused action's transaction has rolled back (the caller catches
 *   the refusal outside its transaction), so the refusal is never lost with the rollback.
 *
 * Events are pseudonymous: IP address, user agent and e-mail address are stored as keyed hashes (HMAC-SHA-256
 * with a key derived from the application key), plus the coarse network prefix of the IP address. Correlating
 * events (same address, same account) works; reading the address back does not.
 */
final class SecurityEventRecorder
{
    private ?string $pseudonymKey = null;

    public function __construct(private readonly TenantContext $tenant) {}

    /**
     * @param  array<string, mixed>  $data  Only the keys declared by {@see SecurityEventType::dataKeys()}.
     */
    public function record(
        SecurityEventType $type,
        Actor $actor,
        SecurityEventOutcome $outcome = SecurityEventOutcome::Succeeded,
        ?string $reason = null,
        ?Model $subject = null,
        ?int $amount = null,
        ?string $currency = null,
        array $data = [],
        ?string $restaurantId = null,
    ): SecurityEvent {
        $unknown = array_diff(array_keys($data), $type->dataKeys());
        if ($unknown !== []) {
            throw new LogicException(sprintf('Security event %s does not declare the data keys: %s.', $type->value, implode(', ', $unknown)));
        }

        $restaurantId ??= $subject?->getAttribute('restaurant_id') ?? $this->tenant->id() ?? $actor->user?->restaurant_id;
        if ($restaurantId === null && $subject !== null && $subject->getTable() === 'restaurants') {
            $restaurantId = (string) $subject->getKey();
        }

        $event = new SecurityEvent;
        $event->forceFill([
            'id' => (string) Str::ulid(),
            'occurred_at' => Carbon::now(),
            'type' => $type,
            'outcome' => $outcome,
            'reason' => $reason,
            'schema_version' => SecurityEvent::SCHEMA_VERSION,
            'restaurant_id' => $restaurantId,
            'actor_kind' => $this->actorKind($actor),
            'user_id' => $actor->userId(),
            'device_id' => $actor->deviceId(),
            'subject_type' => $subject !== null ? Str::snake(class_basename($subject)) : null,
            'subject_id' => $subject !== null ? (string) $subject->getKey() : null,
            'amount' => $amount,
            'currency' => $currency ?? ($amount !== null ? $subject?->getAttribute('currency') : null),
            'ip_hash' => $actor->ipAddress !== null ? $this->pseudonym('ip', $actor->ipAddress) : null,
            'ip_network' => $actor->ipAddress !== null ? self::network($actor->ipAddress) : null,
            'user_agent_hash' => $actor->userAgent !== null && $actor->userAgent !== '' ? $this->pseudonym('ua', $actor->userAgent) : null,
            'request_id' => $actor->requestId,
            'data' => $data === [] ? null : array_map(static fn (mixed $v): mixed => $v instanceof BackedEnum ? $v->value : $v, $data),
        ])->save();

        return $event;
    }

    /**
     * A refused action, with the refusal's error code as the reason.
     *
     * @param  array<string, mixed>  $data
     */
    public function refused(
        SecurityEventType $type,
        Actor $actor,
        DomainException|string $reason,
        ?Model $subject = null,
        ?int $amount = null,
        ?string $currency = null,
        array $data = [],
        ?string $restaurantId = null,
    ): SecurityEvent {
        return $this->record(
            $type,
            $actor,
            SecurityEventOutcome::Refused,
            $reason instanceof DomainException ? self::reasonOf($reason) : $reason,
            $subject,
            $amount,
            $currency,
            $data,
            $restaurantId,
        );
    }

    /** Keyed hash of an e-mail address (lower-cased), to correlate attempts on one account without storing it. */
    public function emailHash(string $email): string
    {
        return $this->pseudonym('email', Str::lower(trim($email)));
    }

    /** The error code, refined by the context's `reason` when the exception carries one (e.g. PRESENTMENT_INVALID:expired). */
    public static function reasonOf(DomainException $e): string
    {
        $detail = $e->context()['reason'] ?? null;

        return is_string($detail) && $detail !== '' ? $e->errorCode().':'.$detail : $e->errorCode();
    }

    /** IPv4 → /24, IPv6 → /48: enough to see a network, not a household. */
    public static function network(string $ip): ?string
    {
        $packed = @inet_pton($ip);
        if ($packed === false) {
            return null;
        }
        if (strlen($packed) === 4) {
            return inet_ntop(substr($packed, 0, 3)."\0").'/24';
        }

        return inet_ntop(substr($packed, 0, 6).str_repeat("\0", 10)).'/48';
    }

    private function actorKind(Actor $actor): SecurityActorKind
    {
        return match (true) {
            $actor->device !== null => SecurityActorKind::Device,
            $actor->user !== null => SecurityActorKind::User,
            $actor->ipAddress === null => SecurityActorKind::System,
            default => SecurityActorKind::Anonymous,
        };
    }

    private function pseudonym(string $kind, string $value): string
    {
        $this->pseudonymKey ??= hash_hmac('sha256', 'giftcard-pro/security-events/pseudonyms/v1', self::applicationKey(), true);

        return hash_hmac('sha256', $kind."\0".$value, $this->pseudonymKey);
    }

    private static function applicationKey(): string
    {
        $key = (string) config('app.key');

        return str_starts_with($key, 'base64:') ? (string) base64_decode(substr($key, 7), true) : $key;
    }
}
