<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\GiftCardStatus;
use App\Enums\RestaurantStatus;
use App\Enums\TransactionType;
use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\UpdateSystemSettingsRequest;
use App\Http\Resources\AuditLogResource;
use App\Models\AuditLog;
use App\Models\GiftCard;
use App\Models\GiftCardTransaction;
use App\Models\Restaurant;
use App\Models\SystemSetting;
use App\Services\Audit\AuditLogger;
use App\Support\Actor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

final class PlatformController extends Controller
{
    public function stats(): JsonResponse
    {
        $monthStart = Carbon::now()->startOfMonth();

        return response()->json(['data' => [
            'restaurants_total' => Restaurant::query()->count(),
            'restaurants_active' => Restaurant::query()->where('status', RestaurantStatus::Active->value)->count(),
            'cards_total' => GiftCard::query()->withoutGlobalScopes()->count(),
            'cards_active' => GiftCard::query()->withoutGlobalScopes()->where('status', GiftCardStatus::Active->value)->count(),
            'transactions_this_month' => GiftCardTransaction::query()->withoutGlobalScopes()->where('created_at', '>=', $monthStart)->count(),
            'volume_sold_this_month' => (int) GiftCardTransaction::query()->withoutGlobalScopes()
                ->whereIn('type', [TransactionType::Issue->value, TransactionType::Reload->value])
                ->whereNull('reversed_at')
                ->where('created_at', '>=', $monthStart)
                ->sum('amount'),
        ]]);
    }

    public function auditLogs(Request $request): AnonymousResourceCollection
    {
        $v = $request->validate([
            'restaurant_id' => ['nullable', 'uuid'],
            'action' => ['nullable', 'string', 'max:80'],
        ]);

        $logs = AuditLog::query()
            ->withoutGlobalScopes()
            ->with(['user', 'restaurant'])
            ->when($v['restaurant_id'] ?? null, static fn ($q, $id) => $q->where('restaurant_id', $id))
            ->when($v['action'] ?? null, static fn ($q, $a) => $q->where('action', 'like', addcslashes((string) $a, '%_\\').'%'))
            ->latest('created_at')
            ->orderByDesc('id')
            ->paginate($this->perPage($request, 50))
            ->withQueryString();

        return AuditLogResource::collection($logs);
    }

    public function settings(): JsonResponse
    {
        return response()->json(['data' => SystemSetting::query()->orderBy('key')->get(['key', 'value', 'type', 'description', 'is_public'])]);
    }

    public function updateSettings(UpdateSystemSettingsRequest $request, AuditLogger $audit): JsonResponse
    {
        DB::transaction(function () use ($request, $audit): void {
            /** @var list<array{key: string, value: mixed}> $items */
            $items = $request->validated('settings');
            foreach ($items as $item) {
                /** @var SystemSetting $setting */
                $setting = SystemSetting::query()->where('key', $item['key'])->firstOrFail();
                $old = $setting->value;
                $setting->value = $this->cast($setting->type, $item['value']);
                if ($setting->isDirty('value')) {
                    $setting->save();
                    $audit->log('system_setting.updated', Actor::fromRequest($request), $setting, ['value' => $old], ['value' => $setting->value], restaurantId: null);
                }
            }
        });

        return $this->settings();
    }

    private function cast(string $type, mixed $value): mixed
    {
        return match ($type) {
            'boolean' => filter_var($value, FILTER_VALIDATE_BOOLEAN),
            'integer' => (int) $value,
            'string' => $value === null ? null : mb_substr((string) $value, 0, 2000),
            default => $value,
        };
    }
}
