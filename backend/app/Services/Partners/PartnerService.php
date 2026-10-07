<?php

declare(strict_types=1);

namespace App\Services\Partners;

use App\Enums\DeviceStatus;
use App\Exceptions\Domain\DeviceRevokedException;
use App\Exceptions\Domain\LinkCodeInvalidException;
use App\Exceptions\Domain\RestaurantSuspendedException;
use App\Models\Device;
use App\Models\Partner;
use App\Models\PartnerConnection;
use App\Models\PartnerLinkCode;
use App\Models\Restaurant;
use App\Services\Audit\AuditLogger;
use App\Support\Actor;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use SensitiveParameter;

/**
 * POS partners (decision 2026-10-07): the till system of a POS company redeems vouchers and gift cards inside its own
 * app. The company holds one partner key; each restaurant connects it with a one-time code from its dashboard and
 * can disconnect it at any time. Each till of the partner is a device of the restaurant (type `pos`).
 */
final class PartnerService
{
    /** Letters and digits that cannot be confused when read aloud or typed (no 0/O, 1/I/L). */
    private const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

    private const TOUCH_SECONDS = 60;

    public function __construct(private readonly AuditLogger $audit) {}

    // ------------------------------------------------------------------ platform

    /** @return array{Partner, string} The partner and its key (shown once). */
    public function create(string $name, ?string $contactEmail): array
    {
        $key = self::newKey();
        $partner = Partner::query()->create([
            'name' => mb_substr(trim($name), 0, 120),
            'contact_email' => $contactEmail,
            'key_hash' => Partner::hashKey($key),
            'key_prefix' => substr($key, 0, 12),
            'status' => 'active',
        ]);
        $this->audit->log('partner.created', Actor::system(), $partner, null, ['name' => $partner->name]);

        return [$partner, $key];
    }

    /** A new key; the old one stops at once. */
    public function rotateKey(Partner $partner): string
    {
        $key = self::newKey();
        $partner->forceFill(['key_hash' => Partner::hashKey($key), 'key_prefix' => substr($key, 0, 12)])->save();
        $this->audit->log('partner.key_rotated', Actor::system(), $partner);

        return $key;
    }

    public function setActive(Partner $partner, bool $active): void
    {
        $partner->forceFill(['status' => $active ? 'active' : 'suspended'])->save();
        $this->audit->log($active ? 'partner.activated' : 'partner.suspended', Actor::system(), $partner);
    }

    public function authenticate(#[SensitiveParameter] string $key): ?Partner
    {
        if (! str_starts_with($key, Partner::KEY_PREFIX) || strlen($key) > 100) {
            return null;
        }
        /** @var Partner|null $partner */
        $partner = Partner::query()->where('key_hash', Partner::hashKey($key))->first();
        if ($partner === null || ! $partner->isActive()) {
            return null;
        }
        if ($partner->last_used_at === null || $partner->last_used_at->diffInSeconds(Carbon::now()) > self::TOUCH_SECONDS) {
            Partner::query()->whereKey($partner->getKey())->update(['last_used_at' => Carbon::now()]);
        }

        return $partner;
    }

    // ------------------------------------------------------------------ restaurant

    /** @return array{code: string, expires_at: Carbon} A one-time code for the POS company (shown once). */
    public function createLinkCode(Actor $actor, Restaurant $restaurant): array
    {
        $code = '';
        for ($i = 0; $i < 8; $i++) {
            $code .= self::CODE_ALPHABET[random_int(0, strlen(self::CODE_ALPHABET) - 1)];
        }
        $expires = Carbon::now()->addHours((int) config('giftcard.partner.link_code_hours', 24));
        $link = new PartnerLinkCode;
        $link->forceFill([
            'restaurant_id' => $restaurant->getKey(),
            'code_hash' => self::hashCode($code),
            'created_by' => $actor->userId(),
            'expires_at' => $expires,
        ])->save();
        $this->audit->log('partner.code_created', $actor, $link, null, ['expires_at' => $expires->toIso8601String()]);

        return ['code' => substr($code, 0, 4).'-'.substr($code, 4), 'expires_at' => $expires];
    }

    public function disconnect(Actor $actor, PartnerConnection $connection): PartnerConnection
    {
        if ($connection->isActive()) {
            $connection->forceFill(['status' => 'revoked', 'revoked_at' => Carbon::now(), 'revoked_by' => $actor->userId()])->save();
            $this->audit->log('partner.disconnected', $actor, $connection, ['status' => 'active'], ['status' => 'revoked'], [
                'partner' => $connection->partner()->value('name'),
            ]);
        }

        return $connection;
    }

    // ------------------------------------------------------------------ partner

    /** The POS company redeems a restaurant's code: the restaurant is connected (again). */
    public function connect(Partner $partner, Actor $actor, #[SensitiveParameter] string $code): PartnerConnection
    {
        return DB::transaction(function () use ($partner, $actor, $code): PartnerConnection {
            /** @var PartnerLinkCode|null $link */
            $link = PartnerLinkCode::query()->withoutGlobalScopes()->where('code_hash', self::hashCode($code))->lockForUpdate()->first();
            if ($link === null || $link->used_at !== null || $link->expires_at->isPast()) {
                throw new LinkCodeInvalidException;
            }
            /** @var Restaurant $restaurant */
            $restaurant = Restaurant::query()->findOrFail($link->restaurant_id);
            if (! $restaurant->isActive()) {
                throw new RestaurantSuspendedException;
            }
            $link->forceFill(['used_at' => Carbon::now(), 'used_by_partner_id' => $partner->getKey()])->save();

            /** @var PartnerConnection|null $connection */
            $connection = PartnerConnection::query()->withoutGlobalScopes()
                ->where('partner_id', $partner->getKey())->where('restaurant_id', $restaurant->getKey())->lockForUpdate()->first();
            $connection ??= new PartnerConnection;
            $connection->forceFill([
                'partner_id' => $partner->getKey(),
                'restaurant_id' => $restaurant->getKey(),
                'status' => 'active',
                'connected_by' => $link->created_by,
                'connected_at' => Carbon::now(),
                'revoked_by' => null,
                'revoked_at' => null,
            ])->save();
            $this->audit->log('partner.connected', $actor, $connection, null, ['partner' => $partner->name], restaurantId: (string) $restaurant->getKey());

            return $connection->setRelation('restaurant', $restaurant)->setRelation('partner', $partner);
        });
    }

    /** The partner's till in this restaurant, created on its first request; a revoked till is refused. */
    public function terminal(PartnerConnection $connection, string $terminalId, ?string $name, ?string $ip): Device
    {
        $fingerprint = hash('sha256', 'pos:'.$connection->partner_id.':'.$terminalId);
        /** @var Device|null $device */
        $device = Device::query()->withoutGlobalScopes()->withTrashed()
            ->where('restaurant_id', $connection->restaurant_id)->where('fingerprint', $fingerprint)->first();

        if ($device === null) {
            // A new till id is a new device (with its own failure throttle): a partner cannot mint them without end.
            $max = (int) config('giftcard.partner.max_terminals', 50);
            if (Device::query()->withoutGlobalScopes()->where('partner_connection_id', $connection->getKey())->count() >= $max) {
                throw ValidationException::withMessages(['X-Terminal-Id' => "This restaurant already has {$max} tills of your system. Reuse a till id, or ask the restaurant to remove old tills."]);
            }
            $label = $name !== null && trim($name) !== '' ? trim($name) : $terminalId;
            $device = new Device;
            $device->forceFill([
                'restaurant_id' => $connection->restaurant_id,
                'partner_connection_id' => $connection->getKey(),
                'name' => mb_substr($connection->partner->name.' · '.$label, 0, 120),
                'type' => 'pos',
                'fingerprint' => $fingerprint,
                'platform' => 'pos',
                'status' => DeviceStatus::Active,
                'last_seen_at' => Carbon::now(),
                'last_ip' => $ip,
            ])->save();
            $this->audit->log('device.registered', new Actor(null, $device, $ip), $device, null, ['name' => $device->name], [
                'partner' => $connection->partner->name,
            ], restaurantId: $connection->restaurant_id);

            return $device;
        }
        if ($device->trashed() || ! $device->isActive()) {
            throw new DeviceRevokedException;
        }
        if ($device->last_seen_at === null || $device->last_seen_at->diffInSeconds(Carbon::now()) > self::TOUCH_SECONDS) {
            Device::query()->withoutGlobalScopes()->whereKey($device->getKey())->update(['last_seen_at' => Carbon::now(), 'last_ip' => $ip]);
        }

        return $device;
    }

    private static function newKey(): string
    {
        return Partner::KEY_PREFIX.Str::random(40);
    }

    private static function hashCode(string $code): string
    {
        return hash('sha256', 'partner-link:'.strtoupper((string) preg_replace('/[^A-Za-z0-9]/', '', $code)));
    }
}
