<?php

declare(strict_types=1);

namespace App\Services\Auth;

use App\Enums\Permission;
use App\Exceptions\Domain\DeviceRevokedException;
use App\Models\Device;
use App\Models\PersonalAccessToken;
use App\Models\User;
use App\Services\Audit\AuditLogger;
use App\Services\Devices\DeviceService;
use App\Support\Actor;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\NewAccessToken;

/**
 * Sign-in tokens for the native waiter app (GiftCard Waiter).
 *
 * A token can scan and redeem; for managers and owners (roles with `cards.create` and `cards.write_nfc`)
 * it can also sell a card and program its tag in the app. It is bound to the phone that signed in (X-Device-Id), expires after
 * `device_token_days` without use and is renewed while the phone is in use. Revoking the device in
 * Devices stops the token immediately. One active token per person and phone: signing in again
 * replaces the previous token.
 */
final class DeviceTokenService
{
    /** @var list<string> */
    public const ABILITIES = [Permission::CardsScan->value, Permission::CardsRedeem->value];

    /**
     * Selling and programming cards in the app: granted only when the role has both permissions. The role is
     * still checked on every request (a token never grants more than the role, see User::hasPermission).
     *
     * @var list<string>
     */
    public const ISSUING_ABILITIES = [Permission::CardsCreate->value, Permission::CardsWriteNfc->value];

    /** @return list<string> */
    public static function abilitiesFor(User $user): array
    {
        $granted = $user->role->permissionSlugs();

        return array_diff(self::ISSUING_ABILITIES, $granted) === []
            ? [...self::ABILITIES, ...self::ISSUING_ABILITIES]
            : self::ABILITIES;
    }

    public function __construct(
        private readonly DeviceService $devices,
        private readonly AuditLogger $audit,
    ) {}

    public function issue(Request $request, User $user, string $deviceId, string $deviceName, string $platform): NewAccessToken
    {
        $restaurant = $user->restaurant;
        $granted = $user->role->permissionSlugs();

        if ($restaurant === null || array_diff(self::ABILITIES, $granted) !== []) {
            throw new AuthorizationException;
        }

        $device = $this->devices->resolve($restaurant, $user, $deviceId, $request->userAgent(), $request->ip(), $deviceName);

        if (! $device->isActive()) {
            throw new DeviceRevokedException;
        }

        $actor = new Actor($user, $device, $request->ip(), mb_substr((string) $request->userAgent(), 0, 500), $request->attributes->get('request_id'));

        return DB::transaction(function () use ($user, $device, $platform, $actor): NewAccessToken {
            PersonalAccessToken::query()
                ->where('tokenable_id', $user->getKey())
                ->where('device_id', $device->getKey())
                ->whereNull('revoked_at')
                ->update(['revoked_at' => Carbon::now(), 'revoked_by' => $user->getKey()]);

            $token = $user->createToken(
                mb_substr('GiftCard Waiter · '.$device->name, 0, 191),
                self::abilitiesFor($user),
                Carbon::now()->addDays(self::lifetimeDays()),
            );

            /** @var PersonalAccessToken $model */
            $model = $token->accessToken;
            $model->forceFill(['restaurant_id' => $user->restaurant_id, 'device_id' => $device->getKey()])->save();

            $this->audit->log('auth.device_token_issued', $actor, $device, null, [
                'platform' => $platform,
                'expires_at' => $model->expires_at,
            ], restaurantId: $user->restaurant_id);

            return $token;
        });
    }

    /**
     * Rolling expiry: renewed at most once a day so an active phone never has to sign in again,
     * while a phone left in a drawer for a month does.
     */
    public function renew(PersonalAccessToken $token): void
    {
        if ($token->device_id === null || $token->expires_at === null) {
            return;
        }

        $target = Carbon::now()->addDays(self::lifetimeDays());
        if (! $token->expires_at->lessThan($target->copy()->subDay())) {
            return;
        }

        $changes = ['expires_at' => $target];
        // Once a day the abilities also follow the role (a waiter promoted to manager, or a token issued before
        // card selling existed in the app) without a new sign-in.
        $user = $token->tokenable;
        if ($user instanceof User) {
            $abilities = self::abilitiesFor($user);
            if ($abilities !== array_values((array) $token->abilities)) {
                $changes['abilities'] = $abilities;
            }
        }

        $token->forceFill($changes)->saveQuietly();
    }

    /** Checks that a device-bound token is used from its own phone and that the phone is still allowed. */
    public function assertDevice(PersonalAccessToken $token, ?string $deviceHeader): Device
    {
        /** @var Device|null $device */
        $device = $token->device_id !== null
            ? Device::query()->withoutGlobalScopes()->whereKey($token->device_id)->first()
            : null;

        $fingerprint = is_string($deviceHeader) && $deviceHeader !== ''
            ? hash('sha256', $token->restaurant_id.'|'.$deviceHeader)
            : null;

        if ($device === null || $fingerprint === null || ! hash_equals($device->fingerprint, $fingerprint)) {
            throw new AuthenticationException('This sign-in belongs to another device. Please sign in again.');
        }

        if (! $device->isActive()) {
            throw new DeviceRevokedException;
        }

        return $device;
    }

    private static function lifetimeDays(): int
    {
        return max(1, (int) config('giftcard.security.device_token_days', 30));
    }
}
