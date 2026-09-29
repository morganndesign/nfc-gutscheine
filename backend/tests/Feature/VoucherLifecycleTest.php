<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Enums\TransactionType;
use App\Enums\VoucherStatus;
use App\Exceptions\Domain\ImmutableRecordException;
use App\Models\AuditLog;
use App\Models\Medium;
use App\Models\Payment;
use App\Models\Voucher;
use App\Models\VoucherTransaction;
use App\Services\Media\PrintableQrService;
use App\Services\Vouchers\VoucherService;
use App\Support\Actor;
use Illuminate\Database\QueryException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

final class VoucherLifecycleTest extends TestCase
{
    public function test_manager_sells_a_printable_voucher_with_payment_ledger_and_qr(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $response = $this->withHeaders($this->idempotency())->postJson('/api/v1/vouchers', [
            'value' => 5000,
            'form' => 'printable',
            'payment' => ['method' => 'card_terminal', 'reference' => 'T-4711'],
            'recipient_name' => 'Maria',
        ]);

        $response->assertCreated()
            ->assertHeader('Cache-Control', 'no-store, private')
            ->assertJsonPath('data.kind', 'digital')
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.balance', 5000)
            ->assertJsonPath('data.expires_at', null)
            ->assertJsonPath('transaction.type', 'issue')
            ->assertJsonPath('transaction.amount', 5000)
            ->assertJsonPath('payment.method', 'card_terminal')
            ->assertJsonPath('payment.reference', 'T-4711')
            ->assertJsonPath('replayed', false);

        $payload = (string) $response->json('printable.payload');
        $this->assertMatchesRegularExpression('/^GCPV1\.[A-Za-z0-9_-]{43}$/', $payload);
        $this->assertStringStartsWith('<?xml', (string) $response->json('printable.qr_svg'));

        $voucher = Voucher::query()->findOrFail($response->json('data.id'));
        $this->assertSame(16, strlen($voucher->voucher_number));
        $this->assertLedgerConsistent($voucher);

        // The secret is stored only as its hash, and never in the audit trail.
        $medium = Medium::query()->where('voucher_id', $voucher->id)->sole();
        $this->assertSame(PrintableQrService::hashOf($payload), $medium->secret_hash);
        $this->assertDatabaseMissing('media', ['secret_hash' => $payload]);
        $this->assertFalse(AuditLog::query()->get()->contains(static fn (AuditLog $l): bool => str_contains(json_encode($l->toArray()) ?: '', substr($payload, 6))));

        $payment = Payment::query()->where('voucher_id', $voucher->id)->sole();
        $this->assertSame(5000, $payment->amount);
        $this->assertSame($payment->id, VoucherTransaction::query()->where('voucher_id', $voucher->id)->sole()->payment_id);
    }

    public function test_voucher_values_follow_the_restaurant_limits(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant);

        $sell = fn (int $value) => $this->withHeaders($this->idempotency())->postJson('/api/v1/vouchers', [
            'value' => $value, 'form' => 'printable', 'payment' => $this->cashPayment(),
        ]);

        $sell(100)->assertStatus(422)->assertJsonPath('code', 'INVALID_AMOUNT');
        $sell(50001)->assertStatus(422)->assertJsonPath('code', 'INVALID_AMOUNT');
        $sell(50000)->assertCreated();
    }

    public function test_vouchers_do_not_expire_unless_the_restaurant_sets_a_validity_of_at_least_three_years(): void
    {
        Carbon::setTestNow('2026-10-01 12:00:00');
        $restaurant = $this->restaurant(['timezone' => 'Europe/Vienna']);
        $this->assertNull($this->issueVoucher($restaurant)->expires_at);

        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $this->putJson('/api/v1/settings/vouchers', ['validity_months' => 24])->assertStatus(422)->assertJsonValidationErrors('validity_months');
        $this->putJson('/api/v1/settings/vouchers', ['validity_months' => 36])->assertOk()->assertJsonPath('data.validity_months', 36);

        $voucher = $this->issueVoucher($restaurant->refresh());
        $this->assertSame('2029-10-01 23:59:59', $voucher->expires_at?->timezone('Europe/Vienna')->format('Y-m-d H:i:s'));
    }

    public function test_partial_and_full_redemption_with_a_scanned_qr(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $this->redeemWithQr($sale->voucher, $sale->printable->payload, 1250)
            ->assertCreated()
            ->assertJsonPath('data.voucher.balance', 3750)
            ->assertJsonPath('data.transaction.amount', -1250);

        $this->redeemWithQr($sale->voucher, $sale->printable->payload, 3750)
            ->assertCreated()
            ->assertJsonPath('data.voucher.balance', 0)
            ->assertJsonPath('data.voucher.status', 'active')
            ->assertJsonPath('data.voucher.actions.redeem', false);

        // Empty is not a status: the QR still presents, but there is nothing to redeem.
        $presentment = $this->present($sale->printable->payload)->assertCreated()->assertJsonPath('data.voucher.balance', 0)->json('data.id');
        $this->withHeaders($this->idempotency())->postJson("/api/v1/vouchers/{$sale->voucher->id}/redemptions", ['amount' => 1, 'presentment_id' => $presentment])
            ->assertStatus(422)->assertJsonPath('code', 'INSUFFICIENT_BALANCE');

        $this->assertLedgerConsistent($sale->voucher);
    }

    public function test_redemption_rejects_invalid_and_loose_amounts(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $presentment = (string) $this->present($sale->printable->payload)->json('data.id');
        $key = $this->idempotency();
        // Raw JSON bodies: the test client would turn 10.0 into 10.
        $redeem = fn (string $amountJson) => $this->call('POST', "/api/v1/vouchers/{$sale->voucher->id}/redemptions", [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_IDEMPOTENCY_KEY' => $key['Idempotency-Key'],
        ], '{"amount":'.$amountJson.',"presentment_id":"'.$presentment.'"}');

        // Audit P9: only strict integers in minor units.
        foreach (['0', '-5', '"100"', '10.0', 'true', '1e2', '" 100"', '12.5'] as $amount) {
            $redeem($amount)->assertStatus(422)->assertJsonValidationErrors('amount');
        }
        $redeem('6000')->assertStatus(422)->assertJsonPath('code', 'INSUFFICIENT_BALANCE');

        $this->assertSame(5000, $sale->voucher->refresh()->balance);
    }

    public function test_full_redemption_only_setting(): void
    {
        $restaurant = $this->restaurant();
        $restaurant->settings->forceFill(['allow_partial_redemption' => false])->save();
        $sale = $this->sell($restaurant, 3000);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $this->redeemWithQr($sale->voucher, $sale->printable->payload, 1000)->assertStatus(422)->assertJsonPath('code', 'INVALID_AMOUNT');
        $this->redeemWithQr($sale->voucher, $sale->printable->payload, 3000)->assertCreated();
    }

    public function test_debit_limits_per_transaction_and_per_day(): void
    {
        Carbon::setTestNow('2026-10-01 10:00:00');
        $restaurant = $this->restaurant();
        $restaurant->settings->forceFill(['max_debit_per_transaction' => 3000, 'max_debit_per_voucher_per_day' => 5000])->save();
        $sale = $this->sell($restaurant, 20000);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $qr = $sale->printable->payload;

        $this->redeemWithQr($sale->voucher, $qr, 3001)->assertStatus(422)
            ->assertJsonPath('code', 'DEBIT_LIMIT_EXCEEDED')->assertJsonPath('context.limit', 'per_transaction');
        $this->redeemWithQr($sale->voucher, $qr, 3000)->assertCreated();
        $this->redeemWithQr($sale->voucher, $qr, 2500)->assertStatus(422)
            ->assertJsonPath('code', 'DEBIT_LIMIT_EXCEEDED')->assertJsonPath('context.remaining', 2000);
        $this->redeemWithQr($sale->voucher, $qr, 2000)->assertCreated();

        Carbon::setTestNow('2026-10-02 10:00:00');
        $this->redeemWithQr($sale->voucher, $qr, 3000)->assertCreated();
    }

    public function test_blocked_and_expired_vouchers_cannot_be_redeemed(): void
    {
        $restaurant = $this->restaurant();
        $blocked = $this->sell($restaurant);
        $expired = $this->sell($restaurant);
        $owner = $this->staff($restaurant, RoleSlug::Owner);

        Sanctum::actingAs($owner, ['*']);
        $this->postJson("/api/v1/vouchers/{$blocked->voucher->id}/block", ['reason' => 'Reported stolen'])->assertOk()->assertJsonPath('data.status', 'blocked');
        $this->postJson("/api/v1/vouchers/{$expired->voucher->id}/expire", ['reason' => 'Test'])->assertOk()->assertJsonPath('data.status', 'expired');

        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $this->redeemWithQr($blocked->voucher, $blocked->printable->payload, 100)->assertStatus(422)->assertJsonPath('code', 'VOUCHER_BLOCKED');
        $this->redeemWithQr($expired->voucher, $expired->printable->payload, 100)->assertStatus(422)->assertJsonPath('code', 'VOUCHER_EXPIRED');
    }

    public function test_reload_needs_a_payment_and_respects_the_balance_cap(): void
    {
        $restaurant = $this->restaurant();
        $voucher = $this->issueVoucher($restaurant, 40000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $reload = fn (array $body) => $this->withHeaders($this->idempotency())->postJson("/api/v1/vouchers/{$voucher->id}/reloads", $body);

        $reload(['amount' => 5000])->assertStatus(422)->assertJsonValidationErrors('payment');
        $reload(['amount' => 5000, 'payment' => ['method' => 'card_terminal']])->assertStatus(422)->assertJsonValidationErrors('payment.reference');
        $reload(['amount' => 10001, 'payment' => $this->cashPayment()])->assertStatus(422)->assertJsonPath('code', 'BALANCE_LIMIT_EXCEEDED');
        $reload(['amount' => 10000, 'payment' => $this->cashPayment()])
            ->assertCreated()
            ->assertJsonPath('data.voucher.balance', 50000)
            ->assertJsonPath('data.transaction.payment.method', 'cash');

        $restaurant->settings->forceFill(['allow_reload' => false])->save();
        $reload(['amount' => 100, 'payment' => $this->cashPayment()])->assertStatus(422)->assertJsonPath('code', 'RELOAD_NOT_ALLOWED');

        $this->assertSame(2, Payment::query()->where('voucher_id', $voucher->id)->count());
        $this->assertLedgerConsistent($voucher);
    }

    public function test_a_redemption_is_reversed_once_by_a_new_entry(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $txId = $this->redeemWithQr($sale->voucher, $sale->printable->payload, 2000)->json('data.transaction.id');

        $this->postJson("/api/v1/transactions/{$txId}/reverse", ['reason' => 'Wrong table'])
            ->assertCreated()
            ->assertJsonPath('data.type', 'reversal')
            ->assertJsonPath('data.amount', 2000)
            ->assertJsonPath('data.related_transaction_id', $txId);

        $this->getJson("/api/v1/transactions/{$txId}")->assertOk()
            ->assertJsonPath('data.reversed', true)
            ->assertJsonPath('data.reversible', false);

        $this->postJson("/api/v1/transactions/{$txId}/reverse", ['reason' => 'Again'])
            ->assertStatus(409)->assertJsonPath('code', 'TRANSACTION_NOT_REVERSIBLE');

        $this->assertSame(5000, $sale->voucher->refresh()->balance);
        $this->assertSame(0, $sale->voucher->total_redeemed);
        $this->assertLedgerConsistent($sale->voucher);
    }

    public function test_reversing_a_redemption_cannot_exceed_the_balance_cap(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant, 50000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $txId = $this->redeemWithQr($sale->voucher, $sale->printable->payload, 20000)->json('data.transaction.id');
        $this->withHeaders($this->idempotency())->postJson("/api/v1/vouchers/{$sale->voucher->id}/reloads", ['amount' => 20000, 'payment' => $this->cashPayment()])->assertCreated();

        // Audit P8a: the reversal would bring the balance to 70 000 against a cap of 50 000.
        $this->postJson("/api/v1/transactions/{$txId}/reverse", ['reason' => 'Mistake'])
            ->assertStatus(422)->assertJsonPath('code', 'BALANCE_LIMIT_EXCEEDED');
        $this->assertSame(50000, $sale->voucher->refresh()->balance);
    }

    public function test_a_manager_cannot_reverse_a_reload_they_booked_themselves(): void
    {
        $restaurant = $this->restaurant();
        $voucher = $this->sell($restaurant, 5000)->voucher;
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $txId = $this->withHeaders($this->idempotency())->postJson("/api/v1/vouchers/{$voucher->id}/reloads", ['amount' => 3000, 'payment' => $this->cashPayment()])
            ->assertCreated()->json('data.transaction.id');

        // Took the cash, then takes the balance back: refused (and not offered).
        $this->getJson("/api/v1/transactions/{$txId}")->assertOk()->assertJsonPath('data.reversible', false);
        $this->postJson("/api/v1/transactions/{$txId}/reverse", ['reason' => 'Mistake'])
            ->assertStatus(409)->assertJsonPath('code', 'TRANSACTION_NOT_REVERSIBLE')->assertJsonPath('context.reason', 'own_reload');
        $this->assertSame(8000, $voucher->refresh()->balance);

        // A second manager (four eyes) reverses it.
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->getJson("/api/v1/transactions/{$txId}")->assertOk()->assertJsonPath('data.reversible', true);
        $this->postJson("/api/v1/transactions/{$txId}/reverse", ['reason' => 'Mistake'])->assertCreated();
        $this->assertSame(5000, $voucher->refresh()->balance);
        $this->assertLedgerConsistent($voucher);
    }

    public function test_an_owner_may_reverse_their_own_reload(): void
    {
        $restaurant = $this->restaurant();
        $voucher = $this->sell($restaurant, 5000)->voucher;
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $txId = $this->withHeaders($this->idempotency())->postJson("/api/v1/vouchers/{$voucher->id}/reloads", ['amount' => 3000, 'payment' => $this->cashPayment()])
            ->assertCreated()->json('data.transaction.id');
        $this->postJson("/api/v1/transactions/{$txId}/reverse", ['reason' => 'Mistake'])->assertCreated();
    }

    public function test_a_lost_sheet_gets_a_new_qr_and_the_old_one_stops(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $this->postJson("/api/v1/vouchers/{$sale->voucher->id}/printable", ['reason' => 'Guest lost it'])->assertForbidden();

        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $new = $this->postJson("/api/v1/vouchers/{$sale->voucher->id}/printable", ['reason' => 'Guest lost it'])->assertCreated()
            ->assertHeader('Cache-Control', 'no-store, private')
            ->assertJsonPath('data.balance', 5000)
            ->json('printable.payload');
        $this->assertNotSame($sale->printable->payload, $new);
        $this->postJson("/api/v1/vouchers/{$sale->voucher->id}/printable", [])->assertStatus(422);

        // The found old sheet pays nothing; the new one pays.
        $this->present($sale->printable->payload)->assertStatus(422);
        $this->redeemWithQr($sale->voucher, (string) $new, 1500)->assertCreated()->assertJsonPath('data.voucher.balance', 3500);
    }

    public function test_sales_cannot_be_reversed(): void
    {
        $restaurant = $this->restaurant();
        $voucher = $this->issueVoucher($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $issue = VoucherTransaction::query()->where('voucher_id', $voucher->id)->sole();
        $this->postJson("/api/v1/transactions/{$issue->id}/reverse", ['reason' => 'Refund'])
            ->assertStatus(409)->assertJsonPath('code', 'TRANSACTION_NOT_REVERSIBLE');
    }

    public function test_expiry_keeps_the_balance_and_an_owner_can_reinstate(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant, 8000);
        $voucher = $sale->voucher;

        // Audit P7: managers cannot expire vouchers.
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson("/api/v1/vouchers/{$voucher->id}/expire", ['reason' => 'x'])->assertForbidden();

        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $this->postJson("/api/v1/vouchers/{$voucher->id}/expire", [])->assertStatus(422)->assertJsonValidationErrors('reason');
        $this->postJson("/api/v1/vouchers/{$voucher->id}/expire", ['reason' => 'Guest asked for a refund in cash'])
            ->assertOk()
            ->assertJsonPath('data.status', 'expired')
            ->assertJsonPath('data.balance', 8000);

        // Audit P6: no write-off entry, the ledger still sums to the balance.
        $this->assertSame(1, VoucherTransaction::query()->where('voucher_id', $voucher->id)->count());

        $this->postJson("/api/v1/vouchers/{$voucher->id}/reinstate", ['reason' => 'Refund cancelled', 'expires_on' => '2020-01-01'])
            ->assertStatus(422)->assertJsonValidationErrors('expires_on');
        $this->postJson("/api/v1/vouchers/{$voucher->id}/reinstate", ['reason' => 'Refund cancelled'])
            ->assertOk()
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.balance', 8000)
            ->assertJsonPath('data.expires_at', null);

        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $this->redeemWithQr($voucher, $sale->printable->payload, 8000)->assertCreated();
    }

    public function test_nightly_expiry_keeps_balances_and_skips_blocked_vouchers(): void
    {
        Carbon::setTestNow('2026-10-01 12:00:00');
        $restaurant = $this->restaurant();
        $restaurant->settings->forceFill(['validity_months' => 36])->save();
        $active = $this->issueVoucher($restaurant, 6000);
        $blocked = $this->issueVoucher($restaurant, 7000);
        $this->asTenant($restaurant, fn () => app(VoucherService::class)
            ->block(new Actor($this->staff($restaurant)), $blocked, 'Lost'));

        Carbon::setTestNow('2029-10-02 01:00:00');
        $this->artisan('vouchers:expire')->assertSuccessful();

        $this->assertSame(VoucherStatus::Expired, $active->refresh()->status);
        $this->assertSame(6000, $active->balance);
        $this->assertSame(VoucherStatus::Blocked, $blocked->refresh()->status);

        // Unblocking after the expiry date applies the expiry; the balance stays.
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson("/api/v1/vouchers/{$blocked->id}/unblock")->assertOk()->assertJsonPath('data.status', 'expired')->assertJsonPath('data.balance', 7000);
        $this->assertSame(0, VoucherTransaction::query()->where('type', '!=', TransactionType::Issue->value)->count());
    }

    public function test_voucher_history_merges_ledger_and_events(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->redeemWithQr($sale->voucher, $sale->printable->payload, 1000)->assertCreated();
        $this->postJson("/api/v1/vouchers/{$sale->voucher->id}/block", ['reason' => 'Suspicious'])->assertOk();

        $history = $this->getJson("/api/v1/vouchers/{$sale->voucher->id}/history")->assertOk()->json('data');
        $types = array_column($history, 'type');

        $this->assertContains('issue', $types);
        $this->assertContains('redemption', $types);
        $this->assertContains('voucher.blocked', $types);
        $this->assertContains('medium.issued', array_column(
            AuditLog::query()->where('action', 'medium.issued')->get(['action'])->toArray(),
            'action',
        ));
        $this->assertSame('cash', collect($history)->firstWhere('type', 'issue')['payment_method']);
    }

    public function test_voucher_detail_lists_media_and_payments_without_secrets(): void
    {
        $restaurant = $this->restaurant();
        $voucher = $this->issueVoucher($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $response = $this->getJson("/api/v1/vouchers/{$voucher->id}")->assertOk()
            ->assertJsonPath('data.media.0.type', 'printable_qr')
            ->assertJsonPath('data.media.0.status', 'active')
            ->assertJsonPath('data.payments.0.method', 'cash');

        $this->assertStringNotContainsString('secret', (string) $response->getContent());
    }

    public function test_financial_history_rejects_updates_and_deletes(): void
    {
        $restaurant = $this->restaurant();
        $voucher = $this->issueVoucher($restaurant);
        $tx = VoucherTransaction::query()->withoutGlobalScopes()->where('voucher_id', $voucher->id)->sole();

        foreach (['voucher_transactions', 'payments', 'audit_logs'] as $table) {
            try {
                DB::table($table)->limit(1)->update(['created_at' => now()]);
                $this->fail("UPDATE on {$table} must be rejected.");
            } catch (QueryException $e) {
                $this->assertStringContainsString('append-only', $e->getMessage());
            }
            try {
                DB::table($table)->delete();
                $this->fail("DELETE on {$table} must be rejected.");
            } catch (QueryException $e) {
                $this->assertStringContainsString('append-only', $e->getMessage());
            }
        }

        $this->expectException(ImmutableRecordException::class);
        $tx->forceFill(['amount' => 1])->save();
    }
}
