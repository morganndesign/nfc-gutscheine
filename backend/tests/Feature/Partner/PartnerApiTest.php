<?php

declare(strict_types=1);

namespace Tests\Feature\Partner;

use App\Enums\DeviceStatus;
use App\Enums\RoleSlug;
use App\Models\Device;
use App\Models\Partner;
use App\Models\PartnerConnection;
use App\Models\PartnerLinkCode;
use App\Models\Restaurant;
use App\Models\User;
use App\Models\Voucher;
use App\Notifications\PartnerConnectedNotification;
use App\Services\Partners\PartnerService;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\Sanctum;
use Tests\Support\Ntag424Chip;
use Tests\Support\WithCards;
use Tests\TestCase;

/**
 * The POS partner API (decision 2026-10-07): a till system with one partner key reaches only the restaurants that
 * connected it with a one-time code, redeems gift cards (live authentication relayed by its NFC reader) and printed
 * vouchers (QR) inside its own app, and each of its tills is a revocable device of the restaurant.
 */
final class PartnerApiTest extends TestCase
{
    use WithCards;

    private Restaurant $restaurant;

    private Partner $partner;

    private string $key;

    private string $connectionId = '';

    private string $token = '';

    protected function setUp(): void
    {
        parent::setUp();
        $this->restaurant = $this->restaurant(['name' => 'Trattoria Bella Vista']);
        [$this->partner, $this->key] = app(PartnerService::class)->create('Kassa Wien GmbH', 'dev@kassa.example');
    }

    protected function tearDown(): void
    {
        $this->tearDownCardKeystore();
        parent::tearDown();
    }

    /** The owner creates a code in the dashboard; the POS company redeems it and gets the restaurant's till token. */
    private function connect(?Restaurant $restaurant = null): string
    {
        $restaurant ??= $this->restaurant;
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $code = (string) $this->postJson('/api/v1/partner-connections/code')->assertCreated()->json('data.code');
        $this->app['auth']->forgetGuards();
        $connected = $this->partnerCall('POST', 'connections', ['code' => $code])->assertCreated();
        $this->token = (string) $connected->json('data.token');

        return (string) $connected->json('data.id');
    }

    /** @param array<string, mixed> $body @param array<string, string> $headers */
    private function partnerCall(string $method, string $path, array $body = [], array $headers = [], ?string $key = null): TestResponse
    {
        return $this->json($method, '/api/partner/v1/'.$path, $body, ['Authorization' => 'Bearer '.($key ?? $this->key), 'Accept-Language' => 'de'] + $headers);
    }

    /** @param array<string, mixed> $body @param array<string, string> $headers */
    private function till(string $method, string $path, array $body = [], string $terminal = 'KASSE-01', array $headers = []): TestResponse
    {
        return $this->partnerCall($method, $path, $body, ['X-Terminal-Id' => $terminal, 'X-Terminal-Name' => 'Theke'] + $headers, $this->token);
    }

    /** What the POS app does with its NFC reader: NDEF URL, EV2 part 1, relay, answer. */
    private function tapAtTill(Ntag424Chip $chip, string $terminal = 'KASSE-01'): TestResponse
    {
        $begun = $this->till('POST', 'cards/authentications', [
            'tap_url' => $chip->readNdefUrl(),
            'rf_uid' => $chip->uidHex(),
            'challenge' => bin2hex(substr($chip->authenticateFirst(), 0, 16)),
        ], $terminal);
        if ($begun->status() !== 200) {
            return $begun;
        }
        $answer = $chip->transceive((string) hex2bin((string) $begun->json('data.command')));

        return $this->till('POST', 'cards/authentications/'.$begun->json('data.authentication'), ['response' => bin2hex($answer)], $terminal);
    }

    public function test_a_partner_key_reaches_only_restaurants_that_connected_it_with_a_one_time_code(): void
    {
        $this->partnerCall('GET', 'me', key: 'gcpp_wrong')->assertUnauthorized();
        $this->getJson('/api/partner/v1/me')->assertUnauthorized();
        $this->partnerCall('GET', 'me')->assertOk()->assertJsonPath('data.partner.name', 'Kassa Wien GmbH')->assertJsonPath('data.connections', 0);

        // Waiters and managers cannot connect a till system; the owner can.
        $this->actingAsStaff($this->restaurant, RoleSlug::Manager);
        $this->postJson('/api/v1/partner-connections/code')->assertForbidden();
        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        $code = (string) $this->postJson('/api/v1/partner-connections/code')->assertCreated()->assertJsonStructure(['data' => ['code', 'expires_at']])->json('data.code');
        $this->assertMatchesRegularExpression('/^[A-Z2-9]{4}-[A-Z2-9]{4}$/', $code);
        $this->app['auth']->forgetGuards();

        $this->partnerCall('POST', 'connections', ['code' => 'AAAA-BBBB'])->assertStatus(422)->assertJsonPath('code', 'LINK_CODE_INVALID');
        $connected = $this->partnerCall('POST', 'connections', ['code' => strtolower(str_replace('-', ' ', $code))])->assertCreated()
            ->assertJsonPath('data.restaurant.name', 'Trattoria Bella Vista')->assertJsonPath('data.restaurant.currency', 'EUR')
            ->assertJsonStructure(['data' => ['id', 'token', 'rules' => ['allow_partial_redemption', 'max_debit_per_transaction']]]);
        $connection = (string) $connected->json('data.id');
        $token = (string) $connected->json('data.token');
        $this->assertStringStartsWith('gcpc_', $token);
        // Single use.
        $this->partnerCall('POST', 'connections', ['code' => $code])->assertStatus(422)->assertJsonPath('code', 'LINK_CODE_INVALID');
        // The list never shows a token.
        $this->partnerCall('GET', 'connections')->assertOk()->assertJsonCount(1, 'data')->assertJsonMissingPath('data.0.token');
        // The tills use the restaurant's token; the partner key does not reach a restaurant, the token not the partner's list.
        $this->partnerCall('GET', 'connection', key: $token)->assertOk()->assertJsonPath('data.id', $connection);
        $this->partnerCall('GET', 'connection')->assertUnauthorized();
        $this->partnerCall('GET', 'connections', key: $token)->assertUnauthorized();
        $this->partnerCall('GET', 'connection', key: 'gcpc_wrong')->assertUnauthorized();

        // A new token for this restaurant (a till was stolen): the old one stops, the new one works; another partner
        // cannot do it.
        [, $otherKey] = app(PartnerService::class)->create('Andere Kasse', null);
        $this->partnerCall('POST', "connections/{$connection}/token", key: $otherKey)->assertForbidden()->assertJsonPath('code', 'CONNECTION_REVOKED');
        $fresh = (string) $this->partnerCall('POST', "connections/{$connection}/token")->assertCreated()->json('data.token');
        $this->partnerCall('GET', 'connection', key: $token)->assertUnauthorized();
        $this->partnerCall('GET', 'connection', key: $fresh)->assertOk();

        // An expired code connects nothing.
        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        $late = (string) $this->postJson('/api/v1/partner-connections/code')->json('data.code');
        $this->app['auth']->forgetGuards();
        Carbon::setTestNow(now()->addHours(25));
        $this->partnerCall('POST', 'connections', ['code' => $late], key: $otherKey)->assertStatus(422);
    }

    public function test_a_gift_card_is_tapped_at_the_pos_and_part_of_the_bill_is_paid_with_it(): void
    {
        $this->setUpCardKeystore();
        [$card, $voucher] = $this->activeCardVoucher($this->restaurant, 5000);
        $this->connectionId = $this->connect();

        // A card that refused step 2 (only its status word): the server says so, it is not a format error.
        $begun = $this->till('POST', 'cards/authentications', [
            'tap_url' => $this->chip($card)->readNdefUrl(),
            'rf_uid' => $this->chip($card)->uidHex(),
            'challenge' => bin2hex(substr($this->chip($card)->authenticateFirst(), 0, 16)),
        ])->assertOk();
        $this->till('POST', 'cards/authentications/'.$begun->json('data.authentication'), ['response' => '91AE'])
            ->assertForbidden()->assertJsonPath('code', 'CARD_AUTHENTICATION_FAILED');

        $presented = $this->tapAtTill($this->chip($card))->assertCreated()
            ->assertJsonPath('data.method', 'card')->assertJsonPath('data.voucher.balance', 5000)->assertJsonPath('data.voucher.redeemable', true)
            ->assertJsonPath('data.card.number', $card->card_number);
        $presentment = (string) $presented->json('data.presentment_id');

        $key = (string) Str::uuid();
        $this->till('POST', 'redemptions', ['presentment_id' => $presentment, 'amount' => 4500, 'reference' => 'Bon 4711', 'staff' => 'Max'], headers: ['Idempotency-Key' => $key])
            ->assertCreated()->assertJsonPath('data.amount', 4500)->assertJsonPath('data.balance_after', 500)->assertJsonPath('data.reference', 'Bon 4711')
            ->assertJsonPath('data.replayed', false);
        // The same request again (the answer was lost): the same booking, nothing twice.
        $this->till('POST', 'redemptions', ['presentment_id' => $presentment, 'amount' => 4500, 'reference' => 'Bon 4711'], headers: ['Idempotency-Key' => $key])
            ->assertOk()->assertJsonPath('data.replayed', true)->assertJsonPath('data.balance_after', 500);
        $this->till('GET', 'redemptions/'.$key)->assertOk()->assertJsonPath('data.status', 'booked')->assertJsonPath('data.balance_after', 500);
        $this->till('GET', 'redemptions/'.Str::uuid())->assertOk()->assertJsonPath('data.status', 'not_booked');
        // A presentment pays once.
        $this->till('POST', 'redemptions', ['presentment_id' => $presentment, 'amount' => 100], headers: ['Idempotency-Key' => (string) Str::uuid()])
            ->assertStatus(422)->assertJsonPath('code', 'PRESENTMENT_INVALID')->assertJsonPath('context.reason', 'already_used');
        $this->assertSame(500, $voucher->refresh()->balance);

        // The till is a device of the restaurant, named after the POS system; the booking names it and the staff.
        /** @var Device $device */
        $device = Device::query()->withoutGlobalScopes()->where('type', 'pos')->sole();
        $this->assertSame('Kassa Wien GmbH · Theke', $device->name);
        $this->assertDatabaseHas('voucher_transactions', ['voucher_id' => $voucher->id, 'device_id' => $device->id, 'reference' => 'Bon 4711', 'note' => 'Kasse: Max', 'user_id' => null]);
        $this->assertLedgerConsistent($voucher);
    }

    public function test_a_printed_voucher_is_scanned_at_the_pos_and_a_cancelled_bill_gives_the_amount_back(): void
    {
        $sale = $this->sell($this->restaurant, 3000);
        $this->connectionId = $this->connect();
        $this->till('POST', 'vouchers/scan', ['code' => 'GCPV1.not-a-voucher'])->assertStatus(422)->assertJsonPath('code', 'MEDIUM_NOT_RECOGNIZED');
        $presentment = (string) $this->till('POST', 'vouchers/scan', ['code' => (string) $sale->printable->payload])->assertCreated()
            ->assertJsonPath('data.method', 'qr')->assertJsonPath('data.voucher.balance', 3000)->assertJsonPath('data.voucher.max_amount', 3000)->json('data.presentment_id');

        // Another till of the same POS cannot use this till's presentment.
        $this->till('POST', 'redemptions', ['presentment_id' => $presentment, 'amount' => 1000], 'KASSE-02', ['Idempotency-Key' => (string) Str::uuid()])
            ->assertStatus(422)->assertJsonPath('context.reason', 'other_device');
        $redemption = (string) $this->till('POST', 'redemptions', ['presentment_id' => $presentment, 'amount' => 1000], headers: ['Idempotency-Key' => (string) Str::uuid()])
            ->assertCreated()->assertJsonPath('data.balance_after', 2000)->json('data.id');
        // More than the balance or not a whole voucher: refused by the restaurant's rules.
        $again = (string) $this->till('POST', 'vouchers/scan', ['code' => (string) $sale->printable->payload])->json('data.presentment_id');
        $this->till('POST', 'redemptions', ['presentment_id' => $again, 'amount' => 5000], headers: ['Idempotency-Key' => (string) Str::uuid()])
            ->assertStatus(422)->assertJsonPath('code', 'INSUFFICIENT_BALANCE');

        // The bill was cancelled: the till gives the amount back, once.
        $this->till('POST', "redemptions/{$redemption}/cancellation", ['reason' => 'Bon storniert'])->assertCreated()
            ->assertJsonPath('data.amount', 1000)->assertJsonPath('data.balance_after', 3000);
        $this->till('POST', "redemptions/{$redemption}/cancellation", ['reason' => 'Bon storniert'])->assertStatus(409)->assertJsonPath('code', 'TRANSACTION_NOT_REVERSIBLE');
        $this->assertSame(3000, $sale->voucher->refresh()->balance);

        // Too late at the till: the restaurant corrects it in its dashboard.
        $p = (string) $this->till('POST', 'vouchers/scan', ['code' => (string) $sale->printable->payload])->json('data.presentment_id');
        $late = (string) $this->till('POST', 'redemptions', ['presentment_id' => $p, 'amount' => 500], headers: ['Idempotency-Key' => (string) Str::uuid()])->json('data.id');
        Carbon::setTestNow(now()->addMinutes(61));
        $this->till('POST', "redemptions/{$late}/cancellation", ['reason' => 'zu spät'])->assertStatus(409)->assertJsonPath('context.reason', 'too_late');
        $this->assertLedgerConsistent($sale->voucher);
    }

    public function test_a_partner_never_reaches_another_restaurants_vouchers_or_redemptions(): void
    {
        $other = $this->restaurant(['name' => 'Anderes Lokal']);
        $foreign = $this->sell($other, 3000);
        $this->connectionId = $this->connect();

        $this->till('POST', 'vouchers/scan', ['code' => (string) $foreign->printable->payload])->assertStatus(422)->assertJsonPath('code', 'MEDIUM_NOT_RECOGNIZED');
        // A redemption the restaurant booked itself is not the till's to cancel.
        $own = $this->sell($this->restaurant, 3000);
        $this->actingAsStaff($this->restaurant, RoleSlug::Manager);
        $presentment = (string) $this->present((string) $own->printable->payload)->json('data.id');
        $staffRedemption = (string) $this->postJson("/api/v1/vouchers/{$own->voucher->id}/redemptions", ['amount' => 500, 'presentment_id' => $presentment], $this->idempotency())
            ->assertCreated()->json('data.transaction.id');
        $this->app['auth']->forgetGuards();
        $this->till('POST', "redemptions/{$staffRedemption}/cancellation", ['reason' => 'nicht meins'])->assertStatus(409)->assertJsonPath('context.reason', 'not_found');
        $this->assertSame(3000, Voucher::query()->withoutGlobalScopes()->findOrFail($foreign->voucher->id)->balance);
    }

    public function test_the_owner_disconnects_the_pos_or_revokes_one_till_and_it_stops_at_once(): void
    {
        $sale = $this->sell($this->restaurant, 3000);
        $this->connectionId = $this->connect();
        $this->till('POST', 'vouchers/scan', ['code' => (string) $sale->printable->payload])->assertCreated();
        $this->till('GET', 'connection')->assertOk();
        $this->till('POST', 'vouchers/scan', [], 'bad id!')->assertStatus(422)->assertJsonValidationErrors('X-Terminal-Id');
        // Tills are not minted without end.
        config(['giftcard.partner.max_terminals' => 2]);
        $this->till('GET', 'connection')->assertOk();
        $this->till('POST', 'vouchers/scan', ['code' => 'x'], 'KASSE-02')->assertStatus(422)->assertJsonPath('code', 'MEDIUM_NOT_RECOGNIZED');
        $this->till('POST', 'vouchers/scan', ['code' => 'x'], 'KASSE-03')->assertStatus(422)->assertJsonValidationErrors('X-Terminal-Id');
        config(['giftcard.partner.max_terminals' => 50]);

        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        $this->getJson('/api/v1/partner-connections')->assertOk()->assertJsonPath('data.0.partner.name', 'Kassa Wien GmbH')
            ->assertJsonPath('data.0.terminals.0.name', 'Kassa Wien GmbH · Theke');
        // The till is in Devices like a waiter phone, and is revoked there.
        $device = Device::query()->withoutGlobalScopes()->where('fingerprint', hash('sha256', 'pos:'.$this->partner->id.':KASSE-01'))->firstOrFail();
        $device->forceFill(['status' => DeviceStatus::Revoked, 'revoked_at' => now()])->save();
        $this->app['auth']->forgetGuards();
        $this->till('POST', 'vouchers/scan', ['code' => (string) $sale->printable->payload])->assertForbidden()->assertJsonPath('code', 'DEVICE_REVOKED');
        $this->till('POST', 'vouchers/scan', ['code' => (string) $sale->printable->payload], 'KASSE-02')->assertCreated();

        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        $this->deleteJson("/api/v1/partner-connections/{$this->connectionId}")->assertOk()->assertJsonPath('data.status', 'revoked');
        $this->getJson('/api/v1/partner-connections')->assertOk()->assertJsonCount(0, 'data');
        $this->app['auth']->forgetGuards();
        $this->till('POST', 'vouchers/scan', ['code' => (string) $sale->printable->payload], 'KASSE-02')->assertForbidden()->assertJsonPath('code', 'CONNECTION_REVOKED');
        $this->assertSame('revoked', PartnerConnection::query()->withoutGlobalScopes()->sole()->status);

        // A new code connects it again, with a new token (the old one stays dead); a suspended partner stops everywhere.
        $old = $this->token;
        $this->connectionId = $this->connect();
        $this->assertNotSame($old, $this->token);
        $this->partnerCall('GET', 'connection', key: $old)->assertUnauthorized();
        $this->till('GET', 'connection')->assertOk();
        app(PartnerService::class)->setActive($this->partner, false);
        $this->till('GET', 'connection')->assertUnauthorized();
    }

    public function test_the_platform_creates_rotates_and_suspends_a_partner_key_from_the_console(): void
    {
        $this->artisan('partner:manage', ['action' => 'create', 'name' => 'Neue Kasse', '--email' => 'it@neue.example'])
            ->expectsOutputToContain('Partner key (shown once')->assertSuccessful();
        /** @var Partner $partner */
        $partner = Partner::query()->where('name', 'Neue Kasse')->sole();
        $this->assertStringStartsWith('gcpp_', $partner->key_prefix);
        $this->artisan('partner:manage', ['action' => 'list'])->assertSuccessful();

        $this->connectionId = $this->connect();
        $this->artisan('partner:manage', ['action' => 'rotate', 'name' => $this->partner->id])->assertSuccessful();
        // The old key stops at once; the restaurants' tills keep working (their own tokens).
        $this->partnerCall('GET', 'me')->assertUnauthorized();
        $this->till('GET', 'connection')->assertOk();
        $this->artisan('partner:manage', ['action' => 'suspend', 'name' => $partner->id])->assertSuccessful();
        $this->assertSame('suspended', $partner->refresh()->status);
        $this->artisan('partner:manage', ['action' => 'rotate', 'name' => 'nope'])->assertFailed();
    }

    public function test_a_till_cancelling_many_redemptions_in_a_day_raises_an_alert(): void
    {
        $sale = $this->sell($this->restaurant, 10000);
        $this->connectionId = $this->connect();
        for ($i = 0; $i < 5; $i++) {
            $p = (string) $this->till('POST', 'vouchers/scan', ['code' => (string) $sale->printable->payload])->json('data.presentment_id');
            $id = (string) $this->till('POST', 'redemptions', ['presentment_id' => $p, 'amount' => 100], headers: ['Idempotency-Key' => (string) Str::uuid()])->assertCreated()->json('data.id');
            $this->till('POST', "redemptions/{$id}/cancellation", ['reason' => 'Bon storniert'])->assertCreated();
        }
        $this->artisan('giftcard:monitor-security-events')->assertSuccessful();
        $this->assertDatabaseHas('security_alerts', ['rule' => 'money.reversals']);
    }

    public function test_the_till_is_told_the_most_it_may_debit_now(): void
    {
        $sale = $this->sell($this->restaurant, 30000);
        $this->restaurant->settings->update(['max_debit_per_transaction' => 20000, 'max_debit_per_voucher_per_day' => 25000]);
        $this->connectionId = $this->connect();
        $scan = fn (): TestResponse => $this->till('POST', 'vouchers/scan', ['code' => (string) $sale->printable->payload])->assertCreated();

        $p = (string) $scan()->assertJsonPath('data.voucher.max_amount', 20000)->json('data.presentment_id');
        $this->till('POST', 'redemptions', ['presentment_id' => $p, 'amount' => 20000], headers: ['Idempotency-Key' => (string) Str::uuid()])->assertCreated();
        // 25,000 a day: 5,000 left today, although 10,000 are on it.
        $scan()->assertJsonPath('data.voucher.balance', 10000)->assertJsonPath('data.voucher.max_amount', 5000);
        // Whole vouchers only: the whole balance or nothing.
        $this->restaurant->settings->update(['allow_partial_redemption' => false, 'max_debit_per_transaction' => 50000, 'max_debit_per_voucher_per_day' => 50000]);
        $scan()->assertJsonPath('data.voucher.max_amount', 10000);
        $this->restaurant->settings->update(['max_debit_per_transaction' => 5000]);
        $scan()->assertJsonPath('data.voucher.max_amount', 0);
    }

    public function test_the_owners_are_mailed_when_a_pos_system_connects(): void
    {
        Notification::fake();
        $owner = $this->staff($this->restaurant, RoleSlug::Owner, ['locale' => 'bs']);
        $manager = $this->staff($this->restaurant, RoleSlug::Manager);
        $this->connect();

        Notification::assertSentTo($owner, PartnerConnectedNotification::class, function (PartnerConnectedNotification $n) use ($owner): bool {
            $mail = $n->toMail($owner);

            return $n->locale === 'bs' && str_contains((string) $mail->subject, 'Kassa Wien GmbH')
                && str_contains(implode(' ', $mail->introLines), 'Trattoria Bella Vista');
        });
        Notification::assertNotSentTo($manager, PartnerConnectedNotification::class);
        // A code that does not work mails nobody.
        Notification::fake();
        $this->partnerCall('POST', 'connections', ['code' => 'ABCD-EFGH'])->assertStatus(422);
        Notification::assertNothingSent();
    }

    public function test_the_owner_sees_and_revokes_codes_not_used_yet_and_old_codes_are_pruned(): void
    {
        $owner = $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        $code = (string) $this->postJson('/api/v1/partner-connections/code')->assertCreated()->json('data.code');
        $this->postJson('/api/v1/partner-connections/code')->assertCreated();
        $list = $this->getJson('/api/v1/partner-connections')->assertOk()->assertJsonCount(2, 'open_codes')
            ->assertJsonPath('open_codes.0.created_by', $owner->name);
        $this->assertStringNotContainsString(str_replace('-', '', $code), (string) $list->getContent());
        $first = (string) $list->json('open_codes.0.id');

        // Another restaurant's owner cannot revoke it.
        $this->actingAsStaff($this->restaurant(), RoleSlug::Owner);
        $this->deleteJson("/api/v1/partner-connections/codes/{$first}")->assertNotFound();
        $this->actingAsStaff($this->restaurant, RoleSlug::Manager);
        $this->deleteJson("/api/v1/partner-connections/codes/{$first}")->assertForbidden();

        Sanctum::actingAs($owner, ['*']);
        $this->deleteJson("/api/v1/partner-connections/codes/{$first}")->assertNoContent();
        $this->getJson('/api/v1/partner-connections')->assertJsonCount(1, 'open_codes');
        $this->assertDatabaseHas('audit_logs', ['action' => 'partner.code_revoked']);
        $this->app['auth']->forgetGuards();
        $this->partnerCall('POST', 'connections', ['code' => $code])->assertStatus(422);

        // Used and expired codes leave the list; a week after expiry they are deleted.
        $this->connect();
        Sanctum::actingAs($owner, ['*']);
        $this->getJson('/api/v1/partner-connections')->assertJsonCount(1, 'open_codes');
        Carbon::setTestNow(now()->addDays(2));
        $this->getJson('/api/v1/partner-connections')->assertJsonCount(0, 'open_codes');
        $this->assertSame(3, PartnerLinkCode::query()->withoutGlobalScopes()->count());
        Carbon::setTestNow(now()->addDays(7));
        $this->artisan('model:prune', ['--model' => [PartnerLinkCode::class]])->assertSuccessful();
        $this->assertSame(0, PartnerLinkCode::query()->withoutGlobalScopes()->count());
        Carbon::setTestNow();
    }

    public function test_the_platform_manages_partners_in_the_admin_area(): void
    {
        $this->connect();
        $admin = User::factory()->platformAdmin()->create();
        Sanctum::actingAs($admin, ['*']);
        $this->getJson('/api/v1/admin/partners')->assertOk()
            ->assertJsonPath('data.0.name', 'Kassa Wien GmbH')
            ->assertJsonPath('data.0.restaurants.0.name', 'Trattoria Bella Vista')
            ->assertJsonMissingPath('data.0.key_hash');

        $created = $this->postJson('/api/v1/admin/partners', ['name' => 'Gastro Kasse', 'contact_email' => 'it@gastro.example'])->assertCreated()
            ->assertHeader('Cache-Control', 'no-store, private');
        $key = (string) $created->json('data.key');
        $id = (string) $created->json('data.id');
        $this->assertStringStartsWith('gcpp_', $key);
        $this->assertStringStartsWith(substr($key, 0, 12), (string) $created->json('data.key_prefix'));
        $this->assertDatabaseHas('audit_logs', ['action' => 'partner.created', 'user_id' => $admin->id]);
        $this->getJson('/api/v1/admin/partners')->assertJsonCount(2, 'data')->assertJsonMissingPath('data.0.key');

        $this->app['auth']->forgetGuards();
        $this->partnerCall('GET', 'me', key: $key)->assertOk();
        Sanctum::actingAs($admin, ['*']);
        $rotated = (string) $this->postJson("/api/v1/admin/partners/{$id}/key")->assertCreated()->json('data.key');
        $this->postJson("/api/v1/admin/partners/{$id}/suspend")->assertOk()->assertJsonPath('data.status', 'suspended');
        $this->app['auth']->forgetGuards();
        $this->partnerCall('GET', 'me', key: $key)->assertUnauthorized();
        $this->partnerCall('GET', 'me', key: $rotated)->assertUnauthorized();
        Sanctum::actingAs($admin, ['*']);
        $this->postJson("/api/v1/admin/partners/{$id}/activate")->assertOk()->assertJsonPath('data.status', 'active');
        $this->app['auth']->forgetGuards();
        $this->partnerCall('GET', 'me', key: $rotated)->assertOk();

        // Restaurant staff never reach it.
        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        $this->getJson('/api/v1/admin/partners')->assertForbidden();
        $this->postJson('/api/v1/admin/partners', ['name' => 'x y'])->assertForbidden();
    }
}
