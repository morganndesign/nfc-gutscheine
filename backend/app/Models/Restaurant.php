<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\RestaurantStatus;
use Database\Factories\RestaurantFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Carbon;

/**
 * @property string $id
 * @property string $name
 * @property string $slug
 * @property string|null $legal_name
 * @property string|null $vat_number
 * @property string|null $email
 * @property string|null $phone
 * @property string|null $website
 * @property string|null $address_line1
 * @property string|null $address_line2
 * @property string|null $postal_code
 * @property string|null $city
 * @property string $country
 * @property string $currency
 * @property string $timezone
 * @property string $locale
 * @property RestaurantStatus $status
 * @property string $plan
 * @property Carbon|null $suspended_at
 * @property string|null $suspension_reason
 * @property Carbon $created_at
 * @property Carbon $updated_at
 * @property-read RestaurantSetting $settings
 */
class Restaurant extends Model
{
    /** @use HasFactory<RestaurantFactory> */
    use HasFactory;

    use HasUuids;
    use SoftDeletes;

    protected $fillable = [
        'name', 'slug', 'legal_name', 'vat_number', 'email', 'phone', 'website',
        'address_line1', 'address_line2', 'postal_code', 'city', 'country',
        'currency', 'timezone', 'locale', 'plan',
    ];

    protected function casts(): array
    {
        return [
            'status' => RestaurantStatus::class,
            'suspended_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::created(static function (Restaurant $restaurant): void {
            if (! $restaurant->settings()->exists()) {
                $restaurant->settings()->create([
                    'card_number_prefix' => '',
                ]);
            }
        });
    }

    public function isActive(): bool
    {
        return $this->status === RestaurantStatus::Active;
    }

    /** @return HasOne<RestaurantSetting, $this> */
    public function settings(): HasOne
    {
        return $this->hasOne(RestaurantSetting::class);
    }

    /** @return HasMany<User, $this> */
    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }

    /** @return HasMany<GiftCard, $this> */
    public function giftCards(): HasMany
    {
        return $this->hasMany(GiftCard::class)->withoutGlobalScopes();
    }

    /** @return HasMany<Device, $this> */
    public function devices(): HasMany
    {
        return $this->hasMany(Device::class)->withoutGlobalScopes();
    }
}
