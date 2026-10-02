<?php

declare(strict_types=1);

namespace App\Http\Requests\Admin;

use App\Enums\CardBatchStatus;
use App\Http\Requests\ApiRequest;
use Illuminate\Validation\Rule;

/** The special status changes only: release, shipping and the restaurant's receipt have their own endpoints. */
final class ChangeCardBatchStatusRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        $special = array_filter(CardBatchStatus::cases(), static fn (CardBatchStatus $s): bool => ! $s->hasOwnStep() && $s !== CardBatchStatus::InProduction);

        return [
            'status' => ['required', 'string', Rule::in(array_values(array_map(static fn (CardBatchStatus $s): string => $s->value, $special)))],
            'reason' => ['required', 'string', 'min:3', 'max:120'],
            'production_date' => ['nullable', 'date_format:Y-m-d'],
        ];
    }
}
