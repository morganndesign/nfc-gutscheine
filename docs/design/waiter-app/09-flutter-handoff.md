# 09 · Flutter Handoff

**GiftCard Waiter** — what the Flutter team needs to build the app from this specification: token delivery, typography, component and screen inventory, the redeem transaction model, API contract, platform integration, budgets, acceptance criteria and open questions. Described in words and tables; no code.

| | |
|---|---|
| Document | 09 of 14 · (12) Design-to-engineering handoff |
| Audience | Flutter engineering (iOS + Android), backend engineering, QA, release management |
| Binding source | Design brief v1 (all sections), [API reference](../../API.md), [NFC guide](../../NFC.md) |
| Read first | [02 · IA and journey](02-information-architecture-and-journey.md) (state machine) · [12 · UI copy](12-ui-copy-and-error-messages.md) (error catalogue, strings) |
| Related | [01](01-product-vision-and-principles.md) · [03a](03a-screens-access-and-scanning.md) · [03b](03b-screens-charge-redeem-success-problems.md) · [04](04-design-system.md) · [05](05-component-library.md) · [06](06-motion-guidelines.md) · [07](07-accessibility-guidelines.md) · [08](08-responsive-behaviour.md) · [10](10-assets-icons-illustrations.md) · [11](11-sound-and-haptics.md) |

---

## Contents

1. [How to read this specification](#1-how-to-read-this-specification)
2. [Design-token delivery](#2-design-token-delivery)
3. [Typography setup](#3-typography-setup)
4. [State and transactions](#4-state-and-transactions)
5. [Screen inventory](#5-screen-inventory)
6. [Build foundations and component inventory](#6-build-foundations-and-component-inventory)
7. [Platform integration requirements](#7-platform-integration-requirements)
8. [Candidate packages to evaluate](#8-candidate-packages-to-evaluate)
9. [API contract and backend prerequisites](#9-api-contract-and-backend-prerequisites)
10. [Performance budgets](#10-performance-budgets)
11. [QA acceptance criteria](#11-qa-acceptance-criteria)
12. [Definition of done](#12-definition-of-done)
13. [Open questions](#13-open-questions)

---

## 1. How to read this specification

### 1.1 Document map — who owns what

| Question | Owner document | Engineering takes from it |
|---|---|---|
| Why does the app behave this way? | [01 · Vision and principles](01-product-vision-and-principles.md) | Tie-breaker in reviews (principles P1–P10, D1–D8) |
| Which screen follows which, and on what event? | [02 · IA and journey](02-information-architecture-and-journey.md) | **App state machine** (states, events, guards), navigation rules N1–N10, entry points, idempotency lifecycle |
| What does each screen look like and do? | [03a](03a-screens-access-and-scanning.md) (S01–S06, S11–S17) · [03b](03b-screens-charge-redeem-success-problems.md) (S07–S10, S13) | Layout, states, micro-interactions, per-screen acceptance criteria |
| Which values? | [04 · Design system](04-design-system.md) | All tokens (tiers 1–3), type scale, colour, elevation, motion/haptic/sound summaries |
| How is each component built? | [05 · Component library](05-component-library.md) | Anatomy, variants, states, component tokens |
| How does it move? | [06 · Motion](06-motion-guidelines.md) | Durations, curves, springs, choreography, Reduce Motion |
| How is it accessible? | [07 · Accessibility](07-accessibility-guidelines.md) | Labels, focus order, live regions, text scaling, hold-to-redeem alternative |
| How does it adapt? | [08 · Responsive](08-responsive-behaviour.md) | Width/height classes, tablet two-pane, orientation |
| How is it built? | **09 · this document** | Handoff, contracts, budgets, QA |
| Which files? | [10 · Assets](10-assets-icons-illustrations.md) | Icons, illustrations, fonts, sounds, app icons, splash |
| What does it sound and feel like? | [11 · Sound and haptics](11-sound-and-haptics.md) | Haptic/sound triggers and platform mapping |
| What does it say? | [12 · UI copy](12-ui-copy-and-error-messages.md) | **Master string table**, error catalogue, formatting rules |

### 1.2 Conventions

- **Screen IDs** `S01`–`S17` are used in routes, file names of screen modules, test case IDs and analytics-free logs. Never rename them.
- **Token names** (`color.bg.canvas`, `space.4`, `motion.duration.base`, `haptic.success`) are the public API between design and code. Code references tokens, never literal values.
- **Component names** (`PrimaryButton`, `BalanceCard`, `HoldButton` …) are binding (brief §6). Use them as the names of the Flutter components.
- **Copy keys** (`charge.redeem`, `getManager` …) from [12 §5](12-ui-copy-and-error-messages.md#5-master-string-table) are the only way strings enter the UI. No hard-coded user-visible text.
- **State names** (`Ready.Idle`, `Charge.Entering`, `Redeeming`, `Slow`, `Uncertain` …) come from [02 §4.5](02-information-architecture-and-journey.md) and are used in logs and test scripts.
- **"Decision"** in this document = settled for v1. **"Proposal (not part of v1)"** = not to be built without a product decision. **"Candidate"** = to evaluate, not mandated.
- **Units:** pt (iOS) = dp (Android) = logical pixel in Flutter. ms for durations. Money in cents in all logic; formatting only at the edge.

### 1.3 Precedence when documents disagree

1. The design brief. 2. [02](02-information-architecture-and-journey.md) for behaviour and state. 3. [04](04-design-system.md) for values. 4. [12](12-ui-copy-and-error-messages.md) for strings. 5. The screen documents. Topic owners that declare themselves authoritative win within their topic over the screen documents: [06](06-motion-guidelines.md) motion, [07](07-accessibility-guidelines.md) accessibility behaviour, [10](10-assets-icons-illustrations.md) assets and illustration, [11](11-sound-and-haptics.md) haptic/sound mapping. Decisions in the resolved conflicts register of [13 §7](13-future-and-design-review.md#7-resolved-conflicts-register) (R01–R23) are binding over all of the above except the brief. Report every conflict to design; do not resolve silently in code.

---

## 2. Design-token delivery

### 2.1 Source and format

| | |
|---|---|
| Source of truth | Token tables in [04](04-design-system.md) (tier 1–2) and [05](05-component-library.md) (tier 3) |
| Machine-readable export | `tokens/waiter.tokens.json`, W3C Design Tokens Community Group format (`$value`, `$type`, `$description`), one file for all themes |
| Versioning | Semantic version in the file (`$extensions.version`); a token rename is a major version and requires a code migration note |
| Delivery | Exported by design into the app repository via pull request; CI validates the schema and fails on unknown references |
| Generation | A build step turns the JSON into the app's theme data (colours per theme, spacing, radii, type styles, durations, curves, haptic/sound identifiers). Generated files are never edited by hand. |

### 2.2 JSON structure (data format example)

Colour tokens carry both themes and the high-contrast override; all other categories are theme-independent.

```json
{
  "$extensions": { "version": "1.0.0", "product": "giftcard-waiter" },
  "color": {
    "bg": {
      "canvas":  { "$type": "color", "$value": { "light": "#FAFAFA", "dark": "#0A0A0C" } },
      "surface": { "$type": "color", "$value": { "light": "#FFFFFF", "dark": "#141417" } }
    },
    "fg": {
      "secondary": { "$type": "color",
                     "$value": { "light": "#52525B", "dark": "#A1A1AA" },
                     "$extensions": { "highContrast": "{color.fg.primary}" } }
    },
    "accent": {
      "saffron": { "$type": "color", "$value": { "light": "#E8A33D", "dark": "#F0B454" },
                   "$description": "NFC rings, focus accents, hold ring. Never text on light." }
    },
    "scrim": { "$type": "color", "$value": { "light": "rgba(10,10,12,0.48)", "dark": "rgba(0,0,0,0.64)" } }
  },
  "space":  { "4": { "$type": "dimension", "$value": 16 }, "16": { "$type": "dimension", "$value": 64 } },
  "radius": { "l": { "$type": "dimension", "$value": 20 }, "sheet": { "$type": "dimension", "$value": 32 } },
  "type": {
    "amount": {
      "xl": { "$type": "typography",
              "$value": { "fontFamily": "Geist", "fontWeight": 600, "fontSize": 64, "lineHeight": 68,
                          "letterSpacing": "-2.5%", "fontFeatures": ["tnum"] },
              "$extensions": { "maxScale": 1.3, "minSizeAfterShrink": 40, "truncate": false } }
    }
  },
  "motion": {
    "duration": { "base": { "$type": "duration", "$value": "240ms" } },
    "ease":     { "standard": { "$type": "cubicBezier", "$value": [0.2, 0, 0, 1] } },
    "spring":   { "card": { "$type": "spring", "$value": { "response": 0.42, "damping": 0.82 } } }
  },
  "elev": {
    "2": { "$type": "shadow",
           "$value": { "light": { "x": 0, "y": 4, "blur": 16, "color": "rgba(0,0,0,0.08)" },
                       "dark":  { "surfaceStep": "{color.bg.raised}", "border": "{color.border.subtle}" } } }
  },
  "haptic": { "success": { "$type": "haptic",
              "$value": { "ios": "notification.success", "android": "CONFIRM+pattern[0,20,60,30]" } } },
  "sound":  { "success": { "$type": "sound", "$value": { "file": "gcw_success", "maxMs": 280 } } }
}
```

### 2.3 Naming

- Paths in the JSON mirror token names exactly: `color.bg.canvas` ↔ `color` → `bg` → `canvas`.
- Numeric scale steps stay strings in the JSON (`"4"`) and map to the step, not the value.
- `$type` values beyond the DTCG standard (`haptic`, `sound`, `spring`) are documented in the file header and consumed only by the generator.

### 2.4 Light, dark and high contrast

- The theme is resolved from (1) the Menu override (System / Light / Dark, persisted locally), else (2) the OS appearance ([04 §2](04-design-system.md)).
- High contrast (iOS Increase Contrast, Android High contrast text) is a **modifier on top** of the resolved theme: `fg.secondary → fg.primary`, `border.subtle → border.strong`, status banner text weight 600.
- Theme changes apply without restart and without resetting any screen state or input.
- Dark theme replaces shadows by surface steps + 1 pt `border.subtle` — the generator emits both and components pick per theme.
- The `BalanceCard` colour is **not** a token: it comes from the restaurant `brand_color` at runtime with the contrast fallback rules of [04 §8.6](04-design-system.md).

### 2.5 How tokens map to the Flutter theme (described)

| Token category | Becomes | Notes |
|---|---|---|
| `color.*` | Two colour schemes (light, dark) plus a high-contrast variant of each, exposed through the app's own theme extension, not only Material's colour scheme | Material roles (primary, surface …) are mapped for system widgets (text selection, scroll glow), but components read the semantic tokens |
| `type.*` | Named text styles with family, weight, size, line height (as height ratio), letter spacing (converted from % to absolute), font features (`tnum`) and scale limits | See §3 |
| `space.*`, `radius.*`, `size.*` | Constants grouped by category | |
| `elev.*` | Shadow lists per theme | |
| `motion.*` | Durations, curves, spring descriptions | Reduce Motion replacements in [06](06-motion-guidelines.md) |
| `haptic.*`, `sound.*` | Identifiers handed to the feedback service (§7.8) | Components never call platform haptics directly |

---

## 3. Typography setup

| Requirement | Detail |
|---|---|
| Bundled fonts | Geist Sans 400/500/600/700 and Geist Mono 500 as static TTFs ([10 §2.4](10-assets-icons-illustrations.md)); registered for the whole app; no Google Fonts runtime loading; no system-font fallback for Latin text |
| Default family | Geist Sans on both platforms (replaces San Francisco / Roboto in all app text, including dialogs and snackbars the app draws itself) |
| Tabular figures | `tnum` enabled on every style that can contain digits (all amount, balance, caption, key, label styles). Verified by test: "1111" and "0000" at `type.amount.xl` have identical widths |
| Letter spacing | Brief values are percentages of font size; convert to absolute values per style (e.g. −2.5 % × 64 = −1.6) — list in [04 Appendix](04-design-system.md) |
| Line height | Fixed per style (height ratio = line height / size); text centred by cap height as specified in [04 §3.2](04-design-system.md) |
| Text scaling clamps | Body, caption, labels: follow OS scale up to **200 %**. Amounts (`type.amount.*`, `type.balance`): up to **130 %**, then shrink-to-fit down to a minimum of **40 pt**; **never truncate an amount**. Titles: up to 150 %. Overline: 130 %. Keypad digits: 120 %. Card number (S11): 130 %, shrink min 20 |
| Scaling source | iOS Dynamic Type content size category / Android font scale (including Android 14 non-linear scaling) — the app applies its own per-style clamp on top of the OS factor |
| Bold Text | iOS Bold Text / Android bold text raise weights one step (400→500→600→700) ([04 §10.2](04-design-system.md)) |
| Glyph coverage | ä ö ü ß č ć š ž đ (upper and lower), € • · – … „ " and no-break space must render in Geist without fallback (test in §11) |
| Locale-aware formatting | Money/dates via the formatter rules in [12 §1.4–1.5](12-ui-copy-and-error-messages.md#14-numbers-and-currency); formatting never inside widgets ad hoc |

---

## 4. State and transactions

### 4.1 App state machine

The app state machine is specified in **[02 §4.5](02-information-architecture-and-journey.md)** (diagram, states, events, guards). It is binding. Engineering implements it as one explicit state holder for the loop (Ready → Scanning → LookingUp → Charge → Redeeming → Success) plus global handlers for session/account events (`HTTP_401`, `DEVICE_REVOKED`, `RESTAURANT_SUSPENDED`, `ACCOUNT_LOCKED`, update required) that can interrupt any state.

Implementation rules:

1. Every state transition is logged locally (state name, event, timestamp; no card data, no amounts) in a ring buffer of 500 entries for diagnostics. Never sent anywhere in v1.
2. Screens render **from state**; a screen never owns business state (amount, card, key) itself — this is what makes orientation changes, theme changes and resume lossless ([02 N10](02-information-architecture-and-journey.md)).
3. Timers (4 s auto-return, 3 s "still looking", 8 s slow, 10 s lookup timeout, 20 s uncertain (automatic-retry cap), throttle countdowns, 15 min background) are driven by a monotonic clock, not wall-clock time.

### 4.2 Card context

| Item | Lifetime |
|---|---|
| Card context (`/scan` response) | From LOOKUP_OK until S07 is closed, a new card replaces it, or the app is in background > 15 min |
| Typed amount | Cleared on card change, close, or background > 15 min; kept on theme/orientation change and on the 401 re-sign-in in redeem context |
| Read data (URL, UID, SUN values) | Used for one `/scan` request, then discarded; never persisted, never logged |

### 4.3 Idempotency-key lifecycle (rules)

The lifecycle is specified in [02 §4.5.4](02-information-architecture-and-journey.md) and in detail in [03b §1.1](03b-screens-charge-redeem-success-problems.md). A **redeem attempt** = one (card id, amount) pair plus one `Idempotency-Key`. Engineering rules:

| # | Rule |
|---|---|
| K1 | A key is a UUID v4 generated **when the Redeem action starts** (tap-up on `PrimaryButton`, or `HoldButton` reaching 100 %) — never earlier (not on amount entry). |
| K2 | The key is bound to the tuple **(card id, amount in cents)** of the signed-in user. |
| K3 | **Before generating**, check for a pending attempt with the same tuple; if one exists, reuse its key. |
| K4 | Every automatic retry and every manual "Erneut versuchen" sends the **same key** and the **identical body** (same `amount`; the app sends no `reference`/`note` in v1). Each HTTP attempt gets a **new** `X-Request-Id`. |
| K5 | The attempt is **closed** (key discarded) on: 201 / 200 `replayed: true`; any definitive 4xx (§9.3); `DEVICE_REVOKED` / `RESTAURANT_SUSPENDED`; amount change; card switch; S07 closed; sign-out; business-day rollover. |
| K6 | The attempt is **kept** on: timeout, transport error, offline, 5xx; "Abbrechen" in the uncertain (final) state; `401` (kept across re-authentication on the S15 session sheet, then back on S07 with the same amount). |
| K7 | Pending attempts live **in memory only**. A process kill discards them; the waiter re-scans and the fresh balance is authoritative. Nothing is ever queued or re-sent after a restart. |
| K8 | On `409 IDEMPOTENCY_CONFLICT` (should not occur given K4): close the attempt, restore S07 with `redeem.tapAgain`, **never resubmit automatically** — a money action always needs a new human action. |
| K9 | The key never appears in the UI, in logs outside the local diagnostic buffer, or in crash reports. |

> **Alignment note.** [02 §5.7 E08](02-information-architecture-and-journey.md), [03b §3](03b-screens-charge-redeem-success-problems.md) and this document share one rule set: silent automatic retries with the same key for up to 20 s after the tap, then "Erneut versuchen" (same key) / "Abbrechen"; attempt kept across 401; in-memory only. Invariant: one attempt can book at most once.

### 4.4 Redeem transaction state table

The redeem transaction is a sub-machine of `Charge` / `Redeeming` ([02 §4.5](02-information-architecture-and-journey.md), [03b §3.1](03b-screens-charge-redeem-success-problems.md)). Mapping: Idle = `Charge.Entering` with amount 0 · Editing = `Charge.Entering` with amount > 0 · Submitting = `Redeeming` (03b states 1–2) · Retrying = `Slow` (03b state 3) · Uncertain = `Uncertain` (03b states 4–5) · Success = `Success` · Failed = definitive rejection (03b state 6).

| State | Entered when | UI (S07 / S08) | Network | Key | Exits |
|---|---|---|---|---|---|
| **Idle** | Card loaded, amount 0 (or a card-state variant) | Keypad active; button `charge.enterAmount` disabled. Partial disabled: amount fixed to balance, `charge.redeemFull` enabled | none | none | KEY → Editing · partial disabled: REDEEM → Submitting · CLOSE → Ready |
| **Editing** | Amount > 0 | `charge.redeem` (or `HoldButton` with `charge.hold` at ≥ € 100,00); guards: over balance, max single (once known), offline, rate/velocity countdown, switch-card snackbar visible | none | none, or a kept attempt for this tuple (after "Abbrechen" or 401) | KEY → Editing (closes a kept attempt if the amount changes) · amount → 0 → Idle · REDEEM_TAP / HOLD_COMPLETE with guards → Submitting · HOLD released before 600 ms → Editing (nothing sent) |
| **Submitting** | Redeem started | Label kept 0–150 ms, then `Spinner` + `charge.redeeming`; keypad, chip, ✕, back and edge swipe locked; Android card taps ignored; iOS links for other cards queued | `POST /cards/{id}/redeem`, attempt timeout 8 s | generated (K1) or reused (K3) | 2xx → Success · definitive 4xx → Failed · 401 → session sheet (attempt kept) · 8 s timeout → Retrying · transport error / offline / 5xx → Uncertain |
| **Retrying** ("Connection slow") | First attempt unanswered after 8 s | `Spinner` + `redeem.slow`; helper `uncertain.body`; no haptic or sound | First request **aborted** and re-sent immediately with the same key; attempt timeout 8 s | same | 2xx → Success · definitive 4xx → Failed · transport failure or second timeout → Uncertain |
| **Uncertain — auto** ("Connection interrupted") | Transport error, offline, 5xx, second timeout | Uncertain panel replaces helper, chip and keypad: `uncertain.title`, `uncertain.body`, `uncertain.retrying` ("Versuch {n} von 3"), `uncertain.guestHint`; `haptic.warning` once, no sound | Retries with the same key after **1 s, 2 s, 4 s** (each attempt 8 s); a connectivity-restored event skips the current wait | same | 2xx (incl. `replayed`) → Success · definitive 4xx → Failed · 3 retries failed **or 20 s since the tap** → Uncertain — final |
| **Uncertain — final** | Automatic retries exhausted | Panel with `uncertain.failedBody` + guest hint; `SecondaryButton` `common.cancel` · `PrimaryButton` `common.tryAgain`; support code; Android back / iOS edge swipe = Cancel | One automatic retry when connectivity is restored; otherwise only on "Erneut versuchen" | same (kept) | "Erneut versuchen" → Submitting (same key) · "Abbrechen" → Editing with the `uncertain.cancelled` banner, attempt kept (K6) |
| **Success** | 201 or 200 `replayed: true` | S09; `haptic.success` + `sound.success`; Recent row appended from `data.transaction` + `data.card` (deduplicated by transaction id) | none | closed | TIMER_4S / TAP → Ready · Android CARD_IN_FIELD → LookingUp · iPhone "Nächste Karte scannen" → Scanning · "Dem Gast zeigen" → presentation mode |
| **Failed** | Definitive 4xx | Back to S07 per [12 §3.2](12-ui-copy-and-error-messages.md#32-redeem--post-apiv1cardsidredeem): card updated from the error `context` or code (never by re-posting a SUN URL — [03b §1.2](03b-screens-charge-redeem-success-problems.md)); helper `redeem.nothingBooked` for card-state rejections | none | closed | → Editing / Idle, or the card-state variant |

**Invariants (automated tests):**

- I1: Two redeem requests for the same tuple never carry different keys unless a definitive answer arrived in between.
- I2: No redeem request is sent while the OS reports no network path (Editing shows `offline.body`, button disabled).
- I3: `replayed: true` renders exactly like 201; Recent never gets a second row for the same transaction id.
- I4: Leaving S07/S08 by navigation is impossible in Submitting, Retrying and Uncertain — auto.
- I5: The amount and remaining balance on S09 come from the server response, never from local input; the `BalanceCard` never shows a reduced balance before confirmation.
- I6: No copy in Retrying or Uncertain claims that nothing was booked.

### 4.5 Lifecycle interactions

| Event during a redeem | Behaviour |
|---|---|
| App to background (< 15 min) in Submitting / Retrying / Uncertain | The in-flight request continues if the OS allows; on foreground the state resumes and the next retry with the same key resolves the outcome ([02 §4.3](02-information-architecture-and-journey.md)) |
| App to background > 15 min | Card context and attempt dropped (N9); on return the waiter re-scans |
| App killed | Attempt lost (K7); re-scan shows the true balance |
| Sign-out | Token, Recent and any attempt deleted |
| 04:00 rollover | Recent cleared |
| Clock or time-zone change | Business day is computed in the restaurant time zone from `/auth/me`; the device time zone is irrelevant; all timers use a monotonic clock |

### 4.6 Recent (local shift history)

- Built only from redeem 2xx responses on this device for the signed-in user; keyed by transaction id; max 200 rows (oldest dropped); stored encrypted at rest with the platform's data protection (iOS file protection "complete until first user authentication"; Android app-private storage); cleared on sign-out, on 04:00 rollover (restaurant time zone) and on user change.
- Row fields: transaction id, created_at, card last4, amount, remaining balance, restaurant name. Nothing else (no full card number, no card id in the UI).

---

## 5. Screen inventory

Routes are logical identifiers for the router and deep links, not web URLs. Card data is never part of a route (routes may be logged).

| ID | Screen | Route id | Presentation | Layer ([02 §4.2](02-information-architecture-and-journey.md)) | Reader mode (Android) | Keep awake |
|---|---|---|---|---|---|---|
| S01 | Splash | `splash` | Full screen, native splash → first Flutter frame | — | off | — |
| S02 | Sign in | `signIn` | Full screen | Access | off | — |
| S03 | Enable biometrics | `biometrics` | Full screen; OS biometric prompt as system sheet | Access | off | — |
| S04 | Unlock | `unlock` | Full screen; OS biometric prompt auto-shown | Access | off | — |
| S05 | Ready (Home) | `ready` (root) | Full screen, root; variants: android, ios, noNfc, offline, maintenance, nfcOff | 0 | **on** | on |
| S06 | Scanning | Android: state of `ready` · iPhone: system NFC sheet (`NFCTagReaderSession`) | Inline state / **system sheet** | 0 / system | on | on |
| S07 | Charge | `charge` | Full screen (vertical/scale transition from scan origin, never a horizontal push) | 1 | **on** | on |
| S08 | Redeeming | state of `charge` | In-place | 1 | taps ignored | on |
| S09 | Success | `success` | Full screen (replaces `charge`) | 1 | **on** | on |
| S10 | Problem | `problem/{variant}` — `notFound`, `notFoundManual`, `foreign`, `verify`, `verifyFinal`, `throttled`, `network`, `server`, `notGiftCard`, `conflict` | Full screen (`ProblemScreen`) | 1 | on (re-tap allowed) | on |
| S11 | Manual entry | `manual` | Full screen | 1 | off | on |
| S12 | QR scan | `qr` | Full screen, camera; variant `cameraDenied`, `cameraUnavailable` | 1 | off | on |
| S13 | Recent / Recent detail | `recent`, `recent/detail` (transaction id held in state, not route) | **Bottom sheet**; detail = sheet on sheet | 2 | off | on |
| S14 | Menu | `menu`; sign-out confirmation `Dialog` | **Bottom sheet** | 2 | off | on |
| S15 | Session & account | `sessionExpired` (**bottom sheet**, not dismissible, over any layer) · `blocked/{variant}` — `forbidden`, `deviceRevoked`, `suspended`, `locked`, `deactivated` (full screen, replaces stack) · `updateRequired` (full screen, blocking) · maintenance = `Banner` on S05 | Sheet / full | 2 / replaces | off | off (blocked, update) |
| S16 | Permission states | variants of `ready` (`nfcOff`, `nfcUnsupported`) and `qr` (`cameraDenied`) | In-place | 0 / 1 | off | on |
| S17 | First-run intro | `intro` | Full screen, 3-page pager | Access | off | — |
| — | Deep link | `https://<domain>/c/{token}` | Resolved to LookingUp (method `link`) after the access gate | — | — | — |

---

## 6. Build foundations and component inventory

### 6.1 Component inventory

Names are binding (brief §6). Specifications: [05](05-component-library.md). Priority: **P0** = needed for the redeem loop (S05–S10), **P1** = needed for release, **P2** = variant or refinement.

| Component | Priority | Used on | Depends on | Notes for engineering |
|---|---|---|---|---|
| `PrimaryButton` (large 64 / regular 56) | P0 | all | tokens, `Spinner` | Label may carry an amount and break at " · " ([12 §1.8](12-ui-copy-and-error-messages.md#18-length-limits)) |
| `HoldButton` | P0 | S07/S08 | `PrimaryButton`, `ProgressRing`, feedback service | 600 ms hold, ticks at 33/66/100 %, accessible alternative action ([07](07-accessibility-guidelines.md)) |
| `Keypad` | P0 | S07, S11 | tokens, feedback service | 3 × 4: 1–9, 00, 0, ⌫; long-press ⌫ clears; ≥ 72 pt keys (64 compact); `haptic.key` |
| `AmountDisplay` | P0 | S07 | formatter, `type.amount.xl` | POS entry (digits shift in from the right), max 7 digits, shrink-to-fit, never truncate |
| `BalanceCard` | P0 | S07, S09 (small) | brand colour logic, `StatusBadge` | ID-1 ratio, squircle on iOS, contrast fallback, desaturation for blocked/expired/replaced |
| `StatusBadge` | P0 | S07 | icons | 6 statuses |
| `StatusBanner` | P0 | S07, S08 | icons | info/warning/danger/success |
| `NfcScanAnimation` | P0 | S05 Android | motion tokens | native vector drawing, Reduce Motion = static rings |
| `SuccessMark` | P0 | S09 | motion tokens | native path drawing (Lottie fallback only per [10 §2.6](10-assets-icons-illustrations.md)) |
| `CountdownHairline` | P0 | S09 | motion tokens | 4 s, interruptible |
| `QuickAmountChip` | P0 | S07 | formatter | |
| `Skeleton` | P0 | S06/S07 | motion tokens | appears after 150 ms |
| `Spinner` | P0 | buttons | | 20 pt, 2 pt stroke |
| `ProgressRing` | P0 | `HoldButton`, S10 throttled, S15 locked | | |
| `IconButton` | P0 | all | | 56 pt target |
| `TopBar` + `Avatar` | P0 | S05 | | restaurant name, initials, Recent, Menu |
| `ProblemScreen` | P0 | S10, S15, S16 | illustrations/icons | template: illustration, title, body, support code, ≤ 2 actions |
| `Snackbar` | P0 | S05, S07, S14 | | 4 s, one action |
| `SecondaryButton`, `TertiaryButton` | P0 | all | | |
| `Banner` | P1 | S05 (offline, maintenance) | | |
| `BottomSheet` | P1 | S13, S14, S15 session | | `radius.sheet`, scrim, drag handle |
| `TextField` | P1 | S02, S15 session | | e-mail, password with visibility toggle |
| `CardNumberField` | P1 | S11 | Geist Mono | groups of 4 |
| `TransactionRow`, `HistoryCard` | P1 | S13 | formatter | |
| `EmptyState` | P1 | S13 | illustration | |
| `Dialog` | P1 | S14 sign-out, S07 switch-card fallback | | only these two uses |
| `DangerButton` | P1 | S14 sign-out confirm only | | |

### 6.2 Build order

| Wave | Content | Exit criterion |
|---|---|---|
| **0 · Foundations** | Token generator and theme (light/dark/high contrast), fonts and text styles with clamps, formatter (money, dates, spoken amounts), localisation pipeline, feedback service (haptics + sounds), secure storage, API client with headers and error mapping (§9), state holder skeleton, router with S-IDs | Token snapshot tests pass; formatter unit tests for all locale rows in [12 §1.4](12-ui-copy-and-error-messages.md#14-numbers-and-currency) |
| **1 · Platform spikes** (parallel to wave 0) | Android reader mode with UID + NDEF; iOS tag reader session with NTAG21x and NTAG 424 DNA; universal/app links; biometric prompt incl. enrolment-change detection; native path drawing of `SuccessMark` | Each spike demonstrated on the reference devices (§11.3) with real cards |
| **2 · The loop** | S05 (Android + iPhone variants), S06, S07 (active + all card states), S08 (all sub-states), S09, S10 variants; P0 components | Tap-to-ready ≤ 5 s on reference devices; redeem state table (§4.4) test suite green |
| **3 · Alternatives** | S11, S12, S16 | |
| **4 · Access and session** | S01, S02, S03, S04, S17, S15 all variants, token handling | |
| **5 · Periphery** | S13, S14, maintenance/update, tablet layouts ([08](08-responsive-behaviour.md)) | |
| **6 · Hardening** | Accessibility pass ([07](07-accessibility-guidelines.md)), performance budgets (§10), test matrix (§11.3), store assets ([10 §5](10-assets-icons-illustrations.md)) | Definition of done (§12) |

### 6.3 Assets

All files, formats and names: [10](10-assets-icons-illustrations.md). Icons and illustrations are rendered as vectors with runtime colours; no PNGs in the app except platform launcher/splash needs.

### 6.4 Theming of system surfaces

- Status bar / navigation bar: icons follow the resolved theme; S12 camera forces light-on-dark; sheets keep the underlying screen's bar style.
- Android edge-to-edge (required on Android 15+): the app draws behind system bars and respects insets ([08](08-responsive-behaviour.md)).
- System dialogs the app cannot style (biometric prompt, NFC sheet, permission prompts) are left native.

### 6.5 Localisation resources

| Item | Rule |
|---|---|
| Source | Master string table in [12 §5](12-ui-copy-and-error-messages.md#5-master-string-table); translators work on exported resource files, and changes flow back into 12 |
| Format | ARB files with ICU MessageFormat (plurals, placeholders); one file per language: `app_de.arb`, `app_en.arb` (template), `app_bs.arb`; `app_hr.arb` and `app_sr.arb` are generated copies of `app_bs.arb` at build time so system locale matching works for all three |
| Key mapping | Spec key → resource identifier: remove dots, lowerCamelCase: `charge.redeemFull` → `chargeRedeemFull`, `ios.sheet.alert` → `iosSheetAlert`, `getManager` → `getManager`. The spec key is kept in the ARB `@` metadata (`"description"`) for traceability |
| Language selection | Phone language de\* → DE, en\* → EN, bs/hr/sr (any script/region) → BHS (Latin), anything else → EN (brief §7). Android 13+ per-app language setting is supported with the same list |
| Number/date locale | Restaurant locale for DE/EN UI, BHS pattern for BHS UI ([12 §1.4](12-ui-copy-and-error-messages.md#14-numbers-and-currency)); the restaurant locale and time zone come from `/auth/me` and are cached |
| Platform strings | iOS `InfoPlist.strings` in `de`, `en`, `bs`, `hr`, `sr`, `sr-Latn` (all BHS Latin) for the three usage descriptions (§7.3); Android: app name only (not translated) |
| Pseudo-localisation | A build flag renders every string +40 % longer with accents (e.g. "[Ķàŕţé šçàññéñ ~~~~]") to test layouts |
| Missing key | Build fails (no runtime fallback to key names) |

---

## 7. Platform integration requirements

### 7.1 Android NFC (reader mode)

| Requirement | Detail |
|---|---|
| Mode | **Reader mode** on the current activity while Ready, Charge and Success (and Problem, for re-tap) are in the foreground; disabled in all other states ([02 §4.5.2](02-information-architecture-and-journey.md)) and when the app pauses |
| Flags | Poll **NFC-A only** (NTAG21x and NTAG 424 DNA are ISO 14443-A); **no platform sounds** (the app plays `sound.cardDetected` itself after a successful read); NDEF check **left enabled** so the NDEF message is read by the system and delivered with the tag |
| Presence check delay | **250 ms** (extra for the reader-mode presence check) — detects card removal quickly and keeps the next tap responsive |
| Data read | NDEF URI record (the card URL, including `picc`/`cmac` for 424 DNA) and the tag identifier (UID) formatted as upper-case hex bytes joined by colons (`04:A2:3F:1B:6C:80:12`) |
| Validation before any request | URL must match `https://<allowed domain>/c/<UUID v4>` (allowed domains from build config); otherwise `scan.notCard` without a network request. Non-NDEF tags (bank cards) → same, silently counted |
| Feedback order | Read complete → `haptic.cardDetected` + `sound.cardDetected` → lookup. Never before the read completes |
| Duplicate reads | The same UID read again within 2 s after a completed read is ignored (card lingering on the phone; [03a §6.1](03a-screens-access-and-scanning.md)) |
| Background taps | Manifest intent filter for NDEF discovery on `https://<domain>/c/` so a tap while the app is not in the foreground opens the app **with the tag** (UID available → method `nfc`); App Links (§7.4) cover QR/links (method `link`) |
| NFC state | Listen for adapter state changes; NFC off → S05 `nfcOff` variant with a button opening the system NFC settings; no NFC hardware → `nfcUnsupported` variant. Manifest declares NFC as **not required** so tablets without NFC can install |
| Permissions | NFC (normal permission, no prompt) |

### 7.2 iOS NFC (tag reader session)

| Requirement | Detail |
|---|---|
| Session type | Tag reader session polling **ISO 14443** (MIFARE family covers NTAG21x; NTAG 424 DNA may surface as MIFARE (DESFire family) or ISO 7816 — confirm in the wave-1 spike) — required to read the **UID** in addition to NDEF. An NDEF-only reader session is not sufficient (no UID) |
| Start | Only on user action: "Karte scannen" (S05) or "Nächste Karte scannen" (S09) |
| Alert texts | Start: `ios.sheet.alert` · success: `ios.sheet.found` (system shows ✓, then the app invalidates the session; sheet dismisses in ≈ 0.3–0.6 s) · multiple tags: `ios.sheet.multiple`, restart polling after 500 ms · read error: `ios.sheet.readFailed` (keep session, restart polling after 400 ms) · 45 s without a card (15 s before the system timeout): `ios.sheet.timeoutSoon` · not a card URL: `scan.notCard`, keep session, restart polling after 1 000 ms (values owned by [03a §6.2](03a-screens-access-and-scanning.md)) |
| Timeout | The system ends the session after ≈ 60 s → return to S05 **silently** with `ready.ios.timeout`. User cancel → same, silent |
| System busy | Session cannot start (system resource unavailable) → snackbar `scan.unavailable` |
| Data read | Tag identifier → UID (same format as Android); NDEF message → URL (incl. SUN parameters) |
| Entitlements / Info.plist | NFC tag reading capability with the tag format (and NDEF); usage description (§7.3); ISO 7816 application identifier list containing the NFC Forum Type 4 NDEF application `D2760000850101` (needed if 424 DNA surfaces as ISO 7816) |
| Background tag reading | iPhone XS and later read the card URL while the app is closed and offer to open it; the universal link (§7.4) opens S07 via method `link` (no UID → see [open question 4](#13-open-questions)) |
| iPad | No NFC; the iPad variant of S05 is QR/manual-first; no NFC wording |

### 7.3 Info.plist usage descriptions

Strings from [12 §5.21](12-ui-copy-and-error-messages.md#521-platform-strings-os-owned-surfaces), localised via `InfoPlist.strings`:

| Key | DE | EN | BHS |
|---|---|---|---|
| NFC reader usage | Zum Lesen von Gutscheinkarten per NFC. | Reads gift cards via NFC. | Za čitanje poklon kartica putem NFC-a. |
| Camera usage | Zum Scannen der QR-Codes auf Gutscheinkarten. | Scans the QR codes on gift cards. | Za skeniranje QR kodova na poklon karticama. |
| Face ID usage | Zum Entsperren der App mit Face ID. | Unlocks the app with Face ID. | Za otključavanje aplikacije pomoću Face ID-a. |

No location, contacts, photos, microphone, tracking or notification permissions are requested. App Tracking Transparency is not needed (no tracking).

### 7.4 Universal links and App Links

| | iOS | Android |
|---|---|---|
| Mechanism | Associated Domains `applinks:<domain>` (production + staging) | Intent filter with auto-verify for `https://<domain>/c/` |
| Server file | `/.well-known/apple-app-site-association` with the app ID and component `/c/*` | `/.well-known/assetlinks.json` with the package name and the **Play App Signing** SHA-256 fingerprint (plus upload key for internal builds) |
| Behaviour | Link opens the app → access gate (S02/S04 if needed) → LookingUp with method `link` and the full URL as `token`; pending link kept 120 s ([02 §4.3](02-information-architecture-and-journey.md)) | same |
| Fallback | Without the app, the URL keeps working in the browser (web terminal / public balance page) — backend prerequisite 3 | same |

### 7.5 Secure storage

| Item | iOS | Android |
|---|---|---|
| Access token | Keychain, accessible **after first unlock, this device only** (no iCloud Keychain sync, not in backups) | Encrypted with an AES-GCM key held in the **Android Keystore** (StrongBox when available), ciphertext in app-private storage; excluded from cloud backup and device transfer |
| Device id (`X-Device-Id`) | Keychain, same class; generated once (UUID v4, 36 chars — within the 16–64 range) | Same as token |
| Reinstall | iOS keeps Keychain items across reinstall: on first launch after install (no local "installed" marker) the app deletes its Keychain items → new device id, signed out | App data removed with the app |
| Recent (idempotency attempts are memory-only, K7) | Encrypted file with complete-until-first-authentication protection | App-private encrypted storage |
| Biometric gate | Biometrics gate the **app** (UI unlock), not the token read — background refresh of `/app/config` and resumed redeems need the token without a prompt | same |
| Enrolment change | Detect a changed biometric set (evaluated policy domain state on iOS; a Keystore key invalidated by new enrolment on Android) → `unlock.changed`, require password | same |

Settings (theme, sound, haptics, keep screen on, first-run flags) are ordinary preferences, not secrets.

### 7.6 Biometric authentication

- iOS: LocalAuthentication with device-owner authentication (biometrics with the **OS passcode fallback**, brief §2); reason string `biometrics.reason`; Face ID usage description required.
- Android: BiometricPrompt allowing **Class 3 (strong) and Class 2 (weak)** biometrics plus device credential (PIN/pattern/password) as the OS fallback; title `biometrics.reason`, subtitle `biometrics.promptSubtitle.android`. Because device credential is allowed, the prompt has no negative button; "Passwort verwenden" is on S04 itself.
- Prompt is shown automatically on S04 on cold start and after > 15 min in background; cancel leaves S04 with `unlock.button.*` and `unlock.usePassword`.
- S03 offers enabling once after first sign-in; enrolment missing → `biometrics.notEnrolled.*`.

### 7.7 Keep screen on

Screen stays awake while S05, S07, S08, S09, S10 are visible **and** the setting "Keep screen on" is on (default on). Sheets (S13, S14) keep it on — the shift continues underneath. It is released when the app goes to background and on S01–S04, S15 blocking states and S17. The app never changes screen brightness.

### 7.8 Haptics and sound channels

| | iOS | Android |
|---|---|---|
| Haptics | Mapping per `haptic.*` token ([04 §16](04-design-system.md), [11](11-sound-and-haptics.md)): impact (light/medium/rigid), selection, notification (success/warning/error) generators, prepared ahead of expected events (e.g. when Redeem is pressed) to hit ≤ 30 ms latency | View-based haptic constants (KEYBOARD_TAP, CLOCK_TICK, CONFIRM, REJECT on API 30+) and vibration waveforms from the token table below API 30; respect the system "touch feedback" setting |
| Haptic implementation note | Flutter's built-in haptic calls do not cover notification-type feedback or waveforms → a thin platform channel ("feedback service") is required | same |
| Sound session | Ambient audio category: **respects the silent switch**, mixes with other audio, does not duck music | Plays as notification/sonification usage; **skipped when ringer mode is silent or vibrate** |
| Loading | All four sounds preloaded at app start into a low-latency player/pool | same |
| User switches | Menu "Töne" / "Vibration" gate the service; default on | same |

### 7.9 Screen capture — decision

**Decision: no screen-capture protection in v1.** The app shows no customer data (brief §0); balances and masked card numbers are what the guest sees anyway, and screenshots are useful for support. iOS app-switcher snapshots and Android recents thumbnails are left default.

### 7.10 Transport security and certificate pinning — decision

**Decision: no certificate pinning in v1.** TLS only: TLS 1.2+ via the platform stack, no cleartext traffic (iOS ATS default; Android network security config disallows cleartext and user-installed CAs in release builds). Pinning is listed as a **future consideration** (needs a key-rotation plan with backup pins and a remote kill-switch via `/app/config` before it can be safe).

### 7.11 Orientation, windowing

Phones portrait-locked; tablets all orientations; iPad split view/slide over supported with the width classes of [08](08-responsive-behaviour.md); Android multi-window: the app remains functional down to 360 × 480 dp, reader mode only when the app window is focused.

---

## 8. Candidate packages to evaluate

**Candidates only — not mandated.** Each must pass: active maintenance, null safety, licence compatible with closed-source distribution (MIT/BSD/Apache), no transitive analytics/ads SDKs, and the platform requirements in §7. A thin platform channel is always an acceptable alternative.

| Need | Candidate(s) | What to verify |
|---|---|---|
| NFC (Android reader mode + iOS tag session) | `nfc_manager` | Reader-mode flags (NFC-A only, no platform sounds, presence-check delay extra); UID on both platforms; iOS ISO 14443 polling with custom alert messages and `restartPolling`; NTAG 424 DNA on iOS. If any flag is not exposed → own platform channel for NFC |
| Biometrics | `local_auth` | Android Class 2 + device credential combination; iOS passcode fallback; enrolment-change detection (may need a small platform addition) |
| Secure storage | `flutter_secure_storage` | Keychain accessibility class "after first unlock, this device only"; Android Keystore-backed encryption (not deprecated EncryptedSharedPreferences paths); reinstall behaviour |
| QR scanning | `mobile_scanner` | QR-only format filter, torch, start < 500 ms, lifecycle pause/resume, no ML-kit bundled model bloat beyond size budget |
| Keep screen on | `wakelock_plus` | Enable/disable per screen |
| Universal/App links | `app_links` | Cold and warm link delivery |
| Connectivity | `connectivity_plus` | Used only as a hint (NETWORK_DOWN/UP); requests decide ([02 §4.5.3](02-information-architecture-and-journey.md)) |
| HTTP | `dio` or `http` | Per-request timeout, cancellation, interceptors for headers and error mapping |
| Localisation | Flutter's `gen-l10n` with `intl` | ICU plurals incl. BHS few; de-AT/de-CH/en-GB/bs number formats |
| UUID | `uuid` | v4 from a cryptographically secure source |
| Low-latency sound | `soundpool` / `just_audio` / own channel | < 50 ms start latency, silent-switch behaviour, ringer-mode check |
| App version / store | `package_info_plus`, `url_launcher` | Version for `/app/config` comparison; open store listing and NFC settings |
| Vector rendering | `flutter_svg` or build-time vector compilation | Runtime recolouring by role (`line`/`accent`) for illustrations |

---

## 9. API contract and backend prerequisites

### 9.1 Common request rules

| Item | Rule |
|---|---|
| Base URL | `https://<domain>/api/v1` (per environment in build config) |
| Auth | `Authorization: Bearer <token>` from the native token login (prerequisite 1) — no cookies, no CSRF |
| `X-Device-Id` | On **every** request, including sign-in: the stable per-install id (§7.5) |
| `X-Request-Id` | On every request: new UUID v4 per HTTP attempt (also per retry). Last 6 characters form the support code ([12 §2.5](12-ui-copy-and-error-messages.md#25-support-code)); full id written to the local diagnostic ring buffer |
| `Idempotency-Key` | On redeem only (§4.3) |
| `Accept` / `Content-Type` | `application/json` |
| `Accept-Language` | UI language (`de`, `en`, `bs`) — used by the backend for server-provided texts (maintenance notice) |
| `User-Agent` | `GiftCardWaiter/<version> (<platform> <os version>; <device model>)` |
| Timeouts | Connect 5 s; lookup total 10 s (UI "still looking" at 3 s); redeem 8 s per attempt; others 10 s |
| Amounts | Integer cents in requests and responses; never floating point |
| Errors | Body `{message, code, context}`; the app switches on `code` (never on `message`), falls back to HTTP status |

### 9.2 Per screen

| Screen | Endpoint | Request | Success → state | Errors → state |
|---|---|---|---|---|
| S01 | `GET /app/config` (public, prerequisite 4) | `platform`, `version` | Store min version + maintenance notice → continue | Timeout 2 s or error → continue (non-blocking); below min version → S15 `updateRequired` |
| S01 / resume | `GET /auth/me` | — | Refresh user, permissions, restaurant settings (name, locale, time zone, `brand_color`, `allow_partial_redemption`, `max_single_redemption`) | 401 → S02 (cold start) / S15 session sheet (warm); 403 codes → S15 blocked variants |
| S02 | `POST /auth/token` (prerequisite 1) | `{email, password, device_id, device_name, platform}` | Token stored → S03 (first time) / S17 / S05 | 422 / 401 → `signIn.error.invalid` · 403 `FORBIDDEN` → `signIn.error.noPermission` · 423 → S15 `locked` · 429 → `signIn.error.throttled` · 403 `DEVICE_REVOKED` → S15 · offline → `signIn.offline.body` · 5xx → `signIn.error.server` |
| S04 | none (local biometric) | — | → S05; `/auth/me` in background | — |
| S05 | none while idle; `/app/config` on resume (max once per 5 min) | — | Banner update | — |
| S06 / S11 / S12 / link | `POST /scan` | `{method: nfc, token: <url>, nfc_uid}` · `{method: qr, token}` · `{method: manual, card_number: <16 digits>}` · `{method: link, token}` | Card context → S07 (active) or S07 card-state variant | [12 §3.1](12-ui-copy-and-error-messages.md#31-card-lookup--post-apiv1scan) L01–L12 |
| S07 / S08 | `POST /cards/{id}/redeem` | `{amount}` + `Idempotency-Key` | `{data: {card, transaction}, replayed}` → S09; Recent row | [12 §3.2](12-ui-copy-and-error-messages.md#32-redeem--post-apiv1cardsidredeem) R01–R18; state table §4.4 |
| S13 | none (local) | — | — | — |
| S14 | `GET /devices/current` (device name, on open, cached) · `POST /auth/logout` on sign-out | — | Sign-out: token deleted locally **even if the request fails** | — |
| S15 | `GET /auth/me` for "Erneut prüfen" | — | Back to the previous state | Same code → stay |

### 9.3 Error classification

| Class | Codes | Client behaviour |
|---|---|---|
| **Definitive rejection** (nothing booked, key discarded) | 400 `IDEMPOTENCY_KEY_REQUIRED`, `VALIDATION_FAILED`; 403 all codes; 404; 409 `INVALID_CARD_STATE`, `IDEMPOTENCY_CONFLICT`; 422 all codes; 423; 429 `SCAN_THROTTLED`, `VELOCITY_LIMIT_EXCEEDED`, `TOO_MANY_REQUESTS` | Show the mapped message; no automatic retry |
| **Session** | 401 `UNAUTHENTICATED` | S15 session sheet; the rejected request booked nothing; in redeem context the attempt and key are **kept** (K6) |
| **Uncertain** (request may have been processed) | Timeout after the request was sent, connection reset, 408, 5xx, 502/503/504 | Redeem: Retrying/Uncertain with the same key. Lookup: S10 `network`/`server` (safe to repeat) |
| **Not sent** | No network path before sending, DNS failure, TLS handshake failure | Redeem: stays in Editing with `offline.body` (no key generated); lookup: L10 |

### 9.4 Backend prerequisites (checklist for the backend team)

From brief §8. The app cannot ship without items 1–4.

- [ ] **1. Token login for native apps** — `POST /auth/token {email, password, device_id, device_name, platform}` → device-bound Sanctum token with abilities `cards.scan` and `cards.redeem` only; **30-day rolling expiry** (refreshed on use); revocable via Devices (revocation → `403 DEVICE_REVOKED` or `401` on the next call); same login rate limits and `ACCOUNT_LOCKED` behaviour as `/auth/login`; `POST /auth/logout` revokes the current token. (Today only cookie SPA login and owner-created API tokens exist.)
- [ ] **2. Settings exposure** — `max_single_redemption` (cents or null), `brand_color`, `locale` (and time zone) in the `/scan` response or `/auth/me`; the error for exceeding the maximum returns the limit in `context`.
- [ ] **3. Universal Links / App Links** — serve `apple-app-site-association` and `assetlinks.json` for `/c/*` on every card domain; web fallback unchanged.
- [ ] **4. `GET /app/config`** (public) — minimum supported app version per platform, maintenance notice text (per locale), optional `allowed_card_domains`; cacheable (60 s).
- [ ] **5. (Optional, later)** waiter-scoped read of the user's own transactions today — would replace the local Recent.
- [ ] **Verify** (no new work expected): `/scan` accepts `method: link` and `method: qr` with full URLs including `picc`/`cmac`; `nfc_uid` format with colons; `/cards/{id}/redeem` returns `replayed: true` with the original transaction for a repeated key; concurrent requests with the **same** key return the original result or a retryable status — never a 500 that looks like a failure ([open question 5](#13-open-questions)).

---

## 10. Performance budgets

### 10.1 Budgets

| Metric | Budget | Measured on | How |
|---|---|---|---|
| Cold start → S04 visible (biometrics) / S05 (no biometrics) | **< 1.5 s** | iPhone SE 3, Galaxy A-series reference | Launch to first interactive frame, release build, median of 10 |
| Warm resume → S05 interactive | **< 400 ms** | same | Background < 15 min |
| NFC read complete → `haptic.cardDetected` | < 50 ms | Android reference | Instrumented timestamps |
| Lookup response → S07 fully rendered | **< 150 ms** | all | Response received to first frame with balance |
| Skeleton shown if lookup slower than | 150 ms | — | Rule, brief §3 |
| Key press → digit visible + haptic | < 50 ms | all | |
| Redeem response → S09 first frame | < 100 ms | all | |
| Frame rate | **60 fps**, **120 fps on ProMotion / 120 Hz Android** | all | No more than 1 dropped frame per transition; no shader-compilation jank on first run of each transition |
| Tap-to-ready (typical, brief §3) | Android ≈ 3.5 s · iPhone ≈ 4.5 s · always < 5 s excluding typing and network variance — measured from the Ready (Home) screen S05 with the app already unlocked (app open / unlock not included) | reference devices | Scripted run with real cards |
| App download size | **< 25 MB** (per-architecture download, both stores) | store reports | Asset payload ≤ 2.5 MB ([10](10-assets-icons-illustrations.md)) |
| Memory | < 200 MB resident on S07; QR camera < 300 MB | low-end Android | |
| Battery | Reader mode + keep-awake for a 6 h shift ≤ 35 % on the Android reference device (screen at 50 %) | Galaxy A-series | Test shift |

### 10.2 Network

Payloads are small (< 2 KB). The app keeps one HTTP/2 connection warm while in the foreground (connection reuse saves ~ 100–300 ms per lookup on mobile networks).

### 10.3 Analytics and telemetry — decision

**Decision: no third-party analytics, crash or attribution SDKs in v1.** Crash data comes only from the stores' built-in reporting (App Store Connect, Play Console vitals), which the user controls through OS settings.

**Proposal (not part of v1 behaviour, off by default):** anonymous timing metrics to the own backend — per event only `{metric name, duration ms, platform, app version, device class}` for tap-to-lookup, lookup-to-render, redeem round-trip, cold start; no card data, no user id, no device id; batched daily; enabled only by a restaurant-level setting and a Menu disclosure. Requires an endpoint, a privacy review and a product decision.

---

## 11. QA acceptance criteria

### 11.1 Global criteria (every screen)

- G1 All strings come from [12 §5](12-ui-copy-and-error-messages.md#5-master-string-table) in DE, EN, BHS; no truncation at 320 pt width at 100 % text size; at 200 % every body/label text is fully readable (wrapping allowed) and no amount is truncated.
- G2 Every interactive element ≥ 56 × 56 pt and has a VoiceOver/TalkBack label; focus order top → bottom.
- G3 Light, dark and high-contrast themes render per [04](04-design-system.md); switching theme keeps state.
- G4 Reduce Motion replaces movement with 160 ms cross-fades; progress indicators stay.
- G5 Primary actions are in the bottom 45 % of the screen on phones.
- G6 Fonts: glyph test string "Ää Öö Üü ß Čč Ćć Šš Žž Đđ € 1.234,50 • · – … „x"" renders in Geist without fallback.

### 11.2 Per screen

| Screen | Acceptance criteria (each testable) |
|---|---|
| **S01** | Mark shown ≤ 600 ms when config responds < 600 ms; spinner appears only after 1 s; native splash → first Flutter frame without visible jump; `/app/config` failure does not block start; below-minimum version → S15 update. |
| **S02** | Submit enabled only with non-empty fields; invalid credentials → `signIn.error.invalid`, password cleared, e-mail kept; 423 → S15 locked with countdown; 429 → inline, button disabled for `Retry-After`; "Passwort vergessen" opens the web page; keyboard "next/go" order e-mail → password → submit; password manager autofill works on both platforms. |
| **S03** | Shown once per install after the first sign-in; label matches the device capability (Face ID / Touch ID / Android biometrics); "Nicht jetzt" never shows S03 again; not enrolled → snackbar, stays on S03. |
| **S04** | Biometric prompt appears automatically within 300 ms of S04; success → S05 ≤ 400 ms; cancel leaves retry and "Passwort verwenden"; enrolment change → password required; shown on cold start and after > 15 min background only. |
| **S05** | Android: reader mode active within 200 ms of S05 visible, platform NFC sound never heard, NFC glyph animation runs (static with Reduce Motion); iPhone: "Karte scannen" in thumb zone opens the NFC sheet ≤ 400 ms; iPad/no-NFC: QR/manual variant, no NFC wording; offline banner appears ≤ 2 s after airplane mode on and disappears with `ready.online`; maintenance banner shows server text; TopBar shows restaurant, initials, Recent, Menu. |
| **S06** | Android: tap → haptic+sound after read, skeleton after 150 ms, `scan.slow` "Suche dauert länger …" at 3 s, S10 network at 10 s; card removed mid-read → `scan.readFailed.title`, reader continues; bank card → `scan.notCard`, no request sent (verified in network log). iPhone: alert texts per §7.2; multiple cards → message and restart; 60 s timeout → S05 silent with hint; the UID is included in `/scan` for NTAG21x on both platforms. |
| **S07** | Balance card renders brand colour with correct text colour (contrast ≥ 4.5 : 1, else ink fallback); POS entry "2 4 9 0" → € 24,90; 8th digit ignored with announcement; ⌫ deletes one, long-press clears; amount > balance → inline `charge.overBalance`, button disabled, chip sets amount to balance; partial disabled → keypad hidden, `charge.redeemFull`; amount ≥ € 100,00 → `HoldButton`; each card state (blocked, expired, inactive, replaced, zero) shows badge + banner, no keypad, no Redeem; full card number visible in header; Android new card with amount 0 → replaced with cross-fade; with amount > 0 → switch snackbar, card unchanged until "Wechseln". |
| **S08** | Spinner after 150 ms; no navigation possible while submitting; hold released before 600 ms sends nothing; slow state at 8 s; network cut after send → uncertain with the **same** `Idempotency-Key` on every retry (verified in server log); reconnect → S09 exactly once and one ledger entry; retries at +1 / +2 / +4 s; after 3 retries or 20 s the final state shows "Erneut versuchen" / "Abbrechen" and the support code; "Erneut versuchen" and a Redeem after "Abbrechen" with the unchanged amount reuse the key and book at most once; no copy claims that nothing was booked ([03b AC-S08-1…16](03b-screens-charge-redeem-success-problems.md)). Definitive 4xx → S07 with the mapped message and a new key on the next attempt. |
| **S09** | Amount and remaining balance from the server response; `haptic.success` + `sound.success` on the first frame of the SuccessMark circle draw (circle 240 ms, then check 200 ms — [06 M18](06-motion-guidelines.md), [11](11-sound-and-haptics.md) T3); countdown hairline 4 s then S05; any tap returns immediately; Android: a new card tap during S09 opens S07 for the new card; iPhone: "Nächste Karte scannen" opens the sheet in one tap; Recent gains exactly one row (none for a replay of an already-listed transaction). |
| **S10** | Each variant shows the title/body/actions of [12 §3](12-ui-copy-and-error-messages.md#3-error-catalogue); throttled countdown uses `retry_after` and enables "Erneut scannen" at 0; verify: one rescan offered, never QR/manual options; a lookup whose URL carries `picc`/`cmac` is never re-posted; support code shown only on the variants listed in [12 §2.5](12-ui-copy-and-error-messages.md#25-support-code); feedback per [11](11-sound-and-haptics.md). |
| **S11** | Numeric keypad only; groups of 4 in Geist Mono; submit enabled at exactly 16 digits; counter `manual.counter` "{count} von 16" updates per digit and is announced; not found → back to S11 with digits kept. |
| **S12** | Camera starts < 500 ms; only QR codes recognised; foreign QR → `qr.notCard` without request; torch toggle; denied → S16 camera state with "Einstellungen öffnen"; returning from settings with permission granted starts the camera without restart. |
| **S13** | Rows only from this device, this user, since 04:00 restaurant time; newest first; summary total equals the sum of rows; empty state with illustration 96 pt; detail sheet shows the reverse note; list cleared on sign-out and at 04:00; max 200 rows. |
| **S14** | Theme switch applies instantly; sound/haptic switches take effect on the next event; keep-screen-on toggle works; sign-out confirmation deletes token, Recent and any attempt and lands on S02; version shown. |
| **S15** | 401 anywhere → session sheet over the current layer; lookup context → S05 after sign-in; redeem context → S07 with amount kept and the same attempt (K6); revoked/deactivated → token and Recent cleared, only "Zur Anmeldung"; suspended/forbidden → "Erneut prüfen" calls `/auth/me`; locked → countdown; update required cannot be dismissed. |
| **S16** | NFC turned off in settings → S05 nfcOff within 1 s; turning it on → reader mode resumes without restart; no-NFC device shows QR/manual variant; camera denied state per S12. |
| **S17** | Shown once after the first sign-in; three cards; "Überspringen" on every card; total reading time ≤ 30 s; never shown again after completion or skip; deep link during intro defers the intro to the next S05. |

### 11.3 Test matrix

| Device | OS versions | Focus |
|---|---|---|
| iPhone SE (3rd gen) | iOS 16 (minimum), iOS 18 | Compact height (< 700 pt), Touch ID, performance floor |
| iPhone 15 / 16 | iOS 18, iOS 26 (current) | Reference iPhone, Face ID, background tag reading, Dynamic Island |
| iPhone 16 Pro Max (or newest Pro Max) | iOS 26 | 120 Hz ProMotion, large width, Dynamic Type 200 % |
| iPad (10th gen) or iPad Air | iPadOS 17, iPadOS 26 | No NFC, QR/manual, split view, landscape two-pane |
| Google Pixel 7 | Android 14 | Reference Android, reader mode, themed icon |
| Google Pixel 8 | Android 15, Android 16 | Edge-to-edge, predictive back, 120 Hz |
| Samsung Galaxy A-series (A15 / A25) | Android 14 (One UI 6) | Low/mid-range performance floor, NFC antenna position (centre-back), battery test |
| Samsung Galaxy S-series (S23 / S24) | Android 14/15 (One UI 6/7) | Samsung NFC stack, One UI launcher masks |
| Android 9 device with NFC (e.g. older Galaxy A or Nokia) | Android 9 (API 28, minimum) | Haptic fallbacks without CONFIRM/REJECT, legacy splash |
| Android tablet (Galaxy Tab S-series) | Android 14 | Tablet layouts, NFC present/absent handling |

**Card set per device:** NTAG213, NTAG215, NTAG216 (UID-bound), NTAG 424 DNA (SUN), a cloned NTAG (UID mismatch), a copied 424 URL (replay), QR-only printed card, card from another restaurant, blocked / expired / inactive / replaced / zero-balance cards, a bank card and a transit card (not a gift card), card through a thick phone case.

**Conditions:** airplane mode toggled at each redeem sub-state; 3G throttling (400 ms RTT); captive-portal Wi-Fi; server returning 500/503; clock and time-zone change; 04:00 rollover during a shift; text size 100 % / 200 %; Bold Text; Increase Contrast; Reduce Motion; VoiceOver and TalkBack full loop; silent switch on/off; ringer vibrate; system haptics off; left-hand use.

---

## 12. Definition of done

A screen, component or flow is done when:

- [ ] It matches its screen/component specification in all states listed there, on iOS and Android, in light, dark and high contrast.
- [ ] All strings come from the master table in DE, EN and BHS; pseudo-localisation shows no clipping.
- [ ] Acceptance criteria in §11.2 and in the screen document pass on at least one iOS and one Android reference device, with real cards where NFC is involved.
- [ ] Accessibility: labels, focus order, live announcements and text scaling per [07](07-accessibility-guidelines.md) verified with VoiceOver and TalkBack.
- [ ] Motion, haptics and sound per [06](06-motion-guidelines.md) and [11](11-sound-and-haptics.md), including Reduce Motion and the Menu switches.
- [ ] Performance budgets in §10 met in a release build on the reference low-end device.
- [ ] Redeem-related work: the state-table invariants I1–I5 are covered by automated tests (including simulated timeouts, connection loss after send, 5xx and `replayed: true`).
- [ ] No user-visible hard-coded string, colour, size or duration (lint rule / review).
- [ ] No customer data, full card numbers (outside S07 header and S11), UIDs, tokens, keys or request ids in logs, crash reports or analytics.
- [ ] Design review sign-off (screenshots in all three languages, both themes) and QA sign-off recorded.

**Release-level:** all backend prerequisites 1–4 live in production; universal/App Links verified on production domains; store assets complete ([10 §5](10-assets-icons-illustrations.md)); pilot restaurant run of one full service without a manager intervention caused by the app.

---

## 13. Open questions

Only questions that block or change implementation. Owner in brackets.

| # | Question | Why it matters | Owner |
|---|---|---|---|
| 1 | **Token login endpoint design:** is "30-day rolling" implemented as sliding expiry on the same token, or as a short-lived access token plus refresh token? What does the response contain (token, expiry, user, restaurant settings)? Where does `device_name` come from — the OS model name, or editable in the dashboard only? | Determines token storage, refresh logic, the 401 path and the Menu "Gerätename" source | Backend |
| 2 | **Account deactivated:** deactivation revokes tokens, so the next call returns plain 401 — indistinguishable from an expired session. Can the API return a dedicated code (e.g. `ACCOUNT_DEACTIVATED`) on requests and on token login? | Without it, S15 "account deactivated" cannot be shown; the waiter sees "Sitzung abgelaufen" and fails to sign in with an unhelpful message | Backend |
| 3 | **Max single redemption error:** which code and `context` does the server return when `max_single_redemption` is exceeded (reuse `INVALID_AMOUNT` with `context.max`?) | Copy R02 vs R03 selection | Backend |
| 4 | **`link` method and clone detection:** iPhone background tag reads and App Links deliver no UID, so UID-bound NTAG21x cards cannot be clone-checked on that path (NTAG 424 DNA is still verified via SUN). Accept for v1, or should the server require an in-app NFC scan for UID-bound cards above a balance/amount threshold? | Security posture of the most convenient iPhone path | Product + backend |
| 5 | **Concurrent same-key requests:** when the client retries after its 8 s timeout while the first request is still being processed, what does the server return for the second request? It must be the original result (after waiting) or a retryable status (e.g. 409 "in progress" with a distinct code), never a 500 from a unique-index violation. | The Retrying state relies on it; a 500 would be treated as uncertain (safe) but prolongs the uncertain state | Backend |
| 6 | **Device identity after reinstall:** a reinstall creates a new device id (§7.5). A waiter whose device was revoked can therefore sign in again as a "new" device. Is that acceptable in v1, or should new devices require manager approval? | Meaning of "device revoked" for managers | Product |
| 7 | **`VELOCITY_LIMIT_EXCEEDED` details:** is there a `retry_after` or a window length in `context`? | Whether copy can state a time instead of "später" | Backend |
| 8 | **Maintenance notice localisation:** does `/app/config` return the notice per locale, or one text? | Fallback string `maintenance.default` vs server text | Backend |
| 9 | **iOS NTAG 424 DNA surfacing:** does CoreNFC present the 424 DNA as MIFARE (DESFire family) or ISO 7816 on current iOS versions, and is the NDEF read with SUN parameters identical to Android? | Entitlement/Info.plist configuration and the NFC package choice | Engineering spike (wave 1) |
| 10 | **Bundle identifiers, domains and store names** follow the platform name decision ("GiftCard Waiter" is a working name). Needed before universal links, App Links and store listings can be configured. | Release setup | Product |

---

Version 1.0 · September 2026 · GiftCard Waiter design specification
