<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Device;
use App\Models\PartnerConnection;
use App\Models\PartnerLinkCode;
use App\Models\User;
use App\Services\Partners\PartnerService;
use App\Support\Actor;
use App\Support\Tenancy\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

/**
 * Settings › Kassensysteme (owners, decision 2026-10-07): the POS systems that redeem this restaurant's vouchers in
 * their own till app. The owner creates a one-time code for the POS company, sees its tills and disconnects it; codes
 * not used yet are listed and can be revoked.
 */
final class PartnerConnectionController extends Controller
{
    public function __construct(private readonly PartnerService $partners) {}

    public function index(): JsonResponse
    {
        $connections = PartnerConnection::query()->with('partner')->where('status', 'active')->orderBy('connected_at')->get();

        $codes = PartnerLinkCode::query()->whereNull('used_at')->where('expires_at', '>', Carbon::now())->orderBy('created_at')->get();
        $names = User::query()->whereIn('id', $codes->pluck('created_by')->filter()->unique()->values())->pluck('name', 'id');

        return response()->json([
            'data' => $connections->map(fn (PartnerConnection $c): array => $this->data($c))->values(),
            // Codes not used yet (the code itself is never shown again: only its hash is stored).
            'open_codes' => $codes->map(static fn (PartnerLinkCode $l): array => [
                'id' => $l->id,
                'created_at' => $l->created_at?->toIso8601String(),
                'created_by' => $l->created_by !== null ? ($names[$l->created_by] ?? null) : null,
                'expires_at' => $l->expires_at->toIso8601String(),
            ])->values(),
        ]);
    }

    public function revokeCode(Request $request, PartnerLinkCode $code): JsonResponse
    {
        $this->partners->revokeLinkCode(Actor::fromRequest($request), $code);

        return response()->json(null, 204);
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
