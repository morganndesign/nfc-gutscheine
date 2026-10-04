<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/**
 * A card order that cannot be placed or decided: too many open orders (`context.reason` = `too_many_open`), or an
 * order that was already decided (`already_decided`, 409).
 */
final class CardOrderException extends DomainException
{
    public function errorCode(): string
    {
        return 'CARD_ORDER_NOT_POSSIBLE';
    }

    public function status(): int
    {
        return ($this->context['reason'] ?? null) === 'already_decided' ? 409 : 422;
    }

    protected function defaultMessage(): string
    {
        return 'This card order is not possible.';
    }
}
