<?php

declare(strict_types=1);

namespace Tests\Feature\Online;

use App\Enums\CardState;
use App\Enums\OnlineOrderStatus;
use App\Enums\PaymentDirection;
use App\Enums\PaymentMethod;
use App\Enums\RoleSlug;
use App\Enums\VoucherKind;
use App\Enums\VoucherStatus;
use App\Events\VoucherIssued;
use App\Mail\TemplatedMail;
use App\Models\OnlineOrder;
use App\Models\OnlineShop;
use App\Models\Payment;
use App\Models\PspAccount;
use App\Models\Restaurant;
use App\Models\Voucher;
use App\Notifications\OnlinePaymentNotification;
use GuzzleHttp\Promise\PromiseInterface;
use Illuminate\Http\Client\Request as HttpRequest;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Notification;
use Illuminate\Testing\TestResponse;
use Tests\Support\WithCards;
use Tests\TestCase;

/**
 * Online sales (decision 2026-10-06): the restaurant connects its own Stripe account (no keys), switches its shop on,
 * a guest pays on Stripe's page, and only Stripe's signed webhook turns the order into a voucher, once. Refunds go
 * back to the guest's card; a disputed payment blocks the voucher; a gift card is picked up at the restaurant.
 */
final class OnlineSalesTest extends TestCase
{
    use WithCards;

    private const SECRET = 'whsec_test_secret';

    private Restaurant $restaurant;

    private int $sessions = 0;

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.stripe.secret' => 'sk_test_platform', 'services.stripe.webhook_secret' => self::SECRET]);
        $this->restaurant = $this->restaurant(['name' => 'Trattoria Bella Vista', 'slug' => 'trattoria-bella-vista']);
        Http::preventStrayRequests();
    }

    protected function tearDown(): void
    {
        $this->tearDownCardKeystore();
        parent::tearDown();
    }

    /** A connected, enabled account and an open shop, as after the owner's onboarding. */
    private function openShop(bool $cardPickup = false): void
    {
        $this->asTenant($this->restaurant, function () use ($cardPickup): void {
            PspAccount::query()->create([
                'restaurant_id' => $this->restaurant->id, 'provider' => 'stripe', 'account_id' => 'acct_rest',
                'charges_enabled' => true, 'payouts_enabled' => true, 'details_submitted' => true, 'enabled_at' => now(),
            ]);
            $shop = new OnlineShop(['amounts' => [2500, 5000], 'max_amount' => 25000, 'card_pickup' => $cardPickup,
                'terms_url' => 'https://bella.example/agb', 'imprint_url' => 'https://bella.example/impressum']);
            $shop->restaurant_id = $this->restaurant->id;
            $shop->enabled = true;
            $shop->save();
        });
    }

    /** @param array<string, mixed> $overrides */
    private function order(array $overrides = []): TestResponse
    {
        Http::fake(['api.stripe.com/v1/checkout/sessions' => function (): PromiseInterface {
            $id = 'cs_test_'.(++$this->sessions);

            return Http::response(['id' => $id, 'url' => 'https://checkout.stripe.com/c/pay/'.$id]);
        }]);

        return $this->postJson('/api/v1/shop/trattoria-bella-vista/orders', $overrides + [
            'amount' => 5000,
            'buyer_email' => 'Anna@Example.com',
            'buyer_name' => 'Anna',
            'recipient_name' => 'Oma Hilde',
            'gift_message' => 'Alles Gute!',
            'accept_terms' => true,
            'locale' => 'de',
        ]);
    }

    /** @param array<string, mixed> $object */
    private function webhook(string $type, array $object, string $account = 'acct_rest', ?string $id = null, ?string $secret = null): TestResponse
    {
        $payload = (string) json_encode(['id' => $id ?? 'evt_'.bin2hex(random_bytes(6)), 'type' => $type, 'account' => $account, 'data' => ['object' => $object]]);
        $t = time();
        $signature = 't='.$t.',v1='.hash_hmac('sha256', $t.'.'.$payload, $secret ?? self::SECRET);

        return $this->call('POST', '/api/v1/webhooks/stripe', [], [], [], ['HTTP_STRIPE_SIGNATURE' => $signature, 'CONTENT_TYPE' => 'application/json'], $payload);
    }

    /** @return array<string, mixed> Stripe's checkout session of the order, paid */
    private function paidSession(OnlineOrder $order, ?int $amount = null): array
    {
        return [
            'id' => $order->checkout_id, 'object' => 'checkout.session', 'payment_status' => 'paid', 'status' => 'complete',
            'amount_total' => $amount ?? $order->amount, 'currency' => 'eur', 'payment_intent' => 'pi_test_1',
            'client_reference_id' => $order->id, 'metadata' => ['order_id' => $order->id],
        ];
    }

    public function test_the_owner_connects_the_restaurants_own_stripe_account_without_keys(): void
    {
        $this->actingAsStaff($this->restaurant, RoleSlug::Manager);
        $this->postJson('/api/v1/online-shop/connect')->assertForbidden();

        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        Http::fake([
            'api.stripe.com/v1/accounts' => Http::response(['id' => 'acct_new', 'charges_enabled' => false]),
            'api.stripe.com/v1/account_links' => Http::response(['url' => 'https://connect.stripe.com/setup/s/abc']),
            'api.stripe.com/v1/accounts/acct_new' => Http::response(['id' => 'acct_new', 'charges_enabled' => true, 'payouts_enabled' => true, 'details_submitted' => true]),
        ]);
        $this->postJson('/api/v1/online-shop/connect')->assertOk()->assertJsonPath('data.url', 'https://connect.stripe.com/setup/s/abc');
        Http::assertSent(static fn (HttpRequest $r): bool => $r->url() === 'https://api.stripe.com/v1/accounts'
            && $r['type'] === 'standard' && $r->hasHeader('Authorization', 'Bearer sk_test_platform'));
        $this->assertDatabaseHas('psp_accounts', ['restaurant_id' => $this->restaurant->id, 'account_id' => 'acct_new', 'charges_enabled' => false]);

        // Not before Stripe allows charges, and not without the restaurant's terms and imprint.
        $this->putJson('/api/v1/online-shop', ['enabled' => true])->assertUnprocessable()->assertJsonValidationErrors('enabled');
        $this->postJson('/api/v1/online-shop/refresh')->assertOk()->assertJsonPath('data.account.charges_enabled', true);
        $this->putJson('/api/v1/online-shop', ['enabled' => true])->assertUnprocessable()->assertJsonValidationErrors('enabled');
        $this->putJson('/api/v1/online-shop', [
            'enabled' => true, 'amounts' => [5000, 2500], 'max_amount' => 20000,
            'terms_url' => 'https://bella.example/agb', 'imprint_url' => 'https://bella.example/impressum',
        ])->assertOk()->assertJsonPath('data.shop.enabled', true)->assertJsonPath('data.shop.amounts', [2500, 5000])
            ->assertJsonPath('data.url', config('giftcard.frontend_url').'/g/trattoria-bella-vista');
        // Never above the platform's cap for online vouchers.
        $this->putJson('/api/v1/online-shop', ['max_amount' => 40000])->assertUnprocessable()->assertJsonValidationErrors('max_amount');

        $this->getJson('/api/v1/shop/trattoria-bella-vista')->assertOk()->assertJsonPath('data.restaurant.name', 'Trattoria Bella Vista')
            ->assertJsonPath('data.max_amount', 20000);
        $this->deleteJson('/api/v1/online-shop/connection')->assertOk()->assertJsonPath('data.account', null)->assertJsonPath('data.shop.enabled', false);
        $this->getJson('/api/v1/shop/trattoria-bella-vista')->assertStatus(409)->assertJsonPath('code', 'ONLINE_SHOP_UNAVAILABLE');
    }

    public function test_only_stripes_signed_webhook_turns_a_paid_order_into_a_voucher_once(): void
    {
        Mail::fake();
        $this->restaurant->settings->update(['send_customer_emails' => false]);
        $this->openShop();

        $response = $this->order()->assertCreated()->assertJsonPath('data.checkout_url', 'https://checkout.stripe.com/c/pay/cs_test_1');
        Http::assertSent(static fn (HttpRequest $r): bool => $r->url() === 'https://api.stripe.com/v1/checkout/sessions'
            && $r->hasHeader('Stripe-Account', 'acct_rest') && (int) $r['line_items'][0]['price_data']['unit_amount'] === 5000
            && $r['customer_email'] === 'anna@example.com');
        /** @var OnlineOrder $order */
        $order = OnlineOrder::query()->findOrFail($response->json('data.order_id'));
        $token = (string) $response->json('data.token');
        $this->assertSame(OnlineOrderStatus::Pending, $order->status);
        $this->getJson("/api/v1/shop/orders/{$order->id}?token={$token}")->assertOk()->assertJsonPath('data.status', 'pending');
        $this->getJson("/api/v1/shop/orders/{$order->id}?token=wrong")->assertNotFound();

        // A forged event, an event for another amount or account: nothing.
        $this->webhook('checkout.session.completed', $this->paidSession($order), secret: 'whsec_other')->assertStatus(400);
        $this->webhook('checkout.session.completed', $this->paidSession($order, 100))->assertOk();
        $this->webhook('checkout.session.completed', $this->paidSession($order), account: 'acct_other')->assertOk();
        $this->assertSame(0, Voucher::query()->withoutGlobalScopes()->count());

        $this->webhook('checkout.session.completed', $this->paidSession($order), id: 'evt_paid')->assertOk();
        $this->webhook('checkout.session.completed', $this->paidSession($order), id: 'evt_paid')->assertOk();
        $this->webhook('checkout.session.completed', $this->paidSession($order), id: 'evt_paid_again')->assertOk();

        $order->refresh();
        $this->assertSame(OnlineOrderStatus::Paid, $order->status);
        /** @var Voucher $voucher */
        $voucher = Voucher::query()->withoutGlobalScopes()->sole();
        $this->assertTrue($voucher->sold_online);
        $this->assertSame(VoucherKind::Digital, $voucher->kind);
        $this->assertSame(5000, $voucher->balance);
        $this->assertSame('Oma Hilde', $voucher->recipient_name);
        $this->assertSame($voucher->id, $order->voucher_id);
        /** @var Payment $payment */
        $payment = Payment::query()->withoutGlobalScopes()->sole();
        $this->assertSame(PaymentMethod::Online, $payment->method);
        $this->assertSame('pi_test_1', $payment->reference);
        $this->assertNull($payment->received_by);
        // The guest gets the voucher they paid for, with its PDF, whatever the till's e-mail setting.
        Mail::assertSent(TemplatedMail::class, static fn (TemplatedMail $m): bool => $m->hasTo('anna@example.com') && $m->voucherPdf !== null);
        $this->getJson("/api/v1/shop/orders/{$order->id}?token={$token}")->assertOk()->assertJsonPath('data.status', 'paid');
    }

    public function test_the_shop_sells_only_what_it_offers_and_never_at_the_till(): void
    {
        $this->openShop();
        $this->order(['amount' => 30000])->assertUnprocessable()->assertJsonPath('code', 'INVALID_AMOUNT');
        $this->order(['amount' => 100])->assertUnprocessable();
        $this->order(['accept_terms' => false])->assertUnprocessable()->assertJsonValidationErrors('accept_terms');
        $this->order(['website' => 'http://spam.example'])->assertUnprocessable()->assertJsonValidationErrors('website');
        OnlineShop::query()->withoutGlobalScopes()->update(['custom_amount' => false]);
        $this->order(['amount' => 4000])->assertUnprocessable();
        $this->order(['amount' => 2500])->assertCreated();

        // A person never books an online payment.
        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        $this->postJson('/api/v1/vouchers', ['value' => 3000, 'form' => 'printable', 'payment' => ['method' => 'online', 'reference' => 'pi_fake']], $this->idempotency())
            ->assertUnprocessable()->assertJsonValidationErrors('payment.method');
    }

    public function test_one_buyer_cannot_open_order_after_order(): void
    {
        $this->openShop();
        for ($i = 0; $i < 5; $i++) {
            $this->order()->assertCreated();
        }
        $this->order()->assertStatus(429);
    }

    public function test_an_online_voucher_is_refunded_to_the_guests_card_and_a_dispute_blocks_it(): void
    {
        Notification::fake();
        $this->openShop();
        $order = OnlineOrder::query()->findOrFail($this->order()->json('data.order_id'));
        $this->webhook('checkout.session.completed', $this->paidSession($order))->assertOk();
        /** @var Voucher $voucher */
        $voucher = Voucher::query()->withoutGlobalScopes()->sole();

        // A manager cannot cancel an online sale; it goes back through Stripe.
        $this->actingAsStaff($this->restaurant, RoleSlug::Manager);
        $this->getJson("/api/v1/vouchers/{$voucher->id}")->assertJsonPath('data.online', true)->assertJsonPath('data.can_cancel_sale', false);
        $this->postJson("/api/v1/vouchers/{$voucher->id}/cancellation", ['reason' => 'wrong amount'], $this->idempotency())
            ->assertStatus(409)->assertJsonPath('context.reason', 'online');

        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        Http::fake(['api.stripe.com/v1/refunds' => Http::response(['id' => 're_test_1', 'status' => 'succeeded'])]);
        $key = $this->idempotency();
        $this->postJson("/api/v1/vouchers/{$voucher->id}/refund", ['payment' => ['method' => 'online'], 'reason' => 'Rücktritt'], $key)->assertSuccessful();
        Http::assertSent(static fn (HttpRequest $r): bool => $r->url() === 'https://api.stripe.com/v1/refunds' && $r['payment_intent'] === 'pi_test_1'
            && (int) $r['amount'] === 5000 && $r->hasHeader('Stripe-Account', 'acct_rest'));
        $this->assertSame(VoucherStatus::Refunded, $voucher->refresh()->status);
        $this->assertSame(OnlineOrderStatus::Refunded, $order->refresh()->status);
        $out = Payment::query()->withoutGlobalScopes()->where('direction', PaymentDirection::Out->value)->sole();
        $this->assertSame('re_test_1', $out->reference);
        $this->assertSame(PaymentMethod::Online, $out->method);
        // The same request again is the same refund, here and at Stripe.
        $this->postJson("/api/v1/vouchers/{$voucher->id}/refund", ['payment' => ['method' => 'online'], 'reason' => 'Rücktritt'], $key)->assertSuccessful();
        $this->assertSame(1, Payment::query()->withoutGlobalScopes()->where('direction', PaymentDirection::Out->value)->count());

        // Another order, disputed by the card holder: the voucher stops at once, the owners hear of it.
        $second = OnlineOrder::query()->findOrFail($this->order(['buyer_email' => 'ben@example.com'])->json('data.order_id'));
        $session = ['payment_intent' => 'pi_test_2'] + $this->paidSession($second);
        $this->webhook('checkout.session.completed', $session)->assertOk();
        $disputed = Voucher::query()->withoutGlobalScopes()->whereKey($second->refresh()->voucher_id)->sole();
        $this->webhook('charge.dispute.created', ['object' => 'dispute', 'payment_intent' => 'pi_test_2', 'reason' => 'fraudulent'])->assertOk();
        $this->assertSame(VoucherStatus::Blocked, $disputed->refresh()->status);
        $this->assertSame(OnlineOrderStatus::Disputed, $second->refresh()->status);
        Notification::assertSentTimes(OnlinePaymentNotification::class, 1);
        $this->artisan('giftcard:monitor-security-events')->assertSuccessful();
        $this->assertDatabaseHas('security_alerts', ['rule' => 'online.dispute']);
    }

    public function test_the_gift_card_is_picked_up_at_the_restaurant_and_the_emailed_qr_stops(): void
    {
        $this->setUpCardKeystore();
        Event::fake([VoucherIssued::class]);
        Carbon::setTestNow('2026-10-06 12:00:00');
        $this->openShop(cardPickup: true);
        $order = OnlineOrder::query()->findOrFail($this->order(['card_pickup' => true])->json('data.order_id'));
        $this->assertTrue($order->card_pickup);
        $this->webhook('checkout.session.completed', $this->paidSession($order))->assertOk();
        $qr = null;
        Event::assertDispatched(VoucherIssued::class, static function (VoucherIssued $e) use (&$qr): bool {
            $qr = $e->printablePayload;

            return true;
        });
        /** @var Voucher $voucher */
        $voucher = Voucher::query()->withoutGlobalScopes()->sole();
        $card = $this->availableCard($this->restaurant);

        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        $this->postJson('/api/v1/presentments', ['purpose' => 'pickup', 'method' => 'printable_qr', 'credential' => $qr])->assertForbidden();

        $this->actingAsStaff($this->restaurant, RoleSlug::Manager);
        $pickup = fn (): string => (string) $this->postJson('/api/v1/presentments', ['purpose' => 'pickup', 'method' => 'printable_qr', 'credential' => $qr])
            ->assertCreated()->assertJsonPath('data.voucher.card_pickup.open', true)->json('data.id');
        // Not within 24 hours of the payment (a stolen card would be disputed by then).
        $this->postJson("/api/v1/vouchers/{$voucher->id}/card-pickup", ['qr_presentment_id' => $pickup(), 'presentment_id' => (string) $this->tapCard($this->chip($card), 'bind')->assertCreated()->json('data.id')])
            ->assertStatus(409)->assertJsonPath('context.reason', 'too_early');

        Carbon::setTestNow('2026-10-07 12:30:00');
        $this->postJson("/api/v1/vouchers/{$voucher->id}/card-pickup", ['qr_presentment_id' => $pickup(), 'presentment_id' => (string) $this->tapCard($this->chip($card), 'bind')->assertCreated()->json('data.id')])
            ->assertOk()->assertJsonPath('data.kind', 'card');
        $this->assertSame(VoucherKind::Card, $voucher->refresh()->kind);
        $this->assertSame(CardState::Active, $card->refresh()->state);
        $this->assertNotNull($order->refresh()->card_picked_up_at);
        // The e-mailed QR no longer pays; the card does.
        $this->postJson('/api/v1/presentments', ['purpose' => 'spend', 'method' => 'printable_qr', 'credential' => $qr])->assertUnprocessable();
        $this->tapCard($this->chip($card), 'spend')->assertCreated()->assertJsonPath('data.voucher.balance', 5000);
        // Once only.
        $this->postJson('/api/v1/presentments', ['purpose' => 'pickup', 'method' => 'printable_qr', 'credential' => $qr])->assertUnprocessable();
        $this->getJson('/api/v1/online-orders?pickup=open')->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_an_order_left_on_the_payment_page_expires_and_a_late_payment_still_counts(): void
    {
        $this->openShop();
        $order = OnlineOrder::query()->findOrFail($this->order()->json('data.order_id'));
        $this->webhook('checkout.session.expired', ['id' => $order->checkout_id, 'metadata' => ['order_id' => $order->id], 'payment_status' => 'unpaid'])->assertOk();
        $this->assertSame(OnlineOrderStatus::Expired, $order->refresh()->status);
        $this->webhook('checkout.session.completed', $this->paidSession($order))->assertOk();
        $this->assertSame(OnlineOrderStatus::Paid, $order->refresh()->status);

        $stale = OnlineOrder::query()->findOrFail($this->order(['buyer_email' => 'carl@example.com'])->json('data.order_id'));
        Carbon::setTestNow(now()->addHours(2));
        $this->artisan('online:expire-orders')->assertSuccessful();
        $this->assertSame(OnlineOrderStatus::Expired, $stale->refresh()->status);
    }

    public function test_a_stale_or_replayed_signature_is_refused(): void
    {
        $this->openShop();
        $order = OnlineOrder::query()->findOrFail($this->order()->json('data.order_id'));
        $payload = (string) json_encode(['id' => 'evt_old', 'type' => 'checkout.session.completed', 'account' => 'acct_rest', 'data' => ['object' => $this->paidSession($order)]]);
        $t = time() - 600;
        $signature = 't='.$t.',v1='.hash_hmac('sha256', $t.'.'.$payload, self::SECRET);
        $this->call('POST', '/api/v1/webhooks/stripe', [], [], [], ['HTTP_STRIPE_SIGNATURE' => $signature, 'CONTENT_TYPE' => 'application/json'], $payload)->assertStatus(400);
        $this->call('POST', '/api/v1/webhooks/stripe', [], [], [], ['CONTENT_TYPE' => 'application/json'], $payload)->assertStatus(400);
        $this->assertSame(0, Voucher::query()->withoutGlobalScopes()->count());
    }

    public function test_a_payment_after_the_restaurant_disconnected_still_gives_the_voucher_and_the_shop_closes(): void
    {
        Mail::fake();
        $this->openShop();
        // The shop offers no card: an order asking for one gets none.
        $order = OnlineOrder::query()->findOrFail($this->order(['card_pickup' => true])->json('data.order_id'));
        $this->assertFalse($order->card_pickup);

        // Stripe withdrew the connection while the guest was on the payment page: the money is there, so is the voucher.
        $this->webhook('account.application.deauthorized', ['id' => 'ca_1', 'object' => 'application'])->assertOk();
        $this->assertNull(PspAccount::query()->withoutGlobalScopes()->first());
        $this->assertFalse((bool) OnlineShop::query()->withoutGlobalScopes()->sole()->enabled);
        $this->getJson('/api/v1/shop/trattoria-bella-vista')->assertStatus(409);

        $this->webhook('checkout.session.completed', $this->paidSession($order))->assertOk();
        $this->assertSame(OnlineOrderStatus::Paid, $order->refresh()->status);
        $this->assertNotNull($order->voucher_id);
    }

    public function test_no_card_without_an_order_for_one_or_on_a_disputed_voucher(): void
    {
        $this->setUpCardKeystore();
        Event::fake([VoucherIssued::class]);
        Carbon::setTestNow('2026-10-06 12:00:00');
        $this->openShop(cardPickup: true);
        $payloads = [];
        foreach (['plain@example.com' => false, 'card@example.com' => true] as $email => $card) {
            $order = OnlineOrder::query()->findOrFail($this->order(['buyer_email' => $email, 'card_pickup' => $card])->json('data.order_id'));
            $this->webhook('checkout.session.completed', ['payment_intent' => 'pi_'.md5($email)] + $this->paidSession($order))->assertOk();
        }
        Event::assertDispatched(VoucherIssued::class, static function (VoucherIssued $e) use (&$payloads): bool {
            $payloads[$e->voucher->id] = $e->printablePayload;

            return true;
        });
        $plain = OnlineOrder::query()->where('buyer_email', 'plain@example.com')->sole();
        $withCard = OnlineOrder::query()->where('buyer_email', 'card@example.com')->sole();
        $card = $this->availableCard($this->restaurant);
        Carbon::setTestNow('2026-10-08 12:00:00');

        $this->actingAsStaff($this->restaurant, RoleSlug::Manager);
        // The voucher's QR is not a pickup QR when no card was ordered: the presentment says so, the hand-out refuses.
        $this->postJson('/api/v1/presentments', ['purpose' => 'pickup', 'method' => 'printable_qr', 'credential' => $payloads[$plain->voucher_id]])
            ->assertCreated()->assertJsonPath('data.voucher.card_pickup', null);
        $qr = (string) $this->postJson('/api/v1/presentments', ['purpose' => 'pickup', 'method' => 'printable_qr', 'credential' => $payloads[$plain->voucher_id]])->json('data.id');
        $this->postJson("/api/v1/vouchers/{$plain->voucher_id}/card-pickup", ['qr_presentment_id' => $qr, 'presentment_id' => (string) $this->tapCard($this->chip($card), 'bind')->json('data.id')])
            ->assertStatus(409)->assertJsonPath('context.reason', 'no_card_ordered');

        // A disputed payment stops the voucher and its card.
        $this->webhook('charge.dispute.created', ['object' => 'dispute', 'payment_intent' => 'pi_'.md5('card@example.com'), 'reason' => 'fraudulent'])->assertOk();
        $qr = (string) $this->postJson('/api/v1/presentments', ['purpose' => 'pickup', 'method' => 'printable_qr', 'credential' => $payloads[$withCard->voucher_id]])->json('data.id');
        $this->postJson("/api/v1/vouchers/{$withCard->voucher_id}/card-pickup", ['qr_presentment_id' => $qr, 'presentment_id' => (string) $this->tapCard($this->chip($card), 'bind')->json('data.id')])
            ->assertStatus(409)->assertJsonPath('context.reason', 'not_paid');
        // Refused hand-outs leave the stock card in stock.
        $this->assertSame(CardState::Available, $card->refresh()->state);
    }
}
