<?php

declare(strict_types=1);

namespace App\Services\GiftCards;

use App\Data\IssueGiftCardData;
use App\Data\TransactionResult;
use App\Enums\GiftCardStatus;
use App\Enums\NfcTagType;
use App\Enums\TransactionType;
use App\Events\GiftCardIssued;
use App\Events\GiftCardRedeemed;
use App\Events\GiftCardReloaded;
use App\Exceptions\Domain\BalanceLimitExceededException;
use App\Exceptions\Domain\CardBlockedException;
use App\Exceptions\Domain\CardExpiredException;
use App\Exceptions\Domain\CardNotRedeemableException;
use App\Exceptions\Domain\IdempotencyConflictException;
use App\Exceptions\Domain\InsufficientBalanceException;
use App\Exceptions\Domain\InvalidAmountException;
use App\Exceptions\Domain\InvalidCardStateException;
use App\Exceptions\Domain\NfcCardAlreadyProgrammedException;
use App\Exceptions\Domain\NfcTagInUseException;
use App\Exceptions\Domain\NfcVerificationFailedException;
use App\Exceptions\Domain\ReloadNotAllowedException;
use App\Exceptions\Domain\TenantMismatchException;
use App\Exceptions\Domain\TransactionNotReversibleException;
use App\Exceptions\Domain\VelocityLimitExceededException;
use App\Models\Customer;
use App\Models\GiftCard;
use App\Models\GiftCardTransaction;
use App\Models\Restaurant;
use App\Models\RestaurantSetting;
use App\Services\Audit\AuditLogger;
use App\Support\Actor;
use App\Support\CardNumber;
use App\Support\Tenancy\TenantContext;
use Closure;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * The single entry point for every state or balance change of a gift card.
 *
 * Guarantees:
 *  - Atomicity: every operation runs in one database transaction.
 *  - No race conditions / double spending: the card row is locked with SELECT ... FOR UPDATE
 *    before the balance is read, so concurrent redemptions are serialised.
 *  - Idempotency: money-moving operations accept an idempotency key (unique per restaurant);
 *    a retried request returns the original result instead of charging twice.
 *  - Full ledger: every balance change produces an immutable GiftCardTransaction and an audit log.
 */
final class GiftCardService
{
    private const DB_ATTEMPTS = 3;

    public function __construct(
        private readonly TenantContext $tenant,
        private readonly AuditLogger $audit,
        private readonly CardNumberGenerator $numbers,
    ) {}

    // ---------------------------------------------------------------------
    // Issuing
    // ---------------------------------------------------------------------

    public function issue(Actor $actor, IssueGiftCardData $data): TransactionResult
    {
        $restaurant = $this->tenant->require();
        $settings = $restaurant->settings;

        $this->assertAmountInRange($data->value, $settings->min_card_value, $settings->max_card_value);

        $expiresAt = match (true) {
            $data->expiresOn !== null => $this->endOfDay($data->expiresOn, $restaurant),
            $data->useDefaultExpiry && $settings->default_validity_months > 0 => Carbon::now($restaurant->timezone)
                ->addMonthsNoOverflow($settings->default_validity_months)->endOfDay()->utc(),
            default => null,
        };

        return $this->idempotent(
            $restaurant->getKey(),
            $data->idempotencyKey,
            static fn (GiftCardTransaction $tx): bool => $tx->type === TransactionType::Issue && $tx->amount === $data->value,
            function () use ($actor, $data, $restaurant, $expiresAt): TransactionResult {
                $customerId = $data->customerId;
                if ($data->newCustomer !== null) {
                    $customer = new Customer;
                    $customer->fill($data->newCustomer)->save();
                    $customerId = $customer->getKey();
                    $this->audit->log('customer.created', $actor, $customer);
                }

                $card = new GiftCard;
                $card->forceFill([
                    'restaurant_id' => $restaurant->getKey(),
                    'customer_id' => $customerId,
                    'public_token' => (string) Str::uuid(), // RFC 4122 v4, cryptographically random
                    'card_number' => $this->numbers->generate($restaurant),
                    'status' => $data->activate ? GiftCardStatus::Active : GiftCardStatus::Inactive,
                    'currency' => $restaurant->currency,
                    'initial_value' => $data->value,
                    'balance' => 0,
                    'total_loaded' => $data->value,
                    'total_redeemed' => 0,
                    'expires_at' => $expiresAt,
                    'activated_at' => $data->activate ? Carbon::now() : null,
                    'issued_by' => $actor->userId(),
                    'recipient_name' => $data->recipientName,
                    'notes' => $data->notes,
                    'nfc_tag_type' => $data->tagType,
                ])->save();

                $tx = $this->record($card, TransactionType::Issue, $data->value, $actor, $data->idempotencyKey);
                $card->save();

                $this->audit->log('gift_card.issued', $actor, $card, null, [
                    'card_number' => $card->card_number,
                    'value' => $data->value,
                    'status' => $card->status,
                    'expires_at' => $card->expires_at,
                ]);

                GiftCardIssued::dispatch($card, $tx);

                return new TransactionResult($card, $tx);
            },
        );
    }

    public function activate(Actor $actor, GiftCard $card): GiftCard
    {
        return $this->mutate($card, function (GiftCard $locked) use ($actor): void {
            if ($locked->status !== GiftCardStatus::Inactive) {
                throw new InvalidCardStateException('Only inactive cards can be activated.', ['status' => $locked->status->value]);
            }
            if ($locked->isExpiredByDate()) {
                throw new CardExpiredException;
            }

            $locked->status = $locked->balance > 0 ? GiftCardStatus::Active : GiftCardStatus::Redeemed;
            $locked->activated_at = Carbon::now();
            $locked->save();

            $this->audit->log('gift_card.activated', $actor, $locked, ['status' => GiftCardStatus::Inactive], ['status' => $locked->status]);
        });
    }

    // ---------------------------------------------------------------------
    // Money movements
    // ---------------------------------------------------------------------

    public function redeem(
        Actor $actor,
        GiftCard $card,
        int $amount,
        ?string $idempotencyKey = null,
        ?string $reference = null,
        ?string $note = null,
    ): TransactionResult {
        $this->assertOwnedByTenant($card);
        $this->assertPositive($amount);

        return $this->idempotent(
            $card->restaurant_id,
            $idempotencyKey,
            static fn (GiftCardTransaction $tx): bool => $tx->type === TransactionType::Redemption
                && $tx->gift_card_id === $card->getKey()
                && -$tx->amount === $amount,
            function () use ($actor, $card, $amount, $idempotencyKey, $reference, $note): TransactionResult {
                $locked = $this->lock($card);
                $settings = $this->settings();

                $this->assertRedeemable($locked);

                if ($settings->max_single_redemption !== null && $amount > $settings->max_single_redemption) {
                    throw new InvalidAmountException('The amount exceeds the maximum allowed for a single redemption.', [
                        'max_single_redemption' => $settings->max_single_redemption,
                    ]);
                }
                if ($amount > $locked->balance) {
                    throw new InsufficientBalanceException('', ['balance' => $locked->balance, 'requested' => $amount]);
                }
                if (! $settings->allow_partial_redemption && $amount !== $locked->balance) {
                    throw new InvalidAmountException('This restaurant only allows redeeming the full card balance.', ['balance' => $locked->balance]);
                }
                $this->assertVelocity($locked, $settings);

                $tx = $this->record($locked, TransactionType::Redemption, -$amount, $actor, $idempotencyKey, $reference, $note);
                $locked->total_redeemed += $amount;
                $locked->last_used_at = Carbon::now();

                if ($locked->balance === 0) {
                    $locked->status = GiftCardStatus::Redeemed;
                    $locked->redeemed_at = Carbon::now();
                }
                $locked->save();

                $this->audit->log('gift_card.redeemed', $actor, $locked, null, [
                    'amount' => $amount,
                    'balance' => $locked->balance,
                    'status' => $locked->status,
                ], ['transaction_id' => $tx->getKey(), 'reference' => $reference]);

                GiftCardRedeemed::dispatch($locked, $tx);

                return new TransactionResult($locked, $tx);
            },
        );
    }

    public function reload(
        Actor $actor,
        GiftCard $card,
        int $amount,
        ?string $idempotencyKey = null,
        ?string $reference = null,
        ?string $note = null,
    ): TransactionResult {
        $this->assertOwnedByTenant($card);
        $this->assertPositive($amount);

        return $this->idempotent(
            $card->restaurant_id,
            $idempotencyKey,
            static fn (GiftCardTransaction $tx): bool => $tx->type === TransactionType::Reload
                && $tx->gift_card_id === $card->getKey()
                && $tx->amount === $amount,
            function () use ($actor, $card, $amount, $idempotencyKey, $reference, $note): TransactionResult {
                $locked = $this->lock($card);
                $settings = $this->settings();

                if (! $settings->allow_reload) {
                    throw new ReloadNotAllowedException;
                }
                if (! in_array($locked->status, [GiftCardStatus::Active, GiftCardStatus::Redeemed, GiftCardStatus::Inactive], true)) {
                    throw $locked->status === GiftCardStatus::Blocked
                        ? new CardBlockedException
                        : new InvalidCardStateException('This card can no longer be reloaded.', ['status' => $locked->status->value]);
                }
                if ($locked->isExpiredByDate()) {
                    throw new CardExpiredException;
                }
                $this->assertAmountInRange($amount, 1, $settings->max_card_value);
                if ($locked->balance + $amount > $settings->max_card_balance) {
                    throw new BalanceLimitExceededException('', ['max_card_balance' => $settings->max_card_balance, 'balance' => $locked->balance]);
                }

                $tx = $this->record($locked, TransactionType::Reload, $amount, $actor, $idempotencyKey, $reference, $note);
                $locked->total_loaded += $amount;
                $locked->last_used_at = Carbon::now();
                if ($locked->status === GiftCardStatus::Redeemed) {
                    $locked->status = GiftCardStatus::Active;
                    $locked->redeemed_at = null;
                }
                $locked->save();

                $this->audit->log('gift_card.reloaded', $actor, $locked, null, [
                    'amount' => $amount,
                    'balance' => $locked->balance,
                ], ['transaction_id' => $tx->getKey(), 'reference' => $reference]);

                GiftCardReloaded::dispatch($locked, $tx);

                return new TransactionResult($locked, $tx);
            },
        );
    }

    /**
     * Moves value from one card to another card of the same restaurant.
     *
     * @return array{source: TransactionResult, target: TransactionResult}
     */
    public function transfer(
        Actor $actor,
        GiftCard $source,
        GiftCard $target,
        ?int $amount = null,
        ?string $idempotencyKey = null,
        ?string $note = null,
    ): array {
        $this->assertOwnedByTenant($source);
        $this->assertOwnedByTenant($target);

        if ($source->getKey() === $target->getKey()) {
            throw new InvalidCardStateException('Source and target card must be different.');
        }
        if ($source->restaurant_id !== $target->restaurant_id) {
            throw new TenantMismatchException('Balances can only be transferred between cards of the same restaurant.');
        }

        if ($idempotencyKey !== null) {
            $existing = $this->findByKey($source->restaurant_id, $idempotencyKey);
            if ($existing !== null) {
                return $this->replayTransfer($existing, $source, $target, $idempotencyKey);
            }
        }

        try {
            return DB::transaction(function () use ($actor, $source, $target, $amount, $idempotencyKey, $note): array {
                // Lock in a deterministic order to avoid deadlocks between opposing transfers.
                [$first, $second] = strcmp($source->getKey(), $target->getKey()) < 0 ? [$source, $target] : [$target, $source];
                $lockedFirst = $this->lock($first);
                $lockedSecond = $this->lock($second);
                $from = $lockedFirst->getKey() === $source->getKey() ? $lockedFirst : $lockedSecond;
                $to = $lockedFirst->getKey() === $target->getKey() ? $lockedFirst : $lockedSecond;

                $settings = $this->settings();
                $this->assertTransferable($from, 'source');
                if (! in_array($from->status, [GiftCardStatus::Active, GiftCardStatus::Blocked], true)) {
                    // Inactive (not yet handed out) cards must be activated before their value can move.
                    throw new InvalidCardStateException('Only active or blocked cards can transfer their balance.', ['status' => $from->status->value]);
                }
                if (! in_array($to->status, [GiftCardStatus::Active, GiftCardStatus::Inactive, GiftCardStatus::Redeemed], true) || $to->isExpiredByDate()) {
                    throw new InvalidCardStateException('The target card cannot receive a balance.', ['status' => $to->status->value]);
                }

                $value = $amount ?? $from->balance;
                $this->assertPositive($value);
                if ($value > $from->balance) {
                    throw new InsufficientBalanceException('', ['balance' => $from->balance, 'requested' => $value]);
                }
                if ($to->balance + $value > $settings->max_card_balance) {
                    throw new BalanceLimitExceededException('', ['max_card_balance' => $settings->max_card_balance]);
                }

                $out = $this->record($from, TransactionType::TransferOut, -$value, $actor, $idempotencyKey, null, $note, counterparty: $to);
                $in = $this->record($to, TransactionType::TransferIn, $value, $actor, $idempotencyKey !== null ? $idempotencyKey.':in' : null, null, $note, $out, $from);

                if ($from->balance === 0 && $from->status === GiftCardStatus::Active) {
                    $from->status = GiftCardStatus::Redeemed;
                    $from->redeemed_at = Carbon::now();
                }
                if ($to->status === GiftCardStatus::Redeemed) {
                    $to->status = GiftCardStatus::Active;
                    $to->redeemed_at = null;
                }
                $from->save();
                $to->save();

                $this->audit->log('gift_card.balance_transferred', $actor, $from, null, [
                    'amount' => $value,
                    'target_card_id' => $to->getKey(),
                    'target_card_number' => $to->card_number,
                ], ['out_transaction_id' => $out->getKey(), 'in_transaction_id' => $in->getKey()]);

                return [
                    'source' => new TransactionResult($from, $out),
                    'target' => new TransactionResult($to, $in),
                ];
            }, self::DB_ATTEMPTS);
        } catch (UniqueConstraintViolationException $e) {
            $existing = $idempotencyKey !== null ? $this->findByKey($source->restaurant_id, $idempotencyKey) : null;
            if ($existing === null) {
                throw $e;
            }

            return $this->replayTransfer($existing, $source, $target, $idempotencyKey);
        }
    }

    /**
     * Replaces a lost / damaged card: issues a new card (new token, new number) carrying the
     * remaining balance, and permanently retires the old card.
     */
    /**
     * @return array{card: GiftCard, transaction: GiftCardTransaction|null} The new card and its transfer-in entry (null for zero balance)
     */
    public function replace(Actor $actor, GiftCard $card, string $reason, ?NfcTagType $tagType = null): array
    {
        $this->assertOwnedByTenant($card);
        $restaurant = $this->tenant->require();

        return DB::transaction(function () use ($actor, $card, $reason, $tagType, $restaurant): array {
            $old = $this->lock($card);
            $this->assertTransferable($old, 'card', allowZeroBalance: true);

            $new = new GiftCard;
            $new->forceFill([
                'restaurant_id' => $old->restaurant_id,
                'customer_id' => $old->customer_id,
                'public_token' => (string) Str::uuid(),
                'card_number' => $this->numbers->generate($restaurant),
                // A replacement never changes what the card may do: unsold (inactive) stays inactive.
                'status' => match (true) {
                    $old->activated_at === null => GiftCardStatus::Inactive,
                    $old->balance > 0 => GiftCardStatus::Active,
                    default => GiftCardStatus::Redeemed,
                },
                'currency' => $old->currency,
                'initial_value' => $old->balance,
                'balance' => 0,
                'total_loaded' => 0,
                'total_redeemed' => 0,
                'expires_at' => $old->expires_at,
                'activated_at' => $old->activated_at !== null ? Carbon::now() : null,
                'issued_by' => $actor->userId(),
                'recipient_name' => $old->recipient_name,
                'notes' => $old->notes,
                'replaces_id' => $old->getKey(),
                'nfc_tag_type' => $tagType ?? $old->nfc_tag_type,
            ])->save();

            $value = $old->balance;
            $in = null;
            if ($value > 0) {
                $out = $this->record($old, TransactionType::TransferOut, -$value, $actor, null, null, 'Replaced by '.CardNumber::format($new->card_number).': '.$reason, counterparty: $new);
                $in = $this->record($new, TransactionType::TransferIn, $value, $actor, null, null, 'Replacement for '.CardNumber::format($old->card_number), $out, $old);
            }

            $previousStatus = $old->status;
            $old->status = GiftCardStatus::Replaced;
            $old->replaced_by_id = $new->getKey();
            $old->blocked_reason = $reason;
            $old->save();
            $new->save();

            $this->audit->log('gift_card.replaced', $actor, $old, ['status' => $previousStatus], [
                'status' => GiftCardStatus::Replaced,
                'replaced_by_id' => $new->getKey(),
                'replaced_by_number' => $new->card_number,
                'transferred' => $value,
            ], ['reason' => $reason]);

            return ['card' => $new, 'transaction' => $in];
        }, self::DB_ATTEMPTS);
    }

    public function reverse(Actor $actor, GiftCardTransaction $transaction, string $reason): TransactionResult
    {
        if ($transaction->restaurant_id !== $this->tenant->id()) {
            throw new TenantMismatchException;
        }

        return DB::transaction(function () use ($actor, $transaction, $reason): TransactionResult {
            /** @var GiftCardTransaction $original */
            $original = GiftCardTransaction::query()->whereKey($transaction->getKey())->lockForUpdate()->firstOrFail();

            if (! $original->type->isReversible() || $original->isReversed()) {
                throw new TransactionNotReversibleException;
            }

            $card = $this->lock($original->giftCard);
            if (in_array($card->status, [GiftCardStatus::Replaced, GiftCardStatus::Expired], true)) {
                throw new TransactionNotReversibleException('Transactions of replaced or expired cards cannot be reversed.');
            }

            $delta = -$original->amount;
            if ($card->balance + $delta < 0) {
                throw new InsufficientBalanceException('The card balance is too low to reverse this reload.', ['balance' => $card->balance]);
            }

            $tx = $this->record($card, TransactionType::Reversal, $delta, $actor, null, null, $reason, $original);

            if ($original->type === TransactionType::Redemption) {
                $card->total_redeemed -= abs($original->amount);
                if ($card->status === GiftCardStatus::Redeemed && $card->balance > 0) {
                    $card->status = GiftCardStatus::Active;
                    $card->redeemed_at = null;
                }
            } else {
                $card->total_loaded -= $original->amount;
                if ($card->balance === 0 && $card->status === GiftCardStatus::Active) {
                    $card->status = GiftCardStatus::Redeemed;
                    $card->redeemed_at = Carbon::now();
                }
            }
            $card->save();

            $original->reversed_at = Carbon::now();
            $original->save();

            $this->audit->log('transaction.reversed', $actor, $original, null, [
                'reversal_transaction_id' => $tx->getKey(),
                'amount' => $delta,
                'balance' => $card->balance,
            ], ['reason' => $reason, 'gift_card_id' => $card->getKey()]);

            return new TransactionResult($card, $tx);
        }, self::DB_ATTEMPTS);
    }

    // ---------------------------------------------------------------------
    // Status changes
    // ---------------------------------------------------------------------

    public function block(Actor $actor, GiftCard $card, string $reason): GiftCard
    {
        return $this->mutate($card, function (GiftCard $locked) use ($actor, $reason): void {
            if (! in_array($locked->status, [GiftCardStatus::Active, GiftCardStatus::Inactive, GiftCardStatus::Redeemed], true)) {
                throw new InvalidCardStateException('This card cannot be blocked.', ['status' => $locked->status->value]);
            }

            $previous = $locked->status;
            $locked->status = GiftCardStatus::Blocked;
            $locked->blocked_at = Carbon::now();
            $locked->blocked_reason = $reason;
            $locked->save();

            $this->audit->log('gift_card.blocked', $actor, $locked, ['status' => $previous], ['status' => $locked->status], ['reason' => $reason]);
        });
    }

    public function unblock(Actor $actor, GiftCard $card): GiftCard
    {
        return $this->mutate($card, function (GiftCard $locked) use ($actor): void {
            if ($locked->status !== GiftCardStatus::Blocked) {
                throw new InvalidCardStateException('Only blocked cards can be unblocked.', ['status' => $locked->status->value]);
            }

            $locked->status = match (true) {
                $locked->activated_at === null => GiftCardStatus::Inactive,
                $locked->balance > 0 => GiftCardStatus::Active,
                default => GiftCardStatus::Redeemed,
            };
            $locked->blocked_at = null;
            $locked->blocked_reason = null;
            $locked->save();

            $this->audit->log('gift_card.unblocked', $actor, $locked, ['status' => GiftCardStatus::Blocked], ['status' => $locked->status]);
        });
    }

    /**
     * Expires a card: the remaining balance is written off with an expiration ledger entry.
     */
    public function expire(Actor $actor, GiftCard $card, ?string $reason = null): GiftCard
    {
        return $this->mutate($card, function (GiftCard $locked) use ($actor, $reason): void {
            if ($locked->status->isTerminal()) {
                throw new InvalidCardStateException('This card is already closed.', ['status' => $locked->status->value]);
            }

            $previous = $locked->status;
            $writtenOff = $locked->balance;
            if ($writtenOff > 0) {
                $this->record($locked, TransactionType::Expiration, -$writtenOff, $actor, null, null, $reason ?? 'Card expired');
            }

            $locked->status = GiftCardStatus::Expired;
            $locked->expired_at = Carbon::now();
            $locked->save();

            $this->audit->log('gift_card.expired', $actor, $locked, ['status' => $previous, 'balance' => $writtenOff], [
                'status' => GiftCardStatus::Expired,
                'balance' => 0,
            ], ['reason' => $reason ?? 'expiration_date_reached']);
        });
    }

    /**
     * @param  array{customer_id?: string|null, recipient_name?: string|null, notes?: string|null, expires_at?: string|null}  $attributes
     */
    public function update(Actor $actor, GiftCard $card, array $attributes): GiftCard
    {
        return $this->mutate($card, function (GiftCard $locked) use ($actor, $attributes): void {
            if (array_key_exists('expires_at', $attributes)) {
                if ($locked->status->isTerminal()) {
                    throw new InvalidCardStateException('The expiration date of a closed card cannot be changed.');
                }
                $attributes['expires_at'] = $attributes['expires_at'] !== null
                    ? $this->endOfDay($attributes['expires_at'], $this->tenant->require())
                    : null;
            }

            $locked->fill($attributes);
            $dirty = $locked->getDirty();
            if ($dirty === []) {
                return;
            }

            $old = array_intersect_key($locked->getOriginal(), $dirty);
            $locked->save();

            $this->audit->log('gift_card.updated', $actor, $locked, $old, $dirty);
        });
    }

    /**
     * Records that the card's URL has been written to a physical NFC tag and binds the chip UID.
     */
    /**
     * Records the physical tag of a card. A chip UID is only ever stored together with `$verified`: the
     * dashboard wrote the tag, read it back and the URL matched ({@see NfcProgrammingService}). The UNIQUE
     * index on `gift_cards.nfc_uid_active` guarantees platform-wide that one chip belongs to at most one
     * usable card, also when two programming stations race.
     */
    public function bindNfcTag(Actor $actor, GiftCard $card, NfcTagType $tagType, ?string $uid, bool $locked, bool $verified = false, bool $onlyIfUnprogrammed = false): GiftCard
    {
        $uid = $uid !== null ? NfcUid::normalize($uid) : null;

        if ($uid !== null && ! $verified) {
            throw new NfcVerificationFailedException('A chip serial number can only be saved after the tag was read back and verified.');
        }

        try {
            return $this->mutate($card, function (GiftCard $row) use ($actor, $tagType, $uid, $locked, $verified, $onlyIfUnprogrammed): void {
                if ($row->status->isTerminal()) {
                    throw new InvalidCardStateException('Tags cannot be written for closed cards.');
                }
                // Checked under the row lock: two programming stations never both program one card.
                if ($onlyIfUnprogrammed && $row->nfc_written_at !== null && ($uid === null || $row->nfc_uid !== $uid)) {
                    throw new NfcCardAlreadyProgrammedException;
                }

                if ($uid !== null) {
                    $this->assertChipAvailable($row, $uid);
                }

                $old = [
                    'nfc_uid' => $row->nfc_uid,
                    'nfc_tag_type' => $row->nfc_tag_type,
                    'nfc_locked' => $row->nfc_locked,
                    'nfc_verified_at' => $row->nfc_verified_at?->toIso8601String(),
                ];
                $sameChip = $uid !== null && $uid === $row->nfc_uid;
                $row->nfc_tag_type = $tagType;
                // Re-provisioning the same NTAG 424 chip must never reset its replay counter:
                // otherwise previously captured SUN URLs would become valid again.
                $row->nfc_uid = $uid ?? ($tagType === NfcTagType::Ntag424Dna ? $row->nfc_uid : null);
                $row->nfc_written_at = Carbon::now();
                $row->nfc_verified_at = $verified ? Carbon::now() : null;
                $row->nfc_locked = $locked;
                if (! $sameChip && $row->nfc_uid !== $old['nfc_uid']) {
                    $row->nfc_read_counter = null;
                }
                $row->save();

                $this->audit->log('gift_card.nfc_written', $actor, $row, $old, [
                    'nfc_uid' => $uid,
                    'nfc_tag_type' => $tagType,
                    'nfc_locked' => $locked,
                    'verified' => $verified,
                ]);
            });
        } catch (UniqueConstraintViolationException) {
            // Lost a race against another station binding the same chip in the same instant.
            throw new NfcTagInUseException;
        }
    }

    /**
     * Marks the verified tag of a card as permanently read-only after the dashboard locked it.
     */
    public function markNfcLocked(Actor $actor, GiftCard $card, string $uid): GiftCard
    {
        $uid = NfcUid::normalize($uid);

        return $this->mutate($card, function (GiftCard $row) use ($actor, $uid): void {
            if ($row->nfc_uid !== $uid || $row->nfc_verified_at === null) {
                throw new InvalidCardStateException('Only the verified tag of this card can be marked as locked.');
            }
            if ($row->nfc_locked) {
                return;
            }

            $row->nfc_locked = true;
            $row->save();

            $this->audit->log('gift_card.nfc_locked', $actor, $row, ['nfc_locked' => false], ['nfc_locked' => true], ['uid' => $uid]);
        });
    }

    /**
     * Throws when the chip is linked to another usable card — in this or in another restaurant.
     * The other restaurant's card is never disclosed.
     */
    private function assertChipAvailable(GiftCard $card, string $uid): void
    {
        $owner = GiftCard::query()->withoutGlobalScopes()
            ->where('nfc_uid_active', $uid)
            ->whereKeyNot($card->getKey())
            ->first(['id', 'restaurant_id', 'card_number']);

        if ($owner === null) {
            return;
        }

        if ($owner->restaurant_id !== $card->restaurant_id) {
            throw new NfcTagInUseException('This NFC tag is linked to a card of another business.');
        }

        throw new NfcTagInUseException('This NFC tag is already linked to another active card.', [
            'card_id' => $owner->id,
            'card_number' => $owner->card_number,
        ]);
    }

    /**
     * Expires every card whose expiration date has passed. Runs from the scheduler, per restaurant.
     */
    public function expireDueCards(Restaurant $restaurant, ?Carbon $now = null): int
    {
        $count = 0;

        $this->tenant->runAs($restaurant, function () use (&$count, $now): void {
            GiftCard::query()
                ->whereNotIn('status', [GiftCardStatus::Expired->value, GiftCardStatus::Replaced->value])
                ->whereNotNull('expires_at')
                ->where('expires_at', '<=', $now ?? Carbon::now())
                ->orderBy('id')
                ->chunkById(200, function ($cards) use (&$count): void {
                    foreach ($cards as $card) {
                        /** @var GiftCard $card */
                        try {
                            $this->expire(Actor::system(), $card, 'Expiration date reached');
                            $count++;
                        } catch (InvalidCardStateException) {
                            // Closed concurrently (e.g. replaced a moment ago) — nothing left to expire.
                        } catch (\Throwable $e) {
                            // One broken card must never stop the nightly run for everybody else.
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

    /**
     * @param  Closure(GiftCard): void  $callback
     */
    private function mutate(GiftCard $card, Closure $callback): GiftCard
    {
        $this->assertOwnedByTenant($card);

        return DB::transaction(function () use ($card, $callback): GiftCard {
            $locked = $this->lock($card);
            $callback($locked);

            return $locked;
        }, self::DB_ATTEMPTS);
    }

    /**
     * Converts a calendar day (Y-m-d) into the last second of that day in the restaurant's timezone, stored in UTC.
     */
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

    private function lock(GiftCard $card): GiftCard
    {
        /** @var GiftCard */
        return GiftCard::query()->whereKey($card->getKey())->lockForUpdate()->firstOrFail();
    }

    /**
     * Applies a signed amount to the (locked) card and writes the ledger entry. The caller saves the card.
     */
    private function record(
        GiftCard $card,
        TransactionType $type,
        int $amount,
        Actor $actor,
        ?string $idempotencyKey = null,
        ?string $reference = null,
        ?string $note = null,
        ?GiftCardTransaction $related = null,
        ?GiftCard $counterparty = null,
    ): GiftCardTransaction {
        $before = $card->balance;
        $after = $before + $amount;

        if ($after < 0) {
            throw new InsufficientBalanceException('', ['balance' => $before]);
        }

        $card->balance = $after;

        $tx = new GiftCardTransaction;
        $tx->forceFill([
            'restaurant_id' => $card->restaurant_id,
            'gift_card_id' => $card->getKey(),
            'type' => $type,
            'amount' => $amount,
            'balance_before' => $before,
            'balance_after' => $after,
            'currency' => $card->currency,
            'idempotency_key' => $idempotencyKey,
            'reference' => $reference,
            'note' => $note,
            'user_id' => $actor->userId(),
            'device_id' => $actor->deviceId(),
            'related_transaction_id' => $related?->getKey(),
            'counterparty_card_id' => $counterparty?->getKey(),
            'ip_address' => $actor->ipAddress,
            'created_at' => Carbon::now(),
        ])->save();

        return $tx;
    }

    /**
     * @param  Closure(GiftCardTransaction): bool  $matches
     * @param  Closure(): TransactionResult  $operation
     */
    private function idempotent(string $restaurantId, ?string $key, Closure $matches, Closure $operation): TransactionResult
    {
        if ($key !== null) {
            $existing = $this->findByKey($restaurantId, $key);
            if ($existing !== null) {
                return $this->replay($existing, $matches);
            }
        }

        try {
            return DB::transaction($operation, self::DB_ATTEMPTS);
        } catch (UniqueConstraintViolationException $e) {
            // A concurrent request with the same idempotency key won the race.
            $existing = $key !== null ? $this->findByKey($restaurantId, $key) : null;
            if ($existing === null) {
                throw $e;
            }

            return $this->replay($existing, $matches);
        }
    }

    /**
     * @param  Closure(GiftCardTransaction): bool  $matches
     */
    private function replay(GiftCardTransaction $existing, Closure $matches): TransactionResult
    {
        if (! $matches($existing)) {
            throw new IdempotencyConflictException;
        }

        /** @var GiftCard $card */
        $card = GiftCard::query()->findOrFail($existing->gift_card_id);

        return new TransactionResult($card, $existing, replayed: true);
    }

    /**
     * @return array{source: TransactionResult, target: TransactionResult}
     */
    private function replayTransfer(GiftCardTransaction $out, GiftCard $source, GiftCard $target, string $key): array
    {
        if ($out->type !== TransactionType::TransferOut || $out->gift_card_id !== $source->getKey() || $out->counterparty_card_id !== $target->getKey()) {
            throw new IdempotencyConflictException;
        }

        $in = $this->findByKey($source->restaurant_id, $key.':in') ?? throw new IdempotencyConflictException;

        return [
            'source' => new TransactionResult($source->refresh(), $out, true),
            'target' => new TransactionResult($target->refresh(), $in, true),
        ];
    }

    private function findByKey(string $restaurantId, string $key): ?GiftCardTransaction
    {
        /** @var GiftCardTransaction|null */
        return GiftCardTransaction::query()
            ->forRestaurant($restaurantId)
            ->where('idempotency_key', $key)
            ->first();
    }

    private function settings(): RestaurantSetting
    {
        return $this->tenant->require()->settings;
    }

    private function assertOwnedByTenant(GiftCard $card): void
    {
        if ($card->restaurant_id !== $this->tenant->require()->getKey()) {
            throw new TenantMismatchException;
        }
    }

    private function assertRedeemable(GiftCard $card): void
    {
        match (true) {
            $card->status === GiftCardStatus::Blocked => throw new CardBlockedException,
            $card->status === GiftCardStatus::Expired, $card->isExpiredByDate() => throw new CardExpiredException,
            $card->status !== GiftCardStatus::Active => throw new CardNotRedeemableException('', ['status' => $card->status->value]),
            default => null,
        };
    }

    private function assertTransferable(GiftCard $card, string $label, bool $allowZeroBalance = false): void
    {
        if ($card->status->isTerminal()) {
            throw new InvalidCardStateException("The {$label} card is already closed.", ['status' => $card->status->value]);
        }
        if ($card->isExpiredByDate()) {
            throw new CardExpiredException;
        }
        if (! $allowZeroBalance && $card->balance === 0) {
            throw new InsufficientBalanceException("The {$label} card has no balance.", ['balance' => 0]);
        }
    }

    private function assertVelocity(GiftCard $card, RestaurantSetting $settings): void
    {
        if ($settings->max_redemptions_per_card_per_hour <= 0) {
            return;
        }

        $window = GiftCardTransaction::query()
            ->where('gift_card_id', $card->getKey())
            ->where('type', TransactionType::Redemption->value)
            ->whereNull('reversed_at')
            ->where('created_at', '>=', Carbon::now()->subHour());

        $recent = (clone $window)->count();
        $limit = $settings->max_redemptions_per_card_per_hour;

        if ($recent >= $limit) {
            // A slot frees when the redemption that must drop out of the one-hour window reaches its age.
            /** @var GiftCardTransaction|null $blocking */
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
