<?php

declare(strict_types=1);

namespace Tests\Feature\Cards;

use App\Crypto\CryptoProvider;
use App\Crypto\Ntag424\CardKeys;
use App\Crypto\Ntag424\CardProfile;
use App\Enums\CardBatchStatus;
use App\Enums\CardState;
use App\Enums\RoleSlug;
use App\Enums\SecurityEventOutcome;
use App\Enums\SecurityEventType;
use App\Models\Card;
use App\Models\CardBatch;
use App\Models\CardEvent;
use App\Models\KeySet;
use App\Models\Restaurant;
use App\Models\SecurityAlert;
use App\Models\SecurityEvent;
use App\Models\User;
use App\Services\Cards\CardBatchLifecycle;
use App\Support\Actor;
use Closure;
use Illuminate\Cache\ArrayStore;
use Illuminate\Cache\Repository;
use Illuminate\Contracts\Cache\Repository as CacheRepository;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\Sanctum;
use Tests\Support\Ntag424Chip;
use Tests\Support\WithCards;
use Tests\TestCase;

/**
 * The in-house station personalises blank NTAG 424 DNA chips (architecture §9.3): the server drives every APDU,
 * the phone relays bytes. The chip here is an APDU-level simulation written from the datasheet.
 */
final class StationPersonalizationTest extends TestCase
{
    use WithCards;

    private Restaurant $restaurant;

    /** Every JSON body the station received, to prove no key ever left the server. @var list<string> */
    private array $bodies = [];

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpCardKeystore();
        $this->restaurant = $this->restaurant(['name' => 'Zum Goldenen Hirschen']);
    }

    protected function tearDown(): void
    {
        $this->tearDownCardKeystore();
        parent::tearDown();
    }

    /** A batch in production (as ordered), or one already stopped (`rejected`) that takes no chips. */
    private function stationBatch(int $quantity = 3, bool $inProduction = true): CardBatch
    {
        $admin = new Actor(User::factory()->platformAdmin()->create());
        $batches = app(CardBatchLifecycle::class);
        $batch = $batches->order($this->restaurant, KeySet::query()->where('version', 'ks-2026-01')->firstOrFail(), 'Card Co', $quantity, $admin);

        return $inProduction ? $batch : $batches->changeStatus($batch, CardBatchStatus::Rejected, 'order cancelled', $admin);
    }

    private function actingAsStation(): User
    {
        $admin = User::factory()->platformAdmin()->create();
        Sanctum::actingAs($admin, ['*']);

        return $admin;
    }

    /**
     * What the station app does: tap the chip, relay each round's commands (stopping at the first refused one)
     * until the server says done. `$lose(stage, n)` may return how many commands run before the tag leaves the
     * field; then the station gives up this attempt and the last response is returned.
     *
     * @param  (Closure(string, int): ?int)|null  $lose
     */
    private function station(Ntag424Chip $chip, CardBatch $batch, ?Closure $lose = null): TestResponse
    {
        $response = $this->postJson("/api/v1/admin/card-batches/{$batch->id}/personalizations", ['rf_uid' => $chip->uidHex()]);
        while ($response->status() === 200 && $response->json('data.personalization') !== null) {
            $this->bodies[] = (string) $response->getContent();
            /** @var list<string> $commands */
            $commands = $response->json('data.commands');
            $limit = $lose !== null ? $lose((string) $response->json('data.stage'), count($commands)) : null;
            $answers = [];
            foreach ($commands as $i => $command) {
                if ($limit !== null && $i >= $limit) {
                    break;
                }
                $answer = $chip->transceive((string) hex2bin($command));
                $answers[] = bin2hex($answer);
                if (! in_array(strtoupper(bin2hex(substr($answer, -2))), ['9000', '9100', '91AF', '9190'], true)) {
                    break;
                }
            }
            if ($limit !== null) {
                return $response;
            }
            $response = $this->postJson('/api/v1/admin/personalizations/'.$response->json('data.personalization'), ['responses' => $answers]);
        }
        $this->bodies[] = (string) $response->getContent();

        return $response;
    }

    private function keys(Card $card): CardKeys
    {
        return new CardKeys($this->app->make(CryptoProvider::class), 'ks-2026-01', $card->batch_id);
    }

    private function assertKeyedAsProfile(Ntag424Chip $chip, Card $card): void
    {
        $keys = $this->keys($card);
        $this->assertSame($keys->masterKey($chip->uid), $chip->key(0));
        $this->assertSame($keys->metaReadKey(), $chip->key(1));
        $this->assertSame($keys->sdmMacKey($chip->uid), $chip->key(2));
        $this->assertSame($keys->challengeKey($chip->uid), $chip->key(3));
        $this->assertSame(CardProfile::FACTORY_KEY, $chip->key(4));
        foreach ([0, 1, 2, 3] as $slot) {
            $this->assertSame(CardProfile::KEY_VERSION, $chip->keyVersion($slot));
        }
        $this->assertTrue($chip->sdmEnabled());
    }

    public function test_a_blank_chip_is_keyed_configured_and_passes_qa_through_the_relay(): void
    {
        $batch = $this->stationBatch();
        $this->actingAsStation();
        $chip = Ntag424Chip::factory();

        $this->station($chip, $batch)->assertOk()
            ->assertJsonPath('data.stage', 'done')
            ->assertJsonPath('data.personalization', null)
            ->assertJsonPath('data.commands', [])
            ->assertJsonPath('data.card.card_number', $batch->batch_code.'-0001')
            ->assertJsonPath('data.card.state', 'qa_passed');

        /** @var Card $card */
        $card = Card::query()->withoutGlobalScopes()->where('uid', $chip->uid)->firstOrFail();
        $this->assertSame(CardState::QaPassed, $card->state);
        $this->assertKeyedAsProfile($chip, $card);

        // The chip now presents a SUN URL the guest page and the till accept; QA consumed counter 1.
        $this->assertSame(1, $card->sdm_counter);
        $this->get(str_replace((string) config('giftcard.tap_url'), '/t', $chip->readNdefUrl()))->assertOk();

        // The history: registered → personalized → qa_passed, and the station steps in the event stream.
        $this->assertSame(['manufactured', 'personalized', 'qa_passed'], CardEvent::query()->where('card_id', $card->id)->orderBy('chain_seq')->get()->map(fn (CardEvent $e): string => $e->to_state->value)->all());
        $stages = SecurityEvent::query()->where('type', SecurityEventType::CardPersonalize->value)->pluck('data')->map(fn ($d) => $d['stage'])->all();
        $this->assertSame(['keys', 'qa'], $stages);

        // No key ever reached the phone: only encrypted, MACed commands.
        $keys = $this->keys($card);
        foreach ([$keys->masterKey($chip->uid), $keys->metaReadKey(), $keys->sdmMacKey($chip->uid), $keys->challengeKey($chip->uid)] as $key) {
            foreach ($this->bodies as $body) {
                $this->assertStringNotContainsStringIgnoringCase(bin2hex($key), $body);
            }
        }
    }

    public function test_a_chip_whose_answer_was_lost_after_rekeying_is_finished_with_its_own_keys(): void
    {
        $batch = $this->stationBatch();
        $this->actingAsStation();
        $chip = Ntag424Chip::factory();

        // The whole script runs on the chip, but its answers never reach the server.
        $this->station($chip, $batch, static fn (string $stage, int $n): ?int => $stage === 'script' ? $n : null);
        $this->assertKeyedAsProfile($chip, Card::query()->withoutGlobalScopes()->where('uid', $chip->uid)->firstOrFail());
        $this->assertSame(CardState::Manufactured, Card::query()->withoutGlobalScopes()->where('uid', $chip->uid)->firstOrFail()->state);

        // Second tap: factory K0 is refused, the card's own K0 works, no key is changed twice.
        $this->station($chip, $batch)->assertOk()->assertJsonPath('data.card.state', 'qa_passed');
        $this->assertKeyedAsProfile($chip, Card::query()->withoutGlobalScopes()->where('uid', $chip->uid)->firstOrFail());
    }

    public function test_a_chip_that_left_the_field_in_the_middle_of_the_script_is_resumed_safely(): void
    {
        $batch = $this->stationBatch();
        $this->actingAsStation();
        $chip = Ntag424Chip::factory();

        // Settings and K1 are written, then the tag is gone (K2, K3, K0 still factory).
        $this->station($chip, $batch, static fn (string $stage, int $n): ?int => $stage === 'script' ? 2 : null);
        $this->assertSame(CardProfile::KEY_VERSION, $chip->keyVersion(1));
        $this->assertSame(0, $chip->keyVersion(2));
        $this->assertSame(CardState::Manufactured, Card::query()->withoutGlobalScopes()->where('uid', $chip->uid)->firstOrFail()->state);

        $this->station($chip, $batch)->assertOk()->assertJsonPath('data.card.state', 'qa_passed');
        $this->assertKeyedAsProfile($chip, Card::query()->withoutGlobalScopes()->where('uid', $chip->uid)->firstOrFail());
        $this->assertSame(1, Card::query()->withoutGlobalScopes()->count());
    }

    public function test_a_chip_with_unknown_keys_is_refused_and_recorded(): void
    {
        $batch = $this->stationBatch();
        $this->actingAsStation();
        $foreign = Ntag424Chip::factory();
        // Someone else's chip: K0 is neither factory nor ours.
        $reflection = new \ReflectionProperty($foreign, 'keys');
        $reflection->setValue($foreign, array_fill(0, 5, random_bytes(16)));

        $this->station($foreign, $batch)->assertStatus(422)
            ->assertJsonPath('code', 'CARD_PERSONALIZATION_FAILED')
            ->assertJsonPath('context.reason', 'auth:91AE');

        $refusal = SecurityEvent::query()->where('type', SecurityEventType::CardPersonalize->value)->where('outcome', SecurityEventOutcome::Refused->value)->firstOrFail();
        $this->assertSame('CARD_PERSONALIZATION_FAILED:auth:91AE', $refusal->reason);
        $this->artisan('giftcard:monitor-security-events')->assertSuccessful();
        $this->assertSame(1, SecurityAlert::query()->where('rule', 'card.unknown_keys')->count());
    }

    public function test_a_chip_that_can_never_be_keyed_gives_its_place_in_the_order_back(): void
    {
        // docs/NFC.md A4 then A7: a chip of another system held to the station must not take a genuine chip's place.
        $batch = $this->stationBatch(1);
        $this->actingAsStation();
        $foreign = Ntag424Chip::factory();
        (new \ReflectionProperty($foreign, 'keys'))->setValue($foreign, array_fill(0, 5, random_bytes(16)));
        $this->station($foreign, $batch)->assertStatus(422)->assertJsonPath('context.reason', 'auth:91AE');
        $this->assertSame(CardState::QaFailed, Card::query()->withoutGlobalScopes()->where('uid', $foreign->uid)->sole()->state);

        $this->station(Ntag424Chip::factory(), $batch)->assertOk()->assertJsonPath('data.card.state', 'qa_passed');
    }

    public function test_a_chip_that_claims_to_be_an_ntag_424_dna_but_cannot_prove_it_is_counterfeit(): void
    {
        $batch = $this->stationBatch(1);
        $this->actingAsStation();

        // An emulator with the right GetVersion answer that does not know Read_Sig.
        $noSignature = Ntag424Chip::factory();
        $noSignature->readSigStatus = "\x91\x1C";
        $this->station($noSignature, $batch)->assertStatus(422)->assertJsonPath('context.reason', 'not_genuine');

        // One that answers GetVersion with frames of the wrong length.
        $shortVersion = Ntag424Chip::factory();
        $shortVersion->hardwareVersion = "\x04\x04\x02\x30\x00\x11";
        $this->station($shortVersion, $batch)->assertStatus(422)->assertJsonPath('context.reason', 'version_length');

        foreach ([$noSignature, $shortVersion] as $chip) {
            $this->assertSame(CardState::QaFailed, Card::query()->withoutGlobalScopes()->where('uid', $chip->uid)->sole()->state);
            $this->assertSame(0, $chip->keyVersion(0));
        }
        $this->artisan('giftcard:monitor-security-events')->assertSuccessful();
        $this->assertSame(2, SecurityAlert::query()->where('rule', 'card.counterfeit')->sole()->occurrences, 'both chips count in the batch\'s alert');
        $this->station(Ntag424Chip::factory(), $batch)->assertOk()->assertJsonPath('data.card.state', 'qa_passed');
    }

    public function test_a_chip_that_is_not_a_genuine_nxp_chip_is_never_keyed(): void
    {
        $batch = $this->stationBatch(1);
        $this->actingAsStation();
        $fake = Ntag424Chip::counterfeit();

        $this->station($fake, $batch)->assertStatus(422)->assertJsonPath('context.reason', 'not_genuine');
        $card = Card::query()->withoutGlobalScopes()->where('uid', $fake->uid)->firstOrFail();
        $this->assertSame(CardState::QaFailed, $card->state);
        $this->assertSame(0, $fake->keyVersion(0), 'no key was changed');
        // Held again, the check runs again and refuses it again; it still gets no key.
        $this->station($fake, $batch)->assertStatus(422)->assertJsonPath('context.reason', 'not_genuine');
        $this->assertSame(0, $fake->keyVersion(0));

        // Its place in the order goes to a genuine chip; after that the counterfeit is not even checked again.
        $genuine = Ntag424Chip::factory();
        $this->station($genuine, $batch)->assertOk()->assertJsonPath('data.card.state', 'qa_passed');
        $this->assertNotNull(Card::query()->withoutGlobalScopes()->where('uid', $genuine->uid)->value('originality_signature'));
        $this->station($fake, $batch)->assertStatus(422)->assertJsonPath('context.reason', 'qa_failed');
    }

    public function test_a_genuine_chip_refused_by_a_wrong_chip_check_is_checked_again_and_keyed(): void
    {
        $batch = $this->stationBatch(1);
        $this->actingAsStation();
        // The first real cards were refused by the station (it stopped at Read_Sig's 91 90): their chips got no key.
        $chip = Ntag424Chip::factory();
        $answer = $chip->hardwareVersion;
        $chip->hardwareVersion = "\x04\x04\x02\x31\x00\x11\x05";
        $this->station($chip, $batch)->assertStatus(422)->assertJsonPath('context.reason', 'not_ntag424');
        $this->assertSame(0, $chip->keyVersion(0));

        $chip->hardwareVersion = $answer;
        $this->station($chip, $batch)->assertOk()->assertJsonPath('data.card.state', 'qa_passed');
        $card = Card::query()->withoutGlobalScopes()->where('uid', $chip->uid)->sole();
        $this->assertSame(CardState::QaPassed, $card->state);
        $this->assertSame(['manufactured', 'qa_failed', 'manufactured', 'personalized', 'qa_passed'],
            CardEvent::query()->withoutGlobalScopes()->where('card_id', $card->id)->orderBy('created_at')->orderBy('id')->pluck('to_state')->map(fn (CardState $s): string => $s->value)->all());
    }

    public function test_a_chip_refused_for_unknown_keys_is_not_checked_again(): void
    {
        $batch = $this->stationBatch(2);
        $this->actingAsStation();
        $foreign = Ntag424Chip::factory();
        (new \ReflectionProperty($foreign, 'keys'))->setValue($foreign, array_fill(0, 5, random_bytes(16)));
        $this->station($foreign, $batch)->assertStatus(422)->assertJsonPath('context.reason', 'auth:91AE');
        $this->station($foreign, $batch)->assertStatus(422)->assertJsonPath('context.reason', 'qa_failed');
    }

    public function test_only_an_ntag_424_dna_whose_version_carries_its_uid_is_keyed(): void
    {
        $batch = $this->stationBatch(1);
        $this->actingAsStation();

        // Another NXP product (a DESFire: HW type 01) with a valid-looking signature.
        $desfire = Ntag424Chip::factory();
        $desfire->hardwareVersion = "\x04\x01\x01\x33\x00\x1A\x05";
        $this->station($desfire, $batch)->assertStatus(422)->assertJsonPath('context.reason', 'not_ntag424')
            // What the chip answered is named (hardware, software, production data after the UID), for diagnosis.
            ->assertJsonPath('context.detail', fn (string $d): bool => str_starts_with($d, '04010133001A05 '));
        $this->assertSame(0, $desfire->keyVersion(0));

        // An emulator replaying another chip's production data.
        $emulator = Ntag424Chip::factory();
        $emulator->productionUid = "\x04".random_bytes(6);
        $this->station($emulator, $batch)->assertStatus(422)->assertJsonPath('context.reason', 'uid_mismatch');

        // A chip of another vendor.
        $foreign = Ntag424Chip::factory();
        $foreign->softwareVersion = "\x05\x04\x02\x01\x02\x11\x05";
        $this->station($foreign, $batch)->assertStatus(422)->assertJsonPath('context.reason', 'not_nxp');

        foreach ([$desfire, $emulator, $foreign] as $chip) {
            $this->assertSame(CardState::QaFailed, Card::query()->withoutGlobalScopes()->where('uid', $chip->uid)->sole()->state);
        }
        $this->station(Ntag424Chip::factory(), $batch)->assertOk()->assertJsonPath('data.card.state', 'qa_passed');

        $this->artisan('giftcard:monitor-security-events')->assertSuccessful();
        $this->assertSame(1, SecurityAlert::query()->where('rule', 'card.counterfeit')->count(), 'one alert per batch, deduplicated');
    }

    public function test_a_tampered_answer_breaks_the_session(): void
    {
        $batch = $this->stationBatch();
        $this->actingAsStation();
        $chip = Ntag424Chip::factory();

        $begun = $this->postJson("/api/v1/admin/card-batches/{$batch->id}/personalizations", ['rf_uid' => $chip->uidHex()])->assertOk();
        $answers = array_map(fn (string $c): string => bin2hex($chip->transceive((string) hex2bin($c))), $begun->json('data.commands'));
        $auth = $this->postJson('/api/v1/admin/personalizations/'.$begun->json('data.personalization'), ['responses' => $answers])->assertOk();
        $session = $this->postJson('/api/v1/admin/personalizations/'.$auth->json('data.personalization'), [
            'responses' => [bin2hex($chip->transceive((string) hex2bin($auth->json('data.commands.0'))))],
        ])->assertOk()->assertJsonPath('data.stage', 'versions');

        $versions = array_map(fn (string $c): string => bin2hex($chip->transceive((string) hex2bin($c))), $session->json('data.commands'));
        $versions[1] = substr_replace($versions[1], $versions[1][3] === '0' ? '1' : '0', 3, 1);
        $this->postJson('/api/v1/admin/personalizations/'.$session->json('data.personalization'), ['responses' => $versions])
            ->assertStatus(422)->assertJsonPath('code', 'CARD_PERSONALIZATION_FAILED');

        // Each round is used once.
        $this->postJson('/api/v1/admin/personalizations/'.$session->json('data.personalization'), ['responses' => $versions])
            ->assertStatus(422);
        $this->assertSame('CARD_PERSONALIZATION_FAILED:expired', SecurityEvent::query()->where('outcome', 'refused')->orderByDesc('seq')->value('reason'));
    }

    public function test_a_round_relayed_twice_at_the_same_time_is_used_once(): void
    {
        // Both requests read the round before either removes it (GET, GET, DEL, DEL).
        $store = new class extends ArrayStore
        {
            public function forget($key): bool
            {
                return true;
            }
        };
        $this->app->instance(CacheRepository::class, new Repository($store));
        $batch = $this->stationBatch();
        $this->actingAsStation();
        $chip = Ntag424Chip::factory();

        $begun = $this->postJson("/api/v1/admin/card-batches/{$batch->id}/personalizations", ['rf_uid' => $chip->uidHex()])->assertOk();
        $answers = array_map(fn (string $c): string => bin2hex($chip->transceive((string) hex2bin($c))), $begun->json('data.commands'));
        $round = '/api/v1/admin/personalizations/'.$begun->json('data.personalization');

        $this->postJson($round, ['responses' => $answers])->assertOk();
        $this->postJson($round, ['responses' => $answers])->assertStatus(422)->assertJsonPath('context.reason', 'expired');
    }

    public function test_only_batches_in_production_take_chips(): void
    {
        $this->actingAsStation();
        $chip = Ntag424Chip::factory();

        $this->station($chip, $this->stationBatch(inProduction: false))->assertStatus(422)
            ->assertJsonPath('code', 'CARD_PERSONALIZATION_FAILED');
        $this->assertSame(0, Card::query()->withoutGlobalScopes()->count());

        // A card that already passed QA is not personalised again.
        $batch = $this->stationBatch();
        $this->station($chip, $batch)->assertOk();
        $this->station($chip, $batch)->assertStatus(422);
        $this->assertSame(['CARD_PERSONALIZATION_FAILED:batch_not_in_production', 'CARD_PERSONALIZATION_FAILED:already_personalized'],
            SecurityEvent::query()->where('outcome', 'refused')->orderBy('seq')->pluck('reason')->all());
    }

    public function test_the_station_lists_the_batches_it_may_personalise(): void
    {
        $batch = $this->stationBatch(2);
        $this->stationBatch(inProduction: false);
        $this->actingAsStation();
        $this->station(Ntag424Chip::factory(), $batch)->assertOk();

        $this->getJson('/api/v1/admin/station/batches')->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $batch->id)
            ->assertJsonPath('data.0.batch_code', $batch->batch_code)
            ->assertJsonPath('data.0.restaurant', 'Zum Goldenen Hirschen')
            ->assertJsonPath('data.0.quantity_ordered', 2)
            ->assertJsonPath('data.0.registered', 1)
            ->assertJsonPath('data.0.qa_passed', 1);
    }

    public function test_the_station_is_platform_only(): void
    {
        $batch = $this->stationBatch();
        $this->actingAsStaff($this->restaurant, RoleSlug::Owner);

        $this->postJson("/api/v1/admin/card-batches/{$batch->id}/personalizations", ['rf_uid' => '04A1B2C3D4E5F6'])->assertForbidden();
        $this->postJson('/api/v1/admin/personalizations/01J0000000000000000000000A', ['responses' => ['9000']])->assertForbidden();
    }
}
