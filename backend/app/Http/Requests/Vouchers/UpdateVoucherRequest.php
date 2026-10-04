<?php

declare(strict_types=1);

namespace App\Http\Requests\Vouchers;

use App\Http\Requests\ApiRequest;

final class UpdateVoucherRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'customer_id' => ['sometimes', 'nullable', 'uuid', $this->existsInTenant('customers')],
            'recipient_name' => ['sometimes', 'nullable', 'string', 'max:160'],
            'gift_message' => ['sometimes', 'nullable', 'string', 'max:300'],
            'notes' => ['sometimes', 'nullable', 'string', 'max:2000'],
        ];
    }
}
