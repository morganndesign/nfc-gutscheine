<?php

declare(strict_types=1);

namespace App\Services\GiftCards;

final class NfcUid
{
    /**
     * Normalises chip serial numbers ("04:a2:3f:..", "04A23F..") to upper-case hex without separators.
     */
    public static function normalize(string $uid): string
    {
        return strtoupper(preg_replace('/[^0-9A-Fa-f]/', '', $uid) ?? '');
    }

    public static function isValid(string $uid): bool
    {
        $normalized = self::normalize($uid);

        // NTAG21x / NTAG424: 7-byte UID; 4 and 10-byte UIDs exist for other ISO 14443-A chips.
        return in_array(strlen($normalized), [8, 14, 20], true);
    }
}
