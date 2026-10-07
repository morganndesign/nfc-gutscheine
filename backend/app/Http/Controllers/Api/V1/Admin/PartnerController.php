<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Partner;
use App\Models\PartnerConnection;
use App\Services\Partners\PartnerService;
use App\Support\Actor;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Admin › Kassen-Partner (platform, audit L4): the POS companies with a partner key, the restaurants that connected
 * them, a new partner (its key is shown once), a new key (the old one stops at once), suspend and reactivate.
 * The same as `php artisan partner:manage`, for operators without a terminal.
 */
final class PartnerController extends Controller
{
    public function __construct(private readonly PartnerService $partners) {}

    public function index(): JsonResponse
    {
        $partners = Partner::query()->orderBy('name')->get();
        $connections = PartnerConnection::query()->withoutGlobalScopes()->where('status', 'active')
            ->with('restaurant:id,name')->orderBy('connected_at')->get();

        return response()->json(['data' => $partners->map(fn (Partner $p): array => $this->data($p, $connections->where('partner_id', $p->id)))->values()]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'min:2', 'max:120'],
            'contact_email' => ['nullable', 'email:rfc', 'max:190'],
        ]);
        [$partner, $key] = $this->partners->create((string) $data['name'], $data['contact_email'] ?? null, Actor::fromRequest($request));

        return $this->withKey($partner, $key);
    }

    public function rotate(Request $request, Partner $partner): JsonResponse
    {
        return $this->withKey($partner, $this->partners->rotateKey($partner, Actor::fromRequest($request)));
    }

    public function suspend(Request $request, Partner $partner): JsonResponse
    {
        $this->partners->setActive($partner, false, Actor::fromRequest($request));

        return response()->json(['data' => $this->data($partner, new Collection)]);
    }

    public function activate(Request $request, Partner $partner): JsonResponse
    {
        $this->partners->setActive($partner, true, Actor::fromRequest($request));

        return response()->json(['data' => $this->data($partner, new Collection)]);
    }

    /** The key is shown this once: never cached. */
    private function withKey(Partner $partner, string $key): JsonResponse
    {
        return response()->json(['data' => $this->data($partner, new Collection) + ['key' => $key]], 201)
            ->header('Cache-Control', 'no-store, private');
    }

    /**
     * @param  Collection<int, PartnerConnection>  $connections
     * @return array<string, mixed>
     */
    private function data(Partner $partner, Collection $connections): array
    {
        return [
            'id' => $partner->id,
            'name' => $partner->name,
            'contact_email' => $partner->contact_email,
            'status' => $partner->status,
            'key_prefix' => $partner->key_prefix,
            'last_used_at' => $partner->last_used_at?->toIso8601String(),
            'created_at' => $partner->created_at->toIso8601String(),
            'restaurants' => $connections->map(static fn (PartnerConnection $c): array => [
                'id' => $c->restaurant_id,
                'name' => $c->restaurant?->name,
                'connected_at' => $c->connected_at->toIso8601String(),
            ])->values()->all(),
        ];
    }
}
