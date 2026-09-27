<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class InsufficientBalanceException extends DomainException
{
    public function errorCode(): string
    {
        return 'INSUFFICIENT_BALANCE';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'The gift card balance is insufficient for this amount.';
    }
}
