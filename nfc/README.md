# NFC — where everything lives

There is **no separate NFC program**. Tags are programmed from the **dashboard** (web app, Chrome on Android),
and read by the **waiter app** and the backend. This folder is only a signpost; nothing here is built or run.

| Part | Location |
|---|---|
| Programming workflow (read → check → detect chip → write → read back → verify → save → lock) | `dashboard/src/lib/nfc-programming.ts`, `dashboard/src/lib/nfc.ts` |
| Programming station page (*Gift cards → Program NFC tags*, `/cards/program`) | `dashboard/src/app/(app)/cards/program/page.tsx` |
| Single-card dialog and UI pieces | `dashboard/src/components/cards/nfc-*.tsx`, `dashboard/src/hooks/use-nfc-programmer.ts` |
| Server rules (check, bind, lock, attempt log, clone detection, NTAG 424 SUN) | `backend/app/Http/Controllers/Api/V1/GiftCard*Controller.php`, `backend/app/Services/GiftCards/`, `backend/app/Services/Nfc/` |
| Reading tags in the native app | `waiter-app/lib/core/platform/channels.dart` + `waiter-app/android/app/src/main/kotlin/eu/tapredeem/waiter/WaiterNfc.kt`, `waiter-app/ios/Runner/WaiterNfc.swift` |
| Tests | `dashboard/src/lib/nfc*.test.ts`, `backend/tests/Feature/NfcProgrammingTest.php`, `backend/tests/Feature/CardScanTest.php`, `e2e/nfc-programming.mjs` |
| Guide (tags, workflow, errors, NTAG 424 DNA) | [docs/NFC.md](../docs/NFC.md) |
| Hardware release test (real tags, real phones) | [docs/NFC-RELEASE-TEST.md](../docs/NFC-RELEASE-TEST.md) |

How to start and test NFC programming: [RUNNING_THE_PROJECT.md → NFC programming](../RUNNING_THE_PROJECT.md#6-nfc-programming).
