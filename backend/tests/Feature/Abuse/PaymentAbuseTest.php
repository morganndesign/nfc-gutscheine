<?php

declare(strict_types=1);

namespace Tests\Feature\Abuse;

use App\Enums\RoleSlug;
use App\Models\Payment;
use App\Models\Voucher;
use Tests\TestCase;

/**
 * Invariant 3: no voucher gets value without a payment record; complimentary value needs the owner and a reason.
 */
final class PaymentAbuseTest extends TestCase
{
    public function test_a_sale_without_payment_is_refused(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        foreach ([[], ['payment' => []], ['payment' => ['method' => 'online_psp']], ['payment' => ['method' => 'iou']], ['payment' => ['method' => 'cash', 'extra' => 1]]] as $body) {
            $this->withHeaders($this->idempotency())->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable'] + $body)
                ->assertStatus(422);
        }
        // A card sale needs the tapped card's presentment.
        $this->withHeaders($this->idempotency())->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'card', 'payment' => ['method' => 'cash']])
            ->assertStatus(422)->assertJsonValidationErrors('presentment_id');

        $this->assertSame(0, Voucher::query()->count());
    }

    public function test_terminal_and_bank_payments_need_a_reference(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        foreach (['card_terminal', 'bank_transfer'] as $method) {
            $this->withHeaders($this->idempotency())->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable', 'payment' => ['method' => $method]])
                ->assertStatus(422)->assertJsonValidationErrors('payment.reference');
        }
    }

    public function test_only_the_owner_issues_complimentary_vouchers_and_always_with_a_reason(): void
    {
        $restaurant = $this->restaurant();
        $body = ['value' => 5000, 'form' => 'printable', 'payment' => ['method' => 'complimentary', 'reason' => 'Raffle prize']];

        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->withHeaders($this->idempotency())->postJson('/api/v1/vouchers', $body)
            ->assertStatus(403)->assertJsonPath('code', 'COMPLIMENTARY_NOT_ALLOWED');

        $owner = $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $this->withHeaders($this->idempotency())->postJson('/api/v1/vouchers', ['payment' => ['method' => 'complimentary']] + $body)
            ->assertStatus(422)->assertJsonValidationErrors('payment.reason');
        $this->withHeaders($this->idempotency())->postJson('/api/v1/vouchers', $body)->assertCreated()
            ->assertJsonPath('payment.method', 'complimentary')
            ->assertJsonPath('payment.reason', 'Raffle prize');

        $this->assertSame($owner->id, Payment::query()->sole()->approved_by);
    }

    public function test_complimentary_value_is_not_revenue(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $this->withHeaders($this->idempotency())->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable', 'payment' => ['method' => 'complimentary', 'reason' => 'Marketing']])->assertCreated();
        $this->withHeaders($this->idempotency())->postJson('/api/v1/vouchers', ['value' => 3000, 'form' => 'printable', 'payment' => ['method' => 'cash']])->assertCreated();

        $this->getJson('/api/v1/dashboard/stats')->assertOk()
            ->assertJsonPath('data.monthly_revenue', 3000)
            ->assertJsonPath('data.outstanding_balance', 8000);
    }
}
