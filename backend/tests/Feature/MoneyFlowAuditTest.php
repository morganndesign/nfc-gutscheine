<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Models\Payment;
use App\Models\VoucherTransaction;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Tests\TestCase;

/** Production audit (money and voucher flows): defects found and fixed before the first restaurant goes live. */
final class MoneyFlowAuditTest extends TestCase
{
    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    public function test_a_redemption_of_a_refunded_voucher_cannot_be_reversed(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $redemption = $this->redeemWithQr($sale->voucher, $sale->printable->payload, 2000)->assertCreated()->json('data.transaction.id');

        // The owner pays the remaining 3000 back and closes the voucher.
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $this->postJson("/api/v1/vouchers/{$sale->voucher->id}/refund", ['payment' => ['method' => 'cash'], 'reason' => 'Guest returned it'], $this->idempotency())->assertCreated();

        // Reversing the old redemption would put 2000 back on a closed voucher nobody can use or refund.
        $this->getJson("/api/v1/transactions/{$redemption}")->assertOk()->assertJsonPath('data.reversible', false);
        $this->postJson("/api/v1/transactions/{$redemption}/reverse", ['reason' => 'Wrong table'])
            ->assertStatus(409)->assertJsonPath('code', 'TRANSACTION_NOT_REVERSIBLE');

        $voucher = $sale->voucher->refresh();
        $this->assertSame('refunded', $voucher->status->value);
        $this->assertSame(0, $voucher->balance);
        $this->assertLedgerConsistent($voucher);
    }

    public function test_a_manager_cannot_revive_an_expired_voucher_by_blocking_and_unblocking_it(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $this->postJson("/api/v1/vouchers/{$sale->voucher->id}/expire", ['reason' => 'Paid back in kind'])->assertOk()->assertJsonPath('data.status', 'expired');

        // Reinstating is the owner's (audit P7); block + unblock must not be a way around it.
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson("/api/v1/vouchers/{$sale->voucher->id}/block", ['reason' => 'Suspicious'])->assertOk()->assertJsonPath('data.status', 'blocked');
        $this->postJson("/api/v1/vouchers/{$sale->voucher->id}/unblock")->assertOk()->assertJsonPath('data.status', 'expired');

        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $this->redeemWithQr($sale->voucher, $sale->printable->payload, 1000)->assertStatus(422)->assertJsonPath('code', 'VOUCHER_EXPIRED');
        $this->assertSame(5000, $sale->voucher->refresh()->balance);
    }

    public function test_a_blocked_active_voucher_returns_to_active(): void
    {
        $restaurant = $this->restaurant();
        $voucher = $this->issueVoucher($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson("/api/v1/vouchers/{$voucher->id}/block", ['reason' => 'Suspicious'])->assertOk();
        $this->postJson("/api/v1/vouchers/{$voucher->id}/unblock")->assertOk()->assertJsonPath('data.status', 'active')->assertJsonPath('data.expired_at', null);
    }

    public function test_a_reload_key_reused_with_another_payment_method_is_a_conflict(): void
    {
        $restaurant = $this->restaurant();
        $voucher = $this->issueVoucher($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $key = $this->idempotency();
        $url = "/api/v1/vouchers/{$voucher->id}/reloads";

        $this->withHeaders($key)->postJson($url, ['amount' => 2000, 'payment' => ['method' => 'cash']])->assertCreated();
        // A genuine retry replays.
        $this->withHeaders($key)->postJson($url, ['amount' => 2000, 'payment' => ['method' => 'cash']])->assertOk()->assertJsonPath('replayed', true);
        // Same key, other money: the till would show "paid by card" for a cash booking (cash-up off by 2000).
        $this->withHeaders($key)->postJson($url, ['amount' => 2000, 'payment' => ['method' => 'card_terminal', 'reference' => 'T-77']])
            ->assertStatus(409)->assertJsonPath('code', 'IDEMPOTENCY_CONFLICT');

        $this->assertSame(7000, $voucher->refresh()->balance);
    }

    public function test_a_sale_key_reused_with_another_payment_method_or_form_is_a_conflict(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $key = $this->idempotency();

        $first = $this->withHeaders($key)->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable', 'payment' => ['method' => 'cash']])->assertCreated();
        $this->withHeaders($key)->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable', 'payment' => ['method' => 'card_terminal', 'reference' => 'T-1']])
            ->assertStatus(409)->assertJsonPath('code', 'IDEMPOTENCY_CONFLICT');
        $this->withHeaders($key)->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'card', 'presentment_id' => (string) Str::uuid(), 'payment' => ['method' => 'cash']])
            ->assertStatus(409)->assertJsonPath('code', 'IDEMPOTENCY_CONFLICT');

        // The conflicting attempts neither replaced the QR of the first sale nor booked anything.
        $this->present((string) $first->json('printable.payload'))->assertCreated();
        $this->assertSame(1, Payment::query()->count());
    }

    public function test_a_refund_key_reused_with_another_payout_method_is_a_conflict(): void
    {
        $restaurant = $this->restaurant();
        $voucher = $this->issueVoucher($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $key = $this->idempotency();
        $url = "/api/v1/vouchers/{$voucher->id}/refund";

        $this->withHeaders($key)->postJson($url, ['payment' => ['method' => 'cash'], 'reason' => 'Returned'])->assertCreated();
        $this->withHeaders($key)->postJson($url, ['payment' => ['method' => 'cash'], 'reason' => 'Returned'])->assertOk()->assertJsonPath('replayed', true);
        $this->withHeaders($key)->postJson($url, ['payment' => ['method' => 'bank_transfer', 'reference' => 'AT-1'], 'reason' => 'Returned'])
            ->assertStatus(409)->assertJsonPath('code', 'IDEMPOTENCY_CONFLICT');
    }

    public function test_a_reversal_on_a_later_day_does_not_change_an_earlier_cash_up(): void
    {
        Carbon::setTestNow('2026-10-02 10:00:00');
        $restaurant = $this->restaurant(['timezone' => 'Europe/Vienna']);
        $voucher = $this->issueVoucher($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $reload = $this->postJson("/api/v1/vouchers/{$voucher->id}/reloads", ['amount' => 2000, 'payment' => ['method' => 'cash']], $this->idempotency())->json('data.transaction.id');

        $closed = $this->getJson('/api/v1/reports/cash-up?date=2026-10-02')->assertOk()->json('data');
        $this->assertSame(7000, $closed['total_received']);

        // Next day a colleague reverses the reload. The 2 October close was 7000 in the drawer and stays so;
        // the correction shows on the day it was made.
        Carbon::setTestNow('2026-10-03 09:00:00');
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson("/api/v1/transactions/{$reload}/reverse", ['reason' => 'typo'])->assertCreated();

        $this->assertSame($closed, $this->getJson('/api/v1/reports/cash-up?date=2026-10-02')->assertOk()->json('data'));
        $this->assertSame(2000, $this->getJson('/api/v1/reports/cash-up?date=2026-10-03')->json('data.reversed_reloads'));
    }

    public function test_todays_cash_up_is_available_right_after_local_midnight(): void
    {
        // 00:30 in Vienna on 3 October is still 2 October in UTC.
        Carbon::setTestNow('2026-10-02 22:30:00');
        $restaurant = $this->restaurant(['timezone' => 'Europe/Vienna']);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->getJson('/api/v1/reports/cash-up?date=2026-10-03')->assertOk()->assertJsonPath('data.date', '2026-10-03');
        $this->getJson('/api/v1/reports/cash-up?date=2026-10-04')->assertStatus(422);
    }

    public function test_the_cash_up_day_follows_vienna_local_time_on_the_25_hour_dst_day(): void
    {
        $restaurant = $this->restaurant(['timezone' => 'Europe/Vienna']);
        $seller = $this->staff($restaurant, RoleSlug::Manager);
        // 25 October 2026: clocks go back at 03:00 CEST, the local day lasts 25 hours (22:00 UTC on the 24th to 23:00 UTC on the 25th).
        foreach (['2026-10-24 21:59:59' => 100, '2026-10-24 22:00:00' => 200, '2026-10-25 22:59:59' => 400, '2026-10-25 23:00:00' => 800] as $at => $value) {
            Carbon::setTestNow($at);
            $this->sell($restaurant, $value + 1000, $seller);
        }

        Carbon::setTestNow('2026-10-27 12:00:00');
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->assertSame(1200 + 1400, $this->getJson('/api/v1/reports/cash-up?date=2026-10-25')->json('data.total_received'));
        $this->assertSame(1100, $this->getJson('/api/v1/reports/cash-up?date=2026-10-24')->json('data.total_received'));
        $this->assertSame(1800, $this->getJson('/api/v1/reports/cash-up?date=2026-10-26')->json('data.total_received'));
    }

    public function test_the_payments_export_neutralises_formulas_in_free_text(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $this->postJson('/api/v1/vouchers', ['value' => 1000, 'form' => 'printable', 'payment' => ['method' => 'card_terminal', 'reference' => '=HYPERLINK("http://x")']], $this->idempotency())->assertCreated();
        $this->postJson('/api/v1/vouchers', ['value' => 1000, 'form' => 'printable', 'payment' => ['method' => 'complimentary', 'reason' => '@SUM(A1:A9)']], $this->idempotency())->assertCreated();

        $today = Carbon::now($restaurant->timezone)->toDateString();
        $csv = $this->get("/api/v1/reports/payments/export?from={$today}&to={$today}")->assertOk()->streamedContent();
        $this->assertStringContainsString("'=HYPERLINK", $csv);
        $this->assertStringContainsString("'@SUM", $csv);
        $this->assertStringNotContainsString(';=', $csv);
        $this->assertStringNotContainsString(';@', $csv);
    }

    public function test_chart_revenue_is_money_kept_like_the_kpi(): void
    {
        Carbon::setTestNow('2026-10-02 10:00:00');
        $restaurant = $this->restaurant(['timezone' => 'Europe/Vienna']);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable', 'payment' => ['method' => 'cash']], $this->idempotency())->assertCreated();
        // Sold by mistake and cancelled at once: the money went back, it is no revenue.
        $wrong = $this->postJson('/api/v1/vouchers', ['value' => 9000, 'form' => 'printable', 'payment' => ['method' => 'cash']], $this->idempotency())->json('data.id');
        $this->postJson("/api/v1/vouchers/{$wrong}/cancellation", ['reason' => 'Wrong amount'], $this->idempotency())->assertCreated();

        $this->assertSame(5000, $this->getJson('/api/v1/dashboard/stats')->json('data.monthly_revenue'));
        $charts = $this->getJson('/api/v1/dashboard/charts?days=7')->assertOk()->json('data');
        $this->assertSame(5000, collect($charts['daily'])->firstWhere('date', '2026-10-02')['sold']);
        $this->assertSame(5000, collect($charts['monthly'])->firstWhere('month', '2026-10')['revenue']);
        // The cancellation (refund entry, payout, revoked QR) keeps every chain and balance intact.
        $this->artisan('giftcard:verify-chains')->assertSuccessful();
    }

    public function test_charts_put_each_transaction_on_its_local_day_across_a_dst_change(): void
    {
        $restaurant = $this->restaurant(['timezone' => 'Europe/Vienna']);
        // 00:30 local on 1 October (summer time, UTC+2) is 22:30 UTC on 30 September.
        Carbon::setTestNow('2026-09-30 22:30:00');
        $this->sell($restaurant, 4000);

        // Viewed in winter time (UTC+1): the sale still belongs to 1 October and to October.
        Carbon::setTestNow('2026-11-10 12:00:00');
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $charts = $this->getJson('/api/v1/dashboard/charts?days=90')->assertOk()->json('data');
        $daily = collect($charts['daily'])->keyBy('date');
        $this->assertSame(4000, $daily['2026-10-01']['sold']);
        $this->assertSame(0, $daily['2026-09-30']['sold']);
        $monthly = collect($charts['monthly'])->keyBy('month');
        $this->assertSame(4000, $monthly['2026-10']['revenue']);
        $this->assertSame(0, $monthly['2026-09']['revenue']);
        $this->assertSame(1, VoucherTransaction::query()->count());
    }
}
