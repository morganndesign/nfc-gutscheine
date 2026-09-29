<?php

declare(strict_types=1);

namespace App\Http\Requests\Vouchers;

use App\Enums\PresentmentMethod;
use App\Enums\PresentmentPurpose;
use App\Http\Requests\ApiRequest;
use Illuminate\Validation\Rule;

final class CreatePresentmentRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'purpose' => ['required', 'string', Rule::enum(PresentmentPurpose::class)],
            'method' => ['required', 'string', Rule::enum(PresentmentMethod::class)],
            // What the device read: the scanned QR text (printable_qr).
            'credential' => ['required', 'string', 'max:512'],
        ];
    }
}
