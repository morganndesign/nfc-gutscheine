<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Mail\TemplatedMail;
use App\Models\NotificationLog;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

final class NotificationTest extends TestCase
{
    public function test_customer_receives_localised_issue_email_with_escaped_content(): void
    {
        Mail::fake();
        $restaurant = $this->restaurant(['name' => 'Beisl <b>Test</b>', 'locale' => 'de-AT']);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->postJson('/api/v1/cards', [
            'value' => 5000,
            'customer' => ['first_name' => '<script>alert(1)</script>', 'email' => 'guest@example.com'],
        ])->assertCreated();

        Mail::assertSent(TemplatedMail::class, function (TemplatedMail $mail): bool {
            $this->assertStringStartsWith('Ihr Gutschein', $mail->subjectLine);
            $this->assertStringNotContainsString('<script>', $mail->htmlBody);
            $this->assertStringContainsString('&lt;script&gt;', $mail->htmlBody);
            $this->assertStringContainsString('50,00', $mail->htmlBody);

            return $mail->hasTo('guest@example.com');
        });
        $this->assertDatabaseHas('notification_logs', ['recipient' => 'guest@example.com', 'status' => 'sent', 'template_key' => 'card_issued']);
    }

    public function test_no_email_when_disabled(): void
    {
        Mail::fake();
        $restaurant = $this->restaurant();
        $restaurant->settings->forceFill(['send_customer_emails' => false])->save();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->postJson('/api/v1/cards', ['value' => 5000, 'customer' => ['email' => 'guest@example.com']])->assertCreated();

        Mail::assertNothingSent();
    }

    public function test_expiring_reminders_are_sent_once(): void
    {
        Mail::fake();
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson('/api/v1/cards', [
            'value' => 5000,
            'expires_at' => Carbon::now()->addDays(10)->format('Y-m-d'),
            'customer' => ['email' => 'soon@example.com'],
        ])->assertCreated();

        $this->artisan('giftcards:notify-expiring')->assertSuccessful();
        $this->artisan('giftcards:notify-expiring')->assertSuccessful();

        $this->assertSame(1, NotificationLog::query()->where('template_key', 'card_expiring')->count());
    }
}
