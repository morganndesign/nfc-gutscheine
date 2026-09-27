<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Models\SystemSetting;
use App\Models\User;
use Tests\TestCase;

/** GET /api/v1/app/config — public start-up configuration of the native waiter app. */
final class WaiterAppConfigTest extends TestCase
{
    private function setting(string $key, mixed $value): void
    {
        SystemSetting::query()->where('key', $key)->firstOrFail()->forceFill(['value' => $value])->save();
    }

    public function test_config_is_public_and_cacheable(): void
    {
        config(['giftcard.card_base_url' => 'https://cards.example.at']);

        $this->getJson('/api/v1/app/config')
            ->assertOk()
            ->assertHeader('Cache-Control', 'max-age=60, public')
            ->assertJsonPath('data.min_version', ['android' => null, 'ios' => null])
            ->assertJsonPath('data.update_required', null)
            ->assertJsonPath('data.maintenance_notice', null)
            ->assertJsonPath('data.card_domains', ['cards.example.at']);
    }

    public function test_update_is_required_below_the_minimum_version_of_the_platform(): void
    {
        $this->setting('app.min_version.ios', '1.2.0');

        $this->getJson('/api/v1/app/config?platform=ios&version=1.1.9')->assertOk()->assertJsonPath('data.update_required', true);
        $this->getJson('/api/v1/app/config?platform=ios&version=1.10.0')->assertOk()->assertJsonPath('data.update_required', false);
        $this->getJson('/api/v1/app/config?platform=android&version=0.1.0')->assertOk()->assertJsonPath('data.update_required', false);
        $this->getJson('/api/v1/app/config?platform=ios&version=latest')->assertStatus(422)->assertJsonValidationErrors('version');
    }

    public function test_maintenance_notice_is_passed_through(): void
    {
        $this->setting('platform.maintenance_notice', '  Wartung heute 23:00–23:30.  ');

        $this->getJson('/api/v1/app/config')->assertJsonPath('data.maintenance_notice', 'Wartung heute 23:00–23:30.');
    }

    public function test_platform_admin_sets_minimum_versions_with_validation_and_audit(): void
    {
        $this->actingAs(User::factory()->platformAdmin()->create(), 'sanctum');

        $this->putJson('/api/v1/admin/system-settings', ['settings' => [['key' => 'app.min_version.android', 'value' => 'v2']]])
            ->assertStatus(422)->assertJsonValidationErrors('settings.0.value');

        $this->putJson('/api/v1/admin/system-settings', ['settings' => [['key' => 'app.min_version.android', 'value' => '1.3.0']]])
            ->assertOk();

        $this->assertSame('1.3.0', SystemSetting::get('app.min_version.android'));
        $this->assertDatabaseHas('audit_logs', ['action' => 'system_setting.updated']);
        $this->getJson('/api/v1/app/config?platform=android&version=1.2.9')->assertJsonPath('data.update_required', true);
    }
}
