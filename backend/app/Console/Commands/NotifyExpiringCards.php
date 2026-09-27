<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Enums\GiftCardStatus;
use App\Enums\RestaurantStatus;
use App\Jobs\SendCardNotification;
use App\Models\GiftCard;
use App\Models\NotificationLog;
use App\Models\NotificationTemplate;
use App\Models\Restaurant;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;

final class NotifyExpiringCards extends Command
{
    protected $signature = 'giftcards:notify-expiring';

    protected $description = 'Queue reminder emails for cards with a balance that expire soon.';

    public function handle(): int
    {
        $days = (int) config('giftcard.notifications.expiring_days_before');
        $queued = 0;

        GiftCard::query()
            ->withoutGlobalScopes()
            ->whereNull('deleted_at')
            ->where('status', GiftCardStatus::Active->value)
            ->where('balance', '>', 0)
            ->whereNotNull('customer_id')
            // Only restaurants that are live (not suspended, not closed).
            ->whereIn('restaurant_id', Restaurant::query()->where('status', RestaurantStatus::Active->value)->select('id'))
            ->whereBetween('expires_at', [Carbon::now(), Carbon::now()->addDays($days)])
            ->whereNotExists(static function ($q): void {
                $q->selectRaw('1')
                    ->from((new NotificationLog)->getTable())
                    ->whereColumn('notification_logs.gift_card_id', 'gift_cards.id')
                    ->where('notification_logs.template_key', NotificationTemplate::KEY_CARD_EXPIRING);
            })
            ->select('id')
            ->chunkById(500, static function ($cards) use (&$queued): void {
                foreach ($cards as $card) {
                    SendCardNotification::dispatch($card->id, NotificationTemplate::KEY_CARD_EXPIRING);
                    $queued++;
                }
            });

        $this->info("Queued {$queued} expiration reminder(s).");

        return self::SUCCESS;
    }
}
