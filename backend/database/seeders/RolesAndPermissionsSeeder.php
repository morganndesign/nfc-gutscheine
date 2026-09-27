<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Enums\Permission as PermissionEnum;
use App\Enums\RoleSlug;
use App\Models\Permission;
use App\Models\Role;
use Illuminate\Database\Seeder;

final class RolesAndPermissionsSeeder extends Seeder
{
    public function run(): void
    {
        $ids = [];
        foreach (PermissionEnum::cases() as $permission) {
            $model = Permission::query()->updateOrCreate(
                ['slug' => $permission->value],
                ['name' => $permission->label(), 'group' => $permission->group()],
            );
            $ids[$permission->value] = $model->getKey();
        }

        $descriptions = [
            RoleSlug::PlatformAdmin->value => 'Operates the GiftCard Pro platform and manages all restaurants.',
            RoleSlug::Owner->value => 'Full control over one restaurant, its staff, settings and integrations.',
            RoleSlug::Manager->value => 'Manages gift cards, customers and reports of the restaurant.',
            RoleSlug::Waiter->value => 'Scans cards and redeems balances.',
        ];

        foreach (RoleSlug::cases() as $slug) {
            $role = Role::query()->updateOrCreate(
                ['slug' => $slug->value],
                [
                    'name' => $slug->label(),
                    'description' => $descriptions[$slug->value],
                    'scope' => $slug->isPlatform() ? 'platform' : 'restaurant',
                    'rank' => $slug->rank(),
                    'is_system' => true,
                ],
            );

            $role->syncPermissions(array_values(array_map(
                static fn (PermissionEnum $p): string => $ids[$p->value] ?? throw new \LogicException("Unknown permission {$p->value}"),
                $slug->defaultPermissions(),
            )));
        }
    }
}
