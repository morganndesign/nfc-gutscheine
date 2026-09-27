# 11 · Sound & Haptics — GiftCard Waiter

Scope: every non-visual feedback event in the app — haptic and sound tokens, the complete event map, platform implementation mapping (iOS / Android), timing rules, the brief for the sound designer, system-setting behaviour, accessibility and test procedure.
Related: visual counterparts and animation timing in [06](06-motion-guidelines.md) · hearing and motor accessibility in [07](07-accessibility-guidelines.md) · tokens in [04](04-design-system.md) · components in [05](05-component-library.md) · screens in [03a](03a-screens-access-and-scanning.md) / [03b](03b-screens-charge-redeem-success-problems.md) · engineering notes in [09](09-flutter-handoff.md) · Menu toggle labels in [12](12-ui-copy-and-error-messages.md).

---

## 1. Philosophy — feedback confirms, never decorates

1. **Every haptic or sound answers a question the waiter has right now:** "Did it read the card?" "Did the key register?" "Did the money go through?" "Is something wrong?" If no question is being answered, there is no feedback.
2. **Few, distinct signals.** 7 haptic tokens and 4 sound tokens (brief §5). The waiter learns them within a shift; the guest learns `sound.success`.
3. **Sound is for outcomes, haptics for actions.** Keys get haptics, never sound. Sounds are reserved for card detection and outcomes (success, warning, error).
4. **Never alone.** Every sound and haptic accompanies a visible state change (text + icon). The app is fully usable muted and with haptics off.
5. **Quiet by design.** Max ≈ −18 LUFS, ≤ 400 ms. The dining room is a shared space: sounds are audible to the waiter and the guest at the table, not to the next table.
6. **The platform wins.** Silent switch, ringer mode, Do Not Disturb, and OS haptic settings always override app preferences. We never raise volume, never bypass silent mode.
7. **No double feedback.** If the OS already gave feedback (Apple's NFC sheet, biometric prompts), the app stays silent.

---

## 2. Tokens (binding, brief §5)

### 2.1 Haptic tokens

| Token | Meaning | iOS | Android (API 30+) | Android fallback (API 28–29) |
|---|---|---|---|---|
| `haptic.key` | an input registered | `UIImpactFeedbackGenerator` style **light**, intensity 0.5 | `KEYBOARD_TAP` | `KEYBOARD_TAP` (available since API 8) |
| `haptic.select` | a choice/selection changed | `UISelectionFeedbackGenerator` `selectionChanged` | `CLOCK_TICK` | `CLOCK_TICK` (API 21) |
| `haptic.cardDetected` | a card was read | `UIImpactFeedbackGenerator` **medium**, intensity 1.0 | `CONFIRM` | one-shot 20 ms, amplitude 180 |
| `haptic.success` | money moved | `UINotificationFeedbackGenerator` **.success** | `CONFIRM` + waveform [0, 20, 60, 30] ms | waveform [0, 20, 60, 30] ms |
| `haptic.warning` | attention, recoverable | `UINotificationFeedbackGenerator` **.warning** | waveform [0, 30, 80, 30] ms | same |
| `haptic.error` | failed / blocked | `UINotificationFeedbackGenerator` **.error** | `REJECT` | waveform [0, 40, 60, 40, 60, 40] ms |
| `haptic.holdTick` | hold progress 33/66/100 % | `UIImpactFeedbackGenerator` **rigid**, intensities 0.5 / 0.7 / 1.0 | `CLOCK_TICK` ×3 (last one followed by `CONFIRM` — see §5.2) | `CLOCK_TICK` ×3 |

Waveform notation: `[off, on, off, on, …]` in ms, starting with the initial delay (Android `VibrationEffect.createWaveform(timings, amplitudes, repeat = −1)`).

### 2.2 Sound tokens

| Token | Character (brief) | Length | Target loudness (§6.2) |
|---|---|---|---|
| `sound.cardDetected` | single soft glass tick, 1.6 kHz | 60 ms | −22 LUFS-M max |
| `sound.success` | two-note rising chime E6 → B6, gentle decay — the signature | 280 ms | −18 LUFS-M max (loudest) |
| `sound.warning` | single mid tone 660 Hz | 150 ms | −20 LUFS-M max |
| `sound.error` | two low tones 330 Hz, 2 × 90 ms, 60 ms gap | 240 ms | −20 LUFS-M max |

No sound for key presses, button taps, sheets, navigation, sign-in, or unlock.

---

## 3. Event map (complete)

Visual column names the change that the haptic/sound must be synchronised with (§4). "—" = none, deliberately.

### 3.1 Access & session (S01–S04, S15)

| # | Event | Screen | Haptic | Sound | Visual feedback |
|---|---|---|---|---|---|
| E01 | App launch / splash | S01 | — | — | M01 |
| E02 | Sign-in validation or 401 error | S02 | `haptic.error` | — | M02 field shake + error text |
| E03 | Account locked (423) | S02 | `haptic.error` | — | error with retry time |
| E04 | Sign-in success | S02 → S03/S05 | — | — | screen transition |
| E05 | Biometric success | S04 | — (OS gives feedback) | — | M03 |
| E06 | Biometric failure | S04 | — (OS) | — | fallback button fade |
| E07 | Session expired sheet | S15 | `haptic.warning` | — | sheet M24 |
| E08 | Device revoked / restaurant suspended / update required | S15 | `haptic.error` | — | full-screen state |
| E09 | Maintenance banner appears | S05 | — | — | M25/M26 banner |

### 3.2 Scanning (S05, S06, S11, S12, S16)

| # | Event | Screen | Haptic | Sound | Visual feedback |
|---|---|---|---|---|---|
| E10 | Android: tag enters field, read starts | S05/S06 | — | — | M05 reading state |
| E11 | **Android: card read OK** | S05/S06 | `haptic.cardDetected` | `sound.cardDetected` | M06 ring collapse (frame 0) |
| E12 | Android: read failed (tag lost/unreadable), 1st–2nd time | S05 | — | — | M05 revert |
| E13 | Android: read failed 3 × within 5 s | S05 | `haptic.warning` | — | M07 hint (move card / hold still) |
| E13a | Android: tag is not a gift card (`scan.notCard`) | S05 | `haptic.warning` | `sound.warning` | M05 revert + title swap ([03a §6.1](03a-screens-access-and-scanning.md)) |
| E14 | iPhone: tap "Scan card" | S05 | — | — | M11 press; Apple sheet |
| E15 | **iPhone: card read in Apple sheet** | system | — (Apple plays its own) | — (Apple plays its own) | Apple ✓ "Card found" |
| E16 | iPhone: session timeout / cancel | S05 | — | — | M07 hint (brief: silent) |
| E17 | QR decoded | S12 | `haptic.cardDetected` | `sound.cardDetected` | M06 bracket collapse |
| E18 | Manual number complete (16 digits) | S11 | `haptic.select` | — | Continue enables |
| E19 | Manual number invalid (length/checksum) | S11 | `haptic.error` | — | M02 shake |
| E20 | NFC off / unsupported / camera denied shown | S16 | — | — | state screen |

### 3.3 Card result (S07, S10)

| # | Event | Screen | Haptic | Sound | Visual feedback |
|---|---|---|---|---|---|
| E21 | Lookup OK, card active | S07 | — (E11 already confirmed) | — | M08 card rises |
| E22 | Card on S07 with problem status: blocked | S07 | `haptic.error` | `sound.error` | card desaturated + badge + danger `StatusBanner` |
| E23 | Card on S07: expired, inactive, zero balance | S07 | `haptic.warning` | `sound.warning` | badge + warning banner |
| E24 | Card on S07: replaced | S07 | `haptic.warning` | `sound.warning` | badge + banner |
| E25 | S10: not found, wrong restaurant, verification failed | S10 | `haptic.error` | `sound.error` | M22 — verification failed (`NFC_UID_MISMATCH` / `NFC_SIGNATURE_INVALID` / `NFC_REPLAY_DETECTED`): calm, non-alarming visual per [03b §5.2](03b-screens-charge-redeem-success-problems.md) (warning tone, no red, no flash) |
| E26 | S10: scan throttled, network error (lookup), server error | S10 | `haptic.warning` | `sound.warning` | M22 |
| E27 | Throttle countdown reaches 0 | S10 | `haptic.select` | — | M30 button enables |
| E28 | Lookup > 3 s ("Still looking…") | S07 | — | — | text fade-in |

### 3.4 Charge & redeem (S07, S08)

| # | Event | Screen | Haptic | Sound | Visual feedback |
|---|---|---|---|---|---|
| E30 | Digit / "00" key registered (touch-down) | S07, S11 | `haptic.key` | — | M11 + M12 |
| E31 | ⌫ delete | S07, S11 | `haptic.key` | — | M13 |
| E32 | Long-press ⌫ clears | S07, S11 | `haptic.select` | — | M13 clear |
| E33 | 8th digit rejected (max 7) | S07 | `haptic.warning` | — | limit nudge ±3 pt, 2 cycles, 240 ms ([06](06-motion-guidelines.md) M12) |
| E34 | Amount crosses above balance | S07 | `haptic.warning` | — | M14 enter |
| E35 | `QuickAmountChip` tapped | S07 | `haptic.select` | — | amount replaced, M14 exit |
| E36 | Amount crosses ≥ € 100 (Redeem becomes `HoldButton`) | S07 | — | — | label/hint cross-fade |
| E37 | Redeem tap (< € 100) | S07 | — | — | M11, M17 |
| E38 | Hold 33 % / 66 % | S07 | `haptic.holdTick` (0.5 / 0.7) | — | M16 ring |
| E39 | Hold 100 % (committed) | S07 | `haptic.holdTick` (1.0) | — | ring full, M17 |
| E40 | Hold released early | S07 | — | — | ring reverses 160 ms |
| E41 | AT arm (Path B, [07](07-accessibility-guidelines.md) §5.3) | S07 | `haptic.select` | — | armed state |
| E42 | Spinner appears (> 150 ms) | S08 | — | — | M17 |
| E43 | "Connection slow" (> 8 s) | S08 | — | — | info banner |
| E44 | "Redemption uncertain" (network lost / 5xx, silent auto-retrying with the same key for up to 20 s) | S08 | `haptic.warning` (once) | — | uncertain panel replaces the keypad ([03b §3.4](03b-screens-charge-redeem-success-problems.md)) |
| E45 | **Redeem success** (incl. `replayed: true`) | S08 → S09 | `haptic.success` | `sound.success` | M18 — SuccessMark circle starts |
| E46 | Redeem rejected: insufficient balance, invalid amount, max single redemption, card not redeemable, blocked/expired meanwhile | S07 | `haptic.error` | `sound.error` | inline error / banner |
| E47 | Redeem rejected: velocity limit (429) | S07 | `haptic.warning` | `sound.warning` | banner + `getManager` |
| E48 | Redemption still unconfirmed 20 s after the tap (retries exhausted, incl. repeated 5xx) | S08 | `haptic.warning` | — (no second sound) | panel with "Try again" (same key) / "Cancel" ([03b §3.5](03b-screens-charge-redeem-success-problems.md)) |

### 3.5 Success & next card (S09, Android swap)

| # | Event | Screen | Haptic | Sound | Visual feedback |
|---|---|---|---|---|---|
| E50 | Auto-return to Ready | S09 → S05 | — | — | M20 |
| E51 | iPhone "Scan next card" | S09 | — | — | Apple sheet |
| E52 | Android: new card on S09 / on S07 with amount 0 | S09/S07 | `haptic.cardDetected` | `sound.cardDetected` | M21 cross-fade 300 ms |
| E53 | Android: new card on S07 with amount typed | S07 | `haptic.warning` | — | snackbar "Different card detected — Switch?" (or dialog with AT) |
| E54 | "Switch" tapped | S07 | `haptic.select` | — | M21 + amount clears |

### 3.6 Sheets, menu, system

| # | Event | Screen | Haptic | Sound | Visual feedback |
|---|---|---|---|---|---|
| E60 | Sheet open / close / detent snap | S13, S14 | — | — | M24 |
| E61 | Toggle changed (theme, keep screen on) | S14 | `haptic.select` | — | switch state |
| E62 | **Sound toggle turned ON** | S14 | `haptic.select` | `sound.cardDetected` once (preview, only if the system would allow sound) | switch state |
| E63 | **Haptics toggle turned ON** | S14 | `haptic.select` (preview) | — | switch state |
| E64 | Haptics toggle turned OFF | S14 | — | — | switch state |
| E65 | Sign-out confirmed | S14 | — | — | Dialog → S02 |
| E66 | Offline banner appears / disappears | S05/S07/S09 | — | — | M26 |
| E67 | Snackbar (generic info) | any | — | — | M23 |
| E68 | Recent row tapped | S13 | — | — | detail sheet |

**Severity rule behind the map:** `error` = the card or action cannot proceed without a different card, a manager, or a later attempt at the card level (blocked, not found, foreign, verification, rejected redeem). `warning` = recoverable here and now, or temporary (expired/inactive/zero balance are shown so the waiter can inform the guest; throttle, network, uncertain). This aligns haptic/sound severity with the banner colour (`danger` / `warning`). One deliberate exception: **verification failed** uses the error haptic and error sound, but its visual is calm (warning tone, no red, no flash — [03b §5.2](03b-screens-charge-redeem-success-problems.md)), because the guest may be innocent and is watching.

---

## 4. Timing rules

| Rule | Value |
|---|---|
| **T1 — Haptic ↔ visual** | The haptic fires within **10 ms** of the first frame of the visual state change it confirms (same frame at 60–120 Hz). |
| **T2 — Sound ↔ visual** | Sound playback is *started* on the same frame as the visual change; measured acoustic onset ≤ 30 ms after that frame on reference devices (≤ 50 ms tolerated on low-end Android). Visuals are **never delayed** to wait for audio. |
| **T3 — Success** | `sound.success` and `haptic.success` start with the first frame of the `SuccessMark` circle draw (M18 t = 0). The chime's second note (B6, at 90 ms) lands while the circle is ≈ 40 % drawn; its decay overlaps the check stroke (240–440 ms) — sound and mark finish together. |
| **T4 — Card detected** | Android: on the read-complete callback, same frame as M06 starts; the API request is sent on that frame too (feedback never waits for the network). |
| **T5 — Keys** | `haptic.key` on key touch-down, same frame as M11 press. At fast typing (≥ 8 keys/s) haptics may coalesce: never more than one `haptic.key` per 50 ms (the Taptic Engine and many Android LRAs smear faster pulses). |
| **T6 — Minimum spacing** | Two different haptic events < 80 ms apart: the later, higher-severity one wins and the earlier is dropped (e.g. E30 key + E34 over-balance on the same key press → only `haptic.warning`). |
| **T7 — No stacking of sounds** | A new sound stops a playing sound (≤ 5 ms fade-out to avoid a click). Only one sound voice at a time. |
| **T8 — Background** | No haptics or sounds when the app is not foreground (a redeem result arriving in the background plays nothing; the result is shown on return). |

### 4.1 Latency engineering

**iOS**
- Keep one instance of each generator per screen (`impactLight` for keys, `impactMedium` for card detected, `notification` for outcomes, `selection`, `impactRigid` for hold ticks).
- `prepare()` puts the Taptic Engine in a ready state for **a few seconds** only. Call it:
  - on S05 appear and after every read attempt → `impactMedium` (E11 is not used on iPhone NFC, but QR E17 is);
  - on S07 appear, and on **every key touch-down** for the next key (`impactLight`);
  - on Redeem **touch-down** (and at hold start) → `notification` for E45/E46 and `impactRigid` for ticks;
  - on S09 appear → `impactMedium` for E52-equivalent QR re-scan.
- Sounds: play through the **alert channel** (brief §5) using System Sound Services: all four sounds are registered once at app start (one system-sound ID each) and played by ID. This channel uses the **ringer/alert volume**, obeys the silent switch automatically, mixes with other audio and has the lowest start latency on iOS. It requires linear-PCM (or IMA4) CAF files (§6.1). T7 on iOS: a new sound does not cut the previous one (the channel cannot stop a playing sound); sounds are short enough (≤ 280 ms) that overlap is inaudible in practice.

**Android**
- Use view-based `performHapticFeedback` for predefined constants (lowest latency, respects the user's touch-feedback setting automatically).
- For waveforms, one `Vibrator` / `VibratorManager` instance; effects pre-built at screen appear.
- Vibration attributes: usage **touch** (API 33+ `VibrationAttributes.USAGE_TOUCH`) so the system "Touch feedback" intensity applies; on API 28–32 use audio-attributes usage **assistance sonification** and read the system `HAPTIC_FEEDBACK_ENABLED` setting manually.
- Sounds: `SoundPool` with all four sounds loaded at start (max streams 1), attributes usage **notification event** / content type **sonification**; low-latency output where the device supports it. Details in [09](09-flutter-handoff.md).

---

## 5. Platform implementation mapping

### 5.1 iOS

| Token | Generator | Call | prepare() moment | Notes |
|---|---|---|---|---|
| `haptic.key` | Impact **light** | impactOccurred(intensity 0.5) | S07/S11 appear + each key touch-down | intensity param iOS 13+ (min OS 16 ✓) |
| `haptic.select` | Selection | selectionChanged | sheet/menu appear; S07 appear (chip) | |
| `haptic.cardDetected` | Impact **medium** | impactOccurred(intensity 1.0) | S05/S09/S12 appear; after each scan attempt | iPhone NFC: **not played** (Apple sheet feedback, E15) |
| `haptic.success` | Notification | notificationOccurred(.success) | Redeem touch-down / hold start | |
| `haptic.warning` | Notification | notificationOccurred(.warning) | S07 appear, S10 appear | |
| `haptic.error` | Notification | notificationOccurred(.error) | S02 submit touch-down; Redeem touch-down; scan attempt | |
| `haptic.holdTick` | Impact **rigid** | impactOccurred(intensity 0.5 / 0.7 / 1.0) at 200/400/600 ms | hold touch-down | |

iOS devices without a Taptic Engine (none supported on iOS 16) and iPads (no haptic hardware): calls are no-ops; nothing else changes.

### 5.2 Android

| Token | API 30+ | API 28–29 fallback | Waveform (timings ms / amplitudes 0–255) if no amplitude control → on/off only |
|---|---|---|---|
| `haptic.key` | `KEYBOARD_TAP` | `KEYBOARD_TAP` | — |
| `haptic.select` | `CLOCK_TICK` | `CLOCK_TICK` | — |
| `haptic.cardDetected` | `CONFIRM` | one-shot | `createOneShot(20 ms, 180)` |
| `haptic.success` | `CONFIRM`, then waveform | waveform only | timings [0, 20, 60, 30], amplitudes [0, 160, 0, 255] |
| `haptic.warning` | waveform | waveform | timings [0, 30, 80, 30], amplitudes [0, 200, 0, 200] |
| `haptic.error` | `REJECT` | waveform | timings [0, 40, 60, 40, 60, 40], amplitudes [0, 255, 0, 255, 0, 255] |
| `haptic.holdTick` | `CLOCK_TICK` at 33/66 %, `CONFIRM` at 100 % | `CLOCK_TICK` ×3 | — |

Notes:
- `haptic.success` on API 30+: the `CONFIRM` constant fires at t = 0 and the waveform is started **40 ms** later (the "+ 40 ms pattern" of brief §5), giving a confirm-then-double-pulse signature distinct from `haptic.cardDetected`.
- If `hasAmplitudeControl()` is false, amplitudes are ignored (full-strength on/off); patterns remain distinguishable by rhythm.
- Optional enhancement (API 31+, if `areAllPrimitivesSupported`): composition primitives (`CLICK` 0.6 for card detected, `CLICK` 0.5 + `CLICK` 1.0 at 60 ms for success). Must be A/B-checked against the constants; the constants are the baseline.
- OEM variance (Samsung One UI, Xiaomi) is large: patterns are tuned on Pixel (reference LRA) and verified on the device matrix (§9).
- Devices with no vibrator (`hasVibrator()` false): no-op; the Menu "Haptics" toggle is hidden.

---

## 6. Sound design brief (for the sound designer)

### 6.1 Global requirements

| Item | Requirement |
|---|---|
| Family | One coherent family: glass/soft-mallet timbre, warm, no synth "beeps", no voice, no musical logo other than `sound.success`. |
| Master format | **48 kHz, 24-bit, mono WAV**, no dither on masters. |
| Head/tail | Onset within the first **1 ms** of the file (no leading silence — latency). Tail: natural decay to −60 dB, then ≤ 5 ms fade to digital silence. |
| Loudness | Measured as **momentary loudness (LUFS-M, 400 ms window)** because files are shorter than integrated windows: max per token in §2.2; **true peak ≤ −1 dBTP**. Relative ranking must be preserved: success loudest, card detected quietest. |
| Spectrum | Main energy 600 Hz – 4 kHz (phone speakers roll off below ≈ 400 Hz and are harsh above ≈ 6 kHz). Nothing below 200 Hz (inaudible on phone speakers, wastes headroom). Low-pass everything at 10 kHz. |
| Phone speaker check | Each sound must remain recognisable on an iPhone SE speaker and a low-cost Android speaker at 50 % volume, in 70 dB(A) café noise (§8). |
| Delivery — iOS | **16-bit linear-PCM `.caf`, 48 kHz mono** (required by the iOS alert channel, which does not accept AAC; files are < 30 KB each). Additionally deliver **AAC-LC 192 kbps in `.caf`** with encoder priming trimmed (gapless metadata — the ≈ 2112-sample / 44 ms AAC priming must not become leading silence) as a reserve for a media-player fallback. |
| Delivery — Android | **Ogg Vorbis** q6, 48 kHz mono, in `res/raw`; also 16-bit PCM WAV variant for devices where `SoundPool` Ogg decode latency is high. |
| File names | `gcw_card_detected`, `gcw_success`, `gcw_warning`, `gcw_error` — masters `gcw_<name>_48k24_master.wav`; iOS `gcw_<name>.caf`; Android `gcw_<name>.ogg` (lowercase + underscores, valid Android resource names). |
| Versioning | `v1` in the delivery folder name, not in file names (file names are referenced by engineering). |
| Stems | Deliver the layered session (each partial/noise layer as a stem) for later tuning. |

### 6.2 Per-sound specification

#### `sound.cardDetected` — "I've got it"
- **Purpose:** confirms the card was read (Android NFC, QR). Heard dozens of times per hour: must be the least tiring sound in the set.
- **Character:** single soft glass tick — a fingertip flick on a thin wine glass, very dry.
- **Frequencies:** fundamental **1.6 kHz** (sine-like), partial at 4.8 kHz at −18 dB, a 2–3 ms filtered noise transient (band 3–6 kHz) at −24 dB for definition.
- **Envelope (ADSR):** A 1 ms · D 15 ms to −12 dB · S 0 (none) · R 44 ms exponential → total **60 ms**.
- **Loudness:** ≤ −22 LUFS-M; peak ≈ −6 dBFS.
- **Must not:** resemble the iOS/Android system NFC sounds, a keyboard click, or a camera shutter.

#### `sound.success` — the signature
- **Purpose:** money moved. Heard by waiter and guest; it is the brand's audible mark in the restaurant.
- **Character:** two-note **rising** chime, **E6 (1318.5 Hz) → B6 (1975.5 Hz)** — a perfect fifth, bright but warm; soft mallet on a small bell / celesta-glass hybrid. Calm, not triumphant; no reverb tail beyond the file.
- **Structure:** note 1 starts at 0 ms; note 2 starts at **90 ms** (overlapping note 1's release by 20 ms); total length **280 ms**.
- **Timbre:** fundamental; 2nd harmonic at −12 dB; one inharmonic bell partial at 2.76 × fundamental at −24 dB (decays 2× faster than the fundamental); gentle 3–4 kHz presence so it survives restaurant noise.
- **Envelope note 1 (E6):** A 3 ms · D 60 ms to −10 dB · S — · R 50 ms (ends ≈ 110 ms).
- **Envelope note 2 (B6):** A 3 ms · D 80 ms to −8 dB · S — · R 107 ms exponential (ends 280 ms).
- **Level:** note 2 is +1 dB louder than note 1 (the rise should *feel* completed).
- **Loudness:** ≤ −18 LUFS-M (the loudest sound); true peak ≤ −1 dBTP.
- **Sync:** designed so that note 2's attack aligns visually with the `SuccessMark` circle ≈ 40 % drawn (§4 T3).
- **Must not:** sound like a slot machine, cash register, Apple Pay chime, or a messenger notification.

#### `sound.warning` — "look at the screen"
- **Purpose:** recoverable problem (expired/inactive/zero balance, throttle, network, velocity).
- **Character:** single mid tone, neutral, soft attack — a muted marimba bar.
- **Frequencies:** fundamental **660 Hz**; 2nd harmonic 1320 Hz at −8 dB and 3rd 1980 Hz at −16 dB — required because 660 Hz alone sits in the speech band and is masked by conversation; the harmonics keep the perceived pitch at 660 Hz while adding presence.
- **Envelope:** A 5 ms · D 40 ms to −6 dB · S held −6 dB to 100 ms · R 50 ms → **150 ms**.
- **Loudness:** ≤ −20 LUFS-M.
- **Must not:** sound like an error (no falling pitch, no buzz).

#### `sound.error` — "this won't work"
- **Purpose:** blocking problem (blocked card, not found, foreign, verification failed, rejected redeem). Server errors on lookup are temporary and use `sound.warning` (E26).
- **Character:** two identical low tones, soft and firm — not a buzzer, not alarming (the guest hears it too; no blame).
- **Frequencies:** perceived pitch **330 Hz**. Because phone speakers barely reproduce 330 Hz, build it as a **missing-fundamental** tone: 330 Hz at −6 dB + harmonics 660 Hz (0 dB reference), 990 Hz at −4 dB, 1320 Hz at −12 dB. The ear hears 330 Hz even where the speaker cannot play it.
- **Structure:** tone 1 0–90 ms, gap 90–150 ms, tone 2 150–240 ms → total **240 ms**.
- **Envelope (each tone):** A 4 ms · D 30 ms to −4 dB · S −4 dB to 70 ms · R 20 ms.
- **Loudness:** ≤ −20 LUFS-M.
- **Must not:** use dissonance, falling glissando, or noise bursts.

### 6.3 Acceptance of the sound set
- Blind test with 8 restaurant staff: each sound identified correctly (card / success / warning / error) after one demonstration in ≥ 90 % of trials, in café noise.
- Guest test: `sound.success` rated "pleasant/neutral" by ≥ 80 %; `sound.error` rated "not embarrassing" by ≥ 80 %.
- Loudness and true-peak report per file (tool output attached to the delivery).

---

## 7. Respecting system and app settings

### 7.1 Matrix

| Setting | Sounds | Haptics |
|---|---|---|
| App **Sound** OFF (Menu) | none | unaffected |
| App **Haptics** OFF (Menu) | unaffected | none |
| iOS **silent switch / Silent mode** (Action button) | none (the alert channel obeys it automatically) | unaffected (our haptics still play; iOS "System Haptics" setting governs) |
| iOS **Settings → Sounds & Haptics → System Haptics OFF** | — | none (generators become no-ops) |
| iOS **Focus / Do Not Disturb** | play (in-app feedback to a user-initiated action is not a notification) | play |
| iOS volume | follows the **ringer/alert volume** (Settings → Sounds & Haptics); the app never sets volume | — |
| Android **ringer mode Silent** | none | none (Silent = no vibration by user choice) |
| Android **ringer mode Vibrate** | none | play |
| Android **Do Not Disturb** active (interruption filter ≠ all) | none | play (constants) — waveforms only if "Touch feedback" is on |
| Android **Touch feedback OFF** (Settings → Sound & vibration) | — | none (constants auto-suppressed; waveforms suppressed by our check / touch usage) |
| Android **Vibration intensity** (API 33+) | — | honoured via touch usage attributes |
| Android notification volume 0 | effectively none | — |
| Headphones / Bluetooth connected | sounds route to the connected output (the waiter hears them; the guest does not) — accepted; no special handling | unaffected |
| Screen reader running | play; sounds never overlap speech priority (short, ducked by the OS where supported) | play |
| Low Power Mode / Battery Saver | play | play (short events; negligible power) |

**Volume note:** on both platforms sounds follow the phone's **ringer/notification volume**, not the media volume (brief §5: alert channel). The Menu help text states "Uses the ringer volume" (string in [12](12-ui-copy-and-error-messages.md)).

### 7.2 Menu toggles (S14)
- **Sound** — default ON. When the system would mute sound anyway (silent switch, Android silent/vibrate, DND), the toggle stays operable and shows a secondary line: "Phone is on silent" (string in [12](12-ui-copy-and-error-messages.md)).
- **Haptics** — default ON. Hidden on devices without haptic hardware (iPad, Android without vibrator). When the OS has haptics off, secondary line "Vibration is off in phone settings".
- Toggling ON plays a one-time preview (E62, E63).
- Settings are per device (stored locally) and survive sign-out.

---

## 8. Noisy restaurants, quiet rooms, guests

| Situation | Design response |
|---|---|
| Busy restaurant, 70–80 dB(A) | Haptics carry the waiter's feedback (phone in hand). Sounds are tuned (§6) for presence in 1–4 kHz, above most voice energy; success chime E6/B6 cuts through cutlery and conversation. We do **not** auto-raise volume. |
| Quiet fine-dining room | Levels (≤ −18 LUFS-M) are moderate; waiters can turn sound off in Menu with one toggle; haptics remain. |
| Open kitchen / bar | Error and warning sounds are designed to be non-alarming so a colleague does not mistake them for a device alarm. |
| Guest at the table | `sound.success` is the only sound designed *for* the guest; the Success screen is readable at 48 pt. Errors are soft and blameless. |
| Winter gloves | Haptic perception through gloves is reduced: `haptic.success` and `haptic.error` are multi-pulse patterns (distinguishable by rhythm, not strength); sounds and the visual state are primary here. |
| Phone in apron pocket (idle) | Android keeps reader mode only in foreground; no sounds while backgrounded (T8). |

---

## 9. Accessibility (hearing and beyond)

- **Visual equivalents (always):** every sound event in §3 has a simultaneous text + icon state (see the Visual column). No information is conveyed by sound alone — the app is fully operable deaf or muted ([07](07-accessibility-guidelines.md) §8.3).
- **Haptic equivalents:** each sound event also has a haptic (except card-problem-free lookup E21, which the preceding E11 already covers).
- **Deaf-blind / low vision + hearing loss:** haptic rhythms are distinct per severity: `success` = confirm + two pulses, `warning` = two equal pulses, `error` = three strong pulses; VoiceOver/TalkBack braille displays receive the announcements of [07](07-accessibility-guidelines.md) §5.6.
- **Screen readers:** sounds are short and never cover speech for more than 280 ms; the success announcement is posted at M18 t = 0 alongside the chime.
- **Vestibular / sensory sensitivity:** no continuous or repeating sounds or haptics; no loops.
- **Hearing aids (MFi / ASHA):** sounds route with the system audio; mono files avoid channel loss.

---

## 10. Testing checklist

**Mapping & correctness**
- [ ] Every event E01–E68 produces exactly the haptic/sound listed (and nothing where "—").
- [ ] iPhone NFC read (E15): no app haptic or sound — only Apple's.
- [ ] Severity alignment: danger banner ↔ `error`; warning banner ↔ `warning`.

**Timing (high-speed camera 240 fps + contact mic / accelerometer on the device)**
- [ ] Haptic within 10 ms of the visual change (E11, E30, E45) on reference devices.
- [ ] Sound acoustic onset ≤ 30 ms (iPhone 15, Pixel 8), ≤ 50 ms (Android 9 low-end) after the visual change.
- [ ] `sound.success` + `haptic.success` start on the `SuccessMark` first frame.
- [ ] Fast typing (10 keys/s): no haptic backlog after the last key; ≤ 1 `haptic.key` per 50 ms.
- [ ] Key + over-balance on the same press: only `haptic.warning`.

**Settings**
- [ ] App Sound OFF / Haptics OFF each suppress only their channel.
- [ ] iOS silent switch: no sound, haptics present; System Haptics OFF: no haptics.
- [ ] Android Silent: nothing; Vibrate: haptics only; DND: no sound; Touch feedback OFF: no haptics (including waveforms).
- [ ] API 28/29 device: fallback waveforms play; API 30+: `CONFIRM`/`REJECT` used.
- [ ] Device without amplitude control: patterns still distinguishable.
- [ ] Toggle-ON previews play once; iPad shows no Haptics toggle.

**Audio quality**
- [ ] Files match §6.1 (format, onset ≤ 1 ms, loudness and true-peak report).
- [ ] Recognition test in 70 dB(A) café noise on iPhone SE and a low-cost Android speaker.
- [ ] No clicks at start/end; new sound cleanly interrupts a playing one.

**Background & lifecycle**
- [ ] Redeem result while backgrounded: no sound/haptic; result shown on return.
- [ ] Audio from other apps (music at the bar) is mixed, not stopped, by our sounds (iOS alert channel; Android: no audio-focus request for sonification).

---

Version 1.0 · September 2026 · GiftCard Waiter design specification
