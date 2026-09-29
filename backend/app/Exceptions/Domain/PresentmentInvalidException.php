<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/**
 * The presentment is expired, already used, or belongs to another user, device, voucher or purpose. The reason is in the context.
 */
final class PresentmentInvalidException extends DomainException
{
    public function errorCode(): string
    {
        return 'PRESENTMENT_INVALID';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'This scan is no longer valid. Please scan the voucher again.';
    }
}
