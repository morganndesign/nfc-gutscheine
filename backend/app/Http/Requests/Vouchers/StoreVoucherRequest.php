<?php

declare(strict_types=1);

namespace App\Http\Requests\Vouchers;

use App\Enums\Permission;
use App\Http\Requests\ApiRequest;
use App\Models\User;

/**
 * Sale of a voucher. Amounts are integers in minor units; floats, strings and booleans are refused (audit P9).
 * A card sale (`form: card`) also needs `cards.bind` and a fresh presentment of the tapped stock card: a `bind` tap, or
 * the till's top-up tap (`reload`) of a card that turned out to be new.
 */
final class StoreVoucherRequest extends ApiRequest
{
    public function authorize(): bool
    {
        $user = $this->user();

        return $this->input('form') !== 'card' || ($user instanceof User && $user->hasPermission(Permission::CardsBind));
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'value' => ['required', 'integer:strict', 'min:1', 'max:100000000'],
            // How the voucher is handed over: a printed QR, or a physical card tapped for this sale.
            'form' => ['required', 'string', 'in:printable,card'],
            'presentment_id' => ['required_if:form,card', 'prohibited_unless:form,card', 'uuid'],
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
