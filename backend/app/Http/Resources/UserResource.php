<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin User
 */
final class UserResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var User $user */
        $user = $this->resource;

        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'status' => $user->status->value,
            'locale' => $user->locale,
            'role' => $this->whenLoaded('role', static fn (): array => [
                'slug' => $user->role->slug->value,
                'name' => $user->role->name,
            ]),
            'restaurant_id' => $user->restaurant_id,
            'last_login_at' => $user->last_login_at?->toIso8601String(),
            'locked' => $user->isLocked(),
            'created_at' => $user->created_at->toIso8601String(),
            'invitation' => $this->when($user->invitationSummary !== null, static fn (): ?array => $user->invitationSummary),
        ];
    }
}
