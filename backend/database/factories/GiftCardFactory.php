<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Enums\GiftCardStatus;
use App\Models\GiftCard;
use App\Models\Restaurant;
use App\Support\CardNumber;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * Creates card rows directly (without ledger entries). Use GiftCardService::issue() when a
 * consistent ledger is required (seeders, feature tests of money flows).
 *
 * @extends Factory<GiftCard>
 */
final class GiftCardFactory extends Factory
{
    protected $model = GiftCard::class;

    /** @return array<string, mixed> */
    public function definition(): array
    {
        $payload = (string) $this->faker->numberBetween(1, 9).$this->faker->numerify(str_repeat('#', 14));
        $value = $this->faker->randomElement([2500, 5000, 7500, 10000]);

        return [
            'restaurant_id' => Restaurant::factory(),
            'public_token' => (string) Str::uuid(),
            'card_number' => $payload.CardNumber::luhnCheckDigit($payload),
            'status' => GiftCardStatus::Active,
            'currency' => 'EUR',
            'initial_value' => $value,
            'balance' => $value,
            'total_loaded' => $value,
            'total_redeemed' => 0,
            'expires_at' => now()->addYears(3),
            'activated_at' => now(),
        ];
    }

    public function status(GiftCardStatus $status): self
    {
        return $this->state(['status' => $status]);
    }
}
