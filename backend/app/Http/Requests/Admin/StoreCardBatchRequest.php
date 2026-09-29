<?php

declare(strict_types=1);

namespace App\Http\Requests\Admin;

use App\Http\Requests\ApiRequest;
use Illuminate\Validation\Rule;

final class StoreCardBatchRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'restaurant_id' => ['required', 'uuid', Rule::exists('restaurants', 'id')->whereNull('deleted_at')],
            // Defaults to the one active key set.
            'key_set' => ['nullable', 'string', 'max:32', Rule::exists('key_sets', 'version')->where('status', 'active')],
            'manufacturer' => ['required', 'string', 'min:2', 'max:120'],
            'quantity' => ['required', 'integer:strict', 'min:1', 'max:100000'],
            'card_design_ref' => ['nullable', 'string', 'max:120'],
        ];
    }
}
