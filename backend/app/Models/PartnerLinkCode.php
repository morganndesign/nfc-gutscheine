<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Concerns\BelongsToRestaurant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * A one-time code an owner gives to a POS company to connect its till system (24 hours, single use; only the hash
 * is stored).
 *
 * @property string $id
 * @property string $restaurant_id
 * @property string $code_hash
 * @property string|null $created_by
 * @property Carbon $expires_at
 * @property Carbon|null $used_at
 * @property string|null $used_by_partner_id
 */
class PartnerLinkCode extends Model
{
    use BelongsToRestaurant;
    use HasUuids;

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return ['expires_at' => 'datetime', 'used_at' => 'datetime'];
    }
}
