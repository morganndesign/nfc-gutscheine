<?php

declare(strict_types=1);

namespace App\Services\Restaurants;

use App\Enums\RestaurantStatus;
use App\Enums\RoleSlug;
use App\Models\Restaurant;
use App\Models\SystemSetting;
use App\Models\User;
use App\Services\Audit\AuditLogger;
use App\Services\Users\UserService;
use App\Support\Actor;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Platform-level restaurant (tenant) lifecycle.
 */
final class RestaurantService
{
    public function __construct(
        private readonly AuditLogger $audit,
        private readonly UserService $users,
    ) {}

    /**
     * @param  array<string, mixed>  $data
     * @param  array{name: string, email: string, password?: string|null}  $owner
     * @return array{restaurant: Restaurant, owner: User}
     */
    public function create(Actor $actor, array $data, array $owner): array
    {
        return DB::transaction(function () use ($actor, $data, $owner): array {
            $restaurant = new Restaurant;
            $restaurant->fill($data);
            $restaurant->slug = $this->uniqueSlug((string) ($data['slug'] ?? $data['name']));
            $restaurant->status = RestaurantStatus::Active;
            $restaurant->plan = (string) ($data['plan'] ?? SystemSetting::get('platform.default_plan', 'standard'));
            $restaurant->save();

            if (isset($data['settings']) && is_array($data['settings'])) {
                $restaurant->settings->fill($data['settings'])->save();
            }

            $ownerUser = $this->users->create($actor, $restaurant, [
                'name' => $owner['name'],
                'email' => $owner['email'],
                'password' => $owner['password'] ?? null,
                'role' => RoleSlug::Owner->value,
            ]);

            $this->audit->log('restaurant.created', $actor, $restaurant, null, $restaurant->only(['name', 'slug', 'currency', 'timezone']), restaurantId: $restaurant->getKey());

            return ['restaurant' => $restaurant->load('settings'), 'owner' => $ownerUser];
        });
    }

    /** @param array<string, mixed> $data */
    public function update(Actor $actor, Restaurant $restaurant, array $data): Restaurant
    {
        $restaurant->fill($data);
        $dirty = $restaurant->getDirty();

        if ($dirty !== []) {
            $old = array_intersect_key($restaurant->getOriginal(), $dirty);
            $restaurant->save();
            $this->audit->log('restaurant.updated', $actor, $restaurant, $old, $dirty, restaurantId: $restaurant->getKey());
        }

        return $restaurant;
    }

    public function suspend(Actor $actor, Restaurant $restaurant, string $reason): Restaurant
    {
        $restaurant->forceFill([
            'status' => RestaurantStatus::Suspended,
            'suspended_at' => Carbon::now(),
            'suspension_reason' => $reason,
        ])->save();

        $this->audit->log('restaurant.suspended', $actor, $restaurant, ['status' => RestaurantStatus::Active], ['status' => RestaurantStatus::Suspended], ['reason' => $reason], $restaurant->getKey());

        return $restaurant;
    }

    public function reactivate(Actor $actor, Restaurant $restaurant): Restaurant
    {
        $restaurant->forceFill([
            'status' => RestaurantStatus::Active,
            'suspended_at' => null,
            'suspension_reason' => null,
        ])->save();

        $this->audit->log('restaurant.reactivated', $actor, $restaurant, ['status' => RestaurantStatus::Suspended], ['status' => RestaurantStatus::Active], restaurantId: $restaurant->getKey());

        return $restaurant;
    }

    private function uniqueSlug(string $source): string
    {
        $base = Str::slug($source) ?: 'restaurant';
        $base = Str::limit($base, 60, '');
        $slug = $base;
        $i = 2;

        while (Restaurant::withTrashed()->where('slug', $slug)->exists()) {
            $slug = $base.'-'.$i++;
        }

        return $slug;
    }
}
