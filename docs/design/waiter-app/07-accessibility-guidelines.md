# 07 · Accessibility Guidelines — GiftCard Waiter

Scope: how GiftCard Waiter meets WCAG 2.2 AA (as applied to native mobile apps via WCAG2ICT) and the platform accessibility guidelines of Apple HIG and Material 3 — for every screen S01–S17, including the physical realities of the job: dark dining rooms, sunny terraces, one hand on a tray, winter gloves, noise, time pressure.
Related: motion and Reduce Motion variants in [06](06-motion-guidelines.md) · layout and text scaling per size class in [08](08-responsive-behaviour.md) · haptic/sound equivalents in [11](11-sound-and-haptics.md) · tokens in [04](04-design-system.md) · components in [05](05-component-library.md) · screens in [03a](03a-screens-access-and-scanning.md) / [03b](03b-screens-charge-redeem-success-problems.md) · strings in [12](12-ui-copy-and-error-messages.md) · build notes in [09](09-flutter-handoff.md).

**Binding targets (brief §9):** WCAG 2.2 AA · text contrast ≥ 4.5:1, UI ≥ 3:1 · VoiceOver/TalkBack labels on every control · amount announced on change ("24 euro 90"; exact spoken form per [12](12-ui-copy-and-error-messages.md)) · live announcements for scan result, success, error · focus order top → bottom · touch targets ≥ 56 pt · all primary actions in the bottom 45 % of the screen · status never by colour alone · Reduce Motion · Dynamic Type · left-handed use · light theme recommended outdoors (tip in Menu) · the app never changes screen brightness.

---

## 1. Principles

1. **One decision per screen.** Ready: scan. Charge: amount + redeem. Success: next. Problem: one recovery action.
2. **Every signal has three channels.** Text + icon (always), colour/motion (visual reinforcement), haptic/sound (non-visual reinforcement). Remove any one channel and the state is still clear.
3. **The assistive path is not a lesser path.** Screen-reader, Switch Control, Voice Control and keyboard users can complete scan → redeem → next without sighted help and without extra screens.
4. **No precision, no punishment.** No small targets, no precision gestures, no timeouts that lose work.

---

## 2. WCAG 2.2 AA mapping

Status: ✅ meets · ⚠️ meets with documented exception/mitigation · N/A not applicable.

| SC | Criterion | How GiftCard Waiter meets it | How to test | St. |
|---|---|---|---|---|
| 1.1.1 | Non-text content | Every icon-only control has a label (§5.1). Decorative graphics (`NfcScanAnimation`, card sheen, `SuccessMark`, `CountdownHairline`) are hidden from AT; their meaning is in adjacent text. Status icons are grouped with their text. | Accessibility Inspector audit; TalkBack swipe-through of each screen: no "unlabelled", no "image" | ✅ |
| 1.3.1 | Info and relationships | Titles have heading trait/role; `BalanceCard` is one grouped element; list rows in Recent are single elements; toggles expose switch role and state. | Rotor "Headings" on each screen; TalkBack "Headings" navigation | ✅ |
| 1.3.2 | Meaningful sequence | Reading order = visual order top → bottom (§5.5). | Swipe-through each screen, compare with §5.5 | ✅ |
| 1.3.3 | Sensory characteristics | Instructions never rely on shape/location alone: "Hold the card near the **top** of the iPhone" is supplemented by the system sheet's own graphic; no "tap the green button". | Copy review against [12](12-ui-copy-and-error-messages.md) | ✅ |
| 1.3.4 | Orientation | Tablets: all orientations (rotate freely). **Phones are portrait-locked** (brief §2) — a **documented WCAG 1.3.4 exception under "essential"**: the one-handed NFC hold position (card held to the antenna at the top-back while the thumb reaches the bottom 45 %) only works in portrait; the Charge layout also depends on vertical height. To be revisited in v1.1. Mitigation: large phones ≥ 400 pt still portrait; tablets and unfolded foldables unlocked (a foldable's cover screen is a phone window and follows the portrait lock — [08 §6.1](08-responsive-behaviour.md)); users with mounted phones are advised to use a tablet. | Rotate every device class | ⚠️ documented exception — re-evaluate for v1.1 |
| 1.3.5 | Identify input purpose | S02 e-mail field = e-mail/username content type, password = password content type; OS autofill and password managers work. | Autofill with iCloud Keychain / Google Password Manager / 1Password | ✅ |
| 1.4.1 | Use of colour | Card states: `StatusBadge` text + icon; banners: icon + text; over-balance: text + icon + disabled button label; success: check + title. | Grayscale filter (iOS Color Filters, Android "Grayscale" in dev options) — every state identifiable | ✅ |
| 1.4.3 | Contrast (minimum) | All text tokens ≥ 4.5:1 on their backgrounds (§3.1); brand-colour card text auto-picked, fallback to ink if < 4.5:1. | Contrast table §3.1; eyedropper on screenshots of every card colour in QA palette | ✅ |
| 1.4.4 | Resize text | Text scales to 200 % (amounts to 130 % then shrink-to-fit ≥ 40 pt) without loss (§6). | Largest supported size on every screen | ✅ |
| 1.4.10 | Reflow | Minimum window 320 × 568 pt without two-dimensional scrolling; below it a "Window too small" message ([08](08-responsive-behaviour.md) §6). | Split View / multi-window at minimum size | ✅ |
| 1.4.11 | Non-text contrast | Focus ring, toggles, `ProgressRing`, `HoldButton` ring, `CountdownHairline`, status icons ≥ 3:1. **Findings** in §3.3 (dark-theme hold ring, input borders) are fixed by this spec. Keypad key fills are not required to reach 3:1 because the digit glyph (15.7:1) identifies the control. | Measure each graphical indicator against adjacent colours | ⚠️ requires §3.3 changes |
| 1.4.12 | Text spacing | Layouts tolerate +50 % line height and +12 % letter spacing (bold/large text) without clipping: all text containers are content-sized, none fixed-height except keypad digits (capped, §6.2). | Increase letter spacing via Bold Text + largest size; visual review | ✅ |
| 1.4.13 | Content on hover or focus | No hover tooltips. iPad pointer hover shows only highlight. | Pointer on iPad | N/A |
| 2.1.1 | Keyboard | Full Keyboard Access (iOS), Android keyboard navigation: every control focusable and operable; hardware digit entry on S07 ([08](08-responsive-behaviour.md) §7). `HoldButton` operable via arm/confirm (§5.3). | Complete happy path with external keyboard only | ✅ |
| 2.1.2 | No keyboard trap | Sheets and dialogs return focus on close (Esc / Back closes). | Tab through sheets and close with Esc | ✅ |
| 2.1.4 | Character key shortcuts | Single-key digit shortcuts act only on S07/S11 where the amount/number field is the screen's active input (equivalent to "active only on focus"); disabled when any text field, sheet or dialog has focus. | Open Menu sheet, type digits → nothing happens | ✅ |
| 2.2.1 | Timing adjustable | Success auto-return (4 s) loses nothing (the transaction is final and listed in Recent), is ended by any interaction, and with a screen reader or Switch Control runs **10 s** and is cancelled by any assistive navigation on S09 (§8.4). The iOS NFC session timeout is Apple's and returns silently to Ready. Throttle countdown (429) is a real-world security limit (exception "real-time/essential"). Snackbars with actions never time out with AT. | Enable VoiceOver → 10 s countdown; swipe once → countdown cancelled, S09 stays | ✅ |
| 2.2.2 | Pause, stop, hide | The NFC breathing (M04) is a status indicator of listening, low amplitude (4 %), and stops with Reduce Motion, Low Power Mode, and whenever it is covered. Skeleton and spinner stop on completion. | Reduce Motion ON → rings static | ⚠️ essential-indicator argument + OS control |
| 2.3.1 | Three flashes | No flashing; minimum fade 160 ms; no content alternates more than once per 1.2 s. | Frame-step M04, M10 | ✅ |
| 2.4.3 | Focus order | Top → bottom; focus is placed deliberately after transitions (§5.7). | Swipe-through after each transition | ✅ |
| 2.4.6 | Headings and labels | Screen titles are headings; labels describe purpose ("Redeem 24 euro 90", not "Button"). | Rotor headings | ✅ |
| 2.4.7 | Focus visible | Keyboard / Switch focus: 2 pt ring in `color.focus.ring` with 2 pt offset (#18181B light, 16.97:1 on canvas · #F0B454 dark, 10.7:1 on canvas — [04 §8.4](04-design-system.md)); on the brand card the ring is drawn outside the card on the canvas. | Full Keyboard Access traversal screenshots | ✅ |
| 2.4.11 | Focus not obscured (min.) | Snackbar and banners never cover the focused element; the snackbar sits above the CTA region; sheets move focus into themselves. | Keyboard focus on bottom keypad row with snackbar visible | ✅ |
| 2.5.1 | Pointer gestures | No multipoint or path gestures. Sheet swipe has close button/scrim/back alternatives. | Operate sheets without swiping | ✅ |
| 2.5.2 | Pointer cancellation | Buttons act on touch-up. Keypad digits register on touch-down — allowed because every digit is instantly reversible (⌫). `HoldButton` completes while held but can be aborted by releasing before 600 ms (abort mechanism). | Press Redeem, slide off, release → no redeem | ✅ |
| 2.5.3 | Label in name | Accessible name starts with the visible label: visible "Redeem € 24,90" → name "Redeem 24 euro 90" (spoken form of the same text). Voice Control "Tap Redeem" works. | Voice Control / Voice Access: speak visible labels | ✅ |
| 2.5.4 | Motion actuation | No shake/tilt input. NFC proximity is not device motion. | — | N/A |
| 2.5.7 | Dragging movements | Every drag (sheet, snackbar swipe) has a tap alternative. | Operate S13/S14 with taps only | ✅ |
| 2.5.8 | Target size (min.) | 56 × 56 pt minimum everywhere (24 required); keypad 72 pt high. | Accessibility Scanner "Touch target" check; overlay grid | ✅ |
| 3.1.1 / 3.1.2 | Language of page / parts | App language declared per locale; mixed-language parts tagged (§9.2). | VoiceOver pronunciation in DE/EN/BHS | ✅ |
| 3.2.1 / 3.2.2 | On focus / on input | Focus never triggers actions. Typing an amount never submits; hold/tap does. Card read navigating to Charge is the expected, initiated action. | Keyboard focus moves, no side effects | ✅ |
| 3.2.3 / 3.2.4 | Consistent navigation / identification | `TopBar` (Recent, Menu) identical on S05/S07/S09; the primary action is always bottom, full width, same label pattern. | Screen comparison | ✅ |
| 3.2.6 | Consistent help | "Help" always in the same place (Menu, S14). | — | ✅ |
| 3.3.1 | Error identification | Every error names what happened + what to do (brief §7); inline errors are associated with their field. | Trigger each error in [12](12-ui-copy-and-error-messages.md) with a screen reader | ✅ |
| 3.3.2 | Labels or instructions | Visible labels on S02 fields; S11 shows the 16-digit format; Charge shows the balance next to the entry. | — | ✅ |
| 3.3.3 | Error suggestion | Over-balance offers "Use balance · € 32,50"; problem screens state the next step; `getManager` where only a manager can help. | — | ✅ |
| 3.3.4 | Error prevention (legal, financial) | Redemption is **checked** (over-balance blocked client- and server-side, idempotency prevents double booking), **reviewed** (the button states the exact amount; card + balance visible on the same screen), and **reversible** (manager reversal in dashboard, stated in Recent detail). ≥ € 100 requires a deliberate hold/arm-confirm. | Attempt over-balance, double-tap Redeem rapidly, retry after network loss → one booking | ✅ |
| 3.3.7 | Redundant entry | Signed-in e-mail remembered; the scanned card carries into Charge; nothing is entered twice. | — | ✅ |
| 3.3.8 | Accessible authentication (min.) | No cognitive test: password managers, paste and autofill allowed; biometrics; "forgot password" opens the web page. | Paste password, autofill | ✅ |
| 4.1.2 | Name, role, value | All custom components (`Keypad`, `AmountDisplay`, `HoldButton`, `BalanceCard`, toggles) expose name, role/traits, value, state (§5.1). | Accessibility Inspector / TalkBack verbose | ✅ |
| 4.1.3 | Status messages | Scan result, over-balance, submitting, success, errors, offline, snackbars announced without focus move where appropriate (§5.6). | Listen with screen on/off (Screen Curtain) | ✅ |

---

## 3. Colour & contrast

### 3.1 Verified token pairs (WCAG relative-luminance ratios)

| Pair | Light | Dark | Requirement | Result |
|---|---|---|---|---|
| `fg.primary` on `bg.canvas` | 16.97 | 18.00 | 4.5 | ✅ |
| `fg.secondary` on `bg.canvas` | 7.41 | 7.72 | 4.5 | ✅ |
| `fg.tertiary` on `bg.canvas` | 4.63 | 5.86 | 4.5 | ✅ |
| `fg.tertiary` on `bg.surface` | 4.83 | 5.44 | 4.5 | ✅ |
| `fg.tertiary` on `bg.key` | **4.28** | 4.92 | 4.5 | ❌ light — never place tertiary text on keys/secondary buttons (§3.3) |
| `fg.primary` on `bg.key` (key digits) | 15.71 | ≈ 16 | 4.5 | ✅ |
| `fg.onAccent` on `action.primary` | 17.72 | 18.00 | 4.5 | ✅ |
| `accent.saffronText` on `bg.canvas` | 4.81 | 10.70 | 4.5 | ✅ |
| `success` on `success.bg` | 5.21 | 7.69 | 4.5 | ✅ |
| `danger` on `danger.bg` | 5.91 | 6.50 | 4.5 | ✅ |
| `warning` on `warning.bg` | 4.84 | 9.78 | 4.5 | ✅ |
| `info` on `info.bg` | 6.16 | 9.63 | 4.5 | ✅ |
| `accent.saffron` on `bg.canvas` (NFC arcs) | **2.07** | 10.70 | 3 if meaningful | decorative in light — the title text carries the state (§3.3) |
| `accent.saffron` on `action.primary` (hold ring) | 8.22 | **1.68** | 3 | ❌ dark — fixed in §3.3 (ring uses `color.hold.progress`: 8.22 / 4.57 ✅) |
| `border.strong` on `bg.surface` (input outline) | **2.56** | **1.76** | 3 | ❌ — fixed in §3.3 (inputs use `color.border.control`: 3.42 / 3.80 ✅) |
| White text on `brand.ink` card | 17.85 | 17.85 | 4.5 | ✅ |

### 3.2 Environment guidance

| Environment | Risk | Rule |
|---|---|---|
| **Sunny terrace** (10 000–100 000 lux) | dark theme washes out; reflections | Menu tip recommends Light theme outdoors (brief §9). Primary information uses `fg.primary` and `type.amount.xl`/`type.balance` sizes (≥ 40 pt, weight 600). No information in `fg.tertiary` that is needed to complete a redemption. The app never changes brightness. |
| **Dark dining room** (< 50 lux) | glare at guest's table, night vision | Dark theme via "follow system" (most phones switch at night). No full-white flashes: the success background is `success.bg` (#052E22 in dark), never white. Screen transitions never pass through a lighter frame. |
| **Mixed** (terrace at dusk) | wrong theme | Theme is changeable in two taps (Menu → Theme); state is kept. |
| **Guest reading upside-down / at an angle** | small text | Success amount `type.amount.l` (48 pt) and remaining balance `type.body.l` minimum. |

### 3.3 Findings and required fixes (to be reflected in [04](04-design-system.md) / [05](05-component-library.md))

| # | Finding | Fix (binding for v1 unless 04 adopts an equivalent) |
|---|---|---|
| F1 | Dark theme: saffron hold ring on light `action.primary` = 1.68:1 | The `HoldButton` ring uses **`color.hold.progress`** in both themes ([04 §8.4](04-design-system.md)): light #E8A33D (8.22:1 on #18181B, 6.91:1 on pressed #27272A), dark #B45309 (4.57:1 on #F4F4F5, 3.40:1 on pressed #D4D4D8) — all ≥ 3:1. Track: `color.hold.track`. |
| F2 | Input outlines (`border.strong`) < 3:1 in both themes | `TextField` and `CardNumberField` outlines use **`color.border.control`** ([04 §8.4](04-design-system.md): #8A8A93 light — 3.42:1 on surface, 3.28:1 on canvas; #71717A dark — 3.80:1 on surface, 4.09:1 on canvas, 3.51:1 on raised) at 1 pt, focused 2 pt `color.focus.ring`. Rationale unchanged: an input boundary is a non-text UI component that must reach 3:1 (WCAG 1.4.11); `border.strong` stays for non-essential dividers/focus base. |
| F3 | Saffron NFC arcs on light canvas 2.07:1 | Accepted: arcs are decorative/reinforcing; the state is carried by `ready.android.title` (16.97:1). Arcs must never be the only indicator of listening vs. off. |
| F4 | `fg.tertiary` on `bg.key` 4.28:1 (light) | Do not place tertiary text on key-coloured surfaces; keypad sub-labels are not used. |
| F5 | High-contrast mode maps `border.subtle` → `border.strong`, still < 3:1 | In high-contrast mode, input outlines use `fg.primary`; dividers are non-essential and exempt. |

### 3.4 High-contrast mode

Trigger: iOS *Increase Contrast*, Android *High contrast text*. Applies (brief §5): `fg.secondary` → `fg.primary`, `border.subtle` → `border.strong`, status banner text weight 600. Additionally (this spec): focus ring 3 pt; `BalanceCard` sheen disabled (flat brand colour); `StatusBadge` gets a 1 pt border in its text colour; disabled Redeem button uses `fg.secondary` label on `bg.key` with an explicit "(not available)" in its accessible value rather than lower opacity only.

### 3.5 Brand-colour card

Text colour auto-selected (white or #0A0A0C) and must reach 4.5:1 against the **lightest** point of the sheen (+6 % luminance), else the card falls back to `color.brand.ink` (brief §5). Desaturated states (blocked/expired/replaced, 40 %) re-run the check on the desaturated colour. The `StatusBadge` on the card uses its own background (not the card colour).

---

## 4. Touch, gloves and one-handed use

### 4.1 Target sizes

| Element | Visual | Touch target | Notes |
|---|---|---|---|
| Every interactive element | ≥ 44 pt | **≥ 56 × 56 pt** | hit area may extend into spacing, never overlap another target |
| Keypad keys | full cell | **≥ 72 pt high** (52 on compact height < 700 pt), width = (content width − 2 × 8) / 3 | gaps ≥ 8 pt |
| Primary CTA / `HoldButton` | full width | 64 pt high (56 compact height) | |
| `QuickAmountChip` | 40 pt high | 56 pt (8 pt extension above/below) | |
| `IconButton` (Recent, Menu, close) | 24 pt icon | 56 × 56 | |
| Recent `TransactionRow` | full width | ≥ 64 pt high | |

### 4.2 Glove-friendly by default (no separate "glove mode")

Winter terrace service means capacitive gloves or touchscreen-tipped gloves, which enlarge the contact patch (≈ 12–15 mm) and reduce precision. v1 has **no glove mode setting** — the default design is glove-safe:

1. **Large targets** (§4.1) and ≥ 8 pt gaps between adjacent keys; no two primary/destructive actions adjacent (brief §5).
2. **No precision gestures:** no swipe-to-act, no pinch, no drag handles required, no small close "×" (56 pt), no edge swipes required (system back is optional; every screen has an on-screen way back).
3. **No required long-press except `HoldButton`** (≥ € 100). Long-press ⌫ (clear) is a shortcut; repeated ⌫ does the same.
4. **Hold with gloves:** `HoldButton` tolerates finger drift — the hold continues while the touch stays within the button + 16 pt; it only aborts on lift or on leaving that area. It works with gloves because it only needs contact, not precision.
5. **Touch slop:** a keypad touch that moves ≤ 12 pt still registers as a tap; a touch that starts on one key and slides to another registers the **first** key only (prevents double digits with a fat contact patch).
6. **Double-registration guard:** two touches on the same key within 60 ms are treated as one (glove bounce). Deliberate fast double digits ("00") are slower than 60 ms in practice; the "00" key exists for speed.
7. **Fallback if gloves don't register at all:** NFC scanning needs no touch on Android. Nothing else can be done without touch — the Help page advises touchscreen gloves (see [12](12-ui-copy-and-error-messages.md)).

### 4.3 Thumb zone (bottom 45 % of the window height)

| Screen | In the thumb zone (bottom 45 %) | Allowed above |
|---|---|---|
| S02 Sign in | "Sign in" button (keyboard-attached, above keyboard) | fields (focused by tap, keyboard then lifts content) |
| S04 Unlock | "Use password" fallback, retry biometric | lock glyph, title |
| S05 Ready | iOS "Scan card" button; QR and manual entry buttons; Android: the instruction and secondary buttons | `TopBar` (Recent, Menu), NFC animation (not a target on Android) |
| S07 Charge | `Keypad`, `QuickAmountChip`, Redeem/`HoldButton` | `BalanceCard` (informational), `TopBar`, close/back |
| S09 Success | "Scan next card" (iOS) / background tap-to-return | amount, SuccessMark (informational) |
| S10 Problem | primary recovery action + secondary | icon, title, body |
| S11 Manual | keypad, "Continue" | `CardNumberField` |
| S12 QR | "Enter number instead", close | viewfinder (no interaction required) |
| S13/S14 Sheets | sheets open from the bottom; rows start at medium detent inside the zone; close button duplicates at top-right is also reachable via scrim tap below | — |

Rule: a control required on the happy path is never placed in the top 55 % — the `TopBar` holds only optional actions.

### 4.4 Left-handed and symmetric use

Layouts are horizontally symmetric: full-width CTA, centred keypad, centred amount, centred Ready instruction. No action is placed in only one bottom corner. Snackbar action sits at the trailing edge but the whole snackbar is ≥ 56 pt tall and the action ≥ 56 × 56. RTL is not a v1 locale; layouts are nevertheless mirror-safe.

---

## 5. Screen readers (VoiceOver, TalkBack)

### 5.1 Label patterns per component

Notation: **Label** (name) · **Value** · **Traits/Role** · **Hint** (spoken after a pause; omitted when obvious). Amounts use the spoken pattern of §5.2. EN shown; DE/BHS and the key names are owned by [12](12-ui-copy-and-error-messages.md) (`*.a11y`, `*.a11yHint`, `*.a11yValue`, §5.20 `a11y.*`). Strings below that 12 does not yet contain are marked **(new)** and are to be added there.

| Component | Label | Value | Traits / role | Hint / notes |
|---|---|---|---|---|
| `TopBar` restaurant name | "{restaurant}" | — | header | first element on S05/S07/S09 |
| `IconButton` Recent | "Recent redemptions" | "{n} today" | button | — |
| `Avatar` / Menu | "Menu, signed in as {first name}" | — | button | — |
| `NfcScanAnimation` | hidden | — | — | meaning carried by the title |
| Ready title (Android) | "Hold the card to the phone" (`ready.android.title`) | — | header | when NFC off: S16 text instead |
| "Scan card" (iOS) | "Scan card" | — | button | "Opens the card reader. Hold the card near the top of the iPhone." |
| `BalanceCard` (one element) | "Gift card, {restaurant}" | "Balance {amount}. Card ending {6 4 8 8}. Valid until {date}. {status if not active}" | static text (not a button) | full card number (S07 header, tertiary): separate element "Card number {5285 1058 7098 6488 read in groups}" |
| `StatusBadge` | included in card value, e.g. "Blocked" | — | — | never a separate stop |
| `StatusBanner` | "{severity word}: {title}. {body}" (severity word: Info / Warning / Error / Success) | — | static text, live region when it appears | |
| `AmountDisplay` | "Amount" | "{amount}" or "0 euro" | updates frequently / live region polite | "Use the keypad below." |
| Keypad digit | "{digit}" | — | keyboard key (iOS) / button | no hint |
| Keypad "00" | "Double zero" / DE "Doppelnull" | — | keyboard key | |
| Keypad ⌫ | "Delete" / DE "Löschen" | — | keyboard key | custom action "Clear amount" / "Betrag löschen" (replaces long-press) |
| `QuickAmountChip` | "Use balance, {amount}" | — | button | |
| Redeem (`PrimaryButton`) | "Redeem {amount}" | disabled → "Not available" | button (+ not enabled) | disabled over balance: hint "{diff} more than the balance" |
| `HoldButton` | see §5.3 | | | |
| Busy state | "Redeem {amount}" | "Redeeming" | button, not enabled, busy | announcement §5.6 |
| `SuccessMark` | hidden | — | — | title carries it |
| Success group | "Redeemed {amount}" | "Remaining balance {amount}" | header | |
| `CountdownHairline` | hidden | — | — | disabled with AT (§8.4) |
| `ProblemScreen` | title = header; body = static text | — | — | status icon hidden (title says it) |
| `Snackbar` | "{message}" | — | live region assertive | action as separate button |
| `BottomSheet` | sheet title as header; container = modal | — | modal (iOS `accessibilityViewIsModal`, Android pane title) | close button "Close" |
| `Dialog` | title header + message | — | modal alert | |
| `TransactionRow` | "{time}, card ending {6 4 8 8}" | "Redeemed {amount}, remaining {amount}" | button | "Shows details" |
| `HistoryCard` | "{n} redemptions today, total {amount}" | — | header/summary | |
| `Banner` (offline) | "No connection. Redeeming needs a connection so nothing is ever booked twice." | — | live region polite | |
| `TextField` e-mail / password | "E-mail" / "Password" | entered text / secure | text field | inline error appended to value: "Error: {message}" |
| `CardNumberField` | "Card number" | digits read in groups of four | text field | "16 digits" |
| `Skeleton` card | "Loading card" | — | busy | only one element, not per shape |
| Menu toggles | "Sound" / "Haptics" / "Keep screen on" | "On"/"Off" | switch | |
| Theme choice | "Theme" | "Follow system" / "Light" / "Dark" | adjustable / radio group | |

### 5.2 Numbers, money and card numbers — spoken forms

Visible text follows restaurant locale; spoken text follows the **app language** and is generated explicitly (never left to the TTS parser, which reads "€ 24,90" inconsistently across engines). The spoken-amount pattern is owned by [12](12-ui-copy-and-error-messages.md) §1.4 (`a11y.amount`); the table below mirrors it.

| Visible | EN spoken | DE spoken | BHS spoken |
|---|---|---|---|
| € 24,90 / €24.90 | "24 euros 90" | "24 Euro 90" | "24 eura 90" |
| € 21,00 | "21 euros" | "21 Euro" | "21 euro" |
| € 0,50 | "50 cents" | "50 Cent" | "50 centi" |
| € 1,00 | "1 euro" | "1 Euro" | "1 euro" |
| € 1.250,00 | "1250 euros" | "1250 Euro" | "1250 eura" |
| •••• 6488 | "card ending 6 4 8 8" | "Karte endet auf 6 4 8 8" | "kartica završava na 6 4 8 8" |
| 5285 1058 7098 6488 | "5 2 8 5, 1 0 5 8, 7 0 9 8, 6 4 8 8" | same digits | same digits |
| 14:32 | "14:32" (engine time format) | "14 Uhr 32" | "14 i 32" |

Rules: digits of card numbers are spoken individually with a pause between groups (separate spans / spelled-out characters); amounts use the grammatical plural of the language (BHS forms require native review, see §9); other currencies (restaurant `currency`) use the currency name from CLDR in the app language ("24 Swiss francs 90"). The €-sign is never spoken as "euro sign".

### 5.3 HoldButton with assistive technology (exact behaviour)

Raw touch (no AT): press and hold 600 ms (M16). With assistive technology the button offers **three** equivalent paths; all of them keep the same guarantee — an amount ≥ € 100,00 is only redeemed after two deliberate actions or one deliberate sustained action.

**Accessible element**

| Property | EN | DE |
|---|---|---|
| Label | "Redeem 150 euro" | "150 Euro einlösen" |
| Value | "Hold to redeem" (`charge.hold`) | "Halten zum Einlösen" |
| Hint | "Double tap and hold, or use the actions menu." | "Doppeltippen und halten oder das Aktionsmenü verwenden." |

This hint supersedes the shorter `a11y.hold.hint` ("Double-tap and hold to redeem") in [03b](03b-screens-charge-redeem-success-problems.md) — it must mention the actions menu so Path C is discoverable. The custom action and the Path B announcements are **(new)** strings for [12](12-ui-copy-and-error-messages.md).
| Custom action | "Confirm redeem 150 euro" | "Einlösen von 150 Euro bestätigen" |

**Path A — sustained gesture**
- *VoiceOver:* double-tap-and-hold passes the touch through → the real 600 ms hold runs with ring and `haptic.holdTick`; lifting early aborts. Announcement on completion: see §5.6 "Redeeming".
- *TalkBack:* double-tap-and-hold issues a long-click (it does not pass a continuous touch). The long-click action is labelled "redeem 150 euro" (TalkBack speaks "Double-tap and hold to redeem 150 euro") and **executes the redeem** — the long-click is itself the sustained deliberate action.

**Path B — arm, then confirm (double-tap twice)**
1. Accessibility *activate* (VoiceOver/TalkBack double-tap, Switch Control select, Voice Control "Tap Redeem", Full Keyboard Access Space) → button enters **Armed**: no request is sent; visual state = ring drawn full as a dashed outline, label area shows "Tap again to redeem" (visual); `haptic.select`.
2. Announcement (assertive): EN "Armed. Double tap again to redeem 150 euro." · DE "Bereit. Zum Einlösen von 150 Euro erneut doppeltippen."
3. Second activation within **10 s** → redeem (M17). Announcement "Redeeming".
4. Disarm (no request): 10 s pass, focus leaves the button, amount changes, or a new card is detected. Announcement only for the timeout: EN "Not redeemed. Redeem was not confirmed." · DE "Nicht eingelöst. Einlösen wurde nicht bestätigt." Disarming is harmless (nothing is lost), so the 10 s window does not violate 2.2.1.

**Path C — actions menu**
- VoiceOver rotor "Actions" / TalkBack actions menu (three-finger tap or swipe up-then-right) → "Confirm redeem 150 euro" → executes immediately. Choosing a named action from a menu is already two deliberate steps.

**Below € 100** (single-tap Redeem): standard button; one activation redeems. No arming.

**Hold duration decision:** fixed **600 ms** in v1, not user-adjustable. Rationale: a single, consistent muscle-memory across staff and devices; the assistive paths above remove the need to hold for anyone who cannot. OS-level touch settings are respected: with iOS Touch Accommodations *Hold Duration* or Android *Touch & hold delay* set, the 600 ms counts from the moment the OS delivers the touch.

### 5.4 Transient UI under assistive technology

- **Snackbars** do not auto-dismiss while VoiceOver/TalkBack/Switch Control run; Android honours the user's *Time to take action* setting otherwise.
- **"Different card detected — Switch?"** (Android): with a screen reader running, the prompt is shown as the `Dialog` switch-card **fallback** (brief §6) — focus moves into the dialog: title "Different card detected", buttons "Switch" / "Keep current card" (strings in [12](12-ui-copy-and-error-messages.md)).
- **Status banners** stay until the state resolves (never timed).

### 5.5 Reading order (top → bottom) for key screens

**S05 Ready — Android**
1. Restaurant name (header) → 2. Recent redemptions → 3. Menu → 4. Banner if present (offline / maintenance) → 5. Title "Hold the card to the phone" (header) → 6. Hint (antenna position) if shown → 7. "Scan QR code" → 8. "Enter card number".

**S05 Ready — iPhone**
1. Restaurant name → 2. Recent → 3. Menu → 4. Banner if present → 5. Hint text if shown (after session timeout) → 6. **"Scan card"** → 7. "Scan QR code" → 8. "Enter card number".

**S07 Charge**
1. Back/close ("Close card") → 2. `BalanceCard` (one element: name + balance + ending + validity + status) → 3. Full card number (tertiary header line) → 4. `StatusBanner` if present → 5. `AmountDisplay` ("Amount, 24 euro 90") → 6. Over-balance message if present → 7. `QuickAmountChip` if present → 8. Keypad rows 1-2-3, 4-5-6, 7-8-9, 00-0-⌫ → 9. Redeem / `HoldButton`.
Partial disabled: 5 = "Amount, full balance 32 euro 50" (static), keypad absent.

**S09 Success**
1. "Redeemed" + amount (header, one element: "Redeemed, 24 euros 90") → 2. "Remaining balance 7 euros 60" (or "Card is now empty") → 3. "Card ending 6 4 8 8" → 4. iPhone: "Scan next card" / Android: "Just tap the next card" (static hint) → 5. "Show guest" → 6. "Done". S09 has no `TopBar` ([03b](03b-screens-charge-redeem-success-problems.md)). The success announcement is posted at t = 0, so the result is heard even though focus lands on the primary action (§5.7).

**S10 Problem**
1. Title (header, e.g. "Card not found") → 2. Body (≤ 2 lines) → 3. Countdown text if throttled → 4. Primary action → 5. Secondary action → 6. Close.

### 5.6 Announcements (live regions / posted announcements)

Placeholders: `{amount}`, `{balance}`, `{diff}` in spoken form (§5.2); `{restaurant}`; `{last4}` digit-spaced.
Priority: **A** = assertive/interrupting (iOS announcement, interrupts; Android `announceForAccessibility`/assertive live region), **P** = polite (queued).

| Event | EN | DE | Pri. |
|---|---|---|---|
| Card read (Android NFC, QR) — `a11y.cardDetected` | "Card detected" | "Karte erkannt" | P |
| Card loaded, active (S07) — `a11y.cardLoaded` | "{restaurant}. Balance {balance}." | "{restaurant}. Guthaben {balance}." | A |
| Card loaded, not active — `a11y.cardLoaded` + status word appended | "{restaurant}. Balance {balance}. Card blocked. {blocked_reason}" · "… Card expired." · "… Card not activated yet." · "… Card was replaced." · "… No balance left." | "{restaurant}. Guthaben {balance}. Karte gesperrt. {blocked_reason}" · "… Karte abgelaufen." · "… Karte noch nicht aktiviert." · "… Karte wurde ersetzt." · "… Kein Guthaben mehr." | A |
| Partial disabled **(new)** | "Only the full balance can be redeemed: {balance}." | "Nur das gesamte Guthaben kann eingelöst werden: {balance}." | P (after card) |
| Lookup > 3 s **(new)** | "Still looking" | "Wird noch gesucht" | P |
| Amount change — `a11y.amount` | "Amount {amount}" | "Betrag {amount}" | P, **debounced 500 ms** after the last key ([12](12-ui-copy-and-error-messages.md) §1.10) — a burst "2-4-9-0" is announced once as "Amount 24 euros 90"; a newer value replaces an unspoken older one |
| Amount cleared **(new)** | "Amount cleared" | "Betrag gelöscht" | P |
| Over balance (enter) — `a11y.overBalance` | "{diff} more than the balance. Redeem not available." | "{diff} mehr als das Guthaben. Einlösen nicht möglich." | A |
| Hold threshold reached (amount ≥ 100) | "Hold to redeem" (`charge.hold`) | "Halten zum Einlösen" | P (once per amount entry) |
| Redeem started **(new)** | "Redeeming" | "Wird eingelöst" | A |
| Connection slow (> 8 s) — `a11y.problem` with the banner copy | "{title}. {body}" | "{Titel}. {Text}" | P |
| Uncertain — `a11y.problem` | "Connection interrupted. Checking … Nothing is ever booked twice." (`uncertain.*`) | "Verbindung unterbrochen. Wird geprüft … Es wird nie doppelt gebucht." | A |
| **Success** — `a11y.redeemed` | "{amount} redeemed. Remaining balance {remaining}." | "{amount} eingelöst. Restguthaben {remaining}." | A |
| Redeem error (422 etc.) — `a11y.problem` | "{title}. {body}" | "{Titel}. {Text}" | A |
| Problem screen (S10), S15 states — `a11y.problem` | "{title}. {body}" | "{Titel}. {Text}" | A (focus also moves) |
| Throttled countdown end — `a11y.countdownDone` | "Scanning possible again" | "Scannen wieder möglich" | P |
| Different card (dialog) | dialog title (strings in 12) | Dialogtitel | A (focus moves into dialog) |
| Card switched — `a11y.cardLoaded` | "{restaurant}. Balance {balance}." | "{restaurant}. Guthaben {balance}." | A |
| Offline — `a11y.problem` | "No connection. Redeeming needs a connection so nothing is ever booked twice." | "Keine Verbindung. Einlösen braucht Internet, damit nie doppelt gebucht wird." | P |
| Back online — `a11y.backOnline` | "Back online" | "Wieder verbunden" | P |
| Return to Ready — `a11y.ready` | "Ready for the next card" | "Bereit für die nächste Karte" | P |
| iPhone NFC session timeout | the hint text | Hinweistext | P |
| Session expired — `a11y.problem` | "Session expired. {body}" | "Sitzung abgelaufen. {Text}" | A |

Wording follows brief §7 (no exclamation marks, no blame, no "Sie/du"). German quotation marks „…“ are used when a UI label is quoted.

### 5.7 Focus management after transitions

| Transition | Focus goes to | Notes |
|---|---|---|
| S01 → S05 | Restaurant name in `TopBar` | |
| S04 unlock → previous screen | first element of that screen | |
| S05 → S07 (scan result) | `BalanceCard` | its announcement (§5.6) replaces the default screen-change read-out |
| S07 new card swap | `BalanceCard` | "Card switched" announcement |
| S07 over-balance | stays on the key that was pressed | announcement only |
| S07 → S08 busy | stays on the Redeem button | value "Redeeming" |
| S08 → S09 | iPhone: "Scan next card" · Android: "Done" ([03b](03b-screens-charge-redeem-success-problems.md)) | `a11y.redeemed` is posted at t = 0 before the focus move, so the result is always spoken first |
| S09 → S05 | Ready title (Android) / "Scan card" (iPhone) | |
| Any → S10 | problem title | |
| Sheet open (S13/S14/S15) | sheet title | focus trapped in sheet |
| Sheet close | the button that opened it | |
| Dialog close | the control that triggered it; after "Switch": `BalanceCard` | |
| Snackbar appears | **not moved** (announced) | reachable by swiping to the end of the screen (placed last in order) |
| Error on S02 | the first invalid field | error text part of its value |

Focus is set **after** the transition's first frame (not at its end), so the screen reader is never behind the waiter; the motion (M08/M18) is not waited for.

---

## 6. Dynamic Type / font scale

### 6.1 Global rules (brief §5)
- Body, caption, labels: scale with the OS up to **200 %** of the base size; beyond 200 % (iOS AX3–AX5, Android extreme scales) they stay at 200 %. Titles (`type.title.l`, `type.title.m`) scale to **150 %** and then stay fixed ([04 §3.7](04-design-system.md)).
- Amounts (`type.amount.xl`, `type.amount.l`, `type.balance`): scale to max **130 %**, then **shrink-to-fit** to the available width, minimum 40 pt. An amount is **never truncated** and never wraps inside a number.
- Keypad digits (`type.key`, 30 pt): scale to max **120 %** (36 pt) inside fixed-height keys ([04 §3.7](04-design-system.md) — the key height is the target, the digit is a label).
- Android: the OS non-linear font scaling (Android 14+) is honoured first, then the caps above apply.
- Line heights scale proportionally; letter spacing tokens stay.
- Nothing essential moves out of view; if content exceeds the window, the upper informational region scrolls — the action region (keypad, CTA) never scrolls away.

### 6.2 Reflow per screen (at 200 %)

| Screen | Behaviour at large text sizes |
|---|---|
| S02 Sign in | Single column scrolls; the "Sign in" button stays attached above the keyboard; labels above fields (never placeholders as labels). |
| S05 Ready | Title wraps to max 3 lines; secondary buttons stack vertically (full width) instead of side-by-side; iOS "Scan card" label may wrap to 2 lines (button grows to max 88 pt). NFC animation shrinks from 200 pt to 144 pt to make room. |
| S07 Charge | Priority order: (1) action region pinned: `Keypad`, CTA, `AmountDisplay`; (2) `BalanceCard` switches to the variant `BalanceCard / compact` (88 pt strip: restaurant name above balance; [05 §3.1](05-component-library.md), [08](08-responsive-behaviour.md) §3.2) at ≥ 130 %; card text is capped at 130 %, and the full content (overline, masked number, validity, status) stays in the card's accessibility label. The card is never interactive. CTA label wraps to two lines "Redeem" / "€ 24,90" (button height grows to max 88 pt). Over-balance message may wrap to 2 lines; chip moves below it. |
| S09 Success | Vertical stack scrolls if needed; amount shrink-to-fit; "Scan next card" wraps to 2 lines. |
| S10 Problem | Title wraps (max 3 lines at 200 %), body 2 lines becomes up to 4 lines — allowed; actions pinned at bottom; content region scrolls. |
| S11 Manual | `CardNumberField` digits (Geist Mono) scale to 130 % then shrink-to-fit; groups never break across lines. |
| S12 QR | Viewfinder shrinks (min 200 pt) so the instruction and "Enter number instead" fit. |
| S13 Recent | Rows become two-line: line 1 time + `•••• 6488`, line 2 amount + remaining; row height grows. |
| S14 Menu | Rows grow; toggles stay trailing; labels wrap. |
| S17 Intro | Card text scrolls within the card; "Skip" always visible. |

---

## 7. Other OS settings

| Setting | Behaviour |
|---|---|
| **Reduce Motion** / Remove animations | All rules of [06](06-motion-guidelines.md) §2.4. |
| **Reduce Transparency** | Background privacy overlay is solid (M28); sheet scrims become opaque `bg.canvas` at 88 %; no blurred materials anywhere. |
| **Bold Text** (iOS) / Bold font (Android 12+) | All weights +100 (400→500, 500→600, 600→700); layouts tolerate the wider glyphs (tabular figures unaffected in width). |
| **Button Shapes** (iOS) | `TertiaryButton` gets an underline; `IconButton`s get a `bg.key` circle. |
| **Smart Invert** | Brand card, QR viewfinder and SuccessMark are marked "ignore invert"; UI otherwise inverts (dark theme is recommended instead). |
| **Differentiate Without Colour** | Already default (icons + text everywhere). |
| **Grayscale / colour filters** | No meaning lost (verified in §10). |
| **Mono audio / hearing devices** | Sounds are mono; MFi hearing aids receive sound via the system route. |
| **Speak Screen / Select to Speak** | Works; all text is real text (no text in images). |

---

## 8. Specific needs

### 8.1 Colour blindness
Status = icon + word, always: blocked (⊘ + "Card blocked"), expired (clock + "Card expired"), inactive (pause/dash + "Card not activated yet"), replaced (arrows + "Card was replaced"), zero (empty wallet + "No balance left"), success (check + "Redeemed"), error (exclamation in circle), warning (exclamation in triangle), info (i). Red/green are never the only difference between two states; success and danger also differ in icon shape and title. Deuteranopia/protanopia/tritanopia checked with simulators (§10).

### 8.2 Cognitive load
- One decision per screen; the Charge screen combines card + amount only because they are one decision ("how much from this card").
- Consistent positions: the primary action is always the bottom full-width button; Recent and Menu never move.
- Labels are verb + object with the exact amount; no icons without words for actions.
- Error copy: what happened + what to do, max 2 lines (brief §7).
- No hidden gestures required; no modes except the ≥ € 100 hold (stated on the button).
- First-run intro (S17) ≤ 30 s, skippable, shown once per install; the Help page (S14 → Help) covers the same three steps for anyone who skipped it.

### 8.3 Hearing
Sound is **never** the only feedback (brief §5): every sound event has a simultaneous visual state change and (unless off) a haptic ([11](11-sound-and-haptics.md) §7). Success is visible to the guest at 48 pt. The app works fully muted. No spoken audio, no video.

### 8.4 Motor and timing
- **No punishing timeouts.** Nothing typed is ever lost by waiting. The only timers: Success auto-return (4 s; ended by any interaction; **10 s** while VoiceOver, TalkBack or Switch Control run, and **cancelled** by any assistive navigation on S09 — the waiter then leaves with "Done", "Scan next card" or a new card), iPhone NFC session (Apple, harmless), `HoldButton` arming window (harmless), scan throttle (server security).
- **Hold duration** fixed 600 ms with assistive alternatives (§5.3).
- **Tremor:** touch slop and double-registration guard (§4.2) prevent accidental double digits; the over-balance guard prevents large mistakes; ≥ € 100 needs a hold.
- **Switch Control:** all elements reachable in reading order; `HoldButton` via arm/confirm; keypad as a group (item-mode scanning enters the group, then row, then key).
- **Voice Control / Voice Access:** visible labels match accessible names (2.5.3); keys can be spoken as "Tap 2"; "Tap Redeem" arms the hold variant (Path B), second "Tap Redeem" confirms.
- **One hand + tray:** everything required is in the thumb zone (§4.3); no two-hand gestures.

---

## 9. Language & localisation

### 9.1 Language selection
UI language follows the phone language if de/en/bs/hr/sr, else English (brief §7). Number/currency formatting follows the **restaurant locale**; spoken forms (§5.2) follow the **UI language**.

### 9.2 Screen-reader language tagging
- The app declares its UI language to the OS so VoiceOver/TalkBack pick the right voice.
- **Restaurant names** and `blocked_reason` (free text from the dashboard) are **not** tagged (unknown language; speaking them in the UI voice is the least surprising).
- **BHS:** strings are Latin ijekavian. Tag as `hr` when the device offers no Bosnian/Serbian voice (iOS has a Croatian voice; Bosnian/Serbian availability varies on Android TTS engines). **Proposal (not part of v1):** validate pronunciation of `bs`/`sr` UI with native speakers on both platforms before deciding on per-string tagging.
- Mixed strings (e.g. English brand word "GiftCard" in German UI) are not tagged — it is a proper name.

### 9.3 Localisation layout rules
- German strings are on average 30–35 % longer than English: every text container is content-sized; buttons wrap to 2 lines before truncating; the amount part of a button label is never truncated.
- Glyph coverage: ä ö ü ß č ć š ž đ (Geist bundled, brief §5). Uppercase `type.overline` uses locale-aware uppercasing (ß → SS in "GUTSCHEINKARTE"-type overlines).
- Dates: "Valid until 26.09.2029" per restaurant locale; spoken as full date in UI language.

---

## 10. Testing protocol

### 10.1 Devices (minimum matrix per release)

| Class | iOS | Android |
|---|---|---|
| Compact height | iPhone SE (3rd gen), iOS 16 | 5.5″, 360 × 640 dp, Android 9 |
| Standard | iPhone 15, current iOS | Pixel 8 (current Android) |
| Large | iPhone 15 Pro Max | Samsung Galaxy S24 Ultra (One UI) |
| Tablet | iPad 10th gen (no NFC) | Samsung Galaxy Tab S9 |
| Foldable | — | Galaxy Z Fold (both screens) |

### 10.2 Tools
- **iOS:** Xcode Accessibility Inspector (audit + element inspection, contrast checks), VoiceOver with Screen Curtain, Voice Control, Switch Control, Full Keyboard Access, Settings → Accessibility → Display & Text Size at every size up to AX5, Colour Filters, Reduce Motion/Transparency, Increase Contrast.
- **Android:** Accessibility Scanner (touch targets, contrast, labels), TalkBack (current), Switch Access, Voice Access, Select to Speak, font size + display size maximum, "Remove animations", "High contrast text", Colour correction/Grayscale; `adb shell settings put system font_scale 2.0`.
- **Both:** colour-blindness simulators on screenshots (Sim Daltonism or equivalent), luminance meter / sunlight test outdoors (≥ 30 000 lux), dark-room test (< 50 lux), glove test (two glove types: touchscreen-tipped knit, leather), one-hand test (phone in the non-dominant hand, tray simulated with a 1 kg weight in the other).

### 10.3 Manual checklist (every release)

**Screen reader (VoiceOver and TalkBack, EN and DE)**
- [ ] Complete: unlock → scan → type € 24,90 → redeem → success → next, with Screen Curtain / screen off.
- [ ] Complete a € 150,00 redemption via Path A, Path B and Path C (§5.3); verify Path B disarms after 10 s with announcement and no request.
- [ ] Every announcement in §5.6 fires once, in the right language, with correct spoken amounts.
- [ ] Reading order matches §5.5 on S05, S07, S09, S10.
- [ ] Focus lands per §5.7 after every transition.
- [ ] With a screen reader, Success auto-returns after 10 s if untouched; one swipe cancels the countdown; "Done" returns to Ready.
- [ ] "Different card detected" appears as dialog under TalkBack.

**Visual**
- [ ] Contrast table §3.1 re-verified if any token changed; F1/F2 fixes present.
- [ ] Grayscale: every state identifiable.
- [ ] Increase Contrast / High contrast text mapping applied (§3.4).
- [ ] 200 % text on every screen of §6.2: no truncated amount, no clipped text, action region pinned.
- [ ] Sunlight test in light theme: amount, balance and Redeem label readable at arm's length.
- [ ] Dark-room test: no bright flash on any transition.

**Motor / touch**
- [ ] Accessibility Scanner: zero touch-target findings < 56 pt.
- [ ] Glove test: 20 consecutive 4-digit amounts without a mis-registered digit.
- [ ] Thumb test: all happy-path actions reachable one-handed on the Large device class.
- [ ] Full Keyboard Access / external keyboard: complete happy path.
- [ ] Switch Control: complete happy path including a hold amount.

**Motion & sensory**
- [ ] Reduce Motion: no movement; progress indicators remain.
- [ ] Sound off + haptics off + Reduce Motion: happy path still unambiguous.

**Release gate:** any failure in the screen-reader happy path, contrast of text, target size, or the ≥ € 100 assistive paths blocks the release.

---

Version 1.0 · September 2026 · GiftCard Waiter design specification
