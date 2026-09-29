<?php

declare(strict_types=1);

namespace App\Crypto\Ntag424;

/** A verified NTAG 424 DNA Secure Unique NFC read: the chip's UID and its SDM read counter. */
final readonly class SunMessage
{
    public function __construct(
        /** 7-byte UID, upper-case hex. */
        public string $uid,
        public int $readCounter,
    ) {}
}
