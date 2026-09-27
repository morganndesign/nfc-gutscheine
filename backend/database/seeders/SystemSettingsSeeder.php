<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\SystemSetting;
use Illuminate\Database\Seeder;

final class SystemSettingsSeeder extends Seeder
{
    public function run(): void
    {
        $defaults = [
            ['key' => 'platform.support_email', 'value' => 'support@giftcardpro.app', 'type' => 'string', 'description' => 'Support contact shown to restaurant staff (e.g. when an account is suspended).', 'is_public' => true],
            ['key' => 'platform.maintenance_notice', 'value' => null, 'type' => 'string', 'description' => 'Optional banner shown to every signed-in user (planned maintenance, incidents). Leave empty to hide.', 'is_public' => true],
            ['key' => 'app.min_version.android', 'value' => null, 'type' => 'string', 'description' => 'Oldest GiftCard Waiter version allowed on Android (e.g. 1.0.0). Older apps ask the waiter to update. Empty = no minimum.', 'is_public' => true],
            ['key' => 'app.min_version.ios', 'value' => null, 'type' => 'string', 'description' => 'Oldest GiftCard Waiter version allowed on iPhone (e.g. 1.0.0). Older apps ask the waiter to update. Empty = no minimum.', 'is_public' => true],
            ['key' => 'platform.default_plan', 'value' => 'standard', 'type' => 'string', 'description' => 'Plan assigned to newly onboarded restaurants.', 'is_public' => false],
        ];

        foreach ($defaults as $setting) {
            SystemSetting::query()->firstOrCreate(['key' => $setting['key']], $setting);
        }
    }
}
