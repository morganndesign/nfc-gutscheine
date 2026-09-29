<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\SystemSetting;
use App\Support\AppVersion;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Public start-up configuration for the native waiter app: minimum supported versions, the platform
 * maintenance notice and the support contact. Read on launch and on resume; cacheable.
 */
final class AppConfigController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'platform' => ['sometimes', 'string', 'in:android,ios'],
            'version' => ['sometimes', 'string', 'regex:'.AppVersion::PATTERN],
        ]);

        $minimum = [
            'android' => $this->version('app.min_version.android'),
            'ios' => $this->version('app.min_version.ios'),
        ];

        $platform = $validated['platform'] ?? null;
        $version = $validated['version'] ?? null;
        $notice = SystemSetting::get('platform.maintenance_notice');

        return response()->json([
            'data' => [
                'min_version' => $minimum,
                'update_required' => $platform !== null && $version !== null ? AppVersion::isBelow($version, $minimum[$platform]) : null,
                'maintenance_notice' => is_string($notice) && trim($notice) !== '' ? trim($notice) : null,
                'support_email' => SystemSetting::get('platform.support_email'),
            ],
        ])->header('Cache-Control', 'public, max-age=60');
    }

    private function version(string $key): ?string
    {
        $value = SystemSetting::get($key);

        return is_string($value) && AppVersion::isValid($value) ? $value : null;
    }
}
