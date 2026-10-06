# 03b · Screens — Charge, Redeeming, Success, Problems, Recent (S07–S10, S13)

The money path of GiftCard Waiter: **card known → amount → Redeem → confirmed → next guest.** This document
specifies every screen and variant from the moment a card lookup starts until the device is ready for the next
card, plus the local shift history.

| Covered here | Lives elsewhere |
|---|---|
| S07 Charge · S08 Redeeming · S09 Success · S10 Problem screens · S13 Recent + Recent detail | S01–S06, S11, S12, S14–S17 → [03a-screens-access-and-scanning.md](03a-screens-access-and-scanning.md) |
| Screen layout, behaviour, states, copy usage | Token values → [04-design-system.md](04-design-system.md) · component anatomy → [05-component-library.md](05-component-library.md) · curves & choreography → [06-motion-guidelines.md](06-motion-guidelines.md) · a11y rules → [07-accessibility-guidelines.md](07-accessibility-guidelines.md) · breakpoints → [08-responsive-behaviour.md](08-responsive-behaviour.md) · haptic/sound assets → [11-sound-and-haptics.md](11-sound-and-haptics.md) · full string catalogue → [12-ui-copy-and-error-messages.md](12-ui-copy-and-error-messages.md) |

---

## 0. Conventions for this document

**Units.** pt (iOS) = dp (Android). All sizes are layout sizes before Dynamic Type / font scale.

**Reference viewports** (used in every wireframe and budget):

| ID | Device class | Viewport (pt) | Safe area top / bottom | Side margin | Height class |
|---|---|---|---|---|---|
| P-R | iPhone 15 / 16 (reference) | 393 × 852 | 59 / 34 | 20 | regular (≥ 700) |
| P-L | iPhone 15 Pro Max | 430 × 932 | 59 / 34 | 24 | regular |
| A-R | Pixel 8 (edge-to-edge, gesture nav) | 412 × 915 | 48 / 24 | 24 | regular |
| P-C | iPhone SE 3 (compact height) | 375 × 667 | 20 / 0 | 20 | compact (< 700) |
| T-P | iPad 10th gen portrait | 820 × 1180 | 24 / 20 | 32 | tablet |
| T-L | iPad 10th gen landscape | 1180 × 820 | 24 / 20 | 32 | tablet |

**Amounts.** Always cents internally. Shown in restaurant locale (de-AT `€ 24,90`, en-GB `€24.90`, BHS UI with
de-AT locale still follows the restaurant locale). Examples below use de-AT formatting in wireframes and English
UI copy in prose.

**Spoken amounts** (VoiceOver/TalkBack): `{euros} euro {cents}` in the UI language — "24 euro 90", "Betrag 24 Euro
90", "Iznos 24 eura 90"; whole amounts drop the cents ("100 euro"). Rules in [07](07-accessibility-guidelines.md).

**Support code.** Short form of the `X-Request-Id` of the failing (or confirming) request: last 6 characters,
uppercase, no hyphens → `7F3A9C` (format and placement owned by [12 §2.5](12-ui-copy-and-error-messages.md#25-support-code)).
Shown in `type.caption`, `color.fg.tertiary`. Long-press copies the **full** UUID to the clipboard (haptic.select +
Snackbar "Copied"). Managers match it against audit logs. The transaction id short form uses the same rule, prefixed
`TX` → `TX 5E12C0`.

**Masking.** `•••• 6488` everywhere except the S07 TopRow, which shows the full formatted number
`5285 1058 7098 6488`.

**Spec field order** for every screen and variant: Purpose · Entry/exit · Wireframe · Hierarchy · Typography ·
Colour · Components · States · Motion · Micro-interactions · Haptics · Sound · Accessibility · Tablet &
landscape · Portrait · Android · iPhone · Time · Acceptance criteria. For variants, a field marked "= base"
inherits the S07 base value unchanged; only deltas are written out.

---

## 1. Shared rules (S07–S10)

### 1.1 The redeem attempt (idempotency lifecycle)

A **redeem attempt** = one `(card id, amount)` pair plus one `Idempotency-Key` (UUID v4). It is the unit that the
server guarantees never to book twice.

| Event | Key behaviour |
|---|---|
| Waiter starts Redeem (tap-up on PrimaryButton, or HoldButton reaches 100 %) and **no pending attempt** exists for this card + amount | New key generated at this moment |
| Automatic retry (timeout, transport error, 5xx) | **Same key** |
| Manual "Try again" in the uncertain state | **Same key** |
| "Cancel" in the uncertain state, then Redeem again with **unchanged card + amount** | **Same key** (pending attempt kept) — if the first request was booked after all, the server answers `replayed: true` and S09 shows it |
| Amount changed, card switched, or S07 closed | Pending attempt discarded; next Redeem gets a new key |
| Definitive 4xx (422, 409, 429, 403 card errors) | Attempt closed; next Redeem gets a new key |
| 401 UNAUTHENTICATED | Attempt kept (same key) across re-authentication on S15 |
| Success (201) or replay (200, `replayed: true`) | Attempt closed; card state updated from `data.card` |

Pending attempts live in memory only; a process kill discards them (the waiter re-scans; the fresh balance is
authoritative). **Nothing is ever queued offline.**

The native app is stricter than the web terminal (`terminal.tsx`): the web keeps the key on any ≥ 500 and
renews on < 500, but shows only a toast and no retry loop. Native adds automatic retries, the explicit uncertain
state and keeps the key across Cancel for an unchanged amount.

### 1.2 SUN-signed cards: never re-send a URL

NTAG 424 DNA URLs contain a one-time `picc`/`cmac`. Re-posting the same URL to `/scan` returns
`NFC_REPLAY_DETECTED`. Therefore:

- The app never retries a `/scan` whose token contains `picc`+`cmac` — lookup "Try again" becomes **"Scan
  again"** (requires a fresh tap) for these cards.
- Card data is **never refreshed by re-scanning the stored URL.** After a redeem error, the card is updated from
  the error `context` (e.g. `INSUFFICIENT_BALANCE.context.balance`) or from the error code itself
  (`CARD_BLOCKED` → blocked).

### 1.3 Error → surface map

**Lookup (`POST /scan`)**

| Response | Surface |
|---|---|
| 200, status active, balance > 0 | S07 normal (or partial-disabled) |
| 200, status blocked / expired or `is_expired` / replaced / inactive / redeemed or balance 0 | S07 card-state variant (§ 2.11–2.15). Precedence: blocked › expired › replaced › inactive › zero balance |
| 404 CARD_NOT_FOUND | S10 not found |
| 403 CARD_FOREIGN_RESTAURANT | S10 foreign |
| 403 NFC_UID_MISMATCH · NFC_SIGNATURE_INVALID · NFC_REPLAY_DETECTED | S10 verification failed |
| 429 SCAN_THROTTLED · TOO_MANY_REQUESTS (`retry_after`) | S10 throttled |
| No response ≤ 10 s, offline, DNS/TLS/transport failure | S10 network |
| 5xx | S10 server |
| 401 | S15 session expired sheet ([03a](03a-screens-access-and-scanning.md)) |
| 403 DEVICE_REVOKED · RESTAURANT_SUSPENDED | S15 ([03a](03a-screens-access-and-scanning.md)) |

**Redeem (`POST /cards/{id}/redeem`)** — the server checks in this order: blocked → expired → not active →
max single redemption → balance → full-only → velocity.

| Response | Surface | Key |
|---|---|---|
| 201 | S09 | closed |
| 200 `replayed: true` (top-level field, next to `data`) | S09, identical | closed |
| Timeout 8 s / transport error / offline / 502–504 / other 5xx | S08 slow or uncertain, auto-retry | same |
| 422 INSUFFICIENT_BALANCE (`context.balance`) | S08 → S07 balance-changed (§ 3.8) | new |
| 422 CARD_BLOCKED | S07 blocked (no reason available) | new |
| 422 CARD_EXPIRED | S07 expired | new |
| 422 CARD_NOT_REDEEMABLE (`context.status`) | S07 variant for that status (redeemed → zero balance; inactive; replaced) | new |
| 422 INVALID_AMOUNT with `context.max_single_redemption` | S07 max-single (§ 2.16) | new |
| 422 INVALID_AMOUNT with `context.balance` only (full-only rule changed meanwhile) | S07 partial-disabled, amount set to `context.balance` | new |
| 422 VALIDATION_FAILED / 400 IDEMPOTENCY_KEY_REQUIRED | S07 helper line `problem.server.title` "Something went wrong" + support code (client defect; logged) | new |
| 409 INVALID_CARD_STATE | as CARD_NOT_REDEEMABLE | new |
| 409 IDEMPOTENCY_CONFLICT | S07, helper "Please tap Redeem again." — **no automatic resubmit** | new |
| 429 VELOCITY_LIMIT_EXCEEDED | S07 velocity banner (§ 2.17) | new |
| 429 TOO_MANY_REQUESTS (`retry_after`) | S07 rate banner with countdown (§ 2.17) | new |
| 401 | S15 session sheet; on return S07 with amount and pending attempt intact | same |
| 403 DEVICE_REVOKED · RESTAURANT_SUSPENDED | S15 | discarded |

### 1.4 Global interaction locks

While an attempt is in flight (S08 submitting/slow/uncertain): Keypad, QuickAmountChip, ✕, system back
(Android) and edge-swipe back (iOS) are disabled; Android reader-mode taps are **ignored** (no haptic, no sound);
iOS universal-link opens for another card are held and delivered after the attempt resolves (§ 2.18).

---

## 2. S07 — Charge

### 2.1 Purpose

One surface that answers "what is on this card?" and "how much do we take?". The waiter sees the card and its
balance, types the amount on a POS keypad and redeems with one tap (< € 100) or one 600 ms hold (≥ € 100). The
button always states the exact amount; there is no confirmation screen.

### 2.2 Entry / exit

| Entry | Trigger | Transition |
|---|---|---|
| S05 / S06 (Android) | NFC read → lookup started | BalanceCard grows from the NfcScanAnimation centre, motion.spring.card, 240 ms (≈ motion.base); Skeleton if lookup > 150 ms |
| S06 (iPhone) | System sheet "Card found" dismissed | Same, starting as the sheet slides down |
| S11 manual / S12 QR | Lookup started | Push from right, motion.base, ease.standard |
| Universal link `/c/<token>` (iOS/Android App Links) | App opened / foregrounded by link, user unlocked | S07 directly (method `link`), cross-fade motion.fast |
| S09 (Android) | New card tapped during countdown | 300 ms cross-fade, haptic.cardDetected |
| S07 (Android) | New card tapped, amount = 0 | Card replaced in place, 300 ms cross-fade, amount stays 0 |

| Exit | Trigger |
|---|---|
| S08 | Redeem tap-up (< € 100) or hold complete (≥ € 100) |
| S05 | ✕, Android back, iOS edge swipe, "Done" on card-state variants; cross-fade motion.base; amount discarded, nothing booked |
| S10 | Lookup fails (§ 1.3) — replaces the skeleton |
| S15 | 401 / device revoked / restaurant suspended |
| S07 (other card) | Snackbar "Switch" or amount = 0 new tap (Android) |

### 2.3 Wireframe — portrait, P-R 393 × 852 (base: active card, amount € 24,90)

```
 x:0                                                     393
 ┌───────────────────────────────────────────────────────┐ y 0
 │ status bar                         safe area 59        │
 ├───────────────────────────────────────────────────────┤ y 59
 │ [✕]        5285 1058 7098 6488          (56 empty)    │ TopRow 56: IconButton 56 at x 4 (glyph on margin 20)
 ├───────────────────────────────────────────────────────┤ y 115   space.1 (4)
 │            ╭──────────────────────────╮               │ y 119
 │            │ GIFT CARD            ))) │               │ BalanceCard 224 × 141 (ID-1, height-driven)
 │            │ Trattoria Bella Vista    │               │ x 84.5 – 308.5, padding space.3
 │            │ € 32,50                  │               │ ID-1 corner radius, no shadow
 │            │ •••• 6488 · Valid until 26.09.2029      │
 │            ╰──────────────────────────╯               │ y 260   space.3 (12)
 │                     € 24,90                           │ y 272  AmountDisplay 68 (type.amount.xl, centred)
 │                                                       │ y 340  Helper line 22 (reserved, empty)
 │                                                       │ y 362  space.2 (8)
 │              ( Use balance · € 32,50 )                │ y 370  Assist row 40 (chip; hit area 56)
 │                                                       │ y 410  space.3 (12)
 │  ┌───────────┐ ┌───────────┐ ┌───────────┐            │ y 422
 │  │     1     │ │     2     │ │     3     │            │ keys 112.3 × 72, gaps space.2 (8)
 │  └───────────┘ └───────────┘ └───────────┘            │
 │  │     4     │ │     5     │ │     6     │            │ y 502
 │  │     7     │ │     8     │ │     9     │            │ y 582
 │  │    00     │ │     0     │ │     ⌫     │            │ y 662 – 734
 │                                                       │ y 734  space.3 (12)
 │  ┌─────────────────────────────────────────────┐      │ y 746
 │  │              Redeem € 24,90                 │      │ PrimaryButton large 353 × 64, radius.l
 │  └─────────────────────────────────────────────┘      │ y 810  space.2 (8)
 │ home indicator                     safe area 34        │ y 818 – 852
 └───────────────────────────────────────────────────────┘
 Thumb zone (bottom 45 %) starts at y 469: keypad rows 2–4 and the button are inside it.
```

### 2.4 Vertical budget and BalanceCard sizing

The layout is **bottom-anchored**: button, keypad, assist row, helper and AmountDisplay are fixed; the BalanceCard
takes the remaining height, keeping the ID-1 ratio (width = height × 1.586, never wider than the content width,
centred; max height 220 on phones, 280 on tablets).

| Element | Regular height (P-R, P-L, A-R) | Compact height (P-C) |
|---|---|---|
| TopRow | 56 | 56 |
| TopRow → card | space.1 (4) | space.0 + leftover |
| BalanceCard | flexible | **strip presentation, 88** (see below) |
| Card → AmountDisplay | space.3 (12) | space.2 (8) |
| AmountDisplay | 68 (`type.amount.xl`) | 52 (`type.amount.l`) |
| Helper line | 22 (reserved) | 22 |
| Helper → assist row | space.2 (8) | space.1 (4) |
| Assist row | 40 (hit 56) | 40 |
| Assist → Keypad | space.3 (12) | space.2 (8) |
| Keypad | 4 × 72 + 3 × 8 = 312 | 4 × 64 + 3 × 8 = 280 |
| Keypad → button | space.3 (12) | space.2 (8) |
| PrimaryButton | 64 (large) | 56 (regular) |
| Bottom gap above safe area | space.2 (8); space.4 (16) if safe bottom = 0 | space.4 (16) |
| **Fixed total** | **618** | **550** |

| Viewport | Available (height − safe areas) | BalanceCard |
|---|---|---|
| P-R 393 × 852 | 759 | 224 × 141 (ID-1) |
| P-L 430 × 932 | 839 | 349 × 220 (capped; 1 pt leftover above card) |
| A-R 412 × 915 | 843 | 349 × 220 (capped; 5 pt leftover above card) |
| Pixel 7a 412 × 846 | 774 | 248 × 156 |
| P-C 375 × 667 | 647 | strip (`BalanceCard / compact`) 335 × 88 (9 pt leftover, added above the card) |

**Presentation switch.** ID-1 needs ≥ 136 pt (padding 12 + overline 14 + name 28 + gap 8 + balance 44 + caption
18 + padding 12). If the computed height is < 136 pt — compact height, or font scale ≥ 130 % on regular phones —
the BalanceCard renders as the **strip** (variant `BalanceCard / compact`, [05 §3.1](05-component-library.md)): full content width × 88, radius.l, same brand background/sheen/text
rules; content = restaurant name (`type.caption`, 1 line) above balance (`type.balance`), NFC glyph (20 pt) and
StatusBadge right-aligned. Overline and validity are omitted visually but stay in the accessibility label; the
full card number is already in the TopRow. Padding space.3; card inner padding switches from space.3 to space.4
when height ≥ 180.

### 2.5 Hierarchy

1. **Amount** (AmountDisplay) — what will happen. 2. **Balance** (BalanceCard) — what is possible. 3. **Redeem
button** — the commit, repeating the amount. 4. Keypad. 5. Assist chip. 6. Card identity (restaurant, •••• 6488,
validity, full number in TopRow). The amount is the largest type on screen (64 vs 40 balance).

### 2.6 Typography

| Element | Token | Notes |
|---|---|---|
| Full card number (TopRow) | type.caption, tnum | 1 line, centred, never truncated (19 chars fit 200 pt) |
| "GIFT CARD" | type.overline | uppercase, +8 % |
| Restaurant name | type.title.m | 1 line, tail ellipsis on ID-1; full name in a11y label |
| Balance | type.balance, tnum | shrink-to-fit min 40 pt is n/a (40 is the token); never truncated |
| `•••• 6488 · Valid until 26.09.2029` | type.caption, tnum | "No expiry" when `expires_at` null |
| AmountDisplay | type.amount.xl (compact: type.amount.l), tnum | scales to max 130 %, then shrink-to-fit ≥ 40 pt |
| Helper line | type.body.m (600 when "Increase contrast") | 1 line; 2 lines only at font scale ≥ 150 % (card switches to strip) |
| QuickAmountChip | type.label | |
| Keypad digits | type.key, tnum | scale capped at 120 % ([04 §3.7](04-design-system.md)) |
| PrimaryButton | type.label large (17/22) | |

### 2.7 Colour

| Element | Token | Light | Dark |
|---|---|---|---|
| Screen | color.bg.canvas | #FAFAFA | #0A0A0C |
| TopRow ✕ glyph | color.fg.primary | #18181B | #F4F4F5 |
| Card number | color.fg.tertiary | #71717A | #8B8B94 |
| BalanceCard background | restaurant `brand_color`, fallback color.brand.ink | #0F172A | #0F172A |
| BalanceCard text | auto (white / #0A0A0C), ≥ 4.5:1 or ink fallback | — | — |
| NFC glyph arcs | color.accent.saffron | #E8A33D | #F0B454 |
| AmountDisplay (amount > 0) | color.fg.primary | #18181B | #F4F4F5 |
| AmountDisplay (0) | color.fg.tertiary | #71717A | #8B8B94 |
| AmountDisplay (over balance) | color.danger | #B91C1C | #F87171 |
| Helper line — danger | color.danger | #B91C1C | #F87171 |
| Helper line — info | color.fg.secondary | #52525B | #A1A1AA |
| Chip background / label | color.bg.key / color.fg.primary | #F1F1F3 / #18181B | #1E1E23 / #F4F4F5 |
| Keys | color.bg.key → color.bg.keyPressed | #F1F1F3 → #E4E4E7 | #1E1E23 → #2A2A31 |
| PrimaryButton | color.action.primary / color.fg.onAccent | #18181B / #FFFFFF | #F4F4F5 / #0A0A0C |
| PrimaryButton pressed | color.action.primaryPressed | #27272A | #D4D4D8 |
| Disabled button | color.bg.key / color.fg.tertiary | #F1F1F3 / #71717A | #1E1E23 / #8B8B94 |
| HoldButton progress ring | color.hold.progress (track: color.hold.track #4F4F52 / #CFCFD0) | #E8A33D | #B45309 |

Dark theme: BalanceCard gets 1 px color.border.subtle instead of shadow; keys have no shadow in either theme.

### 2.8 Components

TopRow (Charge configuration: IconButton ✕ left, caption centre, empty 56 slot right — not the S05 `TopBar`) ·
IconButton · BalanceCard · StatusBadge · StatusBanner · AmountDisplay · QuickAmountChip · Keypad · PrimaryButton
(large) · HoldButton · Spinner · Skeleton · Snackbar · Dialog (switch-card fallback only). Anatomy in
[05](05-component-library.md).

### 2.9 Amount entry rules (Keypad + AmountDisplay)

| Input | Result |
|---|---|
| Digit 1–9 | Shifts in from the right: `0,00 → 0,02 → 0,24 → 2,49 → 24,90` |
| `0` / `00` at amount 0 | No-op, no haptic |
| `00` when only 1 digit fits (6 digits typed) | Adds one `0` |
| 8th digit (max 7 digits = € 99.999,99) | Ignored; AmountDisplay limit nudge ±3 pt × 2 cycles in 240 ms (half the M02 amplitude, [06](06-motion-guidelines.md) M12); haptic.warning |
| ⌫ tap | Removes last digit (`24,90 → 2,49`) |
| ⌫ long press 500 ms | Clears to 0; haptic.select |
| QuickAmountChip "Use balance · € 32,50" | Amount = balance; haptic.select |
| Any change | Pending attempt discarded (§ 1.1); over-balance and max-single checks re-evaluated synchronously |

Parity with web `keypad.tsx`: same POS shift-in, same 3 × 4 layout incl. `00`; native caps at 7 digits (web: 8)
per brief, and adds long-press clear, chip and limits.

### 2.10 Base variant — Active card, amount > 0, amount < € 100

| Field | Specification |
|---|---|
| Purpose | Type and redeem any amount ≤ balance. |
| Entry/exit | § 2.2. |
| Wireframe | § 2.3. |
| States | **Amount 0** → § 2.10a. **Loading** → § 2.19. **Error** → helper line / banner per § 1.3. **Disabled** → button disabled when amount 0, amount > balance, amount > known max single, throttled/velocity with known retry time, Snackbar pending. |
| Motion | Entry: motion.spring.card (response 0.42, damping 0.82) BalanceCard scale 0.92 → 1 + fade, keypad rises 16 pt + fade, motion.base, ease.decelerate, 40 ms stagger per key row. Exit to S05: cross-fade motion.base. Reduce Motion: 160 ms cross-fades only. Details [06](06-motion-guidelines.md). |
| Micro-interactions | Key press: scale 0.96 + color.bg.keyPressed in motion.instant (90 ms), release motion.fast (160 ms) ease.standard. **Digit roll-in:** new digit enters from +12 pt x, opacity 0 → 1, motion.fast ease.decelerate; existing digits slide left one tabular width, motion.fast ease.standard; the currency sign never moves vertically. Delete: last digit exits +12 pt x, fade, motion.instant. Chip: all digits cross-fade motion.fast. Button label updates in the same frame as AmountDisplay (no animation on label text). |
| Haptics | haptic.key per effective key press (not for no-ops) · haptic.select for chip, ⌫ long press · haptic.warning for 8th digit and over-balance crossing. |
| Sound | None (no sound on key presses). |
| Accessibility | Focus order: ✕ → card number → BalanceCard → AmountDisplay → helper → chip → keys (row-wise) → button. ✕ "Close card". BalanceCard is one element: "Gift card, Trattoria Bella Vista, balance 32 euro 50, card ending 6488, valid until 26 September 2029". AmountDisplay is a polite live region, debounced 400 ms: "Amount 24 euro 90". Keys: "1" … "9", "double zero", "Delete" + hint "Long press to clear". Button: "Redeem 24 euro 90". Full number TopRow read digit groups: "5285 1058 7098 6488". Touch targets ≥ 56. |
| Tablet & landscape | § 2.20. |
| Portrait | Phones portrait-locked; § 2.3–2.4. |
| Android | Reader mode on; new card tap → § 2.18. System back = ✕. Edge-to-edge; nav-bar scrim transparent, bottom inset from gesture area. Button ripple suppressed in favour of pressed colour. |
| iPhone | Edge-swipe back = ✕. Universal-link card opens handled as § 2.18. No NFC session while on S07. |
| Time | Card visible ≤ 0.24 s after lookup response; 4-digit amount ≈ 1.2 s; tap Redeem 0.1 s. |
| Acceptance | **AC-S07-1** Typing 2, 4, 9, 0 shows `€ 24,90` and the button reads "Redeem € 24,90" in the same frame. **AC-S07-2** Every key has a 56 pt+ hit area, ≥ 72 pt high on regular height, gaps ≥ 8 pt. **AC-S07-3** Button bottom edge sits 8 pt above the safe area; button centre is in the bottom 45 % on P-R, P-L, A-R, P-C. **AC-S07-4** Amount is never truncated at € 99.999,99 on P-C (shrink-to-fit ≥ 40 pt). **AC-S07-5** VoiceOver announces "Amount 24 euro 90" once, ≤ 500 ms after the last key. **AC-S07-6** 8th digit is ignored with shake + haptic.warning. **AC-S07-7** Long-press ⌫ 500 ms clears to 0. **AC-S07-8** BalanceCard keeps 1.586:1 ± 0.01 in ID-1 presentation on all regular-height viewports; strip appears when computed height < 136 pt. |

#### 2.10a Amount = 0

| Field | Delta to base |
|---|---|
| Purpose | Invite input; nothing to commit. |
| Wireframe | AmountDisplay `€ 0,00` in color.fg.tertiary; button disabled with label **"Enter amount"** (`charge.enterAmount`). Chip visible. |
| States | Initial state on every entry. |
| Haptics / Sound | None. |
| Accessibility | Button "Enter amount, dimmed". AmountDisplay "Amount 0 euro". |
| Android | New card tap replaces the card immediately (§ 2.18). |
| Acceptance | **AC-S07-9** Disabled button cannot fire and has no pressed state; label is exactly "Enter amount". |

### 2.11 Variant — Amount > balance

```
 │            ╭──────── BalanceCard € 32,50 ─────╮        │
 │                     € 40,00                           │ AmountDisplay, color.danger
 │          ⚠ € 7,50 more than the balance               │ Helper line 22, icon 16 + type.body.m, color.danger
 │              ( Use balance · € 32,50 )                │ chip, emphasised (1.5 pt color.border.strong ring)
 │  [ keypad unchanged ]                                  │
 │  ┌─────────────────────────────────────────────┐      │
 │  │        Redeem € 40,00   (disabled)          │      │
 │  └─────────────────────────────────────────────┘      │
```

| Field | Delta to base |
|---|---|
| Purpose | Prevent a guaranteed server rejection and offer the one-tap fix; the waiter collects the rest by other means. |
| Entry/exit | Entered when the amount becomes > balance; left when it becomes ≤ balance (⌫, chip). |
| Hierarchy | Red amount + message, then chip as the obvious next step. |
| Typography | Helper type.body.m; chip type.label. |
| Colour | AmountDisplay + helper color.danger; icon ⚠ color.danger; chip ring color.border.strong. |
| Components | Helper line, QuickAmountChip (emphasised), PrimaryButton disabled. |
| Motion | Helper fades in motion.fast. |
| Micro-interactions | **Over-balance shake:** AmountDisplay translates x 0 → +6 → −6 → +6 → −6 → 0 pt (2 cycles) in 240 ms, ease.standard, only on the **crossing** from ≤ balance to > balance (not on further digits). Reduce Motion: no shake, helper fade only. |
| Haptics | haptic.warning on crossing. |
| Sound | None. |
| Accessibility | Assertive announcement once per crossing: "7 euro 50 more than the balance. Redeem not available." Chip: "Use balance, 32 euro 50". |
| Tablet | Helper and chip in right pane (§ 2.20). |
| Android / iPhone | Identical. |
| Time | Fix = 1 chip tap (≈ 0.4 s). |
| Acceptance | **AC-S07-10** Balance € 32,50, amount € 32,51 → helper "€ 0,01 more than the balance", button disabled, shake exactly once. **AC-S07-11** Chip sets € 32,50, clears helper, enables button "Redeem € 32,50". **AC-S07-12** Status is conveyed by icon + text, not colour alone. |

### 2.12 Variant — Amount ≥ € 100,00 (HoldButton)

```
 │  ┌─────────────────────────────────────────────┐      │
 │  │  ◌  Redeem € 124,00                          │      │ HoldButton 64: ring 28 pt at leading 20 pt,
 │  │     Hold to redeem                          │      │ label type.label large + type.caption (2 lines, 40 pt)
 │  └─────────────────────────────────────────────┘      │
```

| Field | Delta to base |
|---|---|
| Purpose | A deliberate 600 ms gesture for large amounts (`holdToConfirmThresholdCents = 10000`, inclusive). |
| Entry/exit | Button morphs PrimaryButton ↔ HoldButton when the amount crosses € 100,00 (cross-fade motion.fast). Hold complete → S08. |
| Typography | Line 1 `charge.redeem` type.label large; line 2 `charge.hold` type.caption at 80 % opacity of color.fg.onAccent. |
| Colour | Ring progress color.hold.progress (#E8A33D / #B45309); track color.hold.track. |
| States | Idle → holding (0–600 ms) → complete → S08. Release or finger leaves bounds + 12 pt slop before 600 ms → cancel. |
| Motion | Ring fills linearly 0 → 100 % over 600 ms; button scales to 0.98 on touch-down (motion.instant). Cancel: ring reverses to 0 in motion.fast, scale returns. Reduce Motion: ring still fills (progress indicator), no scale. |
| Micro-interactions | Quick tap (< 150 ms) shows the helper line "Hold to redeem" (info colour) for 2 s and pulses the ring track once (opacity 30 → 60 → 30 %, motion.slow). |
| Haptics | haptic.holdTick at 200/400/600 ms (33/66/100 %); quick-tap: haptic.select. |
| Sound | None until result. |
| Accessibility | Label "Redeem 124 euro. Hold to redeem." Hint "Double-tap and hold to redeem." VoiceOver/TalkBack pass-through (double-tap-and-hold) drives the same 600 ms ring. Switch Control / Voice Control: one activation starts the 600 ms ring automatically; a second activation within 600 ms cancels. Progress announced "33 %, 66 %, done" is **not** spoken (ticks suffice). |
| Android / iPhone | Identical timing; haptic mapping per token table. |
| Time | +0.6 s vs tap. |
| Acceptance | **AC-S07-13** € 99,99 → single tap; € 100,00 → hold required. **AC-S07-14** Release at 590 ms → no request sent, ring reverses. **AC-S07-15** Request is sent within 16 ms of 600 ms; finger still down has no further effect. **AC-S07-16** With VoiceOver, double-tap-and-hold for 600 ms redeems; a plain double tap does not. |

### 2.13 Variant — Partial redemption disabled

```
 │ [✕]        5285 1058 7098 6488                        │
 │   ╭───────────────────────────────────────────╮       │ BalanceCard at max size for the viewport
 │   │ GIFT CARD                            )))   │       │ (P-R: 349 × 220 — height cap 220, ID-1 ratio,
 │   │ Trattoria Bella Vista                      │       │  centred in the 353 content width)
 │   │ € 32,50                                    │       │
 │   │ •••• 6488 · Valid until 26.09.2029          │       │
 │   ╰───────────────────────────────────────────╯       │ space.6 (24)
 │                     € 32,50                           │ AmountDisplay, fixed, color.fg.primary
 │     Only the full balance can be redeemed here.       │ helper, info (color.fg.secondary)
 │                                                       │ flexible space (no keypad, no chip)
 │  ┌─────────────────────────────────────────────┐      │
 │  │     Redeem full balance · € 32,50           │      │ PrimaryButton large (HoldButton if ≥ € 100)
 │  └─────────────────────────────────────────────┘      │
```

| Field | Delta to base |
|---|---|
| Purpose | Restaurant setting `allow_partial_redemption = false`: the only possible action is the whole balance. |
| Entry/exit | Scan response flag false, or redeem 422 INVALID_AMOUNT with `context.balance` (setting changed meanwhile → amount set to `context.balance`, helper shows `redeem.nothingBooked` for 4 s first). |
| Hierarchy | Card → fixed amount → explanation → button. |
| Components | No Keypad, no QuickAmountChip. Button `charge.redeemFull`. |
| States | Balance 0 → zero-balance variant. ≥ € 100 → HoldButton with the same label + "Hold to redeem". |
| Motion | Entry as base without keypad rise. |
| Haptics / Sound | = base. |
| Accessibility | Helper read after amount: "Amount 32 euro 50. Only the full balance can be redeemed here." Button "Redeem full balance, 32 euro 50". |
| Tablet | Right pane shows AmountDisplay + helper + button vertically centred; no keypad. |
| Time | Card → Redeem: 1 tap (≈ 0.5 s). |
| Acceptance | **AC-S07-17** No keypad or chip is rendered. **AC-S07-18** Button text contains the full balance in restaurant locale. **AC-S07-19** Balance € 150,00 → HoldButton. |

### 2.14 Card-state variants (card data visible, no redemption)

Shared layout for zero balance, blocked, expired, inactive, replaced. Rule from the brief: problems that concern
**the card** stay on S07 with the BalanceCard visible so the waiter can tell the guest balance and status.

```
 │ [✕]        5285 1058 7098 6488                        │ TopRow 56
 │   ╭───────────────────────────────────────────╮       │ BalanceCard, ID-1 max size, 40 % desaturated
 │   │ GIFT CARD                            )))   │       │ (blocked/expired/replaced); StatusBadge bottom-left
 │   │ Trattoria Bella Vista                      │       │
 │   │ € 32,50                                    │       │
 │   │ [⛔ Blocked]         •••• 6488              │       │
 │   ╰───────────────────────────────────────────╯       │ space.6 (24)
 │  ┌─────────────────────────────────────────────┐      │ StatusBanner (danger|warning), radius.m,
 │  │ ⛔  Card blocked                             │      │ padding space.4, icon 24,
 │  │     Reason: Reported lost                   │      │ title type.body.l 600, body type.body.m
 │  │     Please get a manager.                   │      │ max 3 lines body
 │  └─────────────────────────────────────────────┘      │
 │                                                       │ flexible space
 │  ┌─────────────────────────────────────────────┐      │
 │  │                    Done                     │      │ PrimaryButton large → S05
 │  └─────────────────────────────────────────────┘      │
```

Common fields for all five:

| Field | Specification |
|---|---|
| Entry/exit | From lookup (status) or from a redeem 422/409 (§ 1.3, then with helper line `redeem.nothingBooked` shown above the banner for 4 s). Exit: "Done", ✕, back → S05; Android new card tap → replaces card (amount is 0 here). |
| Hierarchy | Status banner title › balance › reason/instruction › Done. |
| Typography | Banner title type.body.l 600; body type.body.m; badge type.caption 600. |
| Components | BalanceCard (desaturated where listed), StatusBadge, StatusBanner, PrimaryButton ("Done", `common.done`). No Keypad, AmountDisplay or chip. |
| Motion | Card entry = base; banner slides up 8 pt + fade, motion.base, 120 ms after card settles. Desaturation applied before first frame (no animated drain). |
| Micro-interactions | None. |
| Accessibility | On appear, assertive: "{banner title}. {body}". Banner is a single element after the BalanceCard in focus order. StatusBadge text is part of the BalanceCard label ("status blocked"). |
| Tablet | Left pane: card + banner; right pane: centred "Done" button, no keypad. |
| Android | Reader mode stays on; the next card tap replaces this card directly. |
| iPhone | "Done" → S05 where "Scan card" is one tap away. |
| Time | Read status ≤ 1 s; Done 0.3 s. |

| Variant | Trigger | Badge / desaturate | Banner tone · icon | Banner copy (title / body) | Haptic · Sound (on appear) |
|---|---|---|---|---|---|
| **Zero balance** | status `redeemed` or balance 0 | redeemed · no | warning · empty-card glyph | `card.empty` "No balance left" / `card.empty.body` "This card has been fully used." | haptic.warning · sound.warning |
| **Blocked** | status `blocked` or CARD_BLOCKED | blocked · 40 % | danger · ⛔ | `card.blocked` "Card blocked" / `card.blocked.reason` "Reason: {reason}" (only if `blocked_reason` present; max 2 lines, ellipsis) + `getManager` "Please get a manager" | haptic.error · sound.error |
| **Expired** | `is_expired` or status `expired` or CARD_EXPIRED | expired · 40 % | warning · hourglass | `card.expired` "Card expired" / `card.expired.body` "Expired on {date}. A manager can help." (`{date}` from `expires_at` in restaurant time zone; omitted clause if unknown) | haptic.warning · sound.warning |
| **Inactive** | status `inactive` | inactive · no | warning · pause-circle | `card.inactive` "Card not activated yet" / `card.inactive.body` "It can be redeemed once activated. Please get a manager." | haptic.warning · sound.warning |
| **Replaced** | status `replaced` | replaced · 40 % | warning · swap-arrows | `card.replaced` "Card was replaced" / `card.replaced.body` "The balance is on the new card. Ask the guest for the new card." Balance shown as returned (normally € 0,00) | haptic.warning · sound.warning |

Colour: danger banner color.danger.bg (#FEF2F2 / #2A0E0E), title+icon color.danger (#B91C1C / #F87171), body
color.fg.primary; warning banner color.warning.bg (#FFFBEB / #2A1E06), icon color.warning (#B45309 / #FBBF24),
title and body color.fg.primary (tone is carried by icon + background, never by text colour alone).
"Increase contrast": banner text weight 600.

Acceptance (card-state):
**AC-S07-20** Each status maps to exactly one variant using precedence blocked › expired › replaced › inactive ›
zero balance (e.g. blocked + expired → blocked). **AC-S07-21** No keypad, amount or Redeem is rendered.
**AC-S07-22** `blocked_reason` null → no "Reason:" line. **AC-S07-23** Balance remains readable (≥ 4.5:1) after
40 % desaturation, else the ink fallback applies. **AC-S07-24** Sound/haptic fire once, after the card-detected
feedback of the scan (not simultaneously; ≥ 240 ms later).

### 2.15 Variant — Blocked with reason (worked example)

`blocked_reason = "Reported lost"` → banner: "Card blocked" / "Reason: Reported lost" / "Please get a manager."
The reason is manager-entered free text: rendered verbatim, 2 lines max, never shown on S09 guest view, never
stored in Recent.

### 2.16 Variant — Max single redemption exceeded

| Field | Specification |
|---|---|
| Purpose | Respect the restaurant's per-redemption cap. |
| Entry | Redeem → 422 INVALID_AMOUNT with `context.max_single_redemption` (cents). Once known, the cap is cached for the session and checked **client-side before submit** (same behaviour as over-balance, no server round trip). When backend prerequisite 2 exposes the cap at scan time, the client-side check applies from the first keystroke. |
| Wireframe | Helper line (danger): "Max. € 150,00 per redemption" (`charge.maxSingle`); assist row chip "Use maximum · € 150,00" (`charge.useMax`) replaces "Use balance" while amount > max; button disabled. |
| Motion / micro | Server-triggered entry: button morphs back from spinner (motion.fast), shake 6 pt × 2 / 240 ms on AmountDisplay. Client-side crossing: same as over-balance. |
| Haptics · Sound | Server-triggered: haptic.error · sound.error. Client-side crossing: haptic.warning, no sound. |
| Accessibility | Assertive: "Maximum 150 euro per redemption. Redeem not available." |
| States | `charge.maxSingle` is shown only when the cap value is known. A 422 INVALID_AMOUNT without any `context` is treated like VALIDATION_FAILED (§ 1.3: generic helper + support code). |
| Time | Correction via chip: 0.4 s. |
| Acceptance | **AC-S07-25** After a 422 with cap 15000, typing € 150,01 disables the button without a request. **AC-S07-26** Chip sets exactly € 150,00. **AC-S07-27** Key for the next attempt is new. |

### 2.17 Variant — Velocity limit / rate limit (429)

```
 │                     € 24,90                           │
 │  ┌─────────────────────────────────────────────┐      │ StatusBanner warning, occupies helper + assist
 │  │ ⏱ Limit for this card reached                │      │ rows (70 pt: 22 + 8 + 40), radius.m
 │  │   Possible again in 12 min. Or get a manager.│      │
 │  └─────────────────────────────────────────────┘      │
 │  [ keypad ]                                           │
 │  [ Redeem € 24,90 — disabled while countdown runs ]   │
```

| Field | Specification |
|---|---|
| Purpose | Explain a fraud/rate stop without blame, and when it lifts. |
| Entry | 429 VELOCITY_LIMIT_EXCEEDED (per card per rolling hour) or 429 TOO_MANY_REQUESTS (`retry_after` s; card-operation limiter 90/min per user per terminal). |
| Copy | Velocity, retry time known (`Retry-After` header or `retry_after`): `charge.velocity.title` "Limit for this card reached" + `charge.velocity.bodyTime` "Possible again in {minutes} min. Or get a manager." Unknown (current API sends none for velocity): title + `getManager` "Please get a manager". Rate limit: `charge.rateLimited` "Too many requests — possible again in {seconds} s". |
| States | Time known: button disabled; countdown text updates every 1 s (seconds) or 60 s (minutes); at 0 banner fades out and button re-enables (haptic.select). Time unknown: button stays **enabled**; a new tap is a new attempt (new key). Keypad stays usable. |
| Colour | color.warning.bg / icon color.warning / text color.fg.primary. |
| Motion | Banner cross-fades with helper/chip, motion.base. |
| Haptics · Sound | haptic.warning · sound.warning. |
| Accessibility | Assertive on appear; countdown **not** re-announced each tick (announce only when available again: "Redeem available again"). |
| Tablet | Banner in right pane above keypad. |
| Acceptance | **AC-S07-28** Banner shows minutes when `retry_after ≥ 60`, seconds otherwise. **AC-S07-29** Without retry info the button stays enabled and banner persists until the card is closed or a success happens. **AC-S07-30** Nothing in the copy mentions fraud or the waiter. |

### 2.18 Variant — New card detected while charging

| Field | Specification |
|---|---|
| Purpose | Never charge the wrong card when a second guest's card is tapped. |
| Entry | Android reader-mode read on S07; iPhone universal-link/App-Link open for a **different** card id while S07 is foreground. Same card (same id) → ignored silently. |
| Amount = 0 | Replace immediately: 300 ms cross-fade of BalanceCard + TopRow, haptic.cardDetected + sound.cardDetected. No Snackbar. |
| Amount > 0 | Snackbar replaces the PrimaryButton slot (same 353 × 64 frame on P-R, radius.s, elev.3; surface colours per [05](05-component-library.md)): message `charge.switchCard.message` "Different card detected — Switch?", action TertiaryButton `charge.switchCard.action` "Switch" (right, 56 hit), dismiss by swipe or `charge.switchCard.keep` "Keep" (left). **Redeem is unavailable while the Snackbar shows.** Auto-dismiss after 6 s = Keep. |
| Switch | New card's lookup starts; amount reset to 0; pending attempt discarded; cross-fade 300 ms. |
| During S08 | Taps ignored (§ 1.4). |
| Motion | Snackbar slides up 16 pt + fade from the button position, motion.base, ease.decelerate; button fades out simultaneously. |
| Haptics · Sound | haptic.cardDetected · sound.cardDetected on detection (both cases). |
| Accessibility | With VoiceOver/TalkBack running, a **Dialog** replaces the Snackbar (no timeout): title "Different card detected", buttons "Switch" / "Keep"; focus moves to the Dialog. |
| iPhone | Only via universal links (no reader session on S07). |
| Time | Decision ≤ 1 tap. |
| Acceptance | **AC-S07-31** With € 24,90 typed, a second card tap never changes the card without "Switch". **AC-S07-32** While the Snackbar is shown, the Redeem action cannot fire. **AC-S07-33** Same-card re-tap produces no UI change. |

### 2.19 Variant — Lookup skeleton (card loading)

```
 │ [✕]        ████ ████ ████ ████                        │ caption skeleton 160 × 12
 │            ╭──────────────────────────╮               │ Skeleton card, same frame as the final card,
 │            │ ▒▒▒▒▒▒                    │               │ color.bg.key base, shimmer
 │            │ ▒▒▒▒▒▒▒▒▒▒▒▒              │               │
 │            │ ▒▒▒▒▒▒▒▒                  │               │
 │            ╰──────────────────────────╯               │
 │                     € 0,00                            │ AmountDisplay tertiary
 │                  Still looking …                      │ helper (after 3 s), color.fg.secondary
 │  [ keypad 40 % opacity, disabled ]                    │
 │  [ Enter amount — disabled ]                          │
```

| Field | Specification |
|---|---|
| Purpose | Never a blank screen while `/scan` runs. |
| Timing | 0–150 ms: previous screen stays (no flash). 150 ms: S07 with Skeleton. 3 s: helper `lookup.stillLooking` "Still looking …". 10 s: request abandoned → S10 network. Response arriving at any time: Skeleton cross-fades to content, motion.fast. |
| States | ✕ enabled (cancels lookup, → S05). Keypad and chip disabled (partial rule, balance and status unknown). |
| Motion | Shimmer: gradient sweep 1200 ms linear loop; Reduce Motion: static skeleton at 60 % opacity. |
| Haptics · Sound | None (card-detected feedback already played by S06). |
| Accessibility | Container label "Loading card"; `aria-busy`/`isBusy`; polite "Still looking" at 3 s. |
| Acceptance | **AC-S07-34** A 100 ms lookup shows no skeleton. **AC-S07-35** At 10.0 s the S10 network variant appears. **AC-S07-36** Keypad inputs are ignored during skeleton. |

### 2.20 Tablet & landscape (S07 all variants)

**Tablet portrait (T-P 820 × 1180):** single centred column, max width 440, margins 32. BalanceCard 440 × 277
(ID-1, tablet cap 280). Keys 80 high, gaps space.3 (12). PrimaryButton large 64. AmountDisplay type.amount.xl.

**Tablet landscape (T-L 1180 × 820) — two-pane:**

```
 x:32                         574  606                        1148
 ┌──────────────────────────────┬─────────────────────────────┐ y 24 (safe)
 │ [✕]   5285 1058 7098 6488    │                             │ TopRow 56 spans left pane
 │  ╭────────────────────────╮  │            € 24,90          │ AmountDisplay 68
 │  │ GIFT CARD          )))  │  │                             │ helper 22
 │  │ Trattoria Bella Vista  │  │     ( Use balance · € 32,50 )│ chip 40
 │  │ € 32,50                │  │  ┌─────┐ ┌─────┐ ┌─────┐    │ Keypad: 3 × 128 wide,
 │  │ •••• 6488 · 26.09.2029 │  │  │  1  │ │  2  │ │  3  │    │ keys 80 high, gaps 12
 │  ╰────────────────────────╯  │  │  …  │ │  …  │ │  …  │    │ (4 × 80 + 3 × 12 = 356)
 │  Card     5285 … 6488        │  └─────┘ └─────┘ └─────┘    │
 │  Valid    26.09.2029         │  ┌───────────────────────┐  │
 │  [StatusBanner if any]       │  │    Redeem € 24,90      │  │ PrimaryButton large 64
 │                              │  └───────────────────────┘  │
 └──────────────────────────────┴─────────────────────────────┘ y 800
```

Left pane 542 wide: card 440 × 277 centred, summary rows (type.body.m labels color.fg.tertiary, values
color.fg.primary) and card-state banners. Right pane 542 wide, content max 420, block vertically centred (tablet
on counter: centre is the reach zone). Gutter space.8 (32), divider none. Snackbar replaces the right-pane button.
Transition: panes enter together (left motion.spring.card, right fade-up 16 pt motion.base). Android tablets ≥ 600 dp
wide in landscape use the same layout; phones never rotate.

---

## 3. S08 — Redeeming (in-place states of S07)

S08 is not a new screen: S07 stays, the button becomes the progress surface, and — only when the network fails
— an uncertain panel replaces the keypad area.

### 3.1 State machine

| # | State | Enters when | Button | Keypad / chip / ✕ | Leaves to |
|---|---|---|---|---|---|
| 1 | Pressed | touch-down | color.action.primaryPressed, scale 0.98 | enabled | 2 on tap-up (or hold 100 %) · base on cancel |
| 2 | Submitting | request sent (key per § 1.1) | label kept 0–150 ms, then Spinner 20 pt + `charge.redeeming` "Redeeming € 24,90 …" | locked (40 % opacity, motion.fast) | S09 · 3 · 4 · 6 |
| 3 | Slow | request pending 8 s → aborted and re-sent with same key | Spinner + `redeem.slow` "Connection slow — retrying" | locked | S09 · 4 · 6 |
| 4 | Uncertain (auto-retrying) | transport failure / offline / 5xx / second timeout | hidden; uncertain panel | locked | S09 · 5 · 6 |
| 5 | Uncertain (final) | 3 retries failed or 20 s since tap | hidden; panel with "Try again" / "Cancel" | locked except panel buttons | 2 (Try again) · S07-cancelled (Cancel) |
| 6 | Definitive error | 4xx per § 1.3 | back to base label | unlocked | S07 variant |
| 7 | Success / replayed | 201 or 200 `replayed: true` | — | — | S09 |

Retry schedule (same key throughout): attempt 1 (timeout 8 s) → on transport failure wait **1 s** → attempt 2 →
wait **2 s** → attempt 3 → wait **4 s** → attempt 4. Each attempt times out after 8 s. Overall cap 20 s after the
tap; whichever comes first ends automatic retrying (→ state 5). If the OS reports connectivity restored during
a wait, the pending wait is skipped. In state 5, connectivity restored triggers **one** automatic retry with the
same key.

### 3.2 Pressed & Submitting

| Field | Specification |
|---|---|
| Purpose | Show that the commit was received, without flicker on fast (≤ 0.5 s) responses. |
| Wireframe | Same frame as base; button content = `Spinner` (20 pt, 2 pt stroke, color.fg.onAccent) + 8 pt + label. |
| Typography | type.label large. |
| Colour | Button stays color.action.primary (not disabled grey — it is busy, not unavailable). |
| Motion | Spinner fades in motion.instant at 150 ms; keypad dims motion.fast. |
| Haptics · Sound | None until result (tap already gave the pressed state; hold gave holdTicks). |
| Accessibility | Button label "Redeeming 24 euro 90", `isBusy`; polite "Redeeming". ✕ reported dimmed. |
| Android | Back ignored; reader-mode taps ignored. |
| iPhone | Edge swipe disabled; universal links queued. |
| Time | Typical 0.1 s + ≤ 0.5 s → most responses never show the spinner. |
| Acceptance | **AC-S08-1** No spinner if the response arrives < 150 ms. **AC-S08-2** Exactly one request in flight per attempt; double-tap sends one request. **AC-S08-3** ✕, back, keypad and chip have no effect while submitting. |

### 3.3 Slow (> 8 s)

| Field | Specification |
|---|---|
| Purpose | Honest feedback that the server is slow, while retrying safely. |
| Wireframe | Button: Spinner + "Connection slow — retrying" (1 line; at font scale ≥ 150 % 2 lines, button grows to 80). Helper line (info): `uncertain.body` "Checking … Nothing is ever booked twice." |
| Motion | Label cross-fade motion.fast. |
| Haptics · Sound | None (avoid alarming the guest while it may still succeed). |
| Accessibility | Polite: "Connection slow, retrying. Nothing is ever booked twice." |
| Acceptance | **AC-S08-4** At 8.0 s the first request is aborted and re-sent with the **same** `Idempotency-Key` and a **new** `X-Request-Id`. |

### 3.4 Uncertain — auto-retrying

```
 │            ╭──────── BalanceCard € 32,50 ─────╮        │ card unchanged (no optimistic balance!)
 │                     € 24,90                           │ AmountDisplay, color.fg.secondary
 │  ┌─────────────────────────────────────────────┐      │ Uncertain panel replaces helper + chip +
 │  │ ◌  Connection interrupted                   │      │ keypad (same total height: 22+8+40+12+312)
 │  │    Checking … Nothing is ever booked twice. │      │ color.warning.bg, radius.l, padding space.5
 │  │    Attempt 2 of 3                           │      │
 │  │                                             │      │
 │  │    Tell the guest: “One moment please,      │      │ guest hint, type.body.m, color.fg.secondary
 │  │    the payment is being confirmed.”         │      │
 │  └─────────────────────────────────────────────┘      │
 │  [ button area: empty 64, reserved ]                  │
```

| Field | Specification |
|---|---|
| Purpose | Make the one dangerous moment calm and unambiguous: money may or may not have moved; the app finds out. |
| Hierarchy | Title › reassurance › attempt counter › what to say to the guest. |
| Typography | Title `uncertain.title` type.title.m; body `uncertain.body` type.body.l; counter `uncertain.retrying` type.caption tnum; guest hint `uncertain.guestHint` type.body.m. |
| Colour | Panel color.warning.bg; ProgressRing 24 pt indeterminate color.warning; text color.fg.primary / color.fg.secondary. |
| Components | StatusBanner (large, warning) with ProgressRing; no buttons in this state. |
| Motion | Keypad fades out motion.fast while the panel fades/scales 0.98 → 1, motion.base. Counter text cross-fades. |
| Haptics · Sound | Once on entering: haptic.warning, **no sound** (retries are silent — [11](11-sound-and-haptics.md) E44). Not repeated per retry. |
| Accessibility | Assertive once: "Connection interrupted. Checking. Nothing is ever booked twice." Counter changes polite. Focus moves to the panel title. |
| Tablet | Panel replaces keypad in the right pane. |
| Time | Up to 20 s from tap. |
| Acceptance | **AC-S08-5** Retries at +1 s, +2 s, +4 s after each failure, all with the same key. **AC-S08-6** The BalanceCard never shows a reduced balance before server confirmation. **AC-S08-7** A success during retrying goes straight to S09. |

### 3.5 Uncertain — final (manual)

```
 │  ┌─────────────────────────────────────────────┐      │
 │  │ ⚠  Connection interrupted                   │      │
 │  │    Not confirmed yet. Try again — nothing   │      │ `uncertain.failedBody`
 │  │    is ever booked twice.                    │      │
 │  │    Tell the guest: “One moment please,      │      │
 │  │    the payment is being confirmed.”         │      │
 │  └─────────────────────────────────────────────┘      │ space.3
 │  ┌─────────────────────┐ ┌─────────────────────┐      │ SecondaryButton "Cancel" (left, 56)
 │  │       Cancel        │ │     Try again       │      │ PrimaryButton regular "Try again" (right, 56)
 │  └─────────────────────┘ └─────────────────────┘      │ gap space.3; widths (353 − 12) / 2
```

| Field | Specification |
|---|---|
| Purpose | Hand control to the waiter without ever losing the idempotency guarantee. |
| Try again | Re-sends with the **same key** → state 2. If it was booked meanwhile: 200 `replayed: true` → S09 as normal. |
| Cancel | Returns to S07 **unchanged** (same card, same amount, same balance display) with a warning StatusBanner in the helper+assist area: `uncertain.cancelled` "Not confirmed. Scan the card again before charging." + `uncertain.cancelledGuestHint`. The pending attempt (key + card + amount) is **kept**: pressing Redeem again with the same amount reuses the key, so a booking that did reach the server is replayed, never duplicated. Changing the amount or closing the card discards it; the banner therefore recommends a fresh scan first (fresh balance = truth). |
| What the waiter says | During checking: **"One moment please, the payment is being confirmed."** After Cancel: **"The payment isn't confirmed. We'll check the balance before charging again."** The waiter must **not** say "nothing was charged": the app cannot know until the server answers. If a later scan shows the reduced balance, the booking went through; if not, nothing was booked. |
| Recent | Unconfirmed attempts are never added; added only when a (replayed) success arrives. |
| Colour | Cancel = SecondaryButton (color.bg.key); Try again = PrimaryButton. Not adjacent primaries (one primary). |
| Haptics · Sound | Entering final: haptic.warning (no second sound). Cancel: haptic.select. |
| Accessibility | Focus to "Try again". Labels "Try again, same payment, never booked twice"; "Cancel, payment not confirmed". |
| Android | Back = Cancel. |
| iPhone | Edge swipe = Cancel. |
| Time | Decision 1 tap. |
| Acceptance | **AC-S08-8** "Try again" request carries the identical `Idempotency-Key`. **AC-S08-9** After Cancel, Redeem with unchanged amount reuses the key; after changing the amount, a new key is used. **AC-S08-10** Cancel does not alter card, amount or Recent. **AC-S08-11** No copy states that nothing was booked. |

### 3.6 Definitive error — card changed meanwhile (CARD_BLOCKED / CARD_EXPIRED / CARD_NOT_REDEEMABLE / INVALID_CARD_STATE)

S07 switches to the matching card-state variant (§ 2.14) using the error code (blocked without reason — no data
available; expired without date if unknown). Helper line above the banner for 4 s: `redeem.nothingBooked`
"Nothing was booked." Haptic.error · sound.error (replaces the variant's appear feedback). Assertive: "Nothing
was booked. Card blocked. Please get a manager." Key closed. **AC-S08-12** Card is updated without calling `/scan`.

### 3.7 Definitive error — IDEMPOTENCY_CONFLICT

Should not occur (keys are per card + amount). Handling: new key generated, S07 base restored with helper (info)
`redeem.tapAgain` "Please tap Redeem again." — **no automatic resubmit** (a money action always needs a human
action). haptic.warning, no sound. Support code logged. **AC-S08-13** No second request is sent without a new
tap.

### 3.8 Definitive error — INSUFFICIENT_BALANCE (balance changed meanwhile)

| Field | Specification |
|---|---|
| Purpose | Another device redeemed first; show the true balance instantly. |
| Behaviour | BalanceCard balance updates to `context.balance` (digit roll, motion.base); amount kept → now > balance → over-balance variant (§ 2.11) with helper `redeem.balanceChanged` "Balance changed: now € 20,00" for 4 s, then the regular over-balance message. Chip "Use balance · € 20,00". `context.balance = 0` → zero-balance variant. |
| Haptics · Sound | haptic.error · sound.error (no shake — the amount did not change). |
| Accessibility | Assertive: "Balance changed, now 20 euro. 4 euro 90 more than the balance." |
| Acceptance | **AC-S08-14** Balance displayed equals `context.balance`, no extra request. **AC-S08-15** Next Redeem uses a new key. |

### 3.9 Replayed success

200 with top-level `replayed: true` (web and native share the server; web ignores the flag): treated exactly as
201 — same S09, same sound, same Recent entry (deduplicated by `transaction.id`). **AC-S08-16** A replay never
creates a second Recent row.

---

## 4. S09 — Success

### 4.1 Purpose

Confirm unmistakably — for waiter and guest — that the money moved, show what is left, and be ready for the next
card within 4 s without any tap.

### 4.2 Entry / exit

| Entry | Trigger |
|---|---|
| S08 | 201 or 200 `replayed: true` |

| Exit | Trigger | Transition |
|---|---|---|
| S05 | CountdownHairline completes (4 s) | cross-fade motion.base |
| S05 | Tap anywhere outside controls; "Done" (Android) | cross-fade motion.fast |
| S06 (iPhone sheet) | "Scan next card" | system sheet directly (1 tap) |
| S12 (iPad) | "Scan next card" (no NFC) | push, motion.base |
| S07 (Android) | New card tap | 300 ms cross-fade + haptic.cardDetected |
| S09 guest view | "Show guest" | § 4.8 |

### 4.3 Wireframe — P-R portrait (iPhone)

```
 ┌───────────────────────────────────────────────────────┐ y 0
 │ status bar                                             │
 ├═══════════════════════════════════════════════════════┤ y 59 CountdownHairline 2 pt, full bleed,
 │                                                       │      shrinks right→left (mirrored in RTL)
 │                                                       │ flexible (content block centred in y 61–682)
 │                     ╭──────╮                          │ y 205  SuccessMark 96 × 96
 │                     │  ✓   │                          │
 │                     ╰──────╯                          │ y 301  space.6 (24)
 │                     Redeemed                          │ y 325  type.title.m, color.success, 28
 │                                                       │        space.1 (4)
 │                    € 24,90                            │ y 357  type.amount.l, 52
 │                                                       │        space.4 (16)
 │            Remaining balance € 8,60                   │ y 425  type.title.m, color.fg.primary, 28
 │                   •••• 6488                           │ y 457  type.caption, color.fg.tertiary, 18
 │                                                       │ flexible
 │                  [ Show guest ]                       │ y 682  TertiaryButton 56 (`success.showGuest`)
 │                                                       │ y 738  space.2 (8)
 │  ┌─────────────────────────────────────────────┐      │ y 746
 │  │             Scan next card                  │      │ PrimaryButton large 64
 │  └─────────────────────────────────────────────┘      │ y 810 + space.2 (8) → y 818
 │ home indicator                                        │ safe 34
 └───────────────────────────────────────────────────────┘
```

Android bottom area (replaces the iPhone button block, same bottom alignment):

```
 │               )))  Just tap the next card             │ hint row 56: NfcScanAnimation 24 pt (static rings)
 │                                                       │ + type.body.m color.fg.secondary
 │  ┌──────────────────────┐ ┌──────────────────────┐    │ SecondaryButton "Show guest" | SecondaryButton "Done"
 │  │      Show guest      │ │         Done         │    │ 56 each, gap space.3
 │  └──────────────────────┘ └──────────────────────┘    │
```

### 4.4 Specification

| Field | Specification |
|---|---|
| Hierarchy | SuccessMark › amount › remaining balance › card › next action. |
| Typography | "Redeemed" `success.title` type.title.m · amount type.amount.l tnum · `success.remaining` type.title.m tnum · `•••• 6488` type.caption · hint type.body.m · buttons type.label (large on PrimaryButton). |
| Colour | Canvas color.bg.canvas; SuccessMark circle color.success (#047857 / #34D399) with check color.fg.onSuccess (#FFFFFF / #0A0A0C); halo ring color.success.bg (#ECFDF5 / #052E22) 24 pt wide; "Redeemed" color.success; hairline color.success on track color.border.subtle. |
| Components | CountdownHairline · SuccessMark · PrimaryButton (iPhone/iPad) · TertiaryButton / SecondaryButton · NfcScanAnimation (Android hint) · no TopBar, no ✕. |
| States | Loading/empty/error: n/a (only reached with a confirmed response). Countdown paused while the app is backgrounded (resumes on return with the remaining time; if > 15 min, the unlock flow takes precedence and S09 is dropped to S05). |
| Motion | t = 0 response: S07 content fades out motion.fast; halo scale 0.6 → 1, motion.spring.card; circle stroke draws t = 0 → 240 ms, then check stroke draws t = 240 → 440 ms (200 ms), ease.decelerate; haptic.success + sound.success at t = 0; "Redeemed" + amount rise 8 pt + fade at t = 160, motion.base; remaining + card at t = 240; complete ≈ t 520 (motion.emphasis). CountdownHairline starts at t = 520, 4000 ms linear. Reduce Motion: 160 ms cross-fade, check fully drawn, hairline still runs. [06](06-motion-guidelines.md). |
| Micro-interactions | Tap anywhere (outside buttons) → S05 immediately. Hairline does not restart on touch. |
| Haptics | haptic.success at t = 0. |
| Sound | sound.success at t = 0 (signature two-note chime; respects silent switch / ringer mode). |
| Accessibility | Assertive at t = 0: "Redeemed 24 euro 90, remaining balance 8 euro 60". Focus to the PrimaryButton (iPhone) / "Done" (Android). With VoiceOver/TalkBack on, auto-return is **extended to 10 s** (the announcement takes ~3 s) — the hairline runs 10 s. Hairline has no a11y element. |
| Tablet & landscape | Content block centred, max width 440; T-L: same centred column (no two-pane). Buttons max width 440. |
| Portrait | As wireframe. |
| Android | Reader mode on: a card tap during S09 goes straight to S07 for that card (the success is final; nothing to lose). Hint `success.next.android`. "Done" → S05. |
| iPhone | `success.next.ios` PrimaryButton opens the NFC system sheet with `ios.sheet.alert` directly. iPad: same label opens S12. |
| Time | Success visible to guest 0.8 s; waiter can proceed immediately; ready-for-next at ≤ 4.52 s without a tap. |
| Acceptance | **AC-S09-1** Recent row is written before the first success frame. **AC-S09-2** Sound and haptic fire within 50 ms of the response, exactly once (also for replays). **AC-S09-3** Auto-return at 4.52 s ± 50 ms after response (10.52 s with screen reader). **AC-S09-4** Tap anywhere returns in ≤ 160 ms. **AC-S09-5** iPhone "Scan next card" opens the NFC sheet with one tap. **AC-S09-6** Android new card tap during countdown opens S07 of the new card. **AC-S09-7** Amounts are the server values (`transaction.amount`, `data.card.balance`), not client-computed. |

### 4.5 Variant — Full-balance redemption ("Card is now empty")

`data.card.balance = 0` (status becomes `redeemed`): the remaining line is replaced by `success.empty` "Card is
now empty" (type.title.m, color.fg.primary) with a StatusBadge "redeemed" beside `•••• 6488`. Everything else
= S09. Accessibility: "Redeemed 32 euro 50. Card is now empty." **AC-S09-8** The word "0,00" is not shown; the
empty message is.

### 4.6 Recent entry

Written on response receipt (before animation): `{transaction.id, created_at, card last 4, amount, balance_after,
X-Request-Id}`. Dedup by `transaction.id`.

### 4.7 Timing budget check

| Step | Budget | S09 contribution |
|---|---|---|
| Response → first success frame | ≤ 16 ms | render |
| Mark complete | 520 ms | animation |
| Auto-return | + 4000 ms | countdown |

### 4.8 Show guest (presentation mode of S09)

```
 ┌───────────────────────────────────────────────────────┐
 │                                                       │ no status-bar content change, no staff UI
 │                      ╭────╮                           │ SuccessMark 64
 │                      │ ✓  │                           │ space.4
 │                     Redeemed                          │ type.title.l, color.success
 │                                                       │
 │                   € 24,90                             │ type.amount.xl (64)
 │                                                       │ space.8 (32)
 │                Remaining balance                      │ type.title.m, color.fg.secondary
 │                   € 8,60                              │ type.balance (40), color.fg.primary
 │                                                       │ space.4
 │             Trattoria Bella Vista · •••• 6488         │ type.caption, color.fg.tertiary
 │                                                       │
 │                                                       │ (no buttons; tap anywhere to close)
 └───────────────────────────────────────────────────────┘
```

| Field | Specification |
|---|---|
| Purpose | The waiter turns the phone to the guest; the guest reads amount and remaining balance at arm's length. |
| Entry/exit | "Show guest" on S09 → countdown **stops** (hairline hidden). Exit: tap anywhere → S05; Android card tap → S07; auto-return after 20 s. |
| Hierarchy | Amount › remaining balance › restaurant/card. |
| Colour | Canvas; theme follows app theme; "Increase contrast" as usual. |
| Components | SuccessMark (static), text only. No TopBar, buttons, hints, support codes, reasons or staff names. |
| Motion | Cross-fade motion.base; amount scales 0.9 → 1 motion.spring.soft. |
| Haptics · Sound | None (already played). |
| Accessibility | Screen reader: "Redeemed 24 euro 90, remaining balance 8 euro 60. Double-tap to close." Whole view is one element. |
| Full balance | "Card is now empty" in type.title.l replaces the remaining block. |
| Tablet | Content scales ×1.25 (tablet type ramps per [08](08-responsive-behaviour.md)); centred. |
| Acceptance | **AC-S09-9** No interactive control is visible. **AC-S09-10** Remaining balance ≥ 40 pt. **AC-S09-11** Auto-close at 20 s. |

---

## 5. S10 — Problem screens

### 5.1 ProblemScreen template

```
 ┌───────────────────────────────────────────────────────┐ y 0
 │ status bar                                  safe 59    │
 ├───────────────────────────────────────────────────────┤ y 59
 │ [✕]                                                   │ TopRow 56 (✕ → S05)
 │                                                       │ flexible (block centred in y 115 – 594)
 │                    ╭─────────╮                         │ Illustration 120 × 120 (96 on compact height),
 │                    │   ?▭    │                         │ style and inventory per [10 §4](10-assets-icons-illustrations.md)
 │                    ╰─────────╯                         │ space.6 (24)
 │                  Card not found                       │ type.title.l, color.fg.primary, max 2 lines, centred
 │                                                       │ space.2 (8)
 │     This card is not in the system. Check the        │ type.body.l, color.fg.secondary, max 2 lines,
 │     card or ask the guest for another one.           │ max width 320
 │                                                       │ flexible
 │                    Code 7F3A9C                        │ type.caption, color.fg.tertiary, 18; space.4 (16)
 │  ┌─────────────────────────────────────────────┐      │ SecondaryButton 56 (optional)
 │  │            Enter card number                │      │ space.2 (8)
 │  └─────────────────────────────────────────────┘      │
 │  ┌─────────────────────────────────────────────┐      │ PrimaryButton large 64
 │  │               Scan again                    │      │
 │  └─────────────────────────────────────────────┘      │ space.2 (8) → safe 34
 └───────────────────────────────────────────────────────┘
```

| Field | Template specification |
|---|---|
| Purpose | Full-screen outcome when **no card data** is available: what happened + what to do, one line each. |
| Entry | Replaces the S07 skeleton or S06 reading state (cross-fade motion.base). |
| Exit | Primary / secondary as per variant; ✕, back, edge swipe → S05. Android: reader mode **on** (except throttled) — a new tap starts a new lookup directly. |
| Hierarchy | Illustration › title › body › primary › secondary › support code. |
| Typography | Title type.title.l; body type.body.l; code type.caption tnum; buttons type.label (large on primary). |
| Colour | Canvas; tone per variant: danger (color.danger / color.danger.bg), warning (color.warning / color.warning.bg), info (color.info / color.info.bg). Title never coloured. Illustrations follow [10 §4](10-assets-icons-illustrations.md) (monoline, `color.fg.secondary`, one saffron accent, no status colours); tone is carried by the illustration's subject/icon and the text, never by colour alone. |
| Components | ProblemScreen, IconButton, PrimaryButton, SecondaryButton, TertiaryButton. |
| States | Loading: after a primary "Try again", the primary button shows Spinner after 150 ms and the screen stays until the result. Empty: n/a. Disabled: primary disabled only for throttled countdown. |
| Motion | Illustration scale 0.9 → 1 + fade motion.spring.soft; text fade-up 8 pt at +80 ms, motion.base. Reduce Motion: fade only. |
| Micro-interactions | Long-press support code → copy full X-Request-Id + Snackbar "Copied" (`common.copied`). |
| Accessibility | Assertive on appear: "{title}. {body}". Focus to title (heading), then body, primary, secondary, code ("Support code 7 F 3 A 9 C", characters read singly). |
| Tablet & landscape | Block max width 480, centred both axes; buttons max width 400 stacked; T-L same. |
| Android | Back = ✕. |
| iPhone | Primary "Scan again" opens NFC sheet directly (iPad: S12). |
| Time | Understand ≤ 2 s; recover ≤ 1 tap. |

### 5.2 Variants

| Variant | Code(s) | Tone · illustration | Title | Body | Primary | Secondary | Haptic · Sound |
|---|---|---|---|---|---|---|---|
| **Card not found** | 404 CARD_NOT_FOUND (nfc/qr/link) | warning · card with "?" | `problem.notFound.title` | `problem.notFound.body` "This card is not in the system. Check the card or ask the guest for another one." | `common.scanAgain` (Android: listening; button returns to S05) | `common.enterNumber` → S11 | haptic.error · sound.error |
| Card not found — manual | 404, method manual | warning · card with "?" | `problem.notFound.title` | `problem.notFound.bodyManual` "No card with this number. Check the digits." | `common.editNumber` → S11 prefilled | — | haptic.error · sound.error |
| **Card from another restaurant** | 403 CARD_FOREIGN_RESTAURANT | info · card with location pin | `problem.foreign.title` | `problem.foreign.body` "It can only be redeemed at the restaurant that issued it." | `common.done` → S05 | — | haptic.error · sound.error |
| **Verification failed** | 403 NFC_UID_MISMATCH · NFC_SIGNATURE_INVALID · NFC_REPLAY_DETECTED | warning · shield with "i" (never a red alarm) | `problem.verify.title` | `problem.verify.body` "Please don't accept this card for now. A manager can check it." | `common.done` → S05 | TertiaryButton `common.scanAgain` (a bad read is possible; a second failure shows the same screen) | haptic.error · sound.error (per [11](11-sound-and-haptics.md) E25); the visual stays calm — warning tone, no red, no flash (the guest is present) |
| **Scan throttled** | 429 SCAN_THROTTLED · TOO_MANY_REQUESTS (`retry_after`) | info · stopwatch | `problem.throttled.title` "Too many scans" | `problem.throttled.body` "Scanning is possible again shortly." | `problem.scanAgainIn` "Scan again · 0:42" disabled, counts down each second; at 0 → `common.scanAgain` enabled + haptic.select | — | haptic.warning · sound.warning |
| **Network error (lookup)** | no response ≤ 10 s / offline / transport | info · cloud with slash | `offline.title` | `problem.network.body` "The card could not be checked. Check Wi-Fi or mobile data, then try again." | `common.tryAgain` (re-sends identical `/scan`) — **or** `common.scanAgain` when the token carries `picc`+`cmac` (§ 1.2) | — | haptic.warning · sound.warning |
| **Server error** | 5xx on lookup | danger · wrench | `problem.server.title` "Something went wrong" | `problem.server.body` "The problem is on our side. Try again in a moment." | `common.tryAgain` (same SUN rule) | — | haptic.warning · sound.warning |
| Device revoked / restaurant suspended / session expired | 403 DEVICE_REVOKED · RESTAURANT_SUSPENDED · 401 | — | **Not S10.** → S15 in [03a](03a-screens-access-and-scanning.md). Recent is cleared on device revoke per S15. | | | | per 03a |

Verification-failed details: the support line appends a neutral reason tag for managers — `Code 7F3A9C · UID`,
`· SIG` or `· REPLAY` — never the words "clone", "fake" or "fraud". The body plus `getManager` phrasing is the
whole instruction; no guest-facing language. The screen does not auto-dismiss.

Throttled details: Android reader mode is **paused** during the countdown (taps produce no feedback); `retry_after`
≥ 60 shows `m:ss`. VoiceOver announces the remaining time once on appear and "Scanning available again" at 0.

Support code: shown on not found, wrong restaurant, verification failed and server error; **not** on throttled and
network (no request reached the server) — placement list per [12 §2.5](12-ui-copy-and-error-messages.md#25-support-code).

### 5.3 Acceptance (S10)

**AC-S10-1** Every variant shows ≤ 2 lines of body at 100 % font scale on P-R (DE, EN, BHS). **AC-S10-2** Primary
action lies in the bottom 45 %. **AC-S10-3** Verification failed plays haptic.error + sound.error ([11](11-sound-and-haptics.md) E25) but its visual
stays calm: never color.danger, never a red flash, never the words fraud/clone/fake. **AC-S10-4** Throttled primary is disabled until `retry_after` elapses, then
enables without user action. **AC-S10-5** Network "Try again" for SUN tokens never re-posts the stored URL.
**AC-S10-6** Support code equals the last 6 characters (uppercase) of the failing request's X-Request-Id; long
press copies the full id. **AC-S10-7** 401/403 account errors never render S10.

---

## 6. S13 — Recent (sheet) and Recent detail (sheet)

### 6.1 Purpose

Answer "what did I redeem this shift?" — for guest questions and end-of-shift checks. Read-only, local, this
device and this waiter only, since 04:00 (restaurant time zone).

### 6.2 Entry / exit

| Entry | Exit |
|---|---|
| S05 TopBar "Recent" (IconButton, history glyph) | Drag down, scrim tap, ✕, back → S05 |
| — | Row tap → Recent detail (sheet on sheet) → close → Recent |

Not reachable from S07/S08/S09 (keeps the money path linear).

### 6.3 Wireframe — Recent sheet, P-R (medium detent 62 %, large detent to safe top + 12)

```
 ┌───────────────────────────────────────────────────────┐
 │                    S05 behind scrim                    │ color.scrim
 ╭───────────────────────────────────────────────────────╮ radius.sheet (32) top corners, elev.3
 │                        ▬▬▬                            │ grabber 36 × 5, 8 from top
 │  Recent                                         [✕]   │ header 56: type.title.m + IconButton 56
 │  ┌─────────────────────────────────────────────┐      │ HistoryCard: radius.xl, color.bg.key, padding space.4
 │  │  12 redemptions · € 486,40 today            │      │ type.body.l 600, tnum; height 56
 │  └─────────────────────────────────────────────┘      │ space.4 (16)
 │  19:00                                                │ hour header 32, type.overline, color.fg.tertiary
 │  19:42   •••• 6488                      € 24,90       │ TransactionRow 64: time type.body.l tnum,
 │          Left € 8,60                                  │ card type.body.m fg.secondary, left caption,
 │  ───────────────────────────────────────────────      │ amount type.label large tnum right; divider
 │  19:05   •••• 1123                      € 32,50       │ color.border.subtle inset 20
 │          Card now empty                               │
 │  18:00                                                │
 │  18:51   •••• 9034                      € 120,00      │
 │          Left € 30,00                                 │
 │  …                                                    │ scroll; max 200 rows
 │  This phone only · cleared at 04:00                   │ footer type.caption, color.fg.tertiary, 40
 ╰───────────────────────────────────────────────────────╯ + safe bottom
```

### 6.4 Recent sheet specification

| Field | Specification |
|---|---|
| Hierarchy | Summary › newest rows › older hours. |
| Typography | Title type.title.m (`recent.title`); summary type.body.l 600 (`recent.summary`); hour type.overline; time type.body.l tnum; card type.body.m; left caption type.caption (`recent.row.remaining` / `success.empty` short "Card now empty" → `recent.row.empty`); amount type.label large tnum; footer type.caption (`recent.footer`). |
| Colour | Sheet color.bg.surface (#FFFFFF / #141417); HistoryCard color.bg.key; rows on surface; pressed row color.bg.keyPressed; dividers color.border.subtle; scrim color.scrim. |
| Components | BottomSheet · HistoryCard · TransactionRow · EmptyState · IconButton. |
| Ordering | Newest first; grouped by clock hour (restaurant time zone, 24 h in de/BHS, locale format in en). |
| States | **Empty:** EmptyState centred in the sheet body: clock glyph 48 (color.fg.tertiary), `recent.empty.title` "No redemptions yet" (type.title.m), `recent.empty.body` "Redemptions from this phone appear here until 04:00." (type.body.m, color.fg.secondary); HistoryCard hidden. **Limit:** at 200 rows the oldest drops; footer shows `recent.limit` "Latest 200 redemptions"; summary counts stored rows only. **Loading:** none (local store, ≤ 16 ms). **Error:** store unreadable → EmptyState with same copy (never blocks S05). |
| Motion | Sheet: motion.spring.soft from bottom; scrim fade motion.base. Rows: no stagger. New row while open (not possible — S13 only opens from S05). 04:00 clear while open: rows fade out motion.base → EmptyState. |
| Micro-interactions | Row press: color.bg.keyPressed, motion.instant; no swipe actions. |
| Haptics | haptic.select on row tap and on detent snap. |
| Sound | None. |
| Accessibility | Sheet title is a heading; hour headers are headings. Row label: "19:42, card ending 6488, 24 euro 90 redeemed, left 8 euro 60" + hint "Shows details". Summary: "12 redemptions, 486 euro 40 today". Escape gesture (two-finger Z / back) closes. |
| Tablet & landscape | Sheet as centred form sheet 540 × up to 720 (iPad) / bottom sheet max width 640 (Android tablets). |
| Android | Back closes; predictive back animation scales the sheet 0.95. |
| iPhone | Native sheet detents (medium, large). |
| Time | Open 0.36 s; find a row ≤ 3 s. |

### 6.5 Recent detail sheet

```
 ╭───────────────────────────────────────────────────────╮ sheet on sheet, color.bg.raised, radius.sheet
 │                        ▬▬▬                            │
 │  Redemption                                     [✕]   │ type.title.m (`recent.detail.title`)
 │                    € 24,90                            │ type.amount.l, tnum; space.6
 │  Time                  Today, 19:42:07                │ rows 48: label type.body.m color.fg.tertiary,
 │  Card                  •••• 6488                      │ value type.body.l color.fg.primary, right-aligned
 │  Amount                € 24,90                        │ dividers color.border.subtle
 │  Remaining balance     € 8,60                         │
 │  Transaction           TX 5E12C0                      │ long-press copies full id
 │  Support code          7F3A9C                         │ long-press copies full X-Request-Id
 │                                                       │ space.6
 │  Wrong amount? A manager can reverse it in the        │ type.body.m, color.fg.secondary
 │  dashboard.                                           │ (`recent.detail.reverseHint`)
 ╰───────────────────────────────────────────────────────╯
```

| Field | Specification |
|---|---|
| Purpose | Facts for a guest query or a manager reversal. No actions (waiters cannot reverse). |
| Entry/exit | Row tap → motion.spring.soft; ✕ / drag / back → Recent. |
| Components | BottomSheet, IconButton; no buttons besides ✕. |
| Full-balance row | "Remaining balance" value = "Card now empty". |
| Accessibility | Each row one element: "Remaining balance, 8 euro 60". Hint on id rows: "Long press to copy". |
| Tablet | Pushes inside the form sheet (iPad) instead of stacking. |
| Acceptance | See below. |

### 6.6 Clearing and data rules

| Rule | Value |
|---|---|
| Scope | Redemptions confirmed on **this device** by the **signed-in waiter** |
| Window | Since the start of the current business day, 04:00 restaurant time zone |
| Source | Redeem responses only (201 and replays); no server read |
| Cap | 200 rows, oldest dropped |
| Cleared | At 04:00 (also evaluated on app foreground and cold start) · on sign-out · on device revoked (S15) · when a different user id signs in |
| Not cleared | Session expiry (401) followed by re-auth of the same user; app restart |
| Stored fields | transaction id, created_at, last 4, amount, balance_after, currency, X-Request-Id short/full. No blocked reasons, no customer data, no full card number |
| Storage | Device-protected, app-private storage; excluded from backups |

### 6.7 Acceptance (S13)

**AC-S13-1** A redemption at 03:59 is listed; at 04:00 the list is empty. **AC-S13-2** Sign-out empties the list
before the S02 screen appears. **AC-S13-3** Replayed successes never duplicate rows. **AC-S13-4** Summary equals
the sum of listed amounts. **AC-S13-5** Detail shows the line "Wrong amount? A manager can reverse it in the
dashboard." exactly once, and no reverse action. **AC-S13-6** Rows show only `•••• NNNN`. **AC-S13-7** 201st
redemption drops the oldest row and shows the limit footer.

---

## 7. Interaction timing summary

| Interaction | Android | iPhone |
|---|---|---|
| Card read → S07 visible (lookup ≤ 0.4 s) | ≤ 0.94 s | ≤ 1.14 s |
| Type 4 digits | 1.2 s | 1.2 s |
| Redeem tap → S09 first frame | ≤ 0.6 s | ≤ 0.6 s |
| Hold (≥ € 100) | + 0.6 s | + 0.6 s |
| S09 → ready (no tap) | 4.52 s | 4.52 s |
| S09 → next card (tap) | 0 s (tap card) | 1 tap + sheet 0.3 s |
| Uncertain worst case to manual decision | 20 s | 20 s |

---

## 8. Notes for engineering handoff (behaviour gaps found in the current API)

1. `VELOCITY_LIMIT_EXCEEDED` currently carries no `retry_after`; § 2.17 handles "unknown". Exposing the rolling
   window end would enable the countdown.
2. `max_single_redemption` is only learned from 422 `context` until backend prerequisite 2 ships (§ 2.16).
3. Redeem replay returns HTTP **200** with top-level `replayed: true`; first booking returns **201**. Both → S09.
4. `CARD_BLOCKED` on redeem has no `blocked_reason`; the blocked variant then omits the reason line.
5. Zero-balance cards fail redeem with `CARD_NOT_REDEEMABLE` (`context.status = redeemed`), not
   INSUFFICIENT_BALANCE.
6. SUN URLs must never be re-posted (§ 1.2); the web terminal is safe only because it never retries lookups.

---

## 9. New copy keys (proposed)

Existing brief keys used unchanged: `charge.redeem`, `charge.redeemFull`, `charge.hold`, `charge.overBalance`,
`charge.useBalance`, `success.title`, `success.remaining`, `success.next.ios`, `success.next.android`,
`problem.notFound.title`, `problem.foreign.title`, `problem.verify.title`, `card.blocked`, `card.expired`,
`card.inactive`, `card.replaced`, `card.empty`, `offline.title`, `uncertain.title`, `uncertain.body`,
`getManager`, `ios.sheet.alert`. Full catalogue and plural rules: [12](12-ui-copy-and-error-messages.md).

| Key | DE (de-AT) | EN | BHS |
|---|---|---|---|
| charge.enterAmount | Betrag eingeben | Enter amount | Unesi iznos |
| charge.redeeming | {amount} wird eingelöst … | Redeeming {amount} … | Iskorištava se {amount} … |
| charge.fullOnly | Hier ist nur das gesamte Guthaben einlösbar. | Only the full balance can be redeemed here. | Ovdje se može iskoristiti samo cijelo stanje. |
| charge.maxSingle | Max. {amount} pro Einlösung | Max. {amount} per redemption | Najviše {amount} po iskorištavanju |
| charge.useMax | Maximum verwenden · {amount} | Use maximum · {amount} | Iskoristi maksimum · {amount} |
| charge.velocity.title | Limit für diese Karte erreicht | Limit for this card reached | Dosegnut je limit za ovu karticu |
| charge.velocity.bodyTime | Wieder möglich in {minutes} Min. Oder einen Manager holen. | Possible again in {minutes} min. Or get a manager. | Ponovo moguće za {minutes} min. Ili pozovite menadžera. |
| charge.rateLimited | Zu viele Anfragen – wieder möglich in {seconds} s | Too many requests — possible again in {seconds} s | Previše zahtjeva – ponovo moguće za {seconds} s |
| charge.switchCard.message | Andere Karte erkannt – wechseln? | Different card detected — Switch? | Prepoznata je druga kartica – zamijeniti? |
| charge.switchCard.action | Wechseln | Switch | Zamijeni |
| charge.switchCard.keep | Behalten | Keep | Zadrži |
| lookup.stillLooking | Karte wird noch gesucht … | Still looking … | Još tražimo … |
| card.empty.body | Diese Karte ist vollständig eingelöst. | This card has been fully used. | Ova kartica je potpuno iskorištena. |
| card.blocked.reason | Grund: {reason} | Reason: {reason} | Razlog: {reason} |
| card.expired.body | Abgelaufen am {date}. Ein Manager kann helfen. | Expired on {date}. A manager can help. | Istekla {date}. Menadžer može pomoći. |
| card.inactive.body | Erst nach der Aktivierung einlösbar. Bitte einen Manager holen. | It can be redeemed once activated. Please get a manager. | Može se iskoristiti tek nakon aktivacije. Molimo pozovite menadžera. |
| card.replaced.body | Das Guthaben ist auf der neuen Karte. Gast nach der neuen Karte fragen. | The balance is on the new card. Ask the guest for the new card. | Stanje je na novoj kartici. Zamolite gosta za novu karticu. |
| redeem.slow | Verbindung langsam – neuer Versuch | Connection slow — retrying | Spora veza – ponovni pokušaj |
| redeem.nothingBooked | Nichts gebucht. | Nothing was booked. | Ništa nije knjiženo. |
| redeem.balanceChanged | Guthaben hat sich geändert: jetzt {amount} | Balance changed: now {amount} | Stanje se promijenilo: sada {amount} |
| redeem.tapAgain | Bitte noch einmal einlösen. | Please tap Redeem again. | Molimo ponovo dodirnite Iskoristi. |
| uncertain.retrying | Versuch {n} von 3 | Attempt {n} of 3 | Pokušaj {n} od 3 |
| uncertain.failedBody | Noch nicht bestätigt. Erneut versuchen – es wird nie doppelt gebucht. | Not confirmed yet. Try again — nothing is ever booked twice. | Još nije potvrđeno. Pokušajte ponovo – ništa se ne knjiži dvaput. |
| uncertain.guestHint | Dem Gast sagen: „Einen Moment bitte, die Zahlung wird bestätigt.“ | Tell the guest: “One moment please, the payment is being confirmed.” | Recite gostu: „Trenutak, molim, plaćanje se potvrđuje.“ |
| uncertain.cancelled | Nicht bestätigt. Vor einer neuen Buchung die Karte erneut scannen. | Not confirmed. Scan the card again before charging. | Nije potvrđeno. Prije novog terećenja ponovo skenirajte karticu. |
| uncertain.cancelledGuestHint | Dem Gast sagen: „Die Zahlung ist nicht bestätigt. Wir prüfen das Guthaben, bevor wir neu buchen.“ | Tell the guest: “The payment isn't confirmed. We'll check the balance before charging again.” | Recite gostu: „Plaćanje nije potvrđeno. Provjerit ćemo stanje prije novog terećenja.“ |
| success.empty | Karte ist jetzt leer | Card is now empty | Kartica je sada prazna |
| success.showGuest | Dem Gast zeigen | Show guest | Pokaži gostu |
| guest.remaining.label | Restguthaben | Remaining balance | Preostalo stanje |
| problem.notFound.body | Diese Karte ist nicht im System. Karte prüfen oder nach einer anderen fragen. | This card is not in the system. Check the card or ask the guest for another one. | Ova kartica nije u sistemu. Provjerite karticu ili zamolite drugu. |
| problem.notFound.bodyManual | Keine Karte mit dieser Nummer. Ziffern prüfen. | No card with this number. Check the digits. | Nema kartice s ovim brojem. Provjerite cifre. |
| problem.foreign.body | Sie ist nur im ausstellenden Lokal einlösbar. | It can only be redeemed at the restaurant that issued it. | Može se iskoristiti samo u restoranu koji ju je izdao. |
| problem.verify.body | Diese Karte bitte vorerst nicht annehmen. Ein Manager kann sie prüfen. | Please don't accept this card for now. A manager can check it. | Molimo, zasad ne prihvatajte ovu karticu. Menadžer je može provjeriti. |
| problem.throttled.title | Zu viele Scans | Too many scans | Previše skeniranja |
| problem.throttled.body | Scannen ist in Kürze wieder möglich. | Scanning is possible again shortly. | Skeniranje će uskoro ponovo biti moguće. |
| problem.scanAgainIn | Erneut scannen · {time} | Scan again · {time} | Skeniraj ponovo · {time} |
| problem.network.body | Karte konnte nicht geprüft werden. WLAN oder mobile Daten prüfen, dann erneut versuchen. | The card could not be checked. Check Wi-Fi or mobile data, then try again. | Kartica nije provjerena. Provjerite Wi-Fi ili mobilne podatke, pa pokušajte ponovo. |
| problem.server.title | Etwas ist schiefgelaufen | Something went wrong | Nešto nije u redu |
| problem.server.body | Das Problem liegt bei uns. Gleich erneut versuchen. | The problem is on our side. Try again in a moment. | Problem je kod nas. Pokušajte ponovo za trenutak. |
| problem.supportCode | Code {code} | Code {code} | Kôd {code} |
| common.done | Fertig | Done | Gotovo |
| common.cancel | Abbrechen | Cancel | Otkaži |
| common.tryAgain | Erneut versuchen | Try again | Pokušaj ponovo |
| common.scanAgain | Erneut scannen | Scan again | Skeniraj ponovo |
| common.enterNumber | Kartennummer eingeben | Enter card number | Unesi broj kartice |
| common.editNumber | Nummer bearbeiten | Edit number | Uredi broj |
| common.copied | Kopiert | Copied | Kopirano |
| recent.title | Zuletzt | Recent | Nedavno |
| recent.summary | {count, plural, one {# Einlösung} other {# Einlösungen}} · {amount} heute | {count, plural, one {# redemption} other {# redemptions}} · {amount} today | {count, plural, one {# iskorištavanje} few {# iskorištavanja} other {# iskorištavanja}} · {amount} danas |
| recent.row.remaining | Rest {amount} | Left {amount} | Ostatak {amount} |
| recent.row.empty | Karte jetzt leer | Card now empty | Kartica sada prazna |
| recent.empty.title | Noch keine Einlösungen | No redemptions yet | Još nema iskorištavanja |
| recent.empty.body | Einlösungen von diesem Handy erscheinen hier bis 04:00. | Redemptions from this phone appear here until 04:00. | Iskorištavanja s ovog telefona prikazuju se ovdje do 04:00. |
| recent.footer | Nur dieses Handy · wird um 04:00 geleert | This phone only · cleared at 04:00 | Samo ovaj telefon · briše se u 04:00 |
| recent.limit | Die letzten 200 Einlösungen | Latest 200 redemptions | Posljednjih 200 iskorištavanja |
| recent.detail.title | Einlösung | Redemption | Iskorištavanje |
| recent.detail.time | Zeit | Time | Vrijeme |
| recent.detail.card | Karte | Card | Kartica |
| recent.detail.amount | Betrag | Amount | Iznos |
| recent.detail.remaining | Restguthaben | Remaining balance | Preostalo stanje |
| recent.detail.transaction | Buchung | Transaction | Transakcija |
| recent.detail.supportCode | Support-Code | Support code | Kôd za podršku |
| recent.detail.reverseHint | Falscher Betrag? Ein Manager kann ihn im Dashboard stornieren. | Wrong amount? A manager can reverse it in the dashboard. | Pogrešan iznos? Menadžer ga može stornirati u kontrolnoj ploči. |
| a11y.charge.close | Karte schließen | Close card | Zatvori karticu |
| a11y.amount | Betrag {spokenAmount} | Amount {spokenAmount} | Iznos {spokenAmount} |
| a11y.keypad.doubleZero | Doppelnull | Double zero | Dvije nule |
| a11y.keypad.delete | Löschen | Delete | Obriši |
| a11y.keypad.deleteHint | Lange drücken zum Leeren | Long press to clear | Dugo pritisnite za brisanje svega |
| a11y.hold.hint | Doppeltippen und halten zum Einlösen | Double-tap and hold to redeem | Dvaput dodirnite i držite za iskorištavanje |
| a11y.overBalance | {diff} mehr als das Guthaben. Einlösen nicht möglich. | {diff} more than the balance. Redeem not available. | {diff} više od stanja. Iskorištavanje nije moguće. |
| a11y.success | Eingelöst {amount}, Restguthaben {balance} | Redeemed {amount}, remaining balance {balance} | Iskorišteno {amount}, preostalo stanje {balance} |

---

Version 1.0 · September 2026 · GiftCard Waiter design specification
