<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Device;
use App\Models\PartnerConnection;
use App\Services\Partners\PartnerService;
use App\Support\Actor;
use App\Support\Tenancy\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Settings › Kassensysteme (owners, decision 2026-10-07): the POS systems that redeem this restaurant's vouchers in
 * their own till app. The owner creates a one-time code for the POS company, sees its tills and disconnects it.
 */
final class PartnerConnectionController extends Controller
{
    public function __construct(private readonly PartnerService $partners) {}

    public function index(): JsonResponse
    {
        $connections = PartnerConnection::query()->with('partner')->where('status', 'active')->orderBy('connected_at')->get();

        return response()->json(['data' => $connections->map(fn (PartnerConnection $c): array => $this->data($c))->values()]);
    }

    public function code(Request $request, TenantContext $tenant): JsonResponse
    {
        $link = $this->partners->createLinkCode(Actor::fromRequest($request), $tenant->require());

        return response()->json(['data' => ['code' => $link['code'], 'expires_at' => $link['expires_at']->toIso8601String()]], 201)
            ->header('Cache-Control', 'no-store, private');
    }

    public function destroy(Request $request, PartnerConnection $connection): JsonResponse
    {
        $this->partners->disconnect(Actor::fromRequest($request), $connection);

        return response()->json(['data' => $this->data($connection->load('partner'))]);
    }

    /** @return array<string, mixed> */
    private function data(PartnerConnection $connection): array
    {
        $terminals = Device::query()->where('partner_connection_id', $connection->getKey())->orderBy('name')->get();

        return [
            'id' => $connection->id,
            'partner' => ['name' => $connection->partner->name],
            'status' => $connection->status,
            'connected_at' => $connection->connected_at->toIso8601String(),
            'terminals' => $terminals->map(static fn (Device $d): array => [
                'id' => $d->id,
                'name' => $d->name,
                'status' => $d->status->value,
                'last_seen_at' => $d->last_seen_at?->toIso8601String(),
            ])->values()->all(),
        ];
    }
}
