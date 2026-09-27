<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Data\IssueGiftCardData;
use App\Enums\GiftCardStatus;
use App\Enums\NfcTagType;
use App\Http\Controllers\Controller;
use App\Http\Middleware\RequireIdempotencyKey;
use App\Http\Requests\Cards\CardIndexRequest;
use App\Http\Requests\Cards\StoreGiftCardRequest;
use App\Http\Requests\Cards\UpdateGiftCardRequest;
use App\Http\Resources\GiftCardResource;
use App\Http\Resources\TransactionResource;
use App\Models\GiftCard;
use App\Services\Exports\CsvExporter;
use App\Services\GiftCards\CardUrlBuilder;
use App\Services\GiftCards\GiftCardService;
use App\Support\Actor;
use App\Support\CardNumber;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Carbon;
use Symfony\Component\HttpFoundation\StreamedResponse;

final class GiftCardController extends Controller
{
    public function __construct(private readonly GiftCardService $cards) {}

    public function index(CardIndexRequest $request): AnonymousResourceCollection
    {
        $cards = $this->filteredQuery($request)
            ->with('customer')
            ->paginate($this->perPage($request))
            ->withQueryString();

        return GiftCardResource::collection($cards);
    }

    public function store(StoreGiftCardRequest $request): JsonResponse
    {
        $actor = Actor::fromRequest($request);
        $input = $request->validated();
        $key = $request->attributes->get(RequireIdempotencyKey::ATTRIBUTE);

        $result = $this->cards->issue($actor, IssueGiftCardData::fromArray($input, is_string($key) ? $key : null));

        $card = $result->card->load(['customer', 'issuer']);

        return response()->json([
            'data' => GiftCardResource::make($card)->resolve($request),
            'transaction' => TransactionResource::make($result->transaction)->resolve($request),
            'nfc' => app(CardUrlBuilder::class)->payloadFor($card),
            'replayed' => $result->replayed,
        ], $result->replayed ? 200 : 201);
    }

    public function show(GiftCard $card): GiftCardResource
    {
        return GiftCardResource::make($card->load(['customer', 'issuer', 'replacedBy', 'replaces']));
    }

    public function update(UpdateGiftCardRequest $request, GiftCard $card): GiftCardResource
    {
        /** @var array{customer_id?: string|null, recipient_name?: string|null, notes?: string|null, expires_at?: string|null} $data */
        $data = $request->validated();
        $updated = $this->cards->update(Actor::fromRequest($request), $card, $data);

        return GiftCardResource::make($updated->load(['customer', 'issuer']));
    }

    public function export(CardIndexRequest $request, CsvExporter $exporter): StreamedResponse
    {
        $restaurant = $this->tenant()->require();
        $tz = $restaurant->timezone;
        $money = static fn (int $cents): string => $exporter->amount($cents, $restaurant->locale);

        return $exporter->stream(
            $this->filteredQuery($request)->with('customer')->reorder(),
            [
                'Card number' => static fn (GiftCard $c): string => CardNumber::format($c->card_number),
                'Status' => static fn (GiftCard $c): string => $c->status->label(),
                'Currency' => static fn (GiftCard $c): string => $c->currency,
                'Initial value' => static fn (GiftCard $c): string => $money($c->initial_value),
                'Balance' => static fn (GiftCard $c): string => $money($c->balance),
                'Total loaded' => static fn (GiftCard $c): string => $money($c->total_loaded),
                'Total redeemed' => static fn (GiftCard $c): string => $money($c->total_redeemed),
                'Customer' => static fn (GiftCard $c): ?string => $c->customer?->full_name,
                'Customer email' => static fn (GiftCard $c): ?string => $c->customer?->email,
                'Recipient' => static fn (GiftCard $c): ?string => $c->recipient_name,
                'Expires at' => static fn (GiftCard $c): ?string => $c->expires_at?->timezone($tz)->format('Y-m-d'),
                'Created at' => static fn (GiftCard $c): string => $c->created_at->timezone($tz)->format('Y-m-d H:i'),
                'Last used at' => static fn (GiftCard $c): ?string => $c->last_used_at?->timezone($tz)->format('Y-m-d H:i'),
                'Notes' => static fn (GiftCard $c): ?string => $c->notes,
            ],
            'gift-cards-'.Carbon::now($tz)->format('Y-m-d-His').'.csv',
        );
    }

    /**
     * @return Builder<GiftCard>
     */
    private function filteredQuery(CardIndexRequest $request): Builder
    {
        $v = $request->validated();
        $query = GiftCard::query()->search($v['search'] ?? null);

        if (! empty($v['status'])) {
            $query->whereIn('status', $v['status']);
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
        $ntag21x = [NfcTagType::Ntag213->value, NfcTagType::Ntag215->value, NfcTagType::Ntag216->value];
        match ($v['nfc_status'] ?? null) {
            'unprogrammed' => $query->whereNull('nfc_written_at')
                ->whereNotIn('status', [GiftCardStatus::Replaced->value, GiftCardStatus::Expired->value])
                ->where(static fn (Builder $q) => $q->whereNull('nfc_tag_type')->orWhereIn('nfc_tag_type', $ntag21x)),
            'unverified' => $query->whereNotNull('nfc_written_at')->whereNull('nfc_verified_at')->whereIn('nfc_tag_type', $ntag21x),
            'verified' => $query->whereNotNull('nfc_verified_at'),
            default => null,
        };
        if (! empty($v['card_number_after'])) {
            $query->where('card_number', '>', preg_replace('/\D/', '', (string) $v['card_number_after']));
        }

        $sort = $v['sort'] ?? '-created_at';
        $direction = str_starts_with($sort, '-') ? 'desc' : 'asc';

        return $query->orderBy(ltrim($sort, '-'), $direction)->orderBy('id', $direction);
    }
}
