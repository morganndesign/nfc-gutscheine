# 00 · Design Brief — GiftCard Waiter (binding source of truth)

*The brief every other document in this folder was written from. Documents cite it as "brief §n". The resolved conflicts register in [13 §7](13-future-and-design-review.md) clarifies details the brief left open.*

All specification documents are written from this brief. Do not contradict it; do not invent new screens,
features, tokens or copy keys beyond it without marking them clearly as "Proposal (not part of v1)".
All documents are Markdown in English (the design and engineering language). UI strings are given in German (primary, Austria), English and BHS (Bosnian/Croatian/Serbian).
NO code (no Dart, no Flutter widgets, no pseudo-code classes). Describe behaviour, values, states, rules.
Tables, ASCII wireframes and precise numbers are encouraged. Do not repeat content that belongs to another
document — cross-link it (relative links to the file names below).

## 0. Context (existing system — verified)

- GiftCard Pro: SaaS for restaurants (Austria first) to issue and redeem physical gift cards with NFC chip + QR.
  The card stores **only** a URL `https://<domain>/c/<UUID v4>`; balance lives on the server.
- Card number: 16 digits, formatted `5285 1058 7098 6488`. Waiter screens show it masked `•••• 6488` except on
  the charge screen header, where the full formatted number is shown in tertiary text (the waiter may need to read
  it to a manager).
- NFC chips: NTAG213/215/216 (URL + chip UID binding against clones) and NTAG 424 DNA (URL carries one-time SUN
  signature `picc`/`cmac`; replay-proof). QR-only printed cards exist.
- Backend API (REST, JSON, cents). Waiter permissions: `cards.scan` + `cards.redeem` only (no reload, no block,
  no history, no reversal).
  - `POST /api/v1/scan` body `{method: nfc|qr|link|manual, token?: <url>, card_number?: <digits>, nfc_uid?: "04:A2:…"}`
    → `{id, restaurant_name, card_number (formatted), status: active|inactive|redeemed|blocked|expired|replaced,
    currency, balance (cents), expires_at, is_expired, blocked_reason, allow_partial_redemption,
    actions: {redeem, reload, history, block, activate}}`. No customer data is ever returned.
  - `POST /api/v1/cards/{id}/redeem` body `{amount (cents), reference?, note?}`, header `Idempotency-Key` (UUID,
    required; same key on retry never books twice; replay returns `replayed: true`) → `{data: {card, transaction}}`.
  - Headers on every call: `X-Device-Id` (stable random id per install), `X-Request-Id` (per request, UUID).
  - Error codes (HTTP → code): 401 UNAUTHENTICATED · 403 FORBIDDEN, RESTAURANT_SUSPENDED, DEVICE_REVOKED,
    CARD_FOREIGN_RESTAURANT, NFC_UID_MISMATCH, NFC_SIGNATURE_INVALID, NFC_REPLAY_DETECTED · 404 CARD_NOT_FOUND ·
    409 INVALID_CARD_STATE, IDEMPOTENCY_CONFLICT · 422 INSUFFICIENT_BALANCE, INVALID_AMOUNT, CARD_BLOCKED,
    CARD_EXPIRED, CARD_NOT_REDEEMABLE, VALIDATION_FAILED · 423 ACCOUNT_LOCKED (retry_after s) ·
    429 TOO_MANY_REQUESTS, SCAN_THROTTLED (retry_after), VELOCITY_LIMIT_EXCEEDED · 5xx server.
  - Restaurant settings relevant to the waiter: currency (EUR), allow_partial_redemption, max single redemption
    (not yet exposed to clients — see Backend prerequisites), brand_color (hex, default #0F172A), locale (de-AT,
    de-DE, de-CH, en-GB, en-US), time zone.
- Measured today (web app): card lookup ~0.1 s server time; full redeem flow ~0.5 s system time.

## 1. Product definition (decided)

- Name: **GiftCard Waiter** (working name; follows the platform name decision). Native iOS (iPhone, iPad) and
  Android (phones, tablets). Portrait-first; landscape supported on tablets and large phones only as specified.
- Job: **scan a gift card → redeem an amount → next guest.** Nothing else.
- **In scope v1:** sign in, biometric unlock, NFC scan (Android continuous, iPhone per-scan sheet), QR scan
  (camera), manual card number entry, charge (card details + amount on ONE screen), redeem, success, all error
  states, shift history ("Recent", local to device), minimal menu (account, restaurant, device name, theme,
  sound, haptics, help, sign out), 30-second first-run intro, offline/network handling, session handling,
  forced-update and maintenance states.
- **Out of scope v1 (never show):** reload, block, card creation, customer data, reports, team, settings of the
  restaurant, reversals, tips, receipts/printing, cash register integration.
- Card details and amount entry are **one screen** ("Charge") — the balance card sits at the top, the keypad
  below. This saves a transition and a tap; the user flow "Card Details → Enter Amount" happens on one surface.
- **No confirmation screen.** The Redeem button always states the exact amount ("Redeem € 24,90").
  **Hold-to-redeem** (press and hold 600 ms with a filling progress ring) is required when the amount is
  **≥ € 100,00** (constant `holdToConfirmThresholdCents = 10000`, fixed in v1). Below: single tap.
- **No undo in the app** (reversals need a manager in the dashboard). The Success screen does not mention
  mistakes; the Recent detail sheet contains the line "Wrong amount? A manager can reverse it in the dashboard."
- **Never redeem offline.** No offline queue. Money moves only with a server confirmation.
- Idempotency: one `Idempotency-Key` per redeem attempt (generated when the Redeem action starts); reused for
  every automatic/manual retry of the same attempt until success or a definitive 4xx; a new key only after the
  amount or card changes or a definitive error.
- Auto-return from Success to Ready after **4 s** (progress hairline shows the countdown); any tap or a new card
  tap (Android) interrupts immediately.
- **Partial redemption disabled** by restaurant → keypad hidden; amount fixed to full balance; button
  "Redeem full balance € 32,50".
- Amount > balance → button disabled, inline message "€ 7,50 more than the balance" + chip "Use balance € 32,50".
- **Recent (shift history):** bottom sheet from Ready screen, lists redemptions made **on this device by the
  signed-in waiter since the start of the current business day (04:00 local)**, built locally from redeem
  responses (no server endpoint needed; waiters lack `transactions.view`). Max 200 rows; cleared on sign-out and
  at 04:00. Row: time, `•••• 6488`, amount, remaining balance. Tap → detail sheet. Read-only.
- **Devices & people:** v1 assumes a personal or shift-assigned phone. Biometric unlock belongs to the device.
  Shared-device quick switching (staff PIN) is a Future consideration (needs backend).

## 2. Platform behaviour (decided)

- **Android:** NFC *reader mode* while the Ready, Success and Charge screens are visible (app foreground):
  continuous listening, platform sound suppressed, app plays its own feedback **after** a successful read.
  Tapping a new card on the Charge screen (amount 0) or Success screen replaces the current card (with a 300 ms
  cross-fade and the "card detected" haptic). If an amount is already typed on Charge, a new tap shows a snackbar
  "Different card detected — Switch?" with action "Switch" (prevents charging the wrong card).
  NFC off → Ready shows the "NFC is off" state with a button that deep-links to NFC settings.
- **iPhone (iOS 13+, iPhone 7+ for reading; UID read via tag reader session for NTAG):** reading requires Apple's
  **system NFC sheet**. The Ready screen shows a large "Scan card" button (thumb zone). Tap → system sheet with
  our alert text "Hold the card near the top of the iPhone." → on read, sheet shows ✓ "Card found" and dismisses
  (≈ 0.3–0.6 s) → Charge screen. Session timeout (≈ 60 s) → back to Ready silently with hint text. Success screen
  primary action on iPhone = "Scan next card" (opens the sheet directly, 1 tap). Background tag reading /
  universal links: tapping a card to a locked or idle iPhone opens `https://<domain>/c/<token>` → the app opens
  straight on the Charge screen for that card (method `link`) if the user is unlocked; otherwise after unlock.
- **iPad / Android tablets:** iPad has no NFC → QR (camera) and manual entry only; tablet layouts per
  responsive spec (two-pane on Charge in landscape).
- **Biometrics:** Face ID / Touch ID (iOS), BiometricPrompt class 3 strong/class 2 allowed (Android). Device
  passcode fallback via OS. No custom PIN in v1.
- **Unlock policy:** biometric (if enabled) on cold start and when the app returns from background after
  **> 15 min**; token lifetime 30 days rolling, device-bound; sign-out clears token + Recent.
- **Keep screen awake** while on Ready/Charge/Success during service (setting "Keep screen on", default ON).
- **Orientation:** phones portrait-locked; tablets all orientations.
- **Minimum OS:** iOS 16, Android 9 (API 28). Recommend Android devices with NFC antenna near the top-back.

## 3. Timing budget (target < 5 s from tap to ready-for-next)

| Step | Android | iPhone |
|---|---|---|
| Open app (warm, unlocked) → Ready | 0.4 s | 0.4 s |
| Start scan | 0 (always listening) | tap "Scan card" 0.4 s + sheet 0.3 s |
| Card read + lookup | 0.3 s read + ≤ 0.4 s API | 0.5 s read + ≤ 0.4 s API |
| Transition to Charge | 0.24 s | 0.24 s |
| Type amount (4 digits) | ~1.2 s | ~1.2 s |
| Tap Redeem → server → Success | 0.1 + ≤ 0.5 s | same |
| Success visible to guest | 0.8 s (can tap next card immediately) | 0.8 s |
| **Total (typical)** | **≈ 3.5 s** | **≈ 4.5 s** |
Rules: lookup shows a skeleton after 150 ms (never a blank); if lookup > 3 s → "Still looking…" text;
> 10 s → network error state. Redeem button shows spinner after 150 ms; > 8 s → "Connection slow" state with
automatic idempotent retry.

## 4. Screen inventory (IDs are binding; use them in all documents)

| ID | Screen | Notes |
|---|---|---|
| S01 | Splash | brand mark, ≤ 600 ms, no spinner unless > 1 s |
| S02 | Sign in | e-mail + password; forgot password opens web page |
| S03 | Enable biometrics | once after first sign-in; "Use Face ID" / "Not now" |
| S04 | Unlock | biometric prompt auto-shown; fallback "Use password" |
| S05 | Ready (Home) | the resting screen; variants per platform & state |
| S06 | Scanning | Android: inline reading state on S05; iPhone: system sheet |
| S07 | Charge | balance card + amount keypad + Redeem; all card states |
| S08 | Redeeming | in-place state of S07 (button → progress) incl. hold-to-redeem |
| S09 | Success | big check, amount, remaining balance, auto-return |
| S10 | Problem screens | full-screen card problems & scan errors (variants) |
| S11 | Manual entry | 16-digit number with keypad |
| S12 | QR scan | camera viewfinder |
| S13 | Recent (sheet) + Recent detail (sheet) | local shift history |
| S14 | Menu (sheet) | account, restaurant, device, theme, sound, haptics, keep screen on, help, sign out |
| S15 | Session & account states | session expired sheet, device revoked, restaurant suspended, account locked, account deactivated, update required, maintenance banner |
| S16 | Permission states | NFC off (Android), NFC unsupported, camera denied, notifications not used |
| S17 | First-run intro | 3 cards, skippable, ≤ 30 s |

**Card states on S07/S10 (variants):** Active (normal) · Active + partial disabled · Zero balance (status
redeemed or balance 0) · Blocked (show blocked_reason if present) · Expired (is_expired or status expired) ·
Inactive (not activated yet) · Replaced · Amount > balance (inline, not a screen) · Amount > max single
redemption (inline after server 422, message) · Velocity limit (429) · Wrong restaurant (403 foreign) ·
Card not found (404) · Verification failed (UID mismatch / signature invalid / replay) · Scan throttled (429
with countdown) · Network error (lookup) · Redemption uncertain (network lost during redeem, auto-retrying) ·
Server error · Session expired (401) · Device revoked · Restaurant suspended · Offline (S05 variant).
Rule: problems that concern **the card** are shown on S07 with the balance card visible and a status banner
(so the waiter can tell the guest the balance/status) — blocked, expired, inactive, replaced, zero balance.
Problems where **no card data** is available (not found, wrong restaurant, verification failed, throttled,
network, server) are **S10 full-screen problem screens**.

## 5. Design system tokens (binding names and values)

Naming: `color.bg.canvas`, `space.4`, `radius.l`, `type.amount.xl`, `motion.duration.base`, etc.

**Typography** — Geist Sans (UI) and Geist Mono (card numbers only on S11), bundled with the app (SIL OFL 1.1).
Numbers always with tabular figures (`tnum`). German/BHS glyph coverage required (ä ö ü ß č ć š ž đ).
| Token | Size/Line | Weight | Tracking | Use |
|---|---|---|---|---|
| type.amount.xl | 64/68 | 600 | −2.5 % | amount being typed (S07) |
| type.amount.l | 48/52 | 600 | −2 % | success amount (S09) |
| type.balance | 40/44 | 600 | −2 % | balance on balance card |
| type.title.l | 28/34 | 600 | −1 % | screen titles (S02, S10) |
| type.title.m | 22/28 | 600 | −0.5 % | sheet titles |
| type.body.l | 17/24 | 400 | 0 | primary body |
| type.body.m | 15/22 | 400 | 0 | secondary body |
| type.label | 15/20 | 600 | 0 | buttons (large 17/22) |
| type.caption | 13/18 | 500 | +0.5 % | meta, card number |
| type.overline | 11/14 | 600 | +8 % uppercase | "GIFT CARD" on balance card |
| type.key | 30/36 | 500 | 0 | keypad digits |
Dynamic Type / font scale supported to 200 % for body/caption/labels; amounts scale to max 130 % and then
shrink-to-fit (min 40 pt) — never truncate an amount.

**Spacing** (4-pt base): space.0=0, .1=4, .2=8, .3=12, .4=16, .5=20, .6=24, .8=32, .10=40, .12=48, .16=64.
Screen side margin: 20 (width < 400 pt), 24 (400–599), 32 (tablet ≥ 600). Safe areas always respected.

**Radius:** radius.xs=8 (chips, badges), .s=12 (inputs, snackbar), .m=16 (small buttons, rows), .l=20 (large
buttons, keypad keys), .xl=28 (balance card, sheets content cards), .sheet=32 (top corners of bottom sheets),
.full=999 (pills, round buttons). Balance card uses a continuous (squircle) corner on iOS and a matched rounded
rect on Android.

**Touch targets:** minimum 56 × 56 pt for every interactive element (exceeds 44/48). Keypad keys ≥ 72 pt high
(64 on compact height < 700 pt), primary CTA 64 pt high (56 on compact height), full width. Glove-friendly: key
gaps ≥ 8 pt, no two destructive/primary actions adjacent.

**Colour** (light / dark). Default theme: **follow system**; user can force Light or Dark in Menu.
| Token | Light | Dark | Use |
|---|---|---|---|
| color.bg.canvas | #FAFAFA | #0A0A0C | screen background |
| color.bg.surface | #FFFFFF | #141417 | sheets, cards |
| color.bg.raised | #FFFFFF | #1C1C21 | sheet on sheet, snackbar (dark) |
| color.bg.key | #F1F1F3 | #1E1E23 | keypad keys, secondary buttons |
| color.bg.keyPressed | #E4E4E7 | #2A2A31 | pressed key |
| color.fg.primary | #18181B | #F4F4F5 | text |
| color.fg.secondary | #52525B | #A1A1AA | secondary text |
| color.fg.tertiary | #71717A | #8B8B94 | meta text (≥ 4.5:1 on canvas) |
| color.fg.onAccent | #FFFFFF | #0A0A0C | text on primary button |
| color.border.subtle | #E4E4E7 | #26262B | dividers |
| color.border.strong | #A1A1AA | #3F3F46 | input borders, focus rings base |
| color.action.primary | #18181B | #F4F4F5 | primary button background |
| color.action.primaryPressed | #27272A | #D4D4D8 | pressed |
| color.brand.ink | #0F172A | #0F172A | default balance card colour |
| color.accent.saffron | #E8A33D | #F0B454 | NFC rings, focus accents, hold-progress ring; never text on light |
| color.accent.saffronText | #B45309 | #F0B454 | saffron as text |
| color.success | #047857 | #34D399 | success icon/text |
| color.success.bg | #ECFDF5 | #052E22 | success background tint |
| color.danger | #B91C1C | #F87171 | blocked, errors |
| color.danger.bg | #FEF2F2 | #2A0E0E | danger banner |
| color.warning | #B45309 | #FBBF24 | expired, inactive, zero balance |
| color.warning.bg | #FFFBEB | #2A1E06 | warning banner |
| color.info | #1D4ED8 | #93C5FD | neutral info (offline, tips) |
| color.info.bg | #EFF6FF | #0B1A33 | info banner |
| color.scrim | rgba(10,10,12,0.48) | rgba(0,0,0,0.64) | behind sheets |
**High-contrast / sunlight:** OS "Increase contrast" (iOS) / "High contrast text" (Android) switches
fg.secondary→fg.primary, border.subtle→border.strong, and increases status banner text weight to 600.

**Balance card** (the hero component): 1.586:1 ratio (ID-1), full width minus margins, max height 220 pt on
phones; background = restaurant `brand_color` (fallback color.brand.ink) with a subtle top-left to bottom-right
sheen (+6 % luminance to −6 %); text colour auto-chosen (white on dark brand colours, #0A0A0C on light ones;
must pass 4.5:1, else fall back to ink background). Content: overline "GIFT CARD" · restaurant name (title.m) ·
balance (type.balance) · `•••• 6488` + "Valid until 26.09.2029" (caption) · NFC glyph top-right (3 saffron arcs)
· status badge bottom-left when not active. States desaturate: blocked/expired/replaced → 40 % desaturated with
status badge.

**Elevation** (light theme shadows; dark theme uses surface colour steps + 1 px border.subtle instead):
elev.0 none · elev.1 `0 1 2 rgba(0,0,0,.04)` · elev.2 `0 4 16 rgba(0,0,0,.08)` (balance card) · elev.3
`0 12 32 rgba(0,0,0,.12)` (sheets, snackbar) · elev.card-brand `0 16 40 <brand colour at 28 %>`.

**Motion** — durations: motion.instant 90 ms · fast 160 · base 240 · slow 360 · emphasis 520; curves:
motion.ease.standard (0.2, 0, 0, 1) · decelerate (0, 0, 0, 1) · accelerate (0.3, 0, 1, 1) · spring.card
(response 0.42 s, damping 0.82) · spring.soft (response 0.55, damping 0.9). Reduce Motion: replace movement
with 160 ms cross-fades, disable ring pulse (static rings), keep progress indicators.

**Haptics** (names used everywhere):
| Token | iOS | Android |
|---|---|---|
| haptic.key | UIImpactFeedbackGenerator .light (intensity 0.5) | KEYBOARD_TAP |
| haptic.select | UISelectionFeedbackGenerator | CLOCK_TICK |
| haptic.cardDetected | UIImpactFeedbackGenerator .medium | CONFIRM (API 30+), else 20 ms vibrate |
| haptic.success | UINotificationFeedbackGenerator .success | CONFIRM + 40 ms pattern [0,20,60,30] |
| haptic.warning | .warning | pattern [0,30,80,30] |
| haptic.error | .error | REJECT (API 30+), else pattern [0,40,60,40,60,40] |
| haptic.holdTick | .rigid at 33/66/100 % of hold | CLOCK_TICK at 33/66/100 % |
Haptics can be switched off in Menu (default ON). Respect system haptic settings.

**Sound** (default ON, plays through the notification/"alert" channel, respects iOS silent switch and Android
ringer mode "silent/vibrate"; max ~ -18 LUFS; each ≤ 400 ms):
| Token | Character |
|---|---|
| sound.cardDetected | single soft glass tick, 1.6 kHz, 60 ms |
| sound.success | two-note rising chime (E6 → B6), 280 ms, gentle decay — the signature sound |
| sound.warning | single mid tone 660 Hz, 150 ms |
| sound.error | two low tones 330 Hz, 2 × 90 ms, 60 ms gap |
No sound for key presses. Sound switch in Menu.

## 6. Components (binding names)

Buttons: `PrimaryButton` (large 64 / regular 56), `SecondaryButton`, `TertiaryButton` (text), `DangerButton`
(only in Menu sign-out confirmation), `HoldButton` (PrimaryButton variant with ring), `IconButton` (56).
Inputs: `Keypad` (3×4: 1–9, 00, 0, ⌫; long-press ⌫ clears), `AmountDisplay` (POS entry: digits shift in from the
right; "2 4 9 0" → € 24,90; max 7 digits = € 99.999,99), `QuickAmountChip` ("Use balance € 32,50"),
`TextField` (sign-in), `CardNumberField` (S11, groups of 4).
Display: `BalanceCard`, `StatusBadge` (active, inactive, redeemed, blocked, expired, replaced), `StatusBanner`
(info/warning/danger/success), `NfcScanAnimation` (3 concentric saffron arcs + breathing glow), `ProgressRing`,
`Skeleton` (balance card + lines), `Spinner` (inline 20 pt, 2 pt stroke), `SuccessMark` (drawn check in circle),
`CountdownHairline` (2 pt line across top of S09), `TransactionRow`, `HistoryCard` (Recent summary header:
"12 redemptions · € 486,40 today"), `Snackbar`, `BottomSheet`, `Dialog` (only: sign-out confirm, switch-card
confirm fallback), `Banner` (maintenance/offline), `EmptyState`, `ProblemScreen` (S10 template),
`TopBar` (restaurant name + waiter initials avatar + Recent + Menu), `Avatar` (initials).

## 7. Copy rules (binding)

- Primary language German (Austria), then English and BHS (ijekavian, Latin). The app follows the phone language
  if it is de/en/bs/hr/sr, else English; restaurant locale decides number/currency format.
- Tone: short, calm, instructive; no exclamation marks; no blame ("Card not found", not "You scanned a wrong card").
- German: neutral imperative/infinitive style without addressing ("Karte an das Handy halten"), no "Sie/du" in
  the waiter app. BHS: imperative plural/formal ("Prislonite karticu").
- Money: de-AT "€ 24,90", en "€24.90" (en-GB) — follow restaurant locale; BHS "24,90 €".
- Button labels = verb + object: "Redeem € 24,90" / "€ 24,90 einlösen" / "Iskoristi 24,90 €".
- Every error = what happened + what to do (one line each). Max 2 lines of body text on a problem screen.
- Key strings (use exactly):
| Key | DE | EN | BHS |
|---|---|---|---|
| ready.android.title | Karte an das Handy halten | Hold the card to the phone | Prislonite karticu uz telefon |
| ready.ios.button | Karte scannen | Scan card | Skeniraj karticu |
| ios.sheet.alert | Karte oben an das iPhone halten | Hold the card near the top of the iPhone | Prislonite karticu na vrh iPhonea |
| charge.redeem | € {amount} einlösen | Redeem {amount} | Iskoristi {amount} |
| charge.redeemFull | Gesamtes Guthaben einlösen · {amount} | Redeem full balance · {amount} | Iskoristi cijeli iznos · {amount} |
| charge.hold | Halten zum Einlösen | Hold to redeem | Držite za iskorištavanje |
| charge.overBalance | {diff} mehr als das Guthaben | {diff} more than the balance | {diff} više od stanja |
| charge.useBalance | Guthaben verwenden · {amount} | Use balance · {amount} | Iskoristi stanje · {amount} |
| success.title | Eingelöst | Redeemed | Iskorišteno |
| success.remaining | Restguthaben {amount} | Remaining balance {amount} | Preostalo stanje {amount} |
| success.next.ios | Nächste Karte scannen | Scan next card | Skeniraj sljedeću karticu |
| success.next.android | Nächste Karte einfach antippen | Just tap the next card | Samo prislonite sljedeću karticu |
| problem.notFound.title | Karte nicht gefunden | Card not found | Kartica nije pronađena |
| problem.foreign.title | Karte eines anderen Lokals | Card from another restaurant | Kartica drugog restorana |
| problem.verify.title | Karte konnte nicht geprüft werden | Card could not be verified | Kartica nije mogla biti provjerena |
| card.blocked | Karte gesperrt | Card blocked | Kartica blokirana |
| card.expired | Karte abgelaufen | Card expired | Kartica istekla |
| card.inactive | Karte noch nicht aktiviert | Card not activated yet | Kartica još nije aktivirana |
| card.replaced | Karte wurde ersetzt | Card was replaced | Kartica je zamijenjena |
| card.empty | Kein Guthaben mehr | No balance left | Nema više stanja |
| offline.title | Keine Verbindung | No connection | Nema veze |
| offline.body | Einlösen braucht Internet, damit nie doppelt gebucht wird. | Redeeming needs a connection so nothing is ever booked twice. | Za iskorištavanje je potrebna veza, da se ništa ne knjiži dvaput. |
| uncertain.title | Verbindung unterbrochen | Connection interrupted | Veza prekinuta |
| uncertain.body | Wird geprüft … Es wird nie doppelt gebucht. | Checking … Nothing is ever booked twice. | Provjeravamo … Ništa se ne knjiži dvaput. |
| session.expired | Sitzung abgelaufen | Session expired | Sesija je istekla |
| getManager | Bitte Betriebsleitung holen | Please get a manager | Molimo pozovite menadžera |

## 8. Backend prerequisites (to list in handoff, not to design)

1. Token login for native apps: `POST /auth/token {email, password, device_id, device_name, platform}` →
   device-bound Sanctum token with abilities `cards.scan`, `cards.redeem`, 30-day rolling expiry, revocable via
   Devices. Refresh on use. (Current API has cookie SPA login and owner-created API tokens only.)
2. Expose `max_single_redemption` (cents or null) and `brand_color`, `locale` in the scan response or `/auth/me`.
3. Universal Links (`apple-app-site-association`) and Android App Links (`assetlinks.json`) for `/c/*` so a card
   tap / QR opens the app; keep the web fallback.
4. `GET /app/config` (public): minimum supported app version per platform, maintenance notice text — drives
   "Update required" and the maintenance banner.
5. Optional later: waiter-scoped read of own transactions today (would replace local Recent).

## 9. Accessibility (binding targets)

WCAG 2.2 AA (contrast 4.5:1 text, 3:1 UI), VoiceOver/TalkBack labels for every control, amount announced on
change ("24 euro 90"), live region announcements for scan result/success/error, focus order top→bottom,
touch ≥ 56 pt, one-handed: all primary actions in the bottom 45 % of the screen (thumb zone), status never by
colour alone (icon + text), Reduce Motion, Dynamic Type, left-handed usage works (symmetric layout), sunlight:
light theme recommended outdoors (tip in Menu), brightness not changed by the app.

## 10. Quality bar

Precise values everywhere (pt/dp, ms, hex, curves). ASCII wireframes for each screen. For every screen:
Purpose · Entry/exit · Layout (portrait) · Hierarchy · Spacing · Typography · Components · States (loading,
empty, error, each variant) · Animations & transitions · Micro-interactions · Haptics · Sound · Accessibility
· Tablet/landscape · Android vs iPhone differences · Time for the interaction · Acceptance criteria.
Footer on every document: `Version 1.0 · September 2026 · GiftCard Waiter design specification`.

---

Version 1.0 · September 2026 · GiftCard Waiter design specification
