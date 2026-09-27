<?php

declare(strict_types=1);

namespace App\Support;

/**
 * Prevents CSV / formula injection when exports are opened in Excel or Google Sheets.
 */
final class CsvSanitizer
{
    public static function cell(mixed $value): string
    {
        $string = match (true) {
            $value === null => '',
            is_bool($value) => $value ? 'yes' : 'no',
            $value instanceof \BackedEnum => (string) $value->value,
            $value instanceof \DateTimeInterface => $value->format(DATE_ATOM),
            default => (string) $value,
        };

        $isNumber = preg_match('/^-?\d+(?:[.,]\d+)?$/', $string) === 1;

        if ($string !== '' && in_array($string[0], ['=', '+', '-', '@', "\t", "\r"], true) && ! $isNumber) {
            return "'".$string;
        }

        return $string;
    }
}
