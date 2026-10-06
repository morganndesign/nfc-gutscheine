<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Concerns\BelongsToRestaurant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * A restaurant's voucher shop: what it offers online. Its address is the restaurant's slug.
 *
 * @property string $id
 * @property string $restaurant_id
 * @property bool $enabled
 * @property list<int> $amounts Offered amounts in cents
 * @property bool $custom_amount
 * @property int $max_amount
 * @property bool $card_pickup
 * @property string|null $headline
 * @property string|null $intro
 * @property string|null $terms_url
 * @property string|null $imprint_url
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class OnlineShop extends Model
{
    use BelongsToRestaurant;
    use HasUuids;

    protected $fillable = ['amounts', 'custom_amount', 'max_amount', 'card_pickup', 'headline', 'intro', 'terms_url', 'imprint_url'];

    protected $attributes = ['amounts' => '[2500,5000,10000]', 'custom_amount' => true, 'card_pickup' => false, 'enabled' => false];

    protected function casts(): array
    {
        return [
            'enabled' => 'boolean',
            'amounts' => 'array',
            'custom_amount' => 'boolean',
            'max_amount' => 'integer',
            'card_pickup' => 'boolean',
        ];
    }
}
