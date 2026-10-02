<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\CardBatchStatus;
use App\Enums\CardState;
use App\Models\Concerns\BelongsToRestaurant;
use App\Services\Cards\CardBatchLifecycle;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;

/**
 * One restaurant order = one print run = one shipment (architecture §8.1). Its status changes move its cards
 * ({@see CardBatchLifecycle}). Cards are generic: the artwork (`card_design_ref`) is restaurant branding only,
 * never an amount, voucher number or QR code; a card's value is assigned at activation. The batch code is never on
 * a card or in its URL.
 *
 * @property string $id
 * @property string $batch_code
 * @property string $restaurant_id
 * @property string $key_set_id
 * @property string $manufacturer
 * @property string $chip_type
 * @property string|null $card_design_ref
 * @property int $quantity_ordered
 * @property CardBatchStatus $status
 * @property Carbon|null $accepted_at
 * @property Carbon|null $ordered_at
 * @property Carbon|null $personalized_at
 * @property Carbon|null $shipped_at
 * @property Carbon|null $delivered_at
 * @property Carbon|null $received_at
 * @property string|null $tracking_ref
 * @property array<string, mixed>|null $qa_report
 * @property string|null $accepted_by
 * @property string|null $received_by
 * @property-read KeySet $keySet
 * @property-read Restaurant $restaurant
 */
class CardBatch extends Model
{
    use BelongsToRestaurant;
    use HasUuids;

    protected $guarded = ['id', 'status'];

    protected function casts(): array
    {
        return [
            'status' => CardBatchStatus::class,
            'quantity_ordered' => 'integer',
            'production_date' => 'date',
            'ordered_at' => 'datetime',
            'personalized_at' => 'datetime',
            'accepted_at' => 'datetime',
            'shipped_at' => 'datetime',
            'delivered_at' => 'datetime',
            'received_at' => 'datetime',
            'qa_report' => 'array',
        ];
    }

    /** @return BelongsTo<KeySet, $this> */
    public function keySet(): BelongsTo
    {
        return $this->belongsTo(KeySet::class);
    }

    /** @return HasMany<Card, $this> */
    public function cards(): HasMany
    {
        return $this->hasMany(Card::class, 'batch_id');
    }

    /** Count buckets over card states (architecture §8.3). */
    public const BUCKETS = [
        'in_production' => [CardState::Manufactured, CardState::Personalized],
        'qa_failed' => [CardState::QaFailed],
        'central_stock' => [CardState::QaPassed, CardState::InInventory, CardState::Assigned],
        'in_transit' => [CardState::Shipped, CardState::Delivered],
        'available' => [CardState::Available],
        'activated' => [CardState::Bound, CardState::Active, CardState::Suspended],
        'replaced' => [CardState::Replaced],
        'revoked' => [CardState::Revoked],
        'lost' => [CardState::Lost],
        'destroyed' => [CardState::Destroyed],
    ];

    /**
     * The counts, always computed from the cards (never stored): one indexed GROUP BY (batch_id, state).
     *
     * @return array<string, int> bucket => cards, plus `registered`
     */
    public function counts(): array
    {
        /** @var array<string, int> $byState */
        $byState = Card::query()->withoutGlobalScopes()
            ->where('batch_id', $this->getKey())
            ->groupBy('state')
            ->selectRaw('state, COUNT(*) AS cards')
            ->pluck('cards', 'state')
            ->map(static fn (mixed $n): int => (int) $n)
            ->all();

        $counts = [];
        foreach (self::BUCKETS as $bucket => $states) {
            $counts[$bucket] = array_sum(array_map(static fn (CardState $s): int => $byState[$s->value] ?? 0, $states));
        }
        $counts['registered'] = array_sum($byState);

        return $counts;
    }
}
