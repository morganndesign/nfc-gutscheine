<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\NfcWriteAttempt;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin NfcWriteAttempt
 */
final class NfcWriteAttemptResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var NfcWriteAttempt $a */
        $a = $this->resource;

        return [
            'id' => $a->id,
            'attempt_id' => $a->attempt_id,
            'gift_card_id' => $a->gift_card_id,
            'method' => $a->method->value,
            'stage' => $a->stage->value,
            'result' => $a->result->value,
            'error_code' => $a->error_code,
            'error_message' => $a->error_message,
            'uid' => $a->uid,
            'tag_type' => $a->tag_type?->value,
            'locked' => $a->locked,
            'timings' => [
                'detect_ms' => $a->detect_ms,
                'write_ms' => $a->write_ms,
                'verify_ms' => $a->verify_ms,
                'total_ms' => $a->total_ms,
            ],
            'user' => $this->whenLoaded('user', static fn () => $a->user !== null ? ['id' => $a->user->id, 'name' => $a->user->name] : null),
            'created_at' => $a->created_at->toIso8601String(),
            'completed_at' => $a->completed_at?->toIso8601String(),
        ];
    }
}
