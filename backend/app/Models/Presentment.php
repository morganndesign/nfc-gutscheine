<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\PresentmentMethod;
use App\Enums\PresentmentPurpose;
use App\Enums\PresentmentStatus;
use App\Models\Concerns\BelongsToRestaurant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * The server's record that a medium was genuinely presented to this device and user, now (architecture §10.1):
 * single use, valid 60 seconds, bound to user, device, restaurant, voucher and purpose.
 *
 * @property string $id
 * @property string $restaurant_id
 * @property string $voucher_id
 * @property string $medium_id
 * @property PresentmentPurpose $purpose
 * @property PresentmentMethod $method
 * @property string $level
 * @property PresentmentStatus $status
 * @property string|null $user_id
 * @property string|null $device_id
 * @property Carbon $expires_at
 * @property Carbon|null $consumed_at
 * @property Carbon $created_at
 * @property-read Voucher $voucher
 * @property-read Medium $medium
 */
class Presentment extends Model
{
    use BelongsToRestaurant;
    use HasUuids;

    public const UPDATED_AT = null;

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'purpose' => PresentmentPurpose::class,
            'method' => PresentmentMethod::class,
            'status' => PresentmentStatus::class,
            'expires_at' => 'datetime',
            'consumed_at' => 'datetime',
            'created_at' => 'datetime',
        ];
    }

    public function isExpired(?Carbon $now = null): bool
    {
        return $this->expires_at->lessThanOrEqualTo($now ?? Carbon::now());
    }

    /** @return BelongsTo<Voucher, $this> */
    public function voucher(): BelongsTo
    {
        return $this->belongsTo(Voucher::class);
    }

    /** @return BelongsTo<Medium, $this> */
    public function medium(): BelongsTo
    {
        return $this->belongsTo(Medium::class);
    }
}
