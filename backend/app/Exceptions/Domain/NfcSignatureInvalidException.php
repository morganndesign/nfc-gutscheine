<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class NfcSignatureInvalidException extends DomainException
{
    public function errorCode(): string
    {
        return 'NFC_SIGNATURE_INVALID';
    }

    public function status(): int
    {
        return 403;
    }

    protected function defaultMessage(): string
    {
        return 'The secure NFC signature could not be verified.';
    }
}
