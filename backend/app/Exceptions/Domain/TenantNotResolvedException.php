<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class TenantNotResolvedException extends DomainException
{
    public function errorCode(): string
    {
        return 'TENANT_NOT_RESOLVED';
    }

    public function status(): int
    {
        return 403;
    }

    protected function defaultMessage(): string
    {
        return 'No restaurant context is available for this request.';
    }
}
