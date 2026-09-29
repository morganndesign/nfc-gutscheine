<?php

declare(strict_types=1);

namespace App\Enums;

enum MediumStatus: string
{
    case Active = 'active';
    /** Final: a revoked medium never works again. */
    case Revoked = 'revoked';
}
