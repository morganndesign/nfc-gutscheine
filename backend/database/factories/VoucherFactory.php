<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Enums\VoucherKind;
use App\Enums\VoucherStatus;
use App\Models\Restaurant;
use App\Models\Voucher;
use App\Support\VoucherNumber;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Creates voucher rows directly, without ledger entries, payments or media: for list, search and isolation
 * tests only. Money flows go through VoucherService::sell() so the ledger stays consistent.
 *
 * @extends Factory<Voucher>
 */
final class VoucherFactory extends Factory
{
    protected $model = Voucher::class;

    /** @return array<string, mixed> */
    public function definition(): array
    {
        $payload = (string) $this->faker->numberBetween(1, 9).$this->faker->numerify(str_repeat('#', 14));

        return [
            'restaurant_id' => Restaurant::factory(),
            'kind' => VoucherKind::Digital,
            'voucher_number' => $payload.VoucherNumber::luhnCheckDigit($payload),
            'status' => VoucherStatus::Active,
            'currency' => 'EUR',
            'initial_value' => 0,
            'balance' => 0,
            'total_loaded' => 0,
            'total_redeemed' => 0,
        ];
    }

    public function status(VoucherStatus $status): self
    {
        return $this->state(['status' => $status]);
    }
}
