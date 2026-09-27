<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/** A programming step refers to an attempt that does not exist, belongs to another card or is already closed. */
final class NfcAttemptInvalidException extends DomainException
{
    public function errorCode(): string
    {
        return 'NFC_ATTEMPT_INVALID';
    }

    public function status(): int
    {
        return 409;
    }

    protected function defaultMessage(): string
    {
        return 'This programming attempt is no longer valid. Tap the tag again to start over.';
    }
}
