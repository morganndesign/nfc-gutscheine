<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class RestaurantSuspendedException extends DomainException
{
    public function errorCode(): string
    {
        return 'RESTAURANT_SUSPENDED';
    }

    public function status(): int
    {
        return 403;
    }

    protected function defaultMessage(): string
    {
        return 'This restaurant account is suspended. Please contact support.';
    }
}
