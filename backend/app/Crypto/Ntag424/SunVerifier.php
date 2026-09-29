<?php

declare(strict_types=1);

namespace App\Crypto\Ntag424;

use App\Crypto\CryptoProvider;
use App\Crypto\KeyReference;
use App\Crypto\Primitives\Aes;
use App\Crypto\Primitives\Cmac;
use App\Exceptions\Domain\SunVerificationFailedException;
use Closure;
use Throwable;

/**
 * Verifies NTAG 424 DNA SUN messages, "SDM with encrypted PICC data" (NXP AN12196): the tap URL carries
 * `e` (PICCData encrypted with the SDM meta-read key: UID and read counter) and `m` (the truncated MAC under a
 * session key derived from the card's SDM file-read key, UID and counter).
 *
 * A valid MAC proves the read came from the genuine chip; the caller compares the counter with the last one
 * seen (compare-and-set) to refuse replayed URLs. SUN alone never spends.
 */
final class SunVerifier
{
    private const UID_MIRRORED = 0x80;

    private const COUNTER_MIRRORED = 0x40;

    public function __construct(private readonly CryptoProvider $provider) {}

    /**
     * @param  Closure(string): string  $fileReadKey  The card's SDM file-read key for a 7-byte UID (ephemeral)
     * @param  string  $macInput  Bytes covered by the MAC (empty when SDMMACInputOffset = SDMMACOffset)
     */
    public function verify(KeyReference $metaReadKey, Closure $fileReadKey, string $encryptedPiccHex, string $macHex, string $macInput = ''): SunMessage
    {
        if (preg_match('/^[0-9A-Fa-f]{32}$/', $encryptedPiccHex) !== 1 || preg_match('/^[0-9A-Fa-f]{16}$/', $macHex) !== 1) {
            throw new SunVerificationFailedException;
        }

        $picc = $this->provider->decryptCbc($metaReadKey, Aes::ZERO_IV, (string) hex2bin($encryptedPiccHex));
        $tag = ord($picc[0]);
        if (($tag & self::UID_MIRRORED) === 0 || ($tag & self::COUNTER_MIRRORED) === 0 || ($tag & 0x0F) !== 7) {
            throw new SunVerificationFailedException;
        }

        $uid = substr($picc, 1, 7);
        $counter = substr($picc, 8, 3);

        try {
            $expected = self::mac($fileReadKey($uid), $uid, $counter, $macInput);
        } catch (Throwable) {
            throw new SunVerificationFailedException;
        }
        if (! hash_equals($expected, strtoupper($macHex))) {
            throw new SunVerificationFailedException;
        }

        return new SunMessage(strtoupper(bin2hex($uid)), ord($counter[0]) | (ord($counter[1]) << 8) | (ord($counter[2]) << 16));
    }

    /**
     * The truncated SDM MAC (upper-case hex) for a UID and counter (3 bytes, LSB first). Used by the verifier,
     * the personalisation station's QA and tests.
     */
    public static function mac(string $fileReadKey, string $uid, string $counterLsbFirst, string $macInput = ''): string
    {
        // SV2 = 3C C3 00 01 00 80 ‖ UID ‖ SDMReadCtr
        $sessionKey = Cmac::compute($fileReadKey, "\x3C\xC3\x00\x01\x00\x80".$uid.$counterLsbFirst);
        $full = Cmac::compute($sessionKey, $macInput);

        $truncated = '';
        for ($i = 1; $i < 16; $i += 2) {
            $truncated .= $full[$i];
        }

        return strtoupper(bin2hex($truncated));
    }
}
