<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class TenantMismatchException extends DomainException
{
    public function errorCode(): string
    {
        return 'TENANT_MISMATCH';
    }

    public function status(): int
    {
        return 403;
    }

    protected function defaultMessage(): string
    {
        return 'This record belongs to another restaurant.';
    }
}
