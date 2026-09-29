<?php

declare(strict_types=1);

namespace App\Crypto\Ntag424;

use App\Exceptions\Domain\SunVerificationFailedException;
use InvalidArgumentException;

/**
 * The URL a card presents when tapped: `{giftcard.tap_url}/{key set}?e={PICCData}&m={MAC}` (architecture §10.3).
 * The personalisation writes it as an NDEF URI record whose `e` and `m` the chip fills on every read (SDM).
 */
final readonly class TapUrl
{
    private const ENCRYPTED_PICC_HEX = 32;

    private const MAC_HEX = 16;

    public function __construct(
        public string $keySet,
        public string $e,
        public string $m,
    ) {}

    /** Accepts only a URL on the configured origin with a well-formed key set, `e` and `m`. */
    public static function parse(string $url, ?string $origin = null): self
    {
        $prefix = ($origin ?? self::origin()).'/';
        if (! str_starts_with($url, $prefix)) {
            throw new SunVerificationFailedException;
        }
        $rest = substr($url, strlen($prefix));
        $question = strpos($rest, '?');
        if ($question === false) {
            throw new SunVerificationFailedException;
        }
        $keySet = substr($rest, 0, $question);
        parse_str(substr($rest, $question + 1), $query);
        $e = $query['e'] ?? null;
        $m = $query['m'] ?? null;
        if (! is_string($e) || ! is_string($m) || preg_match('/^[a-z0-9][a-z0-9._-]{0,31}$/', $keySet) !== 1) {
            throw new SunVerificationFailedException;
        }

        return new self($keySet, $e, $m);
    }

    /**
     * The NDEF file content for a key set, with `e` and `m` as zero placeholders, and where the chip mirrors them.
     *
     * File: NLEN (2, big endian) ‖ D1 01 PL 55 ‖ URI prefix ‖ URI. Offsets count from the start of the file.
     *
     * @return array{file: string, piccOffset: int, macOffset: int}
     */
    public static function ndefTemplate(string $keySet, ?string $origin = null): array
    {
        if (preg_match('/^[a-z0-9][a-z0-9._-]{0,31}$/', $keySet) !== 1) {
            throw new InvalidArgumentException('Invalid key set version.');
        }
        $url = sprintf('%s/%s?e=%s&m=%s', $origin ?? self::origin(), $keySet, str_repeat('0', self::ENCRYPTED_PICC_HEX), str_repeat('0', self::MAC_HEX));

        [$prefix, $uri] = match (true) {
            str_starts_with($url, 'https://') => ["\x04", substr($url, 8)],
            str_starts_with($url, 'http://') => ["\x03", substr($url, 7)],
            default => ["\x00", $url],
        };
        $payload = $prefix.$uri;
        if (strlen($payload) > 200) {
            throw new InvalidArgumentException('The tap URL is too long for one short NDEF record.');
        }
        $record = "\xD1\x01".chr(strlen($payload))."\x55".$payload;
        $file = pack('n', strlen($record)).$record;
        $uriStart = 7;

        return [
            'file' => $file,
            'piccOffset' => $uriStart + (int) strpos($uri, '?e=') + 3,
            'macOffset' => $uriStart + (int) strpos($uri, '&m=') + 3,
        ];
    }

    /** Reads the URL back from NDEF file content (as the chip returns it, mirrored). */
    public static function fromNdef(string $file): ?string
    {
        if (strlen($file) < 7) {
            return null;
        }
        $length = (ord($file[0]) << 8) | ord($file[1]);
        $record = substr($file, 2, $length);
        if (strlen($record) !== $length || substr($record, 0, 2) !== "\xD1\x01" || $record[3] !== "\x55") {
            return null;
        }
        $payload = substr($record, 4, ord($record[2]));
        $prefix = match ($payload[0] ?? '') {
            "\x04" => 'https://',
            "\x03" => 'http://',
            "\x00" => '',
            default => null,
        };

        return $prefix === null ? null : $prefix.substr($payload, 1);
    }

    private static function origin(): string
    {
        return (string) config('giftcard.tap_url');
    }
}
