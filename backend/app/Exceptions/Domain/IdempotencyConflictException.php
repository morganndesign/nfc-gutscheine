<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class IdempotencyConflictException extends DomainException
{
    public function errorCode(): string
    {
        return 'IDEMPOTENCY_CONFLICT';
    }

    public function status(): int
    {
        return 409;
    }

    protected function defaultMessage(): string
    {
        return 'This idempotency key was already used for a different request.';
    }
}
