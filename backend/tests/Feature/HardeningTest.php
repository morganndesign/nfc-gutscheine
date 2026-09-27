<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\GiftCardStatus;
use App\Enums\RoleSlug;
use App\Http\Middleware\TrackDevice;
use App\Models\AuditLog;
use App\Models\Customer;
use App\Models\GiftCard;
use App\Models\GiftCardTransaction;
use App\Models\NotificationLog;
use App\Support\Tenancy\TenantContext;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\Request;
use Illuminate\Session\ArraySessionHandler;
use Illuminate\Session\Store;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

/**
 * Regression tests for issues found in the production-readiness audit.
 */
final class HardeningTest extends TestCase
{
    public function test_expiry_is_the_end_of_the_day_in_the_restaurant_timezone(): void
    {
        $restaurant = $this->restaurant(['timezone' => 'Europe/Vienna']);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $day = Carbon::now('Europe/Vienna')->addMonths(6)->format('Y-m-d');

        $id = $this->postJson('/api/v1/cards', ['value' => 5000, 'expires_at' => $day])->assertCreated()->json('data.id');

        $card = GiftCard::query()->withoutGlobalScopes()->findOrFail($id);
        $expected = Carbon::parse($day.' 23:59:59', 'Europe/Vienna')->utc();
        $this->assertSame($expected->format('Y-m-d H:i:s'), $card->expires_at?->utc()->format('Y-m-d H:i:s'));
    }

    public function test_explicit_null_expiry_means_no_expiry_and_missing_means_default(): void
    {
        $restaurant = $this->restaurant();
        $restaurant->settings->forceFill(['default_validity_months' => 24])->save();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $noExpiry = $this->postJson('/api/v1/cards', ['value' => 5000, 'expires_at' => null])->assertCreated()->json('data');
        $default = $this->postJson('/api/v1/cards', ['value' => 5000])->assertCreated()->json('data');

        $this->assertNull($noExpiry['expires_at']);
        $this->assertNotNull($default['expires_at']);
    }

    public function test_replacing_an_inactive_card_keeps_it_inactive(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 5000, null, ['activate' => false]);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->postJson("/api/v1/cards/{$card->id}/replace", ['reason' => 'Damaged in the printer'])
            ->assertCreated()
            ->assertJsonPath('data.status', 'inactive')
            ->assertJsonPath('data.balance', 5000);
    }

    public function test_replacing_an_empty_card_writes_no_zero_ledger_entries(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 5000], $this->idempotency());

        $newId = $this->postJson("/api/v1/cards/{$card->id}/replace", ['reason' => 'Lost'])->assertCreated()->json('data.id');

        $this->assertSame(0, GiftCardTransaction::query()->withoutGlobalScopes()->where('amount', 0)->count());
        $this->assertSame(0, GiftCardTransaction::query()->withoutGlobalScopes()->where('gift_card_id', $newId)->count());
        $this->assertSame(GiftCardStatus::Redeemed, GiftCard::query()->withoutGlobalScopes()->findOrFail($newId)->status);
    }

    public function test_inactive_cards_cannot_transfer_value(): void
    {
        $restaurant = $this->restaurant();
        $inactive = $this->issueCard($restaurant, 5000, null, ['activate' => false]);
        $target = $this->issueCard($restaurant, 1000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->postJson("/api/v1/cards/{$inactive->id}/transfer", ['target_card_id' => $target->id], $this->idempotency())
            ->assertStatus(409)->assertJsonPath('code', 'INVALID_CARD_STATE');
        $this->assertSame(1000, $target->refresh()->balance);
    }

    public function test_rebinding_the_same_secure_chip_keeps_the_replay_counter(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson("/api/v1/cards/{$card->id}/nfc", ['method' => 'provisioned', 'tag_type' => 'ntag424_dna', 'locked' => true])->assertOk();
        // The chip UID of an NTAG 424 DNA is bound on its first verified (SUN) tap.
        GiftCard::query()->withoutGlobalScopes()->whereKey($card->id)->update(['nfc_uid' => '04A39493CC8680', 'nfc_read_counter' => 42]);

        $this->postJson("/api/v1/cards/{$card->id}/nfc", ['method' => 'provisioned', 'tag_type' => 'ntag424_dna', 'locked' => true])->assertOk();
        $fresh = GiftCard::query()->withoutGlobalScopes()->findOrFail($card->id);
        $this->assertSame(42, $fresh->nfc_read_counter);
        $this->assertSame('04A39493CC8680', $fresh->nfc_uid);

        // An unverified UID is never accepted, not even for a secure chip.
        $this->postJson("/api/v1/cards/{$card->id}/nfc", ['method' => 'provisioned', 'tag_type' => 'ntag424_dna', 'uid' => '04A39493CC8680'])
            ->assertUnprocessable()->assertJsonValidationErrors('uid');
    }

    public function test_card_creation_is_idempotent_and_validates_the_key(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $headers = $this->idempotency('create-card-attempt-1');

        $first = $this->postJson('/api/v1/cards', ['value' => 5000], $headers)->assertCreated();
        $again = $this->postJson('/api/v1/cards', ['value' => 5000], $headers)->assertOk()->assertJsonPath('replayed', true);

        $this->assertSame($first->json('data.id'), $again->json('data.id'));
        $this->assertSame(1, GiftCard::query()->withoutGlobalScopes()->count());

        $this->postJson('/api/v1/cards', ['value' => 5000], ['Idempotency-Key' => str_repeat('x', 200)])->assertStatus(400);
        $this->postJson('/api/v1/cards', ['value' => 5000], ['Idempotency-Key' => 'reserved:in'])->assertStatus(400);
    }

    public function test_session_is_pinned_to_the_device_it_started_on(): void
    {
        $restaurant = $this->restaurant();
        $user = $this->staff($restaurant, RoleSlug::Waiter);
        app(TenantContext::class)->set($restaurant);
        $session = new Store('test', new ArraySessionHandler(10));
        $middleware = app(TrackDevice::class);

        $request = function (string $deviceId) use ($session, $user): Request {
            $request = Request::create('/api/v1/scan', 'POST', server: ['HTTP_X_DEVICE_ID' => $deviceId]);
            $request->setLaravelSession($session);
            $request->setUserResolver(static fn () => $user);

            return $request;
        };

        $middleware->handle($request('aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa'), static fn () => response('ok'));
        $middleware->handle($request('aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa'), static fn () => response('ok'));

        $this->expectException(AuthenticationException::class);
        $middleware->handle($request('bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb'), static fn () => response('ok'));
    }

    public function test_cards_of_closed_restaurants_are_not_disclosed(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $restaurant->delete();

        $this->getJson("/api/v1/public/cards/{$card->public_token}")->assertNotFound();
    }

    public function test_each_card_event_sends_exactly_one_email(): void
    {
        Mail::fake();
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $id = $this->postJson('/api/v1/cards', ['value' => 5000, 'customer' => ['email' => 'once@example.com']])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/cards/{$id}/reload", ['amount' => 1000], $this->idempotency())->assertCreated();

        Mail::assertSentCount(2);
    }

    public function test_customer_personal_data_never_enters_the_audit_trail(): void
    {
        Mail::fake();
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $customer = Customer::factory()->create(['restaurant_id' => $restaurant->id, 'email' => 'old@example.com']);

        $this->patchJson("/api/v1/customers/{$customer->id}", ['email' => 'new@example.com', 'phone' => '+43 1 234'])->assertOk();
        $log = AuditLog::query()->where('action', 'customer.updated')->firstOrFail();
        $this->assertStringNotContainsString('example.com', (string) json_encode([$log->old_values, $log->new_values]));
        $this->assertSame('[personal data]', $log->new_values['email'] ?? null);

        $cardId = $this->postJson('/api/v1/cards', ['value' => 5000, 'customer_id' => $customer->id])->assertCreated()->json('data.id');
        $this->assertTrue(NotificationLog::query()->where('recipient', 'new@example.com')->exists());

        $this->postJson("/api/v1/customers/{$customer->id}/anonymize")->assertOk();
        $this->assertFalse(NotificationLog::query()->where('recipient', 'new@example.com')->exists());
        $this->assertNotNull($cardId);
    }

    public function test_invalid_chip_serial_numbers_are_rejected(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $card->public_token, 'nfc_uid' => str_repeat('A', 40)])
            ->assertJsonValidationErrors('nfc_uid');
    }

    public function test_health_check_verifies_database_and_cache(): void
    {
        $this->get('/up')->assertOk();
    }

    public function test_cors_is_disabled(): void
    {
        $this->withHeaders(['Origin' => 'https://evil.example', 'Access-Control-Request-Method' => 'POST'])
            ->options('/api/v1/auth/login')
            ->assertHeaderMissing('Access-Control-Allow-Origin');
    }

    public function test_exports_use_decimal_comma_for_german_locales(): void
    {
        $restaurant = $this->restaurant(['locale' => 'de-AT']);
        $this->issueCard($restaurant, 1250);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $csv = $this->get('/api/v1/transactions/export')->assertOk()->streamedContent();
        $this->assertStringContainsString(';12,50;', $csv);
    }
}
