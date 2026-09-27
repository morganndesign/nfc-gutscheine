<?php

declare(strict_types=1);

namespace App\Support;

use NumberFormatter;

/**
 * Money is always handled as integer minor units (cents) to avoid floating point errors.
 */
final class Money
{
    public static function format(int $minorUnits, string $currency, string $locale = 'de-AT'): string
    {
        $formatter = new NumberFormatter(str_replace('-', '_', $locale), NumberFormatter::CURRENCY);
        $formatted = $formatter->formatCurrency($minorUnits / 100, $currency);

        return $formatted === false ? sprintf('%s %.2f', $currency, $minorUnits / 100) : $formatted;
    }
}
