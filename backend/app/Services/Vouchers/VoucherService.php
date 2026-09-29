<?php

declare(strict_types=1);

namespace App\Services\Vouchers;

use App\Data\IssueVoucherData;
use App\Data\PaymentData;
use App\Data\SaleResult;
use App\Data\TransactionResult;
use App\Enums\PaymentMethod;
use App\Enums\Permission;
use App\Enums\PresentmentPurpose;
use App\Enums\TransactionType;
use App\Enums\VoucherKind;
use App\Enums\VoucherStatus;
use App\Events\VoucherIssued;
use App\Events\VoucherRedeemed;
use App\Events\VoucherReloaded;
use App\Exceptions\Domain\BalanceLimitExceededException;
use App\Exceptions\Domain\ComplimentaryNotAllowedException;
use App\Exceptions\Domain\DebitLimitExceededException;
use App\Exceptions\Domain\IdempotencyConflictException;
use App\Exceptions\Domain\InsufficientBalanceException;
use App\Exceptions\Domain\InvalidAmountException;
use App\Exceptions\Domain\InvalidVoucherStateException;
use App\Exceptions\Domain\PresentmentInvalidException;
use App\Exceptions\Domain\ReloadNotAllowedException;
use App\Exceptions\Domain\TenantMismatchException;
use App\Exceptions\Domain\TransactionNotReversibleException;
use App\Exceptions\Domain\VelocityLimitExceededException;
use App\Exceptions\Domain\VoucherBlockedException;
use App\Exceptions\Domain\VoucherExpiredException;
use App\Exceptions\Domain\VoucherNotRedeemableException;
use App\Models\Customer;
use App\Models\Payment;
use App\Models\Presentment;
use App\Models\Restaurant;
use App\Models\RestaurantSetting;
use App\Models\Voucher;
use App\Models\VoucherTransaction;
use App\Services\Audit\AuditLogger;
use App\Services\Media\PrintableQrService;
use App\Services\Presentments\PresentmentService;
use App\Support\Actor;
use App\Support\Tenancy\TenantContext;
use Closure;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * The single entry point for every change of a voucher's money or status.
 *
 * Guarantees:
 *  - Atomicity: every operation is one database transaction.
 *  - No double spending: the voucher row is locked (SELECT … FOR UPDATE) before its balance is read.
 *  - Proof of presence: every debit consumes a presentment of the voucher's own medium, in the same transaction.
 *  - Payment evidence: every sale and reload records the payment that funded it.
 *  - Idempotency: money operations carry an idempotency key (unique per restaurant). The key is checked before
 *    and again after the row lock, so a retry that waited for the first attempt replays its result (audit P2).
 *  - Immutable history: ledger, payments and audit log are append-only and hash-chained. A correction is a
 *    new entry (reversal); expiry never writes a balance off.
 */
final class VoucherService
{
    private const DB_ATTEMPTS = 3;

    public function __construct(
        private readonly TenantContext $tenant,
        private readonly AuditLogger $audit,
        private readonly VoucherNumberGenerator $numbers,
        private readonly PresentmentService $presentments,
        private readonly PrintableQrService $printables,
    ) {}

    // ---------------------------------------------------------------------
    // Sale
    // ---------------------------------------------------------------------

    /**
     * Sells a digital voucher with its printable QR. The QR payload is part of the result only; it is never
     * stored. A retry of the same sale (same key, same user and device) within the sale window, before the
     * voucher was used, issues a fresh QR and revokes the unseen one: the buyer is still at the counter
     * (invariant 8, "media created within the sale itself").
     */
    public function sell(Actor $actor, IssueVoucherData $data): SaleResult
    {
        $restaurant = $this->tenant->require();
        $settings = $restaurant->settings;

        $this->assertAmountInRange($data->value, $settings->min_voucher_value, $settings->max_voucher_balance);
        $this->assertPaymentAllowed($actor, $data->payment);

        $existing = $this->findByKey($restaurant->getKey(), $data->idempotencyKey);
        if ($existing !== null) {
            return $this->replaySale($actor, $existing, $data);
        }

        try {
            $result = DB::transaction(function () use ($actor, $data, $restaurant, $settings): SaleResult {
                $voucher = new Voucher;
                $voucher->forceFill([
                    'restaurant_id' => $restaurant->getKey(),
                    'customer_id' => $data->customerId,
                    'kind' => VoucherKind::Digital,
                    'voucher_number' => $this->numbers->generate($restaurant),
                    'status' => VoucherStatus::Active,
                    'currency' => $restaurant->currency,
                    'initial_value' => $data->value,
                    'balance' => 0,
                    'total_loaded' => $data->value,
                    'total_redeemed' => 0,
                    'expires_at' => $this->expiryFor($restaurant, $settings),
                    'issued_by' => $actor->userId(),
                    'recipient_name' => $data->recipientName,
                    'notes' => $data->notes,
                ]);

                $customer = null;
                if ($data->newCustomer !== null) {
                    $customer = new Customer;
                    $customer->fill($data->newCustomer)->save();
                    $voucher->customer_id = $customer->getKey();
                }
                $voucher->save();

                // Chain order: payments → ledger → audit log.
                $payment = $this->recordPayment($voucher, $data->value, $data->payment, $actor);
                $tx = $this->record($voucher, TransactionType::Issue, $data->value, $actor, $data->idempotencyKey, payment: $payment);
                $voucher->save();

                if ($customer !== null) {
                    $this->audit->log('customer.created', $actor, $customer);
                }
                $this->audit->log('voucher.sold', $actor, $voucher, null, [
                    'kind' => $voucher->kind,
                    'value' => $data->value,
                    'payment_method' => $data->payment->method,
                    'expires_at' => $voucher->expires_at,
                ], ['transaction_id' => $tx->getKey(), 'payment_id' => $payment->getKey()]);

                $printable = $this->printables->issue($actor, $voucher, 'sale');

                VoucherIssued::dispatch($voucher, $tx);

                return new SaleResult($voucher, $tx, $payment, $printable);
            }, self::DB_ATTEMPTS);
        } catch (UniqueConstraintViolationException $e) {
            // A concurrent request with the same idempotency key won the race.
            $existing = $this->findByKey($restaurant->getKey(), $data->idempotencyKey) ?? throw $e;

            return $this->replaySale($actor, $existing, $data);
        }

        return $result;
    }

    // ---------------------------------------------------------------------
    // Money movements
    // ---------------------------------------------------------------------

    /**
     * Debits a voucher. `$presentmentId` must be a verified, unexpired `spend` presentment of this voucher,
     * made by the same user on the same device, with a method allowed for the voucher's kind.
     */
    public function redeem(
        Actor $actor,
        Voucher $voucher,
        int $amount,
        string $presentmentId,
        string $idempotencyKey,
        ?string $reference = null,
        ?string $note = null,
    ): TransactionResult {
        $this->assertOwnedByTenant($voucher);
        $this->assertPositive($amount);

        $matches = static fn (VoucherTransaction $tx): bool => $tx->type === TransactionType::Redemption
            && $tx->voucher_id === $voucher->getKey()
            && -$tx->amount === $amount;

        try {
            return $this->idempotent($voucher->restaurant_id, $idempotencyKey, $matches, function () use ($actor, $voucher, $amount, $presentmentId, $idempotencyKey, $reference, $note, $matches): TransactionResult {
                // Lock order: presentment, then voucher (architecture §10.6).
                /** @var Presentment|null $presentment */
                $presentment = Presentment::query()->whereKey($presentmentId)->lockForUpdate()->first();
                $locked = $this->lock($voucher);

                // A retry that waited on the locks while the first attempt committed replays it (audit P2).
                $replay = $this->findByKey($locked->restaurant_id, $idempotencyKey);
                if ($replay !== null) {
                    return $this->replay($replay, $matches);
                }

                $presentment = $this->presentments->consume($presentment, $actor, $locked, PresentmentPurpose::Spend);
                $settings = $this->settings();

                $this->assertRedeemable($locked);
                if ($amount > $locked->balance) {
                    throw new InsufficientBalanceException('', ['balance' => $locked->balance, 'requested' => $amount]);
                }
                if (! $settings->allow_partial_redemption && $amount !== $locked->balance) {
                    throw new InvalidAmountException('This restaurant only allows redeeming the full voucher balance.', ['balance' => $locked->balance]);
                }
                $this->assertDebitLimits($locked, $amount, $settings);
                $this->assertVelocity($locked, $settings);

                $tx = $this->record($locked, TransactionType::Redemption, -$amount, $actor, $idempotencyKey, $reference, $note, presentment: $presentment);
                $locked->total_redeemed += $amount;
                $locked->last_used_at = Carbon::now();
                $locked->save();

                $this->audit->log('voucher.redeemed', $actor, $locked, null, [
                    'amount' => $amount,
                    'balance' => $locked->balance,
                ], ['transaction_id' => $tx->getKey(), 'presentment_id' => $presentment->getKey(), 'reference' => $reference]);

                VoucherRedeemed::dispatch($locked, $tx);

                return new TransactionResult($locked, $tx);
            });
        } catch (PresentmentInvalidException $e) {
            $this->presentments->recordRejection($actor, $voucher, $presentmentId, $e);

            throw $e;
        }
    }

    public function reload(
        Actor $actor,
        Voucher $voucher,
        int $amount,
        PaymentData $payment,
        string $idempotencyKey,
        ?string $note = null,
    ): TransactionResult {
        $this->assertOwnedByTenant($voucher);
        $this->assertPositive($amount);
        $this->assertPaymentAllowed($actor, $payment);

        $matches = static fn (VoucherTransaction $tx): bool => $tx->type === TransactionType::Reload
            && $tx->voucher_id === $voucher->getKey()
            && $tx->amount === $amount;

        return $this->idempotent($voucher->restaurant_id, $idempotencyKey, $matches, function () use ($actor, $voucher, $amount, $payment, $idempotencyKey, $note, $matches): TransactionResult {
            $locked = $this->lock($voucher);

            $replay = $this->findByKey($locked->restaurant_id, $idempotencyKey);
            if ($replay !== null) {
                return $this->replay($replay, $matches);
            }

            $settings = $this->settings();
            if (! $settings->allow_reload) {
                throw new ReloadNotAllowedException;
            }
            $this->assertUsable($locked);
            if ($locked->balance + $amount > $settings->max_voucher_balance) {
                throw new BalanceLimitExceededException('', ['max_voucher_balance' => $settings->max_voucher_balance, 'balance' => $locked->balance]);
            }

            $paymentRow = $this->recordPayment($locked, $amount, $payment, $actor);
            $tx = $this->record($locked, TransactionType::Reload, $amount, $actor, $idempotencyKey, note: $note, payment: $paymentRow);
            $locked->total_loaded += $amount;
            $locked->last_used_at = Carbon::now();
            $locked->save();

            $this->audit->log('voucher.reloaded', $actor, $locked, null, [
                'amount' => $amount,
                'balance' => $locked->balance,
                'payment_method' => $payment->method,
            ], ['transaction_id' => $tx->getKey(), 'payment_id' => $paymentRow->getKey()]);

            VoucherReloaded::dispatch($locked, $tx);

            return new TransactionResult($locked, $tx);
        });
    }

    /**
     * Corrects a redemption or reload with a new, opposite entry. The original entry is never touched; it
     * counts as reversed because a reversal points at it (UNIQUE, so at most once).
     */
    public function reverse(Actor $actor, VoucherTransaction $transaction, string $reason): TransactionResult
    {
        if ($transaction->restaurant_id !== $this->tenant->id()) {
            throw new TenantMismatchException;
        }
        if (! $transaction->type->isReversible()) {
            throw new TransactionNotReversibleException;
        }

        try {
            return DB::transaction(function () use ($actor, $transaction, $reason): TransactionResult {
                $voucher = $this->lock($transaction->voucher()->firstOrFail());

                if ($transaction->reversal()->exists()) {
                    throw new TransactionNotReversibleException('This transaction has already been reversed.');
                }

                $delta = -$transaction->amount;
                if ($voucher->balance + $delta < 0) {
                    throw new InsufficientBalanceException('The voucher balance is too low to reverse this reload.', ['balance' => $voucher->balance]);
                }
                $settings = $this->settings();
                if ($delta > 0 && $voucher->balance + $delta > $settings->max_voucher_balance) {
                    // The stored-value cap holds for corrections too (audit P8a).
                    throw new BalanceLimitExceededException('', ['max_voucher_balance' => $settings->max_voucher_balance, 'balance' => $voucher->balance]);
                }

                $tx = $this->record($voucher, TransactionType::Reversal, $delta, $actor, note: $reason, related: $transaction);
                if ($transaction->type === TransactionType::Redemption) {
                    $voucher->total_redeemed -= -$transaction->amount;
                } else {
                    $voucher->total_loaded -= $transaction->amount;
                }
                $voucher->save();

                $this->audit->log('transaction.reversed', $actor, $transaction, null, [
                    'reversal_transaction_id' => $tx->getKey(),
                    'amount' => $delta,
                    'balance' => $voucher->balance,
                ], ['reason' => $reason, 'voucher_id' => $voucher->getKey()]);

                return new TransactionResult($voucher, $tx);
            }, self::DB_ATTEMPTS);
        } catch (UniqueConstraintViolationException) {
            // A concurrent reversal of the same entry won.
            throw new TransactionNotReversibleException('This transaction has already been reversed.');
        }
    }

    // ---------------------------------------------------------------------
    // Status changes (never touch the balance)
    // ---------------------------------------------------------------------

    public function block(Actor $actor, Voucher $voucher, string $reason): Voucher
    {
        return $this->mutate($voucher, function (Voucher $locked) use ($actor, $reason): void {
            if ($locked->status === VoucherStatus::Blocked) {
                throw new InvalidVoucherStateException('This voucher is already blocked.', ['status' => $locked->status->value]);
            }

            $previous = $locked->status;
            $locked->status = VoucherStatus::Blocked;
            $locked->blocked_at = Carbon::now();
            $locked->blocked_reason = $reason;
            $locked->save();

            $this->audit->log('voucher.blocked', $actor, $locked, ['status' => $previous], ['status' => $locked->status], ['reason' => $reason]);
        });
    }

    /** Back to active, or to expired when the voucher's expiry passed while it was blocked. */
    public function unblock(Actor $actor, Voucher $voucher): Voucher
    {
        return $this->mutate($voucher, function (Voucher $locked) use ($actor): void {
            if ($locked->status !== VoucherStatus::Blocked) {
                throw new InvalidVoucherStateException('Only blocked vouchers can be unblocked.', ['status' => $locked->status->value]);
            }

            $expired = $locked->isExpiredByDate();
            $locked->status = $expired ? VoucherStatus::Expired : VoucherStatus::Active;
            $locked->expired_at = $expired ? Carbon::now() : $locked->expired_at;
            $locked->blocked_at = null;
            $locked->blocked_reason = null;
            $locked->save();

            $this->audit->log('voucher.unblocked', $actor, $locked, ['status' => VoucherStatus::Blocked], ['status' => $locked->status]);
        });
    }

    /**
     * Expires an active voucher now. The balance stays (audit P6); the voucher can be reinstated. Owner only,
     * always with a reason (audit P7). `$reason` null is used by the nightly job when the expiry date passed.
     */
    public function expire(Actor $actor, Voucher $voucher, ?string $reason): Voucher
    {
        return $this->mutate($voucher, function (Voucher $locked) use ($actor, $reason): void {
            if ($locked->status !== VoucherStatus::Active) {
                throw new InvalidVoucherStateException('Only active vouchers can expire.', ['status' => $locked->status->value]);
            }

            $locked->status = VoucherStatus::Expired;
            $locked->expired_at = Carbon::now();
            $locked->save();

            $this->audit->log('voucher.expired', $actor, $locked, ['status' => VoucherStatus::Active], [
                'status' => VoucherStatus::Expired,
                'balance' => $locked->balance,
            ], ['reason' => $reason ?? 'expiry_date_reached']);
        });
    }

    /**
     * Makes an expired voucher usable again, with its full balance. `$expiresOn` is the new last valid day
     * (restaurant timezone) or null for no expiry.
     */
    public function reinstate(Actor $actor, Voucher $voucher, string $reason, ?string $expiresOn): Voucher
    {
        return $this->mutate($voucher, function (Voucher $locked) use ($actor, $reason, $expiresOn): void {
            if ($locked->status !== VoucherStatus::Expired) {
                throw new InvalidVoucherStateException('Only expired vouchers can be reinstated.', ['status' => $locked->status->value]);
            }

            $previousExpiry = $locked->expires_at;
            $locked->status = VoucherStatus::Active;
            $locked->expires_at = $expiresOn !== null ? $this->endOfDay($expiresOn, $this->tenant->require()) : null;
            $locked->expired_at = null;
            $locked->save();

            $this->audit->log('voucher.reinstated', $actor, $locked, [
                'status' => VoucherStatus::Expired,
                'expires_at' => $previousExpiry,
            ], [
                'status' => VoucherStatus::Active,
                'expires_at' => $locked->expires_at,
                'balance' => $locked->balance,
            ], ['reason' => $reason]);
        });
    }

    /**
     * @param  array{customer_id?: string|null, recipient_name?: string|null, notes?: string|null}  $attributes
     */
    public function update(Actor $actor, Voucher $voucher, array $attributes): Voucher
    {
        return $this->mutate($voucher, function (Voucher $locked) use ($actor, $attributes): void {
            $locked->fill($attributes);
            $dirty = $locked->getDirty();
            if ($dirty === []) {
                return;
            }

            $old = array_intersect_key($locked->getOriginal(), $dirty);
            $locked->save();

            $this->audit->log('voucher.updated', $actor, $locked, $old, $dirty);
        });
    }

    /**
     * Expires every active voucher whose last valid day has ended. Blocked vouchers are left alone (audit P6);
     * unblocking them applies the expiry. Balances are kept.
     */
    public function expireDue(Restaurant $restaurant, ?Carbon $now = null): int
    {
        $count = 0;

        $this->tenant->runAs($restaurant, function () use (&$count, $now): void {
            Voucher::query()
                ->where('status', VoucherStatus::Active->value)
                ->whereNotNull('expires_at')
                ->where('expires_at', '<=', $now ?? Carbon::now())
                ->orderBy('id')
                ->chunkById(200, function ($vouchers) use (&$count): void {
                    foreach ($vouchers as $voucher) {
                        /** @var Voucher $voucher */
                        try {
                            $this->expire(Actor::system(), $voucher, null);
                            $count++;
                        } catch (InvalidVoucherStateException) {
                            // Blocked or expired concurrently: nothing to do.
                        } catch (\Throwable $e) {
                            // One broken voucher must never stop the nightly run for everybody else.
                            report($e);
                        }
                    }
                });
        });

        return $count;
    }

    // ---------------------------------------------------------------------
    // Internals
    // ---------------------------------------------------------------------

    private function replaySale(Actor $actor, VoucherTransaction $existing, IssueVoucherData $data): SaleResult
    {
        if ($existing->type !== TransactionType::Issue || $existing->amount !== $data->value) {
            throw new IdempotencyConflictException;
        }

        return DB::transaction(function () use ($actor, $existing): SaleResult {
            $voucher = $this->lock($existing->voucher()->firstOrFail());
            /** @var Payment $payment */
            $payment = Payment::query()->findOrFail($existing->payment_id);

            $window = (int) config('giftcard.security.sale_replay_window_minutes', 15);
            $sameSeller = $existing->user_id === $actor->userId() && $existing->device_id === $actor->deviceId();
            $untouched = ! VoucherTransaction::query()->where('voucher_id', $voucher->getKey())->whereKeyNot($existing->getKey())->exists();
            $recent = $existing->created_at->greaterThan(Carbon::now()->subMinutes($window));

            $printable = null;
            if ($sameSeller && $untouched && $recent && $voucher->kind === VoucherKind::Digital && $voucher->status === VoucherStatus::Active) {
                $printable = $this->printables->issue($actor, $voucher, 'sale_retry');
            }

            return new SaleResult($voucher, $existing, $payment, $printable, replayed: true);
        }, self::DB_ATTEMPTS);
    }

    private function recordPayment(Voucher $voucher, int $amount, PaymentData $data, Actor $actor): Payment
    {
        $complimentary = $data->method === PaymentMethod::Complimentary;

        $payment = new Payment;
        $payment->forceFill([
            'restaurant_id' => $voucher->restaurant_id,
            'voucher_id' => $voucher->getKey(),
            'method' => $data->method,
            'amount' => $amount,
            'currency' => $voucher->currency,
            'reference' => $data->reference,
            'approved_by' => $complimentary ? $actor->userId() : null,
            'reason' => $data->reason,
            'received_by' => $actor->userId(),
            'device_id' => $actor->deviceId(),
        ])->save();

        return $payment;
    }

    private function assertPaymentAllowed(Actor $actor, PaymentData $payment): void
    {
        if ($payment->method === PaymentMethod::Complimentary) {
            if ($actor->user === null || ! $actor->user->hasPermission(Permission::VouchersSellComplimentary)) {
                throw new ComplimentaryNotAllowedException;
            }
            if ($payment->reason === null || mb_strlen(trim($payment->reason)) < 3) {
                throw new InvalidAmountException('A complimentary voucher needs a reason.');
            }
        }
        if ($payment->method->requiresReference() && $payment->reference === null) {
            throw new InvalidAmountException('This payment method needs a reference (terminal receipt or bank reference).', ['method' => $payment->method->value]);
        }
    }

    /**
     * @param  Closure(Voucher): void  $callback
     */
    private function mutate(Voucher $voucher, Closure $callback): Voucher
    {
        $this->assertOwnedByTenant($voucher);

        return DB::transaction(function () use ($voucher, $callback): Voucher {
            $locked = $this->lock($voucher);
            $callback($locked);

            return $locked;
        }, self::DB_ATTEMPTS);
    }

    private function expiryFor(Restaurant $restaurant, RestaurantSetting $settings): ?Carbon
    {
        if ($settings->validity_months === null) {
            return null;
        }

        return Carbon::now($restaurant->timezone)->addMonthsNoOverflow($settings->validity_months)->endOfDay()->utc();
    }

    /** The last second of a calendar day (Y-m-d) in the restaurant's timezone, stored in UTC. */
    private function endOfDay(string $date, Restaurant $restaurant): Carbon
    {
        $moment = Carbon::createFromFormat('Y-m-d', $date, $restaurant->timezone);
        if ($moment === null) {
            throw new InvalidAmountException('The expiration date is invalid.');
        }
        $moment = $moment->endOfDay();

        if ($moment->isPast()) {
            throw new InvalidAmountException('The expiration date must be in the future.');
        }

        return $moment->utc();
    }

    private function lock(Voucher $voucher): Voucher
    {
        /** @var Voucher */
        return Voucher::query()->whereKey($voucher->getKey())->lockForUpdate()->firstOrFail();
    }

    /**
     * Applies a signed amount to the locked voucher and appends the ledger entry. The caller saves the voucher.
     */
    private function record(
        Voucher $voucher,
        TransactionType $type,
        int $amount,
        Actor $actor,
        ?string $idempotencyKey = null,
        ?string $reference = null,
        ?string $note = null,
        ?VoucherTransaction $related = null,
        ?Payment $payment = null,
        ?Presentment $presentment = null,
    ): VoucherTransaction {
        $before = $voucher->balance;
        $after = $before + $amount;

        if ($after < 0) {
            throw new InsufficientBalanceException('', ['balance' => $before]);
        }

        $voucher->balance = $after;

        $tx = new VoucherTransaction;
        $tx->forceFill([
            'restaurant_id' => $voucher->restaurant_id,
            'voucher_id' => $voucher->getKey(),
            'type' => $type,
            'amount' => $amount,
            'balance_before' => $before,
            'balance_after' => $after,
            'currency' => $voucher->currency,
            'idempotency_key' => $idempotencyKey,
            'presentment_id' => $presentment?->getKey(),
            'payment_id' => $payment?->getKey(),
            'related_transaction_id' => $related?->getKey(),
            'reference' => $reference,
            'note' => $note,
            'user_id' => $actor->userId(),
            'device_id' => $actor->deviceId(),
            'ip_address' => $actor->ipAddress,
            'created_at' => Carbon::now(),
        ])->save();

        return $tx;
    }

    /**
     * @param  Closure(VoucherTransaction): bool  $matches
     * @param  Closure(): TransactionResult  $operation
     */
    private function idempotent(string $restaurantId, string $key, Closure $matches, Closure $operation): TransactionResult
    {
        $existing = $this->findByKey($restaurantId, $key);
        if ($existing !== null) {
            return $this->replay($existing, $matches);
        }

        try {
            return DB::transaction($operation, self::DB_ATTEMPTS);
        } catch (UniqueConstraintViolationException $e) {
            // A concurrent request with the same idempotency key won the race.
            $existing = $this->findByKey($restaurantId, $key) ?? throw $e;

            return $this->replay($existing, $matches);
        }
    }

    /**
     * @param  Closure(VoucherTransaction): bool  $matches
     */
    private function replay(VoucherTransaction $existing, Closure $matches): TransactionResult
    {
        if (! $matches($existing)) {
            throw new IdempotencyConflictException;
        }

        return new TransactionResult($existing->voucher()->firstOrFail(), $existing, replayed: true);
    }

    private function findByKey(string $restaurantId, string $key): ?VoucherTransaction
    {
        /** @var VoucherTransaction|null */
        return VoucherTransaction::query()
            ->forRestaurant($restaurantId)
            ->where('idempotency_key', $key)
            ->first();
    }

    private function settings(): RestaurantSetting
    {
        return $this->tenant->require()->settings;
    }

    private function assertOwnedByTenant(Voucher $voucher): void
    {
        if ($voucher->restaurant_id !== $this->tenant->require()->getKey()) {
            throw new TenantMismatchException;
        }
    }

    /** Active and not past its expiry date (the nightly job may not have run yet). */
    private function assertUsable(Voucher $voucher): void
    {
        match (true) {
            $voucher->status === VoucherStatus::Blocked => throw new VoucherBlockedException,
            $voucher->status === VoucherStatus::Expired, $voucher->isExpiredByDate() => throw new VoucherExpiredException,
            $voucher->status !== VoucherStatus::Active => throw new VoucherNotRedeemableException('', ['status' => $voucher->status->value]),
            default => null,
        };
    }

    private function assertRedeemable(Voucher $voucher): void
    {
        $this->assertUsable($voucher);
        if ($voucher->balance === 0) {
            throw new InsufficientBalanceException('This voucher has no balance left.', ['balance' => 0]);
        }
    }

    /** Per-transaction and per-day limits (architecture §6.3), checked under the voucher lock. */
    private function assertDebitLimits(Voucher $voucher, int $amount, RestaurantSetting $settings): void
    {
        if ($amount > $settings->max_debit_per_transaction) {
            throw new DebitLimitExceededException('The amount exceeds the maximum for one redemption.', [
                'limit' => 'per_transaction',
                'max' => $settings->max_debit_per_transaction,
            ]);
        }

        $dayStart = Carbon::now($this->tenant->require()->timezone)->startOfDay()->utc();
        $today = (int) -VoucherTransaction::query()
            ->where('voucher_id', $voucher->getKey())
            ->ofType(TransactionType::Redemption)
            ->notReversed()
            ->where('created_at', '>=', $dayStart)
            ->sum('amount');

        if ($today + $amount > $settings->max_debit_per_voucher_per_day) {
            throw new DebitLimitExceededException('The amount exceeds what this voucher may pay today.', [
                'limit' => 'per_voucher_per_day',
                'max' => $settings->max_debit_per_voucher_per_day,
                'remaining' => max(0, $settings->max_debit_per_voucher_per_day - $today),
            ]);
        }
    }

    private function assertVelocity(Voucher $voucher, RestaurantSetting $settings): void
    {
        $limit = $settings->max_redemptions_per_voucher_per_hour;
        if ($limit <= 0) {
            return;
        }

        $window = VoucherTransaction::query()
            ->where('voucher_id', $voucher->getKey())
            ->ofType(TransactionType::Redemption)
            ->notReversed()
            ->where('created_at', '>=', Carbon::now()->subHour());

        $recent = (clone $window)->count();

        if ($recent >= $limit) {
            // A slot frees when the redemption that must drop out of the one-hour window reaches its age.
            /** @var VoucherTransaction|null $blocking */
            $blocking = $window->orderBy('created_at')->skip($recent - $limit)->first();
            $retryAfter = $blocking !== null
                ? max(1, (int) ceil(Carbon::now()->diffInSeconds($blocking->created_at->copy()->addHour(), true)))
                : null;

            throw new VelocityLimitExceededException('', $retryAfter !== null ? ['retry_after' => $retryAfter] : []);
        }
    }

    private function assertPositive(int $amount): void
    {
        if ($amount <= 0) {
            throw new InvalidAmountException('The amount must be greater than zero.');
        }
    }

    private function assertAmountInRange(int $amount, int $min, int $max): void
    {
        if ($amount < $min || $amount > $max) {
            throw new InvalidAmountException('The amount is outside the allowed range.', ['min' => $min, 'max' => $max]);
        }
    }
}
