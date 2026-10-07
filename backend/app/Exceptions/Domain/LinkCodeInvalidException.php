<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/** POS partners: A restaurant's connection code that is unknown, already used or older than 24 hours. */
final class LinkCodeInvalidException extends DomainException
{
    public function errorCode(): string
    {
        return 'LINK_CODE_INVALID';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'This connection code is unknown, used or expired.';
    }
}
