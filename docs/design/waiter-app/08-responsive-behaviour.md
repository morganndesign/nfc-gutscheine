# 08 · Responsive Behaviour — GiftCard Waiter

Scope: how every screen adapts to window size, orientation, device type (phone, tablet, foldable), multi-window, hardware keyboards, safe areas and text scaling.
Related: base (standard-phone) layouts and wireframes in [03a](03a-screens-access-and-scanning.md) / [03b](03b-screens-charge-redeem-success-problems.md) · spacing, margins and type tokens in [04](04-design-system.md) · component internals (e.g. `BalanceCard` densities) in [05](05-component-library.md) · motion on layout changes in [06](06-motion-guidelines.md) · accessibility sizing and Dynamic Type in [07](07-accessibility-guidelines.md) · implementation of window-size detection in [09](09-flutter-handoff.md) · strings in [12](12-ui-copy-and-error-messages.md).

**Division of responsibility:** 03a/03b define *what* is on each screen at the standard size; this document defines *how it compresses, expands and re-arranges* across classes. All values are in points (iOS pt = Android dp).

---

## 1. Size classes

Classes are computed from the **app window**, not the physical screen (split-screen, Stage Manager, foldables and Android display-size settings all change the window).

### 1.1 Width classes

| Class | Window width | Side margin (brief §5) | Typical devices |
|---|---|---|---|
| **W-compact** | < 360 pt | 20 | Android phones with "Display size" enlarged; small Android phones; narrow split-screen |
| **W-standard** | 360–399 | 20 | iPhone SE 3 / 13 mini / 15 / 16 (375–393), Galaxy S24 (360), Galaxy A-series |
| **W-large** | 400–599 | 24 | iPhone Plus/Pro Max (428–440), Pixel 8/9 (412), Galaxy S24 Ultra (412), iPad Slide Over, half-width split |
| **W-tablet** | ≥ 600 | 32 | iPad (all), Android tablets, unfolded foldables |

### 1.2 Height classes

| Class | Window height | Effect |
|---|---|---|
| **H-compact** | < 700 pt | Keypad keys 64 pt, primary CTA 56 pt (brief §5), `AmountDisplay` uses `type.amount.l` metrics (48/52), `BalanceCard / compact` (88 pt) |
| **H-regular** | ≥ 700 pt | Keys 72 pt, CTA 64 pt, `type.amount.xl` |

### 1.3 Minimum window
**320 × 568 pt.** Below this in either dimension, the app shows the "Window too small" state (§6.3).

### 1.4 Class changes at runtime
Rotation (tablets), split-screen resizing, folding/unfolding and font-scale changes re-evaluate the class immediately. State is always preserved (card, typed amount, idempotency key, sheet open). Layout changes animate with a 240 ms (`motion.duration.base`) cross-fade of the re-arranged regions; with Reduce Motion 160 ms ([06](06-motion-guidelines.md) §2.4). A redeem in flight is never cancelled by a layout change.

---

## 2. Global layout rules

| Rule | Value |
|---|---|
| Side margins | 20 / 20 / 24 / 32 by width class |
| Max content width, single column | **480 pt**, centred (tablets, large windows) |
| Max form width (S02, S11) | 400 pt, centred |
| Max sheet width (S13, S14, S15) | 560 pt, centred horizontally on tablets; full width on phones |
| Primary action zone | bottom 45 % of the window (brief §9) |
| Vertical priority on S07 | action region (keypad + CTA + amount) is fixed; the `BalanceCard` absorbs all compression (§3.2) |
| Scrolling | only informational regions scroll; action regions are pinned |
| Keypad width | = content width (max 400 pt); key width = (keypad width − 2 × 8) / 3 |

---

## 3. Per-screen rules

### 3.1 S05 Ready

| Class | Layout |
|---|---|
| W-compact / standard | `TopBar` 56; centred `NfcScanAnimation` 200 pt (Android) / 160 pt arc motif above the "Scan card" button (iPhone); instruction `type.title.l`; secondary actions (QR, manual) as two `SecondaryButton`s side by side (each ≥ 56 pt, gap 12); if their labels do not fit on one line each, they stack full width. |
| H-compact | NFC animation 144 pt; title `type.title.m`; secondary actions stay side by side (56 pt) so the bottom zone keeps room for the primary action. |
| W-large | Same as standard with 24 margins; NFC animation 220 pt. |
| W-tablet | Content centred, max content width **480 pt**, vertically centred in the window with the primary button kept in the bottom 45 %. See §5 for iPad (no NFC). |
| Offline / maintenance banners | Below `TopBar`, full content width (not window width on tablets: 480 max, centred). |

### 3.2 S07 Charge (the critical screen)

**Vertical stack (portrait, phones and single-pane tablets), top → bottom:**

| Region | H-regular | H-compact |
|---|---|---|
| Header row (`TopBar` variant with close + full card number, per [03b](03b-screens-charge-redeem-success-problems.md)) | 56 | 56 |
| Gap | 4 | 0 (+ leftover) |
| `BalanceCard` | **flexible** (see density rules) | flexible (in practice `BalanceCard / compact`, 88) |
| Gap | 12 | 8 |
| `AmountDisplay` | 68 (`type.amount.xl`) | 52 (`type.amount.l` metrics) |
| Helper line (over-balance message, hold hint; reserved) | 22 | 22 |
| Gap | 8 | 4 |
| Assist row (`QuickAmountChip`) | 40 | 40 |
| Gap | 12 | 8 |
| `Keypad` 4 rows + 3 gaps of 8 | 312 (72 keys) | 280 (64 keys) |
| Gap | 12 | 8 |
| CTA (`PrimaryButton` / `HoldButton`) | 64 | 56 |
| Bottom | safe-area bottom + 8 (home indicator / gesture bar) · 16 (no inset) · 3-button nav: inset + 16 (§8) | safe-area bottom + 16 |
| **Fixed total (without card and safe-area insets)** | **618** (with the 8 pt bottom gap) | **550** (with the 16 pt bottom gap) |

Values are those of [03b §2.4](03b-screens-charge-redeem-success-problems.md) (the screen spec owns the S07 budget).

The `QuickAmountChip` is 40 pt visually; its 56 pt touch target extends 8 pt above and below into adjacent gaps (never overlapping a key's target — the top keypad row's target starts at its visual edge).

**`BalanceCard` density rules** (card height H = window height − top inset − bottom inset − fixed total):

| Available H | Density | Geometry | Content |
|---|---|---|---|
| ≥ 220 | **Full**, capped | height 220 (brief max on phones), width = min(content width, 220 × 1.586 = 349), centred | overline "GIFT CARD", restaurant name (`type.title.m`), balance (`type.balance`), `•••• 6488` + validity (`type.caption`), NFC glyph, status badge |
| 136–219 | **Full**, ratio-kept | height = H, width = H × 1.586, centred (a smaller "real" card) | as above |
| < 136 — or font scale ≥ 130 % | **`BalanceCard / compact`** (strip) | full content width × **88 pt**, `radius.l`; leftover space goes above the card | restaurant name (`type.caption`) above balance (`type.balance`); NFC glyph 20 pt and StatusBadge trailing ([05 §3.1](05-component-library.md)) |

The card is never interactive in any density ([05 §3.1](05-component-library.md)). Internal padding and type of each density are specified in 05. The density is chosen when S07 opens and only changes on a class change or text-size change — **never** while typing (the helper line and assist row are always reserved, so over-balance and hold hints never resize the card).

**Worked examples (portrait, H-regular unless noted):**

| Device (window) | Insets top / bottom | Card H | Density | Card size |
|---|---|---|---|---|
| iPhone 15 (393 × 852) | 59 / 34 | 141 | Full, ratio | 224 × 141 |
| iPhone 15 Pro Max (430 × 932) | 59 / 34 | 221 → cap 220 | Full, capped | 349 × 220 |
| iPhone 13 mini (375 × 812) | 50 / 34 | 110 | compact | 335 × 88 |
| iPhone SE 3 (375 × 667, H-compact) | 20 / 0 | 97 | compact | 335 × 88 |
| Pixel 8 (412 × 915, gesture nav) | 52 / 24 | 221 → 220 | Full, capped | 349 × 220 |
| Galaxy S24 (360 × 780, gesture nav) | 39 / 24 | 99 | compact | 320 × 88 |
| Galaxy A-series (360 × 800, 3-button nav) | 32 / 48 (+ 8 extra bottom gap) | 94 | compact | 320 × 88 |

**Partial redemption disabled:** keypad and assist row are removed; the card takes Full density (ratio, up to 220), the fixed amount "full balance" and CTA sit in the bottom zone; the free space is placed **above** the card (card stays close to the thumb-zone CTA).

**Card-problem states** (blocked/expired/inactive/replaced/zero): keypad is absent ([03b](03b-screens-charge-redeem-success-problems.md)); `StatusBanner` sits between card and actions; card Full density.

**Width classes:**
- W-compact: keypad keys ≥ (320 − 40 − 16) / 3 = 88 pt wide — still ≥ 56. `AmountDisplay` shrink-to-fit applies earlier (7 digits + separators at 64 pt ≈ 300 pt → shrinks to fit 280 pt; min 40 pt).
- W-large: keypad max width 400, centred; margins 24.
- W-tablet portrait (and landscape below 856 pt width): single column, content max 480, keypad max 400, centred; card Full up to 280 pt high (tablet cap: width 440 × 1.586 → **277 pt**).
- W-tablet landscape ≥ 856 pt: two-pane (§4.2).

### 3.3 S09 Success

| Class | Layout |
|---|---|
| Phones | Vertical stack centred (content per [03b](03b-screens-charge-redeem-success-problems.md)): `SuccessMark` → `success.title` → amount `type.amount.l` → remaining balance → `•••• 6488` → bottom zone: iPhone "Scan next card" `PrimaryButton` / Android hint `success.next.android`, then "Show guest" + "Done". No `TopBar`. `CountdownHairline` at top (below safe area). |
| H-compact | `SuccessMark` 72 pt; gaps −25 %. |
| Tablets (any orientation) | Single column centred, content and buttons max **440** ([03b](03b-screens-charge-redeem-success-problems.md)); `SuccessMark` 120 pt; no two-pane (one message only). |

### 3.4 S10 Problem screens

| Class | Layout |
|---|---|
| Phones | Icon 48 pt at 30 % window height; title `type.title.l`; body ≤ 2 lines (up to 4 at large text); actions pinned bottom (primary full width; secondary `TertiaryButton` above it — never side by side). Content region scrolls if needed. |
| H-compact | Icon at 20 % height; icon 40 pt. |
| Tablets | Centred block, max 480; actions pinned to the bottom of the centred block, not the window edge, when window height > 900 (keeps eye travel short); otherwise bottom of window. |

### 3.5 S02 Sign in

| Class | Layout |
|---|---|
| Phones | Logo 48, title, e-mail, password, "Sign in" (`PrimaryButton` 56), "Forgot password" (`TertiaryButton`). With keyboard up: content scrolls so that the focused field **and** the Sign-in button are visible; Sign-in button sits directly above the keyboard. |
| H-compact | Logo hidden while keyboard is visible. |
| Tablets | Form max 400, centred vertically and horizontally; in landscape with an on-screen keyboard the form is anchored above the keyboard. |

### 3.6 S11 Manual entry

| Class | Layout |
|---|---|
| Phones | `CardNumberField` (Geist Mono, 4 groups) top; keypad (same geometry as S07; the "00" position is an empty, non-interactive slot — card numbers have no "00" shortcut) bottom; "Continue" CTA (enabled at 16 digits). |
| H-compact | Keys 64, CTA 56. |
| Tablets | Single column max 400; landscape ≥ 856: field left pane, keypad right pane (same column rules as §4.2). Hardware keyboard typing supported (§7). |

### 3.7 S12 QR scan

| Class | Layout |
|---|---|
| Phones | Camera preview full-bleed behind the `TopBar` (scrim 48 % around a square viewfinder 240 pt, radius `radius.l`); instruction above; "Enter number instead" bottom. |
| H-compact | Viewfinder 200 pt. |
| Tablets | Viewfinder 320 pt, centred; preview fills window. iPad in landscape: camera is on the long edge — instruction adds "Hold the card in front of the camera" with an arrow toward the camera side (orientation-aware; strings in [12](12-ui-copy-and-error-messages.md)). |
| Split-screen | Preview is cropped to the window; viewfinder min 200; below that the "Window too small" rule applies. |

### 3.8 S13 Recent / Recent detail (sheets)

| Class | Layout |
|---|---|
| Phones | Bottom sheet full width, detents medium (50 %) and large; `HistoryCard` header sticky; `TransactionRow` 64 pt. Detail as sheet-on-sheet (content height). |
| H-compact | Opens directly at large detent (medium would show < 3 rows). |
| W-large | Same as phones, rows show remaining balance in a trailing column. |
| Tablets | Sheet width 560, centred, bottom-anchored, max height 80 % of window; landscape two-pane Charge stays visible behind the scrim. |

### 3.9 S14 Menu (sheet)

| Class | Layout |
|---|---|
| Phones | Bottom sheet content-height (max large detent); rows 56–64 pt; sign-out at the bottom, separated by 24 pt from other rows (brief: no destructive adjacent to primary). |
| Tablets | Width 560, centred. |

### 3.10 S01, S03, S04, S15, S16, S17
Single column, max content 480 on tablets, actions in the bottom zone; S17 intro cards max 480 wide, 3 cards paged horizontally on all classes (paging also by buttons, [07](07-accessibility-guidelines.md) 2.5.7).

---

## 4. Orientation

### 4.1 Phones
**Portrait-locked** (brief §2), including W-large phones. This is a **documented WCAG 1.3.4 exception (essential: the one-handed NFC hold position)**, to be revisited in v1.1 — rationale in [07](07-accessibility-guidelines.md) SC 1.3.4. Upside-down portrait is not supported. **Tablets rotate freely** (all orientations, §4.2).

### 4.2 Tablets — landscape two-pane Charge (S07)

Condition: window width ≥ **856 pt** and width > height. Otherwise single column (§3.2).

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ TopBar (full width, margins 32)       Restaurant   5285 1058 7098 6488   ⟲ ☰ │
├──────────┬───────────────────────────┬───────┬──────────────────────┬────────┤
│  outer   │  LEFT PANE  (360–480)     │gutter │ RIGHT PANE (400)     │ outer  │
│  margin  │  ┌─────────────────────┐  │  32   │  € 24,90             │ margin │
│  ≥ 32    │  │    BalanceCard      │  │       │  assist row          │ ≥ 32   │
│          │  │  Full, ratio 1.586  │  │       │  ┌───┬───┬───┐       │        │
│          │  │  width = left pane  │  │       │  │ 1 │ 2 │ 3 │  …    │        │
│          │  └─────────────────────┘  │       │  └───┴───┴───┘       │        │
│          │  StatusBanner (if any)    │       │  [ Redeem € 24,90 ]  │        │
└──────────┴───────────────────────────┴───────┴──────────────────────┴────────┘
```

| Column | Width rule |
|---|---|
| Outer margins | 32 each, plus half of any leftover |
| Left pane (card) | clamp(360, W − 64 − 32 − 400, **480**) |
| Gutter | 32 |
| Right pane (amount + keypad + CTA) | **400 fixed** (keys (400 − 16) / 3 = 128 wide, 72 high; 80 high if window height ≥ 800) |
| Vertical | Left pane content vertically centred; right pane bottom-aligned (CTA at bottom inset + 16) so the thumb reaches it when the tablet is held by its sides |

Worked widths:

| Device, landscape (pt) | Left pane | Leftover → each outer margin |
|---|---|---|
| iPad mini 6 (1133 × 744) | 480 | 157 → 32 + 78.5 = 110.5 |
| iPad 10th gen / Air 11″ (1180 × 820) | 480 | 204 → 134 |
| iPad Pro 13″ (1376 × 1032) | 480 | 400 → 232 |
| Galaxy Tab S9 (1280 × 800 dp) | 480 | 304 → 184 |
| Unfolded foldable in landscape (≈ 880 × 690) | 384 | 0 → 32 |
| Foldable ≈ 830 wide | — (< 856) | single column |

Card in the left pane: width = pane width, height = width / 1.586 (max 303 at 480 wide — tablet exception to the 220 pt phone cap).

### 4.3 Tablets — other screens in landscape
- **S05 Ready:** centred, max content width **480**; iPad shows the QR-first layout (§5). No two-pane.
- **S09, S10, S02, S04, S17:** centred single column (§3).
- **S11:** two-pane like S07 (field left, keypad right) at ≥ 856.
- **S12:** full-window camera preview, viewfinder centred.
- **S13/S14:** sheets 560 wide, centred.
- Rotation while on S07: the pane split animates via a 240 ms cross-fade; the typed amount, card and any `HoldButton` progress are preserved (a hold in progress is aborted on rotation — the ring reverses, [06](06-motion-guidelines.md) M16).

---

## 5. iPad and tablets without NFC

iPad has no NFC reader accessible to apps; some Android tablets have none either (`NFC unsupported`, S16).

| Element | Behaviour |
|---|---|
| S05 primary | **"Scan QR code"** as `PrimaryButton` (large, bottom zone) with a QR illustration (160 pt) in place of the NFC animation |
| S05 secondary | **"Enter card number"** as `SecondaryButton` directly above the primary (never side by side with it) |
| Instruction | QR-oriented copy (strings in [12](12-ui-copy-and-error-messages.md)); no NFC wording anywhere |
| S09 next action | "Scan next QR code" replaces NFC wording (per [12](12-ui-copy-and-error-messages.md)); opens S12 directly |
| Universal links | A card URL opened from the camera app or a link opens S07 (method `link`) — same as iPhone |
| Android tablets **with** NFC | Android phone behaviour (reader mode). Antenna is often back-centre: the Ready hint shows "back centre" guidance for the device's model class (strings in [12](12-ui-copy-and-error-messages.md)) |
| Android tablets with NFC **off** | S16 "NFC is off" state with deep link to settings, QR as secondary |

---

## 6. Foldables, split-screen and multi-window

### 6.1 Foldables
- **Folded (cover screen):** a normal phone class (Galaxy Z Fold cover ≈ 344–370 × 800+ → W-compact/standard). Very small cover screens (flip-phone covers) are below the minimum window → §6.3.
- **Unfolded:** W-tablet; ≥ 856 wide in landscape → two-pane; otherwise single column max 480.
- **Continuity:** fold/unfold preserves all state; the NFC reader session (Android) is re-registered for the new window without losing the loaded card.
- **Hinge / posture:** content never straddles a vertical hinge: when a hinge or fold feature is reported vertical and the window is two-pane, the gutter is aligned over the hinge (the left pane ends before it); single-column content is centred in the larger half. Tabletop (horizontal fold): content in the upper half, keypad + CTA in the lower half on S07 — same stack, split at the fold with the assist row as the break point.
- **NFC antenna:** on foldables the antenna position differs folded vs unfolded; the Ready hint text changes with the state.

### 6.2 Split-screen / multi-window / Stage Manager / Slide Over
- Width classes follow the window (a half-width iPad split is W-large; one-third is W-compact/standard).
- Slide Over (320 × tall) is supported (≥ 320 × 568).
- Android multi-window: NFC reader mode is enabled only while GiftCard Waiter is the **focused, resumed** window; when another app has focus, the Ready screen shows "Tap here to scan" state (the NFC animation static, instruction replaced by "Tap to activate scanning" — **Proposal**, string for [12](12-ui-copy-and-error-messages.md)). A tap focuses the window and enables reader mode.
- Keep screen awake applies only while the app is visible in any window.

### 6.3 "Window too small"
Condition: window width < 320 pt **or** height < 568 pt.
- The whole window shows a centred message: icon (resize), title "Window too small", body "Make the window larger to continue." (**Proposal** — strings to be added to [12](12-ui-copy-and-error-messages.md) as `window.tooSmall.title` / `.body`).
- No other controls. A redeem already in flight completes in the background logic and its result (S09 / error) is shown when the window becomes large enough. NFC reader mode is off in this state.
- Returning to a valid size restores the previous screen with state.

---

## 7. Hardware keyboards (iPad, Android tablets, phones with keyboards)

| Screen | Key | Action |
|---|---|---|
| S07 Charge | 0–9 (top row and numpad) | type into `AmountDisplay` (POS entry, same rules and M12 animation as on-screen keys, `haptic.key` **not** played for hardware keys) |
| S07 | Backspace | delete last digit |
| S07 | ⌥/Alt + Backspace, or Esc when amount > 0 | clear amount |
| S07 | Esc when amount = 0 | close Charge → Ready |
| S07 | Return / Enter / numpad Enter | **Redeem, only when amount < € 100,00** (`holdToConfirmThresholdCents`) and the button is enabled. At ≥ € 100,00 Enter does **not** redeem: the assist row pulses the `charge.hold` hint (opacity 1 → 0.4 → 1, 320 ms) and VoiceOver/TalkBack announce "Hold to redeem". Keyboard-only users redeem via the `HoldButton` arm/confirm path with Tab + Space ([07](07-accessibility-guidelines.md) §5.3). |
| S07 | `,` `.` | ignored (POS entry; no decimal separator needed) |
| S07 | Tab / Shift-Tab | focus order per [07](07-accessibility-guidelines.md) §5.5 |
| S11 Manual | 0–9, Backspace | type into `CardNumberField`; Return = Continue when 16 digits |
| S11 | Cmd/Ctrl + V | paste a 16-digit number (spaces/dashes stripped) |
| S02 Sign in | standard text entry, Tab between fields, Return = next field / Sign in | |
| S05 Ready | Return | iPhone/iPad: primary action (Scan card / Scan QR code) |
| Sheets / dialogs | Esc | close |
| Any | Cmd/Ctrl + , | not used (no settings shortcut in v1) |

Rules:
- Digit shortcuts are inactive when a sheet, dialog or text field has focus ([07](07-accessibility-guidelines.md) SC 2.1.4).
- iPad: shortcuts are listed in the ⌘-hold overlay: "Redeem" (Return), "Clear amount" (Esc), "Close" (Esc).
- When a hardware keyboard is attached, the on-screen keypad stays visible (the waiter may mix both).
- A keypress and an on-screen tap arriving in the same frame are processed in order of arrival; no duplicates.

---

## 8. Safe areas, notches, Dynamic Island, system bars

| Area | Rule |
|---|---|
| **Top (notch, Dynamic Island, punch-hole, status bar)** | `TopBar` starts at safe-area top. No content or touch target inside the top inset. `CountdownHairline` (S09) sits at safe-area top + 0 (directly under the status bar), never under the Dynamic Island. Live Activities / Dynamic Island are **not** used in v1. |
| **Bottom — iPhone home indicator** | CTA bottom edge = safe-area bottom (34) + 8. No target within the home-indicator area. The home indicator auto-hide is **not** requested (the waiter needs normal app switching). |
| **Bottom — iPhone/iPad with home button** | CTA bottom edge = 16 from window bottom. |
| **Android — gesture navigation** | Edge-to-edge (mandatory from API 35 targets): content draws behind a transparent navigation bar; CTA bottom edge = navigation-bar inset (≈ 16–24 dp) + 8. The keypad's outer keys start 20 pt from the side edges and may overlap the back-gesture region (≈ 24 dp); taps are unaffected because back is a horizontal swipe, and a stationary `HoldButton` press never triggers it. **No** system-gesture exclusion is requested. |
| **Android — 3-button navigation** | Nav bar ≈ 48 dp, opaque `color.bg.canvas` with 1 px `border.subtle` top line; CTA bottom edge = inset + 16. |
| **Android — status bar** | Transparent; icon colour dark on light theme, light on dark theme and on S12 camera. |
| **Landscape tablets** | Safe-area left/right respected (iPad in some orientations with camera housing); margins = max(32, inset + 16). |
| **Rounded display corners** | No target within 12 pt of a rounded corner's curve; side margins already satisfy this on all current devices. |
| **On-screen keyboard (S02, S11 text fallback)** | Content above the keyboard inset; the primary button stays attached to the keyboard top + 8. |
| **Snackbar placement** | Bottom edge = CTA top − 8 on S07/S09 (never covers the CTA or keypad's bottom row); on S05 = safe bottom + 16 above the primary button zone's top. Width = content width (max 480). |
| **Sheets** | Extend under the bottom inset (background fills it); interactive content ends at safe bottom + 8. |
| **Privacy overlay (M28)** | Covers the full window including insets. |

---

## 9. Text scaling interplay

Full rules in [07](07-accessibility-guidelines.md) §6. Class-specific consequences:

| Situation | Result |
|---|---|
| H-regular, text ≤ 130 % | layouts as specified |
| Any class, text ≥ 130 % | S07 `BalanceCard` → `BalanceCard / compact` (88 pt) regardless of height ([03b §2.4](03b-screens-charge-redeem-success-problems.md)); from 150 % S05 secondary buttons stack |
| H-compact, text ≥ 150 % | S07 card stays `BalanceCard / compact`; S09 `SuccessMark` 56 pt; S10 content scrolls |
| Any class, text ≥ 185 % | S07 card stays `BalanceCard / compact` (card text capped at 130 %); CTA label 2 lines (height ≤ 88); `AmountDisplay` at 130 % cap with shrink-to-fit |
| Tablet two-pane, any text size | left pane scrolls independently if the card + banner exceed height; right pane pinned |
| W-compact + large amounts | `AmountDisplay` shrink-to-fit reaches 40 pt min for € 99.999,99 at ≈ 300 pt; if still wider (large text), the currency symbol drops to `type.title.l` size (the digits never shrink below 40 pt) |

Order of compression when space runs out on any screen: (1) decorative sizes (NFC animation, SuccessMark, icons), (2) gaps to their minimum (8), (3) `BalanceCard` density, (4) informational text scrolls. Never: shrinking touch targets, truncating amounts, hiding the primary action.

---

## 10. Acceptance criteria

- [ ] Size class is derived from the window; verified in iPad Split View ⅓ / ½ / ⅔, Slide Over, Stage Manager and Android split-screen.
- [ ] S07 worked examples (§3.2) match on the listed devices ± 2 pt; the card density never changes while typing.
- [ ] No touch target < 56 pt at any class; keypad ≥ 64 pt high on H-compact.
- [ ] Landscape tablet two-pane appears at ≥ 856 pt width only; left pane ≤ 480, right pane 400.
- [ ] iPad Ready shows "Scan QR code" as primary; no NFC wording on any iPad screen.
- [ ] Below 320 × 568: "Window too small" state; above: previous state restored intact.
- [ ] Hardware keyboard: digits, Backspace, Esc, Enter (< € 100 only) behave per §7; Enter at ≥ € 100 never redeems.
- [ ] No content under the Dynamic Island, notch, home indicator or navigation bar; tested with gesture and 3-button navigation.
- [ ] Rotation, fold/unfold and split resizing preserve card, amount and idempotency key; a hold in progress aborts safely.
- [ ] 200 % text on H-compact S07: action region fully visible, card in `BalanceCard / compact` (88 pt), no truncated amount.

---

Version 1.0 · September 2026 · GiftCard Waiter design specification
