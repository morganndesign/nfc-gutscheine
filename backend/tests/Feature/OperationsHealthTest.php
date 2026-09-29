<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Jobs\QueueHeartbeat;
use App\Support\Heartbeat;
use Illuminate\Contracts\Queue\Job;
use Illuminate\Mail\Events\MessageSent;
use Illuminate\Queue\Events\JobFailed;
use Illuminate\Support\Facades\Event;
use RuntimeException;
use Tests\TestCase;

/** What the external uptime monitor and the operations inbox see when a background service stops. */
final class OperationsHealthTest extends TestCase
{
    public function test_the_operations_check_fails_until_scheduler_and_worker_beat_and_again_when_they_stop(): void
    {
        $this->get('/api/v1/health/operations')->assertStatus(503)->assertSeeText('degraded');

        Heartbeat::beat(Heartbeat::SCHEDULER);
        $this->get('/api/v1/health/operations')->assertStatus(503);
        (new QueueHeartbeat)->handle();
        $this->get('/api/v1/health/operations')->assertOk()->assertSeeText('ok')->assertHeader('Cache-Control', 'no-store, private');

        $this->travel(Heartbeat::STALE_SECONDS + 60)->seconds();
        $this->get('/api/v1/health/operations')->assertStatus(503);

        $this->artisan('schedule:list')->expectsOutputToContain('heartbeat:scheduler')->expectsOutputToContain('heartbeat:worker');
    }

    public function test_a_job_that_failed_for_good_is_mailed_to_operations_once_an_hour(): void
    {
        config(['giftcard.ops_alert_email' => 'ops@giftcardpro.test', 'mail.default' => 'array']);
        $sent = [];
        Event::listen(MessageSent::class, static function (MessageSent $e) use (&$sent): void {
            $sent[] = $e->message->getSubject();
        });
        $job = $this->createStub(Job::class);
        $job->method('resolveName')->willReturn('App\\Jobs\\SendVoucherNotification');

        event(new JobFailed('redis', $job, new RuntimeException('Connection to smtp refused')));
        event(new JobFailed('redis', $job, new RuntimeException('Connection to smtp refused')));

        $this->assertSame(['[GiftCard Pro] Background job failed: App\\Jobs\\SendVoucherNotification'], $sent);
    }
}
