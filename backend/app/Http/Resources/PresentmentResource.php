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
            'voucher' => PresentedVoucherResource::make($presentment->voucher)->resolve($request),
        ];
    }
}
