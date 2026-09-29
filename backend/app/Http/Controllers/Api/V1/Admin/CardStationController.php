<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\CardBatchStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\Cards\BeginPersonalizationRequest;
use App\Http\Requests\Cards\ContinuePersonalizationRequest;
use App\Models\CardBatch;
use App\Services\Cards\CardPersonalizer;
use App\Services\Cards\PersonalizationStep;
use App\Support\Actor;
use Illuminate\Http\JsonResponse;

/**
 * The personalisation station (internal, Android): relays the server's APDUs to a blank chip round by round
 * (architecture §9.3). The response never contains key material, only commands already encrypted and MACed.
 */
final class CardStationController extends Controller
{
    /** The batches the station may personalise now: ordered for the station, in production. */
    public function batches(): JsonResponse
    {
        $batches = CardBatch::query()->withoutGlobalScopes()
            ->with('restaurant:id,name')
            ->where('personalization', 'in_house_station')
            ->where('status', CardBatchStatus::InProduction->value)
            ->orderBy('batch_code')
            ->get();

        return response()->json(['data' => $batches->map(static function (CardBatch $batch): array {
            $counts = $batch->counts();

            return [
                'id' => $batch->id,
                'batch_code' => $batch->batch_code,
                'restaurant' => $batch->restaurant->name,
                'quantity_ordered' => $batch->quantity_ordered,
                'registered' => $counts['registered'],
                'qa_passed' => $counts['central_stock'],
            ];
        })->all()]);
    }

    public function begin(BeginPersonalizationRequest $request, CardPersonalizer $personalizer, string $batch): JsonResponse
    {
        /** @var CardBatch $found */
        $found = CardBatch::query()->withoutGlobalScopes()->findOrFail($batch);

        return $this->respond($personalizer->begin($found, (string) hex2bin((string) $request->validated('rf_uid')), Actor::fromRequest($request)));
    }

    public function continue(ContinuePersonalizationRequest $request, CardPersonalizer $personalizer, string $personalization): JsonResponse
    {
        return $this->respond($personalizer->next($personalization, $request->responses(), Actor::fromRequest($request)));
    }

    private function respond(PersonalizationStep $step): JsonResponse
    {
        return response()->json(['data' => [
            'personalization' => $step->id,
            'stage' => $step->stage,
            'commands' => array_map(static fn (string $apdu): string => strtoupper(bin2hex($apdu)), $step->commands),
            'expires_in' => $step->done() ? null : CardPersonalizer::STEP_SECONDS,
            'card' => [
                'card_number' => $step->card->card_number,
                'state' => $step->card->state->value,
            ],
        ]]);
    }
}
