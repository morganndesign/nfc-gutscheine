<?php

declare(strict_types=1);

namespace App\Models\Concerns;

use App\Exceptions\Domain\TenantMismatchException;
use App\Models\Restaurant;
use App\Models\Scopes\RestaurantScope;
use App\Support\Tenancy\TenantContext;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Marks a model as tenant-owned. Reads are scoped to the active restaurant and writes
 * are stamped with it; attempts to write a row into a different restaurant fail hard.
 *
 * @mixin Model
 */
trait BelongsToRestaurant
{
    public static function bootBelongsToRestaurant(): void
    {
        static::addGlobalScope(new RestaurantScope);

        static::creating(static function (Model $model): void {
            $tenant = app(TenantContext::class);

            if ($model->getAttribute('restaurant_id') === null && $tenant->has()) {
                $model->setAttribute('restaurant_id', $tenant->id());
            }

            static::guardTenant($model, $tenant);
        });

        static::updating(static function (Model $model): void {
            if ($model->isDirty('restaurant_id')) {
                throw new TenantMismatchException('The owning restaurant of a record can never change.');
            }

            static::guardTenant($model, app(TenantContext::class));
        });
    }

    protected static function guardTenant(Model $model, TenantContext $tenant): void
    {
        if ($tenant->has() && $model->getAttribute('restaurant_id') !== $tenant->id()) {
            throw new TenantMismatchException;
        }
    }

    /** @return BelongsTo<Restaurant, $this> */
    public function restaurant(): BelongsTo
    {
        return $this->belongsTo(Restaurant::class);
    }

    /**
     * @param  Builder<static>  $query
     * @return Builder<static>
     */
    public function scopeForRestaurant(Builder $query, Restaurant|string $restaurant): Builder
    {
        $id = $restaurant instanceof Restaurant ? $restaurant->getKey() : $restaurant;

        return $query->withoutGlobalScope(RestaurantScope::class)->where($this->qualifyColumn('restaurant_id'), $id);
    }
}
