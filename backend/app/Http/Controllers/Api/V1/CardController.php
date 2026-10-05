<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Cards\CardIndexRequest;
use App\Http\Requests\Cards\CardReasonRequest;
use App\Http\Requests\Cards\ReceiveCardBatchRequest;
use App\Http\Requests\Cards\ReplaceCardRequest;
use App\Http\Requests\Cards\ResumeCardRequest;
use App\Http\Resources\CardBatchResource;
use App\Http\Resources\CardResource;
use App\Models\Card;
use App\Models\CardBatch;
use App\Models\CardEvent;
use App\Services\Cards\CardService;
use App\Support\Actor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * The restaurant's physical cards (architecture §11): stock and guests' cards by inventory number, deliveries,
 * suspension, replacement. Cards are addressed by their inventory number; ids and UIDs never leave the server.
 */
final class CardController extends Controller
{
    public function __construct(private readonly CardService $cards) {}

    public function index(CardIndexRequest $request): AnonymousResourceCollection
    {
        $v = $request->validated();
        $query = Card::query()->with(['batch', 'activeMedium.voucher'])
            ->when($v['state'] ?? null, static fn ($q, array $states) => $q->whereIn('state', $states))
            ->when($v['search'] ?? null, static fn ($q, string $s) => $q->where('card_number', 'like', '%'.strtoupper($s)))
            ->when($v['batch'] ?? null, static fn ($q, string $b) => $q->whereIn('batch_id', CardBatch::query()->where('batch_code', $b)->select('id')))
            ->orderBy('card_number');

        return CardResource::collection($query->paginate($this->perPage($request, 50)));
    }

    public function show(string $card): JsonResponse
    {
        $found = $this->find($card)->load(['batch', 'activeMedium.voucher']);
        $history = CardEvent::query()->withoutGlobalScopes()->where('card_id', $found->getKey())->orderBy('chain_seq')->get()
            ->map(static fn (CardEvent $e): array => [
                'from_state' => $e->from_state?->value,
                'to_state' => $e->to_state->value,
                'reason' => $e->reason,
                'at' => $e->created_at?->toIso8601String(),
            ]);

        return response()->json(['data' => CardResource::make($found)->resolve() + ['history' => $history->all()]]);
    }

    public function suspend(CardReasonRequest $request, string $card): CardResource
    {
        return $this->respond($this->cards->suspend(Actor::fromRequest($request), $this->find($card), (string) $request->validated('reason')));
    }

    /** Only with the card tapped at the till (`resume` presentment), never by number alone. */
    public function resume(ResumeCardRequest $request, string $card): CardResource
    {
        return $this->respond($this->cards->resume(Actor::fromRequest($request), $this->find($card), (string) $request->validated('reason'), (string) $request->validated('presentment_id')));
    }

    public function revoke(CardReasonRequest $request, string $card): CardResource
    {
        return $this->respond($this->cards->revoke(Actor::fromRequest($request), $this->find($card), (string) $request->validated('reason')));
    }

    /** The platform's test restaurant: the card goes back into stock (decision 2026-10-05). */
    public function resetTest(Request $request, string $card): CardResource
    {
        return $this->respond($this->cards->resetTestCard(Actor::fromRequest($request), $this->find($card)));
    }

    public function replace(ReplaceCardRequest $request, string $card): CardResource
    {
        $surrender = $request->validated('surrender_presentment_id');
        $new = $this->cards->replace(
            Actor::fromRequest($request),
            $this->find($card),
            (string) $request->validated('presentment_id'),
            is_string($surrender) ? $surrender : null,
            (string) $request->validated('reason'),
        );

        return $this->respond($new);
    }

    public function batches(): AnonymousResourceCollection
    {
        return CardBatchResource::collection(CardBatch::query()->orderByDesc('ordered_at')->get());
    }

    public function receive(ReceiveCardBatchRequest $request, string $batch): CardBatchResource
    {
        /** @var CardBatch $found */
        $found = CardBatch::query()->whereKey($batch)->firstOrFail();
        $received = $this->cards->receive(Actor::fromRequest($request), $found, (int) $request->validated('count'), (string) $request->validated('presentment_id'));

        return CardBatchResource::make($received);
    }

    private function find(string $number): Card
    {
        /** @var Card */
        return Card::query()->where('card_number', strtoupper($number))->firstOrFail();
    }

    private function respond(Card $card): CardResource
    {
        return CardResource::make($card->refresh()->load(['batch', 'activeMedium.voucher']));
    }
}
