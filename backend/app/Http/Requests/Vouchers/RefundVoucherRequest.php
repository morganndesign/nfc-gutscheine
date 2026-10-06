<?php

declare(strict_types=1);

namespace App\Http\Requests\Vouchers;

use App\Enums\PaymentMethod;
use App\Http\Requests\ApiRequest;
use Illuminate\Validation\Rule;

final class RefundVoucherRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            // How the money goes back to the guest; never "complimentary". `online`: back to the guest's card through the
            // payment provider (online vouchers only; the provider's refund id becomes the reference).
            'payment' => ['required', 'array:method,reference'],
            'payment.method' => ['required', 'string', Rule::in([PaymentMethod::Cash->value, PaymentMethod::CardTerminal->value, PaymentMethod::BankTransfer->value, PaymentMethod::Online->value])],
            'payment.reference' => [
                'nullable', 'string', 'max:120',
                Rule::requiredIf(fn (): bool => in_array($this->input('payment.method'), [PaymentMethod::CardTerminal->value, PaymentMethod::BankTransfer->value], true)),
            ],
            'reason' => ['required', 'string', 'min:3', 'max:500'],
        ];
    }
}
