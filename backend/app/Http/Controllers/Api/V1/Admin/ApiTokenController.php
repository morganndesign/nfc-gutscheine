<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\ApiTokenResource;
use App\Models\PersonalAccessToken;
use App\Services\ApiTokens\ApiTokenService;
use App\Support\Actor;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * Incident response for the platform (audit S2): every access token of every restaurant (integration tokens and
 * waiter app sign-ins) can be listed and revoked. Tokens are never created here.
 */
final class ApiTokenController extends Controller
{
    public function __construct(private readonly ApiTokenService $tokens) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $v = $request->validate([
            'restaurant_id' => ['nullable', 'uuid'],
            'active' => ['nullable', 'boolean'],
        ]);

        $tokens = PersonalAccessToken::query()
            ->with(['tokenable', 'restaurant'])
            ->when(isset($v['restaurant_id']), static fn ($q) => $q->where('restaurant_id', $v['restaurant_id']))
            ->when(($v['active'] ?? null) !== null && (bool) $v['active'], static fn ($q) => $q
                ->whereNull('revoked_at')
                ->where(static fn ($e) => $e->whereNull('expires_at')->orWhere('expires_at', '>', now())))
            ->latest()
            ->paginate($this->perPage($request, 50));

        return ApiTokenResource::collection($tokens);
    }

    public function revoke(Request $request, string $token): ApiTokenResource
    {
        /** @var PersonalAccessToken $model */
        $model = PersonalAccessToken::query()->findOrFail($token);

        return ApiTokenResource::make($this->tokens->revoke(Actor::fromRequest($request), $model)->load(['tokenable', 'restaurant']));
    }
}
