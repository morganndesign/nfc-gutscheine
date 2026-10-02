<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use Symfony\Component\Mime\Email;
use Tests\TestCase;

/**
 * "Forgot password" is sent by the queue worker, whose application language is the server default (APP_LOCALE, "en"
 * in production): the e-mail must still be in the language the user chose (de, en, bs), with every line translated.
 */
final class PasswordResetEmailTest extends TestCase
{
    private function resetMailFor(string $locale): Email
    {
        config(['mail.default' => 'array']);
        app()->setLocale('en');
        $restaurant = $this->restaurant();
        $user = $this->staff($restaurant, RoleSlug::Manager, ['email' => "m-{$locale}@example.com", 'locale' => $locale]);
        $user->forceFill(['last_login_at' => now()])->save();

        $this->postJson('/api/v1/auth/forgot-password', ['email' => "m-{$locale}@example.com"])->assertOk();

        $messages = array_values(iterator_to_array(app('mailer')->getSymfonyTransport()->messages()));
        $this->assertCount(1, $messages);
        $mail = $messages[0]->getOriginalMessage();
        $this->assertInstanceOf(Email::class, $mail);
        $this->assertSame('en', app()->getLocale(), 'the worker keeps its own language for the next job');

        return $mail;
    }

    public function test_a_german_user_gets_the_reset_link_in_german(): void
    {
        $mail = $this->resetMailFor('de');
        $text = (string) $mail->getTextBody();

        $this->assertSame('Passwort zurücksetzen', $mail->getSubject());
        $this->assertStringContainsString('Hallo!', $text);
        $this->assertStringContainsString('Sie erhalten diese E-Mail, weil für Ihr Konto das Zurücksetzen des Passworts angefordert wurde.', $text);
        $this->assertStringContainsString('Neues Passwort festlegen', $text);
        $this->assertStringContainsString('Dieser Link ist 60 Minuten gültig.', $text);
        $this->assertStringContainsString('Falls Sie das nicht angefordert haben, müssen Sie nichts tun.', $text);
        $this->assertStringNotContainsString('You are receiving', $text);
    }

    public function test_a_bosnian_user_gets_the_reset_link_in_bhs(): void
    {
        $mail = $this->resetMailFor('bs');
        $text = (string) $mail->getTextBody();

        $this->assertSame('Ponovno postavljanje lozinke', $mail->getSubject());
        $this->assertStringContainsString('Zdravo!', $text);
        $this->assertStringContainsString('Ovaj link vrijedi 60 minuta.', $text);
        $this->assertStringNotContainsString('You are receiving', $text);
    }

    public function test_an_english_user_gets_the_reset_link_in_english(): void
    {
        $mail = $this->resetMailFor('en');

        $this->assertSame('Reset your password', $mail->getSubject());
        $this->assertStringContainsString('This link is valid for 60 minutes.', (string) $mail->getTextBody());
    }

    public function test_every_language_translates_the_reset_e_mail(): void
    {
        $keys = [
            'Reset Password Notification',
            'You are receiving this email because we received a password reset request for your account.',
            'Reset Password',
            'This password reset link will expire in :count minutes.',
            'If you did not request a password reset, no further action is required.',
        ];
        foreach (['de', 'en', 'bs'] as $locale) {
            $catalogue = json_decode((string) file_get_contents(lang_path("{$locale}.json")), true, flags: JSON_THROW_ON_ERROR);
            foreach ($keys as $key) {
                $this->assertArrayHasKey($key, $catalogue, "lang/{$locale}.json");
            }
        }
    }
}
