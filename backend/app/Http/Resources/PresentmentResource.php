<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\Presentment;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Presentment
 */
final class PresentmentResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var Presentment $presentment */
        $presentment = $this->resource;

        return [
            'id' => $presentment->id,
            'purpose' => $presentment->purpose->value,
            'method' => $presentment->method->value,
            'level' => $presentment->level,
            'expires_at' => $presentment->expires_at->toIso8601String(),
            // Seconds left as seen by the server: clients count down from receipt, independent of their clock.
            'expires_in' => max(0, (int) floor(now()->diffInSeconds($presentment->expires_at, false))),
            // Null for a card presented before it pays for a voucher (receive, bind).
            'voucher' => $presentment->voucher !== null ? PresentedVoucherResource::make($presentment->voucher)->resolve($request) : null,
            // A physical card: its inventory number and state, for staff. Never its id or UID.
            'card' => $presentment->card !== null ? [
                'card_number' => $presentment->card->card_number,
                'state' => $presentment->card->state->value,
            ] : null,
        ];
    }
}
