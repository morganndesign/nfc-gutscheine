<?php

declare(strict_types=1);

namespace App\Services\GiftCards;

use App\Models\GiftCard;
use App\Models\Restaurant;
use App\Support\CardNumber;
use RuntimeException;

/**
 * Generates unguessable, Luhn-valid card numbers. Numbers are random (not sequential) so that
 * knowing one card number reveals nothing about others.
 */
final class CardNumberGenerator
{
    public function generate(Restaurant $restaurant): string
    {
        $length = (int) config('giftcard.card_number.length', 16);
        $attempts = (int) config('giftcard.card_number.max_generation_attempts', 10);
        $prefix = CardNumber::normalize($restaurant->settings->card_number_prefix);

        for ($i = 0; $i < $attempts; $i++) {
            $payload = $prefix;
            while (strlen($payload) < $length - 1) {
                $payload .= (string) random_int(0, 9);
            }
            // Never start with 0 so numbers survive spreadsheet round-trips.
            if ($payload[0] === '0') {
                $payload[0] = (string) random_int(1, 9);
            }

            $number = $payload.CardNumber::luhnCheckDigit($payload);

            $exists = GiftCard::query()
                ->withoutGlobalScopes()
                ->where('restaurant_id', $restaurant->getKey())
                ->where('card_number', $number)
                ->exists();

            if (! $exists) {
                return $number;
            }
        }

        throw new RuntimeException('Unable to generate a unique card number.');
    }
}
