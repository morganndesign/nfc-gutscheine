<?php

declare(strict_types=1);

namespace App\Http\Requests\Online;

use App\Http\Requests\ApiRequest;

final class UpdateOnlineShopRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'enabled' => ['sometimes', 'boolean'],
            'amounts' => ['sometimes', 'array', 'min:1', 'max:6'],
            'amounts.*' => ['integer', 'min:1'],
            'custom_amount' => ['sometimes', 'boolean'],
            'max_amount' => ['sometimes', 'integer', 'min:1'],
            'card_pickup' => ['sometimes', 'boolean'],
            'headline' => ['sometimes', 'nullable', 'string', 'max:120'],
            'intro' => ['sometimes', 'nullable', 'string', 'max:600'],
            'terms_url' => ['sometimes', 'nullable', 'string', 'url:https', 'max:500'],
            'imprint_url' => ['sometimes', 'nullable', 'string', 'url:https', 'max:500'],
        ];
    }
}
