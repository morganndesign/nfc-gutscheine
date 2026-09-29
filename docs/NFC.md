# NFC — physical cards (NTAG 424 DNA)

GiftCard Pro sells, pays with and manages physical gift cards built on **NXP NTAG 424 DNA** chips. Cards are
generic: the artwork is restaurant branding only (no amount, number or QR); a card's value is assigned when it is
sold. This page is the operational reference and the **validation procedure for real cards**.

## How a card is protected

| Threat | Protection |
|---|---|
| A copied tap URL (photographed, logged, shared) | The URL carries SUN data: UID and read counter encrypted with K1, MAC with the card's own K2 (AN12196). The server accepts each counter once (compare-and-set); an older or repeated URL is refused (`SUN_REPLAYED`) and counted by the fraud rules. |
| A cloned NDEF on another chip | Paying, selling and receiving need **live authentication**: AuthenticateEV2First with the card's K3, answered by the chip, relayed by the phone. The radio UID must equal the UID inside the SUN (`rf_uid_mismatch` → critical alert). |
| A chip that is not a genuine NXP NTAG 424 DNA | The station reads NXP's **originality signature** (Read_Sig, ECDSA secp224r1 over the UID) and verifies it against NXP's public key before any key is written; a fake becomes `qa_failed` (critical alert). |
| Extracting keys from one card | Every card has its own K0, K2, K3 (two-level AN10922 diversification root → batch → card, all derived inside the key provider); K1 is per key set. One card's keys unlock nothing else. |
| Changing a card's content or keys | NDEF file: read free, write and change only with K0; the SDM counter cannot be read out; all configuration runs under EV2 secure messaging (CommMode.Full, MACed responses verified). K0 exists only in the key provider. |
| Replaying a tap into a payment | A presentment is single use, 60 seconds, bound to user, device, restaurant, purpose and (for spending) voucher. |
| A card lost or stolen | Suspend it (dashboard or app) — it stops paying at once, also for a tap made a moment earlier; replace it with a stock card, the balance stays with the voucher. |
| A staff member moving a guest's balance onto a stock card they keep | A manager replaces only a card that is at hand (the old card is tapped: `surrender`); a lost or stolen card is replaced by the owner. The guest gets an e-mail for every replacement; three replacements by one person in a day raise `card.replacements`. |
| A compromised batch or key set | `compromised` revokes every card of the batch not yet with a guest; `cards:key-set:create` rotates to a new key set (old one `verify_only`). |
| A changed or swapped keystore | Daily `cards:key-set:verify` compares every root key with the key check value of its ceremony. |

### NTAG 424 DNA features — used and deliberately not used

| Feature (NT4H2421Gx) | Use |
|---|---|
| AES-128 keys K0–K4, AuthenticateEV2First, secure messaging | Used (K0 change key, K1 SUN meta read, K2 SUN MAC, K3 live challenge; K4 unused and referenced by no access right). |
| SDM with encrypted PICCData + SDMMAC, SDMReadCtr | Used (`SDMOptions C1`, `SDMAccessRights FF 12`: counter retrieval never, meta read K1, file read K2). |
| Originality signature (Read_Sig) | Used at the station. |
| Key versions | Used (01 for every key written; makes re-personalisation after an interruption safe). |
| LRP mode | Not used: AES mode with per-card diversified keys is sufficient; LRP would change every key operation for no gain in this threat model. |
| SDM encrypted file data | Not used: the card carries no private data. |
| SDMReadCtrLimit | Not used: it would make a card unusable after N taps; replays are refused by the server's counter instead. |
| Random ID | Not used: live authentication binds the radio UID to the SUN UID (anti-cloning). A reader in radio range can see the UID, which identifies a card but not its voucher or guest. |
| TagTamper | Not applicable (NTAG 424 DNA TT with a tamper loop; gift cards have none). |

## Where things run

- **Station (internal):** platform staff sign into the waiter app (station token), choose a batch in production and
  hold blank chips to the phone one after the other: originality check, tap URL, SDM settings, keys K1–K3 then K0,
  a guest-style SUN read and a K3 check → `qa_passed`. Interrupted chips are finished by holding them again.
- **Platform dashboard:** *Card batches* (order, production, two-person acceptance, shipping, hold resolution),
  *Security alerts*.
- **Restaurant, waiter app:** confirm a delivery (count + one tapped card), sell a gift card (tapped after payment),
  *Tap card* to pay, find / suspend / resume / replace a card.
- **Restaurant dashboard:** *Cards* (stock, guests' cards, history, suspend, resume, take stock cards out of
  service); the voucher detail shows its card.
- **Guest:** tapping the card with any phone opens `{TAP_URL}/{key set}?e=…&m=…`: restaurant, balance (if the
  restaurant allows it), validity. No cookies, no referrer.

API: [API.md → Card presentments](API.md#card-presentments-live-authentication), [Cards](API.md#cards-cardsview-cardsmanage),
[Card batches (platform)](API.md#card-batches-platform-platformcardsmanage), [Personalisation station](API.md#personalisation-station-platformcardspersonalize).

## Before the first real card

1. **Server** (staging first): `CRYPTO_KEYSTORE_KEY` set (the API does not start without it), a copy kept offline.
   `TAP_URL` chosen for the life of the cards (default `APP_URL/t`) — it is written into every card.
2. **Key ceremony** (two people, *Terminal* → **api**): `php artisan crypto:keystore:init` (first time only), then
   `php artisan cards:key-set:create ks-2026-01 --manufacturer="<printer>"`. Record the printed key check values
   on paper; `php artisan cards:key-set:verify` must pass. The next nightly backup copies the keystore; check with
   `ops:check-backups`.
3. **Off-site backups** configured ([DEPLOYMENT.md → Backups](DEPLOYMENT.md#backups)).
4. **Apps:** Android release build; iPhone via TestFlight (the App ID needs *NFC Tag Reading*; automatic signing
   in `testflight.yml` adds it from `Runner.entitlements`).
5. **Accounts:** a platform staff account for the station (and a second one for the acceptance), a manager of a
   test restaurant.

## Validation procedure with real cards

Equipment: 22 blank NTAG 424 DNA cards (2 kept blank for D2) (factory keys) from the chosen printer, 2 cards from another system or with
other keys (e.g. an NTAG 424 DNA already personalised elsewhere), 1 NTAG 213/215 sticker, one Android phone with NFC
(station), one Android phone and one iPhone (XS or newer, iOS 16+) as tills, a phone with *NFC Tools* for the
attack tests. Staging server, test restaurant. Record every result in the sign-off table.

### A · Personalisation (station, Android)

| # | Step | Expected |
|---|---|---|
| A1 | Dashboard → *Card batches* → order 20 cards for the test restaurant; *Status…* → *In production* | Batch `in_production`; the station lists it |
| A2 | Station: choose the batch, personalise 15 cards one after the other | Each shows "Card B-…-00nn done" in under 3 s; dashboard counts 15 personalised |
| A3 | Pull a card away while "Personalising" is shown (after ~0.5 s); hold it again | First attempt "not finished", second one done; key versions and counter consistent (A6) |
| A4 | Hold a card from another system | "Unknown card – set it aside"; alert `card.unknown_keys` |
| A5 | Hold the NTAG 213/215 sticker | Nothing happens or "not finished" (not an ISO 7816 card); no card registered |
| A6 | Open a personalised card's URL with any phone (tap it) | Guest page "not activated yet"; tapping again works; each tap increments the counter (`card_events`/`security_events` `card.tap`) |
| A7 | Personalise 5 cards on the **iPhone** station (same account) | Same as A2 (one system sheet per card) |
| A8 | Move the batch to *Personalised*, *QA testing*; approve by person 1, then person 2 | Accepted; cards not finished at the station are `qa_failed`; the same person cannot approve twice |

### B · Delivery (waiter app, manager)

| # | Step | Expected |
|---|---|---|
| B1 | *Status…* → *Assigned*, *Shipped* (tracking number), *Delivered* | The restaurant sees the delivery |
| B2 | App → Menu → *Confirm a delivery*, count one less than delivered, tap a card | "The count does not match…"; batch `on_hold` |
| B3 | Dashboard → *Resolve* with the missing card number | That card `lost`, the others `available` |
| B4 | Repeat with a second small batch and the right count, tapping a card of **another** batch | "This card is not from this delivery" |

### C · Sale and payment (Android till and iPhone till)

| # | Step | Expected |
|---|---|---|
| C1 | *Sell voucher* → *Gift card* → €50 → cash → *Tap card* | "Card activated", card number shown; dashboard: voucher `card`, card `active` |
| C2 | Tap the sold card again for another sale | "This card cannot be sold" |
| C3 | *Tap card* on the Android till, redeem €12 | Charge screen with €50 balance → €38 |
| C4 | Same on the iPhone till, redeem €8 | €30 |
| C5 | Tap to charge with the phone in airplane mode, then online | Clear offline message; nothing booked; works online |
| C6 | Time 10 taps from card contact to the charge screen on each till | Median under 1.5 s on Wi-Fi; note the worst case |
| C7 | Guest phone taps the card | Balance €30 (with "show balance" on), nothing that identifies the card |

### D · Attacks (must all fail)

| # | Step | Expected |
|---|---|---|
| D1 | Read the card's URL with *NFC Tools*, open it twice in a browser | First may show the page if unused; the second is refused ("already used"); after 3 replays alert `card.url_replay` |
| D2 | Read a fresh URL from an active card with *NFC Tools* (do not open it) and write it onto a **blank** NTAG 424 DNA; *Tap card* at the till with the copy | Refused ("Card not accepted"); alert `card.clone_attempt` (critical, e-mailed). A copy on an NTAG 213/215 is not even read by the till (not an ISO 7816 card) |
| D3 | Tap a card of another restaurant at the test restaurant's till | "Card not accepted" |
| D4 | Read the card 60 times with *NFC Tools* (no server contact), then tap at the till | Payment works; alert `card.counter_gap` (warning) |
| D5 | Try to write the NDEF file of a personalised card with *NFC Tools* | Write refused by the chip |

### E · Lost card and replacement

| # | Step | Expected |
|---|---|---|
| E1 | App → *Find a card* (number from the voucher detail) → *Suspend* → "Lost" | The card no longer pays (C3 now refused) |
| E2 | As manager: *Replace card* → only *Damaged* offered (note: lost/stolen by the owner). As owner: *Replace card* → *Lost* → tap a stock card | "Replaced by B-…"; the new card pays the remaining balance; the old card is refused for ever; the guest's e-mail arrives |
| E2b | Sell another card; as manager *Replace card* → *Damaged* → tap the old card, then a stock card (Android and iPhone) | Two taps; replaced; tapping another guest's card as the old one is refused |
| E3 | Dashboard → *Cards* → take a damaged stock card out of service | `revoked`; it cannot be sold |

### F · Operations

| # | Step | Expected |
|---|---|---|
| F1 | Next morning: `ops:check-backups` | Current, keystore copied, off-site copy present |
| F2 | Restore the last dump into a scratch database; `giftcard:verify-chains` there | Chains and balances verify |
| F3 | Dashboard → *Security alerts* | D1–D4 alerts present; acknowledge them with a note |

### Sign-off

| Area | Android (model, OS) | iPhone (model, iOS) | Result | Notes | Date / name |
|---|---|---|---|---|---|
| A Personalisation | | | | | |
| B Delivery | | | | | |
| C Sale and payment | | | | | |
| D Attacks | | | | | |
| E Replacement | | | | | |
| F Operations | | | | | |

A failure in A–E stops the rollout: keep the cards, the server logs and the security event export
(`php artisan giftcard:export-security-events`) of the test for analysis.
