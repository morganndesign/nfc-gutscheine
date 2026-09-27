<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Enums\NfcTagType;
use App\Http\Requests\ApiRequest;
use Illuminate\Validation\Rule;

final class ReplaceCardRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'reason' => ['required', 'string', 'min:3', 'max:500'],
            'nfc_tag_type' => ['nullable', Rule::enum(NfcTagType::class)],
        ];
    }
}
