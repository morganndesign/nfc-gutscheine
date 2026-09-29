<?php

declare(strict_types=1);

namespace App\Services\Cards;

use App\Crypto\CryptoProvider;
use App\Crypto\Ntag424\CardKeys;
use App\Crypto\Ntag424\SunVerifier;
use App\Enums\KeySetStatus;
use App\Enums\SecurityEventType;
use App\Exceptions\Domain\DomainException;
use App\Exceptions\Domain\SunReplayedException;
use App\Exceptions\Domain\SunVerificationFailedException;
use App\Models\Card;
use App\Models\KeySet;
use App\Services\Security\SecurityEventRecorder;
use App\Support\Actor;

/**
 * Verifies a card's tap URL `https://t.giftcardpro.at/{k}?e=…&m=…` (architecture §10.3, P3-01): K1 of key set
 * `{k}` opens the UID and counter, the card's own K2 checks the MAC, and the counter must be higher than the last
 * one accepted (compare-and-set), so a copied URL works at most once. SUN alone never spends, binds or receives.
 */
final class TapVerifier
{
    public function __construct(
        private readonly CryptoProvider $crypto,
        private readonly SecurityEventRecorder $events,
    ) {}

    public function verify(string $keySetVersion, string $e, string $m, Actor $actor, string $purpose = 'balance'): Card
    {
        $card = null;
        try {
            [$card, $counter, $previous] = $this->check($keySetVersion, $e, $m, $card);
        } catch (DomainException $refusal) {
            // A replay names the genuine card whose URL was copied: fraud monitoring counts it per card.
            $this->events->refused(SecurityEventType::CardTap, $actor, $refusal, data: array_filter([
                'key_set' => mb_substr($keySetVersion, 0, 32),
                'purpose' => $purpose,
                'card_number' => $card?->card_number,
            ], static fn (?string $v): bool => $v !== null), restaurantId: $card?->restaurant_id);

            throw $refusal;
        }

        $this->events->record(SecurityEventType::CardTap, $actor, data: array_filter([
            'key_set' => $keySetVersion,
            'card_number' => $card->card_number,
            'counter' => $counter,
            // Reads between two verified taps that never reached the server (skimming shows up here).
            'counter_gap' => $previous !== null ? $counter - $previous : null,
            'purpose' => $purpose,
        ], static fn (mixed $v): bool => $v !== null), restaurantId: $card->restaurant_id);

        return $card;
    }

    /**
     * @param  Card|null  $identified  set to the card as soon as its MAC is verified (also for a replay)
     *
     * @param-out Card $identified
     *
     * @return array{0: Card, 1: int, 2: int|null} card, accepted counter, the previous one
     */
    private function check(string $keySetVersion, string $e, string $m, ?Card &$identified): array
    {
        /** @var KeySet|null $keySet */
        $keySet = preg_match('/^[a-z0-9][a-z0-9._-]{0,31}$/', $keySetVersion) === 1
            ? KeySet::query()->where('version', $keySetVersion)->whereIn('status', [KeySetStatus::Active->value, KeySetStatus::VerifyOnly->value])->first()
            : null;
        if ($keySet === null) {
            throw new SunVerificationFailedException;
        }

        $card = null;
        $message = SunVerifier::verify(
            CardKeys::keySetMetaReadKey($this->crypto, $keySet->version),
            function (string $uid) use ($keySet, &$card): string {
                /** @var Card|null $found */
                $found = Card::query()->withoutGlobalScopes()->where('uid', $uid)->where('key_set_id', $keySet->getKey())->first();
                if ($found === null) {
                    throw new SunVerificationFailedException;
                }
                $card = $found;

                return (new CardKeys($this->crypto, $keySet->version, $found->batch_id))->sdmMacKey($uid);
            },
            $e,
            $m,
        );

        /** @var Card $card */
        $identified = $card;
        $previous = $card->sdm_counter;
        $counter = $message->readCounter;
        // Compare-and-set: only a counter higher than every earlier one is accepted.
        $updated = Card::query()->withoutGlobalScopes()->whereKey($card->getKey())
            ->where(static fn ($q) => $q->whereNull('sdm_counter')->orWhere('sdm_counter', '<', $counter))
            ->update(['sdm_counter' => $counter]);
        if ($updated !== 1) {
            throw new SunReplayedException;
        }

        return [$card->refresh(), $counter, $previous];
    }
}
