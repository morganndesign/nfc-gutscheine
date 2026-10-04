<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Settings\UpdateNotificationTemplateRequest;
use App\Http\Resources\NotificationTemplateResource;
use App\Models\NotificationTemplate;
use App\Models\Restaurant;
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

    /** The e-mails the restaurant's guests get, in the restaurant's language only. */
    public function index(Request $request): JsonResponse
    {
        $restaurant = Restaurant::query()->findOrFail($this->tenant()->id());
        $templates = NotificationTemplate::effective((string) $restaurant->getKey(), $restaurant->locale)
            ->filter(static fn (NotificationTemplate $t): bool => array_key_exists($t->key, NotificationTemplate::PLACEHOLDERS))
            ->sortBy(static fn (NotificationTemplate $t): int|false => array_search($t->key, array_keys(NotificationTemplate::PLACEHOLDERS), true))
            ->values();

        return response()->json([
            'language' => NotificationTemplate::languageOf($restaurant->locale),
            'data' => NotificationTemplateResource::collection($templates)->resolve($request),
        ]);
    }

    public function update(UpdateNotificationTemplateRequest $request, string $key): NotificationTemplateResource
    {
        abort_unless(array_key_exists($key, NotificationTemplate::PLACEHOLDERS), 404);
        $restaurantId = (string) $this->tenant()->id();
        $restaurant = Restaurant::query()->findOrFail($restaurantId);
        // The restaurant edits the version its guests get: the language of the template that applies now.
        $locale = NotificationTemplate::effective($restaurantId, $restaurant->locale)->get($key)->locale
            ?? NotificationTemplate::languageOf($restaurant->locale);

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
