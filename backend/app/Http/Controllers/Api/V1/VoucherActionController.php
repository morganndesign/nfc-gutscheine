<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Data\PaymentData;
use App\Data\TransactionResult;
use App\Enums\TransactionType;
use App\Http\Controllers\Controller;
use App\Http\Middleware\RequireIdempotencyKey;
use App\Http\Requests\ReasonRequest;
use App\Http\Requests\Vouchers\RedeemVoucherRequest;
use App\Http\Requests\Vouchers\RefundVoucherRequest;
use App\Http\Requests\Vouchers\ReinstateVoucherRequest;
use App\Http\Requests\Vouchers\ReloadVoucherRequest;
use App\Http\Resources\PresentedVoucherResource;
use App\Http\Resources\TransactionResource;
use App\Http\Resources\VoucherResource;
use App\Models\Voucher;
use App\Models\VoucherTransaction;
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

    /**
     * The outcome of one of the caller's own redemption attempts, by its Idempotency-Key. A till whose request
     * went unanswered asks here instead of sending the debit again, so an unknown outcome is resolved without
     * risking a second booking (audit M1, M2, M6). Only the caller's own attempts are visible. "not_booked" is
     * final only once the attempt can no longer be running on the server; the client waits for that.
     */
    public function redemptionOutcome(Request $request, Voucher $voucher, string $idempotencyKey): JsonResponse
    {
        $transaction = VoucherTransaction::query()
            ->where('restaurant_id', $voucher->restaurant_id)
            ->where('voucher_id', $voucher->getKey())
            ->where('idempotency_key', $idempotencyKey)
            ->ofType(TransactionType::Redemption)
            ->where('user_id', $this->user($request)->getKey())
            ->first();

        if ($transaction === null) {
            return response()->json(['data' => ['status' => 'not_booked']])->header('Cache-Control', 'no-store, private');
        }

        return response()->json(['data' => [
            'status' => 'booked',
            'voucher' => PresentedVoucherResource::make($voucher->refresh())->resolve($request),
            'transaction' => TransactionResource::make($transaction->loadMissing('payment'))->resolve($request),
        ]])->header('Cache-Control', 'no-store, private');
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

    /** POST /vouchers/{voucher}/refund: pays the remaining balance back and closes the voucher (owners). */
    public function refund(RefundVoucherRequest $request, Voucher $voucher): JsonResponse
    {
        /** @var array{method: string, reference?: string|null} $payment */
        $payment = $request->validated('payment');

        $result = $this->vouchers->refund(
            Actor::fromRequest($request),
            $voucher,
            PaymentData::fromArray($payment),
            (string) $request->validated('reason'),
            (string) $request->attributes->get(RequireIdempotencyKey::ATTRIBUTE),
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
