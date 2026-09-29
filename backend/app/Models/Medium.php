<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\MediumRole;
use App\Enums\MediumStatus;
use App\Enums\MediumType;
use App\Models\Concerns\BelongsToRestaurant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * "This credential may access that voucher" (architecture §5.1). A medium never owns money or expiry.
 *
 * @property string $id
 * @property string $restaurant_id
 * @property string $voucher_id
 * @property MediumType $type
 * @property MediumRole $role
 * @property MediumStatus $status
 * @property string|null $secret_hash
 * @property string|null $created_by
 * @property Carbon|null $revoked_at
 * @property string|null $revoked_by
 * @property string|null $revoke_reason
 * @property Carbon $created_at
 * @property Carbon $updated_at
 * @property-read Voucher $voucher
 * @property-read Card|null $card
 */
class Medium extends Model
{
    use BelongsToRestaurant;
    use HasUuids;

    protected $table = 'media';

    protected $guarded = ['id'];

    protected $hidden = ['secret_hash'];

    protected function casts(): array
    {
        return [
            'type' => MediumType::class,
            'role' => MediumRole::class,
            'status' => MediumStatus::class,
            'revoked_at' => 'datetime',
        ];
    }

    public function isActive(): bool
    {
        return $this->status === MediumStatus::Active;
    }

    /** @return BelongsTo<Card, $this> The physical card of an `nfc_card` medium. */
    public function card(): BelongsTo
    {
        return $this->belongsTo(Card::class)->withoutGlobalScopes();
    }

    /** @return BelongsTo<Voucher, $this> */
    public function voucher(): BelongsTo
    {
        return $this->belongsTo(Voucher::class);
    }
}
