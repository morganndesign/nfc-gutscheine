<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Enums\NfcTagType;
use App\Enums\NfcWriteMethod;
use App\Http\Requests\ApiRequest;
use Illuminate\Validation\Rule;

/**
 * Records the tag of a card.
 *
 * - `web_nfc`: written and read back by the dashboard. The UID is stored only here, together with the
 *   read-back proof (`read_back.uid`, `read_back.url`), and only for NTAG213/215/216 (detected type).
 * - `manual` (external writer app), `provisioned` (NTAG 424 DNA), `printed` (QR only): no UID is accepted.
 */
final class BindNfcTagRequest extends ApiRequest
{
    public const NTAG21X = ['ntag213', 'ntag215', 'ntag216'];

    /** @return array<string, mixed> */
    public function rules(): array
    {
        $method = $this->input('method');
        $web = $method === NfcWriteMethod::WebNfc->value;

        $tagTypes = match ($method) {
            NfcWriteMethod::WebNfc->value, NfcWriteMethod::Manual->value => self::NTAG21X,
            NfcWriteMethod::Provisioned->value => [NfcTagType::Ntag424Dna->value],
            NfcWriteMethod::Printed->value => [NfcTagType::QrOnly->value],
            default => NfcTagType::values(),
        };

        return [
            'method' => ['required', Rule::enum(NfcWriteMethod::class)],
            'tag_type' => ['required', Rule::in($tagTypes)],
            'attempt_id' => [$web ? 'required' : 'nullable', 'uuid'],
            'uid' => $web
                ? ['required', 'string', 'max:40', NfcUidRule::closure()]
                : ['prohibited'],
            'read_back' => $web ? ['required', 'array'] : ['prohibited'],
            'read_back.uid' => $web ? ['required', 'string', 'max:40'] : [],
            'read_back.url' => $web ? ['required', 'string', 'max:2048'] : [],
            'locked' => $web ? ['sometimes', 'boolean', 'declined'] : ['sometimes', 'boolean'],
            // Programming station: refuse if the card got a tag in the meantime (another phone).
            'only_if_unprogrammed' => ['sometimes', 'boolean'],
            'timings' => ['sometimes', 'array'],
            'timings.detect_ms' => ['nullable', 'integer', 'min:0'],
            'timings.write_ms' => ['nullable', 'integer', 'min:0'],
            'timings.verify_ms' => ['nullable', 'integer', 'min:0'],
            'timings.total_ms' => ['nullable', 'integer', 'min:0'],
        ];
    }

    /** @return array<string, string> */
    public function messages(): array
    {
        return [
            'uid.prohibited' => 'A chip serial number is only saved when the dashboard wrote and verified the tag.',
            'locked.declined' => 'Lock the tag after it was verified (POST /cards/{card}/nfc/lock).',
        ];
    }
}
