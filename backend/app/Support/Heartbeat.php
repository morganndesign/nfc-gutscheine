<?php

declare(strict_types=1);

namespace App\Support;

use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;

/**
 * Proof of life of the background services (the scheduler beats every minute, the worker when it runs the
 * scheduler's heartbeat job). GET /health/operations turns a stale beat into a failing check for the external
 * uptime monitor: nothing inside the platform can report that the scheduler itself stopped.
 */
final class Heartbeat
{
    public const SCHEDULER = 'scheduler';

    public const WORKER = 'worker';

    /** A beat older than this is a stopped service. */
    public const STALE_SECONDS = 300;

    public static function beat(string $service): void
    {
        Cache::put('ops:heartbeat:'.$service, Carbon::now()->getTimestamp(), 3600);
    }

    public static function fresh(string $service): bool
    {
        $last = Cache::get('ops:heartbeat:'.$service);

        return is_int($last) && Carbon::now()->getTimestamp() - $last <= self::STALE_SECONDS;
    }
}
