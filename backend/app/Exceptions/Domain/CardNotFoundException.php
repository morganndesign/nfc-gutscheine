<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class CardNotFoundException extends DomainException
{
    public function errorCode(): string
    {
        return 'CARD_NOT_FOUND';
    }

    public function status(): int
    {
        return 404;
    }

    protected function defaultMessage(): string
    {
        return 'Gift card not found.';
    }
}
