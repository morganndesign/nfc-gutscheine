<?php

declare(strict_types=1);

namespace App\Enums;

/**
 * How the money for a sale or reload was received (decision 25). `online` is paid in the restaurant's online shop
 * through its payment provider account; only the provider's verified webhook books it, never a person.
 */
enum PaymentMethod: string
{
    case Cash = 'cash';
    case CardTerminal = 'card_terminal';
    case BankTransfer = 'bank_transfer';
    /**
     * Loyalty: value given without payment (regulars, marketing), always with a reason; owners and the managers the
     * owner allowed (decision 2026-10-05/06). Never revenue, never paid out.
     */
    case Complimentary = 'complimentary';

    /** Paid in the restaurant's online shop; the reference is the provider's payment id (a refund: its refund id). */
    case Online = 'online';

    public function label(): string
    {
        return match ($this) {
            self::Cash => 'Cash',
            self::CardTerminal => 'Card terminal',
            self::BankTransfer => 'Bank transfer',
            self::Complimentary => 'Loyalty (no payment)',
            self::Online => 'Online',
        };
    }

    /** A terminal receipt number or bank reference proves the payment and is required. */
    public function requiresReference(): bool
    {
        return in_array($this, [self::CardTerminal, self::BankTransfer, self::Online], true);
    }

    /**
     * Methods a person records at the till or in the dashboard. Online payments are booked by the provider's
     * webhook only.
     *
     * @return list<string>
     */
    public static function tillValues(): array
    {
        return [self::Cash->value, self::CardTerminal->value, self::BankTransfer->value, self::Complimentary->value];
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
