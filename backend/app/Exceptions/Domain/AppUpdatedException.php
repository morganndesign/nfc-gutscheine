<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/** The waiter app was updated since this token was issued: sign in again, with the e-mailed code (decision 2026-10-06). */
final class AppUpdatedException extends DomainException
{
    public function errorCode(): string
    {
        return 'APP_UPDATED';
    }

    public function status(): int
    {
        return 401;
    }

    protected function defaultMessage(): string
    {
        return 'The app was updated. Please sign in again.';
    }
}
