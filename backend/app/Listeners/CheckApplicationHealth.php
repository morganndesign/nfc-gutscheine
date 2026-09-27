<?php

declare(strict_types=1);

namespace App\Listeners;

use Illuminate\Foundation\Events\DiagnosingHealth;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * Makes GET /up (used by Docker health checks, the deploy script and uptime monitoring) fail
 * when the database or the cache/session store is unreachable — not only when PHP is down.
 */
final class CheckApplicationHealth
{
    public function handle(DiagnosingHealth $event): void
    {
        DB::connection()->select('select 1');

        $key = 'health:'.bin2hex(random_bytes(4));
        Cache::put($key, 'ok', 10);
        if (Cache::pull($key) !== 'ok') {
            throw new RuntimeException('Cache store is not writable.');
        }
    }
}
