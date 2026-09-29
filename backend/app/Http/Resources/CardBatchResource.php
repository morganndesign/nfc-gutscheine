<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\CardBatch;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A card batch with its counts computed from the cards. The platform view adds production details.
 *
 * @mixin CardBatch
 */
final class CardBatchResource extends JsonResource
{
    public bool $platform = false;

    public function forPlatform(): self
    {
        $this->platform = true;

        return $this;
    }

    /** @return array<array-key, mixed> */
    public function toArray(Request $request): array
    {
        /** @var CardBatch $batch */
        $batch = $this->resource;

        return [
            'id' => $batch->id,
            'batch_code' => $batch->batch_code,
            'status' => $batch->status->value,
            'quantity_ordered' => $batch->quantity_ordered,
            'counts' => $batch->counts(),
            'card_design_ref' => $batch->card_design_ref,
            'ordered_at' => $batch->ordered_at?->toIso8601String(),
            'shipped_at' => $batch->shipped_at?->toIso8601String(),
            'delivered_at' => $batch->delivered_at?->toIso8601String(),
            'received_at' => $batch->received_at?->toIso8601String(),
            'tracking_ref' => $batch->tracking_ref,
            $this->mergeWhen($this->platform, fn (): array => [
                'restaurant' => ['id' => $batch->restaurant_id, 'name' => $batch->restaurant->name],
                'key_set' => $batch->keySet->version,
                'manufacturer' => $batch->manufacturer,
                'accepted_at' => $batch->accepted_at?->toIso8601String(),
                'approvals' => array_values(array_filter([$batch->accepted_by, $batch->accepted_second_by])),
                'qa_report' => $batch->qa_report,
            ]),
        ];
    }
}
