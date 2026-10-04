<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Enums\SecurityEventType;
use App\Exceptions\Domain\AccountDeactivatedException;
use App\Exceptions\Domain\DomainException;
use App\Models\PersonalAccessToken;
use App\Models\User;
use App\Services\Auth\DeviceTokenService;
use App\Services\Security\SecurityEventRecorder;
use App\Support\Actor;
use Closure;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * A waiter app token only works from the phone it was issued to and stops working as soon as that
 * phone is revoked in Devices (403 DEVICE_REVOKED). A copied token is useless on another device.
 * A deactivated account gets 401 ACCOUNT_DEACTIVATED. It also only reaches the requests the waiter app makes
 * (method and path): listing vouchers, profile or password changes need the web app.
 */
final class EnforceDeviceToken
{
    /**
     * Method and path of every request the waiter app makes; nothing else is reachable with its token.
     *
     * @var list<array{0: string, 1: string}>
     */
    private const ALLOWED = [
        ['GET', 'api/v1/auth/me'],
        ['POST', 'api/v1/auth/logout'],
        ['GET', 'api/v1/devices/current'],
        // The user's own language (shared with the dashboard); nothing else of the profile.
        ['PUT', 'api/v1/auth/language'],
        // The restaurant's logo on the guest's card.
        ['GET', 'api/v1/restaurant/logo'],
        ['POST', 'api/v1/presentments'],
        // A physical card: live authentication relayed by the phone.
        ['POST', 'api/v1/presentments/cards'],
        ['POST', 'api/v1/presentments/cards/*'],
        ['POST', 'api/v1/vouchers/*/redemptions'],
        // The outcome of one of this user's own attempts (unknown outcome after a lost answer).
        ['GET', 'api/v1/vouchers/*/redemptions/*'],
        // Managers and owners: sell a voucher (the role and permissions decide).
        ['POST', 'api/v1/vouchers'],
        // Managers and owners: top up a guest's card (tapped at the till).
        ['POST', 'api/v1/vouchers/*/reloads'],
        // Physical cards: confirm a delivery, look up, suspend, resume and replace a guest's card.
        ['GET', 'api/v1/card-batches'],
        ['POST', 'api/v1/card-batches/*/receipt'],
        ['GET', 'api/v1/card-orders'],
        ['POST', 'api/v1/card-orders'],
        ['GET', 'api/v1/cards/*'],
        ['POST', 'api/v1/cards/*/suspend'],
        ['POST', 'api/v1/cards/*/resume'],
        ['POST', 'api/v1/cards/*/replacement'],
        // Platform staff: the personalisation station.
        ['GET', 'api/v1/admin/station/batches'],
        ['POST', 'api/v1/admin/card-batches/*/personalizations'],
        ['POST', 'api/v1/admin/personalizations/*'],
    ];

    public function __construct(
        private readonly DeviceTokenService $tokens,
        private readonly SecurityEventRecorder $events,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();
        $token = $user instanceof User ? $user->currentAccessToken() : null;

        if ($token instanceof PersonalAccessToken && is_string($token->device_id) && $user instanceof User) {
            if (! $user->isActive()) {
                $this->refused($request, $user, 'ACCOUNT_DEACTIVATED');

                throw new AccountDeactivatedException;
            }

            $header = $request->header('X-Device-Id');
            try {
                $device = $this->tokens->assertDevice($token, is_string($header) ? $header : null);
            } catch (DomainException $e) {
                $this->refused($request, $user, SecurityEventRecorder::reasonOf($e));

                throw $e;
            } catch (AuthenticationException $e) {
                $this->refused($request, $user, 'OTHER_DEVICE');

                throw $e;
            }
            $request->attributes->set('device', $device);

            if (! $this->allowed($request)) {
                $this->refused($request, $user, 'ROUTE_NOT_ALLOWED');

                throw new AuthorizationException;
            }
        }

        return $next($request);
    }

    /** A token used from another phone, a revoked phone, a deactivated account or for a request the app never makes. */
    private function refused(Request $request, User $user, string $reason): void
    {
        $this->events->refused(SecurityEventType::DeviceTokenUse, Actor::fromRequest($request)->withUser($user), $reason, $user, data: [
            'method' => $request->method(),
            'route' => $request->route()?->uri() ?? $request->path(),
        ], restaurantId: $user->restaurant_id);
    }

    private function allowed(Request $request): bool
    {
        foreach (self::ALLOWED as [$method, $path]) {
            if ($request->isMethod($method) && $request->is($path)) {
                return true;
            }
        }

        return false;
    }
}
