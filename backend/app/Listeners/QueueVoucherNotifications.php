<?php

declare(strict_types=1);

namespace App\Listeners;

use App\Events\VoucherIssued;
use App\Events\VoucherReloaded;
use App\Jobs\SendVoucherNotification;
use App\Models\NotificationTemplate;

final class QueueVoucherNotifications
{
    public function handleIssued(VoucherIssued $event): void
    {
        if ($event->voucher->customer_id !== null) {
            SendVoucherNotification::dispatch($event->voucher->getKey(), NotificationTemplate::KEY_VOUCHER_ISSUED, $event->transaction->getKey());
        }
    }

    public function handleReloaded(VoucherReloaded $event): void
    {
        if ($event->voucher->customer_id !== null) {
            SendVoucherNotification::dispatch($event->voucher->getKey(), NotificationTemplate::KEY_VOUCHER_RELOADED, $event->transaction->getKey());
        }
    }
}
