<?php

declare(strict_types=1);

namespace Tests\Feature\Abuse;

use App\Enums\CardState;
use App\Enums\RoleSlug;
use App\Models\Card;
use App\Models\KeySet;
use App\Models\Restaurant;
use App\Models\SecurityAlert;
use App\Models\User;
use App\Services\Cards\CardBatchLifecycle;
use App\Support\Actor;
use Laravel\Sanctum\Sanctum;
use Tests\Support\Ntag424Chip;
use Tests\Support\WithCards;
use Tests\TestCase;

/**
 * Pre-launch penetration tests of the card protocol edges: malformed tap pages, a relay that reorders the station's
 * answers, and a cloned card that knows the genuine UID.
 */
final class NfcAttackTest extends TestCase
{
    use WithCards;

    private Restaurant $restaurant;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpCardKeystore();
        $this->restaurant = $this->restaurant();
    }

    protected function tearDown(): void
    {
        $this->tearDownCardKeystore();
        parent::tearDown();
    }

    public function test_the_station_cannot_skip_the_originality_check_by_numbering_its_answers(): void
    {
        $admin = new Actor(User::factory()->platformAdmin()->create());
        $batches = app(CardBatchLifecycle::class);
        $batch = $batches->order($this->restaurant, KeySet::query()->where('version', 'ks-2026-01')->firstOrFail(), 'Card Co', 1, $admin);
        Sanctum::actingAs(User::factory()->platformAdmin()->create(), ['*']);
        $fake = Ntag424Chip::counterfeit();

        $round = $this->postJson("/api/v1/admin/card-batches/{$batch->id}/personalizations", ['rf_uid' => $fake->uidHex()])->assertOk();
        $answers = [];
        foreach ((array) $round->json('data.commands') as $i => $command) {
            $answers[$i] = bin2hex($fake->transceive((string) hex2bin((string) $command)));
        }
        // A relay that leaves out the answer to Read_Sig (index 4) and numbers the rest itself.
        unset($answers[4]);

        $this->postJson('/api/v1/admin/personalizations/'.$round->json('data.personalization'), ['responses' => $answers])
            ->assertStatus(422);
        $this->assertSame(0, $fake->keyVersion(0), 'a counterfeit chip never gets keys');
        $this->assertNotSame(CardState::Personalized, Card::query()->withoutGlobalScopes()->where('uid', $fake->uid)->sole()->state);
    }

    public function test_the_tap_page_answers_a_malformed_query_without_an_error(): void
    {
        [$card] = $this->activeCardVoucher($this->restaurant);
        $url = $this->chip($card)->readNdefUrl();
        $path = (string) parse_url($url, PHP_URL_PATH);
        parse_str((string) parse_url($url, PHP_URL_QUERY), $query);

        foreach (['e[]=1&m=2', 'e=00&m[x]=1', "e[]={$query['e']}&m[]={$query['m']}"] as $malformed) {
            $this->get("{$path}?{$malformed}")->assertForbidden();
        }
        // The genuine URL still works afterwards.
        $this->get($path.'?'.parse_url($url, PHP_URL_QUERY))->assertOk();
    }

    public function test_a_cloned_card_with_the_genuine_uid_raises_the_clone_alert(): void
    {
        [$card] = $this->activeCardVoucher($this->restaurant);
        $this->actingAsStaff($this->restaurant, RoleSlug::Waiter);
        $genuine = $this->chip($card);

        // A fresh URL skimmed from the genuine card, replayed by an emulator that also copies the UID it saw on
        // the radio layer. It does not have K3, so its answer to the challenge is wrong.
        $emulator = new Ntag424Chip($card->uid);
        $begun = $this->postJson('/api/v1/presentments/cards', [
            'purpose' => 'spend',
            'tap_url' => $genuine->readNdefUrl(),
            'rf_uid' => $card->uidHex(),
            'challenge' => bin2hex(substr($emulator->authenticateFirst(), 0, 16)),
        ])->assertOk();
        $answer = $emulator->transceive((string) hex2bin((string) $begun->json('data.command')));
        $this->postJson('/api/v1/presentments/cards/'.$begun->json('data.authentication'), ['response' => bin2hex(str_pad(substr($answer, 0, -2), 32, "\0")."\x91\x00")])
            ->assertForbidden()
            ->assertJsonPath('code', 'CARD_AUTHENTICATION_FAILED');

        $this->artisan('giftcard:monitor-security-events')->assertSuccessful();
        $this->assertSame('card:'.$card->card_number, SecurityAlert::query()->where('rule', 'card.clone_attempt')->sole()->subject);
    }
}
