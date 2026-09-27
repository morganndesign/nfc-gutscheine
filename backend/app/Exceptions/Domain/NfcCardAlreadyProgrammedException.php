<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/** Programming station: the card got a tag in the meantime (e.g. from a second phone). */
final class NfcCardAlreadyProgrammedException extends DomainException
{
    public function errorCode(): string
    {
        return 'NFC_CARD_ALREADY_PROGRAMMED';
    }

    public function status(): int
    {
        return 409;
    }

    protected function defaultMessage(): string
    {
        return 'This card was programmed on another device in the meantime.';
    }
}
