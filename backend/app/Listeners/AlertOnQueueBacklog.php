<?php

declare(strict_types=1);

namespace App\Listeners;

use App\Models\SystemSetting;
use Illuminate\Queue\Events\QueueBusy;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Throwable;

/**
 * `queue:monitor` (every 5 minutes) raises QueueBusy when a queue holds more than 500 jobs — e.g. the worker
 * container is down and customer e-mails pile up. This logs a critical entry and e-mails the operations
 * address, at most once per queue every 30 minutes so a long outage does not flood the inbox.
 */
final class AlertOnQueueBacklog
{
    private const REPEAT_AFTER_SECONDS = 1800;

    public function handle(QueueBusy $event): void
    {
        $queue = $event->connection.':'.$event->queue;

        Log::critical('Queue backlog above threshold', ['queue' => $queue, 'size' => $event->size]);

        if (! Cache::add('queue-backlog-alert:'.$queue, true, self::REPEAT_AFTER_SECONDS)) {
            return;
        }

        $to = config('giftcard.ops_alert_email') ?: SystemSetting::get('platform.support_email');
        if (! is_string($to) || $to === '') {
            return;
        }

        try {
            Mail::raw(
                "The queue {$queue} holds {$event->size} jobs (threshold 500).\n\n"
                ."Check the worker container: docker compose --env-file .env.production ps queue\n"
                .'Restart it if needed: docker compose --env-file .env.production restart queue',
                static fn ($message) => $message->to($to)->subject("[GiftCard Pro] Queue backlog on {$queue}"),
            );
        } catch (Throwable $e) {
            Log::error('Queue backlog alert could not be sent', ['queue' => $queue, 'error' => $e->getMessage()]);
        }
    }
}
