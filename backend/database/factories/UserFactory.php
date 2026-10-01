<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Enums\RoleSlug;
use App\Enums\UserStatus;
use App\Models\Restaurant;
use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends Factory<User>
 */
final class UserFactory extends Factory
{
    protected $model = User::class;

    protected static ?string $password = null;

    /** @return array<string, mixed> */
    public function definition(): array
    {
        return [
            'restaurant_id' => Restaurant::factory(),
            'role_id' => fn (): string => Role::findBySlug(RoleSlug::Waiter)->getKey(),
            'name' => $this->faker->name(),
            'email' => $this->faker->unique()->safeEmail(),
            'email_verified_at' => now(),
            'password' => self::$password ??= Hash::make('Password123!'),
            'status' => UserStatus::Active,
            'locale' => 'de',
            'remember_token' => Str::random(10),
        ];
    }

    public function role(RoleSlug $role): self
    {
        return $this->state(fn (): array => ['role_id' => Role::findBySlug($role)->getKey()]);
    }

    public function owner(): self
    {
        return $this->role(RoleSlug::Owner);
    }

    public function manager(): self
    {
        return $this->role(RoleSlug::Manager);
    }

    public function waiter(): self
    {
        return $this->role(RoleSlug::Waiter);
    }

    public function platformAdmin(): self
    {
        return $this->role(RoleSlug::PlatformAdmin)->state(['restaurant_id' => null]);
    }

    public function forRestaurant(Restaurant $restaurant): self
    {
        return $this->state(['restaurant_id' => $restaurant->getKey()]);
    }

    public function inactive(): self
    {
        return $this->state(['status' => UserStatus::Inactive]);
    }
}
