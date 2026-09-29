<?php

declare(strict_types=1);

namespace Tests\Feature\Cards;

use App\Enums\CardState;
use App\Enums\MediumRole;
use App\Enums\MediumStatus;
use App\Enums\MediumType;
use App\Enums\RoleSlug;
use App\Enums\SecurityEventOutcome;
use App\Enums\SecurityEventType;
use App\Models\Card;
use App\Models\Medium;
use App\Models\Restaurant;
use App\Models\SecurityEvent;
use App\Models\Voucher;
use App\Services\Cards\CardLifecycle;
use App\Services\Vouchers\VoucherService;
use App\Support\Actor;
use Tests\Support\WithCards;
use Tests\TestCase;

/** Phase 3: SUN-verified taps with counter compare-and-set, and the guest balance page. */
final class TapPageTest extends TestCase
{
    use WithCards;

    private Restaurant $restaurant;

    private Card $card;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpCardKeystore();

        $this->restaurant = $this->restaurant(['name' => 'Beisl am Eck', 'locale' => 'de-AT']);
        $this->card = $this->cardInStock();
    }

    protected function tearDown(): void
    {
        $this->tearDownCardKeystore();
        parent::tearDown();
    }

    private function cardInStock(): Card
    {
        return $this->availableCard($this->restaurant);
    }

    /** The guest page path of the card's tap with read counter `$counter`. */
    private function tapUrl(int $counter): string
    {
        $url = $this->sunUrl($this->card, $counter);

        return parse_url($url, PHP_URL_PATH).'?'.parse_url($url, PHP_URL_QUERY);
    }

    private function activate(int $balance = 4250): Voucher
    {
        $voucher = $this->issueVoucher($this->restaurant, $balance);
        $cards = app(CardLifecycle::class);
        $cards->transition($this->card, CardState::Bound, 'sold', Actor::system());
        $cards->transition($this->card->refresh(), CardState::Active, 'voucher activated', Actor::system());
        $medium = new Medium;
        $medium->forceFill([
            'restaurant_id' => $this->restaurant->id,
            'voucher_id' => $voucher->id,
            'type' => MediumType::NfcCard,
            'role' => MediumRole::Spend,
            'status' => MediumStatus::Active,
            'card_id' => $this->card->id,
        ])->save();

        return $voucher;
    }

    public function test_a_guest_sees_the_balance_of_an_active_card_and_nothing_that_identifies_it(): void
    {
        $voucher = $this->activate(4250);

        $page = $this->get($this->tapUrl(5))->assertOk()
            ->assertHeader('Cache-Control', 'no-store, private')
            ->assertHeader('Referrer-Policy', 'no-referrer')
            ->assertSee('Beisl am Eck')
            ->assertSee('Guthaben')
            ->assertSee('Unbefristet gültig');
        $html = (string) $page->getContent();
        $this->assertStringContainsString('42,50', $html);
        foreach ([$voucher->voucher_number, $this->card->card_number, $this->card->uidHex(), $this->card->id] as $secret) {
            $this->assertStringNotContainsString($secret, $html);
        }
        $this->assertCount(0, $page->headers->getCookies(), 'the page sets no cookies');
        $this->assertSame(5, $this->card->refresh()->sdm_counter);

        // The station's QA read was the card's first tap.
        $event = SecurityEvent::query()->where('type', SecurityEventType::CardTap->value)->get()->filter(static fn (SecurityEvent $e): bool => $e->data['purpose'] === 'balance')->sole();
        $this->assertSame(SecurityEventOutcome::Succeeded, $event->outcome);
        $this->assertSame(5, $event->data['counter']);
    }

    public function test_a_copied_or_older_tap_url_is_refused(): void
    {
        $this->activate();
        $url = $this->tapUrl(7);
        $this->get($url)->assertOk();

        $this->withHeader('Accept-Language', 'de-AT,de;q=0.9')->get($url)->assertForbidden()->assertSee('konnte nicht geprüft werden', false);
        $this->withHeader('Accept-Language', 'hr-HR')->get($url)->assertForbidden()->assertSee('nije mogla provjeriti', false);
        $this->get($this->tapUrl(6))->assertForbidden();
        $this->get($this->tapUrl(8))->assertOk();
        $this->assertSame('SUN_REPLAYED', SecurityEvent::query()->where('type', SecurityEventType::CardTap->value)->where('outcome', 'refused')->value('reason'));
    }

    public function test_forged_or_foreign_taps_are_refused(): void
    {
        $this->activate();
        $url = $this->tapUrl(9);

        $forged = substr($url, 0, -1).(substr($url, -1) === '0' ? '1' : '0');
        $this->get($forged)->assertForbidden();
        $this->get(str_replace('/t/ks-2026-01', '/t/ks-2099-01', $url))->assertForbidden();
        $this->get('/t/ks-2026-01?e=zz&m=00')->assertForbidden();
        $this->get('/t/ks-2026-01')->assertForbidden();
        $this->assertSame(1, $this->card->refresh()->sdm_counter, 'nothing after the station QA read was accepted');
    }

    public function test_the_page_follows_the_card_and_voucher_state_and_the_restaurant_setting(): void
    {
        $this->get($this->tapUrl(2))->assertOk()->assertSee('noch nicht aktiviert');

        $voucher = $this->activate();
        $this->restaurant->settings->forceFill(['public_balance' => false])->save();
        $this->get($this->tapUrl(3))->assertOk()->assertSee('erfahren Sie im Lokal')->assertDontSee('class="amount"', false);

        $this->restaurant->settings->forceFill(['public_balance' => true])->save();
        $this->asTenant($this->restaurant, fn () => app(VoucherService::class)->block(Actor::system(), $voucher, 'lost'));
        $this->get($this->tapUrl(4))->assertOk()->assertSee('gesperrt');

        app(CardLifecycle::class)->transition($this->card->refresh(), CardState::Suspended, 'lost', Actor::system());
        app(CardLifecycle::class)->transition($this->card->refresh(), CardState::Revoked, 'fraud', Actor::system());
        $this->get($this->tapUrl(5))->assertOk()->assertSee('nicht mehr gültig');
    }

    public function test_the_restaurant_controls_the_public_balance(): void
    {
        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        $this->putJson('/api/v1/settings/vouchers', ['public_balance' => false])->assertOk()->assertJsonPath('data.public_balance', false);
        $this->assertFalse($this->restaurant->settings->refresh()->public_balance);
    }
}
