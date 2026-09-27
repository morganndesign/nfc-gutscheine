<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\GiftCardStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\StoreRestaurantRequest;
use App\Http\Requests\Cards\ReasonRequest;
use App\Http\Requests\Settings\UpdateRestaurantRequest;
use App\Http\Resources\RestaurantResource;
use App\Http\Resources\UserResource;
use App\Models\GiftCard;
use App\Models\Restaurant;
use App\Models\User;
use App\Services\Restaurants\RestaurantService;
use App\Support\Actor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Arr;

final class RestaurantController extends Controller
{
    public function __construct(private readonly RestaurantService $restaurants) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $request->validate(['search' => ['nullable', 'string', 'max:100'], 'status' => ['nullable', 'in:active,suspended']]);
        $search = $request->string('search')->toString();

        $restaurants = Restaurant::query()
            ->withCount(['users', 'giftCards'])
            ->addSelect(['outstanding_balance' => GiftCard::query()
                ->withoutGlobalScopes()
                ->selectRaw('COALESCE(SUM(balance), 0)')
                ->whereColumn('gift_cards.restaurant_id', 'restaurants.id')
                ->whereIn('status', [GiftCardStatus::Active->value, GiftCardStatus::Inactive->value, GiftCardStatus::Blocked->value]),
            ])
            ->when($search !== '', static fn ($q) => $q->where(static fn ($w) => $w
                ->where('name', 'like', '%'.addcslashes($search, '%_\\').'%')
                ->orWhere('slug', 'like', '%'.addcslashes($search, '%_\\').'%')
                ->orWhere('email', 'like', '%'.addcslashes($search, '%_\\').'%')))
            ->when($request->filled('status'), static fn ($q) => $q->where('status', $request->string('status')->toString()))
            ->orderBy('name')
            ->paginate($this->perPage($request))
            ->withQueryString();

        return RestaurantResource::collection($restaurants);
    }

    public function store(StoreRestaurantRequest $request): JsonResponse
    {
        $data = $request->validated();

        $result = $this->restaurants->create(
            Actor::fromRequest($request),
            Arr::except($data, ['owner']),
            $data['owner'],
        );

        return response()->json([
            'data' => RestaurantResource::make($result['restaurant'])->resolve($request),
            'owner' => UserResource::make($result['owner']->load('role'))->resolve($request),
        ], 201);
    }

    public function show(Restaurant $restaurant): JsonResponse
    {
        $restaurant->load('settings')->loadCount(['users', 'giftCards']);

        return response()->json([
            'data' => RestaurantResource::make($restaurant)->resolve(),
            'users' => UserResource::collection(
                User::query()->with('role')->where('restaurant_id', $restaurant->getKey())->orderBy('name')->get(),
            )->resolve(),
        ]);
    }

    public function update(UpdateRestaurantRequest $request, Restaurant $restaurant): RestaurantResource
    {
        return RestaurantResource::make($this->restaurants->update(Actor::fromRequest($request), $restaurant, $request->validated())->load('settings'));
    }

    public function suspend(ReasonRequest $request, Restaurant $restaurant): RestaurantResource
    {
        return RestaurantResource::make($this->restaurants->suspend(Actor::fromRequest($request), $restaurant, (string) $request->validated('reason')));
    }

    public function reactivate(Request $request, Restaurant $restaurant): RestaurantResource
    {
        return RestaurantResource::make($this->restaurants->reactivate(Actor::fromRequest($request), $restaurant));
    }
}
