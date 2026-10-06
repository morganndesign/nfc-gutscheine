<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Concerns\BelongsToRestaurant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * A restaurant's own account at the payment provider (Stripe Connect). We keep its id and what the provider says
 * about it; never a key: every charge is made with the platform's key on behalf of this account.
 *
 * @property string $id
 * @property string $restaurant_id
 * @property string $provider
 * @property string $account_id
 * @property bool $charges_enabled
 * @property bool $payouts_enabled
 * @property bool $details_submitted
 * @property string|null $connected_by
 * @property Carbon|null $enabled_at
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class PspAccount extends Model
{
    use BelongsToRestaurant;
    use HasUuids;

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'charges_enabled' => 'boolean',
            'payouts_enabled' => 'boolean',
            'details_submitted' => 'boolean',
            'enabled_at' => 'datetime',
        ];
    }
}
