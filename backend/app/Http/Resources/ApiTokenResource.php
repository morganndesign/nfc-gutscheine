<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\PersonalAccessToken;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin PersonalAccessToken
 */
final class ApiTokenResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var PersonalAccessToken $token */
        $token = $this->resource;

        return [
            'id' => $token->id,
            'name' => $token->name,
            'abilities' => $token->abilities,
            'last_used_at' => $token->last_used_at?->toIso8601String(),
            'expires_at' => $token->expires_at?->toIso8601String(),
            'revoked_at' => $token->revoked_at?->toIso8601String(),
            'active' => $token->isUsable(),
            'owner' => $this->whenLoaded('tokenable', static fn (): array => [
                'id' => $token->tokenable?->getKey(),
                'name' => $token->tokenable?->getAttribute('name'),
            ]),
            'kind' => $token->device_id !== null ? 'device' : 'integration',
            'restaurant' => $this->whenLoaded('restaurant', static fn (): ?array => $token->restaurant !== null
                ? ['id' => $token->restaurant->id, 'name' => $token->restaurant->name]
                : null),
            'created_at' => $token->created_at?->toIso8601String(),
        ];
    }
}
