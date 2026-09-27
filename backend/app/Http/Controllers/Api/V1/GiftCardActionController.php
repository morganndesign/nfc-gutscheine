<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Data\TransactionResult;
use App\Enums\NfcTagType;
use App\Enums\NfcWriteMethod;
use App\Exceptions\Domain\CardNotFoundException;
use App\Http\Controllers\Controller;
use App\Http\Middleware\RequireIdempotencyKey;
use App\Http\Requests\Cards\BindNfcTagRequest;
use App\Http\Requests\Cards\CheckNfcTagRequest;
use App\Http\Requests\Cards\LockNfcTagRequest;
use App\Http\Requests\Cards\MoneyOperationRequest;
use App\Http\Requests\Cards\OptionalReasonRequest;
use App\Http\Requests\Cards\ReasonRequest;
use App\Http\Requests\Cards\ReplaceCardRequest;
use App\Http\Requests\Cards\ReportNfcFailureRequest;
use App\Http\Requests\Cards\TransferBalanceRequest;
use App\Http\Resources\GiftCardResource;
use App\Http\Resources\NfcWriteAttemptResource;
use App\Http\Resources\ScannedCardResource;
use App\Http\Resources\TransactionResource;
use App\Models\GiftCard;
use App\Models\NfcWriteAttempt;
use App\Services\GiftCards\CardHistoryService;
use App\Services\GiftCards\CardUrlBuilder;
use App\Services\GiftCards\GiftCardService;
use App\Services\GiftCards\NfcProgrammingService;
use App\Services\GiftCards\QrCodeService;
use App\Support\Actor;
use App\Support\CardNumber;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;

final class GiftCardActionController extends Controller
{
    public function __construct(private readonly GiftCardService $cards) {}

    public function activate(Request $request, GiftCard $card): GiftCardResource
    {
        return GiftCardResource::make($this->cards->activate(Actor::fromRequest($request), $card));
    }

    public function redeem(MoneyOperationRequest $request, GiftCard $card): JsonResponse
    {
        $result = $this->cards->redeem(
            Actor::fromRequest($request),
            $card,
            (int) $request->validated('amount'),
            $request->attributes->get(RequireIdempotencyKey::ATTRIBUTE),
            $request->validated('reference'),
            $request->validated('note'),
        );

        return $this->moneyResponse($request, $result);
    }

    public function reload(MoneyOperationRequest $request, GiftCard $card): JsonResponse
    {
        $result = $this->cards->reload(
            Actor::fromRequest($request),
            $card,
            (int) $request->validated('amount'),
            $request->attributes->get(RequireIdempotencyKey::ATTRIBUTE),
            $request->validated('reference'),
            $request->validated('note'),
        );

        return $this->moneyResponse($request, $result);
    }

    public function block(ReasonRequest $request, GiftCard $card): GiftCardResource
    {
        return GiftCardResource::make($this->cards->block(Actor::fromRequest($request), $card, (string) $request->validated('reason')));
    }

    public function unblock(Request $request, GiftCard $card): GiftCardResource
    {
        return GiftCardResource::make($this->cards->unblock(Actor::fromRequest($request), $card));
    }

    public function expire(OptionalReasonRequest $request, GiftCard $card): GiftCardResource
    {
        return GiftCardResource::make($this->cards->expire(Actor::fromRequest($request), $card, $request->validated('reason')));
    }

    public function transfer(TransferBalanceRequest $request, GiftCard $card): JsonResponse
    {
        $targetId = $request->validated('target_card_id');
        $target = $targetId !== null
            ? GiftCard::query()->findOrFail((string) $targetId)
            : GiftCard::query()->where('card_number', CardNumber::normalize((string) $request->validated('target_card_number')))->first();

        if ($target === null) {
            throw new CardNotFoundException('The target card was not found.');
        }

        $result = $this->cards->transfer(
            Actor::fromRequest($request),
            $card,
            $target,
            $request->validated('amount') !== null ? (int) $request->validated('amount') : null,
            $request->attributes->get(RequireIdempotencyKey::ATTRIBUTE),
            $request->validated('note'),
        );

        return response()->json([
            'data' => [
                'source' => GiftCardResource::make($result['source']->card)->resolve($request),
                'target' => GiftCardResource::make($result['target']->card)->resolve($request),
                'transactions' => [
                    TransactionResource::make($result['source']->transaction)->resolve($request),
                    TransactionResource::make($result['target']->transaction)->resolve($request),
                ],
            ],
            'replayed' => $result['source']->replayed,
        ]);
    }

    public function replace(ReplaceCardRequest $request, GiftCard $card): JsonResponse
    {
        $tagType = $request->validated('nfc_tag_type');
        $result = $this->cards->replace(
            Actor::fromRequest($request),
            $card,
            (string) $request->validated('reason'),
            $tagType !== null ? NfcTagType::from((string) $tagType) : null,
        );

        return response()->json([
            'data' => GiftCardResource::make($result['card']->load('replaces'))->resolve($request),
            'nfc' => app(CardUrlBuilder::class)->payloadFor($result['card']),
        ], 201);
    }

    public function bindNfc(BindNfcTagRequest $request, GiftCard $card, NfcProgrammingService $nfc): GiftCardResource
    {
        $actor = Actor::fromRequest($request);
        $method = NfcWriteMethod::from((string) $request->validated('method'));
        $tagType = NfcTagType::from((string) $request->validated('tag_type'));

        $bound = $method === NfcWriteMethod::WebNfc
            ? $nfc->bindVerified(
                $actor,
                $card,
                (string) $request->validated('attempt_id'),
                $tagType,
                (string) $request->validated('uid'),
                (string) $request->validated('read_back.uid'),
                (string) $request->validated('read_back.url'),
                (array) $request->validated('timings', []),
                $request->boolean('only_if_unprogrammed'),
            )
            : $nfc->bindUnverified($actor, $card, $request->validated('attempt_id'), $method, $tagType, $request->boolean('locked'));

        return GiftCardResource::make($bound);
    }

    public function checkNfc(CheckNfcTagRequest $request, GiftCard $card, NfcProgrammingService $nfc): JsonResponse
    {
        return response()->json(['data' => $nfc->check(
            Actor::fromRequest($request),
            $card,
            (string) $request->validated('attempt_id'),
            (string) $request->validated('uid'),
            $request->validated('current_url'),
            $request->boolean('only_if_unprogrammed'),
        )]);
    }

    public function lockNfc(LockNfcTagRequest $request, GiftCard $card, NfcProgrammingService $nfc): GiftCardResource
    {
        return GiftCardResource::make($nfc->confirmLock(Actor::fromRequest($request), $card, (string) $request->validated('attempt_id')));
    }

    public function reportNfcFailure(ReportNfcFailureRequest $request, GiftCard $card, NfcProgrammingService $nfc): JsonResponse
    {
        /** @var array{attempt_id: string, stage: string, result: string, error_code: string, message?: string|null, uid?: string|null, tag_type?: string|null, previous_url?: string|null, read_back_url?: string|null, timings?: array<string, mixed>} $report */
        $report = $request->validated();
        $attempt = $nfc->reportFailure(Actor::fromRequest($request), $card, $report['attempt_id'], $report);

        return NfcWriteAttemptResource::make($attempt->load('user'))->response()->setStatusCode(201);
    }

    public function nfcAttempts(GiftCard $card): AnonymousResourceCollection
    {
        return NfcWriteAttemptResource::collection(
            NfcWriteAttempt::query()->where('gift_card_id', $card->id)->with('user')->latest()->orderByDesc('id')->limit(50)->get()
        );
    }

    public function nfcPayload(GiftCard $card, CardUrlBuilder $urls): JsonResponse
    {
        return response()->json([
            'data' => $urls->payloadFor($card) + [
                'lock_after_write' => $this->tenant()->require()->settings->lock_nfc_tags_after_write,
            ],
        ]);
    }

    public function history(GiftCard $card, CardHistoryService $history): JsonResponse
    {
        return response()->json(['data' => $history->timeline($card)]);
    }

    public function qr(GiftCard $card, CardUrlBuilder $urls, QrCodeService $qr): Response
    {
        return response($qr->svg($urls->url($card)), 200, [
            'Content-Type' => 'image/svg+xml',
            'Cache-Control' => 'no-store, private',
            'Content-Disposition' => 'inline; filename="card-'.substr($card->card_number, -4).'.svg"',
        ]);
    }

    private function moneyResponse(Request $request, TransactionResult $result): JsonResponse
    {
        $user = $this->user($request);
        $cardPayload = $user->hasPermission('cards.view')
            ? GiftCardResource::make($result->card)->resolve($request)
            : ScannedCardResource::make($result->card)->resolve($request);

        return response()->json([
            'data' => [
                'card' => $cardPayload,
                'transaction' => TransactionResource::make($result->transaction)->resolve($request),
            ],
            'replayed' => $result->replayed,
        ], $result->replayed ? 200 : 201);
    }
}
