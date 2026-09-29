<?php

declare(strict_types=1);

namespace App\Services\Audit;

use App\Models\AuditLog;
use App\Support\Actor;
use App\Support\Tenancy\TenantContext;
use Illuminate\Database\Eloquent\Model;

/**
 * Writes append-only audit entries. Sensitive attributes are never persisted.
 */
final class AuditLogger
{
    /** @var list<string> */
    private const REDACTED = ['password', 'remember_token', 'token', 'secret_hash', 'two_factor_secret'];

    /**
     * Guest (customer) personal data is never copied into the append-only audit trail, otherwise
     * GDPR anonymisation could not erase it. The log records *that* the field changed.
     *
     * @var array<string, list<string>>
     */
    private const PERSONAL_DATA = [
        'customers' => ['first_name', 'last_name', 'email', 'phone', 'notes'],
        'vouchers' => ['recipient_name', 'notes'],
    ];

    public function __construct(private readonly TenantContext $tenant) {}

    /**
     * @param  array<string, mixed>|null  $old
     * @param  array<string, mixed>|null  $new
     * @param  array<string, mixed>  $metadata
     */
    public function log(
        string $action,
        Actor $actor,
        ?Model $subject = null,
        ?array $old = null,
        ?array $new = null,
        array $metadata = [],
        ?string $restaurantId = null,
    ): AuditLog {
        $restaurantId ??= $subject?->getAttribute('restaurant_id') ?? $this->tenant->id();

        if ($subject !== null && $restaurantId === null && $subject->getTable() === 'restaurants') {
            $restaurantId = (string) $subject->getKey();
        }

        return AuditLog::query()->create([
            'restaurant_id' => $restaurantId,
            'user_id' => $actor->userId(),
            'device_id' => $actor->deviceId(),
            'action' => $action,
            'auditable_type' => $subject !== null ? class_basename($subject) : null,
            'auditable_id' => $subject?->getKey(),
            'old_values' => $old !== null ? $this->redact($old, $subject) : null,
            'new_values' => $new !== null ? $this->redact($new, $subject) : null,
            'metadata' => $metadata === [] ? null : $metadata,
            'ip_address' => $actor->ipAddress,
            'user_agent' => $actor->userAgent,
            'request_id' => $actor->requestId,
        ]);
    }

    /**
     * @param  array<string, mixed>  $values
     * @return array<string, mixed>
     */
    private function redact(array $values, ?Model $subject): array
    {
        $personal = $subject !== null ? (self::PERSONAL_DATA[$subject->getTable()] ?? []) : [];
        foreach ($personal as $key) {
            if (array_key_exists($key, $values)) {
                $values[$key] = $values[$key] === null ? null : '[personal data]';
            }
        }

        foreach (self::REDACTED as $key) {
            if (array_key_exists($key, $values)) {
                $values[$key] = '[redacted]';
            }
        }

        return array_map(
            static fn (mixed $v): mixed => $v instanceof \BackedEnum ? $v->value : ($v instanceof \DateTimeInterface ? $v->format(DATE_ATOM) : $v),
            $values,
        );
    }
}
