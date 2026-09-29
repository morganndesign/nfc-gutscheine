<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/** The card did not prove it holds its key (wrong answer, expired or reused challenge). Nothing is spent. */
final class CardAuthenticationFailedException extends DomainException
{
    public function errorCode(): string
    {
        return 'CARD_AUTHENTICATION_FAILED';
    }

    public function status(): int
    {
        return 403;
    }

    protected function defaultMessage(): string
    {
        return 'The card could not be verified. Please tap it again.';
    }
}
