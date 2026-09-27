<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Settings\UpdateDeviceRequest;
use App\Http\Resources\DeviceResource;
use App\Models\Device;
use App\Services\Devices\DeviceService;
use App\Support\Actor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

final class DeviceController extends Controller
{
    public function __construct(private readonly DeviceService $devices) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        return DeviceResource::collection(
            Device::query()->with('lastUser')->orderByDesc('last_seen_at')->paginate($this->perPage($request, 50)),
        );
    }

    /** The device making this request (auto-registered through the X-Device-Id header). */
    public function current(Request $request): JsonResponse
    {
        $device = $request->attributes->get('device');

        return response()->json(['data' => $device instanceof Device ? DeviceResource::make($device)->resolve($request) : null]);
    }

    public function update(UpdateDeviceRequest $request, Device $device): DeviceResource
    {
        /** @var array{name?: string, type?: string} $data */
        $data = $request->validated();

        return DeviceResource::make($this->devices->update(Actor::fromRequest($request), $device, $data));
    }

    public function revoke(Request $request, Device $device): DeviceResource
    {
        return DeviceResource::make($this->devices->revoke(Actor::fromRequest($request), $device));
    }

    public function restore(Request $request, Device $device): DeviceResource
    {
        return DeviceResource::make($this->devices->restore(Actor::fromRequest($request), $device));
    }
}
