<?php

declare(strict_types=1);

namespace App\Http\Requests\Admin;

use App\Http\Requests\ApiRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

final class StoreRestaurantRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:160'],
            'slug' => ['nullable', 'string', 'max:60', 'alpha_dash'],
            'legal_name' => ['nullable', 'string', 'max:200'],
            'vat_number' => ['nullable', 'string', 'max:40'],
            'email' => ['nullable', 'email:rfc', 'max:191'],
            'phone' => ['nullable', 'string', 'max:40'],
            'address_line1' => ['nullable', 'string', 'max:191'],
            'postal_code' => ['nullable', 'string', 'max:20'],
            'city' => ['nullable', 'string', 'max:100'],
            'country' => ['nullable', 'string', 'size:2', 'alpha'],
            'currency' => ['nullable', 'string', 'size:3', 'alpha', Rule::in(['EUR', 'CHF', 'USD', 'GBP'])],
            'timezone' => ['nullable', 'timezone:all'],
            'locale' => ['nullable', 'in:de-AT,de-DE,de-CH,en-GB,en-US'],
            'plan' => ['nullable', 'string', 'max:40'],
            'owner' => ['required', 'array'],
            'owner.name' => ['required', 'string', 'max:160'],
            'owner.email' => ['required', 'email:rfc', 'max:191', Rule::unique('users', 'email')],
            'owner.password' => ['nullable', 'string', Password::defaults()],
        ];
    }

    /** @return array<string, string> */
    public function attributes(): array
    {
        return [
            'owner.name' => "owner's name",
            'owner.email' => "owner's e-mail address",
            'owner.password' => "owner's password",
        ];
    }
}
