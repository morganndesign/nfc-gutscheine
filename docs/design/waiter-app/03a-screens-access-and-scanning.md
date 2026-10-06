# 03a · Screens — Access & Scanning

GiftCard Waiter · native iOS (iPhone, iPad) and Android (phones, tablets)

This document specifies the screens a waiter passes through **before** a card is on the Charge screen: getting in (S01–S04), the resting screen and every way a card can arrive (S05, S06, S11, S12), the menu (S14), the session/account/permission states that interrupt all of this (S15, S16) and the one-time intro (S17).

| Covered here | Specified elsewhere |
|---|---|
| S01 Splash · S02 Sign in · S03 Enable biometrics · S04 Unlock · S05 Ready (Home) · S06 Scanning · S11 Manual entry · S12 QR scan · S14 Menu sheet · S15 Session & account states · S16 Permission states · S17 First-run intro | S07 Charge · S08 Redeeming · S09 Success · S10 Problem screens · S13 Recent → [03b-screens-charge-redeem-success-problems.md](03b-screens-charge-redeem-success-problems.md) |

Related: token values → [04-design-system.md](04-design-system.md) · component anatomy and states → [05-component-library.md](05-component-library.md) · transition catalogue → [06-motion-guidelines.md](06-motion-guidelines.md) · a11y rules → [07-accessibility-guidelines.md](07-accessibility-guidelines.md) · breakpoints and tablet layouts → [08-responsive-behaviour.md](08-responsive-behaviour.md) · haptic/sound patterns → [11-sound-and-haptics.md](11-sound-and-haptics.md) · all strings → [12-ui-copy-and-error-messages.md](12-ui-copy-and-error-messages.md).

---

## 0. Conventions used in this document

### 0.1 Reference frames

All measurements are in pt (iOS) / dp (Android); 1 pt ≙ 1 dp. Wireframes show y-coordinates from the top edge of the screen.

| Frame | Size | Top inset | Bottom inset | Side margin | Thumb-zone line (55 % of height) |
|---|---|---|---|---|---|
| **iPhone reference** (iPhone 15/16) | 393 × 852 | 59 (Dynamic Island) | 34 (home indicator) | 20 (`< 400`) | y = 469 |
| **iPhone compact** (iPhone SE 3rd gen, height < 700) | 375 × 667 | 20 | 0 | 20 | y = 367 |
| **Android reference** (Pixel 7/8 class) | 412 × 915 | 48 (status bar + cutout) | 24 (gesture bar) | 24 (`400–599`) | y = 503 |
| **Tablet** (iPad 10th gen portrait / Android 10″) | 820 × 1180 | 24 | 20 | 32 (`≥ 600`) | y = 649 |

Rule from the brief: every primary action sits **below the thumb-zone line** (bottom 45 % of the screen). Every interactive element is ≥ 56 × 56 pt. Content column on tablets: max width 480, centred (details in [08-responsive-behaviour.md](08-responsive-behaviour.md)).

**Compact height** (< 700 pt): PrimaryButton large drops to 56, keypad keys to 64, NfcScanAnimation from 200 to 160 (iPhone) / 240 to 176 (Android). No other rule changes.

### 0.2 Shared chrome

**TopBar** (S05 only; 56 high, full width, background `color.bg.canvas`, no divider; a 1 px `color.border.subtle` divider fades in only when content scrolls under it — never on S05, which does not scroll).

```
┌──────────────────────────────────────────┐
│ ←20→ Gasthaus Zum Goldenen H…  [⟲] [LG] ←8→│  56
└──────────────────────────────────────────┘
        restaurant name            Recent Avatar
        type.body.m · 600          IconButton 56  Avatar 36 in a 56 target
```

- Restaurant name: `type.body.m` at weight 600, `color.fg.primary`, single line, tail-truncated, max width = bar width − margin − 2 × 56 − space.2. Not interactive.
- Recent: IconButton 56 (clock-arrow glyph 24, `color.fg.primary`) → opens S13 (see 03b).
- Avatar: initials (2 letters, `type.caption` 600), 36 visual circle, `color.bg.key` fill, `color.fg.primary` text, inside a 56 × 56 target, trailing edge inset space.2 from the side margin so the visual circle aligns to the margin → opens S14.
- Order left → right is fixed; VoiceOver/TalkBack order: restaurant name (heading) → Recent → Menu.

**Navigation bar** (S11, S12): 56 high; IconButton 56 leading (back chevron on S11, close ✕ on S12), title centred `type.body.m` 600 `color.fg.primary`; trailing slot empty or IconButton 56. No large titles.

**Bottom action area**: anchored to the bottom safe-area inset with space.4 (16) padding below the lowest button. Buttons span the content width (screen − 2 × margin). Two buttons side by side use a space.3 (12) gap.

### 0.3 Motion names used here

Names are the transition catalogue of [06-motion-guidelines.md](06-motion-guidelines.md); this document only names trigger, duration token and curve token. Reduce Motion replaces every movement with a 160 ms (`motion.duration.fast`) cross-fade and makes NfcScanAnimation static (rings visible, no pulse).

| Name | Used for | Duration | Curve |
|---|---|---|---|
| `fade-through` | replacing one root screen with another (S01→S02/S04/S05, S04→S05) | `motion.duration.base` 240 | `motion.ease.standard` |
| `push` / `pop` | S05 → S11 / S12 and back | `motion.duration.base` 240 | `motion.ease.standard` (platform-native gesture curve on interactive back) |
| `sheet-rise` / `sheet-fall` | S13, S14, S15 session sheet | rise `motion.spring.soft`; fall `motion.duration.fast` 160 | `motion.spring.soft` / `motion.ease.accelerate` |
| `ring-breathe` | NfcScanAnimation idle (iPhone, low amplitude — 06 M04 iPhone variant) | loop, **2.4 s period** (1.2 s in + 1.2 s out) | sine in-out (06 M04) |
| `ring-pulse` | NfcScanAnimation listening (Android — 06 M04) | loop, **2.4 s period** (1.2 s in + 1.2 s out) | sine in-out (06 M04) |
| `ring-read` | tag discovered, read in progress (Android — 06 M05): arcs scale to 1.06, full opacity | `motion.duration.instant` 90 | `motion.ease.standard` |
| `ring-converge` | successful read (S06): rings converge into the card (06 M06) | `motion.duration.base` 240 | `motion.ease.accelerate` |
| `skeleton-shimmer` | Skeleton while looking up | loop | linear (06) |
| `card-lift` | Skeleton on S05 → BalanceCard on S07 (shared element) | `motion.duration.base` 240 | `motion.spring.card` |
| `banner-in` / `banner-out` | StatusBanner / Banner appearing, disappearing | `motion.duration.base` / `motion.duration.fast` | `motion.ease.decelerate` / `motion.ease.accelerate` |
| `shake` | invalid input (S02 fields, S11 field) — 06 M02 | `motion.duration.base` 240 | `motion.ease.standard` (±6 pt, 2 cycles) |
| `press` | every button/key pressed state | `motion.duration.instant` 90 | `motion.ease.standard` (scale: keys 0.96, buttons 0.98, chips 0.97 — [04 §13.1](04-design-system.md); colour → pressed token) |
| `crossfade-state` | a state change inside one screen (e.g. Ready → Offline) | `motion.duration.fast` 160 | `motion.ease.standard` |

### 0.4 Copy

Existing keys from the brief are used verbatim (`ready.android.title`, `ready.ios.button`, `ios.sheet.alert`, `offline.title`, `offline.body`, `session.expired`, `getManager`). New strings are shown as `key` + DE / EN / BHS on first use and collected in § 13. German is primary; no "Sie/du"; no exclamation marks.

---

## 1. S01 · Splash

**Purpose.** Bridge from OS launch to the first real screen while the app restores the session, reads `GET /app/config` and decides the route. It is a continuation of the OS launch screen, not a loading screen.

### Entry / exit

| From | Trigger | To | Condition |
|---|---|---|---|
| OS launch (cold start) | app icon or card link (universal link / App Link) | S01 | always on cold start |
| S01 | routing done (≤ 600 ms target) | S15 Update required | `/app/config` says installed version < minimum |
| S01 | routing done | S02 Sign in | no stored token |
| S01 | routing done | S04 Unlock | token present, biometrics enabled |
| S01 | routing done | S05 Ready | token present, biometrics not enabled (or not available) |
| S01 | routing done | S07 Charge (03b) | token present, biometrics not enabled, launched by `/c/<token>` link |

Warm starts (app still in memory) never show S01: < 15 min in background → last screen; > 15 min → S04 (if biometrics enabled).

`/app/config` is requested with a 1 000 ms budget; if it has not answered, routing continues with the cached config (or none) and the check completes in the background (update-required can then replace the current screen via S15).

### Portrait layout (iPhone reference)

```
y=0    ┌─────────────────────────────┐
       │ status bar                  │  59
y=59   │                             │
       │                             │
y=378  │          ◈ brand mark       │  96 × 96, centred on screen centre (y 426)
y=474  │                             │
       │                             │
y=762  │           (spinner)         │  Spinner 20, only after 1 000 ms; centre y = 852 − 34 − 56
       │                             │
y=852  └─────────────────────────────┘
```

- The brand mark is the app icon glyph without the icon plate, 96 × 96, exactly matching the static OS launch screen (iOS launch storyboard; Android 12+ SplashScreen API icon at its standard 240 dp container, glyph area 160 dp — on Android the OS draws the mark, so its size follows the platform, not the 96 pt above).
- No text, no version, no restaurant name.

### Visual hierarchy
1. Brand mark · 2. (after 1 s only) Spinner · 3. nothing else.

### Typography
None visible. Accessibility label only.

### Colours

| Element | Token | Light | Dark |
|---|---|---|---|
| Background | `color.bg.canvas` | #FAFAFA | #0A0A0C |
| Brand mark | `color.fg.primary` | #18181B | #F4F4F5 |
| Spinner | `color.fg.tertiary` | #71717A | #8B8B94 |

Theme follows the stored Menu choice once the app runs; the OS launch screen can only follow the system theme, so a forced-light user on a dark system sees a dark launch frame and a 160 ms `crossfade-state` into light — accepted.

### Components
Spinner (inline 20 pt, 2 pt stroke) only.

### States

| State | Behaviour |
|---|---|
| Normal (≤ 600 ms) | brand mark only, then `fade-through` to the target |
| Slow (> 1 000 ms) | Spinner fades in (`motion.duration.fast`) below the brand mark |
| Very slow (> 4 000 ms, e.g. keychain/keystore locked on first unlock after reboot) | continue routing with local data only; never block on network |
| Error (config unreachable) | silent; routing uses cache; no error shown on S01 |
| Empty / disabled | n/a |

### Animations & transitions
- Exit: `fade-through` (`motion.duration.base`, `motion.ease.standard`); the brand mark scales 1.00 → 0.96 and fades out during the first 120 ms.
- Spinner in: `crossfade-state` (`motion.duration.fast`).
- Reduce Motion: no scale, 160 ms cross-fade.

### Micro-interactions
None; touches are ignored.

### Haptic / Sound
None / none.

### Accessibility
- The screen exposes one element: label `splash.loading` "Wird geladen" / "Loading" / "Učitavanje", trait image; not announced unless the spinner appears (> 1 s), then a single polite announcement of the same label.
- Dynamic Type: n/a.

New strings (S01):

| Key | DE | EN | BHS |
|---|---|---|---|
| `splash.loading` (a11y) | Wird geladen | Loading | Učitavanje |

### Tablet / Landscape / Portrait
- Tablet: identical, centred; brand mark stays 96. Tablets may launch in landscape; the mark is centred in whatever orientation the OS gives.
- Landscape: phones portrait-locked; S01 never appears in landscape on phones.
- Portrait: as wireframe; compact height: mark stays centred, spinner at y = height − bottom inset − 56.

### Android vs iPhone
- **Android:** uses the SplashScreen API (Android 12+) with icon background `color.bg.canvas`; on Android 9–11 an equivalent themed window background. The app's own S01 frame must be pixel-identical so the hand-off is invisible.
- **iPhone:** static launch storyboard; the app's S01 view replicates it.

### Time required
Target ≤ 0.6 s from icon tap to first interactive frame of the next screen (warm device); budget from the brief: open → Ready 0.4 s when warm and unlocked.

### Acceptance criteria
- [ ] No visible jump (size, position, colour) between the OS launch frame and S01.
- [ ] Spinner never appears when routing completes in ≤ 1 000 ms.
- [ ] S01 never waits for `/app/config` longer than 1 000 ms.
- [ ] Routing table above is honoured in all 5 cases; a `/c/<token>` launch lands on S07 (unlocked) or on S04 with the card kept pending.
- [ ] No text on the screen; VoiceOver/TalkBack reads "Loading" only after 1 s.

---

## 2. S02 · Sign in

**Purpose.** Get a waiter from zero to a device-bound session with e-mail + password. The restaurant is derived from the account; the app never asks for it.

### Entry / exit

| From | Trigger | To |
|---|---|---|
| S01 | no token | S02 |
| S04 | "Use password" / biometrics changed | S02 (e-mail prefilled) |
| S15 | session expired sheet → "Sign in again"; device revoked → "Sign in"; account deactivated → "Back to sign in" | S02 (e-mail prefilled where known) |
| S14 | sign out confirmed | S02 (empty) |
| S02 | "Forgot password?" | in-app browser (SFSafariViewController / Chrome Custom Tab) on the web reset page; closing returns to S02 unchanged |
| S02 | success, device has enrolled biometrics, biometrics not yet offered on this install | S03 |
| S02 | success, otherwise, first run on this install | S17 |
| S02 | success, otherwise | S05 (or S07 if a card link is pending) |
| S02 | 423 ACCOUNT_LOCKED | S02 locked state (S15 · § 10.4) |
| S02 | 403 account deactivated | S15 Account deactivated |

A successful sign-in with an e-mail different from the previous session's clears Recent before S05 is shown.

### Portrait layout (iPhone reference, keyboard hidden)

```
y=0    ┌──────────────────────────────────┐
       │ status bar                        │ 59
y=59   │ ◈ 32                              │ brand row 56 (mark 32, left, centred vertically)
y=115  │ space.8 32                        │
y=147  │ Anmelden                          │ title  type.title.l  34
y=181  │ space.2 8                         │
y=189  │ Mit dem Mitarbeiterkonto anmelden │ subtitle type.body.m  22
y=211  │ space.8 32                        │
y=243  │ [StatusBanner slot – 0 when empty]│ (when shown: 56–78 + space.4)
y=243  │ E-Mail                            │ label  type.caption 18
y=265  │ ┌──────────────────────────────┐  │ space.1 4 → TextField 56
y=265  │ │ lukas@goldener-hirsch.at     │  │
y=321  │ └──────────────────────────────┘  │
y=333  │ space.3 12                        │
y=333  │ Passwort                          │ label 18
y=355  │ ┌──────────────────────────[👁]┐  │ TextField 56 with trailing IconButton 56
y=411  │ └──────────────────────────────┘  │
y=419  │ space.2 8                         │
y=419  │ Passwort vergessen?               │ TertiaryButton 56 (left-aligned text, 56 target)
y=475  │                                   │ flex 263
y=738  │ ┌──────────────────────────────┐  │
       │ │           Anmelden           │  │ PrimaryButton large 64
y=802  │ └──────────────────────────────┘  │
y=802  │ space.4 16                        │
y=818  │ home indicator 34                 │
y=852  └──────────────────────────────────┘
```

**Keyboard visible** (e-mail keyboard ≈ 336 pt incl. suggestion bar on the reference iPhone): the PrimaryButton rides on top of the keyboard with space.4 (16) above the keyboard's top edge; the form scrolls so the focused field sits ≥ space.6 (24) above the button. Brand row and subtitle may scroll off; the title stays if height allows.

```
y=147  │ Anmelden                          │
       │ …                                 │
y=265  │ [ E-Mail field (focused) ]        │
y=355  │ [ Passwort field ]                │
y=436  │ [        Anmelden        ]        │ 64, bottom = keyboard top − 16
y=516  │▒▒▒▒▒▒▒▒ keyboard ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│
```

### Visual hierarchy
1. Title "Anmelden" · 2. the two fields and the PrimaryButton · 3. subtitle, "Forgot password?".

### Typography

| Element | Token |
|---|---|
| Title | `type.title.l` |
| Subtitle | `type.body.m` |
| Field labels | `type.caption` |
| Field text | `type.body.l` |
| Placeholder (none — labels are always visible; no placeholder text) | — |
| Inline field error | `type.caption` |
| "Forgot password?" | `type.label` |
| Button | `type.label` large (17/22) |
| StatusBanner text | `type.body.m` (600 under high contrast) |

### Colours

| Element | Token | Light | Dark |
|---|---|---|---|
| Background | `color.bg.canvas` | #FAFAFA | #0A0A0C |
| Title, field text | `color.fg.primary` | #18181B | #F4F4F5 |
| Subtitle, labels | `color.fg.secondary` | #52525B | #A1A1AA |
| TextField fill | `color.bg.surface` | #FFFFFF | #141417 |
| TextField border (rest) | `color.border.control` | #8A8A93 | #71717A |
| TextField border (focus, 2 pt) | `color.focus.ring` ([05](05-component-library.md); saffron alone is < 3:1 on light surface) | #18181B | #F0B454 |
| Caret | `color.fg.primary` | #18181B | #F4F4F5 |
| TextField border (error, 2 pt) + error text | `color.danger` | #B91C1C | #F87171 |
| Show-password glyph | `color.fg.secondary` | #52525B | #A1A1AA |
| "Forgot password?" | `color.fg.primary` (underline on press) | #18181B | #F4F4F5 |
| PrimaryButton | `color.action.primary` / text `color.fg.onAccent` | #18181B / #FFFFFF | #F4F4F5 / #0A0A0C |
| PrimaryButton pressed | `color.action.primaryPressed` | #27272A | #D4D4D8 |
| PrimaryButton disabled | `color.bg.key` fill, `color.fg.tertiary` text | #F1F1F3 / #71717A | #1E1E23 / #8B8B94 |
| StatusBanner danger | `color.danger.bg` / `color.danger` | #FEF2F2 / #B91C1C | #2A0E0E / #F87171 |
| StatusBanner info (offline) | `color.info.bg` / `color.info` | #EFF6FF / #1D4ED8 | #0B1A33 / #93C5FD |

### Components
TextField × 2 (radius.s, height 56, inner padding space.4), IconButton 56 (show/hide password, inside the password field's trailing edge), TertiaryButton, PrimaryButton large, StatusBanner (danger / info) in the slot above the fields, Spinner inside the PrimaryButton while signing in.

### Field rules
- E-mail: e-mail keyboard, no auto-capitalisation, no autocorrect, return key "Next" → password; trimmed on submit; format checked only on submit or on blur after a value was entered (never while typing).
- Password: secure entry, return key "Go" → submit when both fields are non-empty; show/hide toggles plain text (label switches between `signIn.password.show` / `signIn.password.hide`).
- Autofill: iOS content types username / password (Password AutoFill and passkey-free); Android autofill hints e-mail / password. A password manager fill + "Go" must be possible without touching the button.
- The device name and platform are sent automatically (OS device name); no field.

### States

| State | What changes | Copy |
|---|---|---|
| Empty (initial) | PrimaryButton disabled until both fields are non-empty | — |
| Prefilled (from S04/S15) | e-mail filled, focus on password, keyboard up | — |
| Filled | button enabled | `signIn.submit` |
| Loading | button shows Spinner (after 150 ms) replacing the label, width unchanged; fields read-only (not greyed); back gestures ignored | a11y: "Signing in" |
| Error · e-mail format | e-mail field red border + `shake`, inline error under the field | `signIn.error.emailFormat` |
| Error · 401 wrong credentials | danger StatusBanner in the slot, password cleared, focus to password, `shake` on the password field | `signIn.error.invalid` |
| Error · 403 FORBIDDEN (no redeem ability) | danger StatusBanner | `signIn.error.noPermission` |
| Error · 403 deactivated | → S15 Account deactivated | — |
| Error · 423 ACCOUNT_LOCKED | → locked state, § 10.4 | `locked.*` |
| Error · 429 TOO_MANY_REQUESTS | danger StatusBanner with live countdown from `retry_after`; button disabled and labelled with the countdown | `signIn.error.throttled` |
| Error · 5xx / timeout (8 s) | danger StatusBanner; button re-enabled | `signIn.error.server` |
| Offline | info StatusBanner (`offline.title` + `signIn.offline.body`), button disabled; auto-clears when connectivity returns | — |
| Disabled | see Empty / Offline / Throttled | — |

Mini wireframe — banner shown (slot expands, fields move down by banner height + space.4):

```
y=243  ┌ ⚠ E-Mail oder Passwort stimmt nicht.        ┐  StatusBanner danger, 2 lines = 78
       └   Bitte prüfen und erneut versuchen.         ┘
y=337  E-Mail  …                                         (fields shifted by 94)
```

New strings:

| Key | DE | EN | BHS |
|---|---|---|---|
| `signIn.title` | Anmelden | Sign in | Prijava |
| `signIn.subtitle` | Mit dem Mitarbeiterkonto anmelden | Use your staff account | Prijavite se računom zaposlenika |
| `signIn.email.label` | E-Mail | E-mail | E-mail |
| `signIn.password.label` | Passwort | Password | Lozinka |
| `signIn.password.show` | Passwort anzeigen | Show password | Prikaži lozinku |
| `signIn.password.hide` | Passwort verbergen | Hide password | Sakrij lozinku |
| `signIn.forgot` | Passwort vergessen? | Forgot password? | Zaboravljena lozinka? |
| `signIn.submit` | Anmelden | Sign in | Prijavi se |
| `signIn.error.emailFormat` | E-Mail-Adresse prüfen | Check the e-mail address | Provjerite e-mail adresu |
| `signIn.error.invalid` | E-Mail oder Passwort stimmt nicht. Bitte prüfen und erneut versuchen. | E-mail or password is incorrect. Check both and try again. | E-mail ili lozinka nisu ispravni. Provjerite i pokušajte ponovo. |
| `signIn.error.noPermission` | Dieses Konto kann keine Karten einlösen. Bitte einen Manager holen. | This account can't redeem cards. Please get a manager. | Ovaj račun ne može iskorištavati kartice. Molimo pozovite menadžera. |
| `signIn.error.throttled` | Zu viele Versuche. Erneut möglich in {time}. | Too many attempts. Try again in {time}. | Previše pokušaja. Ponovo za {time}. |
| `signIn.error.server` | Anmelden gerade nicht möglich. Gleich noch einmal versuchen. | Can't sign in right now. Try again in a moment. | Prijava trenutno nije moguća. Pokušajte ponovo za trenutak. |
| `signIn.offline.body` | Anmelden braucht eine Internetverbindung. | Signing in needs a connection. | Za prijavu je potrebna veza. |
| `signIn.loading` (a11y) | Anmeldung läuft | Signing in | Prijava u toku |

### Animations & transitions
- Enter from S01/S14/S15: `fade-through`. Enter from S04: `fade-through` (not a push — S02 replaces S04 as root).
- Keyboard: the button and form follow the OS keyboard animation curve and duration exactly (not a token — platform-native).
- StatusBanner: `banner-in` (height grows from 0 while fading in, `motion.duration.base`, `motion.ease.decelerate`); `banner-out` on next edit of any field.
- Invalid field: `shake` (`motion.duration.base`, 06 M02).
- Exit on success: `fade-through` to S03 / S17 / S05.
- Reduce Motion: no shake (border colour + error text only); banners cross-fade.

### Micro-interactions
- Buttons use `press`.
- Tapping anywhere outside fields dismisses the keyboard.
- The show/hide toggle keeps the caret position.
- After a 401, the password field is cleared but the e-mail is kept and not re-validated.
- Countdown labels update every second, `tnum` so width never jitters.

### Haptic
| Event | Token |
|---|---|
| Sign-in success | none (the next screen is the reward; keeps S03/S05 calm) |
| 401 / 403 / 429 / 5xx banner | `haptic.error` |
| E-mail format error | `haptic.warning` |
| Show/hide toggle | `haptic.select` |

### Sound
None on S02 (sounds are reserved for card events; see [11-sound-and-haptics.md](11-sound-and-haptics.md)).

### Accessibility
- Focus order: title (heading) → subtitle → StatusBanner (if present) → e-mail → password → show/hide → "Forgot password?" → Sign in.
- Fields expose their visible label as accessibility label; error text is attached as the field's hint/error so it is read with the field.
- StatusBanner appearance: assertive live announcement of its full text.
- Loading: button label changes to `signIn.loading`, trait "busy/not enabled".
- Dynamic Type to 200 %: labels, field text and button grow; fields grow in height (min 56); the screen scrolls; the PrimaryButton stays pinned above keyboard/safe area. Title wraps to 2 lines max, then scales down to fit.
- Password manager and switch control fully supported; no custom gestures.

### Tablet / Landscape / Portrait
- Tablet: form column max width 480, centred horizontally; vertical block (title → button) centred in the safe area; the button sits directly below "Forgot password?" with space.8 instead of being bottom-anchored (thumb zone is irrelevant at tablet size in a stand). With keyboard up, the column scrolls so the button stays visible.
- Landscape (tablets only): same centred column; if the keyboard leaves < 320 pt, title and subtitle scroll away.
- Portrait (phones): as wireframe; compact height: brand row removed, title at safe top + space.6, PrimaryButton 56.

### Android vs iPhone
- **Android:** back gesture on S02 exits the app (S02 is root); IME action "Next"/"Done"; autofill framework; "Forgot password?" opens a Chrome Custom Tab tinted `color.bg.canvas`.
- **iPhone:** keyboard toolbar suppressed (no "Done" bar); Password AutoFill QuickType bar allowed; SFSafariViewController with `color.fg.primary` controls tint.

### Time required
Target: ≤ 8 s with password-manager autofill; ≤ 25 s typed. Server round-trip budget 1.5 s before the Spinner is joined by nothing else (no "slow" copy; timeout at 8 s → `signIn.error.server`).

### Acceptance criteria
- [ ] Only two fields exist; no restaurant field, no device-name field.
- [ ] PrimaryButton disabled until both fields are non-empty; enabled state reachable with password-manager fill alone.
- [ ] Button remains fully visible above the keyboard at every Dynamic Type size on the compact frame.
- [ ] 401 clears only the password and moves focus there; e-mail kept.
- [ ] 423 and 429 show a live countdown and re-enable the button exactly when it reaches 0.
- [ ] "Forgot password?" opens the web reset page in an in-app browser and returns to S02 with fields unchanged.
- [ ] Offline banner appears within 2 s of losing connectivity and clears automatically on reconnect.
- [ ] After success the route is S03 (first time, biometrics enrolled) → S17 (first run) → S05, each shown at most once per install.
- [ ] No sound on any S02 event; haptics as tabled.

---

## 3. S03 · Enable biometrics

**Purpose.** Offer Face ID / Touch ID / Android biometric unlock exactly once per install, right after the first successful sign-in, so every later start is one glance instead of a password.

### Entry / exit

| From | Trigger | To |
|---|---|---|
| S02 | first successful sign-in on this install **and** the device has enrolled biometrics (iOS: biometry available; Android: BIOMETRIC_STRONG or BIOMETRIC_WEAK available and enrolled) | S03 |
| S03 | "Use Face ID" → OS prompt succeeds | S17 (first run) or S05 / S07 (pending link) |
| S03 | "Not now" | same as above; biometrics stay off (can be turned on later — Proposal (not part of v1): a Menu row; in v1 only by signing out and in again) |
| S03 | OS prompt cancelled / failed | stays on S03 (error state) |

S03 is **skipped** when no biometrics are enrolled, when biometrics are locked out, or when S03 was already shown on this install (flag survives sign-out; cleared only by reinstall).

### Portrait layout (iPhone reference)

```
y=0    ┌──────────────────────────────────┐
       │ status bar                        │ 59
y=59   │ flex 185                          │
y=244  │            ╭──────╮               │ glyph plate 96 × 96, radius.full
       │            │  ⌾   │               │ Face ID / Touch ID / fingerprint glyph 48
y=340  │            ╰──────╯               │
y=364  │   Mit Face ID entsperren?         │ title type.title.l, centred, ≤ 2 lines (34/68)
y=398  │ space.3 12                        │
y=410  │  Schneller Start in jede Schicht. │ body type.body.l, centred, ≤ 2 lines (48)
y=458  │  Das Passwort bleibt als Altern…  │
       │ flex 216                          │
y=674  │ ┌──────────────────────────────┐  │ PrimaryButton large 64
       │ │       Face ID verwenden      │  │
y=738  │ └──────────────────────────────┘  │
y=746  │ space.2 8                         │
y=746  │          Jetzt nicht              │ TertiaryButton 56, full width target
y=802  │ space.4 16                        │
y=818  │ home indicator 34                 │
y=852  └──────────────────────────────────┘
```

The text block is centred in the space between the safe top and PrimaryButton top − space.8 (32).

### Visual hierarchy
1. Title question · 2. PrimaryButton · 3. glyph, body, "Not now".

### Typography
Title `type.title.l` · body `type.body.l` · PrimaryButton `type.label` large · TertiaryButton `type.label`.

### Colours

| Element | Token | Light | Dark |
|---|---|---|---|
| Background | `color.bg.canvas` | #FAFAFA | #0A0A0C |
| Glyph plate | `color.bg.key` | #F1F1F3 | #1E1E23 |
| Glyph | `color.fg.primary` | #18181B | #F4F4F5 |
| Title | `color.fg.primary` | #18181B | #F4F4F5 |
| Body | `color.fg.secondary` | #52525B | #A1A1AA |
| PrimaryButton | `color.action.primary` / `color.fg.onAccent` | #18181B / #FFFFFF | #F4F4F5 / #0A0A0C |
| TertiaryButton text | `color.fg.primary` | #18181B | #F4F4F5 |
| Inline error | `color.danger` | #B91C1C | #F87171 |

### Components
PrimaryButton large, TertiaryButton, a static glyph plate (no component — illustration). OS biometric prompt (system UI).

### States

| State | Behaviour | Copy |
|---|---|---|
| Default | as wireframe | see strings |
| Prompt showing | the OS prompt overlays; S03 content stays static; buttons not interactive | OS reason string `biometrics.reason` |
| Error (cancelled / not recognised) | caption under the body in `color.danger` with ⚠ glyph; buttons re-enabled; no automatic re-prompt | `biometrics.failed` |
| Loading / empty / disabled | n/a (instant) | — |

Variants by capability (only the glyph and the two strings change; layout identical):

| Variant | Glyph | Title key | Button key |
|---|---|---|---|
| iPhone Face ID | Face ID glyph | `biometrics.title.faceId` | `biometrics.enable.faceId` |
| iPhone Touch ID (SE) | fingerprint | `biometrics.title.touchId` | `biometrics.enable.touchId` |
| Android (any class 3/class 2) | fingerprint + face combined glyph | `biometrics.title.android` | `biometrics.enable.android` |

New strings:

| Key | DE | EN | BHS |
|---|---|---|---|
| `biometrics.title.faceId` | Mit Face ID entsperren? | Unlock with Face ID? | Otključavati pomoću Face ID-a? |
| `biometrics.title.touchId` | Mit Touch ID entsperren? | Unlock with Touch ID? | Otključavati pomoću Touch ID-a? |
| `biometrics.title.android` | Mit Biometrie entsperren? | Unlock with biometrics? | Otključavati biometrijom? |
| `biometrics.body` | Schneller Start in jede Schicht. Das Passwort bleibt als Alternative. | A faster start to every shift. Your password still works as a fallback. | Brži početak svake smjene. Lozinka ostaje kao zamjena. |
| `biometrics.enable.faceId` | Face ID verwenden | Use Face ID | Koristi Face ID |
| `biometrics.enable.touchId` | Touch ID verwenden | Use Touch ID | Koristi Touch ID |
| `biometrics.enable.android` | Biometrie verwenden | Use biometrics | Koristi biometriju |
| `biometrics.notNow` | Jetzt nicht | Not now | Ne sada |
| `biometrics.reason` | Zum Entsperren von GiftCard Waiter | To unlock GiftCard Waiter | Za otključavanje aplikacije GiftCard Waiter |
| `biometrics.failed` | Nicht bestätigt. Noch einmal versuchen. | Not confirmed. Try again. | Nije potvrđeno. Pokušajte ponovo. |

### Animations & transitions
- Enter: `fade-through` from S02. Exit: `fade-through` to S17/S05.
- Error caption: `crossfade-state` (`motion.duration.fast`).

### Micro-interactions
`press` on both buttons. "Use Face ID" disables both buttons while the OS prompt is up (prevents double prompts).

### Haptic
Success → `haptic.success` is **not** used (it is reserved for redemptions); the OS gives its own biometric feedback. Error caption → `haptic.warning`.

### Sound
None.

### Accessibility
- Focus order: title (heading) → body → PrimaryButton → TertiaryButton. Glyph is decorative (hidden).
- Error caption: polite live announcement.
- Dynamic Type 200 %: title and body wrap freely; the text block scrolls if needed; buttons stay pinned bottom.

### Tablet / Landscape / Portrait
- Tablet: centred column max 480; buttons directly below the body with space.10 (40); iPad Face ID prompt is the system HUD.
- Landscape: tablets only; same column.
- Portrait (phones): as wireframe; compact: glyph plate 72 (glyph 36), PrimaryButton 56.

### Android vs iPhone
- **Android:** BiometricPrompt with allowed authenticators BIOMETRIC_STRONG | BIOMETRIC_WEAK | DEVICE_CREDENTIAL (passcode fallback via OS); prompt title = `biometrics.title.android` without "?", negative button handled by the OS.
- **iPhone:** first use triggers the one-time OS Face ID permission with the `biometrics.reason` string (Info.plist usage description). If the user denies it, S03 shows the error state and "Use Face ID" becomes "Not now"-equivalent (biometrics off) — no dead ends.

### Time required
Target ≤ 4 s (read, tap, glance).

### Acceptance criteria
- [ ] Shown only once per install, only after the first sign-in, only when biometrics are enrolled.
- [ ] Declining never blocks progress; the waiter reaches S05 in one tap.
- [ ] Correct glyph and strings per capability variant.
- [ ] No re-prompt loop: a failed/cancelled prompt waits for a new tap.
- [ ] Buttons are inside the thumb zone on all phone frames.

---

## 4. S04 · Unlock

**Purpose.** Let the owner of the device back in on cold start and after > 15 min in background, with the OS biometric prompt appearing **immediately on appear** and no extra tap.

### Entry / exit

| From | Trigger | To |
|---|---|---|
| S01 | cold start, token present, biometrics enabled | S04 |
| any screen | app returns from background after > 15 min (measured from backgrounding), biometrics enabled | S04 (covers the app; the screen underneath is restored after unlock, except S08 — see 03b) |
| OS | card link `/c/<token>` opened while locked | S04 with pending-card banner |
| S04 | biometric success | previous screen, or S05 on cold start, or S07 if a card link is pending |
| S04 | "Use password" | S02 (e-mail prefilled) |
| S04 | biometric enrolment changed since enabling (iOS domain state / Android key invalidated) | S02 with the `unlock.changed` banner |
| S04 | token rejected on first API call after unlock (401) | S15 session expired sheet |

Unlock is local (keychain / keystore). It needs no network; an offline unlock lands on S05 in its Offline variant.

### Portrait layout (iPhone reference)

```
y=0    ┌──────────────────────────────────┐
       │ status bar                        │ 59
y=59   │ flex 220                          │
y=279  │             ( LG )                │ Avatar 72, initials type.title.m
y=351  │ space.4 16                        │
y=367  │          Lukas Gruber             │ name type.title.m, centred
y=395  │ space.1 4                         │
y=399  │   Gasthaus Zum Goldenen Hirschen  │ restaurant type.body.m, fg.secondary
y=421  │ flex                              │
y=598  │ [ StatusBanner info – optional ]  │ pending card / biometrics changed (60) + space.4
y=674  │ ┌──────────────────────────────┐  │
       │ │   Mit Face ID entsperren     │  │ PrimaryButton large 64
y=738  │ └──────────────────────────────┘  │
y=746  │        Passwort verwenden         │ TertiaryButton 56
y=802  │ space.4 16                        │
y=852  └──────────────────────────────────┘
```

The OS prompt appears on top (iOS: the Face ID HUD in the screen centre over the avatar block; Android: BiometricPrompt bottom sheet covering the lower part). The S04 content underneath must still make sense when the prompt is dismissed.

### Visual hierarchy
1. Waiter name (who is unlocking) · 2. PrimaryButton (re-trigger) · 3. restaurant, "Use password".

### Typography
Avatar initials `type.title.m` · name `type.title.m` · restaurant `type.body.m` · banner `type.body.m` · buttons `type.label` (large for PrimaryButton).

### Colours

| Element | Token | Light | Dark |
|---|---|---|---|
| Background | `color.bg.canvas` | #FAFAFA | #0A0A0C |
| Avatar fill / initials | `color.bg.key` / `color.fg.primary` | #F1F1F3 / #18181B | #1E1E23 / #F4F4F5 |
| Name | `color.fg.primary` | #18181B | #F4F4F5 |
| Restaurant | `color.fg.secondary` | #52525B | #A1A1AA |
| Pending-card banner | `color.info.bg` / `color.info` | #EFF6FF / #1D4ED8 | #0B1A33 / #93C5FD |
| PrimaryButton | `color.action.primary` / `color.fg.onAccent` | #18181B / #FFFFFF | #F4F4F5 / #0A0A0C |

### Components
Avatar (72 variant), StatusBanner (info), PrimaryButton large, TertiaryButton, OS biometric prompt.

### States

| State | Behaviour | Copy |
|---|---|---|
| Appear | OS prompt requested on the first rendered frame (≤ 100 ms after appear); buttons disabled while it is up | `biometrics.reason` |
| Prompt cancelled | buttons enabled; no auto re-prompt (avoids loops); a tap on PrimaryButton re-prompts | `unlock.button.*` |
| Biometric failure (OS retries exhausted) | OS falls back to device passcode (iOS device-owner authentication / Android DEVICE_CREDENTIAL); passcode success = unlock | OS |
| Biometric lockout | PrimaryButton triggers passcode directly; label unchanged | — |
| Biometrics changed | skip prompt, go to S02 with info banner | `unlock.changed` |
| Pending card (link) | info StatusBanner above the PrimaryButton | `unlock.pendingCard` |
| Loading / empty / error | none of its own (no network) | — |

New strings:

| Key | DE | EN | BHS |
|---|---|---|---|
| `unlock.button.faceId` | Mit Face ID entsperren | Unlock with Face ID | Otključaj pomoću Face ID-a |
| `unlock.button.touchId` | Mit Touch ID entsperren | Unlock with Touch ID | Otključaj pomoću Touch ID-a |
| `unlock.button.android` | Entsperren | Unlock | Otključaj |
| `unlock.usePassword` | Passwort verwenden | Use password | Koristi lozinku |
| `unlock.changed` | Biometrie wurde auf diesem Gerät geändert. Bitte mit Passwort anmelden. | Biometrics changed on this device. Sign in with your password. | Biometrija je promijenjena na ovom uređaju. Prijavite se lozinkom. |
| `unlock.pendingCard` | Die Karte wird nach dem Entsperren geöffnet. | The card opens after unlocking. | Kartica se otvara nakon otključavanja. |

### Animations & transitions
- Enter from S01: `fade-through`. Enter over a backgrounded app: S04 is already in place when the app becomes visible (the app-switcher snapshot is replaced by an S04-styled privacy cover — no card data, balances or Recent ever visible in the switcher).
- Exit on success: `fade-through` (`motion.duration.base`); if returning to S07 via link, `card-lift` is not used — plain `fade-through`.

### Micro-interactions
`press` on both buttons; the Avatar is not interactive.

### Haptic / Sound
OS biometric feedback only; no app haptic, no app sound.

### Accessibility
- Focus order: name (heading, read together with restaurant: "Lukas Gruber, Gasthaus Zum Goldenen Hirschen") → banner → PrimaryButton → "Use password".
- When the OS prompt is dismissed, focus moves to the PrimaryButton.
- VoiceOver users: the OS announces Face ID state; the app adds nothing.
- Dynamic Type: name/restaurant wrap to 2 lines; avatar stays 72.

### Tablet / Landscape / Portrait
- Tablet: centred column 480; buttons below the text block with space.10.
- Landscape: tablets only.
- Portrait: compact: Avatar 56, PrimaryButton 56.

### Android vs iPhone
- **Android:** BiometricPrompt (bottom sheet) with the waiter's first name in the subtitle; system back while the prompt is up cancels it; back on S04 exits the app.
- **iPhone:** Face ID HUD / Touch ID alert; the app requests evaluation on `didBecomeActive`, never while inactive (avoids the "prompt appears under the Control Center" bug).

### Time required
Target ≤ 1.0 s from app visible to previous screen (Face ID ≈ 0.5 s + `fade-through` 0.24 s).

### Acceptance criteria
- [ ] OS prompt appears without any tap within 100 ms of S04 becoming active.
- [ ] Background > 15 min → S04; ≤ 15 min → no S04.
- [ ] App-switcher snapshot never shows balances, card numbers or Recent.
- [ ] Cancelled prompt never re-opens automatically.
- [ ] Changed biometrics force password sign-in.
- [ ] A pending card link survives unlock and opens S07 for that card.
- [ ] Works fully offline.

---

## 5. S05 · Ready (Home)

**Purpose.** The resting screen for the whole shift. It must say one thing — *a card can be scanned now* — and make the next card reachable with zero taps (Android) or one thumb tap (iPhone). Everything else (Recent, Menu, manual entry, QR) is secondary.

### Entry / exit

| From | Trigger | To |
|---|---|---|
| S01 / S03 / S04 / S17 | route complete | S05 |
| S02 | sign-in success (after S03/S17 when due) | S05 |
| S07 (03b) | close ✕ / back | S05 |
| S09 (03b) | 4 s auto-return or tap | S05 |
| S10 (03b) | dismiss action | S05 |
| S11 / S12 | back / close | S05 (`pop`) |
| S13 / S14 | sheet dismissed | S05 (sheet falls, S05 was underneath) |
| S05 | Android: card tapped (reader mode) | S06 inline reading state → S07 or S10 |
| S05 | iPhone: "Scan card" | S06 system sheet → S07 or S10 |
| S05 | "Card number" | S11 (`push`) |
| S05 | "QR code" | S12 (`push`) |
| S05 | Recent IconButton | S13 sheet |
| S05 | Avatar | S14 sheet |
| S05 | any API 401 / DEVICE_REVOKED / RESTAURANT_SUSPENDED / update-required config | S15 |
| S05 | NFC switched off (Android) / NFC unavailable | S05 variant (S16) |
| OS | card link `/c/<token>` while unlocked | S07 directly (method `link`) |

### 5.1 Portrait layout — iPhone · Ready (reference 393 × 852)

```
y=0    ┌─────────────────────────────────────────┐
       │ status bar / Dynamic Island              │ 59
y=59   ├─────────────────────────────────────────┤
       │ Gasthaus Zum Goldenen H…      [⟲] [LG]  │ TopBar 56
y=115  ├─────────────────────────────────────────┤
       │ [Banner slot · 0 when empty]             │
       │ flex 142                                 │
y=257  │               ╭ ─ ─ ╮                    │
       │             (  ( ◉ )  )                  │ NfcScanAnimation 200 × 200, idle (ring-breathe)
y=457  │               ╰ ─ ─ ╯                    │
y=457  │ space.6 24                               │
y=481  │   Nach dem Tippen die Karte oben an das  │ hint type.body.m, centred, ≤ 2 lines (44)
y=525  │   iPhone halten                          │
       │ flex 141                                 │
─ ─ ─ ─│─ ─ ─ ─ thumb-zone line y=469 ─ ─ ─ ─ ─ ─ │
y=666  │ ┌─────────────────────────────────────┐ │
       │ │  ⌁  Karte scannen                   │ │ PrimaryButton large 64, NFC glyph 24 + label
y=730  │ └─────────────────────────────────────┘ │
y=730  │ space.4 16                               │
y=746  │ ┌────────────────┐ ┌──────────────────┐ │
       │ │ ⌨ Kartennummer │ │ ▦ QR-Code        │ │ SecondaryButton 56 × 170.5, gap space.3
y=802  │ └────────────────┘ └──────────────────┘ │
y=802  │ space.4 16                               │
y=818  │ home indicator 34                        │
y=852  └─────────────────────────────────────────┘
```

Rules: the animation + hint block is vertically centred between the TopBar (or Banner) bottom and the PrimaryButton top, flex split 1 : 1. The PrimaryButton and the SecondaryButton row are bottom-anchored and never move when banners appear.

### 5.2 Portrait layout — Android · Listening (reference 412 × 915)

```
y=0    ┌─────────────────────────────────────────┐
       │ status bar                               │ 48
y=48   ├─────────────────────────────────────────┤
       │ Gasthaus Zum Goldenen Hir…    [⟲] [LG]  │ TopBar 56
y=104  ├─────────────────────────────────────────┤
       │ [Banner slot]                            │
       │ flex 167                                 │
y=271  │            ╭ ─ ─ ─ ─ ╮                   │
       │          (  (  ( ◉ )  )  )               │ NfcScanAnimation 240 × 240, listening (ring-pulse)
y=511  │            ╰ ─ ─ ─ ─ ╯                   │
y=511  │ space.6 24                               │
y=535  │     Karte an das Handy halten            │ ready.android.title  type.title.l, ≤ 2 lines (34/68)
y=569  │ space.2 8                                │
y=577  │   Die Karte wird automatisch erkannt     │ hint type.body.m (22, ≤ 2 lines)
y=599  │ flex 204                                 │
y=803  │ space.4 16                               │
y=819  │ ┌────────────────┐ ┌──────────────────┐ │
       │ │ ⌨ Kartennummer │ │ ▦ QR-Code        │ │ SecondaryButton 56 × 176, gap space.3
y=875  │ └────────────────┘ └──────────────────┘ │
y=875  │ space.4 16                               │
y=891  │ gesture bar 24                           │
y=915  └─────────────────────────────────────────┘
```

Rules: flex split 45 : 55 above/below the block (the block sits slightly above centre, the visual centre of a hand-held phone). No PrimaryButton on Android Ready — the card itself is the action.

### 5.3 Visual hierarchy
- **Android:** 1. NfcScanAnimation + title (the instruction) · 2. hint · 3. SecondaryButtons, TopBar.
- **iPhone:** 1. PrimaryButton "Scan card" · 2. NfcScanAnimation (tells *where* the card goes) · 3. hint, SecondaryButtons, TopBar.

### 5.4 Typography

| Element | Token |
|---|---|
| Restaurant name (TopBar) | `type.body.m`, weight 600 |
| Avatar initials | `type.caption`, weight 600 |
| Android title | `type.title.l` |
| Hint / tip / timeout text | `type.body.m` |
| PrimaryButton label | `type.label` large (17/22) |
| SecondaryButton labels | `type.label` (15/20) |
| Banner title / body | `type.body.m` 600 / `type.body.m` |

### 5.5 Colours

| Element | Token | Light | Dark |
|---|---|---|---|
| Background | `color.bg.canvas` | #FAFAFA | #0A0A0C |
| TopBar text, icons | `color.fg.primary` | #18181B | #F4F4F5 |
| Avatar fill | `color.bg.key` | #F1F1F3 | #1E1E23 |
| NfcScanAnimation arcs + glow | `color.accent.saffron` (glow at 24 % → 0 %) | #E8A33D | #F0B454 |
| NfcScanAnimation centre glyph | `color.fg.primary` | #18181B | #F4F4F5 |
| Android title | `color.fg.primary` | #18181B | #F4F4F5 |
| Hint | `color.fg.secondary` | #52525B | #A1A1AA |
| First-card tip text + glyph | `color.info` | #1D4ED8 | #93C5FD |
| PrimaryButton | `color.action.primary` / `color.fg.onAccent` | #18181B / #FFFFFF | #F4F4F5 / #0A0A0C |
| SecondaryButton | `color.bg.key` / `color.fg.primary` | #F1F1F3 / #18181B | #1E1E23 / #F4F4F5 |
| SecondaryButton pressed | `color.bg.keyPressed` | #E4E4E7 | #2A2A31 |
| Disabled (any button) | `color.bg.key` fill at 100 %, label `color.fg.tertiary` | #F1F1F3 / #71717A | #1E1E23 / #8B8B94 |
| Banner (maintenance) | `color.warning.bg` / `color.warning` | #FFFBEB / #B45309 | #2A1E06 / #FBBF24 |
| Disabled rings (NFC off / offline) | `color.border.strong` | #A1A1AA | #3F3F46 |

Saffron is never used for text on light backgrounds; the saffron glow is decorative and needs no contrast ratio; the centre glyph carries the 3:1 UI contrast.

### 5.6 Components
TopBar, Avatar, IconButton (Recent), NfcScanAnimation (states used here: `idle`, `listening`, `reading`, `disabled` — anatomy in [05-component-library.md](05-component-library.md)), PrimaryButton large (iPhone only), SecondaryButton × 2 (56), Banner (maintenance), StatusBanner, Skeleton (looking-up), Spinner, Snackbar, TertiaryButton (cancel lookup).

SecondaryButton content: leading glyph 20 (keyboard / QR) + label, centred; labels `ready.manual`, `ready.qr`.

### 5.7 Variants and states

| # | Variant | Trigger | Layout change | Copy |
|---|---|---|---|---|
| V1 | **Android · listening** | Android, NFC on, online | § 5.2 | `ready.android.title`, `ready.android.hint` |
| V2 | **iPhone · ready** | iPhone, NFC reading available, online | § 5.1 | `ready.ios.button`, `ready.ios.hint` |
| V3 | **Reading / looking up** | card read (both) | see S06 § 6.1 and § 6.4 | `scan.lookingUp`, `scan.slow` |
| V4 | **NFC off** (Android) | NFC adapter present, disabled | mini wireframe V4 | `nfcOff.*` (S16) |
| V5 | **NFC unsupported / iPad** | no NFC hardware, iPad, or iPhone `readingAvailable = false` | mini wireframe V5 | `ready.noNfc.*` |
| V6 | **Offline** | no connectivity for ≥ 2 s | mini wireframe V6 | `offline.title`, `offline.body` |
| V7 | **Maintenance banner** | `/app/config` carries a notice | Banner in slot | server text, fallback `maintenance.default` |
| V8 | **First card of the shift hint** | no successful card read on this device since 04:00 local | hint line replaced by tip (no layout change) | `ready.firstCardTip.android` / `.ios` |
| V9 | **Keep screen on** | Menu setting ON (default) | none (behaviour only) | — |
| V10 | **iPhone · scan timed out / cancelled** | reader session timed out (≈ 60 s) | hint line replaced for 6 s | `ready.ios.timeout` |
| V11 | **iPhone · NFC temporarily unavailable** | session could not start (system busy, e.g. during a call) | hint line replaced until next tap | `scan.unavailable` |

Priority when several apply: V4/V5 (hardware) > V6 (offline) > V3 (reading) > V10/V11 > V8 > V1/V2. V7 (banner) and V9 combine with every variant.

**Loading:** S05 has no loading state of its own (it renders from local data). **Empty:** V1/V2 *are* the empty state. **Error:** delegated — card errors go to S07/S10 (03b), account errors to S15.

#### V4 · NFC off (Android)

```
y=104  ├─────────────────────────────────────────┤
       │ flex                                     │
y=287  │          (  ( ⊘ )  )                     │ NfcScanAnimation disabled, 240, static grey arcs, NFC-off glyph
y=527  │ space.6                                  │
y=551  │            NFC ist aus                   │ nfcOff.title  type.title.l
y=593  │   NFC einschalten, um Karten zu scannen. │ nfcOff.body   type.body.m
       │ flex                                     │
y=739  │ ┌─────────────────────────────────────┐ │ PrimaryButton large 64: nfcOff.action
y=803  │ └─────────────────────────────────────┘ │ space.4
y=819  │ [ Kartennummer ]   [ QR-Code ]          │ SecondaryButtons stay enabled
y=875  └─────────────────────────────────────────┘
```

Behaviour and deep link: S16 § 11.1.

#### V5 · NFC unsupported / iPad

```
y=115  ├─────────────────────────────────────────┤
       │ flex                                     │
y=281  │          ╭──────────╮                    │ QR glyph plate 160 × 160, radius.xl, color.bg.key; QR glyph 72
y=441  │          ╰──────────╯                    │
y=465  │   QR-Code auf der Karte scannen          │ ready.noNfc.title  type.title.l (≤ 2 lines)
y=507  │   Dieses Gerät hat kein NFC. QR-Code …   │ ready.noNfc.hint   type.body.m (2 lines)
       │ flex                                     │
y=666  │ ┌─────────────────────────────────────┐ │ PrimaryButton large 64: ▦ ready.noNfc.button → S12
y=730  │ └─────────────────────────────────────┘ │ space.4
y=746  │ ┌─────────────────────────────────────┐ │ SecondaryButton 56, full width: ⌨ ready.manual → S11
y=802  │ └─────────────────────────────────────┘ │
y=852  └─────────────────────────────────────────┘
```

No NfcScanAnimation anywhere; the "QR code" SecondaryButton is removed because it became the PrimaryButton.

#### V6 · Offline

```
y=115  ├─────────────────────────────────────────┤
       │ flex                                     │
y=257  │          (  ( ☁̸ )  )                    │ NfcScanAnimation disabled (static grey arcs, cloud-off glyph)
y=481  │           Keine Verbindung               │ offline.title  type.title.l
y=523  │  Einlösen braucht Internet, damit nie    │ offline.body   type.body.m, 2 lines
       │  doppelt gebucht wird.                   │
y=666  │ [        Karte scannen  (disabled)     ] │ iPhone only
y=746  │ [ Kartennummer (disabled) ][ QR-Code (d)]│
y=852  └─────────────────────────────────────────┘
```

- Entered after 2 s of confirmed no connectivity (OS reachability + a failed request), `crossfade-state`; left immediately when a connectivity probe to the API succeeds; on leaving, a Snackbar `ready.online` for 2 s and a polite announcement.
- Android: reader mode **stays on** while offline so a tapped card is not routed to the browser; a tap gives `haptic.warning` + `sound.warning` and the Snackbar `ready.offline.tap` (2.5 s). No lookup is attempted.
- Recent (TopBar) and Menu stay available offline.
- Probing: every 5 s while S05 is visible (backoff to 30 s after 2 min), plus on every OS connectivity change.

#### V7 · Maintenance banner

```
y=115  ├─────────────────────────────────────────┤
y=123  │ ┌ ⚠ Wartung heute 23:00–23:30.  ──  [✕]┐│ Banner (warning), 1–2 lines: 56–78, radius.m, inset side margin
y=179  │ └────────────────────────────────────── ┘│
y=195  │ (space.4 · centred block re-centres in the remaining space)
```

- Text comes from `/app/config` in the device language if provided, else EN; max 140 characters, 2 lines, tail-truncated with the full text in the accessibility label.
- Dismiss ✕ (IconButton 56, a11y `maintenance.dismiss`) hides it until the notice text changes or the app cold-starts.
- Never blocks scanning; if the API is actually down the normal S10 errors apply.

#### V8 · First card of the shift hint
- Shown while no card has been **read successfully** on this device since the business day started (04:00 local). Disappears (`crossfade-state`) after the first successful read and does not come back that day.
- Replaces the hint line in place: info glyph 16 + text in `color.info`, `type.body.m`, ≤ 2 lines. No layout change, no dismiss control.

#### V9 · Keep screen on
- While S05, S07 or S09 is visible and the app is unlocked and foreground, the OS idle timer is suspended (setting "Keep screen on", default ON, S14).
- Released immediately when: the app backgrounds, S04/S02/S15 is shown, S11/S12 is shown, or the setting is off.
- No visible indicator on S05. The app never changes screen brightness.
- Proposal (not part of v1): release after 30 min without any interaction to save battery.

#### V10 · iPhone scan timed out
The hint line changes to `ready.ios.timeout` (`crossfade-state`) for 6 s or until the next tap anywhere, then returns to `ready.ios.hint`. No haptic, no sound (the waiter may have simply walked away).

New strings (S05):

| Key | DE | EN | BHS |
|---|---|---|---|
| `topBar.recent` (a11y) | Verlauf | Recent | Nedavno |
| `topBar.menu` (a11y) | Menü, {name} | Menu, {name} | Meni, {name} |
| `ready.android.hint` | Die Karte wird automatisch erkannt | The card is detected automatically | Kartica se automatski prepoznaje |
| `ready.ios.hint` | Nach dem Tippen die Karte oben an das iPhone halten | After tapping, hold the card near the top of the iPhone | Nakon dodira prislonite karticu na vrh iPhonea |
| `ready.ios.timeout` | Keine Karte erkannt. Zum Wiederholen „Karte scannen“ tippen. | No card detected. Tap “Scan card” to try again. | Kartica nije prepoznata. Dodirnite „Skeniraj karticu“ za novi pokušaj. |
| `ready.manual` | Kartennummer | Card number | Broj kartice |
| `ready.qr` | QR-Code | QR code | QR kôd |
| `ready.firstCardTip.android` | Tipp: Die NFC-Antenne sitzt meist hinten oben, nahe der Kamera. | Tip: the NFC antenna is usually at the top of the back, near the camera. | Savjet: NFC antena je obično gore na poleđini, blizu kamere. |
| `ready.firstCardTip.ios` | Tipp: Die Karte flach an die Oberkante halten, nahe der Kamera. | Tip: hold the card flat against the top edge, near the camera. | Savjet: držite karticu ravno uz gornji rub, blizu kamere. |
| `ready.noNfc.title` | QR-Code auf der Karte scannen | Scan the QR code on the card | Skenirajte QR kôd na kartici |
| `ready.noNfc.hint` | Dieses Gerät hat kein NFC. QR-Code oder Kartennummer verwenden. | This device has no NFC. Use the QR code or the card number. | Ovaj uređaj nema NFC. Koristite QR kôd ili broj kartice. |
| `ready.noNfc.button` | QR-Code scannen | Scan QR code | Skeniraj QR kôd |
| `ready.offline.tap` | Keine Verbindung – Karte kann nicht geprüft werden | No connection — the card can't be checked | Nema veze – kartica se ne može provjeriti |
| `ready.online` | Wieder verbunden | Connected again | Veza je ponovo uspostavljena |
| `maintenance.default` | Geplante Wartung: Einlösen kann kurz nicht möglich sein. | Scheduled maintenance: redeeming may be briefly unavailable. | Planirano održavanje: iskorištavanje može kratko biti nedostupno. |
| `maintenance.dismiss` (a11y) | Hinweis schließen | Dismiss notice | Zatvori obavijest |

### 5.8 Animations & transitions

| Name | Trigger | Duration | Curve |
|---|---|---|---|
| `ring-pulse` | V1 visible (loop; paused when app inactive or a sheet covers > 50 %) | loop, 2.4 s period (06 M04) | sine in-out (06 M04) |
| `ring-breathe` | V2 visible (loop, lower amplitude: glow 12 % ↔ 24 %, no ring expansion) | loop, 2.4 s period (06 M04) | sine in-out (06 M04) |
| `crossfade-state` | switching V1/V2 ↔ V4/V5/V6, hint ↔ tip ↔ timeout | `motion.duration.fast` | `motion.ease.standard` |
| `banner-in` / `banner-out` | V7 | `motion.duration.base` / `motion.duration.fast` | decelerate / accelerate |
| `push` | → S11, S12 | `motion.duration.base` | `motion.ease.standard` |
| `sheet-rise` | → S13, S14 | `motion.spring.soft` | — |
| `fade-through` | S09 auto-return → S05 | `motion.duration.base` | `motion.ease.standard` |

Reduce Motion: rings static at their rest values (scale 1.0, arcs 1.0 / 0.72 / 0.44, glow 32 % — 06 M04); all changes cross-fade in 160 ms.

### 5.9 Micro-interactions
- `press` on every button; the "Scan card" PrimaryButton additionally pushes the NfcScanAnimation into `listening` the moment it is pressed (before the sheet appears) so the eye is drawn to the top of the phone.
- Recent IconButton shows no badge (no counts on the home screen; the count lives in S13's HistoryCard).
- Long-press on any control does nothing (no hidden actions).
- Double-tapping "Scan card" never opens two sessions (disabled until the sheet is dismissed).

### 5.10 Haptic

| Event | Token |
|---|---|
| Card read (Android) | `haptic.cardDetected` (see S06) |
| Card tapped while offline | `haptic.warning` |
| NFC read failed (Android) | none for the 1st–2nd failure; `haptic.warning` after 3 failures within 5 s ([11](11-sound-and-haptics.md) E12/E13) |
| Tap on SecondaryButton / IconButton / Avatar | none (navigation) |
| "Scan card" press | none (the system sheet provides feedback) |
| NFC turned on (returning from settings) | `haptic.select` |

### 5.11 Sound

| Event | Token |
|---|---|
| Card read (Android) | `sound.cardDetected` |
| Card tapped while offline | `sound.warning` |
| Everything else on S05 | none |

### 5.12 Accessibility
- **Focus order:** TopBar (restaurant name, heading) → Recent → Menu (Avatar) → Banner (if any) → [Android: title, hint] / [iPhone: hint] → PrimaryButton (iPhone) → Card number → QR code. The NfcScanAnimation is decorative and hidden; the Android title carries the meaning.
- **Labels:** Recent: `topBar.recent`; Avatar: `topBar.menu` with the waiter's full name, trait button; PrimaryButton: `ready.ios.button` with hint `ready.ios.hint`; SecondaryButtons: their visible labels.
- **Android title** is a polite live region: V1 → V4/V6 changes are announced ("NFC is off", "No connection").
- **On return to S05** (from S09/S10/S07) focus lands on the Android title / the iPhone PrimaryButton — never on the TopBar — so a screen-reader user can scan the next card at once.
- **Dynamic Type 200 %:** title and hint wrap (title ≤ 3 lines, then shrink-to-fit down to `type.title.m`); the NfcScanAnimation shrinks first (down to 120) to protect text and buttons; SecondaryButtons stack vertically (each full width, space.3 gap) when either label no longer fits on one line; the bottom stack remains anchored; content between TopBar and buttons becomes scrollable only as a last resort.
- **Left-handed:** symmetric; nothing depends on hand.
- **Status never by colour alone:** NFC off, offline and maintenance each carry a glyph and text.

### 5.13 Tablet behaviour
- Content column max width 480, centred; TopBar spans the full width with 32 margins.
- **iPad:** always V5 (no NFC). PrimaryButton "Scan QR code" and SecondaryButton "Card number" sit directly below the text block with space.10 (40) (not bottom-anchored; tablets are typically used on a table or in a stand).
- **Android tablet with NFC:** V1 with NfcScanAnimation 280; the first-card tip says where the antenna usually is (back, centre on most tablets — same string, generic).
- Details in [08-responsive-behaviour.md](08-responsive-behaviour.md).

### 5.14 Landscape behaviour
- Phones: portrait-locked; not applicable.
- Tablets landscape: two columns inside the safe area: left column (50 %) holds the NfcScanAnimation or QR plate centred; right column (max 400) holds title, hint and the buttons, vertically centred. TopBar unchanged.

### 5.15 Portrait behaviour
As § 5.1 / § 5.2. Compact height (iPhone SE): NfcScanAnimation 160, PrimaryButton 56, hint ≤ 2 lines, flex split unchanged (TopBar 20–76, PrimaryButton 523–579, SecondaryButtons 595–651).

### 5.16 Android differences
- Reader mode is enabled for the whole time S05 is visible and foreground (flags: NFC-A, skip NDEF check off, platform sounds suppressed). Also while S13/S14 are open over S05 (a card tap closes the sheet and proceeds as normal — the card always wins).
- No PrimaryButton; title instead.
- System back on S05 moves the app to background (does not sign out, does not close the session).

### 5.17 iPhone differences
- No background listening: PrimaryButton "Scan card" in the thumb zone starts the system NFC sheet (S06).
- Background tag reading and universal links: a card tapped to the iPhone while the app is closed or on another screen opens `/c/<token>` → S07 directly (after S04 if locked).
- V11 exists only on iPhone.

### 5.18 Time required

The loop budgets of brief §3 (≈ 3.5 s Android, ≈ 4.5 s iPhone, [02 §5.1](02-information-architecture-and-journey.md#51-timing-budget)) are measured from the Ready (Home) screen S05 with the app already unlocked; the first row below (app foreground → S05) is not part of them.

| Interaction | Target |
|---|---|
| App foreground (warm, unlocked) → S05 interactive | 0.4 s |
| Android: card on phone → S07 visible | ≤ 0.94 s (0.3 read + ≤ 0.4 API + 0.24 transition) |
| iPhone: tap "Scan card" → S07 visible | ≤ 1.84 s (0.4 tap + 0.3 sheet + 0.5 read + ≤ 0.4 API overlapping the sheet dismissal + 0.24 transition) |
| Reach S11/S12 | 0.24 s |

### 5.19 Acceptance criteria
- [ ] Android: a card tapped within 300 ms of S05 appearing is read (reader mode is active before the first frame is shown).
- [ ] Android Ready has no PrimaryButton; iPhone Ready has "Scan card" fully below the thumb-zone line on every phone frame.
- [ ] "Card number" and "QR code" are SecondaryButtons, 56 high, side by side, equal width (stack only at large Dynamic Type).
- [ ] TopBar shows restaurant name (body.m 600), Recent IconButton and waiter initials Avatar; nothing else. No reload/block/history-of-card action exists anywhere.
- [ ] Variant priority is honoured (e.g. NFC off + offline shows NFC off).
- [ ] Offline: all scan entry points disabled; Android card tap gives warning feedback without routing to the browser; recovery is automatic.
- [ ] Maintenance banner never moves the bottom buttons.
- [ ] First-card tip disappears after the first successful read of the business day and does not reappear before 04:00.
- [ ] Screen stays awake on S05 when the setting is ON; never when OFF; never in background.
- [ ] VoiceOver/TalkBack focus lands on the scan affordance after returning from S09.
- [ ] Reduce Motion: no ring movement.

---

## 6. S06 · Scanning

**Purpose.** Turn a physical tap into card data with unmistakable, fast feedback — inline on Android, inside Apple's system sheet on iPhone — and hand over to Charge (S07) or a problem screen (S10) without a blank frame.

S06 is not a separate screen on Android (it is a state of S05) and is mostly system UI on iPhone. What follows specifies both, plus the shared *looking-up* state that runs after the read on both platforms.

### Entry / exit

| From | Trigger | To |
|---|---|---|
| S05 (Android) | tag discovered in reader mode | S06 reading state |
| S05 (iPhone) | "Scan card" | S06 system sheet |
| S09 (iPhone, 03b) | "Scan next card" | S06 system sheet (opens directly) |
| S06 | lookup 200 with any card state | S07 (03b) — card states and banners are defined there |
| S06 | 404 / 403 foreign / verification failed / 429 throttled / network > 10 s / 5xx | S10 (03b) |
| S06 | 401 / DEVICE_REVOKED / RESTAURANT_SUSPENDED | S15 |
| S06 | user cancels (iPhone sheet Cancel / "Cancel" during slow lookup) | S05 |

### 6.1 Android · inline reading state (timeline)

```
t = 0 ms       tag discovered ─ NfcScanAnimation → reading (ring-read, motion.duration.instant)
               read NDEF URL + UID (typ. ≤ 300 ms)
t = r          read OK ─ haptic.cardDetected + sound.cardDetected · rings converge into the card (ring-converge, 240 ms)
               title → scan.lookingUp · POST /api/v1/scan {method: nfc, token, nfc_uid}
t = r + 150    no response yet ─ crossfade-state → looking-up layout (§ 6.4, Skeleton)
t = r + 3000   caption → scan.slow · TertiaryButton "Cancel" fades in
t = r + 10000  → S10 network error (03b)
response       → S07 (card-lift) or S10 / S15
```

Mini wireframe at t = r (before 150 ms) — only text and animation change, layout identical to § 5.2:

```
y=271  │          (((●)))  arcs solid saffron     │ reading: arcs held at 1.06 (ring-read); converge into the card on read OK
y=535  │      Karte wird gesucht …                │ title swaps to scan.lookingUp
y=577  │   (hint line hidden)                     │
```

Android read problems (inline, stay on S05, return to V1 after 2 000 ms or on the next tap):

| Case | Detection | Title → | Feedback |
|---|---|---|---|
| Read failed (card moved away mid-read, I/O error) | tag lost before URL + UID are read | `scan.readFailed.title` + hint `scan.readFailed.body` | 1st–2nd failure: none; 3 × within 5 s: `haptic.warning`, no sound ([11](11-sound-and-haptics.md) E12/E13); rings return to rest (240 ms, decelerate) — no shake |
| Not a gift card | tag has no NDEF URL, or URL not `https://<domain>/c/<UUID>` | `scan.notCard` | `haptic.warning`, `sound.warning` |
| Same card again within 2 s after a completed read | same UID | ignored silently (card lingering on the phone) | none |
| Another tap while a lookup is in flight | any | ignored silently | none |
| Two cards at once | anti-collision in the NFC controller delivers one tag; a second different UID within 500 ms is ignored | — | — |

### 6.2 iPhone · system NFC sheet

The sheet is Apple UI. We control only its **alert message** and **when/how the session ends**. It appears over S05; the top ~45 % of S05 (TopBar, NfcScanAnimation) remains visible behind it — the animation switches to `listening` so the area above the sheet points to the top of the phone.

**What we control**

| Moment | Our action | Text shown in the sheet (key) | DE | EN | BHS |
|---|---|---|---|---|---|
| Session start | alert message set on begin | `ios.sheet.alert` | Karte oben an das iPhone halten | Hold the card near the top of the iPhone | Prislonite karticu na vrh iPhonea |
| Card read OK, URL valid | alert message updated, then session ended as success → system ✓ | `ios.sheet.found` | Karte gefunden | Card found | Kartica pronađena |
| Read failed (I/O, tag lost) | alert message updated, polling restarted after 400 ms (sheet stays open — no extra tap) | `ios.sheet.readFailed` | Karte nicht gelesen. Erneut versuchen. | Couldn't read the card. Try again. | Kartica nije pročitana. Pokušajte ponovo. |
| More than one tag in the field | alert message updated, polling restarted after 500 ms | `ios.sheet.multiple` | Mehrere Karten erkannt. Nur eine Karte halten. | More than one card detected. Hold only one. | Prepoznato više kartica. Držite samo jednu. |
| Tag is not a gift card | alert message updated, polling restarted after 1 000 ms | `scan.notCard` | Das ist keine Geschenkkarte | This is not a gift card | Ovo nije poklon-kartica |
| 45 s without a card (15 s before the system timeout) | alert message updated | `ios.sheet.timeoutSoon` | Noch keine Karte. Karte flach oben an das iPhone halten. | No card yet. Hold it flat near the top of the iPhone. | Još nema kartice. Prislonite je ravno na vrh iPhonea. |
| System timeout (≈ 60 s) | nothing in the sheet; on dismissal S05 shows V10 silently | `ready.ios.timeout` (on S05) | — | — | — |
| Same card read twice in one session | ignored; session already ending | — | — | — | — |

Rules: alert messages ≤ 60 characters (the sheet wraps at ~2 lines); no amounts, balances or card numbers in the sheet; the lookup request is fired the instant the URL is read — **before** the success message — so the API time overlaps the sheet's ✓ and dismissal.

**What we don't control**

| Aspect | Owner | Consequence for design |
|---|---|---|
| Sheet appearance, size, position, dark/light styling, "Ready to Scan" title, the phone/tag illustration | iOS | our S05 must look right behind any iOS sheet version |
| Sheet "Cancel" button and its label | iOS (localised by system language, not app language) | cancel returns to S05 V2 with no message |
| Detection sound and haptic, ✓ / ✕ animation | iOS | the app plays **no** `sound.cardDetected` / `haptic.cardDetected` on iPhone reads (no double feedback) |
| Session timeout (≈ 60 s) and its dismissal | iOS | we pre-warn at 45 s; after timeout V10 |
| Dismissal duration after success (≈ 0.3–0.6 s) | iOS | lookup runs in parallel; S07 appears right after dismissal |
| Whether a session can start (e.g. during calls, other NFC session active) | iOS | V11 hint `scan.unavailable` on S05 |
| Sheet dismissal on app switch / Control Center | iOS | treated as Cancel |

iPhone timeline:

```
t = 0       tap "Scan card"  (press 90 ms; NfcScanAnimation → listening)
t ≈ 0.3 s   system sheet up, alert = ios.sheet.alert
t = r       URL + UID read → POST /api/v1/scan {method: nfc, token, nfc_uid} fired
            alert = ios.sheet.found → session ends as success → system ✓
t = r+0.3…0.6  sheet dismissed
            lookup done?  yes → S07 (card-lift from NfcScanAnimation position)
                          no  → looking-up state (§ 6.4) until response
```

New strings (S06):

| Key | DE | EN | BHS |
|---|---|---|---|
| `ios.sheet.found` | Karte gefunden | Card found | Kartica pronađena |
| `ios.sheet.readFailed` | Karte nicht gelesen. Erneut versuchen. | Couldn't read the card. Try again. | Kartica nije pročitana. Pokušajte ponovo. |
| `ios.sheet.multiple` | Mehrere Karten erkannt. Nur eine Karte halten. | More than one card detected. Hold only one. | Prepoznato više kartica. Držite samo jednu. |
| `ios.sheet.timeoutSoon` | Noch keine Karte. Karte flach oben an das iPhone halten. | No card yet. Hold it flat near the top of the iPhone. | Još nema kartice. Prislonite je ravno na vrh iPhonea. |
| `scan.notCard` | Das ist keine Geschenkkarte | This is not a gift card | Ovo nije poklon-kartica |
| `scan.readFailed.title` | Karte konnte nicht gelesen werden | Couldn't read the card | Kartica nije pročitana |
| `scan.readFailed.body` | Karte eine Sekunde ruhig halten. | Hold it still for a second. | Držite je mirno jednu sekundu. |
| `scan.detected` (a11y announcement) | Karte erkannt | Card detected | Kartica prepoznata |
| `scan.lookingUp` | Karte wird gesucht … | Looking up card … | Tražimo karticu … |
| `scan.slow` | Suche dauert länger … | Still looking … | Još tražimo … |
| `scan.unavailable` | NFC gerade nicht verfügbar. Kartennummer oder QR-Code verwenden. | NFC isn't available right now. Use the card number or QR code. | NFC trenutno nije dostupan. Koristite broj kartice ili QR kôd. |
| `common.cancel` | Abbrechen | Cancel | Otkaži |

### 6.3 Other card sources (same lookup)
- **Link** (`method: link`) from background tag reading / universal link / Android App Link: skips S05 and S06 visuals; S07 opens with its own Skeleton (03b).
- **QR** (S12) and **manual** (S11) use the looking-up state of their own screens (§ 8, § 7), not S05.

### 6.4 Looking-up state (both platforms, on S05)

Shown when the lookup has not answered 150 ms after the read (Android) or after sheet dismissal (iPhone). The Skeleton occupies exactly the position the BalanceCard will take on S07, so the hand-over is a morph, not a jump.

```
y=59   ├─────────────────────────────────────────┤ TopBar 56 (unchanged)
y=115  │ space.4 16                               │
y=131  │ ┌─────────────────────────────────────┐ │ Skeleton · BalanceCard shape 353 × 220, ID-1 radius
       │ │ ▭▭▭▭                         ◌      │ │ (same geometry as S07 BalanceCard, 03b)
       │ │ ▭▭▭▭▭▭▭▭▭▭                          │ │
       │ │ ▭▭▭▭▭▭▭                              │ │
y=351  │ └─────────────────────────────────────┘ │
y=351  │ space.6 24                               │
y=375  │         ◌  Karte wird gesucht …          │ Spinner 20 + scan.lookingUp type.body.m fg.secondary
       │                                          │ (after 3 s: scan.slow)
       │ flex                                     │
y=746  │ [              Abbrechen               ] │ TertiaryButton 56, only after 3 s (replaces the
y=802  │                                          │ SecondaryButton row; iPhone PrimaryButton hidden)
y=852  └─────────────────────────────────────────┘
```

- During looking-up, the SecondaryButtons and (iPhone) PrimaryButton are hidden (not disabled) so they cannot be tapped by accident; the Cancel TertiaryButton appears at 3 s in the same area.
- Cancel aborts the request (it is a read, nothing is booked) and returns to V1/V2 with `crossfade-state`.
- On response: `card-lift` — Skeleton morphs into the BalanceCard (`motion.duration.base`, `motion.spring.card`), the keypad of S07 rises from below. If the response is a problem without card data, `fade-through` to S10.

### 6.5 Visual hierarchy
Android reading: 1. converged saffron rings · 2. title "Looking up card …" · 3. nothing else. Looking-up: 1. Skeleton card · 2. status caption · 3. Cancel.

### 6.6 Typography
Title (Android) `type.title.l`; status caption `type.body.m`; Cancel `type.label`. Sheet typography is system.

### 6.7 Colours

| Element | Token | Light | Dark |
|---|---|---|---|
| Rings (reading) | `color.accent.saffron` at 100 %, glow 32 % | #E8A33D | #F0B454 |
| Rings (read failed / not a card) | `color.warning` | #B45309 | #FBBF24 |
| Skeleton base | `color.bg.key` | #F1F1F3 | #1E1E23 |
| Skeleton shimmer highlight | `color.bg.keyPressed` | #E4E4E7 | #2A2A31 |
| Caption | `color.fg.secondary` | #52525B | #A1A1AA |
| Spinner | `color.fg.tertiary` | #71717A | #8B8B94 |
| Warning title (read failed) | `color.fg.primary` + warning glyph `color.warning` | #18181B / #B45309 | #F4F4F5 / #FBBF24 |

### 6.8 Components
NfcScanAnimation (`listening` → `reading`), Skeleton (balance card variant), Spinner, TertiaryButton, system NFC sheet (iPhone).

### 6.9 States summary

| State | Android | iPhone |
|---|---|---|
| Loading (read) | reading rings | system sheet |
| Loading (lookup) | reading → Skeleton at 150 ms | Skeleton after dismissal (if still pending) |
| Slow (> 3 s) | `scan.slow` + Cancel | same |
| Error (read) | inline warning 2 s | message in sheet, polling restarts |
| Error (lookup) | S10 / S15 | S10 / S15 |
| Empty / disabled | n/a | "Scan card" disabled while a session is active |

### 6.10 Animations & transitions
`ring-read` (tag discovered, `motion.duration.instant`) · `ring-converge` (read OK: rings converge into the card, `motion.duration.base`, `motion.ease.accelerate` — 06 M06) · `skeleton-shimmer` (loop) · `crossfade-state` (reading → looking-up, `motion.duration.fast`) · `card-lift` (→ S07, `motion.duration.base`, `motion.spring.card`) · `fade-through` (→ S10) · read failure: rings return to rest (240 ms, decelerate) — **no ring shake** (06 M05). Reduce Motion: converge becomes a 160 ms fade-out of the arcs; card-lift becomes a 160 ms cross-fade.

### 6.11 Micro-interactions
- Feedback fires at **read OK**, never at mere tag discovery (a half-read must not sound like success).
- A card that stays on the phone after S07 is shown does not re-trigger (UID debounce).

### 6.12 Haptic

| Event | Android | iPhone |
|---|---|---|
| Read OK | `haptic.cardDetected` | none (system sheet) |
| Read failed | none for the 1st–2nd failure; `haptic.warning` after 3 × within 5 s ([11](11-sound-and-haptics.md) E12/E13) | none (system sheet) |
| Not a gift card | `haptic.warning` | none (system sheet) |
| Lookup error → S10 | per 03b | per 03b |

### 6.13 Sound

| Event | Android | iPhone |
|---|---|---|
| Read OK | `sound.cardDetected` | none (system sheet) |
| Read failed | none (never a sound, also not after 3 ×) | none |
| Not a gift card | `sound.warning` | none |

Sound respects the Menu switch, the iOS silent switch and Android ringer mode ([11-sound-and-haptics.md](11-sound-and-haptics.md)).

### 6.14 Accessibility
- Read OK: assertive announcement `scan.detected`, followed on S07 by the card summary (03b).
- Looking-up: caption is a polite live region; `scan.slow` is announced; Cancel receives focus when it appears.
- Read failed / not a card: assertive announcement of the title.
- iPhone: VoiceOver reads the system sheet itself; our alert messages are what it reads.
- Dynamic Type: the caption wraps; Skeleton keeps its geometry.

### 6.15 Tablet / Landscape / Portrait
- Tablet: Android tablets as phone (Skeleton max width 400, centred); iPad never shows S06.
- Landscape (tablets): Skeleton in the left column position of S07's two-pane layout ([08-responsive-behaviour.md](08-responsive-behaviour.md)).
- Portrait: as above.

### 6.16 Android vs iPhone
Summarised in the tables above: Android = zero taps, inline, app-owned feedback; iPhone = one tap, system sheet, system-owned feedback, our texts only.

### 6.17 Time required
Android read + lookup ≤ 0.7 s (0.3 + 0.4); iPhone start → read → dismiss ≤ 1.2 s (0.3 sheet + 0.5 read + ≤ 0.4 dismissal, API overlapped).

### 6.18 Acceptance criteria
- [ ] Android: `haptic.cardDetected` + `sound.cardDetected` fire exactly once per successful read, after the URL and UID are read, never on a failed read.
- [ ] Android platform NFC sound never plays while S05/S07/S09 are visible.
- [ ] iPhone: no app sound/haptic during the system sheet.
- [ ] The scan request is sent before the iPhone success message is set.
- [ ] Skeleton never appears before 150 ms; no blank frame between read and S07.
- [ ] "Still looking …" at 3 s, S10 network error at 10 s; Cancel works and books nothing.
- [ ] iPhone alert texts match the table exactly in all three languages and fit in 2 lines on a 375-pt-wide iPhone at default text size.
- [ ] Multiple tags, read failure and non-card tags keep the iPhone sheet open and restart polling.

---

## 7. S11 · Manual entry

**Purpose.** Look up a card by its 16-digit number when NFC and QR are not an option (damaged chip, iPad without camera line of sight, guest reading the number aloud). Only the system keypad of the app is used — never the OS keyboard.

### Entry / exit

| From | Trigger | To |
|---|---|---|
| S05 | "Card number" SecondaryButton (all variants except offline) | S11 (`push`) |
| S12 | "Enter card number" | S11 (replaces S12 in the stack; back goes to S05) |
| S16 camera denied | "Enter card number" | S11 |
| S10 (03b) | "Try again" after card not found from a manual lookup | S11 with the previous number restored |
| S11 | back chevron / edge swipe / Android back | S05 (`pop`); typed digits are discarded |
| S11 | "Look up card" → 200 | S07 (`fade-through`) |
| S11 | → 404 / 403 foreign / 429 throttled / network / 5xx | S10 (03b) |
| S11 | → 401 / revoked / suspended | S15 |

### Portrait layout (iPhone reference)

```
y=0    ┌─────────────────────────────────────────┐
       │ status bar                               │ 59
y=59   │ [‹]          Kartennummer           [  ]│ navigation bar 56
y=115  │ space.6 24                               │
y=139  │   16 Ziffern auf der Rückseite der Karte │ helper type.caption, fg.secondary, centred (18)
y=157  │ space.2 8                                │
y=165  │ ┌─────────────────────────────────────┐ │
       │ │  5285 1058 7098 ••••                │ │ CardNumberField 64, Geist Mono at type.title.m metrics, centred
y=229  │ └─────────────────────────────────────┘ │
y=237  │                               12 von 16  │ counter type.caption, fg.tertiary, right-aligned (18)
y=255  │ flex 155                                 │
y=410  │ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
       │ │    1     │ │    2     │ │    3     │ │ Keypad: keys 112.3 × 72, gaps space.2 (8)
       │ ├──────────┤ ├──────────┤ ├──────────┤ │
       │ │    4     │ │    5     │ │    6     │ │
       │ │    7     │ │    8     │ │    9     │ │
       │ │    00    │ │    0     │ │    ⌫     │ │
y=722  │ └──────────┘ └──────────┘ └──────────┘ │ 4 × 72 + 3 × 8 = 312
y=722  │ space.4 16                               │
y=738  │ ┌─────────────────────────────────────┐ │
       │ │           Karte suchen              │ │ PrimaryButton large 64 (disabled < 16 digits)
y=802  │ └─────────────────────────────────────┘ │
y=802  │ space.4 16                               │
y=852  └─────────────────────────────────────────┘
```

CardNumberField: 4 groups of 4, separated by a 12-pt gap; empty positions render as `•` in `color.fg.tertiary` so the total length is always visible; typed digits in `color.fg.primary`; caret after the last digit (`color.fg.primary`, 2 pt); radius.s; fill `color.bg.surface`; 1 pt `color.border.control` at rest, 2 pt `color.focus.ring` when focused (always focused on this screen; [05](05-component-library.md)). 19 characters at 22 pt mono ≈ 251 pt, fits the 353-pt field with space.4 padding.

### Visual hierarchy
1. The number being typed · 2. Keypad + "Look up card" · 3. helper, counter.

### Typography

| Element | Token |
|---|---|
| Navigation title | `type.body.m`, 600 |
| Helper, counter, inline error | `type.caption` |
| Card number | Geist Mono, `type.title.m` metrics (22/28), `tnum` |
| Keypad digits | `type.key` |
| Button | `type.label` large |

### Colours

| Element | Token | Light | Dark |
|---|---|---|---|
| Background | `color.bg.canvas` | #FAFAFA | #0A0A0C |
| Field fill | `color.bg.surface` | #FFFFFF | #141417 |
| Field focus border / caret | `color.accent.saffron` | #E8A33D | #F0B454 |
| Field error border / error text | `color.danger` | #B91C1C | #F87171 |
| Digits | `color.fg.primary` | #18181B | #F4F4F5 |
| Empty slots, counter | `color.fg.tertiary` | #71717A | #8B8B94 |
| Helper | `color.fg.secondary` | #52525B | #A1A1AA |
| Keys / pressed | `color.bg.key` / `color.bg.keyPressed` | #F1F1F3 / #E4E4E7 | #1E1E23 / #2A2A31 |
| PrimaryButton | `color.action.primary` / `color.fg.onAccent` | #18181B / #FFFFFF | #F4F4F5 / #0A0A0C |

### Components
Navigation bar (IconButton back), CardNumberField, Keypad (radius.l keys), PrimaryButton large, Spinner, TertiaryButton (Cancel during slow lookup).

### Input rules
- Keypad only; the OS keyboard never appears. Hardware/Bluetooth keyboards: digits, Backspace, Enter (= submit when 16) accepted.
- `00` inserts two zeros (one if only one position is left).
- ⌫ deletes one digit; long-press ⌫ (500 ms) clears all.
- 17th digit is rejected with the limit nudge on the field (±3 pt, 2 cycles, 240 ms — half the `shake` amplitude, [06](06-motion-guidelines.md) M12 / [05 §2.5](05-component-library.md)) and `haptic.warning`.
- Paste (long-press on the field → system Paste menu): all non-digits stripped; exactly 16 digits → field filled; otherwise nothing pasted and inline error `manual.error.paste`.
- No Luhn/check-digit validation client-side (the server decides).

### States

| State | Behaviour | Copy |
|---|---|---|
| Empty | 16 grey slots, counter "0 von 16", button disabled | `manual.helper`, `manual.counter` |
| Typing (1–15) | counter updates; button disabled | — |
| Complete (16) | button enabled; counter becomes a ✓ + "16 von 16" in `color.success` | — |
| Loading | button Spinner after 150 ms; keypad disabled (keys at 100 % colour, not greyed, input ignored) | a11y `scan.lookingUp` |
| Slow (> 3 s) | caption under field swaps to `scan.slow`; Cancel TertiaryButton replaces the counter row | `scan.slow`, `common.cancel` |
| > 10 s | S10 network error | — |
| Error · 422 VALIDATION_FAILED | red field border, `shake`, inline error replaces the counter; digits kept | `manual.error.invalid` |
| Error · paste | inline error for 3 s | `manual.error.paste` |
| Error · 404 / others | S10 (03b) | — |
| Offline | S11 not reachable from offline S05; if connectivity drops while on S11, button disabled + info caption `offline.title` under the field | — |

### Animations & transitions
`push` in / `pop` out · digit insert: new digit fades/slides in 4 pt from the right (`motion.duration.instant`) · `shake` for errors (`motion.duration.base`, 06 M02) · counter ✓ `crossfade-state` · → S07 `fade-through`.

### Micro-interactions
- Keys: `press` (colour to `color.bg.keyPressed`, scale 0.96).
- Completing the 16th digit briefly (160 ms) pulses the field border to `color.success` then back to `color.focus.ring`.
- Returning from S10 with a restored number places the caret at the end, all digits selected-looking (ready for ⌫).

### Haptic
`haptic.key` per keypress · `haptic.select` on the 16th digit · `haptic.warning` on rejected input · `haptic.error` on 422.

### Sound
None (no key sounds; lookup sounds belong to S07/S10).

### Accessibility
- Focus order: back → title → helper → field → keypad (row by row) → "Look up card".
- Field label: "Card number, {count} of 16 digits", value read in groups ("5 2 8 5, 1 0 5 8 …").
- Keys: "1"…"9", "0", "double zero", "Delete" (hint: "Long press to clear"). Each keypress announces the new digit (polite).
- Dynamic Type: helper/counter scale to 200 %; the card number scales to 130 %, then shrink-to-fit (never wraps inside a group); keys keep `type.key` up to 120 % ([04 §3.7](04-design-system.md)).
- Compact height: keys 64, button 56 (keypad 280, starts at y = 667 − 16 − 56 − 16 − 280 = 299).

### Tablet / Landscape / Portrait
- Tablet: centred column 400 wide; keypad keys 80 high; button directly below the keypad.
- Landscape (tablets): two columns — left: helper, field, counter vertically centred; right: keypad + button.
- Portrait (phones): as wireframe.

### Android vs iPhone
Android: system back = back chevron; predictive back animation allowed. iPhone: edge-swipe back. Otherwise identical.

### Time required
Target ≤ 8 s for a number read from the card (16 digits ≈ 5.5 s + tap + lookup ≤ 0.4 s + transition 0.24 s).

### Acceptance criteria
- [ ] OS keyboard never appears.
- [ ] Exactly 16 digits enable the button; 17th is rejected.
- [ ] Long-press ⌫ clears the field.
- [ ] Pasting "5285-1058-7098-6488" fills the field.
- [ ] Digits are retained after a 404 when the waiter returns via "Try again".
- [ ] Button in thumb zone on every phone frame; keys ≥ 72 (52 compact).
- [ ] Screen reader reads digits in groups, not as one large number.

New strings (S11):

| Key | DE | EN | BHS |
|---|---|---|---|
| `manual.title` | Kartennummer | Card number | Broj kartice |
| `manual.helper` | 16 Ziffern auf der Rückseite der Karte | 16 digits on the back of the card | 16 cifara na poleđini kartice |
| `manual.counter` | {count} von 16 | {count} of 16 | {count} od 16 |
| `manual.submit` | Karte suchen | Look up card | Pronađi karticu |
| `manual.error.invalid` | Kartennummer prüfen | Check the card number | Provjerite broj kartice |
| `manual.error.paste` | Keine gültige Kartennummer zum Einfügen | No valid card number to paste | Nema ispravnog broja kartice za lijepljenje |
| `common.back` (a11y) | Zurück | Back | Nazad |
| `keypad.doubleZero` (a11y) | Doppelnull | Double zero | Dvije nule |
| `keypad.delete` (a11y) | Löschen | Delete | Obriši |
| `keypad.delete.hint` (a11y) | Lange drücken, um alles zu löschen | Long press to clear | Dugo pritisnite za brisanje svega |

---

## 8. S12 · QR scan

**Purpose.** Read the QR code printed on every card with the camera — the only scan method on iPad and for QR-only cards, and the fallback when a chip fails.

### Entry / exit

| From | Trigger | To |
|---|---|---|
| S05 | "QR code" SecondaryButton / V5 PrimaryButton "Scan QR code" | S12 (`push`) |
| S12 | first entry ever | OS camera permission prompt over S12 |
| S12 | ✕ / Android back / edge swipe | S05 (`pop`) |
| S12 | "Enter card number" | S11 |
| S12 | valid card QR → lookup 200 | S07 (`fade-through`) |
| S12 | lookup problem | S10 / S15 |
| S12 | permission denied / restricted | S16 camera state (in place) |

### Portrait layout (iPhone reference)

S12 always renders with **dark-theme token values**, regardless of the app theme (text sits over a live camera image).

```
y=0    ┌─────────────────────────────────────────┐ camera preview full-bleed (aspect-fill), under everything
       │ status bar (light content)               │ 59
y=59   │ [✕]         QR-Code scannen        [ϟ] │ navigation bar 56 on color.scrim; torch IconButton trailing
y=115  │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │ color.scrim outside the window
       │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
y=230  │ ░░░░░░░ ┏━━          ━━┓ ░░░░░░░░░░░░░░ │ viewfinder window 256 × 256, radius.xl
       │ ░░░░░░░ ┃                ┃ ░░░░░░░░░░░░ │ saffron corner brackets 32 long, 4 pt stroke
       │ ░░░░░░░       (clear)      ░░░░░░░░░░░░ │ centre y = 358 (42 % of height)
       │ ░░░░░░░ ┃                ┃ ░░░░░░░░░░░░ │
y=486  │ ░░░░░░░ ┗━━          ━━┛ ░░░░░░░░░░░░░░ │
y=510  │ ░░  Kamera auf den QR-Code der Karte  ░░ │ hint type.body.l, 2 lines (48), centred
y=558  │ ░░  richten                           ░░ │
       │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
y=746  │ ┌─────────────────────────────────────┐ │ SecondaryButton 56 full width: ⌨ qr.manual
y=802  │ └─────────────────────────────────────┘ │
y=852  └─────────────────────────────────────────┘
```

### Visual hierarchy
1. Viewfinder window · 2. hint · 3. close, torch, "Enter card number".

### Typography
Navigation title `type.body.m` 600 · hint `type.body.l` · status (looking up / not a card) `type.body.m` · button `type.label`.

### Colours (dark values always)

| Element | Token | Value |
|---|---|---|
| Scrim outside window, bars | `color.scrim` | rgba(0,0,0,0.64) |
| Title, hint | `color.fg.primary` | #F4F4F5 |
| Icons | `color.fg.primary` | #F4F4F5 |
| Corner brackets (searching / detected) | `color.accent.saffron` | #F0B454 |
| Brackets + message (not a card) | `color.warning` | #FBBF24 |
| SecondaryButton | `color.bg.key` / `color.fg.primary` | #1E1E23 / #F4F4F5 |
| Torch on state | IconButton fill `color.fg.primary`, glyph `color.fg.onAccent` | #F4F4F5 / #0A0A0C |

### Components
Navigation bar (IconButton close, IconButton torch), viewfinder (illustrated overlay, not a component), SecondaryButton, Spinner, TertiaryButton (Cancel), EmptyState (camera denied — S16).

### States

| State | Behaviour | Copy |
|---|---|---|
| Starting camera | black preview, brackets visible; Spinner in the window after 500 ms | — |
| Searching | live preview; decoding continuously on-device (no network) | `qr.hint` |
| Detected (valid card URL `https://<domain>/c/<UUID>`) | brackets animate to the code's bounds and turn solid; preview freezes; hint → Spinner + `scan.lookingUp`; request `method: qr` | `scan.lookingUp` |
| Slow (> 3 s) | `scan.slow`, Cancel TertiaryButton replaces "Enter card number"; Cancel unfreezes and resumes searching | `scan.slow`, `common.cancel` |
| > 10 s | S10 network error | — |
| Not a gift card (other QR, other domain) | hint → `qr.notCard` in warning colour for 2.5 s; the same payload is ignored for 3 s; scanning continues | `qr.notCard` |
| Low light (no code for 3 s and scene luminance low) | hint → `qr.dark`; torch IconButton pulses once | `qr.dark` |
| Camera denied / restricted | S16 § 11.3 in place of the preview | — |
| Offline | not reachable from offline S05; if lost while on S12 → an info caption `offline.title` replaces the hint, detection pauses | — |
| Disabled / empty | n/a | — |

Mini wireframe — detected:

```
y=230  │ ░░░░░░░   ┏━━━━━━━┓   ░░░░░░░░░░░░░░ │ brackets snapped to QR bounds, solid saffron
       │ ░░░░░░░   ┃ ▦▦▦▦▦ ┃   ░░ (frozen)  ░ │
y=486  │ ░░░░░░░   ┗━━━━━━━┛   ░░░░░░░░░░░░░░ │
y=510  │ ░░      ◌  Karte wird gesucht …    ░░ │
```

### Animations & transitions
`push` / `pop` · brackets snap: `motion.duration.fast`, `motion.ease.decelerate` · hint changes `crossfade-state` · → S07 `fade-through` · torch pulse: one scale 1.0 → 1.08 → 1.0 over `motion.duration.slow`. Reduce Motion: brackets change colour without moving; no pulse.

### Micro-interactions
- Tap inside the window: focus + exposure at that point.
- Pinch: disabled (fixed 1× / auto-macro where available) — fewer failure modes.
- The torch state is remembered for the session.

### Haptic
Valid detection `haptic.cardDetected` · not a card `haptic.warning` · torch toggle `haptic.select`.

### Sound
Valid detection `sound.cardDetected` · not a card `sound.warning`.

### Accessibility
- Focus order: close → title → torch → hint → "Enter card number".
- Hint is a polite live region; detection announces `scan.detected`; not-a-card announces `qr.notCard` (assertive).
- Torch: label `qr.torchOn` / `qr.torchOff`, trait toggle/selected.
- VoiceOver users are offered "Enter card number" as the second focus stop after the hint — manual entry is the accessible alternative to aiming a camera.
- Dynamic Type: hint wraps to 3 lines; viewfinder shrinks to 224 if needed.

### Tablet / Landscape / Portrait
- Tablet: viewfinder 320; hint and button in a 400-wide centred column. Proposal (not part of v1): a camera-switch IconButton on tablets so a stand-mounted iPad can use the front camera.
- Landscape (tablets): preview follows device orientation; viewfinder centred in the left 60 %; hint and button in the right column.
- Portrait (phones): as wireframe; compact: viewfinder 224, hint 2 lines.

### Android vs iPhone
- **Android:** system back closes; on Android, reader mode is not active on S12 (brief: only S05/S07/S09); a card tapped here is handled by the OS (App Link → S07 via `link`). Proposal (not part of v1): keep reader mode active on S11/S12 so an accidental card tap is processed in-app.
- **iPhone:** edge-swipe back; status bar light content; the camera indicator (green dot) is system.

### Time required
Target ≤ 2.5 s from "QR code" tap to S07 (push 0.24 + camera start ≤ 0.8 + aim/decode ≤ 1.0 + lookup ≤ 0.4).

### Acceptance criteria
- [ ] Only URLs matching `https://<domain>/c/<UUID v4>` trigger a lookup; everything else shows `qr.notCard`.
- [ ] One detection = one request (preview freezes; no duplicate lookups).
- [ ] Always dark styling; all text ≥ 4.5:1 against the scrim over a white scene.
- [ ] Torch works and its state is announced.
- [ ] "Enter card number" is always reachable in the thumb zone.
- [ ] Camera is released immediately when leaving S12 or backgrounding.

New strings (S12):

| Key | DE | EN | BHS |
|---|---|---|---|
| `qr.title` | QR-Code scannen | Scan QR code | Skeniraj QR kôd |
| `qr.hint` | Kamera auf den QR-Code der Karte richten | Point the camera at the QR code on the card | Usmjerite kameru na QR kôd kartice |
| `qr.notCard` | Dieser QR-Code gehört zu keiner Geschenkkarte | This QR code isn't a gift card | Ovaj QR kôd nije poklon-kartica |
| `qr.dark` | Zu dunkel? Licht einschalten. | Too dark? Turn on the light. | Pretamno? Uključite svjetlo. |
| `qr.torchOn` (a11y) | Licht einschalten | Turn on light | Uključi svjetlo |
| `qr.torchOff` (a11y) | Licht ausschalten | Turn off light | Isključi svjetlo |
| `qr.manual` | Kartennummer eingeben | Enter card number | Unesi broj kartice |
| `common.close` (a11y) | Schließen | Close | Zatvori |

---

## 9. S14 · Menu sheet

**Purpose.** The only place for account, restaurant, device and personal preferences. Deliberately short: nothing here affects cards or money.

### Entry / exit

| From | Trigger | To |
|---|---|---|
| S05 | Avatar in TopBar | S14 (`sheet-rise`) |
| S14 | swipe down / tap scrim / Android back / ✕-less (no close button — grabber + scrim) | S05 |
| S14 | Appearance row | nested sheet (appearance choice) |
| S14 | Help | in-app browser (help page, app language) |
| S14 | Sign out → confirm | S02 (`fade-through`) |
| S14 (Android) | card tapped | sheet falls, S06 reading state |

### Portrait layout (iPhone reference; sheet height 748, top at y = 104)

```
y=104  ╭─────────────────────────────────────────╮ radius.sheet 32, color.bg.surface, elev.3
       │                ▬▬▬                       │ grabber 36 × 5 (area 24)
y=128  │ (LG)  Lukas Gruber                       │ account header 72: Avatar 48,
       │       lukas@goldener-hirsch.at           │ name type.body.l 600 · e-mail type.body.m fg.secondary
y=200  │ space.2                                  │
y=208  │ Lokal            Gasthaus Zum Golden…    │ row 56 (read-only)
y=264  │ Gerät                  iPhone von Lukas  │ row 56 (read-only)
y=320  │ space.6                                  │
y=344  │ EINSTELLUNGEN                            │ type.overline, fg.tertiary (14) + space.2
y=366  │ Darstellung                Wie System ›  │ row 56 → nested sheet
y=422  │ Töne                               [●━] │ row 56, system switch
y=478  │ Vibration                          [●━] │ row 56, system switch
y=534  │ Bildschirm anlassen                [●━] │ row 72: label + caption
       │ Während Scannen und Einlösen             │
y=606  │ space.2                                  │
y=614  │ ☀ Im Freien ist das helle Design besser  │ tip type.caption fg.tertiary (18, ≤ 2 lines)
y=632  │ space.6                                  │
y=656  │ Hilfe                                 ↗  │ row 56
y=712  │ Abmelden                                 │ row 56, label color.danger
y=768  │ space.4                                  │
y=784  │           Version 1.0.0 (142)            │ type.caption fg.tertiary, centred (18)
y=802  │ space.4 + home indicator 34              │
y=852  ╰─────────────────────────────────────────╯
```

Rows: full-bleed touch area, text inset by the side margin, 1 px `color.border.subtle` divider inset by the margin between rows of a group; row press state `color.bg.keyPressed` at 100 %; radius.m on the pressed highlight.

### Visual hierarchy
1. Who is signed in (header) · 2. settings rows · 3. help, sign out, version.

### Typography
Header name `type.body.l` 600 · e-mail `type.body.m` · row labels `type.body.l` · row values `type.body.m` · section overline `type.overline` · captions/tip/version `type.caption` · Sign out `type.body.l` 600.

### Colours

| Element | Token | Light | Dark |
|---|---|---|---|
| Scrim | `color.scrim` | rgba(10,10,12,0.48) | rgba(0,0,0,0.64) |
| Sheet | `color.bg.surface` | #FFFFFF | #141417 (+ 1 px `color.border.subtle` top edge) |
| Grabber | `color.border.strong` | #A1A1AA | #3F3F46 |
| Labels | `color.fg.primary` | #18181B | #F4F4F5 |
| Values, e-mail | `color.fg.secondary` | #52525B | #A1A1AA |
| Overline, tip, version | `color.fg.tertiary` | #71717A | #8B8B94 |
| Dividers | `color.border.subtle` | #E4E4E7 | #26262B |
| Switch on-track | `color.action.primary` | #18181B | #F4F4F5 |
| Sign out label | `color.danger` | #B91C1C | #F87171 |
| Nested sheet | `color.bg.raised` | #FFFFFF | #1C1C21 |

### Components
BottomSheet, Avatar (48), platform switch controls (styled per [05-component-library.md](05-component-library.md)), Dialog (sign-out confirmation) with SecondaryButton + DangerButton.

### Rows and behaviour

| Row | Control | Behaviour |
|---|---|---|
| Restaurant | read-only value | name from the account |
| Device | read-only value | device name sent at sign-in (OS name); not editable in v1 |
| Appearance | value + chevron | nested sheet: Match system (default) · Light · Dark; applies live with a 160 ms cross-fade |
| Sounds | switch, default ON | turning ON plays `sound.cardDetected` once as a sample |
| Haptics | switch, default ON | turning ON plays `haptic.select` once; row disabled (with caption `menu.haptics.unavailable`) on devices without a haptic engine |
| Keep screen on | switch, default ON | see S05 V9 |
| Sunlight tip | static caption | always shown |
| Help | opens help page in the in-app browser | |
| Sign out | danger text row | Dialog: `menu.signOut.confirm.title` / `.body`, buttons `common.cancel` (SecondaryButton) and `menu.signOut` (DangerButton); confirm clears token, Recent and pending links → S02 |
| Version | static | `menu.version` |

Mini wireframe — sign-out Dialog (centred, radius.xl, `color.bg.raised`, width content − 0, max 400):

```
╭───────────────────────────────╮
│ Abmelden?                     │ type.title.m
│ Der Schichtverlauf wird von   │ type.body.m, fg.secondary
│ diesem Gerät gelöscht.        │
│ [ Abbrechen ] [ Abmelden ]    │ SecondaryButton 56 · DangerButton 56, gap space.3
╰───────────────────────────────╯
```

### States
Loading: none (all local). Empty: n/a. Error: sign-out never fails visibly — token revocation is attempted in the background; local data is cleared regardless. Disabled: Haptics row on devices without haptics. Offline: all rows work; Help shows the browser's own offline page.

### Animations & transitions
`sheet-rise` (`motion.spring.soft`) / `sheet-fall` (`motion.duration.fast`, `motion.ease.accelerate`) · nested sheet same · Dialog: scale 0.96 → 1 + fade (`motion.duration.fast`, `motion.ease.decelerate`) · theme change `crossfade-state`.

### Micro-interactions
Switches toggle on tap anywhere in the row · the sheet follows the finger when dragged and dismisses past 30 % of its height or a downward velocity > 800 pt/s.

### Haptic
Switch toggle `haptic.select` · appearance choice `haptic.select` · sign-out confirm `haptic.warning`.

### Sound
Only the Sounds-ON sample (`sound.cardDetected`).

### Accessibility
- Focus moves into the sheet on open (header first); order top → bottom; the scrim is a "Close menu" element for screen readers (label `menu.close`).
- Rows expose label + value ("Sounds, on, switch").
- Dialog traps focus; initial focus on Cancel (the safe action).
- Dynamic Type 200 %: rows grow (min 56), values move below labels when they don't fit; the sheet becomes scrollable up to 90 % of screen height.

### Tablet / Landscape / Portrait
- Tablet: presented as a centred sheet (form sheet) 480 wide, max height 720, radius.xl on all corners.
- Landscape (tablets): same form sheet.
- Portrait (phones): as wireframe; compact height: sheet takes 90 % and scrolls.

### Android vs iPhone
Android: system back dismisses (nested sheet first); switches are Material-style tinted with the tokens. iPhone: iOS switches tinted `color.action.primary`; sheet uses the native sheet presentation with a custom detent equal to content height.

### Time required
Open ≤ 0.3 s; change one setting ≤ 2 s; sign out ≤ 3 s (2 taps).

### Acceptance criteria
- [ ] No row offers reload, block, card creation, reports, team or restaurant settings.
- [ ] Sign-out always asks for confirmation and always clears token and Recent, online or offline.
- [ ] Settings persist across app restarts and are per device.
- [ ] Theme change applies without restart.
- [ ] Android: a card tap closes the sheet and starts reading.

New strings (S14):

| Key | DE | EN | BHS |
|---|---|---|---|
| `menu.close` (a11y) | Menü schließen | Close menu | Zatvori meni |
| `menu.restaurant` | Lokal | Restaurant | Restoran |
| `menu.device` | Gerät | Device | Uređaj |
| `menu.section.settings` | Einstellungen | Settings | Postavke |
| `menu.theme` | Darstellung | Appearance | Izgled |
| `menu.theme.system` | Wie System | Match system | Kao sistem |
| `menu.theme.light` | Hell | Light | Svijetlo |
| `menu.theme.dark` | Dunkel | Dark | Tamno |
| `menu.sound` | Töne | Sounds | Zvukovi |
| `menu.haptics` | Vibration | Haptics | Vibracija |
| `menu.haptics.unavailable` | Auf diesem Gerät nicht verfügbar | Not available on this device | Nije dostupno na ovom uređaju |
| `menu.keepScreenOn` | Bildschirm anlassen | Keep screen on | Ekran uvijek uključen |
| `menu.keepScreenOn.caption` | Während Scannen und Einlösen | While scanning and redeeming | Tokom skeniranja i iskorištavanja |
| `menu.sunlightTip` | Im Freien ist das helle Design besser lesbar. | Outdoors, the light theme is easier to read. | Na otvorenom je svijetla tema čitljivija. |
| `menu.help` | Hilfe | Help | Pomoć |
| `menu.version` | Version {version} | Version {version} | Verzija {version} |
| `menu.signOut` | Abmelden | Sign out | Odjavi se |
| `menu.signOut.confirm.title` | Abmelden? | Sign out? | Odjaviti se? |
| `menu.signOut.confirm.body` | Der Schichtverlauf wird von diesem Gerät gelöscht. | The shift history on this device will be deleted. | Historija smjene na ovom uređaju bit će izbrisana. |

---

## 10. S15 · Session & account states

**Purpose.** Stop the waiter safely and explain in one line what happened and what to do, whenever the session, the device, the restaurant account, the waiter account or the app version no longer allows redeeming. None of these states ever shows card data, and none can be dismissed into a working Ready screen.

### Entry / exit (all variants)

| Variant | Trigger | Presentation | Exit |
|---|---|---|---|
| 10.1 Session expired | any API 401 UNAUTHENTICATED | BottomSheet over the current screen, not dismissible | "Sign in again" → S02 (e-mail prefilled); after sign-in → S05; Recent kept if the same e-mail signs in |
| 10.2 Device revoked | 403 DEVICE_REVOKED | full screen (ProblemScreen template) | "Sign in" → S02; token, Recent, pending links cleared on entry |
| 10.3 Restaurant suspended | 403 RESTAURANT_SUSPENDED | full screen | "Check again" (re-validates with the API; success → S05) · "Sign out" TertiaryButton → S02 |
| 10.4 Account locked | 423 ACCOUNT_LOCKED on sign-in (`retry_after`) | in place on S02 (StatusBanner + disabled button with countdown) | countdown reaches 0 → S02 normal |
| 10.5 Account deactivated | 403 FORBIDDEN on sign-in or on any call for an account marked inactive | full screen | "Back to sign in" → S02 (empty); token cleared |
| 10.6 Update required | `/app/config` minimum version > installed (checked at S01 and on foreground, max once per 15 min) | full screen, no back, no dismiss | "Update now" → App Store / Play Store page |
| 10.7 Maintenance banner | `/app/config` notice present | Banner on S05 (S05 V7) | dismiss for this notice; see § 5.7 V7 |

**Never interrupt money in flight:** if a 401/403/update condition is detected while S08 Redeeming is running, the redeem result is shown first (03b) and the S15 state appears when the waiter leaves S09/S10. Session expiry during S08 is handled by 03b's uncertain/ retry rules.

### 10.1 Session expired — sheet layout (iPhone reference)

```
y=0    │ current screen, dimmed by color.scrim   │
y=568  ╭─────────────────────────────────────────╮ radius.sheet 32, color.bg.surface, no grabber
y=568  │ space.6 24                               │
y=592  │ ⏱  (48, color.warning)                   │ glyph
y=640  │ space.4 16                               │
y=656  │ Sitzung abgelaufen                       │ session.expired  type.title.m (28)
y=684  │ space.2 8                                │
y=692  │ Zum Weitermachen erneut anmelden.        │ session.expired.body  type.body.m (22)
y=714  │ space.6 24                               │
y=738  │ ┌─────────────────────────────────────┐ │ PrimaryButton large 64: session.expired.action
y=802  │ └─────────────────────────────────────┘ │
y=818  │ space.4 16 + home indicator 34          │
y=852  ╰─────────────────────────────────────────╯
```

Swipe-down, scrim tap and Android back do nothing (the sheet rubber-bands 12 pt and settles).

### 10.2 / 10.3 / 10.5 / 10.6 — full-screen layout (ProblemScreen template, iPhone reference)

```
y=0    ┌─────────────────────────────────────────┐
       │ status bar                               │ 59
y=59   │ (no TopBar, no back)                     │
       │ flex                                     │
y=259  │              ╭──────╮                    │ icon plate 96, radius.full, tone bg token
       │              │  ⊘   │                    │ glyph 48, tone token
y=355  │              ╰──────╯                    │
y=379  │     Gerät wurde entfernt                 │ title type.title.l, centred, ≤ 2 lines
y=413  │ space.3 12                               │
y=425  │  Das Gerät ist nicht mehr für dieses     │ body type.body.l, centred, ≤ 2 lines (48)
y=473  │  Lokal freigegeben. …                    │
       │ flex                                     │
y=674  │ ┌─────────────────────────────────────┐ │ PrimaryButton large 64
y=738  │ └─────────────────────────────────────┘ │
y=746  │           Abmelden                       │ TertiaryButton 56 (only where listed)
y=802  │ space.4 16                               │
y=852  └─────────────────────────────────────────┘
```

Template details (icon plate, spacing, tone mapping) are shared with S10 in 03b; this document fixes only content and behaviour.

### 10.4 Account locked — on S02 (mini wireframe)

```
y=243  ┌ ⊘ Konto vorübergehend gesperrt           ┐ StatusBanner danger (title 600 + body), 78
       └   Zu viele Anmeldeversuche. Erneut möglich in 4:59. ┘
y=337  E-Mail  [ lukas@… ]   (editable)
y=427  Passwort [       ]    (editable)
y=509  Passwort vergessen?   (enabled — resetting is the way out)
y=738  [   Erneut in 4:59   ]  PrimaryButton large, disabled, label counts down (tnum)
```

`{time}` = `m:ss` below 1 hour, `h:mm:ss` from 1 hour; countdown uses the monotonic clock (not wall time); on reaching 0 the banner falls (`banner-out`), the button becomes `signIn.submit`, a polite announcement `locked.over` is made.

### Variant content

| Variant | Glyph · tone (plate bg / glyph) | Title | Body | Primary | Secondary | Clears |
|---|---|---|---|---|---|---|
| 10.1 Session expired | clock · `color.warning.bg` / `color.warning` | `session.expired` | `session.expired.body` | `session.expired.action` | — | token only |
| 10.2 Device revoked | device-x · `color.danger.bg` / `color.danger` | `deviceRevoked.title` | `deviceRevoked.body` | `deviceRevoked.action` | — | token, Recent, pending link |
| 10.3 Restaurant suspended | pause · `color.warning.bg` / `color.warning` | `suspended.title` | `suspended.body` | `suspended.retry` | `menu.signOut` (TertiaryButton) | nothing |
| 10.4 Account locked | lock · StatusBanner danger | `locked.title` | `locked.body` | `locked.button` (disabled) | "Forgot password?" stays | nothing |
| 10.5 Account deactivated | person-x · `color.danger.bg` / `color.danger` | `deactivated.title` | `deactivated.body` | `common.backToSignIn` | — | token, Recent |
| 10.6 Update required | arrow-up · `color.info.bg` / `color.info` | `update.title` | `update.body` | `update.action` | — | nothing |

### Visual hierarchy
1. Title (what happened) · 2. PrimaryButton (the only way on) · 3. body, glyph.

### Typography
Sheet title `type.title.m`; full-screen title `type.title.l`; bodies `type.body.l` (full screen) / `type.body.m` (sheet, banner); buttons `type.label` large.

### Colours
Background `color.bg.canvas` (#FAFAFA / #0A0A0C); sheet `color.bg.surface` (#FFFFFF / #141417); scrim `color.scrim`; title `color.fg.primary`; body `color.fg.secondary`; tones as in the table (warning #FFFBEB·#B45309 / #2A1E06·#FBBF24; danger #FEF2F2·#B91C1C / #2A0E0E·#F87171; info #EFF6FF·#1D4ED8 / #0B1A33·#93C5FD); PrimaryButton `color.action.primary` / `color.fg.onAccent`.

### Components
BottomSheet (10.1), ProblemScreen (10.2, 10.3, 10.5, 10.6), StatusBanner (10.4), Banner (10.7), PrimaryButton large, TertiaryButton, Spinner (in "Check again" while re-validating).

### States

| State | Behaviour |
|---|---|
| Loading | 10.3 "Check again": Spinner in button after 150 ms; still suspended → body re-announced, `haptic.warning`; network error → body unchanged, caption `offline.title` below |
| Empty / disabled | 10.4 button disabled until countdown ends; 10.6 has no other state |
| Error | 10.6: if the store cannot be opened, the button stays and nothing else happens (no dead end — the OS shows its own error) |
| Offline | 10.1/10.2/10.5 buttons still lead to S02 (which then shows its offline banner); 10.6 button still opens the store app |

### Animations & transitions
10.1 `sheet-rise`; full-screen variants `fade-through` from whatever screen was active; 10.4 `banner-in`; 10.7 per S05. Reduce Motion: cross-fades.

### Micro-interactions
Countdown ticks every second with `tnum`; "Check again" can be tapped at most once per 3 s.

### Haptic
10.1 `haptic.warning` · 10.2 / 10.3 / 10.5 `haptic.error` · 10.4 `haptic.error` once on appear · 10.6 none.

### Sound
`sound.error` only when the state is the direct result of the waiter's scan or redeem action (e.g. 10.3 after a card tap); none when detected at launch, on foreground, or on sign-in.

### Accessibility
- Full-screen variants: focus starts on the title (heading); assertive announcement "title. body".
- 10.1: sheet is modal; focus trapped; announcement `session.expired`.
- 10.4: countdown not announced every second — announced once on appear and once when it ends (`locked.over`); the button's accessibility value carries the remaining time for on-demand reading.
- Dynamic Type: titles wrap to 3 lines, bodies unlimited (screen scrolls); buttons stay pinned.

### Tablet / Landscape / Portrait
Tablet: content column 480 centred, buttons directly below the body with space.10; 10.1 presented as a centred form sheet 480 wide. Landscape (tablets): same, vertically centred. Portrait phones: as wireframes; compact: icon plate 72, PrimaryButton 56.

### Android vs iPhone
- **Android:** system back on full-screen variants moves the app to background (never back into Ready); 10.6 opens the Play Store listing (in-app update flow not used in v1).
- **iPhone:** 10.6 opens the App Store product page in-app (store sheet) with fallback to the App Store app.

### Time required
Understanding + action ≤ 5 s each (read title, tap one button). 10.1 → back in S05: ≤ 10 s with password autofill.

### Acceptance criteria
- [ ] Every 401 anywhere leads to 10.1 — never to a generic error or a silent sign-out.
- [ ] 10.2 and 10.5 clear the token and Recent before rendering.
- [ ] 10.3 keeps the session; "Check again" returns to S05 when the restaurant is active again.
- [ ] 10.4 countdown matches `retry_after` ± 1 s and survives app backgrounding.
- [ ] 10.6 cannot be bypassed (no back, no swipe, no deep link into S05/S07).
- [ ] No S15 state interrupts an in-flight redeem.
- [ ] No state shows any card number or balance.

New strings (S15):

| Key | DE | EN | BHS |
|---|---|---|---|
| `session.expired.body` | Zum Weitermachen erneut anmelden. | Sign in again to continue. | Prijavite se ponovo za nastavak. |
| `session.expired.action` | Erneut anmelden | Sign in again | Ponovo se prijavi |
| `deviceRevoked.title` | Gerät wurde entfernt | This device was removed | Uređaj je uklonjen |
| `deviceRevoked.body` | Das Gerät ist nicht mehr für dieses Lokal freigegeben. Erneut anmelden oder Manager fragen. | It's no longer allowed for this restaurant. Sign in again or ask a manager. | Uređaj više nije odobren za ovaj restoran. Prijavite se ponovo ili pitajte menadžera. |
| `deviceRevoked.action` | Anmelden | Sign in | Prijavi se |
| `suspended.title` | Einlösen ist pausiert | Redeeming is paused | Iskorištavanje je pauzirano |
| `suspended.body` | Das Konto des Lokals ist pausiert. Bitte einen Manager holen. | The restaurant's account is paused. Please get a manager. | Račun restorana je pauziran. Molimo pozovite menadžera. |
| `suspended.retry` | Erneut prüfen | Check again | Provjeri ponovo |
| `locked.title` | Konto vorübergehend gesperrt | Account temporarily locked | Račun je privremeno zaključan |
| `locked.body` | Zu viele Anmeldeversuche. Erneut möglich in {time}. | Too many sign-in attempts. Try again in {time}. | Previše pokušaja prijave. Ponovo za {time}. |
| `locked.button` | Erneut in {time} | Try again in {time} | Ponovo za {time} |
| `locked.over` (a11y) | Anmelden ist wieder möglich | You can sign in again | Prijava je ponovo moguća |
| `deactivated.title` | Konto deaktiviert | Account deactivated | Račun je deaktiviran |
| `deactivated.body` | Dieses Konto kann nicht mehr verwendet werden. Bitte einen Manager holen. | This account can no longer be used. Please get a manager. | Ovaj račun se više ne može koristiti. Molimo pozovite menadžera. |
| `common.backToSignIn` | Zur Anmeldung | Back to sign in | Nazad na prijavu |
| `update.title` | Update erforderlich | Update required | Potrebno ažuriranje |
| `update.body` | Diese Version wird nicht mehr unterstützt. Zum Weiterarbeiten aktualisieren. | This version is no longer supported. Update to keep redeeming. | Ova verzija više nije podržana. Ažurirajte za nastavak rada. |
| `update.action` | Jetzt aktualisieren | Update now | Ažuriraj sada |

---

## 11. S16 · Permission states

**Purpose.** Make every missing capability (NFC switched off, no NFC hardware, camera permission) explain itself and offer the shortest path out — a settings deep link or an alternative input — without ever leaving the waiter at a dead end.

The app requests exactly one runtime permission: **camera** (S12). NFC needs no runtime permission (iOS shows its usage text in the system sheet's context; Android declares it in the manifest). **Notifications are never requested** in v1 and no notification state exists.

### 11.1 NFC off (Android)

| Aspect | Specification |
|---|---|
| Detection | NFC adapter present and disabled — checked when S05 appears/resumes and live via the adapter-state broadcast while S05 is visible |
| Presentation | S05 V4 (wireframe in § 5.7) |
| Primary action | `nfcOff.action` → opens the NFC settings panel (Android 10+: NFC settings panel; else NFC settings; fallback wireless settings; fallback system settings) |
| Alternatives | "Card number" and "QR code" SecondaryButtons stay enabled |
| Return | on resume, re-check; NFC on → `crossfade-state` to V1, `haptic.select`, polite announcement `nfcOff.on`; still off → V4 unchanged, no nagging |
| During Charge/Success | if NFC is turned off while S07/S09 is open, nothing interrupts; S05 shows V4 when reached |
| iPhone | not applicable (iOS has no user NFC switch) |

### 11.2 NFC unsupported

| Aspect | Specification |
|---|---|
| Detection | Android: no NFC adapter · iPad: always · iPhone: tag reading reported unavailable |
| Presentation | S05 V5 (QR-first layout, § 5.7) and S17 card 1 in its no-NFC variant |
| Actions | PrimaryButton `ready.noNfc.button` → S12; SecondaryButton `ready.manual` → S11 |
| Persistence | evaluated on every S05 appear (cheap); never shown as an error, it is simply the device's Ready layout |

### 11.3 Camera — first request, denied, restricted

**First request.** On the first entry to S12, the OS prompt appears immediately over S12's dark frame (no custom pre-prompt screen — the context of tapping "QR code" is the explanation). The OS usage string is `camera.purpose`.

**Denied** (user declined, or turned off in Settings) — rendered inside S12 in place of the preview, dark values:

```
y=59   │ [✕]         QR-Code scannen             │ navigation bar 56 (torch hidden)
       │ flex                                     │
y=259  │              ╭──────╮                    │ EmptyState: plate 96 color.bg.key, camera-off glyph 48 color.fg.secondary
y=355  │              ╰──────╯                    │
y=379  │     Kamerazugriff ist aus                │ camera.denied.title  type.title.l
y=425  │  Kamera in den Einstellungen erlauben,   │ camera.denied.body   type.body.l (≤ 2 lines)
       │  um QR-Codes zu scannen.                 │
y=666  │ [          Einstellungen öffnen        ] │ PrimaryButton large 64 → app settings page
y=746  │ [          Kartennummer eingeben       ] │ SecondaryButton 56 → S11
y=852  └─────────────────────────────────────────┘
```

**Restricted** (MDM / Screen Time): same layout, body `camera.restricted.body`, no "Open Settings"; "Enter card number" becomes the PrimaryButton.

**Return from Settings:** permission granted → camera starts automatically (`crossfade-state`). iOS may terminate the app when a privacy permission changes; the app then cold-starts (S01 → S04/S05) — accepted; no state is restored into S12.

### 11.4 Shared specification for S16

- **Hierarchy:** 1. title (what is missing) · 2. primary fix · 3. alternative input.
- **Typography:** titles `type.title.l`, bodies `type.body.l` (S12) / `type.body.m` (S05 variants), buttons `type.label`.
- **Colours:** NFC off rings `color.border.strong` (#A1A1AA / #3F3F46); camera EmptyState dark values (`color.bg.key` #1E1E23, `color.fg.secondary` #A1A1AA, `color.fg.primary` #F4F4F5); buttons as elsewhere.
- **Components:** NfcScanAnimation (`disabled`), EmptyState, PrimaryButton large, SecondaryButton.
- **Loading/empty/error:** none beyond the above; a failed settings intent falls back one level as listed.
- **Animations:** `crossfade-state` for all state changes.
- **Micro-interactions:** returning from Settings re-checks without any tap.
- **Haptic:** NFC turned on `haptic.select`; denied state appears silently (no error haptic — nothing went wrong in the waiter's hands).
- **Sound:** none.
- **Accessibility:** titles are headings and polite live regions; buttons state their destination ("Open Settings, opens the Settings app").
- **Tablet/landscape:** as the host screen (S05/S12). **Portrait:** as wireframes.
- **Android vs iPhone:** NFC off is Android-only; camera settings deep link opens the app's settings page on both.
- **Time required:** NFC off → on and back to V1 ≤ 6 s; camera denied → granted ≤ 10 s.

### Acceptance criteria
- [ ] NFC off state appears within 500 ms of NFC being switched off while S05 is visible.
- [ ] "Turn on NFC" reaches an NFC toggle in one step on Android 10+.
- [ ] Returning with NFC on shows V1 without any tap.
- [ ] iPad never shows NFC wording anywhere.
- [ ] Camera denied always offers "Enter card number"; restricted hides "Open Settings".
- [ ] The app never asks for notification permission.

New strings (S16):

| Key | DE | EN | BHS |
|---|---|---|---|
| `nfcOff.title` | NFC ist aus | NFC is off | NFC je isključen |
| `nfcOff.body` | NFC einschalten, um Karten zu scannen. | Turn on NFC to scan cards. | Uključite NFC za skeniranje kartica. |
| `nfcOff.action` | NFC einschalten | Turn on NFC | Uključi NFC |
| `nfcOff.on` (a11y) | NFC ist an. Bereit zum Scannen. | NFC is on. Ready to scan. | NFC je uključen. Spremno za skeniranje. |
| `camera.purpose` (OS usage string) | Die Kamera wird nur zum Scannen von QR-Codes auf Geschenkkarten verwendet. | The camera is only used to scan QR codes on gift cards. | Kamera se koristi samo za skeniranje QR kodova na poklon-karticama. |
| `nfc.purpose` (OS usage string, iOS) | NFC wird zum Lesen von Geschenkkarten verwendet. | NFC is used to read gift cards. | NFC se koristi za čitanje poklon-kartica. |
| `camera.denied.title` | Kamerazugriff ist aus | Camera access is off | Pristup kameri je isključen |
| `camera.denied.body` | Kamera in den Einstellungen erlauben, um QR-Codes zu scannen. | Allow camera access in Settings to scan QR codes. | Dozvolite pristup kameri u postavkama za skeniranje QR kodova. |
| `camera.denied.action` | Einstellungen öffnen | Open Settings | Otvori postavke |
| `camera.restricted.body` | Die Kamera ist auf diesem Gerät gesperrt. Kartennummer verwenden. | The camera is restricted on this device. Use the card number. | Kamera je ograničena na ovom uređaju. Koristite broj kartice. |

---

## 12. S17 · First-run intro

**Purpose.** In ≤ 30 s, teach the three things a new waiter must know: how the card is read on *this* device, that amount and redeem are one screen (hold for large amounts), and that money only moves online and never twice. Shown once per install, skippable at any time, never again.

### Entry / exit

| From | Trigger | To |
|---|---|---|
| S02 / S03 | first successful sign-in on this install (after S03 if shown), no card link pending | S17 card 1 |
| S02 / S03 | first sign-in with a card link pending (universal link / App Link) | S07 for that card; S17 is **deferred** to the next time S05 is shown ([02 §4.3](02-information-architecture-and-journey.md)) — the flag is not set yet |
| S17 | "Skip" (any card) | S05 |
| S17 | "Start" on card 3 | S05 |
| S17 | Android: a card tapped during S17 | intro ends, flag set, S06 reading state → S07 (the waiter is clearly ready) |

The "shown" flag is written when card 1 first renders (so a crash or app kill never replays it). It survives sign-out; only a reinstall resets it.

### Portrait layout (iPhone reference 393 × 852)

```
y=0    ┌─────────────────────────────────────────┐
       │ status bar                               │ 59
y=59   │                               Überspringen│ top row 56: TertiaryButton trailing (56 target)
y=115  │ space.16 64 + space.6 24 = 88 (fixed)    │
y=203  │            ┌─────────────┐               │ illustration artboard 160 × 160, centred,
       │            │  line art   │               │ no plate (10 §4.3/§4.4)
y=363  │            └─────────────┘               │
y=363  │ space.8 32                               │
y=395  │      Karte antippen                      │ title type.title.l, centred, ≤ 2 lines (34 / 68)
y=429  │ space.3 12                               │
y=441  │  Die Karte an die Rückseite halten.      │ body type.body.l, centred, ≤ 3 lines (72)
y=513  │  Das Handy erkennt sie sofort.           │   → worst case (2-line title) body ends y = 547
       │ flex (≥ 159)                             │
y=706  │              ● ○ ○                       │ page dots 8 × 8, space.2 apart
y=714  │ space.6 24                               │
y=738  │ ┌─────────────────────────────────────┐ │ PrimaryButton large 64: Next / Start
y=802  │ └─────────────────────────────────────┘ │ space.4 16 + home indicator 34
y=852  └─────────────────────────────────────────┘
```

### Portrait layout (iPhone compact · iPhone SE 375 × 667)

```
y=0    ┌─────────────────────────────────────────┐
       │ status bar                               │ 20
y=20   │                               Überspringen│ top row 56
y=76   │ space.8 32 (fixed)                       │
y=108  │            ┌─────────┐                   │ illustration artboard 120 × 120
y=228  │            └─────────┘                   │ (compact-height variant, 10 §4.3)
y=228  │ space.6 24                               │
y=252  │      Karte antippen                      │ title type.title.l, ≤ 2 lines (34 / 68)
y=286  │ space.3 12                               │
y=298  │  Die Karte an die Rückseite halten.      │ body type.body.l, ≤ 3 lines (72)
y=370  │  Das Handy erkennt sie sofort.           │   → worst case (2-line title) body ends y = 404
       │ flex (≥ 159)                             │
y=563  │              ● ○ ○                       │ page dots 8 × 8
y=571  │ space.6 24                               │
y=595  │ ┌─────────────────────────────────────┐ │ PrimaryButton 56 (compact)
y=651  │ └─────────────────────────────────────┘ │ space.4 16, no bottom inset
y=667  └─────────────────────────────────────────┘
```

Vertical budget (worst case: 2-line title, 3-line body, 100 % text):

| Block | Reference 852 | Compact 667 |
|---|---|---|
| Status bar + top row | 59 + 56 = 115 | 20 + 56 = 76 |
| Space above illustration | 88 | 32 |
| Illustration | 160 | 120 |
| Illustration → title | 32 (`space.8`) | 24 (`space.6`) |
| Title (2 lines) + gap + body (3 lines) | 68 + 12 + 72 = 152 | 152 |
| Flex (minimum) | 159 | 159 |
| Dots + gap | 8 + 24 = 32 | 32 |
| PrimaryButton + bottom padding + inset | 64 + 16 + 34 = 114 | 56 + 16 + 0 = 72 |
| **Total** | **852** | **667** (≥ 159 pt spare in the flex) |

The illustration's top edge sits in the upper third of the free area on both frames (10 §4.3 "upper third"); the PrimaryButton is below the thumb-zone line on both (y = 738 > 469; y = 595 > 367). Cards change by horizontal swipe or the PrimaryButton; the top row and bottom area stay fixed while the middle block (illustration + title + body) pages.

### Card content

| Card | Illustration ([10 §4.4](10-assets-icons-illustrations.md#44-inventory-10-illustrations)) | Title | Body | Button |
|---|---|---|---|---|
| 1 · Android | `ill_intro_tap` (#8) — phone outline, card approaching its upper back edge, saffron NFC arcs | `intro.1.title.android` | `intro.1.body.android` | `intro.next` |
| 1 · iPhone | `ill_intro_tap` (#8) — same artwork; the arcs sit at the top edge of the phone, which matches "near the top of the iPhone" | `intro.1.title.ios` | `intro.1.body.ios` | `intro.next` |
| 1 · no NFC (iPad, devices without NFC) | no illustration in the 10 §4.4 inventory — `scan-qr-code` icon at `icon.48` in `color.fg.secondary`, centred in the illustration slot; the slot keeps its 160 / 120 height so the text does not jump between cards | `intro.1.title.noNfc` | `intro.1.body.noNfc` | `intro.next` |
| 2 | `ill_intro_amount` (#9) — keypad, amount field, Redeem bar with a saffron partial hold ring | `intro.2.title` | `intro.2.body` (`{threshold}` = € 100,00 in restaurant locale) | `intro.next` |
| 3 | `ill_intro_done` (#10) — SuccessMark geometry with the card outline behind; saffron check | `intro.3.title` | `intro.3.body` | `intro.start` |

Illustrations follow [10 §4.2](10-assets-icons-illustrations.md#42-style) exactly: monoline 1.75 pt line art in `color.fg.secondary`, exactly one saffron accent, no plate, no shadow, no amounts, text or brand colour inside the artwork (so nothing can be mistaken for real card data). Sizes: **160 × 160 pt** on reference and tablet, **120 × 120 pt** on compact height (< 700 pt), each size drawn with its own 1.75 pt stroke.

> **Resolved in design review ([13 §7 · R04](13-future-and-design-review.md#7-resolved-conflicts-register)).** Earlier drafts used 240 pt static renderings of real components on a surface plate. [10 §4](10-assets-icons-illustrations.md#4-illustration-style-15) is authoritative for illustration style and wins: S17 uses the three 160 pt line illustrations (120 pt on compact height); the layout above is re-flowed for that artboard and fits iPhone SE (667 pt) without scrolling at 100 % text size.

### Visual hierarchy
1. Title · 2. illustration · 3. body, dots, Skip. The PrimaryButton is the dominant interactive element.

### Typography
Title `type.title.l` · body `type.body.l` · Skip `type.label` · button `type.label` large.

### Colours

| Element | Token | Light | Dark |
|---|---|---|---|
| Background | `color.bg.canvas` | #FAFAFA | #0A0A0C |
| Illustration line / accent | `color.fg.secondary` / `color.accent.saffron` (high contrast: `color.fg.primary`, stroke +0.25 pt — [10 §4.5](10-assets-icons-illustrations.md#45-dark-mode-and-high-contrast)) | #52525B / #E8A33D | #A1A1AA / #F0B454 |
| Illustration knock-out | `color.bg.canvas` | #FAFAFA | #0A0A0C |
| Title | `color.fg.primary` | #18181B | #F4F4F5 |
| Body | `color.fg.secondary` | #52525B | #A1A1AA |
| Active dot / inactive dot | `color.fg.primary` / `color.border.strong` | #18181B / #A1A1AA | #F4F4F5 / #3F3F46 |
| Skip | `color.fg.primary` | #18181B | #F4F4F5 |
| PrimaryButton | `color.action.primary` / `color.fg.onAccent` | #18181B / #FFFFFF | #F4F4F5 / #0A0A0C |

### Components
TertiaryButton (Skip), PrimaryButton large, page dots (visual element), illustrations `ill_intro_tap` / `ill_intro_amount` / `ill_intro_done` (assets, not components — [10 §4.4](10-assets-icons-illustrations.md#44-inventory-10-illustrations)); no-NFC card 1 uses the `scan-qr-code` icon.

### States
Loading / empty / error / disabled: none (fully local). Variants: card 1 per device capability (3 variants).

### Animations & transitions
- Enter: `fade-through` from S02/S03. Exit: `fade-through` to S05.
- Paging: middle block slides horizontally with the finger; release animates with `motion.spring.soft`; dots cross-fade (`motion.duration.fast`).
- All illustrations are static SVGs (no animation — [10 §2.6](10-assets-icons-illustrations.md#26-animation-files--decision)); the only motion on S17 is paging and the dot cross-fade.
- Reduce Motion: paging becomes a 160 ms cross-fade.

### Micro-interactions
Swipe past the last card = "Start". Tapping dots does nothing (they are indicators). "Skip" stays in the same place on all cards.

### Haptic
Page change `haptic.select`; Skip / Start none.

### Sound
None.

### Accessibility
- Each card is one accessibility group read as "Page {n} of 3. {title}. {body}" (`intro.page`).
- Focus order: Skip → card group → PrimaryButton. Paging via the PrimaryButton or the screen reader's scroll gesture; on page change, focus moves to the new card group.
- Illustrations are decorative and hidden from VoiceOver/TalkBack ([10 §4.2](10-assets-icons-illustrations.md#42-style)).
- Dynamic Type: from 150 % text size the illustration uses the 120 pt variant on every frame; from 200 % on compact height it is hidden (the slot collapses, `space.8` remains above the title); title/body wrap freely; the middle block scrolls vertically only as a last resort, Skip and the PrimaryButton never scroll.

### Tablet / Landscape / Portrait
- Tablet: middle block in a 480-wide column; illustration stays 160 pt (not scaled up — [10 §4.3](10-assets-icons-illustrations.md#43-sizes)).
- Landscape (tablets): illustration 160 left, text right (two columns inside a 720-wide container), dots and button under the text column.
- Portrait (phones): as wireframes above; compact height: illustration 120, PrimaryButton 56.

### Android vs iPhone
Only card 1 differs (see table). Android system back on card 2/3 goes to the previous card; on card 1 it acts as Skip.

### Time required
≤ 30 s total at an unhurried reading pace (≈ 8 s per card + 3 taps); Skip ≤ 1 s.

### Acceptance criteria
- [ ] Shown once per install, after the first sign-in, never again (including after sign-out/sign-in).
- [ ] Skip is reachable on every card and exits in one tap.
- [ ] Card 1 matches the device capability (Android NFC / iPhone / no NFC).
- [ ] Illustrations are the 10 §4.4 line illustrations at 160 pt (120 pt on compact height), one saffron accent, no plate; no component renderings.
- [ ] On iPhone SE (375 × 667) at 100 % text, all three cards fit without scrolling and the PrimaryButton top edge is at y = 595.
- [ ] Card 2 threshold uses the restaurant locale format of € 100,00.
- [ ] No card mentions reload, block, undo or reversal.
- [ ] Total word count of all three bodies ≤ 60 words per language.

New strings (S17):

| Key | DE | EN | BHS |
|---|---|---|---|
| `intro.skip` | Überspringen | Skip | Preskoči |
| `intro.next` | Weiter | Next | Dalje |
| `intro.start` | Loslegen | Start | Počni |
| `intro.page` (a11y) | Seite {n} von 3 | Page {n} of 3 | Stranica {n} od 3 |
| `intro.1.title.android` | Karte antippen | Tap the card | Prislonite karticu |
| `intro.1.body.android` | Die Karte an die Rückseite halten. Das Handy erkennt sie sofort. | Hold the card to the back of the phone. It's detected instantly. | Prislonite karticu na poleđinu telefona. Odmah se prepoznaje. |
| `intro.1.title.ios` | Scannen, dann Karte halten | Tap Scan, then hold the card | Skenirajte, pa prislonite karticu |
| `intro.1.body.ios` | „Karte scannen“ tippen, dann die Karte oben an das iPhone halten. | Tap “Scan card”, then hold the card near the top of the iPhone. | Dodirnite „Skeniraj karticu“, zatim prislonite karticu na vrh iPhonea. |
| `intro.1.title.noNfc` | QR-Code scannen | Scan the QR code | Skenirajte QR kôd |
| `intro.1.body.noNfc` | Kamera auf den QR-Code richten oder die Kartennummer eingeben. | Point the camera at the QR code or type the card number. | Usmjerite kameru na QR kôd ili unesite broj kartice. |
| `intro.2.title` | Betrag eingeben, einlösen | Type the amount, redeem | Unesite iznos, iskoristite |
| `intro.2.body` | Guthaben sehen, Betrag tippen, fertig. Ab {threshold} zum Bestätigen gedrückt halten. | See the balance, type the amount, done. From {threshold}, press and hold to confirm. | Pogledajte stanje, unesite iznos, gotovo. Od {threshold} držite za potvrdu. |
| `intro.3.title` | Nie doppelt gebucht | Never booked twice | Nikad dvaput knjiženo |
| `intro.3.body` | Eingelöst wird nur mit Verbindung. Alle Einlösungen der Schicht stehen unter „Verlauf“. | Redeeming only works online. Your shift's redemptions are under “Recent”. | Iskorištavanje radi samo uz vezu. Iskorištavanja iz smjene su pod „Nedavno“. |

---

## 13. New copy keys (for 12-ui-copy-and-error-messages.md)

All keys introduced by this document, in order of first use. Existing brief keys used here (not repeated): `ready.android.title`, `ready.ios.button`, `ios.sheet.alert`, `offline.title`, `offline.body`, `session.expired`, `getManager`. Placeholders: `{name}` waiter full name · `{time}` countdown `m:ss` / `h:mm:ss` · `{count}` digits typed · `{version}` app version + build · `{n}` page number · `{threshold}` hold-to-redeem threshold formatted in the restaurant locale. "(a11y)" = screen-reader only; "(OS usage string)" = shown by the OS permission prompt.

| # | Key | Screen | DE | EN | BHS |
|---|---|---|---|---|---|
| 1 | `splash.loading` (a11y) | S01 | Wird geladen | Loading | Učitavanje |
| 2 | `signIn.title` | S02 | Anmelden | Sign in | Prijava |
| 3 | `signIn.subtitle` | S02 | Mit dem Mitarbeiterkonto anmelden | Use your staff account | Prijavite se računom zaposlenika |
| 4 | `signIn.email.label` | S02 | E-Mail | E-mail | E-mail |
| 5 | `signIn.password.label` | S02 | Passwort | Password | Lozinka |
| 6 | `signIn.password.show` | S02 | Passwort anzeigen | Show password | Prikaži lozinku |
| 7 | `signIn.password.hide` | S02 | Passwort verbergen | Hide password | Sakrij lozinku |
| 8 | `signIn.forgot` | S02 | Passwort vergessen? | Forgot password? | Zaboravljena lozinka? |
| 9 | `signIn.submit` | S02 | Anmelden | Sign in | Prijavi se |
| 10 | `signIn.error.emailFormat` | S02 | E-Mail-Adresse prüfen | Check the e-mail address | Provjerite e-mail adresu |
| 11 | `signIn.error.invalid` | S02 | E-Mail oder Passwort stimmt nicht. Bitte prüfen und erneut versuchen. | E-mail or password is incorrect. Check both and try again. | E-mail ili lozinka nisu ispravni. Provjerite i pokušajte ponovo. |
| 12 | `signIn.error.noPermission` | S02 | Dieses Konto kann keine Karten einlösen. Bitte einen Manager holen. | This account can't redeem cards. Please get a manager. | Ovaj račun ne može iskorištavati kartice. Molimo pozovite menadžera. |
| 13 | `signIn.error.throttled` | S02 | Zu viele Versuche. Erneut möglich in {time}. | Too many attempts. Try again in {time}. | Previše pokušaja. Ponovo za {time}. |
| 14 | `signIn.error.server` | S02 | Anmelden gerade nicht möglich. Gleich noch einmal versuchen. | Can't sign in right now. Try again in a moment. | Prijava trenutno nije moguća. Pokušajte ponovo za trenutak. |
| 15 | `signIn.offline.body` | S02 | Anmelden braucht eine Internetverbindung. | Signing in needs a connection. | Za prijavu je potrebna veza. |
| 16 | `signIn.loading` (a11y) | S02 | Anmeldung läuft | Signing in | Prijava u toku |
| 17 | `biometrics.title.faceId` | S02 | Mit Face ID entsperren? | Unlock with Face ID? | Otključavati pomoću Face ID-a? |
| 18 | `biometrics.title.touchId` | S02 | Mit Touch ID entsperren? | Unlock with Touch ID? | Otključavati pomoću Touch ID-a? |
| 19 | `biometrics.title.android` | S02 | Mit Biometrie entsperren? | Unlock with biometrics? | Otključavati biometrijom? |
| 20 | `biometrics.body` | S02 | Schneller Start in jede Schicht. Das Passwort bleibt als Alternative. | A faster start to every shift. Your password still works as a fallback. | Brži početak svake smjene. Lozinka ostaje kao zamjena. |
| 21 | `biometrics.enable.faceId` | S02 | Face ID verwenden | Use Face ID | Koristi Face ID |
| 22 | `biometrics.enable.touchId` | S02 | Touch ID verwenden | Use Touch ID | Koristi Touch ID |
| 23 | `biometrics.enable.android` | S02 | Biometrie verwenden | Use biometrics | Koristi biometriju |
| 24 | `biometrics.notNow` | S02 | Jetzt nicht | Not now | Ne sada |
| 25 | `biometrics.reason` | S02 | Zum Entsperren von GiftCard Waiter | To unlock GiftCard Waiter | Za otključavanje aplikacije GiftCard Waiter |
| 26 | `biometrics.failed` | S02 | Nicht bestätigt. Noch einmal versuchen. | Not confirmed. Try again. | Nije potvrđeno. Pokušajte ponovo. |
| 27 | `unlock.button.faceId` | S02 | Mit Face ID entsperren | Unlock with Face ID | Otključaj pomoću Face ID-a |
| 28 | `unlock.button.touchId` | S02 | Mit Touch ID entsperren | Unlock with Touch ID | Otključaj pomoću Touch ID-a |
| 29 | `unlock.button.android` | S02 | Entsperren | Unlock | Otključaj |
| 30 | `unlock.usePassword` | S02 | Passwort verwenden | Use password | Koristi lozinku |
| 31 | `unlock.changed` | S02 | Biometrie wurde auf diesem Gerät geändert. Bitte mit Passwort anmelden. | Biometrics changed on this device. Sign in with your password. | Biometrija je promijenjena na ovom uređaju. Prijavite se lozinkom. |
| 32 | `unlock.pendingCard` | S02 | Die Karte wird nach dem Entsperren geöffnet. | The card opens after unlocking. | Kartica se otvara nakon otključavanja. |
| 33 | `topBar.recent` (a11y) | S05 | Verlauf | Recent | Nedavno |
| 34 | `topBar.menu` (a11y) | S05 | Menü, {name} | Menu, {name} | Meni, {name} |
| 35 | `ready.android.hint` | S05 | Die Karte wird automatisch erkannt | The card is detected automatically | Kartica se automatski prepoznaje |
| 36 | `ready.ios.hint` | S05 | Nach dem Tippen die Karte oben an das iPhone halten | After tapping, hold the card near the top of the iPhone | Nakon dodira prislonite karticu na vrh iPhonea |
| 37 | `ready.ios.timeout` | S05 | Keine Karte erkannt. Zum Wiederholen „Karte scannen“ tippen. | No card detected. Tap “Scan card” to try again. | Kartica nije prepoznata. Dodirnite „Skeniraj karticu“ za novi pokušaj. |
| 38 | `ready.manual` | S05 | Kartennummer | Card number | Broj kartice |
| 39 | `ready.qr` | S05 | QR-Code | QR code | QR kôd |
| 40 | `ready.firstCardTip.android` | S05 | Tipp: Die NFC-Antenne sitzt meist hinten oben, nahe der Kamera. | Tip: the NFC antenna is usually at the top of the back, near the camera. | Savjet: NFC antena je obično gore na poleđini, blizu kamere. |
| 41 | `ready.firstCardTip.ios` | S05 | Tipp: Die Karte flach an die Oberkante halten, nahe der Kamera. | Tip: hold the card flat against the top edge, near the camera. | Savjet: držite karticu ravno uz gornji rub, blizu kamere. |
| 42 | `ready.noNfc.title` | S05 | QR-Code auf der Karte scannen | Scan the QR code on the card | Skenirajte QR kôd na kartici |
| 43 | `ready.noNfc.hint` | S05 | Dieses Gerät hat kein NFC. QR-Code oder Kartennummer verwenden. | This device has no NFC. Use the QR code or the card number. | Ovaj uređaj nema NFC. Koristite QR kôd ili broj kartice. |
| 44 | `ready.noNfc.button` | S05 | QR-Code scannen | Scan QR code | Skeniraj QR kôd |
| 45 | `ready.offline.tap` | S05 | Keine Verbindung – Karte kann nicht geprüft werden | No connection — the card can't be checked | Nema veze – kartica se ne može provjeriti |
| 46 | `ready.online` | S05 | Wieder verbunden | Connected again | Veza je ponovo uspostavljena |
| 47 | `maintenance.default` | S05 | Geplante Wartung: Einlösen kann kurz nicht möglich sein. | Scheduled maintenance: redeeming may be briefly unavailable. | Planirano održavanje: iskorištavanje može kratko biti nedostupno. |
| 48 | `maintenance.dismiss` (a11y) | S05 | Hinweis schließen | Dismiss notice | Zatvori obavijest |
| 49 | `ios.sheet.found` | S06 | Karte gefunden | Card found | Kartica pronađena |
| 50 | `ios.sheet.readFailed` | S06 | Karte nicht gelesen. Erneut versuchen. | Couldn't read the card. Try again. | Kartica nije pročitana. Pokušajte ponovo. |
| 51 | `ios.sheet.multiple` | S06 | Mehrere Karten erkannt. Nur eine Karte halten. | More than one card detected. Hold only one. | Prepoznato više kartica. Držite samo jednu. |
| 52 | `ios.sheet.timeoutSoon` | S06 | Noch keine Karte. Karte flach oben an das iPhone halten. | No card yet. Hold it flat near the top of the iPhone. | Još nema kartice. Prislonite je ravno na vrh iPhonea. |
| 53 | `scan.notCard` | S06 | Das ist keine Geschenkkarte | This is not a gift card | Ovo nije poklon-kartica |
| 54 | `scan.readFailed.title` | S06 | Karte konnte nicht gelesen werden | Couldn't read the card | Kartica nije pročitana |
| 55 | `scan.readFailed.body` | S06 | Karte eine Sekunde ruhig halten. | Hold it still for a second. | Držite je mirno jednu sekundu. |
| 56 | `scan.detected` (a11y announcement) | S06 | Karte erkannt | Card detected | Kartica prepoznata |
| 57 | `scan.lookingUp` | S06 | Karte wird gesucht … | Looking up card … | Tražimo karticu … |
| 58 | `scan.slow` | S06 | Suche dauert länger … | Still looking … | Još tražimo … |
| 59 | `scan.unavailable` | S06 | NFC gerade nicht verfügbar. Kartennummer oder QR-Code verwenden. | NFC isn't available right now. Use the card number or QR code. | NFC trenutno nije dostupan. Koristite broj kartice ili QR kôd. |
| 60 | `common.cancel` | S06 | Abbrechen | Cancel | Otkaži |
| 61 | `manual.title` | S11 | Kartennummer | Card number | Broj kartice |
| 62 | `manual.helper` | S11 | 16 Ziffern auf der Rückseite der Karte | 16 digits on the back of the card | 16 cifara na poleđini kartice |
| 63 | `manual.counter` | S11 | {count} von 16 | {count} of 16 | {count} od 16 |
| 64 | `manual.submit` | S11 | Karte suchen | Look up card | Pronađi karticu |
| 65 | `manual.error.invalid` | S11 | Kartennummer prüfen | Check the card number | Provjerite broj kartice |
| 66 | `manual.error.paste` | S11 | Keine gültige Kartennummer zum Einfügen | No valid card number to paste | Nema ispravnog broja kartice za lijepljenje |
| 67 | `common.back` (a11y) | S11 | Zurück | Back | Nazad |
| 68 | `keypad.doubleZero` (a11y) | S11 | Doppelnull | Double zero | Dvije nule |
| 69 | `keypad.delete` (a11y) | S11 | Löschen | Delete | Obriši |
| 70 | `keypad.delete.hint` (a11y) | S11 | Lange drücken, um alles zu löschen | Long press to clear | Dugo pritisnite za brisanje svega |
| 71 | `qr.title` | S12 | QR-Code scannen | Scan QR code | Skeniraj QR kôd |
| 72 | `qr.hint` | S12 | Kamera auf den QR-Code der Karte richten | Point the camera at the QR code on the card | Usmjerite kameru na QR kôd kartice |
| 73 | `qr.notCard` | S12 | Dieser QR-Code gehört zu keiner Geschenkkarte | This QR code isn't a gift card | Ovaj QR kôd nije poklon-kartica |
| 74 | `qr.dark` | S12 | Zu dunkel? Licht einschalten. | Too dark? Turn on the light. | Pretamno? Uključite svjetlo. |
| 75 | `qr.torchOn` (a11y) | S12 | Licht einschalten | Turn on light | Uključi svjetlo |
| 76 | `qr.torchOff` (a11y) | S12 | Licht ausschalten | Turn off light | Isključi svjetlo |
| 77 | `qr.manual` | S12 | Kartennummer eingeben | Enter card number | Unesi broj kartice |
| 78 | `common.close` (a11y) | S12 | Schließen | Close | Zatvori |
| 79 | `menu.close` (a11y) | S14 | Menü schließen | Close menu | Zatvori meni |
| 80 | `menu.restaurant` | S14 | Lokal | Restaurant | Restoran |
| 81 | `menu.device` | S14 | Gerät | Device | Uređaj |
| 82 | `menu.section.settings` | S14 | Einstellungen | Settings | Postavke |
| 83 | `menu.theme` | S14 | Darstellung | Appearance | Izgled |
| 84 | `menu.theme.system` | S14 | Wie System | Match system | Kao sistem |
| 85 | `menu.theme.light` | S14 | Hell | Light | Svijetlo |
| 86 | `menu.theme.dark` | S14 | Dunkel | Dark | Tamno |
| 87 | `menu.sound` | S14 | Töne | Sounds | Zvukovi |
| 88 | `menu.haptics` | S14 | Vibration | Haptics | Vibracija |
| 89 | `menu.haptics.unavailable` | S14 | Auf diesem Gerät nicht verfügbar | Not available on this device | Nije dostupno na ovom uređaju |
| 90 | `menu.keepScreenOn` | S14 | Bildschirm anlassen | Keep screen on | Ekran uvijek uključen |
| 91 | `menu.keepScreenOn.caption` | S14 | Während Scannen und Einlösen | While scanning and redeeming | Tokom skeniranja i iskorištavanja |
| 92 | `menu.sunlightTip` | S14 | Im Freien ist das helle Design besser lesbar. | Outdoors, the light theme is easier to read. | Na otvorenom je svijetla tema čitljivija. |
| 93 | `menu.help` | S14 | Hilfe | Help | Pomoć |
| 94 | `menu.version` | S14 | Version {version} | Version {version} | Verzija {version} |
| 95 | `menu.signOut` | S14 | Abmelden | Sign out | Odjavi se |
| 96 | `menu.signOut.confirm.title` | S14 | Abmelden? | Sign out? | Odjaviti se? |
| 97 | `menu.signOut.confirm.body` | S14 | Der Schichtverlauf wird von diesem Gerät gelöscht. | The shift history on this device will be deleted. | Historija smjene na ovom uređaju bit će izbrisana. |
| 98 | `session.expired.body` | S15 | Zum Weitermachen erneut anmelden. | Sign in again to continue. | Prijavite se ponovo za nastavak. |
| 99 | `session.expired.action` | S15 | Erneut anmelden | Sign in again | Ponovo se prijavi |
| 100 | `deviceRevoked.title` | S15 | Gerät wurde entfernt | This device was removed | Uređaj je uklonjen |
| 101 | `deviceRevoked.body` | S15 | Das Gerät ist nicht mehr für dieses Lokal freigegeben. Erneut anmelden oder Manager fragen. | It's no longer allowed for this restaurant. Sign in again or ask a manager. | Uređaj više nije odobren za ovaj restoran. Prijavite se ponovo ili pitajte menadžera. |
| 102 | `deviceRevoked.action` | S15 | Anmelden | Sign in | Prijavi se |
| 103 | `suspended.title` | S15 | Einlösen ist pausiert | Redeeming is paused | Iskorištavanje je pauzirano |
| 104 | `suspended.body` | S15 | Das Konto des Lokals ist pausiert. Bitte einen Manager holen. | The restaurant's account is paused. Please get a manager. | Račun restorana je pauziran. Molimo pozovite menadžera. |
| 105 | `suspended.retry` | S15 | Erneut prüfen | Check again | Provjeri ponovo |
| 106 | `locked.title` | S15 | Konto vorübergehend gesperrt | Account temporarily locked | Račun je privremeno zaključan |
| 107 | `locked.body` | S15 | Zu viele Anmeldeversuche. Erneut möglich in {time}. | Too many sign-in attempts. Try again in {time}. | Previše pokušaja prijave. Ponovo za {time}. |
| 108 | `locked.button` | S15 | Erneut in {time} | Try again in {time} | Ponovo za {time} |
| 109 | `locked.over` (a11y) | S15 | Anmelden ist wieder möglich | You can sign in again | Prijava je ponovo moguća |
| 110 | `deactivated.title` | S15 | Konto deaktiviert | Account deactivated | Račun je deaktiviran |
| 111 | `deactivated.body` | S15 | Dieses Konto kann nicht mehr verwendet werden. Bitte einen Manager holen. | This account can no longer be used. Please get a manager. | Ovaj račun se više ne može koristiti. Molimo pozovite menadžera. |
| 112 | `common.backToSignIn` | S15 | Zur Anmeldung | Back to sign in | Nazad na prijavu |
| 113 | `update.title` | S15 | Update erforderlich | Update required | Potrebno ažuriranje |
| 114 | `update.body` | S15 | Diese Version wird nicht mehr unterstützt. Zum Weiterarbeiten aktualisieren. | This version is no longer supported. Update to keep redeeming. | Ova verzija više nije podržana. Ažurirajte za nastavak rada. |
| 115 | `update.action` | S15 | Jetzt aktualisieren | Update now | Ažuriraj sada |
| 116 | `nfcOff.title` | S16 | NFC ist aus | NFC is off | NFC je isključen |
| 117 | `nfcOff.body` | S16 | NFC einschalten, um Karten zu scannen. | Turn on NFC to scan cards. | Uključite NFC za skeniranje kartica. |
| 118 | `nfcOff.action` | S16 | NFC einschalten | Turn on NFC | Uključi NFC |
| 119 | `nfcOff.on` (a11y) | S16 | NFC ist an. Bereit zum Scannen. | NFC is on. Ready to scan. | NFC je uključen. Spremno za skeniranje. |
| 120 | `camera.purpose` (OS usage string) | S16 | Die Kamera wird nur zum Scannen von QR-Codes auf Geschenkkarten verwendet. | The camera is only used to scan QR codes on gift cards. | Kamera se koristi samo za skeniranje QR kodova na poklon-karticama. |
| 121 | `nfc.purpose` (OS usage string, iOS) | S16 | NFC wird zum Lesen von Geschenkkarten verwendet. | NFC is used to read gift cards. | NFC se koristi za čitanje poklon-kartica. |
| 122 | `camera.denied.title` | S16 | Kamerazugriff ist aus | Camera access is off | Pristup kameri je isključen |
| 123 | `camera.denied.body` | S16 | Kamera in den Einstellungen erlauben, um QR-Codes zu scannen. | Allow camera access in Settings to scan QR codes. | Dozvolite pristup kameri u postavkama za skeniranje QR kodova. |
| 124 | `camera.denied.action` | S16 | Einstellungen öffnen | Open Settings | Otvori postavke |
| 125 | `camera.restricted.body` | S16 | Die Kamera ist auf diesem Gerät gesperrt. Kartennummer verwenden. | The camera is restricted on this device. Use the card number. | Kamera je ograničena na ovom uređaju. Koristite broj kartice. |
| 126 | `intro.skip` | S17 | Überspringen | Skip | Preskoči |
| 127 | `intro.next` | S17 | Weiter | Next | Dalje |
| 128 | `intro.start` | S17 | Loslegen | Start | Počni |
| 129 | `intro.page` (a11y) | S17 | Seite {n} von 3 | Page {n} of 3 | Stranica {n} od 3 |
| 130 | `intro.1.title.android` | S17 | Karte antippen | Tap the card | Prislonite karticu |
| 131 | `intro.1.body.android` | S17 | Die Karte an die Rückseite halten. Das Handy erkennt sie sofort. | Hold the card to the back of the phone. It's detected instantly. | Prislonite karticu na poleđinu telefona. Odmah se prepoznaje. |
| 132 | `intro.1.title.ios` | S17 | Scannen, dann Karte halten | Tap Scan, then hold the card | Skenirajte, pa prislonite karticu |
| 133 | `intro.1.body.ios` | S17 | „Karte scannen“ tippen, dann die Karte oben an das iPhone halten. | Tap “Scan card”, then hold the card near the top of the iPhone. | Dodirnite „Skeniraj karticu“, zatim prislonite karticu na vrh iPhonea. |
| 134 | `intro.1.title.noNfc` | S17 | QR-Code scannen | Scan the QR code | Skenirajte QR kôd |
| 135 | `intro.1.body.noNfc` | S17 | Kamera auf den QR-Code richten oder die Kartennummer eingeben. | Point the camera at the QR code or type the card number. | Usmjerite kameru na QR kôd ili unesite broj kartice. |
| 136 | `intro.2.title` | S17 | Betrag eingeben, einlösen | Type the amount, redeem | Unesite iznos, iskoristite |
| 137 | `intro.2.body` | S17 | Guthaben sehen, Betrag tippen, fertig. Ab {threshold} zum Bestätigen gedrückt halten. | See the balance, type the amount, done. From {threshold}, press and hold to confirm. | Pogledajte stanje, unesite iznos, gotovo. Od {threshold} držite za potvrdu. |
| 138 | `intro.3.title` | S17 | Nie doppelt gebucht | Never booked twice | Nikad dvaput knjiženo |
| 139 | `intro.3.body` | S17 | Eingelöst wird nur mit Verbindung. Alle Einlösungen der Schicht stehen unter „Verlauf“. | Redeeming only works online. Your shift's redemptions are under “Recent”. | Iskorištavanje radi samo uz vezu. Iskorištavanja iz smjene su pod „Nedavno“. |

---

Version 1.0 · September 2026 · GiftCard Waiter design specification
