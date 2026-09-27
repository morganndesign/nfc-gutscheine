<?php

declare(strict_types=1);

namespace App\Support;

/**
 * Human-readable card numbers: digits only, Luhn-checked, displayed in groups of four.
 */
final class CardNumber
{
    public static function luhnCheckDigit(string $payload): int
    {
        $sum = 0;
        $double = true;

        for ($i = strlen($payload) - 1; $i >= 0; $i--) {
            $digit = (int) $payload[$i];
            if ($double) {
                $digit *= 2;
                if ($digit > 9) {
                    $digit -= 9;
                }
            }
            $sum += $digit;
            $double = ! $double;
        }

        return (10 - ($sum % 10)) % 10;
    }

    public static function isValid(string $number): bool
    {
        $digits = self::normalize($number);

        if (strlen($digits) < 8) {
            return false;
        }

        return self::luhnCheckDigit(substr($digits, 0, -1)) === (int) substr($digits, -1);
    }

    public static function normalize(string $number): string
    {
        return preg_replace('/\D+/', '', $number) ?? '';
    }

    public static function format(string $number): string
    {
        return trim(chunk_split(self::normalize($number), 4, ' '));
    }

    public static function mask(string $number): string
    {
        $digits = self::normalize($number);

        return '•••• '.substr($digits, -4);
    }
}
