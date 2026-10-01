<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Settings\UpdateRestaurantRequest;
use App\Http\Requests\Settings\UpdateVoucherSettingsRequest;
use App\Http\Resources\RestaurantResource;
use App\Http\Resources\RestaurantSettingsResource;
use App\Services\Audit\AuditLogger;
use App\Services\Restaurants\RestaurantService;
use App\Support\Actor;
use Illuminate\Validation\ValidationException;

final class SettingsController extends Controller
{
    public function __construct(private readonly AuditLogger $audit) {}

    public function show(): RestaurantResource
    {
        return RestaurantResource::make($this->tenant()->require()->load('settings'));
    }

    public function updateRestaurant(UpdateRestaurantRequest $request, RestaurantService $restaurants): RestaurantResource
    {
        $restaurant = $restaurants->update(Actor::fromRequest($request), $this->tenant()->require(), $request->validated());

        return RestaurantResource::make($restaurant->load('settings'));
    }

    public function updateVoucherSettings(UpdateVoucherSettingsRequest $request): RestaurantSettingsResource
    {
        $settings = $this->tenant()->require()->settings;
        $settings->fill($request->validated());

        if ($settings->min_voucher_value > $settings->max_voucher_balance) {
            throw ValidationException::withMessages(['min_voucher_value' => __('api.min_above_max')]);
        }
        if ($settings->max_debit_per_transaction > $settings->max_debit_per_voucher_per_day) {
            throw ValidationException::withMessages(['max_debit_per_transaction' => __('api.debit_above_daily')]);
        }

        if ($settings->isDirty()) {
            $old = array_intersect_key($settings->getOriginal(), $settings->getDirty());
            $new = $settings->getDirty();
            $settings->save();
            $this->audit->log('restaurant.settings_updated', Actor::fromRequest($request), $settings, $old, $new);
        }

        return RestaurantSettingsResource::make($settings);
    }
}
