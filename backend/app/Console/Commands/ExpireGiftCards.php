<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Enums\RestaurantStatus;
use App\Models\Restaurant;
use App\Services\GiftCards\GiftCardService;
use Illuminate\Console\Command;
use Throwable;

final class ExpireGiftCards extends Command
{
    protected $signature = 'giftcards:expire';

    protected $description = 'Expire gift cards whose expiration date has passed and write off their balance.';

    public function handle(GiftCardService $cards): int
    {
        $total = 0;
        $failures = 0;

        Restaurant::query()->where('status', RestaurantStatus::Active->value)->each(function (Restaurant $restaurant) use ($cards, &$total, &$failures): void {
            try {
                $count = $cards->expireDueCards($restaurant);
                $total += $count;
                if ($count > 0) {
                    $this->line("{$restaurant->name}: {$count} card(s) expired");
                }
            } catch (Throwable $e) {
                $failures++;
                report($e);
                $this->error("{$restaurant->name}: {$e->getMessage()}");
            }
        });

        $this->info("Expired {$total} card(s).");

        return $failures === 0 ? self::SUCCESS : self::FAILURE;
    }
}
