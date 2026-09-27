# NFC programming — hardware release test

The automated tests (PHPUnit, `node --test`, `e2e/nfc-programming.mjs`) run against a **simulated** NFC field.
They prove the workflow, the server rules and the recovery paths, but not how real chips and real phones behave
(radio timing, Chrome's Web NFC implementation, Android's NFC stack). This test is done by a person with real devices
before every release that changes `dashboard/src/lib/nfc*.ts`, the programming station or the NFC API.

Duration: about 45 minutes per phone.

## Equipment

| Item | Quantity |
|---|---|
| Google Pixel (Android 13+), Chrome current | 1 |
| Samsung Galaxy (Android 13+), Chrome current (not Samsung Internet) | 1 |
| Blank NTAG213 cards or stickers | 5 |
| Blank NTAG215 cards | 5 |
| Blank NTAG216 cards | 3 |
| One NTAG 424 DNA card (or any bank/transit card) | 1 |
| A second phone with the waiter app (or the web waiter terminal on Android) | 1 |
| Staging restaurant with **20 new cards** without tags, a manager login, *Lock tags after writing* **off** at first | — |

Before starting: NFC on in the phone settings; open the dashboard in Chrome, sign in as manager, open
**Gift cards → Program NFC tags** and allow NFC for the site when Chrome asks.

## Test cases

Run every case on **both** phones. Write the result (✅ / ❌ + note) into the report below. "Nothing saved" is
checked on the card page (*NFC tag* shows *Not written yet*, *Tag programming* lists the failed attempt).

| # | Case | Steps | Expected |
|---|---|---|---|
| H1 | NTAG213 | Start the station; hold a blank NTAG213 flat on the back of the phone until the green tick. | Steps turn green, *NTAG213* detected, log row *Verified*, progress `1 / 20`. Card page: *Verified*, chip serial shown. |
| H2 | NTAG215 | Next card, blank NTAG215. | As H1 with *NTAG215*. |
| H3 | NTAG216 | Next card, blank NTAG216. | As H1 with *NTAG216*. |
| H4 | Read → verify → redeem | Take the H1 card to the waiter phone, tap it, redeem € 5. | Card opens immediately with the right balance; redemption booked; card history shows it. |
| H5 | Tag removed while writing | Next card; hold a blank tag and pull it away as soon as *Write card link* starts spinning. | Red panel **Tag removed too early**; nothing saved. **Try again**, hold the same tag still → *Verified*. No page reload. |
| H6 | Same tag twice | Open the H2 card → ⋯ → *Write NFC tag* → hold the H2 tag again. | *This tag is already programmed for this card*; nothing written (tag content unchanged). |
| H7 | Tag of another card | In the station, on the next card, hold the H3 tag. | **Tag belongs to another active card** with the other card number; H3 tag still works on the waiter phone. |
| H8 | Cloned URL on another chip | With an NFC writer app, copy the H1 card's link onto a blank tag (not through the dashboard). Tap it on the waiter phone. | Refused as copied card (*Cloned card rejected* in the audit log); no redemption possible from the tap. |
| H9 | Locked tag | Turn *Lock each tag after verifying* on; program one card (tag gets locked). Then, on the next card, hold that locked tag. | First: *Verified · locked*. Second: **Tag belongs to another active card** (refused before writing). Also hold a tag locked by another app (foreign content): **Tag is locked**. |
| H10 | Wrong tag type | Hold the NTAG 424 DNA (or a bank card). | **Wrong tag type**; nothing written. |
| H11 | Server unavailable | Switch the phone to airplane mode (NFC stays on), hold a blank tag. | **Server unavailable**; nothing written. Airplane mode off → **Try again** → *Verified*. |
| H12 | Network timeout | Only if a throttling proxy is available: delay API responses > 15 s. | **Network timeout**; after *Try again* the card is saved exactly once (*Already programmed* if the first save had arrived). |
| H13 | Batch of 10 | Program 10 cards in a row without touching the screen except for tags. | No stuck step; progress and averages update; **CSV** download opens. |
| H14 | Screen stays on | Wait 2 minutes on a card without holding a tag. | Screen does not turn off. |

## Measurements

After H13, download the session log (**CSV** on the station). From the successful rows compute:

| Value | Column | Target |
|---|---|---|
| Average write time | `Write ms` | < 300 ms |
| Average verification time | `Verify ms` | < 500 ms |
| Average complete programming time (tag read → saved) | `Tag to saved ms` | < 2.5 s |
| Average time per card incl. handling | station *Avg. per card* | < 8 s |

The same numbers are stored per attempt (`nfc_write_attempts.detect_ms`, `write_ms`, `verify_ms`, `total_ms`) and
shown by `GET /cards/{id}/nfc/attempts`.

## Report template

```
NFC programming release test — version …, date …, tester …
Server: staging …   Chrome versions: Pixel … / Samsung …

Case | Pixel … (Android …) | Samsung … (Android …) | Note
H1   |                     |                       |
…    |                     |                       |
H14  |                     |                       |

Measurements (10 cards, H13)     | Pixel | Samsung
Average write time (ms)          |       |
Average verification time (ms)   |       |
Average tag → saved (s)          |       |
Average per card incl. handling  |       |

Result: release / no release. Open issues: …
```
