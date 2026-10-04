<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\CardOrder;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A restaurant's card order; the platform view adds the restaurant.
 *
 * @mixin CardOrder
 */
final class CardOrderResource extends JsonResource
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
        /** @var CardOrder $order */
        $order = $this->resource;

        return [
            'id' => $order->id,
            'quantity' => $order->quantity,
            'note' => $order->note,
            'status' => $order->status->value,
            'requested_by' => $order->requester?->name,
            'created_at' => $order->created_at->toIso8601String(),
            'decided_at' => $order->decided_at?->toIso8601String(),
            'decline_reason' => $order->decline_reason,
            'batch_code' => $order->batch?->batch_code,
            $this->mergeWhen($this->platform, fn (): array => [
                'restaurant' => ['id' => $order->restaurant_id, 'name' => $order->restaurant->name],
            ]),
        ];
    }
}
