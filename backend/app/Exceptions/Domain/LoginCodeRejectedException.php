<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/**
 * Waiter app sign-in: the e-mailed code was refused. `reason` says why, for the app's own wording: `wrong` (try
 * again), `expired` (sign in again: expired, used, 5 wrong tries or another phone), `locked` (15 wrong codes within
 * an hour: the account is locked for 60 minutes), `wait` (a new code only every 30 seconds).
 */
final class LoginCodeRejectedException extends DomainException
{
    public function errorCode(): string
    {
        return 'LOGIN_CODE_REJECTED';
    }

    protected function defaultMessage(): string
    {
        return 'The sign-in code was not accepted.';
    }
}
