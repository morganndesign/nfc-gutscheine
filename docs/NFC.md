# NFC guide

## What is written to a card

Exactly one NDEF **URI record**:

```
https://app.example.com/c/3f2b6c1e-8d4a-4f7b-9a2c-1e5d7f9b3a6c
```

The token is a random UUID v4. No balance, no customer data, no card number. If a card is lost the token
is retired by *Replace lost card*; the new card gets a new token.

The same URL is printed as a QR code on the back of the card, so every card works with **any phone**.

| Who scans | What happens |
|---|---|
| Waiter, Android + Chrome, in the waiter app | Web NFC reads URL + chip serial number → `POST /scan` → card opens |
| Waiter, iPhone | iOS reads NDEF URLs natively (hold card near the top of the phone) → notification → opens `/c/{token}` → logged-in staff land directly in the terminal with the card open |
| Any staff, camera | QR → same URL; the waiter app also has a built-in QR scanner (BarcodeDetector) |
| Guest | Opens the public balance page (can be disabled per restaurant) |
| No phone at hand | Manual card number entry (Luhn-checked) |

## Supported tags

| Tag | User memory | Recommended use | Clone protection |
|---|---|---|---|
| **NTAG213** | 144 bytes | Standard PVC cards, stickers | UID binding |
| **NTAG215** | 504 bytes | Default | UID binding |
| NTAG216 | 888 bytes | Works, not required | UID binding |
| **NTAG 424 DNA** | 416 bytes | Premium / high-value cards | Cryptographic (AES-128 SUN), replay-proof |
| QR only | — | Paper vouchers | None beyond token secrecy |

The URL needs ~75 bytes, so every NTAG21x variant fits comfortably.

## Programming NTAG213/215/216 tags

Tags are programmed from the dashboard in **Chrome on Android** (Web NFC). Two entry points use the same workflow:

- **One card:** open the card → *⋯ → Write NFC tag* (also shown right after *Create card*).
- **Many cards:** *Gift cards → Program NFC tags* (`/cards/program`) — a programming station that works through every
  usable card without a tag in card-number order (optionally starting at a card number). The operator holds one blank
  tag per card to the phone; after a verified card the next one comes up automatically, with a sound and vibration.
  The screen stays on (Wake Lock). Each tag is labelled with the card number shown on screen. *Skip card*, *Try again*
  and *Stop* are always available; the session log lists every card with result, chip type and UID.

### The workflow (`dashboard/src/lib/nfc-programming.ts`)

| # | Step | Where | Failure → |
|---|---|---|---|
| 1 | **Read the tag**: chip UID and current content | Web NFC `scan()` (one reader for the whole session) | `READ_FAILED`, `PERMISSION_DENIED`, `NFC_DISABLED` |
| 2 | **Check the server** | `POST /cards/{id}/nfc/check` | — |
| 3 | **Refuse** if the chip is linked to another usable card (this or another restaurant) or the tag carries the link of another usable card. Nothing is written. | server | `TAG_LINKED_TO_OTHER_CARD`, `TAG_CARRIES_OTHER_CARD`, `TAG_OF_OTHER_BUSINESS`, `CARD_CLOSED` |
| 4a | **Detect the chip type** by memory size (below) | Web NFC `write()` | `TAG_UNSUPPORTED` (e.g. NTAG 424 DNA / Type 4), `TAG_TOO_SMALL` |
| 4b | **Write** one NDEF URI record with the card URL, replacing the whole message | Web NFC `write()` | `WRITE_FAILED`, `TIMEOUT` |
| 5 | **Read the tag again** — a fresh read of the tag still on the phone; if the first read-back is stale the operator is asked to lift and re-tap once | Web NFC `scan()` | `TIMEOUT` |
| 6 | **Verify**: same chip UID, URL *exactly* the card URL | browser **and** server | `TAG_SWAPPED`, `URL_MISMATCH` (`NFC_VERIFICATION_FAILED`) |
| 7 | **Save the UID** — only now: `nfc_uid`, `nfc_tag_type`, `nfc_verified_at` | `POST /cards/{id}/nfc` (`method: web_nfc`, `read_back`) | `NFC_TAG_IN_USE` (race, caught by the unique index) |
| 8 | **Lock** (optional, *Lock tag after writing* / restaurant setting): `makeReadOnly()`, then `POST /cards/{id}/nfc/lock` | Web NFC + server | `LOCK_FAILED` — the tag stays verified and writable; the card shows it unlocked |

If a tag already carries this card's link and its chip is the verified chip of this card, step 2 answers
`already_programmed` and nothing is written (e.g. re-tapping a locked tag). Programming a *new* tag for a card that
already has one replaces the old chip (the dialog warns); the old tag is rejected as a clone from then on.

**Nothing is saved to the card unless steps 1–6 succeeded.** A UID is never accepted without the read-back proof: the
API rejects `uid` for every other method.

### Chip type detection

Web NFC does not expose the chip model, so the memory is measured with probe messages (MIME type
`application/vnd.giftcardpro.probe`) that are overwritten by the URL right after:

| Probe message | Fits | Result |
|---|---|---|
| 600 bytes | NTAG216 (888 B) | **NTAG216** |
| 300 bytes | NTAG215 (504 B) | **NTAG215** |
| 200 bytes | 256-byte NDEF file (NTAG 424 DNA, other Type 4 tags) but not NTAG213 | **refused** — not an NTAG21x |
| none of them | NTAG213 (144 B) | **NTAG213** (the URL, ~75 bytes, must still fit) |

A failed probe is retried once so a brief loss of contact is not mistaken for a smaller chip. Chips larger than an
NTAG216 are recorded as NTAG216. The probes run only after the server check allowed the tag.

### Attempt log

Every attempt has one client-generated `attempt_id` and one row in `nfc_write_attempts` — successes, refusals
(server check or unsupported chip), failures (write, verification, lock, network) and cancellations. The server writes
the row for the steps it sees (check, bind, lock); failures only the browser sees are reported to
`POST /cards/{id}/nfc/attempts`. Refusals and failures are also in the audit log (`gift_card.nfc_write_refused`,
`gift_card.nfc_write_failed`, `gift_card.nfc_lock_failed`); success is `gift_card.nfc_written` (with `verified: true`)
and `gift_card.nfc_locked`. The card page shows the list under **Tag programming**.

### Errors the operator sees

Every failure shows a title, what to do, and that nothing was saved; **Try again** starts a new attempt in the same
NFC session (no reload), **Skip card** moves on. Codes and texts: `ERROR_TEXTS` in `dashboard/src/lib/nfc-programming.ts`.

| Title | Codes | Cause |
|---|---|---|
| Tag removed too early | `TAG_LOST`, `TAG_REMOVED`, `TIMEOUT` | Tag moved away while reading / writing / reading back (a write that fails right after successful probe writes is treated as removal) |
| Wrong tag type | `TAG_UNSUPPORTED`, `TAG_TOO_SMALL`, `READ_FAILED` | NTAG 424 DNA, other Type 4 or non-NDEF tags, link does not fit |
| Tag is locked | `TAG_READ_ONLY` | No write accepted at all (not even 40 bytes) — detected before the card link is written |
| Tag belongs to another active card / business | `TAG_LINKED_TO_OTHER_CARD`, `TAG_CARRIES_OTHER_CARD`, `TAG_OF_OTHER_BUSINESS`, `NFC_TAG_IN_USE` | Server check or unique index |
| Write failed | `WRITE_FAILED` | Other write errors |
| Verification failed | `URL_MISMATCH`, `TAG_SWAPPED`, `NFC_VERIFICATION_FAILED` | Read-back differs |
| Server unavailable | `SERVER_UNAVAILABLE` | No connection, or 5xx |
| Network timeout | `NETWORK_TIMEOUT` | A programming request got no answer within 15 s. A save that did reach the server is recognised on the retry (*already programmed*) and still locked if requested — never saved twice |
| Card already programmed | `CARD_ALREADY_PROGRAMMED`, `NFC_CARD_ALREADY_PROGRAMMED` | Station only: another phone programmed the card; the station moves on by itself |

### Station figures

Progress (`126 / 300 cards programmed`: cards without a tag in the chosen range at the start), successful cards,
failed attempts, skipped cards, elapsed time, average time per card including handling, and the average tag → saved,
write and read-back times. The session log can be downloaded as CSV. Each attempt stores `detect_ms`, `write_ms`,
`verify_ms` and `total_ms` (tag read → chip saved) in `nfc_write_attempts`.

### Reusing a tag whose save failed

A tag that carries the link of another card whose **verified** chip is a different one is only a copy of that link
(`content: stale_copy`) and may be programmed again — e.g. after a station lost a race for a card. A tag carrying the
link of a card *without* a verified chip stays protected (it may be that card's only tag).

### Uniqueness

`gift_cards.nfc_uid_active` is a generated column (`nfc_uid` while the card is not deleted, `replaced` or `expired`)
with a **unique index**: one chip belongs to at most one usable card on the whole platform, also when two stations
program the same chip at the same moment. Replaced and expired cards keep `nfc_uid` for history and release the chip,
so the tag of a replaced card can be re-programmed for its replacement.

### In GiftCard Waiter (Android, managers and owners)

Since 1.4.3 managers and owners can sell and program a card in the app: S05 → **New gift card** → amount (and
optional guest e-mail) → **Create card** → hold a blank tag to the phone. The app runs the same steps as the dashboard
against the same endpoints (`POST /cards`, `…/nfc/check`, `…/nfc`, `…/nfc/lock`, `…/nfc/attempts`) and records the
verified write with `method: web_nfc` (written and read back by a client; the device is in the audit log). Two
differences: the chip type is read with the NTAG21x GET_VERSION command instead of probe writes, and the read-back
comes straight from the chip (no browser cache, so no second re-tap is needed). Waiters' sign-ins cannot create or
program cards (403), and the app does not show the action to them.

### Without Chrome on Android

Desktop browsers and iPhones cannot write tags from a web page. The dialog shows the URL for an external writer app
(e.g. *NFC Tools*) and *Mark as written* (`method: manual`). Such cards are shown as **not verified** and **no UID is
stored**, so clone detection does not apply to them — program them on an Android phone to verify.

### How UID binding stops clones

NTAG21x UIDs are burned in at the factory. When a waiter taps a card, Web NFC reports the chip's serial number;
if the card is bound to a different UID the scan is refused (`NFC_UID_MISMATCH`), logged in `nfc_scans` and the
audit log. A copied URL on another chip therefore fails. Limitations: "magic" UID-changeable clones exist, and
iOS/QR/manual lookups do not transmit a UID — for high-value cards use NTAG 424 DNA.

## NTAG 424 DNA (Secure Unique NFC)

With SUN/SDM enabled, the chip rewrites part of its URL on **every tap**:

```
https://app.example.com/c/{token}?picc=EF963FF7828658A599F3041510671E88&cmac=94EED9EE65337086
```

- `picc` = AES-128-CBC( K_SDMMetaRead, PICCDataTag ‖ UID ‖ SDMReadCtr ‖ padding )
- `cmac` = MACt( CMAC( K_SesSDMFileReadMAC, ε ) ), where the session key is `CMAC(K_SDMFileRead, 3CC3 0001 0080 ‖ UID ‖ SDMReadCtr)`

The server (`App\Services\Nfc\Ntag424SunVerifier`) decrypts `picc`, recomputes the MAC, and requires the
counter to be **strictly greater** than the last accepted value (atomic compare-and-set on
`gift_cards.nfc_read_counter`). A sniffed or copied URL is therefore useless after one use, and a clone cannot
produce valid MACs without the key. The implementation is verified against the official NXP AN12196 vectors
(`tests/Unit/Ntag424SunVerifierTest`).

### Keys

```bash
php artisan giftcard:nfc-keys
# NTAG424_META_READ_KEY=…   (shared, decrypts PICC data)
# NTAG424_FILE_READ_KEY=…   (master for MAC keys)
# NTAG424_DIVERSIFY_KEYS=true
```

With diversification the per-chip MAC key is `HMAC-SHA256(FILE_READ_KEY, UID)[0..16]` — program each chip with
its own derived key, so extracting one chip's key compromises only that chip.

### Provisioning a 424 DNA card

1. Create the card with card type *NTAG 424 DNA* (or change it in *Write NFC tag*).
2. Copy the **NDEF template** from the dialog.
3. With NXP *TagWriter* (Android) or a desktop provisioning tool (e.g. `ntag424` libraries with an ACR122U):
   - write the template URL,
   - enable SDM with **encrypted PICC data** (UID + read counter mirroring) at the `picc=` offset, **SDM MAC** at the
     `cmac=` offset with `SDMMACInputOffset = SDMMACOffset` (empty MAC input),
   - set the SDM Meta Read key to `NTAG424_META_READ_KEY` and the SDM File Read key to the (diversified) MAC key,
   - change the default application keys (never leave factory keys).
4. Click *Mark as provisioned*. The UID is bound automatically on the first verified tap.

In the waiter app, Android taps and iPhone taps (which open the URL including `picc`/`cmac`) are both verified: the
server checks the SUN message for `method: nfc` **and** `method: link`, so a copied or replayed link of a secure card is
refused. The printed QR code (`method: qr`) and the card number (`manual`) of a 424 card are accepted without a chip
check, as for every card.

## Operational tips

- Buy tags with a pre-printed QR area or print the back with the built-in **print layout** (ID-1, 85.6 × 54 mm).
- Lock NTAG21x tags after writing in production (prevents vandals from rewriting them). Locking happens only after verification.
- For batches, use *Program NFC tags*; label each tag with the card number on screen before taking the next one.
- Real-tag release test (not possible in CI): [NFC-RELEASE-TEST.md](NFC-RELEASE-TEST.md) — 14 cases on a Pixel and a Samsung phone, measurements and a report template.
- Several phones programming at once: give each phone its own *Start at card number*. If two phones still reach the same card, the second one is refused (`CARD_ALREADY_PROGRAMMED`), moves on by itself, and its tag can be used for the next card.
- Train staff: hold the card flat against the upper back of the phone for ~1 s.
- Android: NFC must be enabled in system settings and Chrome must be allowed NFC for the site (the app shows a hint).
