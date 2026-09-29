<?php

declare(strict_types=1);

namespace App\Services\Vouchers;

use App\Models\Restaurant;
use App\Models\Voucher;
use App\Support\VoucherNumber;
use RuntimeException;

/**
 * Generates random, Luhn-valid internal voucher numbers. Numbers are random (not sequential) so that knowing one
 * reveals nothing about others. They are never credentials (decision 24).
 */
final class VoucherNumberGenerator
{
    public function generate(Restaurant $restaurant): string
    {
        $length = (int) config('giftcard.voucher_number.length', 16);
        $attempts = (int) config('giftcard.voucher_number.max_generation_attempts', 10);

        for ($i = 0; $i < $attempts; $i++) {
            $payload = '';
            while (strlen($payload) < $length - 1) {
                $payload .= (string) random_int(0, 9);
            }
            // Never start with 0 so numbers survive spreadsheet round-trips.
            if (str_starts_with($payload, '0')) {
                $payload = random_int(1, 9).substr($payload, 1);
            }

            $number = $payload.VoucherNumber::luhnCheckDigit($payload);

            $exists = Voucher::query()
                ->withoutGlobalScopes()
                ->where('restaurant_id', $restaurant->getKey())
                ->where('voucher_number', $number)
                ->exists();

            if (! $exists) {
                return $number;
            }
        }

        throw new RuntimeException('Unable to generate a unique voucher number.');
    }
}
