<?php

declare(strict_types=1);

namespace App\Http\Requests\Cards;

use App\Http\Requests\ApiRequest;

final class ContinuePersonalizationRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            // The chip's answers to the last round's commands, in order, each with its status word.
            'responses' => ['required', 'array', 'min:1', 'max:12'],
            'responses.*' => ['required', 'string', 'regex:/^(?:[0-9A-Fa-f]{2}){2,258}$/'],
        ];
    }

    /** @return list<string> */
    public function responses(): array
    {
        /** @var list<string> $hex */
        $hex = $this->validated('responses');

        return array_map(static fn (string $h): string => (string) hex2bin($h), $hex);
    }
}
