<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Models\Customer;
use Tests\TestCase;

/**
 * One restaurant must never be able to see or touch another restaurant's data.
 */
final class TenantIsolationTest extends TestCase
{
    public function test_cards_of_other_restaurants_are_invisible(): void
    {
        $mine = $this->restaurant();
        $theirs = $this->restaurant();
        $myCard = $this->issueCard($mine);
        $foreignCard = $this->issueCard($theirs);

        $this->actingAsStaff($mine, RoleSlug::Owner);

        $this->getJson('/api/v1/cards')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $myCard->id);

        $this->getJson("/api/v1/cards/{$foreignCard->id}")->assertNotFound();
        $this->patchJson("/api/v1/cards/{$foreignCard->id}", ['notes' => 'hacked'])->assertNotFound();
        $this->postJson("/api/v1/cards/{$foreignCard->id}/redeem", ['amount' => 100], $this->idempotency())->assertNotFound();
        $this->postJson("/api/v1/cards/{$foreignCard->id}/block", ['reason' => 'test'])->assertNotFound();
    }

    public function test_foreign_card_scan_is_rejected_and_logged(): void
    {
        $mine = $this->restaurant();
        $theirs = $this->restaurant();
        $foreignCard = $this->issueCard($theirs);

        $this->actingAsStaff($mine, RoleSlug::Waiter);

        $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => 'https://app.giftcardpro.test/c/'.$foreignCard->public_token])
            ->assertForbidden()
            ->assertJsonPath('code', 'CARD_FOREIGN_RESTAURANT')
            ->assertJsonMissingPath('data');

        $this->assertDatabaseHas('nfc_scans', ['restaurant_id' => $mine->id, 'result' => 'foreign_restaurant', 'gift_card_id' => null]);
    }

    public function test_transfer_to_foreign_card_is_impossible(): void
    {
        $mine = $this->restaurant();
        $theirs = $this->restaurant();
        $myCard = $this->issueCard($mine);
        $foreignCard = $this->issueCard($theirs);

        $this->actingAsStaff($mine, RoleSlug::Owner);

        $this->postJson("/api/v1/cards/{$myCard->id}/transfer", ['target_card_id' => $foreignCard->id], $this->idempotency())
            ->assertStatus(422)
            ->assertJsonValidationErrors('target_card_id');

        $this->postJson("/api/v1/cards/{$myCard->id}/transfer", ['target_card_number' => $foreignCard->card_number], $this->idempotency())
            ->assertNotFound();
    }

    public function test_customers_and_users_are_isolated(): void
    {
        $mine = $this->restaurant();
        $theirs = $this->restaurant();
        $foreignCustomer = Customer::factory()->create(['restaurant_id' => $theirs->id]);
        $foreignUser = $this->staff($theirs, RoleSlug::Waiter);

        $this->actingAsStaff($mine, RoleSlug::Owner);

        $this->getJson("/api/v1/customers/{$foreignCustomer->id}")->assertNotFound();
        $this->getJson('/api/v1/customers')->assertJsonCount(0, 'data');
        $this->getJson("/api/v1/users/{$foreignUser->id}")->assertNotFound();
        $this->postJson("/api/v1/users/{$foreignUser->id}/deactivate")->assertNotFound();

        $this->postJson('/api/v1/cards', ['value' => 5000, 'customer_id' => $foreignCustomer->id])
            ->assertStatus(422)->assertJsonValidationErrors('customer_id');
    }

    public function test_cards_cannot_be_looked_up_by_number_across_restaurants(): void
    {
        $mine = $this->restaurant();
        $theirs = $this->restaurant();
        $foreignCard = $this->issueCard($theirs);

        $this->actingAsStaff($mine, RoleSlug::Waiter);

        $this->postJson('/api/v1/scan', ['method' => 'manual', 'card_number' => $foreignCard->card_number])
            ->assertNotFound()->assertJsonPath('code', 'CARD_NOT_FOUND');
    }
}
