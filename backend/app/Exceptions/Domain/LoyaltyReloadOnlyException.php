<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/**
 * A loyalty voucher is topped up with loyalty value only, never with money: it is the restaurant's own gift, booked
 * apart from revenue (decision 2026-10-06).
 */
final class LoyaltyReloadOnlyException extends DomainException
{
    public function errorCode(): string
    {
        return 'LOYALTY_RELOAD_ONLY';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'A loyalty voucher is topped up with loyalty value only.';
    }
}
