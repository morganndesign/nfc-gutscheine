<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class VelocityLimitExceededException extends DomainException
{
    public function errorCode(): string
    {
        return 'VELOCITY_LIMIT_EXCEEDED';
    }

    public function status(): int
    {
        return 429;
    }

    protected function defaultMessage(): string
    {
        return 'Too many redemptions on this voucher in a short period. Please contact a manager.';
    }
}
