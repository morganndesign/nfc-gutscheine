<?php

declare(strict_types=1);

namespace App\Crypto\Ntag424;

use InvalidArgumentException;

/**
 * What a personalised GiftCard Pro card looks like on the chip (architecture §9.2, §10.3):
 *
 * - NDEF file (02): the tap URL, readable by anyone, writable and changeable only with K0; SDM mirrors PICCData
 *   encrypted with K1 into `e` and the SDM MAC under K2 into `m` on every read. The counter is not retrievable.
 * - K1 = key set's K1, K0/K2/K3 = the card's own keys, all with key version 01. K4 stays unused (no right
 *   references it).
 *
 * Multi-byte values are sent LSB first; access-right nibbles are key numbers, E = free, F = never.
 */
final class CardProfile
{
    public const APPLICATION = "\xD2\x76\x00\x00\x85\x01\x01";

    public const NDEF_FILE = 0x02;

    public const KEY_VERSION = 0x01;

    public const FACTORY_KEY = "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";

    /** Order of the key changes: K0 last, since changing the authenticated key ends the session. */
    public const KEY_ORDER = [1, 2, 3, 0];

    /**
     * ChangeFileSettings data for the NDEF file (NT4H2421Gx §10.7.1):
     * FileOption 40 (SDM on, CommMode.Plain) ‖ AccessRights 00 E0 (RW 0, Change 0, Read E, Write 0) ‖
     * SDMOptions C1 (UID + SDMReadCtr mirrored, ASCII) ‖ SDMAccessRights F F | 1 2 (CtrRet never, MetaRead K1,
     * FileRead K2) ‖ PICCDataOffset ‖ SDMMACInputOffset ‖ SDMMACOffset (MAC over nothing but itself).
     */
    public static function ndefFileSettings(int $piccOffset, int $macOffset): string
    {
        return "\x40"."\x00\xE0"."\xC1"."\xFF\x12".self::offset($piccOffset).self::offset($macOffset).self::offset($macOffset);
    }

    /**
     * ChangeKey data (before encryption): for the authenticated key `NewKey ‖ KeyVer`, for any other key
     * `(NewKey ⊕ OldKey) ‖ KeyVer ‖ CRC32(NewKey)`.
     */
    public static function changeKeyData(int $slot, string $newKey, ?string $oldKey = null): string
    {
        if (strlen($newKey) !== 16 || ($slot !== 0 && ($oldKey === null || strlen($oldKey) !== 16))) {
            throw new InvalidArgumentException('Card keys are 16 bytes.');
        }

        return $slot === 0
            ? $newKey.chr(self::KEY_VERSION)
            : ($newKey ^ $oldKey).chr(self::KEY_VERSION).self::crc32($newKey);
    }

    /** NXP's CRC32 (JAMCRC: IEEE CRC-32 without the final inversion), LSB first. */
    public static function crc32(string $data): string
    {
        return pack('V', crc32($data) ^ 0xFFFFFFFF);
    }

    private static function offset(int $offset): string
    {
        if ($offset < 0 || $offset > 0xFF) {
            throw new InvalidArgumentException('NDEF offsets stay inside the 256-byte file.');
        }

        return substr(pack('V', $offset), 0, 3);
    }
}
