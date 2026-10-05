<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use Illuminate\Support\Facades\Auth;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

final class SettingsAndApiTokensTest extends TestCase
{
    public function test_owner_updates_voucher_settings_within_the_platform_limits(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $this->putJson('/api/v1/settings/vouchers', ['allow_reload' => false, 'validity_months' => 60, 'brand_color' => '#112233'])
            ->assertOk()
            ->assertJsonPath('data.allow_reload', false)
            ->assertJsonPath('data.validity_months', 60)
            ->assertJsonPath('data.platform_limits.max_voucher_balance', 50000);

        $this->putJson('/api/v1/settings/vouchers', ['brand_color' => 'red'])->assertJsonValidationErrors('brand_color');
        $this->putJson('/api/v1/settings/vouchers', ['max_voucher_balance' => 50001])->assertJsonValidationErrors('max_voucher_balance');
        $this->putJson('/api/v1/settings/vouchers', ['max_debit_per_transaction' => '100'])->assertJsonValidationErrors('max_debit_per_transaction');
        $this->putJson('/api/v1/settings/vouchers', ['allow_reload' => 'yes'])->assertJsonValidationErrors('allow_reload');
        $this->putJson('/api/v1/settings/vouchers', ['max_debit_per_transaction' => 30000, 'max_debit_per_voucher_per_day' => 20000])
            ->assertJsonValidationErrors('max_debit_per_transaction');
        $this->putJson('/api/v1/settings/vouchers', ['validity_months' => null])->assertOk()->assertJsonPath('data.validity_months', null);
        $this->assertDatabaseHas('audit_logs', ['action' => 'restaurant.settings_updated', 'restaurant_id' => $restaurant->id]);
    }

    public function test_notification_template_override(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $this->getJson('/api/v1/settings/notification-templates')->assertOk()->assertJsonPath('data.0.is_default', true);

        $this->putJson('/api/v1/settings/notification-templates/voucher_issued', [
            'subject' => 'Ihr Gutschein', 'body' => 'Hallo {{ customer_name }}',
        ])->assertSuccessful()->assertJsonPath('data.is_default', false);

        $this->putJson('/api/v1/settings/notification-templates/unknown_key', ['subject' => 'x', 'body' => 'y'])->assertNotFound();
    }

    public function test_api_token_is_restricted_to_its_abilities_and_can_be_revoked(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant, 5000);
        $voucher = $sale->voucher;
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $created = $this->postJson('/api/v1/api-tokens', ['name' => 'POS', 'abilities' => ['vouchers.redeem']])
            ->assertCreated();
        $plain = $created->json('plain_text_token');
        $this->assertNotEmpty($plain);

        // Switch from the session user to pure bearer authentication.
        $this->app['auth']->forgetGuards();

        $presentment = $this->withToken($plain)->postJson('/api/v1/presentments', ['purpose' => 'spend', 'method' => 'printable_qr', 'credential' => $sale->printable->payload])
            ->assertCreated()->json('data.id');
        $this->withToken($plain)->postJson("/api/v1/vouchers/{$voucher->id}/redemptions", ['amount' => 500, 'presentment_id' => $presentment], $this->idempotency())->assertCreated();
        $this->withToken($plain)->getJson('/api/v1/vouchers')->assertForbidden();
        $this->withToken($plain)->postJson("/api/v1/vouchers/{$voucher->id}/reloads", ['amount' => 500, 'payment' => $this->cashPayment()], $this->idempotency())->assertForbidden();

        $tokenId = $created->json('data.id');
        $owner = $this->staff($restaurant, RoleSlug::Owner);
        $this->app['auth']->forgetGuards();
        Sanctum::actingAs($owner, ['*']);
        $this->postJson("/api/v1/api-tokens/{$tokenId}/revoke")->assertOk()->assertJsonPath('data.active', false);

        $this->app['auth']->forgetGuards();
        Auth::forgetUser();
        $this->withToken($plain)->postJson('/api/v1/presentments', ['purpose' => 'spend', 'method' => 'printable_qr', 'credential' => $sale->printable->payload])->assertUnauthorized();
    }

    public function test_tokens_cannot_exceed_creator_permissions(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        // Not even offered to integrations (audit 2026-10-06 L1).
        $this->postJson('/api/v1/api-tokens', ['name' => 'Bad', 'abilities' => ['platform.restaurants.manage']])
            ->assertUnprocessable()->assertJsonValidationErrors('abilities.0');
    }
}
