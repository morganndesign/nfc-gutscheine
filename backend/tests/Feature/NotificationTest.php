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
            $this->assertStringContainsString('Bezahlt: Bar', $mail->textBody);
            // Nothing that proves or spends the voucher: no voucher number, link, QR payload or token.
            foreach ([$voucher->voucher_number, substr($voucher->voucher_number, -4), 'http', 'GCPV1', substr($qr, 6, 12)] as $forbidden) {
                $this->assertStringNotContainsString($forbidden, $mail->htmlBody.$mail->textBody.$mail->subjectLine);
            }

            return $mail->hasTo('guest@example.com');
        });
        $this->assertDatabaseHas('notification_logs', ['recipient' => 'guest@example.com', 'status' => 'sent', 'template_key' => 'voucher_issued']);
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
            $this->assertStringContainsString('Plaćeno: Kartica', $mail->textBody);
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
}
