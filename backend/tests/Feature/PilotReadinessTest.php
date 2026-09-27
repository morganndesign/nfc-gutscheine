<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Enums\TransactionType;
use App\Models\GiftCardTransaction;
use App\Support\CardNumber;
use Tests\TestCase;

/**
 * Behaviour changed while preparing the first pilot restaurant (wording and owner-facing numbers).
 */
final class PilotReadinessTest extends TestCase
{
    public function test_dashboard_reports_the_number_of_cards_carrying_the_liability(): void
    {
        $restaurant = $this->restaurant();
        $this->issueCard($restaurant, 5000);
        $this->issueCard($restaurant, 2500);
        $empty = $this->issueCard($restaurant, 1000);
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $this->postJson("/api/v1/cards/{$empty->id}/redeem", ['amount' => 1000], $this->idempotency())->assertCreated();

        $this->getJson('/api/v1/dashboard/stats')->assertOk()
            ->assertJsonPath('data.outstanding_balance', 7500)
            ->assertJsonPath('data.outstanding_cards', 2)
            ->assertJsonPath('data.monthly_redeemed', 1000);
    }

    public function test_new_devices_are_named_after_hardware_and_browser_not_the_person(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $iphone = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1';

        $this->withHeaders(['X-Device-Id' => 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 'User-Agent' => $iphone])
            ->getJson('/api/v1/devices/current')
            ->assertOk()
            ->assertJsonPath('data.name', 'iPhone · Safari');
    }

    public function test_replacement_ledger_notes_use_the_printed_card_number_format(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant, 4000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $newId = $this->postJson("/api/v1/cards/{$card->id}/replace", ['reason' => 'Lost'])->assertCreated()->json('data.id');

        $in = GiftCardTransaction::query()->withoutGlobalScopes()->where('gift_card_id', $newId)->where('type', TransactionType::TransferIn->value)->firstOrFail();
        $out = GiftCardTransaction::query()->withoutGlobalScopes()->where('gift_card_id', $card->id)->where('type', TransactionType::TransferOut->value)->firstOrFail();

        $this->assertSame('Replacement for '.CardNumber::format($card->card_number), $in->note);
        $this->assertStringStartsWith('Replaced by ', (string) $out->note);
        $this->assertStringEndsWith(': Lost', (string) $out->note);
    }

    public function test_exports_use_readable_status_and_type_names(): void
    {
        $restaurant = $this->restaurant();
        $this->issueCard($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $this->assertStringContainsString(';Active;', $this->get('/api/v1/cards/export')->assertOk()->streamedContent());
        $this->assertStringContainsString(';Sale;', $this->get('/api/v1/transactions/export')->assertOk()->streamedContent());
    }
}
