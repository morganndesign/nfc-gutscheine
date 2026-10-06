<?php

declare(strict_types=1);

namespace App\Services\Online;

use App\Data\IssueVoucherData;
use App\Data\PaymentData;
use App\Data\TransactionResult;
use App\Enums\OnlineOrderStatus;
use App\Enums\PaymentMethod;
use App\Enums\SecurityEventType;
use App\Enums\VoucherStatus;
use App\Exceptions\Domain\DomainException;
use App\Exceptions\Domain\InvalidAmountException;
use App\Exceptions\Domain\InvalidVoucherStateException;
use App\Exceptions\Domain\OnlinePaymentFailedException;
use App\Models\OnlineOrder;
use App\Models\PspAccount;
use App\Models\Restaurant;
use App\Models\Voucher;
use App\Models\WebhookEvent;
use App\Services\Audit\AuditLogger;
use App\Services\Security\SecurityEventRecorder;
use App\Services\Vouchers\VoucherService;
use App\Support\Actor;
use App\Support\Tenancy\TenantContext;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\Exceptions\ThrottleRequestsException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Throwable;

/**
 * Online orders (decision 2026-10-06): the buyer chooses an amount in the restaurant's shop and pays on the
 * provider's page; the provider's signed webhook alone turns a paid order into a voucher, exactly once. The voucher
 * is a printable one, e-mailed with its PDF; a gift card is picked up at the restaurant later (the QR then stops).
 */
final class OnlineOrderService
{
    public function __construct(
        private readonly PaymentProvider $provider,
        private readonly OnlineShopService $shops,
        private readonly VoucherService $vouchers,
        private readonly TenantContext $tenant,
        private readonly AuditLogger $audit,
        private readonly SecurityEventRecorder $events,
        private readonly OnlinePaymentMails $mails,
    ) {}

    // ------------------------------------------------------------------ the buyer

    /**
     * Opens an order and the provider's payment page for it. Returns the order, the secret that shows its status
     * to the buyer, and the payment page's address.
     *
     * @param  array{amount: int, buyer_email: string, buyer_name?: string|null, recipient_name?: string|null, gift_message?: string|null, card_pickup?: bool, locale?: string|null}  $input
     * @return array{order: OnlineOrder, token: string, checkout_url: string}
     */
    public function start(string $slug, array $input, ?string $ip): array
    {
        ['restaurant' => $restaurant, 'shop' => $shop, 'account' => $account] = $this->shops->open($slug);

        $amount = (int) $input['amount'];
        $min = (int) $restaurant->settings->min_voucher_value;
        $max = min($shop->max_amount, $this->shops->platformMax($restaurant));
        if ($amount < $min || $amount > $max || (! $shop->custom_amount && ! in_array($amount, $shop->amounts, true))) {
            throw new InvalidAmountException('This amount cannot be bought here.', ['min' => $min, 'max' => $max]);
        }
        $email = Str::lower(trim($input['buyer_email']));
        $perHour = (int) config('giftcard.online.orders_per_hour', 5);
        foreach (['online-order:email:'.hash('sha256', $email), 'online-order:ip:'.hash('sha256', (string) $ip)] as $key) {
            if (RateLimiter::tooManyAttempts($key, $perHour)) {
                throw new ThrottleRequestsException('Too many orders. Please try again later.');
            }
            RateLimiter::hit($key, 3600);
        }

        $token = Str::random(40);
        $locale = in_array($input['locale'] ?? null, ['de', 'en', 'bs'], true) ? (string) $input['locale'] : substr($restaurant->locale, 0, 2);
        $order = new OnlineOrder;
        $order->forceFill([
            'restaurant_id' => $restaurant->getKey(),
            'status' => OnlineOrderStatus::Pending,
            'amount' => $amount,
            'currency' => $restaurant->currency,
            'buyer_email' => $email,
            'buyer_name' => self::text($input['buyer_name'] ?? null),
            'recipient_name' => self::text($input['recipient_name'] ?? null),
            'gift_message' => self::text($input['gift_message'] ?? null),
            'card_pickup' => $shop->card_pickup && (bool) ($input['card_pickup'] ?? false),
            'locale' => $locale,
            'status_token_hash' => hash('sha256', $token),
            'provider' => $account->provider,
            'account_id' => $account->account_id,
            'application_fee' => intdiv($amount * max(0, (int) config('giftcard.online.application_fee_bps', 0)), 10000),
            'ip_hash' => $ip !== null ? hash_hmac('sha256', $ip, (string) config('app.key')) : null,
            'expires_at' => Carbon::now()->addMinutes((int) config('giftcard.online.checkout_minutes', 30))->addMinute(),
        ])->save();

        $page = config('giftcard.frontend_url').'/g/'.$restaurant->slug;
        try {
            $checkout = $this->provider->createCheckout(
                $order,
                __('online.product', ['restaurant' => $restaurant->name], $locale === 'bs' ? 'bs' : $locale),
                $page.'/danke?order='.$order->getKey().'&token='.$token,
                $page.'?cancelled=1',
            );
        } catch (Throwable $e) {
            report($e);
            $order->forceFill(['status' => OnlineOrderStatus::Expired])->save();

            throw new OnlinePaymentFailedException;
        }
        $order->forceFill(['checkout_id' => $checkout->id])->save();

        return ['order' => $order, 'token' => $token, 'checkout_url' => $checkout->url];
    }

    /** The buyer's own order (its status page after the payment), or null when the token does not prove it. */
    public function forBuyer(string $orderId, string $token): ?OnlineOrder
    {
        if (! Str::isUuid($orderId)) {
            return null;
        }
        /** @var OnlineOrder|null $order */
        $order = OnlineOrder::query()->with('restaurant')->find($orderId);

        return $order !== null && hash_equals($order->status_token_hash, hash('sha256', $token)) ? $order : null;
    }

    // ------------------------------------------------------------------ the provider

    /**
     * Handles a verified provider event once. A retry of an event that was handled is answered at once; an event
     * that failed is handled again on the provider's retry.
     */
    public function handle(ProviderEvent $event): void
    {
        try {
            /** @var WebhookEvent $record */
            $record = WebhookEvent::query()->firstOrCreate(
                ['provider' => $this->provider->name(), 'event_id' => $event->id],
                ['type' => $event->type, 'account_id' => $event->accountId],
            );
        } catch (UniqueConstraintViolationException) {
            /** @var WebhookEvent $record */
            $record = WebhookEvent::query()->where('provider', $this->provider->name())->where('event_id', $event->id)->firstOrFail();
        }
        if ($record->processed_at !== null) {
            return;
        }

        match ($event->type) {
            'checkout.session.completed', 'checkout.session.async_payment_succeeded' => $this->paid($event),
            'checkout.session.expired', 'checkout.session.async_payment_failed' => $this->expired($event),
            'charge.dispute.created' => $this->disputed($event),
            'charge.refunded' => $this->refundedElsewhere($event),
            'account.updated' => $this->accountUpdated($event),
            'account.application.deauthorized' => $this->deauthorized($event),
            default => null,
        };

        $record->forceFill(['processed_at' => Carbon::now()])->save();
    }

    private function paid(ProviderEvent $event): void
    {
        $session = $event->object;
        if (($session['payment_status'] ?? null) !== 'paid') {
            // A delayed method (bank debit): the voucher comes with `async_payment_succeeded`.
            return;
        }
        $order = $this->orderOf($session);
        if ($order === null) {
            return;
        }

        DB::transaction(function () use ($order, $session, $event): void {
            /** @var OnlineOrder $locked */
            $locked = OnlineOrder::query()->whereKey($order->getKey())->lockForUpdate()->firstOrFail();
            // Paid in time or just after the page expired: the money is there, the guest gets the voucher.
            if (! in_array($locked->status, [OnlineOrderStatus::Pending, OnlineOrderStatus::Expired], true)) {
                return;
            }
            $paymentId = (string) ($session['payment_intent'] ?? '');
            // Only what we asked for, on the restaurant's account: never a voucher for a different amount or account.
            if ($event->accountId !== $locked->account_id || (int) ($session['amount_total'] ?? -1) !== $locked->amount
                || strtoupper((string) ($session['currency'] ?? '')) !== $locked->currency || $paymentId === '') {
                $this->events->refused(SecurityEventType::OnlineOrder, Actor::system(), 'mismatch', $locked, $locked->amount, $locked->currency, [
                    'order_id' => $locked->getKey(), 'status' => 'mismatch', 'card_pickup' => $locked->card_pickup,
                ]);

                return;
            }

            /** @var Restaurant $restaurant */
            $restaurant = Restaurant::query()->with('settings')->findOrFail($locked->restaurant_id);
            $this->tenant->runAs($restaurant, function () use ($locked, $paymentId): void {
                try {
                    $sale = $this->vouchers->sell(Actor::system(), new IssueVoucherData(
                        value: $locked->amount,
                        payment: new PaymentData(PaymentMethod::Online, $paymentId),
                        idempotencyKey: 'online-'.$locked->getKey(),
                        recipientName: $locked->recipient_name,
                        giftMessage: $locked->gift_message,
                        notes: $locked->card_pickup ? 'Online: Geschenkkarte im Lokal abholen' : 'Online',
                        newCustomer: ['email' => $locked->buyer_email, 'first_name' => $locked->buyer_name],
                    ));
                } catch (DomainException $e) {
                    // The shop's limits changed while the buyer paid: the money goes straight back.
                    report($e);
                    $this->provider->refund($locked->account_id, $paymentId, $locked->amount, 'order-'.$locked->getKey());
                    $locked->forceFill(['status' => OnlineOrderStatus::Refunded, 'payment_id' => $paymentId, 'paid_at' => Carbon::now()])->save();
                    $this->events->record(SecurityEventType::OnlineOrder, Actor::system(), subject: $locked, amount: $locked->amount, data: [
                        'order_id' => $locked->getKey(), 'status' => 'refunded', 'card_pickup' => $locked->card_pickup,
                    ]);

                    return;
                }
                $locked->forceFill([
                    'status' => OnlineOrderStatus::Paid,
                    'payment_id' => $paymentId,
                    'paid_at' => Carbon::now(),
                    'voucher_id' => $sale->voucher->getKey(),
                ])->save();
                $this->audit->log('online.order_paid', Actor::system(), $locked, null, ['status' => 'paid', 'voucher_id' => $sale->voucher->getKey()]);
                $this->events->record(SecurityEventType::OnlineOrder, Actor::system(), subject: $locked, amount: $locked->amount, data: [
                    'order_id' => $locked->getKey(), 'status' => 'paid', 'card_pickup' => $locked->card_pickup,
                ]);
            });
        });
    }

    private function expired(ProviderEvent $event): void
    {
        $order = $this->orderOf($event->object);
        if ($order !== null && $order->status === OnlineOrderStatus::Pending) {
            OnlineOrder::query()->whereKey($order->getKey())->where('status', OnlineOrderStatus::Pending->value)
                ->update(['status' => OnlineOrderStatus::Expired->value, 'updated_at' => Carbon::now()]);
        }
    }

    /** A card holder disputed the payment (often a stolen card): the voucher stops paying at once. */
    private function disputed(ProviderEvent $event): void
    {
        $order = $this->orderByPayment((string) ($event->object['payment_intent'] ?? ''), $event->accountId);
        if ($order === null || $order->voucher_id === null) {
            return;
        }
        $this->tenant->runAs($order->restaurant, function () use ($order, $event): void {
            /** @var Voucher $voucher */
            $voucher = Voucher::query()->findOrFail($order->voucher_id);
            if ($voucher->status === VoucherStatus::Active) {
                $this->vouchers->block(Actor::system(), $voucher, 'Online payment disputed');
            }
            $order->forceFill(['status' => OnlineOrderStatus::Disputed])->save();
            $this->events->record(SecurityEventType::OnlineDispute, Actor::system(), subject: $voucher, amount: $order->amount, data: [
                'order_id' => $order->getKey(), 'reason' => mb_substr((string) ($event->object['reason'] ?? ''), 0, 60),
            ]);
            $this->notifyOwners($order, $voucher, 'dispute');
        });
    }

    /** A refund made in the provider's own dashboard, not through ours: the voucher stops until the owner closes it. */
    private function refundedElsewhere(ProviderEvent $event): void
    {
        $order = $this->orderByPayment((string) ($event->object['payment_intent'] ?? ''), $event->accountId);
        if ($order === null || $order->voucher_id === null || $order->status !== OnlineOrderStatus::Paid) {
            return;
        }
        $this->tenant->runAs($order->restaurant, function () use ($order): void {
            /** @var Voucher $voucher */
            $voucher = Voucher::query()->findOrFail($order->voucher_id);
            if ($voucher->status === VoucherStatus::Active) {
                $this->vouchers->block(Actor::system(), $voucher, 'Refunded outside GiftCard Pro');
                $this->notifyOwners($order, $voucher, 'refunded_elsewhere');
            }
        });
    }

    private function accountUpdated(ProviderEvent $event): void
    {
        $account = $this->accountOf($event->accountId ?? (is_string($event->object['id'] ?? null) ? $event->object['id'] : null));
        if ($account === null) {
            return;
        }
        $this->shops->apply(Actor::system(), $account, new ProviderAccount(
            $account->account_id,
            (bool) ($event->object['charges_enabled'] ?? false),
            (bool) ($event->object['payouts_enabled'] ?? false),
            (bool) ($event->object['details_submitted'] ?? false),
        ));
    }

    private function deauthorized(ProviderEvent $event): void
    {
        $account = $this->accountOf($event->accountId);
        if ($account !== null) {
            /** @var Restaurant $restaurant */
            $restaurant = Restaurant::query()->findOrFail($account->restaurant_id);
            $this->shops->disconnect(Actor::system(), $restaurant);
        }
    }

    // ------------------------------------------------------------------ the restaurant

    /**
     * Refunds an online voucher to the buyer's card (owners): the voucher stops first, the provider pays back the
     * paid-in money still on it, then the refund is booked with the provider's refund id. A retry with the same key
     * is the same refund at the provider and here.
     */
    public function refund(Actor $actor, Voucher $voucher, string $reason, string $idempotencyKey): TransactionResult
    {
        /** @var OnlineOrder|null $order */
        $order = OnlineOrder::query()->where('voucher_id', $voucher->getKey())->first();
        if ($order === null || $order->payment_id === null) {
            throw new InvalidVoucherStateException('Only a voucher bought online is refunded online.', ['reason' => 'not_online']);
        }
        if ($voucher->status !== VoucherStatus::Refunded) {
            $amount = $this->vouchers->refundable($voucher);
            if ($amount > $order->amount) {
                // Money added at the till cannot go back to the buyer's card.
                throw new InvalidAmountException('More than the online payment is refundable: refund it in cash or by bank transfer.', ['max' => $order->amount]);
            }
            if ($voucher->status === VoucherStatus::Active) {
                $this->vouchers->block($actor, $voucher, 'Online refund');
            }
            try {
                $refundId = $this->provider->refund($order->account_id, $order->payment_id, $amount, $idempotencyKey);
            } catch (Throwable $e) {
                report($e);

                throw new OnlinePaymentFailedException;
            }
        }

        $result = $this->vouchers->refund($actor, $voucher->refresh(), new PaymentData(PaymentMethod::Online, $refundId ?? 'replay'), $reason, $idempotencyKey);
        $order->forceFill(['status' => OnlineOrderStatus::Refunded])->save();

        return $result;
    }

    /**
     * Binds the gift card the buyer picks up to the online voucher: its QR (`pickup`) and a stock card (`bind`)
     * are both at the till. Not before the hold after the payment (stolen-card purchases), only once.
     */
    public function pickUpCard(Actor $actor, Voucher $voucher, string $qrPresentmentId, string $cardPresentmentId): Voucher
    {
        /** @var OnlineOrder|null $order */
        $order = OnlineOrder::query()->where('voucher_id', $voucher->getKey())->first();
        self::assertPickup($order);

        // The voucher's transaction (presentments → card → voucher, then the order row): a refused QR is still
        // logged, and two hand-outs at once end in one card (the second finds the voucher on a card already).
        return $this->vouchers->convertToCard($actor, $voucher, $qrPresentmentId, $cardPresentmentId, function () use ($actor, $order): void {
            /** @var OnlineOrder $locked */
            $locked = OnlineOrder::query()->whereKey($order->getKey())->lockForUpdate()->firstOrFail();
            self::assertPickup($locked);
            $locked->forceFill(['card_picked_up_at' => Carbon::now()])->save();
            $this->events->record(SecurityEventType::OnlineOrder, $actor, subject: $locked, data: [
                'order_id' => $locked->getKey(), 'status' => 'card_picked_up', 'card_pickup' => true,
            ]);
        });
    }

    /** @phpstan-assert OnlineOrder $order */
    private static function assertPickup(?OnlineOrder $order): void
    {
        if ($order === null || ! $order->card_pickup) {
            throw new InvalidVoucherStateException('No gift card was ordered with this voucher.', ['reason' => 'no_card_ordered']);
        }
        if ($order->card_picked_up_at !== null) {
            throw new InvalidVoucherStateException('The gift card for this voucher was already picked up.', ['reason' => 'picked_up']);
        }
        $from = $order->cardPickupFrom();
        if ($order->status !== OnlineOrderStatus::Paid || $from === null) {
            throw new InvalidVoucherStateException('This voucher cannot get its card now.', ['reason' => 'not_paid']);
        }
        if (Carbon::now()->lessThan($from)) {
            throw new InvalidVoucherStateException('The card can be picked up from '.$from->toIso8601String().'.', ['reason' => 'too_early', 'from' => $from->toIso8601String()]);
        }
    }

    // ------------------------------------------------------------------ helpers

    /** @param array<string, mixed> $session */
    private function orderOf(array $session): ?OnlineOrder
    {
        $id = $session['metadata']['order_id'] ?? $session['client_reference_id'] ?? null;
        if (! is_string($id) || ! Str::isUuid($id)) {
            return null;
        }
        /** @var OnlineOrder|null $order */
        $order = OnlineOrder::query()->find($id);

        // The checkout must be the one we opened for this order.
        return $order !== null && $order->checkout_id === ($session['id'] ?? null) ? $order : null;
    }

    private function orderByPayment(string $paymentId, ?string $accountId): ?OnlineOrder
    {
        if ($paymentId === '') {
            return null;
        }
        /** @var OnlineOrder|null $order */
        $order = OnlineOrder::query()->with('restaurant')->where('payment_id', $paymentId)->first();

        return $order !== null && $order->account_id === $accountId ? $order : null;
    }

    private function accountOf(?string $accountId): ?PspAccount
    {
        if ($accountId === null) {
            return null;
        }

        /** @var PspAccount|null */
        return PspAccount::query()->where('provider', $this->provider->name())->where('account_id', $accountId)->first();
    }

    /** @param 'dispute'|'refunded_elsewhere' $kind */
    private function notifyOwners(OnlineOrder $order, Voucher $voucher, string $kind): void
    {
        $this->mails->owners($order->restaurant_id, $order->restaurant->name, $kind, $voucher->voucher_number, $order->amount, $order->currency);
    }

    private static function text(mixed $value): ?string
    {
        $value = is_string($value) ? trim($value) : '';

        return $value === '' ? null : $value;
    }
}
