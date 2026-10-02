<?php

declare(strict_types=1);

namespace Tests\Feature\Cards;

use App\Crypto\CryptoProvider;
use App\Crypto\Local\LocalKeystore;
use App\Enums\CardState;
use App\Enums\KeySetStatus;
use App\Models\KeySet;
use App\Services\Cards\CardLifecycle;
use App\Support\Actor;
use Tests\Support\TestOriginality;
use Tests\Support\WithCards;
use Tests\TestCase;

/** Key ceremony, rotation, retirement and the daily tamper check of the card root keys. */
final class KeySetCommandsTest extends TestCase
{
    use WithCards;

    private string $path;

    protected function setUp(): void
    {
        parent::setUp();
        $this->path = sys_get_temp_dir().'/gcp-ks-'.bin2hex(random_bytes(6)).'/keystore.json';
        config([
            'crypto.provider' => 'local',
            'crypto.local.keystore_path' => $this->path,
            'crypto.local.master_key' => 'base64:'.base64_encode(random_bytes(32)),
        ]);
        $this->app->forgetInstance(LocalKeystore::class);
        $this->app->forgetInstance(CryptoProvider::class);
        $this->artisan('crypto:keystore:init')->assertSuccessful();
        config(['giftcard.cards.originality_public_key' => TestOriginality::publicKey()]);
    }

    protected function tearDown(): void
    {
        if (is_file($this->path)) {
            unlink($this->path);
            rmdir(dirname($this->path));
        }
        parent::tearDown();
    }

    public function test_a_ceremony_creates_the_active_set_and_rotation_demotes_the_previous_one(): void
    {
        $this->artisan('cards:key-set:create', ['version' => 'ks-2026-01'])->assertSuccessful();
        $first = KeySet::query()->where('version', 'ks-2026-01')->sole();
        $this->assertSame(KeySetStatus::Active, $first->status);
        $this->assertSame(['root-k0', 'root-k1', 'root-k2', 'root-k3'], array_keys($first->key_check_values));

        $this->artisan('cards:key-set:create', ['version' => 'ks-2027-01'])->assertSuccessful();
        $this->assertSame(KeySetStatus::VerifyOnly, $first->refresh()->status);
        $this->assertSame(KeySetStatus::Active, KeySet::query()->where('version', 'ks-2027-01')->sole()->status);

        $this->artisan('cards:key-set:create', ['version' => 'ks-2027-01'])->assertFailed();
        $this->artisan('cards:key-set:create', ['version' => 'Bad Version'])->assertFailed();
        $this->artisan('cards:key-set:verify')->assertSuccessful();
    }

    public function test_every_version_the_ceremony_accepts_can_key_and_verify_cards(): void
    {
        // K1 is diversified from "K" ‖ version ‖ 01 ‖ system identifier: AN10922 takes at most 31 bytes.
        $this->artisan('cards:key-set:create', ['version' => 'ks-2026-01-printer1'])->assertFailed();
        $this->assertSame(0, KeySet::query()->count());
        $this->assertSame([], app(LocalKeystore::class)->read(), 'no root key of a refused set stays in the keystore');

        $longest = 'ks-2026-01-printer';
        $this->artisan('cards:key-set:create', ['version' => $longest])->assertSuccessful();
        $card = $this->availableCard($this->restaurant(), $longest);
        $this->get(str_replace((string) config('giftcard.tap_url'), '/t', $this->chip($card)->readNdefUrl()))->assertOk();
    }

    public function test_the_tamper_check_fails_when_a_key_or_its_record_differs(): void
    {
        $this->artisan('cards:key-set:create', ['version' => 'ks-2026-01'])->assertSuccessful();
        $set = KeySet::query()->sole();
        $set->forceFill(['key_check_values' => ['root-k2' => '000000'] + $set->key_check_values])->save();

        $this->artisan('cards:key-set:verify')->expectsOutputToContain('ks-2026-01/root-k2: key check value differs')->assertFailed();

        KeySet::query()->create(['version' => 'ks-ghost', 'manufacturer' => 'x', 'status' => KeySetStatus::VerifyOnly, 'key_check_values' => []]);
        $this->artisan('cards:key-set:verify')->expectsOutputToContain('ks-ghost/root-k0: missing in the provider')->assertFailed();
    }

    public function test_a_set_is_retired_only_when_none_of_its_cards_is_in_use(): void
    {
        $this->artisan('cards:key-set:create', ['version' => 'ks-2026-01'])->assertSuccessful();
        $restaurant = $this->restaurant();
        [, $cards] = $this->deliveredCards($restaurant, 1);

        $this->artisan('cards:key-set:status', ['version' => 'ks-2026-01', 'status' => 'retired'])->assertFailed();
        $this->artisan('cards:key-set:status', ['version' => 'ks-2026-01', 'status' => 'active'])->assertFailed();

        app(CardLifecycle::class)->transition($cards[0], CardState::Revoked, 'test', Actor::system());
        $this->artisan('cards:key-set:status', ['version' => 'ks-2026-01', 'status' => 'retired'])->assertSuccessful();
        $this->artisan('cards:key-set:status', ['version' => 'ks-2026-01', 'status' => 'verify_only'])->assertFailed();

        // A retired set verifies nothing: the card's URL is refused like a forgery.
        $url = $this->chip($cards[0])->readNdefUrl();
        $this->get(str_replace((string) config('giftcard.tap_url'), '/t', $url))->assertForbidden();
    }
}
