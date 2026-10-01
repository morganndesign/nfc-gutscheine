<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\User;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

final class PlatformAuditRestaurantFilterTest extends TestCase
{
    /** @return list<string> */
    private function restaurantIds(string $query): array
    {
        $data = $this->getJson('/api/v1/admin/audit-logs'.$query)->assertOk()->json('data');

        return array_values(array_unique(array_map(static fn (array $row): string => (string) ($row['restaurant']['id'] ?? 'platform'), $data)));
    }

    private function entry(?string $restaurantId, string $action): void
    {
        AuditLog::query()->withoutGlobalScopes()->create([
            'restaurant_id' => $restaurantId,
            'action' => $action,
        ]);
    }

    public function test_platform_audit_filters_by_restaurant_or_platform(): void
    {
        $a = $this->restaurant();
        $b = $this->restaurant();
        $archived = $this->restaurant();
        $this->entry($a->id, 'restaurant.updated');
        $this->entry($b->id, 'restaurant.updated');
        $this->entry($archived->id, 'restaurant.archived');
        $this->entry(null, 'system_setting.updated');
        $archived->delete();

        Sanctum::actingAs(User::factory()->platformAdmin()->create(), ['*']);

        $this->assertSame([$a->id], $this->restaurantIds("?restaurant={$a->id}"));
        $this->assertSame([$archived->id], $this->restaurantIds("?restaurant={$archived->id}"));
        $this->assertSame(['platform'], $this->restaurantIds('?restaurant=platform'));
        $this->assertEqualsCanonicalizing([$a->id, $b->id, $archived->id, 'platform'], $this->restaurantIds(''));
        // The older parameter keeps working.
        $this->assertSame([$b->id], $this->restaurantIds("?restaurant_id={$b->id}"));
        // Combined with the action filter.
        $this->assertSame([], $this->restaurantIds("?restaurant={$a->id}&action=system_setting."));

        $this->getJson('/api/v1/admin/audit-logs?restaurant=nope')->assertUnprocessable()->assertJsonValidationErrors('restaurant');
    }
}
