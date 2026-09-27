<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class ScanThrottledException extends DomainException
{
    public function errorCode(): string
    {
        return 'SCAN_THROTTLED';
    }

    public function status(): int
    {
        return 429;
    }

    protected function defaultMessage(): string
    {
        return 'Too many failed card lookups. Please wait a moment and try again.';
    }
}
