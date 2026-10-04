<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Cards\StoreCardOrderRequest;
use App\Http\Resources\CardOrderResource;
use App\Models\CardOrder;
use App\Services\Cards\CardOrderService;
use App\Support\Actor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/** The restaurant's card orders (app and dashboard). */
final class CardOrderController extends Controller
{
    public function __construct(private readonly CardOrderService $orders) {}

    public function index(): AnonymousResourceCollection
    {
        return CardOrderResource::collection(
            CardOrder::query()->with(['requester', 'batch'])->latest()->limit(20)->get(),
        );
    }

    public function store(StoreCardOrderRequest $request): JsonResponse
    {
        $note = $request->validated('note');
        $order = $this->orders->request(Actor::fromRequest($request), (int) $request->validated('quantity'), is_string($note) ? $note : null);

        return CardOrderResource::make($order->load(['requester', 'batch']))->response()->setStatusCode(201);
    }
}
