<?php

declare(strict_types=1);

namespace App\Listeners;

use App\Support\OpsAlert;
use Illuminate\Queue\Events\QueueBusy;

/**
 * `queue:monitor` (every 5 minutes) raises QueueBusy when a queue holds more than 500 jobs — e.g. the worker
 * container is down and customer e-mails pile up. Operations hear of it at most once per queue every 30 minutes.
 */
final class AlertOnQueueBacklog
{
    public function handle(QueueBusy $event): void
    {
        $queue = $event->connection.':'.$event->queue;

        OpsAlert::send(
            'queue-backlog:'.$queue,
            "Queue backlog on {$queue}",
            "The queue {$queue} holds {$event->size} jobs (threshold 500).\n\n"
            ."Check the \"worker\" service in Coolify (resource → Logs, status healthy?).\n"
            .'Restart it there if needed (the service restarts automatically after a crash).',
            1800,
        );
    }
}
