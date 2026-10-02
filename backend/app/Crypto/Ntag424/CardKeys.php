<?php

declare(strict_types=1);

namespace App\Crypto\Ntag424;

use App\Crypto\CryptoProvider;
use App\Crypto\KeyReference;
use InvalidArgumentException;

/**
 * The keys of the cards of one batch (architecture §9.2). Card keys are never stored: they are derived on
 * demand in two AN10922 levels, root (in the provider) → batch → card; K1 in one level, root → key set.
 *
 * | Slot | Purpose                          | Key                                  |
 * |------|----------------------------------|--------------------------------------|
 * | K0   | change keys and settings         | per card: AN10922(batch(root-k0))    |
 * | K1   | encrypt UID + counter (SUN `e`)  | per key set: AN10922(root-k1)        |
 * | K2   | SUN MAC (`m`)                    | per card: AN10922(batch(root-k2))    |
 * | K3   | live challenge at till / binding | per card: AN10922(batch(root-k3))    |
 */
final class CardKeys
{
    private const SYSTEM_IDENTIFIER = 'GiftCardPro';

    /** The longest key set version K1's AN10922 input (`K` ‖ version ‖ 01 ‖ system identifier, ≤ 31 bytes) takes. */
    public const MAX_VERSION_LENGTH = 31 - 2 - 11;

    /** @var array<int, string> slot => batch key (ephemeral, for this object's lifetime) */
    private array $batchKeys = [];

    /**
     * @param  string  $keySetVersion  e.g. `ks-2026-01`
     * @param  string  $batchId  the batch UUID
     */
    public function __construct(
        private readonly CryptoProvider $provider,
        private readonly string $keySetVersion,
        private readonly string $batchId,
    ) {
        new KeyReference($keySetVersion);
        if (preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/', $batchId) !== 1) {
            throw new InvalidArgumentException('The batch id is a UUID.');
        }
    }

    /** K1: shared by the key set, it opens PICCData before the UID is known. */
    public function metaReadKey(): string
    {
        return self::keySetMetaReadKey($this->provider, $this->keySetVersion);
    }

    /** K1 of a key set, without a batch: the tap is decrypted before the card (and so its batch) is known. */
    public static function keySetMetaReadKey(CryptoProvider $provider, string $keySetVersion): string
    {
        return An10922::fromProvider($provider, KeyReference::of($keySetVersion, 'root-k1'), 'K'.$keySetVersion."\x01".self::SYSTEM_IDENTIFIER);
    }

    /** K2 of the card with this UID. */
    public function sdmMacKey(string $uid): string
    {
        return $this->cardKey(2, $uid);
    }

    /** K3 of the card with this UID: the live challenge. */
    public function challengeKey(string $uid): string
    {
        return $this->cardKey(3, $uid);
    }

    /** K0 of the card with this UID: personalisation only. */
    public function masterKey(string $uid): string
    {
        return $this->cardKey(0, $uid);
    }

    private function cardKey(int $slot, string $uid): string
    {
        if (strlen($uid) !== 7) {
            throw new InvalidArgumentException('An NTAG 424 DNA UID is 7 bytes.');
        }

        return An10922::fromKey($this->batchKey($slot), $uid.chr($slot).self::SYSTEM_IDENTIFIER);
    }

    private function batchKey(int $slot): string
    {
        return $this->batchKeys[$slot] ??= An10922::fromProvider(
            $this->provider,
            KeyReference::of($this->keySetVersion, 'root-k'.$slot),
            'B'.hex2bin(str_replace('-', '', $this->batchId)).chr($slot),
        );
    }

    /** @return array<string, string> */
    public function __debugInfo(): array
    {
        return ['keySet' => $this->keySetVersion, 'batch' => $this->batchId];
    }
}
