<?php

declare(strict_types=1);

namespace App\Enums;

/**
 * "Redeemed" is not a status: an active voucher with balance 0 is simply empty, and a reload refills it.
 * Expired and blocked vouchers keep their balance; both can return to active (unblock, reinstate). A refunded
 * voucher is closed for good.
 */
enum VoucherStatus: string
{
    case Active = 'active';
    case Blocked = 'blocked';
    case Expired = 'expired';
    /** The balance was paid back; closed for good. */
    case Refunded = 'refunded';

    public function label(): string
    {
        return match ($this) {
            self::Active => 'Active',
            self::Blocked => 'Blocked',
            self::Expired => 'Expired',
            self::Refunded => 'Refunded',
        };
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
