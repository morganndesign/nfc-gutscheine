<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\Customer;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Customer
 */
final class CustomerResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var Customer $customer */
        $customer = $this->resource;

        return [
            'id' => $customer->id,
            'first_name' => $customer->first_name,
            'last_name' => $customer->last_name,
            'full_name' => $customer->full_name,
            'email' => $customer->email,
            'phone' => $customer->phone,
            'notes' => $customer->notes,
            'marketing_consent' => $customer->marketing_consent,
            'anonymized' => $customer->anonymized_at !== null,
            'gift_cards_count' => $this->whenCounted('giftCards'),
            'gift_cards_balance' => $this->whenAggregated('giftCards', 'balance', 'sum', static fn ($v): int => (int) $v),
            'created_at' => $customer->created_at->toIso8601String(),
        ];
    }
}
