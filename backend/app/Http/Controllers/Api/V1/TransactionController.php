<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Enums\PaymentDirection;
use App\Enums\PaymentMethod;
use App\Http\Controllers\Controller;
use App\Http\Requests\ReasonRequest;
use App\Http\Requests\Vouchers\TransactionIndexRequest;
use App\Http\Resources\TransactionResource;
use App\Models\VoucherTransaction;
use App\Services\Exports\CsvExporter;
use App\Services\Vouchers\VoucherService;
use App\Support\Actor;
use App\Support\VoucherNumber;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Carbon;
use Symfony\Component\HttpFoundation\StreamedResponse;

final class TransactionController extends Controller
{
    public function index(TransactionIndexRequest $request): AnonymousResourceCollection
    {
        $transactions = $this->filteredQuery($request)
            ->with(['voucher', 'user', 'device', 'reversal', 'payment'])
            ->paginate($this->perPage($request))
            ->withQueryString();

        return TransactionResource::collection($transactions);
    }

    public function show(VoucherTransaction $transaction): TransactionResource
    {
        return TransactionResource::make($transaction->load(['voucher', 'user', 'device', 'reversal', 'payment']));
    }

    public function reverse(ReasonRequest $request, VoucherTransaction $transaction, VoucherService $vouchers): JsonResponse
    {
        $result = $vouchers->reverse(Actor::fromRequest($request), $transaction, (string) $request->validated('reason'));

        return response()->json([
            'data' => TransactionResource::make($result->transaction->load(['voucher', 'user']))->resolve($request),
        ], 201);
    }

    public function export(TransactionIndexRequest $request, CsvExporter $exporter): StreamedResponse
    {
        $restaurant = $this->tenant()->require();
        $tz = $restaurant->timezone;
        $money = static fn (int $cents): string => $exporter->amount($cents, $restaurant->locale);

        return $exporter->stream(
            $this->filteredQuery($request)->with(['voucher', 'user', 'device', 'reversal', 'payment'])->reorder(),
            [
                'Date' => static fn (VoucherTransaction $t): string => $t->created_at->timezone($tz)->format('Y-m-d H:i:s'),
                'Transaction ID' => static fn (VoucherTransaction $t): string => $t->id,
                'Type' => static fn (VoucherTransaction $t): string => $t->type->label(),
                'Voucher number' => static fn (VoucherTransaction $t): string => VoucherNumber::format($t->voucher->voucher_number),
                'Amount' => static fn (VoucherTransaction $t): string => $money($t->amount),
                'Balance after' => static fn (VoucherTransaction $t): string => $money($t->balance_after),
                'Currency' => static fn (VoucherTransaction $t): string => $t->currency,
                'Reference' => static fn (VoucherTransaction $t): ?string => $t->reference,
                'Payment method' => static fn (VoucherTransaction $t): ?string => $t->payment?->method->label(),
                // The money that moved with the entry: received (sale, reload) or paid out (refund); may differ from
                // Amount on a refund, where complimentary value is closed without a payout.
                'Payment' => static fn (VoucherTransaction $t): ?string => $t->payment !== null && $t->payment->method !== PaymentMethod::Complimentary ? $money($t->payment->direction === PaymentDirection::Out ? -$t->payment->amount : $t->payment->amount) : null,
                // Value given without payment (audit L3): never in Payment.
                'Loyalty value' => static fn (VoucherTransaction $t): ?string => $t->payment?->method === PaymentMethod::Complimentary ? $money($t->payment->amount) : null,
                'Payment reference' => static fn (VoucherTransaction $t): ?string => $t->payment?->reference,
                'Note' => static fn (VoucherTransaction $t): ?string => $t->note,
                'Reversed' => static fn (VoucherTransaction $t): bool => $t->isReversed(),
                'User' => static fn (VoucherTransaction $t): ?string => $t->user?->name,
                'Device' => static fn (VoucherTransaction $t): ?string => $t->device?->name,
            ],
            'transactions-'.Carbon::now($tz)->format('Y-m-d-His').'.csv',
        );
    }

    /**
     * @return Builder<VoucherTransaction>
     */
    private function filteredQuery(TransactionIndexRequest $request): Builder
    {
        $v = $request->validated();
        $query = VoucherTransaction::query();

        if (! empty($v['type'])) {
            $query->whereIn('type', $v['type']);
        }
        if (! empty($v['voucher_id'])) {
            $query->where('voucher_id', $v['voucher_id']);
        }
        if (! empty($v['user_id'])) {
            $query->where('user_id', $v['user_id']);
        }
        if (! empty($v['from'])) {
            $query->where('created_at', '>=', $this->dayStart($v['from']));
        }
        if (! empty($v['to'])) {
            $query->where('created_at', '<=', $this->dayEnd($v['to']));
        }
        if (! empty($v['search'])) {
            $term = (string) $v['search'];
            $digits = VoucherNumber::normalize($term);
            $query->where(static function (Builder $q) use ($term, $digits): void {
                $q->where('reference', 'like', '%'.addcslashes($term, '%_\\').'%');
                if ($digits !== '') {
                    $q->orWhereHas('voucher', static fn (Builder $c) => $c->where('voucher_number', 'like', '%'.$digits.'%'));
                }
            });
        }

        return $query->orderByDesc('created_at')->orderByDesc('id');
    }
}
