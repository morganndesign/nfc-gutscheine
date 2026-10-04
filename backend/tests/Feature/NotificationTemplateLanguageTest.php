<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Models\NotificationTemplate;
use Tests\TestCase;

/** The restaurant sees and edits only the e-mails its guests get, in the restaurant's language (2026-10-04). */
final class NotificationTemplateLanguageTest extends TestCase
{
    public function test_only_the_restaurant_language_is_listed(): void
    {
        foreach (['de_AT' => 'de', 'bs_BA' => 'bs', 'hr_HR' => 'bs', 'en_GB' => 'en'] as $locale => $language) {
            $restaurant = $this->restaurant(['locale' => $locale]);
            $this->actingAsStaff($restaurant, RoleSlug::Owner);

            $response = $this->getJson('/api/v1/settings/notification-templates')->assertOk()->assertJsonPath('language', $language);
            $this->assertSame([$language], array_values(array_unique(array_column($response->json('data'), 'locale'))), $locale);
            $this->assertEqualsCanonicalizing(array_keys(NotificationTemplate::PLACEHOLDERS), array_column($response->json('data'), 'key'));
        }
    }

    public function test_a_bosnian_restaurant_saves_its_bosnian_template(): void
    {
        $restaurant = $this->restaurant(['locale' => 'bs_BA']);
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $this->putJson('/api/v1/settings/notification-templates/voucher_issued', ['subject' => 'Vaš vaučer', 'body' => 'Zdravo {{ customer_name }}'])
            ->assertSuccessful()->assertJsonPath('data.locale', 'bs')->assertJsonPath('data.is_default', false);

        $this->assertSame('Vaš vaučer', NotificationTemplate::resolve($restaurant->id, 'voucher_issued', 'bs_BA')?->subject);
        $this->getJson('/api/v1/settings/notification-templates')->assertOk()
            ->assertJsonFragment(['key' => 'voucher_issued', 'subject' => 'Vaš vaučer']);
    }

    public function test_a_switched_off_email_is_not_sent_instead_of_falling_back_to_the_default(): void
    {
        $restaurant = $this->restaurant(['locale' => 'de_AT']);
        $this->actingAsStaff($restaurant, RoleSlug::Owner);

        $this->putJson('/api/v1/settings/notification-templates/voucher_reloaded', ['subject' => 'x', 'body' => 'y', 'is_active' => false])->assertSuccessful();

        $this->assertNull(NotificationTemplate::resolve($restaurant->id, 'voucher_reloaded', 'de_AT'));
        $this->assertNotNull(NotificationTemplate::resolve($restaurant->id, 'voucher_issued', 'de_AT'));
        $this->getJson('/api/v1/settings/notification-templates')->assertOk()->assertJsonFragment(['key' => 'voucher_reloaded', 'is_active' => false]);
    }

    public function test_after_a_language_change_guests_get_the_new_language_not_an_old_custom_version(): void
    {
        $restaurant = $this->restaurant(['locale' => 'en_GB']);
        $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $this->putJson('/api/v1/settings/notification-templates/voucher_issued', ['subject' => 'Custom', 'body' => 'b'])->assertSuccessful();

        $restaurant->update(['locale' => 'de_AT']);

        $this->assertSame('de', NotificationTemplate::resolve($restaurant->id, 'voucher_issued', 'de_AT')?->locale);
    }
}
