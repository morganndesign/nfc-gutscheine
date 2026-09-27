<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Enums\DeviceStatus;
use App\Models\Device;
use App\Models\Restaurant;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Device>
 */
final class DeviceFactory extends Factory
{
    protected $model = Device::class;

    /** @return array<string, mixed> */
    public function definition(): array
    {
        return [
            'restaurant_id' => Restaurant::factory(),
            'name' => $this->faker->randomElement(['Bar iPhone', 'Terrace Android', 'Counter iPad']),
            'type' => 'phone',
            'fingerprint' => hash('sha256', $this->faker->uuid()),
            'status' => DeviceStatus::Active,
            'last_seen_at' => now(),
        ];
    }

    public function revoked(): self
    {
        return $this->state(['status' => DeviceStatus::Revoked, 'revoked_at' => now()]);
    }
}
