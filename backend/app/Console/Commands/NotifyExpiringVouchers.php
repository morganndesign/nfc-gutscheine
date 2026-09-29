<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Enums\RestaurantStatus;
use App\Enums\VoucherStatus;
use App\Jobs\SendVoucherNotification;
use App\Models\NotificationLog;
use App\Models\NotificationTemplate;
use App\Models\Restaurant;
use App\Models\Voucher;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;

final class NotifyExpiringVouchers extends Command
{
    protected $signature = 'vouchers:notify-expiring';

    protected $description = 'Queue reminder e-mails for vouchers with a balance that expire soon (once per voucher).';

    public function handle(): int
    {
        $days = (int) config('giftcard.notifications.expiring_days_before');
        $queued = 0;

        Voucher::query()
            ->withoutGlobalScopes()
            ->where('status', VoucherStatus::Active->value)
            ->where('balance', '>', 0)
            ->whereNotNull('customer_id')
            // Only restaurants that are live (not suspended, not closed).
            ->whereIn('restaurant_id', Restaurant::query()->where('status', RestaurantStatus::Active->value)->select('id'))
            ->whereBetween('expires_at', [Carbon::now(), Carbon::now()->addDays($days)])
            ->whereNotExists(static function ($q): void {
                $q->selectRaw('1')
                    ->from((new NotificationLog)->getTable())
                    ->whereColumn('notification_logs.voucher_id', 'vouchers.id')
                    ->where('notification_logs.template_key', NotificationTemplate::KEY_VOUCHER_EXPIRING);
            })
            ->select('id')
            ->chunkById(500, static function ($vouchers) use (&$queued): void {
                foreach ($vouchers as $voucher) {
                    SendVoucherNotification::dispatch($voucher->id, NotificationTemplate::KEY_VOUCHER_EXPIRING);
                    $queued++;
                }
            });

        $this->info("Queued {$queued} expiration reminder(s).");

        return self::SUCCESS;
    }
}
