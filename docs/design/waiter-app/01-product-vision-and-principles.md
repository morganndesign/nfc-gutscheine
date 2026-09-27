# 01 · Product Vision and Principles

**GiftCard Waiter** — native iOS and Android app for restaurant staff: scan an NFC gift card, redeem an amount, serve the next guest. Nothing else.

| | |
|---|---|
| Document | 01 of 14 · Vision, UX principles, visual design principles |
| Audience | Product, design, engineering, QA, restaurant pilot partners |
| Binding source | Design brief v1 (screen IDs S01–S17, tokens, copy keys, timing budget) |
| Read next | [02 · Information architecture and journey](02-information-architecture-and-journey.md) |
| Related | [03a · Screens: access and scanning](03a-screens-access-and-scanning.md) · [03b · Screens: charge, redeem, success, problems](03b-screens-charge-redeem-success-problems.md) · [04 · Design system](04-design-system.md) · [06 · Motion](06-motion-guidelines.md) · [11 · Sound and haptics](11-sound-and-haptics.md) · [12 · UI copy](12-ui-copy-and-error-messages.md) |

---

## Contents

1. [Product vision](#1-product-vision)
   1.1 [The problem at the table](#11-the-problem-at-the-table) · 1.2 [Who we design for](#12-who-we-design-for) · 1.3 [Vision statement](#13-vision-statement) · 1.4 [What it is / what it will never be](#14-what-it-is--what-it-will-never-be) · 1.5 [The tap loop](#15-the-tap-loop) · 1.6 [From web terminal to native app](#16-from-web-terminal-to-native-app) · 1.7 [Success metrics](#17-success-metrics)
2. [UX principles](#2-ux-principles) (10)
3. [Design principles](#3-design-principles) (8, with do / don't)
4. [How to use these principles in review](#4-how-to-use-these-principles-in-review)

---

## 1. Product vision

### 1.1 The problem at the table

It is 20:40 on a Saturday in a Viennese Gasthaus. Table 12 asks for the bill and one guest puts a gift card on the plate. From here, every second is visible to everyone at the table.

```
  THE TABLE                                   THE WAITER
  ─────────                                   ──────────
  Guest holds the card, slightly unsure        Three other tables waiting, one tray
  whether it "still works".                    in the left hand, phone in the right.
  Companions watch. The evening should         Must get the amount right, must not
  end smoothly, not with a discussion.         book twice, must not look lost.

  THE ROOM                                     THE SYSTEM
  ────────                                     ──────────
  Dim candle light at 5 lux — or a terrace     Balance lives on the server, the card
  in July sun at 80 000 lux. Clatter,          only carries a link. Money may move
  music, 75 dB. Wet or greasy fingers.         only with a server confirmation.
```

What goes wrong today with generic tools and the web terminal:

| Friction | Cost at the table |
|---|---|
| The iPhone web flow needs the system NFC notification to be found and tapped, or a QR scan. | 3–6 s of fumbling, the guest watches the waiter search the phone. |
| Card details and amount on separate steps, or a confirmation dialog before booking. | An extra tap and transition per guest, and a dialog that trains "tap OK without reading". |
| Uncertain network: "Did it book or not?" | The waiter taps again and risks a double booking, or asks the guest to wait while calling a manager. |
| Error texts written for owners ("INVALID_CARD_STATE"). | The waiter cannot explain anything to the guest and escalates everything. |
| Screen dims, session times out, login during service. | Seconds lost at the worst possible moment. |
| Bright white UI at night, pale grey UI in sunlight. | Glare at candle-lit tables, unreadable amounts on the terrace. |

The waiter's real task is social, not technical: **close the bill gracefully**. The app succeeds when the guest remembers the evening, not the payment.

### 1.2 Who we design for

| Persona | Context | What they need from the app |
|---|---|---|
| **Lukas, 34, head waiter** | 12 years in service, fast, impatient with software, uses his own Android phone as the restaurant device. 100+ redemptions on a December Saturday. | Zero ceremony. Tap card, type, redeem, next. Never a dialog. |
| **Ana, 21, student, weekend shifts** | First day on the job, the manager has 30 seconds to show her the app. Speaks BCS and German. iPhone. | Obvious first step, forgiving input, clear words when something is wrong, no fear of "breaking" money. |
| **Martina, 48, restaurant manager** | Not a daily user of this app; uses the web dashboard. Called to the table when a card is blocked or expired. | The waiter's screen already shows what she needs to decide: card status, balance, last four digits, full number on the charge screen header. |
| **The guest** (secondary user, never touches the app) | Sees the screen when the waiter turns it around, often from 60–80 cm, sometimes without glasses. | The balance and the remaining balance, big and unambiguous; a calm, trustworthy look that matches the restaurant. |

### 1.3 Vision statement

> **The fastest, calmest way to accept a gift card at the table — as natural as a contactless payment, and just as trustworthy.**
>
> One tap to read, one number to type, one button that says exactly what will happen. The system protects the money; the waiter looks after the guest.

Three commitments follow from it:

1. **Under five seconds** from card tap to ready-for-next, on both platforms — measured from the Ready (Home) screen S05 with the app already unlocked ([timing budget](02-information-architecture-and-journey.md#51-timing-budget)).
2. **Zero doubt about money:** every booking is confirmed by the server, never duplicated, never made offline.
3. **Zero training:** a new waiter redeems correctly the first time without being shown how.

### 1.4 What it is / what it will never be

| GiftCard Waiter **is** | GiftCard Waiter **will never be** |
|---|---|
| A single-purpose tool: scan → redeem → next guest. | A back office. No reload, block, card creation, reports, team, restaurant settings. |
| One resting screen (S05 Ready) and short-lived layers on top of it. | A tab-bar app with sections to explore. |
| A native citizen of each platform: continuous NFC on Android, Apple's NFC sheet on iPhone, Face ID / BiometricPrompt, system back behaviour. | A web view in a shell, or an identical UI forced onto both platforms. |
| Online-only for money: the server confirms every redemption. | An offline cash register. There is no offline queue, ever. |
| A screen the guest may see: brand of the restaurant, balance, remaining balance, masked card number. | A place for customer data. Names, e-mails, purchaser and recipient never reach the device. |
| A shift companion: local "Recent" list of today's redemptions on this device. | A transaction history, reversal tool or audit system. Reversals are done by a manager in the dashboard. |
| Calm, precise, premium through restraint. | Gamified, playful or loud. No confetti, no streaks, no tips prompt, no upsell. |
| A tool that trusts the waiter to type the right amount and makes that amount impossible to misread. | A tool that asks "Are you sure?" after every action. |

Anything proposed later must pass one test: *does it make the loop "scan → redeem → next" faster, safer or calmer?* If not, it belongs in the dashboard. Candidates are collected in [13 · Future and design review](13-future-and-design-review.md).

### 1.5 The tap loop

The whole product is one loop. Everything else — sign-in, unlock, menu, history — exists only to keep this loop running.

```
                         ┌───────────────────────────────┐
                         │          S05  READY           │  ◄── resting state
                         │  Android: always listening    │      (screen kept awake)
                         │  iPhone:  "Scan card" button  │
                         └──────────────┬────────────────┘
                                        │ ① TAP   card read + lookup (≤ 0.7–0.9 s)
                                        ▼
                         ┌───────────────────────────────┐
                         │          S07  CHARGE          │
                         │  Balance card (who / how much)│
                         │  Amount + keypad (how much)   │
                         │  "Redeem € 24,90"             │
                         └──────────────┬────────────────┘
                                        │ ② TYPE + REDEEM  (≈ 1.2 s + ≤ 0.6 s)
                                        ▼
                         ┌───────────────────────────────┐
                         │          S09  SUCCESS         │
                         │  ✓  € 24,90                   │
                         │  Remaining balance € 75,10    │
                         └──────────────┬────────────────┘
                                        │ ③ NEXT   auto after 4 s · any tap ·
                                        │          next card (Android) · "Scan next card" (iPhone)
                                        └──────────────► back to ① (or directly to S07)
```

**Loop rules**

- **Three beats, three screens, one decision.** Tap (card), type (amount), redeem (commit). The only decision the waiter makes is the amount.
- **The loop never waits for the app.** Every system delay is covered: skeleton after 150 ms, spinner after 150 ms, "Still looking…" after 3 s, automatic idempotent retry after 8 s ([02 § 5.1](02-information-architecture-and-journey.md#51-timing-budget)).
- **The loop closes itself.** S09 returns to S05 after 4 s without a tap; on Android a new card on S09 jumps straight to S07.
- **The loop has one feel.** The same three sounds, the same three haptics, in the same order, a hundred times a night: `haptic.cardDetected` · `haptic.key` (typing) · `haptic.success` + `sound.success`. After one evening the waiter can redeem without looking at the phone for confirmation.
- **Problems leave the loop visibly and re-enter it at S05.** Card problems stay on S07 with the balance card visible; problems without card data use S10. Both have exactly one way back.

### 1.6 From web terminal to native app

The current web waiter terminal ([user guide](../../USER_GUIDE.md), screenshots `waiter-ready.png`, `waiter-amount.png`, `waiter-success.png`) proves the flow. The native app must clearly surpass it:

| Web terminal today | GiftCard Waiter (native) | Why it is better |
|---|---|---|
| iPhone: hero is "Scan QR code"; NFC requires finding and tapping a system notification. | iPhone: hero is **"Scan card"** in the thumb zone, opening Apple's NFC sheet in one tap; "Scan next card" on S09 opens it directly. | Removes 3–6 s of fumbling per guest; NFC becomes the default on both platforms. |
| Android: "Scan card" must be pressed once per session in Chrome. | Android: reader mode is always on while S05/S07/S09 are visible. | Zero taps to start a scan. |
| Header (restaurant, waiter name, menu) repeated on every screen. | TopBar only on S05; S07/S09 give the full height to the card and the amount. | One hero per screen, more room for the keypad in the thumb zone. |
| Card box is a neutral grey panel with the full 16-digit number. | `BalanceCard` in the restaurant's `brand_color`, ID-1 ratio, masked `•••• 6488` (full number only as tertiary text in the S07 header). | Looks like the physical card; the guest recognises "their" card; less data exposed. |
| Separate "Full balance" button, no guidance when the amount is too high. | Inline "€ 7,50 more than the balance" + chip "Use balance · € 32,50"; button disabled. | The error explains itself and offers the fix in one tap. |
| Success shows the full card number; "Next card" button must be tapped. | Success shows `•••• 6488`, remaining balance, 4 s auto-return with `CountdownHairline`. | Privacy by default; the loop closes itself. |
| No hold protection for large amounts. | `HoldButton` for amounts ≥ € 100,00 (600 ms). | A slip of the finger can never book a large amount. |
| Network error: "Press the button again." | Idempotent automatic retry with a calm "Connection interrupted — nothing is ever booked twice." | The waiter never has to decide whether it is safe to retry. |
| Generic sign-in in a browser tab; session cookies. | Device-bound token, Face ID / BiometricPrompt unlock, 30-day rolling session. | Unlock in < 1 s at the start of a shift. |

### 1.7 Success metrics

Metrics are measured in pilot restaurants (moderated usability sessions in weeks 1–2, instrumented field use afterwards). Instrumentation never records customer data or card numbers; it uses `X-Request-Id` / `X-Device-Id` timings and anonymous event counts (details in [09 · Flutter handoff](09-flutter-handoff.md)).

| # | Metric | Target v1 | Definition | How measured |
|---|---|---|---|---|
| M1 | **Time-to-redeem (median)** | **< 4 s** on both platforms | Android: card enters the NFC field → S09 visible. iPhone: tap on "Scan card" → S09 visible. Only successful single-attempt redemptions with 1–4 typed digits. | Client timestamps per loop, server time from request logs. Budget: ≈ 2.7 s Android, ≈ 3.6 s iPhone ([02 § 5.1](02-information-architecture-and-journey.md#51-timing-budget)). |
| M2 | **Tap loop time (median)** | ≈ 3.5 s Android · ≈ 4.5 s iPhone; p90 < 7 s | From scan start to ready for the next card (S09 visible for 0.8 s), measured from the Ready (Home) screen S05 with the app already unlocked (app open/unlock excluded). | As M1 plus the S09 dwell until next scan. |
| M3 | **Double bookings** | **0** | Two redeem transactions caused by one waiter intent (same card, same amount, same attempt). | Server: redeem transactions per `Idempotency-Key`; manual reversals tagged "duplicate" in the dashboard. |
| M4 | **First-time success without training** | **≥ 95 %** | New waiter (never used the app), no instruction, completes sign-in → first redemption of a given amount correctly on the first try. | Moderated tests, n ≥ 20 per platform, task: "The guest wants to pay € 24,90 with this card." |
| M5 | **Error recovery without a manager** | **≥ 80 %** for non-card problems | Share of network, session, permission, scan-read and throttle problems resolved by the waiter alone (card problems like blocked/expired are *meant* to involve a manager and are excluded). | Field events: problem shown → next successful redemption within 2 min without "getManager" copy being shown; plus observation. |
| M6 | **Crash-free sessions** | **≥ 99.9 %** | Sessions (foreground periods) without an app crash or ANR. | Platform crash reporting. |
| M7 | **Wrong-amount rate** (guard metric) | < 0.5 % of redemptions | Redemptions reversed by a manager within 24 h with reason "wrong amount". | Dashboard reversals; reviewed monthly. |
| M8 | **Scan success on first tap** (guard metric) | ≥ 97 % Android · ≥ 95 % iPhone | NFC reads that produce a lookup without a retry or timeout. | Client events per scan attempt. |

A release is not shipped if M3 > 0 in beta, M6 < 99.9 % over 7 days, or M4 < 90 % in usability testing.

---

## 2. UX principles

Ten principles, in priority order. When two conflict, the higher one wins. Each principle has a rationale, rules that make it testable, and a concrete example from the app.

### P1 · One screen · one task · one decision

**Rationale.** A waiter looks at the phone for fractions of a second between two conversations. Every screen that asks for more than one thing costs a re-orientation.

**In practice**
- Each screen answers one question: S05 "Which card?", S07 "How much?", S09 "Did it work?", S10 "What happened, what now?".
- Maximum one `PrimaryButton` per screen; at most two secondary actions.
- No confirmation screens and no "Are you sure?" dialogs in the loop. The only dialogs in the whole app are the sign-out confirmation and the switch-card fallback ([05 · Component library](05-component-library.md)).
- Card details and amount entry are **one screen** (S07): the decision "how much" is made while seeing "how much is left".

**Example.** On S07 the waiter sees the balance card (€ 100,00), types `2 4 9 0`, and the button already reads "Redeem € 24,90". There is no second step; the label *is* the confirmation.

### P2 · The amount is the interface

**Rationale.** Money errors happen when the number is small, ambiguous or separated from the action. In this app the typed amount is the largest element on screen and it is repeated verbatim on the button.

**In practice**
- The amount is set in `type.amount.xl` (64/68, 600, tabular figures) and never truncated; it shrinks to fit (min 40 pt) rather than cut ([04 · Design system](04-design-system.md)).
- POS-style entry: digits shift in from the right; "2 4 9 0" → € 24,90. No decimal key, no cursor.
- The Redeem button always states the exact amount in the restaurant locale ("€ 24,90 einlösen" / "Redeem € 24,90" / "Iskoristi 24,90 €").
- VoiceOver/TalkBack announce every change ("24 euro 90").
- Balance, typed amount and remaining balance never share the same size on one screen; each has its own token (`type.balance`, `type.amount.xl`, `type.amount.l`).

**Example.** A waiter types `2 4 9 0 0` by mistake. The display reads **€ 249,00**, the button changes to "Hold to redeem" with the amount, and the hold requirement (≥ € 100,00) gives a natural moment to notice. One long-press on ⌫ clears.

### P3 · Never make the waiter think about money safety — the system does

**Rationale.** A waiter who worries "did it book twice?" hesitates, retries, or calls a manager. Safety must be structural, not a matter of vigilance.

**In practice**
- Every redeem attempt carries one `Idempotency-Key`, reused for every automatic retry until success or a definitive error. A replayed response (`replayed: true`) is shown exactly like a first-time success.
- **Never redeem offline.** When offline, S05 says so, and the Redeem button is disabled with the reason (`offline.title`, `offline.body`).
- When the connection drops during a redemption, the app says what it is doing and what it guarantees: `uncertain.title` "Connection interrupted" · `uncertain.body` "Checking … Nothing is ever booked twice."
- Guards are enforced before the button is enabled: amount > 0, amount ≤ balance, card redeemable, partial redemption allowed.
- Large amounts (≥ € 100,00) need a 600 ms hold — protection without a dialog.
- Android: a new card tapped while an amount is typed on S07 never silently replaces the card; a snackbar asks "Different card detected — Switch?".

**Example.** The terrace Wi-Fi drops right after "Redeem € 38,00". After 8 s the button area changes to the calm uncertain state, the app keeps retrying silently with the same key, and when the connection returns within the 20 s automatic-retry window S09 appears normally. The waiter never saw a "try again?" question — it appears only if 20 s pass without an answer ("Try again" with the same key, or "Cancel"; [03b §3](03b-screens-charge-redeem-success-problems.md)).

### P4 · Thumb-first

**Rationale.** One hand holds the phone, the other holds the card or a tray. The waiter's thumb must reach every action that matters without shifting grip — left or right handed.

**In practice**
- All primary actions sit in the bottom 45 % of the screen ([07 · Accessibility](07-accessibility-guidelines.md)).
- Touch targets ≥ 56 × 56 pt everywhere; keypad keys ≥ 72 pt high (64 on compact height); primary CTA 64 pt high (56 compact), full width.
- Layouts are symmetric: nothing essential lives only in one corner. The TopBar (top) contains only secondary things: restaurant, avatar, Recent, Menu.
- Key gaps ≥ 8 pt; no two primary or destructive actions adjacent. Glove-friendly and wet-finger tolerant.
- Sheets (Recent, Menu) open from the bottom and are dismissed by a downward swipe.

**Example.** On iPhone the "Scan card" button on S05 and "Scan next card" on S09 occupy the same position, 64 pt high at the bottom edge above the safe area. A waiter can run the whole loop with one thumb and never look for the button.

### P5 · Say what happened and what to do

**Rationale.** Every problem at the table has two audiences: the waiter (what do I do?) and the guest (what does this mean for me?). Codes and jargon serve neither.

**In practice**
- Every error = one line *what happened* + one line *what to do*. Max 2 lines of body on a problem screen.
- No blame, no exclamation marks, no technical codes on screen: "Card not found", never "You scanned a wrong card", never "404".
- Card problems (blocked, expired, inactive, replaced, zero balance) are shown **on S07 with the balance card visible**, so the waiter can tell the guest the status and balance. Problems without card data use full-screen S10.
- When only a manager can help, say so explicitly with `getManager` ("Please get a manager") — once, not as a fallback on every screen.
- Copy lives in [12 · UI copy and error messages](12-ui-copy-and-error-messages.md), in German (primary), English and BHS.

**Example.** A blocked card: the balance card appears desaturated with the badge "Blocked", the banner reads `card.blocked` "Card blocked" + the `blocked_reason` if present + `getManager`. The waiter can say to the guest: "The card is blocked, I'll get the manager" — the screen gave her the sentence.

### P6 · Speed is a feature, calm is a feature

**Rationale.** Fast without calm feels frantic; calm without speed feels slow. The app must be both: instant response, quiet presentation.

**In practice**
- Timing budget per step is binding ([02 § 5.1](02-information-architecture-and-journey.md#51-timing-budget)). Skeletons and spinners appear only after 150 ms — fast operations never flash a loader.
- No blocking modal spinners. Loading happens in place (skeleton balance card, spinner inside the button).
- Animations explain, never decorate: 160–360 ms, standard curves; the only emphasis moment is S09 (`motion.duration.emphasis` 520 ms) ([06 · Motion](06-motion-guidelines.md)).
- Sounds ≤ 400 ms, ~ −18 LUFS, respecting silent mode; no key-press sounds ([11 · Sound and haptics](11-sound-and-haptics.md)).
- Copy is calm: "Checking …" rather than "Error!", "Still looking…" rather than a red flash.

**Example.** If a lookup takes 3.2 s on a weak connection, the skeleton balance card is already on screen and the caption "Still looking…" fades in. Nothing jumps, nothing blinks red, and the waiter can say "one moment" with confidence.

### P7 · Platform-honest

**Rationale.** The two platforms read NFC differently. Pretending otherwise produces a worse app on both. We design the best possible loop for each platform and keep everything else identical.

**In practice**

| Aspect | Android | iPhone |
|---|---|---|
| Scan start | Reader mode always on while S05, S07, S09 are visible — the waiter just taps the card. | System NFC sheet opened by the "Scan card" button (S05) or "Scan next card" (S09). |
| Scan feedback | App plays `haptic.cardDetected` + `sound.cardDetected` after a successful read (platform sound suppressed). | System sheet shows ✓ "Card found" and dismisses (≈ 0.3–0.6 s); app feedback per [11](11-sound-and-haptics.md). |
| Next card | Tap the next card on S09 (`success.next.android` "Just tap the next card"). | "Scan next card" button (`success.next.ios`). |
| Card tap while app idle | — (reader mode requires foreground) | Background tag reading / universal link opens S07 directly (after unlock). |
| Biometrics | BiometricPrompt (class 3; class 2 allowed) | Face ID / Touch ID |
| Back | System back gesture/button = one layer back, never exits during a redemption. | Swipe-down on sheets; no edge-swipe back on S07 while redeeming. |
| Shapes | Matched rounded rectangles | Continuous (squircle) corners |
| iPad | — | No NFC: QR scan (S12) and manual entry (S11) are primary. |

Everything that is *not* platform-specific — tokens, copy, screen IDs, states, timing — is identical.

**Example.** On S09, Android shows the caption "Just tap the next card" and no button is required; iPhone shows a full-width "Scan next card" PrimaryButton. Both reach the next S07 with the fewest possible actions their platform allows.

### P8 · Every state is designed

**Rationale.** At a restaurant, the rare states happen daily: the Wi-Fi drops, a card is expired, a phone has NFC switched off. An undesigned state is a support call and a waiting guest.

**In practice**
- Every screen spec in [03a](03a-screens-access-and-scanning.md) and [03b](03b-screens-charge-redeem-success-problems.md) lists loading, empty, error and every variant; the app-wide state machine is in [02 § 4.5](02-information-architecture-and-journey.md#45-app-state-machine).
- All 21 card/problem variants listed in the brief have a designed layout, copy key, sound, haptic and a way back.
- No generic "Something went wrong". Server errors (5xx) have their own S10 variant with retry.
- Empty states are designed too: an empty Recent sheet says what will appear there.
- Session, device and restaurant problems (S15) and permissions (S16) are designed as calmly as the happy path.

**Example.** An Android phone with NFC turned off: S05 does not show a broken listening animation. It shows the "NFC is off" state with one button that deep-links to the NFC settings, plus QR and manual entry as alternatives — the waiter can still serve the guest.

### P9 · Recover in place, return to Ready

**Rationale.** Waiters should never feel "lost" in the app. There is one home, and every path leads back to it.

**In practice**
- S05 Ready is the only resting screen. All other screens are temporary layers that return to S05 ([02 § 4.2](02-information-architecture-and-journey.md#42-navigation-model)).
- Every problem offers exactly one obvious way forward (retry, scan again, or back to Ready).
- Inline recoveries beat new screens: amount > balance is an inline message with a fix chip, not a screen.
- Context is preserved where it is safe (typed amount survives a transient network error on S07) and discarded where it is risky (a new card resets the amount; a definitive error creates a new idempotency key for the next attempt).

**Example.** Lookup fails because the card is from another restaurant: S10 `problem.foreign.title` "Card from another restaurant" with "Scan another card" as the only primary action. One tap and the waiter is back in the loop.

### P10 · Privacy by default, even at the table

**Rationale.** The screen is regularly turned toward the guest and seen by neighbours. The app is also used on personal phones.

**In practice**
- No customer data exists in the app — the API never returns it.
- Card numbers are masked `•••• 6488` everywhere, except the tertiary full number in the S07 header (so it can be read to a manager) and the S11 input field.
- Recent is local to the device and the signed-in waiter, limited to the current business day (from 04:00), max 200 rows, cleared on sign-out and at 04:00.
- Nothing about a card survives on screen longer than needed: S09 returns to S05 after 4 s, and a card on S07 is discarded when the app returns from background after > 15 min (unlock required).

**Example.** The guest sees S09: ✓, "Redeemed", € 24,90, "Remaining balance € 75,10", `•••• 6488` — everything they need, nothing their neighbour should see.

---

## 3. Design principles

Visual principles. They turn the UX principles into pixels. Token values live in [04 · Design system](04-design-system.md); components in [05 · Component library](05-component-library.md).

### D1 · Quiet surfaces

The canvas (`color.bg.canvas` #FAFAFA / #0A0A0C) and surfaces are near-neutral and almost flat. Structure comes from spacing (4-pt grid) and typography, not from boxes, lines and shadows. Elevation is reserved for the balance card (`elev.2` + `elev.card-brand`) and sheets (`elev.3`).

| Do | Don't |
|---|---|
| Separate groups with `space.6`–`space.8` and a type-scale step. | Put every element in its own bordered card. |
| Use `color.border.subtle` only for list dividers in sheets. | Draw outlines around the amount display or the keypad block. |
| Keep keypad keys as filled `color.bg.key` tiles without borders or shadows. | Give keys drop shadows or gradients. |

### D2 · One hero per screen

Every screen has exactly one element that the eye lands on first — and it is the answer to that screen's question.

| Screen | Hero | Everything else |
|---|---|---|
| S05 Ready | Android: `NfcScanAnimation` · iPhone: "Scan card" button · iPad: QR action | TopBar, secondary actions in tertiary style |
| S07 Charge | The amount (`type.amount.xl`) — the balance card is the context above it | Keypad in `color.bg.key`, button at the bottom |
| S09 Success | `SuccessMark` + amount (`type.amount.l`) | Remaining balance, masked number, hairline |
| S10 Problem | Title (`type.title.l`) with status icon | Max 2 lines of body, one action |

| Do | Don't |
|---|---|
| Size the hero at least 1.5× larger than anything else on the screen. | Compete with the hero using a second large number (e.g. balance and amount at equal size). |
| Let the hero own its colour moment (success green on S09, saffron on S05 Android). | Use accent colour on secondary elements of the same screen. |

### D3 · The card is the brand of the restaurant

GiftCard Waiter has almost no brand of its own. The `BalanceCard` carries the restaurant's `brand_color` (fallback `color.brand.ink` #0F172A), the restaurant's name, and the ID-1 proportions of the physical card (1.586:1) — so the guest recognises *their* card on the screen.

| Do | Don't |
|---|---|
| Render the balance card like a physical card: full width minus margins, max 220 pt high, subtle sheen (+6 % → −6 % luminance), `radius.xl` continuous corners on iOS. | Add restaurant logos, photos or patterns (not in v1; see [13](13-future-and-design-review.md)). |
| Choose text colour automatically (white or #0A0A0C) and fall back to ink when 4.5:1 cannot be met. | Use `brand_color` for buttons, backgrounds or text elsewhere in the app. |
| Desaturate the card 40 % for blocked/expired/replaced and add the `StatusBadge`. | Tint the whole card red; status is conveyed by badge + banner, not by recolouring the brand. |

### D4 · Numbers are typography

Amounts and balances are the product. They are set with the same care as a headline in a financial statement.

| Do | Don't |
|---|---|
| Always tabular figures (`tnum`) so amounts don't jitter while typing. | Use proportional figures in amounts, rows or countdowns. |
| Negative tracking on large amounts (−2.5 % at 64 pt, −2 % at 48/40 pt). | Letter-space amounts or set them in a light weight. |
| Format by restaurant locale: de-AT "€ 24,90", en-GB "€24.90", BHS "24,90 €". | Mix formats within one screen, or show cents as a superscript. |
| Shrink-to-fit (min 40 pt) when Dynamic Type or large amounts need space. | Truncate, ellipsise or wrap an amount. |
| Use Geist Mono only for the 16-digit input on S11. | Use monospaced type for amounts or masked numbers elsewhere. |

### D5 · Colour means status only

Neutral greys build the interface; colour carries meaning. There are exactly three sources of colour, each with one job:

| Colour source | Meaning | Where |
|---|---|---|
| `color.success` / `.danger` / `.warning` / `.info` (+ `.bg`) | Status: redeemed, blocked/error, expired/inactive/empty, offline/info | `SuccessMark`, `StatusBadge`, `StatusBanner`, `Banner` |
| `color.accent.saffron` | "Tap / hold here" — the NFC affordance and the hold progress | `NfcScanAnimation` arcs, NFC glyph on the balance card, `HoldButton` ring (via `color.hold.progress`, which darkens to #B45309 in dark theme for contrast — [04](04-design-system.md)), focus accents |
| `brand_color` | The restaurant | `BalanceCard` only |

| Do | Don't |
|---|---|
| Pair every status colour with an icon and a text label (never colour alone). | Use green for "Redeem" or red for "Delete" as decoration. |
| Keep the `PrimaryButton` neutral (`color.action.primary`). | Use saffron as text on light backgrounds (fails contrast; use `color.accent.saffronText`). |
| Tint only the banner background (`.bg` tokens) and the icon. | Tint full screens red on errors. |

### D6 · Motion explains causality

Motion shows *what caused what*: the card arrived, the amount was accepted, the screen returns home. It never entertains. Durations 90–520 ms; the Reduce Motion alternative is always a 160 ms cross-fade ([06 · Motion](06-motion-guidelines.md)).

| Do | Don't |
|---|---|
| Let the balance card arrive as a physical object with `motion.spring.card`, continuing the gesture of the card tap (choreography in [06](06-motion-guidelines.md)). | Slide screens in from the side like a navigation stack. |
| Draw the check of `SuccessMark` once (emphasis 520 ms), then hold still. | Loop, bounce or add confetti on success. |
| Animate `CountdownHairline` linearly over 4 s so the auto-return is predictable. | Auto-return without any visible countdown. |
| Keep progress indicators under Reduce Motion (they carry information). | Remove the hold ring or spinner when Reduce Motion is on. |

### D7 · Premium through restraint

Premium here means *precise and quiet*, the way a well-made card terminal feels: few elements, exact alignment, generous space, perfect numbers, one signature sound.

| Do | Don't |
|---|---|
| One typeface family (Geist Sans, Geist Mono for S11 only), 11 type tokens, nothing ad hoc. | Introduce a display font, italic styles or decorative icons. |
| Align everything to the 4-pt grid and the screen side margin (20 / 24 / 32 pt). | Nudge elements by 1–3 pt "to look right". |
| One signature sound (`sound.success`, two-note rising chime E6 → B6). | Add sounds for keys, navigation or sheets. |
| Use illustrations only where no card is shown — S10/S15 frequent problems, S13 empty Recent, S17 intro ([10 §4.1](10-assets-icons-illustrations.md)). | Add mascots, emoji or stock imagery. |

### D8 · Dark room / sunlight ready

The same app runs at a candle-lit table and on a sunny terrace. Neither is an edge case.

| Condition | Design response |
|---|---|
| Dark room (< 10 lux) | Dark theme (follows system by default): canvas #0A0A0C, no pure white areas larger than the text; dark theme uses surface steps + 1 px `border.subtle` instead of shadows; balance card keeps the brand colour and glows subtly via `elev.card-brand`. |
| Bright sunlight (> 50 000 lux) | Light theme recommended outdoors (tip in Menu S14); text ≥ 4.5:1, UI ≥ 3:1; OS "Increase contrast" / "High contrast text" switches `fg.secondary`→`fg.primary`, `border.subtle`→`border.strong`, banner text weight 600. |
| Both | Amounts ≥ 40 pt; status by icon + text; the app never changes screen brightness; "Keep screen on" (default ON) prevents dimming on S05/S07/S09. |

| Do | Don't |
|---|---|
| Test every screen at 5 lux and in direct sun on a real device before sign-off. | Rely on thin 1 px hairlines or `fg.tertiary` for anything the waiter must read at a glance. |
| Let the user force Light or Dark in Menu (S14). | Force brightness to maximum on S09 (brightness belongs to the user). |

---

## 4. How to use these principles in review

Every design and build review for GiftCard Waiter runs the same five questions. A "no" blocks sign-off.

| # | Question | Principles |
|---|---|---|
| R1 | Does this screen have one task, one hero, one primary action — in the thumb zone? | P1, P4, D2 |
| R2 | Can the amount be misread, mistyped unnoticed, or booked twice? | P2, P3, D4 |
| R3 | Does every state (loading, empty, error, each variant) have designed layout, copy, sound, haptic and one way back to S05? | P5, P8, P9 |
| R4 | Does it respect the platform's NFC, biometrics and back behaviour, and stay inside the timing budget? | P6, P7 |
| R5 | Is colour used only for status, saffron only for the tap affordance, `brand_color` only on the balance card — and does it work at 5 lux and in full sun? | D5, D8 |

The full review checklist and open questions are in [13 · Future and design review](13-future-and-design-review.md).

---

Version 1.0 · September 2026 · GiftCard Waiter design specification
