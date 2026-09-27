<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use Tests\TestCase;

final class PermissionsTest extends TestCase
{
    public function test_waiter_can_only_scan_and_redeem(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $card->public_token])->assertOk();
        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 100], $this->idempotency())->assertCreated();

        $this->getJson('/api/v1/cards')->assertForbidden()->assertJsonPath('code', 'FORBIDDEN');
        $this->getJson("/api/v1/cards/{$card->id}")->assertForbidden();
        $this->postJson('/api/v1/cards', ['value' => 5000])->assertForbidden();
        $this->postJson("/api/v1/cards/{$card->id}/reload", ['amount' => 100], $this->idempotency())->assertForbidden();
        $this->postJson("/api/v1/cards/{$card->id}/block", ['reason' => 'nope'])->assertForbidden();
        $this->getJson('/api/v1/dashboard/stats')->assertForbidden();
        $this->getJson('/api/v1/transactions')->assertForbidden();
        $this->getJson('/api/v1/users')->assertForbidden();
        $this->getJson('/api/v1/settings')->assertForbidden();
        $this->getJson('/api/v1/admin/restaurants')->assertForbidden();
    }

    public function test_manager_manages_cards_but_not_staff_or_settings(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->getJson('/api/v1/cards')->assertOk();
        $this->getJson('/api/v1/dashboard/stats')->assertOk();
        $this->getJson('/api/v1/audit-logs')->assertOk();
        $this->postJson('/api/v1/users', ['name' => 'X', 'email' => 'x@example.com', 'role' => 'waiter'])->assertForbidden();
        $this->putJson('/api/v1/settings/cards', ['allow_reload' => false])->assertForbidden();
        $this->getJson('/api/v1/api-tokens')->assertForbidden();
    }

    public function test_owner_has_full_restaurant_access_but_no_platform_access(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $this->getJson('/api/v1/users')->assertOk();
        $this->getJson('/api/v1/settings')->assertOk();
        $this->getJson('/api/v1/api-tokens')->assertOk();
        $this->getJson('/api/v1/admin/restaurants')->assertForbidden();
        $this->getJson('/api/v1/admin/stats')->assertForbidden();
    }

    public function test_revoked_devices_are_blocked(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $owner = $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $deviceHeader = ['X-Device-Id' => 'b9f1c2d3-4e5f-4a6b-8c7d-9e0f1a2b3c4d'];

        $this->withHeaders($deviceHeader)->getJson('/api/v1/devices/current')->assertOk()->assertJsonPath('data.is_current', true);
        $deviceId = $this->getJson('/api/v1/devices')->json('data.0.id');

        $this->postJson("/api/v1/devices/{$deviceId}/revoke")->assertOk()->assertJsonPath('data.status', 'revoked');

        $this->withHeaders($deviceHeader)->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $card->public_token])
            ->assertForbidden()->assertJsonPath('code', 'DEVICE_REVOKED');

        $this->assertNotNull($owner);
    }
}
