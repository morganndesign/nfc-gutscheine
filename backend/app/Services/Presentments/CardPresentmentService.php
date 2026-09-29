<?php

declare(strict_types=1);

namespace App\Services\Presentments;

use App\Crypto\CryptoProvider;
use App\Crypto\Ntag424\CardAuthenticator;
use App\Crypto\Ntag424\CardKeys;
use App\Enums\CardState;
use App\Enums\MediumStatus;
use App\Enums\MediumType;
use App\Enums\PresentmentMethod;
use App\Enums\PresentmentPurpose;
use App\Enums\PresentmentStatus;
use App\Enums\SecurityEventType;
use App\Enums\VoucherKind;
use App\Exceptions\Domain\CardAuthenticationFailedException;
use App\Exceptions\Domain\CardNotUsableException;
use App\Exceptions\Domain\DomainException;
use App\Exceptions\Domain\PresentmentThrottledException;
use App\Exceptions\Domain\SunVerificationFailedException;
use App\Models\Card;
use App\Models\KeySet;
use App\Models\Medium;
use App\Models\Presentment;
use App\Models\Voucher;
use App\Services\Cards\TapVerifier;
use App\Services\Security\SecurityEventRecorder;
use App\Support\Actor;
use App\Support\Tenancy\TenantContext;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\RateLimiter;
use SensitiveParameter;

/**
 * Live authentication of a physical card (A3), relayed by the phone (architecture §10.2):
 *
 * 1. The phone reads the card's NDEF URL (SUN), notes the UID it sees on the radio layer and asks the card for
 *    `AuthenticateEV2First` with K3, which answers E(K3, RndB). {@see begin()} verifies the SUN (the card's
 *    own MAC, counter compare-and-set against copied URLs), checks the radio UID against the SUN UID (a copied
 *    NDEF on another chip fails), the card's state for the purpose, and returns the command for the card.
 * 2. The phone relays the card's answer. {@see complete()} checks it (the card proved it holds its key) and
 *    creates a single-use, 60-second presentment, exactly like a scan.
 *
 * The phone never holds a key, never sees RndA and cannot shortcut a step. Failed attempts count towards the
 * same lock-out as failed scans.
 */
final class CardPresentmentService
{
    public function __construct(
        private readonly TapVerifier $taps,
        private readonly CardAuthenticator $authenticator,
        private readonly CryptoProvider $crypto,
        private readonly TenantContext $tenant,
        private readonly SecurityEventRecorder $events,
    ) {}

    /**
     * @param  string  $tapUrl  The NDEF URI read from the card
     * @param  string  $rfUidHex  The UID the phone saw on the radio layer (14 hex)
     * @param  string  $encryptedRndBHex  The card's answer to AuthenticateEV2First part 1 (32 hex)
     * @return array{authentication: string, command: string, expires_in: int} command = APDU (hex) for the card
     */
    public function begin(Actor $actor, PresentmentPurpose $purpose, string $tapUrl, string $rfUidHex, #[SensitiveParameter] string $encryptedRndBHex): array
    {
        $restaurant = $this->tenant->require();
        $throttle = $this->throttleKey($actor, $restaurant->getKey());
        if (RateLimiter::tooManyAttempts($throttle, $this->failureLimit())) {
            $e = new PresentmentThrottledException('', ['retry_after' => RateLimiter::availableIn($throttle)]);
            $this->events->refused(SecurityEventType::CardAuthenticate, $actor, $e, data: ['purpose' => $purpose->value, 'stage' => 'begin']);

            throw $e;
        }

        try {
            [$keySet, $e, $m] = $this->parse($tapUrl);
            $card = $this->taps->verify($keySet, $e, $m, $actor, $purpose->value);

            // Anti-cloning: the SUN names the chip that computed it; the radio layer names the chip on the phone.
            if (preg_match('/^[0-9A-Fa-f]{14}$/', $rfUidHex) !== 1 || ! hash_equals($card->uid, (string) hex2bin($rfUidHex))) {
                throw new CardAuthenticationFailedException('', ['reason' => 'rf_uid_mismatch']);
            }
            if ($card->restaurant_id !== $restaurant->getKey()) {
                throw new CardNotUsableException('', ['reason' => 'other_restaurant']);
            }
            if (! in_array($card->state, $purpose->cardStates(), true)) {
                throw new CardNotUsableException('', ['reason' => 'state', 'state' => $card->state->value]);
            }
            $voucher = $purpose === PresentmentPurpose::Spend ? $this->voucherOf($card) : null;
            if (preg_match('/^[0-9A-Fa-f]{32}$/', $encryptedRndBHex) !== 1) {
                throw new CardAuthenticationFailedException;
            }

            $begun = $this->authenticator->begin($this->keysFor($card), $card->uid, (string) hex2bin($encryptedRndBHex), [
                'card' => $card->getKey(),
                'purpose' => $purpose->value,
                'user' => $actor->userId(),
                'device' => $actor->deviceId(),
                'restaurant' => $restaurant->getKey(),
                'voucher' => $voucher?->getKey(),
                'counter' => $card->sdm_counter,
            ]);
        } catch (DomainException $refusal) {
            $this->refused($actor, $throttle, $refusal, $purpose, 'begin', $card ?? null);

            throw $refusal;
        }

        return [
            'authentication' => $begun['challenge'],
            // AuthenticateEV2First part 2: 90 AF 00 00 20 ‖ E(K3, RndA ‖ RndB') ‖ 00
            'command' => '90AF000020'.strtoupper(bin2hex($begun['response'])).'00',
            'expires_in' => CardAuthenticator::LIFETIME_SECONDS,
        ];
    }

    /**
     * @param  string  $cardResponseHex  The card's answer to part 2: 32 bytes of data and status word 91 00
     */
    public function complete(Actor $actor, string $authentication, #[SensitiveParameter] string $cardResponseHex): Presentment
    {
        $restaurant = $this->tenant->require();
        $throttle = $this->throttleKey($actor, $restaurant->getKey());
        $card = null;
        $purpose = null;

        try {
            $response = preg_match('/^[0-9A-Fa-f]{68}$/', $cardResponseHex) === 1 ? (string) hex2bin($cardResponseHex) : '';
            if ($response === '' || substr($response, 32) !== "\x91\x00") {
                throw new CardAuthenticationFailedException;
            }

            [, $context] = $this->authenticator->finish(function (array $context) use (&$card): CardKeys {
                $card = Card::query()->withoutGlobalScopes()->findOrFail($context['card']);

                return $this->keysFor($card);
            }, $authentication, substr($response, 0, 32));

            /** @var Card $card */
            $purpose = PresentmentPurpose::from((string) $context['purpose']);
            if ($context['user'] !== $actor->userId() || $context['device'] !== $actor->deviceId() || $context['restaurant'] !== $restaurant->getKey()) {
                throw new CardAuthenticationFailedException;
            }

            // The card may have been suspended between the two steps.
            $card->refresh();
            if (! in_array($card->state, $purpose->cardStates(), true)) {
                throw new CardNotUsableException('', ['reason' => 'state', 'state' => $card->state->value]);
            }
            $voucher = $purpose === PresentmentPurpose::Spend ? $this->voucherOf($card) : null;
            if ($voucher !== null && $voucher->getKey() !== $context['voucher']) {
                throw new CardAuthenticationFailedException;
            }

            $presentment = new Presentment;
            $presentment->forceFill([
                'restaurant_id' => $restaurant->getKey(),
                'voucher_id' => $voucher?->getKey(),
                'medium_id' => $voucher !== null ? $this->mediumOf($card)?->getKey() : null,
                'card_id' => $card->getKey(),
                'rf_uid' => $card->uid,
                'sdm_counter' => $card->sdm_counter,
                'purpose' => $purpose,
                'method' => PresentmentMethod::LiveAuth,
                'level' => PresentmentMethod::LiveAuth->level(),
                'status' => PresentmentStatus::Verified,
                'user_id' => $actor->userId(),
                'device_id' => $actor->deviceId(),
                'expires_at' => Carbon::now()->addSeconds(PresentmentService::lifetimeSeconds()),
                'created_at' => Carbon::now(),
            ])->save();
        } catch (DomainException $refusal) {
            $this->refused($actor, $throttle, $refusal, $purpose, 'complete', $card);

            throw $refusal;
        }

        $this->events->record(SecurityEventType::CardAuthenticate, $actor, subject: $voucher, data: [
            'card_number' => $card->card_number,
            'purpose' => $purpose->value,
            'counter' => $card->sdm_counter,
            'presentment_id' => $presentment->getKey(),
            'stage' => 'complete',
        ], restaurantId: (string) $restaurant->getKey());

        return $presentment->setRelation('voucher', $voucher)->setRelation('card', $card);
    }

    /** @return array{0: string, 1: string, 2: string} key set version, e, m */
    private function parse(string $tapUrl): array
    {
        $origin = (string) config('giftcard.tap_url');
        if (! str_starts_with($tapUrl, $origin.'/')) {
            throw new SunVerificationFailedException;
        }
        $path = (string) parse_url($tapUrl, PHP_URL_PATH);
        parse_str((string) parse_url($tapUrl, PHP_URL_QUERY), $query);
        $keySet = ltrim($path, '/');
        $e = $query['e'] ?? null;
        $m = $query['m'] ?? null;
        if (! is_string($e) || ! is_string($m) || preg_match('/^[a-z0-9][a-z0-9._-]{0,31}$/', $keySet) !== 1) {
            throw new SunVerificationFailedException;
        }

        return [$keySet, $e, $m];
    }

    private function keysFor(Card $card): CardKeys
    {
        /** @var KeySet $keySet */
        $keySet = KeySet::query()->findOrFail($card->key_set_id);

        return new CardKeys($this->crypto, $keySet->version, $card->batch_id);
    }

    private function mediumOf(Card $card): ?Medium
    {
        /** @var Medium|null */
        return Medium::query()->withoutGlobalScopes()
            ->where('card_id', $card->getKey())
            ->where('type', MediumType::NfcCard->value)
            ->where('status', MediumStatus::Active->value)
            ->first();
    }

    /** The voucher an active card pays for. */
    private function voucherOf(Card $card): Voucher
    {
        $medium = $this->mediumOf($card);
        /** @var Voucher|null $voucher */
        $voucher = $medium !== null ? Voucher::query()->withoutGlobalScopes()->find($medium->voucher_id) : null;
        if ($voucher === null || $voucher->kind !== VoucherKind::Card) {
            throw new CardNotUsableException('', ['reason' => 'not_bound', 'state' => CardState::Active->value]);
        }

        return $voucher;
    }

    private function refused(Actor $actor, string $throttle, DomainException $refusal, ?PresentmentPurpose $purpose, string $stage, ?Card $card): void
    {
        if (! $refusal instanceof PresentmentThrottledException && ! $refusal instanceof CardNotUsableException) {
            RateLimiter::hit($throttle, (int) config('giftcard.security.presentment_failure_decay_seconds', 300));
        }
        $this->events->refused(SecurityEventType::CardAuthenticate, $actor, $refusal, data: array_filter([
            'card_number' => $card?->card_number,
            'purpose' => $purpose?->value,
            'stage' => $stage,
        ], static fn (mixed $v): bool => $v !== null), restaurantId: $card?->restaurant_id);
    }

    private function failureLimit(): int
    {
        return (int) config('giftcard.security.presentment_failure_limit', 10);
    }

    /** The same budget as failed scans: per restaurant, user and device (never per IP address). */
    private function throttleKey(Actor $actor, string $restaurantId): string
    {
        return 'presentment-failures:'.$restaurantId.'|'.($actor->userId() ?? '-').'|'.($actor->deviceId() ?? '-');
    }
}
