<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Mail\TemplatedMail;
use App\Models\NotificationLog;
use App\Models\Voucher;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

final class NotificationTest extends TestCase
{
    public function test_customer_receives_a_localised_email_without_value_number_or_link(): void
    {
        Mail::fake();
        $restaurant = $this->restaurant(['name' => 'Beisl <b>Test</b>', 'locale' => 'de-AT']);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $response = $this->postJson('/api/v1/vouchers', [
            'value' => 5000,
            'form' => 'printable',
            'payment' => $this->cashPayment(),
            'customer' => ['first_name' => '<script>alert(1)</script>', 'email' => 'guest@example.com'],
        ], $this->idempotency())->assertCreated();
        $voucher = Voucher::query()->findOrFail($response->json('data.id'));
        $qr = (string) $response->json('printable.payload');

        Mail::assertSent(TemplatedMail::class, function (TemplatedMail $mail) use ($voucher, $qr): bool {
            $this->assertStringStartsWith('Ihr Gutschein', $mail->subjectLine);
            $this->assertStringNotContainsString('<script>', $mail->htmlBody);
            $this->assertStringContainsString('&lt;script&gt;', $mail->htmlBody);
            $this->assertStringContainsString('unbefristet gültig', $mail->htmlBody);
            // Architecture §6.4 and decision 24: no amount, no voucher number, no link, no QR.
            foreach (['50,00', '50.00', substr($voucher->voucher_number, -4), 'http', substr($qr, 6, 12)] as $forbidden) {
                $this->assertStringNotContainsString($forbidden, $mail->htmlBody.$mail->textBody);
            }

            return $mail->hasTo('guest@example.com');
        });
        $this->assertDatabaseHas('notification_logs', ['recipient' => 'guest@example.com', 'status' => 'sent', 'template_key' => 'voucher_issued']);
    }

    public function test_no_email_when_disabled(): void
    {
        Mail::fake();
        $restaurant = $this->restaurant();
        $restaurant->settings->forceFill(['send_customer_emails' => false])->save();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment(), 'customer' => ['email' => 'guest@example.com']], $this->idempotency())->assertCreated();

        Mail::assertNothingSent();
    }

    public function test_expiring_reminders_are_sent_once(): void
    {
        Mail::fake();
        Carbon::setTestNow('2026-10-01 12:00:00');
        $restaurant = $this->restaurant();
        $restaurant->settings->forceFill(['validity_months' => 36])->save();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment(), 'customer' => ['email' => 'soon@example.com']], $this->idempotency())->assertCreated();

        Carbon::setTestNow('2029-09-25 12:00:00');
        $this->artisan('vouchers:notify-expiring')->assertSuccessful();
        $this->artisan('vouchers:notify-expiring')->assertSuccessful();

        $this->assertSame(1, NotificationLog::query()->where('template_key', 'voucher_expiring')->count());
    }
}
