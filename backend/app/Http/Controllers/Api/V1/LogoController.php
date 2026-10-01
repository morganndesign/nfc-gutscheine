<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\RestaurantSettingsResource;
use App\Models\RestaurantLogo;
use App\Services\Branding\LogoService;
use App\Support\Actor;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Http\UploadedFile;

/** The restaurant's logo: owners upload and remove it; every signed-in staff member and phone of the restaurant reads it. */
final class LogoController extends Controller
{
    public function __construct(private readonly LogoService $logos) {}

    public function show(Request $request): Response
    {
        $restaurant = $this->tenant()->require();
        $logo = RestaurantLogo::query()->whereKey($restaurant->getKey())->first();
        abort_if($logo === null, 404);

        $etag = '"'.(string) $restaurant->settings->logo_version.'"';
        if ($request->header('If-None-Match') === $etag) {
            return response('', 304, ['ETag' => $etag]);
        }

        return response((string) base64_decode($logo->data, true), 200, [
            'Content-Type' => $logo->mime,
            'ETag' => $etag,
            // The URL carries the version: private caches may keep it.
            'Cache-Control' => 'private, max-age=31536000, immutable',
            'X-Content-Type-Options' => 'nosniff',
            'Content-Security-Policy' => "default-src 'none'",
        ]);
    }

    public function store(Request $request): RestaurantSettingsResource
    {
        $request->validate(['logo' => ['required', 'file', 'mimes:png,jpg,jpeg', 'max:2048']]);
        $restaurant = $this->tenant()->require();
        /** @var UploadedFile $file */
        $file = $request->file('logo');
        $this->logos->store(Actor::fromRequest($request), $restaurant, $file);

        return RestaurantSettingsResource::make($restaurant->settings->refresh());
    }

    public function destroy(Request $request): RestaurantSettingsResource
    {
        $restaurant = $this->tenant()->require();
        $this->logos->remove(Actor::fromRequest($request), $restaurant);

        return RestaurantSettingsResource::make($restaurant->settings->refresh());
    }
}
