# NFC — where everything lives

The platform does not read, write or program NFC tags. Physical cards (NTAG 424 DNA with live authentication
through the crypto service and an APDU relay in the waiter app) are designed but not built. This folder is only a
signpost; nothing here is built or run.

| Part | Location |
|---|---|
| What exists today and where the design is | [docs/NFC.md](../docs/NFC.md) |
| SUN verification library (no endpoint uses it) | `backend/app/Services/Nfc/`, tests `backend/tests/Unit/AesCmacTest.php`, `backend/tests/Unit/Ntag424SunVerifierTest.php` |
| Card platform design | [docs/architecture/ntag424-platform-architecture.md](../docs/architecture/ntag424-platform-architecture.md) |
