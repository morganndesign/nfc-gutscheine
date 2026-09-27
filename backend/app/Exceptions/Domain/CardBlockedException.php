<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class CardBlockedException extends DomainException
{
    public function errorCode(): string
    {
        return 'CARD_BLOCKED';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'This gift card is blocked.';
    }
}
