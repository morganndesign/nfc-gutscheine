<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Enums\Permission;
use App\Enums\VoucherStatus;
use App\Models\Medium;
use App\Models\User;
use App\Models\Voucher;
use App\Services\Vouchers\VoucherService;
use App\Support\VoucherNumber;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Full voucher representation for back-office users.
 *
 * @mixin Voucher
 */
final class VoucherResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var Voucher $voucher */
        $voucher = $this->resource;

        return [
            'id' => $voucher->id,
            'kind' => $voucher->kind->value,
            'voucher_number' => $voucher->voucher_number,
            'voucher_number_formatted' => VoucherNumber::format($voucher->voucher_number),
            'status' => $voucher->status->value,
            'currency' => $voucher->currency,
            'initial_value' => $voucher->initial_value,
            'balance' => $voucher->balance,
            'total_loaded' => $voucher->total_loaded,
            'total_redeemed' => $voucher->total_redeemed,
            'expires_at' => $voucher->expires_at?->toIso8601String(),
            'is_expired' => $voucher->isExpiredByDate(),
            'blocked_at' => $voucher->blocked_at?->toIso8601String(),
            'blocked_reason' => $voucher->blocked_reason,
            'expired_at' => $voucher->expired_at?->toIso8601String(),
            'recipient_name' => $voucher->recipient_name,
            'notes' => $voucher->notes,
            'customer' => CustomerResource::make($this->whenLoaded('customer')),
            'issued_by' => $this->whenLoaded('issuer', static fn () => $voucher->issuer !== null ? ['id' => $voucher->issuer->id, 'name' => $voucher->issuer->name] : null),
            'media' => $this->whenLoaded('media', static fn (): array => $voucher->media->map(static fn (Medium $m): array => [
                'id' => $m->id,
                'type' => $m->type->value,
                'role' => $m->role->value,
                'status' => $m->status->value,
                // A card's inventory number (never its id or UID); staff look it up under Cards.
                'card_number' => $m->relationLoaded('card') ? $m->card?->card_number : null,
                'created_at' => $m->created_at->toIso8601String(),
                'revoked_at' => $m->revoked_at?->toIso8601String(),
            ])->values()->all()),
            'payments' => $this->whenLoaded('payments', static fn () => PaymentResource::collection($voucher->payments)->resolve()),
            // What a refund would pay back now (detail view, for those who may refund).
            'refundable' => $this->when(
                $voucher->relationLoaded('payments') && $request->user() instanceof User && $request->user()->hasPermission(Permission::VouchersRefund),
                static fn (): int => in_array($voucher->status, [VoucherStatus::Active, VoucherStatus::Blocked, VoucherStatus::Expired], true)
                    ? app(VoucherService::class)->refundable($voucher)
                    : 0,
            ),
            'last_used_at' => $voucher->last_used_at?->toIso8601String(),
            'created_at' => $voucher->created_at->toIso8601String(),
            'updated_at' => $voucher->updated_at->toIso8601String(),
        ];
    }
}
