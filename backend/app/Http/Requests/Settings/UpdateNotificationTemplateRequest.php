<?php

declare(strict_types=1);

namespace App\Http\Requests\Settings;

use App\Http\Requests\ApiRequest;

final class UpdateNotificationTemplateRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'subject' => ['required', 'string', 'max:200'],
            'body' => ['required', 'string', 'max:10000'],
            'is_active' => ['sometimes', 'boolean'],
            'locale' => ['sometimes', 'string', 'in:en,de'],
        ];
    }
}
