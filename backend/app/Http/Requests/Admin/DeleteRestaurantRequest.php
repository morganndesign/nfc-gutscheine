<?php

declare(strict_types=1);

namespace App\Http\Requests\Admin;

use App\Http\Requests\ApiRequest;

final class DeleteRestaurantRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return ['confirm' => ['required', 'string', 'max:80']];
    }

    /** @return array<string, string> */
    public function messages(): array
    {
        return ['confirm.required' => "Type the restaurant's short name to confirm the deletion."];
    }
}
