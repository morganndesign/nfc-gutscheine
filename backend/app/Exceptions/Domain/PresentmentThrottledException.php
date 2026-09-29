<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/**
 * Too many failed presentments by this user on this device in this restaurant (audit S7: never keyed by IP).
 */
final class PresentmentThrottledException extends DomainException
{
    public function errorCode(): string
    {
        return 'PRESENTMENT_THROTTLED';
    }

    public function status(): int
    {
        return 429;
    }

    protected function defaultMessage(): string
    {
        return 'Too many invalid scans on this device. Please wait a moment.';
    }
}
