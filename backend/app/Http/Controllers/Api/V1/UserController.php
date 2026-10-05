<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Users\StoreUserRequest;
use App\Http\Requests\Users\UpdateUserRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\Users\UserService;
use App\Support\Actor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

final class UserController extends Controller
{
    public function __construct(private readonly UserService $users) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $request->validate(['search' => ['nullable', 'string', 'max:100'], 'status' => ['nullable', 'in:active,inactive']]);
        $search = $request->string('search')->toString();

        $users = User::query()
            ->with('role')
            ->where('restaurant_id', $this->tenant()->id())
            ->when($search !== '', static fn ($q) => $q->where(static fn ($w) => $w
                ->where('name', 'like', '%'.addcslashes($search, '%_\\').'%')
                ->orWhere('email', 'like', '%'.addcslashes($search, '%_\\').'%')))
            ->when($request->filled('status'), static fn ($q) => $q->where('status', $request->string('status')->toString()))
            ->orderBy('name')
            ->paginate($this->perPage($request))
            ->withQueryString();

        return UserResource::collection($users);
    }

    public function store(StoreUserRequest $request): JsonResponse
    {
        /** @var array{name: string, email: string, role: string, password?: string|null, locale?: string|null} $data */
        $data = $request->validated();
        $user = $this->users->create(Actor::fromRequest($request), $this->tenant()->require(), $data);

        return UserResource::make($user->load('role'))->response()->setStatusCode(201);
    }

    public function show(User $user): UserResource
    {
        return UserResource::make($user->load('role'));
    }

    public function update(UpdateUserRequest $request, User $user): UserResource
    {
        /** @var array{name?: string, email?: string, role?: string, locale?: string, current_password?: string} $data */
        $data = $request->validated();

        return UserResource::make($this->users->update(Actor::fromRequest($request), $user, $data));
    }

    /** The owner allows a manager to give loyalty, or takes it back. */
    public function loyalty(Request $request, User $user): UserResource
    {
        $request->validate(['allowed' => ['required', 'boolean']]);

        return UserResource::make($this->users->setLoyaltyGrant(Actor::fromRequest($request), $user, $request->boolean('allowed')));
    }

    public function deactivate(Request $request, User $user): UserResource
    {
        return UserResource::make($this->users->deactivate(Actor::fromRequest($request), $user)->load('role'));
    }

    public function activate(Request $request, User $user): UserResource
    {
        return UserResource::make($this->users->activate(Actor::fromRequest($request), $user)->load('role'));
    }

    public function sendPasswordReset(Request $request, User $user): JsonResponse
    {
        $this->users->sendPasswordReset(Actor::fromRequest($request), $user);

        return response()->json(['message' => 'Password reset link sent.']);
    }
}
