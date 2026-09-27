<?php

declare(strict_types=1);

namespace App\Services\Nfc;

use App\Exceptions\Domain\NfcSignatureInvalidException;
use Throwable;

/**
 * Verifies NTAG 424 DNA SUN messages (NXP AN12196, "SDM with encrypted PICC data").
 *
 * The tag is configured to mirror into its NDEF URL:
 *   https://app.example.com/c/{public_token}?picc={32 hex chars}&cmac={16 hex chars}
 *
 * - PICCData is AES-128-CBC encrypted with the SDM Meta Read key and contains the 7-byte
 *   UID and the 24-bit SDM read counter, which increments on every tap.
 * - The CMAC is computed with a session key derived from the SDM File Read key, UID and counter.
 *
 * A valid MAC proves the read came from the genuine chip; a strictly increasing counter
 * (checked by the caller) proves it is not a replayed URL.
 */
final class Ntag424SunVerifier
{
    private const PICC_TAG_UID_MIRROR = 0x80;

    private const PICC_TAG_COUNTER_MIRROR = 0x40;

    public function __construct(
        private readonly ?string $metaReadKeyHex,
        private readonly ?string $fileReadKeyHex,
        private readonly bool $diversifyKeys = true,
    ) {}

    public static function fromConfig(): self
    {
        /** @var array{meta_read_key: ?string, file_read_key: ?string, diversify_keys: bool} $config */
        $config = config('giftcard.nfc.ntag424');

        return new self($config['meta_read_key'], $config['file_read_key'], $config['diversify_keys']);
    }

    public function isConfigured(): bool
    {
        return $this->validKey($this->metaReadKeyHex) && $this->validKey($this->fileReadKeyHex);
    }

    /**
     * @param  string  $piccHex  Encrypted PICCData (32 hex chars)
     * @param  string  $cmacHex  Truncated SDM MAC (16 hex chars)
     * @param  string  $macInput  Bytes covered by the MAC (empty when SDMMACInputOffset == SDMMACOffset)
     */
    public function verify(string $piccHex, string $cmacHex, string $macInput = ''): SunMessage
    {
        if (! $this->isConfigured()) {
            throw new NfcSignatureInvalidException('Secure NFC (NTAG 424 DNA) keys are not configured on the server.');
        }

        if (! preg_match('/^[0-9A-Fa-f]{32}$/', $piccHex) || ! preg_match('/^[0-9A-Fa-f]{16}$/', $cmacHex)) {
            throw new NfcSignatureInvalidException;
        }

        try {
            $picc = AesCmac::decryptCbc((string) hex2bin((string) $this->metaReadKeyHex), (string) hex2bin($piccHex));
        } catch (Throwable) {
            throw new NfcSignatureInvalidException;
        }

        $tag = ord($picc[0]);
        $uidLength = $tag & 0x0F;

        if (($tag & self::PICC_TAG_UID_MIRROR) === 0 || ($tag & self::PICC_TAG_COUNTER_MIRROR) === 0 || $uidLength !== 7) {
            throw new NfcSignatureInvalidException;
        }

        $uid = substr($picc, 1, 7);
        $counterBytes = substr($picc, 8, 3);
        $counter = ord($counterBytes[0]) | (ord($counterBytes[1]) << 8) | (ord($counterBytes[2]) << 16);

        $expected = $this->computeMac($uid, $counterBytes, $macInput);

        if (! hash_equals(strtoupper($expected), strtoupper($cmacHex))) {
            throw new NfcSignatureInvalidException;
        }

        return new SunMessage(strtoupper(bin2hex($uid)), $counter);
    }

    /**
     * Computes the truncated SDM MAC (hex). Public for provisioning tools and tests.
     */
    public function computeMac(string $uid, string $counterBytesLsbFirst, string $macInput = ''): string
    {
        $fileKey = $this->fileKeyFor($uid);

        // SV2 = 3C C3 00 01 00 80 || UID || SDMReadCtr  (16 bytes)
        $sv2 = "\x3C\xC3\x00\x01\x00\x80".$uid.$counterBytesLsbFirst;
        $sessionKey = AesCmac::compute($fileKey, $sv2);
        $full = AesCmac::compute($sessionKey, $macInput);

        // MACt: the odd-indexed bytes of the full 16-byte CMAC.
        $truncated = '';
        for ($i = 1; $i < 16; $i += 2) {
            $truncated .= $full[$i];
        }

        return strtoupper(bin2hex($truncated));
    }

    private function fileKeyFor(string $uid): string
    {
        $master = (string) hex2bin((string) $this->fileReadKeyHex);

        if (! $this->diversifyKeys) {
            return $master;
        }

        return substr(hash_hmac('sha256', $uid, $master, true), 0, 16);
    }

    private function validKey(?string $hex): bool
    {
        return is_string($hex) && preg_match('/^[0-9A-Fa-f]{32}$/', $hex) === 1;
    }
}
