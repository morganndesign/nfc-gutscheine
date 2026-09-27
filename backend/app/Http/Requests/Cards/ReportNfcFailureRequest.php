<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Enums\NfcTagType;
use App\Enums\NfcWriteStage;
use App\Http\Requests\ApiRequest;
use Illuminate\Validation\Rule;

/** A programming step failed in the browser (no network round-trip happened for it). */
final class ReportNfcFailureRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'attempt_id' => ['required', 'uuid'],
            'stage' => ['required', Rule::enum(NfcWriteStage::class)],
            'result' => ['required', Rule::in(['failed', 'refused', 'cancelled'])],
            'error_code' => ['required', 'string', 'max:64', 'regex:/^[A-Z][A-Z0-9_]*$/'],
            'message' => ['nullable', 'string', 'max:500'],
            'uid' => ['nullable', 'string', 'max:40', NfcUidRule::closure()],
            'tag_type' => ['nullable', Rule::enum(NfcTagType::class)],
            'previous_url' => ['nullable', 'string', 'max:2048'],
            'read_back_url' => ['nullable', 'string', 'max:2048'],
            'timings' => ['sometimes', 'array'],
            'timings.detect_ms' => ['nullable', 'integer', 'min:0'],
            'timings.write_ms' => ['nullable', 'integer', 'min:0'],
            'timings.verify_ms' => ['nullable', 'integer', 'min:0'],
            'timings.total_ms' => ['nullable', 'integer', 'min:0'],
        ];
    }
}
