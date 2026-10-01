<?php

declare(strict_types=1);

namespace App\Http\Requests\Admin;

use App\Http\Requests\ApiRequest;
use App\Http\Requests\Settings\UpdateRestaurantRequest as RestaurantProfileRules;
use Illuminate\Validation\Rule;

/**
 * Platform admin edit of a restaurant: everything the restaurant may edit itself, plus plan and currency
 * (the currency only until the first gift card exists, enforced by RestaurantService).
 */
final class UpdateRestaurantRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            ...(new RestaurantProfileRules)->rules(),
            'currency' => ['sometimes', 'required', 'string', 'size:3', 'alpha', Rule::in(['EUR', 'CHF', 'USD', 'GBP'])],
        ];
    }
}
