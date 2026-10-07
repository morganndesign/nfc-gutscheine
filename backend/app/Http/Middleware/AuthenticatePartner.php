<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Exceptions\Domain\ConnectionRevokedException;
use App\Exceptions\Domain\RestaurantSuspendedException;
use App\Models\PartnerConnection;
use App\Models\Restaurant;
use App\Services\Partners\PartnerService;
use App\Support\Tenancy\TenantContext;
use Closure;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Response;

/**
 * The POS partner API (`/api/partner/v1`, decision 2026-10-07).
 *
 * `partner`: `Authorization: Bearer gcpp_…` names the POS company (401 otherwise).
 * `partner:connection`: `X-Connection-Id` names one of its restaurant connections, which becomes the tenant (403
 * CONNECTION_REVOKED when the restaurant disconnected it).
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
        $key = $request->bearerToken();
        $partner = is_string($key) ? $this->partners->authenticate($key) : null;
        if ($partner === null) {
            throw new AuthenticationException('Unknown or suspended partner key.');
        }
        $request->attributes->set(self::PARTNER, $partner);

        if ($scope === 'connection' || $scope === 'terminal') {
            $id = $request->header('X-Connection-Id');
            /** @var PartnerConnection|null $connection */
            $connection = is_string($id) && preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $id) === 1
                ? PartnerConnection::query()->withoutGlobalScopes()->whereKey($id)->where('partner_id', $partner->getKey())->first()
                : null;
            if ($connection === null || ! $connection->isActive()) {
                throw new ConnectionRevokedException;
            }
            /** @var Restaurant $restaurant */
            $restaurant = Restaurant::query()->with('settings')->findOrFail($connection->restaurant_id);
            if (! $restaurant->isActive()) {
                throw new RestaurantSuspendedException;
            }
            $this->tenant->set($restaurant);
            $connection->setRelation('partner', $partner)->setRelation('restaurant', $restaurant);
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
        }

        return $next($request);
    }
}
