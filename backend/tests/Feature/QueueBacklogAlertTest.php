<?php

declare(strict_types=1);

namespace Tests\Feature;

use Illuminate\Mail\Events\MessageSent;
use Illuminate\Queue\Events\QueueBusy;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

final class QueueBacklogAlertTest extends TestCase
{
    public function test_a_queue_backlog_mails_the_ops_address_once_per_half_hour(): void
    {
        config(['giftcard.ops_alert_email' => 'ops@example.at', 'mail.default' => 'array']);
        $sent = [];
        Event::listen(MessageSent::class, static function (MessageSent $e) use (&$sent): void {
            $sent[] = $e->message;
        });

        event(new QueueBusy('redis', 'notifications', 812));
        event(new QueueBusy('redis', 'notifications', 900));
        event(new QueueBusy('redis', 'default', 600));

        $this->assertCount(2, $sent);
        $this->assertSame('ops@example.at', $sent[0]->getTo()[0]->getAddress());
        $this->assertStringContainsString('redis:notifications', (string) $sent[0]->getSubject());
        $this->assertStringContainsString('812 jobs', (string) $sent[0]->getTextBody());
    }
}
