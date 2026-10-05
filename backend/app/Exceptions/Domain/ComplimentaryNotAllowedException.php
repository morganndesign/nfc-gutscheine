<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class ComplimentaryNotAllowedException extends DomainException
{
    public function errorCode(): string
    {
        return 'COMPLIMENTARY_NOT_ALLOWED';
    }

    public function status(): int
    {
        return 403;
    }

    protected function defaultMessage(): string
    {
        return 'You may not issue loyalty value.';
    }
}
