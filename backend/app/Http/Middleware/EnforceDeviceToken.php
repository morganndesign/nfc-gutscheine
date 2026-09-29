<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Exceptions\Domain\AccountDeactivatedException;
use App\Models\PersonalAccessToken;
use App\Models\User;
use App\Services\Auth\DeviceTokenService;
use Closure;
use Illuminate\Auth\Access\AuthorizationException;
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
        ['POST', 'api/v1/presentments'],
        ['POST', 'api/v1/vouchers/*/redemptions'],
        // The outcome of one of this user's own attempts (unknown outcome after a lost answer).
        ['GET', 'api/v1/vouchers/*/redemptions/*'],
        // Managers and owners: sell a voucher (the role and permissions decide).
        ['POST', 'api/v1/vouchers'],
    ];

    public function __construct(private readonly DeviceTokenService $tokens) {}

    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();
        $token = $user instanceof User ? $user->currentAccessToken() : null;

        if ($token instanceof PersonalAccessToken && is_string($token->device_id)) {
            if ($user instanceof User && ! $user->isActive()) {
                throw new AccountDeactivatedException;
            }

            $header = $request->header('X-Device-Id');
            $device = $this->tokens->assertDevice($token, is_string($header) ? $header : null);
            $request->attributes->set('device', $device);

            if (! $this->allowed($request)) {
                throw new AuthorizationException;
            }
        }

        return $next($request);
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
