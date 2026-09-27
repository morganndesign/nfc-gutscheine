<?php

declare(strict_types=1);

namespace Database\Seeders;

use Illuminate\Database\Seeder;

final class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // Reference data: safe to run on every deploy (idempotent).
        $this->call([
            RolesAndPermissionsSeeder::class,
            NotificationTemplateSeeder::class,
            SystemSettingsSeeder::class,
        ]);

        if (app()->environment(['local', 'testing', 'staging']) || (bool) config('giftcard.seed_demo_data')) {
            $this->call(DemoSeeder::class);
        }
    }
}
