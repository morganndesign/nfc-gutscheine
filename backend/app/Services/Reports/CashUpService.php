<?php

declare(strict_types=1);

namespace App\Services\Reports;

use App\Enums\PaymentDirection;
use App\Enums\PaymentMethod;
use App\Enums\TransactionType;
use App\Models\Payment;
use App\Models\User;
use App\Models\VoucherTransaction;
use App\Services\Vouchers\VoucherService;
use App\Support\Tenancy\TenantContext;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * End-of-day cash-up for one local calendar day of the restaurant: the voucher money received and paid out per
 * payment method and per staff member, what was booked and corrected again (reversed paid reloads: a correction of
 * a booking error, not a payout — decision 2026-10-06), loyalty value given (less loyalty sales cancelled that day),
 * and the balance owed to guests at the end of the day (from the ledger, so any past day is exact).
 */
final class CashUpService
{
    public function __construct(private readonly TenantContext $tenant) {}

    /**
     * @return array{
     *     date: string, currency: string,
     *     methods: list<array{method: string, received: int, paid_out: int, net: int, payments: int}>,
     *     staff: list<array{user: array{id: string, name: string}|null, method: string, received: int, paid_out: int}>,
     *     reversed_reloads: int, complimentary: int, total_received: int, total_paid_out: int, outstanding_end_of_day: int
     * }
     */
    public function day(string $date): array
    {
        $restaurant = $this->tenant->require();
        $start = Carbon::parse($date, $restaurant->timezone)->startOfDay();
        $from = $start->copy()->utc();
        $to = $start->copy()->addDay()->utc();

        // The day as it stood at its close: a reversal made on a later day never changes it (it shows on its own day).
        $reversedThatDay = static fn ($q) => $q->select(DB::raw(1))->from('voucher_transactions as t')
            ->join('voucher_transactions as r', 'r.related_transaction_id', '=', 't.id')
            ->whereColumn('t.payment_id', 'payments.id')
            ->where('r.created_at', '<', $to);

        // Money that stays: payments in whose sale or reload was not reversed that day; payouts out.
        $payments = Payment::query()
            ->where('created_at', '>=', $from)->where('created_at', '<', $to)
            ->where('method', '!=', PaymentMethod::Complimentary->value)
            ->whereNotExists($reversedThatDay)
            ->get(['id', 'method', 'direction', 'amount', 'received_by']);

        $methods = [];
        $staff = [];
        foreach ($payments as $payment) {
            /** @var Payment $payment */
            $method = $payment->method->value;
            $out = $payment->direction === PaymentDirection::Out;
            $methods[$method] ??= ['method' => $method, 'received' => 0, 'paid_out' => 0, 'net' => 0, 'payments' => 0];
            $methods[$method][$out ? 'paid_out' : 'received'] += $payment->amount;
            $methods[$method]['net'] += $out ? -$payment->amount : $payment->amount;
            $methods[$method]['payments']++;
            $key = ($payment->received_by ?? '').'|'.$method;
            $staff[$key] ??= ['user_id' => $payment->received_by, 'method' => $method, 'received' => 0, 'paid_out' => 0];
            $staff[$key][$out ? 'paid_out' : 'received'] += $payment->amount;
        }
        $names = User::query()->whereIn('id', array_filter(array_column($staff, 'user_id')))->pluck('name', 'id');

        // Paid reloads only: a reversed loyalty top-up was never money (audit L5).
        $reversedReloads = (int) VoucherTransaction::query()->ofType(TransactionType::Reversal)
            ->where('created_at', '>=', $from)->where('created_at', '<', $to)
            ->whereHas('relatedTransaction', static fn ($q) => $q->where('type', TransactionType::Reload->value)
                ->whereHas('payment', static fn ($p) => $p->where('method', '!=', PaymentMethod::Complimentary->value)))
            ->sum('amount');
        // A loyalty sale cancelled the same day gave nothing (audit L5).
        $cancelledThatDay = static fn ($q) => $q->select(DB::raw(1))->from('voucher_transactions as s')
            ->join('voucher_transactions as c', 'c.voucher_id', '=', 's.voucher_id')
            ->whereColumn('s.payment_id', 'payments.id')
            ->where('s.type', TransactionType::Issue->value)
            ->where('c.type', TransactionType::Refund->value)
            ->where('c.note', 'like', VoucherService::SALE_CANCELLED_NOTE.'%')
            ->where('c.created_at', '<', $to);
        $complimentary = (int) Payment::query()->where('method', PaymentMethod::Complimentary->value)
            ->where('created_at', '>=', $from)->where('created_at', '<', $to)
            ->whereNotExists($reversedThatDay)
            ->whereNotExists($cancelledThatDay)
            ->sum('amount');

        // Each voucher's balance after its last ledger entry before the end of the day.
        $outstanding = (int) VoucherTransaction::query()
            ->whereIn('chain_seq', VoucherTransaction::query()->where('created_at', '<', $to)->groupBy('voucher_id')->selectRaw('MAX(chain_seq)'))
            ->sum('balance_after');

        ksort($methods);

        return [
            'date' => $start->toDateString(),
            'currency' => $restaurant->currency,
            'methods' => array_values($methods),
            'staff' => array_values(array_map(static fn (array $s): array => [
                'user' => $s['user_id'] !== null ? ['id' => (string) $s['user_id'], 'name' => (string) ($names[$s['user_id']] ?? '—')] : null,
                'method' => $s['method'],
                'received' => $s['received'],
                'paid_out' => $s['paid_out'],
            ], $staff)),
            'reversed_reloads' => -$reversedReloads,
            'complimentary' => $complimentary,
            'total_received' => array_sum(array_column($methods, 'received')),
            'total_paid_out' => array_sum(array_column($methods, 'paid_out')),
            'outstanding_end_of_day' => $outstanding,
        ];
    }
}
