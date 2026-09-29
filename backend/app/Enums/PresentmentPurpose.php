<?php

declare(strict_types=1);

namespace App\Enums;

/**
 * What a presentment may be used for (architecture §10.1). `bind`, `select`, `receive`, `resume` and `verify`
 * are added with the physical card flows.
 */
enum PresentmentPurpose: string
{
    /** Pay with the voucher: consumed by exactly one redemption. */
    case Spend = 'spend';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
