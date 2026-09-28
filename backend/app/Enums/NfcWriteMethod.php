<?php

declare(strict_types=1);

namespace App\Enums;

/** How a tag was programmed. Only `web_nfc` proves the content by reading the tag back. */
enum NfcWriteMethod: string
{
    /** Written and read back by a client: the dashboard (Web NFC, Chrome on Android) or GiftCard Waiter (Android). */
    case WebNfc = 'web_nfc';
    /** Written with an external app; the dashboard only records it (never with a UID). */
    case Manual = 'manual';
    /** NTAG 424 DNA provisioned with an external tool; the UID binds on the first verified tap. */
    case Provisioned = 'provisioned';
    /** QR code printed, no chip. */
    case Printed = 'printed';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
