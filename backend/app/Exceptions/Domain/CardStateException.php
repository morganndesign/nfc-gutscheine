<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/** A card or batch cannot make the requested lifecycle change (wrong state, wrong batch, missing approval). */
final class CardStateException extends DomainException
{
    public function errorCode(): string
    {
        return 'CARD_STATE_INVALID';
    }

    public function status(): int
    {
        return 409;
    }

    protected function defaultMessage(): string
    {
        return 'This card cannot make that change in its current state.';
    }
}
