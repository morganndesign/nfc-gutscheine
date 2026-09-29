<?php

declare(strict_types=1);

namespace App\Exceptions\Domain;

/**
 * A personalisation step failed: the chip refused a command, a MAC did not match, the session expired, or the
 * chip is not one this batch may take. `context.reason` says which. The station taps the card again; every step
 * can be repeated safely (keys carry version 01, K0 is changed last).
 */
final class CardPersonalizationFailedException extends DomainException
{
    public function errorCode(): string
    {
        return 'CARD_PERSONALIZATION_FAILED';
    }

    protected function defaultMessage(): string
    {
        return 'The card could not be personalised. Please tap it again.';
    }
}
