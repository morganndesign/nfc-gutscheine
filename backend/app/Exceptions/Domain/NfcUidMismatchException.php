<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class NfcUidMismatchException extends DomainException
{
    public function errorCode(): string
    {
        return 'NFC_UID_MISMATCH';
    }

    public function status(): int
    {
        return 403;
    }

    protected function defaultMessage(): string
    {
        return 'The NFC chip does not match the registered card. The card may be cloned.';
    }
}
