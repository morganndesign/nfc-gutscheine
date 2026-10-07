<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Concerns\BelongsToRestaurant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;

/**
 * A restaurant's consent that a POS partner redeems its vouchers. Revoked by the owner at any time; the partner's
 * tills then stop at once.
 *
 * @property string $id
 * @property string $partner_id
 * @property string $restaurant_id
 * @property string $status active | revoked
 * @property string|null $token_hash the restaurant's connection token (`gcpc_…`), hashed
 * @property string|null $token_prefix
 * @property string|null $connected_by
 * @property Carbon $connected_at
 * @property string|null $revoked_by
 * @property Carbon|null $revoked_at
 * @property Carbon $created_at
 * @property Carbon $updated_at
 * @property-read Partner $partner
 * @property-read Restaurant $restaurant
 */
class PartnerConnection extends Model
{
    use BelongsToRestaurant;
    use HasUuids;

    public const TOKEN_PREFIX = 'gcpc_';

    protected $guarded = ['id'];

    protected $hidden = ['token_hash'];

    protected function casts(): array
    {
        return ['connected_at' => 'datetime', 'revoked_at' => 'datetime'];
    }

    public function isActive(): bool
    {
        return $this->status === 'active';
    }

    /** @return BelongsTo<Partner, $this> */
    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class);
    }

    /** @return BelongsTo<Restaurant, $this> */
    public function restaurant(): BelongsTo
    {
        return $this->belongsTo(Restaurant::class);
    }

    /** @return HasMany<Device, $this> The partner's tills in this restaurant. */
    public function terminals(): HasMany
    {
        return $this->hasMany(Device::class)->withoutGlobalScopes();
    }
}
