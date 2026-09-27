<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class CardExpiredException extends DomainException
{
    public function errorCode(): string
    {
        return 'CARD_EXPIRED';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'This gift card has expired.';
    }
}
