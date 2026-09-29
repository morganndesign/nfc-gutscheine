<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\Restaurant;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Restaurant
 */
final class RestaurantResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var Restaurant $restaurant */
        $restaurant = $this->resource;

        return [
            'id' => $restaurant->id,
            'name' => $restaurant->name,
            'slug' => $restaurant->slug,
            'legal_name' => $restaurant->legal_name,
            'vat_number' => $restaurant->vat_number,
            'email' => $restaurant->email,
            'phone' => $restaurant->phone,
            'website' => $restaurant->website,
            'address_line1' => $restaurant->address_line1,
            'address_line2' => $restaurant->address_line2,
            'postal_code' => $restaurant->postal_code,
            'city' => $restaurant->city,
            'country' => $restaurant->country,
            'currency' => $restaurant->currency,
            'timezone' => $restaurant->timezone,
            'locale' => $restaurant->locale,
            'status' => $restaurant->status->value,
            'plan' => $restaurant->plan,
            'suspended_at' => $restaurant->suspended_at?->toIso8601String(),
            'suspension_reason' => $restaurant->suspension_reason,
            'settings' => RestaurantSettingsResource::make($this->whenLoaded('settings')),
            'users_count' => $this->whenCounted('users'),
            'vouchers_count' => $this->whenCounted('vouchers'),
            'outstanding_balance' => $this->when(isset($restaurant->outstanding_balance), static fn (): int => (int) $restaurant->getAttribute('outstanding_balance')),
            'archived_at' => $restaurant->deleted_at?->toIso8601String(),
            'owner' => $this->whenLoaded('owner', static fn (): ?array => $restaurant->owner === null ? null : [
                'id' => $restaurant->owner->id,
                'name' => $restaurant->owner->name,
                'email' => $restaurant->owner->email,
                'status' => $restaurant->owner->status->value,
                'last_login_at' => $restaurant->owner->last_login_at?->toIso8601String(),
                'invitation' => $restaurant->owner->invitationSummary,
            ]),
            'created_at' => $restaurant->created_at->toIso8601String(),
        ];
    }
}
