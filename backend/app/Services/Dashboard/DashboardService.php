<?php

declare(strict_types=1);

namespace App\Services\Dashboard;

use App\Enums\PaymentMethod;
use App\Enums\TransactionType;
use App\Enums\VoucherStatus;
use App\Models\Restaurant;
use App\Models\Voucher;
use App\Models\VoucherTransaction;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Aggregated KPIs and chart series for the restaurant dashboard.
 * All figures are in minor units and computed in the restaurant's timezone.
 */
final class DashboardService
{
    private const NOT_REVERSED = 'NOT EXISTS (SELECT 1 FROM voucher_transactions r WHERE r.related_transaction_id = voucher_transactions.id)';

    private const PAID = 'NOT EXISTS (SELECT 1 FROM payments p WHERE p.id = voucher_transactions.payment_id AND p.method = ?)';

    /**
     * @return array<string, int|string>
     */
    public function stats(Restaurant $restaurant): array
    {
        $tz = $restaurant->timezone;
        $now = Carbon::now($tz);
        $todayStart = $now->copy()->startOfDay()->utc();
        $monthStart = $now->copy()->startOfMonth()->utc();
        $previousMonthStart = $now->copy()->subMonthNoOverflow()->startOfMonth()->utc();

        $statusCounts = Voucher::query()
            ->select('status', DB::raw('COUNT(*) as aggregate'))
            ->groupBy('status')
            ->pluck('aggregate', 'status')
            ->map(static fn ($v): int => (int) $v);

        // Liability towards guests: every voucher with a balance, expired and blocked ones included.
        $outstanding = Voucher::query()->outstanding()
            ->selectRaw('COUNT(*) as vouchers, COALESCE(SUM(balance), 0) as balance')
            ->toBase()->first();

        $today = VoucherTransaction::query()->where('created_at', '>=', $todayStart);
        $todayCount = (clone $today)->count();
        $todayRedeemed = (int) -(clone $today)->ofType(TransactionType::Redemption)->notReversed()->sum('amount');

        $monthlyRedeemed = (int) -VoucherTransaction::query()
            ->ofType(TransactionType::Redemption)
            ->notReversed()
            ->where('created_at', '>=', $monthStart)
            ->sum('amount');

        return [
            'currency' => $restaurant->currency,
            'vouchers_sold' => Voucher::query()->count(),
            'vouchers_sold_this_month' => Voucher::query()->where('created_at', '>=', $monthStart)->count(),
            'vouchers_active' => $statusCounts->get(VoucherStatus::Active->value, 0),
            'vouchers_empty' => Voucher::query()->where('status', VoucherStatus::Active->value)->where('balance', 0)->count(),
            'vouchers_blocked' => $statusCounts->get(VoucherStatus::Blocked->value, 0),
            'vouchers_expired' => $statusCounts->get(VoucherStatus::Expired->value, 0),
            'outstanding_balance' => (int) ($outstanding->balance ?? 0),
            'outstanding_vouchers' => (int) ($outstanding->vouchers ?? 0),
            'today_transactions' => $todayCount,
            'today_redeemed' => $todayRedeemed,
            'monthly_revenue' => $this->salesBetween($monthStart, null),
            'previous_month_revenue' => $this->salesBetween($previousMonthStart, $monthStart),
            'monthly_redeemed' => $monthlyRedeemed,
            'expiring_soon' => Voucher::query()
                ->where('status', VoucherStatus::Active->value)
                ->where('balance', '>', 0)
                ->whereBetween('expires_at', [Carbon::now(), Carbon::now()->addDays(30)])
                ->count(),
        ];
    }

    /**
     * Daily sold vs. redeemed amounts for the last $days days (inclusive of today).
     *
     * @return list<array{date: string, sold: int, redeemed: int, transactions: int}>
     */
    public function dailySeries(Restaurant $restaurant, int $days = 30): array
    {
        $tz = $restaurant->timezone;
        $end = Carbon::now($tz)->endOfDay();
        $start = $end->copy()->subDays($days - 1)->startOfDay();
        $offsetMinutes = $end->utcOffset();

        $bucket = $this->dateBucket('created_at', $offsetMinutes);

        $rows = VoucherTransaction::query()
            ->selectRaw("{$bucket} as bucket")
            ->selectRaw('SUM(CASE WHEN type IN (?, ?) AND '.self::NOT_REVERSED.' AND '.self::PAID.' THEN amount ELSE 0 END) as sold', [TransactionType::Issue->value, TransactionType::Reload->value, PaymentMethod::Complimentary->value])
            ->selectRaw('SUM(CASE WHEN type = ? AND '.self::NOT_REVERSED.' THEN -amount ELSE 0 END) as redeemed', [TransactionType::Redemption->value])
            ->selectRaw('COUNT(*) as transactions')
            ->where('created_at', '>=', $start->copy()->utc())
            ->where('created_at', '<=', $end->copy()->utc())
            ->groupBy('bucket')
            ->get()
            ->keyBy('bucket');

        $series = [];
        for ($day = $start->copy(); $day->lte($end); $day->addDay()) {
            $key = $day->format('Y-m-d');
            $row = $rows->get($key);
            $series[] = [
                'date' => $key,
                'sold' => (int) ($row->sold ?? 0),
                'redeemed' => (int) ($row->redeemed ?? 0),
                'transactions' => (int) ($row->transactions ?? 0),
            ];
        }

        return $series;
    }

    /**
     * Revenue (card sales + reloads) and redemptions per month for the last $months months, in one query.
     *
     * @return list<array{month: string, revenue: int, redeemed: int}>
     */
    public function monthlySeries(Restaurant $restaurant, int $months = 12): array
    {
        $tz = $restaurant->timezone;
        $start = Carbon::now($tz)->startOfMonth()->subMonthsNoOverflow($months - 1);
        $offsetMinutes = Carbon::now($tz)->utcOffset();
        $bucket = $this->dateBucket('created_at', $offsetMinutes, 'month');

        $rows = VoucherTransaction::query()
            ->selectRaw("{$bucket} as bucket")
            ->selectRaw('SUM(CASE WHEN type IN (?, ?) AND '.self::NOT_REVERSED.' AND '.self::PAID.' THEN amount ELSE 0 END) as revenue', [TransactionType::Issue->value, TransactionType::Reload->value, PaymentMethod::Complimentary->value])
            ->selectRaw('SUM(CASE WHEN type = ? AND '.self::NOT_REVERSED.' THEN -amount ELSE 0 END) as redeemed', [TransactionType::Redemption->value])
            ->where('created_at', '>=', $start->copy()->utc())
            ->groupBy('bucket')
            ->get()
            ->keyBy('bucket');

        $series = [];
        for ($i = 0, $cursor = $start->copy(); $i < $months; $i++, $cursor->addMonthNoOverflow()) {
            $row = $rows->get($cursor->format('Y-m'));
            $series[] = [
                'month' => $cursor->format('Y-m'),
                'revenue' => (int) ($row->revenue ?? 0),
                'redeemed' => (int) ($row->redeemed ?? 0),
            ];
        }

        return $series;
    }

    /** @return list<array{status: string, count: int, balance: int}> */
    public function statusDistribution(): array
    {
        return array_values(Voucher::query()
            ->select('status', DB::raw('COUNT(*) as count'), DB::raw('COALESCE(SUM(balance), 0) as balance'))
            ->groupBy('status')
            ->get()
            ->map(static fn ($row): array => [
                'status' => $row->status instanceof VoucherStatus ? $row->status->value : (string) $row->status,
                'count' => (int) $row->getAttribute('count'),
                'balance' => (int) $row->getAttribute('balance'),
            ])
            ->all());
    }

    /** Money received: sales and reloads that were paid (not complimentary) and not reversed. */
    private function salesBetween(Carbon $from, ?Carbon $to): int
    {
        return (int) VoucherTransaction::query()
            ->ofType(TransactionType::Issue, TransactionType::Reload)
            ->notReversed()
            ->whereHas('payment', static fn (Builder $p) => $p->where('method', '!=', PaymentMethod::Complimentary->value))
            ->where('created_at', '>=', $from)
            ->when($to !== null, static fn (Builder $q) => $q->where('created_at', '<', $to))
            ->sum('amount');
    }

    /**
     * SQL expression grouping a UTC timestamp column into local calendar days or months.
     * The offset is the restaurant's current UTC offset (an integer, never user input); days around
     * a DST switch can be shifted by one hour, which is acceptable for charts.
     */
    private function dateBucket(string $column, int $offsetMinutes, string $unit = 'day'): string
    {
        $offset = (int) $offsetMinutes;

        return match (DB::connection()->getDriverName()) {
            'sqlite' => $unit === 'month'
                ? "strftime('%Y-%m', {$column}, '".($offset >= 0 ? '+' : '')."{$offset} minutes')"
                : "date({$column}, '".($offset >= 0 ? '+' : '')."{$offset} minutes')",
            'pgsql' => "to_char({$column} + interval '{$offset} minutes', '".($unit === 'month' ? 'YYYY-MM' : 'YYYY-MM-DD')."')",
            default => "DATE_FORMAT(DATE_ADD({$column}, INTERVAL {$offset} MINUTE), '".($unit === 'month' ? '%Y-%m' : '%Y-%m-%d')."')",
        };
    }
}
