<?php

declare(strict_types=1);

use Illuminate\Support\Facades\Schedule;

/*
| Nightly jobs run in the restaurants' business timezone (SCHEDULE_TIMEZONE, default Europe/Vienna),
| so "00:15" really means a quarter past midnight for the restaurants.
*/
$tz = (string) config('giftcard.schedule_timezone');

// Expire vouchers whose last valid day has ended. The balance is kept (no write-off); owners can reinstate.
Schedule::command('vouchers:expire')->dailyAt('00:15')->timezone($tz)->withoutOverlapping()->onOneServer();

// Remind customers N days before their voucher expires (once per voucher).
Schedule::command('vouchers:notify-expiring')->dailyAt('10:00')->timezone($tz)->withoutOverlapping()->onOneServer();

// Security event stream: hash-chain settled events into seals (ADR-003).
Schedule::command('giftcard:seal-security-events')->everyMinute()->withoutOverlapping()->onOneServer();
// Fraud and attack rules over new events; high and critical alerts are e-mailed to operations.
Schedule::command('giftcard:monitor-security-events')->everyMinute()->withoutOverlapping()->onOneServer();

// Tamper evidence: recompute every hash chain, every voucher balance from its ledger and every event seal.
Schedule::command('giftcard:verify-chains')->dailyAt('02:30')->timezone($tz)->withoutOverlapping()->onOneServer();

// Tamper check of the card root keys against the key check values of their ceremony.
Schedule::command('cards:key-set:verify')->dailyAt('02:40')->timezone($tz)->withoutOverlapping()->onOneServer();

// Housekeeping.
Schedule::command('queue:prune-failed --hours=720')->dailyAt('03:30')->timezone($tz)->onOneServer();
Schedule::command('auth:clear-resets')->everyFifteenMinutes()->onOneServer();
Schedule::command('queue:monitor redis:default,redis:notifications --max=500')->everyFiveMinutes()->onOneServer()
    ->when(static fn (): bool => config('queue.default') === 'redis');
