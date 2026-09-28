<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/**
 * A restaurant that has financial or customer data cannot be deleted: gift cards, their
 * transactions and customers are business records that must be kept. It can be archived.
 */
final class RestaurantNotDeletableException extends DomainException
{
    public function errorCode(): string
    {
        return 'RESTAURANT_NOT_DELETABLE';
    }

    public function status(): int
    {
        return 409;
    }

    protected function defaultMessage(): string
    {
        return 'This restaurant has business data and cannot be deleted. Archive it instead.';
    }
}
