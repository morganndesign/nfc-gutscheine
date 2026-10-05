<?php

declare(strict_types=1);

namespace App\Services\Cards;

use App\Enums\RoleSlug;
use App\Enums\UserStatus;
use App\Models\Restaurant;
use App\Models\User;
use App\Notifications\CardOrderUpdateNotification;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * E-mails the restaurant about its card order (audit K8): the person who ordered and the owners, each in their
 * language, after the change is committed. A failing mail never undoes the change.
 */
final class CardOrderUpdates
{
    /** @param 'accepted'|'declined'|'shipped' $kind */
    public function notify(string $restaurantId, string $kind, int $quantity, ?string $requestedBy, ?string $batchCode = null, ?string $reason = null): void
    {
        DB::afterCommit(static function () use ($restaurantId, $kind, $quantity, $requestedBy, $batchCode, $reason): void {
            /** @var Restaurant|null $restaurant */
            $restaurant = Restaurant::query()->find($restaurantId);
            if ($restaurant === null) {
                return;
            }
            $recipients = User::query()
                ->where('restaurant_id', $restaurantId)
                ->where('status', UserStatus::Active->value)
                ->where(static fn ($q) => $q->whereHas('role', static fn ($r) => $r->where('slug', RoleSlug::Owner->value))
                    ->when($requestedBy !== null, static fn ($w) => $w->orWhere('id', $requestedBy)))
                ->get();
            foreach ($recipients as $user) {
                /** @var User $user */
                $language = in_array($user->locale, ['de', 'en', 'bs'], true) ? $user->locale : (string) config('giftcard.mail_locale');
                try {
                    $user->notify((new CardOrderUpdateNotification($kind, $restaurant->name, $quantity, $batchCode, $reason))->locale($language));
                } catch (Throwable $e) {
                    Log::warning('Card order update could not be e-mailed.', ['user_id' => $user->getKey(), 'kind' => $kind, 'error' => $e->getMessage()]);
                }
            }
        });
    }
}
