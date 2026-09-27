<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Settings\UpdateNotificationTemplateRequest;
use App\Http\Resources\NotificationTemplateResource;
use App\Models\NotificationTemplate;
use App\Services\Audit\AuditLogger;
use App\Support\Actor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Restaurants see the effective template per key/locale: their own override if present,
 * otherwise the system default. Updating a default creates a restaurant-specific override.
 */
final class NotificationTemplateController extends Controller
{
    public function __construct(private readonly AuditLogger $audit) {}

    public function index(Request $request): JsonResponse
    {
        $restaurantId = $this->tenant()->id();

        $templates = NotificationTemplate::query()
            ->where(static fn ($q) => $q->whereNull('restaurant_id')->orWhere('restaurant_id', $restaurantId))
            ->orderBy('key')
            ->orderBy('locale')
            ->get()
            ->groupBy(static fn (NotificationTemplate $t): string => $t->key.'|'.$t->channel.'|'.$t->locale)
            ->map(static fn ($group) => $group->sortBy(static fn (NotificationTemplate $t): int => $t->restaurant_id === null ? 1 : 0)->first())
            ->values();

        return response()->json(['data' => NotificationTemplateResource::collection($templates)->resolve($request)]);
    }

    public function update(UpdateNotificationTemplateRequest $request, string $key): NotificationTemplateResource
    {
        abort_unless(array_key_exists($key, NotificationTemplate::PLACEHOLDERS), 404);
        $locale = (string) $request->input('locale', 'en');
        $restaurantId = (string) $this->tenant()->id();

        $template = NotificationTemplate::query()->firstOrNew([
            'restaurant_id' => $restaurantId,
            'key' => $key,
            'channel' => 'mail',
            'locale' => $locale,
        ]);

        $old = $template->exists ? $template->only(['subject', 'body', 'is_active']) : null;
        $template->fill([
            'subject' => $request->validated('subject'),
            'body' => $request->validated('body'),
            'is_active' => $request->boolean('is_active', true),
        ])->save();

        $this->audit->log('notification_template.updated', Actor::fromRequest($request), $template, $old, $template->only(['subject', 'body', 'is_active']), restaurantId: $restaurantId);

        return NotificationTemplateResource::make($template);
    }
}
