<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Enums\OnlineOrderStatus;
use App\Models\OnlineOrder;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;

/**
 * Marks online orders whose payment page has closed as expired. Normally the provider's `checkout.session.expired`
 * event does it; this catches a missed event. A payment that still arrives turns an expired order into a voucher.
 */
final class ExpireOnlineOrders extends Command
{
    protected $signature = 'online:expire-orders';

    protected $description = 'Expire online orders whose payment page has closed (an hour after it was opened)';

    public function handle(): int
    {
        $count = OnlineOrder::query()
            ->where('status', OnlineOrderStatus::Pending->value)
            ->where('expires_at', '<', Carbon::now()->subHour())
            ->update(['status' => OnlineOrderStatus::Expired->value, 'updated_at' => Carbon::now()]);
        $this->info("{$count} online orders expired.");

        return self::SUCCESS;
    }
}
