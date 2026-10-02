# 04 · Design System — GiftCard Waiter

*Foundations, tokens and system patterns for the GiftCard Waiter app (iOS, Android). Binding for design and engineering. Components built on these foundations are specified in [05-component-library.md](05-component-library.md).*

| | |
|---|---|
| **Scope** | Visual language, tokens, system-level patterns (loading, progress, success, error, navigation, overlays) |
| **Not in scope** | Screen layouts → [03a-screens-access-and-scanning.md](03a-screens-access-and-scanning.md), [03b-screens-charge-redeem-success-problems.md](03b-screens-charge-redeem-success-problems.md) · motion choreography → [06-motion-guidelines.md](06-motion-guidelines.md) · accessibility procedures → [07-accessibility-guidelines.md](07-accessibility-guidelines.md) · breakpoints & tablet layouts → [08-responsive-behaviour.md](08-responsive-behaviour.md) · haptic/sound design → [11-sound-and-haptics.md](11-sound-and-haptics.md) · strings → [12-ui-copy-and-error-messages.md](12-ui-copy-and-error-messages.md) · implementation mapping → [09-flutter-handoff.md](09-flutter-handoff.md) |
| **Units** | `pt` = iOS point = Android dp = Flutter logical pixel. `px` only where a physical pixel is meant (hairlines). |
| **Token status** | Values from the design brief §5 are **binding and unchanged**. Tokens this document adds are marked **➕ Added** (derived, never contradicting a binding value). |

---

## 1. Identity — how GiftCard Waiter looks different from a stock app

GiftCard Waiter is a precision tool used at a table, in front of a guest, often in dim light, often one-handed, often in a hurry. Its look follows the brand archetype **"the head waiter"**: calm, precise, present when needed, invisible otherwise. It must not read as a default Material or Cupertino app. Seven decisions make that visible:

| # | Decision | What it means in practice | What a stock app would do instead |
|---|---|---|---|
| 1 | **Own typeface** | Geist Sans for all UI, Geist Mono only for the card number on S11. Bundled, never system fonts. Tight negative tracking on large numerals; tabular figures everywhere. | San Francisco / Roboto |
| 2 | **The BalanceCard is the hero** | The only saturated colour surface in the app is the guest's gift card, rendered in the restaurant's `brand_color` at ID-1 proportions with a soft sheen and a brand-tinted shadow. Everything else steps back. | Coloured app bars, tinted buttons, accent-coloured everything |
| 3 | **Calm monochrome UI** | Canvas, surfaces, text and primary buttons are zinc-neutral (Graphit `#18181B` / near-white `#F4F4F5`). Status colours appear only when a status exists. | Brand-tinted UI chrome |
| 4 | **Saffron means "attention" — nothing else** | `color.accent.saffron` is reserved for: NFC arcs, the hold-progress ring, focus accents, the snackbar action. ≤ 5 % of any screen's area (brand allows 10 %; the waiter app is stricter). Never as text on light backgrounds. | Accent on every link, switch and icon |
| 5 | **No floating action buttons, no ripples** | Every press is a custom pressed state: a fill swap to a `*Pressed` token plus a small scale (0.96–0.98), 90 ms in / 160 ms out. No ink splash, no radial ripple, no highlight flash. | Material ripple, FAB |
| 6 | **Flat, borderless chrome** | TopBar has no background tint and no shadow; a 1-px hairline appears only when content scrolls beneath it. Shadows exist on exactly four things: BalanceCard, BottomSheet, Snackbar, Dialog. | Elevated app bars, shadowed cards |
| 7 | **Big, glove-proof geometry** | 56 pt minimum targets, 72 pt keypad keys, 64 pt full-width CTA, generous 20–28 pt radii with continuous (squircle) corners on iOS. | 44/48 pt targets, 4–12 pt radii |

**Signature moments** (the parts a waiter will remember): the three saffron arcs breathing on the Ready screen (S05), the card arriving with a spring (S07), digits sliding in from the right like a payment terminal, the hold ring filling, the drawn check and the two-note chime (S09).

**Never:** gradients other than the BalanceCard sheen · glassmorphism/blur panels · emoji · illustrations with faces · exclamation marks · coloured icons in coloured circles as decoration · more than one primary button per screen · a tab bar.

---

## 2. Token architecture

Three tiers. Engineers consume tier 2 and 3; tier 1 exists only to feed them.

| Tier | Example | Rule |
|---|---|---|
| 1 · Primitive | `zinc.900 = #18181B`, `saffron.500 = #E8A33D` | Never referenced by components or screens directly. |
| 2 · Semantic (this document) | `color.fg.primary`, `space.4`, `radius.l`, `type.body.l`, `motion.duration.base` | The public API. Themes swap values here. |
| 3 · Component (05) | `keypad.key.height`, `balanceCard.padding` | Only when a component needs a value that is not a plain semantic token; always defined as a reference to tier 2 plus an optional derivation. |

**Naming grammar:** `category.role[.variant][.state]`, lowerCamelCase segments, dots as separators: `color.action.primaryPressed`, `type.amount.xl`, `type.key`. Numeric scales use the step number (`space.4` = 16 pt), not the value.

**Theme resolution:** every colour token has a light and a dark value. The app resolves the theme from (1) the Menu override "Light / Dark / System" (S14), else (2) the OS appearance. High-contrast variants (§10) are applied on top of the resolved theme.

---

## 3. Typography

### 3.1 Families

| Family | Weights bundled | Used for | Features on |
|---|---|---|---|
| **Geist Sans** | 400 Regular · 500 Medium · 600 Semibold · 700 Bold (700 only for iOS "Bold Text" / Android "Bold text" accessibility substitution, §10.2) | All UI text and all amounts | `tnum` (tabular figures) on every style that can contain digits; `kern` on; `liga` on; no `ss` alternates |
| **Geist Mono** | 500 Medium | Card number entry on S11 only (`type.cardNumber`) | `tnum` implicit; `zero` off (digits only, no O/0 ambiguity) |

Both under SIL OFL 1.1, bundled with the app binary (no runtime download). Required glyph coverage: Latin-1 + Latin Extended-A — explicitly ä ö ü Ä Ö Ü ß ẞ č ć š ž đ Č Ć Š Ž Đ, € £ CHF, the narrow no-break space U+202F and no-break space U+00A0, the true minus U+2212, the ellipsis U+2026 and the bullet U+2022 (masked card numbers "•••• 6488"). Missing glyph → the build fails its font test (see [09-flutter-handoff.md](09-flutter-handoff.md)); there is no platform-font fallback in production.

### 3.2 Type scale

Binding values from the brief; the tracking column adds the absolute pt value engineers need (tracking % × size).

| Token | Size / line (pt) | Weight | Tracking | Tracking (pt) | Use |
|---|---|---|---|---|---|
| `type.amount.xl` | 64 / 68 | 600 | −2.5 % | −1.60 | Amount being typed (S07, S08) |
| `type.amount.l` | 48 / 52 | 600 | −2 % | −0.96 | Success amount (S09) |
| `type.balance` | 40 / 44 | 600 | −2 % | −0.80 | Balance on BalanceCard |
| `type.title.l` | 28 / 34 | 600 | −1 % | −0.28 | Screen titles (S02, S10, S15, S16) |
| `type.title.m` | 22 / 28 | 600 | −0.5 % | −0.11 | Sheet titles, restaurant name on BalanceCard, dialog titles |
| `type.body.l` | 17 / 24 | 400 | 0 | 0 | Primary body, Ready instruction, row primary text |
| `type.body.m` | 15 / 22 | 400 | 0 | 0 | Secondary body, banner body, inline messages |
| `type.label` | 15 / 20 | 600 | 0 | 0 | Regular buttons, chips, snackbar action |
| `type.label.l` ➕ *(name added; value from brief "large 17/22")* | 17 / 22 | 600 | 0 | 0 | Large buttons (64 pt CTA) |
| `type.caption` | 13 / 18 | 500 | +0.5 % | +0.065 | Meta, masked card number, badges, timestamps |
| `type.overline` | 11 / 14 | 600 | +8 %, uppercase | +0.88 | "GIFT CARD" on BalanceCard, section overlines in sheets |
| `type.key` | 30 / 36 | 500 | 0 | 0 | Keypad digits |
| `type.cardNumber` ➕ | 24 / 32 | Geist Mono 500 | +2 % | +0.48 | CardNumberField (S11) only |
| `type.currency.xl` ➕ | 38 / 68 | 600 | −1 % | −0.38 | € symbol inside `type.amount.xl` (60 % of 64, rounded) |
| `type.currency.l` ➕ | 29 / 52 | 600 | −1 % | −0.29 | € symbol inside `type.amount.l` (60 % of 48) |
| `type.currency.balance` ➕ | 24 / 44 | 600 | −1 % | −0.24 | € symbol inside `type.balance` (60 % of 40) |

Line heights are always set explicitly ("leading-trim off, line box fixed") so that rows and buttons do not change height between iOS and Android font metrics. Text is vertically centred in its line box by cap-height, not by ascender (Geist's ascender is taller than its cap height; centring on the line box alone makes button labels look 1 pt low).

### 3.3 Numerals

1. **Tabular figures everywhere** a digit can appear: amounts, balances, keypad, card numbers, times, counts, countdowns. Digits must never shift horizontally while typing or while a countdown runs.
2. **Lining figures** only (Geist default). No old-style figures.
3. Minus in amounts uses U+2212 "−", never a hyphen. (The waiter app shows no negative amounts in v1; the rule exists for Recent totals and future use.)
4. Grouping and decimal separators follow the restaurant locale (§3.4); they are proportional glyphs — acceptable, because their count only changes when the digit count changes.
5. Masked card number: four U+2022 bullets, a no-break space, the last four digits: "•••• 6488". Bullets are set at `type.caption` size with +0.5 pt extra tracking for readability.

### 3.4 Currency formatting and symbol sizing

Format follows the **restaurant locale** (brief §7), not the phone language.

| Locale | Pattern | Example | Symbol position | Gap symbol ↔ number |
|---|---|---|---|---|
| de-AT | `€ 24,90` | € 1.234,50 | leading | spaced |
| de-DE | `24,90 €` | 1.234,50 € | trailing | spaced |
| de-CH | `CHF 24.90` (currency CHF) / `€ 24.90` (EUR) | CHF 1'234.50 | leading | spaced |
| en-GB | `€24.90` | €1,234.50 | leading | tight |
| en-US | `€24.90` | €1,234.50 | leading | tight |
| BHS strings shown for a de-AT restaurant | the restaurant locale wins: `€ 24,90` | | | |

Note: brief §7 lists "BHS 24,90 €" as the BHS money style; it applies only where the restaurant locale itself is a BHS locale (not in the v1 locale list). Copy keys in [12-ui-copy-and-error-messages.md](12-ui-copy-and-error-messages.md) always insert a pre-formatted `{amount}`.

**Large-amount symbol rule** (applies to `type.amount.xl`, `type.amount.l`, `type.balance` only; in body text the symbol is full size):

- The currency symbol (or code "CHF") is set at **60 % of the amount size**: 38 / 29 / 24 pt.
- It sits **on the same baseline** as the digits — never vertically centred, never superscript.
- Same weight (600) and same colour as the digits in the same state (placeholder state: both `color.fg.tertiary`).
- Gap ➕: "spaced" locales = **0.16 em of the amount size** (10 pt at 64, 8 pt at 48, 6 pt at 40) — replaces the space character, which would be too wide next to the smaller symbol. "Tight" locales = **0.04 em** (3 / 2 / 2 pt), an optical breath only.
- Trailing symbols (de-DE) keep the same gap after the last digit.
- For screen readers the visual string is never read; the accessible value is spoken form (§3.8, [07-accessibility-guidelines.md](07-accessibility-guidelines.md)).

### 3.5 Line length and alignment

| Context | Max measure | Alignment |
|---|---|---|
| Phone body text | full content width (≈ 40–46 characters of `type.body.l` at 335–390 pt) | leading (left) |
| Tablet body text | 480 pt text column (≈ 60 characters) | leading |
| Problem screens (S10), EmptyState, Success (S09), Splash | 320 pt column, centred block | centred, max 2 body lines |
| Buttons | button width minus padding | centred |
| Amounts | never constrained by measure; see shrink rules §3.7 | centred on S07/S09; leading on BalanceCard |

German hyphenation: enabled for `type.body.l` and `type.body.m` in multi-line paragraphs (compounds like "Betriebsleitung" otherwise force ragged 2-word lines). Disabled for titles, buttons, labels, badges, and never inside amounts, card numbers or restaurant names.

### 3.6 Truncation and wrapping rules

| Content | Rule |
|---|---|
| Any amount or balance | **Never truncated, never wrapped.** Shrink-to-fit only (§3.7). |
| Card number (full, S07 header; S11 field) | Never truncated. Full number wraps between groups of four only if unavoidable at 200 % text size. |
| Masked number "•••• 6488" | Never truncated (fixed 9 characters). |
| Restaurant name — TopBar, BalanceCard | 1 line, end-ellipsis. Full name in the accessibility label. |
| Restaurant name — Menu (S14) | Up to 2 lines, then end-ellipsis. |
| Waiter display name — Menu | Up to 2 lines, then end-ellipsis. |
| Screen titles `type.title.l` | Up to 2 lines (3 at ≥ 150 % text size), then end-ellipsis — copy must fit 2 lines at 100 % in all three languages. |
| Sheet titles `type.title.m` | 1 line, end-ellipsis (copy limit: 24 characters). |
| Button labels | Never truncated. Wrap to max 2 lines; button grows in height (min height stays). The amount inside a label is kept on one line with a no-break space between symbol and number. |
| Banner / StatusBanner body | Max 2 lines by copy rule; at large text sizes it may wrap further — never truncated. |
| Snackbar text | Max 2 lines; if longer at large text sizes, the snackbar grows — never truncated. |
| TransactionRow | Time and amount never truncate; the middle column truncates (end-ellipsis) first. |
| `blocked_reason` (server text) | Max 3 lines in the StatusBanner, then end-ellipsis; full text in the accessibility label. |

### 3.7 Dynamic Type and font scale

| Token group | Scales to | Beyond the cap |
|---|---|---|
| `type.body.*`, `type.label*`, `type.caption` | **200 %** (brief) | fixed at 200 % |
| `type.amount.xl`, `type.amount.l`, `type.balance` | **130 %** (brief) | then shrink-to-fit (below) |
| `type.title.l`, `type.title.m` ➕ | 150 % | fixed |
| `type.key` ➕ | 120 % (key height is fixed geometry) | fixed |
| `type.overline` ➕ | 130 % | fixed |
| Any text inside the BalanceCard ➕ | 130 % (card has fixed ratio) | fixed; the full content remains available to screen readers |
| `type.cardNumber` ➕ | 130 % | shrink-to-fit, min 20 pt |

**Shrink-to-fit (amounts):** when the formatted amount does not fit the available width at its current size, the size steps down in 2-pt steps (symbol keeps its 60 % ratio) until it fits, **minimum 40 pt**. Line height scales proportionally. The step-down is animated only when it happens during typing (see [06-motion-guidelines.md](06-motion-guidelines.md)). At 40 pt the longest possible amount ("€ 99.999,99") is ≈ 215 pt wide and fits every supported width, so truncation can never occur.

**Platform mapping:** iOS content size categories xS–xxxL and AX1–AX5; Android `fontScale` 0.85–2.0 (Android 14+ non-linear scaling is honoured first, then our caps are applied to the resulting size). Layout consequences at large sizes (scrolling regions, pinned CTA) are in [08-responsive-behaviour.md](08-responsive-behaviour.md).

### 3.8 Numbers for assistive technology

Every amount exposes a spoken value independent of the visual string: "24 euro 90" (EN), "24 Euro 90" (DE), "24 eura 90" (BHS). Card numbers are spoken in groups ("ending 6 4 8 8"). Details and live-region rules: [07-accessibility-guidelines.md](07-accessibility-guidelines.md).

---

## 4. Spacing and layout

### 4.1 Spacing scale (4-pt base)

| Token | pt | Typical use |
|---|---|---|
| `space.0` | 0 | reset |
| `space.1` | 4 | icon ↔ badge text, tight stacks (overline ↔ title) |
| `space.2` | 8 | icon ↔ label, keypad gaps, chip gaps, inline message ↔ chip |
| `space.3` | 12 | button stack gap, banner icon ↔ text, card ↔ amount (compact) |
| `space.4` | 16 | component inner padding (rows, fields, snackbar), card ↔ amount |
| `space.5` | 20 | compact screen margin, large-button horizontal padding |
| `space.6` | 24 | BalanceCard padding, regular screen margin, section gap |
| `space.8` | 32 | tablet margin, gap before a CTA block, EmptyState stacks |
| `space.10` | 40 | large vertical separation (Success amount ↔ remaining) |
| `space.12` | 48 | top offset of problem-screen icon block |
| `space.16` | 64 | hero offsets on tablets |

No other values are used for layout. Component-internal measurements that are not on the scale (e.g. 36 × 5 grabber, 3 pt ring stroke) are geometry, not spacing, and are listed in the size tokens (Appendix A).

### 4.2 Width classes, margins and grid

| Class | Width | Side margin | Column grid | Max content width |
|---|---|---|---|---|
| Compact width | < 400 pt (iPhone SE/mini/standard, most Android) | **20** (`space.5`) | 4 columns, 8-pt gutter | full |
| Regular width | 400–599 pt (Plus/Max, large Android) | **24** (`space.6`) | 4 columns, 8-pt gutter | full |
| Tablet | ≥ 600 pt | **32** (`space.8`) | 8 columns, 16-pt gutter | 560 pt single column, centred; two-pane rules in [08-responsive-behaviour.md](08-responsive-behaviour.md) |

Safe areas are always respected; margins are added **inside** the safe area. Landscape phones do not exist (portrait lock).

### 4.3 Height classes ➕ (brief defines compact height < 700 pt)

| Class | Height (safe area excluded) | Adjustments |
|---|---|---|
| Compact height | < 700 pt (iPhone SE 2nd/3rd gen, small Android) | Keypad keys 64 pt, CTA 56 pt, `BalanceCard / compact` (88 pt, [05 §3.1](05-component-library.md)), AmountDisplay top gap 4 pt |
| Regular height | ≥ 700 pt | Keys 72 pt, CTA 64 pt, BalanceCard ID-1 layout (max 220 pt) |

The S07 budget on a 375 × 667 iPhone SE (647 pt below the status bar) is worked out in [03b-screens-charge-redeem-success-problems.md](03b-screens-charge-redeem-success-problems.md); the system guarantees it fits without scrolling at 100 % text size (brand value "Handwerk": the app works on an iPhone SE without scrolling).

### 4.4 Vertical rhythm

- All component heights are multiples of 4 pt (hairlines excepted).
- All line heights are even numbers; text blocks are positioned on the 4-pt grid by their line box.
- Stack gaps: related items `space.2`–`space.3`, groups `space.6`, before the CTA block `space.8` (minimum; the CTA block is bottom-anchored, so this is the minimum free space above it).
- The CTA block is always anchored to the bottom safe area with `space.4` bottom padding (phones with a home indicator) or `space.5` (devices without, e.g. iPhone SE, Android 3-button navigation).

### 4.5 Thumb zone map

Percentages of the usable screen height (safe area included, status bar excluded), for one-handed use with either thumb. The layout is horizontally symmetric so left-handed use works identically.

```
 ┌──────────────────────────────┐  0 %
 │ READ ZONE                    │  TopBar, Banner, screen titles
 │ hard to reach one-handed     │  → no primary action; only secondary
 │                              │    IconButtons (Recent, Menu, ✕)
 ├──────────────────────────────┤ 25 %
 │ STRETCH ZONE                 │  BalanceCard, AmountDisplay,
 │ reachable with grip shift    │  StatusBanner, NfcScanAnimation
 │                              │  → read-mostly; rare taps (QuickAmountChip)
 ├──────────────────────────────┤ 55 %
 │ THUMB ZONE                   │  Keypad, PrimaryButton / HoldButton,
 │ natural arc of either thumb  │  Snackbar, SecondaryButtons
 │                              │  → every primary action lives here
 └──────────────────────────────┘ 100 %
```

Rules:
1. **Every primary action lies entirely in the bottom 45 %** of the screen (brief §9) — verified per screen in 03a/03b acceptance criteria.
2. Input controls (Keypad) may extend up to the bottom **60 %**; on a compact-height phone the top keypad row sits at ≈ 44–56 % and is still within the natural arc.
3. The top 25 % holds only actions that are secondary and not time-critical (Recent, Menu, ✕). Each also has a gesture or system alternative (swipe-down, Android back).
4. Nothing interactive within 16 pt of the left or right screen edge on iOS (edge-swipe conflict) except full-width buttons, whose labels are centred.
5. Two primary/destructive actions are never adjacent; when a CTA and a secondary action stack, the gap is `space.3` (12 pt) minimum — glove rule.

---

## 5. Shape

### 5.1 Radius scale

| Token | pt | Used by |
|---|---|---|
| `radius.xs` | 8 | StatusBadge, QuickAmountChip, skeleton blocks without a final radius |
| `radius.s` | 12 | TextField, CardNumberField, Snackbar |
| `radius.m` | 16 | Regular buttons (56), StatusBanner, TransactionRow pressed fill, IconButton pressed fill on square variant |
| `radius.l` | 20 | Large buttons (64), keypad keys |
| `radius.xl` | 28 | HistoryCard, Dialog, content cards inside sheets |
| `radius.sheet` | 32 | Top corners of BottomSheet |
| `radius.full` | 999 | Avatar, circular IconButton fill, pills, grabber, progress caps |

Note: skeleton text lines use half their own height as radius (fully rounded ends), which for 12-pt lines is 6 pt — a geometric rule, not a new token.

**Nesting rule:** an element inset inside a rounded container uses *outer radius − inset*, minimum `radius.xs` (e.g. a 28-pt card with a 16-pt inset content block → 12 pt).

### 5.2 Continuous corners (squircle)

| Platform | Rule |
|---|---|
| iOS | All radii **≥ 16 pt** render as continuous corners (Apple "continuous" curve; in Figma: corner smoothing **60 %**). This includes buttons, keys, BalanceCard, sheets, dialogs, HistoryCard. Radii ≤ 12 pt render as circular arcs. |
| Android | All radii render as **circular arcs with the same nominal value** ("matched rounded rect"). No path-based squircle emulation (anti-aliasing cost on scrolling lists, clipping inconsistencies with shadows). The optical difference (Android corners look ≈ 1 pt rounder) is accepted. |
| Both | `radius.full` is always a true semicircle. Clipping of content (card sheen, skeleton sweep) uses the same shape as the container. |

Design files keep one iOS and one Android frame for the BalanceCard and the large button so reviewers see both corner types.

---

## 6. Elevation and surfaces

Elevation communicates "this floats above the flow and will go away". Only four things float: **BalanceCard, BottomSheet, Snackbar, Dialog**. TopBar, buttons, keys, rows and banners are flat — always.

### 6.1 Light theme — shadows

| Token | Shadow (x y blur, colour) | Spread | Used by |
|---|---|---|---|
| `elev.0` | none | – | everything flat |
| `elev.1` | 0 1 2 `rgba(0,0,0,0.04)` | 0 | HistoryCard (separation from sheet), Avatar on imagery |
| `elev.2` | 0 4 16 `rgba(0,0,0,0.08)` | 0 | BalanceCard in desaturated states and skeleton; Dialog (together with scrim) |
| `elev.3` | 0 12 32 `rgba(0,0,0,0.12)` | 0 | BottomSheet (cast upward: 0 −12 32), Snackbar |

Shadow direction: light from above; the sheet's shadow is cast upward (negative y) because it rises from the bottom edge.

### 6.2 Dark theme — surface steps and borders

No shadows in dark mode (they are invisible on near-black and muddy the brand glow). Separation is expressed by **lighter surface steps plus a 1-px `color.border.subtle` outline**.

| Step | Token | Dark value | Used by |
|---|---|---|---|
| 0 | `color.bg.canvas` | #0A0A0C | Screen background |
| 1 | `color.bg.surface` | #141417 | BottomSheet, HistoryCard |
| 2 | `color.bg.raised` | #1C1C21 | Sheet on sheet (S13 detail), Snackbar, Dialog |
| Controls | `color.bg.key` / `color.bg.keyPressed` | #1E1E23 / #2A2A31 | Keys, secondary buttons, chips |

| Element | Dark treatment |
|---|---|
| BottomSheet | `bg.surface` + 1 px `border.subtle` along the top edge and top corners |
| Stacked sheet | `bg.raised` + 1 px `border.subtle` |
| Snackbar, Dialog | `bg.raised` + 1 px `border.subtle` all round |
| BalanceCard | brand colour unchanged + 1 px `color.card.borderDark` ➕ (#26262B) all round; no glow |

---

## 7. Borders

| Token ➕ | Value | Rule |
|---|---|---|
| `border.width.hairline` | **1 physical px** = 1 / screen scale pt (0.5 pt @2x, 0.33 pt @3x; 1 px on Android at any density) | Dividers between TransactionRows, TopBar scroll edge, Banner bottom edge, dark-mode surface outlines. Must snap to the pixel grid (no blurred half-pixels). |
| `border.width.default` | 1 pt | TextField / CardNumberField at rest, high-contrast outlines on SecondaryButton, card outline in dark mode (rendered as 1 physical px on @1x-equivalent devices only). |
| `border.width.focus` | 2 pt | Focus ring, focused inputs, error inputs |
| `border.width.focus.hc` | 3 pt | Focus ring in high-contrast mode |

Rules:
1. Borders are drawn **inside** the component bounds (inner stroke), so a border-width change between states never shifts layout.
2. Dividers are inset: TransactionRow dividers start at the row's text column (16 pt leading inset), never full-bleed inside a sheet.
3. `color.border.subtle` is **decorative only** (1.22–1.31 : 1). It may never be the only thing that identifies a control.
4. Controls that need a visible boundary (text inputs) use `color.border.control` ➕ (≥ 3 : 1, §8.4), not `border.strong`.

---

## 8. Colour system

### 8.1 Principles

1. **Monochrome by default.** ≥ 90 % of any screen is canvas, surface and zinc text.
2. **One brand surface.** The restaurant's colour appears only on the BalanceCard (and its shadow). Never on buttons, bars, icons or text.
3. **Saffron = attention.** NFC arcs, hold ring, focus accent, snackbar action. Never text on light backgrounds (use `color.accent.saffronText`). ≤ 5 % of screen area.
4. **Status colours only for status**, always paired with an icon and text (never colour alone).
5. **Contrast targets:** text 4.5 : 1 (also for large text — we do not use the 3 : 1 large-text allowance except where noted), UI components and meaningful graphics 3 : 1 (WCAG 2.2 AA, 1.4.3 / 1.4.11).

### 8.2 Contrast verification — binding tokens

All ratios computed with the WCAG 2.x relative-luminance formula (sRGB linearisation, L = 0.2126 R + 0.7152 G + 0.0722 B; ratio = (L₁ + 0.05) / (L₂ + 0.05)), rounded down to two decimals. ✓ = meets its requirement; ✗ = fails → rule or added token in §8.4.

**Neutral foreground**

| Token | Light | on canvas #FAFAFA | on surface #FFFFFF | on bg.key #F1F1F3 | Dark | on canvas #0A0A0C | on surface #141417 | on raised #1C1C21 | on bg.key #1E1E23 | Req. |
|---|---|---|---|---|---|---|---|---|---|---|
| `color.fg.primary` | #18181B | 16.97 ✓ | 17.72 ✓ | 15.71 ✓ | #F4F4F5 | 18.00 ✓ | 16.73 ✓ | 15.44 ✓ | 15.10 ✓ | 4.5 |
| `color.fg.secondary` | #52525B | 7.41 ✓ | 7.73 ✓ | 6.85 ✓ | #A1A1AA | 7.72 ✓ | 7.17 ✓ | 6.62 ✓ | 6.48 ✓ | 4.5 |
| `color.fg.tertiary` | #71717A | 4.63 ✓ | 4.83 ✓ | **4.28 ✗** | #8B8B94 | 5.86 ✓ | 5.44 ✓ | 5.03 ✓ | 4.92 ✓ | 4.5 |

`color.fg.primary` on `color.bg.keyPressed`: 13.96 (light) / 12.96 (dark) ✓.

**Actions**

| Pair | Light | Ratio | Dark | Ratio | Req. |
|---|---|---|---|---|---|
| `fg.onAccent` on `action.primary` | #FFFFFF / #18181B | 17.72 ✓ | #0A0A0C / #F4F4F5 | 18.00 ✓ | 4.5 |
| `fg.onAccent` on `action.primaryPressed` | #FFFFFF / #27272A | 14.89 ✓ | #0A0A0C / #D4D4D8 | 13.38 ✓ | 4.5 |
| `action.primary` against canvas (button shape) | #18181B / #FAFAFA | 16.97 ✓ | #F4F4F5 / #0A0A0C | 18.00 ✓ | 3.0 |
| `bg.key` against canvas (key shape) | #F1F1F3 / #FAFAFA | 1.08 | #1E1E23 / #0A0A0C | 1.19 | n/a ¹ |

¹ Keys and secondary buttons are identified by their label (digit/text at ≥ 6.48 : 1), not their fill; WCAG 1.4.11 does not require a boundary in that case. In high-contrast mode they gain an outline (§10).

**Borders**

| Token | Light | on canvas / surface | Dark | on canvas / surface | Req. | Verdict |
|---|---|---|---|---|---|---|
| `color.border.subtle` | #E4E4E7 | 1.22 / 1.27 | #26262B | 1.31 / 1.22 | none (decorative) | decorative only |
| `color.border.strong` | #A1A1AA | **2.46 / 2.56 ✗** | #3F3F46 | **1.89 / 1.76 ✗** | 3.0 for input boundaries | insufficient as sole input boundary → `color.border.control` ➕ |

**Accent**

| Pair | Light | Ratio | Dark | Ratio | Req. | Verdict |
|---|---|---|---|---|---|---|
| `accent.saffron` on canvas / surface | #E8A33D | **2.07 / 2.16 ✗** | #F0B454 | 10.70 / 9.95 ✓ | 3.0 graphic | Light: decorative only (NFC arcs accompany instruction text) |
| `accent.saffron` on `action.primary` | on #18181B | 8.22 ✓ | on #F4F4F5 | **1.68 ✗** | 3.0 graphic | Dark hold ring needs `color.hold.progress` ➕ |
| `accent.saffron` on `brand.ink` | | 8.28 ✓ | | 9.66 ✓ | 3.0 | NFC glyph on default card ✓ |
| `accent.saffronText` on canvas / surface | #B45309 | 4.81 / 5.02 ✓ | #F0B454 | 10.70 / 9.95 ✓ | 4.5 | ✓ |

**Status**

| Token | Light | on canvas | on surface | on own `.bg` | Dark | on canvas | on surface | on own `.bg` | Req. |
|---|---|---|---|---|---|---|---|---|---|
| `color.success` | #047857 | 5.25 ✓ | 5.48 ✓ | 5.21 ✓ (#ECFDF5) | #34D399 | 10.29 ✓ | 9.56 ✓ | 7.69 ✓ (#052E22) | 4.5 |
| `color.danger` | #B91C1C | 6.20 ✓ | 6.47 ✓ | 5.91 ✓ (#FEF2F2) | #F87171 | 7.15 ✓ | 6.65 ✓ | 6.50 ✓ (#2A0E0E) | 4.5 |
| `color.warning` | #B45309 | 4.81 ✓ | 5.02 ✓ | 4.84 ✓ (#FFFBEB) | #FBBF24 | 11.85 ✓ | 11.01 ✓ | 9.78 ✓ (#2A1E06) | 4.5 |
| `color.info` | #1D4ED8 | 6.42 ✓ | 6.70 ✓ | 6.16 ✓ (#EFF6FF) | #93C5FD | 10.97 ✓ | 10.20 ✓ | 9.63 ✓ (#0B1A33) | 4.5 |

`color.fg.primary` on each tone background: light 16.82 / 16.20 / 17.08 / 16.28, dark 13.45 / 16.36 / 14.85 / 15.79 ✓. `color.fg.secondary` on the tone backgrounds: light 7.06–7.45, dark 5.77 (success.bg) – 7.02 ✓. `color.fg.tertiary` on `danger.bg` 4.41 ✗ → tertiary text is not used inside banners.

Status tones on `bg.key` (light): success 4.86 ✓, danger 5.73 ✓, **warning 4.45 ✗** → status text is always placed on its own `.bg` tint or on canvas/surface, never on `bg.key`.

**Brand**

| Pair | Ratio | Note |
|---|---|---|
| `brand.ink` #0F172A on light canvas | 17.10 | card edge clearly visible |
| `brand.ink` on dark canvas #0A0A0C | 1.11 | card edge invisible → 1-px `color.card.borderDark` ➕ |
| White on `brand.ink` | 17.85 (15.31 on the sheen's lightest stop) | card text ✓ |

**Scrim** (composited): light `rgba(10,10,12,0.48)` over #FAFAFA = #878788; dark `rgba(0,0,0,0.64)` over #0A0A0C = #040404. Sheet surfaces sit above the scrim, so no text is ever placed on the scrim itself.

### 8.3 Binding colour tokens — usage

| Token | Light | Dark | Use / rule |
|---|---|---|---|
| `color.bg.canvas` | #FAFAFA | #0A0A0C | Every screen background |
| `color.bg.surface` | #FFFFFF | #141417 | Sheets, TextField fill, HistoryCard (light) |
| `color.bg.raised` | #FFFFFF | #1C1C21 | Sheet on sheet, snackbar (dark), dialog (dark) |
| `color.bg.key` | #F1F1F3 | #1E1E23 | Keys, SecondaryButton, chips, disabled button fill, skeleton base, pressed fill of TertiaryButton/IconButton/rows |
| `color.bg.keyPressed` | #E4E4E7 | #2A2A31 | Pressed key, pressed SecondaryButton, pressed chip |
| `color.fg.primary` | #18181B | #F4F4F5 | Text, icons, amounts |
| `color.fg.secondary` | #52525B | #A1A1AA | Secondary text, inactive icons, banner body |
| `color.fg.tertiary` | #71717A | #8B8B94 | Meta, placeholder "€ 0,00", timestamps, disabled labels — on canvas/surface/raised only |
| `color.fg.onAccent` | #FFFFFF | #0A0A0C | Label/icon on `action.primary` |
| `color.border.subtle` | #E4E4E7 | #26262B | Dividers, dark-mode outlines (decorative) |
| `color.border.strong` | #A1A1AA | #3F3F46 | Grabber, skeleton-free separators that must be seen, focus-ring *base* track; **not** a stand-alone input boundary |
| `color.action.primary` | #18181B | #F4F4F5 | PrimaryButton / HoldButton fill |
| `color.action.primaryPressed` | #27272A | #D4D4D8 | Pressed PrimaryButton |
| `color.brand.ink` | #0F172A | #0F172A | Default & fallback BalanceCard colour |
| `color.accent.saffron` | #E8A33D | #F0B454 | NFC arcs, hold ring (light), focus accent, snackbar action |
| `color.accent.saffronText` | #B45309 | #F0B454 | Saffron as text/links on light (rare) |
| `color.success` / `.bg` | #047857 / #ECFDF5 | #34D399 / #052E22 | Money moved, active status |
| `color.danger` / `.bg` | #B91C1C / #FEF2F2 | #F87171 / #2A0E0E | Blocked, errors, over-balance |
| `color.warning` / `.bg` | #B45309 / #FFFBEB | #FBBF24 / #2A1E06 | Expired, inactive, zero balance, maintenance |
| `color.info` / `.bg` | #1D4ED8 / #EFF6FF | #93C5FD / #0B1A33 | Offline, neutral tips |
| `color.scrim` | rgba(10,10,12,0.48) | rgba(0,0,0,0.64) | Behind sheets and dialogs |

### 8.4 Added colour tokens ➕

| Token ➕ | Light | Dark | Derived from | Verified contrast | Purpose |
|---|---|---|---|---|---|
| `color.border.control` | #8A8A93 | #71717A | brand "Linie stark" #8A8A93; zinc-500 | L: 3.42 on surface, 3.28 on canvas · D: 3.80 on surface, 4.09 on canvas, 3.51 on raised ✓ 3.0 | Resting boundary of TextField, CardNumberField; SecondaryButton outline in high contrast |
| `color.focus.ring` | #18181B | #F0B454 | fg.primary / accent.saffron (dark) | L: 16.97 on canvas · D: 10.70 on canvas, 9.95 on surface ✓ 3.0 | 2-pt focus ring |
| `color.focus.accent` | #E8A33D | – | accent.saffron | decorative (outer 2-pt band in light, contrast carried by the inner ring) | Brand warmth on focus |
| `color.hold.progress` | #E8A33D | #B45309 | saffron / saffronText (copper) | L: 8.22 on #18181B, 6.91 on pressed #27272A · D: 4.57 on #F4F4F5, 3.40 on pressed #D4D4D8 ✓ 3.0 | HoldButton ring progress |
| `color.hold.track` | #4F4F52 (onAccent 24 % on primary) | #CFCFD0 (onAccent 16 % on primary) | composited | decorative track | HoldButton ring track |
| `color.danger.pressed` | #991B1B | #EF4444 | red-800 / red-500 | label 8.31 / 5.26 ✓ | Pressed DangerButton |
| `color.fg.onDanger` | #FFFFFF | #0A0A0C | – | 6.47 on #B91C1C / 7.15 on #F87171 ✓ | DangerButton label |
| `color.fg.onSuccess` | #FFFFFF | #0A0A0C | – | 5.48 on #047857 / 10.29 on #34D399 ✓ (graphic) | Check inside SuccessMark |
| `color.inverse.bg` | #18181B | = `bg.raised` #1C1C21 | action.primary | – | Snackbar background |
| `color.inverse.fg` | #FFFFFF | = `fg.primary` #F4F4F5 | – | 17.72 / 15.44 ✓ | Snackbar text |
| `color.inverse.action` | #E8A33D | #F0B454 | saffron | 8.22 on #18181B / 9.18 on #1C1C21 ✓ | Snackbar action label |
| `color.card.borderDark` | – (none) | #26262B | border.subtle dark | decorative | BalanceCard outline in dark mode |
| `color.skeleton.base` | #F1F1F3 | #1E1E23 | = bg.key | – | Skeleton shapes |
| `color.skeleton.highlight` | #E0E0E2 | #2F2F34 | fg.primary at 8 % over base | – | Skeleton sweep band ("8 % highlight") |
| `color.state.hover` | rgba(24,24,27,0.04) | rgba(244,244,245,0.04) | fg.primary 4 % | – | Pointer hover (iPad trackpad, Android mouse) |
| `color.state.pressedOverlay` | rgba(24,24,27,0.08) | rgba(244,244,245,0.08) | fg.primary 8 % | – | Pressed state for elements without a `*Pressed` token (on imagery, BalanceCard-adjacent) |
| `color.nfc.arc.hc` | #B45309 | #F0B454 | saffronText | L: 4.81 on canvas ✓ | NFC arcs in high-contrast mode |
| `color.camera.overlay` | rgba(0,0,0,0.56) | rgba(0,0,0,0.56) | – | white text on it ≥ 9 : 1 over any image darker than mid-grey; text additionally gets a 0 1 2 rgba(0,0,0,0.4) shadow | S12 viewfinder mask |

### 8.5 Semantic usage rules

| Colour family | Do | Don't |
|---|---|---|
| Neutral | Use `fg.primary` for anything the waiter must read at a glance (amounts, titles, row values). | Grey out important information to "look elegant". |
| `fg.tertiary` | Meta, placeholders, timestamps on canvas/surface. | Place on `bg.key` or on tone backgrounds (4.28 / 4.41 : 1). |
| Saffron | NFC arcs, hold ring, focus accent, snackbar action — one saffron element per screen region. | Text on light, icons, borders, backgrounds, "highlight" chips. |
| Success | Only after the server confirmed money moved (S09, Recent rows' check icon) and the "Active" badge. | "Card found" confirmations (that is neutral + haptic). |
| Danger | Blocked card, failures, over-balance message, sign-out button. | Destructive styling for "Cancel" or "Close". |
| Warning | Expired, inactive, zero balance, maintenance, "Connection slow". | Emphasis or tips. |
| Info | Offline banner, neutral tips (e.g. "Light theme is easier to read outdoors"). | Links (there are no inline links except "Forgot password?"). |
| Brand colour | BalanceCard only. | Buttons, TopBar, icons, success screen. |

### 8.6 Brand colour handling for the BalanceCard

**Input.** `brand_color` from the restaurant settings (hex `#RRGGBB`, default `#0F172A`). Accepted forms: 6-digit hex with or without "#", case-insensitive. 3-digit, 8-digit (alpha), named colours, empty or malformed values → treated as missing → `color.brand.ink`.

**Sheen.** The card fill is a linear gradient from the top-left corner to the bottom-right corner:
- start stop (0 %): brand colour mixed **6 % toward white** (sRGB),
- end stop (100 %): brand colour mixed **6 % toward black** (sRGB).
This is the implementation of the brief's "+6 % luminance to −6 %". For ink: #1D2537 → #0E1627. No other texture, noise or pattern.

**Automatic text colour — WCAG relative-luminance algorithm** (evaluated once per card, and again whenever the displayed card colour changes, e.g. desaturated states):

1. Compute the two sheen stops as above.
2. Candidate A is white (#FFFFFF). Its worst case is the **lightest** stop (start stop). Compute contrast A = contrast(white, start stop).
3. Candidate B is near-black (#0A0A0C). Its worst case is the **darkest** stop (end stop). Compute contrast B = contrast(#0A0A0C, end stop).
4. Choose the candidate with the higher worst-case contrast; on a tie, white.
5. If the chosen contrast is **≥ 4.5 : 1**, use it for all card text (overline, name, balance, meta) and for the StatusBadge outline.
6. If neither candidate reaches 4.5 : 1, **fall back**: the card is rendered in `color.brand.ink` with white text, and the client logs a non-fatal diagnostic "brand_color_contrast_fallback" once per restaurant per install. Mathematically this happens for brand colours whose relative luminance is around 0.14–0.23 (mid greys, mid teals, mid blues); at L ≈ 0.186 both candidates reach only 4.44 : 1 even without sheen.
7. **Secondary card text** (overline, masked number, validity) uses the chosen text colour at **76 % opacity** (`opacity.cardSecondary` ➕) — only if that composite still reaches 4.5 : 1 against the worst-case stop; otherwise it uses 100 % and is differentiated by size and weight only.
8. **NFC glyph:** saffron arcs are used when saffron reaches ≥ 3 : 1 against both stops; otherwise the arcs are drawn in the chosen text colour (at 100 %).
9. **Light-card edge:** if the card's end stop has less than 1.5 : 1 contrast against `color.bg.canvas` (very light brand colours), the card receives a 1-px `color.border.subtle` outline in light theme as well.

**Worked examples** (computed):

| brand_color | Rel. luminance | Chosen text | Worst-case text contrast | Secondary at 76 % | Saffron glyph (min vs stops) | Result |
|---|---|---|---|---|---|---|
| #0F172A (ink, default) | 0.009 | white | 15.31 | 9.42 ✓ → 76 % | 7.10 ✓ saffron | as designed |
| #7F1D1D (bordeaux) | 0.055 | white | 8.71 | 5.70 ✓ → 76 % | 4.04 ✓ saffron | |
| #14532D (forest) | 0.065 | white | 7.79 | 5.29 ✓ → 76 % | 3.61 ✓ saffron | |
| #1E3A8A (navy) | 0.051 | white | 8.78 | 5.86 ✓ → 76 % | 4.07 ✓ saffron | |
| #2563EB (bright blue) | 0.153 | white | 4.68 | 3.39 ✗ → 100 % | 2.17 ✗ → white arcs | |
| #C2410C (rust) | 0.153 | white | 4.72 | 3.37 ✗ → 100 % | 2.19 ✗ → white arcs | |
| #DC2626 (red) | 0.167 | white | 4.54 | 3.17 ✗ → 100 % | 2.10 ✗ → white arcs | passes narrowly |
| #0D9488 (teal) | 0.230 | #0A0A0C | 4.73 | 3.69 ✗ → 100 % | 1.60 ✗ → dark arcs | |
| #E8A33D (saffron) | 0.437 | #0A0A0C | 8.10 | 5.49 ✓ → 76 % | 1.05 ✗ → dark arcs | |
| #F5F0E6 (cream) | 0.875 | #0A0A0C | 15.29 | 8.25 ✓ → 76 % | 1.67 ✗ → dark arcs | light-edge border |
| #FFFFFF (white) | 1.000 | #0A0A0C | 17.36 | 8.94 ✓ → 76 % | 1.89 ✗ → dark arcs | light-edge border |
| #6B7280 (slate grey) | 0.167 | – | 4.30 / 3.70 | – | – | **fallback to ink** |
| #808080 (mid grey) | 0.216 | – | 3.54 / 4.48 | – | – | **fallback to ink** |

**Desaturated states** (blocked, expired, replaced): the brand colour's chroma is reduced by **40 %** in OKLCH (lightness and hue unchanged), the sheen is recomputed from the result, the text algorithm runs again. Inactive and zero-balance cards are **not** desaturated (brief §5).

**Shadow:** none. The card is drawn flat, with ID-1 proportions and corner radius (3.18 mm on 85.6 mm), like the printed card.

**Dark theme:** the card colour is identical in both themes (it represents a physical object). It gains the 1-px `color.card.borderDark` outline.

---

## 9. Dark mode and light mode rules

1. **Default: follow system.** Menu (S14) offers System / Light / Dark. The choice is stored per device.
2. **Switching** (system change or Menu) cross-fades all colours over `motion.duration.base` (240 ms, `motion.ease.standard`); no layout change. With Reduce Motion: 160 ms cross-fade (same).
3. **Dark is designed, not inverted.** Hierarchy is carried by surface steps (§6.2), not by shadows. Primary buttons invert (near-white fill, near-black label) — the only large light area in dark mode, which makes the CTA unmistakable.
4. **Saturated colours are lifted in dark** (success #34D399, danger #F87171 …) to keep ≥ 4.5 : 1 on near-black; tone backgrounds become deep tints.
5. **The BalanceCard does not change** between themes (a physical card), except outline vs. shadow.
6. **Illustrations** are single SVGs whose colour roles map to the active theme ([10 §4.5](10-assets-icons-illustrations.md#45-dark-mode-and-high-contrast)); no separate dark files.
7. **Outdoor tip:** Menu shows the info line "Light theme is easier to read in sunlight" (copy in [12-ui-copy-and-error-messages.md](12-ui-copy-and-error-messages.md)). The app never changes screen brightness (brief §9).
8. **Night service:** no automatic dark switch based on time; the OS setting is respected.
9. **System NFC sheet, biometric prompts, permission dialogs** are OS-drawn and follow the OS appearance, which may differ from a forced in-app theme. Accepted.

---

## 10. High-contrast mode

### 10.1 Triggers and changes

Triggered by iOS **Increase Contrast** or Android **High contrast text**. Applied on top of the light or dark theme.

| Element | Normal | High contrast |
|---|---|---|
| `color.fg.secondary` (brief) | #52525B / #A1A1AA | → `color.fg.primary` |
| `color.border.subtle` (brief) | #E4E4E7 / #26262B | → `color.border.strong` (#A1A1AA / #3F3F46) |
| StatusBanner text weight (brief) | title 600, body 400 | body → 600 |
| `color.fg.tertiary` ➕ | #71717A / #8B8B94 | → `color.fg.secondary` normal value (#52525B / #A1A1AA: 7.41 / 7.72 : 1) |
| Input boundary ➕ | `border.control` 1 pt | `border.control` 2 pt |
| SecondaryButton, keypad keys, chips ➕ | fill only | fill + 1 pt `border.control` outline |
| Focus ring ➕ | 2 pt | 3 pt (`border.width.focus.hc`) |
| NFC arcs ➕ | saffron #E8A33D (light) | `color.nfc.arc.hc` #B45309 (4.81 : 1) |
| BalanceCard secondary text ➕ | 76 % opacity | 100 % |
| Skeleton ➕ | sweep | unchanged (not information-bearing) |
| Disabled button label ➕ | `fg.tertiary` | `fg.secondary` normal value |
| Scrim ➕ | 0.48 / 0.64 | 0.64 / 0.72 |

### 10.2 Bold Text

iOS **Bold Text** / Android **Bold text** (Android 12+) raise every Geist weight by one step: 400 → 500, 500 → 600, 600 → 700. Tracking and sizes are unchanged. Amount widths grow ≈ 3 %; the shrink-to-fit rule (§3.7) absorbs it.

---

## 11. Iconography

### 11.1 Style

Lucide-style line icons, drawn on a 24 × 24 grid with 2-pt padding (live area 20 × 20), **round caps and round joins**, 2-pt corner radius on rectangles, no fills, no duotone. Custom glyphs (NFC arcs, card glyph) are drawn to the same grid and stroke rules so they are indistinguishable from the set.

### 11.2 Size tokens

The brief sets the base stroke at **1.75 pt**. To keep visual weight constant across sizes, stroke is size-compensated ➕ (strokes never scale with the icon).

| Token | Size (pt) | Stroke (pt) | Used for |
|---|---|---|---|
| `icon.16` | 16 | 1.5 ➕ | StatusBadge, inline message icon, chevrons in rows, QuickAmountChip |
| `icon.20` | 20 | 1.75 | Regular buttons, Banner, Snackbar leading icon, Spinner size |
| `icon.24` | 24 | **1.75** | Default: TopBar IconButtons, large buttons, StatusBanner, keypad ⌫, TextField trailing |
| `icon.32` | 32 | 2.0 ➕ | BalanceCard NFC glyph, NfcScanAnimation centre glyph, EmptyState small |
| `icon.48` | 48 | 2.5 ➕ | ProblemScreen icon, S16 permission states |

Icons are always placed in a touch target of ≥ 56 × 56 pt when interactive.

### 11.3 Optical alignment

1. **Centre on mass, not on box.** Asymmetric glyphs are nudged toward their visual centre: `delete` (⌫) −1 pt horizontally, `play`-like/arrow glyphs ±1 pt, `nfc` arcs +1 pt toward the open side.
2. **Icon + text:** the icon's vertical centre aligns with the text's **cap-height centre** (not the line box centre), gap `space.2` (8 pt); in badges `space.1` (4 pt).
3. **Icon-only buttons** centre the glyph in the 56-pt target; a circular pressed fill of 44 pt is centred on the same point.
4. **Trailing chevrons** align their tip to the text column edge, not their bounding box.
5. **Stroke alignment:** strokes are centred on the path and snapped so that 1.75-pt strokes at @2x/@3x render crisply (paths on half-pixel positions where needed).

### 11.4 Semantic icon map

| Meaning | Lucide name | Notes |
|---|---|---|
| Close | `x` | top-left on task screens and sheets |
| Recent (shift history) | `history` | TopBar |
| Menu | `menu` | TopBar |
| Delete digit | `delete` | Keypad |
| NFC / tap | custom 3-arc glyph (matches printed card) | never Lucide `wifi` rotated |
| QR scan | `scan-qr-code` | S05 alternative |
| Manual entry | `keyboard` | S05 alternative |
| Card | `credit-card` | illustrations, EmptyState |
| Active | `circle-check` | StatusBadge |
| Inactive | `circle-dashed` | StatusBadge |
| Redeemed (zero balance) | `wallet` | StatusBadge |
| Blocked | `ban` | StatusBadge, banner |
| Expired | `calendar-x` | StatusBadge, banner |
| Replaced | `replace` | StatusBadge, banner |
| Info | `info` | StatusBanner info |
| Warning | `triangle-alert` | StatusBanner warning |
| Error | `circle-alert` | StatusBanner danger, inline over-balance |
| Success | `circle-check` | StatusBanner success |
| Offline | `wifi-off` | Banner |
| Maintenance | `wrench` | Banner |
| Face ID / biometrics | `scan-face` (iOS), `fingerprint` (Android) | S03, S04 |
| Password visibility | `eye` / `eye-off` | TextField |
| Torch | `flashlight` / `flashlight-off` | S12 |
| Help | `circle-help` | Menu |
| Sign out | `log-out` | Menu |

One icon per meaning, everywhere. Icons are never used without text except Close, Recent, Menu, ⌫, Torch, password visibility — each has an accessibility label.

---

## 12. Illustration foundation

**Authoritative source: [10 §4 Illustration style](10-assets-icons-illustrations.md#4-illustration-style-15).** Summary only: illustrations appear where no card is shown (S10/S15 frequent problems, S13 empty, S17 intro); monoline 1.75 pt, round caps and joins, lines in `color.fg.secondary`, **exactly one saffron accent**, no fills, no people/faces/hands, no status colours, gradients, shadows or text. Sizes, inventory, dark/high-contrast mapping and export rules are defined only in 10.

---

## 13. Opacity and state layers

No Material ripple, no iOS highlight flash. Every interactive component defines explicit states.

### 13.1 State model

| State | Visual rule | Timing |
|---|---|---|
| **Pressed** | Fill swaps to the component's `*Pressed` token (`bg.keyPressed`, `action.primaryPressed`, `danger.pressed`), or an 8 % `color.state.pressedOverlay` where no token exists; plus scale: keys **0.96**, buttons **0.98**, chips **0.97**, rows/IconButtons **none** (fill only). Scale origin = centre. | Press-in `motion.instant` 90 ms `ease.standard`; release `motion.fast` 160 ms `ease.decelerate`. Pressed visual must appear within one frame of touch-down, also inside scrollable containers (no delayed-touch behaviour). |
| **Hover** (pointer devices only) | 4 % `color.state.hover` overlay | 90 ms |
| **Focused** (keyboard, switch, screen-reader cursor where the platform shows it) | 2-pt `color.focus.ring` drawn **outside** the component with 2-pt offset, following the component's radius + 2; light theme adds a 2-pt `color.focus.accent` band outside the ring | instant |
| **Disabled** | Explicit colours, not opacity: fill `bg.key`, label/icon `fg.tertiary`. Groups (whole keypad during S08) use `opacity.disabled` 0.40. Disabled elements remain visible to screen readers as "dimmed/disabled". | 160 ms cross-fade |
| **Loading** | Label replaced by Spinner; component inert; width constant | Spinner appears after 150 ms |
| **Selected** (Menu theme segmented choice, toggles) | Fill `action.primary`, label `fg.onAccent` | 160 ms |
| **Dragged** (sheet) | No visual change except position; grabber stays | – |

### 13.2 Opacity tokens ➕

| Token | Value | Use |
|---|---|---|
| `opacity.disabled` | 0.40 | Disabled groups (keypad while redeeming) |
| `opacity.cardSecondary` | 0.76 | Secondary text on BalanceCard (if contrast allows, §8.6) |
| `opacity.placeholder` | 1.00 | Placeholders use `fg.tertiary` at full opacity, never reduced opacity |
| `opacity.pressedOverlay` | 0.08 | See `color.state.pressedOverlay` |
| `opacity.hover` | 0.04 | See `color.state.hover` |
| `opacity.holdTrack.light` / `.dark` | 0.24 / 0.16 | HoldButton track |
| `opacity.skeletonPlaceholder.card` | 0.16 | Placeholder bars on a brand-coloured skeleton card (card text colour at 16 %) |
| `opacity.skeletonHighlight` | 0.08 | Sweep band (fg.primary / card text colour at 8 %) |
| `opacity.nfc.idle` | 0.80 · 0.56 · 0.32 | Inner, middle, outer arc at rest (idle state; the signal fades with distance) |

---

## 14. Z-order and layers

| Layer ➕ | z | Contents | Rules |
|---|---|---|---|
| `z.content` | 0 | Screen content, BalanceCard, Keypad, CTA block | – |
| `z.chrome` | 10 | TopBar, Banner, CountdownHairline | Never shadowed; content scrolls beneath the TopBar |
| `z.scrim` | 20 | Scrim for the first sheet | Fades with the sheet |
| `z.sheet` | 30 | BottomSheet (S13, S14, S15 session expired) | Max one sheet level from the screen … |
| `z.sheetStacked` | 40 | Second sheet (S13 detail) with its own scrim at 0.32 over the first sheet | … plus one stacked level. Never three. |
| `z.snackbar` | 45 | Snackbar | Above sheets (feedback from sheet actions stays visible), below dialogs. Opening a dialog dismisses the snackbar. |
| `z.dialog` | 50 | Dialog + its scrim | Only two dialogs exist (sign-out, switch-card fallback) |
| `z.system` | OS-owned | iOS NFC reader sheet, biometric prompt, OS permission dialogs, Android NFC settings | Always above the app. While a system layer is visible the app shows no snackbar, plays no haptic or sound, and pauses any countdown (CountdownHairline, snackbar timers). |

---

## 15. Motion tokens (summary)

Values are binding; choreography, per-component transitions and Reduce Motion alternatives are in [06-motion-guidelines.md](06-motion-guidelines.md).

| Token | Value | Typical use |
|---|---|---|
| `motion.duration.instant` | 90 ms | Press-in, digit enter |
| `motion.duration.fast` | 160 ms | Release, cross-fades, small state changes, Reduce Motion replacement |
| `motion.duration.base` | 240 ms | Screen transition S05 → S07, sheet scrim, theme switch |
| `motion.duration.slow` | 360 ms | Sheet presentation |
| `motion.duration.emphasis` | 520 ms | Success amount entrance, first-run cards |
| `motion.ease.standard` | cubic-bezier(0.2, 0, 0, 1) | Default for everything that moves and stays |
| `motion.ease.decelerate` | cubic-bezier(0, 0, 0, 1) | Entering elements, release |
| `motion.ease.accelerate` | cubic-bezier(0.3, 0, 1, 1) | Leaving elements |
| `motion.spring.card` | response 0.42 s, damping 0.82 | BalanceCard arrival, SuccessMark halo scale (the circle itself draws in 240 ms, then the check stroke in 200 ms — [06 M18](06-motion-guidelines.md)) |
| `motion.spring.soft` | response 0.55 s, damping 0.9 | Sheets, snackbar |

**Timing tokens ➕** (values taken from the brief where stated):

| Token | Value | Source |
|---|---|---|
| `time.feedbackDelay` | 150 ms | brief §3: skeleton / spinner only after 150 ms |
| `time.lookupSlow` | 3 000 ms | brief §3: "Still looking…" |
| `time.lookupTimeout` | 10 000 ms | brief §3: network error |
| `time.redeemSlow` | 8 000 ms | brief §3: "Connection slow", automatic idempotent retry |
| `time.hold` | 600 ms | brief §1 |
| `time.longPressClear` | 500 ms | keypad ⌫ long-press |
| `time.successReturn` | 4 000 ms | brief §1 |
| `time.cardSwap` | 300 ms | brief §2 (Android new-card cross-fade) |
| `time.snackbar` | 4 000 ms | this document |
| `time.skeletonSweep` | 1 200 ms | this document |
| `time.spinnerTurn` | 800 ms per revolution | this document |
| `time.minIndicator` | 240 ms | an indicator, once shown, stays at least this long (no flicker) |

**Reduce Motion (system):** movement → 160 ms cross-fades; NFC ring pulse and glow off (static arcs); skeleton sweep → static; progress indicators (ProgressRing, HoldButton ring, CountdownHairline, Spinner) **stay**.

---

## 16. Haptic and sound tokens (summary)

Binding tokens; waveform design, loudness, channel handling and settings behaviour in [11-sound-and-haptics.md](11-sound-and-haptics.md).

| Token | Fires when | Paired sound |
|---|---|---|
| `haptic.key` | Keypad key touch-down | none (no key sounds) |
| `haptic.select` | QuickAmountChip applied, ⌫ long-press clear, toggles, segmented choices | none |
| `haptic.cardDetected` | Card read successfully (NFC after read, QR decode, Android new-card swap) | `sound.cardDetected` |
| `haptic.success` | Server confirmed redemption (S09, fires with the first frame of the SuccessMark circle draw — [11](11-sound-and-haptics.md) T3) | `sound.success` |
| `haptic.warning` | Card-state problem shown on S07, over-balance crossed, rejected keypad input, snackbar "Different card detected" (replaces `haptic.cardDetected` for that read) | `sound.warning` for card-state problems only; none for rejected input or over-balance; the switch-card read keeps `sound.cardDetected` |
| `haptic.error` | S10 problem screen appears, redeem failed definitively, scan read error | `sound.error` |
| `haptic.holdTick` | HoldButton at 33 / 66 / 100 % | none |

Rules: at most **one haptic per 100 ms** (the later event wins); no haptic or sound while a `z.system` layer is visible; sound and haptics each switchable in Menu (default ON) and always subordinate to OS silent/vibrate settings.

---

## 17. Loading indicators

### 17.1 Which indicator

| Wait | Indicator |
|---|---|
| < 150 ms | **Nothing.** The UI waits (no flash of loading state). |
| Content with known shape is loading (card lookup) | **Skeleton** of that content |
| An action is in flight inside a control (Sign in, Redeem, Find card) | **Spinner** inside the control, replacing the label |
| App cold start > 1 s (S01) | Spinner (large variant) below the brand mark |
| Long waits (lookup > 3 s, redeem > 8 s) | Keep the indicator, add a status line ("Still looking…", "Connection slow") — thresholds from brief §3 |
| Unknown-length wait without a control | Not allowed — every wait belongs to a control or a skeleton |

### 17.2 Spinner

| Property | Value |
|---|---|
| Sizes | **20 pt** (inline, brief) · 32 pt ➕ (S01, full-screen waits) |
| Stroke | **2 pt** (20 pt) · 3 pt (32 pt), round caps |
| Geometry | Arc of 270° on a full-circle track; track = current colour at 16 %, arc = current colour at 100 % |
| Motion | One revolution per 800 ms, linear; arc length constant (no Material "breathing" arc) |
| Colour | Inherits the foreground of its container (`fg.onAccent` in PrimaryButton, `fg.primary` elsewhere) |
| Reduce Motion | Keeps rotating (it is a progress indicator) |
| Accessibility | Container announces "Loading" / "Redeeming" via its state; the spinner itself is hidden from assistive tech |

### 17.3 Skeleton shimmer

| Property | Value |
|---|---|
| Base | `color.skeleton.base` (= `bg.key`); on a brand-coloured card: card text colour at 16 % |
| Shapes | Mirror the final layout exactly: text lines at the final text's cap height rounded to an even number (e.g. 12 pt for `type.body.l`, 28 pt for the balance), fully rounded ends; blocks use their final radius |
| Sweep | Linear gradient band, **40 % of the container width**, angled 20° from vertical, colour `color.skeleton.highlight` = **8 % highlight** (fg.primary / card text at 8 % over base), fading to transparent at both band edges |
| Motion | Travels leading → trailing edge in **1.2 s, linear**, repeats with no pause; all skeleton shapes on screen share **one** sweep (synchronised, clipped by each shape) |
| Delay | Appears after 150 ms; once shown, stays ≥ 240 ms |
| Reduce Motion | No sweep; static base |
| Accessibility | Container announces "Loading card"; shapes hidden from assistive tech |
| Hand-off | Skeleton → content cross-fade `motion.duration.fast`; no layout shift allowed (identical geometry) |

---

## 18. Progress indicators

| Indicator | Determinacy | Where | Spec |
|---|---|---|---|
| **ProgressRing** | determinate | HoldButton (28 pt), scan-throttled and account-locked countdowns (48 pt) | Stroke 3 pt, round cap, starts at 12 o'clock, clockwise; track + progress colours per context. Full spec in 05. |
| **CountdownHairline** | determinate (time) | S09 auto-return | 2 pt line across the full width at the top of S09 (below the safe area), shrinking from full width to 0 over 4 s, linear; `color.fg.tertiary`. Full spec in 05. |
| **Spinner** | indeterminate | inside controls | §17.2 |

Rules: a determinate indicator is used whenever the duration is known (hold, countdowns). Progress indicators remain under Reduce Motion. Countdowns always also show the remaining time in text (seconds) except the 4-s success return, where the hairline is a courtesy, not information.

---

## 19. System patterns: success and error screens

### 19.1 Severity ladder

Every problem is shown at the lowest level that is still safe. Higher levels interrupt more.

| Level | Pattern | Blocks the flow? | Used for | Haptic / sound |
|---|---|---|---|---|
| 1 | **Inline message** (text + icon beside the control) | no | Over-balance, invalid e-mail, wrong password | `haptic.warning` once when entering the state; no sound |
| 2 | **StatusBanner on S07** (card visible) | partially — Redeem hidden or disabled | Card-state problems: blocked, expired, inactive, replaced, zero balance; max single redemption; velocity limit; redemption uncertain | `haptic.warning` + `sound.warning` (uncertain: `haptic.warning` once, no sound — retries are silent) |
| 3 | **Snackbar** | no | Transient, safe-to-ignore offers: "Different card detected — Switch?" (the iOS scan-timeout hint is inline text on S05, not a snackbar) | `haptic.warning` (instead of `haptic.cardDetected`) + `sound.cardDetected` |
| 4 | **ProblemScreen (S10)** | yes, full screen | No card data: not found, wrong restaurant, verification failed, throttled, network, server | not found, wrong restaurant, verification failed: `haptic.error` + `sound.error` (verification keeps a calm visual); throttled, network, server: `haptic.warning` + `sound.warning` ([11](11-sound-and-haptics.md) E25/E26) |
| 5 | **BottomSheet (S15)** | yes, modal | Session expired | `haptic.warning` |
| 6 | **Full-screen account state (S15/S16)** | yes, persistent | Device revoked, restaurant suspended, account locked/deactivated, update required, NFC unsupported, camera denied | none (not caused by the waiter's last action) |

### 19.2 Success screen pattern (S09)

Anatomy (layout detail in 03b):

```
┌──────────────────────────────────┐
│▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔│ ← CountdownHairline (2 pt, shrinking)
│                                  │
│              ( ✓ )               │ ← SuccessMark 96 pt
│                                  │
│            Redeemed              │ ← success.title · type.title.l
│            € 24,90               │ ← type.amount.l (the amount redeemed)
│                                  │
│   Remaining balance € 7,60       │ ← success.remaining · type.body.l · fg.secondary
│                                  │
│                                  │
│  ┌────────────────────────────┐  │
│  │     Scan next card         │  │ ← iPhone: PrimaryButton (success.next.ios)
│  └────────────────────────────┘  │   Android: text line (success.next.android)
└──────────────────────────────────┘
```

Rules:
1. **Only after server confirmation** — success colour, sound and haptic are never used optimistically.
2. **The amount is the hero**, not the word "Redeemed". The guest may look at the screen: the amount must be readable at arm's length (48 pt).
3. **Remaining balance** is always shown (it is what the guest asks next).
4. **No mention of mistakes, no undo** (brief §1).
5. **Auto-return after 4 s** (`time.successReturn`) with the CountdownHairline; any tap anywhere, or a new card tap on Android, leaves immediately.
6. Success tint: canvas stays neutral; only the SuccessMark carries `color.success`. No green full-screen flood (it reads as a payment terminal "approved" screen and is too loud for the dining room).
7. Screen reader: live-region announcement "Redeemed 24 euro 90. Remaining balance 7 euro 60." (assertive); auto-return is extended per [07-accessibility-guidelines.md](07-accessibility-guidelines.md).

### 19.3 Error screen pattern (S10 ProblemScreen)

```
┌──────────────────────────────────┐
│ ✕                                │ ← TopBar (task): close top-left
│                                  │
│              [icon 48]           │ ← tone icon, no decorative circle
│                                  │
│        Card not found            │ ← title · type.title.l · what happened
│   Check the card and try again,  │ ← body · type.body.l · fg.secondary
│   or enter the number.           │   what to do (max 2 lines)
│                                  │
│          Code 7F3A9C             │ ← optional caption · fg.tertiary (support code)
│                                  │
│  ┌────────────────────────────┐  │
│  │        Scan again          │  │ ← PrimaryButton (the likeliest fix)
│  └────────────────────────────┘  │
│        Enter number instead      │ ← TertiaryButton (the alternative)
└──────────────────────────────────┘
```

Rules:
1. **Title = what happened; body = what to do** — one line each where possible, never more than 2 body lines (brief §7).
2. **Never blame** the waiter or the guest; no error codes as titles. The support code (last 6 characters of `X-Request-Id`, uppercase, e.g. `7F3A9C`) appears as caption only where [12 §2.5](12-ui-copy-and-error-messages.md#25-support-code) lists it (on S10: not found, wrong restaurant, verification failed, server error — never on throttled or network), for support.
3. **Exactly one primary action** (the likeliest recovery) and at most one tertiary alternative.
4. Neutral canvas; the tone lives only in the 48-pt icon (danger for failures, warning for throttling, info for connectivity). Variants with an illustration ([10 §4.4](10-assets-icons-illustrations.md#44-inventory-10-illustrations)) use it instead of the icon; illustrations never carry status colours.
5. **"Please get a manager"** (`getManager`) is the body line for verification failures and wrong-restaurant cards — it is an instruction, not a dead end: the primary action is still "Scan next card".
6. Variants, copy and recovery per error code: [03b-screens-charge-redeem-success-problems.md](03b-screens-charge-redeem-success-problems.md), [12-ui-copy-and-error-messages.md](12-ui-copy-and-error-messages.md).

---

## 20. Navigation model

### 20.1 Structure

```
            S01 Splash
               │
     ┌─────────┴──────────┐
  signed out           signed in
     │                     │
 S02 Sign in ─► S03 ─► S04 Unlock (when required)
                           │
                     ┌─────▼──────┐   sheets (bottom):
                     │ S05 READY  │── S13 Recent ─► S13 detail (stacked)
                     │  (root)    │── S14 Menu ─► Dialog: sign out
                     └─┬──┬──┬────┘
          scan (NFC/QR)│  │  │ manual
                       │  │  └────► S11 Manual entry ─┐
                       │  └───────► S12 QR scan ──────┤
                       ▼                              ▼
                   S07 CHARGE ◄───────────────────────┘
                   (S08 in place)
                    │        │
              success│        │card-data-less problem
                    ▼        ▼
               S09 SUCCESS  S10 PROBLEM
                    │        │
                    └──► back to S05 (replace, not push)
```

- **No tab bar, no drawer, no hamburger navigation.** One root (S05); everything else is a task screen above it, or a sheet.
- **Task screens** (S07, S10, S11, S12) cover the full screen and carry **✕ top-left** (TopBar task variant). ✕ always returns to S05, never "back one step".
- **S09 and S10 replace S07** in the stack; leaving them returns to S05. The stack depth above S05 is never more than one screen.
- **Sheets** (S13, S14, S15 session expired) rise over the current screen; one stacked level maximum (S13 detail).
- **Deep link** (`/c/<token>`, method `link`) opens directly on S07 above S05 (after S04 if unlock is required).

### 20.2 Back gestures and buttons

| Context | iOS | Android |
|---|---|---|
| S05 Ready | No back. | System back moves the app to the background (does not finish it; NFC reader mode resumes instantly on return). |
| S07 Charge (idle / typing) | Interactive edge-swipe from the leading edge = ✕. If an amount is typed, it is discarded silently (nothing has been booked). | System back = ✕; predictive back preview (Android 14+) shows S05 behind. |
| S08 Redeeming (request in flight, or HoldButton pressed) | Edge-swipe **disabled**; ✕ hidden. | System back **consumed** (no action, no feedback beyond the visible spinner). Money in flight is never abandoned by navigation. |
| S09 Success | Edge-swipe = return to S05 immediately. | Back = return to S05 immediately. |
| S10, S11, S12 | Edge-swipe = ✕. | Back = ✕. |
| Sheet | Swipe down, ✕, scrim tap. | Back closes the top-most sheet first; swipe down; scrim tap. |
| Dialog | No swipe; buttons only. Scrim tap = Cancel. | Back = Cancel. |
| S02 Sign in | – | Back exits the app. |
| S04 Unlock | – | Back moves the app to the background. |
| S15/S16 full-screen states | No back (state must be resolved). | Back moves the app to the background. |
| System NFC sheet (iOS) | OS "Cancel" returns to S05 silently. | – |

### 20.3 Close button placement

✕ is **top-left** on every task screen and every sheet (consistent with the left-to-right reading start and away from the Menu/Recent cluster top-right). It is an IconButton (56 pt target, `icon.24`), labelled "Close". It never appears together with a "Back" chevron.

---

## 21. Dialogs vs bottom sheets vs snackbars vs banners — decision table

| Question | Pattern | Blocks? | Dismissal | Allowed uses in v1 |
|---|---|---|---|---|
| Does the waiter need to make an **irreversible choice** right now, with no other context? | **Dialog** | Modal, centred | Buttons; scrim/back = Cancel | Sign-out confirmation (S14) · switch-card confirmation **fallback** when a screen reader or Switch Control is active (the timed snackbar is not accessible enough) |
| Is it **a place with content** (list, settings, details) the waiter opens and closes? | **BottomSheet** | Modal over current screen | Swipe down, ✕, scrim, back | Recent + detail (S13), Menu (S14), Session expired (S15) |
| Is it **short feedback or a one-tap offer** that is safe to ignore? | **Snackbar** | No | Auto 4 s, swipe down, action | "Different card detected — Switch?" (ignoring keeps the current card = safe default); settings saved confirmations in Menu are not shown (toggles are self-evident) |
| Is it a **condition of the app/network** that lasts? | **Banner** | No | Disappears when the condition ends | Offline (S05 variant), maintenance notice (S15) |
| Is it a **condition of this card** that the waiter must tell the guest? | **StatusBanner** on S07 | Replaces or disables the Redeem action | Changes with the card | Blocked, expired, inactive, replaced, zero balance, over max single redemption, velocity limit, redemption uncertain |
| Is there **no card data** to show? | **ProblemScreen** (S10) | Full screen | ✕ or primary action | Not found, foreign, verification failed, throttled, network, server |

Never: dialogs for errors, dialogs for success, snackbars for errors that need action, sheets that contain a single sentence, toasts (Android system toasts are not used).

---

## 22. Banners

System-level banners (`Banner` component) sit directly under the TopBar, full-bleed, and push content down (they never overlay the BalanceCard or the CTA).

| Banner | Tone | Icon | Shown on | Action | Priority |
|---|---|---|---|---|---|
| Offline | info | `wifi-off` | S05, S07 (Redeem disabled), S11 | none (auto-resolves; the app re-checks every 5 s and on network change) | 1 (highest) |
| Maintenance notice | warning | `wrench` | S05, S07 | "Details" opens the notice text in a sheet if the text exceeds 2 lines | 2 |

Rules: **one banner at a time**; the higher priority wins and the other is queued. Appearance and disappearance animate height `motion.duration.base` (Reduce Motion: cross-fade 160 ms). A banner never carries a close ✕ — it reflects a condition, not a message. Live-region announcement (polite) when it appears and when the condition clears ("Connection restored", not a banner, a 2-s screen-reader-only announcement).

---

## Appendix A — Token table (for transcription)

Format: **name · light · dark · notes**. ➕ = added by this document. Values without a dark column are theme-independent.

### A.1 Colour

| Name | Light | Dark | Notes |
|---|---|---|---|
| color.bg.canvas | #FAFAFA | #0A0A0C | |
| color.bg.surface | #FFFFFF | #141417 | |
| color.bg.raised | #FFFFFF | #1C1C21 | |
| color.bg.key | #F1F1F3 | #1E1E23 | |
| color.bg.keyPressed | #E4E4E7 | #2A2A31 | |
| color.fg.primary | #18181B | #F4F4F5 | |
| color.fg.secondary | #52525B | #A1A1AA | HC → fg.primary |
| color.fg.tertiary | #71717A | #8B8B94 | not on bg.key (4.28 light) |
| color.fg.onAccent | #FFFFFF | #0A0A0C | |
| color.border.subtle | #E4E4E7 | #26262B | decorative; HC → border.strong |
| color.border.strong | #A1A1AA | #3F3F46 | not a stand-alone input boundary |
| color.action.primary | #18181B | #F4F4F5 | |
| color.action.primaryPressed | #27272A | #D4D4D8 | |
| color.brand.ink | #0F172A | #0F172A | BalanceCard default/fallback |
| color.accent.saffron | #E8A33D | #F0B454 | never text on light |
| color.accent.saffronText | #B45309 | #F0B454 | |
| color.success | #047857 | #34D399 | |
| color.success.bg | #ECFDF5 | #052E22 | |
| color.danger | #B91C1C | #F87171 | |
| color.danger.bg | #FEF2F2 | #2A0E0E | |
| color.warning | #B45309 | #FBBF24 | |
| color.warning.bg | #FFFBEB | #2A1E06 | |
| color.info | #1D4ED8 | #93C5FD | |
| color.info.bg | #EFF6FF | #0B1A33 | |
| color.scrim | rgba(10,10,12,0.48) | rgba(0,0,0,0.64) | HC 0.64 / 0.72 |
| color.border.control ➕ | #8A8A93 | #71717A | ≥ 3 : 1 input boundary |
| color.focus.ring ➕ | #18181B | #F0B454 | |
| color.focus.accent ➕ | #E8A33D | – | light only, decorative outer band |
| color.hold.progress ➕ | #E8A33D | #B45309 | |
| color.hold.track ➕ | #4F4F52 | #CFCFD0 | |
| color.danger.pressed ➕ | #991B1B | #EF4444 | |
| color.fg.onDanger ➕ | #FFFFFF | #0A0A0C | |
| color.fg.onSuccess ➕ | #FFFFFF | #0A0A0C | |
| color.inverse.bg ➕ | #18181B | #1C1C21 | snackbar |
| color.inverse.fg ➕ | #FFFFFF | #F4F4F5 | |
| color.inverse.action ➕ | #E8A33D | #F0B454 | |
| color.card.borderDark ➕ | – | #26262B | |
| color.skeleton.base ➕ | #F1F1F3 | #1E1E23 | |
| color.skeleton.highlight ➕ | #E0E0E2 | #2F2F34 | 8 % highlight |
| color.state.hover ➕ | rgba(24,24,27,0.04) | rgba(244,244,245,0.04) | |
| color.state.pressedOverlay ➕ | rgba(24,24,27,0.08) | rgba(244,244,245,0.08) | |
| color.nfc.arc.hc ➕ | #B45309 | #F0B454 | high contrast |
| color.camera.overlay ➕ | rgba(0,0,0,0.56) | rgba(0,0,0,0.56) | S12 |

### A.2 Typography

| Name | Value | Notes |
|---|---|---|
| type.amount.xl | Geist 64/68 · 600 · −1.60 pt · tnum | max 130 %, then shrink to min 40 |
| type.amount.l | Geist 48/52 · 600 · −0.96 pt · tnum | max 130 %, shrink min 40 |
| type.balance | Geist 40/44 · 600 · −0.80 pt · tnum | max 130 % |
| type.title.l | Geist 28/34 · 600 · −0.28 pt | max 150 % ➕ |
| type.title.m | Geist 22/28 · 600 · −0.11 pt | max 150 % ➕ |
| type.body.l | Geist 17/24 · 400 · 0 | max 200 % |
| type.body.m | Geist 15/22 · 400 · 0 | max 200 % |
| type.label | Geist 15/20 · 600 · 0 | max 200 % |
| type.label.l ➕ | Geist 17/22 · 600 · 0 | large buttons; max 200 % |
| type.caption | Geist 13/18 · 500 · +0.065 pt · tnum | max 200 % |
| type.overline | Geist 11/14 · 600 · +0.88 pt · uppercase | max 130 % ➕ |
| type.key | Geist 30/36 · 500 · 0 · tnum | max 120 % ➕ |
| type.cardNumber ➕ | Geist Mono 24/32 · 500 · +0.48 pt | S11 only; max 130 %, shrink min 20 |
| type.currency.xl ➕ | Geist 38 · 600 · −0.38 pt | baseline-aligned in amount.xl |
| type.currency.l ➕ | Geist 29 · 600 · −0.29 pt | in amount.l |
| type.currency.balance ➕ | Geist 24 · 600 · −0.24 pt | in balance |
| type.currency.gap.spaced ➕ | 0.16 em of amount size | de-AT, de-DE, de-CH |
| type.currency.gap.tight ➕ | 0.04 em of amount size | en-GB, en-US |

### A.3 Spacing, radius, borders

| Name | Value | Notes |
|---|---|---|
| space.0 / .1 / .2 / .3 / .4 / .5 / .6 / .8 / .10 / .12 / .16 | 0 / 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48 / 64 pt | |
| layout.margin.compact | 20 pt | width < 400 |
| layout.margin.regular | 24 pt | 400–599 |
| layout.margin.tablet | 32 pt | ≥ 600 |
| layout.maxContent.tablet ➕ | 560 pt | single-column tablet screens |
| layout.textMeasure.tablet ➕ | 480 pt | body text column |
| layout.compactHeight | < 700 pt | |
| radius.xs / .s / .m / .l / .xl / .sheet / .full | 8 / 12 / 16 / 20 / 28 / 32 / 999 pt | iOS continuous ≥ 16 |
| border.width.hairline ➕ | 1 physical px | |
| border.width.default ➕ | 1 pt | |
| border.width.focus ➕ | 2 pt | |
| border.width.focus.hc ➕ | 3 pt | |
| focus.offset ➕ | 2 pt | ring drawn outside |

### A.4 Sizes ➕ (targets and fixed geometry)

| Name | Value | Notes |
|---|---|---|
| size.target.min | 56 × 56 pt | brief |
| size.button.l | 64 pt high (56 compact height) | brief |
| size.button.m | 56 pt high | brief |
| size.key | 72 pt high (52 compact height) | brief |
| size.key.gap | 8 pt | brief (≥ 8) |
| size.topBar | 56 pt | + safe area |
| size.chip | 40 pt visual, 56 pt target | |
| size.badge | 24 pt | |
| size.field | 56 pt | TextField |
| size.cardNumberField | 64 pt | |
| size.row | 64 pt | TransactionRow |
| size.avatar.m / .l | 40 / 56 pt | |
| size.iconButton.fill | 44 pt circle | pressed fill |
| size.grabber | 36 × 5 pt | |
| size.snackbar.min | 56 pt | |
| size.spinner.s / .l | 20 / 32 pt | stroke 2 / 3 |
| size.ring.hold | 28 pt, stroke 3 | |
| size.ring.countdown | 48 pt, stroke 3 | |
| size.successMark | 96 pt | |
| size.hairline.countdown | 2 pt | |
| size.nfc.canvas | 176 × 120 pt (glow may overflow) | arcs r 36 / 56 / 76, stroke 3, 100° sweep |
| size.balanceCard.maxHeight | 220 pt | brief (phones) |
| size.balanceCard.compact | 88 pt | `BalanceCard / compact` (strip): compact height, font scale ≥ 130 %, reduced window height |
| icon.16 / .20 / .24 / .32 / .48 | stroke 1.5 / 1.75 / 1.75 / 2.0 / 2.5 | base stroke 1.75 (brief) |

### A.5 Elevation, opacity, layers

| Name | Light | Dark | Notes |
|---|---|---|---|
| elev.0 | none | none | |
| elev.1 | 0 1 2 rgba(0,0,0,.04) | surface step + hairline | |
| elev.2 | 0 4 16 rgba(0,0,0,.08) | surface step + hairline | |
| elev.3 | 0 12 32 rgba(0,0,0,.12) | surface step + hairline | sheets cast upward |
| opacity.disabled ➕ | 0.40 | 0.40 | groups only |
| opacity.cardSecondary ➕ | 0.76 | 0.76 | if ≥ 4.5 : 1 |
| opacity.pressedOverlay ➕ | 0.08 | 0.08 | |
| opacity.hover ➕ | 0.04 | 0.04 | |
| opacity.skeletonHighlight ➕ | 0.08 | 0.08 | |
| opacity.skeletonPlaceholder.card ➕ | 0.16 | 0.16 | |
| opacity.holdTrack ➕ | 0.24 | 0.16 | |
| opacity.nfc.idle ➕ | 0.80 / 0.56 / 0.32 | same | inner / middle / outer |
| z.content / chrome / scrim / sheet / sheetStacked / snackbar / dialog ➕ | 0 / 10 / 20 / 30 / 40 / 45 / 50 | same | z.system OS-owned |

### A.6 Motion, time, haptics, sound

| Name | Value | Notes |
|---|---|---|
| motion.duration.instant / fast / base / slow / emphasis | 90 / 160 / 240 / 360 / 520 ms | |
| motion.ease.standard | (0.2, 0, 0, 1) | |
| motion.ease.decelerate | (0, 0, 0, 1) | |
| motion.ease.accelerate | (0.3, 0, 1, 1) | |
| motion.spring.card | response 0.42 s, damping 0.82 | |
| motion.spring.soft | response 0.55 s, damping 0.9 | |
| time.feedbackDelay ➕ | 150 ms | |
| time.lookupSlow ➕ | 3 000 ms | |
| time.lookupTimeout ➕ | 10 000 ms | |
| time.redeemSlow ➕ | 8 000 ms | |
| time.hold ➕ | 600 ms | |
| time.longPressClear ➕ | 500 ms | |
| time.successReturn ➕ | 4 000 ms | |
| time.cardSwap ➕ | 300 ms | |
| time.snackbar ➕ | 4 000 ms | |
| time.skeletonSweep ➕ | 1 200 ms linear | |
| time.spinnerTurn ➕ | 800 ms linear | |
| time.minIndicator ➕ | 240 ms | |
| haptic.key / select / cardDetected / success / warning / error / holdTick | see brief §5 and [11-sound-and-haptics.md](11-sound-and-haptics.md) | |
| sound.cardDetected / success / warning / error | see brief §5 and 11 | ≤ 400 ms, ≈ −18 LUFS |

---

Version 1.0 · September 2026 · GiftCard Waiter design specification
