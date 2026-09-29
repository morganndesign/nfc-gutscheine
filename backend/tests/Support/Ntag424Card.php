<?php

declare(strict_types=1);

namespace Tests\Support;

use App\Crypto\CryptoProvider;
use App\Crypto\Ntag424\CardKeys;
use App\Crypto\Ntag424\Ev2FirstAuthentication;
use App\Crypto\Ntag424\SunVerifier;
use App\Crypto\Primitives\Aes;

/**
 * A personalised NTAG 424 DNA card, as the phone sees it: every NDEF read produces a fresh SUN URL (counter + 1),
 * and it answers AuthenticateEV2First with its own K3. Keys are derived exactly as the personalisation writes
 * them, so the server under test has no shortcut.
 */
final class Ntag424Card
{
    private int $counter = 0;

    private ?string $rndB = null;

    public function __construct(
        private readonly CryptoProvider $provider,
        private readonly CardKeys $keys,
        public readonly string $uid,
        private readonly string $keySet,
        private readonly string $origin = 'https://t.giftcardpro.at',
    ) {}

    public function uidHex(): string
    {
        return strtoupper(bin2hex($this->uid));
    }

    /** ISO ReadBinary of the NDEF file: the URI with a fresh e and m. */
    public function readNdefUrl(): string
    {
        $this->counter++;
        $ctr = chr($this->counter & 0xFF).chr(($this->counter >> 8) & 0xFF).chr(($this->counter >> 16) & 0xFF);
        $e = $this->provider->encryptCbc($this->keys->metaReadKey(), Aes::ZERO_IV, "\xC7".$this->uid.$ctr.random_bytes(5));

        return sprintf('%s/%s?e=%s&m=%s', $this->origin, $this->keySet, strtoupper(bin2hex($e)), SunVerifier::mac($this->keys->sdmMacKey($this->uid), $this->uid, $ctr));
    }

    /** 90 71 00 00 02 03 00 00 → E(K3, RndB) ‖ 91 AF */
    public function authenticateFirst(): string
    {
        $this->rndB = random_bytes(16);

        return Aes::encryptCbc($this->keys->challengeKey($this->uid), Aes::ZERO_IV, $this->rndB)."\x91\xAF";
    }

    /** 90 AF 00 00 20 ‖ E(K3, RndA ‖ RndB') ‖ 00 → E(K3, TI ‖ RndA' ‖ PDcap2 ‖ PCDcap2) ‖ 91 00, or 91 AE */
    public function transceive(string $apdu): string
    {
        if (strlen($apdu) !== 38 || substr($apdu, 0, 5) !== "\x90\xAF\x00\x00\x20" || $this->rndB === null) {
            return "\x91\x7E";
        }
        $key = $this->keys->challengeKey($this->uid);
        $plain = Aes::decryptCbc($key, Aes::ZERO_IV, substr($apdu, 5, 32));
        $rndB = $this->rndB;
        $this->rndB = null;
        if (! hash_equals(Ev2FirstAuthentication::rotate($rndB), substr($plain, 16))) {
            return "\x91\xAE";
        }

        return Aes::encryptCbc($key, Aes::ZERO_IV, random_bytes(4).Ev2FirstAuthentication::rotate(substr($plain, 0, 16)).str_repeat("\0", 12))."\x91\x00";
    }
}
