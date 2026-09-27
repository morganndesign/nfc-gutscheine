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
        $a = $this->issueCard($restaurant, 5000);
        $this->issueCard($restaurant, 2500);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson("/api/v1/cards/{$a->id}/redeem", ['amount' => 5000], $this->idempotency());

        $this->getJson('/api/v1/dashboard/stats')
            ->assertOk()
            ->assertJsonPath('data.cards_sold', 2)
            ->assertJsonPath('data.cards_active', 1)
            ->assertJsonPath('data.cards_redeemed', 1)
            ->assertJsonPath('data.outstanding_balance', 2500)
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

    public function test_card_search_filters_and_sorting(): void
    {
        $restaurant = $this->restaurant();
        $customer = Customer::factory()->create(['restaurant_id' => $restaurant->id, 'last_name' => 'Wittgenstein']);
        $withCustomer = $this->issueCard($restaurant, 9000, null, ['customer_id' => $customer->id]);
        $other = $this->issueCard($restaurant, 1000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->getJson('/api/v1/cards?search=wittgen')->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $withCustomer->id);
        $this->getJson('/api/v1/cards?search='.substr($other->card_number, -6))->assertJsonPath('data.0.id', $other->id);
        $this->getJson('/api/v1/cards?sort=-balance')->assertJsonPath('data.0.id', $withCustomer->id);
        $this->getJson('/api/v1/cards?sort=balance')->assertJsonPath('data.0.id', $other->id);
        $this->getJson('/api/v1/cards?status=redeemed')->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/cards?min_balance=5000')->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/cards?sort=password')->assertJsonValidationErrors('sort');
        $this->getJson('/api/v1/cards?search='.urlencode("%' OR 'a'='a' --"))->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_csv_exports_are_streamed_and_sanitized(): void
    {
        $restaurant = $this->restaurant();
        $this->issueCard($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson('/api/v1/cards', ['value' => 1000, 'notes' => '=HYPERLINK("http://evil")'])->assertCreated();

        $cards = $this->get('/api/v1/cards/export')->assertOk()->assertHeader('Content-Type', 'text/csv; charset=UTF-8');
        $csv = $cards->streamedContent();
        $this->assertStringContainsString('"Card number";Status', $csv);
        $this->assertStringContainsString("'=HYPERLINK", $csv);

        $tx = $this->get('/api/v1/transactions/export')->assertOk()->streamedContent();
        $this->assertSame(3, count(explode("\n", trim($tx)))); // header + 2 issue transactions
    }

    public function test_customer_management_and_gdpr_anonymisation(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $id = $this->postJson('/api/v1/customers', ['first_name' => 'Klara', 'last_name' => 'Wolf', 'email' => 'klara@example.com'])
            ->assertCreated()->json('data.id');
        $this->postJson('/api/v1/cards', ['value' => 5000, 'customer_id' => $id, 'recipient_name' => 'Klara'])->assertCreated();

        $this->getJson("/api/v1/customers/{$id}")->assertOk()->assertJsonCount(1, 'gift_cards')->assertJsonPath('data.gift_cards_balance', 5000);

        $this->postJson("/api/v1/customers/{$id}/anonymize")->assertOk()->assertJsonPath('data.email', null)->assertJsonPath('data.anonymized', true);
        $this->assertDatabaseMissing('customers', ['email' => 'klara@example.com']);
        $this->assertDatabaseMissing('gift_cards', ['recipient_name' => 'Klara']);
        $this->assertDatabaseHas('gift_cards', ['customer_id' => $id, 'balance' => 5000]);
    }

    public function test_transactions_listing_and_filters(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson("/api/v1/cards/{$card->id}/redeem", ['amount' => 1000, 'reference' => 'Bill 991'], $this->idempotency());

        $this->getJson('/api/v1/transactions')->assertOk()->assertJsonCount(2, 'data');
        $this->getJson('/api/v1/transactions?type=redemption')->assertJsonCount(1, 'data')->assertJsonPath('data.0.reference', 'Bill 991');
        $this->getJson('/api/v1/transactions?search=Bill')->assertJsonCount(1, 'data');
    }
}
