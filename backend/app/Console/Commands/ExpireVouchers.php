<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Enums\RestaurantStatus;
use App\Models\Restaurant;
use App\Services\Vouchers\VoucherService;
use Illuminate\Console\Command;
use Throwable;

final class ExpireVouchers extends Command
{
    protected $signature = 'vouchers:expire';

    protected $description = 'Mark active vouchers whose last valid day has ended as expired. Balances are kept; blocked vouchers are skipped.';

    public function handle(VoucherService $vouchers): int
    {
        $total = 0;
        $failures = 0;

        Restaurant::query()->where('status', RestaurantStatus::Active->value)->each(function (Restaurant $restaurant) use ($vouchers, &$total, &$failures): void {
            try {
                $count = $vouchers->expireDue($restaurant);
                $total += $count;
                if ($count > 0) {
                    $this->line("{$restaurant->name}: {$count} voucher(s) expired");
                }
            } catch (Throwable $e) {
                $failures++;
                report($e);
                $this->error("{$restaurant->name}: {$e->getMessage()}");
            }
        });

        $this->info("Expired {$total} voucher(s).");

        return $failures === 0 ? self::SUCCESS : self::FAILURE;
    }
}
