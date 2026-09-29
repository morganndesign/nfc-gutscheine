<?php

declare(strict_types=1);

namespace App\Enums;

/**
 * Decision 26: a voucher is spent either with its physical card or with its QR, never both.
 */
enum VoucherKind: string
{
    /** Spent only with a live-authenticated tap of its own NTAG 424 DNA card. */
    case Card = 'card';
    /** Spent only with a QR presentment. */
    case Digital = 'digital';

    public function allowsSpendingWith(PresentmentMethod $method): bool
    {
        return match ($this) {
            self::Card => $method === PresentmentMethod::LiveAuth,
            self::Digital => $method->isQr(),
        };
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
