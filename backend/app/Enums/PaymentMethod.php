<?php

declare(strict_types=1);

namespace App\Enums;

/**
 * How the money for a sale or reload was received (decision 25). `online_psp` is added with the online shop,
 * where only a verified provider webhook can create it.
 */
enum PaymentMethod: string
{
    case Cash = 'cash';
    case CardTerminal = 'card_terminal';
    case BankTransfer = 'bank_transfer';
    /** No money received (e.g. marketing). Owner only, always with a reason. */
    case Complimentary = 'complimentary';

    public function label(): string
    {
        return match ($this) {
            self::Cash => 'Cash',
            self::CardTerminal => 'Card terminal',
            self::BankTransfer => 'Bank transfer',
            self::Complimentary => 'Complimentary',
        };
    }

    /** A terminal receipt number or bank reference proves the payment and is required. */
    public function requiresReference(): bool
    {
        return in_array($this, [self::CardTerminal, self::BankTransfer], true);
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
