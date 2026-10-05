<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Data\IssueVoucherData;
use App\Enums\MediumStatus;
use App\Enums\VoucherKind;
use App\Http\Controllers\Controller;
use App\Http\Middleware\RequireIdempotencyKey;
use App\Http\Requests\Vouchers\StoreVoucherRequest;
use App\Http\Requests\Vouchers\UpdateVoucherRequest;
use App\Http\Requests\Vouchers\VoucherIndexRequest;
use App\Http\Resources\PaymentResource;
use App\Http\Resources\TransactionResource;
use App\Http\Resources\VoucherResource;
use App\Models\Card;
use App\Models\Medium;
use App\Models\Voucher;
use App\Services\Exports\CsvExporter;
use App\Services\Vouchers\QrCodeService;
use App\Services\Vouchers\VoucherService;
use App\Support\Actor;
use App\Support\VoucherNumber;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Carbon;
use Symfony\Component\HttpFoundation\StreamedResponse;

final class VoucherController extends Controller
{
    public function __construct(private readonly VoucherService $vouchers) {}

    public function index(VoucherIndexRequest $request): AnonymousResourceCollection
    {
        $vouchers = $this->filteredQuery($request)
            ->with('customer')
            ->paginate($this->perPage($request))
            ->withQueryString();

        return VoucherResource::collection($vouchers);
    }

    /**
     * Sells a digital voucher. The response carries the printable QR once (`printable.payload` and its SVG);
     * it is never stored and cannot be fetched again. The print sheet shows the QR and the restaurant, never
     * the voucher number.
     */
    public function store(StoreVoucherRequest $request, QrCodeService $qr): JsonResponse
    {
        $key = (string) $request->attributes->get(RequireIdempotencyKey::ATTRIBUTE);
        $result = $this->vouchers->sell(Actor::fromRequest($request), IssueVoucherData::fromArray($request->validated(), $key));

        $voucher = $result->voucher->load(['customer', 'issuer']);
        $user = $this->user($request);

        return response()->json([
            'data' => $user->hasPermission('vouchers.view')
                ? VoucherResource::make($voucher)->resolve($request)
                // The app's sale view: enough for the printed sheet, no voucher number and no customer data.
                : [
                    'id' => $voucher->id,
                    'kind' => $voucher->kind->value,
                    'balance' => $voucher->balance,
                    'currency' => $voucher->currency,
                    'expires_at' => $voucher->expires_at?->toIso8601String(),
                ],
            'transaction' => TransactionResource::make($result->transaction)->resolve($request),
            'payment' => PaymentResource::make($result->payment)->resolve($request),
            'card' => $this->cardOf($voucher),
            'printable' => $result->printable !== null ? [
                'payload' => $result->printable->payload,
                'qr_svg' => $qr->svg($result->printable->payload),
            ] : null,
            'replayed' => $result->replayed,
        ], $result->replayed ? 200 : 201)->header('Cache-Control', 'no-store, private');
    }

    /** @return array{card_number: string, state: string}|null */
    private function cardOf(Voucher $voucher): ?array
    {
        if ($voucher->kind !== VoucherKind::Card) {
            return null;
        }
        /** @var Card|null $card */
        $card = Card::query()->withoutGlobalScopes()
            ->whereIn('id', Medium::query()->where('voucher_id', $voucher->getKey())->where('status', MediumStatus::Active->value)->whereNotNull('card_id')->select('card_id'))
            ->first();

        return $card !== null ? ['card_number' => $card->card_number, 'state' => $card->state->value] : null;
    }

    public function show(Voucher $voucher): VoucherResource
    {
        return VoucherResource::make($voucher->load(['customer', 'issuer', 'media.card', 'payments']));
    }

    public function update(UpdateVoucherRequest $request, Voucher $voucher): VoucherResource
    {
        /** @var array{customer_id?: string|null, recipient_name?: string|null, gift_message?: string|null, notes?: string|null} $data */
        $data = $request->validated();
        $updated = $this->vouchers->update(Actor::fromRequest($request), $voucher, $data);

        return VoucherResource::make($updated->load(['customer', 'issuer']));
    }

    public function export(VoucherIndexRequest $request, CsvExporter $exporter): StreamedResponse
    {
        $restaurant = $this->tenant()->require();
        $tz = $restaurant->timezone;
        $money = static fn (int $cents): string => $exporter->amount($cents, $restaurant->locale);

        return $exporter->stream(
            $this->filteredQuery($request)->with('customer')->reorder(),
            [
                'Voucher number' => static fn (Voucher $v): string => VoucherNumber::format($v->voucher_number),
                'Kind' => static fn (Voucher $v): string => ucfirst($v->kind->value),
                'Status' => static fn (Voucher $v): string => $v->status->label(),
                'Loyalty' => static fn (Voucher $v): bool => $v->is_loyalty,
                'Currency' => static fn (Voucher $v): string => $v->currency,
                'Initial value' => static fn (Voucher $v): string => $money($v->initial_value),
                'Balance' => static fn (Voucher $v): string => $money($v->balance),
                'Total loaded' => static fn (Voucher $v): string => $money($v->total_loaded),
                'Total redeemed' => static fn (Voucher $v): string => $money($v->total_redeemed),
                'Customer' => static fn (Voucher $v): ?string => $v->customer?->full_name,
                'Customer email' => static fn (Voucher $v): ?string => $v->customer?->email,
                'Recipient' => static fn (Voucher $v): ?string => $v->recipient_name,
                'Expires at' => static fn (Voucher $v): ?string => $v->expires_at?->timezone($tz)->format('Y-m-d'),
                'Created at' => static fn (Voucher $v): string => $v->created_at->timezone($tz)->format('Y-m-d H:i'),
                'Last used at' => static fn (Voucher $v): ?string => $v->last_used_at?->timezone($tz)->format('Y-m-d H:i'),
                'Notes' => static fn (Voucher $v): ?string => $v->notes,
            ],
            'vouchers-'.Carbon::now($tz)->format('Y-m-d-His').'.csv',
        );
    }

    /**
     * @return Builder<Voucher>
     */
    private function filteredQuery(VoucherIndexRequest $request): Builder
    {
        $v = $request->validated();
        $query = Voucher::query()->search($v['search'] ?? null);
        if (! empty($v['loyalty'])) {
            $query->loyalty();
        }

        if (! empty($v['status'])) {
            $query->whereIn('status', $v['status']);
        }
        if (! empty($v['kind'])) {
            $query->where('kind', $v['kind']);
        }
        if (! empty($v['customer_id'])) {
            $query->where('customer_id', $v['customer_id']);
        }
        if (! empty($v['created_from'])) {
            $query->where('created_at', '>=', $this->dayStart($v['created_from']));
        }
        if (! empty($v['created_to'])) {
            $query->where('created_at', '<=', $this->dayEnd($v['created_to']));
        }
        if (! empty($v['expires_from'])) {
            $query->where('expires_at', '>=', $this->dayStart($v['expires_from']));
        }
        if (! empty($v['expires_to'])) {
            $query->where('expires_at', '<=', $this->dayEnd($v['expires_to']));
        }
        if (isset($v['min_balance'])) {
            $query->where('balance', '>=', (int) $v['min_balance']);
        }
        if (isset($v['max_balance'])) {
            $query->where('balance', '<=', (int) $v['max_balance']);
        }

        $sort = $v['sort'] ?? '-created_at';
        $direction = str_starts_with($sort, '-') ? 'desc' : 'asc';

        return $query->orderBy(ltrim($sort, '-'), $direction)->orderBy('id', $direction);
    }
}
