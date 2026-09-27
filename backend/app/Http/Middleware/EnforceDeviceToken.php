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
 * A deactivated account gets 401 ACCOUNT_DEACTIVATED. It also only reaches the endpoints the waiter app uses: profile or password changes need the web app.
 */
final class EnforceDeviceToken
{
    private const ALLOWED = [
        'api/v1/auth/me',
        'api/v1/auth/logout',
        'api/v1/scan',
        'api/v1/cards/*/redeem',
        'api/v1/devices/current',
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

            if (! $request->is(...self::ALLOWED)) {
                throw new AuthorizationException;
            }
        }

        return $next($request);
    }
}
