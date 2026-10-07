<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Exceptions\Domain\ConnectionRevokedException;
use App\Exceptions\Domain\RestaurantSuspendedException;
use App\Models\Restaurant;
use App\Services\Partners\PartnerService;
use App\Support\Tenancy\TenantContext;
use Closure;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Response;

/**
 * The POS partner API (`/api/partner/v1`, decision 2026-10-07; audit H1).
 *
 * `partner`: `Authorization: Bearer gcpp_…`, the POS company's partner key — only to connect restaurants and manage
 * their connections, from the company's own server.
 * `partner:connection`: `Authorization: Bearer gcpc_…`, one restaurant's connection token, held by that restaurant's
 * tills; the restaurant becomes the tenant (403 CONNECTION_REVOKED when the owner disconnected it).
 * `partner:terminal`: as `connection`, plus `X-Terminal-Id` names the till, a device of the restaurant (403
 * DEVICE_REVOKED when the owner revoked it).
 */
final class AuthenticatePartner
{
    public const PARTNER = 'partner';

    public const CONNECTION = 'partner_connection';

    public function __construct(
        private readonly PartnerService $partners,
        private readonly TenantContext $tenant,
    ) {}

    public function handle(Request $request, Closure $next, string $scope = 'partner'): Response
    {
        $this->tenant->clear();
        $bearer = $request->bearerToken();

        if ($scope === 'partner') {
            $partner = is_string($bearer) ? $this->partners->authenticate($bearer) : null;
            if ($partner === null) {
                throw new AuthenticationException('Unknown or suspended partner key.');
            }
            $request->attributes->set(self::PARTNER, $partner);

            return $next($request);
        }

        $connection = is_string($bearer) ? $this->partners->authenticateConnection($bearer) : null;
        if ($connection === null) {
            throw new AuthenticationException('Unknown connection token, or the till system is suspended.');
        }
        if (! $connection->isActive()) {
            throw new ConnectionRevokedException;
        }
        /** @var Restaurant $restaurant */
        $restaurant = Restaurant::query()->with('settings')->findOrFail($connection->restaurant_id);
        if (! $restaurant->isActive()) {
            throw new RestaurantSuspendedException;
        }
        $this->tenant->set($restaurant);
        $connection->setRelation('restaurant', $restaurant);
        $request->attributes->set(self::PARTNER, $connection->partner);
        $request->attributes->set(self::CONNECTION, $connection);

        if ($scope === 'terminal') {
            $terminal = $request->header('X-Terminal-Id');
            if (! is_string($terminal) || preg_match('/^[A-Za-z0-9._-]{4,64}$/', $terminal) !== 1) {
                throw ValidationException::withMessages(['X-Terminal-Id' => 'Send X-Terminal-Id: 4–64 characters A–Z, a–z, 0–9, . _ -, the same for each till.']);
            }
            $name = $request->header('X-Terminal-Name');
            $device = $this->partners->terminal($connection, $terminal, is_string($name) ? mb_substr($name, 0, 60) : null, $request->ip());
            $request->attributes->set('device', $device);
        }

        return $next($request);
    }
}
