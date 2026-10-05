<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\CardOrderStatus;
use App\Models\Concerns\BelongsToRestaurant;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * @property string $id
 * @property string $restaurant_id
 * @property string|null $requested_by
 * @property int $quantity
 * @property string|null $note
 * @property CardOrderStatus $status
 * @property string|null $card_batch_id
 * @property string|null $idempotency_key A repeated request (lost answer) returns this order (audit K5)
 * @property string|null $decided_by
 * @property Carbon|null $decided_at
 * @property string|null $decline_reason
 * @property Carbon $created_at
 * @property-read Restaurant $restaurant
 * @property-read User|null $requester
 * @property-read CardBatch|null $batch
 */
class CardOrder extends Model
{
    use BelongsToRestaurant;
    use HasUuids;

    protected $fillable = ['quantity', 'note'];

    protected function casts(): array
    {
        return [
            'quantity' => 'integer',
            'status' => CardOrderStatus::class,
            'decided_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<Restaurant, $this> */
    public function restaurant(): BelongsTo
    {
        return $this->belongsTo(Restaurant::class);
    }

    /** @return BelongsTo<User, $this> */
    public function requester(): BelongsTo
    {
        return $this->belongsTo(User::class, 'requested_by');
    }

    /** @return BelongsTo<CardBatch, $this> */
    public function batch(): BelongsTo
    {
        return $this->belongsTo(CardBatch::class, 'card_batch_id')->withoutGlobalScopes();
    }
}
