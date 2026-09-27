<?php

declare(strict_types=1);

namespace Tests;

use App\Data\IssueGiftCardData;
use App\Data\TransactionResult;
use App\Enums\RoleSlug;
use App\Models\GiftCard;
use App\Models\Restaurant;
use App\Models\User;
use App\Services\GiftCards\CardUrlBuilder;
use App\Services\GiftCards\GiftCardService;
use App\Support\Actor;
use App\Support\Tenancy\TenantContext;
use Database\Seeders\NotificationTemplateSeeder;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\Sanctum;

abstract class TestCase extends BaseTestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed([RolesAndPermissionsSeeder::class, NotificationTemplateSeeder::class]);
    }

    protected function restaurant(array $attributes = []): Restaurant
    {
        return Restaurant::factory()->create($attributes)->load('settings');
    }

    protected function staff(Restaurant $restaurant, RoleSlug $role = RoleSlug::Manager, array $attributes = []): User
    {
        return User::factory()->forRestaurant($restaurant)->role($role)->create($attributes);
    }

    protected function actingAsStaff(Restaurant $restaurant, RoleSlug $role = RoleSlug::Manager): User
    {
        $user = $this->staff($restaurant, $role);
        Sanctum::actingAs($user, ['*']);

        return $user;
    }

    /**
     * Issues a card through the service layer (consistent ledger), within the restaurant's tenant context.
     */
    protected function issueCard(Restaurant $restaurant, int $value = 5000, ?User $by = null, array $overrides = []): GiftCard
    {
        return $this->asTenant($restaurant, function () use ($restaurant, $value, $by, $overrides): TransactionResult {
            $by ??= $this->staff($restaurant, RoleSlug::Manager);

            return app(GiftCardService::class)->issue(new Actor($by), new IssueGiftCardData(
                value: $value,
                expiresOn: isset($overrides['expires_at']) ? $overrides['expires_at']->copy()->timezone($restaurant->timezone)->format('Y-m-d') : null,
                useDefaultExpiry: ! isset($overrides['expires_at']),
                customerId: $overrides['customer_id'] ?? null,
                activate: $overrides['activate'] ?? true,
                tagType: $overrides['tag_type'] ?? null,
            ));
        })->card;
    }

    /**
     * Programs a tag through the dashboard's Web NFC workflow: check → (write) → read back → bind.
     * `$readBackUrl` defaults to the card's own URL (a correct write).
     */
    protected function programTag(GiftCard $card, string $uid, string $tagType = 'ntag215', ?string $readBackUrl = null, ?string $currentUrl = null): TestResponse
    {
        $attempt = (string) Str::uuid();
        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => $attempt, 'uid' => $uid, 'current_url' => $currentUrl])
            ->assertOk()->assertJsonPath('data.status', 'available');

        return $this->postJson("/api/v1/cards/{$card->id}/nfc", [
            'method' => 'web_nfc',
            'attempt_id' => $attempt,
            'tag_type' => $tagType,
            'uid' => $uid,
            'read_back' => ['uid' => $uid, 'url' => $readBackUrl ?? app(CardUrlBuilder::class)->url($card)],
        ]);
    }

    /**
     * @template T
     *
     * @param  callable(): T  $callback
     * @return T
     */
    protected function asTenant(Restaurant $restaurant, callable $callback): mixed
    {
        return app(TenantContext::class)->runAs($restaurant->load('settings'), $callback);
    }

    /** @return array<string, string> */
    protected function idempotency(?string $key = null): array
    {
        return ['Idempotency-Key' => $key ?? (string) Str::uuid()];
    }

    protected function assertLedgerConsistent(GiftCard $card): void
    {
        $sum = (int) GiftCard::query()->withoutGlobalScopes()->findOrFail($card->getKey())
            ->transactions()->withoutGlobalScopes()->sum('amount');

        $this->assertSame(
            GiftCard::query()->withoutGlobalScopes()->findOrFail($card->getKey())->balance,
            $sum,
            'Card balance must equal the sum of its ledger entries.',
        );
    }
}
