<?php

declare(strict_types=1);

namespace App\Http\Requests\Vouchers;

use App\Enums\VoucherKind;
use App\Enums\VoucherStatus;
use App\Http\Requests\ApiRequest;

final class VoucherIndexRequest extends ApiRequest
{
    public const SORTS = ['created_at', '-created_at', 'balance', '-balance', 'expires_at', '-expires_at', 'voucher_number', '-voucher_number', 'last_used_at', '-last_used_at'];

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'search' => ['nullable', 'string', 'max:100'],
            'status' => ['nullable', 'array'],
            'status.*' => ['string', 'in:'.implode(',', VoucherStatus::values())],
            'customer_id' => ['nullable', 'uuid'],
            'created_from' => ['nullable', 'date'],
            'created_to' => ['nullable', 'date'],
            'expires_from' => ['nullable', 'date'],
            'expires_to' => ['nullable', 'date'],
            'min_balance' => ['nullable', 'integer', 'min:0'],
            'max_balance' => ['nullable', 'integer', 'min:0'],
            'kind' => ['nullable', 'string', 'in:'.implode(',', VoucherKind::values())],
            'sort' => ['nullable', 'in:'.implode(',', self::SORTS)],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ];
    }

    protected function prepareForValidation(): void
    {
        $status = $this->input('status');
        if (is_string($status)) {
            $this->merge(['status' => array_filter(explode(',', $status))]);
        }
    }
}
