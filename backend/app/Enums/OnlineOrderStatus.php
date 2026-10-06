<?php

declare(strict_types=1);

namespace App\Enums;

/** An online order from the restaurant's shop (online sales, decision 2026-10-06). */
enum OnlineOrderStatus: string
{
    /** The buyer is on the payment page; nothing is sold. */
    case Pending = 'pending';

    /** The provider confirmed the payment: the voucher exists and is e-mailed. */
    case Paid = 'paid';

    /** Not paid in time (or the payment page was left): no voucher. */
    case Expired = 'expired';

    /** The voucher was refunded through the provider. */
    case Refunded = 'refunded';

    /** The card holder disputed the payment: the voucher is blocked. */
    case Disputed = 'disputed';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
