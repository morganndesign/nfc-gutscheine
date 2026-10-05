<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Models\Restaurant;
use App\Models\User;
use Laravel\Sanctum\Sanctum;
use Symfony\Component\Mailer\SentMessage;
use Tests\TestCase;

/**
 * The invitation e-mail is German by default (DACH market), English for restaurants set to English, and all
 * wording comes from lang/<locale>/invitation.php and lang/<locale>.json.
 */
final class InvitationEmailLocalizationTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config(['mail.default' => 'array', 'giftcard.frontend_url' => 'https://app.example.test']);
    }

    private function lastMail(): SentMessage
    {
        $messages = array_values(iterator_to_array(app('mailer')->getSymfonyTransport()->messages()));
        $this->assertNotEmpty($messages);

        return end($messages);
    }

    private function onboard(string $locale = 'de-AT', string $ownerName = 'Hanna Maria Hirsch'): Restaurant
    {
        Sanctum::actingAs(User::factory()->platformAdmin()->create(['name' => 'Platform Admin', 'locale' => 'en']), ['*']);
        $id = $this->postJson('/api/v1/admin/restaurants', [
            'name' => 'Zum Goldenen Hirschen',
            'locale' => $locale,
            'owner' => ['name' => $ownerName, 'email' => 'hanna@hirsch.test'],
        ])->assertCreated()->json('data.id');

        return Restaurant::query()->findOrFail($id);
    }

    public function test_owner_invitation_is_german_by_default(): void
    {
        $this->onboard();
        $mail = $this->lastMail()->getOriginalMessage();
        $text = (string) $mail->getTextBody();
        $html = (string) $mail->getHtmlBody();

        $this->assertSame('Einladung zu GiftCard Pro', $mail->getSubject());
        foreach ([
            'Sie wurden zu GiftCard Pro eingeladen.',
            'Hallo Hanna,',
            'Sie wurden als Inhaber des Restaurants „Zum Goldenen Hirschen“ zu GiftCard Pro eingeladen.',
            'Bitte klicken Sie auf den folgenden Button, um Ihr Passwort festzulegen und Ihr Konto zu aktivieren.',
            'Passwort festlegen',
            'Dieser Link ist 72 Stunden gültig und kann nur einmal verwendet werden.',
            'Sollte der Link abgelaufen sein oder Sie Hilfe benötigen, kontaktieren Sie uns bitte unter:',
            'support@giftcardpro.at',
            'Vielen Dank,',
            'Ihr GiftCard Pro Team',
            'Falls der Button nicht funktioniert, können Sie den folgenden Link in Ihren Browser kopieren:',
            'Alle Rechte vorbehalten.',
        ] as $expected) {
            $this->assertStringContainsString($expected, $text, "text part: {$expected}");
        }

        // HTML part: same wording in the responsive template, real UTF-8 typography (not entities or ASCII quotes).
        $this->assertStringContainsString('„Zum Goldenen Hirschen“', $html);
        $this->assertStringContainsString('Passwort festlegen', $html);
        $this->assertStringContainsString('gültig', $html);
        $this->assertStringContainsString('mailto:support@giftcardpro.at', $html);
        $this->assertStringContainsString('https://app.example.test/reset-password#token=', $html);
        $this->assertStringContainsString('utf-8', strtolower((string) $mail->getHtmlCharset()));

        foreach (["If you're having trouble", 'Regards', 'Hello', 'Set your password', 'All rights reserved'] as $english) {
            $this->assertStringNotContainsString($english, $text, "no English left: {$english}");
        }

        // Sending in German does not change the language of the API response (the admin's own: English).
        $this->assertSame('en', app()->getLocale());
    }

    public function test_staff_invitation_is_german_and_names_the_inviter(): void
    {
        $restaurant = $this->restaurant(['name' => 'Café Central', 'locale' => 'de-DE']);
        $owner = $this->actingAsStaff($restaurant, RoleSlug::Owner);
        $owner->forceFill(['name' => 'Olga Owner'])->save();

        $this->postJson('/api/v1/users', ['name' => 'Walter', 'email' => 'walter@example.test', 'role' => 'waiter'])->assertCreated();
        $text = (string) $this->lastMail()->getOriginalMessage()->getTextBody();

        $this->assertStringContainsString('Hallo Walter,', $text);
        $this->assertStringContainsString('Olga Owner hat Sie eingeladen, für das Restaurant „Café Central“ Gutscheine mit GiftCard Pro zu verwalten.', $text);
        $this->assertStringContainsString('bitten Sie Ihren Manager oder den Inhaber, Ihnen die Einladung erneut zu senden', $text);
        $this->assertStringNotContainsString('support@', $text, 'Staff ask their restaurant, not the platform.');
    }

    public function test_english_restaurant_gets_the_english_invitation(): void
    {
        $this->onboard('en-GB', 'Hanna Hirsch');
        $mail = $this->lastMail()->getOriginalMessage();
        $text = (string) $mail->getTextBody();

        $this->assertSame('Your invitation to GiftCard Pro', $mail->getSubject());
        $this->assertStringContainsString('Hello Hanna,', $text);
        $this->assertStringContainsString('as the owner of the restaurant “Zum Goldenen Hirschen”', $text);
        $this->assertStringContainsString('Set your password', $text);
        $this->assertStringContainsString('If the button does not work, copy the following link into your browser:', $text);
    }

    public function test_unknown_restaurant_language_uses_the_platform_default(): void
    {
        $restaurant = $this->onboard();
        $restaurant->forceFill(['locale' => 'fr-FR'])->save();

        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/invitation")->assertOk();
        $this->assertSame('Einladung zu GiftCard Pro', $this->lastMail()->getOriginalMessage()->getSubject());

        config(['giftcard.mail_locale' => 'en']);
        $this->postJson("/api/v1/admin/restaurants/{$restaurant->id}/invitation")->assertOk();
        $this->assertSame('Your invitation to GiftCard Pro', $this->lastMail()->getOriginalMessage()->getSubject());
    }

    public function test_every_language_has_the_same_invitation_keys(): void
    {
        $de = require lang_path('de/invitation.php');
        $en = require lang_path('en/invitation.php');
        $this->assertSame(array_keys($de), array_keys($en));

        $deJson = json_decode((string) file_get_contents(lang_path('de.json')), true, flags: JSON_THROW_ON_ERROR);
        $this->assertArrayHasKey("If you're having trouble clicking the \":actionText\" button, copy and paste the URL below\ninto your web browser:", $deJson);
    }
}
