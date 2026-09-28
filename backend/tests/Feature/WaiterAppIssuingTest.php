<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Models\GiftCard;
use App\Models\PersonalAccessToken;
use App\Models\Restaurant;
use App\Models\Role;
use App\Services\GiftCards\CardUrlBuilder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * Selling and programming a card from GiftCard Waiter: managers and owners only, through the same endpoints and
 * services as the dashboard (POST /cards, POST /cards/{card}/nfc/check, POST /cards/{card}/nfc, …/nfc/lock).
 */
final class WaiterAppIssuingTest extends TestCase
{
    private const DEVICE = 'b1a2c3d4-e5f6-4711-8899-aabbccddeeff';

    private const UID = '04A23F1B6C8012';

    private function signIn(string $email): TestResponse
    {
        return $this->withHeaders(['User-Agent' => 'GiftCardWaiter/1.4.3 (Android 14; Pixel 7)'])
            ->postJson('/api/v1/auth/token', [
                'email' => $email,
                'password' => 'Password123!',
                'device_id' => self::DEVICE,
                'device_name' => 'Pixel 7',
                'platform' => 'android',
            ]);
    }

    private function bearer(string $token): self
    {
        $this->app['auth']->forgetGuards();

        return $this->withHeaders(['Authorization' => 'Bearer '.$token, 'X-Device-Id' => self::DEVICE]);
    }

    private function tokenFor(RoleSlug $role, string $email): string
    {
        $restaurant = $this->restaurant(['name' => 'Trattoria Test']);
        $this->staff($restaurant, $role, ['email' => $email]);

        return (string) $this->signIn($email)->assertCreated()->json('data.token');
    }

    public function test_managers_and_owners_get_the_issuing_abilities_waiters_do_not(): void
    {
        $restaurant = $this->restaurant();
        $this->staff($restaurant, RoleSlug::Manager, ['email' => 'mia@example.com']);
        $this->staff($restaurant, RoleSlug::Owner, ['email' => 'otto@example.com']);
        $this->staff($restaurant, RoleSlug::Waiter, ['email' => 'anna@example.com']);

        foreach (['mia@example.com' => 'manager', 'otto@example.com' => 'owner'] as $email => $role) {
            $permissions = $this->signIn($email)->assertCreated()
                ->assertJsonPath('data.user.role.slug', $role)
                ->json('data.user.permissions');
            $this->assertEqualsCanonicalizing(['cards.scan', 'cards.redeem', 'cards.create', 'cards.write_nfc'], $permissions, $role);
        }

        $this->signIn('anna@example.com')->assertCreated()
            ->assertJsonPath('data.user.role.slug', 'waiter')
            ->assertJsonPath('data.user.permissions', ['cards.scan', 'cards.redeem']);
    }

    public function test_manager_sells_and_programs_a_card_through_the_dashboard_endpoints(): void
    {
        $token = $this->tokenFor(RoleSlug::Manager, 'mia@example.com');
        $key = (string) Str::uuid();

        $created = $this->bearer($token)->withHeaders(['Idempotency-Key' => $key])
            ->postJson('/api/v1/cards', ['value' => 5000, 'activate' => true, 'customer' => ['email' => 'guest@example.com']])
            ->assertCreated()
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.balance', 5000)
            ->assertJsonPath('data.customer.email', 'guest@example.com')
            ->assertJsonPath('replayed', false);
        $cardId = (string) $created->json('data.id');
        $url = (string) $created->json('nfc.url');
        $this->assertSame(app(CardUrlBuilder::class)->url(GiftCard::query()->findOrFail($cardId)), $url);

        // A retry with the same key (answer lost) replays instead of selling a second card.
        $this->bearer($token)->withHeaders(['Idempotency-Key' => $key])
            ->postJson('/api/v1/cards', ['value' => 5000, 'activate' => true, 'customer' => ['email' => 'guest@example.com']])
            ->assertOk()->assertJsonPath('replayed', true)->assertJsonPath('data.id', $cardId);
        $this->assertSame(1, GiftCard::query()->count());

        $attempt = (string) Str::uuid();
        $this->bearer($token)->postJson("/api/v1/cards/{$cardId}/nfc/check", ['attempt_id' => $attempt, 'uid' => self::UID, 'current_url' => null])
            ->assertOk()->assertJsonPath('data.status', 'available')->assertJsonPath('data.expected_url', $url);
        $this->bearer($token)->postJson("/api/v1/cards/{$cardId}/nfc", [
            'method' => 'web_nfc',
            'attempt_id' => $attempt,
            'tag_type' => 'ntag215',
            'uid' => self::UID,
            'read_back' => ['uid' => '04:A2:3F:1B:6C:80:12', 'url' => $url],
        ])->assertOk()->assertJsonPath('data.nfc.uid', self::UID)->assertJsonPath('data.nfc.tag_type', 'ntag215');
        $this->bearer($token)->postJson("/api/v1/cards/{$cardId}/nfc/lock", ['attempt_id' => $attempt])
            ->assertOk()->assertJsonPath('data.nfc.locked', true);

        $this->assertDatabaseHas('nfc_write_attempts', ['attempt_id' => $attempt, 'result' => 'succeeded', 'uid' => self::UID]);
        $this->assertDatabaseHas('audit_logs', ['auditable_id' => $cardId, 'action' => 'gift_card.nfc_written']);

        // A failure only the phone sees is logged like the dashboard's.
        $failed = (string) Str::uuid();
        $this->bearer($token)->postJson("/api/v1/cards/{$cardId}/nfc/attempts", [
            'attempt_id' => $failed, 'stage' => 'write', 'result' => 'failed', 'error_code' => 'TAG_REMOVED',
        ])->assertSuccessful();
        $this->assertDatabaseHas('nfc_write_attempts', ['attempt_id' => $failed, 'result' => 'failed', 'error_code' => 'TAG_REMOVED']);
    }

    public function test_the_app_token_still_reaches_nothing_else(): void
    {
        $token = $this->tokenFor(RoleSlug::Manager, 'mia@example.com');
        $card = $this->issueCard(Restaurant::query()->sole());

        $this->bearer($token)->getJson('/api/v1/cards')->assertForbidden();
        $this->bearer($token)->getJson("/api/v1/cards/{$card->id}")->assertForbidden();
        // The tag payload of a card is within `cards.write_nfc` (same path as the programming endpoints).
        $this->bearer($token)->getJson("/api/v1/cards/{$card->id}/nfc")->assertOk();
        $this->bearer($token)->postJson("/api/v1/cards/{$card->id}/reload", ['amount' => 100])->assertForbidden();
        $this->bearer($token)->postJson("/api/v1/cards/{$card->id}/expire")->assertForbidden();
        $this->bearer($token)->getJson('/api/v1/customers')->assertForbidden();
    }

    public function test_waiters_cannot_sell_or_program_cards(): void
    {
        $token = $this->tokenFor(RoleSlug::Waiter, 'anna@example.com');
        $card = $this->issueCard(Restaurant::query()->sole());

        $this->bearer($token)->postJson('/api/v1/cards', ['value' => 5000])->assertForbidden()->assertJsonPath('code', 'FORBIDDEN');
        $this->bearer($token)->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => (string) Str::uuid(), 'uid' => self::UID])->assertForbidden();
        $this->bearer($token)->postJson("/api/v1/cards/{$card->id}/nfc", [
            'method' => 'web_nfc', 'attempt_id' => (string) Str::uuid(), 'tag_type' => 'ntag215', 'uid' => self::UID,
            'read_back' => ['uid' => self::UID, 'url' => 'https://example.test/c/x'],
        ])->assertForbidden();
        $this->assertSame(1, GiftCard::query()->count());
    }

    public function test_a_demoted_manager_loses_card_selling_immediately(): void
    {
        $restaurant = $this->restaurant();
        $manager = $this->staff($restaurant, RoleSlug::Manager, ['email' => 'mia@example.com']);
        $token = (string) $this->signIn('mia@example.com')->assertCreated()->json('data.token');

        $manager->forceFill(['role_id' => Role::query()->where('slug', RoleSlug::Waiter->value)->value('id')])->save();

        $this->bearer($token)->postJson('/api/v1/cards', ['value' => 5000])->assertForbidden();
        $this->assertSame(0, GiftCard::query()->count());
    }

    public function test_the_daily_renewal_aligns_the_abilities_with_the_role(): void
    {
        $restaurant = $this->restaurant();
        $user = $this->staff($restaurant, RoleSlug::Waiter, ['email' => 'anna@example.com']);
        $token = (string) $this->signIn('anna@example.com')->assertCreated()->json('data.token');
        $model = PersonalAccessToken::query()->sole();
        $this->assertSame(['cards.scan', 'cards.redeem'], $model->abilities);

        // Promoted to manager; the next renewal (at most once a day) adds the issuing abilities.
        $user->forceFill(['role_id' => Role::query()->where('slug', RoleSlug::Manager->value)->value('id')])->save();
        $model->forceFill(['expires_at' => Carbon::now()->addDays(3)])->save();
        $this->bearer($token)->getJson('/api/v1/auth/me')->assertOk();

        $this->assertSame(['cards.scan', 'cards.redeem', 'cards.create', 'cards.write_nfc'], $model->refresh()->abilities);
        $this->assertEqualsCanonicalizing(
            ['cards.scan', 'cards.redeem', 'cards.create', 'cards.write_nfc'],
            $this->bearer($token)->getJson('/api/v1/auth/me')->assertOk()->json('data.permissions'),
        );
    }
}
