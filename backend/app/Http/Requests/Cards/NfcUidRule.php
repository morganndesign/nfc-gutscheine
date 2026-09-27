<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Services\GiftCards\NfcUid;
use Closure;

final class NfcUidRule
{
    public static function closure(): Closure
    {
        return static function (string $attribute, mixed $value, Closure $fail): void {
            if (is_string($value) && ! NfcUid::isValid($value)) {
                $fail('The NFC serial number is not valid.');
            }
        };
    }
}
