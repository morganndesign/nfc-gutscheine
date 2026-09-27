<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\Device;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Device
 */
final class DeviceResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var Device $device */
        $device = $this->resource;
        $current = $request->attributes->get('device');

        return [
            'id' => $device->id,
            'name' => $device->name,
            'type' => $device->type,
            'platform' => $device->platform,
            'status' => $device->status->value,
            'last_seen_at' => $device->last_seen_at?->toIso8601String(),
            'last_ip' => $device->last_ip,
            'last_user' => $this->whenLoaded('lastUser', static fn (): ?array => $device->lastUser !== null ? ['id' => $device->lastUser->id, 'name' => $device->lastUser->name] : null),
            'is_current' => $current instanceof Device && $current->is($device),
            'revoked_at' => $device->revoked_at?->toIso8601String(),
            'created_at' => $device->created_at->toIso8601String(),
        ];
    }
}
