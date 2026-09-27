<?php

declare(strict_types=1);

namespace App\Enums;

/** Last step an NFC programming attempt reached (in order). */
enum NfcWriteStage: string
{
    case Read = 'read';
    case Check = 'check';
    case Detect = 'detect';
    case Write = 'write';
    case Verify = 'verify';
    case Lock = 'lock';
    case Bind = 'bind';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
