<?php

declare(strict_types=1);

namespace App\Enums;

enum ScanResult: string
{
    case Ok = 'ok';
    case NotFound = 'not_found';
    case ForeignRestaurant = 'foreign_restaurant';
    case UidMismatch = 'uid_mismatch';
    case InvalidSignature = 'invalid_signature';
    case Replay = 'replay';
    case Throttled = 'throttled';
}
