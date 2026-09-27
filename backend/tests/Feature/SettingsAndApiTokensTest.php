<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use Illuminate\Support\Facades\Auth;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

final class SettingsAndApiTokensTest extends TestCase
{
    public function test_owner_updates_card_settings_with_validation(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $this->putJson('/api/v1/settings/cards', ['allow_reload' => false, 'default_validity_months' => 24, 'brand_color' => '#112233'])
            ->assertOk()
            ->assertJsonPath('data.allow_reload', false)
            ->assertJsonPath('data.default_validity_months', 24);

        $this->putJson('/api/v1/settings/cards', ['brand_color' => 'red'])->assertJsonValidationErrors('brand_color');
        $this->putJson('/api/v1/settings/cards', ['max_card_value' => 500000])->assertJsonValidationErrors('max_card_value');
        $this->assertDatabaseHas('audit_logs', ['action' => 'restaurant.settings_updated', 'restaurant_id' => $restaurant->id]);
    }

    public function test_notification_template_override(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $this->getJson('/api/v1/settings/notification-templates')->assertOk()->assertJsonPath('data.0.is_default', true);

        $this->putJson('/api/v1/settings/notification-templates/card_issued', [
            'locale' => 'de', 'subject' => 'Ihr Gutschein', 'body' => 'Hallo {{ customer_name }}',
        ])->assertSuccessful()->assertJsonPath('data.is_default', false);

        $this->putJson('/api/v1/settings/notification-templates/unknown_key', ['subject' => 'x', 'body' => 'y'])->assertNotFound();
    }

    public function test_api_token_is_restricted_to_its_abilities_and_can_be_revoked(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $created = $this->postJson('/api/v1/api-tokens', ['name' => 'POS', 'abilities' => ['cards.scan', 'cards.redeem']])
            ->assertCreated();
        $plain = $created->json('plain_text_token');
        $this->assertNotEmpty($plain);

        // Switch from the session user to pure bearer authentication.
        $this->app['auth']->forgetGuards();

        $this->withToken($plain)->postJson('/api/v1/scan', ['method' => 'api', 'token' => $card->public_token])->assertOk();
        $this->withToken($plain)->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 500], $this->idempotency())->assertCreated();
        $this->withToken($plain)->getJson('/api/v1/cards')->assertForbidden();
        $this->withToken($plain)->postJson("/api/v1/cards/{$card->id}/reload", ['amount' => 500], $this->idempotency())->assertForbidden();

        $tokenId = $created->json('data.id');
        $owner = $this->staff($restaurant, RoleSlug::Owner);
        $this->app['auth']->forgetGuards();
        Sanctum::actingAs($owner, ['*']);
        $this->postJson("/api/v1/api-tokens/{$tokenId}/revoke")->assertOk()->assertJsonPath('data.active', false);

        $this->app['auth']->forgetGuards();
        Auth::forgetUser();
        $this->withToken($plain)->postJson('/api/v1/scan', ['method' => 'api', 'token' => $card->public_token])->assertUnauthorized();
    }

    public function test_tokens_cannot_exceed_creator_permissions(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $this->postJson('/api/v1/api-tokens', ['name' => 'Bad', 'abilities' => ['platform.restaurants.manage']])
            ->assertForbidden()->assertJsonPath('code', 'ROLE_ASSIGNMENT_FORBIDDEN');
    }
}
