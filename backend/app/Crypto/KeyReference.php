<?php

declare(strict_types=1);

namespace App\Crypto;

use InvalidArgumentException;
use Stringable;

/**
 * The name of a key held by the {@see CryptoProvider}, e.g. `ks-2026-01/sdm-meta-read`: a key set and the
 * key's role in it. Names are metadata and may be stored and logged; the material never is.
 */
final readonly class KeyReference implements Stringable
{
    private const PATTERN = '/^[a-z0-9][a-z0-9._-]{0,62}(\/[a-z0-9][a-z0-9._-]{0,62}){0,3}$/';

    public function __construct(public string $name)
    {
        if (preg_match(self::PATTERN, $name) !== 1) {
            throw new InvalidArgumentException("Invalid key reference \"{$name}\".");
        }
    }

    public static function of(string $keySet, string $role): self
    {
        return new self($keySet.'/'.$role);
    }

    public function __toString(): string
    {
        return $this->name;
    }
}
