<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class ImmutableRecordException extends DomainException
{
    public function errorCode(): string
    {
        return 'IMMUTABLE_RECORD';
    }

    public function status(): int
    {
        return 409;
    }

    protected function defaultMessage(): string
    {
        return 'This record cannot be modified.';
    }
}
