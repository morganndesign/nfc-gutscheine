<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\RoleSlug;
use App\Notifications\SignInEmailChanged;
use App\Notifications\StaffInvitation;
use Illuminate\Notifications\AnonymousNotifiable;
use Tests\TestCase;

/**
 * Account e-mails come from the platform's own address, so people trust their links. Names typed by users (inviter,
 * restaurant, the person who changed an address) are Markdown inside these e-mails: a name like
 * "[Konto bestätigen](https://evil.example)" must stay text, never become a link.
 */
final class AccountEmailInjectionTest extends TestCase
{
    private const NAME = 'Max [Konto hier bestätigen](https://evil.example/login)';

    private function assertNoInjectedLink(string $html): void
    {
        $this->assertStringNotContainsString('href="https://evil.example', $html);
        $this->assertStringContainsString('[Konto hier bestätigen](https://evil.example/login)', html_entity_decode(strip_tags($html)));
    }

    public function test_an_inviter_or_restaurant_name_cannot_put_a_link_into_an_invitation(): void
    {
        config(['giftcard.frontend_url' => 'https://app.example.test']);
        $user = $this->staff($this->restaurant(), RoleSlug::Waiter, ['name' => self::NAME]);

        $staff = new StaffInvitation('token', self::NAME, self::NAME);
        $this->assertNoInjectedLink((string) $staff->toMail($user)->render());

        $owner = new StaffInvitation('token', self::NAME, null, true, 'support@giftcardpro.at');
        $html = (string) $owner->toMail($user)->render();
        $this->assertNoInjectedLink($html);
        $this->assertStringContainsString('href="mailto:support@giftcardpro.at"', $html, 'the platform\'s own link stays');
        $this->assertStringContainsString('href="https://app.example.test/reset-password#token=', $html);
    }

    public function test_the_address_change_notice_cannot_carry_a_link(): void
    {
        $notice = new SignInEmailChanged(self::NAME, 'x@evil.example', self::NAME, self::NAME);

        $this->assertNoInjectedLink((string) $notice->toMail(new AnonymousNotifiable)->render());
    }
}
