<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Settings\StoreApiTokenRequest;
use App\Http\Resources\ApiTokenResource;
use App\Models\PersonalAccessToken;
use App\Services\ApiTokens\ApiTokenService;
use App\Support\Actor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Carbon;

final class ApiTokenController extends Controller
{
    public function __construct(private readonly ApiTokenService $tokens) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $tokens = PersonalAccessToken::query()
            ->with('tokenable')
            ->where('restaurant_id', $this->tenant()->id())
            ->whereNull('device_id') // waiter app sign-ins are managed under Devices
            ->latest()
            ->paginate($this->perPage($request, 50));

        return ApiTokenResource::collection($tokens);
    }

    public function store(StoreApiTokenRequest $request): JsonResponse
    {
        $expires = $request->validated('expires_at');
        /** @var list<string> $abilities */
        $abilities = $request->validated('abilities');

        $token = $this->tokens->create(
            Actor::fromRequest($request),
            $this->user($request),
            (string) $request->validated('name'),
            $abilities,
            $expires !== null ? Carbon::parse((string) $expires)->endOfDay() : null,
        );

        return response()->json([
            'data' => ApiTokenResource::make($token->accessToken)->resolve($request),
            // The plain-text token is shown exactly once and never stored.
            'plain_text_token' => $token->plainTextToken,
        ], 201);
    }

    public function revoke(Request $request, string $token): ApiTokenResource
    {
        /** @var PersonalAccessToken $model */
        $model = PersonalAccessToken::query()
            ->where('restaurant_id', $this->tenant()->id())
            ->whereNull('device_id')
            ->findOrFail($token);

        return ApiTokenResource::make($this->tokens->revoke(Actor::fromRequest($request), $model));
    }
}
