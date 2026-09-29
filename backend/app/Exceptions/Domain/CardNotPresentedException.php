<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/** A replacement without the old card at hand (lost, stolen) needs `cards.replace_lost` (owners). */
final class CardNotPresentedException extends DomainException
{
    public function errorCode(): string
    {
        return 'CARD_NOT_PRESENTED';
    }

    public function status(): int
    {
        return 403;
    }

    protected function defaultMessage(): string
    {
        return 'Hold the old card to the phone first. Only the owner can replace a card that is not at hand.';
    }
}
