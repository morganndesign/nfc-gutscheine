<?php

declare(strict_types=1);

namespace App\Enums;

enum KeySetStatus: string
{
    /** New batches are keyed with it. */
    case Active = 'active';
    /** Cards still use it; no new batches. */
    case VerifyOnly = 'verify_only';
    /** No card uses it any more. */
    case Retired = 'retired';
}
