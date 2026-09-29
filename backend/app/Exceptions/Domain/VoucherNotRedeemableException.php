<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class VoucherNotRedeemableException extends DomainException
{
    public function errorCode(): string
    {
        return 'VOUCHER_NOT_REDEEMABLE';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'This voucher cannot be redeemed in its current state.';
    }
}
