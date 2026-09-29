<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class VoucherExpiredException extends DomainException
{
    public function errorCode(): string
    {
        return 'VOUCHER_EXPIRED';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'This voucher has expired. An owner can reinstate it; its balance is kept.';
    }
}
