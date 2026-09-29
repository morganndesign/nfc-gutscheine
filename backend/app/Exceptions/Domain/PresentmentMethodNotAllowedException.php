<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/**
 * Decision 26: card vouchers spend only with a live-authenticated card, digital vouchers only with a QR presentment.
 */
final class PresentmentMethodNotAllowedException extends DomainException
{
    public function errorCode(): string
    {
        return 'PRESENTMENT_METHOD_NOT_ALLOWED';
    }

    public function status(): int
    {
        return 422;
    }

    protected function defaultMessage(): string
    {
        return 'This voucher cannot be used this way.';
    }
}
