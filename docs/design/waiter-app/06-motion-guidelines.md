# 06 · Motion Guidelines — GiftCard Waiter

Scope: every animated change in the waiter app — screen transitions, component state changes, loops, progress indicators, and how motion coordinates with system UI (Apple's NFC sheet, biometric prompts) and with network time.
Related: screen behaviour in [03a](03a-screens-access-and-scanning.md) and [03b](03b-screens-charge-redeem-success-problems.md) · tokens in [04](04-design-system.md) · component anatomy in [05](05-component-library.md) · accessibility in [07](07-accessibility-guidelines.md) · haptic and sound timing in [11](11-sound-and-haptics.md) · implementation notes in [09](09-flutter-handoff.md) · strings in [12](12-ui-copy-and-error-messages.md).

---

## 1. Principles

| # | Principle | What it means in this app | Test |
|---|---|---|---|
| P1 | **Motion explains cause and effect** | Every movement starts where its cause is. The card rises from the NFC centre because the card was tapped there. The success chip comes from the balance card because that card was charged. Nothing flies in from an unrelated edge. | For any animation, name the cause in one sentence. If you can't, delete the animation. |
| P2 | **Fast in, calm out** | Content that answers the waiter (card found, success) arrives on `decelerate` or `motion.spring.card` and is readable in ≤ 240 ms. Content that leaves uses `accelerate` and is shorter (90–160 ms). | Frame 8 (≈ 133 ms at 60 Hz) of any entering transition: the primary value (balance, amount) is already ≥ 80 % opaque. |
| P3 | **Never block input** | No animation is a gate. Keys, buttons and NFC reads are live from the first frame of a transition. A new input retargets the running animation from its current value (never queues, never restarts from zero). Business-logic locks (keypad locked during a redeem request) are state, not animation. | Tap a key during the Ready→Charge transition: the digit registers. Tap Redeem during the digit roll-in: the request is sent at touch-up. |
| P4 | **Money never appears to change** | Amounts and balances never count up/down, never tick, never morph digit-into-digit. They fade/slide in at their final value. The only exception is POS entry on `AmountDisplay`, where each digit moves exactly as the waiter typed it. | No frame of any recording shows a monetary value that was not the typed or server-returned value. |
| P5 | **No gimmicks** | No confetti, bounce-overshoot > 2 %, parallax, 3D flips, particle effects, colour cycling, or motion that exists for delight alone. The only loop is the NFC breathing (it communicates "listening"). | Remove the animation: if the screen is equally understandable and the state is equally clear, it was a gimmick. |
| P6 | **Motion is a secondary channel** | State is always carried by text + icon first; motion, colour, haptics and sound reinforce it. With Reduce Motion, sound off and haptics off, the app is fully usable. | Run the full happy path with Reduce Motion ON, sound OFF, haptics OFF — every state is still identifiable. |
| P7 | **Motion never costs time** | Motion must not add to the 5-second budget (brief §3). Transitions overlap network time; nothing waits for an animation to finish before sending a request or accepting a tap. | See §5 timeline. |
| P8 | **Frame-rate independent, battery-aware** | All animations are time-based (ms), correct at 60/90/120 Hz. Loops pause when not visible and in Low Power Mode / Battery Saver fall back to their Reduce Motion variant. | ProMotion and 60 Hz recordings match in duration ±1 frame. |

---

## 2. Tokens

### 2.1 Durations (binding, brief §5)

| Token | ms | Typical use |
|---|---|---|
| `motion.duration.instant` | 90 | press feedback, exits of small elements, pressed-state colour |
| `motion.duration.fast` | 160 | digit roll-in, cross-fades, Reduce Motion replacements, small exits |
| `motion.duration.base` | 240 | standard enters, shake, SuccessMark circle, banner expand |
| `motion.duration.slow` | 360 | large surface enters (full-screen problem content), tablet pane changes |
| `motion.duration.emphasis` | 520 | the complete Charge → Success choreography (envelope) |

### 2.2 Curves (binding, brief §5)

| Token | Definition | Use |
|---|---|---|
| `motion.ease.standard` | cubic-bezier(0.2, 0, 0, 1) | on-screen changes (move, resize, colour) |
| `motion.ease.decelerate` | cubic-bezier(0, 0, 0, 1) | elements entering |
| `motion.ease.accelerate` | cubic-bezier(0.3, 0, 1, 1) | elements leaving |
| `motion.spring.card` | response 0.42 s, damping ratio 0.82 | BalanceCard travel (Ready→Charge, card→chip) |
| `motion.spring.soft` | response 0.55 s, damping ratio 0.90 | bottom sheets, snackbar, sheet drag release |

**Spring conversion** (for platforms that take stiffness/damping; mass = 1):

| Token | ω₀ = 2π / response | Stiffness k = ω₀² | Damping c = 2·ζ·ω₀ | Overshoot | ≈ 2 % settle |
|---|---|---|---|---|---|
| `motion.spring.card` | 14.96 rad/s | 223.8 | 24.5 | ≈ 1.1 % | ≈ 330 ms |
| `motion.spring.soft` | 11.42 rad/s | 130.5 | 20.6 | ≈ 0.15 % | ≈ 390 ms |

Springs are started with the gesture's release velocity when one exists (sheet drag), otherwise with velocity 0.

### 2.3 Animation-local values (not global tokens)

These are fixed values owned by a single animation (from the brief or defined here). They are not added to [04](04-design-system.md) as tokens.

| Value | Where | Source |
|---|---|---|
| Linear (no easing) | progress only: `HoldButton` ring, `CountdownHairline`, `Skeleton` shimmer | this doc |
| 600 ms | `HoldButton` fill | brief §1 |
| 4000 ms | `CountdownHairline` / auto-return | brief §1 |
| 300 ms | Android new-card cross-fade | brief §2 |
| 2400 ms period | NFC breathing loop | this doc |
| 1200 ms period | Skeleton shimmer | this doc |
| Sine in-out, cubic-bezier(0.37, 0, 0.63, 1) | NFC breathing only | **Proposal (not part of v1 token set)** — may be promoted to `motion.ease.breath` |

### 2.4 Reduce Motion (global rule, brief §5)

When iOS *Reduce Motion* or Android *Remove animations* (animator duration scale = 0) is on — **and** in Low Power Mode / Battery Saver for loops only:

1. Every translation, scale, path-draw and blur change is replaced by a **160 ms (`fast`) cross-fade with `ease.standard`**.
2. The NFC breathing is disabled; rings are **static** at their rest values (scale 1.0, arc opacities 1.0 / 0.72 / 0.44, glow opacity 0.32).
3. Progress indicators are **kept** (HoldButton ring, CountdownHairline, Spinner) because they carry information.
4. Shakes are removed; the error colour, icon and text remain.
5. Durations are never 0: the 160 ms fade avoids a hard flash (WCAG 2.3.1 safe).

Android nuance: with *animator duration scale* set to 0, platform animators complete instantly. The app reads the setting and applies the rules above explicitly; progress indicators (hold ring, countdown) are driven by elapsed time, not by animator scale, so they still run their full 600 ms / 4 s. See [09](09-flutter-handoff.md).

---

## 3. Animation catalogue — overview

Names used in the screen specs map to these IDs: `ring-pulse` = M04 (Android) · `ring-breathe` = M04 iPhone variant · `ring-read` = M05 · `ring-converge` = M06 · `card-lift` = M08 · `skeleton-shimmer` = M10 · `crossfade-state` = M09 · `fade-through` = M20/M22. Where a screen spec and this catalogue differ in a value, this catalogue is the motion source of truth; differences are listed in §8.

Legend — **Int.** = interruptibility: *R* = retargets from current value on new input · *C* = cancels instantly (jumps to end state) · *N* = not interruptible by design (≤ 160 ms, input still accepted). **RM** = Reduce Motion alternative.

| ID | Name | Screens | Properties | Duration | Curve | Int. | RM |
|---|---|---|---|---|---|---|---|
| M01 | Splash → Unlock / Ready | S01 → S04/S05 | opacity, translateY | fast out + base in | accelerate / decelerate | C | fade 160 |
| M02 | Field error shake | S02, S11 | translateX, colour, height | base (240) | keyframed | C | colour + text only |
| M03 | Biometric success handoff | S04 → S05 | opacity, translateY | fast + base | accelerate / decelerate | C | fade 160 |
| M04 | NFC ring breathing (idle) | S05 (Android) | scale, opacity | 2400 loop | sine (proposal) | R | static rings |
| M05 | Listening → Reading | S05/S06 (Android) | scale, opacity, colour | instant (90) + fast | standard | R | fade 160 |
| M06 | Card detected — ring collapse | S05 (Android), S12 | scale, opacity | base (240) | accelerate | N | fade 160 |
| M07 | Scan hint fade (iOS session timeout / NFC hint) | S05 | opacity, translateY | base | decelerate | R | fade 160 |
| M08 | Ready → Charge | S05/S06/S11/S12 → S07 | translateY, scale, opacity, radius | motion.spring.card; keypad +40 ms | spring / decelerate | R | fade 160 |
| M09 | Skeleton → content | S07 | opacity | fast | standard | C | same |
| M10 | Skeleton shimmer | S07 | gradient position | 1200 loop | linear | C | static, 60 % opacity |
| M11 | Key / button press | S07, S11, all buttons | scale, colour | instant in / fast out | standard / decelerate | R | colour only |
| M12 | AmountDisplay digit roll-in | S07 | translateY, translateX, opacity, colour | fast (160) | decelerate / standard | R | fade 160 (no move) |
| M13 | Backspace / clear | S07, S11 | translateY, translateX, opacity | instant out, fast shift | accelerate / standard | R | fade |
| M14 | Over-balance enter / exit | S07 | translateX, colour, opacity | base (shake) + fast | keyframed / standard | C | colour + text |
| M15 | QuickAmountChip appear / disappear | S07 | opacity, scale | fast in / instant out | decelerate / accelerate | R | fade |
| M16 | HoldButton ring fill / reverse | S07/S08 | ring sweep, label opacity | 600 linear / reverse 160 | linear / decelerate | R | **kept** |
| M17 | Submitting (label → spinner) | S08 | opacity, keypad opacity | 150 delay + fast | standard | C | same (spinner kept) |
| M18 | Charge → Success | S07/S08 → S09 | position, size, radius, path draw, opacity, colour | emphasis envelope (520) | motion.spring.card / standard / decelerate | C | fade 160 + static mark |
| M19 | CountdownHairline | S09 | width (scaleX) | 4000 | linear | C | **kept** |
| M20 | Success → Ready (auto-return / interrupt) | S09 → S05 | opacity, translateY | fast out + base in | accelerate / decelerate | C | fade 160 |
| M21 | New-card swap (Android) | S07, S09 | opacity (cross-fade) | 300 | standard | R | same |
| M22 | Problem screen entry | → S10 | translateY, opacity (stagger) | base + stagger 40 | decelerate | C | fade 160 |
| M23 | Snackbar in / out | S07, S05, S09 | translateY, opacity | base in / fast out (motion.spring.soft on drag) | decelerate / accelerate | R | fade |
| M24 | Bottom sheet open / drag / close + scrim | S13, S14, S15 | translateY, scrim opacity | motion.spring.soft | spring / linked | R | fade 160 |
| M25 | StatusBanner expand / collapse | S07, S05 | height, opacity | base / fast | standard | R | fade, instant height |
| M26 | Offline banner | S05, S07, S09 | height, translateY, opacity | base / fast | decelerate / accelerate | R | fade |
| M27 | iPhone system NFC sheet coordination | S05/S09 ↔ system sheet → S07 | pause/resume loops, M08 origin | — | — | — | — |
| M28 | Background privacy blur / lock | all | blur, opacity | 0 in / fast out | — / standard | C | solid overlay |
| M29 | Spinner | S08, S15, S02 | rotation | 800 loop | linear | C | **kept** (rotation allowed) |
| M30 | Scan-throttle countdown & retry enable | S10 | text swap, button enable | fast | standard | C | same |

---

## 4. Animation catalogue — detail

Each entry: **Trigger · Screens · Properties (from → to) · Duration · Curve · Delay/stagger · Interruptibility · Reduce Motion · Purpose.** Haptic and sound coupling is listed only as a pointer; timing rules are in [11](11-sound-and-haptics.md) §4.

### M01 — Splash → Unlock / Ready
- **Trigger:** app bootstrap complete (token checked, config fetched or cached). Splash is visible ≤ 600 ms; spinner only if > 1 s (brief S01).
- **Screens:** S01 → S04 (unlock required) or S05 (unlocked, warm).
- **Properties:** Brand mark opacity 1 → 0 (90 ms, accelerate). Destination root opacity 0 → 1 and translateY +8 pt → 0 (240 ms, decelerate), starting 40 ms after the mark begins fading. On S05 Android the NFC arcs start at scale 1.0 and M04 begins after the enter completes.
- **Interruptibility:** C — any tap/scan jumps to end state. An NFC read during M01 is processed normally (reader mode is enabled at first frame of S05).
- **RM:** 160 ms cross-fade, no translate.
- **Purpose:** hand over without a blank frame; the brand mark never "flies" into the TopBar (would be decoration).

### M02 — Field error shake (sign-in, manual entry)
- **Trigger:** S02 validation or 401/423 response; S11 invalid card number (checksum/length) or 404 inline.
- **Properties:** translateX keyframes of the **field container** (label + field + error line move together):

  | t (ms) | 0 | 30 | 90 | 150 | 210 | 240 |
  |---|---|---|---|---|---|---|
  | x (pt) | 0 | +6 | −6 | +6 | −6 | 0 |

  Segments use `ease.standard`. In parallel: border `color.border.control` → `color.danger` (160 ms, standard); error line height 0 → content height and opacity 0 → 1 (160 ms, standard, delay 40 ms).
- **Interruptibility:** C — typing during the shake jumps the shake to x = 0 immediately; colour stays until the value changes.
- **RM:** no shake; colour + error line (160 ms fade).
- **Coupling:** `haptic.error` at t = 0. No sound on sign-in.
- **Purpose:** point to *which* field failed; the rhythm (2 cycles) reads as "no" in every culture.

### M03 — Biometric success handoff
- **Trigger:** OS biometric prompt returns success (Face ID / Touch ID / BiometricPrompt).
- **Properties:** S04 content opacity 1 → 0 (90 ms, accelerate); S05 opacity 0 → 1, translateY +8 → 0 (240 ms, decelerate), starts when the OS prompt begins dismissing (iOS: on callback; Android: on `onAuthenticationSucceeded`). We draw **no** own checkmark — the OS already confirmed.
- **Interruptibility:** C.
- **RM:** fade 160.
- **Purpose:** get out of the way; unlock is not an event worth celebrating.
- **Failure:** biometric cancel/fail shows S04 fallback "Use password" with M25-style fade (160 ms); no shake (the OS prompt already signalled failure).

### M04 — NFC ring breathing (Ready idle)
- **Trigger:** S05 visible, NFC on (Android: full variant; iPhone: low-amplitude variant around the "Scan card" motif, see below). Runs online and offline (the lookup itself is online-only; see offline in [03a](03a-screens-access-and-scanning.md)).
- **Component:** `NfcScanAnimation` — 3 concentric saffron arcs + glow.
- **Properties (one period = 2400 ms, 1200 ms inhale + 1200 ms exhale):**

  | Layer | Rest (t = 0) | Peak (t = 1200) |
  |---|---|---|
  | Arc group scale | 1.00 | 1.04 |
  | Inner arc opacity | 1.00 | 1.00 |
  | Middle arc opacity | 0.72 | 1.00 |
  | Outer arc opacity | 0.44 | 0.80 |
  | Glow (radial, saffron) opacity | 0.24 | 0.48 |

  Curve: sine in-out cubic-bezier(0.37, 0, 0.63, 1) per half (Proposal, §2.3). Outer arc lags the inner by 120 ms (a subtle wave, not a spin).
- **iPhone variant (V2 in [03a](03a-screens-access-and-scanning.md)):** no scale change; glow opacity 0.12 ↔ 0.24 only, same 2400 ms period — the phone is not listening until "Scan card" is tapped, so the motion must be quieter than Android's.
- **Pauses (to rest values, 160 ms):** app backgrounded; any sheet ≥ 50 % height open over S05; `Snackbar` visible; NFC off / unsupported (rings replaced by S16 state); screen reader running (loop continues visually but is not announced — no change); Low Power Mode / Battery Saver → static.
- **Frame rate:** may be rendered at 30 fps (slow, low-amplitude motion); this is permitted to save battery on 120 Hz panels.
- **Interruptibility:** R — any read (M05) retargets from the current scale/opacity; never snaps.
- **RM:** static rings at scale 1.0, arcs 1.0 / 0.72 / 0.44, glow 0.32.
- **Purpose:** "the phone is listening" — the only intentional loop in the app.

### M05 — Listening → Reading (Android)
- **Trigger:** tag discovered in reader mode (before NDEF/UID read completes).
- **Properties:** breathing stops at current value and retargets to: arc group scale → 1.06 (90 ms, standard); all arcs opacity → 1.0 (90 ms); glow → 0.64. Title text cross-fades from `ready.android.title` to the reading label (see [12](12-ui-copy-and-error-messages.md)) — 160 ms, standard. While reading: arcs hold (no spinner; a read takes ~300 ms).
- **Failure (tag lost before read completes / unreadable):** retarget back to rest over 240 ms (decelerate), title cross-fades back; breathing resumes after 400 ms. `haptic.warning` only if the read fails 3 × within 5 s (see [11](11-sound-and-haptics.md)).
- **Interruptibility:** R.
- **RM:** title cross-fade only; rings switch opacity with 160 ms fade.
- **Purpose:** the waiter must see *instantly* that the phone felt the card, so they keep holding it.

### M06 — Card detected: ring collapse into card
- **Trigger:** successful read (UID + URL) on Android; QR decode on S12.
- **Properties:** arcs scale 1.06 → 0.60 and opacity 1 → 0 (240 ms, accelerate), converging on the arc centre; glow opacity 0.64 → 0 (160 ms). On S12: the detected QR corner brackets contract 8 pt towards the code's centre and fade (240 ms, accelerate).
- **Parallelism:** the scan API request is sent at the same frame; M06 runs entirely inside network time.
- **Hand-over:** M08 may start while M06 is still running (at API response or 150 ms after read, whichever first). The collapsing centre is M08's origin.
- **Interruptibility:** N (240 ms; input is still accepted).
- **RM:** arcs fade out 160 ms, no scale.
- **Coupling:** `haptic.cardDetected` + `sound.cardDetected` at t = 0 (Android and QR; not iPhone NFC — the system sheet gives feedback).
- **Purpose:** cause → effect: the thing you held becomes the card on screen.

### M07 — Scan hint fade
- **Trigger:** iPhone NFC session timed out (~60 s) or user cancelled the sheet → back on S05 silently with hint text; Android: no read after 20 s of an NFC field being present-and-lost (repeated failed reads) → hint "hold still / move to top-back" (strings in [12](12-ui-copy-and-error-messages.md)).
- **Properties:** hint opacity 0 → 1, translateY +4 → 0 (240 ms, decelerate). Hides with 160 ms fade on next scan start.
- **RM:** fade 160.
- **Purpose:** explain what to do next without a dialog.

### M08 — Ready → Charge (card rises)
- **Trigger:** scan API response (any card-state that lands on S07) **or** 150 ms after read with no response yet (then the card rises as a `Skeleton`, see M09/M10). Also from S11 (manual entry submit) and S12 (QR), and from a universal link (method `link`).
- **Origin:** Android NFC: centre of `NfcScanAnimation`. iPhone NFC: centre of the "Scan card" button (the sheet has covered it; see M27). S12: centre of the detected QR code. S11: the `CardNumberField`. Link/cold start: bottom-centre of the screen (no visible origin; card rises 24 pt).
- **Properties:**

  | Element | From | To | Timing |
  |---|---|---|---|
  | `BalanceCard` scale | 0.40 (Android/QR origin) · 0.60 (iPhone/S11) | 1.00 | `motion.spring.card` |
  | `BalanceCard` position | origin centre | final layout slot | `motion.spring.card` |
  | `BalanceCard` corner radius | `radius.full` equivalent at scale | ID-1 card radius | `motion.spring.card` |
  | `BalanceCard` opacity | 0 | 1 | 160 ms, decelerate (reaches 1 at 160 ms) |
  | Ready content (title, secondary buttons) | opacity 1, y 0 | opacity 0, y −8 | 90 ms, accelerate |
  | `TopBar` | unchanged (persistent) | — | — |
  | `AmountDisplay` + `Keypad` + CTA | opacity 0, y +16 | opacity 1, y 0 | 240 ms, decelerate, **delay 40 ms** after card start |
  | Keypad rows (stagger) | — | — | +0 / +10 / +20 / +30 ms per row (top → bottom), inside the 40 ms delay budget → last row starts at 70 ms |

- **Readable at:** balance legible (≥ 80 % opacity, ≥ 90 % scale) at ≈ 150 ms; layout settled ≈ 330 ms (spring settle). The brief's 0.24 s transition budget is met because keys are live from frame 1 and the card is legible well within 240 ms.
- **Input:** keys accept digits from frame 1 (buffered into `AmountDisplay`). Redeem stays disabled until card data is present and valid.
- **Interruptibility:** R — a second card (Android) retargets via M21; Back/close retargets the card back to its origin with `motion.spring.card`.
- **RM:** Ready content fades out 90 ms; Charge (card + keypad) fades in 160 ms, standard, no scale/translate; no stagger.
- **Partial redemption disabled:** keypad is absent; the fixed amount + CTA fade up with the same 40 ms delay.
- **Card-problem states on S07** (blocked, expired, inactive, replaced, zero): same motion; card arrives already desaturated 40 %; `StatusBanner` enters via M25 with an extra 80 ms delay so the card lands first.
- **Purpose:** P1 — the card physically "comes out" of where it was tapped.

### M09 — Skeleton → content
- **Trigger:** scan response arrives while the `Skeleton` card is showing.
- **Properties:** skeleton layers opacity 1 → 0 and content opacity 0 → 1 simultaneously, 160 ms, standard. Card background colour: skeleton neutral (`color.bg.key`) → `brand_color` in the same 160 ms. Card geometry does not change (skeleton has the final size).
- **Rules:** if lookup > 3 s, "Still looking…" text fades in under the card (160 ms); > 10 s → network S10 via M22.
- **RM:** same (already a fade).

### M10 — Skeleton shimmer
- **Trigger:** `Skeleton` visible (lookup > 150 ms).
- **Properties:** a diagonal highlight band (width 40 % of element, 20° angle, `color.bg.keyPressed` over the `color.bg.key` base) travels from x = −40 % to x = 140 % of the skeleton group. Period 1200 ms, linear, no pause. All skeleton shapes share **one** band (phase-locked, left → right), not one per element.
- **Interruptibility:** C (stops when content arrives).
- **RM:** no travel; static skeleton at 60 % opacity ([03b](03b-screens-charge-redeem-success-problems.md)).
- **Purpose:** "working" without a spinner; keeps the eventual layout stable.

### M11 — Key / button press
- **Trigger:** touch-down on `Keypad` key, `PrimaryButton`, `SecondaryButton`, `IconButton`, `QuickAmountChip`.
- **Properties:**

  | Phase | Scale | Background | Duration / curve |
  |---|---|---|---|
  | Press (touch-down) | 1.00 → 0.96 | `color.bg.key` → `color.bg.keyPressed` (buttons: `action.primary` → `action.primaryPressed`) | 90 ms, standard |
  | Release | 0.96 → 1.00 | back to rest | 160 ms, decelerate |

  Keypad keys register the digit on touch-down (see [05](05-component-library.md)); `haptic.key` fires on the same frame. Buttons act on touch-up (except `HoldButton`, M16).
- **Rapid typing:** each press retargets from the current scale; a key pressed again at 0.97 goes straight back toward 0.96. There is no ripple on Android keypad keys (the scale + colour is the ripple equivalent; a spreading ripple is visual noise at typing speed). Android buttons outside the keypad keep the platform ripple clipped to the button shape, `color.fg.primary` at 12 %.
- **RM:** colour change only (no scale).
- **Purpose:** immediate acknowledgement under gloves where tactile feel is reduced.

### M12 — AmountDisplay digit roll-in
- **Trigger:** digit or "00" key registered.
- **Behaviour (POS entry, brief §6):** digits shift in from the right; the value is always the typed digits ÷ 100. Example sequence 2 → 4 → 9 → 0: `€ 0,02` → `€ 0,24` → `€ 2,49` → `€ 24,90`. Tabular figures: every digit slot has identical width.
- **Properties:**

  | Element | From | To | Duration / curve |
  |---|---|---|---|
  | New digit (rightmost slot) | y +8 pt, opacity 0 | y 0, opacity 1 | 160 ms, decelerate |
  | Existing digits | old slot x | new slot x (one slot left; they cross the decimal separator) | 160 ms, standard |
  | Placeholder zeros (`color.fg.tertiary`) becoming real digits | tertiary colour | `color.fg.primary` | 160 ms, standard |
  | Thousands separator appearing (≥ € 1.000,00) | opacity 0, width 0 | opacity 1, full width | 160 ms, standard |
  | Whole string re-centring (width grew by a slot) | old centre | new centre | 160 ms, standard |
  | "00" key | two digits enter together, second digit delayed 30 ms | — | 160 ms each |

- **Interruptibility:** R — typing faster than 160 ms per key is normal (≈ 300 ms/key average, bursts of 120 ms). A new key completes the previous roll-in's translate by retargeting (no queue, no pile-up): the previous new digit jumps to y 0 / opacity 1 and all digits animate to their new slots from their current x.
- **Max digits:** 7 (€ 99.999,99). An 8th key: no digit animation; M02-style shake of the display at 50 % amplitude (3 pt, 2 cycles, 240 ms) + `haptic.warning`. RM: no shake.
- **Never:** counting, digit rolling like an odometer, scaling the whole number per key.
- **Screen reader:** amount announcement is not delayed by the animation (announcement fires on value change; see [07](07-accessibility-guidelines.md)).
- **RM:** new digit fades in (160 ms), no y offset; existing digits jump to new slots (no horizontal travel) — a 160 ms cross-fade of the whole string instead.
- **Purpose:** the eye tracks exactly what was typed; the shifting-in motion teaches POS entry.

### M13 — Backspace / clear
- **Backspace (tap ⌫):** rightmost digit y 0 → +8 pt, opacity 1 → 0 (90 ms, accelerate); remaining digits shift one slot right (160 ms, standard); vacated high slots become tertiary placeholder zeros (160 ms colour). `haptic.key`.
- **Clear (long-press ⌫, 500 ms):** all digits opacity → 0 and y → +8 (160 ms, accelerate) with right-to-left stagger 15 ms per digit (max 7 digits → 90 ms total stagger); placeholder `€ 0,00` fades in (160 ms, decelerate). `haptic.select` at clear.
- **Over-balance exit:** if backspace brings the amount ≤ balance, M14 exit runs in parallel.
- **Interruptibility:** R.
- **RM:** fades only.

### M14 — Over-balance: enter / exit
- **Trigger (enter):** the typed amount first exceeds the balance (transition from ≤ to >). Not re-triggered by further digits while still over.
- **Enter properties:**
  - `AmountDisplay` digits: colour `color.fg.primary` → `color.danger` (160 ms, standard).
  - Shake of `AmountDisplay`: keyframes as M02 (6 pt × 2 cycles, 240 ms).
  - Inline message `charge.overBalance` ("€ 7,50 more than the balance") in the assist row: opacity 0 → 1, y +4 → 0 (160 ms, decelerate, delay 40 ms). Warning icon precedes the text (colour not alone).
  - `QuickAmountChip` `charge.useBalance` appears (M15), delay 80 ms.
  - Redeem button: enabled → disabled (label colour to disabled, 160 ms). Label keeps the typed amount so the waiter sees what is wrong.
- **Updates while over:** the diff in the message updates in place with a 90 ms cross-fade of the number only (no counting).
- **Exit (amount ≤ balance, by backspace or chip):** colour back (160 ms), message fades out 90 ms, chip M15 exit, button re-enables (160 ms). No shake on exit.
- **Coupling:** `haptic.warning` at enter; no sound.
- **RM:** colour + message + chip fades, no shake.

### M15 — QuickAmountChip appear / disappear
- **Appear:** opacity 0 → 1, scale 0.92 → 1.00 (160 ms, decelerate), transform origin at the chip's leading edge.
- **Tap:** M11 press; then `AmountDisplay` value is **replaced** by the balance — whole string cross-fades 160 ms (it is not typed, so no roll-in, no counting); M14 exit runs; chip disappears.
- **Disappear:** opacity 1 → 0, scale 1.00 → 0.96 (90 ms, accelerate).
- **Interruptibility:** R.
- **RM:** fade only.

### M16 — HoldButton ring fill / reverse (amount ≥ € 100,00)
- **Trigger:** touch-down on `HoldButton` (amount ≥ `holdToConfirmThresholdCents` = 10000). Helper text `charge.hold` is visible above/inside the button whenever the hold variant is active.
- **Properties:**
  - Progress ring (`ProgressRing` inset 4 pt inside the button outline, 3 pt stroke, round caps) sweeps 0 → 360° in **600 ms, linear**, starting at 12 o'clock, clockwise (in RTL layouts too — a clock direction, not a text direction).
  - Button M11 press scale 0.98 (button value, [04 §13.1](04-design-system.md)) held for the duration of the hold.
  - Track: `color.hold.track` (#4F4F52 / #CFCFD0), visible from touch-down.
  - Ring colour: `color.hold.progress` in both themes — #E8A33D light (8.2:1 on the primary button), #B45309 dark (4.6:1 on #F4F4F5). See [04 §8.4](04-design-system.md) and [07](07-accessibility-guidelines.md) §3.3 F1.
  - Ticks: `haptic.holdTick` at 200 / 400 / 600 ms (33/66/100 %).
- **Complete (600 ms):** ring stays full for 90 ms, then M17 begins (request is sent at the 600 ms mark, not after the 90 ms).
- **Release before complete:** ring reverses from its current angle to 0 in **160 ms, decelerate**; scale returns (160 ms). No haptic on release; no request. A new touch-down during the reverse retargets forward from the current angle **but the 600 ms requirement is re-measured from the new touch-down** (the ring restarts from its current angle at the rate needed to finish exactly 600 ms after the new touch-down).
- **Finger slides off the button** (> 12 pt outside, [03b](03b-screens-charge-redeem-success-problems.md) §2): treated as release.
- **Assistive-technology path:** double-tap arm/confirm and actions menu — no ring animation; see [07](07-accessibility-guidelines.md) §5.3.
- **RM:** **kept** — the ring is a progress indicator; the press scale is removed.
- **Purpose:** a deliberate, visible commitment for large amounts without a confirmation screen.

### M17 — Submitting (label → spinner)
- **Trigger:** Redeem tap (touch-up) or hold completion. The request is sent on this frame.
- **Properties:**
  - 0 ms: button enters "busy": no scale change, background stays `action.primary`; the button ignores further taps (logic).
  - Keypad and chip: non-interactive immediately (logic); visual opacity 1 → 0.48 (160 ms, standard) **after 150 ms** only if still waiting (avoids a flicker on fast responses).
  - 150 ms (only if no response yet): label opacity 1 → 0 (90 ms, accelerate); `Spinner` (20 pt, 2 pt stroke, `color.fg.onAccent`) opacity 0 → 1 (160 ms, decelerate, delay 60 ms). Button width is unchanged (no morph to a circle).
  - > 8 s: "Connection slow" state (see [03b](03b-screens-charge-redeem-success-problems.md)); `StatusBanner` via M25, spinner continues, automatic idempotent retry.
  - Network lost: "Redemption uncertain" (`uncertain.title` / `uncertain.body`) panel replaces the keypad area — keypad fades out (160 ms), panel fades/scales 0.98 → 1 (240 ms), per [03b §3.4](03b-screens-charge-redeem-success-problems.md); silent automatic retries with the same key for up to 20 s after the tap, then "Try again" (same key) / "Cancel" fade in (160 ms), [03b §3.5](03b-screens-charge-redeem-success-problems.md).
- **Error (422 etc.):** spinner → label cross-fade back (160 ms), keypad back to full opacity, inline/banner per [03b](03b-screens-charge-redeem-success-problems.md).
- **Interruptibility:** C.
- **RM:** same (fades); spinner rotation is kept (progress).

### M18 — Charge → Success
- **Trigger:** redeem response 2xx (including `replayed: true`).
- **Envelope:** `motion.duration.emphasis` (520 ms). The amount is readable at ≈ 200 ms.
- **Timeline:**

  | t (ms) | Element | Change | Duration / curve |
  |---|---|---|---|
  | 0 | `SuccessMark` halo (24 pt ring, `color.success.bg`) | opacity 0 → 1, scale 0.6 → 1.0 | `motion.spring.card` |
  | 0 | `Keypad`, `AmountDisplay`, CTA | opacity → 0, y +16 | 160, accelerate |
  | 0 | `BalanceCard` → card chip | shrinks to a chip at the top of S09: width → content width (≈ 132 pt), height → 40 pt, radius → `radius.full`, content cross-fades to `•••• 6488` (caption) on `brand_color` | `motion.spring.card` (settles ≈ 330) |
  | 0 | `SuccessMark` circle | stroke path 0 → 100 %, from 12 o'clock clockwise, 3 pt stroke `color.success`; at 240 the circle fill (`color.success`) fades in | 240 draw + 90 fill, standard |
  | 0 | Haptic + sound | `haptic.success` + `sound.success` | — |
  | 80 | Title `success.title` | opacity 0 → 1, y +8 → 0 | 240, decelerate |
  | 120 | Amount (`type.amount.l`) | opacity 0 → 1, y +8 → 0 — **final value, never counted** | 240, decelerate |
  | 200 | `success.remaining` line | opacity 0 → 1, y +4 → 0 | 240, decelerate |
  | 240 | `SuccessMark` check (`color.fg.onSuccess` on the filled circle) | stroke path 0 → 100 %, short leg then long leg | 200, decelerate |
  | 280 | Next-card instruction / actions (`success.next.ios` button or `success.next.android` hint; "Show guest", "Done" per [03b](03b-screens-charge-redeem-success-problems.md)) | opacity 0 → 1, y +8 → 0 | 240, decelerate |
  | 520 | `CountdownHairline` starts (M19) | — | — |

- **Input:** from t = 0 the Success screen is live: Android reader mode is active (a new card at t = 100 ms is valid → M21/M08); a tap anywhere returns to Ready; the buttons accept taps from their first frame (t = 280). S09 has no `TopBar`.
- **Interruptibility:** C — a new card or tap jumps to the end state and runs the next transition.
- **RM:** Charge content fades out 90 ms; S09 fades in 160 ms with the `SuccessMark` shown fully drawn (static, no path draw, no halo scale). Haptic and sound unchanged.
- **Purpose:** unmistakable confirmation for waiter *and* guest (the screen is often shown to the guest) in under a second.

### M19 — CountdownHairline (4 s)
- **Trigger:** end of M18 (t = 520 ms).
- **Properties:** 2 pt line across the top of S09 (below the status bar/safe area), `color.success` on a `color.border.subtle` track; scaleX 1.0 → 0.0 anchored at the **leading** edge (it shrinks toward the start; in RTL it mirrors), **4000 ms, linear**.
- **Screen reader / Switch Control running:** the countdown runs **10 s** instead of 4 s (same linear hairline, [03b](03b-screens-charge-redeem-success-problems.md)) and is cancelled by any assistive-technology navigation on S09 (see [07](07-accessibility-guidelines.md) §8.4).
- **Interruption (brief §1: "any tap interrupts immediately"):** every interaction ends the countdown at once — nothing waits for it:
  - tap on the empty background → M20 to Ready immediately;
  - "Scan next card" (iPhone) or a new card (Android) → that action immediately;
  - "Done" → Ready immediately;
  - "Show guest" → countdown **cancelled**: hairline fades out (160 ms) and the presentation mode stays (its own 20 s return, [03b](03b-screens-charge-redeem-success-problems.md) §4.8).
- **App backgrounded:** countdown pauses; on return it resumes with the remaining time (after > 15 min the unlock flow takes precedence and S09 is dropped to S05, [03b](03b-screens-charge-redeem-success-problems.md)).
- **RM:** **kept** (it is a progress indicator).

### M20 — Success → Ready (auto-return or interrupt)
- **Trigger:** countdown complete, background tap, or (Android) nothing; a new card goes S09 → S07 via M08/M21 instead.
- **Properties:** S09 content opacity → 0, y −8 (160 ms, accelerate); S05 content opacity 0 → 1, y +8 → 0 (240 ms, decelerate, delay 60 ms); `NfcScanAnimation` enters at rest and M04 resumes after 240 ms.
- **iPhone "Scan next card":** does **not** go to Ready first — it opens the system sheet directly from S09 (M27). If the sheet is cancelled, S09 → S05 via M20.
- **RM:** cross-fade 160 ms.

### M21 — New-card swap (Android)
- **Trigger:** a different card is read while on S07 with amount 0, or on S09 (brief §2).
- **Properties:** `BalanceCard` stays in place; its **content and background colour** cross-fade old → new in **300 ms, standard** (brief value). If the new card's lookup exceeds 150 ms, the cross-fade targets the `Skeleton` state first (M09 then brings in data). From S09: M18 is reversed only partially — S09 fades out (160 ms) while S07 builds via M08 from the NFC antenna area (top-centre of the screen).
- **Amount already typed on S07:** no swap. `Snackbar` "Different card detected — Switch?" enters via M23; on "Switch": M21 runs and `AmountDisplay` clears via M13 clear.
- **Coupling:** `haptic.cardDetected` (+ `sound.cardDetected`) at the read.
- **RM:** same cross-fade (it is already a fade).

### M22 — Problem screen entry (S10)
- **Trigger:** scan result with no card data (not found, foreign, verification failed, throttled, network, server) — brief §4 rule.
- **Properties (stagger 40 ms):**

  | Element | From | To | Start | Duration / curve |
  |---|---|---|---|---|
  | Previous screen | opacity 1 | 0 | 0 | 90, accelerate |
  | Status icon (48 pt, colour per severity) | y −12 pt, opacity 0 | y 0, opacity 1 | 0 | 240, decelerate |
  | Title (`type.title.l`) | y +8, opacity 0 | y 0, 1 | 40 | 240, decelerate |
  | Body (≤ 2 lines) | y +8, opacity 0 | y 0, 1 | 80 | 240, decelerate |
  | Actions (bottom) | y +16, opacity 0 | y 0, 1 | 120 | 240, decelerate |

  Total ≤ 360 ms (`slow`). No shake on problem screens (the screen itself is the error signal).
- **Coupling:** `haptic.error` + `sound.error` at t = 0 (danger-class problems); throttled/network use `haptic.warning` + `sound.warning` (see [11](11-sound-and-haptics.md) §3).
- **Verification failed** (`NFC_UID_MISMATCH` / `NFC_SIGNATURE_INVALID` / `NFC_REPLAY_DETECTED`): `haptic.error` + `sound.error` per [11](11-sound-and-haptics.md) E25, with a calm visual per [03b §5.2](03b-screens-charge-redeem-success-problems.md) — same M22 entry, warning-tone icon, no red, no flash, no pulse.
- **Exit:** "Try again"/"Scan again" → S05 via M20-style fade (160 out / 240 in).
- **RM:** whole screen cross-fades 160 ms, no stagger.

### M23 — Snackbar in / out
- **In:** translateY +16 pt → 0 and opacity 0 → 1 (240 ms, decelerate). Position: above the bottom CTA region (never covering the Redeem button or the keypad's bottom row — see [08](08-responsive-behaviour.md) §8).
- **Out (timeout / action):** translateY 0 → +8, opacity → 0 (160 ms, accelerate).
- **Swipe to dismiss:** horizontal drag follows the finger 1:1; release beyond 40 % width or > 600 pt/s dismisses with `motion.spring.soft` carrying the velocity; else returns with `motion.spring.soft`.
- **Stacking:** one snackbar at a time; a new one replaces the old via out (90 ms) + in.
- **Timeout:** 4 s default; 8 s when it has an action; unlimited while a screen reader is on (switch-card uses the Dialog fallback then — [07](07-accessibility-guidelines.md) §5.4); honour Android accessibility timeout.
- **RM:** fade 160 in / 90 out.

### M24 — Bottom sheets (S13 Recent, S13 detail, S14 Menu, S15 session sheets)
- **Open:** sheet translateY from off-screen (below the bottom edge) → detent with `motion.spring.soft`; scrim `color.scrim` opacity 0 → 1 over 240 ms, standard. Sheet content does not animate separately (no stagger inside sheets).
- **Detents:** Recent: medium (50 % of window height) and large (window height − top safe area − 12 pt). Menu: content height (max large). Detail: content height, pushed on top of Recent as a sheet-on-sheet (`color.bg.raised`), underlying sheet scales to 0.96 and darkens with a second scrim at 50 % (iOS-style stacking; same on Android).
- **Drag physics:** the sheet follows the finger 1:1 between detents. Above the largest detent: rubber-band with resistance factor 0.55 (displacement = drag × 0.55, max 24 pt). Scrim opacity is **linked** to position: 1.0 at the lowest detent, linearly → 0 at fully dismissed.
- **Release:** project the resting point as position + velocity × 0.2 s; snap to the nearest detent or dismiss with `motion.spring.soft`, carrying release velocity. Dismiss if projected position is below 50 % of the lowest detent's height or downward velocity > 1000 pt/s.
- **Scroll hand-off:** a scrolled list inside the sheet only drags the sheet when the list is at its top (standard behaviour).
- **Close:** tap scrim, close `IconButton`, system back (Android), or swipe down — all four always exist (drag is never the only way; WCAG 2.5.7).
- **Close animation:** `motion.spring.soft` to off-screen; scrim 1 → 0 in 160 ms, accelerate.
- **Session-expired sheet (S15):** not dismissible by drag or scrim (detent locked; rubber-band on downward drag with factor 0.3, max 16 pt) — the sheet's own action is required.
- **RM:** sheet and scrim fade 160 ms at the final detent; drag still works (it is direct manipulation) but releases animate with a 160 ms fade to the target instead of a spring when the target is dismissal.

### M25 — StatusBanner expand / collapse
- **Expand:** container height 0 → content height (240 ms, standard); content opacity 0 → 1 (160 ms, decelerate, delay 80 ms); icon has no separate motion. Content below it moves down with the same 240 ms standard curve (layout animation, no jump). On S07 the space is taken from the `BalanceCard` flexible height (see [08](08-responsive-behaviour.md) §3.2), so the keypad never moves.
- **Collapse:** content opacity → 0 (90 ms), height → 0 (160 ms, standard, delay 60 ms).
- **Variant change** (e.g. info "Connection slow" → warning "Connection interrupted"): background colour and icon cross-fade 160 ms, text cross-fades 160 ms; height animates if it changes.
- **RM:** height changes instantly with a 160 ms content fade.

### M26 — Offline banner
- **Trigger:** OS reports no network or the last 2 requests failed with network errors.
- **Enter:** `Banner` (info, `offline.title`) slides down from beneath the `TopBar`: translateY −100 % → 0 + opacity (240 ms, decelerate); content below shifts with M25 rules.
- **While offline:** on S05 Android, M04 continues (reads still happen; the lookup shows the network problem); Redeem on S07 is disabled with `offline.body` shown in the banner's expanded state.
- **Exit:** when connectivity is back and one request (or the `/app/config` probe) succeeds: translateY → −100 %, opacity → 0 (160 ms, accelerate). No "back online" celebration.
- **Flapping guard:** banner stays at least 2 s once shown; hides only after 1 s of stable connectivity (prevents flicker in spotty terrace Wi-Fi).
- **RM:** fade 160.

### M27 — iPhone system NFC sheet coordination
We cannot animate Apple's sheet, and must not fight it.

| Moment | What Apple does | What we do |
|---|---|---|
| Tap "Scan card" (S05) or "Scan next card" (S09) | — | M11 press on the button (90 ms). Session is started on **touch-up, same frame**; we do not wait for the press animation. `NfcScanAnimation` (iPhone variant: static arcs around the button) and any loop **pause at rest** (160 ms). No dimming of our own — Apple's sheet brings its own backdrop. |
| Sheet rises (~0.3 s) | sheet with our `ios.sheet.alert` text | Nothing. Our UI is static behind it. |
| Card read | sheet shows ✓ "Card found", system sound + haptic | API request sent immediately (same frame as the read callback). We play **no** `haptic.cardDetected` / `sound.cardDetected` (double feedback). We build S07 off-screen (hidden) so it is ready. |
| Sheet dismisses (~0.3–0.6 s) | sheet slides down | At the invalidation callback we start **M08** with origin = centre of the "Scan card" button. If the lookup is still pending, M08 starts with the Skeleton. The rise overlaps the tail of the sheet's dismissal (both move in the same direction relationship: sheet down, card up — deliberate, reads as "the card was handed over"). |
| Session timeout (~60 s) or Cancel | sheet dismisses | Return to S05 (or stay on S09 → M20); M07 hint fades in; loops resume after 240 ms. No error haptic (brief: "silently with hint text"). |
| Read error inside the sheet | sheet shows its error | Keep session per iOS behaviour; if the session ends with an error, S05 + M07 hint. |

### M28 — Background privacy blur / lock
- **Trigger:** app resigns active (app switcher, notification centre, incoming call, lock).
- **Enter:** a full-window overlay is applied **with no animation** (the OS snapshots immediately; any animation would be captured mid-frame). Overlay: system material blur (iOS `systemThickMaterial` equivalent; Android: 24 dp blur on API 31+, else solid) + centred brand mark. Card balances, amounts and card numbers must not be legible in the app switcher.
- **Return (≤ 15 min, no unlock needed):** overlay opacity 1 → 0 (160 ms, standard). Screen state is unchanged; S09 countdown resumes (M19).
- **Return (> 15 min):** overlay cross-fades directly into S04 (160 ms); after unlock → M03 → the previous screen if it was S07 with no amount typed, else S05 (see [03a](03a-screens-access-and-scanning.md)).
- **Reduce Transparency:** solid `color.bg.canvas` overlay instead of blur.
- **RM:** same (fade only).

### M29 — Spinner
- `Spinner` 20 pt, 2 pt stroke, 270° arc, rotation 360° per **800 ms, linear**, infinite; arc length oscillation is **not** used (calmer). Appears only after 150 ms of waiting (rule applies everywhere, not only Redeem). RM: kept (rotation is permitted as progress; WCAG 2.2.2 does not apply to loading indicators that stop on completion).

### M30 — Scan-throttle countdown & retry enable (S10 variant)
- Countdown text updates once per second with a 90 ms cross-fade of the number only (no ticking/sliding digits). When it reaches 0: the "Try again" button enables (colour 160 ms, standard); `haptic.select` once. RM: same.

---

## 5. Happy-path timeline — motion never adds time

All times typical, from brief §3. **Bold** = critical path (waiter or network). Animations are drawn on the lines beneath; they only ever overlap the critical path.

### 5.1 Android (≈ 3.5 s to ready-for-next)

```
t (s)     0.0       0.5       1.0       1.5       2.0       2.5       3.0       3.5
          |---------|---------|---------|---------|---------|---------|---------|
CRITICAL  [read 0.3][lookup≤0.4]                       [tap][redeem≤0.5]
PATH      ▲card in field      ▲Charge interactive      ▲0.1 ▲request   ▲Success
          |                   |  [ type 4 digits ~1.2 s ]    sent at    visible
          |                   |                              touch-up   [guest 0.8 s]
          |                                                             ▲next card OK
MOTION
M04 breath ~~~~|
M05 reading    [90]
M06 collapse       [==240==]                 (runs inside lookup time)
M10 skeleton          [·]  (only if lookup >150 ms after read)
M08 card rise          [==motion.spring.card, legible @150, settled @330==]
M08 keypad up            [40 delay][==240==]  keys live from frame 1
M11/M12 keys                        [160][160][160][160]  retargeting, no queue
M17 spinner                                          [150 wait → spinner only if slow]
M18 success                                                    [=====520=====]
   amount readable                                                  ▲+200 ms
M19 hairline                                                              [4 s ...→
HAPTIC/SND ●cardDetected @0.3                                  ●success @response
```

### 5.2 iPhone (≈ 4.5 s)

```
t (s)     0.0       0.5       1.0       1.5       2.0       2.5       3.0       3.5       4.0       4.5
          |---------|---------|---------|---------|---------|---------|---------|---------|---------|
CRITICAL  [tap 0.4][sheet 0.3][read 0.5][lookup≤0.4 ‖ sheet ✓ + dismiss 0.3–0.6]
                                        ▲request sent at read     [type ~1.2 s][tap][redeem][guest 0.8]
MOTION
M11 press [90]  session starts at touch-up (no wait)
M27 loops paused  [..........behind Apple sheet..........]
M08 card rise                            (at sheet invalidation) [==motion.spring.card==]
M08 keypad up                                                     [40][==240==] keys live frame 1
M12 digits                                                              [160]x4
M17 / M18 / M19                                                                  as Android
```

### 5.3 Animations that run in parallel with network time

| Network wait | Parallel motion | Rule |
|---|---|---|
| Scan lookup (`POST /scan`) | M06 ring collapse, M08 card rise (skeleton if needed), M10 shimmer, M09 skeleton → content; iPhone: Apple sheet dismissal | request is sent on the read frame; M08 starts at response **or** read + 150 ms, whichever first |
| Redeem (`POST /redeem`) | M11 release, M16 final 90 ms full-ring hold, M17 (spinner only after 150 ms), M25 "Connection slow" / "Connection interrupted" banners, M29 | request sent at touch-up / hold completion; success choreography starts on response, never delays it |
| Auto-retry after network loss | M25 warning banner, M29 spinner | retries reuse the same `Idempotency-Key`; motion is state display only |
| `/app/config` at start | M01 | splash ≤ 600 ms; if config is slow, cached config is used and the app proceeds |

### 5.4 Hard rules (acceptance)

1. No request is ever sent after, or conditional on, the end of an animation.
2. No tap, key or NFC read is ever ignored because an animation is running.
3. A transition started by input A is retargeted (not queued) by input B.
4. The total of all motion on the critical path is **0 ms**: every animation overlaps either network time or the waiter's own input time.
5. Recorded end-to-end times with animations ON and with Reduce Motion ON differ by < 50 ms.

---

## 6. Performance & implementation constraints

- 60 fps minimum on the reference low-end Android (Android 9, 2 GB RAM); 120 fps on ProMotion where the platform grants it. A dropped frame in M08, M12 or M18 is a release blocker; in M04/M10 it is not.
- Animate only transform and opacity where possible; `BalanceCard` → chip (M18) animates size and radius — render the card as one layer during the morph (no text reflow per frame; the content cross-fades).
- Blur (M28) is static; never animate blur radius.
- Shadows animate opacity, never blur radius.
- All loops (M04, M10, M29) stop when their element is not visible, when the app is backgrounded, and — for M04/M10 — in Low Power Mode / Battery Saver (use RM variant).
- Details on engine choices and platform-specific curve mapping: [09](09-flutter-handoff.md).

## 7. Acceptance checklist (motion QA)

- [ ] Every animation in §3 is implemented with the listed token/values (screen recording at 240 fps, frame-stepped).
- [ ] Reduce Motion ON: no translate/scale/path-draw/shake anywhere; ring static; hold ring, hairline, spinner still animate.
- [ ] Amounts never count; no frame shows an intermediate monetary value (frame-step M14, M15, M18, M21).
- [ ] Keys pressed during M08 register; Redeem tap during M12 sends immediately.
- [ ] Success amount readable ≤ 200 ms after response (frame-step).
- [ ] Haptic/sound coupling within tolerances of [11](11-sound-and-haptics.md) §4.
- [ ] iPhone: no own feedback during Apple's sheet; M08 starts on sheet invalidation.
- [ ] App switcher snapshot shows the privacy overlay, never a balance.
- [ ] Low Power Mode / Battery Saver: M04 and M10 static.

## 8. Alignment items with screen specs

The screen specs were written in parallel; the items below have been reconciled. This document remains the motion source of truth; the screen spec owns layout and content.

| Item | Resolution (applied in 03a / 03b / 05) |
|---|---|
| `ring-breathe` / `ring-pulse` period / curve | **Resolved:** 2400 ms period, sine in-out, scale 1.00 → 1.04 (M04). |
| Read start (`ring-read`) vs `ring-converge` | **Resolved:** read start = M05 (90 ms scale to 1.06); rings converge into the card only on a successful read (M06). |
| Read failure | **Resolved:** M05 revert 240 ms; **no ring shake anywhere** (shake is reserved for input fields, M02). |
| S09 mark | **Resolved:** halo spring + circle draw 0–240 ms, check stroke 240–440 ms (200 ms); haptic + sound at t = 0. |

---

Version 1.0 · September 2026 · GiftCard Waiter design specification
