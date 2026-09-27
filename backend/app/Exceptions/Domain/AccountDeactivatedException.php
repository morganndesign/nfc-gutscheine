<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/**
 * The account was deactivated by the restaurant. Returned to the native waiter app (sign-in and every request)
 * so it can show "Account deactivated" instead of a plain "session expired" (waiter app spec, open question Q2).
 */
final class AccountDeactivatedException extends DomainException
{
    public function errorCode(): string
    {
        return 'ACCOUNT_DEACTIVATED';
    }

    public function status(): int
    {
        return 401;
    }

    protected function defaultMessage(): string
    {
        return 'This account has been deactivated.';
    }
}
