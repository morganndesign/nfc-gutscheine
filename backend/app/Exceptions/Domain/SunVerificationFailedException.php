<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/**
 * An NTAG 424 DNA SUN message (encrypted PICC data + CMAC) did not verify. Used by the tap verification of
 * Phase 3; SUN alone never spends (architecture §10.3).
 */
final class SunVerificationFailedException extends DomainException
{
    public function errorCode(): string
    {
        return 'SUN_VERIFICATION_FAILED';
    }

    public function status(): int
    {
        return 403;
    }

    protected function defaultMessage(): string
    {
        return 'The card could not be verified.';
    }
}
