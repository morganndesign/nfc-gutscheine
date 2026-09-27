<?php

declare(strict_types=1);

namespace App\Http\Requests\Settings;

use App\Http\Requests\ApiRequest;

final class UpdateRestaurantRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'required', 'string', 'max:160'],
            'legal_name' => ['sometimes', 'nullable', 'string', 'max:200'],
            'vat_number' => ['sometimes', 'nullable', 'string', 'max:40'],
            'email' => ['sometimes', 'nullable', 'email:rfc', 'max:191'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:40'],
            'website' => ['sometimes', 'nullable', 'url:https,http', 'max:191'],
            'address_line1' => ['sometimes', 'nullable', 'string', 'max:191'],
            'address_line2' => ['sometimes', 'nullable', 'string', 'max:191'],
            'postal_code' => ['sometimes', 'nullable', 'string', 'max:20'],
            'city' => ['sometimes', 'nullable', 'string', 'max:100'],
            'country' => ['sometimes', 'required', 'string', 'size:2', 'alpha'],
            'timezone' => ['sometimes', 'required', 'timezone:all'],
            'locale' => ['sometimes', 'required', 'string', 'in:de-AT,de-DE,de-CH,en-GB,en-US'],
        ];
    }
}
