<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\TransactionType;
use App\Models\Concerns\BelongsToRestaurant;
use App\Models\Concerns\Immutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Immutable ledger entry. Balance history of a card is fully reconstructable from these rows:
 * sum(amount) over all transactions of a card === card.balance.
 *
 * @property string $id
 * @property string $restaurant_id
 * @property string $gift_card_id
 * @property TransactionType $type
 * @property int $amount
 * @property int $balance_before
 * @property int $balance_after
 * @property string $currency
 * @property string|null $idempotency_key
 * @property string|null $reference
 * @property string|null $note
 * @property string|null $user_id
 * @property string|null $device_id
 * @property string|null $related_transaction_id
 * @property string|null $counterparty_card_id
 * @property Carbon|null $reversed_at
 * @property string|null $ip_address
 * @property Carbon $created_at
 * @property-read GiftCard $giftCard
 * @property-read User|null $user
 * @property-read Device|null $device
 */
class GiftCardTransaction extends Model
{
    use BelongsToRestaurant;
    use HasUuids;
    use Immutable;

    public const UPDATED_AT = null;

    /** @var list<string> */
    public array $mutableAfterCreate = ['reversed_at'];

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'type' => TransactionType::class,
            'amount' => 'integer',
            'balance_before' => 'integer',
            'balance_after' => 'integer',
            'reversed_at' => 'datetime',
            'created_at' => 'datetime',
        ];
    }

    public function isReversed(): bool
    {
        return $this->reversed_at !== null;
    }

    /** @return BelongsTo<GiftCard, $this> */
    public function giftCard(): BelongsTo
    {
        return $this->belongsTo(GiftCard::class)->withTrashed();
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

    /** @return BelongsTo<GiftCardTransaction, $this> */
    public function relatedTransaction(): BelongsTo
    {
        return $this->belongsTo(self::class, 'related_transaction_id');
    }

    /** @return BelongsTo<GiftCard, $this> */
    public function counterpartyCard(): BelongsTo
    {
        return $this->belongsTo(GiftCard::class, 'counterparty_card_id')->withTrashed();
    }

    /**
     * @param  Builder<GiftCardTransaction>  $query
     * @return Builder<GiftCardTransaction>
     */
    public function scopeOfType(Builder $query, TransactionType ...$types): Builder
    {
        return $query->whereIn('type', array_map(static fn (TransactionType $t): string => $t->value, $types));
    }
}
