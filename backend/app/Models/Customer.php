<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Concerns\BelongsToRestaurant;
use Database\Factories\CustomerFactory;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Carbon;

/**
 * @property string $id
 * @property string $restaurant_id
 * @property string|null $first_name
 * @property string|null $last_name
 * @property string|null $email
 * @property string|null $phone
 * @property string|null $notes
 * @property bool $marketing_consent
 * @property Carbon|null $anonymized_at
 * @property Carbon $created_at
 * @property-read string $full_name
 */
class Customer extends Model
{
    use BelongsToRestaurant;

    /** @use HasFactory<CustomerFactory> */
    use HasFactory;

    use HasUuids;
    use SoftDeletes;

    protected $fillable = ['first_name', 'last_name', 'email', 'phone', 'notes', 'marketing_consent'];

    protected function casts(): array
    {
        return [
            'marketing_consent' => 'boolean',
            'anonymized_at' => 'datetime',
        ];
    }

    public function getFullNameAttribute(): string
    {
        return trim(($this->first_name ?? '').' '.($this->last_name ?? '')) ?: ($this->email ?? '—');
    }

    /** @return HasMany<GiftCard, $this> */
    public function giftCards(): HasMany
    {
        return $this->hasMany(GiftCard::class);
    }

    /**
     * @param  Builder<Customer>  $query
     * @return Builder<Customer>
     */
    public function scopeSearch(Builder $query, ?string $term): Builder
    {
        if ($term === null || trim($term) === '') {
            return $query;
        }

        $like = '%'.addcslashes(trim($term), '%_\\').'%';

        return $query->where(static function (Builder $q) use ($like): void {
            $q->where('first_name', 'like', $like)
                ->orWhere('last_name', 'like', $like)
                ->orWhere('email', 'like', $like)
                ->orWhere('phone', 'like', $like);
        });
    }
}
