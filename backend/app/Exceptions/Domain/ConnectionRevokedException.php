<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/** POS partners: The restaurant disconnected the till system (or the connection is unknown): its tills stop at once. */
final class ConnectionRevokedException extends DomainException
{
    public function errorCode(): string
    {
        return 'CONNECTION_REVOKED';
    }

    public function status(): int
    {
        return 403;
    }

    protected function defaultMessage(): string
    {
        return 'This restaurant has disconnected your till system, or it is suspended.';
    }
}
