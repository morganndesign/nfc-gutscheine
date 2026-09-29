<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\SecurityActorKind;
use App\Enums\SecurityEventOutcome;
use App\Enums\SecurityEventType;
use App\Models\Concerns\Immutable;
use App\Services\Security\SecurityEventRecorder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * One row of the security event stream (ADR-003). Append-only; written by
 * {@see SecurityEventRecorder} only.
 *
 * @property int $seq
 * @property string $id
 * @property Carbon $occurred_at
 * @property SecurityEventType $type
 * @property SecurityEventOutcome $outcome
 * @property string|null $reason
 * @property int $schema_version
 * @property string|null $restaurant_id
 * @property SecurityActorKind $actor_kind
 * @property string|null $user_id
 * @property string|null $device_id
 * @property string|null $subject_type
 * @property string|null $subject_id
 * @property int|null $amount
 * @property string|null $currency
 * @property string|null $ip_hash
 * @property string|null $ip_network
 * @property string|null $user_agent_hash
 * @property string|null $request_id
 * @property array<string, mixed>|null $data
 */
class SecurityEvent extends Model
{
    use Immutable;

    /** Version of the event catalogue ({@see SecurityEventType}) new rows are written under. */
    public const SCHEMA_VERSION = 1;

    /**
     * The columns that are sealed, in hashing order. A new column is added at the end with a new schema version.
     *
     * @var list<string>
     */
    public const SEALED_COLUMNS = [
        'seq', 'id', 'occurred_at', 'type', 'outcome', 'reason', 'schema_version', 'restaurant_id', 'actor_kind',
        'user_id', 'device_id', 'subject_type', 'subject_id', 'amount', 'currency', 'ip_hash', 'ip_network',
        'user_agent_hash', 'request_id', 'data',
    ];

    public $timestamps = false;

    /** Microseconds are kept: they order events within a second and are part of the seal. */
    protected $dateFormat = 'Y-m-d H:i:s.u';

    protected $primaryKey = 'seq';

    protected $guarded = ['seq'];

    protected function casts(): array
    {
        return [
            'occurred_at' => 'immutable_datetime',
            'type' => SecurityEventType::class,
            'outcome' => SecurityEventOutcome::class,
            'actor_kind' => SecurityActorKind::class,
            'schema_version' => 'integer',
            'amount' => 'integer',
            'data' => 'array',
        ];
    }
}
