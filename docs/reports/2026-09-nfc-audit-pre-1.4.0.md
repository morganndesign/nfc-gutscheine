# NFC Audit — GiftCard Pro

Audit only. No code was changed. Every statement below comes from reading the current source tree (`/home/claude/giftcard-pro`).

---

## Part A — The 15 questions

### 1. Can a blank NTAG213 / NTAG215 / NTAG216 tag be written?

**Yes, but only in one place and on one platform:** the web dashboard, opened in **Chrome on Android**, by a user with the `cards.write_nfc` permission (manager or owner). It uses the browser's Web NFC API (`NDEFReader`).

In every other environment the system does **not** write the tag. This covers desktop browsers, Safari/Chrome on iPhone, Firefox and the native waiter app. The dashboard instead shows the card URL and asks the user to write it with an external app (for example NFC Tools), then click "Mark as written".

### 2. Where is it implemented? The complete workflow

**Dashboard (Next.js)**

| File | What it does |
|---|---|
| `frontend/src/lib/nfc.ts` | Web NFC wrapper. `isWebNfcSupported()` (l.46), `readTagOnce()` (l.65), `writeCardTag(url, {lock, signal})` (l.101–127), `friendlyNfcError()`, `TAG_TYPES` (l.137) |
| `frontend/src/components/cards/nfc-writer.tsx` | `NfcWriter` component: tag-type select, "Lock tag after writing" switch, and the phases idle → waiting → saving → done. The Web NFC path, the NTAG 424 template path, the QR-only path and the manual/unsupported-browser path |
| `frontend/src/app/(app)/cards/new/page.tsx` l.169 | After a card is created: `<NfcWriter cardId={created.card.id} payload={created.nfc} />` |
| `frontend/src/app/(app)/cards/[id]/page.tsx` l.107, 222, 325 | Card detail: "Write NFC tag" in the ⋯ menu (and via `?write`), dialog `nfc`. Gated by `can("cards.write_nfc")`. Shows tag type, UID and locked state |
| `frontend/src/lib/api/hooks.ts` | `useNfcPayload` → `GET /cards/{id}/nfc`; `useBindNfc` → `POST /cards/{id}/nfc` |
| `frontend/src/hooks/use-capabilities.ts` | `can()` permission helper |

**Backend (Laravel)**

| File | What it does |
|---|---|
| `backend/routes/api.php` l.88–91 | `GET cards/{card}/nfc`, `POST cards/{card}/nfc`, `GET cards/{card}/qr`. All three use `can:cards.write_nfc` |
| `backend/app/Http/Controllers/Api/V1/GiftCardActionController.php` | `nfcPayload()` returns `CardUrlBuilder::payloadFor()` + `lock_after_write`. `bindNfc()`. `qr()` returns an SVG |
| `backend/app/Http/Requests/Cards/BindNfcTagRequest.php` | `tag_type` required enum; `uid` nullable, max 40, `NfcUid::isValid`; `locked` boolean |
| `backend/app/Services/GiftCards/GiftCardService.php` l.583–624 | `bindNfcTag()`: normalises the UID, rejects terminal cards, checks for a UID conflict, stores the fields, resets the replay counter, and writes the audit log `gift_card.nfc_written` |
| `backend/app/Services/GiftCards/CardUrlBuilder.php` | `url()`, `secureTemplate()` (NTAG 424), `payloadFor()`, `extractToken()` |
| `backend/app/Services/GiftCards/NfcUid.php` | `normalize()` (upper hex, no separators), `isValid()` (7 or 10 bytes; plus 4 bytes) |
| `backend/app/Enums/NfcTagType.php` | `ntag213`, `ntag215`, `ntag216`, `ntag424_dna`, `qr_only` |
| `backend/app/Enums/RoleSlug.php` l.63 | `Permission::CardsWriteNfc` granted to manager/owner. Not granted to waiter |
| `backend/app/Http/Resources/GiftCardResource.php` | `nfc: {tag_type, uid, written_at, locked}` |

**Database**

| Migration | Columns |
|---|---|
| `backend/database/migrations/2026_01_01_000004_create_gift_card_tables.php` l.39–50 | `gift_cards.nfc_tag_type` string(20), `nfc_uid` string(32), `nfc_written_at`, `nfc_locked`, `nfc_read_counter`. Index `(restaurant_id, nfc_uid)`, which is **not unique**. `public_token` uuid unique |
| same file l.80–88 | `nfc_scans` (scan log incl. `nfc_uid`) |
| `backend/database/migrations/2026_01_01_000001_create_platform_tables.php` l.51–52 | `restaurant_settings.enforce_nfc_uid_binding` (default true), `lock_nfc_tags_after_write` (default false) |

**Flutter:** no write code (see Q9–Q11).

**Complete workflow (Android Chrome, NTAG213/215/216)**

1. The manager creates a card (`POST /cards`). The response contains `nfc: {url, tag_type_hint, ndef_template}`. `NfcWriter` opens on the "card created" screen. Alternatively, the manager opens an existing card, chooses ⋯ → "Write NFC tag", and the page calls `GET /cards/{id}/nfc`.
2. The manager chooses the tag type (default `ntag215`) and whether to lock. The switch is pre-set from `lock_after_write`.
3. "Write NFC tag" calls `writeCardTag(url)`, which does the following:
   1. `reader.scan()`. The phone waits for a tag, and the first `reading` event provides `serialNumber` (the UID).
   2. `reader.write({records:[{recordType:"url", data:url}]}, {overwrite:true})`. This writes to the next tag in the field.
   3. If lock is on: `reader.makeReadOnly()`.
4. `finish(serialNumber, locked)` calls `POST /cards/{id}/nfc {tag_type, uid, locked}`.
5. The backend validates, checks for a conflict, and saves `nfc_uid`, `nfc_tag_type`, `nfc_written_at` and `nfc_locked`. It writes the audit log `gift_card.nfc_written` with the old and new values.
6. The dialog shows "done". The card page shows the tag type, UID and locked state.

**Manual workflow (desktop / iPhone)**

1. Copy the URL.
2. Write it with an external app.
3. Optionally type the UID.
4. "Mark as written" → `POST /cards/{id}/nfc`. If no UID is typed, `uid` = null.

### 3. Is an NDEF record written?

**Yes.** On the Web NFC path, exactly one NDEF well-known URI record is written (`recordType: "url"`), in `frontend/src/lib/nfc.ts` l.116. The browser/OS formats a factory-blank NTAG21x as NDEF automatically. On the manual path, the external app writes the record; the system does not.

### 4. What exactly is written?

`{CARD_BASE_URL}/c/{public_token}`, for example `https://app.giftcardpro.at/c/3f6c…-uuid-v4`.

- `public_token` is a random UUID v4 (`gift_cards.public_token`, unique). It is not encrypted and not signed.
- There is no balance, card number, customer data or restaurant ID on the tag.
- For NTAG 424 DNA the dashboard only **displays** the template `…/c/{token}?picc=000…(32)&cmac=000…(16)` (`CardUrlBuilder::secureTemplate()`). The system does not write it. It must be provisioned externally (NXP TagWriter) with SDM settings.

### 5. Is the tag verified by reading it back?

**No.** After `write()`, `writeCardTag` does not read the tag again, and it does not compare the written URL with the expected URL. It also does not verify that the tag that was written is the tag whose `serialNumber` was scanned in step 3.1. Scan and write are two separate operations; if the user swaps tags in between, the wrong UID is bound. The backend receives only the UID the browser reported and has no proof the write succeeded.

### 6. Can the same tag be assigned to two cards?

**Partially prevented, not guaranteed.**

- **Prevented:** `GiftCardService::bindNfcTag` l.592–603 rejects a UID already bound to another card of the same restaurant, unless that card is `replaced` or `expired`. The error is 'This NFC tag is already linked to another active card.' with the other `card_number`. This is tested in `backend/tests/Feature/CardScanTest.php::test_one_tag_cannot_be_bound_to_two_active_cards`.

**Gaps:**

- **No database guarantee.** Index `(restaurant_id, nfc_uid)` is not unique. The check runs under a row lock on the *target* card only, so two simultaneous binds of one UID to two different cards can both pass.
- **The tag is overwritten before the check.** The browser writes the new URL (`overwrite: true`) and *then* calls the API. If the API rejects the UID, the physical tag already carries the new card's URL, and the old card's tag is destroyed. There is no pre-write ownership check.
- **The manual path without a UID** (desktop/iPhone) binds nothing. No duplicate check is possible.
- **Cards that are `replaced` or `expired` release their UID** (intentional reuse). This is not configurable.

### 7. Is the UID stored?

**Yes**, when it is known. It is stored in `gift_cards.nfc_uid`, normalised to upper-case hex without separators (`NfcUid::normalize`). It is validated as 4, 7 or 10 bytes and logged in the audit log (`gift_card.nfc_written`, old/new). Each scan stores it in `nfc_scans.nfc_uid`.

It is **not** stored when:

- the manual path is used without typing it;
- the tag type is QR-only;
- the tag is an NTAG 424 before the first tap. It is bound on the first verified SUN tap (`CardScanService` l.136).

### 8. Can a tag be rewritten?

**Yes, if it was not locked.**

- "Write NFC tag" can be run again on the same card or on another card. `overwrite: true` means no warning about existing content.
- Re-binding the same card to a different chip resets `nfc_read_counter`. Re-binding the same NTAG 424 keeps it (`HardeningTest::test_rebinding_the_same_secure_chip_keeps_the_replay_counter`).
- If "Lock tag after writing" was on, `makeReadOnly()` sets the tag permanently read-only and it can never be rewritten.
- There is no password protection (NTAG21x PWD/PACK), no unlock, and no "unbind tag" endpoint (there is no `DELETE /cards/{id}/nfc`).

### 9. Does it work on Android?

- **Writing:** only in **Chrome for Android** (version 89+), through the dashboard. Samsung Internet, Firefox, WebView and the native Flutter app cannot write.
- **Reading:** the native waiter app reads (`waiter-app/android/app/src/main/kotlin/eu/tapredeem/waiter/WaiterNfc.kt`, reader mode). The web waiter terminal (`frontend/src/components/waiter/terminal.tsx`) also reads through Web NFC in Chrome.

### 10. Does it work on iPhone?

- **Writing: no.** iOS has no Web NFC. The Flutter iOS code (`waiter-app/ios/Runner/WaiterNfc.swift`) only calls `readNDEF`, and it has never been compiled in this environment (no Xcode). On an iPhone the only option is the manual path: an external app writes the tag, the manager optionally types the UID, then clicks "Mark as written".
- **Reading:** designed to work. iOS background tag reading opens the URL, and the waiter app's `NFCTagReaderSession` sheet reads it. **Unverified** on a device.

### 11. Can the waiter app read the written cards immediately?

**Yes, by design and in tests; unverified on a real device.**

- The written tag contains a plain NDEF URL. The waiter app reads it right away:
  - **Android:** `WaiterNfc.kt` reads `Ndef.cachedNdefMessage` → `firstUri`, plus the tag UID.
  - **iOS:** reads through `readNDEF` + UID.
- The app then sends `POST /scan {method: nfc, url, nfc_uid}`.
- The backend (`CardScanService::verifyChip` l.150) compares the UID with the bound `nfc_uid` when `enforce_nfc_uid_binding` is on.
- **Covered by:**
  - `backend/tests/Feature/CardScanTest.php::test_waiter_scans_nfc_url_and_sees_minimal_card_view`;
  - `test_cloned_ntag21x_is_detected_by_uid_binding`;
  - the Flutter journey tests with fake NFC.
- **Not covered:** a real physical tag written by the dashboard and read by the app. This has never been executed.

**Caveat:** the URL host must be listed in the app's `CARD_DOMAINS`. The APK built earlier uses the placeholder `app.example.at`, so it would **reject** tags written by a real deployment until it is rebuilt with the real domain.

### 12. Dashboard only, or also mobile?

**Dashboard only.** "Mobile" here means the dashboard opened in Chrome on an Android phone. The native Flutter app has no write function, and its device token cannot call `/cards/{id}/nfc`:

- `EnforceDeviceToken` limits it to `scan`, `redeem`, `auth/me`, `logout` and `devices/current`;
- the waiter role lacks `cards.write_nfc`.

The locked waiter-app spec (`docs/design/waiter-app`) defines no write screen.

### 13. Production-ready parts

| Part | Evidence |
|---|---|
| Card URL generation (`CardUrlBuilder`, `public_token`) | `GiftCardLifecycleTest::test_manager_creates_a_card_with_ledger_entry_and_nfc_payload` |
| `GET/POST /cards/{id}/nfc`: validation, permission, tenant scope, terminal-card guard, audit log | `CardScanTest`, `HardeningTest::test_invalid_chip_serial_numbers_are_rejected` |
| UID normalisation/validation (`NfcUid`) | `HardeningTest` |
| UID clone detection on scan for NTAG21x | `CardScanTest::test_cloned_ntag21x_is_detected_by_uid_binding` |
| NTAG 424 SUN verification (AES-CMAC, replay counter, UID mismatch) | `tests/Unit/Ntag424SunVerifierTest.php`, `AesCmacTest.php`, `CardScanTest::test_ntag424_sun_messages_are_verified_and_replays_rejected` |
| Reading tags in the waiter app and the web terminal | Flutter tests (fake NFC), backend scan tests |

### 14. Placeholder or unfinished parts

| Part | State |
|---|---|
| `writeCardTag` in `frontend/src/lib/nfc.ts` | Works, but has no read-back verification, no scanned-tag = written-tag guarantee and no check of existing content before `overwrite: true`. **No automated test.** |
| `NfcWriter` manual path (desktop/iPhone) | "Mark as written" is a trust-based checkbox: the system records a tag as written without any proof, and usually without a UID |
| NTAG 424 DNA | Only a template and "Mark as provisioned". SDM configuration, key diversification and the first-tap binding depend on an external tool and a manual process (`docs/NFC.md`) |
| UID uniqueness | App-level check only. No unique DB constraint, and race-prone |
| `iOS WaiterNfc.swift` | Read-only, never compiled |
| E2E | `e2e/pilot-journey.mjs` l.100 clicks "Mark as written" only. No write is exercised |

### 15. Completely missing

1. Read-back verification after writing.
2. A pre-write check: reading the existing NDEF content, detecting that the tag belongs to another card, and warning before overwriting.
3. A server-side pre-check endpoint ("is this UID free?") called **before** the physical write.
4. A database-level unique constraint on `(restaurant_id, nfc_uid)` for active cards.
5. Capacity/type detection (the chosen `tag_type` is never compared with the real chip; NTAG213 vs 215 vs 216 is whatever the user selects).
6. Logging of write attempts and failures (only successful binds are audited).
7. An unbind/"remove tag" endpoint and UI.
8. Native NFC writing on Android (Flutter/Kotlin).
9. Native NFC writing on iPhone (Flutter/Swift, `NFCNDEFReaderSession.write` / `NFCTagReaderSession`).
10. Automated NTAG 424 DNA provisioning (ChangeFileSettings/SDM, ChangeKey, key diversification).
11. Password protection for NTAG21x (PWD/PACK) as an alternative to permanent locking.
12. Frontend unit tests for `lib/nfc.ts` and `nfc-writer.tsx`, plus an E2E test of the Web NFC write path.
13. Batch writing (many cards in a row). Not in the spec; listed only as absent.

---

## Conclusion

**⚠ NFC Writing is partially implemented.**

The backend binding and verification are production-ready and tested. The actual writing works only in Chrome on Android through the dashboard, without read-back verification, without pre-write ownership protection and without automated tests. iPhone and the native app cannot write at all.

---

## Part B — Implementation plan for everything missing

No code has been written. Items marked **[DECISION]** extend beyond the locked specs (`docs/design/waiter-app`, the commercial docs) and need your approval before implementation, because the build rule was "no new features". Everything else closes gaps in the existing, specified dashboard write feature.

### B1. Database changes

| # | File (new) | Change |
|---|---|---|
| D1 | `backend/database/migrations/2026_10_01_000001_add_nfc_uid_unique_index.php` | Add `gift_cards.nfc_uid_active` (string 32, nullable), which holds `nfc_uid` while the card status is not `replaced`/`expired` and null otherwise. Add a unique index `(restaurant_id, nfc_uid_active)`. Works on PostgreSQL and MySQL; the alternative, a partial index, is PostgreSQL-only. Backfill: fail the migration with a listing if duplicates exist. |
| D2 | same migration | `gift_cards.nfc_verified_at` timestamp nullable: set only when read-back verification succeeded |
| D3 | `backend/database/migrations/2026_10_01_000002_create_nfc_write_attempts_table.php` | New table `nfc_write_attempts`: `id`, `restaurant_id` FK, `gift_card_id` FK, `user_id` FK, `uid` string(32) null, `tag_type` string(20), `result` enum(`bound`, `verified`, `verify_failed`, `conflict`, `write_failed`, `cancelled`), `error_code` string(64) null, `client` enum(`web_nfc`, `manual`, `android_app`, `ios_app`), `user_agent` string(255) null, `created_at`. Index `(restaurant_id, created_at)`, `(gift_card_id)` |
| D4 | `backend/app/Models/NfcWriteAttempt.php` | Model with `BelongsToRestaurant` tenant scope, casts |
| D5 | `backend/database/factories/NfcWriteAttemptFactory.php` | Factory for tests |
| D6 | `backend/app/Services/GiftCards/GiftCardService.php` (status transitions to `replaced`/`expired`) | Keep `nfc_uid_active` in sync: null it on replace/expire, and set it in `bindNfcTag` |

### B2. Backend APIs

| # | Endpoint | Files | Behaviour |
|---|---|---|---|
| A1 | `POST /cards/{card}/nfc/check` | `backend/routes/api.php` (next to l.88); `GiftCardActionController::checkNfc()`; `backend/app/Http/Requests/Cards/CheckNfcTagRequest.php` (`uid` required + `NfcUid::isValid`, `current_url` nullable string max 2048) | Before the physical write. Returns `{available: bool, conflict: {card_id, card_number, status}\|null, current_card: {card_number}\|null}`. `current_card` is resolved from `current_url` through `CardUrlBuilder::extractToken()` (tenant-scoped), so the UI can warn "This tag currently belongs to card GC-…". Permission `cards.write_nfc`. Rate-limited like the other card actions |
| A2 | `POST /cards/{card}/nfc` (existing) | `BindNfcTagRequest`: add `verified` (boolean), `client` (enum), `read_back_url` (nullable string). `GiftCardService::bindNfcTag()`: new parameter `?bool $verified` | Rejects `verified=true` when `read_back_url` ≠ `CardUrlBuilder::url($card)` (422 `NFC_VERIFY_MISMATCH`). Sets `nfc_verified_at` when verified. Writes an `nfc_write_attempts` row. Catches the unique-index violation (D1) and turns it into the existing conflict exception (race-safe). Audit `gift_card.nfc_written` gets a `verified` flag |
| A3 | `POST /cards/{card}/nfc/attempts` | `GiftCardActionController::logNfcAttempt()`; `backend/app/Http/Requests/Cards/LogNfcAttemptRequest.php` | Records failed/cancelled writes (`write_failed`, `verify_failed`, `cancelled`, `conflict`) with `error_code`. Audit action `gift_card.nfc_write_failed` |
| A4 | `DELETE /cards/{card}/nfc` | `GiftCardActionController::unbindNfc()`; `GiftCardService::unbindNfcTag()` | Clears `nfc_uid`, `nfc_uid_active`, `nfc_tag_type`, `nfc_written_at`, `nfc_verified_at`, `nfc_locked` and `nfc_read_counter`. Audit `gift_card.nfc_unbound`. Permission `cards.write_nfc`. Rejected for terminal cards |
| A5 | `GiftCardResource` | `backend/app/Http/Resources/GiftCardResource.php` | Add `nfc.verified_at` |
| A6 | Audit labels | `backend/app/Enums/AuditAction.php` (or wherever audit action labels live), `frontend/src/lib/audit-labels.ts` | `gift_card.nfc_write_failed`, `gift_card.nfc_unbound` |
| A7 | **[DECISION]** Device-token access for native writing | `backend/app/Http/Middleware/EnforceDeviceToken.php`, `backend/app/Enums/RoleSlug.php` | Only if B4 is approved: allow `GET/POST /cards/{card}/nfc*` for device tokens whose user has `cards.write_nfc`, plus `GET /cards?search=` to pick the card |
| A8 | **[DECISION]** NTAG 424 provisioning data | `GET /cards/{card}/nfc/provisioning` → `{url_template, picc_offset, cmac_offset, sdm_file_settings, diversified_keys}` from `Ntag424SunVerifier` key material (`GenerateNfcKeys`) | Needed only for automated 424 provisioning (B4.6). Keys may be sent only to native clients over TLS and must never be logged |

### B3. Dashboard (Next.js)

| # | File | Change |
|---|---|---|
| F1 | `frontend/src/lib/nfc.ts` | `writeCardTag()` becomes a single-session flow: 1) `scan()` → first `reading` event: capture `serialNumber` **and the existing NDEF records**; 2) callback `onTagDetected({serialNumber, currentUrl})` which awaits A1 and may abort; 3) `write(…, {overwrite:true})`; 4) read-back: continue listening on the same reader, require a `reading` event with the **same** `serialNumber` whose URL record equals the expected URL, with a timeout (e.g. 5 s, "Hold the tag still"); 5) `makeReadOnly()` only **after** a successful verification; 6) return `{serialNumber, locked, verified, readBackUrl}`. New error codes: `VERIFY_MISMATCH`, `VERIFY_TIMEOUT`, `TAG_SWAPPED`, `TAG_CONFLICT`, `TAG_TOO_SMALL` (NDEF message size vs `NDEFReadingEvent` capacity where exposed) |
| F2 | `frontend/src/lib/nfc.ts` | `friendlyNfcError()`: messages for the new codes in all dashboard languages |
| F3 | `frontend/src/components/cards/nfc-writer.tsx` | New phases `checking` (A1 call), `confirm-overwrite` (tag belongs to card GC-…: Cancel / Overwrite), `verifying`, `verify-failed` (retry); sends `verified`, `client`, `read_back_url` to A2; reports failures to A3; the manual path sends `client: manual`, `verified: false` and shows "Not verified" |
| F4 | `frontend/src/app/(app)/cards/[id]/page.tsx` | Show "Verified on …" / "Not verified" badge from `nfc.verified_at`; ⋯ menu "Remove tag" (A4) with a confirmation dialog, gated by `can("cards.write_nfc")` |
| F5 | `frontend/src/lib/api/hooks.ts` | `useCheckNfc` (A1), `useLogNfcAttempt` (A3), `useUnbindNfc` (A4); update `useBindNfc` payload type |
| F6 | `frontend/src/lib/api/types.ts` | `GiftCard.nfc.verified_at`, request/response types for A1–A4 |
| F7 | `frontend/messages/*.json` (the dashboard translation files) | Strings for F1–F4 |

### B4. Flutter / native — all **[DECISION]**

The locked waiter-app spec states the app is "scan an NFC gift card, redeem its balance. Nothing else", and defines screens S01–S17 only. Native writing requires a spec amendment first:

- `docs/design/waiter-app/…`: a new screen spec, strings in spec 12, states in spec 02/09;
- `waiter-app/README.md`.

Option 1: keep writing in the dashboard only, and implement B1–B3 + B5 (recommended minimum). Option 2: add a manager-only write mode as specified below.

| # | File | Change |
|---|---|---|
| N1 | `waiter-app/lib/core/platform/nfc_service.dart` | `Future<NfcWriteResult> writeUrl(String url, {required bool lock, required Duration timeout})` returning `{uid, previousUrl, verified, locked}`; error enum `NfcWriteError {cancelled, notNdef, readOnly, tooSmall, verifyMismatch, tagLost, unsupported}` |
| N2 | `waiter-app/android/app/src/main/kotlin/eu/tapredeem/waiter/WaiterNfc.kt` | Method channel `writeUrl`: reader mode; `Ndef.get(tag)` or `NdefFormatable.get(tag).format()` for blank tags; check `maxSize` against the message; `writeNdefMessage`; read-back through `getNdefMessage()` on the same connection and compare; optional `makeReadOnly()`; return the UID hex |
| N3 | `waiter-app/ios/Runner/WaiterNfc.swift` | `NFCTagReaderSession` (`.iso14443`): `queryNDEFStatus` → `writeNDEF` → `readNDEF` compare → optional `writeLock`; UID from `NFCMiFareTag.identifier`; alert messages. Needs the entitlement `com.apple.developer.nfc.readersession.formats` = `TAG` (already present for reading; verify) and a real Xcode build |
| N4 | `waiter-app/lib/core/api/endpoints/cards_api.dart` (new) | `searchCards`, `nfcPayload`, `checkNfc`, `bindNfc`, `logNfcAttempt` against A1–A3/A7 |
| N5 | `waiter-app/lib/core/state/nfc_write_controller.dart` (new) | States idle → selectCard → holdTag → checking → confirmOverwrite → writing → verifying → done/failed |
| N6 | `waiter-app/lib/screens/s18_write_tag/…` (new: `s18_card_picker_screen.dart`, `s18_write_tag_screen.dart`) | Card search list; "Hold the tag to the phone" screen reusing the S05 scan visuals; the result screens |
| N7 | `waiter-app/lib/app/root_router.dart` | Entry point visible only when `auth/me` returns `cards.write_nfc` |
| N8 | `waiter-app/lib/l10n/*.arb` via `tool/import_strings.dart` | Strings (after spec 12 is amended) |

### B5. Tests

**Backend (PHPUnit)**

| File | Tests |
|---|---|
| `backend/tests/Feature/NfcWritingTest.php` (new) | `test_check_reports_free_uid`; `test_check_reports_conflicting_active_card`; `test_check_resolves_current_card_from_existing_tag_url`; `test_check_requires_write_nfc_permission` (waiter → 403); `test_check_is_tenant_scoped`; `test_bind_with_matching_read_back_sets_verified_at`; `test_bind_with_mismatching_read_back_is_rejected`; `test_manual_bind_is_stored_unverified`; `test_concurrent_binds_of_same_uid_one_fails` (unique index, two transactions); `test_uid_released_when_card_replaced_or_expired`; `test_failed_attempt_is_logged_and_audited`; `test_unbind_clears_all_nfc_fields_and_audits`; `test_unbind_rejected_for_closed_card`; `test_rebound_card_resets_counter_for_new_chip` |
| `backend/tests/Unit/NfcUidTest.php` (new) | normalisation (colons, lower case, spaces); valid 4, 7, 10-byte UIDs; invalid lengths/characters |
| `backend/tests/Feature/MigrationBackfillTest.php` (new, or in the existing migration test) | D1 backfill fills `nfc_uid_active`; duplicate detection aborts |
| `backend/tests/Feature/WaiterAppDeviceTokenTest.php` (only with A7) | device token may call `/cards/{id}/nfc*` only with `cards.write_nfc` |

**Dashboard (Vitest)** — `frontend/src/lib/nfc.test.ts` (new), with a fake `NDEFReader`:

- successful write + verification;
- read-back URL mismatch → `VERIFY_MISMATCH`;
- a different serial on read-back → `TAG_SWAPPED`;
- timeout → `VERIFY_TIMEOUT`;
- lock only after verification;
- no lock when verification fails;
- abort signal;
- `friendlyNfcError` mapping;
- `isWebNfcSupported` true/false.

`frontend/src/components/cards/nfc-writer.test.tsx` (new), with Testing Library and MSW:

- unsupported browser shows the manual path;
- conflict → confirm-overwrite dialog;
- cancel does not write;
- verified bind payload;
- failure calls A3;
- the NTAG 424 and QR paths are unchanged.

**E2E (Playwright)**

- `e2e/nfc-writing.mjs` (new): inject a fake `window.NDEFReader` with `page.addInitScript`. It covers:
  - write → verify → bind shows the "Verified" badge;
  - conflict warning when the fake tag carries another card's URL;
  - remove tag.
- `e2e/pilot-journey.mjs` l.100: keep the manual step, and assert the "Not verified" badge.

**Flutter (only with B4)**

- `waiter-app/test/core/platform/nfc_service_write_test.dart`: channel contract.
- `waiter-app/test/core/state/nfc_write_controller_test.dart`: every state transition and error.
- `waiter-app/test/screens/s18_write_tag_screen_test.dart`.
- `waiter-app/test/journeys/write_tag_journey_test.dart`: fake NFC + scripted backend.
- `waiter-app/test/support/fake_nfc.dart`: add a write simulation.

**Manual hardware test protocol (cannot run in CI)** — `docs/NFC.md`, new section "Release test". Test on Pixel and Samsung (Chrome) and on iPhone 12+ (read, plus write if B4 is approved), with:

- blank NTAG213/215/216;
- a pre-written tag belonging to another card;
- a locked tag;
- a tag that is too small;
- tag removal mid-write;
- a read in the waiter app immediately after writing, with the APK rebuilt with the real `CARD_DOMAINS`.

### B6. Documentation to update together with the code

- `docs/NFC.md`: the verification flow, pre-write check, unbind, uniqueness guarantee, release test protocol.
- `docs/API.md`: A1–A4 (A7/A8 if approved).
- `docs/DATABASE.md` (or the schema section): D1–D3.
- `docs/PERMISSIONS.md` (or its equivalent): the unchanged `cards.write_nfc` plus the device-token rule if A7 is approved.
- `frontend` user guide / help texts for the "Verified" badge and "Remove tag".
- `docs/design/waiter-app/*` and `waiter-app/README.md`: only if B4 is approved.

### B7. Order of work (proposed)

1. D1–D6 + A2 race-safety + `NfcWritingTest` (data integrity first).
2. A1, A3, A4, A5, A6 + backend tests.
3. F1–F7 + Vitest + Playwright.
4. Docs B6.
5. Hardware test on real tags.
6. **Only after your decision:** A7/A8 + B4 (native writing), and automated NTAG 424 provisioning.
