<?php

declare(strict_types=1);

namespace App\Http\Requests\Online;

use App\Http\Requests\ApiRequest;

/** A guest's order in a restaurant's shop (public). */
final class StartOrderRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'amount' => ['required', 'integer', 'min:1', 'max:1000000'],
            'buyer_email' => ['required', 'string', 'email:rfc', 'max:254'],
            'buyer_name' => ['nullable', 'string', 'max:120'],
            'recipient_name' => ['nullable', 'string', 'max:120'],
            'gift_message' => ['nullable', 'string', 'max:300'],
            'card_pickup' => ['sometimes', 'boolean'],
            'locale' => ['nullable', 'string', 'in:de,en,bs'],
            // The buyer agrees to the restaurant's terms (the restaurant is the seller).
            'accept_terms' => ['accepted'],
            // A field people never see: a bot fills it.
            'website' => ['prohibited'],
        ];
    }
}
