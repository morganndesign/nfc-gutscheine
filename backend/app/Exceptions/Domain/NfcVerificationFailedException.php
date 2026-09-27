<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/** The tag read back after writing does not carry exactly the card's URL, or is a different chip. */
final class NfcVerificationFailedException extends DomainException
{
    public function errorCode(): string
    {
        return 'NFC_VERIFICATION_FAILED';
    }

    protected function defaultMessage(): string
    {
        return 'The tag could not be verified. Nothing was saved — please program it again.';
    }
}
