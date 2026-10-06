<?php

declare(strict_types=1);

namespace App\Http\Requests\Online;

use App\Http\Requests\ApiRequest;

/** The gift card of an online voucher, picked up at the restaurant: the voucher's QR and a stock card, both tapped. */
final class CardPickupRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'qr_presentment_id' => ['required', 'uuid'],
            'presentment_id' => ['required', 'uuid'],
        ];
    }
}
