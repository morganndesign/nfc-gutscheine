<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\TransactionResource;
use App\Models\GiftCardTransaction;
use App\Services\Dashboard\DashboardService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class DashboardController extends Controller
{
    public function __construct(private readonly DashboardService $dashboard) {}

    public function stats(): JsonResponse
    {
        return response()->json(['data' => $this->dashboard->stats($this->tenant()->require())]);
    }

    public function charts(Request $request): JsonResponse
    {
        $days = in_array($request->integer('days', 30), [7, 30, 90], true) ? $request->integer('days', 30) : 30;
        $restaurant = $this->tenant()->require();

        return response()->json(['data' => [
            'daily' => $this->dashboard->dailySeries($restaurant, $days),
            'monthly' => $this->dashboard->monthlySeries($restaurant, 12),
            'status_distribution' => $this->dashboard->statusDistribution(),
        ]]);
    }

    public function activity(Request $request): JsonResponse
    {
        $limit = max(1, min(50, $request->integer('limit', 10)));

        $transactions = GiftCardTransaction::query()
            ->with(['giftCard', 'user', 'device'])
            ->latest('created_at')
            ->limit($limit)
            ->get();

        return response()->json(['data' => TransactionResource::collection($transactions)->resolve($request)]);
    }
}
