<?php

declare(strict_types=1);

namespace App\Services\Cards;

use App\Crypto\CryptoProvider;
use App\Crypto\Ntag424\CardKeys;
use App\Crypto\Ntag424\CardProfile;
use App\Crypto\Ntag424\ChipVersion;
use App\Crypto\Ntag424\Ev2FirstAuthentication;
use App\Crypto\Ntag424\Ev2Session;
use App\Crypto\Ntag424\OriginalitySignature;
use App\Crypto\Ntag424\SecureMessaging;
use App\Crypto\Ntag424\TapUrl;
use App\Enums\CardBatchStatus;
use App\Enums\CardState;
use App\Enums\KeySetStatus;
use App\Enums\SecurityEventType;
use App\Exceptions\Domain\CardAuthenticationFailedException;
use App\Exceptions\Domain\CardPersonalizationFailedException;
use App\Exceptions\Domain\DomainException;
use App\Models\Card;
use App\Models\CardBatch;
use App\Models\KeySet;
use App\Services\Security\SecurityEventRecorder;
use App\Support\Actor;
use Illuminate\Contracts\Cache\Repository as Cache;
use Illuminate\Contracts\Encryption\Encrypter;
use Illuminate\Support\Str;

/**
 * Personalises a blank NTAG 424 DNA chip at the in-house station (architecture §9.3), driven entirely by the
 * server: the station phone relays APDUs and never sees a key. Rounds:
 *
 * 1. `begin`: register the chip (`manufactured`) → select, GetVersion (an NXP NTAG 424 DNA with the radio's UID),
 *    Read_Sig (NXP's originality signature), write the NDEF template (free on a blank chip), AuthenticateEV2First with K0.
 * 2. `auth2`: answer the chip with the factory K0; a chip that refuses it gets a second try with its own K0
 *    (it was keyed before, the answer was lost).
 * 3. `versions`: GetKeyVersion 1–3 (CommMode.MAC): keys already at version 01 are not changed again.
 * 4. `script`: ChangeFileSettings (SDM), ChangeKey 1, 2, 3, then 0 (CommMode.Full); then the chip is read like
 *    a guest tap (SUN) and challenged with K3. Verified → `personalized`.
 * 5. `qa`: the chip's K3 answer → `qa_passed`.
 *
 * Every step can be repeated from `begin`: keys are changed only from their known state, K0 last, the NDEF file
 * is written before its write right is taken away. Each round lives {@see self::STEP_SECONDS} and is used once.
 */
final class CardPersonalizer
{
    public const STEP_SECONDS = 60;

    private const PREFIX = 'card-personalization:';

    public function __construct(
        private readonly CryptoProvider $crypto,
        private readonly Cache $cache,
        private readonly Encrypter $encrypter,
        private readonly CardLifecycle $lifecycle,
        private readonly TapVerifier $taps,
        private readonly SecurityEventRecorder $events,
    ) {}

    public function begin(CardBatch $batch, string $rfUid, Actor $actor): PersonalizationStep
    {
        return $this->guard($actor, 'begin', $batch, null, function () use ($batch, $rfUid, $actor): PersonalizationStep {
            if ($batch->status !== CardBatchStatus::InProduction) {
                $this->fail('batch_not_in_production');
            }
            /** @var KeySet $keySet */
            $keySet = KeySet::query()->findOrFail($batch->key_set_id);
            if ($keySet->status !== KeySetStatus::Active) {
                $this->fail('key_set_not_active');
            }
            if (strlen($rfUid) !== 7) {
                $this->fail('invalid_uid');
            }

            /** @var Card|null $card */
            $card = Card::query()->withoutGlobalScopes()->where('uid', $rfUid)->first();
            if ($card === null) {
                $card = $this->lifecycle->register($batch, $rfUid, $actor);
            } elseif ($card->batch_id !== $batch->getKey()) {
                $this->fail('other_batch');
            } elseif ($card->state === CardState::QaFailed) {
                $this->fail('qa_failed');
            } elseif (! in_array($card->state, [CardState::Manufactured, CardState::Personalized], true)) {
                $this->fail('already_personalized');
            }

            $template = TapUrl::ndefTemplate($keySet->version);
            $write = SecureMessaging::apdu(0x8D, chr(CardProfile::NDEF_FILE)."\0\0\0".substr(pack('V', strlen($template['file'])), 0, 3).$template['file']);

            return $this->step($card, [
                'card' => $card->getKey(),
                'batch' => $batch->getKey(),
                'keySet' => $keySet->version,
                'k0' => 'factory',
            ], 'auth', ['select', 'version1', 'version2', 'version3', 'signature', 'write', 'auth1'], [
                self::selectApplication(), ChipVersion::GET_VERSION, ChipVersion::NEXT_FRAME, ChipVersion::NEXT_FRAME, self::READ_SIG, $write, self::authenticateFirst(0),
            ]);
        });
    }

    /** @param list<string> $responses the chip's answers (with status words) to the commands of the last round */
    public function next(string $id, array $responses, Actor $actor): PersonalizationStep
    {
        // Used once, also when the station relays a round twice at the same time: pull() is GET then DEL, the
        // atomic add() of a claim decides.
        $sealed = $this->cache->get(self::PREFIX.$id);
        if (is_string($sealed) && ! $this->cache->add(self::PREFIX.'used:'.$id, true, self::STEP_SECONDS)) {
            $sealed = null;
        }
        $this->cache->forget(self::PREFIX.$id);
        $state = is_string($sealed) ? json_decode($this->encrypter->decryptString($sealed), true, 8, JSON_THROW_ON_ERROR) : null;
        if (! is_array($state)) {
            return $this->guard($actor, 'expired', null, null, fn (): never => $this->fail('expired'));
        }
        /** @var array<string, mixed> $state */
        /** @var Card $card */
        $card = Card::query()->withoutGlobalScopes()->findOrFail($state['card']);
        $stage = (string) $state['stage'];

        return $this->guard($actor, $stage, null, $card, fn (): PersonalizationStep => match ($stage) {
            'auth' => $this->afterAuthStart($card, $state, $responses, $actor),
            'auth2' => $this->afterAuthAnswer($card, $state, $responses, $actor),
            'versions' => $this->afterVersions($card, $state, $responses),
            'script' => $this->afterScript($card, $state, $responses, $actor),
            'qa' => $this->afterQa($card, $state, $responses, $actor),
            default => $this->fail('expired'),
        });
    }

    /**
     * @param  array<string, mixed>  $state
     * @param  list<string>  $responses
     */
    private function afterAuthStart(Card $card, array $state, array $responses, Actor $actor): PersonalizationStep
    {
        /** @var list<string> $expect */
        $expect = $state['expect'];
        $version = [];
        foreach ($responses as $i => $response) {
            $kind = $expect[$i] ?? $this->fail('unexpected_response');
            $sw = self::statusWord($response);
            $ok = match ($kind) {
                'select' => $sw === '9000',
                'version1', 'version2' => $sw === '91AF' && ($version[] = substr($response, 0, -2)) !== '',
                // Only an NXP NTAG 424 DNA whose production data carries the radio's UID.
                'version3' => $sw === '9100' && $this->ntag424($card, $version, substr($response, 0, -2), $actor),
                // Originality: only a genuine NXP NTAG 424 DNA holds NXP's signature of its UID.
                'signature' => in_array($sw, ['9100', '9190'], true) && $this->genuine($card, substr($response, 0, -2), $actor),
                // A chip keyed before no longer lets anyone write: its NDEF file was written first.
                'write' => $sw === '9100' || $sw === '919D',
                default => $sw === '91AF' && strlen($response) === 18,
            };
            if (! $ok) {
                // A chip that answers these plain commands with an error is no NXP NTAG 424 DNA (a chip that left the
                // field gives no answer at all): it never gets keys and gives its place in the order back.
                match ($kind) {
                    'select', 'version1', 'version2', 'version3' => $this->reject($card, 'not_ntag424', 'not an NXP NTAG 424 DNA', $actor),
                    'signature' => $this->reject($card, 'not_genuine', 'not a genuine NXP chip', $actor),
                    default => $this->fail("{$kind}:{$sw}"),
                };
            }
        }
        $last = $expect[count($responses) - 1] ?? null;
        if ($last === 'write') {
            // The phone stops at the refused write; authenticate on its own.
            return $this->step($card, $state, 'auth', ['auth1'], [self::authenticateFirst(0)]);
        }
        if ($last !== 'auth1') {
            $this->fail('incomplete');
        }

        $step = Ev2FirstAuthentication::respond($this->masterKey($card, $state), substr((string) end($responses), 0, 16));
        $state['a'] = bin2hex($step['rndA']);
        $state['b'] = bin2hex($step['rndB']);

        return $this->step($card, $state, 'auth2', ['auth2'], [SecureMessaging::apdu(0xAF, $step['response'])]);
    }

    /**
     * @param  array<string, mixed>  $state
     * @param  list<string>  $responses
     */
    private function afterAuthAnswer(Card $card, array $state, array $responses, Actor $actor): PersonalizationStep
    {
        $response = $this->single($responses);
        if (self::statusWord($response) === '91AE') {
            if ($state['k0'] === 'factory') {
                $state['k0'] = 'card';

                return $this->step($card, $state, 'auth', ['auth1'], [self::authenticateFirst(0)]);
            }
            // Neither the factory K0 nor ours: another system's chip. It can never be keyed here.
            $this->reject($card, 'auth:91AE', 'unknown keys', $actor);
        }
        if (self::statusWord($response) !== '9100' || strlen($response) !== 34) {
            $this->fail('auth:'.self::statusWord($response));
        }
        try {
            $session = Ev2FirstAuthentication::complete($this->masterKey($card, $state), (string) hex2bin((string) $state['a']), (string) hex2bin((string) $state['b']), substr($response, 0, 32));
        } catch (CardAuthenticationFailedException) {
            $this->fail('auth_mismatch');
        }
        unset($state['a'], $state['b']);
        $state['session'] = [bin2hex($session->transactionId), bin2hex($session->encryptionKey), bin2hex($session->macKey)];
        $state['counter'] = 0;

        $commands = [];
        foreach ([1, 2, 3] as $i => $slot) {
            $commands[] = SecureMessaging::resume($session, $i)->macCommand(0x64, chr($slot));
        }

        return $this->step($card, $state, 'versions', ['version1', 'version2', 'version3'], $commands);
    }

    /**
     * @param  array<string, mixed>  $state
     * @param  list<string>  $responses
     */
    private function afterVersions(Card $card, array $state, array $responses): PersonalizationStep
    {
        if (count($responses) !== 3) {
            $this->fail('version:'.self::statusWord((string) end($responses)));
        }
        $session = $this->session($state);
        $counter = (int) $state['counter'];
        $versions = [];
        foreach ([1, 2, 3] as $i => $slot) {
            $data = SecureMessaging::resume($session, $counter + $i)->response($responses[$i]);
            if ($data === null || strlen($data) !== 1 || ! in_array(ord($data), [0x00, CardProfile::KEY_VERSION], true)) {
                $this->fail('version_mac');
            }
            $versions[$slot] = ord($data);
        }
        $counter += 3;

        $keys = $this->keys($card, $state);
        $template = TapUrl::ndefTemplate((string) $state['keySet']);
        $new = [1 => $keys->metaReadKey(), 2 => $keys->sdmMacKey($card->uid), 3 => $keys->challengeKey($card->uid), 0 => $keys->masterKey($card->uid)];

        $kinds = ['settings'];
        $commands = [SecureMessaging::resume($session, $counter)->fullCommand(0x5F, chr(CardProfile::NDEF_FILE), CardProfile::ndefFileSettings($template['piccOffset'], $template['macOffset']))];
        foreach (CardProfile::KEY_ORDER as $slot) {
            $pending = $slot === 0 ? $state['k0'] === 'factory' : $versions[$slot] !== CardProfile::KEY_VERSION;
            if ($pending) {
                $commands[] = SecureMessaging::resume($session, $counter + count($kinds))
                    ->fullCommand(0xC4, chr($slot), CardProfile::changeKeyData($slot, $new[$slot], $slot === 0 ? null : CardProfile::FACTORY_KEY));
                $kinds[] = 'key'.$slot;
            }
        }
        // QA, as a guest's phone and a till would see the card: read the NDEF file (SUN), challenge with K3.
        array_push($commands, "\x00\xA4\x00\x0C\x02\xE1\x04", "\x00\xB0\x00\x00".chr(strlen($template['file'])), self::authenticateFirst(3));
        array_push($kinds, 'selectNdef', 'read', 'auth1');

        $state['counter'] = $counter;

        return $this->step($card, $state, 'script', $kinds, $commands);
    }

    /**
     * @param  array<string, mixed>  $state
     * @param  list<string>  $responses
     */
    private function afterScript(Card $card, array $state, array $responses, Actor $actor): PersonalizationStep
    {
        /** @var list<string> $kinds */
        $kinds = $state['expect'];
        if (count($responses) !== count($kinds)) {
            $failed = $kinds[max(0, count($responses) - 1)] ?? 'script';

            $this->fail("{$failed}:".self::statusWord((string) end($responses)));
        }
        $session = $this->session($state);
        $counter = (int) $state['counter'];
        foreach ($kinds as $i => $kind) {
            if (! in_array($kind, ['settings', 'key1', 'key2', 'key3', 'key0'], true)) {
                break;
            }
            if (SecureMessaging::resume($session, $counter + $i)->response($responses[$i], $kind !== 'key0') === null) {
                $this->fail("{$kind}:".self::statusWord($responses[$i]));
            }
        }

        if ($card->state === CardState::Manufactured) {
            $card = $this->lifecycle->transition($card, CardState::Personalized, 'personalised at station', $actor);
        }
        $this->events->record(SecurityEventType::CardPersonalize, $actor, data: $this->eventData($card, 'keys'), restaurantId: $card->restaurant_id);

        [$read, $challenge] = [$responses[count($kinds) - 2], $responses[count($kinds) - 1]];
        if (self::statusWord($responses[count($kinds) - 3]) !== '9000' || self::statusWord($read) !== '9000') {
            $this->fail('qa_read');
        }
        $url = TapUrl::fromNdef(substr($read, 0, -2));
        try {
            $tap = TapUrl::parse((string) $url);
            $tapped = $this->taps->verify($tap->keySet, $tap->e, $tap->m, $actor, 'qa');
        } catch (DomainException) {
            $this->fail('qa_sun');
        }
        if ($tapped->getKey() !== $card->getKey()) {
            $this->fail('qa_sun');
        }
        if (self::statusWord($challenge) !== '91AF' || strlen($challenge) !== 18) {
            $this->fail('qa_auth:'.self::statusWord($challenge));
        }

        $step = Ev2FirstAuthentication::respond($this->keys($card, $state)->challengeKey($card->uid), substr($challenge, 0, 16));
        unset($state['session'], $state['counter']);
        $state['a'] = bin2hex($step['rndA']);
        $state['b'] = bin2hex($step['rndB']);

        return $this->step($card, $state, 'qa', ['qa'], [SecureMessaging::apdu(0xAF, $step['response'])]);
    }

    /**
     * @param  array<string, mixed>  $state
     * @param  list<string>  $responses
     */
    private function afterQa(Card $card, array $state, array $responses, Actor $actor): PersonalizationStep
    {
        $response = $this->single($responses);
        if (self::statusWord($response) !== '9100' || strlen($response) !== 34) {
            $this->fail('qa_auth:'.self::statusWord($response));
        }
        try {
            Ev2FirstAuthentication::complete($this->keys($card, $state)->challengeKey($card->uid), (string) hex2bin((string) $state['a']), (string) hex2bin((string) $state['b']), substr($response, 0, 32));
        } catch (CardAuthenticationFailedException) {
            $this->fail('qa_auth');
        }

        $card = $this->lifecycle->transition($card, CardState::QaPassed, 'station QA passed', $actor);
        $this->events->record(SecurityEventType::CardPersonalize, $actor, data: $this->eventData($card, 'qa'), restaurantId: $card->restaurant_id);

        return new PersonalizationStep(null, 'done', [], $card);
    }

    /**
     * @param  array<string, mixed>  $state
     * @param  list<string>  $expect
     * @param  list<string>  $commands
     */
    private function step(Card $card, array $state, string $stage, array $expect, array $commands): PersonalizationStep
    {
        $id = (string) Str::ulid();
        $state['stage'] = $stage;
        $state['expect'] = $expect;
        $this->cache->put(self::PREFIX.$id, $this->encrypter->encryptString(json_encode($state, JSON_THROW_ON_ERROR)), self::STEP_SECONDS);

        return new PersonalizationStep($id, $stage, $commands, $card);
    }

    /**
     * Runs a step; a refusal is recorded (after any rollback) and rethrown.
     *
     * @param  \Closure(): PersonalizationStep  $run
     */
    private function guard(Actor $actor, string $stage, ?CardBatch $batch, ?Card $card, \Closure $run): PersonalizationStep
    {
        try {
            return $run();
        } catch (DomainException $refusal) {
            // The batch names the incident: one alert per batch, not per chip.
            $batch ??= $card !== null ? CardBatch::query()->withoutGlobalScopes()->find($card->batch_id) : null;
            $this->events->refused(SecurityEventType::CardPersonalize, $actor, $refusal, data: array_filter([
                'card_number' => $card?->card_number,
                'batch_code' => $batch?->batch_code,
                'stage' => $stage,
            ], static fn (?string $v): bool => $v !== null), restaurantId: $card->restaurant_id ?? $batch?->restaurant_id);

            throw $refusal;
        }
    }

    private function fail(string $reason): never
    {
        throw new CardPersonalizationFailedException('', ['reason' => $reason]);
    }

    /** @param list<string> $responses */
    private function single(array $responses): string
    {
        return count($responses) === 1 ? $responses[0] : $this->fail('unexpected_response');
    }

    /** @param array<string, mixed> $state */
    private function keys(Card $card, array $state): CardKeys
    {
        return new CardKeys($this->crypto, (string) $state['keySet'], $card->batch_id);
    }

    /** @param array<string, mixed> $state */
    private function masterKey(Card $card, array $state): string
    {
        return $state['k0'] === 'factory' ? CardProfile::FACTORY_KEY : $this->keys($card, $state)->masterKey($card->uid);
    }

    /** @param array<string, mixed> $state */
    private function session(array $state): Ev2Session
    {
        /** @var array{0: string, 1: string, 2: string} $s */
        $s = $state['session'];

        return new Ev2Session((string) hex2bin($s[0]), (string) hex2bin($s[1]), (string) hex2bin($s[2]), '', '');
    }

    /** @return array<string, string> */
    private function eventData(Card $card, string $stage): array
    {
        /** @var CardBatch $batch */
        $batch = CardBatch::query()->withoutGlobalScopes()->findOrFail($card->batch_id);

        return ['card_number' => $card->card_number, 'batch_code' => $batch->batch_code, 'stage' => $stage];
    }

    /** Read_Sig (NT4H2421Gx §10.12.1): the 56-byte ECDSA signature of the UID, plain, before authentication. */
    private const READ_SIG = "\x90\x3C\x00\x00\x01\x00\x00";

    /** @param list<string> $version the first two GetVersion frames */
    private function ntag424(Card $card, array $version, string $production, Actor $actor): bool
    {
        $refusal = count($version) === 2 ? ChipVersion::refusal($version[0], $version[1], $production, $card->uid) : 'version_length';
        if ($refusal !== null) {
            $this->reject($card, $refusal, 'not an NXP NTAG 424 DNA', $actor);
        }

        return true;
    }

    /** Checks the chip's originality signature against the configured NXP key and keeps it with the card. */
    private function genuine(Card $card, string $signature, Actor $actor): bool
    {
        $key = (string) config('giftcard.cards.originality_public_key');
        if (! OriginalitySignature::verify($card->uid, $signature, $key)) {
            $this->reject($card, 'not_genuine', 'not a genuine NXP chip', $actor);
        }
        if ($card->originality_signature === null) {
            $card->forceFill(['originality_signature' => strtoupper(bin2hex($signature))])->save();
        }

        return true;
    }

    /** Out of the batch for good: it never gets keys, and it frees its place for a genuine chip. */
    private function reject(Card $card, string $reason, string $cause, Actor $actor): never
    {
        if ($card->state === CardState::Manufactured) {
            $this->lifecycle->transition($card, CardState::QaFailed, $cause, $actor);
        }
        $this->fail($reason);
    }

    private static function selectApplication(): string
    {
        return "\x00\xA4\x04\x00".chr(strlen(CardProfile::APPLICATION)).CardProfile::APPLICATION."\x00";
    }

    /** AuthenticateEV2First part 1: `90 71 00 00 02 KeyNo 00 00`. */
    private static function authenticateFirst(int $slot): string
    {
        return SecureMessaging::apdu(0x71, chr($slot)."\x00");
    }

    private static function statusWord(string $response): string
    {
        return strlen($response) < 2 ? '' : strtoupper(bin2hex(substr($response, -2)));
    }
}
