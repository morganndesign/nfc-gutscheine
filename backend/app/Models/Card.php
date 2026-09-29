<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\CardState;
use App\Models\Concerns\BelongsToRestaurant;
use App\Services\Cards\CardLifecycle;
use Illuminate\Database\Eloquent\Concerns\HasVersion4Uuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;
use LogicException;

/**
 * A physical NTAG 424 DNA card (architecture §5.2, §7). Owns its UID, batch, key set and lifecycle state; never
 * money, customer or expiry (the voucher owns those).
 *
 * - `id` is a version 4 UUID and, like `uid`, is never serialised to any client (decision 27).
 * - `state` is written only by {@see CardLifecycle}; any other write fails.
 *
 * @property string $id
 * @property string $card_number
 * @property string $uid 7 raw bytes
 * @property string $chip_type
 * @property string $batch_id
 * @property string $key_set_id
 * @property string $restaurant_id
 * @property CardState $state
 * @property Carbon $state_changed_at
 * @property int|null $sdm_counter
 * @property string|null $originality_signature
 * @property string|null $successor_card_id
 * @property-read CardBatch $batch
 * @property-read KeySet $keySet
 */
class Card extends Model
{
    use BelongsToRestaurant;
    use HasVersion4Uuids;

    /** Never leaves the server. */
    protected $hidden = ['id', 'uid', 'originality_signature', 'key_set_id', 'successor_card_id', 'batch_id'];

    protected $guarded = ['id', 'state', 'state_changed_at', 'sdm_counter'];

    protected static function booted(): void
    {
        static::saving(static function (self $card): void {
            if ($card->isDirty('state') && ! CardLifecycle::isWriting()) {
                throw new LogicException('A card state changes only through CardLifecycle.');
            }
        });
    }

    protected function casts(): array
    {
        return [
            'state' => CardState::class,
            'state_changed_at' => 'immutable_datetime',
            'sdm_counter' => 'integer',
        ];
    }

    /** @return BelongsTo<CardBatch, $this> */
    public function batch(): BelongsTo
    {
        return $this->belongsTo(CardBatch::class, 'batch_id');
    }

    /** @return BelongsTo<KeySet, $this> */
    public function keySet(): BelongsTo
    {
        return $this->belongsTo(KeySet::class);
    }

    public function uidHex(): string
    {
        return strtoupper(bin2hex($this->uid));
    }
}
