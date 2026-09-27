<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\DeviceStatus;
use App\Models\Concerns\BelongsToRestaurant;
use Database\Factories\DeviceFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Carbon;

/**
 * A waiter phone / tablet / POS terminal that performs card operations.
 *
 * @property string $id
 * @property string $restaurant_id
 * @property string|null $registered_by
 * @property string $name
 * @property string $type
 * @property string $fingerprint
 * @property string|null $platform
 * @property DeviceStatus $status
 * @property Carbon|null $last_seen_at
 * @property string|null $last_ip
 * @property string|null $last_user_id
 * @property Carbon|null $revoked_at
 * @property Carbon $created_at
 */
class Device extends Model
{
    use BelongsToRestaurant;

    /** @use HasFactory<DeviceFactory> */
    use HasFactory;

    use HasUuids;
    use SoftDeletes;

    protected $fillable = ['name', 'type', 'fingerprint', 'platform'];

    protected function casts(): array
    {
        return [
            'status' => DeviceStatus::class,
            'last_seen_at' => 'datetime',
            'revoked_at' => 'datetime',
        ];
    }

    public function isActive(): bool
    {
        return $this->status === DeviceStatus::Active;
    }

    /** @return BelongsTo<User, $this> */
    public function registeredBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'registered_by');
    }

    /** @return BelongsTo<User, $this> */
    public function lastUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'last_user_id');
    }
}
