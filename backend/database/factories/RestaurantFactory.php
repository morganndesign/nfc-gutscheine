<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Enums\RestaurantStatus;
use App\Models\Restaurant;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Restaurant>
 */
final class RestaurantFactory extends Factory
{
    protected $model = Restaurant::class;

    /** @return array<string, mixed> */
    public function definition(): array
    {
        $name = $this->faker->unique()->company().' '.$this->faker->randomElement(['Bistro', 'Trattoria', 'Café', 'Brasserie', 'Wirtshaus']);

        return [
            'name' => $name,
            'slug' => Str::slug($name).'-'.Str::lower(Str::random(4)),
            'email' => $this->faker->companyEmail(),
            'phone' => $this->faker->phoneNumber(),
            'address_line1' => $this->faker->streetAddress(),
            'postal_code' => $this->faker->postcode(),
            'city' => 'Wien',
            'country' => 'AT',
            'currency' => 'EUR',
            'timezone' => 'Europe/Vienna',
            'locale' => 'de-AT',
            'status' => RestaurantStatus::Active,
            'plan' => 'standard',
        ];
    }

    public function suspended(): self
    {
        return $this->state(['status' => RestaurantStatus::Suspended, 'suspended_at' => now(), 'suspension_reason' => 'Unpaid invoice']);
    }
}
