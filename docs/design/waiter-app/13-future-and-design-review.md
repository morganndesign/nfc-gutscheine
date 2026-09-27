# 13 · Future Considerations and Design Review

**GiftCard Waiter** — what v1.0 deliberately leaves out and how the system is prepared for it (deliverable 19), and the complete review of documents 01–12 against the brief, WCAG 2.2 AA and platform conventions (deliverable 20).

| | |
|---|---|
| Document | 14 of 14 · (19) Future design considerations · (20) Complete design review |
| Audience | Product, design, Flutter engineering, backend, QA, accessibility audit, pilot restaurants |
| Binding source | Design brief v1 (§1 scope, §3 timing budget, §8 backend prerequisites, §10 quality bar) |
| Owner of | The **resolved conflicts register** (§7, R01–R23) — binding across all documents, second only to the brief ([09 §1.3](09-flutter-handoff.md#13-precedence-when-documents-disagree)) · the consolidated open questions with recommended defaults (§11) · the sign-off record (§13) |
| Related | [01 · Vision and principles](01-product-vision-and-principles.md) · [02 · IA and journey](02-information-architecture-and-journey.md) · [03a](03a-screens-access-and-scanning.md) · [03b](03b-screens-charge-redeem-success-problems.md) · [04 · Design system](04-design-system.md) · [05 · Components](05-component-library.md) · [06 · Motion](06-motion-guidelines.md) · [07 · Accessibility](07-accessibility-guidelines.md) · [08 · Responsive](08-responsive-behaviour.md) · [09 · Flutter handoff](09-flutter-handoff.md) · [10 · Assets](10-assets-icons-illustrations.md) · [11 · Sound and haptics](11-sound-and-haptics.md) · [12 · UI copy](12-ui-copy-and-error-messages.md) |

Everything in Part 1 is **not part of v1.0**. Where Part 1 sketches a design, it is a **Proposal (not part of v1)** in the sense of the brief; nothing here adds a screen, token or copy key to v1. Part 2 changes v1 only through the resolved conflicts register (§7) and the fixes logged in §8.

---

## Contents

**Part 1 — Future design considerations (19)**
1. [The admission test for anything new](#1-the-admission-test-for-anything-new)
2. [Overview and classification](#2-overview-and-classification)
3. [Considerations in detail](#3-considerations-in-detail) (3.1–3.15)

**Part 2 — Complete design review (20)**
4. [Method](#4-method)
5. [Scorecard](#5-scorecard)
6. [Happy-path walk-through — Android vs iPhone](#6-happy-path-walk-through--android-vs-iphone)
7. [Resolved conflicts register](#7-resolved-conflicts-register)
8. [Review findings](#8-review-findings)
9. [Risk register](#9-risk-register)
10. [Backend prerequisites](#10-backend-prerequisites)
11. [Open questions — consolidated, with recommended defaults](#11-open-questions--consolidated-with-recommended-defaults)
12. [Implementation-readiness checklist](#12-implementation-readiness-checklist)
13. [Sign-off](#13-sign-off)
14. [Final verdict](#14-final-verdict)

---

# Part 1 — Future Design Considerations

## 1. The admission test for anything new

GiftCard Waiter exists for one loop: **scan → redeem → next guest** ([01 §1.5](01-product-vision-and-principles.md#15-the-tap-loop)). Every future idea must pass the test in [01 §1.4](01-product-vision-and-principles.md#14-what-it-is--what-it-will-never-be) — *does it make the loop faster, safer or calmer?* — and, in addition, these five guardrails. A proposal that fails one of them belongs in the dashboard or a manager app, not here.

| # | Guardrail | Why | Checked against |
|---|---|---|---|
| G1 | **No new step in the loop.** A feature may add a layer *beside* the loop (Menu row, sheet), never a screen or tap *inside* S05 → S07 → S09. | P1 "one screen · one task · one decision"; the < 5 s budget has 0.56 s headroom on iPhone (§6). | [01 P1](01-product-vision-and-principles.md#p1--one-screen--one-task--one-decision), [02 §5.1](02-information-architecture-and-journey.md#51-timing-budget) |
| G2 | **Money moves only with a server confirmation.** No local balance, no deferred booking, no optimistic UI. | P3; brief §1 "Never redeem offline". | [03b §1.1](03b-screens-charge-redeem-success-problems.md#11-the-redeem-attempt-idempotency-lifecycle) |
| G3 | **One primary action, in the thumb zone.** A new feature may not add a second `PrimaryButton` to any screen. | P4, D2. | [04 §4.5](04-design-system.md#45-thumb-zone-map) |
| G4 | **Waiter permissions stay `cards.scan` + `cards.redeem`.** Anything needing more (reload, block, reverse, reports) is a different app or the dashboard. | Least privilege; a lost phone must not be able to create value. | brief §0 |
| G5 | **Every new state is fully designed** (layout, copy in DE/EN/BHS, haptic, sound, a11y, tablet) before it ships — no "we'll add the error later". | P8. | [01 P8](01-product-vision-and-principles.md#p8--every-state-is-designed), brief §10 |

**Classification used below**

| Class | Meaning |
|---|---|
| **v1.1** | Planned for the first update (≈ 3 months after launch); design work can start now. |
| **v1.x** | Plausible later; revisit when the stated trigger occurs. The current system is prepared, no work is scheduled. |
| **Never (waiter app)** | Rejected for this app on principle. May exist elsewhere (dashboard, a manager app). Re-opening requires a product decision that changes 01 §1.4. |

---

## 2. Overview and classification

| § | Consideration | Class | Main trigger to revisit | Prepared by |
|---|---|---|---|---|
| 3.1 | Portrait lock revisit (WCAG 1.3.4) | **v1.1** | Accessibility audit, mounted-phone requests | [08 §4](08-responsive-behaviour.md#4-orientation) tablet landscape layouts |
| 3.2 | Tips and split payments | **Never (waiter app)** | — (only a change of product scope) | Idempotent single-amount redeem |
| 3.3 | Multi-restaurant waiters (switch tenant) | v1.x | ≥ 1 pilot group with shared staff | Restaurant name in `TopBar`, 403 `CARD_FOREIGN_RESTAURANT` screen |
| 3.4 | Shared device / staff PIN switch | v1.x | Restaurants reporting shared phones (risk RK-05) | S04 Unlock, `Keypad`, Recent keyed by device + waiter |
| 3.5 | Offline queueing | **Never** | — | `offline.body`, S05 V6, uncertain state |
| 3.6 | Apple Tap to Pay · Wallet gift card passes | Tap to Pay: **Never** · QR in Wallet: v1.x · NFC Wallet pass: v1.x (evaluation) | Guests asking for Wallet cards | S12 QR, universal links, `method: qr / link` |
| 3.7 | POS integration hand-off | v1.x | A POS partner with an API | `reference` field on redeem, universal-link entry to S07 |
| 3.8 | Languages beyond DE/EN/BHS (IT, SL, TR, HR) | v1.x | Market entry outside AT/DE/CH/Balkans | Key-based master table, length limits, locale-driven formatting |
| 3.9 | Large text beyond AX3 / 200 % | v1.x | Audit with low-vision staff | Pinned action region, shrink-to-fit amounts, `BalanceCard / compact` |
| 3.10 | Watch / wearable | **Never** | — | — |
| 3.11 | Reload / sell cards in the app | **Never (waiter app)** | — (manager app) | Permission model |
| 3.12 | Analytics events for the < 5 s goal | **v1.1** | Product + privacy decision (09 §10.3) | Screen IDs, state machine events, request ids |
| 3.13 | Platform changes: iOS 26 (Liquid Glass), Android 15/16 | v1.1 (verification) | Each OS major release | Own drawn UI, token system, "no blurred materials" rule |
| 3.14 | Foldables | v1 baseline · refinements v1.x | Foldable share among pilot devices | [08 §6.1](08-responsive-behaviour.md#61-foldables) |
| 3.15 | Configurable hold-to-redeem threshold | v1.x | Restaurants with high average bills | Constant `holdToConfirmThresholdCents`, `{threshold}` placeholder |

---

## 3. Considerations in detail

Each consideration uses the same four fields: **Trigger** (the signal that reopens it) · **Design implications** · **Already prepared in v1** · **Classification**.

### 3.1 Portrait lock revisit (WCAG 1.3.4 Orientation)

| Field | Content |
|---|---|
| Trigger | Scheduled for v1.1 by [07 §2 SC 1.3.4](07-accessibility-guidelines.md#2-wcag-22-aa-mapping) and [08 §4.1](08-responsive-behaviour.md#41-phones); earlier if an accessibility audit rejects the "essential" argument, or if waiters with mounted phones (wheelchair mounts, counter stands) ask for landscape. |
| Design implications | Landscape on phones means ≈ 320–430 pt of height: the S07 fixed stack (618 pt regular, 550 compact — [03b §2.4](03b-screens-charge-redeem-success-problems.md#24-vertical-budget-and-balancecard-sizing)) cannot fit. The only acceptable layout is the **tablet two-pane S07** ([08 §4.2](08-responsive-behaviour.md#42-tablets--landscape-two-pane-charge-s07)) scaled down: `BalanceCard / compact` + AmountDisplay left, Keypad (keys 56 pt high, the touch minimum) + CTA right. The one-handed NFC hold (card at the top-back, thumb at the bottom 45 %) does not exist in landscape; Android must show where the antenna now is (left or right edge), iPhone's sheet asks for "the top" which becomes a side. Recommendation: **unlock landscape on phones only when a hardware keyboard or an external display is attached, or via an explicit "Allow landscape" switch in Menu (default off)** — this keeps the essential exception for normal use and removes the barrier for mounted use. |
| Already prepared | Two-pane S07 and landscape rules for S05/S09/S10 on tablets ([08 §4.2–4.3](08-responsive-behaviour.md#43-tablets--other-screens-in-landscape)); runtime class changes preserve state ([08 §1.4](08-responsive-behaviour.md#14-class-changes-at-runtime)); hardware-keyboard digit entry on S07 ([08 §7](08-responsive-behaviour.md#7-hardware-keyboards-ipad-android-tablets-phones-with-keyboards)). |
| Classification | **v1.1** (decision + design); implementation of the Menu switch is small because layouts exist. |

### 3.2 Tips and split scenarios — explicitly out of scope

| Field | Content |
|---|---|
| Trigger | None inside this app. Reopened only if the product defines gift-card tips as a *restaurant-accounting* feature (dashboard) — not as a waiter action. |
| Why it stays out | (1) **Scope**: tips and receipts are listed in brief §1 "Out of scope v1 (never show)". (2) **P1/G1**: a tip adds a second decision to S07 ("how much for the bill, how much for me") and a social pressure moment in front of the guest; 01 §1.4 forbids a tips prompt. (3) **Conflict of interest**: the waiter would be entering an amount that benefits the waiter from the guest's stored value; audits would need a separate transaction type. (4) **Split** (several cards or card + cash on one bill) is already possible without any feature: redeem the card's part (the balance chip "Use balance · € 32,50", [03b §2.11](03b-screens-charge-redeem-success-problems.md#211-variant--amount--balance)) and collect the rest by the restaurant's usual means; a second card is simply the next loop. |
| Design guidance if asked again | If a guest wants to tip from the card, the waiter types the **total including tip** as one amount — the app does not distinguish. Any "tip" field would require: a separate line in the redeem request, a separate row type in Recent, dashboard reporting and legal review; none of these belong to the waiter app. |
| Already prepared | One-amount redeem, over-balance chip, idempotent one-attempt model, Recent rows per redemption. |
| Classification | **Never (waiter app).** |

### 3.3 Multi-restaurant waiters (switching tenant)

| Field | Content |
|---|---|
| Trigger | A pilot group of restaurants sharing staff (e.g. two sites of one owner), or support tickets "card from another restaurant" where the waiter actually works at both. |
| Design implications | The restaurant becomes a **session attribute the waiter chooses once per shift**, never per card. Proposal: Menu (S14) row "Restaurant" turns from read-only into a value + chevron opening a nested sheet listing the waiter's restaurants (radio list, current checked); switching clears the card context, keeps Recent **per restaurant**, and cross-fades the `TopBar` name (`crossfade-state`). On S10 "Card from another restaurant" a secondary action "Switch to {restaurant}" may appear **only** if the card's restaurant is in the waiter's list — it opens the same confirmation sheet, never switches silently (a wrong-tenant booking is a real accounting error). The Ready screen gains nothing; the restaurant name in the `TopBar` stays the constant reminder. BalanceCard brand colour already changes per restaurant, which gives a strong visual cue after switching. |
| Backend needs | Token abilities per restaurant (or one token with a restaurant list and an explicit `X-Restaurant-Id`), restaurant list in `/auth/me`, 403 foreign response that says whether the user belongs to the card's restaurant (without leaking other tenants to non-members). |
| Already prepared | `TopBar` restaurant name ([03a §0.2](03a-screens-access-and-scanning.md#02-shared-chrome)); Menu restaurant row ([03a §9](03a-screens-access-and-scanning.md#9-s14--menu-sheet)); S10 foreign-restaurant variant ([03b §5.2](03b-screens-charge-redeem-success-problems.md#52-variants)); brand colour per card ([04 §8.6](04-design-system.md#86-brand-colour-handling-for-the-balancecard)). |
| Classification | v1.x. |

### 3.4 Shared-device / PIN-switch staff mode

| Field | Content |
|---|---|
| Trigger | Restaurants operating one or two "house phones" instead of personal phones (brief §1: v1 assumes a personal or shift-assigned phone); observed in pilots as risk RK-05. |
| Design implications | Proposal: S04 Unlock gains a **staff picker** variant — a grid of `Avatar` initials (56 pt targets, max 12, most recent first) → 4-digit staff PIN on the existing `Keypad` (the only new decision is "who am I", made once per shift or after inactivity). Auto-lock after a configurable inactivity (default 10 min) *and* never during S07–S09. Recent becomes per waiter on the device (already keyed by "this device + signed-in waiter" — brief §1). Biometric unlock is disabled in staff mode (biometrics belong to one person). The PIN keypad reuses S11's field shake and limit nudge rules. No PIN on the redeem itself — that would add a step to the loop (G1). |
| Backend needs | Staff PIN per user (hashed, rate-limited with `ACCOUNT_LOCKED`), a device-level "house device" token that can mint short waiter sessions, audit of which waiter redeemed. |
| Already prepared | S04 layout and states ([03a §4](03a-screens-access-and-scanning.md#4-s04--unlock)); `Avatar` ([05 §5.2](05-component-library.md#52-avatar)); Keypad; Recent keyed per waiter; sign-out clears Recent. |
| Classification | v1.x (needs backend; brief §1 lists it as Future). |

### 3.5 Offline queueing — explicitly rejected

| Field | Content |
|---|---|
| Trigger | None. Requests for it will come ("the terrace Wi-Fi is bad"); the answer is better connectivity, not a queue. |
| Why never | (1) **The balance lives on the server** (brief §0); an offline device does not know the current balance — the same card may be redeemed at the same moment on another phone or at the bar, so any offline acceptance can overdraw. (2) **NTAG 424 DNA SUN signatures are one-time** ([03b §1.2](03b-screens-charge-redeem-success-problems.md#12-sun-signed-cards-never-re-send-a-url)): a queued scan would be replayed later and correctly rejected as `NFC_REPLAY_DETECTED` — after the guest has left. (3) **Blocked, expired, replaced** states cannot be known offline; a blocked (e.g. reported stolen) card would be accepted. (4) The waiter would have to tell the guest "it probably worked" — the exact uncertainty P3 removes. (5) Idempotency protects retries of one attempt; it cannot resolve two offline attempts on different devices. |
| What the design does instead | S05 offline variant V6 with `offline.title` / `offline.body` ("Redeeming needs a connection so nothing is ever booked twice") — the reason is stated, not just the fact ([03a §5.7 V6](03a-screens-access-and-scanning.md#v6--offline)); redeem is blocked before a key is generated ([09 §9.3](09-flutter-handoff.md#93-error-classification) "Not sent"); a connection lost *during* redeem enters the uncertain state with silent same-key retries (R01). |
| Classification | **Never.** |

### 3.6 Apple Tap to Pay and wallet passes

| Field | Content |
|---|---|
| Trigger | Guests asking to keep the gift card in Apple Wallet / Google Wallet; restaurants asking to "accept the rest by card on the same phone". |
| Tap to Pay on iPhone / Android | Tap to Pay accepts **payment cards** through a payment service provider; it is not a way to read gift cards and needs a PSP entitlement and a merchant contract. Taking the remainder of a bill by bank card is cash-register work (brief §1: "cash register integration" out of scope). **Never in the waiter app.** |
| Wallet passes — QR / barcode | A Wallet store-card pass whose barcode encodes the card URL `https://<domain>/c/<UUID>` works **today**: S12 QR scan reads it (`method: qr`), and the guest's own phone never needs to be touched. Design implications: S12 must cope with a bright phone screen as the target (auto-exposure, glare) — add a QR test case "code on a phone screen at 100 % brightness" to QA; the Show-guest mode ([03b §4.8](03b-screens-charge-redeem-success-problems.md#48-show-guest-presentation-mode-of-s09)) is unaffected. Pass issuing is a dashboard/backend feature. **v1.x** (no app change beyond QA). |
| Wallet passes — NFC | NFC-enabled Wallet passes use value-added-service protocols that require Apple's / Google's programme approval, pass certificates and a reader that supports them; whether a third-party phone app may act as that reader on each platform must be verified before any design work. If it becomes possible, the pass read would feed the same lookup as a card tap (a new `method`), with the same `haptic.cardDetected` and no new screen. **v1.x (evaluation only).** |
| Already prepared | S12 QR, universal/App Links for `/c/*` (brief §8.3), `method` field in `POST /scan`, platform-honest principle P7. |

### 3.7 POS integration hand-off

| Field | Content |
|---|---|
| Trigger | A POS/cash-register partner that can hand over the bill amount (brief §1 excludes cash register integration from v1). |
| Design implications | Proposal: the POS opens the app with the amount (and a bill reference) through a universal link; the app lands on **S05 with the amount armed** (a caption "€ 24,90 from register · Table 12" above the Ready title), the waiter taps the card, S07 opens **pre-filled** and the Redeem button already states the amount. The waiter still makes the one decision (tap Redeem / hold ≥ € 100) — the POS never redeems on its own. The amount stays editable; an edited amount shows the caption "changed from € 24,90" so the waiter sees the deviation. After S09, the app returns the transaction id to the POS via its callback URL and auto-returns to the POS instead of S05. Time saved: the ≈ 1.2 s typing step (§6). |
| Backend needs | `reference` on redeem (already in the API body: `reference?`, `note?` — brief §0), partner callback allow-list, signed hand-off links so a malicious link cannot pre-fill amounts. |
| Already prepared | Universal-link entry directly to S07 ([02 §4.3](02-information-architecture-and-journey.md#43-entry-points)); pending-link handling (120 s); idempotency per attempt; POS-style AmountDisplay. |
| Classification | v1.x. |

### 3.8 Languages beyond DE / EN / BHS

| Field | Content |
|---|---|
| Trigger | Restaurants in Italy, Slovenia, Türkiye or Croatia-as-own-locale; staff whose phone language is IT/SL/TR (today they get English — brief §7 fallback). |
| Design implications | **Text expansion** relative to English, measured on this app's vocabulary: DE ≈ +20–35 % (already the design reference), IT ≈ +15–30 %, SL ≈ +10–25 %, TR ≈ +20–35 % with long agglutinated words, HR ≈ same as BHS. All limits in [12 §1.8](12-ui-copy-and-error-messages.md#18-length-limits) are measured on the longest language — adding a language re-runs that check. Hot spots: `charge.redeemFull` with a 5-digit amount on 320 pt, `problem.verify.title`, the overline "GIFT CARD" (IT "CARTA REGALO", SL "DARILNA KARTICA", TR "HEDİYE KARTI" — 11 pt uppercase with +8 % tracking in a fixed-ratio card), S14 row labels ≤ 24. **Turkish casing:** uppercase must be locale-aware (i → İ, ı → I); Geist must cover İ ı ş ğ — verify glyphs before committing. **Croatian:** BHS strings are ijekavian Latin and already read naturally in Croatian; ship a separate `hr` variant only if pilots report friction with specific words. Tone rules per language (no "Sie/du"-equivalents where avoidable; formal imperative where needed) must be written into [12 §1.2](12-ui-copy-and-error-messages.md#12-voice-per-language) first. **Number formatting stays tied to the restaurant locale**, not the app language (brief §7). |
| Already prepared | Key-based master string table with placeholders ([12 §4–5](12-ui-copy-and-error-messages.md#5-master-string-table)); no text in illustrations ([10 §4.2](10-assets-icons-illustrations.md#42-style)); never-truncate rules and wrapping behaviour; pseudo-localisation in the definition of done ([09 §12](09-flutter-handoff.md#12-definition-of-done)); screen-reader language tagging ([07 §9.2](07-accessibility-guidelines.md#92-screen-reader-language-tagging)). |
| Classification | v1.x. |

### 3.9 Large text and Dynamic Type beyond AX3

| Field | Content |
|---|---|
| Trigger | Accessibility audit or a low-vision waiter in a pilot finding the 200 % cap insufficient. |
| Current state | Body, caption and labels scale to **200 %** and then stay fixed; titles to 150 %, amounts to 130 % + shrink-to-fit, keypad digits to 120 % ([04 §3.7](04-design-system.md#37-dynamic-type-and-font-scale)). The 200 % cap is reached around iOS AX2–AX3; AX4–AX5 render at the cap. This meets WCAG 1.4.4 (200 %). |
| Design implications | Lifting the cap on **loop screens** (S05, S07, S09) would push the pinned action region beyond one screen on phones — the one place where scrolling is forbidden. Guidance: (1) allow up to **250 %** on non-loop screens (S02, S10, S13, S14, S15, S17), where content already scrolls and actions are pinned; (2) keep 200 % on S05/S07/S09 and instead offer the OS's own large-content viewer (iOS Large Content Viewer on long-press for keypad keys and TopBar icons); (3) amounts never exceed 130 % — they are already the largest text on screen (64 pt). Never split S07 into two screens to make room (G1). |
| Already prepared | Pinned action region, upper region scrolls ([07 §6.1](07-accessibility-guidelines.md#61-global-rules-brief-5)); `BalanceCard / compact` from 130 % (R11); per-style clamps implemented as a table ([09 §3](09-flutter-handoff.md#3-typography-setup)). |
| Classification | v1.x (after audit). |

### 3.10 Watch / wearable — rejected

| Field | Content |
|---|---|
| Why never | (1) The loop needs a **guest-visible confirmation** (S09: amount 48 pt, remaining balance) — a watch face cannot be shown to the table. (2) Amount entry with gloves on a 40 mm screen violates the 56 pt target rule. (3) Third-party NFC tag reading is not generally available on watches. (4) A second device adds a pairing state to every failure path. Notifications to a watch are also not used — the app sends no notifications (brief §4 S16). |
| Classification | **Never.** |

### 3.11 Reload / sell cards in the app — rejected for the waiter app

| Field | Content |
|---|---|
| Why never here | Reload creates value; a waiter phone that can create value is a fraud target (lost phone, shared phone, shoulder-surfed PIN). The waiter role has `cards.scan` + `cards.redeem` only (brief §0) and the `actions` object from `/scan` is **ignored** for anything but redeem. A reload control next to Redeem would also put two money actions of opposite direction on one screen (P1, G3; brief §6 "no two destructive/primary actions adjacent"). |
| Where it belongs | Dashboard or a separate **manager app** with its own authentication, audit and confirmation patterns (a manager app may reuse this design system: BalanceCard, Keypad, AmountDisplay). |
| Classification | **Never (waiter app).** |

### 3.12 Analytics instrumentation for the < 5 s goal

| Field | Content |
|---|---|
| Trigger | Now: [01 §1.7](01-product-vision-and-principles.md#17-success-metrics) defines M1, M2, M5, M8 as field metrics, but [09 §10.3](09-flutter-handoff.md#103-analytics-and-telemetry--decision) ships v1 **without** telemetry (finding O-02). Decision needed for v1.1. |
| Design implications | Proposal (the 09 §10.3 privacy envelope, unchanged: no card data, no user id, no device id, batched daily, restaurant-level opt-in plus a Menu disclosure row). Events carry only `{event, t_ms (monotonic, relative to loop start), platform, app_version, device_class, method}`: |

| Event | Fired at | Feeds |
|---|---|---|
| `loop.start` | Android: NFC tag in field · iPhone: "Scan card" touch-up · QR: first frame with a code | M1, M2 |
| `scan.read_ok` / `scan.read_failed` | read complete / failed (E11 / E12) | M8 |
| `lookup.response` | `/scan` response received (with outcome class, no code detail) | M1 |
| `charge.interactive` | first S07 frame with balance | M1 |
| `amount.first_key` / `amount.last_key` | typing start / end | typing time (not a system metric) |
| `redeem.start` | tap-up or hold complete | M1 |
| `redeem.result` | S09 first frame, or definitive error, or uncertain | M1, M3 guard |
| `loop.ready_next` | S09 + 0.8 s, or next `loop.start` | M2 |
| `problem.shown` / `problem.resolved` | S10/S15 variant id; next successful redeem within 2 min | M5 |

| Field | Content |
|---|---|
| Derived | Time-to-redeem = `redeem.result − loop.start`; tap loop = `loop.ready_next − loop.start`; system share = total − typing. Report median and p90 per platform and device class. |
| Already prepared | Stable screen IDs and state-machine events usable as event names ([09 §1.2](09-flutter-handoff.md#12-conventions)); timing budgets per step ([09 §10.1](09-flutter-handoff.md#101-budgets)); `X-Request-Id` for server-side timings without client ids. |
| Classification | **v1.1** (product + privacy sign-off; see §11 Q11). |

### 3.13 Platform changes — iOS 26, Android 15 / 16

| Field | Content |
|---|---|
| Trigger | Every OS major release; each beta cycle (June for iOS, spring for Android). |
| iOS 26 "Liquid Glass" materials | System chrome (NFC sheet, permission alerts, keyboard, share sheet, context menus) adopts translucent, refractive materials. The app draws its own UI (Flutter), so **its surfaces do not change automatically**. Guidance: (1) **Do not imitate glass** behind amounts, the balance, keypad digits or any text — every text token must keep ≥ 4.5 : 1 against the *worst-case* backdrop, which a translucent material cannot guarantee in sunlight. (2) Glass-like treatment is acceptable only on non-text chrome where it does not reduce contrast (e.g. a sheet grabber area, the S12 camera overlay controls on a dark scrim), and only when *Reduce Transparency* is off; with it on, solid `color.bg.raised`. (3) Re-verify S05 behind the new system NFC sheet: the top 45 % of S05 stays visible ([03a §6.2](03a-screens-access-and-scanning.md#62-iphone--system-nfc-sheet) "What we don't control") and must still read correctly through a translucent sheet edge. (4) Re-check the icon on the new home-screen modes (tinted/clear) — [10 §2.1](10-assets-icons-illustrations.md#21-ios-app-icon). |
| Android 15 / 16 | Edge-to-edge is enforced for apps targeting API 35: system bars are transparent and insets must be respected — already the rule ([08 §8](08-responsive-behaviour.md#8-safe-areas-notches-dynamic-island-system-bars)). Predictive back animations: S07's close/back must preview returning to S05 and must **not** be available while Submitting / Retrying ([02 §4.2](02-information-architecture-and-journey.md#42-navigation-model) locks). Material 3 "expressive" shapes and motion are **not** adopted — the app's own tokens and press behaviour (R20) stay, per D7 and [04 §1](04-design-system.md#1-identity--how-giftcard-waiter-looks-different-from-a-stock-app). Store policy items (e.g. 16 KB memory page support for new targets) are engineering tasks. |
| Minimum OS | iOS 16 / Android 9 remain for v1.0 (brief §2). Revisit in v1.x: raising to iOS 17 / Android 10 removes fallbacks (e.g. haptic API-level branches in [11 §5.2](11-sound-and-haptics.md#52-android)). |
| Already prepared | Token-driven theming; high-contrast mapping; "no blurred materials" rule under Reduce Transparency ([07 §7](07-accessibility-guidelines.md#7-other-os-settings)); release test matrix with the newest OS ([09 §11.3](09-flutter-handoff.md#113-test-matrix)). |
| Classification | **v1.1** for verification against released OS versions; no redesign. |

### 3.14 Foldables

| Field | Content |
|---|---|
| Trigger | Foldables among pilot devices; Android form-factor quality requirements. |
| Current state (v1 baseline) | Cover screen = phone class, portrait-locked; unfolded = tablet class with two-pane S07 from ≥ 856 pt landscape; content never straddles a hinge; tabletop posture splits S07 at the assist row; state preserved across fold/unfold including the loaded card ([08 §6.1](08-responsive-behaviour.md#61-foldables)). |
| Refinements for v1.x | (1) **Antenna hint per posture** — 08 §6.1 says the Ready hint changes with the fold state, but no strings exist yet (finding O-03). (2) Flip-phone cover screens below 320 × 568 show "Window too small"; a better message is "Open the phone to redeem" (Proposal). (3) Tabletop posture as a **guest-facing mode**: S09 on the upper half facing the guest is a natural fit for Show-guest ([03b §4.8](03b-screens-charge-redeem-success-problems.md#48-show-guest-presentation-mode-of-s09)). |
| Classification | v1 baseline supported · refinements v1.x. |

### 3.15 Configurable hold-to-redeem threshold

| Field | Content |
|---|---|
| Trigger | Restaurants whose typical bill is ≥ € 100 (every redemption would need a hold, adding 0.5 s and training "always hold"). |
| Design implications | The threshold becomes a restaurant setting (range € 50–€ 500, default € 100), delivered with the restaurant settings; the intro copy already uses `{threshold}` ([03a §12](03a-screens-access-and-scanning.md#12-s17--first-run-intro)). No UI in the waiter app to change it. |
| Already prepared | Constant `holdToConfirmThresholdCents` (brief §1, fixed in v1), `{threshold}` placeholder, HoldButton morph rule ([05 §1.5](05-component-library.md#15-holdbutton)). |
| Classification | v1.x. |

---

# Part 2 — Complete Design Review

## 4. Method

| Aspect | How the review was done |
|---|---|
| Scope | Documents 01, 02, 03a, 03b, 04–12 (≈ 129 000 words) against the design brief v1. |
| Reference criteria | (1) Brief §10 **quality bar** — for every screen: purpose, entry/exit, layout, hierarchy, spacing, typography, components, states, animations, micro-interactions, haptics, sound, accessibility, tablet/landscape, Android vs iPhone, time, acceptance criteria. (2) The **UX principles** P1–P10 and design principles D1–D8 of [01](01-product-vision-and-principles.md), using the five review questions of [01 §4](01-product-vision-and-principles.md#4-how-to-use-these-principles-in-review). (3) **WCAG 2.2 AA** as mapped in [07 §2](07-accessibility-guidelines.md#2-wcag-22-aa-mapping). (4) **Apple HIG** (system NFC sheet, Face ID, sheets, Dynamic Type, back-swipe) and **Material 3** conventions (reader mode, BiometricPrompt, predictive back, edge-to-edge, TalkBack). |
| Technique | Heading-level read of all documents, deep reads of the loop (S05–S09), S10, S17, idempotency, haptics/sound, text scaling, accessibility and handoff sections; value-level cross-checks by searching every binding value (durations, amplitudes, colours, slop, caps, timeouts) across all files; timing reconstruction from [02 §5.2–5.3](02-information-architecture-and-journey.md#52-happy-path--android) and [06 §5](06-motion-guidelines.md#5-happy-path-timeline--motion-never-adds-time). |
| Outcome categories | **Resolved conflict** (a decision taken earlier in cross-review, now recorded as binding — §7) · **Finding fixed** (a residual inconsistency found in this review and corrected in its source document — §8) · **Finding open** (needs an owner decision or new translation — §8) · **Risk** (outside the documents' control — §9). |

---

## 5. Scorecard

Rating: ●●●●● excellent · ●●●●○ strong, minor gaps · ●●●○○ adequate, action needed · ●●○○○ weak. "Validated" means only design-validated; field validation comes from the usability test (§12.6) and the pilot.

| # | Criterion | Rating | Evidence | Residual gap |
|---|---|---|---|---|
| 1 | **Zero training < 30 s** | ●●●●○ | S17 intro ≤ 30 s, 3 cards, skippable ([03a §12](03a-screens-access-and-scanning.md#12-s17--first-run-intro)); the Redeem label *is* the confirmation (P1); platform-specific card 1; M4 target ≥ 95 % first-time success ([01 §1.7](01-product-vision-and-principles.md#17-success-metrics)); verb + object labels ([12 §1](12-ui-copy-and-error-messages.md#1-ui-copy-guidelines-17)). | Not yet tested with real waiters; the only non-obvious interaction (hold ≥ € 100) is taught by one intro sentence and the HoldButton's second line. |
| 2 | **< 5 s workflow** | ●●●●○ | Android ≈ 3.54 s, iPhone ≈ 4.44 s from Ready (§6); motion adds 0 ms to the critical path ([06 §5.4](06-motion-guidelines.md#54-hard-rules-acceptance)); request fired on the read frame, lookup overlaps the iOS sheet dismissal ([03a §6.2](03a-screens-access-and-scanning.md#62-iphone--system-nfc-sheet)); skeleton at 150 ms. | iPhone headroom only 0.56 s; ≥ € 100 on iPhone ≈ 5.2 s (O-04); depends on OS sheet latency (RK-02). |
| 3 | **One decision per screen** | ●●●●● | P1; S07 merges card + amount by design (brief §1); no confirmation dialog in the loop; only two dialogs in the app ([05 §4.3](05-component-library.md#43-dialog)); S10 one primary recovery ([05 §4.6](05-component-library.md#46-problemscreen)). | The uncertain-final panel offers two buttons (Try again / Cancel) — a single binary decision, acceptable. |
| 4 | **Premium feel** | ●●●●○ | D7 restraint; one signature sound and one signature motion (M04 breathing, M18 success); Geist with tabular figures; brand-coloured BalanceCard with sheen and continuous corners ([04 §1](04-design-system.md#1-identity--how-giftcard-waiter-looks-different-from-a-stock-app), [04 §8.6](04-design-system.md#86-brand-colour-handling-for-the-balancecard)); custom press states, no ripples. | On the iPhone 15 reference the BalanceCard is 224 × 141 pt (bottom-anchored stack leaves 141 pt — [03b §2.4](03b-screens-charge-redeem-success-problems.md#24-vertical-budget-and-balancecard-sizing)); it reads as a real card but not as a hero. Accepted: the amount is the hero on S07 (D2). |
| 5 | **Glove use** | ●●●●○ | 56 pt minimum targets, 72 pt keys (64 compact), 8 pt gaps, touch slop 12 pt, double-registration guard, no gestures required ([07 §4.1–4.2](07-accessibility-guidelines.md#42-glove-friendly-by-default-no-separate-glove-mode)); hold works with any contact. | Non-capacitive gloves cannot work on any touchscreen (RK-03); glove test not yet run (§12.6). |
| 6 | **Sunlight / dark room** | ●●●●○ | D8; light theme tip in Menu; high-contrast mapping ([04 §10](04-design-system.md#10-high-contrast-mode)); dark theme uses surface steps, no bright flashes ([07 §10.3](07-accessibility-guidelines.md#103-manual-checklist-every-release)); app never changes brightness (brief §9). | Saffron arcs 2.07 : 1 on light canvas accepted as decorative ([07 §3.3 F3](07-accessibility-guidelines.md#33-findings-and-required-fixes-to-be-reflected-in-04--05)); low-end LCD panels in direct sun (RK-11). |
| 7 | **Accessibility** | ●●●●○ | Full WCAG 2.2 AA mapping with test method per SC ([07 §2](07-accessibility-guidelines.md#2-wcag-22-aa-mapping)); three equivalent HoldButton paths ([07 §5.3](07-accessibility-guidelines.md#53-holdbutton-with-assistive-technology-exact-behaviour)); spoken money forms; live regions; Reduce Motion variants for every animation. | 1.3.4 documented exception (R13); the 07 §5.3 strings are not yet in the master table (O-01). |
| 8 | **Platform fidelity** | ●●●●○ | Android continuous reader mode vs iPhone system sheet (P7, [09 §7.1–7.2](09-flutter-handoff.md#71-android-nfc-reader-mode)); Face ID / BiometricPrompt; system back and edge swipe rules ([04 §20.2](04-design-system.md#202-back-gestures-and-buttons)); iOS sheet alert texts; background tag reading via universal links. | Deliberate own typeface and press model instead of SF/Roboto and ripples — correct for the brand, but must be checked against each OS release (§3.13). |
| 9 | **Error recovery** | ●●●●● | Error → surface map ([03b §1.3](03b-screens-charge-redeem-success-problems.md#13-error--surface-map)); idempotency lifecycle with silent same-key retries (R01, R14); every error = what happened + what to do ([12 §2](12-ui-copy-and-error-messages.md#2-error-message-guidelines-18)); support code (R02); card problems keep the balance visible (brief §4 rule). | Depends on server behaviour for concurrent same-key requests (Q5, blocking). |
| 10 | **Implementability** | ●●●●○ | Token JSON structure and naming ([09 §2](09-flutter-handoff.md#2-design-token-delivery)); explicit state machine ([02 §4.5](02-information-architecture-and-journey.md#45-app-state-machine)); redeem state table with invariants ([09 §4.4](09-flutter-handoff.md#44-redeem-transaction-state-table)); performance budgets; per-screen acceptance criteria; build order. | Blocked by backend prerequisites 1–4 (§10) and the iOS 424 DNA spike (Q9). |

**Overall: 42 / 50.** No criterion below "strong"; the gaps are validation (usability test, pilot) and external dependencies, not missing design.

---

## 6. Happy-path walk-through — Android vs iPhone

Scenario: warm app on **S05 Ready, already unlocked** (R12 — opening the app, 0.4 s, and biometric unlock are *not* included), € 100,00 card, amount € 24,90 (4 digits), network typical. Budgets from brief §3 / [02 §5.1](02-information-architecture-and-journey.md#51-timing-budget); timestamps from the journey tables [02 §5.2](02-information-architecture-and-journey.md#52-happy-path--android) and [02 §5.3](02-information-architecture-and-journey.md#53-happy-path--iphone); motion from [06 §5](06-motion-guidelines.md#5-happy-path-timeline--motion-never-adds-time).

| # | Step | Budget Android | t Android (end) | Budget iPhone | t iPhone (end) | What the waiter perceives |
|---|---|---|---|---|---|---|
| 1 | Start scan | 0 (reader mode always listening) | 0.00 | tap "Scan card" 0.4 + sheet 0.3 | 0.70 | Android: nothing to do. iPhone: bottom 64 pt button, Apple sheet with `ios.sheet.alert` |
| 2 | Card read | 0.3 | 0.30 | 0.5 | 1.20 | Android: `haptic.cardDetected` + glass tick at read OK, rings converge (M06). iPhone: Apple ✓ "Karte gefunden" |
| 3 | Lookup (`POST /scan`, fired on the read frame) | ≤ 0.4 | 0.70 | ≤ 0.4 (parallel to sheet dismissal 0.3–0.6) | 1.60 | Skeleton only if > 150 ms (Android shows it at 0.45 s in the typical case) |
| 4 | Transition to Charge (M08, `motion.spring.card`) | 0.24 | 0.94 | 0.24 | 1.84 | BalanceCard legible at +150 ms, keys live from the first frame |
| 5 | Type 4 digits | ~1.2 | 2.14 | ~1.2 | 3.04 | `haptic.key` per digit; button reads "€ 24,90 einlösen" |
| 6 | Tap Redeem (touch-up sends) | 0.1 | 2.24 | 0.1 | 3.14 | Pressed state 90 ms; spinner only after 150 ms |
| 7 | Server → Success | ≤ 0.5 | 2.74 | ≤ 0.5 | 3.64 | `haptic.success` + chime at response; amount readable ≤ 200 ms |
| 8 | Success visible to guest | 0.8 | **3.54** | 0.8 | **4.44** | Android: next card may be tapped any time. iPhone: "Scan next card" in the same position |
| | **Time-to-redeem (M1, excl. step 8)** | | **2.74 s** | | **3.64 s** | Target < 4 s ([01 §1.7](01-product-vision-and-principles.md#17-success-metrics)) ✓ |
| | **Tap-to-ready (M2)** | | **3.54 s** | | **4.44 s** | Target < 5 s ✓ · headroom 1.46 s / 0.56 s |

**Where the 0.9 s platform difference comes from:** the iPhone pays for starting the scan (0.7 s: tap + sheet) and a slower read in the system session (+0.2 s). Everything from S07 onward is identical. The design already recovers what it can: the lookup overlaps the sheet dismissal, and on the next guest "Scan next card" on S09 opens the sheet directly (saves returning to S05).

**Sensitivity (same method, one change at a time):**

| Variation | Android | iPhone | Verdict |
|---|---|---|---|
| Lookup 1.0 s instead of 0.4 s (skeleton path) | 4.14 | 5.04 (lookup no longer fully hidden) | iPhone exceeds on a slow network — acceptable, "Still looking…" only after 3 s |
| Amount ≥ € 100 (5 digits + 600 ms hold instead of 0.1 s tap) | 4.34 | **5.24** | iPhone exceeds the target in the hold case (O-04); the hold is a deliberate safety cost |
| Partial redemption disabled (no typing, "Redeem full balance") | 2.34 | 3.24 | Well inside |
| Next card tapped at 3.6 s (Android) | loop restarts from S09 via M21 | — | Android loops are back-to-back without S05 |
| Reduce Motion on | ± < 50 ms | ± < 50 ms | Required by [06 §5.4](06-motion-guidelines.md#54-hard-rules-acceptance) rule 5 |

---

## 7. Resolved conflicts register

These decisions were taken during cross-document review. They are **BINDING** for design, engineering and QA: where any document still reads differently, this register wins (second only to the brief — [09 §1.3](09-flutter-handoff.md#13-precedence-when-documents-disagree)). IDs R01–R23 are this register's namespace; they are unrelated to the error-catalogue row IDs in [12 §3](12-ui-copy-and-error-messages.md#3-error-catalogue) and the review questions R1–R5 in [01 §4](01-product-vision-and-principles.md#4-how-to-use-these-principles-in-review) — cite them as "13 · R04".

| ID | Topic | Previous conflict | Decision (binding) | Rationale | Documents affected |
|---|---|---|---|---|---|
| **R01** | Uncertain redeem retry | Drafts differed on retry count/length and whether the waiter is asked immediately. | On network loss or 5xx during redeem: **silent automatic retries with the same `Idempotency-Key`** (back-off 1 / 2 / 4 s, 8 s per-attempt timeout) for **up to 20 s after the tap**; then "Try again" (same key) / "Cancel" (key kept pending for this card + amount). | The waiter should not be asked a question the system can answer; the same key makes every retry safe (P3). | 01 P3, 02 §4.5 · §5.7 E08, 03b §3.3–3.5, 06 M17, 09 §4.3–4.4, 11 E44/E48, 12 |
| **R02** | Support code | Format and visibility varied (length, case, full id). | **Last 6 characters of `X-Request-Id`, uppercase** (e.g. `7F3A9C`), as caption; long-press copies the full id. **Not shown** on S10 throttled and S10 network (no request reached the server), offline, card-state banners, inline validation. | Enough for a manager to find the audit entry; not an identifier leak ([12 §2.5](12-ui-copy-and-error-messages.md#25-support-code)). | 03b §5.2 AC-S10-6, 04 §19.3, 05 §4.6, 12 §2.5 |
| **R03** | Verification failed feedback | Visual "calm" vs feedback "alarm". | `NFC_UID_MISMATCH` / `NFC_SIGNATURE_INVALID` / `NFC_REPLAY_DETECTED`: **`haptic.error` + `sound.error`**, but a **calm visual** — warning tone, shield with "i" illustration, no red, no flash; body `getManager`-style instruction; never offers QR/manual as a workaround. | The waiter must notice (money risk), the guest must not feel accused (P5, no blame). | 02 §5.7 E07, 03b §5.2, 04 §19.1, 05 §4.6, 10 §4.4 #3, 11 E25 |
| **R04** | Illustration style / S17 | 03a S17 used 240 pt static renderings of real components on a plate; 10 §4 specified line illustrations. | **10 is authoritative for illustration.** S17 uses `ill_intro_tap` / `ill_intro_amount` / `ill_intro_done` at **160 pt** (120 pt on compact height), monoline 1.75 pt, `color.fg.secondary`, one saffron accent, no plate; layout re-flowed to fit iPhone SE 667 pt. | One illustration language across S10/S13/S15/S17; component renderings looked like real data and drifted with component changes. | 03a §12 (re-flowed in this review), 04 §12, 05 §3.4 · §7, 10 §4 |
| **R05** | Hold ring colour | Saffron ring on the dark-theme primary button = 1.68 : 1. | Ring uses **`color.hold.progress`** (#E8A33D light / #B45309 dark) on `color.hold.track`. | WCAG 1.4.11 ≥ 3 : 1 in both themes and on the pressed fill. | 01 D5, 03b §2.7 · §2.12, 04 §8.4, 05 §1.5 · §3.5, 06 M16, 07 §3.3 F1 |
| **R06** | Input borders | `color.border.strong` as input outline < 3 : 1. | Text inputs use **`color.border.control`** (#8A8A93 / #71717A) at 1 pt; `border.strong` only for non-essential dividers and the focus-ring base. | WCAG 1.4.11 for input boundaries. | 03a §2 · §7, 04 §7 · §8.4, 05 §2.4–2.5, 06 M02, 07 §3.3 F2 |
| **R07** | NFC breathing | Different periods and curves between screen and motion drafts. | **2.4 s period** (1.2 s in, 1.2 s out), sine in-out, group scale 1.00 ↔ 1.04; iPhone idle variant glow-only (12 % ↔ 24 %). Static under Reduce Motion and Low Power. | Calm resting rhythm; low amplitude keeps WCAG 2.2.2 argument valid. | 03a §0.3, 05 §3.4, 06 M04 · §8, 07 SC 2.2.2 |
| **R08** | Read result motion | Ring "shake" on failure vs converge on success; converge at tag discovery vs at read. | Rings **converge into the card only on a successful read** (M06, 240 ms); read start = M05 (scale 1.06, 90 ms); read failure = M05 revert 240 ms decelerate — **no ring shake anywhere**. | A half-read must never look like success; shaking is reserved for input fields. | 03a §6.1 · §6.10, 05 §3.4, 06 M05–M06 · §8 |
| **R09** | Success mark timing | Single draw vs split circle/check; different durations. | Halo spring + **circle draw 0–240 ms**, **check stroke 240–440 ms (200 ms)**; `haptic.success` + `sound.success` at t = 0; amount readable ≤ 200 ms after response. | Feedback at the moment of truth; the check completes the gesture. | 03b §4.4, 05 §3.8, 06 M18 · §8 |
| **R10** | Card arrival spring | Card arrival described with duration/curve pairs in some specs. | The token is **`motion.spring.card`** (response 0.42 s, damping 0.82; settles ≈ 330 ms, legible at 150 ms) for BalanceCard travel and the SuccessMark halo. | One named spring, mapped once in the theme. | 01 D6, 02 §4.5, 03a §0.3 · §6.4, 03b §2.10, 04 §15, 05 §3.1, 06 M08 · M18 |
| **R11** | Compact BalanceCard | Strip height and switch rule differed. | Variant **`BalanceCard / compact`**, **88 pt** (`size.balanceCard.compact`): used when the ID-1 card would be < 136 pt, or at font scale ≥ 130 %. | Keeps the action region fixed on 667 pt phones and at large text. | 03b §2.4, 04 §4.3 · A.4, 05 §3.1, 07 §6.2, 08 §3.2 |
| **R12** | Timing reference point | Totals were read by some as including app open/unlock. | All loop budgets (≈ 3.5 s Android / ≈ 4.5 s iPhone, < 5 s) are **measured from S05 Ready with the app already unlocked**; opening (0.4 s) and unlock are excluded. | Matches service reality (the app stays open during a shift). | 01 §1.7 M2, 02 §5.1, 09 §10.1, this §6 |
| **R13** | Portrait lock | Brief locks phones to portrait; WCAG 1.3.4 requires orientation freedom unless essential. | Phones portrait-locked as a **documented WCAG 1.3.4 "essential" exception** (one-handed NFC hold + vertical Charge stack); tablets and unfolded foldables rotate; revisit in **v1.1** (§3.1). | The exception is honest, narrow and has a revisit date. | 07 SC 1.3.4, 08 §4.1, 09 §7.11, §3.1 here |
| **R14** | 401 during redeem | Whether a session expiry discards the attempt. | A **401 during redeem keeps the attempt and its `Idempotency-Key`**; S15 session sheet re-authenticates; back on S07 with amount and pending attempt intact (K6). | The first request may have booked; a new key could book twice. | 02 §4.5, 03b §1.1 · §1.3, 09 §4.2–4.3 · §9.3 · §11.2, 12 §3.3 |
| **R15** | Uncertain entry feedback | Sound vs silent on entering the uncertain state. | Entering "Connection interrupted": **`haptic.warning` once, no sound**; retries are silent; the final state adds `haptic.warning` again, still no sound. | Sound at the table would alarm the guest; the waiter's hand gets the signal. | 03b §3.4–3.5, 06 M17, 11 E44 · E48 |
| **R16** | S10 haptics | Uniform error feedback across S10 variants. | **`haptic.error` + `sound.error`**: not found, wrong restaurant, verification failed. **`haptic.warning` + `sound.warning`**: scan throttled, network error, server error. | Error = about the card; warning = about the moment (retrying helps). | 04 §19.1, 03b §5.2, 11 E25–E26 |
| **R17** | Focus indicator | Focus drawn in `fg.primary` or saffron in different documents. | Keyboard/switch focus and focused input border use **`color.focus.ring`** (#18181B light / #F0B454 dark), 2 pt (3 pt in high contrast), 2 pt offset. | ≥ 3 : 1 in both themes; saffron alone is < 3 : 1 on light surfaces. | 03a §2 · §7, 04 §8.4 · §13.1, 05 §1.0 · §2.4–2.5, 07 SC 2.4.7 · §3.3 F2 (fixed in this review) |
| **R18** | Field error shake | Amplitude and duration varied. | Field error shake (M02): **240 ms, ±6 pt, 2 cycles**, field container moves as a unit; removed under Reduce Motion. The *limit-reached nudge* (8th amount digit, 17th card digit) is a separate, half-amplitude **±3 pt** variant of the same 240 ms rhythm ([06](06-motion-guidelines.md) M12). | "No" in every culture; the nudge is softer because nothing is wrong. | 03a §0.3 · §2 · §7, 03b §2.9 · §2.11, 05 §2.1, 06 M02 · M12 · M14, 11 E19 · E33 |
| **R19** | NFC read-failure feedback | Every failed read vibrated and beeped in some tables. | Android read failure: **silent for the 1st and 2nd failure**; **`haptic.warning` (no sound) after 3 failures within 5 s**, plus the hold-still hint. "Not a gift card" keeps `haptic.warning` + `sound.warning`. iPhone: the system sheet gives feedback. | Tag loss is normal while positioning; feedback only when the waiter needs to change something. | 03a §5.10 · §6.1 · §6.12–6.13 (fixed in this review), 05 §3.4, 06 M05, 11 E12–E13a |
| **R20** | Press scale | Scales 0.95–0.98 used ad hoc. | **Keys 0.96, buttons 0.98, chips 0.97**, rows and IconButtons no scale; 90 ms in, 160 ms out. | Size-appropriate physicality without ripples (D7). | 03a §0.3, 03b §2.10, 04 §13.1, 05 §1–2, 06 M11 |
| **R21** | Hold slop | 12 pt vs 24 pt. | A hold is cancelled when the finger leaves the button by **more than 12 pt**. | Tolerant of a thumb rolling, strict enough that a slide-off is a deliberate abort (WCAG 2.5.2). | 03b §2.12, 05 §1.5 (fixed in this review), 06 M16, 07 §4.2 |
| **R22** | SuccessMark check colour | White check vs `fg.onAccent`. | Check stroke uses **`color.fg.onSuccess`** (#FFFFFF light / #0A0A0C dark) on the `color.success` circle. | 5.48 : 1 / 10.29 : 1 — readable in both themes. | 03b §4.4, 04 §8.4, 05 §3.8, 06 M18 |
| **R23** | S07 layout ownership | 08 and 03b carried different S07 stacks. | S07 uses the **rows of [03b §2.4](03b-screens-charge-redeem-success-problems.md#24-vertical-budget-and-balancecard-sizing)** (fixed total 618 / 550 pt); 08 only defines the BalanceCard density tiers: **Full (≥ 136 pt, capped at 220)** or **`BalanceCard / compact`** (88 pt). | One owner for the most critical layout. | 03b §2.4, 08 §3.2 |

---

## 8. Review findings

Findings discovered in this review by value-level cross-checks. **Fixed** items were corrected directly in the source document during the review; **open** items need an owner. Severity: **High** = could cause a wrong booking, an inaccessible flow or a build blocker · **Medium** = inconsistent behaviour or missing content that QA would flag · **Low** = documentation or polish.

### 8.1 Fixed in this review

| ID | Where | Finding | Fix applied |
|---|---|---|---|
| F-01 | [03a §12](03a-screens-access-and-scanning.md#12-s17--first-run-intro) | S17 used 240 pt component renderings on a surface plate; 10 §4.4 specifies 160 pt line illustrations; open "Alignment note". | Wireframe re-flowed for a 160 pt artboard (reference) and 120 pt (compact); new iPhone SE wireframe and vertical budget (667 pt with ≥ 159 pt spare flex); card-content table now names `ill_intro_*`; colours, components, motion (static SVGs), a11y (decorative), tablet (160 pt, not scaled) and acceptance criteria updated; alignment note replaced by resolved wording (R04). |
| F-02 | [03a §12](03a-screens-access-and-scanning.md#12-s17--first-run-intro) entry/exit | "Skip → S07 if a card link is pending" contradicted 02 §4.3 and 09 §11.2 (S17 is **deferred** to the next S05 when a link is pending). | Entry table now routes a first sign-in with a pending link straight to S07 and defers S17; Skip → S05 only. |
| F-03 | [07 §8.2](07-accessibility-guidelines.md#82-cognitive-load) | "Intro re-openable from Help" contradicted 03a (shown once per install; Help opens a web page). | Reworded: shown once; the Help page covers the same three steps. |
| F-04 | [01 D7](01-product-vision-and-principles.md#d7--premium-through-restraint) | "Illustrations only in S17 and S16" contradicted 10 §4.1 (S10/S15/S13/S17; S16 uses icons). | Do-row aligned with 10 §4.1. |
| F-05 | [05 §3.4 · §7](05-component-library.md#34-nfcscananimation) | NfcScanAnimation listed as used on S17 (component matrix and "Used in"). | Removed; points to `ill_intro_tap`. |
| F-06 | [03a §5.10, §6.12, §6.13](03a-screens-access-and-scanning.md#612-haptic) · [11 §3.2](11-sound-and-haptics.md#32-scanning-s05-s06-s11-s12-s16) | Every failed read played `haptic.warning` + `sound.warning`, contradicting 03a §6.1, 05 §3.4 and 11 E12–E13 (R19); 11 had no event for "not a gift card". | Tables split into "read failed" (silent ×2, then warning haptic, never sound) and "not a gift card" (warning haptic + sound); 11 gains E13a. |
| F-07 | [03b §2.9](03b-screens-charge-redeem-success-problems.md#29-amount-entry-rules-keypad--amountdisplay) · [03a §7](03a-screens-access-and-scanning.md#7-s11--manual-entry) · [11 E33](11-sound-and-haptics.md#34-charge--redeem-s07-s08) | Limit-reached feedback was ±6 pt in 03a/03b but ±3 pt in 05/06/11. | All aligned to the ±3 pt limit nudge (06 M12); R18 clarified. |
| F-08 | [07 SC 2.4.7, §3.3 F2](07-accessibility-guidelines.md#2-wcag-22-aa-mapping) | Focus ring and focused input border stated as `color.fg.primary` (dark 18 : 1) instead of `color.focus.ring` (R17). | Replaced with `color.focus.ring` and its contrast values. |
| F-09 | [07 §6.1](07-accessibility-guidelines.md#61-global-rules-brief-5) · [03a §7](03a-screens-access-and-scanning.md#7-s11--manual-entry) · [03b §2.6](03b-screens-charge-redeem-success-problems.md#26-typography) | Titles said to scale to 200 % and keypad digits to 130 %; 04 §3.7 and 09 §3 say titles 150 %, `type.key` 120 %. | 07, 03a and 03b aligned to 04. |
| F-10 | [05 §1.5](05-component-library.md#15-holdbutton) | HoldButton cancel slop 24 pt (R21 = 12 pt). | Set to 12 pt with links to 03b/06. |
| F-11 | [05 §1.5](05-component-library.md#15-holdbutton) | HoldButton accessibility block described only a hint and a custom action with the old wording; 07 §5.3 defines three paths. | 05 now defers to 07 §5.3 (label, value, hint, Paths A/B/C). String gap remains → O-01. |
| F-12 | [09 §7.1–7.2](09-flutter-handoff.md#72-ios-nfc-tag-reader-session) | iOS sheet timings contradicted 03a §6.2: multiple tags 1 s (03a 500 ms), "timeout soon" at 20 s (03a 45 s), not-a-card invalidates after 2 s (03a keeps polling), UID debounce 1.5 s (03a 2 s). | 09 aligned to 03a (screen spec owns S06 behaviour). |
| F-13 | [07 SC 1.3.4](07-accessibility-guidelines.md#2-wcag-22-aa-mapping) | "Foldables unlocked" contradicted 08 (cover screen = phone = portrait-locked). | Clarified: unfolded foldables rotate; cover screen follows the phone rule. |
| F-14 | [09 §1.3](09-flutter-handoff.md#13-precedence-when-documents-disagree) | Precedence list ignored documents that declare themselves authoritative (06 motion, 07 a11y, 10 illustration, 11 haptics) and had no place for this register. | Topic owners and the R01–R23 register added to the precedence rule. |
| F-15 | [12 §1.8](12-ui-copy-and-error-messages.md#18-length-limits) | iOS NFC sheet alert limit ≤ 48 characters, but 03a §6.2 allows ≤ 60 and `ios.sheet.timeoutSoon` (DE) has 56. | Limit set to ≤ 60 with reference to 03a. |

### 8.2 Open

| ID | Severity | Where | Finding | Recommended action | Owner |
|---|---|---|---|---|---|
| O-01 | **Medium** | [12 §5.8](12-ui-copy-and-error-messages.md#58-s07-charge--balance-card-keypad-amount) vs [07 §5.3](07-accessibility-guidelines.md#53-holdbutton-with-assistive-technology-exact-behaviour) | The master table still holds the old `a11y.hold.hint` ("Double-tap and hold to redeem"); 07's new hint, the custom action "Confirm redeem {amount}", and the Path B announcements ("Armed…", "Not redeemed…") are missing, and have no BHS. | Add keys `a11y.hold.hint` (updated), `a11y.hold.action`, `a11y.hold.armed`, `a11y.hold.disarmed` with DE/EN from 07 §5.3; proposed BHS: "Dvaput dodirnite i držite ili koristite meni radnji." · "Potvrdite iskorištavanje {amount}" · "Spremno. Dvaput dodirnite ponovo za iskorištavanje {amount}." · "Nije iskorišteno. Iskorištavanje nije potvrđeno." — native review required. | Content + accessibility |
| O-02 | **Medium** | [01 §1.7](01-product-vision-and-principles.md#17-success-metrics) vs [09 §10.3](09-flutter-handoff.md#103-analytics-and-telemetry--decision) | 01 measures M1, M2, M5, M8 with client events and `X-Device-Id` timings; 09 ships v1 with no telemetry and forbids device ids in metrics. v1 cannot report these metrics from the field. | Until the v1.1 decision (§3.12, Q11): measure M1/M2/M4/M8 in moderated pilot sessions and scripted runs; M3/M7 from server data; amend 01 §1.7 "How measured" accordingly when the decision is taken. | Product |
| O-03 | Low | [08 §6.1–6.3](08-responsive-behaviour.md#6-foldables-split-screen-and-multi-window) | Proposal strings not in 12: `window.tooSmall.title/.body`, the multi-window "Tap to activate scanning" state, and the foldable antenna hint per posture. | Either add to 12 with DE/EN/BHS or mark the behaviours as Proposal (not part of v1) and fall back to existing strings (`ready.android.title`). Recommended default: add `window.tooSmall.*` (required for SC 1.4.10), defer the other two. | Content |
| O-04 | Low | [02 §5.1](02-information-architecture-and-journey.md#51-timing-budget) | The < 5 s target is not met on iPhone for ≥ € 100 (≈ 5.24 s, §6) or slow lookups (≈ 5.04 s). | State in 02 §5.1 that the target applies to the typical case (< € 100, 4 digits, lookup ≤ 0.4 s); do not shorten the hold. | Design |
| O-05 | Low | [12 §5.6](12-ui-copy-and-error-messages.md#56-s05-ready-topbar-offline-maintenance) `ready.firstCardTip.android` | "The NFC antenna is usually at the top of the back, near the camera" — the Galaxy A reference device has a centre-back antenna ([09 §11.3](09-flutter-handoff.md#113-test-matrix)). | Reword to "…usually on the back, near the camera or in the middle — try both." (DE/BHS accordingly); see RK-01. | Content |
| O-06 | Low | [03b §3.4](03b-screens-charge-redeem-success-problems.md#34-uncertain--auto-retrying) | Counter "Attempt 2 of 3" implies a fixed count, while the governing limit is 20 s after the tap (R01); with 8 s timeouts the third attempt may start at 19 s and be cut at 20 s. | Keep the counter but make "of 3" conditional, or show "Checking…" only; decide with the copy review. | Design + content |

No High-severity finding remains open.

---

## 9. Risk register

Likelihood (L) and impact (I): H / M / L. IDs RK-nn.

| ID | Risk | L | I | Mitigation (design) | Mitigation (engineering / ops) | Owner |
|---|---|---|---|---|---|---|
| RK-01 | **NFC hardware variance across Android devices** — antenna position (top, centre, near camera), field strength, slow reads of NTAG 424 DNA, vendor quirks in reader mode | H | H | Ready hint and first-card tip ([03a §5.7 V8](03a-screens-access-and-scanning.md#v8--first-card-of-the-shift-hint)); read-failure hint after 3 failures (R19); no penalty for failed reads; S12 QR and S11 manual always one tap away | Device matrix incl. Samsung A-series and Pixel ([09 §11.3](09-flutter-handoff.md#113-test-matrix)); presence-check 250 ms; published "recommended devices" list for restaurants; pilot telemetry of read success (after §3.12) | Engineering + product |
| RK-02 | **iOS system NFC sheet latency and behaviour changes** (sheet rise, dismissal 0.3–0.6 s, iOS 26 visuals) consume most of the iPhone headroom | M | M | Lookup fired on read, overlapped with dismissal; "Scan next card" opens the sheet directly; S05 designed to look right behind any sheet | Measure sheet timings on every iOS beta; budget alarm if tap-to-ready > 4.8 s on the reference iPhone | Engineering |
| RK-03 | **Gloves + capacitive screens** — kitchen nitrile/latex gloves reduce sensitivity; knit gloves without conductive tips do not work at all | M | M | 56 pt targets, 72 pt keys, 8 pt gaps, touch slop 12 pt, no gestures needed; hold works with any contact | Glove test in QA (20 amounts, [07 §10.3](07-accessibility-guidelines.md#103-manual-checklist-every-release)) and usability test (§12.6); onboarding note for managers: touchscreen-capable gloves | QA + product |
| RK-04 | **Restaurant Wi-Fi** — dead zones on terraces, captive portals, overloaded guest networks, Wi-Fi-to-cellular hand-over during redeem | H | M | Offline state with reason; uncertain state with silent same-key retries (R01); no offline booking (§3.5) | Prefer cellular fallback (OS Wi-Fi assist); captive-portal detection treated as offline; warm HTTP/2 connection ([09 §10.2](09-flutter-handoff.md#102-network)); test matrix conditions | Engineering + restaurant |
| RK-05 | **Staff sharing phones** although v1 assumes personal/shift-assigned devices; biometric unlock belongs to the device owner, so a colleague may redeem under another waiter's name | H | M | Recent per device + waiter; sign-out clears token and Recent; restaurant and waiter initials always visible in the `TopBar` | Manager guidance: one account per phone per shift; device list with revoke in the dashboard; v1.x staff PIN mode (§3.4) | Product |
| RK-06 | **Tenant brand colours with poor contrast** (mid greys, mid blues/teals) | M | L | Automatic text colour and **clamp rule**: if neither white nor #0A0A0C reaches 4.5 : 1 against the worst sheen stop, the card falls back to `color.brand.ink`; secondary text and NFC glyph downgrade automatically; desaturated states re-checked ([04 §8.6](04-design-system.md#86-brand-colour-handling-for-the-balancecard)) | Diagnostic `brand_color_contrast_fallback` once per restaurant; dashboard preview/warning when a restaurant picks a colour (dashboard proposal) | Design + backend |
| RK-07 | **Backend prerequisites late** (token login, settings exposure, links, app config) | M | H | App designed so that max single redemption degrades to the server 422 path; maintenance banner falls back to `maintenance.default` | Prerequisites 1–4 tracked as release blockers (§10); mock server for app development | Backend |
| RK-08 | **Concurrent same-key requests** return a 500 instead of the original result (Q5) | M | H | Uncertain state treats 5xx as unconfirmed (safe but longer) | Server serialisation per key (Q5 default); automated test I1–I5 ([09 §12](09-flutter-handoff.md#12-definition-of-done)) | Backend |
| RK-09 | **Clone check gap on the link path** (iPhone background reads and App Links deliver no UID) for NTAG21x cards (Q4) | M | M | S10 verification failed never offers QR/manual as workaround | Recommend NTAG 424 DNA for new card batches; server logs `method`; revisit threshold rule | Product + backend |
| RK-10 | **Battery drain** from reader mode + keep-screen-on over a 6 h shift | M | M | Keep-screen-on only on S05/S07–S10; loops stop when hidden; Low Power variants | Budget ≤ 35 % per 6 h ([09 §10.1](09-flutter-handoff.md#101-budgets)); test shift on the low-end device | Engineering |
| RK-11 | **Sunlight on low-end LCD panels** — contrast collapses above ≈ 30 000 lux | M | M | Light-theme tip in Menu; high-contrast mapping; 64 pt amounts and 48 pt success amount; status never by colour alone | Outdoor QA test ([07 §10.2](07-accessibility-guidelines.md#102-tools)); recommend OLED devices for terraces | QA |
| RK-12 | **One BHS text for Bosnian, Croatian and Serbian speakers** reads as "foreign" to some | M | L | Ijekavian Latin, neutral vocabulary ([12 §1.2](12-ui-copy-and-error-messages.md#12-voice-per-language)) | Native review by one speaker of each standard; separate `hr` only on evidence (§3.8) | Content |
| RK-13 | **App Store / Play review** of a login-only business app with NFC | M | M | QR and manual paths work without NFC; iPad variant has no NFC wording | Demo restaurant, demo account and printed QR test cards in the review notes; NFC usage string ([09 §7.3](09-flutter-handoff.md#73-infoplist-usage-descriptions)) | Product + engineering |
| RK-14 | **iOS reading of NTAG 424 DNA** surfaces differently than expected (Q9) | M | H | — | Wave-1 spike; configure both MIFARE and ISO 7816 AID | Engineering |

---

## 10. Backend prerequisites

From brief §8 and [09 §9.4](09-flutter-handoff.md#94-backend-prerequisites-checklist-for-the-backend-team). **Blocking** = the app cannot ship (or cannot pass QA) without it.

| # | Prerequisite | Blocking? | Why | Fallback if late |
|---|---|---|---|---|
| B1 | `POST /auth/token {email, password, device_id, device_name, platform}` → **device-bound Sanctum token**, abilities `cards.scan` + `cards.redeem` only, **30-day rolling expiry** refreshed on use, revocable via Devices; `POST /auth/logout` | **Blocking** | No native sign-in exists today (cookie SPA login and owner-created tokens only). | None — S02/S04/S15 depend on it. |
| B2 | Expose **`max_single_redemption`** (cents or null), **`brand_color`**, **`locale`** (+ time zone) in the `/scan` response or `/auth/me` | **Blocking** for `brand_color` / `locale`; max single: non-blocking | BalanceCard colour and money formatting need them on first render. | Max single: server 422 path with generic copy ([03b §2.16](03b-screens-charge-redeem-success-problems.md#216-variant--max-single-redemption-exceeded)). |
| B3 | **Universal Links** (`apple-app-site-association`) and **Android App Links** (`assetlinks.json`) for `/c/*` on every card domain; web fallback unchanged | **Blocking** | iPhone background tag reads and system-camera QR scans open the app on S07 only through these. | In-app scanning still works; the background entry point is lost. |
| B4 | **`GET /app/config`** (public): minimum version per platform, maintenance notice (per locale), cacheable 60 s | **Blocking** | Drives S15 "Update required" and the maintenance banner — the only way to stop a broken build in the field. | None acceptable for launch. |
| B5 | Waiter-scoped read of own transactions today | Non-blocking (optional, later) | Would replace the local Recent. | Local Recent (v1 design). |
| B6 | Verify: `method: link` / `qr` with full URL incl. `picc`/`cmac`; `nfc_uid` with colons; `replayed: true` returns the original transaction | **Blocking for QA sign-off** | Correctness of existing endpoints for the native paths. | — |
| B7 | Concurrent same-key requests return the original result or a retryable status, never 500 (Q5) | **Blocking** | Money safety of R01. | — |
| B8 | Dedicated `ACCOUNT_DEACTIVATED` code (Q2) | Non-blocking | Better S15 message. | Generic session-expired path. |
| B9 | `retry_after` / window for `VELOCITY_LIMIT_EXCEEDED` (Q7) | Non-blocking | Copy can name a time. | "später / later" copy. |

---

## 11. Open questions — consolidated, with recommended defaults

All ten questions of [09 §13](09-flutter-handoff.md#13-open-questions) plus those raised by this review. Each has a **recommended default** that engineering may implement now; nobody needs to wait for a product decision unless the "Sign-off" column says so. A default becomes final when its owner signs it off or after 10 working days without objection.

| # | Question | Recommended default | Owner | Owner sign-off needed? |
|---|---|---|---|---|
| Q1 | Token login design: sliding expiry vs access + refresh token; response content; `device_name` source | **One opaque device-bound token with sliding 30-day expiry** extended on each authenticated call; response `{token, expires_at, user {id, name, initials}, restaurant {name, locale, time_zone, currency, brand_color, allow_partial_redemption, max_single_redemption}}`; `device_name` = OS model name sent by the app, renameable **only** in the dashboard. | Backend | No (technical) |
| Q2 | Account deactivated indistinguishable from expired session | Return **401 with `code: ACCOUNT_DEACTIVATED`** on requests and on token login; until available, the app shows the session sheet and then `signIn.error.invalid`. | Backend | No |
| Q3 | Error for exceeding `max_single_redemption` | Reuse **422 `INVALID_AMOUNT`** with `context.max_single_redemption` (cents); the app selects the max-single copy when the context field is present. | Backend | No |
| Q4 | `link` method and clone detection for UID-bound NTAG21x | **Accept for v1**: NTAG 424 DNA remains fully verified (SUN) on every path; NTAG21x via link is unverified but logged with `method: link`; recommend 424 DNA for all new card batches; revisit if any clone is reported. | Product + backend | **Yes — Product** (security posture) |
| Q5 | Concurrent requests with the same key | Server **serialises per key**: a second request waits up to 5 s for the first and returns its result; if still running, **409 `IDEMPOTENCY_IN_PROGRESS`** with `retry_after: 1` — the app treats it as retryable (stays in Retrying, R01). | Backend | No (but **blocking**, B7) |
| Q6 | Reinstall creates a new device id — revoked waiter can sign in as a "new" device | **Accept in v1**; the dashboard device list marks devices first seen < 24 h as "New"; managers revoke as needed; no approval flow. | Product | **Yes — Product** |
| Q7 | `VELOCITY_LIMIT_EXCEEDED` details | Include `retry_after` (s) when the window is known; copy falls back to "später / later". | Backend | No |
| Q8 | Maintenance notice localisation | `/app/config` returns `maintenance.message` as a map `{de, en, bs}`; the app picks the app language, else `maintenance.default`. | Backend | No |
| Q9 | iOS surfacing of NTAG 424 DNA (MIFARE vs ISO 7816) | Configure **both** polling types and the NDEF AID `D2760000850101`; the wave-1 spike confirms and removes the unused one. | Engineering | No |
| Q10 | Bundle identifiers, domains, store names (working name) | Use **neutral bundle identifiers without the product name** (so a rename only changes the display name); display name "GiftCard Waiter" until the platform name decision; universal-link domains = the card domains already printed. | Product | **Yes — Product** (naming) |
| Q11 | Field telemetry for M1/M2/M5/M8 (O-02) | **Ship v1 without telemetry**; measure in moderated pilots; propose the §3.12 event set for v1.1 with restaurant opt-in and a Menu disclosure. | Product | **Yes — Product + privacy** |
| Q12 | Portrait lock after v1.0 (R13, §3.1) | Keep the exception in v1.0; for v1.1 add a Menu switch "Allow landscape" (default off) plus automatic unlock with a hardware keyboard. | Product + accessibility | **Yes — Product** |
| Q13 | Proposal strings in 08 (O-03) | Add `window.tooSmall.title/.body` now (needed for SC 1.4.10); defer the multi-window and foldable-antenna strings to v1.x. | Content | No |
| Q14 | Uncertain counter "Attempt n of 3" (O-06) | Show "Attempt {n}" without "of 3"; the 20 s cap is not communicated as a number. | Design | No |

---

## 12. Implementation-readiness checklist

### 12.1 Design team
- [ ] Figma (or design source) matches the documents after this review: S17 re-flow (F-01), read-failure tables (F-06), limit nudge (F-07), focus ring (F-08).
- [ ] Ten illustrations delivered per [10 §4](10-assets-icons-illustrations.md#4-illustration-style-15) — including the compact 96/120 pt re-draws with 1.75 pt stroke; SVG budget ≤ 80 KB.
- [ ] Icons, app icons (incl. iOS tinted/clear modes), splash, fonts and the four sounds delivered per [10 §6](10-assets-icons-illustrations.md#6-delivery-checklist) and [11 §6](11-sound-and-haptics.md#6-sound-design-brief-for-the-sound-designer).
- [ ] Token JSON exported in the structure of [09 §2.2](09-flutter-handoff.md#22-json-structure-data-format-example), light/dark/high-contrast, including all ➕ tokens of 04.
- [ ] Redlines for S05, S07 (all variants), S09, S10 at P-R, P-C, A-R and tablet landscape.
- [ ] Brand-colour QA palette (the 13 worked examples of [04 §8.6](04-design-system.md#86-brand-colour-handling-for-the-balancecard)) rendered on the BalanceCard in both themes.
- [ ] O-04 and O-06 decided; this register (R01–R23) linked from the design file.

### 12.2 Flutter team
- [ ] Wave-1 spikes done: iOS 424 DNA read (Q9), Android reader mode on the device matrix, native path drawing for SuccessMark ([10 §2.6](10-assets-icons-illustrations.md#26-animation-files--decision)).
- [ ] State machine from [02 §4.5](02-information-architecture-and-journey.md#45-app-state-machine) implemented as one explicit machine; redeem invariants I1–I5 covered by automated tests (timeouts, connection loss after send, 5xx, `replayed: true`, 401 mid-redeem — R14).
- [ ] Per-style text clamps (04 §3.7) implemented as a table; amounts never truncate at 320 pt and 200 %.
- [ ] Haptic/sound mapping per [11 §5](11-sound-and-haptics.md#5-platform-implementation-mapping), including E13a and the silent read-failure rule (R19).
- [ ] Performance budgets of [09 §10.1](09-flutter-handoff.md#101-budgets) measured in release builds on the low-end device.
- [ ] Mock server covering every error code of the brief for UI development before B1–B4 are live.

### 12.3 QA
- [ ] Test matrix of [09 §11.3](09-flutter-handoff.md#113-test-matrix) and conditions (airplane mode at each redeem sub-state, captive portal, 04:00 rollover, 3G throttling).
- [ ] Every acceptance criterion of 03a/03b and [09 §11.2](09-flutter-handoff.md#112-per-screen) as a test case with its screen ID.
- [ ] Double-booking attack tests: rapid double tap, hold + tap, retry after network loss, app kill during Submitting, 401 during redeem → exactly one ledger entry.
- [ ] Real cards: NTAG213/215/216 with UID binding, NTAG 424 DNA (incl. replay), QR-only, a bank card and a transit card (not a gift card), a card on a phone screen (Wallet pass QR, §3.6).
- [ ] Timing runs of §6 (scripted, 10 repetitions per platform), reported as median and p90.

### 12.4 Content and translation
- [ ] O-01: HoldButton accessibility strings added in DE/EN/BHS.
- [ ] O-03 / Q13: `window.tooSmall.*` added; O-05 antenna tip reworded.
- [ ] Native review of all BHS strings by speakers of Bosnian, Croatian and Serbian (RK-12); German review for de-AT and de-CH money formats.
- [ ] Pseudo-localisation (+40 %) run on all screens; no clipping at 320 pt.
- [ ] Length limits of [12 §1.8](12-ui-copy-and-error-messages.md#18-length-limits) re-checked after every string change.

### 12.5 Accessibility audit
- [ ] Independent audit against [07 §2](07-accessibility-guidelines.md#2-wcag-22-aa-mapping) with VoiceOver and TalkBack in DE and EN, Switch Control, Voice Control / Voice Access, Full Keyboard Access.
- [ ] HoldButton Paths A/B/C including Path B disarm after 10 s.
- [ ] Documented exceptions signed: SC 1.3.4 (R13), SC 2.2.2 (breathing indicator).
- [ ] Contrast re-verification of every token pair and the brand-colour palette; high-contrast mapping.
- [ ] 200 % text on every screen of [07 §6.2](07-accessibility-guidelines.md#62-reflow-per-screen-at-200-); S17 on iPhone SE at 150 % and 200 % (illustration size switch of F-01).

### 12.6 Usability test — 5 waiters, gloves and sunlight

A formative test before feature freeze. It does **not** replace the n ≥ 20 per platform measurement of M4 ([01 §1.7](01-product-vision-and-principles.md#17-success-metrics)); it finds the problems that would make M4 fail.

**Participants (5).** Working waiters from pilot restaurants, never used the app: 2 on Android, 2 on iPhone, 1 on the device they use at work; at least 1 left-handed, 1 aged 50+, 1 whose phone language is BHS, 1 who works on a terrace. **Setting:** the restaurant during a quiet hour; a tray with a 1 kg weight in the non-dominant hand; background noise ≈ 70 dB (music). **Material:** test restaurant with brand colour, cards: € 100,00 active, € 32,50 active, blocked, expired, one NTAG 424 DNA card, one QR-only card. **Moderator rules:** no explanation of the app; only the task card is read aloud; think-aloud optional; timing from the first touch.

| # | Task (read to the participant) | Condition | Success criteria | Measures |
|---|---|---|---|---|
| T1 | "This is your new work phone. Sign in with this account and get ready to take gift cards." | Indoor, normal light | Signs in; S17 completed or skipped without help; reaches S05. | Intro time ≤ 30 s; help requests = 0 |
| T2 | "The guest pays € 24,90 with this card." | Indoor | Correct amount redeemed on the first try; no double booking. | Tap-to-ready from S05 ≤ 5 s (Android ≤ 4 s); errors; hesitation > 2 s |
| T3 | "Next guest, € 150,00." | Indoor | Discovers hold-to-redeem without help within 2 attempts; no accidental redemption. | Attempts; time; comment on the ring |
| T4 | "The bill is € 40,00 but the card only has € 32,50 on it. Take what is on the card." | Indoor | Uses "Use balance · € 32,50" or types € 32,50; tells the guest the remainder. | Time; path used |
| T5 | "The guest hands you this card." (blocked) — then (expired) | Indoor | Understands the card cannot be used; tells the guest correctly **without blaming**; knows when to get a manager. | Paraphrase of the message; time to explanation |
| T6 | "Take € 18,40." — moderator switches airplane mode on at touch-up, off after 10 s | Indoor | Waits calmly; does not re-tap or re-scan; confirms exactly one booking afterwards via Recent. | Double-booking attempts = 0; stress rating 1–5 |
| T7 | "Your manager asks how many cards you took today and the total." | Indoor | Opens Recent and reads the summary. | Time ≤ 10 s |
| T8 | "Please put on these gloves and take 10 amounts in a row." (nitrile kitchen gloves, then touchscreen knit gloves) | Indoor | ≤ 1 mis-registered digit in 10 amounts per glove type; hold works. | Mis-keys; time per amount |
| T9 | "On the terrace: the guest pays € 12,00 with this card; read the remaining balance aloud to them." | Outdoor ≥ 30 000 lux, light theme (and once in the theme the participant chose) | Balance and success amount read correctly at arm's length. | Reading errors; theme switch discovered? |
| T10 | "It's evening service; the room is dark." (< 50 lux, dark theme) — repeat T2 | Dark room | No glare complaint; amount read correctly; guest-facing S09 readable. | Comments; errors |

**Pass criteria for the round:** T2 success 5/5 and median tap-to-ready within the platform target; T3 discovered by ≥ 4/5; T6 zero double-booking attempts; T8 within the mis-key limit for touchscreen gloves (nitrile results are reported, not gated); T9 zero reading errors in light theme. Any fail → design change and a second round with 5 new participants.

**After each session:** Single Ease Question per task (1–7); three open questions: "What was unclear?", "When did you not trust the app?", "What would you tell a new colleague about it?".

---

## 13. Sign-off

Sign-off confirms that the role accepts documents 01–13 as the v1.0 specification, including the resolved conflicts register (§7) and the defaults of §11 marked "No". Items marked "Yes" in §11 are signed individually by their owner in the notes column.

| Role | Name | Scope of sign-off | Signature | Date | Notes |
|---|---|---|---|---|---|
| Product | | Scope, §11 Q4 · Q6 · Q10 · Q11 · Q12, release criteria of [01 §1.7](01-product-vision-and-principles.md#17-success-metrics) | | | |
| Design | | 01–13, R01–R23, findings §8 | | | |
| Engineering (Flutter + backend) | | 09 handoff, §10 prerequisites, §11 technical defaults | | | |
| QA | | Test matrix, acceptance criteria, §12.3 | | | |
| Accessibility | | 07, documented exceptions (R13, SC 2.2.2), §12.5 | | | |

---

## 14. Final verdict

GiftCard Waiter's specification is **ready for build, with conditions**. The loop is designed end to end and holds up on every criterion: one decision per screen, a Redeem button that states the amount it books, a money-safety model (one idempotency key per attempt, silent same-key retries, no offline booking) that the waiter never has to think about, and a typical tap-to-ready of ≈ 3.5 s on Android and ≈ 4.4 s on iPhone in which motion adds no time. The review found no High-severity problem; the fifteen inconsistencies it found were corrected in their source documents, and the twenty-three earlier decisions are now binding in one place (§7). What remains is validation and dependencies, not design: backend prerequisites B1–B4 and B7 must be live before release, the iOS NTAG 424 DNA spike (Q9) must pass in wave 1, the HoldButton accessibility strings (O-01) must be translated, and the five-waiter test with gloves and sunlight (§12.6) must pass before feature freeze. The tightest margin is the iPhone budget (0.56 s headroom, exceeded for ≥ € 100); it is a known, accepted cost of Apple's system sheet and of the deliberate hold — and the reason every future feature must pass the admission test of §1 before it touches the loop.

---

Version 1.0 · September 2026 · GiftCard Waiter design specification
