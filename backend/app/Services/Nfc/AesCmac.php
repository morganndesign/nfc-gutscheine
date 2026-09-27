<?php

declare(strict_types=1);

namespace App\Services\Nfc;

use InvalidArgumentException;
use RuntimeException;

/**
 * AES-128 CMAC (RFC 4493 / NIST SP 800-38B) implemented on top of OpenSSL AES-ECB.
 */
final class AesCmac
{
    private const BLOCK = 16;

    private const RB = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x87";

    public static function compute(string $key, string $message): string
    {
        if (strlen($key) !== self::BLOCK) {
            throw new InvalidArgumentException('AES-CMAC requires a 16-byte key.');
        }

        [$k1, $k2] = self::subkeys($key);

        $length = strlen($message);
        $blocks = $length === 0 ? 1 : (int) ceil($length / self::BLOCK);
        $lastComplete = $length !== 0 && $length % self::BLOCK === 0;

        $last = substr($message, ($blocks - 1) * self::BLOCK);
        $last = $lastComplete
            ? $last ^ $k1
            : self::pad($last) ^ $k2;

        $x = str_repeat("\x00", self::BLOCK);
        for ($i = 0; $i < $blocks - 1; $i++) {
            $x = self::encryptBlock($key, $x ^ substr($message, $i * self::BLOCK, self::BLOCK));
        }

        return self::encryptBlock($key, $x ^ $last);
    }

    /** @return array{0: string, 1: string} */
    private static function subkeys(string $key): array
    {
        $l = self::encryptBlock($key, str_repeat("\x00", self::BLOCK));
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
        for ($i = self::BLOCK - 1; $i >= 0; $i--) {
            $byte = ord($block[$i]);
            $out = chr((($byte << 1) & 0xFF) | $carry).$out;
            $carry = ($byte & 0x80) !== 0 ? 1 : 0;
        }

        return $out;
    }

    private static function pad(string $partial): string
    {
        return str_pad($partial."\x80", self::BLOCK, "\x00");
    }

    public static function encryptBlock(string $key, string $block): string
    {
        $out = openssl_encrypt($block, 'aes-128-ecb', $key, OPENSSL_RAW_DATA | OPENSSL_ZERO_PADDING);
        if ($out === false) {
            throw new RuntimeException('AES encryption failed.');
        }

        return $out;
    }

    public static function decryptCbc(string $key, string $data, ?string $iv = null): string
    {
        $out = openssl_decrypt($data, 'aes-128-cbc', $key, OPENSSL_RAW_DATA | OPENSSL_ZERO_PADDING, $iv ?? str_repeat("\x00", self::BLOCK));
        if ($out === false) {
            throw new RuntimeException('AES decryption failed.');
        }

        return $out;
    }
}
