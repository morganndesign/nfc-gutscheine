<?php

declare(strict_types=1);

namespace App\Enums;

enum ScanMethod: string
{
    case Nfc = 'nfc';
    case Qr = 'qr';
    case Link = 'link';
    case Manual = 'manual';
    case Api = 'api';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
