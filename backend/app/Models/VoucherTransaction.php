<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\Permission;
use App\Enums\TransactionType;
use App\Enums\VoucherStatus;
use App\Models\Concerns\BelongsToRestaurant;
use App\Models\Concerns\HashChained;
use App\Models\Concerns\Immutable;
use App\Models\Contracts\HashChainedRecord;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Carbon;

/**
 * Ledger entry: append-only and hash-chained per restaurant. A voucher's balance is always the sum of its
 * entries, and every row satisfies balance_after = balance_before + amount.
 *
 * "Reversed" is derived from the reversal entry that points at this one; nothing on this row ever changes.
 *
 * @property string $id
 * @property string $restaurant_id
 * @property string $voucher_id
 * @property TransactionType $type
 * @property int $amount
 * @property int $balance_before
 * @property int $balance_after
 * @property string $currency
 * @property string|null $idempotency_key
 * @property string|null $presentment_id
 * @property string|null $payment_id
 * @property string|null $related_transaction_id
 * @property string|null $reference
 * @property string|null $note
 * @property string|null $user_id
 * @property string|null $device_id
 * @property string|null $ip_address
 * @property Carbon $created_at
 * @property string $chain_scope
 * @property int $chain_seq
 * @property string $prev_hash
 * @property string $entry_hash
 * @property-read Voucher $voucher
 * @property-read User|null $user
 * @property-read Device|null $device
 * @property-read Payment|null $payment
 * @property-read VoucherTransaction|null $reversal
 */
class VoucherTransaction extends Model implements HashChainedRecord
{
    use BelongsToRestaurant;
    use HashChained;
    use HasUuids;
    use Immutable;

    public const UPDATED_AT = null;

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'type' => TransactionType::class,
            'amount' => 'integer',
            'balance_before' => 'integer',
            'balance_after' => 'integer',
            'chain_seq' => 'integer',
            'created_at' => 'datetime',
        ];
    }

    public static function chainName(): string
    {
        return 'voucher_transactions';
    }

    public function chainAttributes(): array
    {
        return [
            'id', 'restaurant_id', 'voucher_id', 'type', 'amount', 'balance_before', 'balance_after', 'currency',
            'idempotency_key', 'presentment_id', 'payment_id', 'related_transaction_id', 'reference', 'note',
            'user_id', 'device_id', 'ip_address', 'created_at',
        ];
    }

    public function isReversed(): bool
    {
        return $this->relationLoaded('reversal')
            ? $this->reversal !== null
            : $this->reversal()->exists();
    }

    /** A redemption or reload not yet reversed, of a voucher that is still open (a refund closes it for good). */
    public function isReversible(): bool
    {
        return $this->type->isReversible() && ! $this->isReversed() && $this->voucher->status !== VoucherStatus::Refunded;
    }

    /**
     * Whether [viewer] may reverse this entry: reversible at all, and a reload they booked themselves only with the
     * right to reverse their own reloads (four eyes).
     */
    public function isReversibleBy(?User $viewer): bool
    {
        if (! $this->isReversible() || $viewer === null || ! $viewer->hasPermission(Permission::TransactionsReverse)) {
            return false;
        }

        return ! ($this->type === TransactionType::Reload && $this->user_id === $viewer->getKey()
            && ! $viewer->hasPermission(Permission::TransactionsReverseOwnReload));
    }

    /** @return BelongsTo<Voucher, $this> */
    public function voucher(): BelongsTo
    {
        return $this->belongsTo(Voucher::class);
    }

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class)->withTrashed();
    }

    /** @return BelongsTo<Device, $this> */
    public function device(): BelongsTo
    {
        return $this->belongsTo(Device::class)->withTrashed();
    }

    /** @return BelongsTo<Payment, $this> */
    public function payment(): BelongsTo
    {
        return $this->belongsTo(Payment::class);
    }

    /** @return BelongsTo<VoucherTransaction, $this> */
    public function relatedTransaction(): BelongsTo
    {
        return $this->belongsTo(self::class, 'related_transaction_id');
    }

    /**
     * The reversal of this entry, if any (at most one: UNIQUE related_transaction_id).
     *
     * @return HasOne<VoucherTransaction, $this>
     */
    public function reversal(): HasOne
    {
        return $this->hasOne(self::class, 'related_transaction_id');
    }

    /**
     * @param  Builder<VoucherTransaction>  $query
     * @return Builder<VoucherTransaction>
     */
    public function scopeOfType(Builder $query, TransactionType ...$types): Builder
    {
        return $query->whereIn('type', array_map(static fn (TransactionType $t): string => $t->value, $types));
    }

    /**
     * Entries that have not been corrected by a reversal.
     *
     * @param  Builder<VoucherTransaction>  $query
     * @return Builder<VoucherTransaction>
     */
    public function scopeNotReversed(Builder $query): Builder
    {
        return $query->whereDoesntHave('reversal');
    }
}
