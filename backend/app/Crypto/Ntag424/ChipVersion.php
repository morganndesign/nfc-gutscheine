<?php

declare(strict_types=1);

namespace App\Crypto\Ntag424;

/**
 * GetVersion (NT4H2421Gx §10.5.2, `90 60 00 00 00`, then `90 AF 00 00 00` twice): hardware, software and
 * production data of the chip. The station accepts only an NXP NTAG 424 DNA (plain or TT) whose production data
 * carries the UID the radio reported. The answer is not signed — the originality signature is the cryptographic
 * check; this one keeps other NXP products (DESFire, NTAG 413, …) and inconsistent emulators out.
 */
final class ChipVersion
{
    public const GET_VERSION = "\x90\x60\x00\x00\x00";

    public const NEXT_FRAME = "\x90\xAF\x00\x00\x00";

    private const NXP = 0x04;

    private const TYPE_NTAG = 0x04;

    /** HW subtype: 0x02 NTAG 424 DNA (50 pF), 0x08 NTAG 424 DNA TagTamper. */
    private const SUBTYPES = [0x02, 0x08];

    private const MAJOR_VERSION = 0x30;

    /** Storage size code 0x11: between 256 and 512 bytes (416 bytes of files). */
    private const STORAGE = 0x11;

    /**
     * Why the three answers (without status words) are not an NTAG 424 DNA with this UID, or null when they are.
     */
    public static function refusal(string $hardware, string $software, string $production, string $uid): ?string
    {
        if (strlen($hardware) !== 7 || strlen($software) !== 7 || strlen($production) < 14) {
            return 'version_length';
        }
        $hw = array_values(unpack('C7', $hardware) ?: []);
        $sw = array_values(unpack('C7', $software) ?: []);

        return match (true) {
            $hw[0] !== self::NXP || $sw[0] !== self::NXP => 'not_nxp',
            $hw[1] !== self::TYPE_NTAG || ! in_array($hw[2], self::SUBTYPES, true) || $hw[3] !== self::MAJOR_VERSION || $hw[5] !== self::STORAGE => 'not_ntag424',
            substr($production, 0, 7) !== $uid => 'uid_mismatch',
            default => null,
        };
    }
}
