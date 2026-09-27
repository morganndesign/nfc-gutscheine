<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Concerns\Immutable;
use App\Models\Scopes\RestaurantScope;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Append-only audit trail of every security- or money-relevant action.
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
 * @property-read User|null $user
 */
class AuditLog extends Model
{
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
            'created_at' => 'datetime',
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
