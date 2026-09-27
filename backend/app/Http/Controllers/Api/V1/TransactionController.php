<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Cards\ReasonRequest;
use App\Http\Requests\Cards\TransactionIndexRequest;
use App\Http\Resources\TransactionResource;
use App\Models\GiftCardTransaction;
use App\Services\Exports\CsvExporter;
use App\Services\GiftCards\GiftCardService;
use App\Support\Actor;
use App\Support\CardNumber;
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
            ->with(['giftCard', 'user', 'device'])
            ->paginate($this->perPage($request))
            ->withQueryString();

        return TransactionResource::collection($transactions);
    }

    public function show(GiftCardTransaction $transaction): TransactionResource
    {
        return TransactionResource::make($transaction->load(['giftCard', 'user', 'device']));
    }

    public function reverse(ReasonRequest $request, GiftCardTransaction $transaction, GiftCardService $cards): JsonResponse
    {
        $result = $cards->reverse(Actor::fromRequest($request), $transaction, (string) $request->validated('reason'));

        return response()->json([
            'data' => TransactionResource::make($result->transaction->load(['giftCard', 'user']))->resolve($request),
        ], 201);
    }

    public function export(TransactionIndexRequest $request, CsvExporter $exporter): StreamedResponse
    {
        $restaurant = $this->tenant()->require();
        $tz = $restaurant->timezone;
        $money = static fn (int $cents): string => $exporter->amount($cents, $restaurant->locale);

        return $exporter->stream(
            $this->filteredQuery($request)->with(['giftCard', 'user', 'device'])->reorder(),
            [
                'Date' => static fn (GiftCardTransaction $t): string => $t->created_at->timezone($tz)->format('Y-m-d H:i:s'),
                'Transaction ID' => static fn (GiftCardTransaction $t): string => $t->id,
                'Type' => static fn (GiftCardTransaction $t): string => $t->type->label(),
                'Card number' => static fn (GiftCardTransaction $t): string => CardNumber::format($t->giftCard->card_number),
                'Amount' => static fn (GiftCardTransaction $t): string => $money($t->amount),
                'Balance after' => static fn (GiftCardTransaction $t): string => $money($t->balance_after),
                'Currency' => static fn (GiftCardTransaction $t): string => $t->currency,
                'Reference' => static fn (GiftCardTransaction $t): ?string => $t->reference,
                'Note' => static fn (GiftCardTransaction $t): ?string => $t->note,
                'Reversed' => static fn (GiftCardTransaction $t): bool => $t->isReversed(),
                'User' => static fn (GiftCardTransaction $t): ?string => $t->user?->name,
                'Device' => static fn (GiftCardTransaction $t): ?string => $t->device?->name,
            ],
            'transactions-'.Carbon::now($tz)->format('Y-m-d-His').'.csv',
        );
    }

    /**
     * @return Builder<GiftCardTransaction>
     */
    private function filteredQuery(TransactionIndexRequest $request): Builder
    {
        $v = $request->validated();
        $query = GiftCardTransaction::query();

        if (! empty($v['type'])) {
            $query->whereIn('type', $v['type']);
        }
        if (! empty($v['gift_card_id'])) {
            $query->where('gift_card_id', $v['gift_card_id']);
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
            $digits = CardNumber::normalize($term);
            $query->where(static function (Builder $q) use ($term, $digits): void {
                $q->where('reference', 'like', '%'.addcslashes($term, '%_\\').'%');
                if ($digits !== '') {
                    $q->orWhereHas('giftCard', static fn (Builder $c) => $c->where('card_number', 'like', '%'.$digits.'%'));
                }
            });
        }

        return $query->orderByDesc('created_at')->orderByDesc('id');
    }
}
