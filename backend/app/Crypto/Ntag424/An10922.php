<?php

declare(strict_types=1);

namespace App\Crypto\Ntag424;

use App\Crypto\CryptoProvider;
use App\Crypto\KeyReference;
use App\Crypto\Primitives\Aes;
use App\Crypto\Primitives\Cmac;
use InvalidArgumentException;

/**
 * NXP AN10922 AES-128 key diversification: CMAC over 0x01 ‖ M, where the input is always padded to 32 bytes
 * (0x80 00… and subkey K2 when M is shorter than 31 bytes). This is not a plain CMAC call.
 */
final class An10922
{
    private const MAX_INPUT = 31;

    /** Diversifies a provider-held master key. The derived key is ephemeral (per card, per operation). */
    public static function fromProvider(CryptoProvider $provider, KeyReference $master, string $input): string
    {
        return self::derive(static fn (string $data): string => $provider->encryptCbc($master, Aes::ZERO_IV, $data), $input);
    }

    /** Diversifies an ephemeral key (the second level of a two-level derivation). */
    public static function fromKey(string $master, string $input): string
    {
        return self::derive(static fn (string $data): string => Aes::encryptCbc($master, Aes::ZERO_IV, $data), $input);
    }

    /** @param callable(string): string $encryptCbcZeroIv */
    private static function derive(callable $encryptCbcZeroIv, string $input): string
    {
        if ($input === '' || strlen($input) > self::MAX_INPUT) {
            throw new InvalidArgumentException('AN10922 diversification input must be 1–31 bytes.');
        }

        return substr($encryptCbcZeroIv(Cmac::prepared($encryptCbcZeroIv, "\x01".$input, 32)), -Aes::BLOCK);
    }
}
