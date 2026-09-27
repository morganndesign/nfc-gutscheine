<?php

declare(strict_types=1);

namespace App\Support\Tenancy;

use App\Exceptions\Domain\TenantNotResolvedException;
use App\Models\Restaurant;
use App\Models\Scopes\RestaurantScope;

/**
 * Request-scoped holder of the restaurant (tenant) the current request operates on.
 *
 * Every tenant-owned model is automatically constrained to this restaurant via
 * {@see RestaurantScope}. The context is bound as a scoped singleton,
 * so it is reset between requests and queue jobs (Octane-safe).
 */
final class TenantContext
{
    private ?Restaurant $restaurant = null;

    public function set(Restaurant $restaurant): void
    {
        $this->restaurant = $restaurant;
    }

    public function clear(): void
    {
        $this->restaurant = null;
    }

    public function has(): bool
    {
        return $this->restaurant !== null;
    }

    public function id(): ?string
    {
        return $this->restaurant?->getKey();
    }

    public function restaurant(): ?Restaurant
    {
        return $this->restaurant;
    }

    public function require(): Restaurant
    {
        return $this->restaurant ?? throw new TenantNotResolvedException;
    }

    /**
     * Run a callback within the context of a specific restaurant, restoring the previous one afterwards.
     *
     * @template T
     *
     * @param  callable(): T  $callback
     * @return T
     */
    public function runAs(Restaurant $restaurant, callable $callback): mixed
    {
        $previous = $this->restaurant;
        $this->restaurant = $restaurant;

        try {
            return $callback();
        } finally {
            $this->restaurant = $previous;
        }
    }
}
