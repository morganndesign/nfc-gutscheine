<?php

declare(strict_types=1);

use App\Jobs\QueueHeartbeat;
use App\Support\Heartbeat;
use App\Support\OpsAlert;
use Illuminate\Console\Scheduling\Event;
use Illuminate\Support\Facades\Schedule;

/*
| Nightly jobs run in the restaurants' business timezone (SCHEDULE_TIMEZONE, default Europe/Vienna),
| so "00:15" really means a quarter past midnight for the restaurants. Nothing is scheduled between 02:00 and 03:00:
| that hour is skipped when summer time starts and happens twice when it ends.
|
| Overlap locks: a run killed by a deploy or a crash leaves its lock in Redis until it expires. Every lock therefore
| expires before the task is next due (Laravel's default is 24 hours: a killed every-minute task would stop sealing
| and monitoring security events for a day, a killed nightly task would skip the next night).
|
| Failures: a task that exits with an error is e-mailed to operations (OPS_ALERT_EMAIL), at most every six hours
| per task. verify-chains, key-set:verify and check-backups report their own findings in detail instead.
*/
$tz = (string) config('giftcard.schedule_timezone');

$alerting = static function (Event $event, string $task): Event {
    return $event->onFailure(static function () use ($task): void {
        OpsAlert::send(
            'schedule:'.$task,
            "Scheduled task failed: {$task}",
            "The scheduled task {$task} exited with an error. Its output and the exception are in the scheduler's log:\n"
            ."Coolify → scheduler → Logs. Run it by hand to see the error: Terminal → scheduler → php artisan {$task}",
            21600,
        );
    });
};

// Expire vouchers whose last valid day has ended. The balance is kept (no write-off); owners can reinstate.
$alerting(Schedule::command('vouchers:expire')->dailyAt('00:15')->timezone($tz)->withoutOverlapping(720)->onOneServer(), 'vouchers:expire');

// Remind customers N days before their voucher expires (once per voucher).
$alerting(Schedule::command('vouchers:notify-expiring')->dailyAt('10:00')->timezone($tz)->withoutOverlapping(720)->onOneServer(), 'vouchers:notify-expiring');

// Proof of life for GET /api/v1/health/operations: the scheduler beats itself, the worker runs the job.
Schedule::call(static fn () => Heartbeat::beat(Heartbeat::SCHEDULER))->everyMinute()->name('heartbeat:scheduler')->onOneServer();
Schedule::job(new QueueHeartbeat)->everyMinute()->name('heartbeat:worker')->onOneServer();

// Security event stream: hash-chain settled events into seals (ADR-003).
$alerting(Schedule::command('giftcard:seal-security-events')->everyMinute()->withoutOverlapping(10)->onOneServer(), 'giftcard:seal-security-events');
// Fraud and attack rules over new events; high and critical alerts are e-mailed to operations.
$alerting(Schedule::command('giftcard:monitor-security-events')->everyMinute()->withoutOverlapping(10)->onOneServer(), 'giftcard:monitor-security-events');

// Tamper evidence: recompute every hash chain, every voucher balance from its ledger and every event seal.
// Online orders whose payment page closed without a payment (the provider's event is the normal way).
$alerting(Schedule::command('online:expire-orders')->everyFifteenMinutes()->withoutOverlapping(10)->onOneServer(), 'online:expire-orders');

Schedule::command('giftcard:verify-chains')->dailyAt('04:00')->timezone($tz)->withoutOverlapping(720)->onOneServer();

// Tamper check of the card root keys against the key check values of their ceremony.
Schedule::command('cards:key-set:verify')->dailyAt('04:10')->timezone($tz)->withoutOverlapping(720)->onOneServer();

// Backups: the last database dump, keystore copy and off-site copy are current (alerts operations).
Schedule::command('ops:check-backups')->hourlyAt(45)->withoutOverlapping(30)->onOneServer();

// Housekeeping.
$alerting(Schedule::command('queue:prune-failed --hours=720')->dailyAt('03:30')->timezone($tz)->onOneServer(), 'queue:prune-failed');
$alerting(Schedule::command('auth:clear-resets')->everyFifteenMinutes()->onOneServer(), 'auth:clear-resets');
$alerting(Schedule::command('queue:monitor redis:default,redis:notifications --max=500')->everyFiveMinutes()->onOneServer()
    ->when(static fn (): bool => config('queue.default') === 'redis'), 'queue:monitor');
