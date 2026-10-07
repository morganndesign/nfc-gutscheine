# GiftCard Pro – Android POS module

Reference implementation of the GiftCard Pro POS interface (`/api/partner/v1`) for Android till apps.
Full documentation (German): `docs/partner/KASSEN-SCHNITTSTELLE.md`; OpenAPI: `docs/partner/openapi.yaml`.

## Files to copy into the till app

| File | What it does |
|---|---|
| `src/main/kotlin/at/giftcardpro/pos/GiftCardProClient.kt` | API client: connect, read card, scan QR, redeem (safe retry), outcome, cancel |
| `src/main/kotlin/at/giftcardpro/pos/Ntag424.kt` | The fixed NFC command sequence (5 commands, no keys on the till) |
| `src/main/kotlin/at/giftcardpro/pos/CardChannel.kt` | The card as an interface (testable without a device) |
| `src/main/kotlin/at/giftcardpro/pos/Models.kt` | Voucher, presentment, redemption; `Presentment.payable(bill)` |
| `android/IsoDepCardChannel.kt` | 15-line Android adapter for `android.nfc.tech.IsoDep` |

No dependencies besides Android itself (`HttpURLConnection`, `org.json`). The HTTP layer can be replaced
(`HttpTransport`) with OkHttp or Ktor.

## Build and test (JVM)

```bash
gradle test                       # unit tests: NFC sequence, JSON, retry without double booking
GCP_URL=http://localhost:8000 GCP_KEY=gcpp_… GCP_CODE=ABCD-EFGH GCP_QR=GCPV1.… gradle test   # + live test
```
