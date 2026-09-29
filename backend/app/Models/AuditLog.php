<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Concerns\HashChained;
use App\Models\Concerns\Immutable;
use App\Models\Contracts\HashChainedRecord;
use App\Models\Scopes\RestaurantScope;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Append-only, hash-chained audit trail of every security- or money-relevant action. One chain per restaurant,
 * and one for platform-level entries.
 *
 * @property string $id
 * @property string|null $restaurant_id
 * @property string|null $user_id
 * @property string|null $device_id
 * @property string $action
 * @property string|null $auditable_type
 * @property string|null $auditable_id
 * @property array<string, mixed>|null $old_values
 * @property array<string, mixed>|null $new_values
 * @property array<string, mixed>|null $metadata
 * @property string|null $ip_address
 * @property string|null $user_agent
 * @property string|null $request_id
 * @property Carbon $created_at
 * @property string $chain_scope
 * @property int $chain_seq
 * @property string $prev_hash
 * @property string $entry_hash
 * @property-read User|null $user
 */
class AuditLog extends Model implements HashChainedRecord
{
    use HashChained;
    use HasUuids;
    use Immutable;

    public const UPDATED_AT = null;

    protected $guarded = ['id'];

    protected static function booted(): void
    {
        // Read-scoped to the tenant, but writes never fail on tenant mismatch
        // (platform administrators write logs into restaurants they manage).
        static::addGlobalScope(new RestaurantScope);
    }

    protected function casts(): array
    {
        return [
            'old_values' => 'array',
            'new_values' => 'array',
            'metadata' => 'array',
            'chain_seq' => 'integer',
            'created_at' => 'datetime',
        ];
    }

    public static function chainName(): string
    {
        return 'audit_logs';
    }

    public function chainAttributes(): array
    {
        return [
            'id', 'restaurant_id', 'user_id', 'device_id', 'action', 'auditable_type', 'auditable_id', 'old_values',
            'new_values', 'metadata', 'ip_address', 'user_agent', 'request_id', 'created_at',
        ];
    }

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class)->withTrashed();
    }

    /** @return BelongsTo<Restaurant, $this> */
    public function restaurant(): BelongsTo
    {
        return $this->belongsTo(Restaurant::class)->withTrashed();
    }
}
