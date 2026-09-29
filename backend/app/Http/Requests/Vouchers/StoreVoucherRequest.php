<?php

declare(strict_types=1);

namespace App\Http\Requests\Vouchers;

use App\Http\Requests\ApiRequest;

/**
 * Sale of a voucher. Amounts are integers in minor units; floats, strings and booleans are refused (audit P9).
 */
final class StoreVoucherRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'value' => ['required', 'integer:strict', 'min:1', 'max:100000000'],
            // How the voucher is handed over. Card vouchers are sold by binding a card (Phase 5), e-mail
            // vouchers arrive with the online shop (Phase 7).
            'form' => ['required', 'string', 'in:printable'],
            ...PaymentRules::rules(),
            'customer_id' => ['nullable', 'uuid', $this->existsInTenant('customers')],
            'customer' => ['nullable', 'array', 'prohibits:customer_id'],
            'customer.first_name' => ['nullable', 'string', 'max:100'],
            'customer.last_name' => ['nullable', 'string', 'max:100'],
            'customer.email' => ['nullable', 'email:rfc', 'max:191'],
            'customer.phone' => ['nullable', 'string', 'max:40'],
            'customer.marketing_consent' => ['nullable', 'boolean'],
            'recipient_name' => ['nullable', 'string', 'max:160'],
            'notes' => ['nullable', 'string', 'max:2000'],
        ];
    }
}
