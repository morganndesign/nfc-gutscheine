# GiftCard Waiter — Design Specification

GiftCard Waiter is the native Android and iPhone app for restaurant staff. It does one thing: **scan an NFC gift card and redeem its balance.** Nothing else.

This folder is the complete design specification. It is written so that a design team and a Flutter team can build the app **without making product decisions**. It contains no code.

| | |
|---|---|
| Status | Version 1.0 · ready for design production and engineering estimate |
| Platforms | Android 9+ (NFC reader mode), iPhone with iOS 16+ (Core NFC), iPad and tablets without NFC (QR and manual entry only) |
| Languages | German (master), English, Bosnian/Croatian/Serbian |
| Target | New waiter productive in < 30 s; card to "Redeemed" in < 5 s (measured from the Ready screen, app unlocked) |
| Size | 15 documents including the brief, about 145,000 words |

---

## Deliverables → documents

| # | Deliverable | Document | Section |
|---|---|---|---|
| — | Design brief (binding source) | [00 · Design Brief](00-design-brief.md) | all |
| 1 | Product Vision | [01 · Product Vision and Principles](01-product-vision-and-principles.md) | §1 |
| 2 | UX Principles | [01](01-product-vision-and-principles.md) | §2 |
| 3 | Design Principles | [01](01-product-vision-and-principles.md) | §3 |
| 4 | Information Architecture | [02 · Information Architecture and User Journey](02-information-architecture-and-journey.md) | §4 |
| 5 | User Journey | [02](02-information-architecture-and-journey.md) | §5 |
| 6 | Screen Specifications | [03a · Access & Scanning](03a-screens-access-and-scanning.md) (S01–S06, S11, S12, S14–S17) · [03b · Charge, Redeem, Success, Problems](03b-screens-charge-redeem-success-problems.md) (S07–S10, S13) | all |
| 7 | Design System | [04 · Design System](04-design-system.md) | all, token table in Appendix A |
| 8 | Component Library | [05 · Component Library](05-component-library.md) | all |
| 9 | Motion Guidelines | [06 · Motion Guidelines](06-motion-guidelines.md) | M01–M30 |
| 10 | Accessibility Guidelines | [07 · Accessibility Guidelines](07-accessibility-guidelines.md) | all |
| 11 | Responsive Behaviour | [08 · Responsive Behaviour](08-responsive-behaviour.md) | all |
| 12 | Flutter Handoff | [09 · Flutter Handoff](09-flutter-handoff.md) | all |
| 13 | Asset List | [10 · Assets, Icons and Illustrations](10-assets-icons-illustrations.md) | §2 |
| 14 | Icon List | [10](10-assets-icons-illustrations.md) | §3 |
| 15 | Illustration Style | [10](10-assets-icons-illustrations.md) | §4 |
| 16 | Sound & Haptic Guidelines | [11 · Sound & Haptics](11-sound-and-haptics.md) | all |
| 17 | UI Copy Guidelines | [12 · UI Copy and Error Messages](12-ui-copy-and-error-messages.md) | §1, master strings §5 |
| 18 | Error Message Guidelines | [12](12-ui-copy-and-error-messages.md) | §2–§3 |
| 19 | Future Design Considerations | [13 · Future Considerations and Design Review](13-future-and-design-review.md) | Part 1 |
| 20 | Complete Design Review | [13](13-future-and-design-review.md) | Part 2 |

## Screen index

| ID | Screen | Spec |
|---|---|---|
| S01 | Splash | [03a §1](03a-screens-access-and-scanning.md) |
| S02 | Sign in | [03a §2](03a-screens-access-and-scanning.md) |
| S03 | Enable biometrics | [03a §3](03a-screens-access-and-scanning.md) |
| S04 | Unlock | [03a §4](03a-screens-access-and-scanning.md) |
| S05 | Ready (Home) | [03a §5](03a-screens-access-and-scanning.md) |
| S06 | Scanning | [03a §6](03a-screens-access-and-scanning.md) |
| S07 | Charge (card details + amount on one screen) | [03b §2](03b-screens-charge-redeem-success-problems.md) |
| S08 | Redeeming (in-place states of S07) | [03b §3](03b-screens-charge-redeem-success-problems.md) |
| S09 | Success → scan next | [03b §4](03b-screens-charge-redeem-success-problems.md) |
| S10 | Problem screens (not found, blocked, expired, zero balance, wrong restaurant, verification, network, server…) | [03b §5](03b-screens-charge-redeem-success-problems.md) |
| S11 | Manual entry | [03a §7](03a-screens-access-and-scanning.md) |
| S12 | QR scan | [03a §8](03a-screens-access-and-scanning.md) |
| S13 | Recent (sheet) | [03b §6](03b-screens-charge-redeem-success-problems.md) |
| S14 | Menu sheet | [03a §9](03a-screens-access-and-scanning.md) |
| S15 | Session & account states (session expired, revoked, update required, maintenance) | [03a §10](03a-screens-access-and-scanning.md) |
| S16 | Permission states (NFC off, camera denied, biometrics unavailable) | [03a §11](03a-screens-access-and-scanning.md) |
| S17 | First-run intro | [03a §12](03a-screens-access-and-scanning.md) |

## Reading order

| Role | Read first | Then |
|---|---|---|
| Everyone | 01 (15 min) and the 13 verdict (§14) | 02 §5 happy path |
| Product designer | 01 → 02 → 03a/03b → 04 → 05 | 06, 07, 08, 10 |
| Flutter engineer | 09 → 02 (state machine) → 03a/03b | 04 Appendix A, 05, 06, 11 |
| QA | 09 §11–§12 → 13 §12 | acceptance criteria in each screen spec, 07 §10, 11 §10 |
| Content / translation | 12 | 07 §9 |
| Sound designer | 11 §6 | 11 §3 event map |
| Backend | 09 §9 and 13 §10 (prerequisites) | 03b §8 |

## Precedence when documents disagree

1. The **design brief** ([00](00-design-brief.md)), cited everywhere as "brief §n".
2. The **resolved conflicts register** in [13 §7](13-future-and-design-review.md) (R01–R23) is binding. It clarifies the brief and never contradicts it.
3. Then the **topic owner**: tokens → 04, components → 05, motion → 06, accessibility → 07, layout → 08, sound and haptics → 11, copy → 12, illustrations → 10, behaviour per screen → 03a/03b.
4. Anything still unclear is an open question in [13 §11](13-future-and-design-review.md), each with a recommended default. Use the default; do not invent a new behaviour.

## Conventions

- **Units:** pt on iOS and dp on Android, treated as equal. Durations are in ms.
- **Tokens** are written in dot notation (`color.hold.progress`, `motion.spring.card`, `haptic.success`). The token table in [04 Appendix A](04-design-system.md) is the single source of values.
- **Copy** is referenced by key (`charge.redeem`). The DE/EN/BHS text is only in [12 §5](12-ui-copy-and-error-messages.md). German is the master language.
- **Wireframes** are ASCII sketches for structure and measurements only. Visual design comes from the design team, within the tokens.
- **Money:** euro, Austrian format (`€ 24,90`), always in tabular figures.
- **Backend prerequisites** that block the build are listed in [13 §10](13-future-and-design-review.md): token login `POST /auth/token`, the tenant config fields, Universal Links / App Links, and `GET /app/config`.

## Non-negotiables

- Never redeem offline. Never book twice (one idempotency key per redemption attempt).
- One screen, one task, one decision. No confirmation dialogs; hold-to-redeem only for € 100 and more.
- Touch targets ≥ 56 pt, keypad keys ≥ 72 pt, WCAG 2.2 AA in both light and dark themes.
- Feedback confirms and never decorates: every haptic and sound maps to an event in [11 §3](11-sound-and-haptics.md).

---

Version 1.0 · September 2026 · GiftCard Waiter design specification
