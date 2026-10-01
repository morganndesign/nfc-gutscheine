<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Http\Middleware\SetRequestLocale;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * API responses speak the user's language (users.locale) when signed in, otherwise the browser's
 * Accept-Language (hr/sr → bs), German by default. Validation messages use lang/<locale>/validation.php.
 */
final class RequestLocaleTest extends TestCase
{
    public function test_guest_validation_errors_follow_accept_language(): void
    {
        $this->withHeader('Accept-Language', 'de-AT,de;q=0.9,en;q=0.8')
            ->postJson('/api/v1/auth/forgot-password', [])
            ->assertStatus(422)
            ->assertJsonPath('code', 'VALIDATION_FAILED')
            ->assertJsonPath('errors.email.0', 'E-Mail-Adresse ist ein Pflichtfeld.')
            ->assertJsonPath('message', 'E-Mail-Adresse ist ein Pflichtfeld.');

        $this->withHeader('Accept-Language', 'en-GB,en;q=0.9')
            ->postJson('/api/v1/auth/forgot-password', ['email' => 'not-an-address'])
            ->assertStatus(422)
            ->assertJsonPath('errors.email.0', 'The email field must be a valid email address.');

        $this->withHeader('Accept-Language', 'hr-HR,hr;q=0.9')
            ->postJson('/api/v1/auth/forgot-password', [])
            ->assertStatus(422)
            ->assertJsonPath('errors.email.0', 'Polje e-mail adresa je obavezno.');
    }

    public function test_german_is_the_default(): void
    {
        // (Symfony's test requests send "en-us" unless told otherwise, hence the explicit empty header.)
        $this->withHeader('Accept-Language', '')
            ->postJson('/api/v1/auth/forgot-password', [])
            ->assertStatus(422)
            ->assertJsonPath('errors.email.0', 'E-Mail-Adresse ist ein Pflichtfeld.');

        $this->withHeader('Accept-Language', 'fr-FR,fr;q=0.9')
            ->postJson('/api/v1/auth/forgot-password', [])
            ->assertStatus(422)
            ->assertJsonPath('errors.email.0', 'E-Mail-Adresse ist ein Pflichtfeld.');
    }

    public function test_signed_in_user_gets_their_own_language_whatever_the_browser_sends(): void
    {
        $restaurant = $this->restaurant();
        Sanctum::actingAs($this->staff($restaurant, RoleSlug::Owner, ['locale' => 'bs']), ['*']);

        $this->withHeader('Accept-Language', 'en-US')
            ->putJson('/api/v1/auth/profile', ['locale' => 'fr', 'name' => str_repeat('x', 161)])
            ->assertStatus(422)
            ->assertJsonPath('errors.locale.0', 'Odabrana vrijednost za polje jezik nije ispravna.')
            ->assertJsonPath('errors.name.0', 'Polje ime smije imati najviše 160 znakova.')
            ->assertJsonPath('message', 'Polje ime smije imati najviše 160 znakova. (i još 1 greška)');
    }

    public function test_english_user_gets_english_messages(): void
    {
        $restaurant = $this->restaurant();
        Sanctum::actingAs($this->staff($restaurant, RoleSlug::Owner, ['locale' => 'en']), ['*']);

        $this->withHeader('Accept-Language', 'de-AT')
            ->putJson('/api/v1/auth/profile', ['locale' => 'fr'])
            ->assertStatus(422)
            ->assertJsonPath('errors.locale.0', 'The selected locale is invalid.');
    }

    public function test_language_tags_are_normalised(): void
    {
        $this->assertSame('de', SetRequestLocale::normalize('de_AT'));
        $this->assertSame('en', SetRequestLocale::normalize('en-GB'));
        $this->assertSame('bs', SetRequestLocale::normalize('sr-Latn-RS'));
        $this->assertSame('bs', SetRequestLocale::normalize('BS'));
        $this->assertNull(SetRequestLocale::normalize('fr'));
    }
}
