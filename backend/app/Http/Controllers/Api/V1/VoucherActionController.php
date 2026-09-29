<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Data\PaymentData;
use App\Data\TransactionResult;
use App\Http\Controllers\Controller;
use App\Http\Middleware\RequireIdempotencyKey;
use App\Http\Requests\ReasonRequest;
use App\Http\Requests\Vouchers\RedeemVoucherRequest;
use App\Http\Requests\Vouchers\ReinstateVoucherRequest;
use App\Http\Requests\Vouchers\ReloadVoucherRequest;
use App\Http\Resources\PresentedVoucherResource;
use App\Http\Resources\TransactionResource;
use App\Http\Resources\VoucherResource;
use App\Models\Voucher;
use App\Services\Vouchers\VoucherHistoryService;
use App\Services\Vouchers\VoucherService;
use App\Support\Actor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class VoucherActionController extends Controller
{
    public function __construct(private readonly VoucherService $vouchers) {}

    /** Debit with a presentment of the voucher's own medium (architecture §10.6). */
    public function redeem(RedeemVoucherRequest $request, Voucher $voucher): JsonResponse
    {
        $result = $this->vouchers->redeem(
            Actor::fromRequest($request),
            $voucher,
            (int) $request->validated('amount'),
            (string) $request->validated('presentment_id'),
            (string) $request->attributes->get(RequireIdempotencyKey::ATTRIBUTE),
            $request->validated('reference'),
            $request->validated('note'),
        );

        return $this->moneyResponse($request, $result);
    }

    public function reload(ReloadVoucherRequest $request, Voucher $voucher): JsonResponse
    {
        /** @var array{method: string, reference?: string|null, reason?: string|null} $payment */
        $payment = $request->validated('payment');

        $result = $this->vouchers->reload(
            Actor::fromRequest($request),
            $voucher,
            (int) $request->validated('amount'),
            PaymentData::fromArray($payment),
            (string) $request->attributes->get(RequireIdempotencyKey::ATTRIBUTE),
            $request->validated('note'),
        );

        return $this->moneyResponse($request, $result);
    }

    public function block(ReasonRequest $request, Voucher $voucher): VoucherResource
    {
        return VoucherResource::make($this->vouchers->block(Actor::fromRequest($request), $voucher, (string) $request->validated('reason')));
    }

    public function unblock(Request $request, Voucher $voucher): VoucherResource
    {
        return VoucherResource::make($this->vouchers->unblock(Actor::fromRequest($request), $voucher));
    }

    public function expire(ReasonRequest $request, Voucher $voucher): VoucherResource
    {
        return VoucherResource::make($this->vouchers->expire(Actor::fromRequest($request), $voucher, (string) $request->validated('reason')));
    }

    public function reinstate(ReinstateVoucherRequest $request, Voucher $voucher): VoucherResource
    {
        return VoucherResource::make($this->vouchers->reinstate(
            Actor::fromRequest($request),
            $voucher,
            (string) $request->validated('reason'),
            $request->validated('expires_on'),
        ));
    }

    public function history(Voucher $voucher, VoucherHistoryService $history): JsonResponse
    {
        return response()->json(['data' => $history->timeline($voucher)]);
    }

    private function moneyResponse(Request $request, TransactionResult $result): JsonResponse
    {
        $user = $this->user($request);
        $voucher = $user->hasPermission('vouchers.view')
            ? VoucherResource::make($result->voucher)->resolve($request)
            : PresentedVoucherResource::make($result->voucher)->resolve($request);

        return response()->json([
            'data' => [
                'voucher' => $voucher,
                'transaction' => TransactionResource::make($result->transaction->loadMissing('payment'))->resolve($request),
            ],
            'replayed' => $result->replayed,
        ], $result->replayed ? 200 : 201);
    }
}
