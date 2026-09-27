<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin AuditLog
 */
final class AuditLogResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var AuditLog $log */
        $log = $this->resource;

        return [
            'id' => $log->id,
            'action' => $log->action,
            'auditable_type' => $log->auditable_type,
            'auditable_id' => $log->auditable_id,
            'old_values' => $log->old_values,
            'new_values' => $log->new_values,
            'metadata' => $log->metadata,
            'user' => $this->whenLoaded('user', static fn (): ?array => $log->user !== null ? ['id' => $log->user->id, 'name' => $log->user->name] : null),
            'restaurant' => $this->whenLoaded('restaurant', static fn (): ?array => $log->restaurant !== null ? ['id' => $log->restaurant->id, 'name' => $log->restaurant->name] : null),
            'ip_address' => $log->ip_address,
            'request_id' => $log->request_id,
            'created_at' => $log->created_at->toIso8601String(),
        ];
    }
}
