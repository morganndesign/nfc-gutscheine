<?php

declare(strict_types=1);

namespace App\Enums;

enum TransactionType: string
{
    case Issue = 'issue';
    case Redemption = 'redemption';
    case Reload = 'reload';
    case TransferOut = 'transfer_out';
    case TransferIn = 'transfer_in';
    case Expiration = 'expiration';
    case Reversal = 'reversal';
    case Adjustment = 'adjustment';

    public function label(): string
    {
        return match ($this) {
            self::Issue => 'Sale',
            self::Redemption => 'Redemption',
            self::Reload => 'Reload',
            self::TransferOut => 'Transfer out',
            self::TransferIn => 'Transfer in',
            self::Expiration => 'Expiration',
            self::Reversal => 'Reversal',
            self::Adjustment => 'Adjustment',
        };
    }

    /** Transaction types that count as money sold (revenue from card sales). */
    public function isSale(): bool
    {
        return in_array($this, [self::Issue, self::Reload], true);
    }

    public function isReversible(): bool
    {
        return in_array($this, [self::Redemption, self::Reload], true);
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
