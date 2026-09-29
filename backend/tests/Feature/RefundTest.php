<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Data\IssueVoucherData;
use App\Data\PaymentData;
use App\Enums\CardState;
use App\Enums\PaymentMethod;
use App\Enums\RoleSlug;
use App\Jobs\SendVoucherNotification;
use App\Models\Customer;
use App\Models\NotificationTemplate;
use App\Models\Payment;
use App\Models\Restaurant;
use App\Models\SecurityAlert;
use App\Models\Voucher;
use App\Services\Vouchers\VoucherService;
use App\Support\Actor;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\Sanctum;
use Tests\Support\WithCards;
use Tests\TestCase;

/** Refund: the remaining balance goes back to the guest, never more than was paid, and the voucher closes. */
final class RefundTest extends TestCase
{
    use WithCards;

    private Restaurant $restaurant;

    protected function setUp(): void
    {
        parent::setUp();
        $this->restaurant = $this->restaurant();
    }

    private function refund(Voucher $voucher, array $payment = ['method' => 'cash'], ?string $key = null): TestResponse
    {
        return $this->postJson("/api/v1/vouchers/{$voucher->id}/refund", ['payment' => $payment, 'reason' => 'Guest returned the voucher'], $this->idempotency($key));
    }

    public function test_an_untouched_sale_is_paid_back_and_the_voucher_closes(): void
    {
        Queue::fake();
        $customer = Customer::factory()->create(['restaurant_id' => $this->restaurant->id, 'email' => 'gast@example.com']);
        $sale = $this->sell($this->restaurant, 5000, customerId: $customer->id);
        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);

        $this->getJson("/api/v1/vouchers/{$sale->voucher->id}")->assertOk()->assertJsonPath('data.refundable', 5000);
        $key = (string) Str::uuid();
        $first = $this->refund($sale->voucher, key: $key)->assertCreated()
            ->assertJsonPath('data.voucher.status', 'refunded')
            ->assertJsonPath('data.voucher.balance', 0)
            ->assertJsonPath('data.transaction.type', 'refund')
            ->assertJsonPath('data.transaction.amount', -5000)
            ->assertJsonPath('data.transaction.reversible', false)
            ->assertJsonPath('data.transaction.payment.direction', 'out')
            ->assertJsonPath('data.transaction.payment.amount', 5000);
        // A lost answer, retried: the same refund, not a second payout.
        $this->refund($sale->voucher, key: $key)->assertOk()->assertJsonPath('replayed', true)
            ->assertJsonPath('data.transaction.id', $first->json('data.transaction.id'));
        $this->assertSame(1, Payment::query()->where('voucher_id', $sale->voucher->id)->where('direction', 'out')->count());

        // Closed for good: nothing spends, reloads, reverses or refunds it again.
        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        $this->present($sale->printable->payload)->assertStatus(422);
        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        $this->postJson("/api/v1/vouchers/{$sale->voucher->id}/reloads", ['amount' => 100, 'payment' => ['method' => 'cash']], $this->idempotency())->assertStatus(422);
        $this->postJson('/api/v1/transactions/'.$first->json('data.transaction.id').'/reverse', ['reason' => 'undo'])->assertStatus(409);
        foreach (['unblock' => [], 'block' => ['reason' => 'reopen it'], 'expire' => ['reason' => 'close it']] as $action => $body) {
            $this->assertContains($this->postJson("/api/v1/vouchers/{$sale->voucher->id}/{$action}", $body)->status(), [409, 422], $action);
        }
        $this->assertSame('refunded', $sale->voucher->refresh()->status->value);
        $this->refund($sale->voucher)->assertStatus(422);

        Queue::assertPushed(SendVoucherNotification::class, static fn (SendVoucherNotification $j): bool => $j->templateKey === NotificationTemplate::KEY_VOUCHER_REFUNDED);
        $this->assertLedgerConsistent($sale->voucher);
        $this->artisan('giftcard:verify-chains')->assertSuccessful();
        $this->assertSame(0, $this->getJson('/api/v1/dashboard/stats')->json('data.monthly_revenue'), 'the payout is not revenue');
    }

    public function test_only_money_actually_received_is_paid_back(): void
    {
        $owner = $this->staff($this->restaurant, RoleSlug::Owner);
        $gift = $this->asTenant($this->restaurant, fn () => app(VoucherService::class)->sell(new Actor($owner), new IssueVoucherData(
            value: 3000,
            payment: new PaymentData(PaymentMethod::Complimentary, reason: 'Birthday of a regular'),
            idempotencyKey: (string) Str::uuid(),
        )));
        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);

        // Nothing paid for: nothing to pay back.
        $this->refund($gift->voucher)->assertStatus(422)->assertJsonPath('code', 'VOUCHER_NOT_REFUNDABLE');

        // Paid reload of 2000, 1000 spent: of the 4000 left only the 2000 paid in go back; the rest is forfeited.
        $this->postJson("/api/v1/vouchers/{$gift->voucher->id}/reloads", ['amount' => 2000, 'payment' => ['method' => 'cash']], $this->idempotency())->assertCreated();
        $this->redeemWithQr($gift->voucher, $gift->printable->payload, 1000)->assertCreated();
        $this->getJson("/api/v1/vouchers/{$gift->voucher->id}")->assertJsonPath('data.refundable', 2000);
        $this->refund($gift->voucher)->assertCreated()
            ->assertJsonPath('data.transaction.amount', -4000)
            ->assertJsonPath('data.transaction.payment.amount', 2000);
        $this->assertLedgerConsistent($gift->voucher);
    }

    public function test_refunds_are_the_owners_and_need_proof_for_non_cash(): void
    {
        $voucher = $this->issueVoucher($this->restaurant, 5000);
        $this->actingAsStaff($this->restaurant, RoleSlug::Manager);
        $this->refund($voucher)->assertForbidden();
        $this->getJson("/api/v1/vouchers/{$voucher->id}")->assertJsonMissingPath('data.refundable');

        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        $this->refund($voucher, ['method' => 'card_terminal'])->assertStatus(422)->assertJsonValidationErrors('payment.reference');
        $this->refund($voucher, ['method' => 'complimentary'])->assertStatus(422)->assertJsonValidationErrors('payment.method');
        $this->postJson("/api/v1/vouchers/{$voucher->id}/refund", ['payment' => ['method' => 'cash']], $this->idempotency())->assertStatus(422)->assertJsonValidationErrors('reason');
        $this->refund($voucher, ['method' => 'bank_transfer', 'reference' => 'AT-2026-0042'])->assertCreated();
        $this->assertSame(0, $voucher->refresh()->balance);
    }

    public function test_a_card_voucher_refund_revokes_the_card_and_many_refunds_raise_an_alert(): void
    {
        $this->setUpCardKeystore();
        try {
            [$card, $voucher] = $this->activeCardVoucher($this->restaurant, 3000);
            $owner = $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
            $this->refund($voucher)->assertCreated();
            $this->assertSame(CardState::Revoked, $card->refresh()->state);
            $this->tapCard($this->chip($card), 'spend')->assertStatus(422)->assertJsonPath('code', 'CARD_NOT_USABLE');

            foreach ([1, 2] as $i) {
                $this->refund($this->issueVoucher($this->restaurant, 1000 * $i))->assertCreated();
            }
            $this->artisan('giftcard:monitor-security-events')->assertSuccessful();
            $this->assertSame('user:'.$owner->id, SecurityAlert::query()->where('rule', 'money.refunds')->sole()->subject);
        } finally {
            $this->tearDownCardKeystore();
        }
    }

    private function cancel(Voucher $voucher, ?string $reference = null): TestResponse
    {
        return $this->postJson("/api/v1/vouchers/{$voucher->id}/cancellation", ['reason' => 'Wrong amount typed', 'reference' => $reference], $this->idempotency());
    }

    public function test_a_manager_cancels_a_mistaken_sale_and_the_money_goes_back_the_same_way(): void
    {
        $manager = $this->actingAsStaff($this->restaurant, RoleSlug::Manager);
        $id = $this->postJson('/api/v1/vouchers', ['value' => 50000, 'form' => 'printable', 'payment' => ['method' => 'card_terminal', 'reference' => 'T-881']], $this->idempotency())
            ->assertCreated()->json('data.id');
        $voucher = Voucher::query()->findOrFail($id);

        $this->cancel($voucher)->assertStatus(422);
        $this->cancel($voucher, 'T-881-STORNO')->assertCreated()
            ->assertJsonPath('data.voucher.status', 'refunded')
            ->assertJsonPath('data.transaction.payment.method', 'card_terminal')
            ->assertJsonPath('data.transaction.payment.direction', 'out')
            ->assertJsonPath('data.transaction.payment.amount', 50000);
        $this->assertSame(0, $this->getJson('/api/v1/dashboard/stats')->json('data.monthly_revenue'));
        $this->assertLedgerConsistent($voucher);
        $this->assertNotNull($manager);
    }

    public function test_a_used_old_or_own_late_sale_is_not_cancelled_by_the_same_person(): void
    {
        $seller = $this->staff($this->restaurant, RoleSlug::Manager);
        $used = $this->sell($this->restaurant, 3000, $seller);
        $late = $this->sell($this->restaurant, 2000, $seller);
        $gift = $this->asTenant($this->restaurant, fn () => app(VoucherService::class)->sell(new Actor($this->staff($this->restaurant, RoleSlug::Owner)), new IssueVoucherData(
            value: 1500, payment: new PaymentData(PaymentMethod::Complimentary, reason: 'Sorry for the wait'), idempotencyKey: (string) Str::uuid(),
        )));
        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        $this->redeemWithQr($used->voucher, $used->printable->payload, 100)->assertCreated();

        Sanctum::actingAs($seller, ['*']);
        $this->cancel($used->voucher)->assertStatus(409)->assertJsonPath('context.reason', 'not_cancellable');
        $this->travel(20)->minutes();
        $this->cancel($late->voucher)->assertStatus(409)->assertJsonPath('context.reason', 'own_sale');

        // A second manager may; a complimentary sale closes without a payout.
        $this->actingAsStaff($this->restaurant, RoleSlug::Manager);
        $this->cancel($late->voucher)->assertCreated()->assertJsonPath('data.transaction.payment.method', 'cash');
        $this->cancel($gift->voucher)->assertCreated()->assertJsonPath('data.transaction.payment', null)->assertJsonPath('data.voucher.balance', 0);

        // Tomorrow it is the owner's refund, not a cancellation.
        $next = $this->sell($this->restaurant, 1000);
        $this->travel(1)->days();
        $this->cancel($next->voucher)->assertStatus(409)->assertJsonPath('context.reason', 'not_cancellable');
        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        $this->cancel($next->voucher)->assertForbidden();
        $this->artisan('giftcard:seal-security-events')->assertSuccessful();
        $this->artisan('giftcard:verify-chains')->assertSuccessful();
    }
}
