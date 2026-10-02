<?php

declare(strict_types=1);

namespace Tests\Feature;

use Illuminate\Console\Scheduling\Event;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Mail\Events\MessageSent;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Event as Events;
use Tests\TestCase;

/** The scheduler keeps running after a crash or a deploy, and a scheduled task that fails is not silent. */
final class ScheduledTasksTest extends TestCase
{
    /** These report their own findings to operations (with the details) when they exit with a failure. */
    private const SELF_ALERTING = ['giftcard:verify-chains', 'cards:key-set:verify', 'ops:check-backups'];

    /** @return list<Event> */
    private function commands(): array
    {
        return array_values(array_filter(
            app(Schedule::class)->events(),
            static fn (Event $e): bool => str_contains((string) $e->command, 'artisan'),
        ));
    }

    private static function taskName(Event $event): string
    {
        return trim((string) preg_replace('/^.*artisan[\'"]?\s+/', '', (string) $event->command));
    }

    public function test_an_overlap_lock_left_by_a_killed_run_never_blocks_the_next_run(): void
    {
        // A deploy or crash kills the scheduler mid-run; the overlap lock stays in Redis until it expires.
        $now = Carbon::parse('2026-10-05 12:00:30', 'UTC');
        $checked = 0;
        foreach (app(Schedule::class)->events() as $event) {
            if (! $event->withoutOverlapping) {
                continue;
            }
            $first = Carbon::instance($event->nextRunDate($now));
            $second = Carbon::instance($event->nextRunDate($first->copy()->addSecond()));
            $interval = (int) round($first->diffInMinutes($second, true));

            // Before the next run is due; every-minute tasks within ten minutes (a long run must not overlap itself).
            $this->assertLessThanOrEqual(max(10, $interval - 1), $event->expiresAt, self::taskName($event)." (every {$interval} min) keeps a stale overlap lock for {$event->expiresAt} min");
            $checked++;
        }
        $this->assertGreaterThanOrEqual(7, $checked);
    }

    public function test_a_failing_scheduled_task_is_mailed_to_operations(): void
    {
        config(['giftcard.ops_alert_email' => 'ops@giftcardpro.test', 'mail.default' => 'array']);
        $sent = [];
        Events::listen(MessageSent::class, static function (MessageSent $e) use (&$sent): void {
            $sent[] = (string) $e->message->getSubject();
        });

        $expected = [];
        foreach ($this->commands() as $event) {
            $name = self::taskName($event);
            $event->finish(app(), 0);
            if (in_array(strtok($name, ' '), self::SELF_ALERTING, true)) {
                continue;
            }
            $event->finish(app(), 1);
            $event->finish(app(), 1); // the same failure again: one e-mail, not a flood
            $expected[] = '[GiftCard Pro] Scheduled task failed: '.strtok($name, ' ');
        }

        $this->assertContains('[GiftCard Pro] Scheduled task failed: vouchers:expire', $expected);
        $this->assertSame($expected, $sent);
    }

    public function test_nightly_tasks_run_exactly_once_on_the_daylight_saving_days(): void
    {
        $nightly = array_filter(
            app(Schedule::class)->events(),
            static fn (Event $e): bool => $e->timezone === 'Europe/Vienna' && ctype_digit(explode(' ', $e->expression)[1]),
        );
        $this->assertGreaterThanOrEqual(5, count($nightly));
        // Vienna: 2027-03-28 02:00 → 03:00 (02:xx does not exist), 2027-10-31 03:00 → 02:00 (02:xx happens twice).
        foreach (['2027-03-28', '2027-10-31'] as $day) {
            $runs = [];
            $start = Carbon::parse($day.' 00:00', 'Europe/Vienna')->utc()->subHours(2);
            for ($minute = 0; $minute < 28 * 60; $minute++) {
                $now = $start->copy()->addMinutes($minute);
                $this->travelTo($now);
                foreach ($nightly as $event) {
                    if ($now->copy()->timezone($event->timezone)->toDateString() === $day && $event->isDue($this->app)) {
                        $runs[self::taskName($event)] = ($runs[self::taskName($event)] ?? 0) + 1;
                    }
                }
            }
            foreach ($nightly as $event) {
                $this->assertSame(1, $runs[self::taskName($event)] ?? 0, self::taskName($event)." on {$day}");
            }
        }
    }
}
