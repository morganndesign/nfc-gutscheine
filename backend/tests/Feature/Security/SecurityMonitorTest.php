<?php

declare(strict_types=1);

namespace Tests\Feature\Security;

use App\Enums\RoleSlug;
use App\Models\Restaurant;
use App\Models\SecurityAlert;
use App\Models\SystemSetting;
use App\Models\User;
use Illuminate\Mail\Events\MessageSent;
use Illuminate\Support\Facades\Event;
use Laravel\Sanctum\Sanctum;
use Symfony\Component\Mime\Email;
use Tests\Support\WithCards;
use Tests\TestCase;

/** Fraud rules over the event stream: attacks seen in the stream become alerts for the platform. */
final class SecurityMonitorTest extends TestCase
{
    use WithCards;

    private Restaurant $restaurant;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpCardKeystore();
        $this->restaurant = $this->restaurant();
        config(['giftcard.ops_alert_email' => 'ops@giftcardpro.test', 'mail.default' => 'array']);
        Event::listen(MessageSent::class, function (MessageSent $e): void {
            $this->sent[] = $e->message;
        });
    }

    /** @var list<Email> */
    private array $sent = [];

    protected function tearDown(): void
    {
        $this->tearDownCardKeystore();
        parent::tearDown();
    }

    private function monitor(): void
    {
        $this->artisan('giftcard:monitor-security-events')->assertSuccessful();
    }

    public function test_a_cloned_card_url_on_another_chip_raises_a_critical_alert_once(): void
    {
        [$card] = $this->activeCardVoucher($this->restaurant);
        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        $chip = $this->chip($card);

        foreach ([1, 2] as $attempt) {
            $this->postJson('/api/v1/presentments/cards', [
                'purpose' => 'spend',
                'tap_url' => $chip->readNdefUrl(),
                'rf_uid' => '04DEADBEEF0000',
                'challenge' => str_repeat('00', 16),
            ])->assertForbidden();
        }
        $this->monitor();
        $this->monitor();

        $alert = SecurityAlert::query()->where('rule', 'card.clone_attempt')->sole();
        $this->assertSame('critical', $alert->severity);
        $this->assertSame('card:'.$card->card_number, $alert->subject);
        $this->assertSame(2, $alert->occurrences, 'the repeat counts up, it does not open a second alert');
        $this->assertSame(1, $this->rawMails());
        $this->assertSame('ops@giftcardpro.test', $this->sent[0]->getTo()[0]->getAddress());
        $this->assertStringContainsString('critical: card.clone_attempt', (string) $this->sent[0]->getSubject());
    }

    public function test_a_replayed_card_url_is_flagged_after_the_third_replay(): void
    {
        [$card] = $this->activeCardVoucher($this->restaurant);
        $url = str_replace((string) config('giftcard.tap_url'), '/t', $this->chip($card)->readNdefUrl());
        $this->get($url)->assertOk();
        $this->get($url)->assertForbidden();
        $this->get($url)->assertForbidden();
        $this->monitor();
        $this->assertSame(0, SecurityAlert::query()->count());

        $this->get($url)->assertForbidden();
        $this->monitor();
        $alert = SecurityAlert::query()->sole();
        $this->assertSame(['card.url_replay', 'high', 'card:'.$card->card_number], [$alert->rule, $alert->severity, $alert->subject]);
    }

    public function test_many_reads_between_two_taps_are_a_warning_without_mail(): void
    {
        [$card] = $this->activeCardVoucher($this->restaurant);
        $chip = $this->chip($card);
        for ($i = 0; $i < 60; $i++) {
            $chip->readNdefUrl();
        }
        $this->get(str_replace((string) config('giftcard.tap_url'), '/t', $chip->readNdefUrl()))->assertOk();
        $this->monitor();

        $alert = SecurityAlert::query()->sole();
        $this->assertSame(['card.counter_gap', 'warning'], [$alert->rule, $alert->severity]);
        $this->assertSame(0, $this->rawMails());
    }

    public function test_credential_stuffing_from_one_network_is_flagged(): void
    {
        for ($i = 0; $i < 20; $i++) {
            $this->withServerVariables(['REMOTE_ADDR' => '203.0.113.'.($i % 5 + 1)])
                ->postJson('/api/v1/auth/login', ['email' => "nobody{$i}@example.com", 'password' => 'wrong-password'])->assertStatus(422);
        }
        $this->monitor();

        $alert = SecurityAlert::query()->where('rule', 'auth.credential_stuffing')->sole();
        $this->assertSame('network:203.0.113.0/24', $alert->subject);
        $this->assertSame(1, $this->rawMails());
    }

    public function test_the_platform_lists_and_acknowledges_alerts(): void
    {
        [$card] = $this->activeCardVoucher($this->restaurant);
        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        $this->postJson('/api/v1/presentments/cards', ['purpose' => 'spend', 'tap_url' => $this->chip($card)->readNdefUrl(), 'rf_uid' => '04DEADBEEF0000', 'challenge' => str_repeat('00', 16)]);
        $this->monitor();

        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        $this->getJson('/api/v1/admin/security-alerts')->assertForbidden();

        Sanctum::actingAs(User::factory()->platformAdmin()->create(), ['*']);
        $id = $this->getJson('/api/v1/admin/security-alerts?status=open')->assertOk()
            ->assertJsonPath('data.0.rule', 'card.clone_attempt')->json('data.0.id');
        $this->postJson("/api/v1/admin/security-alerts/{$id}/acknowledge", ['note' => 'guest photographed the card, card replaced'])->assertOk()
            ->assertJsonPath('data.status', 'acknowledged');
        $this->getJson('/api/v1/admin/security-alerts?status=open')->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_without_an_operations_address_the_support_address_gets_the_alert(): void
    {
        config(['giftcard.ops_alert_email' => null]);
        SystemSetting::query()->updateOrCreate(['key' => 'platform.support_email'], ['value' => 'support@giftcardpro.test', 'type' => 'string']);
        [$card] = $this->activeCardVoucher($this->restaurant);
        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        $this->postJson('/api/v1/presentments/cards', ['purpose' => 'spend', 'tap_url' => $this->chip($card)->readNdefUrl(), 'rf_uid' => '04DEADBEEF0000', 'challenge' => str_repeat('00', 16)]);
        $this->monitor();

        $this->assertSame(1, $this->rawMails());
    }

    private function rawMails(): int
    {
        return count($this->sent);
    }
}
