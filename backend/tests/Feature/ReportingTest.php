<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Models\Customer;
use Tests\TestCase;

final class ReportingTest extends TestCase
{
    public function test_dashboard_statistics(): void
    {
        $restaurant = $this->restaurant();
        $a = $this->sell($restaurant, 5000);
        $this->issueVoucher($restaurant, 2500);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->redeemWithQr($a->voucher, $a->printable->payload, 5000)->assertCreated();

        $this->getJson('/api/v1/dashboard/stats')
            ->assertOk()
            ->assertJsonPath('data.vouchers_sold', 2)
            ->assertJsonPath('data.vouchers_active', 2)
            ->assertJsonPath('data.vouchers_empty', 1)
            ->assertJsonPath('data.outstanding_balance', 2500)
            ->assertJsonPath('data.outstanding_vouchers', 1)
            ->assertJsonPath('data.monthly_revenue', 7500)
            ->assertJsonPath('data.today_redeemed', 5000)
            ->assertJsonPath('data.today_transactions', 3);

        $charts = $this->getJson('/api/v1/dashboard/charts?days=7')->assertOk();
        $this->assertCount(7, $charts->json('data.daily'));
        $this->assertCount(12, $charts->json('data.monthly'));
        $this->assertSame(7500, collect($charts->json('data.daily'))->sum('sold'));
        $this->assertSame(5000, collect($charts->json('data.daily'))->sum('redeemed'));

        $this->getJson('/api/v1/dashboard/activity')->assertOk()->assertJsonCount(3, 'data');
    }

    public function test_reversed_redemptions_do_not_count(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $tx = $this->redeemWithQr($sale->voucher, $sale->printable->payload, 2000)->json('data.transaction.id');
        $this->postJson("/api/v1/transactions/{$tx}/reverse", ['reason' => 'Wrong voucher'])->assertCreated();

        $this->getJson('/api/v1/dashboard/stats')->assertOk()
            ->assertJsonPath('data.today_redeemed', 0)
            ->assertJsonPath('data.outstanding_balance', 5000);
        $this->assertSame(0, collect($this->getJson('/api/v1/dashboard/charts?days=7')->json('data.daily'))->sum('redeemed'));
    }

    public function test_voucher_search_filters_and_sorting(): void
    {
        $restaurant = $this->restaurant();
        $customer = Customer::factory()->create(['restaurant_id' => $restaurant->id, 'last_name' => 'Wittgenstein']);
        $withCustomer = $this->sell($restaurant, 9000, null, $customer->id)->voucher;
        $other = $this->issueVoucher($restaurant, 1000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->getJson('/api/v1/vouchers?search=wittgen')->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $withCustomer->id);
        $this->getJson('/api/v1/vouchers?search='.substr($other->voucher_number, -6))->assertJsonPath('data.0.id', $other->id);
        $this->getJson('/api/v1/vouchers?sort=-balance')->assertJsonPath('data.0.id', $withCustomer->id);
        $this->getJson('/api/v1/vouchers?sort=balance')->assertJsonPath('data.0.id', $other->id);
        $this->getJson('/api/v1/vouchers?status=expired')->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/vouchers?kind=digital')->assertJsonCount(2, 'data');
        $this->getJson('/api/v1/vouchers?min_balance=5000')->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/vouchers?sort=password')->assertJsonValidationErrors('sort');
        $this->getJson('/api/v1/vouchers?search='.urlencode("%' OR 'a'='a' --"))->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_csv_exports_are_streamed_and_sanitized(): void
    {
        $restaurant = $this->restaurant();
        $this->issueVoucher($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson('/api/v1/vouchers', ['value' => 1000, 'form' => 'printable', 'payment' => $this->cashPayment(), 'notes' => '=HYPERLINK("http://evil")'], $this->idempotency())->assertCreated();

        $export = $this->get('/api/v1/vouchers/export')->assertOk()->assertHeader('Content-Type', 'text/csv; charset=UTF-8');
        $csv = $export->streamedContent();
        $this->assertStringContainsString('"Voucher number";Kind;Status', $csv);
        $this->assertStringContainsString("'=HYPERLINK", $csv);

        $tx = $this->get('/api/v1/transactions/export')->assertOk()->streamedContent();
        $this->assertSame(3, count(explode("\n", trim($tx)))); // header + 2 sales
        $this->assertStringContainsString('"Payment method"', $tx);
    }

    public function test_customer_management_and_gdpr_anonymisation(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $id = $this->postJson('/api/v1/customers', ['first_name' => 'Klara', 'last_name' => 'Wolf', 'email' => 'klara@example.com'])
            ->assertCreated()->json('data.id');
        $this->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable', 'payment' => $this->cashPayment(), 'customer_id' => $id, 'recipient_name' => 'Klara'], $this->idempotency())->assertCreated();

        $this->getJson("/api/v1/customers/{$id}")->assertOk()->assertJsonCount(1, 'vouchers')->assertJsonPath('data.vouchers_balance', 5000);

        $this->postJson("/api/v1/customers/{$id}/anonymize")->assertOk()->assertJsonPath('data.email', null)->assertJsonPath('data.anonymized', true);
        $this->assertDatabaseMissing('customers', ['email' => 'klara@example.com']);
        $this->assertDatabaseMissing('vouchers', ['recipient_name' => 'Klara']);
        $this->assertDatabaseHas('vouchers', ['customer_id' => $id, 'balance' => 5000]);
    }

    public function test_transactions_listing_and_filters(): void
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $presentment = $this->present($sale->printable->payload)->json('data.id');
        $this->postJson("/api/v1/vouchers/{$sale->voucher->id}/redemptions", ['amount' => 1000, 'presentment_id' => $presentment, 'reference' => 'Bill 991'], $this->idempotency())->assertCreated();

        $this->getJson('/api/v1/transactions')->assertOk()->assertJsonCount(2, 'data');
        $this->getJson('/api/v1/transactions?type=redemption')->assertJsonCount(1, 'data')->assertJsonPath('data.0.reference', 'Bill 991');
        $this->getJson('/api/v1/transactions?search=Bill')->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/transactions?type=issue')->assertJsonPath('data.0.payment.method', 'cash');
    }
}
