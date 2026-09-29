<?php

declare(strict_types=1);

namespace Tests\Feature\Abuse;

use App\Enums\RoleSlug;
use App\Models\Voucher;
use App\Models\VoucherTransaction;
use App\Services\Integrity\ChainVerifier;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Tamper evidence (architecture §13.1): the nightly verifier detects any change to the append-only tables,
 * even one made by someone who bypassed the triggers (e.g. with database administrator rights).
 */
final class IntegrityTest extends TestCase
{
    public function test_an_untouched_history_verifies(): void
    {
        $this->history();

        $this->assertSame([], app(ChainVerifier::class)->verify());
        $this->artisan('giftcard:verify-chains')->assertSuccessful();
    }

    public function test_a_changed_amount_is_detected(): void
    {
        [$voucher] = $this->history();

        $this->withoutTriggers('voucher_transactions', static function () use ($voucher): void {
            DB::table('voucher_transactions')->where('voucher_id', $voucher->id)->where('type', 'redemption')->update(['amount' => -1]);
        });

        $problems = app(ChainVerifier::class)->verify();
        $this->assertNotEmpty(array_filter($problems, static fn (string $p): bool => str_contains($p, 'changed')));
        $this->artisan('giftcard:verify-chains')->assertFailed();
    }

    public function test_a_deleted_row_is_detected(): void
    {
        $this->history();

        $this->withoutTriggers('audit_logs', static function (): void {
            DB::table('audit_logs')->orderByDesc('chain_seq')->limit(1)->delete();
        });

        $this->assertNotEmpty(array_filter(app(ChainVerifier::class)->verify(), static fn (string $p): bool => str_contains($p, 'chain head')));
    }

    public function test_a_voucher_balance_that_differs_from_its_ledger_is_detected(): void
    {
        [$voucher] = $this->history();
        DB::table('vouchers')->where('id', $voucher->id)->update(['balance' => 999999]);

        $this->assertNotEmpty(array_filter(app(ChainVerifier::class)->verify(), static fn (string $p): bool => str_contains($p, 'differs from its ledger')));
    }

    public function test_a_payment_method_changed_to_complimentary_is_detected(): void
    {
        $this->history();

        $this->withoutTriggers('payments', static function (): void {
            DB::table('payments')->update(['method' => 'complimentary']);
        });

        $this->assertNotEmpty(array_filter(app(ChainVerifier::class)->verify(), static fn (string $p): bool => str_starts_with($p, 'payments/')));
    }

    /** @return array{0: Voucher} */
    private function history(): array
    {
        $restaurant = $this->restaurant();
        $sale = $this->sell($restaurant, 5000);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->redeemWithQr($sale->voucher, $sale->printable->payload, 1200)->assertCreated();
        $this->withHeaders($this->idempotency())->postJson("/api/v1/vouchers/{$sale->voucher->id}/reloads", ['amount' => 1000, 'payment' => $this->cashPayment()])->assertCreated();
        $this->assertSame(3, VoucherTransaction::query()->count());

        return [$sale->voucher];
    }

    /** Simulates an attacker with database administrator rights. */
    private function withoutTriggers(string $table, callable $tamper): void
    {
        DB::unprepared("DROP TRIGGER {$table}_no_update");
        DB::unprepared("DROP TRIGGER {$table}_no_delete");
        $tamper();
    }
}
