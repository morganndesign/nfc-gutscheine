<?php

declare(strict_types=1);

namespace App\Services\Nfc;

/**
 * Verified result of an NTAG 424 DNA Secure Unique NFC (SUN) read.
 */
final readonly class SunMessage
{
    public function __construct(
        public string $uid,
        public int $readCounter,
    ) {}
}
