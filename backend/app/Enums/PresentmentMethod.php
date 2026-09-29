<?php

declare(strict_types=1);

namespace App\Enums;

use App\Services\Presentments\PresentmentVerifier;

/**
 * How a medium was proven (architecture §10.1). Each method is implemented by one verifier
 * ({@see PresentmentVerifier}); `rotating_qr` and `email_link` join in Phase 7.
 */
enum PresentmentMethod: string
{
    /** AES challenge answered by the NTAG 424 DNA card itself (A3). Its verifier arrives with the crypto service (Phase 4). */
    case LiveAuth = 'live_auth';
    /** Static printable QR (A1, bearer). */
    case PrintableQr = 'printable_qr';

    public function isQr(): bool
    {
        return $this === self::PrintableQr;
    }

    /** Assurance level: A1 bearer, A2 fresh value from a confirmed device, A3 live card authentication. */
    public function level(): string
    {
        return match ($this) {
            self::LiveAuth => 'A3',
            self::PrintableQr => 'A1',
        };
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
