<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class DebitLimitExceededException extends DomainException
{
    public function errorCode(): string
    {
        return 'DEBIT_LIMIT_EXCEEDED';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'The amount exceeds the redemption limit of this restaurant.';
    }
}
