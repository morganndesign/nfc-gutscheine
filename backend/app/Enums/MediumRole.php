<?php

declare(strict_types=1);

namespace App\Enums;

enum MediumRole: string
{
    /** The medium may spend the voucher's balance. */
    case Spend = 'spend';
}
