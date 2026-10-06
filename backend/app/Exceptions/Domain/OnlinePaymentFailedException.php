<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/** The payment provider did not do what was asked (no answer, or refused). Nothing was booked here. */
final class OnlinePaymentFailedException extends DomainException
{
    public function errorCode(): string
    {
        return 'ONLINE_PAYMENT_FAILED';
    }

    public function status(): int
    {
        return 502;
    }

    protected function defaultMessage(): string
    {
        return 'The payment provider could not be reached. Nothing was booked; please try again.';
    }
}
