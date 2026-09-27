<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Data\ScanInput;
use App\Enums\ScanMethod;
use App\Http\Requests\ApiRequest;
use App\Services\GiftCards\NfcUid;
use Closure;
use Illuminate\Validation\Rule;

final class ScanCardRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'method' => ['required', Rule::enum(ScanMethod::class)],
            // Raw NDEF URL / QR content / public token.
            'token' => ['required_without:card_number', 'nullable', 'string', 'max:500'],
            'card_number' => ['required_without:token', 'nullable', 'string', 'max:30'],
            'nfc_uid' => ['nullable', 'string', 'max:40', static function (string $attribute, mixed $value, Closure $fail): void {
                if (is_string($value) && ! NfcUid::isValid($value)) {
                    $fail('The NFC serial number is not valid.');
                }
            }],
            'picc' => ['nullable', 'string', 'size:32', 'regex:/^[0-9A-Fa-f]+$/'],
            'cmac' => ['nullable', 'string', 'size:16', 'regex:/^[0-9A-Fa-f]+$/'],
        ];
    }

    public function toInput(): ScanInput
    {
        $token = $this->validated('token');
        $picc = $this->validated('picc');
        $cmac = $this->validated('cmac');

        // SUN parameters may arrive embedded in the scanned URL.
        if (is_string($token) && ($picc === null || $cmac === null)) {
            $query = parse_url($token, PHP_URL_QUERY);
            if (is_string($query)) {
                parse_str($query, $params);
                $picc ??= isset($params['picc']) && is_string($params['picc']) && preg_match('/^[0-9A-Fa-f]{32}$/', $params['picc']) ? $params['picc'] : null;
                $cmac ??= isset($params['cmac']) && is_string($params['cmac']) && preg_match('/^[0-9A-Fa-f]{16}$/', $params['cmac']) ? $params['cmac'] : null;
            }
        }

        return new ScanInput(
            method: ScanMethod::from((string) $this->validated('method')),
            token: $token,
            cardNumber: $this->validated('card_number'),
            nfcUid: $this->validated('nfc_uid'),
            picc: $picc,
            cmac: $cmac,
        );
    }
}
