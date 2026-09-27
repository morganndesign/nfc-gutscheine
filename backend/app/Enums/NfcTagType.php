<?php

declare(strict_types=1);

namespace App\Enums;

enum NfcTagType: string
{
    case Ntag213 = 'ntag213';
    case Ntag215 = 'ntag215';
    case Ntag216 = 'ntag216';
    case Ntag424Dna = 'ntag424_dna';
    case QrOnly = 'qr_only';

    /** Whether the tag produces a cryptographically verifiable, non-replayable read (SUN / SDM). */
    public function supportsSecureMessaging(): bool
    {
        return $this === self::Ntag424Dna;
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
