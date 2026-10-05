<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Enums\PaymentDirection;
use App\Enums\PaymentMethod;
use App\Http\Controllers\Controller;
use App\Models\Payment;
use App\Services\Exports\CsvExporter;
use App\Services\Reports\CashUpService;
use App\Support\VoucherNumber;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Symfony\Component\HttpFoundation\StreamedResponse;

/** The restaurant's money reports: the daily cash-up and the payments ledger for the accountant. */
final class ReportController extends Controller
{
    /** GET /reports/cash-up?date=Y-m-d (default today): money in and out per method and person, liability at close. */
    public function cashUp(Request $request, CashUpService $cashUp): JsonResponse
    {
        // "Today" is the restaurant's local day: after local midnight the new day is already today, whatever UTC says.
        $today = Carbon::now($this->timezone())->toDateString();
        $date = $request->validate(['date' => ['nullable', 'date_format:Y-m-d', 'before_or_equal:'.$today]])['date'] ?? $today;

        return response()->json(['data' => $cashUp->day((string) $date)]);
    }

    /** GET /reports/payments/export?from=Y-m-d&to=Y-m-d: every payment received or paid out, one row each. */
    public function paymentsExport(Request $request, CsvExporter $exporter): StreamedResponse
    {
        $v = $request->validate([
            'from' => ['required', 'date_format:Y-m-d'],
            'to' => ['required', 'date_format:Y-m-d', 'after_or_equal:from'],
        ]);
        $restaurant = $this->tenant()->require();
        $tz = $restaurant->timezone;
        $money = static fn (int $cents): string => $exporter->amount($cents, $restaurant->locale);

        return $exporter->stream(
            Payment::query()->with(['voucher', 'receiver', 'transaction.reversal'])
                ->where('created_at', '>=', $this->dayStart((string) $v['from']))
                ->where('created_at', '<=', $this->dayEnd((string) $v['to'])),
            [
                'Date' => static fn (Payment $p): string => $p->created_at->timezone($tz)->format('Y-m-d H:i:s'),
                'Payment ID' => static fn (Payment $p): string => $p->id,
                // Loyalty is value given, not money: never in Amount, so a sum of Amount is the money (audit L3).
                'Direction' => static fn (Payment $p): string => match (true) {
                    $p->method === PaymentMethod::Complimentary => 'Loyalty (no payment)',
                    $p->direction === PaymentDirection::Out => 'Paid out',
                    default => 'Received',
                },
                'Method' => static fn (Payment $p): string => $p->method->label(),
                'Amount' => static fn (Payment $p): ?string => $p->method === PaymentMethod::Complimentary ? null : $money($p->direction === PaymentDirection::Out ? -$p->amount : $p->amount),
                'Loyalty value' => static fn (Payment $p): ?string => $p->method === PaymentMethod::Complimentary ? $money($p->amount) : null,
                'Currency' => static fn (Payment $p): string => $p->currency,
                'Reference' => static fn (Payment $p): ?string => $p->reference,
                'Voucher number' => static fn (Payment $p): string => VoucherNumber::format($p->voucher->voucher_number),
                'Reason' => static fn (Payment $p): ?string => $p->reason,
                'Staff' => static fn (Payment $p): ?string => $p->receiver?->name,
                // A reload booked by mistake and reversed: the money was not kept.
                'Reversed' => static fn (Payment $p): bool => $p->transaction?->isReversed() ?? false,
            ],
            'payments-'.$v['from'].'-'.$v['to'].'.csv',
        );
    }
}
