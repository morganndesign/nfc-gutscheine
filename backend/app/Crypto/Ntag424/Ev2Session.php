<?php

declare(strict_types=1);

namespace App\Crypto\Ntag424;

/** The result of AuthenticateEV2First: transaction identifier and session keys for secure messaging. */
final readonly class Ev2Session
{
    public function __construct(
        /** Transaction identifier (4 bytes). */
        public string $transactionId,
        public string $encryptionKey,
        public string $macKey,
        /** PDcap2 (6 bytes) as sent by the card. */
        public string $pdCap2,
        public string $pcdCap2,
    ) {}

    /** @return array<string, string> */
    public function __debugInfo(): array
    {
        return ['transactionId' => strtoupper(bin2hex($this->transactionId))];
    }
}
