<?php

declare(strict_types=1);

namespace App\Support;

/** Semantic app versions ("1.4.2") as reported by the native waiter app. */
final class AppVersion
{
    public const PATTERN = '/^\d{1,4}\.\d{1,4}\.\d{1,4}$/';

    public static function isValid(?string $version): bool
    {
        return $version !== null && preg_match(self::PATTERN, $version) === 1;
    }

    /** True when $version is older than $minimum. An unset minimum never blocks. */
    public static function isBelow(string $version, ?string $minimum): bool
    {
        return self::isValid($minimum) && version_compare($version, (string) $minimum, '<');
    }
}
