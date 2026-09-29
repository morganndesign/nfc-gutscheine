# NFC

GiftCard Pro does not read, write or program NFC tags today. Vouchers are digital and are spent by scanning their
printed QR code ([API.md → Presentments](API.md#presentments-vouchersredeem)).

## Physical cards

Physical cards are a future medium for vouchers of kind `card`. They use **NTAG 424 DNA** chips only. A card is
spent only after **live authentication**: the waiter app relays the card's APDUs over NFC between the chip and the
**crypto service**, which holds the card keys in a hardware security module and proves that the genuine chip is
present at that moment. The result is a presentment with method `live_auth` (assurance level A3).

What exists in the code for this today:

| Part | State |
|---|---|
| `VoucherKind::Card` and the spending rule "a card voucher is spent only with `live_auth`" | In place (`backend/app/Enums/VoucherKind.php`) |
| `PresentmentMethod::LiveAuth` | An enum case without a verifier: `POST /presentments` with `method: live_auth` answers `422 PRESENTMENT_METHOD_UNAVAILABLE` |
| SUN message verification (`Ntag424SunVerifier`, `AesCmac`, `SunMessage`) with NXP AN12196 and RFC 4493 test vectors | Library code in `backend/app/Services/Nfc/` with unit tests; no endpoint uses it |
| Crypto service, HSM keys, APDU relay in the app, card personalisation | Not built |

The waiter app has no NFC code and no NFC permission or entitlement. The dashboard never reads cards.

## Design

- [NTAG 424 DNA platform architecture](architecture/ntag424-platform-architecture.md) — keys, live authentication,
  SUN, personalisation, card lifecycle.
- [GiftCard Pro v2 architecture](architecture/giftcard-pro-v2-architecture.md) — §6 spending rules, §10 presentments
  and verification.
- [Implementation plan](implementation/v2-implementation-plan.md) — the phases that build the crypto service,
  the card model, tap verification and live authentication on Android and iPhone.
