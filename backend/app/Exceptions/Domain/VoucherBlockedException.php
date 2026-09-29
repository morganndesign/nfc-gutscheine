<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class VoucherBlockedException extends DomainException
{
    public function errorCode(): string
    {
        return 'VOUCHER_BLOCKED';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'This voucher is blocked.';
    }
}
