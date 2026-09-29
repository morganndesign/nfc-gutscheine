<?php

declare(strict_types=1);

namespace App\Crypto\Primitives;

use App\Crypto\CryptoProvider;
use App\Crypto\KeyReference;

/**
 * AES-CMAC (RFC 4493 / NIST SP 800-38B), composed from AES-CBC so that it runs the same way with a software
 * key and with a provider-held key: the subkeys come from one encryption of the zero block, the tag is the last
 * block of a CBC encryption with a zero IV.
 */
final class Cmac
{
    private const RB = "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x87";

    /** CMAC with a software (ephemeral) key. */
    public static function compute(string $key, string $message): string
    {
        return self::tag(
            static fn (string $data): string => Aes::encryptCbc($key, Aes::ZERO_IV, $data),
            $message,
        );
    }

    /** CMAC with a provider-held key: the key material never leaves the provider. */
    public static function withProvider(CryptoProvider $provider, KeyReference $key, string $message): string
    {
        return self::tag(
            static fn (string $data): string => $provider->encryptCbc($key, Aes::ZERO_IV, $data),
            $message,
        );
    }

    /**
     * The blocks CBC-MAC runs over for a message padded to [$length] bytes the CMAC way: complete → last block
     * XOR K1; partial → 0x80 00… padding, last block XOR K2. AN10922 uses this with a fixed length of 32.
     *
     * @param  callable(string): string  $encryptCbcZeroIv
     */
    public static function prepared(callable $encryptCbcZeroIv, string $message, ?int $length = null): string
    {
        [$k1, $k2] = self::subkeys($encryptCbcZeroIv(str_repeat("\0", Aes::BLOCK)));

        $messageLength = strlen($message);
        $length ??= $messageLength === 0 ? Aes::BLOCK : (int) (ceil($messageLength / Aes::BLOCK) * Aes::BLOCK);
        $complete = $messageLength === $length && $messageLength !== 0;
        $padded = $complete ? $message : str_pad($message."\x80", $length, "\0");

        $lastStart = $length - Aes::BLOCK;

        return substr($padded, 0, $lastStart).(substr($padded, $lastStart) ^ ($complete ? $k1 : $k2));
    }

    /** @param callable(string): string $encryptCbcZeroIv */
    private static function tag(callable $encryptCbcZeroIv, string $message): string
    {
        $cipher = $encryptCbcZeroIv(self::prepared($encryptCbcZeroIv, $message));

        return substr($cipher, -Aes::BLOCK);
    }

    /** @return array{0: string, 1: string} */
    private static function subkeys(string $l): array
    {
        $k1 = self::shiftLeft($l);
        if ((ord($l[0]) & 0x80) !== 0) {
            $k1 ^= self::RB;
        }
        $k2 = self::shiftLeft($k1);
        if ((ord($k1[0]) & 0x80) !== 0) {
            $k2 ^= self::RB;
        }

        return [$k1, $k2];
    }

    private static function shiftLeft(string $block): string
    {
        $out = '';
        $carry = 0;
        for ($i = Aes::BLOCK - 1; $i >= 0; $i--) {
            $byte = ord($block[$i]);
            $out = chr((($byte << 1) & 0xFF) | $carry).$out;
            $carry = ($byte & 0x80) !== 0 ? 1 : 0;
        }

        return $out;
    }
}
