<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Enums\CardState;
use App\Http\Requests\ApiRequest;
use Illuminate\Validation\Rule;

final class CardIndexRequest extends ApiRequest
{
    /** `state[]=a&state[]=b` or `state=a,b`. */
    protected function prepareForValidation(): void
    {
        $state = $this->input('state');
        if (is_string($state)) {
            $this->merge(['state' => array_values(array_filter(explode(',', $state)))]);
        }
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'state' => ['nullable', 'array'],
            'state.*' => ['string', Rule::in(CardState::values())],
            // Inventory number or its tail.
            'search' => ['nullable', 'string', 'max:32', 'regex:/^[A-Za-z0-9-]+$/'],
            'batch' => ['nullable', 'string', 'max:20'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ];
    }
}
