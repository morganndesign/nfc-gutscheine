<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Models\SystemSetting;
use App\Support\OpsAlert;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

/** Operations alerts are throttled only once they actually reached someone. */
final class OpsAlertTest extends TestCase
{
    public function test_an_alert_that_could_not_be_sent_is_tried_again_next_time(): void
    {
        config(['giftcard.ops_alert_email' => 'ops@example.com']);
        // SMTP down: nothing listens on the port.
        config(['mail.default' => 'smtp', 'mail.mailers.smtp.host' => '127.0.0.1', 'mail.mailers.smtp.port' => 1, 'mail.mailers.smtp.timeout' => 1]);
        $this->assertFalse(OpsAlert::send('test-key', 'Something broke', 'details'));

        Mail::fake();
        $this->assertTrue(OpsAlert::send('test-key', 'Something broke', 'details'), 'the failed attempt must not mute the alert');
        $this->assertFalse(OpsAlert::send('test-key', 'Something broke', 'details'), 'a delivered alert is throttled');
    }

    public function test_an_alert_without_a_recipient_is_not_muted(): void
    {
        config(['giftcard.ops_alert_email' => null]);
        SystemSetting::query()->where('key', 'platform.support_email')->delete();
        $this->assertFalse(OpsAlert::send('nobody', 'Something broke', 'details'));
        config(['giftcard.ops_alert_email' => 'ops@example.com']);
        Mail::fake();
        $this->assertTrue(OpsAlert::send('nobody', 'Something broke', 'details'));
    }
}
