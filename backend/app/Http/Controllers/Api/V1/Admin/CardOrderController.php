<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\CardOrderStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\AcceptCardOrderRequest;
use App\Http\Requests\ReasonRequest;
use App\Http\Resources\CardOrderResource;
use App\Models\CardOrder;
use App\Services\Cards\CardOrderService;
use App\Support\Actor;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/** Card orders of all restaurants, for the platform: open ones first. */
final class CardOrderController extends Controller
{
    public function __construct(private readonly CardOrderService $orders) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $status = $request->query('status');

        return CardOrderResource::collection(
            CardOrder::query()->withoutGlobalScopes()
                ->with(['restaurant', 'requester', 'batch'])
                ->when(is_string($status) && CardOrderStatus::tryFrom($status) !== null, static fn ($q) => $q->where('status', $status))
                ->orderByRaw("case when status = 'requested' then 0 else 1 end")
                ->latest()
                ->limit(100)
                ->get()
                ->map(static fn (CardOrder $o): CardOrderResource => CardOrderResource::make($o)->forPlatform()),
        );
    }

    public function accept(AcceptCardOrderRequest $request, string $order): CardOrderResource
    {
        $quantity = $request->validated('quantity');
        $manufacturer = $request->validated('manufacturer');
        $accepted = $this->orders->accept(Actor::fromRequest($request), $this->find($order), is_string($manufacturer) ? $manufacturer : null, is_int($quantity) ? $quantity : null);

        return CardOrderResource::make($this->find($accepted->id))->forPlatform();
    }

    public function decline(ReasonRequest $request, string $order): CardOrderResource
    {
        $declined = $this->orders->decline(Actor::fromRequest($request), $this->find($order), (string) $request->validated('reason'));

        return CardOrderResource::make($this->find($declined->id))->forPlatform();
    }

    private function find(string $id): CardOrder
    {
        /** @var CardOrder */
        return CardOrder::query()->withoutGlobalScopes()->with(['restaurant', 'requester', 'batch'])->whereKey($id)->firstOrFail();
    }
}
