<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Data\IssueVoucherData;
use App\Data\PaymentData;
use App\Enums\PaymentMethod;
use App\Enums\RoleSlug;
use App\Jobs\SendVoucherNotification;
use App\Mail\TemplatedMail;
use App\Models\NotificationTemplate;
use App\Services\Vouchers\VoucherService;
use App\Support\Actor;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Str;
use Tests\TestCase;

/** Audit 2026-10-06, package 2: money and QR vouchers. */
final class MoneyAuditPackageTest extends TestCase
{
    /** Q1: a retried sale issues a new QR; the guest gets it by e-mail, the first one is dead. */
    public function test_a_retried_sale_e_mails_the_guest_the_qr_that_works(): void
    {
        Mail::fake();
        Queue::fake();
        $this->actingAsStaff($this->restaurant(), RoleSlug::Manager);
        $sale = ['value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment(), 'customer' => ['email' => 'guest@example.com']];
        $key = $this->idempotency();

        $this->postJson('/api/v1/vouchers', $sale, $key)->assertCreated();
        $this->postJson('/api/v1/vouchers', $sale, $key)->assertSuccessful();

        $jobs = [];
        Queue::assertPushed(SendVoucherNotification::class, function (SendVoucherNotification $job) use (&$jobs): bool {
            $jobs[] = $job;

            return $job->templateKey === NotificationTemplate::KEY_VOUCHER_ISSUED;
        });
        $this->assertCount(2, $jobs);
        app()->call([$jobs[1], 'handle']);
        Mail::assertSent(TemplatedMail::class, static fn (TemplatedMail $mail): bool => $mail->voucherPdf !== null);
    }

    /** Q2: full redemption only with limits below the largest balance would leave vouchers that can never be used. */
    public function test_full_redemption_only_needs_limits_that_allow_the_largest_balance(): void
    {
        $this->actingAsStaff($this->restaurant(), RoleSlug::Owner);
        $this->putJson('/api/v1/settings/vouchers', ['allow_partial_redemption' => false, 'max_voucher_balance' => 50000, 'max_debit_per_transaction' => 25000])
            ->assertUnprocessable()->assertJsonValidationErrors('allow_partial_redemption');
        $this->putJson('/api/v1/settings/vouchers', ['allow_partial_redemption' => false, 'max_voucher_balance' => 25000, 'max_debit_per_transaction' => 25000, 'max_debit_per_voucher_per_day' => 25000])
            ->assertOk();
    }

    /** Q5: the voucher page offers "cancel sale" exactly when the server would allow it. */
    public function test_cancel_sale_is_offered_only_when_allowed(): void
    {
        Carbon::setTestNow('2026-10-06 10:00:00');
        $restaurant = $this->restaurant(['timezone' => 'Europe/Vienna']);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $id = (string) $this->postJson('/api/v1/vouchers', ['value' => 3000, 'form' => 'printable', 'payment' => $this->cashPayment()], $this->idempotency())->json('data.id');
        $this->getJson("/api/v1/vouchers/{$id}")->assertJsonPath('data.can_cancel_sale', true);

        Carbon::setTestNow('2026-10-06 10:16:00');
        $this->getJson("/api/v1/vouchers/{$id}")->assertJsonPath('data.can_cancel_sale', false);
        $this->postJson("/api/v1/vouchers/{$id}/cancellation", ['reason' => 'wrong amount'], $this->idempotency())->assertStatus(409)->assertJsonPath('context.reason', 'own_sale');

        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->getJson("/api/v1/vouchers/{$id}")->assertJsonPath('data.can_cancel_sale', true);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $this->assertNotTrue($this->getJson("/api/v1/vouchers/{$id}")->json('data.can_cancel_sale'));

        Carbon::setTestNow('2026-10-07 09:00:00');
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $this->getJson("/api/v1/vouchers/{$id}")->assertJsonPath('data.can_cancel_sale', false);
    }

    /** Q4: a cancellation repeated with the same key after a lost answer is answered with the booked one. */
    public function test_a_repeated_cancellation_is_the_same_one(): void
    {
        $this->actingAsStaff($this->restaurant(), RoleSlug::Manager);
        $id = (string) $this->postJson('/api/v1/vouchers', ['value' => 3000, 'form' => 'printable', 'payment' => $this->cashPayment()], $this->idempotency())->json('data.id');
        $key = $this->idempotency();
        $first = $this->postJson("/api/v1/vouchers/{$id}/cancellation", ['reason' => 'wrong amount'], $key)->assertSuccessful()->json('data.transaction.id');
        $again = $this->postJson("/api/v1/vouchers/{$id}/cancellation", ['reason' => 'wrong amount'], $key)->assertSuccessful()->json('data.transaction.id');
        $this->assertSame($first, $again);
    }

    /** Q7: a cancelled loyalty sale paid nothing back: no "refunded" e-mail. */
    public function test_a_cancelled_loyalty_sale_sends_no_refund_e_mail(): void
    {
        Queue::fake();
        $this->actingAsStaff($this->restaurant(), RoleSlug::Owner);
        $id = (string) $this->postJson('/api/v1/vouchers', [
            'value' => 3000, 'form' => 'printable', 'payment' => ['method' => 'complimentary', 'reason' => 'Regular'], 'customer' => ['email' => 'guest@example.com'],
        ], $this->idempotency())->json('data.id');
        $this->postJson("/api/v1/vouchers/{$id}/cancellation", ['reason' => 'wrong guest'], $this->idempotency())->assertSuccessful();

        Queue::assertNotPushed(SendVoucherNotification::class, static fn (SendVoucherNotification $job): bool => $job->templateKey === NotificationTemplate::KEY_VOUCHER_REFUNDED);
    }

    /** L3 + L5: loyalty is never money in exports and the cash-up. */
    public function test_loyalty_is_never_counted_as_money(): void
    {
        Carbon::setTestNow('2026-10-06 10:00:00');
        $restaurant = $this->restaurant(['timezone' => 'Europe/Vienna']);
        $owner = $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $loyal = $this->asTenant($restaurant, fn () => app(VoucherService::class)->sell(new Actor($owner), new IssueVoucherData(
            value: 2000, payment: new PaymentData(PaymentMethod::Complimentary, reason: 'Regular'), idempotencyKey: (string) Str::uuid(),
        )));
        // A loyalty top-up corrected by a colleague, and a loyalty sale cancelled the same day.
        $topUp = $this->postJson("/api/v1/vouchers/{$loyal->voucher->id}/reloads", ['amount' => 1000, 'payment' => ['method' => 'complimentary', 'reason' => 'Oktober']], $this->idempotency())->json('data.transaction.id');
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $this->postJson("/api/v1/transactions/{$topUp}/reverse", ['reason' => 'wrong card'])->assertCreated();
        $cancelled = (string) $this->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable', 'payment' => ['method' => 'complimentary', 'reason' => 'Mistake']], $this->idempotency())->json('data.id');
        $this->postJson("/api/v1/vouchers/{$cancelled}/cancellation", ['reason' => 'wrong guest'], $this->idempotency())->assertSuccessful();

        $day = $this->getJson('/api/v1/reports/cash-up?date=2026-10-06')->assertOk()->json('data');
        $this->assertSame(2000, $day['complimentary']);
        $this->assertSame(0, $day['reversed_reloads']);
        $this->assertSame(0, $day['total_received']);

        $payments = $this->get('/api/v1/reports/payments/export?from=2026-10-06&to=2026-10-06')->assertOk()->streamedContent();
        $this->assertStringContainsString('Loyalty value', $payments);
        $this->assertStringContainsString('Loyalty (no payment)', $payments);
        $this->assertStringNotContainsString('Received', $payments);
        $this->assertStringNotContainsString('Complimentary', $payments);

        $vouchers = $this->get('/api/v1/vouchers/export')->assertOk()->streamedContent();
        $this->assertStringContainsString(';Loyalty;', $vouchers);
    }

    /** Q8: a new QR for a lost voucher goes to the guest's e-mail as a PDF, the old one stops. */
    public function test_a_new_qr_is_emailed_to_the_guest_on_request(): void
    {
        Mail::fake();
        $this->actingAsStaff($this->restaurant(), RoleSlug::Manager);
        $id = (string) $this->postJson('/api/v1/vouchers', ['value' => 3000, 'form' => 'printable', 'payment' => $this->cashPayment()], $this->idempotency())->json('data.id');
        // Without the guest's e-mail there is nobody to send it to.
        $this->postJson("/api/v1/vouchers/{$id}/printable", ['reason' => 'lost', 'send' => true])->assertUnprocessable()->assertJsonValidationErrors('send');

        $withMail = (string) $this->postJson('/api/v1/vouchers', [
            'value' => 3000, 'form' => 'printable', 'payment' => $this->cashPayment(), 'customer' => ['email' => 'guest@example.com'],
        ], $this->idempotency())->json('data.id');
        Mail::assertSentCount(1);
        $this->postJson("/api/v1/vouchers/{$withMail}/printable", ['reason' => 'lost', 'send' => true])->assertCreated();
        Mail::assertSentCount(2);
        Mail::assertSent(TemplatedMail::class, static fn (TemplatedMail $mail): bool => $mail->hasTo('guest@example.com') && $mail->voucherPdf !== null);
    }
}
