<?php

declare(strict_types=1);

namespace App\Enums;

enum TransactionType: string
{
    case Issue = 'issue';
    case Redemption = 'redemption';
    case Reload = 'reload';
    /** Correction of an earlier redemption or reload: a new entry, the original is never touched. */
    case Reversal = 'reversal';
    /** The remaining balance paid back to the guest; the voucher is closed (`refunded`). */
    case Refund = 'refund';

    public function label(): string
    {
        return match ($this) {
            self::Issue => 'Sale',
            self::Redemption => 'Redemption',
            self::Reload => 'Reload',
            self::Reversal => 'Reversal',
            self::Refund => 'Refund',
        };
    }

    /** Entries that bring money in (paid for by a payment). */
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
