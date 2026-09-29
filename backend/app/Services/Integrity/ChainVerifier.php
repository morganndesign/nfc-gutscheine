<?php

declare(strict_types=1);

namespace App\Services\Integrity;

use App\Models\AuditLog;
use App\Models\Contracts\HashChainedRecord;
use App\Models\Payment;
use App\Models\Voucher;
use App\Models\VoucherTransaction;
use App\Services\Security\SecurityEventSealer;
use App\Support\HashChain;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

/**
 * Recomputes every hash chain and every voucher balance (architecture §13.1: "a nightly verifier recomputes
 * balances and chains"), and every seal of the security event stream. Detects a changed, deleted, inserted or reordered row, a chain head that does not
 * match its last row, a ledger row whose arithmetic is wrong and a voucher whose balance differs from its ledger.
 */
final class ChainVerifier
{
    public function __construct(private readonly SecurityEventSealer $securityEvents) {}

    /** @var list<class-string<Model&HashChainedRecord>> */
    public const CHAINED = [Payment::class, VoucherTransaction::class, AuditLog::class];

    /**
     * @return list<string> Problems found; empty when everything is intact.
     */
    public function verify(): array
    {
        $connection = DB::connection();
        if ($connection->getDriverName() !== 'mysql' || $connection->transactionLevel() > 0) {
            return $this->verifyAll();
        }

        // One consistent snapshot for the whole run. Writes committed meanwhile (a sale adds payment, ledger and
        // audit rows and moves their chain heads) would otherwise show up as a head ahead of its rows or a balance
        // that differs from its ledger. The server default is READ COMMITTED, so the level is set for this
        // transaction only.
        $connection->statement('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ');
        $connection->unprepared('START TRANSACTION WITH CONSISTENT SNAPSHOT, READ ONLY');
        try {
            return $this->verifyAll();
        } finally {
            $connection->unprepared('COMMIT');
        }
    }

    /**
     * @return list<string>
     */
    private function verifyAll(): array
    {
        $problems = [];

        foreach (self::CHAINED as $class) {
            array_push($problems, ...$this->verifyChains($class));
        }

        array_push($problems, ...$this->verifyBalances());
        array_push($problems, ...$this->securityEvents->verify());

        return $problems;
    }

    /**
     * @param  class-string<Model&HashChainedRecord>  $class
     * @return list<string>
     */
    private function verifyChains(string $class): array
    {
        $chain = $class::chainName();
        $problems = [];

        $heads = DB::table('chain_heads')->where('chain', $chain)->get()->keyBy('scope');
        $scopes = $class::query()->withoutGlobalScopes()->distinct()->pluck('chain_scope')
            ->merge($heads->keys())->unique()->values();

        foreach ($scopes as $scope) {
            $expectedSeq = 1;
            $prev = HashChain::GENESIS;

            $rows = $class::query()->withoutGlobalScopes()
                ->where('chain_scope', $scope)
                ->lazyById(1000, 'chain_seq', 'chain_seq');

            foreach ($rows as $row) {
                /** @var Model&HashChainedRecord $row */
                $seq = (int) $row->getAttribute('chain_seq');
                $where = "{$chain}/{$scope}#{$seq}";

                if ($seq !== $expectedSeq) {
                    $problems[] = "{$where}: expected sequence {$expectedSeq} (a row is missing or was inserted).";
                    $expectedSeq = $seq;
                }
                if (! hash_equals($prev, (string) $row->getAttribute('prev_hash'))) {
                    $problems[] = "{$where}: prev_hash does not match the previous row.";
                }

                $recomputed = HashChain::entryHash($row, $chain, (string) $scope, $seq, (string) $row->getAttribute('prev_hash'));
                if (! hash_equals($recomputed, (string) $row->getAttribute('entry_hash'))) {
                    $problems[] = "{$where}: content does not match its hash (the row was changed).";
                }

                $prev = (string) $row->getAttribute('entry_hash');
                $expectedSeq++;
            }

            $head = $heads->get($scope);
            $lastSeq = $expectedSeq - 1;
            if ($head === null) {
                $problems[] = "{$chain}/{$scope}: chain head is missing.";
            } elseif ((int) $head->seq !== $lastSeq || ! hash_equals($prev, (string) $head->head_hash)) {
                $problems[] = "{$chain}/{$scope}: chain head (#{$head->seq}) does not match the last row (#{$lastSeq}); rows were deleted or the head was changed.";
            }
        }

        return $problems;
    }

    /**
     * Every ledger row: balance_after = balance_before + amount, each row continues the previous row of its
     * voucher, no balance below zero, and the voucher's balance equals its last row.
     *
     * @return list<string>
     */
    private function verifyBalances(): array
    {
        $problems = [];
        /** @var array<string, int> $last */
        $last = [];

        $rows = VoucherTransaction::query()->withoutGlobalScopes()
            ->orderBy('chain_scope')
            ->orderBy('chain_seq')
            ->cursor();

        foreach ($rows as $tx) {
            /** @var VoucherTransaction $tx */
            $where = "voucher_transactions/{$tx->chain_scope}#{$tx->chain_seq}";

            if ($tx->balance_after !== $tx->balance_before + $tx->amount) {
                $problems[] = "{$where}: balance_after is not balance_before + amount.";
            }
            if ($tx->balance_after < 0) {
                $problems[] = "{$where}: negative balance.";
            }
            $previous = $last[$tx->voucher_id] ?? 0;
            if ($tx->balance_before !== $previous) {
                $problems[] = "{$where}: balance_before does not continue the previous entry of the voucher.";
            }
            $last[$tx->voucher_id] = $tx->balance_after;
        }

        Voucher::query()->withoutGlobalScopes()->select(['id', 'balance'])->chunkById(1000, static function ($vouchers) use (&$problems, $last): void {
            foreach ($vouchers as $voucher) {
                /** @var Voucher $voucher */
                $ledger = $last[$voucher->id] ?? 0;
                if ($voucher->balance !== $ledger) {
                    $problems[] = "vouchers/{$voucher->id}: balance {$voucher->balance} differs from its ledger ({$ledger}).";
                }
            }
        });

        return $problems;
    }
}
