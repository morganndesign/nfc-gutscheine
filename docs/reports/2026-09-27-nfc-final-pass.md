# NFC programming v2 — final pass report (v1.4.1)

Date: 27 September 2026 · Scope: dashboard NFC programming, NFC API, scan checks. Waiter app unchanged (file checksum identical before and after).

## 1. Real hardware testing — NOT PERFORMED

The build environment has no Pixel, no Samsung and no NFC tags, so no test with real hardware was run, and no hardware result below is claimed. The workflow was tested against a simulated NFC field that behaves like Chrome on Android (see 1b).

**1a. What you need to run** — `docs/NFC-RELEASE-TEST.md`. It has 14 cases on both phones, which cover every item you listed:

| Your item | Case |
|---|---|
| Pixel / Samsung | all cases on both phones |
| NTAG213 / 215 / 216 | H1, H2, H3 |
| write → read → verify → redeem | H1–H4 |
| tag removed during writing | H5 |
| same tag programmed twice | H6 |
| cloned URL on another chip | H8 |
| locked tag | H9 |

It also covers the tag of another card, the wrong tag type, the server being unreachable, a network timeout, a batch of 10 and the screen staying on. It includes the measurements and a report template to fill in; the station's **CSV** export gives you the timing numbers for it.

**1b. Simulated test report** (`e2e/nfc-programming.mjs`, Chromium with the Pixel 7 profile, simulated tags, local server):

| Case | Result |
|---|---|
| NTAG215 blank → detected, written, read back, verified, saved, locked | ✅ |
| NTAG213 blank → verified | ✅ |
| NTAG216 blank → verified | ✅ |
| Previous tag still on the phone → ignored | ✅ |
| Tag of another active card → refused, tag not written | ✅ |
| NTAG 424 DNA → "Wrong tag type" | ✅ |
| Locked tag with foreign content → "Tag is locked", content untouched | ✅ |
| Tag removed during writing → "Tag removed too early", nothing saved | ✅ |
| Server unreachable → "Server unavailable", nothing written | ✅ |
| Verification mismatch → "Verification failed", nothing saved | ✅ |
| Save answer lost after 15 s → "Network timeout"; the retry is saved exactly once and still locked | ✅ |
| Same locked tag programmed twice → "already programmed", nothing written | ✅ |
| Chip read → redeem € 12,50 | ✅ |
| Cloned link on another chip → refused (`NFC_UID_MISMATCH`) | ✅ |
| Tap without a chip serial → refused | ✅ |
| Attempt log complete: 17 attempts, none left "in progress" | ✅ |
| Accessibility scan (axe) of the station | ✅ |

## 2. Programming station improvements — done

The station now shows:

- **Progress:** `9 / 10 cards programmed`, with a progress bar and a percentage. The total is the number of cards without a tag in the chosen range when the session starts.
- **Counts:** successful cards, failed attempts and skipped cards.
- **Time:** elapsed time and the average per card including handling.
- **Averages:** tag → saved, write time, and read-back time.
- **Session log:** can be downloaded as CSV.

The E2E test checks: `9 / 10 cards programmed`, 9 successful, 7 failed attempts, 1 skipped card, and that elapsed time and the averages are shown.

## 3. Error handling — done

Every failure shows a title, what to do next, and that nothing was saved:

| Situation | Message title | Tested |
|---|---|---|
| Tag removed too early | **Tag removed too early** | unit test + E2E |
| Wrong tag type | **Wrong tag type** (NTAG 424, other chips, too small) | unit test + E2E |
| Locked tag (additional) | **Tag is locked** (detected before writing) | unit test + E2E |
| Tag belongs to another active card | **Tag belongs to another active card** + link to that card (another business: **Tag belongs to another business**, no details) | unit test + E2E |
| Write failed | **Write failed** | unit test |
| Verification failed | **Verification failed** | unit test + E2E |
| Server unavailable | **Server unavailable** | unit test + E2E |
| Network timeout | **Network timeout** (15 s limit per request, new) | unit test + E2E |

## 4. Recovery — verified in simulation

In one station session, with no page reload, the E2E test failed and then retried immediately with **Try again** for 7 different failure classes. Every retry succeeded. **Skip card** and **Stop** always work, and if the next card fails to load, that also shows a message with **Try again**.

After a lost server answer, the retry recognises the saved chip and does not save it twice.

## 5. Performance

**Measured (simulation, local server — not hardware numbers):**

| Step | Average | Max |
|---|---|---|
| Chip detection | 98 ms | 214 ms |
| Write | 30 ms | 31 ms |
| Verification (read back) | 41 ms | 42 ms |
| Complete programming (tag read → chip saved) | 221 ms | 330 ms |

These numbers mainly show the server and the app. The write and read times come from the simulator's fixed delays and say nothing about real chips.

Every real attempt now stores `detect_ms`, `write_ms`, `verify_ms` and `total_ms`, and the station shows the averages live. So the hardware numbers will come straight out of the release test (targets are in `NFC-RELEASE-TEST.md`).

Chip detection costs extra writes on every tag:

- NTAG216: 1 extra write.
- NTAG215: 3 extra writes.
- NTAG213: 7 extra writes.

These extra writes are expected to add about 0.1–0.5 s per tag on real chips. This is not yet measured.

## 6. Security review — the requested guarantee does NOT hold, by design

> "No possible path where a card can be redeemed without a successful verification and database registration of the NFC UID."

I cannot confirm this. Redemption is gated on permission, card status, balance and idempotency, not on a registered chip. These paths redeem a card without a chip check:

| Path | Why it exists (locked spec) |
|---|---|
| Dashboard **Redeem** button at the desk (card opened by number/search) | Counter redemption |
| Waiter: manual card-number entry | Worn or unreadable cards, no phone NFC |
| Waiter: QR code scan | QR on the back of every card, QR-only cards |
| Waiter on iPhone (opened link) for NTAG213/215/216 | iPhone link opening has no chip serial |
| Cards written with an external app (unverified, no UID) | Desktop/iPhone programming path |
| NTAG 424 DNA before its first tap | Chip serial binds on first verified tap |

**What is guaranteed (tested):**

1. A chip serial is only ever stored after the tag was read back with the exact card URL. The server re-checks this, and the API rejects a UID on every other path.
2. One chip can belong to at most one usable card on the whole platform. This is enforced by a database unique index and tested under concurrency.
3. When a card has a registered chip, an NFC tap with a different chip is refused before any redemption is offered. New: a tap without a chip serial is refused too.
4. NTAG 424 DNA taps and opened links need a valid, non-replayed cryptographic signature. New: opened links were not checked before.
5. A tag that belongs to another card is never overwritten.

**If you want the guarantee as written**, that is a product change to the locked spec and needs your decision. It would be a restaurant setting such as "Cards with a registered chip can only be redeemed after a matching chip tap". It would block desk, number, QR and iPhone-link redemption for those cards, and it would affect the waiter spec (manual entry, QR) and staff workflows. I have not implemented it.

## 7. Final production checklist

**Fixed in this pass:**

| # | Finding | Type | Fix |
|---|---|---|---|
| 1 | Programming requests had no timeout; a hanging request froze the station silently | Reliability | 15 s timeout, "Network timeout" |
| 2 | Two phones starting at the same card number replaced each other's chips without warning | Reliability / data | `only_if_unprogrammed` checked under the row lock; station auto-skips |
| 3 | A tag written by the losing phone could not be reused | UX | Stale copies of another card's link (that card has a different verified chip) may be reprogrammed |
| 4 | Retry after a lost save answer left the tag unlocked | Security | Lock also after "already programmed" |
| 5 | Locked tags and pulled-away tags showed a generic write error | UX | "Tag is locked" (detected before writing), "Tag removed too early" |
| 6 | Closed browsers left attempts "in progress" forever | Audit quality | Superseded by the next attempt (same user and device, older than 1 min) |
| 7 | Chip-serial probing via the check endpoint was unlimited | Security | 180 requests per minute per user and device |
| 8 | An NFC tap without a chip serial of a bound card was accepted | Security | Refused (`NFC_UID_MISMATCH`) |
| 9 | Native app iPhone reads of NTAG 424 (`method: link`) skipped SUN verification, so a replayed link was accepted | Security | Link scans are now verified like taps; a plain copied link of a 424 card is refused. QR and card number still work |
| 10 | No per-step timings | Operations | Stored per attempt, shown live, CSV export |

**Remaining — decide or test before release:**

| # | Item | Severity | Recommendation |
|---|---|---|---|
| A | **Real-hardware test not done** (Chrome/Android NFC behaviour, especially whether a new scan re-reads the tag still on the phone, and whether a failed probe write keeps the tag connected) | **Blocker** | Run `NFC-RELEASE-TEST.md` on both phones. If the read-back needs a lift-and-retap on some phones, the station already asks for it after 2.5 s, but check that it feels acceptable. |
| B | Redemption without a chip check (section 6) | Product decision | Keep as designed, or order the "strict chip" setting as a spec change |
| C | NTAG213/215/216 clone protection only covers Android taps; iPhone links, QR and manual entry carry no serial | Known limit (documented) | NTAG 424 DNA for high-value cards |
| D | Chips with a changeable UID ("magic" tags) can copy a UID | Known limit (documented) | NTAG 424 DNA |
| E | Detection by memory probes: chips larger than NTAG216 are recorded as NTAG216; an Ultralight EV1 would count as NTAG213 | Low | Buy NTAG21x only; no action |
| F | An attempt interrupted after the probe writes leaves probe data on the tag | Low | Harmless: a retry overwrites it; the tag is not linked to anything |
| G | The web waiter terminal sends `nfc_uid: null` if Chrome reports an empty serial; such taps of bound cards are now refused | Low | Verify during the hardware test (H4) |
| H | Commercial DE/BHS documents do not describe the station's new figures | Low | Add in the next docs pass if wanted |

**Verdict:** the software side is ready for the hardware release test, but NFC v2 is not yet production-ready. It becomes production-ready when item A passes on both phones and you have decided item B.
