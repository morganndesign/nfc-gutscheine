<?php

declare(strict_types=1);

namespace App\Http\Requests\Admin;

use App\Http\Requests\ApiRequest;
use App\Support\AppVersion;
use Illuminate\Validation\Validator;

final class UpdateSystemSettingsRequest extends ApiRequest
{
    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'settings' => ['required', 'array', 'min:1'],
            'settings.*.key' => ['required', 'string', 'exists:system_settings,key'],
            'settings.*.value' => ['present'],
        ];
    }

    /** @return list<callable(Validator): void> */
    public function after(): array
    {
        return [
            function (Validator $validator): void {
                /** @var array<int, array{key?: mixed, value?: mixed}> $items */
                $items = (array) $this->input('settings', []);
                foreach ($items as $i => $item) {
                    $key = $item['key'] ?? null;
                    $value = $item['value'] ?? null;
                    if (is_string($key) && str_starts_with($key, 'app.min_version.') && $value !== null && $value !== ''
                        && ! AppVersion::isValid(is_string($value) ? $value : null)) {
                        $validator->errors()->add("settings.{$i}.value", 'Use a version like 1.0.0, or leave it empty.');
                    }
                }
            },
        ];
    }
}
