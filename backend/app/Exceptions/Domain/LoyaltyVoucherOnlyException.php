<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/** Loyalty value only goes onto a loyalty voucher: a paid voucher never becomes one (decision 2026-10-05). */
final class LoyaltyVoucherOnlyException extends DomainException
{
    public function errorCode(): string
    {
        return 'LOYALTY_VOUCHER_ONLY';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'Loyalty value can only be added to a loyalty voucher.';
    }
}
