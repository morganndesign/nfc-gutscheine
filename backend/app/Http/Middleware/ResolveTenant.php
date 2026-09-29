<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Exceptions\Domain\RestaurantSuspendedException;
use App\Models\Restaurant;
use App\Models\User;
use App\Support\Tenancy\TenantContext;
use Closure;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Binds the authenticated user's restaurant as the tenant for this request.
 *
 * Platform administrators have no restaurant and never act inside one: they operate the platform
 * (restaurants, batches, stations), never vouchers (architecture §13.1).
 */
final class ResolveTenant
{
    public function __construct(private readonly TenantContext $tenant) {}

    public function handle(Request $request, Closure $next): Response
    {
        $this->tenant->clear();

        /** @var User|null $user */
        $user = $request->user();

        if ($user === null) {
            throw new AuthenticationException;
        }

        if (! $user->isActive()) {
            throw new AuthenticationException('This account is deactivated.');
        }

        if (! $user->isPlatformAdmin()) {
            // Always read fresh (settings may have changed; long-running workers must not use stale data).
            $restaurant = $user->restaurant_id !== null
                ? Restaurant::query()->with('settings')->find($user->restaurant_id)
                : null;

            if ($restaurant === null) {
                throw new AuthenticationException('This account is not assigned to a restaurant.');
            }
            if (! $restaurant->isActive()) {
                throw new RestaurantSuspendedException;
            }

            $this->tenant->set($restaurant);
        }

        return $next($request);
    }
}
