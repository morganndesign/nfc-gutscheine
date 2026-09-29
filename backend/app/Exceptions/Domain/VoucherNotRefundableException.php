<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/** Nothing of the balance was paid for (complimentary value is never paid out). */
final class VoucherNotRefundableException extends DomainException
{
    public function errorCode(): string
    {
        return 'VOUCHER_NOT_REFUNDABLE';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'Nothing of this balance was paid for: complimentary value is not paid out.';
    }
}
