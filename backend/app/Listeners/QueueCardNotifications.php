<?php

declare(strict_types=1);

namespace App\Listeners;

use App\Events\GiftCardIssued;
use App\Events\GiftCardRedeemed;
use App\Events\GiftCardReloaded;
use App\Jobs\SendCardNotification;
use App\Models\NotificationTemplate;
use App\Support\Money;

final class QueueCardNotifications
{
    public function handleIssued(GiftCardIssued $event): void
    {
        if ($event->card->customer_id !== null) {
            SendCardNotification::dispatch($event->card->getKey(), NotificationTemplate::KEY_CARD_ISSUED);
        }
    }

    public function handleReloaded(GiftCardReloaded $event): void
    {
        if ($event->card->customer_id !== null) {
            SendCardNotification::dispatch(
                $event->card->getKey(),
                NotificationTemplate::KEY_CARD_RELOADED,
                ['amount' => Money::format($event->transaction->amount, $event->card->currency)],
                $event->transaction->getKey(),
            );
        }
    }

    public function handleRedeemed(GiftCardRedeemed $event): void
    {
        $threshold = (int) config('giftcard.notifications.low_balance_threshold');

        if ($event->card->customer_id !== null
            && $event->card->balance > 0
            && $event->card->balance <= $threshold
            && $event->transaction->balance_before > $threshold) {
            SendCardNotification::dispatch($event->card->getKey(), NotificationTemplate::KEY_BALANCE_LOW, [], $event->transaction->getKey());
        }
    }
}
