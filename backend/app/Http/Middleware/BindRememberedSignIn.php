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
 *
 * It also ends browser sessions signed in before the person's `sessions_revoked_at` (an e-mail change or a
 * deactivation, audit S4): the session remembers when it signed in.
 */
final class BindRememberedSignIn
{
    public const SIGNED_IN_AT = 'signed_in_at';

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

        if ($user instanceof User && $guard->check() && $request->hasSession()) {
            $session = $request->session();
            if ($guard->viaRemember()) {
                // Restored from a valid "remember me" cookie (rotated whenever sessions are revoked): a new sign-in.
                $session->put(self::SIGNED_IN_AT, time());
            } elseif ($user->sessions_revoked_at !== null && (int) $session->get(self::SIGNED_IN_AT, 0) < $user->sessions_revoked_at->getTimestamp()) {
                $guard->logout();
                $session->invalidate();
                $session->regenerateToken();

                throw new AuthenticationException('Please sign in again.');
            }
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
