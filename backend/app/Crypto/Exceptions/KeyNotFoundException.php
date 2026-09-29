<?php

declare(strict_types=1);

namespace App\Crypto\Exceptions;

use App\Crypto\KeyReference;
use RuntimeException;

final class KeyNotFoundException extends RuntimeException
{
    public static function for(KeyReference $key): self
    {
        return new self("The crypto provider holds no key named \"{$key}\".");
    }
}
