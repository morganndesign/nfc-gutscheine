<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/**
 * The restaurant's online shop does not sell now (switched off, not connected to the payment provider, the provider
 * does not allow charges yet, or online sales are not configured). `context.reason` says which.
 */
final class OnlineShopUnavailableException extends DomainException
{
    public function errorCode(): string
    {
        return 'ONLINE_SHOP_UNAVAILABLE';
    }

    public function status(): int
    {
        return 409;
    }

    protected function defaultMessage(): string
    {
        return 'This shop does not sell vouchers online right now.';
    }
}
