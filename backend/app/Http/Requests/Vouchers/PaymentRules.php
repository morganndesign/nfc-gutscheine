<?php

declare(strict_types=1);

namespace App\Http\Requests\Vouchers;

use App\Enums\PaymentMethod;
use Illuminate\Validation\Rule;

/**
 * Validation of the `payment` object of a sale or reload (decision 25).
 */
final class PaymentRules
{
    /** @return array<string, mixed> */
    public static function rules(): array
    {
        return [
            'payment' => ['required', 'array:method,reference,reason'],
            'payment.method' => ['required', 'string', Rule::in(PaymentMethod::tillValues())],
            'payment.reference' => [
                'nullable', 'string', 'max:120',
                Rule::requiredIf(static fn (): bool => in_array(request()->input('payment.method'), [PaymentMethod::CardTerminal->value, PaymentMethod::BankTransfer->value], true)),
            ],
            'payment.reason' => [
                'nullable', 'string', 'min:3', 'max:500',
                Rule::requiredIf(static fn (): bool => request()->input('payment.method') === PaymentMethod::Complimentary->value),
            ],
        ];
    }
}
