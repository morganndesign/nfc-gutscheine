<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Settings\UpdateCardSettingsRequest;
use App\Http\Requests\Settings\UpdateRestaurantRequest;
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

    public function updateCardSettings(UpdateCardSettingsRequest $request): RestaurantSettingsResource
    {
        $settings = $this->tenant()->require()->settings;
        $settings->fill($request->validated());

        if ($settings->min_card_value > $settings->max_card_value) {
            throw ValidationException::withMessages(['min_card_value' => 'The minimum card value must not exceed the maximum card value.']);
        }
        if ($settings->max_card_value > $settings->max_card_balance) {
            throw ValidationException::withMessages(['max_card_value' => 'The maximum card value must not exceed the maximum card balance.']);
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
