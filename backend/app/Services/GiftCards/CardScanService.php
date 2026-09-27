<?php

declare(strict_types=1);

namespace App\Services\GiftCards;

use App\Data\ScanInput;
use App\Enums\NfcTagType;
use App\Enums\ScanMethod;
use App\Enums\ScanResult;
use App\Exceptions\Domain\CardForeignRestaurantException;
use App\Exceptions\Domain\CardNotFoundException;
use App\Exceptions\Domain\NfcReplayDetectedException;
use App\Exceptions\Domain\NfcSignatureInvalidException;
use App\Exceptions\Domain\NfcUidMismatchException;
use App\Exceptions\Domain\ScanThrottledException;
use App\Models\GiftCard;
use App\Models\NfcScan;
use App\Services\Audit\AuditLogger;
use App\Services\Nfc\Ntag424SunVerifier;
use App\Support\Actor;
use App\Support\CardNumber;
use App\Support\Tenancy\TenantContext;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\RateLimiter;

/**
 * Resolves a scanned NFC tag, QR code, link or manually typed card number to a card of the
 * current restaurant, applying anti-fraud checks:
 *
 *  - Brute force: failed lookups are rate limited per user and per IP.
 *  - Tenant isolation: cards of other restaurants are rejected (and the attempt is logged).
 *  - Clone detection (NTAG21x): the chip UID read by the waiter's phone must match the UID bound at write time.
 *  - Replay / clone protection (NTAG 424 DNA): the SUN MAC must verify and the tap counter must increase.
 */
final class CardScanService
{
    public function __construct(
        private readonly TenantContext $tenant,
        private readonly CardUrlBuilder $urls,
        private readonly Ntag424SunVerifier $sun,
        private readonly AuditLogger $audit,
    ) {}

    public function resolve(Actor $actor, ScanInput $input): GiftCard
    {
        $restaurant = $this->tenant->require();
        foreach ($this->throttleKeys($actor) as $key) {
            if (RateLimiter::tooManyAttempts($key, (int) config('giftcard.security.scan_failure_limit'))) {
                $this->log($actor, $input, ScanResult::Throttled);

                throw new ScanThrottledException('', ['retry_after' => RateLimiter::availableIn($key)]);
            }
        }

        $card = $this->find($input);

        if ($card === null) {
            $this->fail($actor, $input, ScanResult::NotFound);

            throw new CardNotFoundException;
        }

        if ($card->restaurant_id !== $restaurant->getKey()) {
            $this->fail($actor, $input, ScanResult::ForeignRestaurant, $card);
            $this->audit->log('gift_card.foreign_scan', $actor, null, metadata: ['method' => $input->method->value]);

            throw new CardForeignRestaurantException;
        }

        // A tap (Android) and an opened tag link (iPhone background reading) both come from the chip.
        if ($input->method === ScanMethod::Nfc || $input->method === ScanMethod::Link) {
            $this->verifyChip($actor, $input, $card, $restaurant->settings->enforce_nfc_uid_binding);
        }

        $this->log($actor, $input, ScanResult::Ok, $card);

        return $card;
    }

    private function find(ScanInput $input): ?GiftCard
    {
        if ($input->cardNumber !== null) {
            $number = CardNumber::normalize($input->cardNumber);

            if (! CardNumber::isValid($number)) {
                return null;
            }

            // Manual lookups are always restricted to the current restaurant.
            /** @var GiftCard|null */
            return GiftCard::query()->where('card_number', $number)->first();
        }

        $token = $input->token !== null ? $this->urls->extractToken($input->token) : null;
        if ($token === null) {
            return null;
        }

        // Deliberately unscoped so that foreign-restaurant cards can be recognised and reported.
        /** @var GiftCard|null */
        return GiftCard::query()->withoutGlobalScopes()->whereNull('deleted_at')->where('public_token', $token)->first();
    }

    private function verifyChip(Actor $actor, ScanInput $input, GiftCard $card, bool $enforceUid): void
    {
        if ($card->nfc_tag_type === NfcTagType::Ntag424Dna) {
            if ($input->picc === null || $input->cmac === null) {
                $this->log($actor, $input, ScanResult::InvalidSignature, $card);

                throw new NfcSignatureInvalidException('This card requires a secure NFC read. Please tap the card again.');
            }

            try {
                $message = $this->sun->verify($input->picc, $input->cmac);
            } catch (NfcSignatureInvalidException $e) {
                $this->log($actor, $input, ScanResult::InvalidSignature, $card);
                $this->audit->log('gift_card.nfc_signature_invalid', $actor, $card);
                $this->hit($actor);

                throw $e;
            }

            if ($card->nfc_uid !== null && $card->nfc_uid !== $message->uid) {
                $this->log($actor, $input, ScanResult::UidMismatch, $card, $message->uid, $message->readCounter);
                $this->audit->log('gift_card.nfc_uid_mismatch', $actor, $card, metadata: ['uid' => $message->uid]);

                $this->hit($actor);

                throw new NfcUidMismatchException;
            }

            // Atomic compare-and-set: only a strictly greater counter is accepted, even under concurrency.
            try {
                $updated = GiftCard::query()
                    ->whereKey($card->getKey())
                    ->where(static fn ($q) => $q->whereNull('nfc_read_counter')->orWhere('nfc_read_counter', '<', $message->readCounter))
                    ->update(['nfc_read_counter' => $message->readCounter, 'nfc_uid' => $card->nfc_uid ?? $message->uid]);
            } catch (UniqueConstraintViolationException) {
                // First tap of a chip that is already linked to another usable card: never bind it twice.
                $this->log($actor, $input, ScanResult::UidMismatch, $card, $message->uid, $message->readCounter);
                $this->audit->log('gift_card.nfc_uid_mismatch', $actor, $card, metadata: ['uid' => $message->uid]);
                $this->hit($actor);

                throw new NfcUidMismatchException;
            }

            if ($updated === 0) {
                $this->log($actor, $input, ScanResult::Replay, $card, $message->uid, $message->readCounter);
                $this->audit->log('gift_card.nfc_replay', $actor, $card, metadata: ['counter' => $message->readCounter]);

                $this->hit($actor);

                throw new NfcReplayDetectedException;
            }

            return;
        }

        // Every NFC tap of the waiter app and the web terminal carries the chip serial number. A tap of a card
        // with a bound chip that arrives without one is treated like a foreign chip.
        if ($enforceUid && $card->nfc_uid !== null && $input->method === ScanMethod::Nfc && ($input->nfcUid === null || NfcUid::normalize($input->nfcUid) === '')) {
            $this->log($actor, $input, ScanResult::UidMismatch, $card);
            $this->audit->log('gift_card.nfc_uid_mismatch', $actor, $card, metadata: ['uid' => null]);
            $this->hit($actor);

            throw new NfcUidMismatchException('The NFC chip serial number is missing. Tap the card again.');
        }

        if ($enforceUid && $card->nfc_uid !== null && $input->nfcUid !== null && NfcUid::normalize($input->nfcUid) !== $card->nfc_uid) {
            $this->log($actor, $input, ScanResult::UidMismatch, $card, NfcUid::normalize($input->nfcUid));
            $this->audit->log('gift_card.nfc_uid_mismatch', $actor, $card, metadata: ['uid' => NfcUid::normalize($input->nfcUid)]);
            $this->hit($actor);

            throw new NfcUidMismatchException;
        }
    }

    private function fail(Actor $actor, ScanInput $input, ScanResult $result, ?GiftCard $card = null): void
    {
        $this->hit($actor);
        $this->log($actor, $input, $result, $card);
    }

    /** Every failed or suspicious lookup counts towards the per-user and per-IP lockout. */
    private function hit(Actor $actor): void
    {
        foreach ($this->throttleKeys($actor) as $key) {
            RateLimiter::hit($key, (int) config('giftcard.security.scan_failure_decay_seconds'));
        }
    }

    private function log(Actor $actor, ScanInput $input, ScanResult $result, ?GiftCard $card = null, ?string $uid = null, ?int $counter = null): void
    {
        $uid ??= $input->nfcUid !== null ? NfcUid::normalize($input->nfcUid) : null;

        // Anything that looks like fraud goes to the application log as well, so it can be alerted on.
        if (! in_array($result, [ScanResult::Ok, ScanResult::NotFound], true)) {
            Log::warning('Suspicious gift card scan', [
                'result' => $result->value,
                'method' => $input->method->value,
                'restaurant_id' => $this->tenant->id(),
                'user_id' => $actor->userId(),
                'device_id' => $actor->deviceId(),
                'ip' => $actor->ipAddress,
                'nfc_uid' => $uid,
            ]);
        }

        NfcScan::query()->create([
            'restaurant_id' => $this->tenant->id(),
            // Never leak the id of a foreign restaurant's card into this tenant's scan log.
            'gift_card_id' => $card !== null && $card->restaurant_id === $this->tenant->id() ? $card->getKey() : null,
            'user_id' => $actor->userId(),
            'device_id' => $actor->deviceId(),
            'method' => $input->method,
            'result' => $result,
            'nfc_uid' => $uid !== null ? substr($uid, 0, 32) : null,
            'read_counter' => $counter,
            'ip_address' => $actor->ipAddress,
            'user_agent' => $actor->userAgent,
        ]);
    }

    /** @return list<string> */
    private function throttleKeys(Actor $actor): array
    {
        return array_values(array_filter([
            $actor->userId() !== null ? 'card-scan-fail:user:'.$actor->userId() : null,
            $actor->ipAddress !== null ? 'card-scan-fail:ip:'.$actor->ipAddress : null,
        ]));
    }
}
