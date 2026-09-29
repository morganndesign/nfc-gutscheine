<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Exceptions\Domain\DeviceRevokedException;
use App\Models\User;
use App\Services\Devices\DeviceService;
use App\Support\Tenancy\TenantContext;
use Closure;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

/**
 * Identifies the terminal from the X-Device-Id header, blocks revoked devices and pins browser
 * sessions to the device they were first used on.
 *
 * Pinning matters for lost / stolen phones: after a manager revokes the device, a thief who keeps
 * the session cookie cannot simply send a fresh device id — the session is bound to the old one.
 *
 * Sign-ins restored from a "remember me" cookie are checked earlier, by BindRememberedSignIn.
 */
final class TrackDevice
{
    private const SESSION_KEY = 'device_fingerprint';

    public function __construct(
        private readonly TenantContext $tenant,
        private readonly DeviceService $devices,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        $header = $request->header('X-Device-Id');
        $deviceId = is_string($header) && preg_match('/^[A-Za-z0-9\-]{16,64}$/', $header) === 1 ? $header : null;
        /** @var User|null $user */
        $user = $request->user();
        $restaurant = $this->tenant->restaurant();

        if ($user === null || $restaurant === null) {
            return $next($request);
        }

        if ($request->hasSession()) {
            $this->pinSession($request, $deviceId);
        }

        if ($deviceId !== null) {
            $device = $this->devices->resolve($restaurant, $user, $deviceId, $request->userAgent(), $request->ip());

            if (! $device->isActive()) {
                throw new DeviceRevokedException;
            }

            $request->attributes->set('device', $device);
        }

        return $next($request);
    }

    private function signOut(Request $request): void
    {
        Auth::guard('web')->logout();
        if ($request->hasSession()) {
            $request->session()->invalidate();
            $request->session()->regenerateToken();
        }
    }

    private function pinSession(Request $request, ?string $deviceId): void
    {
        $session = $request->session();
        $fingerprint = $deviceId !== null ? hash('sha256', $deviceId) : null;
        $pinned = $session->get(self::SESSION_KEY);

        if ($pinned === null) {
            if ($fingerprint !== null) {
                $session->put(self::SESSION_KEY, $fingerprint);
            }

            return;
        }

        if (! is_string($fingerprint) || ! hash_equals((string) $pinned, $fingerprint)) {
            $this->signOut($request);

            throw new AuthenticationException('This session belongs to another device. Please sign in again.');
        }
    }
}
