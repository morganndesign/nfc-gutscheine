<?php

declare(strict_types=1);

namespace App\Services\Devices;

use App\Enums\DeviceStatus;
use App\Http\Middleware\TrackDevice;
use App\Models\Device;
use App\Models\Restaurant;
use App\Models\User;
use App\Services\Audit\AuditLogger;
use App\Services\Auth\AccessRevoker;
use App\Support\Actor;
use Illuminate\Support\Carbon;

/**
 * Waiter devices are identified by a random device id generated once by the client
 * (X-Device-Id header). Devices are registered automatically on first use and can be
 * named and revoked by managers; a revoked device can no longer perform card operations.
 */
final class DeviceService
{
    private const TOUCH_INTERVAL_SECONDS = 60;

    public function __construct(
        private readonly AuditLogger $audit,
        private readonly AccessRevoker $access,
    ) {}

    /**
     * @param  string|null  $name  Name reported by a native app on first sign-in ("Pixel 7"); browsers get a name derived from the user agent.
     */
    public function resolve(Restaurant $restaurant, User $user, string $deviceId, ?string $userAgent, ?string $ip, ?string $name = null): Device
    {
        $fingerprint = hash('sha256', $restaurant->getKey().'|'.$deviceId);

        /** @var Device|null $device */
        $device = Device::query()->forRestaurant($restaurant)->withTrashed()->where('fingerprint', $fingerprint)->first();

        if ($device === null) {
            $device = new Device;
            $device->fill([
                'name' => $name !== null && trim($name) !== '' ? mb_substr(trim($name), 0, 120) : $this->defaultName($userAgent),
                'type' => $this->detectType($userAgent),
                'fingerprint' => $fingerprint,
                'platform' => $userAgent !== null ? mb_substr($userAgent, 0, 120) : null,
            ]);
            $device->forceFill([
                'restaurant_id' => $restaurant->getKey(),
                'registered_by' => $user->getKey(),
                'status' => DeviceStatus::Active,
                'last_seen_at' => Carbon::now(),
                'last_ip' => $ip,
                'last_user_id' => $user->getKey(),
            ])->save();

            $this->audit->log('device.registered', new Actor($user, $device, $ip, $userAgent), $device, null, ['name' => $device->name], restaurantId: $restaurant->getKey());

            return $device;
        }

        if ($device->last_seen_at === null
            || $device->last_seen_at->diffInSeconds(Carbon::now()) > self::TOUCH_INTERVAL_SECONDS
            || $device->last_user_id !== $user->getKey()) {
            Device::query()->forRestaurant($restaurant)->whereKey($device->getKey())->update([
                'last_seen_at' => Carbon::now(),
                'last_ip' => $ip,
                'last_user_id' => $user->getKey(),
            ]);
        }

        return $device;
    }

    /** The registered device for this client id, without registering a new one. */
    public function find(Restaurant $restaurant, string $deviceId): ?Device
    {
        /** @var Device|null */
        return Device::query()->forRestaurant($restaurant)
            ->where('fingerprint', hash('sha256', $restaurant->getKey().'|'.$deviceId))
            ->first();
    }

    /** @param array{name?: string, type?: string} $data */
    public function update(Actor $actor, Device $device, array $data): Device
    {
        $device->fill($data);
        $dirty = $device->getDirty();
        if ($dirty !== []) {
            $old = array_intersect_key($device->getOriginal(), $dirty);
            $device->save();
            $this->audit->log('device.updated', $actor, $device, $old, $dirty);
        }

        return $device;
    }

    /**
     * A revoked device is locked out at once: its sessions (pinned to it), its waiter app tokens (bound to it)
     * and the "remember me" cookies of the people who used it, which are rotated (audit S1). Remembered sign-ins
     * are also bound to known devices ({@see TrackDevice}).
     */
    public function revoke(Actor $actor, Device $device): Device
    {
        $device->forceFill(['status' => DeviceStatus::Revoked, 'revoked_at' => Carbon::now()])->save();

        User::query()
            ->whereKey(array_values(array_filter([$device->last_user_id, $device->registered_by])))
            ->get()
            ->each(fn (User $user) => $this->access->forgetRememberedBrowsers($user));

        $this->audit->log('device.revoked', $actor, $device, ['status' => DeviceStatus::Active], ['status' => DeviceStatus::Revoked]);

        return $device;
    }

    public function restore(Actor $actor, Device $device): Device
    {
        $device->forceFill(['status' => DeviceStatus::Active, 'revoked_at' => null])->save();
        $this->audit->log('device.restored', $actor, $device, ['status' => DeviceStatus::Revoked], ['status' => DeviceStatus::Active]);

        return $device;
    }

    private function detectType(?string $userAgent): string
    {
        $ua = strtolower((string) $userAgent);

        return match (true) {
            str_contains($ua, 'ipad') || str_contains($ua, 'tablet') => 'tablet',
            str_contains($ua, 'mobile') || str_contains($ua, 'android') || str_contains($ua, 'iphone') => 'phone',
            $ua === '' => 'integration',
            default => 'desktop',
        };
    }

    /**
     * A readable default such as "iPhone · Safari" or "Mac · Chrome". The person using the device is shown
     * separately (last user), so the name describes the hardware only and owners can rename it ("Bar tablet").
     */
    private function defaultName(?string $userAgent): string
    {
        $ua = (string) $userAgent;
        $platform = match (true) {
            str_contains($ua, 'iPhone') => 'iPhone',
            str_contains($ua, 'iPad') => 'iPad',
            str_contains($ua, 'Android') => 'Android',
            str_contains($ua, 'CrOS') => 'Chromebook',
            str_contains($ua, 'Macintosh') => 'Mac',
            str_contains($ua, 'Windows') => 'Windows PC',
            str_contains($ua, 'Linux') => 'Linux PC',
            $ua === '' => 'API client',
            default => 'Device',
        };
        $browser = match (true) {
            $ua === '' => null,
            str_contains($ua, 'Edg/') => 'Edge',
            str_contains($ua, 'Firefox/') || str_contains($ua, 'FxiOS') => 'Firefox',
            str_contains($ua, 'SamsungBrowser') => 'Samsung Internet',
            str_contains($ua, 'Chrome/') || str_contains($ua, 'CriOS') => 'Chrome',
            str_contains($ua, 'Safari/') => 'Safari',
            default => null,
        };

        return mb_substr($browser !== null ? $platform.' · '.$browser : $platform, 0, 120);
    }
}
