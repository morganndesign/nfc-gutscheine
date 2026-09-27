<?php

declare(strict_types=1);

namespace App\Services\GiftCards;

use App\Enums\NfcTagType;
use App\Enums\NfcWriteMethod;
use App\Enums\NfcWriteResult;
use App\Enums\NfcWriteStage;
use App\Exceptions\Domain\DomainException;
use App\Exceptions\Domain\NfcAttemptInvalidException;
use App\Exceptions\Domain\NfcCardAlreadyProgrammedException;
use App\Exceptions\Domain\NfcTagInUseException;
use App\Exceptions\Domain\NfcVerificationFailedException;
use App\Models\GiftCard;
use App\Models\NfcWriteAttempt;
use App\Services\Audit\AuditLogger;
use App\Support\Actor;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

/**
 * The server side of the dashboard's card-programming workflow (Web NFC):
 *
 *   read tag → {@see check()} (is the chip / the link on it free?) → detect type → write NDEF URL →
 *   read back → {@see bindVerified()} (URL and chip must match exactly; only now the UID is stored) →
 *   optional lock → {@see confirmLock()}
 *
 * Every attempt is one `nfc_write_attempts` row, keyed by a client-generated `attempt_id`; failures
 * the server cannot see (tag removed, write error, verification mismatch) are reported through
 * {@see reportFailure()}.
 */
final class NfcProgrammingService
{
    public const REASON_CARD_CLOSED = 'CARD_CLOSED';

    public const REASON_TAG_LINKED = 'TAG_LINKED_TO_OTHER_CARD';

    public const REASON_TAG_CARRIES_OTHER_CARD = 'TAG_CARRIES_OTHER_CARD';

    public const REASON_OTHER_RESTAURANT = 'TAG_OF_OTHER_BUSINESS';

    public const REASON_CARD_PROGRAMMED = 'CARD_ALREADY_PROGRAMMED';

    public const CONTENT_BLANK = 'blank';

    public const CONTENT_THIS_CARD = 'this_card';

    public const CONTENT_OTHER_CARD = 'other_card';

    public const CONTENT_RETIRED_CARD = 'retired_card';

    public const CONTENT_FOREIGN = 'foreign';

    /** The link of another card whose verified chip is a different one: a stale copy (e.g. a tag whose save failed). */
    public const CONTENT_STALE_COPY = 'stale_copy';

    public function __construct(
        private readonly GiftCardService $cards,
        private readonly CardUrlBuilder $urls,
        private readonly AuditLogger $audit,
    ) {}

    /**
     * Step 2: decides whether the tag that was just read may be programmed for `$card`.
     *
     * @return array{
     *     status: 'available'|'already_programmed'|'refused',
     *     reason: string|null,
     *     message: string|null,
     *     conflict: array{card_id: string, card_number: string}|null,
     *     content: string,
     *     replaces_tag: bool,
     *     locked: bool,
     *     expected_url: string,
     *     attempt_id: string
     * }
     */
    public function check(Actor $actor, GiftCard $card, string $attemptId, string $uid, ?string $currentUrl, bool $onlyIfUnprogrammed = false): array
    {
        $uid = NfcUid::normalize($uid);
        $currentUrl = $currentUrl !== null && trim($currentUrl) !== '' ? trim($currentUrl) : null;
        $expected = $this->urls->url($card);

        $attempt = $this->open($actor, $card, $attemptId, NfcWriteMethod::WebNfc);
        $this->supersede($actor, $card, $attemptId);
        $attempt->forceFill([
            'stage' => NfcWriteStage::Check,
            'uid' => $uid,
            'previous_url' => $currentUrl !== null ? Str::limit($currentUrl, 500, '') : null,
        ]);

        [$content, $linkedCard] = $this->classifyContent($card, $currentUrl, $uid);

        $refusal = null;
        $conflict = null;
        if ($card->status->isTerminal()) {
            $refusal = [self::REASON_CARD_CLOSED, 'This card is closed. Tags can only be programmed for usable cards.'];
        } elseif (($owner = $this->chipOwner($card, $uid)) !== null) {
            $conflict = $owner;
            $refusal = $owner->restaurant_id === $card->restaurant_id
                ? [self::REASON_TAG_LINKED, 'This tag is already linked to card '.$owner->card_number.'. Use a blank tag.']
                : [self::REASON_OTHER_RESTAURANT, 'This tag belongs to another business. Use a blank tag.'];
        } elseif ($content === self::CONTENT_OTHER_CARD && $linkedCard !== null) {
            $conflict = $linkedCard;
            $refusal = $linkedCard->restaurant_id === $card->restaurant_id
                ? [self::REASON_TAG_CARRIES_OTHER_CARD, 'This tag carries the link of card '.$linkedCard->card_number.'. Use a blank tag.']
                : [self::REASON_OTHER_RESTAURANT, 'This tag belongs to another business. Use a blank tag.'];
        }

        $sameTag = $card->nfc_uid === $uid;
        $alreadyProgrammed = $refusal === null && $sameTag && $content === self::CONTENT_THIS_CARD
            && $currentUrl === $expected && $card->nfc_verified_at !== null;

        if ($refusal === null && ! $alreadyProgrammed && $onlyIfUnprogrammed && $card->nfc_written_at !== null) {
            $refusal = [self::REASON_CARD_PROGRAMMED, 'This card already has a tag (programmed on another device). Continue with the next card.'];
        }

        if ($refusal !== null) {
            $attempt->forceFill([
                'result' => NfcWriteResult::Refused,
                'error_code' => $refusal[0],
                'error_message' => $refusal[1],
                'conflict_card_id' => $conflict?->id,
                'completed_at' => Carbon::now(),
            ])->save();

            $this->audit->log('gift_card.nfc_write_refused', $actor, $card, metadata: [
                'attempt_id' => $attempt->attempt_id,
                'uid' => $uid,
                'reason' => $refusal[0],
            ]);
        } elseif ($alreadyProgrammed) {
            $attempt->forceFill([
                'result' => NfcWriteResult::AlreadyProgrammed,
                'tag_type' => $card->nfc_tag_type,
                'locked' => $card->nfc_locked,
                'completed_at' => Carbon::now(),
            ])->save();
        } else {
            $attempt->save();
        }

        $sameRestaurant = $conflict !== null && $conflict->restaurant_id === $card->restaurant_id;

        return [
            'status' => $refusal !== null ? 'refused' : ($alreadyProgrammed ? 'already_programmed' : 'available'),
            'reason' => $refusal[0] ?? null,
            'message' => $refusal[1] ?? null,
            'conflict' => $sameRestaurant ? ['card_id' => $conflict->id, 'card_number' => $conflict->card_number] : null,
            'content' => $content,
            'replaces_tag' => $refusal === null && $card->nfc_uid !== null && ! $sameTag,
            'locked' => $card->nfc_locked,
            'expected_url' => $expected,
            'attempt_id' => $attempt->attempt_id,
        ];
    }

    /**
     * Step 7: stores the chip only after the tag was read back with exactly the expected URL.
     *
     * @param  array<string, mixed>  $timings  detect_ms, write_ms, verify_ms, total_ms measured by the dashboard
     */
    public function bindVerified(
        Actor $actor,
        GiftCard $card,
        string $attemptId,
        NfcTagType $tagType,
        string $uid,
        string $readBackUid,
        string $readBackUrl,
        array $timings = [],
        bool $onlyIfUnprogrammed = false,
    ): GiftCard {
        $uid = NfcUid::normalize($uid);
        $attempt = $this->existing($card, $attemptId);

        // Retried request (e.g. the response was lost on a flaky connection): idempotent.
        if ($attempt->result === NfcWriteResult::Succeeded && $attempt->uid === $uid) {
            return $card->refresh();
        }
        if ($attempt->result !== NfcWriteResult::InProgress || $attempt->uid !== $uid) {
            throw new NfcAttemptInvalidException;
        }

        $attempt->forceFill([
            'tag_type' => $tagType,
            'read_back_url' => Str::limit($readBackUrl, 500, ''),
            ...$this->timings($timings),
        ]);

        if (NfcUid::normalize($readBackUid) !== $uid) {
            $this->fail($actor, $card, $attempt, NfcWriteStage::Verify, NfcWriteResult::Failed, 'TAG_SWAPPED', 'A different tag was read back than the one that was checked.');

            throw new NfcVerificationFailedException('A different tag was read back. Hold the same tag still until the end.', ['reason' => 'TAG_SWAPPED']);
        }
        if ($readBackUrl !== $this->urls->url($card)) {
            $this->fail($actor, $card, $attempt, NfcWriteStage::Verify, NfcWriteResult::Failed, 'URL_MISMATCH', 'The link read back from the tag does not match the card.');

            throw new NfcVerificationFailedException('The link on the tag does not match this card. Nothing was saved.', ['reason' => 'URL_MISMATCH']);
        }

        try {
            $bound = $this->cards->bindNfcTag($actor, $card, $tagType, $uid, locked: false, verified: true, onlyIfUnprogrammed: $onlyIfUnprogrammed);
        } catch (NfcTagInUseException $e) {
            $this->fail($actor, $card, $attempt, NfcWriteStage::Bind, NfcWriteResult::Refused, 'TAG_IN_USE', $e->getMessage());

            throw $e;
        } catch (NfcCardAlreadyProgrammedException $e) {
            $this->fail($actor, $card, $attempt, NfcWriteStage::Bind, NfcWriteResult::Refused, self::REASON_CARD_PROGRAMMED, $e->getMessage());

            throw $e;
        } catch (DomainException $e) {
            $this->fail($actor, $card, $attempt, NfcWriteStage::Bind, NfcWriteResult::Failed, $e->errorCode(), $e->getMessage());

            throw $e;
        }

        $attempt->forceFill([
            'stage' => NfcWriteStage::Bind,
            'result' => NfcWriteResult::Succeeded,
            'error_code' => null,
            'error_message' => null,
            'completed_at' => Carbon::now(),
        ])->save();

        return $bound;
    }

    /**
     * Records a tag written outside Web NFC (external app, NTAG 424 provisioning tool, printed QR).
     * Never stores a UID: it cannot be verified.
     */
    public function bindUnverified(Actor $actor, GiftCard $card, ?string $attemptId, NfcWriteMethod $method, NfcTagType $tagType, bool $locked): GiftCard
    {
        $attempt = $this->open($actor, $card, $attemptId ?? (string) Str::uuid(), $method);
        $attempt->forceFill(['stage' => NfcWriteStage::Bind, 'tag_type' => $tagType, 'locked' => $locked]);

        try {
            $bound = $this->cards->bindNfcTag($actor, $card, $tagType, null, $locked);
        } catch (DomainException $e) {
            $this->fail($actor, $card, $attempt, NfcWriteStage::Bind, NfcWriteResult::Failed, $e->errorCode(), $e->getMessage());

            throw $e;
        }

        $attempt->forceFill(['result' => NfcWriteResult::Succeeded, 'completed_at' => Carbon::now()])->save();

        return $bound;
    }

    /**
     * Step 8 (optional): the dashboard made the verified tag read-only.
     */
    public function confirmLock(Actor $actor, GiftCard $card, string $attemptId): GiftCard
    {
        $attempt = $this->existing($card, $attemptId);
        // Also after "already programmed": a tag saved earlier (e.g. the answer was lost) is locked on the retry.
        $done = $attempt->result === NfcWriteResult::Succeeded || $attempt->result === NfcWriteResult::AlreadyProgrammed;
        if (! $done || $attempt->method !== NfcWriteMethod::WebNfc || $attempt->uid === null) {
            throw new NfcAttemptInvalidException;
        }

        $locked = $this->cards->markNfcLocked($actor, $card, $attempt->uid);
        $attempt->forceFill(['stage' => NfcWriteStage::Lock, 'locked' => true])->save();

        return $locked;
    }

    /**
     * Failures only the browser sees: no tag / unreadable tag, unsupported chip, write error, verification
     * mismatch, lock error or cancellation.
     *
     * @param  array{stage: string, result: string, error_code: string, message?: string|null, uid?: string|null, tag_type?: string|null, previous_url?: string|null, read_back_url?: string|null, timings?: array<string, mixed>}  $report
     */
    public function reportFailure(Actor $actor, GiftCard $card, string $attemptId, array $report): NfcWriteAttempt
    {
        $stage = NfcWriteStage::from($report['stage']);
        $result = NfcWriteResult::from($report['result']);

        $attempt = NfcWriteAttempt::query()->withoutGlobalScopes()->where('attempt_id', $attemptId)->first();
        if ($attempt !== null && $attempt->gift_card_id !== $card->id) {
            throw new NfcAttemptInvalidException;
        }

        // A lock error after a successful bind: the tag is programmed and verified but stays writable.
        $done = $attempt !== null && in_array($attempt->result, [NfcWriteResult::Succeeded, NfcWriteResult::AlreadyProgrammed], true);
        if ($attempt !== null && $done && $stage === NfcWriteStage::Lock) {
            $attempt->forceFill(['error_code' => $report['error_code'], 'error_message' => $this->message($report)])->save();
            $this->audit->log('gift_card.nfc_lock_failed', $actor, $card, metadata: ['attempt_id' => $attemptId, 'error_code' => $report['error_code']]);

            return $attempt;
        }
        if ($attempt !== null && $attempt->result->isFinal()) {
            throw new NfcAttemptInvalidException;
        }

        $attempt ??= $this->open($actor, $card, $attemptId, NfcWriteMethod::WebNfc);
        $attempt->forceFill(array_filter([
            'uid' => isset($report['uid']) ? NfcUid::normalize($report['uid']) : null,
            'tag_type' => isset($report['tag_type']) ? NfcTagType::tryFrom($report['tag_type']) : null,
            'previous_url' => isset($report['previous_url']) ? Str::limit($report['previous_url'], 500, '') : null,
            'read_back_url' => isset($report['read_back_url']) ? Str::limit($report['read_back_url'], 500, '') : null,
            ...$this->timings($report['timings'] ?? []),
        ], static fn ($v): bool => $v !== null && $v !== ''));

        $this->fail($actor, $card, $attempt, $stage, $result, $report['error_code'], $this->message($report));

        return $attempt;
    }

    /**
     * @param  array<string, mixed>  $timings
     * @return array<string, int>
     */
    private function timings(array $timings): array
    {
        $out = [];
        foreach (['detect_ms', 'write_ms', 'verify_ms', 'total_ms'] as $key) {
            if (isset($timings[$key]) && is_numeric($timings[$key])) {
                $out[$key] = max(0, min((int) $timings[$key], 3_600_000));
            }
        }

        return $out;
    }

    /**
     * A new attempt for a card closes the same user's older attempts for it on the same device that never
     * finished (browser closed, connection lost), so the log has no stale "in progress" rows. Attempts younger
     * than a minute stay open: the same login may be programming on a second phone right now.
     */
    private function supersede(Actor $actor, GiftCard $card, string $attemptId): void
    {
        NfcWriteAttempt::query()
            ->where('gift_card_id', $card->id)
            ->where('user_id', $actor->userId())
            ->when($actor->deviceId(), static fn ($q, $device) => $q->where('device_id', $device), static fn ($q) => $q->whereNull('device_id'))
            ->where('created_at', '<', Carbon::now()->subMinute())
            ->where('result', NfcWriteResult::InProgress->value)
            ->where('attempt_id', '!=', $attemptId)
            ->update([
                'result' => NfcWriteResult::Cancelled->value,
                'error_code' => 'SUPERSEDED',
                'error_message' => 'Not finished; replaced by a newer attempt.',
                'completed_at' => Carbon::now(),
                'updated_at' => Carbon::now(),
            ]);
    }

    /** @param array{message?: string|null} $report */
    private function message(array $report): ?string
    {
        return isset($report['message']) ? Str::limit($report['message'], 250) : null;
    }

    private function fail(Actor $actor, GiftCard $card, NfcWriteAttempt $attempt, NfcWriteStage $stage, NfcWriteResult $result, string $code, ?string $message): void
    {
        $attempt->forceFill([
            'stage' => $stage,
            'result' => $result,
            'error_code' => $code,
            'error_message' => $message,
            'completed_at' => Carbon::now(),
        ])->save();

        if ($result !== NfcWriteResult::Cancelled) {
            $this->audit->log($result === NfcWriteResult::Refused ? 'gift_card.nfc_write_refused' : 'gift_card.nfc_write_failed', $actor, $card, metadata: [
                'attempt_id' => $attempt->attempt_id,
                'stage' => $stage->value,
                'error_code' => $code,
                'uid' => $attempt->uid,
            ]);
        }
    }

    private function open(Actor $actor, GiftCard $card, string $attemptId, NfcWriteMethod $method): NfcWriteAttempt
    {
        $existing = NfcWriteAttempt::query()->withoutGlobalScopes()->where('attempt_id', $attemptId)->first();
        if ($existing !== null) {
            if ($existing->gift_card_id !== $card->id || $existing->result->isFinal()) {
                throw new NfcAttemptInvalidException;
            }

            return $existing;
        }

        $attempt = new NfcWriteAttempt;
        $attempt->forceFill([
            'restaurant_id' => $card->restaurant_id,
            'gift_card_id' => $card->id,
            'user_id' => $actor->userId(),
            'device_id' => $actor->deviceId(),
            'attempt_id' => $attemptId,
            'method' => $method,
            'stage' => NfcWriteStage::Read,
            'result' => NfcWriteResult::InProgress,
            'user_agent' => $actor->userAgent !== null ? Str::limit($actor->userAgent, 250, '') : null,
        ]);

        return $attempt;
    }

    private function existing(GiftCard $card, string $attemptId): NfcWriteAttempt
    {
        $attempt = NfcWriteAttempt::query()->withoutGlobalScopes()->where('attempt_id', $attemptId)->first();
        if ($attempt === null || $attempt->gift_card_id !== $card->id) {
            throw new NfcAttemptInvalidException('Check the tag before saving it.');
        }

        return $attempt;
    }

    private function chipOwner(GiftCard $card, string $uid): ?GiftCard
    {
        /** @var GiftCard|null */
        return GiftCard::query()->withoutGlobalScopes()
            ->where('nfc_uid_active', $uid)
            ->whereKeyNot($card->getKey())
            ->first(['id', 'restaurant_id', 'card_number', 'status']);
    }

    /**
     * @return array{0: string, 1: GiftCard|null}
     */
    private function classifyContent(GiftCard $card, ?string $url, string $uid): array
    {
        if ($url === null) {
            return [self::CONTENT_BLANK, null];
        }

        $token = $this->urls->extractToken($url);
        if ($token === null) {
            return [self::CONTENT_FOREIGN, null];
        }
        if ($token === $card->public_token) {
            return [self::CONTENT_THIS_CARD, null];
        }

        /** @var GiftCard|null $linked */
        $linked = GiftCard::query()->withoutGlobalScopes()->whereNull('deleted_at')
            ->where('public_token', $token)
            ->first(['id', 'restaurant_id', 'card_number', 'status', 'nfc_uid', 'nfc_verified_at']);

        if ($linked === null) {
            return [self::CONTENT_FOREIGN, null];
        }
        // The other card's real tag is a different, verified chip: this one is only a copy of its link
        // (e.g. written by a station whose save failed). Overwriting it cannot harm that card.
        if (! $linked->status->isTerminal() && $linked->nfc_verified_at !== null && $linked->nfc_uid !== null && $linked->nfc_uid !== $uid) {
            return [self::CONTENT_STALE_COPY, $linked];
        }

        return [$linked->status->isTerminal() ? self::CONTENT_RETIRED_CARD : self::CONTENT_OTHER_CARD, $linked];
    }
}
