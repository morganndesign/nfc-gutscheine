<?php

declare(strict_types=1);

namespace Tests\Support;

use App\Crypto\Ntag424\CardKeys;
use App\Crypto\Ntag424\CardProfile;
use App\Crypto\Ntag424\TapUrl;
use App\Crypto\Primitives\Aes;
use App\Crypto\Primitives\Cmac;

/**
 * An NTAG 424 DNA chip at APDU level, written from the datasheet (NT4H2421Gx) independently of the server's
 * command builders: ISO select / read, WriteData, AuthenticateEV2First, GetKeyVersion (CommMode.MAC),
 * ChangeFileSettings and ChangeKey (CommMode.Full), SDM mirroring of encrypted PICCData and the SDM MAC.
 *
 * A factory chip has all-zero keys (version 00) and a freely writable NDEF file; {@see self::personalized()}
 * gives a chip as a manufacturer's personalisation would deliver it.
 */
final class Ntag424Chip
{
    /** @var array<int, string> */
    private array $keys;

    /** @var array<int, int> */
    private array $versions = [0, 0, 0, 0, 0];

    private string $ndef;

    /** Wire bytes: RW|Change, Read|Write. Factory: RW E, Change 0, Read E, Write E. */
    private string $access = "\xE0\xEE";

    /** @var array{metaRead: int, fileRead: int, picc: int, macInput: int, mac: int}|null */
    private ?array $sdm = null;

    private int $sdmCounter = 0;

    private bool $applicationSelected = false;

    private ?int $file = null;

    /** @var array{key: int, rndB: string}|null */
    private ?array $pending = null;

    /** @var array{key: int, ti: string, enc: string, mac: string, ctr: int}|null */
    private ?array $session = null;

    /** Every APDU the chip received, for assertions. @var list<string> */
    public array $received = [];

    public function __construct(public readonly string $uid)
    {
        $this->keys = array_fill(0, 5, CardProfile::FACTORY_KEY);
        $this->ndef = str_repeat("\0", 256);
    }

    public static function factory(?string $uid = null): self
    {
        return new self($uid ?? "\x04".random_bytes(6));
    }

    /** A chip carrying the GiftCard Pro profile with the keys the server derives for it. */
    public static function personalized(CardKeys $keys, string $uid, string $keySet): self
    {
        $chip = new self($uid);
        $chip->keys = [$keys->masterKey($uid), $keys->metaReadKey(), $keys->sdmMacKey($uid), $keys->challengeKey($uid), CardProfile::FACTORY_KEY];
        $chip->versions = [1, 1, 1, 1, 0];
        $template = TapUrl::ndefTemplate($keySet);
        $chip->ndef = str_pad($template['file'], 256, "\0");
        $chip->access = "\x00\xE0";
        $chip->sdm = ['metaRead' => 1, 'fileRead' => 2, 'picc' => $template['piccOffset'], 'macInput' => $template['macOffset'], 'mac' => $template['macOffset']];

        return $chip;
    }

    public function uidHex(): string
    {
        return strtoupper(bin2hex($this->uid));
    }

    public function key(int $slot): string
    {
        return $this->keys[$slot];
    }

    public function keyVersion(int $slot): int
    {
        return $this->versions[$slot];
    }

    public function sdmEnabled(): bool
    {
        return $this->sdm !== null;
    }

    /** What a phone does for a tap: select the NDEF application and file, read the URL (fresh SUN). */
    public function readNdefUrl(): string
    {
        $this->transceive("\x00\xA4\x04\x00\x07".CardProfile::APPLICATION."\x00");
        $this->transceive("\x00\xA4\x00\x0C\x02\xE1\x04");
        $read = $this->transceive("\x00\xB0\x00\x00\x00");

        return (string) TapUrl::fromNdef(substr($read, 0, -2));
    }

    /** AuthenticateEV2First part 1 with K3 (the phone's first live-authentication command). */
    public function authenticateFirst(): string
    {
        if (! $this->applicationSelected) {
            $this->transceive("\x00\xA4\x04\x00\x07".CardProfile::APPLICATION."\x00");
        }

        return $this->transceive("\x90\x71\x00\x00\x02\x03\x00\x00");
    }

    public function transceive(string $apdu): string
    {
        $this->received[] = $apdu;
        if (strlen($apdu) < 4) {
            return "\x67\x00";
        }
        [$cla, $ins] = [ord($apdu[0]), ord($apdu[1])];

        if ($cla === 0x00) {
            return match ($ins) {
                0xA4 => $this->isoSelect($apdu),
                0xB0 => $this->isoRead($apdu),
                default => "\x6D\x00",
            };
        }
        if ($cla !== 0x90 || ! $this->applicationSelected) {
            return "\x6E\x00";
        }
        $data = strlen($apdu) > 5 ? substr($apdu, 5, ord($apdu[4])) : '';

        return match ($ins) {
            0x71 => $this->authenticatePart1($data),
            0xAF => $this->authenticatePart2($data),
            0x64 => $this->getKeyVersion($data),
            0x8D => $this->writeData($data),
            0x5F => $this->changeFileSettings($data),
            0xC4 => $this->changeKey($data),
            default => "\x91\x1C",
        };
    }

    private function isoSelect(string $apdu): string
    {
        $this->session = null;
        if ($apdu === "\x00\xA4\x04\x00\x07".CardProfile::APPLICATION."\x00") {
            $this->applicationSelected = true;
            $this->file = null;

            return "\x90\x00";
        }
        if ($this->applicationSelected && substr($apdu, 0, 7) === "\x00\xA4\x00\x0C\x02\xE1\x04") {
            $this->file = 2;

            return "\x90\x00";
        }

        return "\x6A\x82";
    }

    private function isoRead(string $apdu): string
    {
        if ($this->file !== 2) {
            return "\x69\x86";
        }
        if (ord($this->access[1]) >> 4 !== 0xE) {
            return "\x69\x82";
        }
        $offset = (ord($apdu[2]) << 8) | ord($apdu[3]);
        $length = strlen($apdu) > 4 ? ord($apdu[4]) : 0;
        $length = $length === 0 ? 256 - $offset : $length;

        return substr($this->mirrored(), $offset, $length)."\x90\x00";
    }

    /** SDM: encrypted PICCData (tag C7: UID + counter mirrored, 7-byte UID) and the MAC, as upper-case ASCII hex. */
    private function mirrored(): string
    {
        if ($this->sdm === null) {
            return $this->ndef;
        }
        $this->sdmCounter++;
        $ctr = substr(pack('V', $this->sdmCounter), 0, 3);
        $file = $this->ndef;
        $picc = strtoupper(bin2hex(Aes::encryptCbc($this->keys[$this->sdm['metaRead']], Aes::ZERO_IV, "\xC7".$this->uid.$ctr.random_bytes(5))));
        $file = substr_replace($file, $picc, $this->sdm['picc'], 32);

        $sessionKey = Cmac::compute($this->keys[$this->sdm['fileRead']], "\x3C\xC3\x00\x01\x00\x80".$this->uid.$ctr);
        $full = Cmac::compute($sessionKey, substr($file, $this->sdm['macInput'], $this->sdm['mac'] - $this->sdm['macInput']));
        $mac = '';
        for ($i = 1; $i < 16; $i += 2) {
            $mac .= $full[$i];
        }

        return substr_replace($file, strtoupper(bin2hex($mac)), $this->sdm['mac'], 16);
    }

    private function writeData(string $data): string
    {
        if (strlen($data) < 7 || ord($data[0]) !== 2) {
            return "\x91\x7E";
        }
        if ((ord($this->access[1]) & 0x0F) !== 0xE) {
            return "\x91\x9D";
        }
        $offset = unpack('V', substr($data, 1, 3)."\0")[1];
        $length = unpack('V', substr($data, 4, 3)."\0")[1];
        $content = substr($data, 7);
        if (strlen($content) !== $length || $offset + $length > 256) {
            return "\x91\x7E";
        }
        $this->ndef = substr_replace($this->ndef, $content, $offset, $length);

        return "\x91\x00";
    }

    private function authenticatePart1(string $data): string
    {
        $this->session = null;
        $key = ord($data[0] ?? "\xFF");
        if ($key > 4) {
            return "\x91\x40";
        }
        $rndB = random_bytes(16);
        $this->pending = ['key' => $key, 'rndB' => $rndB];

        return Aes::encryptCbc($this->keys[$key], Aes::ZERO_IV, $rndB)."\x91\xAF";
    }

    private function authenticatePart2(string $data): string
    {
        $pending = $this->pending;
        $this->pending = null;
        if ($pending === null || strlen($data) !== 32) {
            return "\x91\xCA";
        }
        $key = $this->keys[$pending['key']];
        $plain = Aes::decryptCbc($key, Aes::ZERO_IV, $data);
        $rndA = substr($plain, 0, 16);
        $rndB = $pending['rndB'];
        if (substr($plain, 16) !== substr($rndB, 1).$rndB[0]) {
            return "\x91\xAE";
        }
        $ti = random_bytes(4);
        $sv = substr($rndA, 0, 2).(substr($rndA, 2, 6) ^ substr($rndB, 0, 6)).substr($rndB, 6, 10).substr($rndA, 8, 8);
        $this->session = [
            'key' => $pending['key'],
            'ti' => $ti,
            'enc' => Cmac::compute($key, "\xA5\x5A\x00\x01\x00\x80".$sv),
            'mac' => Cmac::compute($key, "\x5A\xA5\x00\x01\x00\x80".$sv),
            'ctr' => 0,
        ];

        return Aes::encryptCbc($key, Aes::ZERO_IV, $ti.substr($rndA, 1).$rndA[0].str_repeat("\0", 12))."\x91\x00";
    }

    private function getKeyVersion(string $data): string
    {
        if ($this->session === null) {
            return strlen($data) === 1 ? chr($this->versions[ord($data)] ?? 0)."\x91\x00" : "\x91\x7E";
        }
        if (strlen($data) !== 9 || ! $this->macValid(0x64, $data)) {
            return $this->integrityError();
        }
        $version = chr($this->versions[ord($data[0])] ?? 0);
        $this->session['ctr']++;

        return $version.$this->responseMac($version)."\x91\x00";
    }

    private function changeFileSettings(string $data): string
    {
        $plain = $this->fullCommandData(0x5F, $data, 1);
        if ($plain === null) {
            return $this->integrityError();
        }
        if ($this->session['key'] !== (ord($this->access[0]) & 0x0F)) {
            return "\x91\x9D";
        }
        if (ord($data[0]) !== 2) {
            return "\x91\xF0";
        }

        $option = ord($plain[0]);
        $access = substr($plain, 1, 2);
        $sdm = null;
        if (($option & 0x40) !== 0) {
            $sdmOptions = ord($plain[3]);
            $sdmAccess = substr($plain, 4, 2);
            $metaRead = ord($sdmAccess[1]) >> 4;
            $fileRead = ord($sdmAccess[1]) & 0x0F;
            // Only the profile this system uses: encrypted PICCData, MAC, no encrypted file data, no limit.
            if ($sdmOptions !== 0xC1 || $metaRead > 4 || $fileRead > 4 || strlen($plain) !== 15) {
                return "\x91\x9E";
            }
            $offsets = array_map(static fn (string $o): int => unpack('V', $o."\0")[1], str_split(substr($plain, 6, 9), 3));
            $sdm = ['metaRead' => $metaRead, 'fileRead' => $fileRead, 'picc' => $offsets[0], 'macInput' => $offsets[1], 'mac' => $offsets[2]];
            if ($sdm['picc'] + 32 > 256 || $sdm['mac'] + 16 > 256 || $sdm['macInput'] > $sdm['mac']) {
                return "\x91\x9E";
            }
        }
        $this->access = $access;
        $this->sdm = $sdm;
        $this->session['ctr']++;

        return $this->responseMac('')."\x91\x00";
    }

    private function changeKey(string $data): string
    {
        $plain = $this->fullCommandData(0xC4, $data, 1);
        if ($plain === null) {
            return $this->integrityError();
        }
        if ($this->session['key'] !== 0) {
            return "\x91\x9D";
        }
        $slot = ord($data[0]);
        if ($slot > 4) {
            return "\x91\x40";
        }
        if ($slot === 0) {
            $this->keys[0] = substr($plain, 0, 16);
            $this->versions[0] = ord($plain[16]);
            $this->session = null;

            return "\x91\x00";
        }
        $new = substr($plain, 0, 16) ^ $this->keys[$slot];
        if (substr($plain, 17, 4) !== pack('V', crc32($new) ^ 0xFFFFFFFF)) {
            return $this->integrityError();
        }
        $this->keys[$slot] = $new;
        $this->versions[$slot] = ord($plain[16]);
        $this->session['ctr']++;

        return $this->responseMac('')."\x91\x00";
    }

    /** Checks the MAC of a CommMode.Full command and returns its decrypted data without padding. */
    private function fullCommandData(int $cmd, string $data, int $headerLength): ?string
    {
        if ($this->session === null || strlen($data) < $headerLength + 16 + 8 || (strlen($data) - $headerLength - 8) % 16 !== 0) {
            return null;
        }
        if (! $this->macValid($cmd, $data)) {
            return null;
        }
        $encrypted = substr($data, $headerLength, -8);
        $iv = Aes::encryptCbc($this->session['enc'], Aes::ZERO_IV, "\xA5\x5A".$this->session['ti'].pack('v', $this->session['ctr']).str_repeat("\0", 8));
        $plain = Aes::decryptCbc($this->session['enc'], $iv, $encrypted);
        $end = strrpos($plain, "\x80");
        if ($end === false || trim(substr($plain, $end + 1), "\0") !== '') {
            return null;
        }

        return substr($plain, 0, $end);
    }

    private function macValid(int $cmd, string $data): bool
    {
        if ($this->session === null) {
            return false;
        }
        $expected = $this->truncated(Cmac::compute($this->session['mac'], chr($cmd).pack('v', $this->session['ctr']).$this->session['ti'].substr($data, 0, -8)));

        return hash_equals($expected, substr($data, -8));
    }

    private function responseMac(string $data): string
    {
        return $this->truncated(Cmac::compute((string) $this->session['mac'], "\x00".pack('v', $this->session['ctr']).$this->session['ti'].$data));
    }

    private function integrityError(): string
    {
        $this->session = null;

        return "\x91\x1E";
    }

    private function truncated(string $full): string
    {
        $out = '';
        for ($i = 1; $i < 16; $i += 2) {
            $out .= $full[$i];
        }

        return $out;
    }
}
