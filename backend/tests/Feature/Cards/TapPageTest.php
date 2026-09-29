<?php

declare(strict_types=1);

namespace Tests\Feature\Cards;

use App\Crypto\CryptoProvider;
use App\Crypto\Local\LocalKeystore;
use App\Crypto\Ntag424\CardKeys;
use App\Crypto\Ntag424\SunVerifier;
use App\Crypto\Primitives\Aes;
use App\Enums\CardBatchStatus;
use App\Enums\CardState;
use App\Enums\KeySetStatus;
use App\Enums\MediumRole;
use App\Enums\MediumStatus;
use App\Enums\MediumType;
use App\Enums\RoleSlug;
use App\Enums\SecurityEventOutcome;
use App\Enums\SecurityEventType;
use App\Models\Card;
use App\Models\KeySet;
use App\Models\Medium;
use App\Models\Restaurant;
use App\Models\SecurityEvent;
use App\Models\User;
use App\Models\Voucher;
use App\Services\Cards\CardBatchLifecycle;
use App\Services\Cards\CardLifecycle;
use App\Services\Vouchers\VoucherService;
use App\Support\Actor;
use Tests\TestCase;

/** Phase 3: SUN-verified taps with counter compare-and-set, and the guest balance page. */
final class TapPageTest extends TestCase
{
    private string $keystorePath;

    private Restaurant $restaurant;

    private Card $card;

    protected function setUp(): void
    {
        parent::setUp();
        $this->keystorePath = sys_get_temp_dir().'/gcp-tap-'.bin2hex(random_bytes(6)).'/keystore.json';
        config([
            'crypto.local.keystore_path' => $this->keystorePath,
            'crypto.local.master_key' => 'base64:'.base64_encode(random_bytes(32)),
        ]);
        $this->app->forgetInstance(LocalKeystore::class);
        $this->app->forgetInstance(CryptoProvider::class);
        $this->artisan('crypto:keystore:init')->assertSuccessful();
        foreach (['k1', 'root-k0', 'root-k2', 'root-k3'] as $role) {
            $this->artisan('crypto:key:generate', ['reference' => 'ks-2026-01/'.$role])->assertSuccessful();
        }

        $this->restaurant = $this->restaurant(['name' => 'Beisl am Eck', 'locale' => 'de-AT']);
        $this->card = $this->cardInStock();
    }

    protected function tearDown(): void
    {
        if (is_file($this->keystorePath)) {
            unlink($this->keystorePath);
            rmdir(dirname($this->keystorePath));
        }
        parent::tearDown();
    }

    private function cardInStock(): Card
    {
        $admin = new Actor(User::factory()->platformAdmin()->create());
        $second = new Actor(User::factory()->platformAdmin()->create());
        $keySet = KeySet::query()->create(['version' => 'ks-2026-01', 'manufacturer' => 'Card Co', 'status' => KeySetStatus::Active, 'key_check_values' => []]);
        $batches = app(CardBatchLifecycle::class);
        $cards = app(CardLifecycle::class);

        $batch = $batches->order($this->restaurant, $keySet, 'Card Co', 1, 'manufacturer', $admin);
        $batch = $batches->changeStatus($batch, CardBatchStatus::InProduction, 'printing', $admin);
        $card = $cards->register($batch, (string) hex2bin('04A39493CC8680'), CardState::Personalized, $admin);
        $cards->transition($card, CardState::QaPassed, 'sample passed', $admin);
        $batch = $batches->changeStatus($batch, CardBatchStatus::Personalized, 'done', $admin);
        $batch = $batches->changeStatus($batch, CardBatchStatus::QaTesting, 'sample', $admin);
        $batches->approve($batch, $admin);
        $batch = $batches->approve($batch, $second);
        foreach ([CardBatchStatus::Assigned, CardBatchStatus::Shipped, CardBatchStatus::Delivered] as $status) {
            $batch = $batches->changeStatus($batch, $status, $status->value, $admin);
        }
        $batches->receive($batch, 1, $card->refresh(), $admin);

        return $card->refresh();
    }

    /** What the card writes into its NDEF URL on a tap with read counter `$counter`. */
    private function tapUrl(int $counter, string $keySet = 'ks-2026-01'): string
    {
        $provider = $this->app->make(CryptoProvider::class);
        $keys = new CardKeys($provider, $keySet === 'ks-2026-01' ? $keySet : 'ks-2026-01', $this->card->batch_id);
        $uid = $this->card->uid;
        $ctr = chr($counter & 0xFF).chr(($counter >> 8) & 0xFF).chr(($counter >> 16) & 0xFF);
        $e = bin2hex($provider->encryptCbc($keys->metaReadKey(), Aes::ZERO_IV, "\xC7".$uid.$ctr.random_bytes(5)));
        $m = SunVerifier::mac($keys->sdmMacKey($uid), $uid, $ctr);

        return "/t/{$keySet}?e={$e}&m={$m}";
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

        $event = SecurityEvent::query()->where('type', SecurityEventType::CardTap->value)->sole();
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
        $this->assertNull($this->card->refresh()->sdm_counter, 'nothing was accepted');
    }

    public function test_the_page_follows_the_card_and_voucher_state_and_the_restaurant_setting(): void
    {
        $this->get($this->tapUrl(1))->assertOk()->assertSee('noch nicht aktiviert');

        $voucher = $this->activate();
        $this->restaurant->settings->forceFill(['public_balance' => false])->save();
        $this->get($this->tapUrl(2))->assertOk()->assertSee('erfahren Sie im Lokal')->assertDontSee('class="amount"', false);

        $this->restaurant->settings->forceFill(['public_balance' => true])->save();
        $this->asTenant($this->restaurant, fn () => app(VoucherService::class)->block(Actor::system(), $voucher, 'lost'));
        $this->get($this->tapUrl(3))->assertOk()->assertSee('gesperrt');

        app(CardLifecycle::class)->transition($this->card->refresh(), CardState::Revoked, 'fraud', Actor::system());
        $this->get($this->tapUrl(4))->assertOk()->assertSee('nicht mehr gültig');
    }

    public function test_the_restaurant_controls_the_public_balance(): void
    {
        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);
        $this->putJson('/api/v1/settings/vouchers', ['public_balance' => false])->assertOk()->assertJsonPath('data.public_balance', false);
        $this->assertFalse($this->restaurant->settings->refresh()->public_balance);
    }
}
