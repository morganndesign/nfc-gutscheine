<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class BalanceLimitExceededException extends DomainException
{
    public function errorCode(): string
    {
        return 'BALANCE_LIMIT_EXCEEDED';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'The resulting balance would exceed the maximum allowed card balance.';
    }
}
