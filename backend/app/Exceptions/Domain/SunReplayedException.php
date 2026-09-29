<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/** A tap URL whose read counter is not higher than the last one accepted: a copied or replayed URL. */
final class SunReplayedException extends DomainException
{
    public function errorCode(): string
    {
        return 'SUN_REPLAYED';
    }

    public function status(): int
    {
        return 403;
    }

    protected function defaultMessage(): string
    {
        return 'This tap was already used. Please tap the card again.';
    }
}
