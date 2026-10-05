<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Enums\VoucherKind;
use App\Jobs\SendVoucherNotification;
use App\Mail\TemplatedMail;
use App\Models\NotificationLog;
use App\Models\Voucher;
use App\Services\Notifications\VoucherNotificationService;
use Illuminate\Contracts\Queue\ShouldBeEncrypted;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

final class NotificationTest extends TestCase
{
    public function test_the_purchase_confirmation_is_a_receipt_without_anything_that_spends_the_voucher(): void
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
            $this->assertStringContainsString('50,00', $mail->subjectLine);
            $this->assertStringNotContainsString('<script>', $mail->htmlBody);
            $this->assertStringContainsString('&lt;script&gt;', $mail->htmlBody);
            $this->assertStringContainsString('Beisl &lt;b&gt;Test&lt;/b&gt;', $mail->htmlBody);
            $this->assertStringContainsString('unbefristet gültig', $mail->htmlBody);
            // ADR-003: a receipt — amount, date, payment.
            $this->assertStringContainsString('Wert: € 50,00', str_replace("\u{00A0}", ' ', $mail->textBody));
            $this->assertStringContainsString('Datum: '.Carbon::now('Europe/Vienna')->format('d.m.Y'), $mail->textBody);
            $this->assertStringContainsString('Zahlungsart: Bar', $mail->textBody);
            // Nothing that proves or spends the voucher: no voucher number, link, QR payload or token.
            foreach ([$voucher->voucher_number, substr($voucher->voucher_number, -4), 'http', 'GCPV1', substr($qr, 6, 12)] as $forbidden) {
                $this->assertStringNotContainsString($forbidden, $mail->htmlBody.$mail->textBody.$mail->subjectLine);
            }

            // The voucher itself travels only as the PDF attachment (decision 2026-10-04), never in the text.
            $this->assertStringContainsString('als PDF angehängt', (string) $mail->attachmentNote);
            $this->assertStringContainsString('als PDF angehängt', $mail->render());
            $this->assertCount(1, $mail->attachments());
            $this->assertNotNull($mail->voucherPdf);
            $this->assertSame('Gutschein-Beisl-b-Test-b.pdf', $mail->voucherPdf[0]);
            $this->assertStringStartsWith('%PDF-', $mail->voucherPdf[1]);

            return $mail->hasTo('guest@example.com');
        });
        $this->assertDatabaseHas('notification_logs', ['recipient' => 'guest@example.com', 'status' => 'sent', 'template_key' => 'voucher_issued']);
        // Nothing of the QR is stored with the e-mail log.
        $this->assertStringNotContainsString(substr($qr, 6, 12), json_encode(NotificationLog::query()->get()->toArray(), JSON_THROW_ON_ERROR));
    }

    public function test_the_sale_job_carries_the_qr_encrypted_on_the_queue(): void
    {
        Queue::fake();
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $qr = (string) $this->postJson('/api/v1/vouchers', [
            'value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment(), 'customer' => ['email' => 'guest@example.com'],
        ], $this->idempotency())->assertCreated()->json('printable.payload');

        Queue::assertPushed(SendVoucherNotification::class, function (SendVoucherNotification $job) use ($qr): bool {
            $this->assertInstanceOf(ShouldBeEncrypted::class, $job);

            return $job->printablePayload === $qr;
        });
    }

    public function test_a_gift_card_sale_never_attaches_a_qr(): void
    {
        Mail::fake();
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $response = $this->postJson('/api/v1/vouchers', [
            'value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment(), 'customer' => ['email' => 'guest@example.com'],
        ], $this->idempotency())->assertCreated();
        $voucher = Voucher::query()->findOrFail($response->json('data.id'));
        $voucher->forceFill(['kind' => VoucherKind::Card])->save();
        Mail::fake();

        app(VoucherNotificationService::class)->send($voucher, 'voucher_issued', null, (string) $response->json('printable.payload'));

        Mail::assertSent(TemplatedMail::class, fn (TemplatedMail $mail): bool => $mail->voucherPdf === null);
    }

    public function test_a_qr_issued_again_before_the_e_mail_left_is_not_attached(): void
    {
        Mail::fake();
        Queue::fake();
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $response = $this->postJson('/api/v1/vouchers', [
            'value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment(), 'customer' => ['email' => 'guest@example.com'],
        ], $this->idempotency())->assertCreated();
        $voucherId = (string) $response->json('data.id');
        $this->postJson("/api/v1/vouchers/{$voucherId}/printable", ['reason' => 'guest lost the sheet'])->assertSuccessful();

        $job = null;
        Queue::assertPushed(SendVoucherNotification::class, function (SendVoucherNotification $pushed) use (&$job): bool {
            $job = $pushed;

            return true;
        });
        app()->call([$job, 'handle']);

        Mail::assertSent(TemplatedMail::class, fn (TemplatedMail $mail): bool => $mail->voucherPdf === null && $mail->attachments() === [] && $mail->attachmentNote === null);
    }

    public function test_the_reload_confirmation_names_the_amount_and_payment_in_bhs(): void
    {
        Mail::fake();
        $restaurant = $this->restaurant(['name' => 'Aščinica', 'locale' => 'hr-HR']);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $voucherId = $this->postJson('/api/v1/vouchers', [
            'value' => 2000,
            'form' => 'printable',
            'payment' => $this->cashPayment(),
            'customer' => ['email' => 'gost@example.com'],
        ], $this->idempotency())->assertCreated()->json('data.id');

        $this->postJson("/api/v1/vouchers/{$voucherId}/reloads", [
            'amount' => 1500,
            'payment' => ['method' => 'card_terminal', 'reference' => 'T-1'],
        ], $this->idempotency())->assertCreated();

        Mail::assertSent(TemplatedMail::class, function (TemplatedMail $mail): bool {
            if (! str_contains($mail->subjectLine, 'dopunjen')) {
                return false;
            }
            $this->assertStringContainsString('Aščinica', $mail->subjectLine);
            $this->assertStringContainsString('15,00', $mail->textBody);
            $this->assertStringContainsString('Način plaćanja: Plaćanje karticom', $mail->textBody);
            $this->assertStringNotContainsString('T-1', $mail->textBody, 'the terminal reference stays internal');

            return true;
        });
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

    public function test_a_reminder_that_failed_for_good_is_tried_again_on_the_next_run(): void
    {
        Mail::fake();
        Carbon::setTestNow('2026-10-01 12:00:00');
        $restaurant = $this->restaurant();
        $restaurant->settings->forceFill(['validity_months' => 36])->save();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment(), 'customer' => ['email' => 'soon@example.com']], $this->idempotency())->assertCreated();

        Carbon::setTestNow('2029-09-25 12:00:00');
        $this->artisan('vouchers:notify-expiring')->assertSuccessful();
        // SMTP was down for longer than the job's retries.
        NotificationLog::query()->where('template_key', 'voucher_expiring')->update(['status' => 'failed']);

        Carbon::setTestNow('2029-09-26 12:00:00');
        $this->artisan('vouchers:notify-expiring')->assertSuccessful();
        $this->assertSame(1, NotificationLog::query()->where('template_key', 'voucher_expiring')->where('status', '!=', 'failed')->count());
    }

    public function test_a_reminder_whose_queued_job_was_lost_is_queued_again_the_next_day(): void
    {
        Queue::fake();
        Carbon::setTestNow('2026-10-01 12:00:00');
        $restaurant = $this->restaurant();
        $restaurant->settings->forceFill(['validity_months' => 36])->save();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment(), 'customer' => ['email' => 'soon@example.com']], $this->idempotency())->assertCreated();
        $reminders = static fn (): int => Queue::pushed(SendVoucherNotification::class, static fn (SendVoucherNotification $job): bool => $job->templateKey === 'voucher_expiring')->count();

        Carbon::setTestNow('2029-09-25 10:00:00');
        $this->artisan('vouchers:notify-expiring')->assertSuccessful();
        $this->artisan('vouchers:notify-expiring')->assertSuccessful();
        $this->assertSame(1, $reminders(), 'queued once while the first job waits');

        // The job never ran (lost with Redis, cleared from the queue): its unique lock must not block the voucher for ever.
        Carbon::setTestNow('2029-09-26 10:00:00');
        $this->artisan('vouchers:notify-expiring')->assertSuccessful();
        $this->assertSame(2, $reminders());
    }

    public function test_the_guest_e_mail_declares_the_language_it_is_written_in(): void
    {
        Mail::fake();
        foreach (['de-AT' => 'de', 'hr-HR' => 'bs', 'en-GB' => 'en'] as $locale => $language) {
            $restaurant = $this->restaurant(['locale' => $locale]);
            $this->actingAsStaff($restaurant, RoleSlug::Manager);
            $this->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment(), 'customer' => ['email' => "guest-{$language}@example.com"]], $this->idempotency())->assertCreated();

            Mail::assertSent(TemplatedMail::class, function (TemplatedMail $mail) use ($language): bool {
                if (! $mail->hasTo("guest-{$language}@example.com")) {
                    return false;
                }
                // Screen readers and mail clients pick voice and hyphenation from it.
                $this->assertStringContainsString('<html lang="'.$language.'">', $mail->render());

                return true;
            });
        }
    }
}
