<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/** The chip (UID) or the link on the tag belongs to another usable card. */
final class NfcTagInUseException extends DomainException
{
    public function errorCode(): string
    {
        return 'NFC_TAG_IN_USE';
    }

    public function status(): int
    {
        return 409;
    }

    protected function defaultMessage(): string
    {
        return 'This NFC tag is already linked to another active card.';
    }
}
