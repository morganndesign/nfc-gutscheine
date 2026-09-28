# NTAG 424 DNA: technical due diligence for GiftCard Pro

**Status:** recommendation before freezing the card architecture.
**Date:** 28 September 2026.
**Related:** `docs/architecture/security-and-issuing-architecture.md`, `docs/NFC.md`, backend `app/Services/Nfc/Ntag424SunVerifier.php`.

**Evidence levels used below:**

| Mark | Meaning |
|---|---|
| **[NXP]** | Stated in an official NXP document (datasheet or application note, §11). |
| **[Apple] / [Google]** | Official platform documentation. |
| **[Community]** | NXP community forum answer by NXP staff, or a reputable open-source project. |
| **[Assessment]** | Our engineering judgement or estimate. Measure these before relying on them. |

Prices are not in this document: NXP does not publish them. Ask two card suppliers for NTAG 424 DNA and DESFire EV3 card quotes at your volumes.

---

## 1. Recommendation

1. **Standardise every *physical* card on NTAG 424 DNA, in AES mode, with Secure Unique NFC (SUN).**
   - Stop issuing NTAG21x cards; keep accepting the ones already in circulation.
   - Keep QR, card number and (later) wallet passes as additional media of the same voucher.
   - "Standardise the entire platform on NTAG 424" is therefore right for the *chip*. It is not right for the *platform*: iPhones, e-mail vouchers and the web keep working through the other media.
2. **Do not run key operations in restaurants.**
   - Cards are **personalised centrally**: keys, SDM configuration and the NDEF template are set before the card reaches the restaurant.
   - The restaurant only **binds** a card to a voucher with one tap. That tap is a SUN read verified by the server, which proves a genuine, correctly personalised, unused card.
   - This is more secure (no keys on restaurant phones) and simpler (no write, verify or lock steps at the table) than today's NTAG21x flow.
3. **Personalisation is server-driven.**
   - In-house, for the pilot and small batches, with an Android station that only **relays APDUs**: the server authenticates to the chip and builds every `ChangeKey`/`ChangeFileSettings` command itself, so keys never exist on the phone.
   - At scale, by a card manufacturer's personalisation service, with keys derived from our master keys and delivered encrypted, per batch.
4. **Keys:**
   - **AN10922 AES-CMAC diversification** per UID, with a **key version per production batch**;
   - master keys in an HSM/KMS, never in `.env`;
   - **no LRP, no Random ID, no SDMReadCtrLimit** (all irreversible or risky, §8).
5. **Not MIFARE DESFire EV3.**
   - Its extra strengths (EAL5+, proximity check against relays, value files, multi-application) mostly help offline, closed-loop payment systems. GiftCard Pro keeps the balance on the server.
   - Its costs are real: full datasheet under NDA, higher complexity, higher card price (supplier quotes).
   - EV3's SUN is "compatible with NTAG DNA" **[NXP]**, so the same backend can accept EV3 later if a customer demands it. The decision is reversible.

**Honest limitation up front (details in §6).** SUN proves that the genuine chip was present when *that* URL was generated. It does not prove that the person presenting it is the card holder:

- someone who reads a card at a few centimetres gets one fresh, valid SUN URL, usable until the owner's next tap;
- NTAG 424 has no relay protection.

Against these we rely on the server-side controls already designed: per-medium method rules, short-lived scan tickets, counters, risk scoring. For restaurant vouchers this is a proportionate level of security.

---

## 2. What NTAG 424 DNA is (verified facts)

| Property | Value | Source |
|---|---|---|
| Standard | NFC Forum **Type 4** Tag (cert. 58562); ISO/IEC 14443-4; ISO/IEC 7816-4 command set | [NXP] datasheet §1–2 |
| Memory | 416 bytes user memory: CC file 32 B, **NDEF file 256 B**, proprietary file 128 B | [NXP] datasheet §8.2.3 |
| Keys | **5 AES-128 application keys** (0–4), each with a 1-byte version; key 0 = AppMasterKey; transport keys = 16 × 00h | [NXP] datasheet §8.2.4 |
| Authentication | `AuthenticateEV2First`/`NonFirst` (AES), or `AuthenticateLRPFirst`/`NonFirst` (LRP) | [NXP] datasheet §9 |
| Secure messaging | Per file: Plain, MAC (CMAC), Full (AES-CBC + CMAC) | [NXP] datasheet §8.2.3.5 |
| SDM / SUN | Mirrors into the NDEF message per read: encrypted PICCData (UID + 24-bit read counter), optional encrypted file data, **SDMMAC** (8-byte truncated CMAC) | [NXP] datasheet §9.3, AN12196 §3 |
| Read counter | 24-bit, reset when SDM is enabled, incremented per read after power-up | [NXP] datasheet §9.3.1 |
| Failed-auth protection | `TotFailCtr` / limit / decrement; authentication delay after repeated failures | [NXP] datasheet §9, AN12196 §6.4 |
| Originality | AES originality keys + **ECC signature** (`Read_Sig`, secp224r1, NXP public key published in AN12196) | [NXP] datasheet §8.7, AN12196 §7.2 |
| Anti-tearing | Writes up to 128 bytes are atomic | [NXP] datasheet §8.6 |
| UID | 7-byte, or optional 4-byte **Random ID** (irreversible) | [NXP] datasheet, AN12196 §6.2 |
| Certification | Common Criteria **EAL4** (HW + SW) | [NXP] datasheet |
| Endurance | 50 years retention, 200 000 write cycles | [NXP] datasheet §5 |
| Range | Up to 10 cm (depends on reader antenna); phones typically 1–4 cm **[Assessment]** | [NXP] datasheet §2 |

---

## 3. The security mechanisms, and how GiftCard Pro should use them

### 3.1 SUN (Secure Dynamic Messaging)

- **What happens:** at every read the chip builds the NDEF URL itself, for example `https://app.giftcardpro.at/c/4?picc=<32 hex>&cmac=<16 hex>`:
  - `picc` = AES-CBC(SDMMetaReadKey, tag ‖ UID ‖ counter ‖ random padding). Random padding makes the ciphertext unlinkable between taps **[NXP]**.
  - `cmac` = truncated CMAC with a session key derived from SDMFileReadKey, UID and counter (SV2 derivation, AN12196 §3.3) **[NXP]**.
- **Verification (server):**
  1. decrypt PICCData;
  2. derive the session MAC key;
  3. compare the MAC;
  4. accept only if `counter > last_counter(UID)`, updated **atomically** (the current code does this with a conditional `UPDATE … WHERE nfc_read_counter < ?`, `CardScanService.php:138`).
- **Replay protection:** a URL can be accepted once, and only if no newer tap has been seen. A copied URL is worthless after the owner's next tap.
- **Works on every NFC phone without an app.** The URL is plain NDEF. iPhones read it in the background and open it (universal link) **[Apple]**. Android reads it in our app or the browser. Web NFC reads it too **[Google]**.

**Decision:**
- *URL format.* Keep the URL generic: the identity comes from the decrypted UID, not from a token in the URL. Cards can then be personalised in bulk before any voucher exists. (This refines the architecture document, §2.2: a 424 medium is identified by `UID + key version`, not by a secret in the URL.)
- *What is mirrored.* Mirror UID + counter encrypted, plus the MAC. Do not use `SDMENCFileData`: no data needs to be hidden on the card.

### 3.2 AES authentication

`AuthenticateEV2First` is a three-pass mutual authentication producing session keys for MAC and encryption **[NXP]**. It is needed **only for personalisation** (changing keys and file settings), never for daily use. Daily use is a passive SUN read with no authentication and no key on the phone.

### 3.3 Key diversification

- **[NXP] AN10922:** derive each card's keys from a master key with **AES-128 CMAC** over `0x01 ‖ UID ‖ application/system identifier ‖ padding`. A broken card key exposes that card only. NXP recommends storing master keys in a **MIFARE SAM AV3**, which also supports NTAG DNA **[NXP]**.
- **Finding in our code.** `Ntag424SunVerifier::fileKeyFor` diversifies with **HMAC-SHA256(master, UID)**, truncated. That is cryptographically sound, but it is **not** the AN10922 scheme. Card manufacturers, SAMs and NXP tools implement AN10922, so they could not produce our keys.
- **Change:** use AN10922 for all new keys, with a key version, and keep the HMAC variant only to verify cards already in circulation.

| Key | Use | Diversified? |
|---|---|---|
| Key 0 AppMasterKey | Personalisation, later maintenance | **Yes** (per UID, AN10922) |
| SDMMetaReadKey | Decrypts PICCData to get the UID | **No, per batch:** the server must decrypt before it knows the UID. It reveals only UID + counter, not MAC keys. |
| SDMFileReadKey | SUN MAC | **Yes** (per UID) |
| Other keys (2–4) | Unused → set to random, diversified values; never left at transport zeros | Yes |

### 3.4 Key provisioning (personalisation)

The personalisation sequence (AN12196 §5) is:

1. select the NDEF application / file;
2. authenticate with key 0 (transport zeros);
3. write the NDEF template (URL with placeholder `picc`/`cmac` fields);
4. `ChangeFileSettings` on the NDEF file: SDM on, UID + counter mirror, `SDMMetaRead` = the meta key, `SDMFileRead` = the MAC key, offsets. It is sent in CommMode.Full;
5. `ChangeKey` for keys 1–4, sent as `(old ⊕ new) ‖ version ‖ CRC32`;
6. `ChangeKey` for key 0 last, with re-authentication;
7. verify: one SUN read checked by the server, plus the ECC originality signature.

**Pitfalls confirmed by NXP support [Community]:**
- A wrong access condition or key order locks you out: error `91AE` means the authentication state does not allow the command.
- NXP says **TagXplorer is no longer supported**; use TapLinx, RFIDDiscover or TagWriter.

Our tooling therefore needs **test vectors from AN12196 as unit tests** and a sacrificial-card test suite before any batch.

### 3.5 Key rotation, stated honestly

- A key on the card can be changed **only while the card is on a reader and after authenticating with key 0** **[NXP]**. There is no remote rotation.
- **Practical rotation = key versions per production batch.** New batches get new master keys; the server keeps old versions to verify existing cards (the version is in our medium record).
- **If a master key is compromised:**
  - the SUN MAC key of every card of that batch is exposed, because diversification protects card-from-card but not against master loss;
  - the only complete remedy is to replace those cards: re-personalise on return, or issue new ones;
  - in the meantime, flag the batch and raise the risk score on its taps.
- This is why master keys belong in an HSM/KMS and batches should stay moderate (e.g. ≤ 10 000 cards per key version) **[Assessment]**.
- *Opportunistic re-keying* (rotating a card when it is tapped at a manager's station) is possible with the relay design (§4), but it adds 1–2 s to that tap. Keep it as an incident-response tool, not a routine.

### 3.6 Card lifecycle

```
Manufactured (transport keys 00…)
  → Personalised (batch, key version; SDM on)          ← central, server-driven
  → In stock (unbound; SUN verifies, no voucher)
  → Bound to a voucher (one tap at sale)               ← restaurant
  → In use (SUN taps; counter increases)
  → Revoked (lost/stolen/replaced; server-side only)
  → [optional] Reset & re-stock (key 0 authentication; returned cards only)
```

- **Replacement** = revoke the medium on the server and bind a new card to the same voucher. No money moves (architecture document §2.1).
- A revoked card keeps producing valid SUN messages, but the server refuses the medium. A thief gains nothing.

### 3.7 Clone resistance

| Attack | NTAG 424 DNA | NTAG21x (today) |
|---|---|---|
| Copy the URL / NDEF content | Useless after the next legitimate tap (counter) | **Works indefinitely** (static URL) |
| Clone the chip, including the UID | Keys cannot be read out (EAL4); a clone cannot compute the MAC | UID can be faked with "magic" tags; content is static |
| Forge a genuine card | Needs the SDMFileRead key | Needs only the URL |
| Relay (attacker phone ↔ victim card in real time) | **Possible** (no proximity check) | Possible |
| Skim one fresh SUN from a card in a pocket (few cm) | **One** valid use, until the owner's next tap | Unlimited use |

---

## 4. Implementation on each platform

### 4.1 Android (native): full capability

- `IsoDep.transceive()` gives raw APDU access to Type 4 tags **[Google]**, so everything is possible from Android: personalisation, authentication, SUN read.
- NXP's own Android apps (TagWriter, TagInfo) and SDK (TapLinx) run on Android.
- **Can Android change keys securely?**
  - *Technically* yes.
  - *Securely* only if the keys are **not present on the phone**. A phone app that holds master or per-card keys exposes them to anyone with a rooted phone or a decompiled APK.
  - **Answer: yes, with the server-driven relay below.** Not with keys inside the app.

**Server-driven relay (recommended personalisation station):**
1. The phone detects the tag, sends the UID to the server and opens a relay session (WebSocket or a sequence of HTTPS calls).
2. The server runs `AuthenticateEV2First` with the diversified key 0 (from the HSM/KMS). The phone forwards opaque APDUs and responses.
3. The server builds the `ChangeFileSettings` and `ChangeKey` commands in secure messaging. The phone sees only ciphertext and MACs.
4. The server verifies by asking the phone for one fresh NDEF read and checking the SUN.

- **Cost:** about 10–14 APDUs, each needing a network round trip. At 50–150 ms per trip that is ≈ 1–2 s per card, and the card must stay on the phone **[Assessment; measure]**.
- ISO 14443-4 keeps the session while the card stays powered, so network latency between commands is acceptable. Set `IsoDep.setTimeout()` generously (≥ 2 s) **[Google]**.
- **Requires:** an attested, owner-approved station device (architecture document §5.1), a platform-admin or manager role, and throttling.

### 4.2 Flutter

- **There is no official NXP Flutter SDK.**
- Community plugins (`nfc_manager`, `flutter_nfc_kit`) expose IsoDep / ISO 7816 transceive.
- GiftCard Waiter already uses **its own platform channels** (`WaiterNfc.kt`, `WaiterNfc.swift`). Extending them with an `apduRelay` method is less risky than adding a plugin.
- All cryptography lives on the server, so the app code stays small (open session, transceive, close).

### 4.3 iOS

| Capability | Status |
|---|---|
| **Reading SUN (daily use)** | ✅ Background tag reading of the URL (iPhone XS and later), or an in-app `NFCNDEFReaderSession` / `NFCTagReaderSession` **[Apple]**. Background reading gives the app the URL, not the UID; that is fine because the UID is inside the encrypted PICCData. Background reading is unavailable while the camera or Wallet is in use, in airplane mode, etc. **[Apple]** |
| **APDUs** (personalisation, authentication) | ✅ possible with `NFCTagReaderSession` + `NFCISO7816Tag.sendCommand` **[Apple]**. The app must list the application identifiers it selects in `com.apple.developer.nfc.readersession.iso7816.select-identifiers`; for NTAG 424 that is the NDEF application `D2760000850101` **[Assessment, per AN12196 command flow]**. |
| Crypto on the device | Not needed with the relay (the server computes). Apple CryptoKit lacks AES-CBC and CMAC; developers use CommonCrypto or third-party libraries **[Community]**. |
| NXP SDK | NXP publishes a *TapLinx iOS SDK* user guide (UG10045). Supported products could not be verified (access restricted). Our relay design does not need it. |
| UX | Every in-app read opens the system sheet: one extra tap per operation. |

**Conclusion:** iPhones can bind cards (one SUN read) and redeem. Personalisation stations should be Android (§4.1) for speed and continuous reader mode.

### 4.4 Web NFC (dashboard)

- Chrome on Android only; NDEF only. **"Low-level I/O operations (e.g. ISO-DEP, NFC-A/B, NFC-F) … are not supported"** **[Google]**.
- The page must be visible, the context secure, and permission granted by a user gesture.
- ✅ The dashboard **can read** SUN URLs (bind a card to a voucher from the web).
- ❌ It **cannot personalise or authenticate** NTAG 424. The current dashboard programming station therefore cannot program 424 cards, and it rightly refuses them today (`TAG_UNSUPPORTED`).
- With central personalisation this does not matter: the web only needs to read.

### 4.5 Readers

| Reader | NTAG 424 |
|---|---|
| NFC phones | Any phone with ISO-DEP (all NFC phones; iPhone 7+ in-app, XS+ background) **[Apple/Google]** |
| PC/SC desktop readers | Any ISO/IEC 14443-4 Type A reader. Validate the chosen model with the full personalisation sequence; some low-cost readers are unreliable for ISO-DEP chaining **[Assessment]**. |
| POS terminals | Only if the terminal exposes NDEF or APDU access to third-party apps; most payment terminals do not **[Assessment]**. Not needed: the waiter phone is the reader. |

---

## 5. SDKs, licensing, NDA

| Item | Finding |
|---|---|
| NTAG 424 DNA datasheet, AN12196 (AES), AN12321 (LRP), AN10922 (diversification) | **Public**, no NDA **[NXP]** |
| MIFARE DESFire EV3 | Public: short datasheet + application notes (e.g. AN12753 quick start). **The full product datasheet is distributed under NDA** (the short datasheet states it is an extract **[NXP]**; NDA requirement documented by the libfreefare project **[Community]**). |
| TapLinx (NXP SDK, Android; iOS guide UG10045) | Free, but needs registration at MIFARE.net, acceptance of a licence agreement, the app's package name registered, and a **licence key** **[Community, NXP staff]**. Not needed for our relay design. |
| NFC TagXplorer (PC) | **No longer supported** by NXP **[Community, NXP staff]** |
| TagInfo / TagWriter (Android apps) | Free NXP apps; useful for inspection and manual tests |
| MIFARE SAM AV3 | Hardware key store supporting NTAG DNA; relevant for a card manufacturer or an on-premise station, optional for us (an HSM/KMS does the same job server-side) **[NXP]** |
| Chip licensing | No per-card licence fee is stated in NXP documentation; the chip price includes use. Use of the trademarks "NTAG", "MIFARE" and "DESFire" in marketing follows NXP's trademark guidelines **[NXP]**. |

---

## 6. Limitations that affect production

1. **SUN ≠ holder authentication.**
   - Skimming at a few cm yields one valid SUN until the owner's next tap. Relay attacks are possible (no proximity check).
   - *Mitigation (designed):*
     - an NFC medium accepts only native NFC reads, never a URL typed or pasted in;
     - a scan ticket valid 60 s is required for redemption;
     - risk scoring flags SUNs that arrive from an unusual device or a long time after the previous tap;
     - guests can freeze their card.
2. **No remote key rotation.** Rotation happens per batch. A master-key compromise means replacing that batch's cards (§3.5).
3. **Irreversible options.** LRP mode and Random ID cannot be switched back **[NXP]**. Our verifier supports AES only.
   - *Decision:* do not enable either.
   - Random ID would improve privacy, but it breaks UID-based diagnostics and tooling. PICCData encryption already hides the UID from third parties.
4. **SDMReadCtrLimit** blocks the card when reached; NXP itself notes the DoS risk **[NXP AN12196 §6.6]**. *Decision:* not set.
5. **Personalisation mistakes brick cards** (`91AE`) **[Community]**.
   - Scripted, tested personalisation only;
   - AN12196 test vectors in CI;
   - a batch starts with 10 sacrificial cards.
6. **The dashboard (Web NFC) cannot personalise.** Personalisation is native Android (relay) or at the manufacturer.
7. **iOS:** reading and binding work; personalisation is possible but slower (system sheet per operation). Keep stations on Android.
8. **Single vendor.** NTAG 424 and SUN are NXP-specific. DESFire EV3 speaks a compatible SUN **[NXP]**, which limits lock-in within NXP; there is no multi-vendor equivalent with the same URL-based SUN **[Assessment]**.
9. **Read time.** A Type 4 NDEF read takes several ISO-DEP APDUs; SUN generation happens at power-up within ISO/IEC 14443 limits **[NXP]**.
   - Expect a slightly longer tap than NTAG21x (tens of ms) **[Assessment]**.
   - Measure it in the hardware test (`docs/NFC-RELEASE-TEST.md`) before the switch.
10. **Existing gaps in our code to close first:**
    - **S8:** chip verification is bypassed with `method: qr/api`;
    - keys are in environment variables;
    - HMAC-based diversification instead of AN10922;
    - the verifier does not check the ECC originality signature (use it at binding time, not per tap).

---

## 7. NTAG 424 DNA vs MIFARE DESFire EV3 (for a restaurant gift-card platform)

| Criterion | NTAG 424 DNA | MIFARE DESFire EV3 |
|---|---|---|
| Crypto | AES-128 (EV2 secure messaging), optional LRP **[NXP]** | AES-128, 3DES; multiple key sets, up to 14 keys per application **[NXP]** |
| SUN / SDM | Yes | Yes, "compatible with NTAG DNA" **[NXP]** |
| Relay protection | No | **Proximity Check** **[NXP]** |
| Offline value / transactions | No value files | **Value, backup and record files; Transaction MAC; anti-tear transactions** **[NXP]** |
| Memory | 416 B | 2–16 kB, many applications **[NXP]** |
| Certification | CC EAL4 | CC **EAL5+** **[NXP]** |
| Documentation | **Fully public** | Full datasheet **under NDA** |
| Implementation complexity | Low–medium: one fixed application, 5 keys, SUN | High: application and file management, key sets, NDA-gated details |
| Phone support | Type 4 NDEF: reads everywhere without an app | Type 4 with NDEF possible, but personalisation is more complex. On iOS, MIFARE DESFire is accessed as a MIFARE tag family in Core NFC **[Assessment]**. |
| Card cost | Low premium over NTAG21x (supplier quote) | Higher (supplier quote) |
| Value for GiftCard Pro | Balance is on the server; the card only needs to **prove it is genuine and fresh**, which is exactly SUN. | Its main advantages (offline value, multi-app, relay protection) solve problems GiftCard Pro does not have. Relay protection matters little when every redemption is online, ticketed and risk-scored. |

**Verdict:** NTAG 424 DNA gives the better balance on every axis we score, as long as the balance stays server-side. Revisit DESFire EV3 only for:

- offline redemption (no connectivity at the till);
- combining the gift card with other applications (staff access, loyalty stamps on the card);
- a customer contract that requires EAL5+ or relay protection.

Because EV3 SUN is compatible, adding it later is a backend configuration change, not a redesign **[Assessment, based on NXP's compatibility statement]**.

| Axis (1 = poor, 5 = best) | NTAG21x (today) | **NTAG 424 DNA** | DESFire EV3 |
|---|---|---|---|
| Security | 1 | **4** | 5 |
| Implementation complexity (5 = simplest) | 5 | **4** | 2 |
| Maintenance | 4 | **4** | 2 |
| UX (tap to read, iPhone background) | 5 | **5** | 4 |
| Long-term scalability | 2 | **4** | 4 |

*[Assessment]*

---

## 8. Production recommendations (the frozen decisions)

1. **Chip:** NTAG 424 DNA, AES mode. No LRP, no Random ID, no SDMReadCtrLimit, no SDMENCFileData.
2. **NDEF template:** `https://app.giftcardpro.at/c/4?picc=<32>&cmac=<16>`.
   - PICCData = UID + counter, encrypted with the meta-read key.
   - The MAC input starts at the MAC offset (no extra mirrored data).
   - The domain is permanent: a domain change would strand every card, so use the platform domain, never a restaurant domain.
3. **Keys:**
   - key 0 and SDMFileRead diversified per UID (AN10922, AES-CMAC);
   - SDMMetaRead per batch;
   - keys 2–4 random and diversified;
   - all with a **key version = batch**;
   - masters in an HSM/KMS;
   - diversification and SUN verification server-side only.
4. **Personalisation:**
   - central, in batches, via the server-driven Android relay (pilot) or the manufacturer (scale);
   - every card verified by SUN read + ECC originality signature before it is stocked;
   - batch records: key version, UIDs, operator, station, results (immutable audit).
5. **Binding at the restaurant:**
   - manager taps a stocked card → server verifies the SUN (genuine + personalised + unbound) → binds it to the voucher;
   - **no writing at the table.** This replaces today's write/read-back/lock flow for physical cards.
6. **Redemption:**
   - the medium accepts only verified SUN reads (native NFC or iPhone link);
   - the counter is strictly increasing, updated atomically;
   - scan ticket → redeem.
7. **Migration:**
   - existing NTAG21x cards keep working;
   - new physical cards are NTAG 424 only;
   - offer exchange of 21x cards for high balances;
   - remove 21x writing from the dashboard and app after the switch-over date.
8. **Before the switch, test on hardware:**
   - AN12196 test vectors in CI;
   - 10 sacrificial cards per batch;
   - read-time measurement on the reference phones;
   - iPhone background read;
   - Web NFC read;
   - replay (same URL twice) and cloned-URL tests;
   - revoked-card test.
9. **Code changes (in order):**
   1. S8 per-medium method rules;
   2. AN10922 diversification + key versions (verifier accepts both schemes);
   3. keys from HSM/KMS;
   4. bind-by-SUN endpoint and app/dashboard flow;
   5. relay endpoint + Android `apduRelay` channel method;
   6. batch/stock management in the platform admin.

   **Estimate:** 12–18 engineer-days, excluding the manufacturer contract **[Assessment]**.

---

## 9. Answers to the specific questions

| Question | Answer |
|---|---|
| Can production provisioning be done entirely from Android? | **Yes, technically.** Android has full ISO-DEP APDU access, and NXP's own tools run on Android. For volume, a manufacturer's personalisation line is faster and keeps keys off phones entirely. |
| Can Android change keys securely? | **Only if the phone never holds the keys:** the server computes the secure-messaging commands and the phone relays APDUs. A phone app that holds keys is not secure against a rooted or decompiled phone. |
| Is server-side provisioning recommended? | **Yes.** It is the design we recommend. It matches NXP's advice to keep master keys in secure storage (a SAM, per AN10922). An HSM/KMS is the server-side equivalent. |
| Is an NDA needed? | Not for NTAG 424 DNA (all documents public). **Yes** for the DESFire EV3 full datasheet. TapLinx needs registration and a licence key, not an NDA **[Community]**. |
| Official SDKs? | TapLinx for Android (and an iOS guide); NFC Reader Library for embedded and PC; TagInfo/TagWriter apps. No Flutter SDK. No server-side SUN library from NXP; AN12196 provides the algorithms and test vectors, and our backend already implements verification. |
| Performance? | SUN read: one normal NDEF read (Type 4). Personalisation via relay: ≈ 1–2 s per card depending on network. Verification on the server: negligible. **[Assessment; measure]** |

---

## 10. Decision needed

- **Adopt NTAG 424 DNA** as the only physical card type, with central personalisation and bind-by-tap at restaurants (§8).
- **Choose the pilot personalisation route:** in-house Android relay (recommended; about 1 week of work), or a manufacturer from day one (supplier contract, minimum quantities).
- **Choose the key store:** managed KMS (e.g. the cloud provider's) vs dedicated HSM, which depends on hosting.

---

## 11. Sources

**NXP (official)**
- [NT4H2421Gx, NTAG 424 DNA data sheet](https://www.nxp.com/docs/en/data-sheet/NT4H2421Gx.pdf)
- [AN12196, NTAG 424 DNA and NTAG 424 DNA TagTamper features and hints (AES)](https://www.nxp.com/docs/en/application-note/AN12196.pdf)
- [AN12321, NTAG 424 DNA features and hints, LRP mode](https://www.nxp.com/docs/en/application-note/AN12321.pdf)
- [AN10922, Symmetric key diversifications](https://www.nxp.com/docs/en/application-note/AN10922.pdf)
- [NTAG 424 DNA product page](https://www.nxp.com/products/rfid-nfc/nfc-hf/ntag-for-tags-and-labels/ntag-424-dna-424-dna-tagtamper-advanced-security-and-privacy-for-trusted-iot-applications:NTAG424DNA)
- [MF3D(H)x3, MIFARE DESFire EV3 short data sheet](https://www.nxp.com/docs/en/data-sheet/MF3D_H_X3_SDS.pdf)
- [MIFARE DESFire EV3 product page](https://www.nxp.com/products/MF3DHx3)
- [AN12753, MIFARE DESFire EV3 quick start guide](https://www.nxp.com/docs/en/application-note/AN12753.pdf)
- [MIFARE SAM AV3](https://www.nxp.com/products/MIFSAMAV3)

**NXP community (answers by NXP staff)**
- [TapLinx SDK licensing](https://community.nxp.com/t5/Other-NXP-Products/TapLinx-SDK-Licensing/m-p/1441828)
- [Issue on NTAG424 DNA after changed app key (91AE; TagXplorer no longer supported)](https://community.nxp.com/t5/TapLinx-SDK-TagWriter-and/Issue-on-NTAG424-DNA-after-changed-App-Key/td-p/2108140)
- [TapLinx support for NTAG 424 DNA](https://community.nxp.com/t5/TapLinx-SDK-TagWriter-and/TapLinx-Support-for-NTAG-424-DNA-for-NDEF-NTAG-Operations/td-p/1759339)
- [AuthenticateEV2First on iOS with Swift](https://community.nxp.com/t5/Secure-Authentication/NFC-NTAG-424-DNA-AuthenticateEV2First-on-iOS-15-with-Swift/m-p/1455808)
- [UG10045, Starting development with TapLinx iOS SDK](https://docs.nxp.com/bundle/UG10045/page/topics/MIFARE_DUOX.html)

**Platforms**
- [Apple: NFCISO7816Tag](https://developer.apple.com/documentation/corenfc/nfciso7816tag)
- [Apple: ISO7816 select identifiers](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.nfc.readersession.iso7816.select-identifiers)
- [Apple: Adding support for background tag reading](https://developer.apple.com/documentation/corenfc/adding-support-for-background-tag-reading)
- [Chrome: Web NFC](https://developer.chrome.com/docs/capabilities/nfc)
- [Android: IsoDep](https://developer.android.com/reference/android/nfc/tech/IsoDep)

**Other**
- [libfreefare issue #116 (DESFire full datasheet under NDA; NTAG 424 public)](https://github.com/nfc-tools/libfreefare/issues/116)
