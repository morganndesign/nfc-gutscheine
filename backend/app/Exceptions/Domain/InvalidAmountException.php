<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class InvalidAmountException extends DomainException
{
    public function errorCode(): string
    {
        return 'INVALID_AMOUNT';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'The amount is not valid.';
    }
}
