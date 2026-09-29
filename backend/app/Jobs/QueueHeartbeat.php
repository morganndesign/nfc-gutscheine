<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Support\Heartbeat;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;

/** Queued every minute by the scheduler: it only runs when a worker takes jobs, so it proves the worker is alive. */
final class QueueHeartbeat implements ShouldQueue
{
    use Dispatchable;
    use Queueable;

    public int $tries = 1;

    public function handle(): void
    {
        Heartbeat::beat(Heartbeat::WORKER);
    }
}
