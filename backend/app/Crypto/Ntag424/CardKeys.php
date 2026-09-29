<?php

declare(strict_types=1);

namespace App\Crypto\Ntag424;

use App\Crypto\CryptoProvider;
use App\Crypto\KeyReference;
use Closure;
use InvalidArgumentException;

/**
 * The keys of one card, derived from its key set (architecture: per-card keys, AN10922). The key set holds one
 * master per role; each card's key is the master diversified with the card's UID, the key number and the
 * platform's system identifier. The SDM meta-read key is shared by the key set: it has to open PICCData before
 * the UID is known.
 */
final class CardKeys
{
    private const SYSTEM_IDENTIFIER = 'GiftCardPro';

    public function __construct(
        private readonly CryptoProvider $provider,
        private readonly string $keySet,
    ) {
        new KeyReference($keySet);
    }

    public function metaReadKey(): KeyReference
    {
        return KeyReference::of($this->keySet, 'sdm-meta-read');
    }

    /** @return Closure(string): string UID (7 bytes) → the card's SDM file-read key */
    public function fileReadKey(): Closure
    {
        return fn (string $uid): string => $this->derive('sdm-file-read', $uid, 0x03);
    }

    /** The card's application key number `$keyNumber` (0–4), for EV2 authentication. */
    public function applicationKey(string $uid, int $keyNumber): string
    {
        if ($keyNumber < 0 || $keyNumber > 4) {
            throw new InvalidArgumentException('NTAG 424 DNA application keys are numbered 0–4.');
        }

        return $this->derive('app-key-'.$keyNumber, $uid, $keyNumber);
    }

    private function derive(string $role, string $uid, int $keyNumber): string
    {
        if (strlen($uid) !== 7) {
            throw new InvalidArgumentException('An NTAG 424 DNA UID is 7 bytes.');
        }

        return An10922::fromProvider($this->provider, KeyReference::of($this->keySet, $role), $uid.chr($keyNumber).self::SYSTEM_IDENTIFIER);
    }
}
