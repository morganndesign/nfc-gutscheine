<?php

declare(strict_types=1);

use Database\Seeders\SystemSettingsSeeder;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Adds the minimum waiter app versions (app.min_version.*) to existing installations. The seeder only
 * creates settings that are missing, so values already set by the platform admin are kept.
 */
return new class extends Migration
{
    public function up(): void
    {
        (new SystemSettingsSeeder)->run();
    }

    public function down(): void
    {
        DB::table('system_settings')->whereIn('key', ['app.min_version.android', 'app.min_version.ios'])->delete();
    }
};
