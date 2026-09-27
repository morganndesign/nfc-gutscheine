<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class ReloadNotAllowedException extends DomainException
{
    public function errorCode(): string
    {
        return 'RELOAD_NOT_ALLOWED';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'Reloading gift cards is disabled for this restaurant.';
    }
}
