<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Enums\PresentmentPurpose;
use App\Http\Requests\ApiRequest;
use Illuminate\Validation\Rule;

final class BeginCardPresentmentRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'purpose' => ['required', 'string', Rule::enum(PresentmentPurpose::class)],
            // The NDEF URI the phone read from the card.
            'tap_url' => ['required', 'string', 'max:256'],
            // The UID the phone saw on the radio layer.
            'rf_uid' => ['required', 'string', 'regex:/^[0-9A-Fa-f]{14}$/'],
            // The card's answer to AuthenticateEV2First (key 3), part 1: E(K3, RndB).
            'challenge' => ['required', 'string', 'regex:/^[0-9A-Fa-f]{32}$/'],
        ];
    }
}
