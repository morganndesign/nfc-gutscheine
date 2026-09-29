<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Enums\PresentmentMethod;
use App\Enums\PresentmentPurpose;
use App\Http\Controllers\Controller;
use App\Http\Requests\Vouchers\CreatePresentmentRequest;
use App\Http\Resources\PresentmentResource;
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
        $presentment = $presentments->present(
            Actor::fromRequest($request),
            PresentmentPurpose::from((string) $request->validated('purpose')),
            PresentmentMethod::from((string) $request->validated('method')),
            (string) $request->validated('credential'),
        );

        return PresentmentResource::make($presentment)->response()->setStatusCode(201)->header('Cache-Control', 'no-store, private');
    }
}
