<?php

declare(strict_types=1);

namespace App\Http\Requests\Settings;

use App\Http\Requests\ApiRequest;

final class UpdateDeviceRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'required', 'string', 'max:120'],
            'type' => ['sometimes', 'required', 'in:phone,tablet,desktop,pos,integration'],
        ];
    }
}
