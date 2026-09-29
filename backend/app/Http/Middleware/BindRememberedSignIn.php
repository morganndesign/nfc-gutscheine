<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Models\User;
use App\Services\Devices\DeviceService;
use Closure;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

/**
 * A browser session restored from a "remember me" cookie is accepted only on a device this person already used
 * and that is still active (audit S1): a copied cookie is useless on a new device id and after the device was
 * revoked. Platform administrators always sign in explicitly. Runs for every authenticated request, so the check
 * happens on the very request that restores the session, whatever endpoint it calls.
 */
final class BindRememberedSignIn
{
    public function __construct(private readonly DeviceService $devices) {}

    public function handle(Request $request, Closure $next): Response
    {
        $guard = Auth::guard('web');
        $user = $request->user();

        if ($user instanceof User && $guard->check() && $guard->viaRemember() && ! $this->onKnownDevice($request, $user)) {
            $guard->logout();
            if ($request->hasSession()) {
                $request->session()->invalidate();
                $request->session()->regenerateToken();
            }

            throw new AuthenticationException('Please sign in again on this device.');
        }

        return $next($request);
    }

    private function onKnownDevice(Request $request, User $user): bool
    {
        $header = $request->header('X-Device-Id');
        $restaurant = $user->restaurant;

        if ($user->isPlatformAdmin() || $restaurant === null || ! is_string($header) || preg_match('/^[A-Za-z0-9\-]{16,64}$/', $header) !== 1) {
            return false;
        }

        $device = $this->devices->find($restaurant, $header);

        return $device !== null
            && $device->isActive()
            && in_array($user->getKey(), [$device->last_user_id, $device->registered_by], true);
    }
}
