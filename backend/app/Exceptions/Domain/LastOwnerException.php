<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/** Every restaurant keeps at least one active owner. */
final class LastOwnerException extends DomainException
{
    public function errorCode(): string
    {
        return 'LAST_OWNER';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'A restaurant must keep at least one active owner.';
    }
}
