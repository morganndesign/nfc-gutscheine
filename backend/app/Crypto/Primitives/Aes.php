<?php

declare(strict_types=1);

namespace App\Crypto\Primitives;

use App\Crypto\CryptoProvider;
use InvalidArgumentException;
use RuntimeException;

/**
 * AES-128 in software, for **ephemeral** keys only: per-card keys derived by the provider and session keys that
 * exist for one card interaction. Long-lived keys are only ever used through {@see CryptoProvider}.
 */
final class Aes
{
    public const BLOCK = 16;

    public const ZERO_IV = "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";

    public static function encryptCbc(string $key, string $iv, string $data): string
    {
        self::check($key, $iv, $data);

        return self::run(openssl_encrypt($data, self::cipher($key), $key, OPENSSL_RAW_DATA | OPENSSL_ZERO_PADDING, $iv));
    }

    public static function decryptCbc(string $key, string $iv, string $data): string
    {
        self::check($key, $iv, $data);

        return self::run(openssl_decrypt($data, self::cipher($key), $key, OPENSSL_RAW_DATA | OPENSSL_ZERO_PADDING, $iv));
    }

    public static function encryptBlock(string $key, string $block): string
    {
        return self::encryptCbc($key, self::ZERO_IV, $block);
    }

    public static function assertCbcInput(string $iv, string $data): void
    {
        if (strlen($iv) !== self::BLOCK) {
            throw new InvalidArgumentException('AES-CBC needs a 16-byte IV.');
        }
        if ($data === '' || strlen($data) % self::BLOCK !== 0) {
            throw new InvalidArgumentException('AES-CBC without padding needs a non-empty multiple of 16 bytes.');
        }
    }

    private static function check(string $key, string $iv, string $data): void
    {
        if (! in_array(strlen($key), [16, 32], true)) {
            throw new InvalidArgumentException('AES needs a 16- or 32-byte key.');
        }
        self::assertCbcInput($iv, $data);
    }

    private static function cipher(string $key): string
    {
        return strlen($key) === 32 ? 'aes-256-cbc' : 'aes-128-cbc';
    }

    private static function run(string|false $out): string
    {
        if ($out === false) {
            throw new RuntimeException('AES operation failed.');
        }

        return $out;
    }
}
