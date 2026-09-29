<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\DeleteRestaurantRequest;
use App\Http\Requests\Admin\ResendInvitationRequest;
use App\Http\Requests\Admin\StoreRestaurantRequest;
use App\Http\Requests\Admin\UpdateRestaurantRequest;
use App\Http\Requests\OptionalReasonRequest;
use App\Http\Requests\ReasonRequest;
use App\Http\Resources\RestaurantResource;
use App\Http\Resources\UserResource;
use App\Models\NotificationLog;
use App\Models\Restaurant;
use App\Models\User;
use App\Models\Voucher;
use App\Services\Restaurants\RestaurantService;
use App\Services\Users\InvitationService;
use App\Support\Actor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Arr;

final class RestaurantController extends Controller
{
    public function __construct(
        private readonly RestaurantService $restaurants,
        private readonly InvitationService $invitations,
    ) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $request->validate([
            'search' => ['nullable', 'string', 'max:100'],
            'status' => ['nullable', 'in:active,suspended,archived'],
        ]);
        $search = $request->string('search')->toString();
        $like = '%'.addcslashes($search, '%_\\').'%';
        $status = $request->string('status')->toString();

        $restaurants = Restaurant::query()
            ->with(['owner'])
            ->withCount(['users', 'vouchers'])
            ->addSelect(['outstanding_balance' => Voucher::query()
                ->withoutGlobalScopes()
                ->selectRaw('COALESCE(SUM(balance), 0)')
                // Liability towards guests: expired and blocked vouchers keep their balance.
                ->whereColumn('vouchers.restaurant_id', 'restaurants.id'),
            ])
            ->when($search !== '', static fn ($q) => $q->where(static fn ($w) => $w
                ->where('name', 'like', $like)
                ->orWhere('slug', 'like', $like)
                ->orWhere('email', 'like', $like)
                ->orWhereHas('users', static fn ($u) => $u->where('email', 'like', $like)->orWhere('name', 'like', $like))))
            ->when($status === 'archived', static fn ($q) => $q->onlyTrashed())
            ->when(in_array($status, ['active', 'suspended'], true), static fn ($q) => $q->where('status', $status))
            ->orderBy('name')
            ->paginate($this->perPage($request))
            ->withQueryString();

        $this->attachInvitations($restaurants->getCollection()->pluck('owner'));

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

        $owner = $result['owner']->load('role');
        $this->attachInvitations([$owner]);

        return response()->json([
            'data' => RestaurantResource::make($result['restaurant']->setRelation('owner', $owner))->resolve($request),
            'owner' => UserResource::make($owner)->resolve($request),
        ], 201);
    }

    public function show(Restaurant $restaurant): JsonResponse
    {
        $restaurant->load(['settings', 'owner'])->loadCount(['users', 'vouchers']);
        $users = User::query()->with('role')->where('restaurant_id', $restaurant->getKey())->orderBy('name')->get();
        $this->attachInvitations($users);
        if ($restaurant->owner !== null) {
            $this->attachInvitations([$restaurant->owner]);
        }

        return response()->json([
            'data' => RestaurantResource::make($restaurant)->resolve(),
            'users' => UserResource::collection($users)->resolve(),
            'business_data' => $this->restaurants->businessData($restaurant),
        ]);
    }

    public function update(UpdateRestaurantRequest $request, Restaurant $restaurant): RestaurantResource
    {
        return RestaurantResource::make($this->restaurants->update(Actor::fromRequest($request), $restaurant, $request->validated())->load(['settings', 'owner']));
    }

    public function suspend(ReasonRequest $request, Restaurant $restaurant): RestaurantResource
    {
        return RestaurantResource::make($this->restaurants->suspend(Actor::fromRequest($request), $restaurant, (string) $request->validated('reason')));
    }

    public function reactivate(Request $request, Restaurant $restaurant): RestaurantResource
    {
        return RestaurantResource::make($this->restaurants->reactivate(Actor::fromRequest($request), $restaurant));
    }

    public function archive(OptionalReasonRequest $request, Restaurant $restaurant): RestaurantResource
    {
        $reason = $request->validated('reason');

        return RestaurantResource::make($this->restaurants->archive(Actor::fromRequest($request), $restaurant, is_string($reason) ? $reason : null));
    }

    public function restore(Request $request, Restaurant $restaurant): RestaurantResource
    {
        abort_unless($restaurant->trashed(), 409, 'This restaurant is not archived.');

        return RestaurantResource::make($this->restaurants->restore(Actor::fromRequest($request), $restaurant));
    }

    public function destroy(DeleteRestaurantRequest $request, Restaurant $restaurant): JsonResponse
    {
        $this->restaurants->delete(Actor::fromRequest($request), $restaurant, (string) $request->validated('confirm'));

        return response()->json(['message' => "{$restaurant->name} was deleted."]);
    }

    public function resendOwnerInvitation(ResendInvitationRequest $request, Restaurant $restaurant): JsonResponse
    {
        $result = $this->restaurants->resendOwnerInvitation(Actor::fromRequest($request), $restaurant, $request->validated());

        return $this->invitationResponse($result['owner'], $result['log']);
    }

    public function resendUserInvitation(ResendInvitationRequest $request, Restaurant $restaurant, User $user): JsonResponse
    {
        $log = $this->restaurants->resendInvitation(Actor::fromRequest($request), $restaurant, $user, $request->validated());

        return $this->invitationResponse($user, $log);
    }

    /**
     * 200 when the e-mail went out; 422 INVITATION_NOT_DELIVERED when the mail server refused it or the
     * platform only logs e-mails. Corrections are saved in every case; the admin can send it again.
     */
    private function invitationResponse(User $user, NotificationLog $log): JsonResponse
    {
        $user->refresh()->load('role');
        $this->attachInvitations([$user]);

        $status = $log->status === 'sent' ? 200 : 422;

        return response()->json(array_filter([
            'message' => match ($log->status) {
                'sent' => "Invitation sent to {$user->email}.",
                'logged' => $log->error,
                default => "The invitation to {$user->email} could not be sent: {$log->error}",
            },
            'code' => $status === 200 ? null : 'INVITATION_NOT_DELIVERED',
            'data' => UserResource::make($user)->resolve(),
        ], static fn ($v): bool => $v !== null), $status);
    }

    /** @param iterable<User|null> $users */
    private function attachInvitations(iterable $users): void
    {
        $users = collect($users)->filter();
        $summaries = $this->invitations->summaries($users);
        $users->each(static function (User $u) use ($summaries): void {
            $u->invitationSummary = $summaries[$u->id] ?? null;
        });
    }
}
