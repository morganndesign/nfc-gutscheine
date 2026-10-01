<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\RestaurantStatus;
use App\Enums\RoleSlug;
use App\Enums\UserStatus;
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
 * @property Carbon|null $suspended_at
 * @property string|null $suspension_reason
 * @property Carbon $created_at
 * @property Carbon $updated_at
 * @property Carbon|null $deleted_at
 * @property-read RestaurantSetting $settings
 * @property-read User|null $owner
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
        'currency', 'timezone', 'locale',
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
                $restaurant->settings()->create();
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

    /**
     * The restaurant's first owner account: the one created (and invited) when the restaurant was onboarded.
     *
     * @return HasOne<User, $this>
     */
    public function owner(): HasOne
    {
        return $this->hasOne(User::class)->ofMany(
            ['created_at' => 'min', 'id' => 'min'],
            // The first owner who can still act for the restaurant (a deactivated one never).
            static fn ($q) => $q->where('status', UserStatus::Active->value)->whereHas('role', static fn ($r) => $r->where('slug', RoleSlug::Owner->value)),
        );
    }

    /** @return HasMany<Voucher, $this> */
    public function vouchers(): HasMany
    {
        return $this->hasMany(Voucher::class)->withoutGlobalScopes();
    }

    /** @return HasMany<Device, $this> */
    public function devices(): HasMany
    {
        return $this->hasMany(Device::class)->withoutGlobalScopes();
    }
}
