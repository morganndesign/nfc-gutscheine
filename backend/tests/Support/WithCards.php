<?php

declare(strict_types=1);

namespace Tests\Support;

use App\Crypto\CryptoProvider;
use App\Crypto\Local\LocalKeystore;
use App\Crypto\Ntag424\CardKeys;
use App\Enums\CardBatchStatus;
use App\Enums\CardState;
use App\Enums\KeySetStatus;
use App\Enums\MediumRole;
use App\Enums\MediumStatus;
use App\Enums\MediumType;
use App\Enums\VoucherKind;
use App\Models\Card;
use App\Models\CardBatch;
use App\Models\KeySet;
use App\Models\Medium;
use App\Models\Restaurant;
use App\Models\User;
use App\Models\Voucher;
use App\Services\Cards\CardBatchLifecycle;
use App\Services\Cards\CardLifecycle;
use App\Support\Actor;
use Tests\TestCase;

/**
 * Physical cards for feature tests: a real local keystore with a key set, a batch that went through the full
 * lifecycle, and simulated NTAG 424 DNA cards personalised with the derived keys.
 *
 * @mixin TestCase
 */
trait WithCards
{
    private ?string $cardKeystorePath = null;

    protected function setUpCardKeystore(string $keySet = 'ks-2026-01'): void
    {
        $this->cardKeystorePath = sys_get_temp_dir().'/gcp-cards-'.bin2hex(random_bytes(6)).'/keystore.json';
        config([
            'crypto.provider' => 'local',
            'crypto.local.keystore_path' => $this->cardKeystorePath,
            'crypto.local.master_key' => 'base64:'.base64_encode(random_bytes(32)),
        ]);
        $this->app->forgetInstance(LocalKeystore::class);
        $this->app->forgetInstance(CryptoProvider::class);
        $this->artisan('crypto:keystore:init')->assertSuccessful();
        foreach (['k1', 'root-k0', 'root-k2', 'root-k3'] as $role) {
            $this->artisan('crypto:key:generate', ['reference' => $keySet.'/'.$role])->assertSuccessful();
        }
        KeySet::query()->create(['version' => $keySet, 'manufacturer' => 'Card Co', 'status' => KeySetStatus::Active, 'key_check_values' => []]);
    }

    protected function tearDownCardKeystore(): void
    {
        if ($this->cardKeystorePath !== null && is_file($this->cardKeystorePath)) {
            unlink($this->cardKeystorePath);
            rmdir(dirname($this->cardKeystorePath));
        }
    }

    /**
     * A batch of `$count` cards, taken through production, acceptance and shipping to `$restaurant`.
     *
     * @return array{0: CardBatch, 1: list<Card>}
     */
    protected function deliveredCards(Restaurant $restaurant, int $count = 1, string $keySet = 'ks-2026-01'): array
    {
        $admin = new Actor(User::factory()->platformAdmin()->create());
        $second = new Actor(User::factory()->platformAdmin()->create());
        $batches = app(CardBatchLifecycle::class);
        $lifecycle = app(CardLifecycle::class);

        $batch = $batches->order($restaurant, KeySet::query()->where('version', $keySet)->firstOrFail(), 'Card Co', $count, 'manufacturer', $admin);
        $batch = $batches->changeStatus($batch, CardBatchStatus::InProduction, 'printing', $admin);
        $cards = [];
        for ($i = 0; $i < $count; $i++) {
            $card = $lifecycle->register($batch, "\x04".random_bytes(6), CardState::Personalized, $admin);
            $cards[] = $lifecycle->transition($card, CardState::QaPassed, 'sample passed', $admin);
        }
        $batch = $batches->changeStatus($batch, CardBatchStatus::Personalized, 'done', $admin);
        $batch = $batches->changeStatus($batch, CardBatchStatus::QaTesting, 'sample', $admin);
        $batches->approve($batch, $admin);
        $batch = $batches->approve($batch, $second);
        foreach ([CardBatchStatus::Assigned, CardBatchStatus::Shipped, CardBatchStatus::Delivered] as $status) {
            $batch = $batches->changeStatus($batch, $status, $status->value, $admin);
        }

        return [$batch, array_map(static fn (Card $c): Card => $c->refresh(), $cards)];
    }

    /** One card in the restaurant's stock (`available`). */
    protected function availableCard(Restaurant $restaurant): Card
    {
        [$batch, $cards] = $this->deliveredCards($restaurant);
        app(CardBatchLifecycle::class)->receive($batch, 1, $cards[0], Actor::system());

        return $cards[0]->refresh();
    }

    /** Links an available card to a card voucher of `$balance` and activates both, as a card sale does. */
    protected function activeCardVoucher(Restaurant $restaurant, int $balance = 5000): array
    {
        $card = $this->availableCard($restaurant);
        $voucher = $this->issueVoucher($restaurant, $balance);
        $voucher->forceFill(['kind' => VoucherKind::Card])->save();
        $lifecycle = app(CardLifecycle::class);
        $lifecycle->transition($card, CardState::Bound, 'sold', Actor::system());
        $lifecycle->transition($card->refresh(), CardState::Active, 'voucher activated', Actor::system());
        $medium = new Medium;
        $medium->forceFill([
            'restaurant_id' => $restaurant->getKey(),
            'voucher_id' => $voucher->getKey(),
            'type' => MediumType::NfcCard,
            'role' => MediumRole::Spend,
            'status' => MediumStatus::Active,
            'card_id' => $card->getKey(),
        ])->save();

        return [$card->refresh(), $voucher->refresh()];
    }

    /** The simulated chip of a registered card. */
    protected function chip(Card $card): Ntag424Card
    {
        $provider = $this->app->make(CryptoProvider::class);
        $keySet = KeySet::query()->findOrFail($card->key_set_id);

        return new Ntag424Card($provider, new CardKeys($provider, $keySet->version, $card->batch_id), $card->uid, $keySet->version);
    }
}
