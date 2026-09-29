<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use Tests\TestCase;

/**
 * Owner-facing wording and numbers.
 */
final class PilotReadinessTest extends TestCase
{
    public function test_dashboard_reports_the_vouchers_carrying_the_liability(): void
    {
        $restaurant = $this->restaurant();
        $this->issueVoucher($restaurant, 5000);
        $this->issueVoucher($restaurant, 2500);
        $empty = $this->sell($restaurant, 1000);
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $this->redeemWithQr($empty->voucher, $empty->printable->payload, 1000)->assertCreated();

        $this->getJson('/api/v1/dashboard/stats')->assertOk()
            ->assertJsonPath('data.outstanding_balance', 7500)
            ->assertJsonPath('data.outstanding_vouchers', 2)
            ->assertJsonPath('data.monthly_redeemed', 1000);
    }

    public function test_expired_vouchers_still_count_as_liability(): void
    {
        $restaurant = $this->restaurant();
        $voucher = $this->issueVoucher($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $this->postJson("/api/v1/vouchers/{$voucher->id}/expire", ['reason' => 'Test'])->assertOk();

        $this->getJson('/api/v1/dashboard/stats')->assertOk()
            ->assertJsonPath('data.outstanding_balance', 5000)
            ->assertJsonPath('data.vouchers_expired', 1);
    }

    public function test_new_devices_are_named_after_hardware_and_browser_not_the_person(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $iphone = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1';

        $this->withHeaders(['X-Device-Id' => 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 'User-Agent' => $iphone])
            ->getJson('/api/v1/devices/current')
            ->assertOk()
            ->assertJsonPath('data.name', 'iPhone · Safari');
    }

    public function test_exports_use_readable_status_and_type_names(): void
    {
        $restaurant = $this->restaurant();
        $this->issueVoucher($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $this->assertStringContainsString(';Active;', $this->get('/api/v1/vouchers/export')->assertOk()->streamedContent());
        $this->assertStringContainsString(';Sale;', $this->get('/api/v1/transactions/export')->assertOk()->streamedContent());
    }
}
