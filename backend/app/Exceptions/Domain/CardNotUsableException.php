<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/**
 * A genuine card that cannot be used for this operation: wrong state, another restaurant, or not linked to a
 * voucher. `context.reason` says which; the card's state is given for the till's message.
 */
final class CardNotUsableException extends DomainException
{
    public function errorCode(): string
    {
        return 'CARD_NOT_USABLE';
    }

    protected function defaultMessage(): string
    {
        return 'This card cannot be used for this.';
    }
}
