<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\CardBatchStatus;
use App\Enums\KeySetStatus;
use App\Exceptions\Domain\CardStateException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\ChangeCardBatchStatusRequest;
use App\Http\Requests\Admin\ResolveCardBatchHoldRequest;
use App\Http\Requests\Admin\ShipCardBatchRequest;
use App\Http\Requests\Admin\StoreCardBatchRequest;
use App\Http\Resources\CardBatchResource;
use App\Models\Card;
use App\Models\CardBatch;
use App\Models\KeySet;
use App\Models\Restaurant;
use App\Services\Cards\CardBatchLifecycle;
use App\Support\Actor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * Platform operations on card batches (architecture §8): order, release, shipping, the special status changes and
 * holds after a disputed receipt. The station personalises; the restaurant receives.
 */
final class CardBatchController extends Controller
{
    public function __construct(private readonly CardBatchLifecycle $batches) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $status = $request->query('status');
        $restaurant = $request->query('restaurant_id');
        $query = CardBatch::query()->withoutGlobalScopes()->with(['restaurant', 'keySet'])
            ->when(is_string($status) && CardBatchStatus::tryFrom($status) !== null, static fn ($q) => $q->where('status', $status))
            ->when(is_string($restaurant), static fn ($q) => $q->where('restaurant_id', $restaurant))
            ->orderByDesc('ordered_at');

        return CardBatchResource::collection($query->paginate($this->perPage($request))->through(
            static fn (CardBatch $b): CardBatchResource => CardBatchResource::make($b)->forPlatform(),
        ));
    }

    public function show(string $batch): CardBatchResource
    {
        return CardBatchResource::make($this->find($batch))->forPlatform();
    }

    public function store(StoreCardBatchRequest $request): JsonResponse
    {
        $v = $request->validated();
        /** @var Restaurant $restaurant */
        $restaurant = Restaurant::query()->findOrFail($v['restaurant_id']);
        $keySet = isset($v['key_set'])
            ? KeySet::query()->where('version', $v['key_set'])->firstOrFail()
            : (KeySet::query()->where('status', KeySetStatus::Active->value)->latest()->first() ?? throw new CardStateException('There is no active key set.'));

        $batch = $this->batches->order($restaurant, $keySet, trim((string) ($v['manufacturer'] ?? '')) ?: 'in-house', (int) $v['quantity'], Actor::fromRequest($request), $v['card_design_ref'] ?? null);

        return CardBatchResource::make($this->find($batch->id))->forPlatform()->response()->setStatusCode(201);
    }

    public function status(ChangeCardBatchStatusRequest $request, string $batch): CardBatchResource
    {
        $v = $request->validated();
        $this->batches->changeStatus($this->find($batch), CardBatchStatus::from((string) $v['status']), (string) $v['reason'], Actor::fromRequest($request), array_filter([
            'production_date' => $v['production_date'] ?? null,
        ], static fn (mixed $x): bool => $x !== null));

        return CardBatchResource::make($this->find($batch))->forPlatform();
    }

    public function release(Request $request, string $batch): CardBatchResource
    {
        $this->batches->release($this->find($batch), Actor::fromRequest($request));

        return CardBatchResource::make($this->find($batch))->forPlatform();
    }

    public function ship(ShipCardBatchRequest $request, string $batch): CardBatchResource
    {
        $tracking = trim((string) $request->validated('tracking_ref'));
        $this->batches->ship($this->find($batch), Actor::fromRequest($request), $tracking !== '' ? $tracking : null);

        return CardBatchResource::make($this->find($batch))->forPlatform();
    }

    public function resolveHold(ResolveCardBatchHoldRequest $request, string $batch): CardBatchResource
    {
        $found = $this->find($batch);
        /** @var list<string> $numbers */
        $numbers = $request->validated('missing');
        $missing = Card::query()->withoutGlobalScopes()->where('batch_id', $found->getKey())->whereIn('card_number', $numbers)->get();
        if ($missing->count() !== count($numbers)) {
            throw new CardStateException('A missing card is not a card of this batch.');
        }
        $this->batches->resolveHold($found, array_values($missing->all()), Actor::fromRequest($request));

        return CardBatchResource::make($this->find($batch))->forPlatform();
    }

    private function find(string $id): CardBatch
    {
        /** @var CardBatch */
        return CardBatch::query()->withoutGlobalScopes()->with(['restaurant', 'keySet'])->findOrFail($id);
    }
}
