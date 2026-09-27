# 05 · Component Library — GiftCard Waiter

*Every component of the GiftCard Waiter app: anatomy, measurements, tokens per state, behaviour, feedback hooks, accessibility and usage. Built on the foundations in [04-design-system.md](04-design-system.md). Component names are binding (brief §6).*

| | |
|---|---|
| **Read first** | [04-design-system.md](04-design-system.md) — tokens, state model (§13), contrast (§8), navigation (§20) |
| **Screens** | [03a-screens-access-and-scanning.md](03a-screens-access-and-scanning.md) (S01–S06, S11, S12, S14–S17) · [03b-screens-charge-redeem-success-problems.md](03b-screens-charge-redeem-success-problems.md) (S07–S10, S13) |
| **Motion** | Durations/curves named here; choreography in [06-motion-guidelines.md](06-motion-guidelines.md) |
| **Accessibility** | Label patterns here; procedures and test scripts in [07-accessibility-guidelines.md](07-accessibility-guidelines.md) |
| **Sizes across devices** | [08-responsive-behaviour.md](08-responsive-behaviour.md) |
| **Haptics & sound** | Hooks here; design in [11-sound-and-haptics.md](11-sound-and-haptics.md) |
| **Strings** | Brief keys quoted verbatim; all other strings are English *examples* whose final wording and keys live in [12-ui-copy-and-error-messages.md](12-ui-copy-and-error-messages.md) |
| **Implementation mapping** | [09-flutter-handoff.md](09-flutter-handoff.md) |

**Conventions.** All measurements in pt (= dp). "Target" = touch target; "visual" = drawn shape. States use the names of 04 §13: *default, pressed, focused, disabled, loading, success, error* plus component-specific states. ➕ marks a component token or value that is not in the brief. Every component meets `size.target.min` 56 × 56 pt. No component uses a ripple, a platform default widget look, or a shadow unless stated.

---

## Contents

1. [Buttons](#1-buttons) — shared rules · PrimaryButton · SecondaryButton · TertiaryButton · DangerButton · HoldButton · IconButton
2. [Inputs](#2-inputs) — Keypad · AmountDisplay · QuickAmountChip · TextField · CardNumberField
3. [Display](#3-display) — BalanceCard · StatusBadge · StatusBanner · NfcScanAnimation · ProgressRing · Skeleton · Spinner · SuccessMark · CountdownHairline · TransactionRow · HistoryCard
4. [Feedback and containers](#4-feedback-and-containers) — Snackbar · BottomSheet · Dialog · Banner · EmptyState · ProblemScreen
5. [Navigation and identity](#5-navigation-and-identity) — TopBar · Avatar
6. [Pattern: confirmation screens](#6-pattern-confirmation-screens)
7. [Component × screen matrix](#7-component--screen-matrix)

---

## 1. Buttons

### 1.0 Shared button rules

**Size variants**

| Variant | Height | Compact height (< 700 pt) | Radius | Horizontal padding | Label | Icon | Icon ↔ label | Min width |
|---|---|---|---|---|---|---|---|---|
| Large | 64 | 56 | `radius.l` 20 | 24 (`space.6`) | `type.label.l` 17/22 | `icon.24` | 8 | full width |
| Regular | 56 | 56 | `radius.m` 16 | 20 (`space.5`) | `type.label` 15/20 | `icon.20` | 8 | 120 (hug) or full width |

**Layout.** CTAs in the thumb zone are **full content width** (screen width − 2 × margin). Buttons in stacks: vertical, gap `space.3` 12 pt, never side by side on phones (glove rule: no two primary/destructive actions adjacent). Side-by-side regular buttons are allowed only for two *secondary* alternatives (S05 "QR code" / "Enter number"), gap 8, equal width.

**Label rules.** Verb + object (brief §7). Amounts inside labels: formatted per restaurant locale with a no-break space inside the amount. Labels never truncate: they wrap to 2 lines and the button grows (padding stays 12 pt min top/bottom). Leading icon optional; trailing icons not used (no "→" arrows).

**State timing.** Pressed within one frame of touch-down; press-in `motion.duration.instant` 90 ms `ease.standard`; release `motion.duration.fast` 160 ms `ease.decelerate`. Activation on **touch-up inside** (buttons are not keys). A touch that moves > 16 pt outside the button bounds cancels the press (visual returns to default, no activation).

**Loading.** Spinner appears **150 ms** after activation (`time.feedbackDelay`); before that the button keeps its pressed look for up to 150 ms, then shows the spinner. Width and height never change. While loading the button is inert and announces "busy".

**Focus.** 2-pt `color.focus.ring` outside the shape, 2-pt offset, radius = button radius + 2 (+ 2-pt saffron accent band outside in light theme; 3 pt in high contrast).

**Accessibility.** Role: button. Label = visible label (amounts in spoken form, e.g. "Redeem 24 euro 90"). Disabled buttons stay focusable by screen readers and expose "dimmed"/"disabled" plus the reason via hint when a reason exists (e.g. "Amount is more than the balance").

---

### 1.1 PrimaryButton

**Purpose.** The single most important action on a screen. Exactly one per screen.

**Anatomy**
```
┌──────────────────────────────────────────────┐
│ ① fill                                        │
│              [② icon]  ③ Redeem € 24,90       │   ④ focus ring (outside, 2 pt)
│                                               │
└──────────────────────────────────────────────┘
 ⑤ spinner replaces ②+③ while loading
```

**Tokens per state**

| State | Fill ① | Label ③ / icon ② | Other |
|---|---|---|---|
| Default | `color.action.primary` (#18181B / #F4F4F5) | `color.fg.onAccent` | – |
| Pressed | `color.action.primaryPressed` (#27272A / #D4D4D8) | `color.fg.onAccent` | scale 0.98 |
| Focused | default fill | default | ring `color.focus.ring` |
| Disabled | `color.bg.key` | `color.fg.tertiary` (HC: `fg.secondary` normal value) | no scale, not interactive |
| Loading | `color.action.primary` | Spinner 20 pt in `fg.onAccent` | inert |
| Loading, slow (> 8 s, S08 only) | `color.action.primary` | Spinner + "Connection slow" (`type.label`, `fg.onAccent`) | copy in 12 |
| Success (S08 → S09 hand-off) | `color.action.primary` | spinner cross-fades to `circle-check` icon.24 in `fg.onAccent` for 160 ms, then the screen transitions | only when a screen change follows |
| Error | returns to Default within 160 ms | – | error content is shown by the screen (StatusBanner/ProblemScreen), never inside the button |

**Behaviour.** Activation on touch-up. Double activation is impossible: the button becomes inert at touch-up and stays inert until the action resolves (idempotency is still guaranteed server-side, see brief §1). Keyboard: Enter/Return activates the screen's PrimaryButton — except a HoldButton (§1.5).

**Haptics/sound.** None of its own. The outcome (success, error) triggers screen-level haptics.

**Motion.** Press scale, spinner cross-fade `fast`; label changes when the amount changes are instant (no animation while typing, the label must track the keypad exactly). See [06-motion-guidelines.md](06-motion-guidelines.md).

**Accessibility.** Role button; label equals visible text with spoken amounts; value none; hint only when disabled ("Enter an amount", "Amount is more than the balance"). Min target 64 × full width (large) / 56 (regular).

**Content.** Verb first in EN/BHS ("Redeem € 24,90", "Iskoristi 24,90 €"), infinitive last in DE ("€ 24,90 einlösen"). Keys: `charge.redeem`, `charge.redeemFull`, `ready.ios.button`, `success.next.ios`.

**Do / Don't**

| Do | Don't |
|---|---|
| Put the exact amount in the label. | "Confirm", "OK", "Submit". |
| Keep it at the bottom, full width. | Place it in the top half or float it (no FAB). |
| Disable it with a visible reason (inline message). | Hide it when the amount is 0 — show it disabled so the layout stays still. |

**Platform differences.** iOS: continuous corners. Android: circular corners; no ripple, no elevation, no uppercase label (Material default overridden).

**Used in.** S02 Sign in · S03 Use Face ID/fingerprint · S05 iPhone "Scan card" · S07 Redeem (< € 100) · S09 iPhone "Scan next card" · S10 primary recovery · S11 Find card · S15 Sign in again / Update · S16 Open NFC settings / Open settings · S17 Continue / Start.

---

### 1.2 SecondaryButton

**Purpose.** An alternative action of lower importance that is still a real choice (e.g. another scan method, "Cancel" in a dialog).

**Anatomy.** Same as PrimaryButton; fill ①, label ③, optional icon ②.

| State | Fill | Label/icon | Other |
|---|---|---|---|
| Default | `color.bg.key` | `color.fg.primary` | HC: + 1 pt `color.border.control` inner outline |
| Pressed | `color.bg.keyPressed` | `color.fg.primary` | scale 0.98 |
| Focused | default | default | focus ring |
| Disabled | `color.bg.key` | `color.fg.tertiary` — *exception to the "no tertiary on bg.key" rule: disabled text is exempt from 1.4.3; still 4.28 : 1* | – |
| Loading | `color.bg.key` | Spinner 20 in `fg.primary` | inert |

**Behaviour, motion, accessibility.** As PrimaryButton.

**Content.** Short (≤ 18 characters DE): "QR-Code", "Nummer eingeben", "Abbrechen".

**Do / Don't.** Do use for peer alternatives. Don't use two SecondaryButtons *and* a PrimaryButton in one stack on phones (max: 1 primary + 1 tertiary, or 2 secondaries side by side).

**Platform differences.** None beyond corners.

**Used in.** S05 alternatives (QR code, Enter number) · S10 secondary recovery where it is a real alternative · S16 · Dialog "Cancel" / "Keep current card" · EmptyState action.

---

### 1.3 TertiaryButton

**Purpose.** Low-emphasis text action: escape hatches and minor alternatives ("Not now", "Use password", "Forgot password?", "Skip").

**Anatomy**
```
     ┌─────────────────────────┐
     │   Enter number instead  │   ← label only; fill appears only when pressed
     └─────────────────────────┘
```

| Property | Value |
|---|---|
| Height | 56 target; visual pressed fill 44 pt high, `radius.m` 16 |
| Padding | 16 horizontal |
| Label | `type.label` (regular) / `type.label.l` when stacked under a large PrimaryButton |
| Width | hug content (min 120 target width), centred under the CTA |

| State | Fill | Label |
|---|---|---|
| Default | none | `color.fg.primary` |
| Pressed | `color.bg.key` (44 pt pill, `radius.m`) | `color.fg.primary` |
| Focused | none | focus ring around the 44-pt shape |
| Disabled | none | `color.fg.tertiary` |
| Loading | – (tertiary actions never load; if one starts a request, it becomes the screen's primary state) | – |

**Rules.** Never underlined, never saffron, never `info` blue (it is not a web link). Inside a StatusBanner it aligns to the banner's text column. In a Snackbar the action uses the snackbar's own style (§4.1).

**Accessibility.** Role button (not link) — except "Forgot password?" which opens a web page: role link, hint "Opens in browser".

**Used in.** S02 Forgot password? · S03 Not now · S04 Use password · S10 alternative · S12 Enter number instead · S17 Skip · StatusBanner actions · Banner "Details".

---

### 1.4 DangerButton

**Purpose.** Confirms a destructive action. **Only** in the Menu sign-out confirmation Dialog (brief §6).

| State | Fill | Label |
|---|---|---|
| Default | `color.danger` (#B91C1C / #F87171) | `color.fg.onDanger` ➕ (#FFFFFF / #0A0A0C) — 6.47 / 7.15 : 1 |
| Pressed | `color.danger.pressed` ➕ (#991B1B / #EF4444) | `color.fg.onDanger` — 8.31 / 5.26 : 1; scale 0.98 |
| Focused | default | focus ring |
| Disabled | not used | – |
| Loading | Spinner 20 in `fg.onDanger` (sign-out revokes the token server-side; ≤ 150 ms usually, spinner rarely visible) | – |

Size: regular (56), full dialog width. Label: "Sign out" / "Abmelden" / "Odjavi se" (keys in 12). Icon: none (the word is enough; `log-out` is used in the Menu row, not in the dialog). Never placed adjacent to a PrimaryButton; in the dialog it sits **above** the SecondaryButton "Cancel" with a 12-pt gap, so the safe action is nearer the thumb.

**Used in.** S14 → Dialog "Sign out?".

---

### 1.5 HoldButton

**Purpose.** A PrimaryButton (large) variant that requires a deliberate **press-and-hold of 600 ms** before redeeming amounts **≥ € 100,00** (`holdToConfirmThresholdCents = 10000`, fixed in v1). It replaces a confirmation screen (see §6).

**Anatomy**
```
┌──────────────────────────────────────────────┐
│                                               │
│  ⓐ◯      ⓑ Redeem € 124,90                    │   ⓐ ProgressRing 28 pt (track + progress)
│           ⓒ Hold to redeem                    │   ⓑ line 1: amount label (type.label.l)
│                                               │   ⓒ line 2: instruction (type.caption)
└──────────────────────────────────────────────┘
  ⓓ fill (action.primary)   ⓔ focus ring outside
```

**Measurements**

| Part | Value |
|---|---|
| Height | 64 (56 compact height) |
| Radius | `radius.l` 20 |
| Ring ⓐ | 28 pt diameter, stroke 3 pt, round caps; centre 34 pt from the leading edge (20-pt inset + 14) |
| Label block ⓑ+ⓒ | centred in the button; horizontal padding **60 pt on both sides** (keeps the block optically centred and clear of the ring) |
| Line 1 ⓑ | `type.label.l` 17/22, `fg.onAccent` |
| Line gap | 2 pt |
| Line 2 ⓒ | `type.caption` 13/18, `fg.onAccent` at 72 % (9.54 : 1 light, 7.80 : 1 dark) — copy `charge.hold` |
| Vertical | block 42 pt; centred (11 pt top/bottom at 64, 7 pt at 56) |

**Tokens per state**

| State | Fill | Ring track | Ring progress | Labels | Other |
|---|---|---|---|---|---|
| Default (armed) | `action.primary` | `color.hold.track` ➕ (#4F4F52 / #CFCFD0) | 0 % | line 1 + line 2 | – |
| Holding | `action.primaryPressed` | track | `color.hold.progress` ➕ (#E8A33D / #B45309) — 6.91 / 3.40 : 1 on pressed fill | unchanged | scale 0.98 |
| Completed → Redeeming (S08) | `action.primary` | – | ring becomes a Spinner (270° arc rotating) in `hold.progress` | line 2 → "Redeeming…" (copy in 12) | inert |
| Redeeming slow (> 8 s) | same | – | spinner | line 2 → "Connection slow" | – |
| Cancelled | back to default in 160 ms | track | drains to 0 % in 160 ms `ease.decelerate` | line 2 emphasised (see Behaviour) | – |
| Focused | default | – | – | – | focus ring |
| Disabled (amount > balance, offline) | `bg.key` | `fg.tertiary` at 24 % | – | `fg.tertiary`; line 2 hidden | – |

**Behaviour**

| Time from touch-down | Event |
|---|---|
| 0 ms | Pressed look; ring progress starts at 12 o'clock, clockwise, **linear in time** |
| 200 ms (33 %) | `haptic.holdTick` |
| 400 ms (66 %) | `haptic.holdTick` |
| 600 ms (100 %) | `haptic.holdTick`; redeem starts **immediately** (no release needed); `Idempotency-Key` is generated now (brief §1: at the start of the Redeem action) |

- **Release before 600 ms** → cancel. No haptic. If the press lasted < 250 ms (a tap), line 2 switches to 100 % opacity and weight 600 for 1.2 s and screen readers hear "Hold to redeem" — the only teaching the component does.
- **Finger slides > 12 pt outside** the button (hold slop, [03b §2.12](03b-screens-charge-redeem-success-problems.md), [06](06-motion-guidelines.md) M16) → cancel (as release).
- **Second finger** anywhere → ignored. **Palm/edge touches** on other controls during a hold are ignored.
- **Interruptions cancel the hold:** app to background, incoming call, system NFC sheet, Android new-card tap (then the switch-card snackbar logic of S07 applies), amount change (impossible while holding: keypad is not touchable by the same thumb, but a second touch on the keypad is ignored anyway).
- **Threshold crossing while typing:** when the typed amount reaches € 100,00 the PrimaryButton morphs into the HoldButton (ring and line 2 fade in, 160 ms); dropping below reverses it. No haptic for the morph.
- **Hardware keyboard / Enter:** does **not** activate a HoldButton. Screen-reader and switch users use the accessibility action (below).

**Haptics/sound.** `haptic.holdTick` ×3 as above. No sound on hold; `haptic.success` + `sound.success` come with S09.

**Motion.** Progress is driven by time, not animation curves; drain uses `fast`/`decelerate`; ring-to-spinner morph `fast` (06). Reduce Motion: unchanged (progress indicator).

**Accessibility**
- Role button; label "Redeem 124 euro 90"; value `charge.hold`; hint "Double tap and hold, or use the actions menu." — the exact element, the three equivalent paths (A sustained gesture, B arm-then-confirm with 10 s disarm, C named custom action "Confirm redeem 124 euro 90") and their announcements are owned by [07 §5.3](07-accessibility-guidelines.md); this component implements them unchanged.
- Choosing the custom action from the actions menu is an explicit, deliberate act equivalent to the hold (Switch Control, Voice Control, dwell).
- Progress announced? No — ticks are haptic; completion is announced by S08/S09 live regions.
- Target: full width × 64.

**Content.** Line 1 is the same string as the PrimaryButton would show (`charge.redeem` / `charge.redeemFull`); line 2 is `charge.hold`. Never "Slide to…" or "Press firmly".

**Do / Don't.** Do keep the ring at the leading edge for both hands (left-handed users cover the ring with the thumb less often than a centred ring — it stays visible either side of a centred thumb because the label block is centred). Don't use a hold for anything other than redeeming ≥ € 100. Don't add a confirmation dialog after the hold.

**Platform differences.** iOS: long-press recognition must not trigger the system text-selection/magnifier or 3D-touch previews. Android: no long-press tooltip, no ripple, no system haptic on long press (our ticks replace it).

**Used in.** S07/S08 when amount ≥ € 100,00.

---

### 1.6 IconButton

**Purpose.** An icon-only action for universally understood functions: Close ✕, Recent, Menu, Torch, password visibility.

**Anatomy**
```
   ┌──────── 56 ────────┐
   │     ╭──44──╮       │   target 56 × 56
   │     │  ✕   │       │   pressed fill: 44-pt circle
   │     ╰──────╯       │   icon.24 centred (optically)
   └────────────────────┘
```

**Variants**

| Variant | Rest fill | Pressed fill | Icon colour | Use |
|---|---|---|---|---|
| Plain | none | `bg.key` 44-pt circle | `fg.primary` | TopBar, sheets, TextField trailing |
| On-camera ➕ | `color.camera.overlay` 44-pt circle | overlay + `state.pressedOverlay` (white 8 %) | #FFFFFF | S12 close and torch over the viewfinder |

| State | Visual |
|---|---|
| Default | icon only (plain) |
| Pressed | 44-pt circle fill appears (90 ms), no scale |
| Focused | focus ring around the 44-pt circle |
| Disabled | icon `fg.tertiary` (e.g. Recent while no redemption exists is **not** disabled — it opens the EmptyState) |
| Selected/toggled (torch on, password visible) | icon swaps (`flashlight` → `flashlight-off`, `eye` → `eye-off`); on-camera torch-on fill becomes `color.accent.saffron` with #0A0A0C icon (10.70 : 1) — the one saffron element on S12 |

**Placement.** Glyph aligned to the screen margin: target edge at margin − 16 pt. Adjacent IconButtons: targets abut (0 gap), glyph centres 56 pt apart.

**Accessibility.** Role button (toggle for torch/visibility with state "on/off"). Labels: "Close", "Recent redemptions", "Menu", "Torch", "Show password"/"Hide password" (keys in 12). Every IconButton also has a system alternative where relevant (✕ ↔ back gesture).

**Platform differences.** Android: long-press shows no tooltip (label is announced by TalkBack; tooltips clutter). iPad with pointer: hover shows the 44-pt fill at 4 % (`state.hover`).

**Used in.** TopBar (S05, S07, S10, S11, S12) · BottomSheet header (S13, S14, S15) · TextField password (S02) · S12 torch.

---

## 2. Inputs

### 2.1 Keypad

**Purpose.** Fast, glove-proof numeric entry for amounts (S07) and card numbers (S11). Replaces the system keyboard.

**Anatomy (amount variant)**
```
┌──────────┐ ┌──────────┐ ┌──────────┐
│    1     │ │    2     │ │    3     │   ① key shape (bg.key, radius.l)
└──────────┘ └──────────┘ └──────────┘   ② digit (type.key)
┌──────────┐ ┌──────────┐ ┌──────────┐
│    4     │ │    5     │ │    6     │   gap 8 horizontal and vertical
└──────────┘ └──────────┘ └──────────┘
┌──────────┐ ┌──────────┐ ┌──────────┐
│    7     │ │    8     │ │    9     │
└──────────┘ └──────────┘ └──────────┘
┌──────────┐ ┌──────────┐ ┌──────────┐
│    00    │ │    0     │ │    ⌫     │   ③ 00 key   ④ delete (icon.24 `delete`)
└──────────┘ └──────────┘ └──────────┘
```

**Variants**

| Variant | Bottom-left key | Used in |
|---|---|---|
| Amount | "00" | S07 |
| Card number | empty cell (no key shape, not focusable — a dead-looking key would invite taps) | S11 |

**Measurements**

| Property | Regular height | Compact height (< 700 pt) |
|---|---|---|
| Key height | **72** | **64** |
| Key width | (keypad width − 16) / 3 → 106 pt at 375-pt screen, 117 at 393 | same |
| Gaps | 8 × 8 | 8 × 8 |
| Total height | 312 | 280 |
| Radius | `radius.l` 20 (continuous on iOS) | same |
| Keypad width | content width; tablets max 400, centred ([08-responsive-behaviour.md](08-responsive-behaviour.md)) | – |
| Digit | `type.key` 30/36, weight 500, tabular, optically centred on cap height | same |
| ⌫ glyph | `icon.24`, stroke 1.75, nudged 1 pt left | same |

No letters under digits (this is not a phone dialler). No key borders (HC: 1-pt `border.control`).

**Tokens per state**

| State | Key fill | Glyph | Transform |
|---|---|---|---|
| Default | `color.bg.key` | `color.fg.primary` | – |
| Pressed | `color.bg.keyPressed` | `color.fg.primary` | **scale 0.96**, 90 ms in / 160 ms out |
| Focused (hardware keyboard / switch) | default | default | focus ring 2 pt around the key |
| Disabled (whole keypad during S08) | default fill, whole keypad at `opacity.disabled` 0.40 | – | inert |
| Rejected input | key shows the normal press; AmountDisplay reacts (see 2.2) | – | – |

**Behaviour**
- **Registration on touch-down** (not touch-up): speed matters (4 digits ≈ 1.2 s budget, brief §3) and rolling thumb presses must never drop a digit. Sliding off a key does not cancel it.
- **Key repeat off:** holding a digit enters it once.
- **⌫ tap:** deletes the last digit (on touch-down).
- **⌫ long-press 500 ms** (`time.longPressClear`): clears the whole entry; `haptic.select`; the ⌫ key stays pressed until release. The first digit already deleted at touch-down is part of the clear (no double effect).
- **Multi-touch:** a second touch-down registers in order; a third simultaneous touch is ignored.
- **Leading zeros** ("0", "00" on an empty amount) are ignored silently (no haptic).
- **Limit reached** (7 digits amount / 16 digits card number): further digits are rejected — `haptic.warning` replaces `haptic.key` for that press, AmountDisplay/CardNumberField does a 3-pt nudge (06). "00" with only one free slot is rejected entirely (never half-applied).
- **Hardware keyboard** (tablets, Bluetooth): 0–9 and numpad digits type, Backspace deletes, Cmd/Ctrl + Backspace clears, Return activates the PrimaryButton (never a HoldButton).
- **Visibility:** hidden (not disabled) when partial redemption is disabled or the card cannot be redeemed (layouts in 03b).

**Haptics/sound.** `haptic.key` on every accepted touch-down; `haptic.warning` on rejected input; `haptic.select` on long-press clear. **No key sounds** (brief).

**Motion.** Press scale; digit entry animation belongs to AmountDisplay. Reduce Motion: scale kept (≤ 4 % size change, not motion), fill change kept.

**Accessibility**
- Each key: role button (keyboard key trait on iOS); labels "1" … "9", "0", "double zero", "Delete".
- ⌫ hint "Double-tap and hold to clear"; custom action "Clear amount" / "Clear number".
- Focus order row by row, left to right.
- Typing echo is not spoken per key; the AmountDisplay live value is (debounced, see 2.2).
- Targets: 106 × 72 minimum.

**Content.** Digits only. "00" is a single key label, not two keys.

**Do / Don't**

| Do | Don't |
|---|---|
| Keep the keypad anchored directly above the CTA block. | Use the system numeric keyboard (layout varies, "Done" key, no 00). |
| Keep key size stable across all card states. | Add a decimal-point key (POS entry makes it unnecessary). |

**Platform differences.** iOS: keys must not show the system key-preview balloon. Android: no ripple, no system keyboard-click sound (our `haptic.key` maps to `KEYBOARD_TAP`).

**Used in.** S07 (amount) · S11 (card number).

---

### 2.2 AmountDisplay

**Purpose.** Shows the amount being entered, payment-terminal style: digits shift in from the right ("2 4 9 0" → € 24,90). Max 7 digits = € 99.999,99.

**Anatomy**
```
                 ① ② ③
                 € 24,90                          ① currency symbol (60 %, baseline-aligned)
                                                  ② implicit digits (placeholder colour)
                                                  ③ typed digits
   ④ ⓘ € 7,50 more than the balance   ⑤ [Use balance · € 32,50]
   ④ inline message slot               ⑤ QuickAmountChip (§2.3)
```

**Measurements**

| Part | Value |
|---|---|
| Amount line box | 68 pt (`type.amount.xl` 64/68) |
| Symbol | `type.currency.xl` 38 pt, same baseline, gap per locale (0.16 em = 10 pt spaced, 0.04 em = 3 pt tight) |
| Alignment | horizontally centred as one unit (symbol + digits); width changes only when the digit count changes |
| Message slot ④ | directly below, gap 4; min height 40 (holds the chip); text `type.body.m` with `icon.16`, gap 8 |
| Available width | content width |

**Formatting logic (described).** The display value is the typed digit string interpreted as cents. Before any digit: placeholder "€ 0,00" (locale form) entirely in `fg.tertiary`. After typing "2": "€ 0,02", where "€ 0,0" is `fg.tertiary` and "2" is `fg.primary`; after "249": "€ 2,49", all significant characters `fg.primary`, the symbol switches to `fg.primary` as soon as the value is > 0. Group separators appear from 1.000 upward. Tabular digits guarantee no horizontal jitter.

**States**

| State | Digits / symbol | Message slot | Trigger / notes |
|---|---|---|---|
| Empty | placeholder "€ 0,00" `fg.tertiary` | empty | PrimaryButton disabled |
| Entering | implicit zeros `fg.tertiary`, typed digits `fg.primary` | empty | – |
| Valid | `fg.primary` | empty (or `charge` helper if any, copy in 12) | – |
| Over balance | `color.danger` | `circle-alert` + `charge.overBalance` ("€ 7,50 more than the balance") in `color.danger` (6.20 / 7.15 : 1) + QuickAmountChip `charge.useBalance` | Redeem disabled; `haptic.warning` once when crossing into this state (not on further digits) |
| Over max single redemption (after server 422) | `color.danger` | message with the limit (copy in 12) | shown until the amount changes |
| Limit reached (7 digits) | unchanged | – | rejected keypress: 3-pt horizontal nudge (06) + `haptic.warning` |
| Fixed (partial redemption disabled) | full balance, `fg.primary`, no placeholder | caption "Full balance only" `fg.secondary` (copy in 12) | keypad hidden; button `charge.redeemFull` |
| Redeeming (S08) | `fg.primary`, locked | – | – |
| Shrunk | size steps down 2 pt at a time to fit width, min 40 pt (04 §3.7) | – | only if the amount + symbol exceed the width (large Dynamic Type or narrow tablet pane) |

**Behaviour.** No caret, no selection, no paste (POS entry). Tapping the display does nothing. Currency placement per restaurant locale (04 §3.4): de-AT "€ 24,90", de-DE "24,90 €", en-GB "€24.90". The amount is kept when the screen is interrupted by the system (backgrounding < 15 min) and discarded on ✕/back.

**Haptics/sound.** Through the Keypad; `haptic.warning` for over-balance crossing and rejected input. No sound.

**Motion.** New digit: slides in from the right 8 pt + fade, `instant` 90 ms, existing digits shift left by one tabular advance, `instant` `ease.standard`. Delete: reverse. Chip-applied amount: roll to the new value, `base` 240 ms. Reduce Motion: instant replacement. Details: [06-motion-guidelines.md](06-motion-guidelines.md).

**Accessibility**
- Role: static text with live region (polite), label "Amount", value spoken form: "24 euro 90"; empty: "0 euro".
- Announcement is **debounced 400 ms** after the last keypress so fast typing yields one announcement of the final value.
- Over-balance: message announced (polite) once when entering the state.
- The message slot's icon is decorative; the text carries meaning.

**Content.** Only formatted numbers; no labels like "Amount:" visible (context is obvious; screen readers get the label).

**Do / Don't.** Do show the placeholder in tertiary so the waiter sees where digits will appear. Don't use a text cursor, don't allow decimals typing, don't right-align (centred keeps symmetry for both hands).

**Platform differences.** None.

**Used in.** S07, S08.

---

### 2.3 QuickAmountChip

**Purpose.** One-tap correction to the full balance when the typed amount exceeds it: "Use balance · € 32,50" (`charge.useBalance`).

**Anatomy**
```
 ╭────────────────────────────╮
 │  Use balance · € 32,50     │   visual 40 pt · target 56 pt (extends 8 pt above/below)
 ╰────────────────────────────╯
```

| Property | Value |
|---|---|
| Height | 40 visual (`size.chip`), 56 target |
| Radius | `radius.xs` 8 |
| Padding | 12 horizontal |
| Label | `type.label` 15/20, tabular amount |
| Icon | none |
| Width | hug; never wider than content width − 0 (wraps label to 2 lines at large text; chip grows) |

| State | Fill | Label | Transform |
|---|---|---|---|
| Default | `bg.key` | `fg.primary` | – (HC: + 1 pt `border.control`) |
| Pressed | `bg.keyPressed` | `fg.primary` | scale 0.97 |
| Focused | default | default | focus ring |
| Disabled | not used (chip is removed instead) | – | – |

**Behaviour.** Appears in the AmountDisplay message slot only in the over-balance state; tapping sets the amount to the exact balance, clears the over-balance state, enables Redeem (or HoldButton if balance ≥ € 100) and removes the chip. The target never overlaps keypad keys (the message slot keeps ≥ 8 pt clearance from the keypad; target extension is clipped there).

**Haptics/sound.** `haptic.select`. No sound.

**Motion.** Enter: fade + 4-pt rise, `fast`; exit: fade `fast`. Amount roll per 2.2.

**Accessibility.** Role button; label "Use balance, 32 euro 50"; after activation the AmountDisplay announces the new value.

**Content.** Always the exact balance in the label; never "Max" or "All".

**Used in.** S07.

---

### 2.4 TextField

**Purpose.** E-mail and password entry on sign-in (S02) and "Use password" re-authentication (S04 fallback).

**Anatomy**
```
 ① E-mail                                  ① label (type.label, fg.secondary)
 ┌──────────────────────────────────────┐   gap 8
 │ ② maria@zumhirschen.at          ④ 👁 │   ② input (type.body.l)   ④ trailing IconButton (password)
 └──────────────────────────────────────┘   ③ container 56 pt
 ⑤ ⓘ E-mail or password is incorrect.      ⑤ helper / error (type.body.m), gap 8
```

**Measurements.** Container 56 high, `radius.s` 12, padding 16 horizontal (right padding 0 when a trailing IconButton is present — the 56 target sits inside the field's right end). Label above (never floating inside). Field stack gap: 16 between fields.

**Tokens per state**

| State | Container fill | Border | Input text | Label | Helper |
|---|---|---|---|---|---|
| Default | `bg.surface` | 1 pt `color.border.control` ➕ (3.42 / 3.80 : 1) | `fg.primary`; placeholder `fg.tertiary` | `fg.secondary` | `fg.secondary` |
| Focused | `bg.surface` | 2 pt `color.focus.ring` (inner stroke — no layout shift) | `fg.primary`, caret `fg.primary` | `fg.primary` | – |
| Filled | `bg.surface` | 1 pt `border.control` | `fg.primary` | `fg.secondary` | – |
| Error | `bg.surface` | 2 pt `color.danger` | `fg.primary` | `fg.secondary` | `circle-alert` icon.16 + text in `color.danger` |
| Disabled (while signing in) | `bg.key` | none | `fg.tertiary` (exempt) | `fg.tertiary` | – |
| Loading | = Disabled; the Sign-in PrimaryButton shows the spinner | | | | |

**Behaviour**
- E-mail: e-mail keyboard, no autocorrect, no auto-capitalisation, trims whitespace, autofill "username"; Return key "Next".
- Password: secure entry, autofill "password" (password managers supported), visibility toggle IconButton (`eye`/`eye-off`), Return key "Sign in" (= PrimaryButton).
- Validation **on submit only** (not while typing); errors clear as soon as the field is edited.
- Paste allowed. Max length: 254 (e-mail), 128 (password).

**Haptics/sound.** `haptic.error` when sign-in fails (screen-level). None per keystroke.

**Motion.** Border/colour changes `fast` cross-fade; no floating-label animation (label is static above).

**Accessibility.** Role text field; label = visible label; error text linked as description and announced (assertive) on submit failure; the password toggle announces "Show password, off/on". Target: the whole 56-pt container.

**Content.** Labels: "E-mail", "Password" (DE "E-Mail", "Passwort"; BHS "E-pošta", "Lozinka") — keys in 12. No placeholders that repeat the label.

**Platform differences.** iOS: keyboard appearance follows theme; "Password AutoFill" bar. Android: autofill framework hints; IME action labels. Neither uses Material filled/outlined field styles or Cupertino rounded fields.

**Used in.** S02, S04 (password fallback), S15 session expired sheet (sign in again, password only).

---

### 2.5 CardNumberField

**Purpose.** Manual entry of the 16-digit card number (S11), in four groups of four, via the Keypad (card-number variant).

**Anatomy**
```
 ① Card number
 ┌──────────────────────────────────────────┐
 │  5285  1058  70·· ····                   │   ② digit cells (Geist Mono 24, type.cardNumber)
 └──────────────────────────────────────────┘   ③ empty cell "·" (fg.tertiary)
 ④ helper / error                                ⑤ caret: 2 × 24 pt bar after the last digit
```

**Measurements**

| Part | Value |
|---|---|
| Container | 64 high (`size.cardNumberField`), `radius.s` 12, padding 16 horizontal, `bg.surface` |
| Digits | `type.cardNumber` Geist Mono 24/32, weight 500, tracking +0.48 pt |
| Group gap | 12 pt (not a space character) — total ≈ 266 pt, fits 335-pt content width |
| Empty cell | "·" (U+00B7) in `fg.tertiary`, same advance as a digit |
| Caret ⑤ | 2 × 24 pt, `fg.primary`, blink 1 s on/off (Reduce Motion: steady) |
| Label ① | `type.label`, `fg.secondary`, gap 8 |

**States**

| State | Border | Content | Notes |
|---|---|---|---|
| Empty | 1 pt `border.control` | 16 "·" cells, caret before the first | "Find card" disabled |
| Partial | 2 pt `focus.ring` (the field is always the focus target on S11) | typed digits `fg.primary`, rest "·" | – |
| Complete (16) | 2 pt `focus.ring` | 16 digits | "Find card" enabled (lookup rules in 03a) |
| Limit reached | – | nudge 3 pt, `haptic.warning` | 17th digit rejected |
| Loading | 1 pt `border.control` | digits `fg.secondary` | spinner in the PrimaryButton |
| Error (not found, etc.) | 2 pt `color.danger` | digits stay | error text `color.danger`, `circle-alert`; next keypress clears the error |
| Pasted | – | 16 digits from clipboard (spaces/dashes stripped); anything else rejected with error text | via long-press → system Paste |

**Haptics/sound.** Keypad hooks; `haptic.error` on not-found (screen-level).

**Motion.** Digits appear with a 90-ms fade (no slide — positions are fixed). Error nudge per 06.

**Accessibility.** Role text field (read-only for system keyboard), label "Card number", value spoken in groups: "5 2 8 5, 1 0 5 8, 7 0" ; hint "Use the keypad below". Each accepted digit is echoed (polite).

**Content.** Only digits. No masking during entry (the waiter types what they see).

**Platform differences.** None; the system keyboard is suppressed on both platforms.

**Used in.** S11.

---

## 3. Display

### 3.1 BalanceCard

**Purpose.** The hero of the app: a digital twin of the guest's physical gift card, in the restaurant's colour, showing what the waiter must tell the guest — balance and status.

**Anatomy — regular (ID-1)**
```
┌─────────────────────────────────────────────┐
│ ① GIFT CARD                           ② )))  │  ① overline (type.overline)  ② NFC glyph 32 pt
│ ③ Zum Hirschen                              │  ③ restaurant name (type.title.m, 1 line)
│                                             │
│                                             │
│ ④ € 32,50                                   │  ④ balance (type.balance; € at 24 pt)
│ ⑤ •••• 6488 · Valid until 26.09.2029        │  ⑤ meta (type.caption)
│ ⑥ [⊘ Blocked]                               │  ⑥ StatusBadge, bottom-left (only when not active)
└─────────────────────────────────────────────┘
  ⑦ fill: brand_color with sheen   ⑧ shadow elev.card-brand (light) / 1-px outline (dark)
```

**Variant `BalanceCard / compact`** (the "strip"; binding height **88 pt**, per [03b §2.4](03b-screens-charge-redeem-success-problems.md))

*When used.* Whenever the ID-1 presentation would be shorter than **136 pt** (the minimum for overline + name + balance + caption + padding): compact-height phones (< 700 pt, e.g. iPhone SE 375 × 667), font scale ≥ 130 % on regular phones, and any window whose available height is reduced (split screen, keyboard-up / system overlays). Chosen when S07 opens; never changes while typing ([08 §3.2](08-responsive-behaviour.md)).

*Anatomy*
```
┌─────────────────────────────────────────────┐  88 pt, full content width, radius.l (20)
│ ③ Zum Hirschen                        ② )))  │  row 1: name (type.caption, 1 line) · NFC glyph 20 pt
│ ④ € 32,50                           ⑥ [⊘]   │  row 2: balance (type.balance) · StatusBadge (not active only)
└─────────────────────────────────────────────┘
```

*Tokens*

| Property | Value |
|---|---|
| Height | **88 pt** = padding 12 + name 18 + gap 2 + balance 44 + padding 12 (`size.balanceCard.compact`) |
| Width | full content width (screen − 2 × margin; 335 on a 375-pt phone) — ID-1 ratio released |
| Radius | `radius.l` 20 (continuous on iOS) |
| Padding | `space.3` 12 all sides |
| ③ Name | `type.caption` 13/18, 1 line, end-ellipsis, primary card text colour |
| ④ Balance | `type.balance` 40/44 with `type.currency.balance` 24 — never smaller than 40 |
| ② NFC glyph | 20 × 20, trailing, row 1 |
| ⑥ StatusBadge | trailing, row 2, only when not active |
| Omitted visually | overline ①, meta ⑤ (masked number, validity) — both stay in the accessibility label; the full card number is in the S07 TopRow |
| Fill, sheen, text colour, shadow, desaturated states | identical to the regular variant |

**Measurements**

| Property | Regular | `BalanceCard / compact` (88 pt) |
|---|---|---|
| Width | content width (screen − 2 × margin) | same |
| Height | width ÷ 1.586, **max 220** on phones (e.g. 335 → 211; 353 → 220 clamped) | **88** |
| Radius | `radius.xl` 28 — continuous on iOS, circular on Android | `radius.l` 20 |
| Padding | 24 all sides | 12 all sides |
| ① Overline | `type.overline` 11/14, top-left | omitted |
| ② NFC glyph | 32 × 32 box, top-right, top aligned with overline cap height; three arcs, stroke 2 pt | 20 × 20, row 1 trailing |
| ③ Name | `type.title.m` 22/28, 4 pt below overline, 1 line, end-ellipsis, width = card − padding − 40 (glyph clearance) | `type.caption` 13/18, 1 line |
| ④ Balance | `type.balance` 40/44 with `type.currency.balance` 24 | same size (never smaller than 40) |
| ⑤ Meta | `type.caption` 13/18, 4 pt below balance: "•••• 6488 · Valid until 26.09.2029" (expired: "Expired 26.09.2025"; no expiry: masked number only) | omitted visually (in the accessibility label) |
| ⑥ Badge | StatusBadge 24 pt, 8 pt below meta, bottom-left | trailing in row 2 |
| Vertical distribution | top block (overline + name) anchored top; bottom block (balance, meta, badge) anchored bottom; free space between | two rows, 2 pt apart, block centred |

**Colour and text** (algorithm and worked examples: [04-design-system.md](04-design-system.md) §8.6)

| Part | Token / rule |
|---|---|
| Fill ⑦ | `brand_color` (fallback `color.brand.ink`), linear sheen top-left → bottom-right: +6 % toward white → +6 % toward black |
| Primary text (③ ④) | auto: #FFFFFF or #0A0A0C, ≥ 4.5 : 1 against the worst sheen stop; else fallback to ink card |
| Secondary text (① ⑤) | same colour at `opacity.cardSecondary` 0.76 if still ≥ 4.5 : 1, else 100 % |
| NFC glyph ② | `color.accent.saffron` if ≥ 3 : 1 against both stops, else primary text colour |
| Shadow ⑧ light | `elev.card-brand` (0 16 40, brand @ 28 %); desaturated states: `elev.2` |
| Dark theme | no shadow; 1-px `color.card.borderDark` #26262B |
| Very light brand colours | + 1-px `border.subtle` in light theme (04 §8.6 step 9) |

**States / variants**

| Variant | Card treatment | Badge | Balance shown | Notes |
|---|---|---|---|---|
| Loading | Skeleton card (§3.6): brand colour fill, placeholder bars in text colour @ 16 %, sweep @ 8 % | – | – | after 150 ms; "Still looking…" below after 3 s (03b) |
| Active | full colour, brand glow | none | yes | – |
| Active, partial disabled | identical to Active | none | yes | the constraint is shown by AmountDisplay "Full balance only" |
| Zero balance (redeemed / balance 0) | full colour | `redeemed` (warning) | "€ 0,00" | StatusBanner `card.empty` below |
| Inactive | full colour | `inactive` (warning) | yes | StatusBanner `card.inactive` |
| Blocked | **40 % desaturated**, `elev.2` | `blocked` (danger) | yes | StatusBanner `card.blocked` with `blocked_reason` |
| Expired | **40 % desaturated**, `elev.2` | `expired` (warning) | yes | meta "Expired {date}" |
| Replaced | **40 % desaturated**, `elev.2` | `replaced` (neutral) | yes | StatusBanner `card.replaced` |
| Swapping (Android new card, amount 0) | old card cross-fades to new over **300 ms** (`time.cardSwap`) | per new state | – | `haptic.cardDetected` + `sound.cardDetected` |
| Arriving | spring in (`motion.spring.card`), see 06 | – | – | – |

**Interaction.** Not interactive: no pressed state, no tap, no long-press, no flip. (A tappable-looking card that does nothing is avoided by the absence of any pressed feedback and no chevron.)

**Haptics/sound.** None of its own; arrival is accompanied by the scan feedback that preceded it.

**Motion.** Arrival spring, swap cross-fade, skeleton → content cross-fade `fast` with identical geometry. Reduce Motion: cross-fades only. [06-motion-guidelines.md](06-motion-guidelines.md).

**Accessibility**
- One element, role: static group (iOS "summary element"; Android heading-less group), not a button.
- Label pattern: "Gift card, {restaurant name}. Balance {spoken amount}. Card ending {6 4 8 8}. {Valid until 26 September 2029 | Expired 26 September 2025}. {Status: Blocked.}" — status part only when not active.
- On arrival on S07 the screen announces the card (assertive), see 07.
- Text inside scales to 130 % max; the full label is always available to assistive tech.

**Content.** Overline in the app language: "GIFT CARD" / "GUTSCHEIN" / "POKLON KARTICA" (keys in 12; DE uses "GUTSCHEIN" as on the printed card). Restaurant name as configured (not uppercase-transformed). Never customer names (none exist in the API).

**Do / Don't**

| Do | Don't |
|---|---|
| Show the balance even for blocked/expired cards (the waiter tells the guest). | Hide the card behind an error screen when card data exists. |
| Keep the brand colour only here. | Tint buttons or TopBar with the brand colour. |
| Recompute text colour after desaturation. | Hard-code white text. |

**Platform differences.** Corner geometry only (continuous vs circular). Shadow rendering: Android uses a coloured ambient shadow equivalent (spot shadow colour = brand @ 28 %) — must visually match the iOS reference within tolerance.

**Used in.** S07, S08 (and its skeleton during S06 → S07).

---

### 3.2 StatusBadge

**Purpose.** Compact card status label, always icon + text (never colour alone).

**Anatomy**
```
 ╭──────────────╮
 │ ⊘  Blocked   │   icon.16 (stroke 1.5) · gap 4 · type.caption
 ╰──────────────╯   height 24 · padding 8 · radius.xs 8
```

**Statuses**

| Status (API) | Label EN (keys in 12) | Icon | Text/icon | Fill | Contrast L / D |
|---|---|---|---|---|---|
| `active` | Active | `circle-check` | `color.success` | `color.success.bg` | 5.21 / 7.69 |
| `inactive` | Not activated | `circle-dashed` | `color.warning` | `color.warning.bg` | 4.84 / 9.78 |
| `redeemed` | No balance | `wallet` | `color.warning` | `color.warning.bg` | 4.84 / 9.78 |
| `blocked` | Blocked | `ban` | `color.danger` | `color.danger.bg` | 5.91 / 6.50 |
| `expired` | Expired | `calendar-x` | `color.warning` | `color.warning.bg` | 4.84 / 9.78 |
| `replaced` | Replaced | `replace` | `color.fg.secondary` | `color.bg.key` | 6.85 / 6.48 |

Uses theme tokens even on the brand-coloured BalanceCard (the badge is a label stuck on the card; its own fill guarantees contrast regardless of the brand colour). On a card whose text colour is dark, the badge adds a 1-px outline in that text colour at 16 % for edge definition.

**States.** Static; no interaction. HC: text weight 600, icon stroke 1.75.

**Accessibility.** Not separately focusable on the BalanceCard (included in the card label as "Status: Blocked"). Elsewhere: static text, label = visible text.

**Content.** One or two words; no punctuation.

**Do / Don't.** Do show only for non-active cards on the BalanceCard (brief: "when not active"). Don't use badges for counts or tags.

**Used in.** BalanceCard (S07, S08). The `active` badge exists for completeness and future list views; v1 does not display it on the card.

---

### 3.3 StatusBanner

**Purpose.** An in-content message about the current card or operation, placed on S07 below the BalanceCard: what happened + what to do. Four tones: info, warning, danger, success.

**Anatomy**
```
┌──────────────────────────────────────────────┐
│ ①[⊘]  ② Card blocked                         │  ① icon.24 in tone colour (top-aligned to title)
│        ③ Reported lost by the restaurant.    │  ② title: type.body.l 600, fg.primary
│        ④ [ Scan another card ]               │  ③ body: type.body.m, fg.secondary (max 2 lines)
└──────────────────────────────────────────────┘  ④ optional TertiaryButton, aligned to text column
```

| Property | Value |
|---|---|
| Container | `radius.m` 16, padding 16, full content width |
| Icon ↔ text | 12 |
| Title ↔ body | 2 |
| Body ↔ action | 4 (action's 56-pt target overlaps the padding; pressed fill 44) |
| Min height | 56 |

**Tones**

| Tone | Fill | Icon | Icon colour | Dark extra |
|---|---|---|---|---|
| info | `color.info.bg` | `info` | `color.info` | 1-px outline `color.info` @ 24 % |
| warning | `color.warning.bg` | `triangle-alert` | `color.warning` | outline `color.warning` @ 24 % |
| danger | `color.danger.bg` | `circle-alert` (card blocked: `ban`) | `color.danger` | outline `color.danger` @ 24 % |
| success | `color.success.bg` | `circle-check` | `color.success` | outline `color.success` @ 24 % |

Title/body contrast on tone fills: `fg.primary` ≥ 13.45 : 1; `fg.secondary` light 7.06–7.45 : 1, dark 5.77 (success.bg) – 7.02 : 1. `fg.tertiary` is never used inside banners (4.41 : 1 on danger.bg).

**Special state — progress.** For "Redemption uncertain" (`uncertain.title` / `uncertain.body`) the icon is replaced by a Spinner 20 in `color.warning`; the banner remains until resolved (then the flow proceeds to S09 or a definitive error).

**Usage mapping (S07)**

| Situation | Tone | Title key |
|---|---|---|
| Blocked | danger | `card.blocked` (+ `blocked_reason` as body when present, max 3 lines) |
| Expired | warning | `card.expired` |
| Inactive | warning | `card.inactive` |
| Replaced | warning | `card.replaced` |
| Zero balance | warning | `card.empty` |
| Velocity limit (429) | warning | copy in 12 |
| Redemption uncertain | warning + spinner | `uncertain.title` |
| Lookup slow ("Still looking…") | – (plain caption, not a banner) | – |
| success | reserved — no v1 screen uses the success tone (success is expressed by S09) | – |

**Behaviour.** Appears with the card (no separate entrance when arriving together); state changes cross-fade `fast`. Not dismissible. HC: body weight 600 (brief).

**Haptics/sound.** On appearance: warning/danger card states → `haptic.warning` + `sound.warning` (04 §19.1). Info: none.

**Accessibility.** Role: status/alert region. danger/warning announced assertively once on appearance ("Card blocked. Reported lost by the restaurant."); info politely. Icon decorative.

**Content.** Title = what happened (≤ 32 characters DE); body = what to do or why (≤ 2 lines). No exclamation marks, no blame.

**Do / Don't.** Do keep the BalanceCard visible above it. Don't stack two StatusBanners — show the most severe (danger > warning > info).

**Used in.** S07, S08.

---

### 3.4 NfcScanAnimation

**Purpose.** The Ready screen's signature: three concentric saffron arcs with a breathing glow that say "hold the card here" and show reader state.

**Geometry**
```
            ╭───────────╮            ③ outer arc  r = 76
         ╭──┴───────────┴──╮         ② middle arc r = 56
       ╭─┴──╭─────────╮────┴─╮       ① inner arc  r = 36
            │         │               each arc: 100° sweep, centred on 12 o'clock
                 ●                    ④ emitter dot 8 pt at centre C
       ░░░░░░░░░░░░░░░░░░░░░░         ⑤ glow: radial, centred on C, radius 96
```

| Property | Value |
|---|---|
| Canvas | 176 × 120 pt; centre C at (88, 100); glow may overflow the canvas (not clipped, non-interactive) |
| Arcs | radii **36 / 56 / 76 pt**, stroke **3 pt**, round caps, sweep 100° (−50° … +50° around 12 o'clock) |
| Emitter dot ④ | 8 pt circle, `color.accent.saffron` |
| Glow ⑤ | radial gradient, saffron at the given opacity at C → 0 at r = 96 |
| Colour | `color.accent.saffron` (#E8A33D / #F0B454); HC light: `color.nfc.arc.hc` #B45309 |

**States**

| State | Arcs (inner / middle / outer) | Glow | Dot | Duration |
|---|---|---|---|---|
| Idle (Ready, not yet listening; iPhone decorative above "Scan card") | static 0.80 / 0.56 / 0.32, no scale | iPhone: breathes 12 % ↔ 24 % ([06 M04](06-motion-guidelines.md) iPhone variant) | saffron | 2.4 s period (glow only) |
| Listening (Android reader mode active) | breathing per [06 M04](06-motion-guidelines.md): group scale 1.00 ↔ 1.04; opacity 1.00 / 0.72 → 1.00 / 0.44 → 0.80; outer lags inner by 120 ms | 24 % ↔ 48 % | saffron | **2.4 s period** (1.2 s in + 1.2 s out), sine in-out — arcs and glow share one period |
| Reading (tag detected, read in progress) | all 1.0, group scale 1.06 ([06 M05](06-motion-guidelines.md)) | steady 64 % | saffron | 90 ms in; held until the read completes (≈ 300 ms) |
| Success (read OK) | rings **converge into the card**: scale 1.06 → 0.60, opacity 1 → 0 ([06 M06](06-motion-guidelines.md)); the converge centre is the BalanceCard's origin | 0.64 → 0 (160 ms) | saffron | 240 ms `base`, accelerate; BalanceCard enters (M08) |
| Error (read failed / tag lost) | arcs return to rest values ([06 M05](06-motion-guidelines.md)); **no shake or nudge**; the text line carries the error | back to rest | saffron | 240 ms decelerate; breathing resumes after 400 ms |
| Disabled (NFC off, S16) | static 0.80 / 0.56 / 0.32 in `fg.tertiary` | off | `fg.tertiary`, hollow (1.5-pt ring) | – |

Colour-only states are always accompanied by text on the screen (instruction, error line); the animation is never the sole carrier of meaning.

**Reduce Motion.** Listening = static rings at rest values (scale 1.0, arcs 1.0 / 0.72 / 0.44, glow 32 % — [06](06-motion-guidelines.md) §3). Success = arcs fade out 160 ms (no scale); error = 160 ms opacity change back to rest.

**Haptics/sound.** Reading (after a successful read, Android): `haptic.cardDetected` + `sound.cardDetected` — app-generated, platform NFC sound suppressed. Read failure: none for the 1st–2nd failure, `haptic.warning` (no sound) after 3 failures within 5 s ([11](11-sound-and-haptics.md) E12/E13). Listening: none.

**Motion.** Exact keyframes, stagger and hand-off to the BalanceCard: [06-motion-guidelines.md](06-motion-guidelines.md).

**Accessibility.** Decorative: hidden from assistive technology. The adjacent instruction (`ready.android.title`) carries the meaning; state changes are announced by the screen ("Card detected", error title).

**Performance.** Runs continuously on S05 during service: must render at the display's refresh rate with negligible CPU/GPU (vector arcs, no blur filters; glow is a pre-computed radial gradient). Paused when the app is not visible.

**Do / Don't.** Do keep it the only saffron element on S05. Don't turn it into a spinner, don't add a phone or card illustration inside it, don't use Lucide `wifi` as a substitute.

**Platform differences.** Android: Listening is the resting state on S05. iPhone: Idle on S05 (reading happens in the system sheet); Success/Error states are not shown (the system sheet shows them).

**Used in.** S05, S06 (Android inline), S16 NFC off (disabled). Not on S17 — the intro uses the static line illustration `ill_intro_tap` ([10 §4.4](10-assets-icons-illustrations.md)).

---

### 3.5 ProgressRing

**Purpose.** Determinate circular progress for holds and countdowns.

**Anatomy**
```
    ╭───╮      ① track (full circle)
   │ 12 │      ② progress arc, from 12 o'clock clockwise
    ╰───╯      ③ optional centre value (countdown seconds)
```

| Size | Diameter | Stroke | Centre text | Track | Progress |
|---|---|---|---|---|---|
| Hold (in HoldButton) | 28 | 3 | none | `color.hold.track` | `color.hold.progress` |
| Countdown | 48 | 3 | `type.label` 15/20, tabular, `fg.primary` | `color.border.subtle` | `color.fg.primary` |

**Behaviour.** Hold: fills 0 → 100 % (see 1.5). Countdown: starts full and **empties** clockwise as time runs out (remaining = visible arc); the centre shows whole seconds remaining (ceil). Used with `retry_after` from 429 `SCAN_THROTTLED` and 423 `ACCOUNT_LOCKED`. At 0 the ring disappears (fade `fast`) and the associated action re-enables.

**Motion.** Linear in time, updated every frame; Reduce Motion: unchanged (progress indicator).

**Accessibility.** Role progress indicator; value "12 seconds remaining"; announced when it starts and when it reaches 0 ("You can scan again"), not every second. Hold ring: hidden (the button speaks for it).

**Used in.** HoldButton (S07/S08) · S10 scan throttled · S15 account locked.

---

### 3.6 Skeleton

**Purpose.** Placeholder with the exact geometry of content being loaded, so nothing jumps when it arrives.

**Variants**

| Variant | Shape | Base | Sweep |
|---|---|---|---|
| Card | Full BalanceCard shape in the restaurant brand colour (known from the session), bars for name (160 × 16), balance (140 × 28), meta (180 × 10) at their final positions (bar height = the final text's cap height, rounded to an even number) | card text colour @ 16 % | card text colour @ 8 % |
| Line | Text line: width as specified by the screen, height = final cap height rounded to even (10 for `type.body.m`, 12 for `type.body.l`), fully rounded | `color.skeleton.base` | `color.skeleton.highlight` |
| Block | Any rectangle, final radius | `color.skeleton.base` | `color.skeleton.highlight` |

**Sweep.** One synchronised band per screen: width 40 % of the container, angled 20°, travels leading → trailing in **1.2 s linear**, repeats without pause; the band is clipped by each skeleton shape. Highlight is **8 %** (04 §17.3).

**Timing.** Appears after **150 ms**; once visible stays ≥ 240 ms; content replaces it with a `fast` cross-fade and identical geometry.

**Reduce Motion.** No sweep; static base.

**Accessibility.** Hidden; the container announces "Loading card".

**Do / Don't.** Do mirror the final layout exactly. Don't show a skeleton for the AmountDisplay or Keypad (they are local and render immediately); don't use a skeleton for actions in flight (use Spinner).

**Used in.** S07 during lookup (card skeleton; keypad visible but disabled until the card is known — 03b).

---

### 3.7 Spinner

**Purpose.** Indeterminate progress inside a control.

| Property | Inline (brief) | Large ➕ |
|---|---|---|
| Size | 20 pt | 32 pt |
| Stroke | 2 pt | 3 pt |
| Geometry | 270° arc on a full track; track = current colour @ 16 % | same |
| Rotation | 1 turn / 800 ms, linear, constant arc length | same |
| Colour | inherits container foreground (`fg.onAccent` in PrimaryButton, `hold.progress` in HoldButton, `color.warning` in the uncertain StatusBanner, `fg.primary` elsewhere) | `fg.secondary` |

**Timing.** Shown 150 ms after the action starts; minimum 240 ms once shown. **Reduce Motion:** keeps rotating.

**Accessibility.** Hidden; the owner announces "Loading"/"Redeeming" (busy state).

**Used in.** PrimaryButton/HoldButton/DangerButton loading (S02, S04, S08, S11, S14), StatusBanner uncertain (S08), S01 (> 1 s, large), S15 (large, while re-checking status).

---

### 3.8 SuccessMark

**Purpose.** The drawn check that marks money successfully moved (S09).

**Anatomy**
```
      ╭─────────╮
    ╱      ╱     ╲       ① circle 96 pt, fill color.success
   │  ╲   ╱       │      ② check path, stroke 6 pt, round caps/joins,
    ╲   ╲╱       ╱          colour color.fg.onSuccess
      ╰─────────╯
```

| Property | Value |
|---|---|
| Circle | 96 pt, `color.success` (#047857 / #34D399) |
| Check | three points on the 96-pt box: (28, 50) → (42, 64) → (68, 36); stroke 6; `color.fg.onSuccess` (#FFFFFF 5.48 : 1 / #0A0A0C 10.29 : 1) |

**Sequence** (06 has the curves)

| t | Event |
|---|---|
| 0 ms | halo scales 0.6 → 1.0 with `motion.spring.card`; circle stroke draws 0 → 100 % over **240 ms** (from 12 o'clock, clockwise, `ease.standard`), fill fades in 90 ms at 240; **`haptic.success` + `sound.success` fire at this moment** ([11](11-sound-and-haptics.md) T3) |
| 240 ms | check stroke draws 0 → 100 % over **200 ms** (`ease.decelerate`), short leg then long leg |
| 440 ms | complete; static |

Reduce Motion: circle and full check fade in together (160 ms); haptic and sound at t = 0.

**Accessibility.** Hidden (the S09 announcement carries the meaning).

**Do / Don't.** Do show only after server confirmation. Don't loop, don't add confetti or particles.

**Used in.** S09.

---

### 3.9 CountdownHairline

**Purpose.** A quiet visual of the 4-s auto-return from S09 to Ready.

| Property | Value |
|---|---|
| Position | top of S09, directly below the top safe area, full screen width (edge to edge, ignores margins) |
| Thickness | **2 pt** |
| Colour | `color.fg.tertiary`; no track |
| Behaviour | starts at full width when S09 appears, shrinks to 0 over **4 s linear**, anchored at the leading edge (shrinks toward the leading side) |
| At 0 | S09 transitions to S05 |
| Pause | while a `z.system` layer is visible or the app is in background (then S09 returns to S05 on resume) |
| Cancel | any tap on S09, a new Android card tap, back gesture → immediate exit |
| Screen reader active | duration extended per [07-accessibility-guidelines.md](07-accessibility-guidelines.md); hairline runs over the extended duration |
| Reduce Motion | unchanged (progress indicator) |

**Accessibility.** Hidden; not information-bearing (auto-return is announced via the screen hint on first use only, see 07).

**Used in.** S09.

---

### 3.10 TransactionRow

**Purpose.** One redemption in the shift history (Recent, S13).

**Anatomy**
```
 ┌───────────────────────────────────────────────────────┐
 │ ① 14:32   ② •••• 6488                    ④ € 24,90  ⑤›│
 │           ③ Remaining € 7,60                           │
 └───────────────────────────────────────────────────────┘
   ─────────── ⑥ hairline divider (inset to column ②) ────
```

| Part | Token | Notes |
|---|---|---|
| Row | height 64 (min; grows with text), padding horizontal = screen margin, vertical 10 | full sheet width |
| ① Time | `type.body.m`, tabular, `fg.secondary`, column 48 pt (64 pt for 12-h locales "2:32 PM") | locale time format, restaurant time zone |
| ② Card | `type.body.l`, `fg.primary`, "•••• 6488" | – |
| ③ Remaining | `type.caption`, `fg.tertiary`, "Remaining € 7,60" (copy in 12) | – |
| ④ Amount | `type.body.l` 600, tabular, `fg.primary`, right-aligned | redeemed amount, no sign |
| ⑤ Chevron | `chevron-right` icon.16, `fg.tertiary`, gap 8 | – |
| ⑥ Divider | `border.width.hairline`, `color.border.subtle`, starts at column ② | not after the last row |

| State | Visual |
|---|---|
| Default | – |
| Pressed | `bg.key` fill, inset 8 pt from the sheet edges, `radius.m` 16; no scale |
| Focused | focus ring around the inset shape |

**Behaviour.** Tap → Recent detail sheet (stacked). Newest first. Read-only; no swipe actions, no long-press menu.

**Accessibility.** Role button; label "14:32, card ending 6 4 8 8, redeemed 24 euro 90, remaining 7 euro 60"; hint "Opens details". Row is one focus stop.

**Content.** Never customer data (none exists). Truncation: only column ② may truncate (it never needs to in practice).

**Used in.** S13.

---

### 3.11 HistoryCard

**Purpose.** Summary header of Recent: "12 redemptions · € 486,40 today" (brief).

**Anatomy**
```
 ╭──────────────────────────────────────────╮
 │ ① TODAY · SINCE 04:00                    │  ① type.overline, fg.secondary
 │ ② € 486,40                               │  ② type.title.l, tabular, fg.primary
 │ ③ 12 redemptions                         │  ③ type.body.m, fg.secondary
 ╰──────────────────────────────────────────╯
```

| Property | Value |
|---|---|
| Container | `radius.xl` 28, padding 20; light: `bg.canvas` fill on the white sheet + `elev.1`; dark: `bg.raised` + 1-px `border.subtle` |
| Gaps | ①→② 4, ②→③ 2 |
| Width | content width |

**States.** Normal · 200-row cap reached: ③ adds " · showing latest 200" (copy in 12) · Empty: HistoryCard hidden, EmptyState shown.

**Behaviour.** Static; totals computed from local Recent data (brief §1: business day from 04:00 local).

**Accessibility.** One static element; label exactly as the brief string: "12 redemptions, 486 euro 40 today".

**Used in.** S13.

---

## 4. Feedback and containers

### 4.1 Snackbar

**Purpose.** Brief, non-blocking feedback or a single safe-to-ignore offer.

**Anatomy**
```
 ┌──────────────────────────────────────────────┐
 │ ① Different card detected          ② Switch  │   ① message: type.body.m
 └──────────────────────────────────────────────┘   ② action: type.label, max one
```

| Property | Value |
|---|---|
| Width | content width, max 560 |
| Height | min 56; grows for 2 lines (text never truncated) |
| Radius | `radius.s` 12 |
| Padding | 16 horizontal, 12 vertical; message ↔ action gap 16 |
| Fill / text | `color.inverse.bg` / `color.inverse.fg` (#18181B / #FFFFFF light; #1C1C21 / #F4F4F5 dark) |
| Action | `color.inverse.action` saffron (8.22 / 9.18 : 1), 56-pt target overlapping padding, pressed: 8 % white overlay pill |
| Elevation | light `elev.3`; dark 1-px `border.subtle` |
| Optional leading icon | `icon.20`, `inverse.fg` |
| Position | **above the thumb-zone CTA**: bottom edge 12 pt above the top of the CTA block (or 16 pt above the bottom safe area when no CTA). Never covers the keypad's bottom row *and* the CTA at once. |

**Behaviour**
- Auto-dismiss after **4 s** (`time.snackbar`); timer pauses while touched and while a `z.system` layer is visible.
- **One action max.** Activating it dismisses the snackbar.
- Swipe down to dismiss. A new snackbar replaces the current one (cross-fade).
- Opening a Dialog dismisses it; sheets appear beneath it (`z.snackbar` 45).
- **Timeout = safe default.** Only offers whose ignored outcome is safe may use a snackbar. "Different card detected — Switch?": ignoring keeps the current card.
- With a screen reader or Switch Control active, decision snackbars are replaced by the Dialog fallback (§4.3); informational snackbars stay 10 s.

**Haptics/sound.** None of its own (the triggering event provides feedback).

**Motion.** Enter: rise 16 pt + fade with `motion.spring.soft`; exit: fade + 8-pt drop, `fast`, `ease.accelerate`. Reduce Motion: fades.

**Accessibility.** Role status; message + action announced politely ("Different card detected. Switch, button."); action focusable; the snackbar does not steal focus.

**Content.** Message ≤ 40 characters DE; action one verb ("Switch" / "Wechseln" / "Zamijeni"). No "OK"/"Dismiss" actions.

**Do / Don't.** Don't use for errors that need action (use StatusBanner/ProblemScreen) or for success of a redemption (S09).

**Platform differences.** Custom on both (not Material Snackbar, not an Android Toast).

**Used in.** S07 (switch card, Android).

---

### 4.2 BottomSheet

**Purpose.** A modal place with content — Recent, Menu, session expired — that rises over the current screen.

**Anatomy**
```
 ╭────────────────── radius.sheet 32 ──────────────────╮
 │                      ▬▬▬▬ ①                          │  ① grabber 36 × 5, 8 pt from top
 │ ② ✕          ③ Recent                                │  ② close IconButton (top-left)  ③ title
 ├──────────────────────────────────────────────────────┤  ④ hairline when content is scrolled
 │ ⑤ content (scrollable)                               │
 │                                                      │
 ╰──────────────────────────────────────────────────────╯
   ⑥ scrim behind (color.scrim)
```

| Property | Value |
|---|---|
| Top corners | `radius.sheet` 32 (continuous on iOS); bottom corners 0 (sheet meets the screen edge) |
| Grabber ① | 36 × 5, `radius.full`, `color.border.strong`, 8 pt from top; drag handle area 24 pt high |
| Header | 56 pt: ✕ IconButton leading (glyph at margin), title `type.title.m` **centred**, trailing slot empty or one IconButton |
| Content padding | screen margin horizontally; bottom = safe area + 16 |
| Fill | `bg.surface`; stacked sheet: light `bg.surface`, dark `bg.raised` |
| Elevation | light `elev.3` cast upward; dark 1-px `border.subtle` top edge |
| Scrim ⑥ | `color.scrim`; stacked sheet adds a second scrim of `rgba(0,0,0,0.32)` over the first sheet |

**Detents**

| Detent | Height | Used by |
|---|---|---|
| Content-fit | content height, capped at Large | S14 Menu, S15 session expired, S13 detail |
| Medium | 50 % of screen height | S13 Recent initial |
| Large | screen height − top safe area − 12 pt | S13 Recent expanded (drag up), Menu when content exceeds |

**Behaviour**
- Dismiss: drag down past 30 % of its height or with downward velocity > 800 pt/s, ✕, scrim tap, Android back (top-most sheet first).
- Rubber-band resistance when dragging above the largest detent.
- Content scrolls inside; scroll-to-top then continues as sheet drag (single gesture).
- Max one stacked level (S13 → detail). Opening a sheet from S07 is not possible (S07 has no Recent/Menu).
- While a sheet is open on S05 (Android), NFC reader mode stays active; a card tap closes the sheet and proceeds to S07 (03a).

**Haptics/sound.** None (no detent haptics).

**Motion.** Present: slide up with `motion.spring.soft`; scrim fade `base`. Dismiss: follows finger, then `fast` `ease.accelerate`. Reduce Motion: fade + 8-pt rise only. [06-motion-guidelines.md](06-motion-guidelines.md).

**Accessibility.** Modal: focus trapped; initial focus on the title; on close, focus returns to the invoking control. Escape gesture (iOS two-finger Z) and TalkBack back close it. Grabber is not focusable (✕ is the accessible close).

**Platform differences.** iOS: continuous corners; the underlying screen does **not** scale down (no iOS card-stack effect — the app keeps its flat identity). Android: predictive back animates the sheet down with the gesture.

**Used in.** S13 Recent (+ detail), S14 Menu, S15 session expired.

---

### 4.3 Dialog

**Purpose.** A modal decision. **Only two uses** (brief): sign-out confirmation, and the switch-card confirmation fallback.

**Anatomy**
```
        ╭──────────────────────────────╮
        │ ① Sign out?                  │  ① title type.title.m
        │ ② Recent will be cleared     │  ② body type.body.m, fg.secondary (max 3 lines)
        │   on this phone.             │
        │ ┌──────────────────────────┐ │
        │ │ ③ Sign out               │ │  ③ action (DangerButton / PrimaryButton, regular)
        │ └──────────────────────────┘ │  gap 12
        │ ┌──────────────────────────┐ │
        │ │ ④ Cancel                 │ │  ④ SecondaryButton (safe choice, nearest the thumb)
        │ └──────────────────────────┘ │
        ╰──────────────────────────────╯
```

| Property | Value |
|---|---|
| Width | content width, max 360; centred vertically slightly above centre (−24 pt) |
| Radius | `radius.xl` 28 |
| Padding | 24 |
| Gaps | title ↔ body 8, body ↔ buttons 24, buttons 12 |
| Fill | light `bg.surface` + `elev.2`; dark `bg.raised` + 1-px `border.subtle` |
| Scrim | `color.scrim` |
| Buttons | regular (56), full dialog width, **stacked vertically**; the changing action on top, the safe action at the bottom |

**The two dialogs**

| Dialog | Title / body (EN examples; keys in 12) | Top button | Bottom button |
|---|---|---|---|
| Sign out (S14) | "Sign out?" / "Recent will be cleared on this phone." | DangerButton "Sign out" | SecondaryButton "Cancel" |
| Switch card fallback (S07, screen reader or Switch Control active) | "Different card detected" / "Switch to card •••• 1234?" | PrimaryButton "Switch" | SecondaryButton "Keep current card" |

**Behaviour.** No swipe dismissal. Scrim tap and Android back = bottom (safe) button. Opening a dialog dismisses any snackbar.

**Haptics/sound.** None on open (the sign-out dialog is user-initiated; the switch-card read already produced `haptic.warning`).

**Motion.** Scale 0.96 → 1 + fade, `base`, `ease.decelerate`; exit fade `fast`. Reduce Motion: fade.

**Accessibility.** Role alert dialog; focus moves to the title; title + body announced; focus trapped; Escape/back = safe action.

**Do / Don't.** Don't add a third dialog in v1. Don't use side-by-side buttons (glove rule, long German labels).

**Used in.** S14, S07.

---

### 4.4 Banner

**Purpose.** A persistent app/network condition shown under the TopBar: offline, maintenance.

**Anatomy**
```
 ┌────────────────────────────────────────────────────┐  full-bleed (edge to edge)
 │ ① [wifi-off]  ② No connection                ③ Details │
 └────────────────────────────────────────────────────┘
   ① icon.20 tone   ② type.body.m 600 fg.primary (+ optional 2nd line body)   ③ optional TertiaryButton
```

| Property | Value |
|---|---|
| Width | full screen width; content inset = screen margin |
| Height | min 48; min 56 when it has an action (full target inside the banner) |
| Padding | 12 vertical |
| Icon ↔ text | 12 |
| Fill | tone `.bg` (info for offline, warning for maintenance) |
| Bottom edge | hairline, tone colour @ 24 % |
| Radius | 0 (it is part of the chrome, not a content card) |

**Content.** Offline: `offline.title` + (on S07) `offline.body` as second line. Maintenance: notice text from `GET /app/config`, max 2 lines; longer text → "Details" opens it in a content-fit sheet.

**Behaviour.** Pushes content down (never overlays). One banner at a time; priority offline > maintenance. No ✕. Disappears when the condition ends.

**Haptics/sound.** None.

**Motion.** Height expand/collapse `base`, `ease.standard`; Reduce Motion: cross-fade 160 ms.

**Accessibility.** Role status; announced politely on appearance; "Connection restored" announced when it disappears (screen-reader only).

**Used in.** S05 (offline variant), S07, S11 (offline), S05/S07 maintenance (S15).

---

### 4.5 EmptyState

**Purpose.** Explains an empty list and what fills it.

**Anatomy**
```
            ① [illustration 96]
            ② No redemptions yet
            ③ Redemptions from this phone
               appear here until 04:00.
            ④ [optional SecondaryButton]
```

| Part | Value |
|---|---|
| ① Illustration | 96 pt (S13 Recent, inside a sheet); single SVG with theme-mapped colour roles — style per [10 §4](10-assets-icons-illustrations.md#4-illustration-style-15) |
| ② Title | `type.title.m`, `fg.primary`, centred; gap 24 below ① |
| ③ Body | `type.body.m`, `fg.secondary`, centred, max 2 lines, 320-pt column; gap 8 |
| ④ Action | optional, SecondaryButton regular (hug); gap 24 |
| Placement | vertically centred in the available area, biased 24 pt upward |

**Accessibility.** Title and body read as one group; illustration hidden.

**Content.** Title states the fact calmly; body explains when content appears. No "Oops".

**Used in.** S13 (no redemptions this business day).

---

### 4.6 ProblemScreen

**Purpose.** Template for full-screen problems where no card data is available (S10), plus full-screen account and permission states (S15, S16).

**Anatomy**
```
┌──────────────────────────────────────┐
│ ① ✕                                  │  ① TopBar task variant (✕ top-left); omitted on S15 states
│                                      │
│             ② [icon 48]              │  ② illustration 120 where [10 §4.4](10-assets-icons-illustrations.md) lists one
│                                      │     — else icon.48 in tone colour, or ProgressRing 48 (countdowns)
│         ③ Card not found             │  ③ type.title.l, fg.primary, centred, max 2 lines
│     ④ Check the card and try again,  │  ④ type.body.l, fg.secondary, centred, max 2 lines
│        or enter the number.          │
│           ⑤ Code 7F3A9C              │  ⑤ optional support code (`common.supportCode`), type.caption, fg.tertiary
│                                      │
│  ┌────────────────────────────────┐  │
│  │ ⑥ Scan again                   │  │  ⑥ PrimaryButton large (exactly one)
│  └────────────────────────────────┘  │
│        ⑦ Enter number instead        │  ⑦ optional TertiaryButton (max one)
└──────────────────────────────────────┘
```

| Property | Value |
|---|---|
| Content block (②–⑤) | 320-pt column, centred horizontally; vertically centred between TopBar and CTA block, biased 32 pt upward |
| Gaps | ② → ③ 24, ③ → ④ 12, ④ → ⑤ 16 |
| CTA block | bottom-anchored; ⑥ → ⑦ 12; bottom padding per 04 §4.4 |
| Background | `bg.canvas` (neutral — the tone lives only in ②) |

**Tone by problem family**

| Family | Icon | Tone | Haptic + sound on appear |
|---|---|---|---|
| Card not found, wrong restaurant | `circle-alert` (foreign: `store`) | danger | `haptic.error` + `sound.error` |
| Server error | `circle-alert` | danger | `haptic.warning` + `sound.warning` ([11](11-sound-and-haptics.md) E26) |
| Verification failed | `shield-alert` | warning (calm — never red, no flash; [03b §5.2](03b-screens-charge-redeem-success-problems.md)) | `haptic.error` + `sound.error` ([11](11-sound-and-haptics.md) E25) |
| Scan throttled, velocity | ProgressRing 48 with seconds | warning | `haptic.warning` + `sound.warning` |
| Network error | `wifi-off` | info | `haptic.warning` + `sound.warning` ([11](11-sound-and-haptics.md) E26) |
| Account/device/restaurant states, update required (S15), permissions (S16) | illustration or `icon.48` | neutral (`fg.secondary`) | none |

**Behaviour.** ✕ and back return to S05. The primary action is the likeliest recovery. The support code ⑤ (last 6 characters of `X-Request-Id`, uppercase, e.g. `7F3A9C`) appears only on the variants listed in [12 §2.5](12-ui-copy-and-error-messages.md#25-support-code) (S10: not found, wrong restaurant, verification failed, server error — not throttled or network); long-press copies the full request id and `common.copied` snackbar confirms.

**Motion.** Enters as a replacement of S07/S06 (06); icon has no animation beyond the screen transition. Reduce Motion: cross-fade.

**Accessibility.** On appearance, focus moves to the title; title + body announced assertively. Icon hidden. Countdown ring announced at start and end.

**Content.** Brief §7: what happened + what to do, max 2 body lines, no blame. `getManager` used as body for verification failure and wrong-restaurant cards. Titles: `problem.notFound.title`, `problem.foreign.title`, `problem.verify.title`, `session.expired`, others in 12.

**Do / Don't.** Don't show error codes as titles; don't offer more than two actions; don't use it when card data exists (use S07 + StatusBanner).

**Used in.** S10 (all variants), S15 full-screen states, S16.

---

## 5. Navigation and identity

### 5.1 TopBar

**Purpose.** Minimal, flat top chrome: identity on Ready, close on task screens.

**Variants**

*Home (S05)*
```
 ┌──────────────────────────────────────────────────────┐
 │ ①(MK)  ② Zum Hirschen                    ③ ⟲   ④ ≡  │   height 56 (+ top safe area)
 └──────────────────────────────────────────────────────┘
   ① Avatar 40   ② restaurant name   ③ Recent IconButton   ④ Menu IconButton
```

*Task (S07, S10, S11, S12)*
```
 ┌──────────────────────────────────────────────────────┐
 │ ① ✕            ② 5285 1058 7098 6488                  │   ② optional centred title
 └──────────────────────────────────────────────────────┘
```

| Part | Home | Task |
|---|---|---|
| Height | 56 | 56 |
| Leading | Avatar 40 (non-interactive), glyph edge at margin | ✕ IconButton, glyph at margin |
| Gap | 12 (avatar ↔ name) | – |
| Title | restaurant name, `type.label.l` 17/22 600, `fg.primary`, 1 line, end-ellipsis | S07: full card number `type.caption` `fg.tertiary` (brief); S11: screen title `type.label.l`; S10/S12: none |
| Trailing | Recent (`history`), Menu (`menu`) IconButtons, targets abutting, last glyph at margin | empty (or Torch on S12) |
| Background | `bg.canvas` (S12: transparent over camera, IconButtons on-camera variant) | same |
| Bottom edge | none at rest; hairline `border.subtle` fades in (`fast`) when content scrolls beneath | same |
| Shadow | never | never |

**Behaviour.** Not collapsible, no large-title behaviour. Banner (§4.4) attaches directly below. Android status bar: edge-to-edge, transparent, icon colour per theme.

**Accessibility.** Home: avatar + name form one static element: "Zum Hirschen, signed in as Maria Koller" (display name from `/auth/me`); Recent/Menu buttons with labels. Task: ✕ labelled "Close"; S07 title labelled "Card number 5 2 8 5, 1 0 5 8, 7 0 9 8, 6 4 8 8". Header trait on the title where it is a screen title (S11).

**Do / Don't.** Don't add a back chevron, a brand logo, colour, or a shadow. Don't put primary actions here.

**Platform differences.** iOS: no navigation-bar blur. Android: no Material top app bar elevation or tint-on-scroll (only the hairline).

**Used in.** S05, S07, S10, S11, S12; the sheet header (§4.2) follows the task variant's geometry.

---

### 5.2 Avatar

**Purpose.** Shows who is signed in, by initials. No photos in v1.

| Size | Diameter | Initials | Use |
|---|---|---|---|
| M | 40 | `type.label` 15/20 600 | TopBar |
| L | 56 | `type.title.m` 22/28 600 | Menu header (S14) |

| Property | Value |
|---|---|
| Shape | circle (`radius.full`) |
| Fill | `color.bg.key` |
| Initials | `color.fg.primary`, uppercase, tabular not relevant |
| Border | none (HC: 1 pt `border.control`) |

**Initials rule.** First letter of the first given name + first letter of the last family name; one name → one letter; BHS digraphs "Lj", "Nj", "Dž" count as one letter and are rendered as written (if both initials are digraphs, only the first is shown — max 2 glyph cells). Empty or non-Latin-renderable names → `user` icon.20 in `fg.secondary`.

**Behaviour.** Non-interactive (Menu has its own IconButton; two targets for one destination would be redundant).

**Accessibility.** Hidden individually; included in the TopBar identity label / Menu header label.

**Used in.** S05 TopBar, S14 Menu header.

---

## 6. Pattern: confirmation screens

**v1 has no confirmation screen for redeeming.** The Redeem action is confirmed by design, not by an extra step.

| Why not a confirmation screen | Evidence / rule |
|---|---|
| **Speed budget.** A confirm step costs one transition (240 ms) + one read + one tap (≈ 0.6–1.0 s) on every redemption — 15–25 % of the 3.5–4.5 s target (brief §3). | Brief §3 timing budget |
| **Confirmation fatigue.** A screen that appears every time is confirmed by habit within a shift; it stops catching errors and only adds time. | Established usability finding; the brand value "Klarheit" favours honest, direct UI |
| **The button already is the confirmation.** The label states the exact amount ("Redeem € 24,90"); the AmountDisplay above shows the same figure at 64 pt, visible to the guest. | `charge.redeem` |
| **Friction where the risk is.** Amounts **≥ € 100,00** require a 600-ms hold with three haptic ticks — a physical act that cannot happen by an accidental brush or a double tap. | HoldButton (§1.5), threshold constant 10000 cents |
| **Errors that matter are prevented, not confirmed.** Amount > balance disables the button; the wrong-card case on Android is caught by the switch-card snackbar; double taps and retries are idempotent (never booked twice). | Brief §1, §2 |
| **Mistakes have an owner.** Reversals are a manager task in the dashboard; the Recent detail sheet says so ("Wrong amount? A manager can reverse it in the dashboard."). | Brief §1 |

**The one confirmation dialog: sign out.** Signing out during service is costly (the waiter must sign in again with e-mail and password, and the device's Recent list is erased). It is rare, deliberate and non-habitual, so a confirmation is effective here: Dialog (§4.3) with DangerButton "Sign out" above SecondaryButton "Cancel".

**Not a confirmation:** the switch-card Dialog is an *accessibility fallback* for the switch-card snackbar (a choice between two cards), not a confirmation of money movement.

**Never confirm:** redemptions below € 100, theme/sound/haptics toggles, closing S07 with a typed amount (nothing is booked), opening the camera or NFC settings.

---

## 7. Component × screen matrix

| Component | S01 | S02 | S03 | S04 | S05 | S06 | S07 | S08 | S09 | S10 | S11 | S12 | S13 | S14 | S15 | S16 | S17 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| PrimaryButton | | ● | ● | | ● iOS | | ● | ● | ● iOS | ● | ● | | | | ● | ● | ● |
| SecondaryButton | | | | | ● | | | | | ● | | | ● | ● dlg | | ● | |
| TertiaryButton | | ● | ● | ● | | | | | | ● | | ● | | | ● | | ● |
| DangerButton | | | | | | | | | | | | | | ● dlg | | | |
| HoldButton | | | | | | | ● ≥ €100 | ● | | | | | | | | | |
| IconButton | | ● | | | ● | | ● | | | ● | ● | ● | ● | ● | ● | | |
| Keypad | | | | | | | ● | ● | | | ● | | | | | | |
| AmountDisplay | | | | | | | ● | ● | | | | | | | | | |
| QuickAmountChip | | | | | | | ● | | | | | | | | | | |
| TextField | | ● | | ● | | | | | | | | | | | ● | | |
| CardNumberField | | | | | | | | | | | ● | | | | | | |
| BalanceCard | | | | | | ● sk. | ● | ● | | | | | | | | | |
| StatusBadge | | | | | | | ● | ● | | | | | | | | | |
| StatusBanner | | | | | | | ● | ● | | | | | | | | | |
| NfcScanAnimation | | | | | ● | ● | | | | | | | | | | ● | |
| ProgressRing | | | | | | | ● | ● | | ● | | | | | ● | | |
| Skeleton | | | | | | ● | ● | | | | | | | | | | |
| Spinner | ● | ● | | ● | | | | ● | | | ● | | | ● | ● | | |
| SuccessMark | | | | | | | | | ● | | | | | | | | |
| CountdownHairline | | | | | | | | | ● | | | | | | | | |
| TransactionRow | | | | | | | | | | | | | ● | | | | |
| HistoryCard | | | | | | | | | | | | | ● | | | | |
| Snackbar | | | | | | | ● | | | | | | | | | | |
| BottomSheet | | | | | ● | | | | | | | | ● | ● | ● | | |
| Dialog | | | | | | | ● fb | | | | | | | ● | | | |
| Banner | | | | | ● | | ● | | | | ● | | | | ● | | |
| EmptyState | | | | | | | | | | | | | ● | | | | |
| ProblemScreen | | | | | | | | | | ● | | | | | ● | ● | |
| TopBar | | | | | ● | | ● | | | ● | ● | ● | | | | | |
| Avatar | | | | | ● | | | | | | | | | ● | | | |

sk. = skeleton state · dlg = inside Dialog · fb = accessibility fallback

---

Version 1.0 · September 2026 · GiftCard Waiter design specification
