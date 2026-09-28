# 12 · UI Copy and Error Messages

**GiftCard Waiter** — how the app speaks, how it reports problems, and the single master list of every UI string in German, English and BHS.

| | |
|---|---|
| Document | 12 of 14 · (17) UI copy guidelines · (18) Error message guidelines, error catalogue, master string table |
| Audience | UX writing, design, Flutter engineering, QA, translators |
| Binding source | Design brief v1 §7 (copy rules and key strings), §4 (screen IDs), API reference (error codes, headers) |
| Owner of | The master string table (§5). Screen documents reference keys; this document owns their wording. |
| Related | [01 · Vision and principles](01-product-vision-and-principles.md) · [02 · IA and journey](02-information-architecture-and-journey.md) · [03a · Screens: access and scanning](03a-screens-access-and-scanning.md) · [03b · Screens: charge, redeem, success, problems](03b-screens-charge-redeem-success-problems.md) · [04 · Design system](04-design-system.md) · [05 · Components](05-component-library.md) · [07 · Accessibility](07-accessibility-guidelines.md) · [08 · Responsive](08-responsive-behaviour.md) · [09 · Flutter handoff](09-flutter-handoff.md) · [11 · Sound and haptics](11-sound-and-haptics.md) |

---

## Contents

1. [UI copy guidelines (17)](#1-ui-copy-guidelines-17)
2. [Error message guidelines (18)](#2-error-message-guidelines-18)
3. [Error catalogue](#3-error-catalogue)
4. [Key conventions and placeholders](#4-key-conventions-and-placeholders)
5. [Master string table](#5-master-string-table)
6. [Translation and review checklist](#6-translation-and-review-checklist)

---

## 1. UI copy guidelines (17)

### 1.1 Who we write for

A waiter mid-service: one hand on a tray, a guest watching, three tables waiting. The phone is read in a glance of 0.5–1 s, sometimes in a dark room, sometimes at a terrace table in full sun. Every word competes with the amount, which is the actual interface ([01 · P2](01-product-vision-and-principles.md)).

The app voice is the brand voice ("an excellent head waiter: calm, precise, friendly — and only as much as needed", [tone-of-voice](../../de/09-brand/tone-of-voice.md)) in its shortest register: **2–8 words per line, verb first, no filler.**

### 1.2 Voice per language

| | German (primary, de-AT) | English | BHS (bs/hr/sr, ijekavian, Latin) |
|---|---|---|---|
| Address | **None.** Neutral infinitive/imperative without pronoun: "Karte an das Handy halten", "Nummer prüfen". No "Sie", no "du", no "Ihr/dein". | Plain imperative: "Hold the card to the phone". Avoid "you/your" in titles and buttons; use it in body text only where a neutral sentence would sound unnatural. | Formal plural imperative in titles, bodies and instructions: "Prislonite karticu", "Provjerite broj". Pronoun "Vi/Vaš" only if unavoidable, then capitalised. |
| Buttons | Object + infinitive: "Karte scannen", "€ 24,90 einlösen" | Verb + object: "Scan card", "Redeem €24.90" | Short imperative (2nd person singular, the platform convention for BHS buttons, as fixed by the brief): "Skeniraj karticu", "Iskoristi 24,90 €", "Otkaži" |
| Button exception | The two input-method buttons on S05 are icon + noun: "Kartennummer", "QR-Code" | "Card number", "QR code" | "Broj kartice", "QR kôd" |
| Politeness | "Bitte" sparingly: the manager escalation line and requests where a bare infinitive would sound curt ("Bitte noch einmal einlösen", "Bitte mit Passwort anmelden") | "Please" only in the same places | "Molimo" only in the same places |
| Register | Austrian standard German (Lokal, Jänner, Betriebsleitung, Servicekraft) | British spelling (recognised, cancelled, colour) | Bosnian-leaning neutral vocabulary: "postavke", "sedmica", "ponovo", "nazad", "cifra" |
| First person | Never "wir" in the UI — except inside a quoted sentence the waiter says to the guest (`uncertain.cancelledGuestHint`) | Never "we" (same exception) | Exception fixed by the brief: "Provjeravamo …", "Još tražimo …" (impersonal "we" is idiomatic in BHS status lines) |

> **Deviation from the brand guide, deliberate:** the brand guide addresses users with "Sie". The waiter app uses no address at all in German (brief §7). The app talks *about the task*, not *to the person* — shorter, and correct for staff of any seniority.

### 1.3 Vocabulary

Use exactly these words. The right column is forbidden in all UI strings, VoiceOver/TalkBack labels and store texts.

| Concept | DE | EN | BHS | Never |
|---|---|---|---|---|
| to redeem | einlösen | redeem | iskoristiti | abbuchen, entwerten, bezahlen, **Zahlung**, pay, **payment**, charge (as verb in UI), plaćanje, naplatiti |
| redemption | Einlösung | redemption | iskorištavanje | Transaktion (in UI), Buchung (except "doppelt gebucht"), payment, uplata |
| balance | Guthaben | balance | stanje | Saldo, Credit, Restwert, credit, iznos na računu |
| remaining balance | Restguthaben | remaining balance | preostalo stanje | Rest (alone, except row label), leftover |
| card | Karte | card | kartica | Gutschein (alone), Giftcard, Voucher, voucher, bon |
| gift card (overline, store) | Gutscheinkarte | gift card | poklon kartica | Geschenkkarte |
| card number | Kartennummer | card number | broj kartice | ID, Code |
| restaurant | Lokal | restaurant | restoran | Location, Outlet, Filiale |
| manager | Betriebsleitung | manager | menadžer | Chef, Admin, Owner, šef |
| phone | Handy (in instructions), Telefon (in states) | phone | telefon | Gerät (except "Gerätename"), device (except "device name"), mobitel |
| blocked | gesperrt | blocked | blokirana | deaktiviert, disabled, ungültig |
| expired | abgelaufen | expired | istekla | verfallen, ungültig |
| replaced | ersetzt | replaced | zamijenjena | ausgetauscht |
| reverse (manager only) | stornieren | reverse | stornirati | löschen, rückgängig machen, undo, refund |
| to sign in / out | anmelden / abmelden | sign in / sign out | prijaviti se / odjaviti se | einloggen, log in, login (as verb), ulogovati se |
| connection | Verbindung | connection | veza | Internet (alone), network, mreža |
| problem (titles) | describe the event | describe the event | describe the event | **Fehler**, **Error**, **Greška**, Ups, Oops, Achtung, Warning, Pažnja |

Brand and technology words stay untranslated: GiftCard Waiter, GiftCard Pro, NFC, QR-Code (DE) / QR code (EN) / QR kôd (BHS, with circumflex to distinguish it from the preposition "kod"), Face ID, Touch ID, iPhone, Android, App Store, Google Play, Dashboard (DE, EN) / dashboard (BHS, lower case).

### 1.4 Numbers and currency

**Rule:** amounts are formatted by the **restaurant locale** for German and English UI (so the number on screen matches the bill in the guest's hand). BHS UI always uses the BHS pattern. Currency is EUR in v1; the currency code from `/scan` (`currency`) is passed to the formatter, never hard-coded.

| UI language | Restaurant locale | Amount | Thousands | Zero | Max (7 digits) |
|---|---|---|---|---|---|
| DE | de-AT | € 24,90 | € 1.234,50 | € 0,00 | € 99.999,99 |
| DE | de-DE | 24,90 € | 1.234,50 € | 0,00 € | 99.999,99 € |
| DE | de-CH | € 24.90 | € 1’234.50 | € 0.00 | € 99’999.99 |
| EN | de-AT (typical: Vienna restaurant, English-speaking waiter) | € 24,90 | € 1.234,50 | € 0,00 | € 99.999,99 |
| EN | en-GB / en-US | €24.90 | €1,234.50 | €0.00 | €99,999.99 |
| BHS | any | 24,90 € | 1.234,50 € | 0,00 € | 99.999,99 € |

- Always two decimals, including in sentences ("€ 5,00", never "€ 5,–" or "€ 5").
- The space between symbol and number is a **no-break space** (U+00A0); the thousands separator never breaks a line.
- All numbers use tabular figures (`tnum`), see [04 · Typography](04-design-system.md).
- Negative amounts never appear in the waiter UI.
- Differences ("{diff} mehr als das Guthaben") use the same formatter.
- Card numbers: full `5285 1058 7098 6488` (groups of 4, no-break spaces, only S07 header and S11); masked `•••• 6488` (four U+2022 bullets, no-break space, last four digits) everywhere else. Never partially masked in other patterns.
- Countdown seconds: "{seconds} s" with no-break space; minutes: "{minutes} min". Never "Sek." or "secs".
- Percentages are not used in the waiter UI.

**Spoken amounts** (VoiceOver/TalkBack, `a11y.amount`): digits are never read as a formatted string ("euro sign two four comma nine zero"). The app supplies a spoken form:

| Locale | 24,90 | 1,00 | 21,00 | 0,50 |
|---|---|---|---|---|
| DE | "24 Euro 90" | "1 Euro" | "21 Euro" | "50 Cent" |
| EN | "24 euros 90" | "1 euro" | "21 euros" | "50 cents" |
| BHS | "24 eura 90" | "1 euro" | "21 euro" | "50 centi" |

### 1.5 Dates and times

All dates and times are shown in the **restaurant time zone**. The business day starts at **04:00** local time (Recent, [03b](03b-screens-charge-redeem-success-problems.md)).

| Use | DE (de-AT) | DE (de-DE/CH) | EN | BHS |
|---|---|---|---|---|
| Date on balance card, problem bodies | 26.09.2029 | 26.09.2029 | 26 Sep 2029 | 26. 9. 2029. |
| Month names (if written out) | Jänner, Februar … | Januar, Februar … | January … | januar, februar … (lower case) |
| Time in rows and details | 18:30 | 18:30 | 18:30 (en-GB) · 6:30 pm (en-US) | 18:30 |
| Time in a sentence | 18:30 Uhr | 18:30 Uhr | 18:30 · 6:30 pm | 18:30 h |
| Business-day reference | seit 04:00 Uhr | seit 04:00 Uhr | since 04:00 | od 04:00 h |

English uses the day-month-abbreviation pattern for dates everywhere so that "09/10" can never be misread by staff from different countries. No relative dates ("vor 3 Minuten") in v1 — Recent shows clock times.

### 1.6 Capitalisation

- **German:** standard German orthography; titles and buttons in sentence form ("Karte nicht gefunden", "Erneut scannen").
- **English:** sentence case everywhere ("Scan next card", "Card not found"). Never Title Case, never ALL CAPS except the overline.
- **BHS:** sentence case; months and weekdays lower case.
- **Overline** (`balanceCard.overline`) is the only uppercase string; it is typed in normal case in the resource file and uppercased by the style (`type.overline`), so screen readers read "Gutscheinkarte", not letters.

### 1.7 Punctuation

| Rule | Example |
|---|---|
| No exclamation marks. Anywhere. | "Eingelöst", never "Eingelöst!" |
| Titles, buttons, labels, badges, chips: no final full stop. | "Karte gesperrt" |
| Body text: full sentences with full stop. | "Nummer prüfen oder QR-Code scannen." |
| Ellipsis: the single character "…" (U+2026), preceded by a no-break space in all three languages (as fixed in the brief keys), only for ongoing processes. | "Wird geprüft …", "Checking …", "Provjeravamo …" |
| Separator between action and amount inside one label: middle dot with spaces " · " (U+00B7). It is also the preferred line-break point. | "Gesamtes Guthaben einlösen · € 32,50" |
| Dash inside a sentence: spaced en dash " – " (U+2013) in all three languages, including English, for one consistent glyph. Never a hyphen, never an em dash. | "Andere Karte erkannt – wechseln?" |
| Quotation marks: DE „…", EN "…", BHS „…". Only for referencing UI labels in help texts. | „Karte scannen" tippen |
| Questions only in confirmations and the switch-card snackbar. Never rhetorical. | "Abmelden?" |
| No emoji, no symbols as words (no "✓ Done", no "→"). The check in the iOS system sheet is drawn by iOS. | |

### 1.8 Length limits

Limits are in characters including spaces, measured on the **longest of DE, EN, BHS** after placeholder substitution with the longest realistic value (amount "€ 99.999,99", restaurant name 32 chars). They are design limits for 320 pt wide screens at 100 % text size; larger text sizes wrap as specified in [07](07-accessibility-guidelines.md) and [08](08-responsive-behaviour.md).

| Element | Component | Limit | Overflow behaviour |
|---|---|---|---|
| Primary / secondary button label (static) | `PrimaryButton`, `SecondaryButton` | **≤ 24** (DE target; hard max 28 in any language) | Never truncated. Wraps to 2 lines only at ≥ 135 % text size. |
| Button label with amount | `PrimaryButton`, `HoldButton` | static part ≤ 26 + amount | Breaks at " · " into two lines (separator removed); amount always on its own line, never split. |
| Tertiary button | `TertiaryButton` | ≤ 28 | Wraps to 2 lines. |
| Screen title | `type.title.l` (S02, S10, S15, S16) | **≤ 32 per line, max 2 lines** | Wraps; never truncated. |
| Sheet title | `type.title.m` | ≤ 28, 1 line | Wraps to 2 lines at large text. |
| Ready instruction title | S05 | ≤ 32, max 2 lines | Wraps. |
| Body text | `type.body.l` / `body.m` | **≤ 90 characters total (≈ 45 per line), max 2 lines** on problem screens and banners | Rewrite, do not shrink. |
| Status banner title | `StatusBanner` | ≤ 28 | Wraps to 2 lines. |
| Status badge | `StatusBadge` | ≤ 16 | Never wraps; must fit. |
| Snackbar message | `Snackbar` | ≤ 48, max 2 lines | 2 lines max; action label ≤ 12. |
| Chip | `QuickAmountChip` | static part ≤ 20 + amount | 1 line. |
| Inline validation (S07, S11, S02) | caption line | ≤ 48 | 1 line, 2 at large text. |
| Menu row label | S14 | ≤ 24 | Value text truncates in the middle, label never. |
| iOS NFC sheet alert | `alertMessage` | ≤ 60 ([03a §6.2](03a-screens-access-and-scanning.md); longest shipped: `ios.sheet.timeoutSoon` DE, 56) | iOS wraps; keep to 2 lines. |
| VoiceOver/TalkBack label | — | ≤ 120 | Content first, control type added by the OS. |
| Android launcher label | — | ≤ 16 | "GiftCard Waiter" (15). |

### 1.9 Pluralisation

Plurals use ICU plural categories; the resource format is ICU MessageFormat (see [09 · Localisation](09-flutter-handoff.md#65-localisation-resources)).

| Language | Categories | Rule (CLDR) | Example `recent.summary` |
|---|---|---|---|
| DE | one, other | n = 1 | 1 Einlösung · 5 Einlösungen |
| EN | one, other | n = 1 | 1 redemption · 5 redemptions |
| BHS | one, few, other | one: n mod 10 = 1 and n mod 100 ≠ 11 · few: n mod 10 = 2–4 and n mod 100 ∉ 12–14 · other: rest | 1 iskorištavanje · 3 iskorištavanja · 5 iskorištavanja · 11 iskorištavanja · 21 iskorištavanje (for nouns like "cifra": 1 cifra · 3 cifre · 5 cifara) |

Never build plurals by concatenation ("Einlösung(en)", "redemption(s)"). Numbers inside plural strings are digits, not words, in the UI.

### 1.10 Accessibility strings

Full rules in [07](07-accessibility-guidelines.md). Copy rules:

- **Every** interactive element and every non-decorative image has a label in all three languages (keys `*.a11y`). Decorative illustrations and the NFC glyph are hidden from assistive technology.
- Labels describe the **thing**, not the gesture: "Menü", not "Tippen für Menü". Control type ("Taste", "Button", "Dugme") is added by the OS — never put it in the label.
- Hints (`*.a11yHint`) only where the gesture is non-standard: hold-to-redeem, long-press backspace.
- Amounts are read with the spoken form (§1.4); card numbers masked as "Karte endet auf 6 4 8 8" (digits separated so they are read one by one).
- **Live-region announcements** (`a11y.*` keys) for: card detected, card loaded, amount change (debounced 500 ms), redeem success, every problem, back online, return to Ready. Politeness: problems and success = assertive; everything else polite.
- Status is never conveyed by colour alone; the banner text always contains the status word.

---

## 2. Error message guidelines (18)

### 2.1 Anatomy

Every problem message has exactly three parts. Each part is one line.

```
┌──────────────────────────────────────────┐
│  [illustration or icon]                  │
│                                          │
│  TITLE      what happened                │  ≤ 32 chars/line · no code · no blame
│  BODY       what to do now               │  ≤ 90 chars · max 2 lines · full stop
│  [support code, small]    Code 7F3A9C    │  only where §2.5 says so
│                                          │
│  [ PRIMARY ACTION  ]                     │  verb + object · thumb zone
│  [ secondary action ]                    │  optional
└──────────────────────────────────────────┘
```

- **Title = what happened**, as a fact about the card, the connection or the account. Never a judgement about the waiter or guest.
- **Body = what to do**, as an instruction the waiter can perform right now. If there is nothing to do but wait, say how long.
- **Action = the one next step**. Primary action returns the waiter to the loop (scan again, try again, done). A problem screen never has more than two actions.
- If money did **not** move and the waiter might fear it did, the body says so explicitly: "Es wurde nichts gebucht." / "Nothing was booked." / "Ništa nije knjiženo."

### 2.2 Severity mapping

| Severity | When | Colour tokens | Icon | Haptic | Sound | Announcement |
|---|---|---|---|---|---|---|
| **info** | Nothing is wrong with the card; the environment needs a moment (offline, slow, maintenance, still looking) | `color.info`, `color.info.bg` | `wifi-off`, `clock`, `info` | none (`haptic.warning` when a lookup fails for network reasons) | none (`sound.warning` on S10 network) | polite |
| **warning** | Recoverable here and now, or temporary (expired, inactive, zero balance, replaced, over balance, throttled, server error, velocity/rate limit, uncertain) | `color.warning`, `color.warning.bg` | `triangle-alert`, `clock` | `haptic.warning` | `sound.warning` (uncertain: none) | assertive |
| **danger** | The card or action cannot proceed without another card, a manager or a later attempt (blocked, not found, wrong restaurant, verification failed, rejected redeem, device revoked, restaurant paused, account deactivated) | `color.danger`, `color.danger.bg` — except verification failed, which keeps a calm warning-tone visual because the guest is present ([03b §5.2](03b-screens-charge-redeem-success-problems.md)) | `ban`, `circle-alert`, `lock` | `haptic.error` | `sound.error` | assertive |
| **success** | Money moved | `color.success`, `color.success.bg` | `SuccessMark` | `haptic.success` | `sound.success` | assertive |

The feedback column follows the severity rule of [11 §3](11-sound-and-haptics.md) (haptic/sound severity = banner severity); where the catalogue (§3) and 11 differ, 11 wins. Inline validation on S07/S11/S02 (over balance, incomplete number, empty field) is **not** an error: no sound, a single `haptic.warning` only when the state is entered, polite announcement.

### 2.3 No blame

| Instead of | Write |
|---|---|
| You scanned a wrong card | Card not found |
| Invalid card | Card from another restaurant / Card blocked |
| You entered too much | €7.50 more than the balance |
| Unauthorized | Session expired |
| Fraud detected / Fake card | Card could not be verified |
| Error 500 | Service not available right now |
| Transaction failed | Nothing was booked. Try again. |

Suspected clones and replays are never called fraud in the UI; the guest may be innocent. The waiter is told not to redeem and to get a manager; the details are in the audit log.

### 2.4 No codes in titles

HTTP status codes, API codes (`CARD_NOT_FOUND`), exception names and stack information never appear in titles, bodies or buttons. The only technical string the waiter may see is the **support code** (§2.5).

### 2.5 Support code

| | |
|---|---|
| Source | The `X-Request-Id` of the failed request (the app generates a UUID v4 per request; the server echoes it). |
| Format | Last 6 characters of the UUID, upper case, no hyphens: `…-4b1e9c7f3a9c` → `7F3A9C`. |
| Rendering | `common.supportCode` ("Code 7F3A9C" / "Kôd 7F3A9C"), `type.caption` with tabular figures, `color.fg.tertiary`, centred below the body. Long-press copies the full request id; `common.copied` snackbar confirms. On S10 verification failed a neutral tag follows: `Code 7F3A9C · UID` / `· SIG` / `· REPLAY`. |
| Shown on | S10 not found, wrong restaurant, verification failed, server error; S07 helper for client defects (R12); S08 uncertain (final); S15 forbidden, device revoked, restaurant paused, account deactivated; S02 server error; Recent detail. |
| Not shown on | Card-state banners (blocked, expired, inactive, replaced, zero), inline validation, offline, S10 throttled and S10 network (no request reached the server), Show-guest mode. |
| Note on format | Binding across all documents: last 6 characters, upper case ([03b](03b-screens-charge-redeem-success-problems.md) AC-S10-6, [04](04-design-system.md), [05](05-component-library.md) and [09](09-flutter-handoff.md) follow this table). |
| Screen reader | Read as "Code 7 F 3 A 9 C" (characters separated). |
| Relation to [02 §4.6](02-information-architecture-and-journey.md) | 02 forbids showing request IDs. The support code is a 6-character fragment, not the request id; it lets a manager find the incident in the audit log without exposing the identifier. It is the only technical string on waiter screens. |

### 2.6 Manager escalation

- Exactly one wording in all places: `getManager` — "Bitte Betriebsleitung holen" / "Please get a manager" / "Molimo pozovite menadžera".
- It is the **body** (or its second sentence), never a button: the waiter cannot "do" it inside the app.
- Used when the waiter cannot resolve the situation alone: card blocked, expired, inactive; verification failed; no permission; device revoked; restaurant paused; account deactivated; velocity limit without a known end time. Offered as an option ("… Oder Betriebsleitung holen.") where the waiter can usually wait: velocity limit with a known end time. Replaced cards need the guest's new card, not a manager.
- Never "contact support", "contact GiftCard Pro", phone numbers or e-mail addresses on waiter screens. Vendor support is the manager's job.

### 2.7 Retry wording

| Situation | DE | EN | BHS | Key |
|---|---|---|---|---|
| Card needs to be read again | Erneut scannen | Scan again | Skeniraj ponovo | `common.scanAgain` |
| Request failed, nothing booked | Erneut versuchen | Try again | Pokušaj ponovo | `common.tryAgain` |
| Redeem outcome unknown (S08 final) | Erneut versuchen — **same key**, body `uncertain.failedBody` says it can never book twice | Try again | Pokušaj ponovo | `common.tryAgain` |
| Automatic retry running | Verbindung langsam – neuer Versuch · Versuch {n} von 3 | Connection slow – retrying · Attempt {n} of 3 | Spora veza – ponovni pokušaj · Pokušaj {n} od 3 | `redeem.slow`, `uncertain.retrying` |
| Account state may have changed (S15) | Erneut prüfen | Check again | Provjeri ponovo | `common.checkAgain` |

Never "Retry", "Reload", "Refresh" or bare "OK". A retry of an uncertain redemption always reuses the same Idempotency-Key ([09 · Redeem state table](09-flutter-handoff.md#44-redeem-transaction-state-table)); the copy around it always carries the reassurance "Es wird nie doppelt gebucht" and never claims that nothing was booked.

### 2.8 Placement rules

| Placement | Used for | Dismissal |
|---|---|---|
| **S07 status banner** (balance card visible) | Problems about a card whose data we have: blocked, expired, inactive, replaced, zero balance, not redeemable | Stays until card closed or replaced |
| **S07 helper / assist rows** | Over balance, max single redemption, balance changed, full-only, "nothing was booked" after a card-state rejection, "please tap Redeem again", client-defect line | Clears on next keypad input or after 4 s where specified |
| **S07 warning banner** | Velocity limit, rate limit, unconfirmed redemption after "Abbrechen" | Until countdown ends, card closed or success |
| **S08 in-place** (button label, uncertain panel replacing the keypad) | Slow connection, uncertain (auto-retrying), uncertain (final) | Resolves automatically, or "Erneut versuchen" / "Abbrechen" in the final state |
| **S10 full screen** | No card data: not found, wrong restaurant, verification failed, throttled, network, server | Primary action, ✕, back |
| **S15** sheet / full screen | Session and account: session expired (sheet), forbidden, device revoked, restaurant paused, account locked, account deactivated, update required; maintenance = S05 banner | Primary action |
| **S16** inline states | NFC off, no NFC, camera denied / restricted / unavailable | Resolves when the permission changes |
| **Snackbar** | Transient, non-blocking: back online, switch card (6 s), NFC unavailable, biometrics not enrolled, code copied | 4 s, or action |
| **iOS system NFC sheet** | Read-level messages only (found, multiple cards, not read, no card yet, not a gift card) | iOS |

---

## 3. Error catalogue

Every API error code and client condition, mapped to where it appears and what it says. Keys refer to §5; texts are the master wording. Placement and flow follow [02](02-information-architecture-and-journey.md) and the screen documents ([03a](03a-screens-access-and-scanning.md), [03b](03b-screens-charge-redeem-success-problems.md) §1.3); feedback follows [11 · Sound and haptics](11-sound-and-haptics.md) (events E25–E47). Recovery rules for the `Idempotency-Key` are in [09 §4](09-flutter-handoff.md#4-state-and-transactions).

### 3.1 Card lookup — `POST /api/v1/scan`

| # | Code / condition | Placement | Sev. | Title (DE / EN / BHS) | Body (DE / EN / BHS) | Actions | Feedback | Recovery |
|---|---|---|---|---|---|---|---|---|
| L01 | 404 `CARD_NOT_FOUND`, method `nfc` / `qr` / `link` | S10 not found | warning | Karte nicht gefunden<br>Card not found<br>Kartica nije pronađena | Diese Karte ist nicht im System. Karte prüfen oder nach einer anderen fragen.<br>This card is not in the system. Check the card or ask the guest for another one.<br>Ova kartica nije u sistemu. Provjerite karticu ili zamolite drugu. | Erneut scannen · Kartennummer eingeben | haptic.error · sound.error | Android: a new tap starts a new lookup directly; support code shown |
| L02 | 404 `CARD_NOT_FOUND`, method `manual` | S10 not found (manual) | warning | as L01 | Keine Karte mit dieser Nummer. Ziffern prüfen.<br>No card with this number. Check the digits.<br>Nema kartice s ovim brojem. Provjerite cifre. | Nummer bearbeiten | haptic.error · sound.error | Back to S11 with the digits kept |
| L03 | 403 `CARD_FOREIGN_RESTAURANT` | S10 foreign | warning | Karte eines anderen Lokals<br>Card from another restaurant<br>Kartica drugog restorana | Sie ist nur im ausstellenden Lokal einlösbar.<br>It can only be redeemed at the restaurant that issued it.<br>Može se iskoristiti samo u restoranu koji ju je izdao. | Fertig | haptic.error · sound.error | → S05. The other restaurant's name is never shown |
| L04 | 403 `NFC_UID_MISMATCH`, `NFC_SIGNATURE_INVALID`, `NFC_REPLAY_DETECTED` | S10 verification failed | danger (calm visual tone, never red — [03b §5.2](03b-screens-charge-redeem-success-problems.md)) | Karte konnte nicht geprüft werden<br>Card could not be verified<br>Kartica nije mogla biti provjerena | Karte vorerst nicht annehmen. Bitte Betriebsleitung holen.<br>Do not accept this card for now. Please get a manager.<br>Zasad ne prihvatajte ovu karticu. Molimo pozovite menadžera. | Fertig · Erneut scannen (tertiary, one fresh read) | haptic.error · sound.error | Never offers QR or manual entry (would bypass chip verification). Support code with neutral tag `· UID` / `· SIG` / `· REPLAY` |
| L05 | 429 `SCAN_THROTTLED`, 429 `TOO_MANY_REQUESTS` (`retry_after`) | S10 throttled | warning | Zu viele Scans<br>Too many scans<br>Previše skeniranja | Scannen ist in Kürze wieder möglich.<br>Scanning is possible again shortly.<br>Skeniranje će uskoro ponovo biti moguće. | Erneut scannen · {time} (disabled, counting down) | haptic.warning · sound.warning; at 0: haptic.select | Android reader mode paused during the countdown; no support code |
| L06 | No response ≤ 10 s, offline, DNS/TLS/transport failure | S10 network | info | Keine Verbindung<br>No connection<br>Nema veze | Karte konnte nicht geprüft werden. WLAN oder mobile Daten prüfen, dann erneut versuchen.<br>The card could not be checked. Check Wi-Fi or mobile data, then try again.<br>Kartica nije provjerena. Provjerite Wi-Fi ili mobilne podatke, pa pokušajte ponovo. | Erneut versuchen — or Erneut scannen for SUN-signed cards | haptic.warning · sound.warning | "Erneut versuchen" re-sends the identical lookup; a URL with `picc`/`cmac` is never re-posted ([03b §1.2](03b-screens-charge-redeem-success-problems.md)) |
| L07 | 5xx on lookup | S10 server | warning | Dienst gerade nicht erreichbar<br>Service not available right now<br>Servis trenutno nije dostupan | Das Problem liegt nicht an der Karte. Gleich erneut versuchen.<br>The problem is not the card. Try again in a moment.<br>Problem nije do kartice. Pokušajte ponovo za trenutak. | Erneut versuchen (same SUN rule) | haptic.warning · sound.warning | Support code shown |
| L08 | Lookup still running after 3 s | S06 / S07 skeleton caption | info | — | Suche dauert länger …<br>Still looking …<br>Još tražimo … | — | none | Becomes L06 at 10 s |
| L09 | Card read while the device is known to be offline (Android) | S05 inline line | info | — | Keine Verbindung – Karte kann nicht geprüft werden<br>No connection – the card can't be checked<br>Nema veze – kartica se ne može provjeriti | — | haptic.warning | No request, no queue; tap again once `ready.online` appears |
| L10 | Tag or QR is not a GiftCard Pro card URL (client-side check, no request) | Android S06 · iOS sheet · S12 | warning | Keine Gutscheinkarte<br>This is not a gift card<br>Ovo nije poklon kartica | S12: Dieser QR-Code gehört zu keiner Gutscheinkarte<br>This QR code isn't a gift card<br>Ovaj QR kôd nije poklon kartica | — | haptic.warning | Bank and transit cards land here |
| L11 | NFC read interrupted / unreadable | Android S06 inline · iOS sheet text | warning | Karte konnte nicht gelesen werden<br>Couldn't read the card<br>Kartica nije pročitana | Karte eine Sekunde ruhig halten.<br>Hold it still for a second.<br>Držite je mirno jednu sekundu. | — | haptic.warning | Reader stays active; iOS restarts polling |
| L12 | 401, 403 `DEVICE_REVOKED`, `RESTAURANT_SUSPENDED`, `FORBIDDEN` | S15 — see §3.3 | | | | | | Never rendered as S10 |

### 3.2 Redeem — `POST /api/v1/cards/{id}/redeem`

| # | Code / condition | Placement | Sev. | Title (DE / EN / BHS) | Body / line (DE / EN / BHS) | Actions | Feedback | Recovery / key |
|---|---|---|---|---|---|---|---|---|
| R01 | 201, or 200 with `replayed: true` | S09 | success | Eingelöst<br>Redeemed<br>Iskorišteno | Restguthaben {amount}<br>Remaining balance {amount}<br>Preostalo stanje {amount} | per S09 | haptic.success · sound.success | Key closed; replay renders identically, no second Recent row |
| R02 | No response within 8 s | S08 slow (button label + helper) | info | Verbindung langsam – neuer Versuch<br>Connection slow – retrying<br>Spora veza – ponovni pokušaj | Wird geprüft … Es wird nie doppelt gebucht.<br>Checking … Nothing is ever booked twice.<br>Provjeravamo … Ništa se ne knjiži dvaput. | — | none | Request aborted and re-sent with the **same** key |
| R03 | Transport error, offline, 5xx, second timeout | S08 uncertain (auto-retrying) | warning | Verbindung unterbrochen<br>Connection interrupted<br>Veza prekinuta | Wird geprüft … Es wird nie doppelt gebucht. + Versuch {n} von 3 + guest line: Dem Gast sagen: „Einen Moment bitte, die Einlösung wird bestätigt."<br>Checking … Nothing is ever booked twice. + Attempt {n} of 3 + Tell the guest: "One moment please, the redemption is being confirmed."<br>Provjeravamo … Ništa se ne knjiži dvaput. + Pokušaj {n} od 3 + Recite gostu: „Trenutak, molim, iskorištavanje se potvrđuje." | — | haptic.warning once, no sound | Same key; retries per [09 §4.4](09-flutter-handoff.md#44-redeem-transaction-state-table) |
| R04 | Retries exhausted (3 retries or 20 s after the tap) | S08 uncertain (final) | warning | Verbindung unterbrochen (unchanged) | Noch nicht bestätigt. Erneut versuchen – es wird nie doppelt gebucht.<br>Not confirmed yet. Try again – nothing is ever booked twice.<br>Još nije potvrđeno. Pokušajte ponovo – ništa se ne knjiži dvaput. | Erneut versuchen (same key) · Abbrechen | haptic.warning (no second sound) | Support code. "Abbrechen" → S07 unchanged with the line below (R05); the attempt is kept for the same card + amount |
| R05 | After "Abbrechen" in R04 | S07 warning banner | warning | — | Nicht bestätigt. Vor dem nächsten Einlösen die Karte erneut scannen. + Dem Gast sagen: „Die Einlösung ist noch nicht bestätigt. Wir prüfen das Guthaben, bevor neu eingelöst wird."<br>Not confirmed. Scan the card again before redeeming. + Tell the guest: "The redemption isn't confirmed yet. We'll check the balance before redeeming again."<br>Nije potvrđeno. Prije novog iskorištavanja ponovo skenirajte karticu. + Recite gostu: „Iskorištavanje još nije potvrđeno. Provjerit ćemo stanje prije novog iskorištavanja." | — | haptic.select | The copy never claims "nothing was booked" (the app cannot know) |
| R06 | 422 `INSUFFICIENT_BALANCE` (`context.balance`) | S07 over-balance variant, helper 4 s | warning | — | Guthaben hat sich geändert: jetzt {amount}<br>Balance changed: now {amount}<br>Stanje se promijenilo: sada {amount} | Chip Guthaben verwenden · {amount} | haptic.error · sound.error | Key closed; balance from `context`, no extra request |
| R07 | 422 `CARD_BLOCKED` | S07 blocked variant + helper 4 s | danger | Karte gesperrt<br>Card blocked<br>Kartica blokirana | Es wurde nichts gebucht. + Bitte Betriebsleitung holen.<br>Nothing was booked. + Please get a manager.<br>Ništa nije knjiženo. + Molimo pozovite menadžera. | Fertig | haptic.error · sound.error | Key closed; no `blocked_reason` available from this response |
| R08 | 422 `CARD_EXPIRED` | S07 expired variant + helper | warning | Karte abgelaufen<br>Card expired<br>Kartica istekla | Es wurde nichts gebucht. + Abgelaufen am {date}. Bitte Betriebsleitung holen. | Fertig | haptic.error · sound.error | Key closed |
| R09 | 422 `CARD_NOT_REDEEMABLE` (`context.status`), 409 `INVALID_CARD_STATE` | S07 variant for that status (zero balance, inactive, replaced) + helper | warning | per status (`card.empty`, `card.inactive`, `card.replaced`) | Es wurde nichts gebucht. + status body | Fertig | haptic.error · sound.error | Key closed |
| R10 | 422 `INVALID_AMOUNT` with `context.max_single_redemption` | S07 helper + chip | warning | — | Max. {amount} pro Einlösung<br>Max. {amount} per redemption<br>Najviše {amount} po iskorištavanju | Chip Maximum verwenden · {amount} | haptic.error · sound.error (server) · haptic.warning (client-side crossing) | Key closed; cap cached and checked client-side afterwards |
| R11 | 422 `INVALID_AMOUNT` with `context.balance` only (full-only rule changed) | S07 partial-disabled variant | info | — | Hier ist nur das gesamte Guthaben einlösbar.<br>Only the full balance can be redeemed here.<br>Ovdje se može iskoristiti samo cijelo stanje. | Gesamtes Guthaben einlösen · {amount} | haptic.warning | Key closed |
| R12 | 422 `VALIDATION_FAILED`, 400 `IDEMPOTENCY_KEY_REQUIRED`, `INVALID_AMOUNT` without context | S07 helper | warning | — | Dienst gerade nicht erreichbar + Code {code} | — | haptic.warning | Client defect, logged; key closed |
| R13 | 409 `IDEMPOTENCY_CONFLICT` | S07 helper (info) | info | — | Bitte noch einmal einlösen.<br>Please tap Redeem again.<br>Molimo ponovo dodirnite Iskoristi. | — | haptic.warning | New key; **no automatic resubmit** |
| R14 | 429 `VELOCITY_LIMIT_EXCEEDED` | S07 warning banner | warning | Limit für diese Karte erreicht<br>Limit for this card reached<br>Dosegnut je limit za ovu karticu | Time known: Wieder möglich in {minutes} min. Oder Betriebsleitung holen.<br>Possible again in {minutes} min. Or get a manager.<br>Ponovo moguće za {minutes} min. Ili pozovite menadžera.<br>Time unknown: Bitte Betriebsleitung holen. | — | haptic.warning · sound.warning | Key closed; button disabled while a countdown runs |
| R15 | 429 `TOO_MANY_REQUESTS` (`retry_after`) | S07 warning banner | warning | — | Zu viele Anfragen – wieder möglich in {seconds} s<br>Too many requests – possible again in {seconds} s<br>Previše zahtjeva – ponovo moguće za {seconds} s | — | haptic.warning · sound.warning | Key closed |
| R16 | No network path before sending | S07 inline (button disabled) | info | Keine Verbindung<br>No connection<br>Nema veze | Einlösen braucht Internet, damit nie doppelt gebucht wird. (`offline.body`) | — | haptic.warning | Nothing sent, no key generated |
| R17 | 401 | S15 session sheet | warning | see A01 | | | | Attempt kept (same key) across re-authentication; back on S07 with amount |
| R18 | 403 `DEVICE_REVOKED`, `RESTAURANT_SUSPENDED`, `FORBIDDEN` | S15 | danger | see §3.3 | | | | Attempt discarded |

### 3.3 Session and account (any request, incl. sign-in)

| # | Code / condition | Placement | Sev. | Title (DE / EN / BHS) | Body (DE / EN / BHS) | Actions | Feedback | Recovery |
|---|---|---|---|---|---|---|---|---|
| A01 | 401 `UNAUTHENTICATED` | S15 session sheet over the current layer, not dismissible | warning | Sitzung abgelaufen<br>Session expired<br>Sesija je istekla | Zum Weitermachen erneut anmelden.<br>Sign in again to continue.<br>Prijavite se ponovo za nastavak. | Password field (e-mail prefilled) · Erneut anmelden | haptic.warning · sound.warning | Lookup context → S05; redeem context → S07, amount and attempt kept |
| A02 | 403 `FORBIDDEN` at sign-in (role without `cards.redeem`) | S02 inline | danger | — | Dieses Konto kann keine Karten einlösen. Bitte Betriebsleitung holen.<br>This account can't redeem cards. Please get a manager.<br>Ovaj račun ne može iskorištavati kartice. Molimo pozovite menadžera. | — | haptic.error | — |
| A03 | 403 `FORBIDDEN` during a session (role changed) | S15 full screen | danger | Keine Berechtigung zum Einlösen<br>No permission to redeem<br>Nema dozvole za iskorištavanje | Dieses Konto kann keine Karten mehr einlösen. Bitte Betriebsleitung holen.<br>This account can no longer redeem cards. Please get a manager.<br>Ovaj račun više ne može iskorištavati kartice. Molimo pozovite menadžera. | Erneut prüfen · Zur Anmeldung | haptic.error · sound.error | Support code; "Erneut prüfen" calls `/auth/me` |
| A04 | 403 `DEVICE_REVOKED` | S15 full screen | danger | Gerät wurde entfernt<br>This device was removed<br>Uređaj je uklonjen | Das Gerät ist nicht mehr für dieses Lokal freigegeben. Bitte Betriebsleitung holen.<br>It's no longer allowed for this restaurant. Please get a manager.<br>Uređaj više nije odobren za ovaj restoran. Molimo pozovite menadžera. | Anmelden | haptic.error · sound.error | Token and Recent cleared; support code |
| A05 | 403 `RESTAURANT_SUSPENDED` | S15 full screen | danger | Einlösen ist pausiert<br>Redeeming is paused<br>Iskorištavanje je pauzirano | Das Konto des Lokals ist pausiert. Bitte Betriebsleitung holen.<br>The restaurant's account is paused. Please get a manager.<br>Račun restorana je pauziran. Molimo pozovite menadžera. | Erneut prüfen | haptic.error · sound.error | Support code |
| A06 | 423 `ACCOUNT_LOCKED` (`retry_after`) | S15 full screen | warning | Konto vorübergehend gesperrt<br>Account temporarily locked<br>Račun je privremeno zaključan | Zu viele Anmeldeversuche. Erneut möglich in {time}.<br>Too many sign-in attempts. Try again in {time}.<br>Previše pokušaja prijave. Ponovo za {time}. | Erneut in {time} (disabled) | haptic.warning · sound.warning | Countdown; at 0 announce `locked.over` |
| A07 | Wrong e-mail or password | S02 inline | warning | — | E-Mail oder Passwort stimmt nicht. Bitte prüfen und erneut versuchen.<br>E-mail or password is incorrect. Check both and try again.<br>E-mail ili lozinka nisu ispravni. Provjerite i pokušajte ponovo. | — | haptic.warning | Password cleared, e-mail kept |
| A08 | 429 at sign-in | S02 inline | warning | — | Zu viele Versuche. Erneut möglich in {time}.<br>Too many attempts. Try again in {time}.<br>Previše pokušaja. Ponovo za {time}. | — | haptic.warning | Button disabled until 0 |
| A09 | 5xx / offline at sign-in | S02 inline | info | — | Anmelden gerade nicht möglich. Gleich noch einmal versuchen. · Anmelden braucht eine Internetverbindung. (and EN/BHS per §5.3) | — | haptic.warning | — |
| A10 | Account deactivated (dedicated code pending — [09 open question 2](09-flutter-handoff.md#13-open-questions)) | S15 full screen | danger | Konto deaktiviert<br>Account deactivated<br>Račun je deaktiviran | Dieses Konto kann nicht mehr verwendet werden. Bitte Betriebsleitung holen.<br>This account can no longer be used. Please get a manager.<br>Ovaj račun se više ne može koristiti. Molimo pozovite menadžera. | Zur Anmeldung | haptic.error · sound.error | Token and Recent cleared; support code |
| A11 | `/app/config` minimum version > installed | S15 full screen, blocking | info | Update erforderlich<br>Update required<br>Potrebno ažuriranje | Diese Version wird nicht mehr unterstützt. Zum Weiterarbeiten aktualisieren.<br>This version is no longer supported. Update to keep redeeming.<br>Ova verzija više nije podržana. Ažurirajte za nastavak rada. | Jetzt aktualisieren | none | Opens the store listing |
| A12 | `/app/config` maintenance notice | S05 `Banner` (dismissible) | info | — | Server text; fallback: Geplante Wartung: Einlösen kann kurz nicht möglich sein.<br>Scheduled maintenance: redeeming may be briefly unavailable.<br>Planirano održavanje: iskorištavanje može kratko biti nedostupno. | ✕ (Hinweis schließen) | none | Hidden until next cold start once dismissed |
| A13 | Offline (no network path) | S05 variant | info | Keine Verbindung<br>No connection<br>Nema veze | Einlösen braucht Internet, damit nie doppelt gebucht wird.<br>Redeeming needs a connection so nothing is ever booked twice.<br>Za iskorištavanje je potrebna veza, da se ništa ne knjiži dvaput. | — | haptic.warning on entering | Back online → "Wieder verbunden" |

### 3.4 Device, permissions, reading and unlock

| # | Condition | Placement | Title / line (DE / EN / BHS) | Body (DE / EN / BHS) | Actions | Feedback |
|---|---|---|---|---|---|---|
| P01 | Android: NFC switched off | S05 / S16 | NFC ist aus<br>NFC is off<br>NFC je isključen | NFC einschalten, um Karten zu scannen.<br>Turn on NFC to scan cards.<br>Uključite NFC za skeniranje kartica. | NFC einschalten · Kartennummer · QR-Code | none; on return `nfcOff.on` announced |
| P02 | No NFC hardware (iPad, some Android) | S05 variant | QR-Code auf der Karte scannen<br>Scan the QR code on the card<br>Skenirajte QR kôd na kartici | Dieses Gerät hat kein NFC. QR-Code oder Kartennummer verwenden.<br>This device has no NFC. Use the QR code or the card number.<br>Ovaj uređaj nema NFC. Koristite QR kôd ili broj kartice. | QR-Code scannen | none |
| P03 | Camera permission denied | S12 / S16 | Kamerazugriff ist aus<br>Camera access is off<br>Pristup kameri je isključen | Kamera in den Einstellungen erlauben, um QR-Codes zu scannen.<br>Allow camera access in Settings to scan QR codes.<br>Dozvolite pristup kameri u postavkama za skeniranje QR kodova. | Einstellungen öffnen · Kartennummer eingeben | none |
| P04 | Camera restricted by device policy | S12 / S16 | Kamerazugriff ist aus | Die Kamera ist auf diesem Gerät gesperrt. Kartennummer verwenden.<br>The camera is restricted on this device. Use the card number.<br>Kamera je ograničena na ovom uređaju. Koristite broj kartice. | Kartennummer eingeben | none |
| P05 | Camera in use by another app | S12 | Kamera nicht verfügbar<br>Camera not available<br>Kamera nije dostupna | Andere Apps mit Kamera schließen oder Kartennummer eingeben.<br>Close other apps using the camera or enter the card number.<br>Zatvorite druge aplikacije s kamerom ili unesite broj kartice. | Kartennummer eingeben | none |
| P06 | iOS: several tags in the field | iOS sheet | Mehrere Karten erkannt. Nur eine Karte halten.<br>More than one card detected. Hold only one.<br>Prepoznato više kartica. Držite samo jednu. | — | — | iOS |
| P07 | iOS: 20 s without a card (sheet still open) | iOS sheet | Noch keine Karte. Karte flach oben an das iPhone halten.<br>No card yet. Hold it flat near the top of the iPhone.<br>Još nema kartice. Prislonite je ravno na vrh iPhonea. | — | — | none |
| P08 | iOS: session timeout (≈ 60 s) or cancel | S05 hint | Keine Karte erkannt. Zum Wiederholen „Karte scannen" tippen.<br>No card detected. Tap "Scan card" to try again.<br>Kartica nije prepoznata. Dodirnite „Skeniraj karticu" za novi pokušaj. | — | Karte scannen | none (silent) |
| P09 | NFC temporarily unavailable (iOS system busy, Android adapter error) | S05 snackbar | NFC gerade nicht verfügbar. Kartennummer oder QR-Code verwenden.<br>NFC isn't available right now. Use the card number or QR code.<br>NFC trenutno nije dostupan. Koristite broj kartice ili QR kôd. | — | — | haptic.warning |
| P10 | Biometrics not enrolled when enabling | S03 snackbar | Face ID ist nicht eingerichtet. In den Einstellungen einrichten. (+ Touch ID / Android variants) | — | — | none |
| P11 | Biometric prompt failed / cancelled | S03 / S04 inline | Nicht bestätigt. Noch einmal versuchen.<br>Not confirmed. Try again.<br>Nije potvrđeno. Pokušajte ponovo. | — | Mit Face ID entsperren · Passwort verwenden | none |
| P12 | Biometric lockout (OS) | S04 inline | Zu viele Versuche. Passwort verwenden.<br>Too many attempts. Use the password.<br>Previše pokušaja. Koristite lozinku. | — | Passwort verwenden | haptic.warning |
| P13 | Biometric set changed on the device | S04 → S02 | Biometrie wurde auf diesem Gerät geändert. Bitte mit Passwort anmelden.<br>Biometrics changed on this device. Sign in with your password.<br>Biometrija je promijenjena na ovom uređaju. Prijavite se lozinkom. | — | Passwort verwenden | none |
| P14 | Android: different card tapped on S07 with amount > 0 | S07 snackbar (Dialog with screen reader) | Andere Karte erkannt – wechseln?<br>Different card detected – Switch?<br>Prepoznata je druga kartica – zamijeniti? | — | Wechseln · Behalten | haptic.cardDetected · sound.cardDetected |

---

## 4. Key conventions and placeholders

### 4.1 Key naming

- Pattern: **`screen.element[.variant][.platform]`**, lowerCamelCase segments, dot-separated, ASCII only. Examples: `ready.android.title`, `charge.redeemFull`, `problem.notFound.bodyManual`.
- Prefixes: `app` · `common` · `splash` (S01) · `signIn` (S02) · `biometrics` (S03) · `unlock` (S04) · `topBar`, `ready`, `maintenance`, `offline` (S05) · `scan`, `ios.sheet`, `lookup` (S06) · `balanceCard`, `badge`, `charge`, `card`, `keypad` (S07) · `redeem`, `uncertain` (S08) · `success`, `guest` (S09) · `problem` (S10) · `manual` (S11) · `qr` (S12) · `recent` (S13) · `menu` (S14) · `session`, `forbidden`, `deviceRevoked`, `suspended`, `locked`, `deactivated`, `update` (S15) · `nfcOff`, `camera` (S16) · `intro` (S17) · `a11y` (screen-reader-only labels and announcements) · `nfc.purpose`, `camera.purpose`, `faceId.purpose` (OS usage strings).
- **Binding keys from the brief keep their exact spelling** even where they do not follow the pattern: `getManager`, `offline.title`, `offline.body`, `uncertain.title`, `uncertain.body`, `session.expired`, `card.blocked` …
- Keys are **flat strings**: dots are not nesting. `card.expired` and `card.expired.body` coexist. Resource files convert keys to lowerCamelCase identifiers (`card.expired.body` → `cardExpiredBody`), see [09 §6.5](09-flutter-handoff.md#65-localisation-resources).
- Platform suffixes: `.ios`, `.android`, `.noNfc`; biometric method suffixes `.faceId`, `.touchId`, `.android`.
- Screen-reader-only strings are marked "(a11y)" in the table; they use either the `a11y.` prefix or the element key.
- **Aliases:** where a screen document introduced a second key for a string that already exists, the table lists the alias in Notes and the alias must not be implemented as a separate string.

### 4.2 Placeholders

| Placeholder | Type | Example (DE / EN / BHS) | Notes |
|---|---|---|---|
| `{amount}` | formatted money incl. symbol | € 24,90 / €24.90 / 24,90 € | Always fully formatted (§1.4). Never add "€" around it. |
| `{diff}` | formatted money | € 7,50 | Amount minus balance |
| `{balance}` | formatted money | € 7,60 | Remaining balance in announcements |
| `{count}` | integer | 12 | Inside a plural where the noun changes |
| `{seconds}` / `{minutes}` | integer | 42 | Countdowns in sentences |
| `{time}` | countdown `m:ss` / `h:mm:ss` | 0:42 | Countdowns in buttons and S15; tabular figures |
| `{date}` | formatted date | 26.09.2029 / 26 Sep 2029 / 26. 9. 2029. | §1.5 |
| `{last4}` | 4 digits | 6488 | Used after "•••• " |
| `{number}` | 16 digits formatted | 5285 1058 7098 6488 | S07 header, S11 |
| `{restaurant}` | string ≤ 60 | Trattoria Bella Vista | From `/scan` or account |
| `{name}` | string | Anna Berger | Waiter display name |
| `{reason}` | string (server) | Verloren gemeldet | `blocked_reason`, shown verbatim, max 2 lines |
| `{code}` | 6 chars | 7F3A9C | Support code (§2.5) |
| `{version}` | string | 1.0.0 (142) | Version and build |
| `{n}` | integer | 2 | Intro page, retry attempt |
| `{threshold}` | formatted money | € 100,00 | Hold-to-redeem threshold |
| `{spokenAmount}` | spoken form | 24 Euro 90 | From `a11y.spokenAmount` (§1.4) |

> **Clarification of a brief key.** The brief writes `charge.redeem` (DE) as "€ {amount} einlösen". Because `{amount}` is always fully formatted, the stored string is **"{amount} einlösen"**, which renders exactly "€ 24,90 einlösen" as intended (and "24,90 € einlösen" in de-DE). No other brief string is changed.

---

## 5. Master string table

Single source for every UI string. **Max** = character limit (§1.8) for the longest language after substitution; "—" = no fixed limit (a11y strings, list content). Notes: **B** = binding brief key (wording must not change) · **03a** / **03b** = key introduced by that screen document · **12** = key introduced here · **harmonised** = wording changed from the screen document to meet §1 (the master wording wins; screen documents quote it for illustration only) · **alias** = second key for the same string, not to be implemented.

### 5.1 App and common

| Key | DE | EN | BHS | Max | Notes |
|---|---|---|---|---|---|
| `app.name` | GiftCard Waiter | GiftCard Waiter | GiftCard Waiter | 16 | 12 · launcher label, not translated |
| `common.cancel` | Abbrechen | Cancel | Otkaži | 12 | 03a/03b |
| `common.close` | Schließen | Close | Zatvori | 12 | 03a (a11y on ✕) / 12 (button) |
| `common.back` | Zurück | Back | Nazad | — | 03a · (a11y) |
| `common.done` | Fertig | Done | Gotovo | 12 | 03b |
| `common.tryAgain` | Erneut versuchen | Try again | Pokušaj ponovo | 24 | 03b · §2.7 |
| `common.scanAgain` | Erneut scannen | Scan again | Skeniraj ponovo | 24 | 03b · §2.7 |
| `common.enterNumber` | Kartennummer eingeben | Enter card number | Unesi broj kartice | 24 | 03b · opens S11 |
| `common.editNumber` | Nummer bearbeiten | Edit number | Uredi broj | 24 | 03b · S11 prefilled |
| `common.openSettings` | Einstellungen öffnen | Open Settings | Otvori postavke | 24 | 12 · = `camera.denied.action` (alias) |
| `common.backToSignIn` | Zur Anmeldung | Back to sign in | Nazad na prijavu | 24 | 03a |
| `common.checkAgain` | Erneut prüfen | Check again | Provjeri ponovo | 24 | 12 · alias `suspended.retry` (03a) |
| `common.supportCode` | Code {code} | Code {code} | Kôd {code} | 12 | 12 · alias `problem.supportCode` (03b) · §2.5 |
| `common.supportCode.a11y` | Support-Code {code} | Support code {code} | Kôd za podršku {code} | — | (a11y) · characters read singly |
| `common.copied` | Kopiert | Copied | Kopirano | 24 | 03b · snackbar after long-press on the code |
| `redeem.nothingBooked` | Es wurde nichts gebucht. | Nothing was booked. | Ništa nije knjiženo. | 28 | 03b · harmonised (DE full sentence) |
| `getManager` | Bitte Betriebsleitung holen | Please get a manager | Molimo pozovite menadžera | 28 | **B** · always ends with "." when used in a body |

### 5.2 S01 Splash, startup problem and server address

| Key | DE | EN | BHS | Max | Notes |
|---|---|---|---|---|---|
| `splash.loading` | Wird geladen | Loading | Učitavanje | — | 03a · (a11y), only if splash > 1 s |
| `startup.offline.title` | Keine Internetverbindung | No internet connection | Nema internet veze | 32 | 12 · startup problem (signed out, server unreachable at launch) |
| `startup.offline.body` | Das Handy ist offline. WLAN oder mobile Daten einschalten, dann erneut versuchen. | This phone is offline. Turn on Wi-Fi or mobile data, then try again. | Telefon nije povezan. Uključite Wi-Fi ili mobilne podatke, pa pokušajte ponovo. | 90 | 12 |
| `startup.hostNotFound.title` | Server nicht gefunden | Server not found | Server nije pronađen | 32 | 12 · DNS: the host name does not exist |
| `startup.hostNotFound.body` | Die Adresse {host} existiert nicht. Server-Adresse prüfen. | The address {host} does not exist. Check the server address. | Adresa {host} ne postoji. Provjerite adresu servera. | 90 | 12 |
| `startup.refused.title` | Server nicht gestartet | Server not running | Server nije pokrenut | 32 | 12 · connection refused |
| `startup.refused.body` | Unter {host} antwortet kein Server. Prüfen, ob er läuft und die Adresse stimmt. | Nothing answers at {host}. Check that the server is running and the address is right. | Na adresi {host} ništa ne odgovara. Provjerite radi li server i je li adresa tačna. | 90 | 12 |
| `startup.timeout.title` | Server antwortet nicht | Server not responding | Server ne odgovara | 32 | 12 · timeout / no route |
| `startup.timeout.body` | {host} hat nicht rechtzeitig geantwortet. Netzwerk prüfen, dann erneut versuchen. | {host} did not answer in time. Check the network, then try again. | {host} nije odgovorio na vrijeme. Provjerite mrežu, pa pokušajte ponovo. | 90 | 12 |
| `startup.tls.title` | Keine sichere Verbindung | No secure connection | Nema sigurne veze | 32 | 12 · TLS certificate rejected |
| `startup.tls.body` | Das Zertifikat von {host} wurde abgelehnt. Datum und Uhrzeit am Handy prüfen. | The certificate of {host} was rejected. Check the phone's date and time. | Certifikat servera {host} je odbijen. Provjerite datum i vrijeme na telefonu. | 90 | 12 |
| `startup.serverError.title` | Server gestört | Server problem | Problem na serveru | 32 | 12 · 5xx |
| `startup.serverError.body` | {host} meldet ein Problem (Status {status}). Später erneut versuchen. | {host} reports a problem (status {status}). Try again later. | {host} javlja problem (status {status}). Pokušajte ponovo kasnije. | 90 | 12 |
| `startup.invalidResponse.title` | Falsche Server-Adresse | Wrong server address | Pogrešna adresa servera | 32 | 12 · 404, HTML, redirect, unexpected JSON |
| `startup.invalidResponse.body` | Unter {host} läuft kein GiftCard-Pro-Server. Server-Adresse prüfen. | {host} is not a GiftCard Pro server. Check the server address. | Na adresi {host} nije GiftCard Pro server. Provjerite adresu servera. | 90 | 12 |
| `startup.configuration.title` | App falsch eingerichtet | App not set up correctly | Aplikacija nije ispravno podešena | 32 | 12 · build without a valid API address |
| `startup.configuration.body` | Diese App-Version hat keine gültige Server-Adresse. Bitte Betriebsleitung holen. | This version of the app has no valid server address. Please get a manager. | Ova verzija aplikacije nema važeću adresu servera. Molimo pozovite menadžera. | 90 | 12 |
| `startup.storage.title` | Geschützter Speicher gesperrt | Protected storage unavailable | Zaštićena pohrana nije dostupna | 32 | 12 · secure storage (Keystore / Keychain) failed |
| `startup.storage.body` | Die App kann ihren geschützten Speicher nicht öffnen. Handy neu starten, dann erneut versuchen. | The app cannot open its protected storage. Restart the phone, then try again. | Aplikacija ne može otvoriti zaštićenu pohranu. Ponovo pokrenite telefon, pa pokušajte ponovo. | 100 | 12 |
| `startup.unknown.title` | App konnte nicht starten | The app could not start | Aplikacija se nije pokrenula | 32 | 12 · anything else, start watchdog |
| `startup.unknown.body` | Erneut versuchen. Passiert es wieder, bitte Betriebsleitung holen. | Try again. If it happens again, please get a manager. | Pokušajte ponovo. Ako se ponovi, molimo pozovite menadžera. | 90 | 12 |
| `startup.server` | Server: {url} | Server: {url} | Server: {url} | — | 12 · small print below the actions |
| `startup.detail` | Details: {detail} | Details: {detail} | Detalji: {detail} | — | 12 · technical reason, not translated |
| `startup.environment` | Umgebung: {name} | Environment: {name} | Okruženje: {name} | — | 12 · development and staging builds only |
| `startup.changeServer` | Server ändern | Change server | Promijeni server | 24 | 12 · development and staging builds only |
| `env.development` | Entwicklung | Development | Razvoj | 16 | 12 · environment name |
| `env.staging` | Staging | Staging | Staging | 16 | 12 · environment name |
| `env.production` | Produktion | Production | Produkcija | 16 | 12 · environment name |
| `env.badge.development` | DEV | DEV | DEV | 8 | 12 · corner badge, development builds |
| `env.badge.staging` | STAGING | STAGING | STAGING | 8 | 12 · corner badge, staging builds |
| `env.badge.a11y` | Testumgebung {name}, Server {host}. Lange drücken, um den Server zu ändern. | Test environment {name}, server {host}. Long-press to change the server. | Testno okruženje {name}, server {host}. Dugo pritisnite za promjenu servera. | — | 12 · (a11y) |
| `server.title` | Server-Adresse | Server address | Adresa servera | 32 | 12 · server sheet (development and staging builds) |
| `server.label` | API-Adresse | API address | Adresa API-ja | 24 | 12 · field label |
| `server.help` | Zum Beispiel http://192.168.1.20:8000 (/api/v1 wird ergänzt). | For example http://192.168.1.20:8000 (/api/v1 is added). | Na primjer http://192.168.1.20:8000 (/api/v1 se dodaje). | 90 | 12 · helper text |
| `server.default` | Standard dieser App: {url} | Default of this app: {url} | Zadano u ovoj aplikaciji: {url} | — | 12 |
| `server.save` | Speichern und verbinden | Save and connect | Sačuvaj i poveži | 24 | 12 · signs out, then connects |
| `server.reset` | Standard verwenden | Use default | Koristi zadano | 24 | 12 |
| `server.invalid` | Keine gültige Adresse. Mit http:// oder https:// beginnen. | Not a valid address. Start with http:// or https://. | Adresa nije važeća. Počnite s http:// ili https://. | 90 | 12 · field error |
| `server.httpsRequired` | In dieser Version sind nur https-Adressen erlaubt. | This version only allows https addresses. | Ova verzija dozvoljava samo https adrese. | 90 | 12 · field error (staging) |
| `server.wrongPath` | Die Adresse muss auf /api/v1 enden. | The address must end in /api/v1. | Adresa mora završavati s /api/v1. | 90 | 12 · field error |

The startup problem screen (S01 → problem template) replaces the endless splash: shown when the waiter is signed out and `/app/config` fails at launch, when the build configuration is invalid, when secure storage cannot be opened, or when the launch has not decided after 20 s. Actions: `common.tryAgain`; in development and staging builds also `startup.changeServer`. `{host}` is `host[:port]` of the API address. Signed-in waiters are not blocked (offline handling of S05).

### 5.3 S02 Sign in

| Key | DE | EN | BHS | Max | Notes |
|---|---|---|---|---|---|
| `signIn.title` | Anmelden | Sign in | Prijava | 32 | 03a |
| `signIn.subtitle` | Mit dem Mitarbeiterkonto anmelden | Use your staff account | Prijavite se računom zaposlenika | 48 | 03a |
| `signIn.email.label` | E-Mail | E-mail | E-mail | 20 | 03a |
| `signIn.email.placeholder` | name@beispiel.at | name@example.com | ime@primjer.ba | 28 | 12 · example domains only |
| `signIn.password.label` | Passwort | Password | Lozinka | 20 | 03a · also used in the S15 session sheet |
| `signIn.password.show` | Passwort anzeigen | Show password | Prikaži lozinku | — | 03a · (a11y) |
| `signIn.password.hide` | Passwort verbergen | Hide password | Sakrij lozinku | — | 03a · (a11y) |
| `signIn.forgot` | Passwort vergessen | Forgot password | Zaboravljena lozinka | 24 | 03a · harmonised (no "?" on buttons, §1.7) |
| `signIn.submit` | Anmelden | Sign in | Prijavi se | 24 | 03a |
| `signIn.loading` | Anmeldung läuft | Signing in | Prijava u toku | — | 03a · (a11y) |
| `signIn.noAccess` | Kein Zugang? Die Betriebsleitung legt ihn im Dashboard an. | No login? A manager creates it in the dashboard. | Nemate pristup? Menadžer ga kreira u dashboardu. | 90 | 12 · caption |
| `signIn.error.required` | Pflichtfeld | Required | Obavezno polje | 24 | 12 · inline |
| `signIn.error.emailFormat` | E-Mail-Adresse prüfen | Check the e-mail address | Provjerite e-mail adresu | 32 | 03a |
| `signIn.error.invalid` | E-Mail oder Passwort stimmt nicht. Bitte prüfen und erneut versuchen. | E-mail or password is incorrect. Check both and try again. | E-mail ili lozinka nisu ispravni. Provjerite i pokušajte ponovo. | 90 | 03a · A07 |
| `signIn.error.noPermission` | Dieses Konto kann keine Karten einlösen. Bitte Betriebsleitung holen. | This account can't redeem cards. Please get a manager. | Ovaj račun ne može iskorištavati kartice. Molimo pozovite menadžera. | 90 | 03a · A02 |
| `signIn.error.throttled` | Zu viele Versuche. Erneut möglich in {time}. | Too many attempts. Try again in {time}. | Previše pokušaja. Ponovo za {time}. | 48 | 03a · A08 |
| `signIn.error.server` | Anmelden gerade nicht möglich. Gleich noch einmal versuchen. | Can't sign in right now. Try again in a moment. | Prijava trenutno nije moguća. Pokušajte ponovo za trenutak. | 90 | 03a · A09 · support code below |
| `signIn.offline.body` | Anmelden braucht eine Internetverbindung. | Signing in needs a connection. | Za prijavu je potrebna veza. | 48 | 03a · A09 |

### 5.4 S03 Enable biometrics

| Key | DE | EN | BHS | Max | Notes |
|---|---|---|---|---|---|
| `biometrics.title.faceId` | Mit Face ID entsperren? | Unlock with Face ID? | Otključavati pomoću Face ID-a? | 32 | 03a · question allowed (offer screen) |
| `biometrics.title.touchId` | Mit Touch ID entsperren? | Unlock with Touch ID? | Otključavati pomoću Touch ID-a? | 32 | 03a |
| `biometrics.title.android` | Mit Biometrie entsperren? | Unlock with biometrics? | Otključavati biometrijom? | 32 | 03a |
| `biometrics.body` | Schneller Start in jede Schicht. Das Passwort bleibt als Alternative. | A faster start to every shift. Your password still works as a fallback. | Brži početak svake smjene. Lozinka ostaje kao zamjena. | 90 | 03a |
| `biometrics.enable.faceId` | Face ID verwenden | Use Face ID | Koristi Face ID | 24 | 03a · **B** wording |
| `biometrics.enable.touchId` | Touch ID verwenden | Use Touch ID | Koristi Touch ID | 24 | 03a |
| `biometrics.enable.android` | Biometrie verwenden | Use biometrics | Koristi biometriju | 24 | 03a |
| `biometrics.notNow` | Jetzt nicht | Not now | Ne sada | 24 | 03a · **B** wording |
| `biometrics.reason` | Zum Entsperren von GiftCard Waiter | To unlock GiftCard Waiter | Za otključavanje aplikacije GiftCard Waiter | 48 | 03a · iOS reason / Android prompt title |
| `biometrics.promptSubtitle.android` | Für den Dienst bei {restaurant} | For service at {restaurant} | Za smjenu u restoranu {restaurant} | 48 | 12 · BiometricPrompt subtitle |
| `biometrics.failed` | Nicht bestätigt. Noch einmal versuchen. | Not confirmed. Try again. | Nije potvrđeno. Pokušajte ponovo. | 48 | 03a · P11 |
| `biometrics.notEnrolled.faceId` | Face ID ist nicht eingerichtet. In den Einstellungen einrichten. | Face ID is not set up. Set it up in Settings. | Face ID nije podešen. Podesite ga u postavkama. | 90 | 12 · P10 snackbar |
| `biometrics.notEnrolled.touchId` | Touch ID ist nicht eingerichtet. In den Einstellungen einrichten. | Touch ID is not set up. Set it up in Settings. | Touch ID nije podešen. Podesite ga u postavkama. | 90 | 12 |
| `biometrics.notEnrolled.android` | Keine Biometrie eingerichtet. In den Einstellungen einrichten. | No biometrics set up. Set them up in Settings. | Biometrija nije podešena. Podesite je u postavkama. | 90 | 12 |

### 5.5 S04 Unlock

| Key | DE | EN | BHS | Max | Notes |
|---|---|---|---|---|---|
| `unlock.button.faceId` | Mit Face ID entsperren | Unlock with Face ID | Otključaj pomoću Face ID-a | 28 | 03a |
| `unlock.button.touchId` | Mit Touch ID entsperren | Unlock with Touch ID | Otključaj pomoću Touch ID-a | 28 | 03a |
| `unlock.button.android` | Entsperren | Unlock | Otključaj | 28 | 03a |
| `unlock.usePassword` | Passwort verwenden | Use password | Koristi lozinku | 24 | 03a · **B** wording |
| `unlock.changed` | Biometrie wurde auf diesem Gerät geändert. Bitte mit Passwort anmelden. | Biometrics changed on this device. Sign in with your password. | Biometrija je promijenjena na ovom uređaju. Prijavite se lozinkom. | 90 | 03a · P13 |
| `unlock.lockedOut` | Zu viele Versuche. Passwort verwenden. | Too many attempts. Use the password. | Previše pokušaja. Koristite lozinku. | 48 | 12 · P12 |
| `unlock.pendingCard` | Die Karte wird nach dem Entsperren geöffnet. | The card opens after unlocking. | Kartica se otvara nakon otključavanja. | 48 | 03a · deep link waiting |

### 5.6 S05 Ready, TopBar, offline, maintenance

| Key | DE | EN | BHS | Max | Notes |
|---|---|---|---|---|---|
| `topBar.recent` | Verlauf | Recent | Nedavno | — | 03a · (a11y) |
| `topBar.menu` | Menü, {name} | Menu, {name} | Meni, {name} | — | 03a · (a11y) |
| `ready.android.title` | Karte an das Handy halten | Hold the card to the phone | Prislonite karticu uz telefon | 32 | **B** |
| `ready.android.hint` | Die Karte wird automatisch erkannt | The card is detected automatically | Kartica se automatski prepoznaje | 40 | 03a |
| `ready.ios.button` | Karte scannen | Scan card | Skeniraj karticu | 24 | **B** |
| `ready.ios.hint` | Nach dem Tippen die Karte oben an das iPhone halten | After tapping, hold the card near the top of the iPhone | Nakon dodira prislonite karticu na vrh iPhonea | 60 | 03a · 2 lines |
| `ready.ios.timeout` | Keine Karte erkannt. Zum Wiederholen „Karte scannen" tippen. | No card detected. Tap "Scan card" to try again. | Kartica nije prepoznata. Dodirnite „Skeniraj karticu" za novi pokušaj. | 90 | 03a · P08 |
| `ready.manual` | Kartennummer | Card number | Broj kartice | 16 | 03a · icon + noun (exception to verb + object, §1.2) |
| `ready.qr` | QR-Code | QR code | QR kôd | 16 | 03a · icon + noun |
| `ready.firstCardTip.android` | Tipp: Die NFC-Antenne sitzt meist hinten oben, nahe der Kamera. | Tip: the NFC antenna is usually at the top of the back, near the camera. | Savjet: NFC antena je obično gore na poleđini, blizu kamere. | 90 | 03a |
| `ready.firstCardTip.ios` | Tipp: Die Karte flach an die Oberkante halten, nahe der Kamera. | Tip: hold the card flat against the top edge, near the camera. | Savjet: držite karticu ravno uz gornji rub, blizu kamere. | 90 | 03a |
| `ready.noNfc.title` | QR-Code auf der Karte scannen | Scan the QR code on the card | Skenirajte QR kôd na kartici | 32 | 03a · P02 |
| `ready.noNfc.hint` | Dieses Gerät hat kein NFC. QR-Code oder Kartennummer verwenden. | This device has no NFC. Use the QR code or the card number. | Ovaj uređaj nema NFC. Koristite QR kôd ili broj kartice. | 90 | 03a |
| `ready.noNfc.button` | QR-Code scannen | Scan QR code | Skeniraj QR kôd | 24 | 03a |
| `ready.offline.tap` | Keine Verbindung – Karte kann nicht geprüft werden | No connection – the card can't be checked | Nema veze – kartica se ne može provjeriti | 60 | 03a · L09 · harmonised (EN en dash) |
| `ready.online` | Wieder verbunden | Connected again | Veza je ponovo uspostavljena | 32 | 03a · snackbar / announcement |
| `offline.title` | Keine Verbindung | No connection | Nema veze | 28 | **B** · also S10 network title |
| `offline.body` | Einlösen braucht Internet, damit nie doppelt gebucht wird. | Redeeming needs a connection so nothing is ever booked twice. | Za iskorištavanje je potrebna veza, da se ništa ne knjiži dvaput. | 90 | **B** |
| `maintenance.default` | Geplante Wartung: Einlösen kann kurz nicht möglich sein. | Scheduled maintenance: redeeming may be briefly unavailable. | Planirano održavanje: iskorištavanje može kratko biti nedostupno. | 90 | 03a · A12 fallback when the server text is missing |
| `maintenance.dismiss` | Hinweis schließen | Dismiss notice | Zatvori obavijest | — | 03a · (a11y) |
| `ready.newCard` | Neue Gutscheinkarte | New gift card | Nova poklon kartica | 24 | S20 · managers and owners only · button on S05 |
| `issue.title` | Neue Gutscheinkarte | New gift card | Nova poklon kartica | 24 | S20 · screen title |
| `issue.amount.label` | Kartenwert | Card value | Vrijednost kartice | 24 | S20 · above the amount |
| `issue.email.label` | E-Mail des Gastes (optional) | Guest e-mail (optional) | E-mail gosta (neobavezno) | 32 | S20 |
| `issue.email.helper` | Der Gast erhält eine Bestätigung. | The guest receives a confirmation. | Gost dobija potvrdu. | 60 | S20 |
| `issue.email.invalid` | Bitte eine gültige E-Mail-Adresse eingeben. | Enter a valid e-mail address. | Unesite ispravnu e-mail adresu. | 60 | S20 · field error |
| `issue.amount.range` | Der Kartenwert muss zwischen {min} und {max} liegen. | The card value must be between {min} and {max}. | Vrijednost kartice mora biti između {min} i {max}. | 60 | S20 · server INVALID_AMOUNT |
| `issue.create` | Karte anlegen · {amount} | Create card · {amount} | Kreiraj karticu · {amount} | 32 | S20 · primary |
| `issue.creating` | Karte wird angelegt … | Creating card … | Kartica se kreira … | 32 | S20 · button progress |
| `issue.program.title` | Leere Karte an das Handy halten | Hold a blank card to the phone | Prislonite praznu karticu uz telefon | 36 | S20 · programming |
| `issue.program.body` | Ruhig an die Rückseite halten, bis das Häkchen erscheint. | Keep it still on the back of the phone until the check mark appears. | Držite je mirno na poleđini telefona dok se ne pojavi kvačica. | 90 | S20 |
| `issue.program.retap` | Karte kurz abheben und erneut anhalten. | Lift the card and hold it to the phone again. | Podignite karticu i ponovo je prislonite. | 60 | S20 · hint |
| `issue.step.check` | Chip prüfen | Check tag | Provjera čipa | 24 | S20 · step |
| `issue.step.write` | Kartenlink schreiben | Write card link | Upis linka kartice | 24 | S20 · step |
| `issue.step.verify` | Zurücklesen und prüfen | Read back and verify | Očitavanje i provjera | 24 | S20 · step |
| `issue.step.save` | Chip der Karte zuordnen | Save chip to card | Spremanje čipa uz karticu | 28 | S20 · step |
| `issue.card` | Karte {number} | Card {number} | Kartica {number} | 32 | S20 · card number, grouped |
| `issue.success.title` | Karte bereit | Card ready | Kartica spremna | 20 | S20 |
| `issue.success.balance` | Guthaben {amount} | Balance {amount} | Stanje {amount} | 32 | S20 |
| `issue.success.verified` | NFC-Chip beschrieben und geprüft | NFC tag written and verified | NFC čip upisan i provjeren | 40 | S20 |
| `issue.success.noTag` | Noch kein Chip. Später im Dashboard beschreiben. | No tag yet. Program it later in the dashboard. | Još nema čipa. Upišite ga kasnije na kontrolnoj ploči. | 60 | S20 · after “Program later” |
| `issue.success.another` | Weitere Karte verkaufen | Sell another card | Prodaj još jednu karticu | 28 | S20 · secondary |
| `issue.later` | Später beschreiben | Program later | Upiši kasnije | 24 | S20 · keeps the card without a tag |
| `issue.nfcOff` | NFC einschalten, um den Chip zu beschreiben. | Turn on NFC to program the tag. | Uključite NFC da biste upisali čip. | 60 | S20 |
| `issue.createFailed.title` | Karte nicht angelegt | Card not created | Kartica nije kreirana | 28 | S20 |
| `issue.createFailed.body` | Es wurde keine Karte angelegt. Verbindung prüfen und erneut versuchen. | No card was created. Check the connection and try again. | Nijedna kartica nije kreirana. Provjerite vezu i pokušajte ponovo. | 90 | S20 · definitive answer |
| `issue.createUncertain.body` | Die Antwort kam nicht an. Erneut versuchen, die Karte wird nicht doppelt angelegt. | The answer did not arrive. Try again, the card will not be created twice. | Odgovor nije stigao. Pokušajte ponovo, kartica se neće kreirati dvaput. | 90 | S20 · same idempotency key |
| `issue.notAllowed.title` | Nicht erlaubt | Not allowed | Nije dozvoljeno | 28 | S20 · 403 |
| `issue.notAllowed.body` | Dieses Konto kann auf diesem Handy keine Karten verkaufen. Ab- und wieder anmelden oder das Dashboard verwenden. | This account cannot sell cards on this phone. Sign out and in again, or use the dashboard. | Ovaj račun ne može prodavati kartice na ovom telefonu. Odjavite se i ponovo prijavite ili koristite kontrolnu ploču. | 120 | S20 · 403 |
| `issue.tagFailed.title` | Chip nicht beschrieben | Tag not programmed | Čip nije upisan | 28 | S20 · the card exists, nothing was saved to it |
| `issue.tag.otherCard` | Dieser Chip gehört zur Karte {number}. Bitte einen leeren Chip verwenden. | This tag belongs to card {number}. Use a blank tag. | Ovaj čip pripada kartici {number}. Koristite prazan čip. | 90 | S20 · check refused, conflict |
| `issue.tag.refused` | Dieser Chip kann für diese Karte nicht verwendet werden. Bitte einen leeren Chip verwenden. | This tag cannot be used for this card. Use a blank tag. | Ovaj čip se ne može koristiti za ovu karticu. Koristite prazan čip. | 90 | S20 · check refused |
| `issue.tag.unsupported` | Dieser Chiptyp wird nicht unterstützt. Bitte NTAG213, 215 oder 216 verwenden. | This tag type is not supported. Use NTAG213, 215 or 216. | Ovaj tip čipa nije podržan. Koristite NTAG213, 215 ili 216. | 90 | S20 |
| `issue.tag.readOnly` | Dieser Chip ist gesperrt und kann nicht beschrieben werden. | This tag is locked and cannot be written. | Ovaj čip je zaključan i ne može se upisati. | 90 | S20 |
| `issue.tag.moved` | Der Chip wurde bewegt. Ruhig halten und erneut versuchen. | The tag moved away. Hold it still and try again. | Čip se pomjerio. Držite ga mirno i pokušajte ponovo. | 90 | S20 · write / read failed, timeout |
| `issue.tag.verifyFailed` | Der Chip konnte nicht geprüft werden. Mit demselben Chip erneut versuchen. | The tag could not be verified. Try again with the same tag. | Čip nije moguće provjeriti. Pokušajte ponovo s istim čipom. | 90 | S20 · read-back mismatch |
| `issue.tag.network` | Keine Verbindung zum Server. Erneut versuchen. | No connection to the server. Try again. | Nema veze sa serverom. Pokušajte ponovo. | 90 | S20 · check / save without answer |

Rows marked **S20** belong to *New gift card* (managers and owners only, see [02 §4.4a](02-information-architecture-and-journey.md)); waiters never see them.

### 5.7 S06 Scanning and iOS system sheet

| Key | DE | EN | BHS | Max | Notes |
|---|---|---|---|---|---|
| `ios.sheet.alert` | Karte oben an das iPhone halten | Hold the card near the top of the iPhone | Prislonite karticu na vrh iPhonea | 48 | **B** |
| `ios.sheet.found` | Karte gefunden | Card found | Kartica pronađena | 48 | 03a · **B** wording |
| `ios.sheet.readFailed` | Karte nicht gelesen. Erneut versuchen. | Couldn't read the card. Try again. | Kartica nije pročitana. Pokušajte ponovo. | 48 | 03a |
| `ios.sheet.multiple` | Mehrere Karten erkannt. Nur eine Karte halten. | More than one card detected. Hold only one. | Prepoznato više kartica. Držite samo jednu. | 48 | 03a · P06 |
| `ios.sheet.timeoutSoon` | Noch keine Karte. Karte flach oben an das iPhone halten. | No card yet. Hold it flat near the top of the iPhone. | Još nema kartice. Prislonite je ravno na vrh iPhonea. | 60 | 03a · P07 |
| `scan.notCard` | Keine Gutscheinkarte | This is not a gift card | Ovo nije poklon kartica | 32 | 03a · harmonised ("Gutscheinkarte", "poklon kartica", §1.3) · L10 |
| `scan.readFailed.title` | Karte konnte nicht gelesen werden | Couldn't read the card | Kartica nije pročitana | 32 | 03a · L11 |
| `scan.readFailed.body` | Karte eine Sekunde ruhig halten. | Hold it still for a second. | Držite je mirno jednu sekundu. | 48 | 03a |
| `scan.detected` | Karte erkannt | Card detected | Kartica prepoznata | — | 03a · (a11y) announcement |
| `scan.lookingUp` | Karte wird gesucht … | Looking up card … | Tražimo karticu … | 32 | 03a |
| `scan.slow` | Suche dauert länger … | Still looking … | Još tražimo … | 32 | 03a · L08 · alias `lookup.stillLooking` (03b) |
| `scan.unavailable` | NFC gerade nicht verfügbar. Kartennummer oder QR-Code verwenden. | NFC isn't available right now. Use the card number or QR code. | NFC trenutno nije dostupan. Koristite broj kartice ili QR kôd. | 90 | 03a · P09 |

### 5.8 S07 Charge — balance card, keypad, amount

| Key | DE | EN | BHS | Max | Notes |
|---|---|---|---|---|---|
| `balanceCard.overline` | Gutscheinkarte | Gift card | Poklon kartica | 16 | 12 · uppercased by style |
| `balanceCard.validUntil` | Gültig bis {date} | Valid until {date} | Vrijedi do {date} | 24 | 12 |
| `balanceCard.noExpiry` | Ohne Ablaufdatum | No expiry date | Bez roka važenja | 24 | 12 · `expires_at` null |
| `balanceCard.masked` | •••• {last4} | •••• {last4} | •••• {last4} | 9 | 12 |
| `balanceCard.a11y` | Gutscheinkarte {restaurant}. Guthaben {spokenAmount}. Karte endet auf {last4}. | Gift card {restaurant}. Balance {spokenAmount}. Card ending {last4}. | Poklon kartica {restaurant}. Stanje {spokenAmount}. Kartica završava na {last4}. | — | 12 · (a11y) · validity and status appended |
| `charge.cardNumber.a11y` | Kartennummer {number} | Card number {number} | Broj kartice {number} | — | 12 · (a11y) |
| `a11y.charge.close` | Karte schließen | Close card | Zatvori karticu | — | 03b · (a11y) |
| `a11y.amount` | Betrag {spokenAmount} | Amount {spokenAmount} | Iznos {spokenAmount} | — | 03b · (a11y) AmountDisplay |
| `charge.enterAmount` | Betrag eingeben | Enter amount | Unesi iznos | 24 | 03b · disabled button at € 0,00 |
| `charge.redeem` | {amount} einlösen | Redeem {amount} | Iskoristi {amount} | 26+amt | **B** (§4.2 clarification) |
| `charge.redeemFull` | Gesamtes Guthaben einlösen · {amount} | Redeem full balance · {amount} | Iskoristi cijeli iznos · {amount} | 26+amt | **B** · breaks at " · " |
| `charge.hold` | Halten zum Einlösen | Hold to redeem | Držite za iskorištavanje | 26 | **B** · HoldButton hint ≥ `holdToConfirmThresholdCents` |
| `a11y.hold.hint` | Doppeltippen und halten zum Einlösen | Double-tap and hold to redeem | Dvaput dodirnite i držite za iskorištavanje | — | 03b · (a11y) |
| `charge.redeeming` | {amount} wird eingelöst … | Redeeming {amount} … | Iskorištava se {amount} … | 26+amt | 03b · S08 button label |
| `charge.overBalance` | {diff} mehr als das Guthaben | {diff} more than the balance | {diff} više od stanja | 40 | **B** |
| `a11y.overBalance` | {diff} mehr als das Guthaben. Einlösen nicht möglich. | {diff} more than the balance. Redeem not available. | {diff} više od stanja. Iskorištavanje nije moguće. | — | 03b · (a11y) |
| `charge.useBalance` | Guthaben verwenden · {amount} | Use balance · {amount} | Iskoristi stanje · {amount} | 20+amt | **B** · QuickAmountChip |
| `charge.useMax` | Maximum verwenden · {amount} | Use maximum · {amount} | Iskoristi maksimum · {amount} | 20+amt | 03b · R10 |
| `charge.maxSingle` | Max. {amount} pro Einlösung | Max. {amount} per redemption | Najviše {amount} po iskorištavanju | 40 | 03b · R10 |
| `charge.fullOnly` | Hier ist nur das gesamte Guthaben einlösbar. | Only the full balance can be redeemed here. | Ovdje se može iskoristiti samo cijelo stanje. | 90 | 03b · partial disabled, R11 |
| `charge.velocity.title` | Limit für diese Karte erreicht | Limit for this card reached | Dosegnut je limit za ovu karticu | 32 | 03b · R14 |
| `charge.velocity.bodyTime` | Wieder möglich in {minutes} min. Oder Betriebsleitung holen. | Possible again in {minutes} min. Or get a manager. | Ponovo moguće za {minutes} min. Ili pozovite menadžera. | 90 | 03b · harmonised ("min" without period) |
| `charge.rateLimited` | Zu viele Anfragen – wieder möglich in {seconds} s | Too many requests – possible again in {seconds} s | Previše zahtjeva – ponovo moguće za {seconds} s | 60 | 03b · R15 · harmonised (EN en dash) |
| `charge.switchCard.message` | Andere Karte erkannt – wechseln? | Different card detected – Switch? | Prepoznata je druga kartica – zamijeniti? | 48 | 03b · **B** EN wording (brief §2) · P14 |
| `charge.switchCard.action` | Wechseln | Switch | Zamijeni | 12 | 03b · **B** |
| `charge.switchCard.keep` | Behalten | Keep | Zadrži | 12 | 03b |
| `charge.switchCard.dialogTitle` | Andere Karte erkannt | Different card detected | Prepoznata je druga kartica | 32 | 12 · Dialog fallback with screen reader ([03b §2.18](03b-screens-charge-redeem-success-problems.md)) |
| `keypad.doubleZero` | Doppelnull | Double zero | Dvije nule | — | 03a · (a11y) · alias `a11y.keypad.doubleZero` (03b) |
| `keypad.delete` | Löschen | Delete | Obriši | — | 03a · (a11y) · alias `a11y.keypad.delete` (03b) |
| `keypad.delete.hint` | Lange drücken, um alles zu löschen | Long press to clear | Dugo pritisnite za brisanje svega | — | 03a · (a11y) · alias `a11y.keypad.deleteHint` (03b) |
| `keypad.cleared` | Betrag gelöscht | Amount cleared | Iznos obrisan | — | 12 · (a11y) announcement |
| `keypad.maxReached` | Höchstbetrag erreicht | Maximum amount reached | Dosegnut najveći iznos | — | 12 · (a11y) · 7 digits |

### 5.9 S07 Card-state banners and badges

| Key | DE | EN | BHS | Max | Notes |
|---|---|---|---|---|---|
| `badge.active` | Aktiv | Active | Aktivna | 16 | 12 · a11y only (active cards show no badge) |
| `badge.inactive` | Nicht aktiviert | Not activated | Nije aktivirana | 16 | 12 |
| `badge.redeemed` | Aufgebraucht | Used up | Potrošena | 16 | 12 · status `redeemed` or balance 0 |
| `badge.blocked` | Gesperrt | Blocked | Blokirana | 16 | 12 |
| `badge.expired` | Abgelaufen | Expired | Istekla | 16 | 12 |
| `badge.replaced` | Ersetzt | Replaced | Zamijenjena | 16 | 12 |
| `card.blocked` | Karte gesperrt | Card blocked | Kartica blokirana | 28 | **B** · danger · body = `getManager` |
| `card.blocked.reason` | Grund: {reason} | Reason: {reason} | Razlog: {reason} | 90 | 03b · only if `blocked_reason` present |
| `card.expired` | Karte abgelaufen | Card expired | Kartica istekla | 28 | **B** · warning |
| `card.expired.body` | Abgelaufen am {date}. Bitte Betriebsleitung holen. | Expired on {date}. Please get a manager. | Istekla {date}. Molimo pozovite menadžera. | 90 | 03b · harmonised (escalation wording §2.6) |
| `card.inactive` | Karte noch nicht aktiviert | Card not activated yet | Kartica još nije aktivirana | 28 | **B** · warning |
| `card.inactive.body` | Erst nach der Aktivierung einlösbar. Bitte Betriebsleitung holen. | It can be redeemed once activated. Please get a manager. | Može se iskoristiti tek nakon aktivacije. Molimo pozovite menadžera. | 90 | 03b |
| `card.replaced` | Karte wurde ersetzt | Card was replaced | Kartica je zamijenjena | 28 | **B** · warning |
| `card.replaced.body` | Das Guthaben ist auf der neuen Karte. Gast nach der neuen Karte fragen. | The balance is on the new card. Ask the guest for the new card. | Stanje je na novoj kartici. Zamolite gosta za novu karticu. | 90 | 03b |
| `card.empty` | Kein Guthaben mehr | No balance left | Nema više stanja | 28 | **B** · warning |
| `card.empty.body` | Diese Karte ist vollständig eingelöst. | This card has been fully used. | Ova kartica je potpuno iskorištena. | 90 | 03b |

### 5.10 S08 Redeeming

| Key | DE | EN | BHS | Max | Notes |
|---|---|---|---|---|---|
| `redeem.slow` | Verbindung langsam – neuer Versuch | Connection slow – retrying | Spora veza – ponovni pokušaj | 36 | 03b · R02 · harmonised (EN en dash) |
| `uncertain.title` | Verbindung unterbrochen | Connection interrupted | Veza prekinuta | 28 | **B** · R03/R04 |
| `uncertain.body` | Wird geprüft … Es wird nie doppelt gebucht. | Checking … Nothing is ever booked twice. | Provjeravamo … Ništa se ne knjiži dvaput. | 90 | **B** · also the helper in R02 |
| `uncertain.retrying` | Versuch {n} von 3 | Attempt {n} of 3 | Pokušaj {n} od 3 | 20 | 03b |
| `uncertain.guestHint` | Dem Gast sagen: „Einen Moment bitte, die Einlösung wird bestätigt." | Tell the guest: "One moment please, the redemption is being confirmed." | Recite gostu: „Trenutak, molim, iskorištavanje se potvrđuje." | 90 | 03b · **harmonised** (never "Zahlung / payment / plaćanje", §1.3) |
| `uncertain.failedBody` | Noch nicht bestätigt. Erneut versuchen – es wird nie doppelt gebucht. | Not confirmed yet. Try again – nothing is ever booked twice. | Još nije potvrđeno. Pokušajte ponovo – ništa se ne knjiži dvaput. | 90 | 03b · R04 |
| `uncertain.cancelled` | Nicht bestätigt. Vor dem nächsten Einlösen die Karte erneut scannen. | Not confirmed. Scan the card again before redeeming. | Nije potvrđeno. Prije novog iskorištavanja ponovo skenirajte karticu. | 90 | 03b · R05 · **harmonised** (no "charging / terećenje") |
| `uncertain.cancelledGuestHint` | Dem Gast sagen: „Die Einlösung ist noch nicht bestätigt. Wir prüfen das Guthaben, bevor neu eingelöst wird." | Tell the guest: "The redemption isn't confirmed yet. We'll check the balance before redeeming again." | Recite gostu: „Iskorištavanje još nije potvrđeno. Provjerit ćemo stanje prije novog iskorištavanja." | 120 | 03b · **harmonised** (vocabulary); 3 lines allowed (quoted speech) |
| `redeem.balanceChanged` | Guthaben hat sich geändert: jetzt {amount} | Balance changed: now {amount} | Stanje se promijenilo: sada {amount} | 48 | 03b · R06 |
| `redeem.tapAgain` | Bitte noch einmal einlösen. | Please tap Redeem again. | Molimo ponovo dodirnite Iskoristi. | 48 | 03b · R13 |

### 5.11 S09 Success

| Key | DE | EN | BHS | Max | Notes |
|---|---|---|---|---|---|
| `success.title` | Eingelöst | Redeemed | Iskorišteno | 20 | **B** |
| `success.remaining` | Restguthaben {amount} | Remaining balance {amount} | Preostalo stanje {amount} | 36 | **B** |
| `success.empty` | Karte ist jetzt leer | Card is now empty | Kartica je sada prazna | 28 | 03b · replaces the remaining line at 0 |
| `success.next.ios` | Nächste Karte scannen | Scan next card | Skeniraj sljedeću karticu | 24 | **B** |
| `success.next.android` | Nächste Karte einfach antippen | Just tap the next card | Samo prislonite sljedeću karticu | 32 | **B** |
| `success.showGuest` | Dem Gast zeigen | Show guest | Pokaži gostu | 24 | 03b · presentation mode |
| `success.card` | Karte •••• {last4} | Card •••• {last4} | Kartica •••• {last4} | 20 | 12 · caption |
| `guest.remaining.label` | Restguthaben | Remaining balance | Preostalo stanje | 20 | 03b · Show-guest mode |
| `a11y.success` | Eingelöst {amount}, Restguthaben {balance} | Redeemed {amount}, remaining balance {balance} | Iskorišteno {amount}, preostalo stanje {balance} | — | 03b · (a11y) assertive; amounts in spoken form |

### 5.12 S10 Problem screens

| Key | DE | EN | BHS | Max | Notes |
|---|---|---|---|---|---|
| `problem.notFound.title` | Karte nicht gefunden | Card not found | Kartica nije pronađena | 32 | **B** · L01/L02 |
| `problem.notFound.body` | Diese Karte ist nicht im System. Karte prüfen oder nach einer anderen fragen. | This card is not in the system. Check the card or ask the guest for another one. | Ova kartica nije u sistemu. Provjerite karticu ili zamolite drugu. | 90 | 03b |
| `problem.notFound.bodyManual` | Keine Karte mit dieser Nummer. Ziffern prüfen. | No card with this number. Check the digits. | Nema kartice s ovim brojem. Provjerite cifre. | 90 | 03b |
| `problem.foreign.title` | Karte eines anderen Lokals | Card from another restaurant | Kartica drugog restorana | 32 | **B** · L03 |
| `problem.foreign.body` | Sie ist nur im ausstellenden Lokal einlösbar. | It can only be redeemed at the restaurant that issued it. | Može se iskoristiti samo u restoranu koji ju je izdao. | 90 | 03b |
| `problem.verify.title` | Karte konnte nicht geprüft werden | Card could not be verified | Kartica nije mogla biti provjerena | 32 (2 lines) | **B** · L04 |
| `problem.verify.body` | Karte vorerst nicht annehmen. Bitte Betriebsleitung holen. | Do not accept this card for now. Please get a manager. | Zasad ne prihvatajte ovu karticu. Molimo pozovite menadžera. | 90 | 03b · harmonised (escalation wording §2.6) |
| `problem.throttled.title` | Zu viele Scans | Too many scans | Previše skeniranja | 32 | 03b · L05 |
| `problem.throttled.body` | Scannen ist in Kürze wieder möglich. | Scanning is possible again shortly. | Skeniranje će uskoro ponovo biti moguće. | 90 | 03b |
| `problem.scanAgainIn` | Erneut scannen · {time} | Scan again · {time} | Skeniraj ponovo · {time} | 24 | 03b · disabled countdown button |
| `problem.network.body` | Karte konnte nicht geprüft werden. WLAN oder mobile Daten prüfen, dann erneut versuchen. | The card could not be checked. Check Wi-Fi or mobile data, then try again. | Kartica nije provjerena. Provjerite Wi-Fi ili mobilne podatke, pa pokušajte ponovo. | 90 | 03b · L06 (title = `offline.title`) |
| `problem.server.title` | Dienst gerade nicht erreichbar | Service not available right now | Servis trenutno nije dostupan | 32 | 03b · **harmonised** (title states what happened, §2.1) |
| `problem.server.body` | Das Problem liegt nicht an der Karte. Gleich erneut versuchen. | The problem is not the card. Try again in a moment. | Problem nije do kartice. Pokušajte ponovo za trenutak. | 90 | 03b · **harmonised** (no "wir/uns" in the UI, §1.2) |

### 5.13 S11 Manual entry

| Key | DE | EN | BHS | Max | Notes |
|---|---|---|---|---|---|
| `manual.title` | Kartennummer | Card number | Broj kartice | 28 | 03a |
| `manual.helper` | 16 Ziffern auf der Rückseite der Karte | 16 digits on the back of the card | 16 cifara na poleđini kartice | 40 | 03a |
| `manual.counter` | {count} von 16 | {count} of 16 | {count} od 16 | 12 | 03a · tabular figures |
| `manual.submit` | Karte suchen | Look up card | Pronađi karticu | 24 | 03a · enabled at 16 digits |
| `manual.error.invalid` | Kartennummer prüfen | Check the card number | Provjerite broj kartice | 32 | 03a |
| `manual.error.paste` | Keine gültige Kartennummer zum Einfügen | No valid card number to paste | Nema ispravnog broja kartice za lijepljenje | 48 | 03a |

### 5.14 S12 QR scan

| Key | DE | EN | BHS | Max | Notes |
|---|---|---|---|---|---|
| `qr.title` | QR-Code scannen | Scan QR code | Skeniraj QR kôd | 28 | 03a |
| `qr.hint` | Kamera auf den QR-Code der Karte richten | Point the camera at the QR code on the card | Usmjerite kameru na QR kôd kartice | 48 | 03a |
| `qr.notCard` | Dieser QR-Code gehört zu keiner Gutscheinkarte | This QR code isn't a gift card | Ovaj QR kôd nije poklon kartica | 48 | 03a · harmonised (vocabulary) · L10 |
| `qr.dark` | Zu dunkel? Licht einschalten. | Too dark? Turn on the light. | Pretamno? Uključite svjetlo. | 32 | 03a |
| `qr.torchOn` | Licht einschalten | Turn on light | Uključi svjetlo | — | 03a · (a11y) |
| `qr.torchOff` | Licht ausschalten | Turn off light | Isključi svjetlo | — | 03a · (a11y) |
| `qr.manual` | Kartennummer eingeben | Enter card number | Unesi broj kartice | 24 | 03a · = `common.enterNumber` (alias) |

### 5.15 S13 Recent and Recent detail

| Key | DE | EN | BHS | Max | Notes |
|---|---|---|---|---|---|
| `recent.title` | Verlauf | Recent | Nedavno | 28 | 03b · harmonised (DE = `topBar.recent`) |
| `recent.summary` | {count, plural, one {# Einlösung} other {# Einlösungen}} · {amount} heute | {count, plural, one {# redemption} other {# redemptions}} · {amount} today | {count, plural, one {# iskorištavanje} few {# iskorištavanja} other {# iskorištavanja}} · {amount} danas | 40 | 03b · HistoryCard |
| `recent.row.remaining` | Rest {amount} | Left {amount} | Ostatak {amount} | 20 | 03b |
| `recent.row.empty` | Karte jetzt leer | Card now empty | Kartica sada prazna | 20 | 03b |
| `recent.row.a11y` | {time}, Karte endet auf {last4}, {amount} eingelöst, Restguthaben {balance} | {time}, card ending {last4}, {amount} redeemed, remaining balance {balance} | {time}, kartica završava na {last4}, iskorišteno {amount}, preostalo stanje {balance} | — | 12 · (a11y) |
| `recent.empty.title` | Noch keine Einlösungen | No redemptions yet | Još nema iskorištavanja | 32 | 03b |
| `recent.empty.body` | Einlösungen von diesem Handy erscheinen hier bis 04:00 Uhr. | Redemptions from this phone appear here until 04:00. | Iskorištavanja s ovog telefona prikazuju se ovdje do 04:00 h. | 90 | 03b · harmonised (time format §1.5) |
| `recent.footer` | Nur dieses Handy · wird um 04:00 Uhr geleert | This phone only · cleared at 04:00 | Samo ovaj telefon · briše se u 04:00 h | 48 | 03b · harmonised (time format) |
| `recent.limit` | Die letzten 200 Einlösungen | Latest 200 redemptions | Posljednjih 200 iskorištavanja | 40 | 03b |
| `recent.detail.title` | Einlösung | Redemption | Iskorištavanje | 28 | 03b |
| `recent.detail.time` | Zeit | Time | Vrijeme | 20 | 03b |
| `recent.detail.card` | Karte | Card | Kartica | 20 | 03b |
| `recent.detail.amount` | Betrag | Amount | Iznos | 20 | 03b |
| `recent.detail.remaining` | Restguthaben | Remaining balance | Preostalo stanje | 20 | 03b |
| `recent.detail.transaction` | Buchung | Transaction | Transakcija | 20 | 03b · value: last 6 chars of the transaction id |
| `recent.detail.supportCode` | Support-Code | Support code | Kôd za podršku | 20 | 03b |
| `recent.detail.reverseHint` | Falscher Betrag? Die Betriebsleitung kann ihn im Dashboard stornieren. | Wrong amount? A manager can reverse it in the dashboard. | Pogrešan iznos? Menadžer ga može stornirati u dashboardu. | 90 | 03b · **B** (EN from brief §1) · harmonised BHS ("dashboard", §1.3) |

### 5.16 S14 Menu

| Key | DE | EN | BHS | Max | Notes |
|---|---|---|---|---|---|
| `menu.close` | Menü schließen | Close menu | Zatvori meni | — | 03a · (a11y) |
| `menu.account` | Konto | Account | Račun | 24 | 12 · value: name and e-mail |
| `menu.restaurant` | Lokal | Restaurant | Restoran | 24 | 03a |
| `menu.device` | Gerät | Device | Uređaj | 24 | 03a · value: device name |
| `menu.section.settings` | Einstellungen | Settings | Postavke | 24 | 03a |
| `menu.theme` | Darstellung | Appearance | Izgled | 24 | 03a |
| `menu.theme.system` | Wie System | Match system | Kao sistem | 14 | 03a |
| `menu.theme.light` | Hell | Light | Svijetlo | 10 | 03a |
| `menu.theme.dark` | Dunkel | Dark | Tamno | 10 | 03a |
| `menu.sunlightTip` | Im Freien ist das helle Design besser lesbar. | Outdoors, the light theme is easier to read. | Na otvorenom je svijetla tema čitljivija. | 60 | 03a |
| `menu.sound` | Töne | Sounds | Zvukovi | 24 | 03a |
| `menu.haptics` | Vibration | Haptics | Vibracija | 24 | 03a |
| `menu.haptics.unavailable` | Auf diesem Gerät nicht verfügbar | Not available on this device | Nije dostupno na ovom uređaju | 40 | 03a |
| `menu.keepScreenOn` | Bildschirm anlassen | Keep screen on | Ekran uvijek uključen | 24 | 03a |
| `menu.keepScreenOn.caption` | Während Scannen und Einlösen | While scanning and redeeming | Tokom skeniranja i iskorištavanja | 40 | 03a |
| `menu.help` | Hilfe | Help | Pomoć | 24 | 03a |
| `menu.version` | Version {version} | Version {version} | Verzija {version} | 32 | 03a |
| `menu.signOut` | Abmelden | Sign out | Odjavi se | 24 | 03a |
| `menu.signOut.confirm.title` | Abmelden? | Sign out? | Odjaviti se? | 28 | 03a · Dialog |
| `menu.signOut.confirm.body` | Der Schichtverlauf wird von diesem Gerät gelöscht. | The shift history on this device will be deleted. | Historija smjene na ovom uređaju bit će izbrisana. | 90 | 03a |
| `menu.signOut.confirm.action` | Abmelden | Sign out | Odjavi se | 24 | 12 · DangerButton (cancel = `common.cancel`) |

### 5.17 S15 Session and account states

| Key | DE | EN | BHS | Max | Notes |
|---|---|---|---|---|---|
| `session.expired` | Sitzung abgelaufen | Session expired | Sesija je istekla | 28 | **B** · A01 |
| `session.expired.body` | Zum Weitermachen erneut anmelden. | Sign in again to continue. | Prijavite se ponovo za nastavak. | 90 | 03a |
| `session.expired.action` | Erneut anmelden | Sign in again | Ponovo se prijavi | 24 | 03a |
| `forbidden.title` | Keine Berechtigung zum Einlösen | No permission to redeem | Nema dozvole za iskorištavanje | 32 | 12 · A03 |
| `forbidden.body` | Dieses Konto kann keine Karten mehr einlösen. Bitte Betriebsleitung holen. | This account can no longer redeem cards. Please get a manager. | Ovaj račun više ne može iskorištavati kartice. Molimo pozovite menadžera. | 90 | 12 |
| `deviceRevoked.title` | Gerät wurde entfernt | This device was removed | Uređaj je uklonjen | 32 | 03a · A04 |
| `deviceRevoked.body` | Das Gerät ist nicht mehr für dieses Lokal freigegeben. Bitte Betriebsleitung holen. | It's no longer allowed for this restaurant. Please get a manager. | Uređaj više nije odobren za ovaj restoran. Molimo pozovite menadžera. | 90 | 03a · harmonised (escalation wording §2.6) |
| `deviceRevoked.action` | Anmelden | Sign in | Prijavi se | 24 | 03a |
| `suspended.title` | Einlösen ist pausiert | Redeeming is paused | Iskorištavanje je pauzirano | 32 | 03a · A05 |
| `suspended.body` | Das Konto des Lokals ist pausiert. Bitte Betriebsleitung holen. | The restaurant's account is paused. Please get a manager. | Račun restorana je pauziran. Molimo pozovite menadžera. | 90 | 03a |
| `locked.title` | Konto vorübergehend gesperrt | Account temporarily locked | Račun je privremeno zaključan | 32 | 03a · A06 |
| `locked.body` | Zu viele Anmeldeversuche. Erneut möglich in {time}. | Too many sign-in attempts. Try again in {time}. | Previše pokušaja prijave. Ponovo za {time}. | 90 | 03a |
| `locked.button` | Erneut in {time} | Try again in {time} | Ponovo za {time} | 24 | 03a · disabled |
| `locked.over` | Anmelden ist wieder möglich | You can sign in again | Prijava je ponovo moguća | — | 03a · (a11y) |
| `deactivated.title` | Konto deaktiviert | Account deactivated | Račun je deaktiviran | 32 | 03a · A10 |
| `deactivated.body` | Dieses Konto kann nicht mehr verwendet werden. Bitte Betriebsleitung holen. | This account can no longer be used. Please get a manager. | Ovaj račun se više ne može koristiti. Molimo pozovite menadžera. | 90 | 03a |
| `update.title` | Update erforderlich | Update required | Potrebno ažuriranje | 32 | 03a · A11 |
| `update.body` | Diese Version wird nicht mehr unterstützt. Zum Weiterarbeiten aktualisieren. | This version is no longer supported. Update to keep redeeming. | Ova verzija više nije podržana. Ažurirajte za nastavak rada. | 90 | 03a |
| `update.action` | Jetzt aktualisieren | Update now | Ažuriraj sada | 24 | 03a |

### 5.18 S16 Permission states

| Key | DE | EN | BHS | Max | Notes |
|---|---|---|---|---|---|
| `nfcOff.title` | NFC ist aus | NFC is off | NFC je isključen | 32 | 03a · P01 |
| `nfcOff.body` | NFC einschalten, um Karten zu scannen. | Turn on NFC to scan cards. | Uključite NFC za skeniranje kartica. | 90 | 03a |
| `nfcOff.action` | NFC einschalten | Turn on NFC | Uključi NFC | 24 | 03a |
| `nfcOff.on` | NFC ist an. Bereit zum Scannen. | NFC is on. Ready to scan. | NFC je uključen. Spremno za skeniranje. | — | 03a · (a11y) |
| `camera.denied.title` | Kamerazugriff ist aus | Camera access is off | Pristup kameri je isključen | 32 | 03a · P03 |
| `camera.denied.body` | Kamera in den Einstellungen erlauben, um QR-Codes zu scannen. | Allow camera access in Settings to scan QR codes. | Dozvolite pristup kameri u postavkama za skeniranje QR kodova. | 90 | 03a |
| `camera.denied.action` | Einstellungen öffnen | Open Settings | Otvori postavke | 24 | 03a |
| `camera.restricted.body` | Die Kamera ist auf diesem Gerät gesperrt. Kartennummer verwenden. | The camera is restricted on this device. Use the card number. | Kamera je ograničena na ovom uređaju. Koristite broj kartice. | 90 | 03a · P04 |
| `camera.unavailable.title` | Kamera nicht verfügbar | Camera not available | Kamera nije dostupna | 32 | 12 · P05 |
| `camera.unavailable.body` | Andere Apps mit Kamera schließen oder Kartennummer eingeben. | Close other apps using the camera or enter the card number. | Zatvorite druge aplikacije s kamerom ili unesite broj kartice. | 90 | 12 |

### 5.19 S17 First-run intro

| Key | DE | EN | BHS | Max | Notes |
|---|---|---|---|---|---|
| `intro.skip` | Überspringen | Skip | Preskoči | 16 | 03a |
| `intro.next` | Weiter | Next | Dalje | 24 | 03a |
| `intro.start` | Loslegen | Start | Počni | 24 | 03a |
| `intro.page` | Seite {n} von 3 | Page {n} of 3 | Stranica {n} od 3 | — | 03a · (a11y) |
| `intro.1.title.android` | Karte antippen | Tap the card | Prislonite karticu | 28 | 03a |
| `intro.1.body.android` | Die Karte an die Rückseite halten. Das Guthaben erscheint in unter einer Sekunde. | Hold the card to the back of the phone. The balance appears in under a second. | Prislonite karticu na poleđinu telefona. Stanje se pojavi za manje od sekunde. | 90 | 03a · **harmonised** (brand guide: "unter einer Sekunde" instead of "sofort") |
| `intro.1.title.ios` | Scannen, dann Karte halten | Tap Scan, then hold the card | Skenirajte, pa prislonite karticu | 32 | 03a |
| `intro.1.body.ios` | „Karte scannen" tippen, dann die Karte oben an das iPhone halten. | Tap "Scan card", then hold the card near the top of the iPhone. | Dodirnite „Skeniraj karticu", zatim prislonite karticu na vrh iPhonea. | 90 | 03a |
| `intro.1.title.noNfc` | QR-Code scannen | Scan the QR code | Skenirajte QR kôd | 28 | 03a |
| `intro.1.body.noNfc` | Kamera auf den QR-Code richten oder die Kartennummer eingeben. | Point the camera at the QR code or type the card number. | Usmjerite kameru na QR kôd ili unesite broj kartice. | 90 | 03a |
| `intro.2.title` | Betrag eingeben, einlösen | Type the amount, redeem | Unesite iznos, iskoristite | 32 | 03a |
| `intro.2.body` | Guthaben sehen, Betrag tippen, fertig. Ab {threshold} zum Bestätigen gedrückt halten. | See the balance, type the amount, done. From {threshold}, press and hold to confirm. | Pogledajte stanje, unesite iznos, gotovo. Od {threshold} držite za potvrdu. | 90 | 03a |
| `intro.3.title` | Nie doppelt gebucht | Never booked twice | Nikad dvaput knjiženo | 28 | 03a |
| `intro.3.body` | Eingelöst wird nur mit Verbindung. Alle Einlösungen der Schicht stehen unter „Verlauf". | Redeeming only works online. Your shift's redemptions are under "Recent". | Iskorištavanje radi samo uz vezu. Iskorištavanja iz smjene su pod „Nedavno". | 90 | 03a |

### 5.20 Screen-reader announcements and spoken forms

| Key | DE | EN | BHS | Politeness | Notes |
|---|---|---|---|---|---|
| `a11y.spokenAmount` | {euros} Euro {cents} | {euros, plural, one {# euro} other {# euros}} {cents} | {euros, plural, one {# euro} few {# eura} other {# eura}} {cents} | — | 12 · cents omitted when 0; "{cents} Cent / cents / centi" when euros = 0 (§1.4) |
| `a11y.cardLoaded` | {restaurant}. Guthaben {spokenAmount}. | {restaurant}. Balance {spokenAmount}. | {restaurant}. Stanje {spokenAmount}. | assertive | 12 · S07 opened; status appended if not active |
| `a11y.problem` | {title}. {body} | {title}. {body} | {title}. {body} | assertive | 12 · every S10/S15 screen and banner |
| `a11y.ready` | Bereit für die nächste Karte | Ready for the next card | Spremno za sljedeću karticu | polite | 12 · return to S05 |
| `a11y.scanAvailable` | Scannen wieder möglich | Scanning available again | Skeniranje ponovo moguće | polite | 12 · throttle end ([03b §5.2](03b-screens-charge-redeem-success-problems.md)) |
| `a11y.redeemAvailable` | Einlösen wieder möglich | Redeem available again | Iskorištavanje ponovo moguće | polite | 12 · rate/velocity countdown end |

Other announcements use the visible string: `scan.detected`, `a11y.success`, `ready.online`, `locked.over`, `nfcOff.on`, `keypad.cleared`, `keypad.maxReached`.

### 5.21 OS usage strings

Delivered through the platforms' own localisation files (iOS `InfoPlist.strings`), see [09 §7.3](09-flutter-handoff.md#73-infoplist-usage-descriptions).

| Key | DE | EN | BHS | Notes |
|---|---|---|---|---|
| `nfc.purpose` | NFC wird zum Lesen von Gutscheinkarten verwendet. | NFC is used to read gift cards. | NFC se koristi za čitanje poklon kartica. | 03a · harmonised (vocabulary) · NFC reader usage (iOS) |
| `camera.purpose` | Die Kamera wird nur zum Scannen von QR-Codes auf Gutscheinkarten verwendet. | The camera is only used to scan QR codes on gift cards. | Kamera se koristi samo za skeniranje QR kodova na poklon karticama. | 03a · harmonised (vocabulary) · camera usage |
| `faceId.purpose` | Face ID wird nur zum Entsperren der App verwendet. | Face ID is only used to unlock the app. | Face ID se koristi samo za otključavanje aplikacije. | 12 · Face ID usage (iOS) |

### 5.22 Key count and alias register

The table holds **348 keys** (§5.1–5.21) — the single list to implement. Aliases below exist in screen documents and resolve to the master key; they are not separate strings.

| Alias (document) | Master key |
|---|---|
| `lookup.stillLooking` (03b) | `scan.slow` |
| `a11y.keypad.doubleZero`, `a11y.keypad.delete`, `a11y.keypad.deleteHint` (03b) | `keypad.doubleZero`, `keypad.delete`, `keypad.delete.hint` |
| `problem.supportCode` (03b) | `common.supportCode` |
| `suspended.retry` (03a) | `common.checkAgain` |
| `camera.denied.action` (03a) — kept as its own key for S16 layout, same text as | `common.openSettings` |
| `qr.manual` (03a) — kept as its own key, same text as | `common.enterNumber` |

---

## 6. Translation and review checklist

- [ ] Every new string has a key in §5 before it ships; screen documents never hold the only copy.
- [ ] DE: no "Sie/du/Ihr/dein", no "Zahlung", no "Fehler" in titles, Austrian terms (Lokal, Betriebsleitung, Jänner).
- [ ] EN: sentence case, British spelling, no "payment", no "error" in titles.
- [ ] BHS: ijekavian Latin (provjerite, sljedeći, cijeli, vrijeme), formal plural in instructions, short imperative on buttons; reviewed by a native speaker from BiH or Croatia and one from Serbia (Latin script).
- [ ] No exclamation marks; ellipsis is U+2026 with a preceding no-break space.
- [ ] Every amount placeholder is `{amount}`-type and fully formatted; no literal "€" next to a placeholder.
- [ ] Plurals in ICU with the right categories (BHS: one/few/other).
- [ ] Length checked at 320 pt width, 100 % and 200 % text size, in the longest language.
- [ ] Every problem string has: title (what happened), body (what to do), action; "nothing booked" where money could be feared lost.
- [ ] All `.a11y` labels present; decorative images hidden.
- [ ] Binding brief keys (**B**) unchanged character for character (apart from the documented `charge.redeem` clarification).

---

Version 1.0 · September 2026 · GiftCard Waiter design specification
