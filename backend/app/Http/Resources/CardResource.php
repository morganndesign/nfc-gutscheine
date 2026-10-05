<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\Card;
use App\Models\CardBatch;
use App\Models\Medium;
use App\Models\Voucher;
use App\Services\Cards\CardService;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A physical card as staff see it: inventory number and lifecycle, never its id, UID or keys. `voucher` is the
 * voucher the card currently pays for.
 *
 * @mixin Card
 */
final class CardResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var Card $card */
        $card = $this->resource;
        /** @var CardBatch|null $batch */
        $batch = $card->relationLoaded('batch') ? $card->batch : null;

        return [
            'card_number' => $card->card_number,
            'state' => $card->state->value,
            'state_changed_at' => $card->state_changed_at->toIso8601String(),
            'batch_code' => $batch?->batch_code,
            'voucher' => $this->when($card->relationLoaded('activeMedium'), function () use ($card): ?array {
                /** @var Medium|null $medium */
                $medium = $card->getRelation('activeMedium');
                /** @var Voucher|null $voucher */
                $voucher = $medium?->voucher;

                return $voucher !== null ? [
                    'id' => $voucher->id,
                    'voucher_number' => $voucher->voucher_number,
                    'status' => $voucher->status->value,
                    // Past its end date but not yet marked by the nightly job: shown as expired (audit K11).
                    'is_expired' => $voucher->isExpiredByDate(),
                    'balance' => $voucher->balance,
                    'currency' => $voucher->currency,
                ] : null;
            }),
            'successor' => $card->successor?->card_number,
            // A suspended card from a compromised batch is replaced, never resumed (audit K6).
            'resumable' => $card->state->value === 'suspended' ? CardService::resumable($card) : null,
        ];
    }
}
