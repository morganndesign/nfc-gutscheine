<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Cards\ScanCardRequest;
use App\Http\Resources\ScannedCardResource;
use App\Services\GiftCards\CardScanService;
use App\Support\Actor;

final class CardScanController extends Controller
{
    public function __invoke(ScanCardRequest $request, CardScanService $scanner): ScannedCardResource
    {
        $card = $scanner->resolve(Actor::fromRequest($request), $request->toInput());

        return ScannedCardResource::make($card);
    }
}
