<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class TransactionNotReversibleException extends DomainException
{
    public function errorCode(): string
    {
        return 'TRANSACTION_NOT_REVERSIBLE';
    }

    public function status(): int
    {
        return 409;
    }

    protected function defaultMessage(): string
    {
        return 'This transaction cannot be reversed.';
    }
}
