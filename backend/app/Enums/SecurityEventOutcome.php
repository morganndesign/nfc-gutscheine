<?php

declare(strict_types=1);

namespace App\Enums;

enum SecurityEventOutcome: string
{
    /** The action happened. */
    case Succeeded = 'succeeded';
    /** The action was refused; `reason` holds the machine-readable cause (usually the API error code). */
    case Refused = 'refused';
}
