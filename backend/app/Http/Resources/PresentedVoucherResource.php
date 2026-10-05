<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Enums\VoucherStatus;
use App\Models\User;
use App\Models\Voucher;
use App\Support\Tenancy\TenantContext;
use App\Support\VoucherNumber;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * What the till needs after a voucher was presented: balance, state and the limits of this restaurant.
 * No customer data.
 *
 * @mixin Voucher
 */
final class PresentedVoucherResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var Voucher $voucher */
        $voucher = $this->resource;
        /** @var User $user */
        $user = $request->user();
        $restaurant = app(TenantContext::class)->require();
        $settings = $restaurant->settings;

        return [
            'id' => $voucher->id,
            'kind' => $voucher->kind->value,
            'restaurant_name' => $restaurant->name,
            'voucher_number' => VoucherNumber::format($voucher->voucher_number),
            'status' => $voucher->status->value,
            'currency' => $voucher->currency,
            'balance' => $voucher->balance,
            // Loyalty value may only be added to a loyalty voucher.
            'loyalty' => $voucher->is_loyalty,
            'expires_at' => $voucher->expires_at?->toIso8601String(),
            'is_expired' => $voucher->isExpiredByDate(),
            'blocked_reason' => $voucher->status === VoucherStatus::Blocked ? $voucher->blocked_reason : null,
            'allow_partial_redemption' => $settings->allow_partial_redemption,
            'max_debit_per_transaction' => $settings->max_debit_per_transaction,
            'actions' => [
                'redeem' => $voucher->isSpendable() && $user->hasPermission('vouchers.redeem'),
            ],
        ];
    }
}
