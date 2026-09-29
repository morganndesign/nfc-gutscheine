<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use Illuminate\Support\Carbon;
use Tests\TestCase;

/** End-of-day cash-up and the payments export: every cent received and paid out, per method and person. */
final class CashUpTest extends TestCase
{
    public function test_the_day_adds_up_per_method_and_person_and_the_liability_is_exact(): void
    {
        Carbon::setTestNow('2026-10-02 10:00:00');
        $restaurant = $this->restaurant(['timezone' => 'Europe/Vienna']);
        $anna = $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $cash = $this->postJson('/api/v1/vouchers', ['value' => 5000, 'form' => 'printable', 'payment' => ['method' => 'cash']], $this->idempotency())->json('data.id');
        $this->postJson('/api/v1/vouchers', ['value' => 3000, 'form' => 'printable', 'payment' => ['method' => 'card_terminal', 'reference' => 'T-1']], $this->idempotency())->assertCreated();
        // A reload booked by mistake and corrected by a colleague: not money kept.
        $reload = $this->postJson("/api/v1/vouchers/{$cash}/reloads", ['amount' => 2000, 'payment' => ['method' => 'cash']], $this->idempotency())->json('data.transaction.id');
        $ben = $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson("/api/v1/transactions/{$reload}/reverse", ['reason' => 'typo'])->assertCreated();
        // The owner pays one voucher back.
        $owner = $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $refunded = $this->postJson('/api/v1/vouchers', ['value' => 1000, 'form' => 'printable', 'payment' => ['method' => 'cash']], $this->idempotency())->json('data.id');
        $this->postJson("/api/v1/vouchers/{$refunded}/refund", ['payment' => ['method' => 'cash'], 'reason' => 'returned'], $this->idempotency())->assertCreated();
        $this->postJson('/api/v1/vouchers', ['value' => 2500, 'form' => 'printable', 'payment' => ['method' => 'complimentary', 'reason' => 'Regular']], $this->idempotency())->assertCreated();

        $day = $this->getJson('/api/v1/reports/cash-up?date=2026-10-02')->assertOk()->json('data');
        $this->assertSame([
            ['method' => 'card_terminal', 'received' => 3000, 'paid_out' => 0, 'net' => 3000, 'payments' => 1],
            ['method' => 'cash', 'received' => 6000, 'paid_out' => 1000, 'net' => 5000, 'payments' => 3],
        ], $day['methods']);
        $this->assertSame(2000, $day['reversed_reloads']);
        $this->assertSame(2500, $day['complimentary']);
        $this->assertSame(5000 + 3000 + 2500, $day['outstanding_end_of_day']);
        $byPerson = collect($day['staff'])->mapWithKeys(fn (array $s): array => [$s['user']['id'].'|'.$s['method'] => [$s['received'], $s['paid_out']]]);
        $this->assertSame([5000, 0], $byPerson[$anna->id.'|cash']);
        $this->assertSame([3000, 0], $byPerson[$anna->id.'|card_terminal']);
        $this->assertSame([1000, 1000], $byPerson[$owner->id.'|cash']);
        $this->assertFalse($byPerson->has($ben->id.'|cash'));

        // A later day does not change an earlier close; the liability of the earlier day stays what it was.
        Carbon::setTestNow('2026-10-03 11:00:00');
        $this->postJson('/api/v1/vouchers', ['value' => 4000, 'form' => 'printable', 'payment' => ['method' => 'cash']], $this->idempotency())->assertCreated();
        $this->assertSame(10500, $this->getJson('/api/v1/reports/cash-up?date=2026-10-02')->json('data.outstanding_end_of_day'));
        $this->assertSame(14500, $this->getJson('/api/v1/reports/cash-up')->json('data.outstanding_end_of_day'));
        $this->getJson('/api/v1/reports/cash-up?date=2099-01-01')->assertStatus(422);

        $csv = $this->get('/api/v1/reports/payments/export?from=2026-10-02&to=2026-10-02')->assertOk()->streamedContent();
        $this->assertSame(6, substr_count($csv, "\n") - 1, 'five payments in, one out');
        $this->assertStringContainsString('Paid out', $csv);
        $this->assertStringContainsString('T-1', $csv);

        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $this->getJson('/api/v1/reports/cash-up')->assertForbidden();
    }
}
