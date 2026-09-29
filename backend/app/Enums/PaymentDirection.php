<?php

declare(strict_types=1);

namespace App\Enums;

/** Money received for a sale or reload (`in`), or paid back to the guest with a refund (`out`). */
enum PaymentDirection: string
{
    case In = 'in';
    case Out = 'out';
}
