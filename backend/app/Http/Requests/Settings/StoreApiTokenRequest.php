<?php

declare(strict_types=1);

namespace App\Http\Requests\Settings;

use App\Http\Requests\ApiRequest;
use App\Services\ApiTokens\ApiTokenService;
use Illuminate\Validation\Rule;

final class StoreApiTokenRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:120'],
            'abilities' => ['required', 'array', 'min:1'],
            'abilities.*' => ['string', Rule::in(ApiTokenService::INTEGRATION_ABILITIES)],
            'expires_at' => ['nullable', 'date', 'after:today'],
        ];
    }
}
