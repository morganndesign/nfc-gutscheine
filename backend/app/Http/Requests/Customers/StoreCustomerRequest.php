<?php

declare(strict_types=1);

namespace App\Http\Requests\Customers;

use App\Http\Requests\ApiRequest;

final class StoreCustomerRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        $required = $this->isMethod('POST') ? 'required_without_all:last_name,email,phone' : 'sometimes';

        return [
            'first_name' => [$required, 'nullable', 'string', 'max:100'],
            'last_name' => ['sometimes', 'nullable', 'string', 'max:100'],
            'email' => ['sometimes', 'nullable', 'email:rfc', 'max:191'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:40', 'regex:/^[0-9+\-\s()\/]*$/'],
            'notes' => ['sometimes', 'nullable', 'string', 'max:2000'],
            'marketing_consent' => ['sometimes', 'boolean'],
        ];
    }
}
