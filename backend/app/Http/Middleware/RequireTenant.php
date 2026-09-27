<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Exceptions\Domain\TenantNotResolvedException;
use App\Support\Tenancy\TenantContext;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Restaurant-scoped endpoints refuse to run without a tenant, so that a missing tenant can
 * never silently widen a query to all restaurants.
 */
final class RequireTenant
{
    public function __construct(private readonly TenantContext $tenant) {}

    public function handle(Request $request, Closure $next): Response
    {
        if (! $this->tenant->has()) {
            throw new TenantNotResolvedException;
        }

        return $next($request);
    }
}
