<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Enums\Permission;
use App\Enums\PresentmentMethod;
use App\Enums\PresentmentPurpose;
use App\Http\Controllers\Controller;
use App\Http\Requests\Cards\BeginCardPresentmentRequest;
use App\Http\Requests\Cards\CompleteCardPresentmentRequest;
use App\Http\Requests\Vouchers\CreatePresentmentRequest;
use App\Http\Resources\PresentmentResource;
use App\Services\Presentments\CardPresentmentService;
use App\Services\Presentments\PresentmentService;
use App\Support\Actor;
use Illuminate\Http\JsonResponse;

/**
 * POST /presentments: the till proves that a voucher's medium is here, now, and gets a single-use,
 * 60-second presentment for the operation that follows (architecture §10.1).
 */
final class PresentmentController extends Controller
{
    public function store(CreatePresentmentRequest $request, PresentmentService $presentments): JsonResponse
    {
        $purpose = PresentmentPurpose::from((string) $request->validated('purpose'));
        // The QR of an online voucher whose card is picked up: only someone who binds cards.
        if ($purpose === PresentmentPurpose::Pickup) {
            $this->authorize(Permission::CardsBind->value);
        }
        $presentment = $presentments->present(
            Actor::fromRequest($request),
            $purpose,
            PresentmentMethod::from((string) $request->validated('method')),
            (string) $request->validated('credential'),
        );

        return PresentmentResource::make($presentment)->response()->setStatusCode(201)->header('Cache-Control', 'no-store, private');
    }

    /**
     * POST /presentments/cards: a physical card, step 1 of its live authentication (SUN + radio UID + the card's
     * challenge). Returns the command the phone relays to the card.
     */
    public function beginCard(BeginCardPresentmentRequest $request, CardPresentmentService $cards): JsonResponse
    {
        $purpose = PresentmentPurpose::from((string) $request->validated('purpose'));
        $this->authorize(match ($purpose) {
            PresentmentPurpose::Spend => Permission::VouchersRedeem->value,
            PresentmentPurpose::Bind, PresentmentPurpose::Pickup => Permission::CardsBind->value,
            PresentmentPurpose::Receive => Permission::CardsReceive->value,
            PresentmentPurpose::Surrender, PresentmentPurpose::Resume => Permission::CardsManage->value,
            PresentmentPurpose::Reload => Permission::VouchersReload->value,
        });

        $begun = $cards->begin(
            Actor::fromRequest($request),
            $purpose,
            (string) $request->validated('tap_url'),
            (string) $request->validated('rf_uid'),
            (string) $request->validated('challenge'),
        );

        return response()->json(['data' => $begun])->header('Cache-Control', 'no-store, private');
    }

    /** POST /presentments/cards/{authentication}: step 2, the card's answer. Returns the presentment. */
    public function completeCard(CompleteCardPresentmentRequest $request, CardPresentmentService $cards, string $authentication): JsonResponse
    {
        $presentment = $cards->complete(Actor::fromRequest($request), $authentication, (string) $request->validated('response'));

        return PresentmentResource::make($presentment)->response()->setStatusCode(201)->header('Cache-Control', 'no-store, private');
    }
}
