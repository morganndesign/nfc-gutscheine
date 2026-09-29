<?php

declare(strict_types=1);

namespace App\Http\Requests\Admin;

use App\Enums\CardBatchStatus;
use App\Http\Requests\ApiRequest;
use Illuminate\Validation\Rule;

final class ChangeCardBatchStatusRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            // Acceptance (two approvals) and the restaurant's receipt have their own endpoints.
            'status' => ['required', 'string', Rule::in(array_values(array_diff(
                array_column(CardBatchStatus::cases(), 'value'),
                [CardBatchStatus::Ordered->value, CardBatchStatus::Accepted->value, CardBatchStatus::InService->value, CardBatchStatus::OnHold->value],
            )))],
            'reason' => ['required', 'string', 'min:3', 'max:120'],
            'tracking_ref' => ['nullable', 'string', 'max:120'],
            'production_date' => ['nullable', 'date_format:Y-m-d'],
        ];
    }
}
