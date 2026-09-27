<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

final class CardForeignRestaurantException extends DomainException
{
    public function errorCode(): string
    {
        return 'CARD_FOREIGN_RESTAURANT';
    }

    public function status(): int
    {
        return 403;
    }

    protected function defaultMessage(): string
    {
        return 'This gift card was issued by a different restaurant and cannot be used here.';
    }
}
