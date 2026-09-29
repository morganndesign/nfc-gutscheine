<?php

declare(strict_types=1);

namespace App\Enums;

/**
 * What a presentment may be used for (architecture §10.1). Each purpose accepts a card only in the states that
 * operation needs ({@see self::cardStates()}).
 */
enum PresentmentPurpose: string
{
    /** Pay with the voucher: consumed by exactly one redemption. */
    case Spend = 'spend';

    /** Link an available card to a paid voucher (sale with a card, adding a card, replacement). */
    case Bind = 'bind';

    /** Confirm a delivery: one card of the delivered batch, tapped by a manager of its restaurant. */
    case Receive = 'receive';

    /**
     * The card states a live-authenticated card may be in for this purpose.
     *
     * @return list<CardState>
     */
    public function cardStates(): array
    {
        return match ($this) {
            self::Spend => [CardState::Active],
            self::Bind => [CardState::Available],
            self::Receive => [CardState::Delivered],
        };
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
