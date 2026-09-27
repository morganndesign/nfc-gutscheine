<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class DeviceRevokedException extends DomainException
{
    public function errorCode(): string
    {
        return 'DEVICE_REVOKED';
    }

    public function status(): int
    {
        return 403;
    }

    protected function defaultMessage(): string
    {
        return 'This device has been revoked. Please contact your manager.';
    }
}
