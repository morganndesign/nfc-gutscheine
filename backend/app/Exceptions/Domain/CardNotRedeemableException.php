<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class CardNotRedeemableException extends DomainException
{
    public function errorCode(): string
    {
        return 'CARD_NOT_REDEEMABLE';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'This gift card cannot be redeemed in its current state.';
    }
}
