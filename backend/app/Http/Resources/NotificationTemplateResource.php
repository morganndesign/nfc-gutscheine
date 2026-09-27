<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\NotificationTemplate;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin NotificationTemplate
 */
final class NotificationTemplateResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var NotificationTemplate $t */
        $t = $this->resource;

        return [
            'id' => $t->id,
            'key' => $t->key,
            'channel' => $t->channel,
            'locale' => $t->locale,
            'subject' => $t->subject,
            'body' => $t->body,
            'is_active' => $t->is_active,
            'is_default' => $t->restaurant_id === null,
            'placeholders' => NotificationTemplate::PLACEHOLDERS[$t->key] ?? [],
        ];
    }
}
