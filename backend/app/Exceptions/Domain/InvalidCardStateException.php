<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class InvalidCardStateException extends DomainException
{
    public function errorCode(): string
    {
        return 'INVALID_CARD_STATE';
    }

    public function status(): int
    {
        return 409;
    }

    protected function defaultMessage(): string
    {
        return 'This action is not allowed for the current card status.';
    }
}
