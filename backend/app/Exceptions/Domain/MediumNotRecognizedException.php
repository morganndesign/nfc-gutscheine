<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/**
 * Unknown, revoked or foreign medium. The answer is the same in every case, so it reveals nothing.
 */
final class MediumNotRecognizedException extends DomainException
{
    public function errorCode(): string
    {
        return 'MEDIUM_NOT_RECOGNIZED';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'This code is not a valid voucher of this restaurant.';
    }
}
