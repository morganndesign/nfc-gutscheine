<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\NfcTagType;
use App\Enums\RoleSlug;
use App\Models\AuditLog;
use App\Models\GiftCard;
use App\Models\NfcWriteAttempt;
use App\Services\GiftCards\CardUrlBuilder;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * NFC programming v2 — the dashboard's write → verify → bind workflow (docs/NFC.md).
 */
final class NfcProgrammingTest extends TestCase
{
    private const UID = '04A23F1B6C8012';

    public function test_complete_write_verify_bind_workflow(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $manager = $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $attempt = (string) Str::uuid();
        $url = app(CardUrlBuilder::class)->url($card);

        // 1–2. Tag read (blank) → server check.
        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => $attempt, 'uid' => '04:a2:3f:1b:6c:80:12'])
            ->assertOk()
            ->assertJsonPath('data.status', 'available')
            ->assertJsonPath('data.content', 'blank')
            ->assertJsonPath('data.expected_url', $url)
            ->assertJsonPath('data.replaces_tag', false);
        $this->assertDatabaseHas('nfc_write_attempts', ['attempt_id' => $attempt, 'result' => 'in_progress', 'stage' => 'check', 'uid' => self::UID]);
        $this->assertNull($card->refresh()->nfc_uid, 'nothing is stored before verification');

        // 3–7. Written, read back, verified → bound.
        $this->postJson("/api/v1/cards/{$card->id}/nfc", [
            'method' => 'web_nfc',
            'attempt_id' => $attempt,
            'tag_type' => 'ntag216',
            'uid' => self::UID,
            'read_back' => ['uid' => '04:A2:3F:1B:6C:80:12', 'url' => $url],
        ])
            ->assertOk()
            ->assertJsonPath('data.nfc.uid', self::UID)
            ->assertJsonPath('data.nfc.tag_type', 'ntag216')
            ->assertJsonPath('data.nfc.locked', false);

        $card->refresh();
        $this->assertNotNull($card->nfc_verified_at);
        $this->assertNotNull($card->nfc_written_at);
        $this->assertDatabaseHas('nfc_write_attempts', [
            'attempt_id' => $attempt, 'result' => 'succeeded', 'stage' => 'bind', 'method' => 'web_nfc',
            'tag_type' => 'ntag216', 'read_back_url' => $url, 'user_id' => $manager->id,
        ]);
        $this->assertDatabaseHas('audit_logs', ['auditable_id' => $card->id, 'action' => 'gift_card.nfc_written']);

        // 8. Lock after verification.
        $this->postJson("/api/v1/cards/{$card->id}/nfc/lock", ['attempt_id' => $attempt])
            ->assertOk()->assertJsonPath('data.nfc.locked', true);
        $this->assertDatabaseHas('nfc_write_attempts', ['attempt_id' => $attempt, 'result' => 'succeeded', 'stage' => 'lock', 'locked' => true]);
        $this->assertDatabaseHas('audit_logs', ['auditable_id' => $card->id, 'action' => 'gift_card.nfc_locked']);

        // The waiter reads the freshly programmed card right away; a copied chip is rejected.
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);
        $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $url, 'nfc_uid' => self::UID])->assertOk()->assertJsonPath('data.id', $card->id);
        $this->postJson('/api/v1/scan', ['method' => 'nfc', 'token' => $url, 'nfc_uid' => '04999999999999'])
            ->assertForbidden()->assertJsonPath('code', 'NFC_UID_MISMATCH');
    }

    public function test_tag_linked_to_another_card_is_refused_before_writing(): void
    {
        $restaurant = $this->restaurant();
        $a = $this->issueCard($restaurant);
        $b = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->programTag($a, self::UID)->assertOk();

        $attempt = (string) Str::uuid();
        $this->postJson("/api/v1/cards/{$b->id}/nfc/check", ['attempt_id' => $attempt, 'uid' => self::UID])
            ->assertOk()
            ->assertJsonPath('data.status', 'refused')
            ->assertJsonPath('data.reason', 'TAG_LINKED_TO_OTHER_CARD')
            ->assertJsonPath('data.conflict.card_id', $a->id)
            ->assertJsonPath('data.conflict.card_number', $a->card_number);

        $this->assertDatabaseHas('nfc_write_attempts', ['attempt_id' => $attempt, 'result' => 'refused', 'error_code' => 'TAG_LINKED_TO_OTHER_CARD', 'conflict_card_id' => $a->id]);
        $this->assertDatabaseHas('audit_logs', ['auditable_id' => $b->id, 'action' => 'gift_card.nfc_write_refused']);

        // The refused attempt is closed: it can never be bound.
        $this->postJson("/api/v1/cards/{$b->id}/nfc", [
            'method' => 'web_nfc', 'attempt_id' => $attempt, 'tag_type' => 'ntag215', 'uid' => self::UID,
            'read_back' => ['uid' => self::UID, 'url' => app(CardUrlBuilder::class)->url($b)],
        ])->assertStatus(409)->assertJsonPath('code', 'NFC_ATTEMPT_INVALID');
        $this->assertNull($b->refresh()->nfc_uid);
    }

    public function test_tag_carrying_the_link_of_another_active_card_is_refused(): void
    {
        $restaurant = $this->restaurant();
        $a = $this->issueCard($restaurant);
        $b = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        // Tag written by an external app for card A (no UID known) — must not be overwritten for B.
        $this->postJson("/api/v1/cards/{$b->id}/nfc/check", [
            'attempt_id' => (string) Str::uuid(),
            'uid' => '04112233445566',
            'current_url' => app(CardUrlBuilder::class)->url($a),
        ])
            ->assertOk()
            ->assertJsonPath('data.status', 'refused')
            ->assertJsonPath('data.reason', 'TAG_CARRIES_OTHER_CARD')
            ->assertJsonPath('data.content', 'other_card')
            ->assertJsonPath('data.conflict.card_number', $a->card_number);
    }

    public function test_tag_of_another_business_is_refused_without_disclosing_the_card(): void
    {
        $other = $this->restaurant();
        $foreign = $this->issueCard($other);
        $this->actingAsStaff($other, RoleSlug::Manager);
        $this->programTag($foreign, self::UID)->assertOk();

        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => (string) Str::uuid(), 'uid' => self::UID])
            ->assertOk()
            ->assertJsonPath('data.status', 'refused')
            ->assertJsonPath('data.reason', 'TAG_OF_OTHER_BUSINESS')
            ->assertJsonPath('data.conflict', null)
            ->assertJsonMissing(['card_number' => $foreign->card_number]);
    }

    public function test_tag_of_a_replaced_card_can_be_reprogrammed(): void
    {
        $restaurant = $this->restaurant();
        $old = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->programTag($old, self::UID)->assertOk();

        $newId = $this->postJson("/api/v1/cards/{$old->id}/replace", ['reason' => 'Damaged'])->assertCreated()->json('data.id');
        $new = GiftCard::query()->findOrFail($newId);

        $this->postJson("/api/v1/cards/{$new->id}/nfc/check", [
            'attempt_id' => (string) Str::uuid(),
            'uid' => self::UID,
            'current_url' => app(CardUrlBuilder::class)->url($old),
        ])->assertOk()->assertJsonPath('data.status', 'available')->assertJsonPath('data.content', 'retired_card');

        $this->programTag($new, self::UID, currentUrl: app(CardUrlBuilder::class)->url($old))->assertOk()->assertJsonPath('data.nfc.uid', self::UID);
        $this->assertSame(self::UID, $old->refresh()->nfc_uid, 'the replaced card keeps its history');
    }

    public function test_url_mismatch_on_read_back_saves_nothing(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $attempt = (string) Str::uuid();
        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => $attempt, 'uid' => self::UID])->assertOk();

        $wrong = app(CardUrlBuilder::class)->url($card).'x';
        $this->postJson("/api/v1/cards/{$card->id}/nfc", [
            'method' => 'web_nfc', 'attempt_id' => $attempt, 'tag_type' => 'ntag215', 'uid' => self::UID,
            'read_back' => ['uid' => self::UID, 'url' => $wrong],
        ])->assertUnprocessable()->assertJsonPath('code', 'NFC_VERIFICATION_FAILED')->assertJsonPath('context.reason', 'URL_MISMATCH');

        $card->refresh();
        $this->assertNull($card->nfc_uid);
        $this->assertNull($card->nfc_written_at);
        $this->assertDatabaseHas('nfc_write_attempts', ['attempt_id' => $attempt, 'result' => 'failed', 'stage' => 'verify', 'error_code' => 'URL_MISMATCH', 'read_back_url' => $wrong]);
        $this->assertDatabaseHas('audit_logs', ['auditable_id' => $card->id, 'action' => 'gift_card.nfc_write_failed']);
    }

    public function test_a_different_tag_read_back_saves_nothing(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $attempt = (string) Str::uuid();
        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => $attempt, 'uid' => self::UID])->assertOk();

        $this->postJson("/api/v1/cards/{$card->id}/nfc", [
            'method' => 'web_nfc', 'attempt_id' => $attempt, 'tag_type' => 'ntag215', 'uid' => self::UID,
            'read_back' => ['uid' => '04000000000001', 'url' => app(CardUrlBuilder::class)->url($card)],
        ])->assertUnprocessable()->assertJsonPath('context.reason', 'TAG_SWAPPED');

        $this->assertNull($card->refresh()->nfc_uid);
        $this->assertDatabaseHas('nfc_write_attempts', ['attempt_id' => $attempt, 'result' => 'failed', 'error_code' => 'TAG_SWAPPED']);
    }

    public function test_uid_is_never_stored_without_check_and_verification(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $url = app(CardUrlBuilder::class)->url($card);

        // No prior check.
        $this->postJson("/api/v1/cards/{$card->id}/nfc", [
            'method' => 'web_nfc', 'attempt_id' => (string) Str::uuid(), 'tag_type' => 'ntag215', 'uid' => self::UID,
            'read_back' => ['uid' => self::UID, 'url' => $url],
        ])->assertStatus(409)->assertJsonPath('code', 'NFC_ATTEMPT_INVALID');

        // No read-back proof.
        $this->postJson("/api/v1/cards/{$card->id}/nfc", ['method' => 'web_nfc', 'attempt_id' => (string) Str::uuid(), 'tag_type' => 'ntag215', 'uid' => self::UID])
            ->assertUnprocessable()->assertJsonValidationErrors('read_back');

        // External writer: UID not accepted.
        $this->postJson("/api/v1/cards/{$card->id}/nfc", ['method' => 'manual', 'tag_type' => 'ntag215', 'uid' => self::UID])
            ->assertUnprocessable()->assertJsonValidationErrors('uid');

        // Web NFC is only for NTAG213/215/216; lock only after verification.
        $this->postJson("/api/v1/cards/{$card->id}/nfc", ['method' => 'web_nfc', 'attempt_id' => (string) Str::uuid(), 'tag_type' => 'ntag424_dna', 'uid' => self::UID, 'read_back' => ['uid' => self::UID, 'url' => $url], 'locked' => true])
            ->assertUnprocessable()->assertJsonValidationErrors(['tag_type', 'locked']);

        $this->assertNull($card->refresh()->nfc_uid);
    }

    public function test_the_attempt_must_belong_to_the_same_card_and_chip(): void
    {
        $restaurant = $this->restaurant();
        $a = $this->issueCard($restaurant);
        $b = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $attempt = (string) Str::uuid();
        $this->postJson("/api/v1/cards/{$a->id}/nfc/check", ['attempt_id' => $attempt, 'uid' => self::UID])->assertOk();

        $this->postJson("/api/v1/cards/{$b->id}/nfc", [
            'method' => 'web_nfc', 'attempt_id' => $attempt, 'tag_type' => 'ntag215', 'uid' => self::UID,
            'read_back' => ['uid' => self::UID, 'url' => app(CardUrlBuilder::class)->url($b)],
        ])->assertStatus(409)->assertJsonPath('code', 'NFC_ATTEMPT_INVALID');

        $this->postJson("/api/v1/cards/{$a->id}/nfc", [
            'method' => 'web_nfc', 'attempt_id' => $attempt, 'tag_type' => 'ntag215', 'uid' => '04000000000002',
            'read_back' => ['uid' => '04000000000002', 'url' => app(CardUrlBuilder::class)->url($a)],
        ])->assertStatus(409)->assertJsonPath('code', 'NFC_ATTEMPT_INVALID');
    }

    public function test_retried_bind_is_idempotent(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $attempt = (string) Str::uuid();
        $body = [
            'method' => 'web_nfc', 'attempt_id' => $attempt, 'tag_type' => 'ntag213', 'uid' => self::UID,
            'read_back' => ['uid' => self::UID, 'url' => app(CardUrlBuilder::class)->url($card)],
        ];
        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => $attempt, 'uid' => self::UID])->assertOk();

        $this->postJson("/api/v1/cards/{$card->id}/nfc", $body)->assertOk();
        $this->postJson("/api/v1/cards/{$card->id}/nfc", $body)->assertOk()->assertJsonPath('data.nfc.uid', self::UID);

        $this->assertSame(1, NfcWriteAttempt::query()->where('attempt_id', $attempt)->count());
        $this->assertSame(1, $this->auditCount('gift_card.nfc_written'));
    }

    public function test_already_programmed_tag_is_recognised_without_writing(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->programTag($card, self::UID)->assertOk();
        $attempt = (string) Str::uuid();

        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", [
            'attempt_id' => $attempt, 'uid' => self::UID, 'current_url' => app(CardUrlBuilder::class)->url($card),
        ])->assertOk()->assertJsonPath('data.status', 'already_programmed')->assertJsonPath('data.content', 'this_card');

        $this->assertDatabaseHas('nfc_write_attempts', ['attempt_id' => $attempt, 'result' => 'already_programmed', 'tag_type' => 'ntag215']);

        // The save of an earlier attempt went through but its answer was lost: the retry can still lock the tag.
        $this->postJson("/api/v1/cards/{$card->id}/nfc/lock", ['attempt_id' => $attempt])->assertOk()->assertJsonPath('data.nfc.locked', true);
    }

    public function test_programming_a_new_tag_replaces_the_old_chip(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->programTag($card, self::UID)->assertOk();

        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => (string) Str::uuid(), 'uid' => '04000000000003'])
            ->assertOk()->assertJsonPath('data.status', 'available')->assertJsonPath('data.replaces_tag', true);
        $this->programTag($card, '04000000000003')->assertOk()->assertJsonPath('data.nfc.uid', '04000000000003');

        // The old chip is free again.
        $other = $this->issueCard($restaurant);
        $this->programTag($other, self::UID)->assertOk();
    }

    public function test_database_rejects_one_chip_on_two_usable_cards(): void
    {
        $restaurant = $this->restaurant();
        $a = $this->issueCard($restaurant);
        $b = $this->issueCard($restaurant);
        GiftCard::query()->withoutGlobalScopes()->whereKey($a->id)->update(['nfc_uid' => self::UID]);

        try {
            GiftCard::query()->withoutGlobalScopes()->whereKey($b->id)->update(['nfc_uid' => self::UID]);
            $this->fail('The UNIQUE constraint on the active NFC UID did not fire.');
        } catch (UniqueConstraintViolationException) {
            $this->addToAssertionCount(1);
        }

        // Expired / replaced / deleted cards release the chip at database level.
        GiftCard::query()->withoutGlobalScopes()->whereKey($a->id)->update(['status' => 'expired']);
        GiftCard::query()->withoutGlobalScopes()->whereKey($b->id)->update(['nfc_uid' => self::UID]);
        $this->assertSame(self::UID, GiftCard::query()->withoutGlobalScopes()->findOrFail($b->id)->nfc_uid);
    }

    public function test_race_lost_at_the_database_is_reported_as_tag_in_use(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $rival = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $attempt = (string) Str::uuid();
        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => $attempt, 'uid' => self::UID])->assertOk()->assertJsonPath('data.status', 'available');

        // Another station binds the same chip between our availability check and our INSERT.
        GiftCard::saving(static function (GiftCard $saving) use ($card, $rival): void {
            if ($saving->id === $card->id && $saving->nfc_uid === self::UID) {
                GiftCard::query()->withoutGlobalScopes()->whereKey($rival->id)->update(['nfc_uid' => self::UID]);
            }
        });

        $this->postJson("/api/v1/cards/{$card->id}/nfc", [
            'method' => 'web_nfc', 'attempt_id' => $attempt, 'tag_type' => 'ntag215', 'uid' => self::UID,
            'read_back' => ['uid' => self::UID, 'url' => app(CardUrlBuilder::class)->url($card)],
        ])->assertStatus(409)->assertJsonPath('code', 'NFC_TAG_IN_USE');

        $this->assertNull(GiftCard::query()->withoutGlobalScopes()->findOrFail($card->id)->nfc_uid);
        $this->assertDatabaseHas('nfc_write_attempts', ['attempt_id' => $attempt, 'result' => 'refused', 'stage' => 'bind', 'error_code' => 'TAG_IN_USE']);
    }

    public function test_browser_side_failures_are_logged(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        // Failure before any server step (tag removed during the write).
        $attempt = (string) Str::uuid();
        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => $attempt, 'uid' => self::UID])->assertOk();
        $this->postJson("/api/v1/cards/{$card->id}/nfc/attempts", [
            'attempt_id' => $attempt, 'stage' => 'write', 'result' => 'failed', 'error_code' => 'WRITE_FAILED',
            'message' => 'The tag was removed too early.', 'tag_type' => 'ntag215',
        ])->assertCreated()->assertJsonPath('data.result', 'failed')->assertJsonPath('data.stage', 'write')->assertJsonPath('data.uid', self::UID);
        $this->assertDatabaseHas('audit_logs', ['auditable_id' => $card->id, 'action' => 'gift_card.nfc_write_failed']);

        // A closed attempt cannot be reopened.
        $this->postJson("/api/v1/cards/{$card->id}/nfc/attempts", ['attempt_id' => $attempt, 'stage' => 'verify', 'result' => 'failed', 'error_code' => 'URL_MISMATCH'])
            ->assertStatus(409);

        // Unsupported chip refused during detection, reported with a fresh attempt id.
        $this->postJson("/api/v1/cards/{$card->id}/nfc/attempts", [
            'attempt_id' => (string) Str::uuid(), 'stage' => 'detect', 'result' => 'refused', 'error_code' => 'TAG_UNSUPPORTED', 'uid' => '04998877665544',
        ])->assertCreated()->assertJsonPath('data.result', 'refused');

        // Cancel: logged in the attempts table, not in the audit trail.
        $audits = $this->auditCount();
        $this->postJson("/api/v1/cards/{$card->id}/nfc/attempts", ['attempt_id' => (string) Str::uuid(), 'stage' => 'read', 'result' => 'cancelled', 'error_code' => 'CANCELLED'])
            ->assertCreated();
        $this->assertSame($audits, $this->auditCount());

        // Lock error after a successful bind keeps the success and records the error.
        $ok = (string) Str::uuid();
        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => $ok, 'uid' => self::UID])->assertOk();
        $this->postJson("/api/v1/cards/{$card->id}/nfc", [
            'method' => 'web_nfc', 'attempt_id' => $ok, 'tag_type' => 'ntag215', 'uid' => self::UID,
            'read_back' => ['uid' => self::UID, 'url' => app(CardUrlBuilder::class)->url($card)],
        ])->assertOk();
        $this->postJson("/api/v1/cards/{$card->id}/nfc/attempts", ['attempt_id' => $ok, 'stage' => 'lock', 'result' => 'failed', 'error_code' => 'LOCK_FAILED'])
            ->assertCreated()->assertJsonPath('data.result', 'succeeded')->assertJsonPath('data.error_code', 'LOCK_FAILED');
        $this->assertFalse($card->refresh()->nfc_locked);

        $this->getJson("/api/v1/cards/{$card->id}/nfc/attempts")
            ->assertOk()->assertJsonCount(4, 'data')->assertJsonPath('data.0.attempt_id', $ok);

        $this->postJson("/api/v1/cards/{$card->id}/nfc/attempts", ['attempt_id' => (string) Str::uuid(), 'stage' => 'write', 'result' => 'succeeded', 'error_code' => 'x'])
            ->assertUnprocessable()->assertJsonValidationErrors(['result', 'error_code']);
    }

    public function test_lock_requires_a_successful_verified_attempt(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $attempt = (string) Str::uuid();
        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => $attempt, 'uid' => self::UID])->assertOk();

        $this->postJson("/api/v1/cards/{$card->id}/nfc/lock", ['attempt_id' => $attempt])->assertStatus(409)->assertJsonPath('code', 'NFC_ATTEMPT_INVALID');
        $this->assertFalse($card->refresh()->nfc_locked);
    }

    public function test_closed_card_is_refused(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->postJson("/api/v1/cards/{$card->id}/expire", ['reason' => 'test'])->assertOk();

        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => (string) Str::uuid(), 'uid' => self::UID])
            ->assertOk()->assertJsonPath('data.status', 'refused')->assertJsonPath('data.reason', 'CARD_CLOSED');
    }

    public function test_external_writes_are_recorded_unverified_without_uid(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->postJson("/api/v1/cards/{$card->id}/nfc", ['method' => 'manual', 'tag_type' => 'ntag215'])
            ->assertOk()->assertJsonPath('data.nfc.uid', null)->assertJsonPath('data.nfc.verified_at', null)->assertJsonPath('data.nfc.tag_type', 'ntag215');
        $this->assertNotNull($card->refresh()->nfc_written_at);
        $this->assertDatabaseHas('nfc_write_attempts', ['gift_card_id' => $card->id, 'method' => 'manual', 'result' => 'succeeded', 'uid' => null]);

        $this->postJson("/api/v1/cards/{$card->id}/nfc", ['method' => 'printed', 'tag_type' => 'ntag215'])
            ->assertUnprocessable()->assertJsonValidationErrors('tag_type');
        $this->postJson("/api/v1/cards/{$card->id}/nfc", ['method' => 'printed', 'tag_type' => 'qr_only'])->assertOk();
    }

    public function test_only_card_programmers_can_use_the_workflow(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Waiter);

        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => (string) Str::uuid(), 'uid' => self::UID])->assertForbidden();
        $this->postJson("/api/v1/cards/{$card->id}/nfc/attempts", ['attempt_id' => (string) Str::uuid(), 'stage' => 'read', 'result' => 'failed', 'error_code' => 'X'])->assertForbidden();
        $this->getJson("/api/v1/cards/{$card->id}/nfc/attempts")->assertForbidden();
        $this->postJson("/api/v1/cards/{$card->id}/nfc/lock", ['attempt_id' => (string) Str::uuid()])->assertForbidden();
    }

    public function test_cards_of_another_restaurant_cannot_be_programmed(): void
    {
        $other = $this->restaurant();
        $foreign = $this->issueCard($other);
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        $this->postJson("/api/v1/cards/{$foreign->id}/nfc/check", ['attempt_id' => (string) Str::uuid(), 'uid' => self::UID])->assertNotFound();
    }

    public function test_programming_queue_lists_cards_without_a_tag_in_card_number_order(): void
    {
        $restaurant = $this->restaurant();
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $cards = collect(range(1, 5))->map(fn () => $this->issueCard($restaurant))->sortBy('card_number')->values();
        $this->programTag($cards[1], self::UID)->assertOk();
        $this->postJson("/api/v1/cards/{$cards[2]->id}/nfc", ['method' => 'manual', 'tag_type' => 'ntag213'])->assertOk();
        $qr = $this->issueCard($restaurant, 5000, null, ['tag_type' => NfcTagType::QrOnly]);
        $this->postJson("/api/v1/cards/{$cards[4]->id}/expire", ['reason' => 'test'])->assertOk();

        $ids = $this->getJson('/api/v1/cards?nfc_status=unprogrammed&sort=card_number')->assertOk()->json('data.*.id');
        $this->assertSame([$cards[0]->id, $cards[3]->id], $ids);
        $this->assertNotContains($qr->id, $ids);

        $this->assertSame([$cards[3]->id], $this->getJson('/api/v1/cards?nfc_status=unprogrammed&sort=card_number&card_number_after='.$cards[0]->card_number)->json('data.*.id'));
        $this->assertSame([$cards[2]->id], $this->getJson('/api/v1/cards?nfc_status=unverified')->json('data.*.id'));
        $this->assertSame([$cards[1]->id], $this->getJson('/api/v1/cards?nfc_status=verified')->json('data.*.id'));
    }

    public function test_station_refuses_a_card_programmed_on_another_device(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $url = app(CardUrlBuilder::class)->url($card);

        // Phone A and phone B both passed the check for the same card with different tags.
        $a = (string) Str::uuid();
        $b = (string) Str::uuid();
        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => $a, 'uid' => '04000000000A01', 'only_if_unprogrammed' => true])->assertJsonPath('data.status', 'available');
        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => $b, 'uid' => '04000000000B01', 'only_if_unprogrammed' => true])->assertJsonPath('data.status', 'available');

        $bind = fn (string $attempt, string $uid) => $this->postJson("/api/v1/cards/{$card->id}/nfc", [
            'method' => 'web_nfc', 'attempt_id' => $attempt, 'tag_type' => 'ntag215', 'uid' => $uid,
            'read_back' => ['uid' => $uid, 'url' => $url], 'only_if_unprogrammed' => true,
        ]);
        $bind($a, '04000000000A01')->assertOk();
        $bind($b, '04000000000B01')->assertStatus(409)->assertJsonPath('code', 'NFC_CARD_ALREADY_PROGRAMMED');

        $this->assertSame('04000000000A01', $card->refresh()->nfc_uid, 'the first chip stays');
        $this->assertDatabaseHas('nfc_write_attempts', ['attempt_id' => $b, 'result' => 'refused', 'error_code' => 'CARD_ALREADY_PROGRAMMED']);

        // A later station check for that card is refused up front; the single-card dialog may still re-program it.
        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => (string) Str::uuid(), 'uid' => '04000000000B01', 'only_if_unprogrammed' => true])
            ->assertJsonPath('data.status', 'refused')->assertJsonPath('data.reason', 'CARD_ALREADY_PROGRAMMED');
        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => (string) Str::uuid(), 'uid' => '04000000000B01'])
            ->assertJsonPath('data.status', 'available')->assertJsonPath('data.replaces_tag', true);
    }

    public function test_a_stale_copy_of_another_cards_link_can_be_reused(): void
    {
        $restaurant = $this->restaurant();
        $a = $this->issueCard($restaurant);
        $b = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $this->programTag($a, self::UID)->assertOk();
        $linkOfA = app(CardUrlBuilder::class)->url($a);

        // Another chip carries A's link, but A's verified chip is a different one → only a copy → reusable.
        $this->postJson("/api/v1/cards/{$b->id}/nfc/check", ['attempt_id' => (string) Str::uuid(), 'uid' => '04000000000C01', 'current_url' => $linkOfA])
            ->assertOk()->assertJsonPath('data.status', 'available')->assertJsonPath('data.content', 'stale_copy');
        $this->programTag($b, '04000000000C01', currentUrl: $linkOfA)->assertOk();

        // A's link on a chip while A has no verified chip (written with another app) stays protected.
        $c = $this->issueCard($restaurant);
        $d = $this->issueCard($restaurant);
        $this->postJson("/api/v1/cards/{$c->id}/nfc", ['method' => 'manual', 'tag_type' => 'ntag215'])->assertOk();
        $this->postJson("/api/v1/cards/{$d->id}/nfc/check", ['attempt_id' => (string) Str::uuid(), 'uid' => '04000000000D01', 'current_url' => app(CardUrlBuilder::class)->url($c)])
            ->assertJsonPath('data.status', 'refused')->assertJsonPath('data.reason', 'TAG_CARRIES_OTHER_CARD');
    }

    public function test_timings_are_stored_with_the_attempt(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $attempt = (string) Str::uuid();
        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => $attempt, 'uid' => self::UID])->assertOk();

        $this->postJson("/api/v1/cards/{$card->id}/nfc", [
            'method' => 'web_nfc', 'attempt_id' => $attempt, 'tag_type' => 'ntag215', 'uid' => self::UID,
            'read_back' => ['uid' => self::UID, 'url' => app(CardUrlBuilder::class)->url($card)],
            'timings' => ['detect_ms' => 180, 'write_ms' => 95, 'verify_ms' => 140, 'total_ms' => 1320],
        ])->assertOk();

        $this->getJson("/api/v1/cards/{$card->id}/nfc/attempts")
            ->assertJsonPath('data.0.timings', ['detect_ms' => 180, 'write_ms' => 95, 'verify_ms' => 140, 'total_ms' => 1320]);
    }

    public function test_unfinished_attempts_are_closed_by_the_next_attempt(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);
        $old = (string) Str::uuid();
        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => $old, 'uid' => self::UID])->assertOk();

        // Within a minute the old attempt stays open (the same login may be busy on a second phone).
        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => (string) Str::uuid(), 'uid' => self::UID])->assertOk();
        $this->assertDatabaseHas('nfc_write_attempts', ['attempt_id' => $old, 'result' => 'in_progress']);

        $this->travel(2)->minutes();
        $this->programTag($card, self::UID)->assertOk();

        $this->assertDatabaseHas('nfc_write_attempts', ['attempt_id' => $old, 'result' => 'cancelled', 'error_code' => 'SUPERSEDED']);
    }

    public function test_programming_requests_are_rate_limited(): void
    {
        $restaurant = $this->restaurant();
        $card = $this->issueCard($restaurant);
        $this->actingAsStaff($restaurant, RoleSlug::Manager);

        foreach (range(1, 180) as $i) {
            $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => (string) Str::uuid(), 'uid' => sprintf('04%012X', $i)])->assertOk();
        }
        $this->postJson("/api/v1/cards/{$card->id}/nfc/check", ['attempt_id' => (string) Str::uuid(), 'uid' => '04FFFFFFFFFFFF'])->assertStatus(429);
    }

    private function auditCount(?string $action = null): int
    {
        return AuditLog::query()->withoutGlobalScopes()->when($action, static fn ($q) => $q->where('action', $action))->count();
    }
}
