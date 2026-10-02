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

    /** Confirm a delivery: one card of the shipped batch, tapped by a manager of its restaurant. */
    case Receive = 'receive';

    /** Hand in a guest's card for its replacement: proves the old card is at the till. */
    case Surrender = 'surrender';

    /**
     * The "top up" tap at the till: an active card names its voucher, consumed by the reload; a card from stock
     * names none and is sold instead (a card sale accepts it like a `bind` tap). Never books a reload on a stock card.
     */
    case Reload = 'reload';

    /** Purposes whose presentment names the card's voucher when the card is active (consumed by an operation on it). */
    public function namesVoucher(): bool
    {
        return in_array($this, [self::Spend, self::Reload], true);
    }

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
            // Delivered as well: batches marked delivered before the receipt step was simplified hold delivered cards.
            self::Receive => [CardState::Shipped, CardState::Delivered],
            self::Surrender => [CardState::Active, CardState::Suspended],
            self::Reload => [CardState::Active, CardState::Available],
        };
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
