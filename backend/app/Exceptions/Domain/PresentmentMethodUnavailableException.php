<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class PresentmentMethodUnavailableException extends DomainException
{
    public function errorCode(): string
    {
        return 'PRESENTMENT_METHOD_UNAVAILABLE';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'This way of presenting a voucher is not available yet.';
    }
}
