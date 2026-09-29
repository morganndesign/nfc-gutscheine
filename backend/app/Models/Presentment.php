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
 * @property string|null $voucher_id
 * @property string|null $medium_id
 * @property string|null $card_id
 * @property string|null $rf_uid 7 raw bytes: the UID the phone saw on the radio layer
 * @property int|null $sdm_counter
 * @property PresentmentPurpose $purpose
 * @property PresentmentMethod $method
 * @property string $level
 * @property PresentmentStatus $status
 * @property string|null $user_id
 * @property string|null $device_id
 * @property Carbon $expires_at
 * @property Carbon|null $consumed_at
 * @property Carbon $created_at
 * @property-read Voucher|null $voucher
 * @property-read Medium|null $medium
 * @property-read Card|null $card
 */
class Presentment extends Model
{
    use BelongsToRestaurant;
    use HasUuids;

    public const UPDATED_AT = null;

    protected $guarded = ['id'];

    protected $hidden = ['card_id', 'rf_uid'];

    protected function casts(): array
    {
        return [
            'purpose' => PresentmentPurpose::class,
            'method' => PresentmentMethod::class,
            'status' => PresentmentStatus::class,
            'expires_at' => 'datetime',
            'consumed_at' => 'datetime',
            'created_at' => 'datetime',
            'sdm_counter' => 'integer',
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

    /** @return BelongsTo<Card, $this> */
    public function card(): BelongsTo
    {
        return $this->belongsTo(Card::class);
    }
}
