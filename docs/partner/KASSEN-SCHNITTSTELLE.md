# GiftCard Pro – Kassen-Schnittstelle (POS-API)

**Version 1.0 · Oktober 2026** · für Kassenanbieter, die Gutscheine und Geschenkkarten von GiftCard Pro direkt in
ihrer Kassen-App einlösen.

---

## 1. Überblick

GiftCard Pro ist ein Gutscheinsystem für Restaurants: gedruckte Gutscheine mit QR-Code und **fälschungssichere
NFC-Geschenkkarten** (NTAG 424 DNA). Guthaben liegen ausschließlich auf dem GiftCard-Pro-Server; auf Karte und
QR-Code steht kein Betrag.

Mit dieser Schnittstelle löst Ihre Kassen-App Gutscheine **ohne App-Wechsel** ein:

1. Die Kellnerin tippt in Ihrer Kasse auf **„Gutschein / Geschenkkarte"**.
2. Der Gast hält seine Karte an das Android-Gerät (oder die Kasse scannt den QR-Code des gedruckten Gutscheins).
3. Ihre App zeigt sofort das **Guthaben** – z. B. „€ 50,00 verfügbar".
4. Der Gast bestätigt, wie viel er verwenden möchte – vorgeschlagen wird `min(Guthaben, Rechnung)`.
5. GiftCard Pro bucht den Betrag ab, Ihre Kasse zieht ihn von der Rechnung ab; den Rest zahlt der Gast wie gewohnt.

```
Kassen-App            NFC-Karte                 GiftCard Pro
    │── Karte lesen (5 Befehle) ─▶│                      │
    │◀─ URL, UID, Challenge ──────│                      │
    │── POST /cards/authentications ──────────────────▶  │ prüft SUN, UID
    │◀─ Befehl für die Karte ─────────────────────────── │
    │── Befehl weiterreichen ────▶│                      │
    │◀─ Antwort der Karte ────────│                      │
    │── POST /cards/authentications/{id} ─────────────▶  │ prüft Karte (AES)
    │◀─ Guthaben, presentment_id (60 s gültig) ───────── │
    │── POST /redemptions (Betrag, Bon-Nr.) ──────────▶  │ bucht ab
    │◀─ neues Guthaben ───────────────────────────────── │
```

Die Kasse leitet beim Kartenlesen **nur Bytes weiter**. Sie besitzt keinen Schlüssel und entscheidet nie selbst, ob
eine Karte echt ist. Eine kopierte oder nachgebaute Karte scheitert am Server.

## 2. Einrichtung

### 2.1 Partner-Schlüssel (einmal pro Kassenanbieter)

GiftCard Pro stellt Ihnen einen **Partner-Schlüssel** aus (`gcpp_…`, 45 Zeichen). Er identifiziert Ihr
Kassensystem bei allen Restaurants.

- Speichern Sie ihn wie ein Passwort: im Backend Ihres Kassensystems oder verschlüsselt auf dem Gerät, **nie** im
  Quellcode oder in Logs.
- Bei Verdacht auf Missbrauch stellen wir sofort einen neuen aus; der alte gilt dann nicht mehr.

### 2.2 Verbindung pro Restaurant (Verbindungscode)

Jedes Restaurant entscheidet selbst, ob Ihr Kassensystem seine Gutscheine einlösen darf:

1. Der Inhaber öffnet im GiftCard-Pro-Dashboard **Einstellungen › Kassensysteme** und klickt
   **„Verbindungscode erstellen"**. Er erhält einen Code wie `K7QF-M2XP` (24 Stunden gültig, einmal verwendbar).
2. Er gibt den Code Ihnen oder trägt ihn selbst in Ihrer Kassen-Einrichtung ein.
3. Ihre App ruft `POST /connections` mit dem Code auf und erhält eine **Verbindungs-ID** (UUID).
4. Speichern Sie die Verbindungs-ID beim Restaurant in Ihrem System. Sie gilt, bis der Inhaber die Verbindung
   trennt.

### 2.3 Kassen-ID (jedes Gerät)

Jedes Kassengerät sendet eine eigene, gleichbleibende **Kassen-ID** (`X-Terminal-Id`, 4–64 Zeichen
`A–Z a–z 0–9 . _ -`), z. B. Ihre Geräte-Seriennummer, und optional einen Namen (`X-Terminal-Name`, z. B. „Theke").

- Jede Kasse erscheint beim Restaurant unter **Geräte** als „Ihr Kassensystem · Theke". Eine verlorene oder
  gestohlene Kasse sperrt der Inhaber dort sofort, ohne die anderen Kassen zu stören.
- Höchstens 50 Kassen pro Restaurant und Kassensystem.

## 3. Grundlagen

| Thema | Wert |
|---|---|
| **Basis-URL** | `https://app.giftcardpro.at/api/partner/v1` |
| **Format** | JSON (UTF-8), `Content-Type: application/json`, `Accept: application/json` |
| **Beträge** | immer in **Cent** als Ganzzahl: `1250` = € 12,50 |
| **Zeit** | ISO 8601 mit Zeitzone, z. B. `2026-10-07T12:00:30+02:00` |
| **Sprache** | `Accept-Language: de` (oder `en`, `bs`) – Fehlermeldungen in dieser Sprache |
| **Verschlüsselung** | nur HTTPS (TLS 1.2+) |

### 3.1 Header

| Header | Wann | Inhalt |
|---|---|---|
| `Authorization` | immer | `Bearer gcpp_…` (Partner-Schlüssel) |
| `X-Connection-Id` | alle Restaurant-Aufrufe | Verbindungs-ID aus `POST /connections` |
| `X-Terminal-Id` | Karten, QR, Einlösungen | gleichbleibende Kassen-ID |
| `X-Terminal-Name` | optional | Anzeigename der Kasse (max. 60 Zeichen) |
| `Idempotency-Key` | `POST /redemptions` | eine neue UUID pro Einlösung (siehe §6) |

### 3.2 Antworten

Erfolg: `{"data": { … }}`. Fehler:

```json
{
  "message": "Das Guthaben reicht nicht aus.",
  "code": "INSUFFICIENT_BALANCE",
  "context": { "balance": 500, "requested": 4500 }
}
```

Werten Sie immer **`code`** aus (stabil); `message` ist ein Satz für Menschen und kann sich ändern.

## 4. Endpunkte

### 4.1 `GET /me` – Schlüssel prüfen

Nur `Authorization`.

```json
{ "data": { "partner": { "id": "0199…", "name": "Kassa Wien GmbH" }, "connections": 12 } }
```

### 4.2 `POST /connections` – Restaurant verbinden

Nur `Authorization`. Body: `{"code": "K7QF-M2XP"}` (Groß-/Kleinschreibung, Leerzeichen und Bindestrich egal).

`201`:

```json
{
  "data": {
    "id": "0199a1b2-7c3d-7000-8000-4e5f6a7b8c9d",
    "status": "active",
    "connected_at": "2026-10-07T11:58:02+02:00",
    "restaurant": { "name": "Trattoria Bella Vista", "currency": "EUR", "locale": "de-AT", "timezone": "Europe/Vienna" },
    "rules": { "allow_partial_redemption": true, "max_debit_per_transaction": 50000 }
  }
}
```

Fehler: `422 LINK_CODE_INVALID` (unbekannt, schon verwendet oder älter als 24 Stunden). Ein Restaurant, das schon
verbunden war, wird mit einem neuen Code wieder verbunden (gleiche ID).

### 4.3 `GET /connections` – alle verbundenen Restaurants

Nur `Authorization`. `data` ist eine Liste wie in 4.2 (nur aktive Verbindungen).

### 4.4 `GET /connection` – ein Restaurant und seine Regeln

`Authorization` + `X-Connection-Id`. Antwort wie 4.2. Gut als Prüfung beim Start der Kasse.

| Regel | Bedeutung |
|---|---|
| `allow_partial_redemption` | `false`: ein Gutschein wird nur **ganz** eingelöst (Betrag = Guthaben) |
| `max_debit_per_transaction` | Höchstbetrag pro Einlösung in Cent (`null` = keiner) |

### 4.5 `POST /cards/authentications` – Geschenkkarte, Schritt 1

`Authorization` + `X-Connection-Id` + `X-Terminal-Id`. Body (Werte aus dem Kartenlesen, §5):

```json
{
  "tap_url": "https://t.giftcardpro.at/ks-2026-01?e=9F3A…&m=4B1C…",
  "rf_uid": "04A39493CC8680",
  "challenge": "8E1D4C7A0B9F2E63D5A1C4F7E9B20356"
}
```

`200`:

```json
{ "data": { "authentication": "01JA7Q3M9W2K8V5T0R6Y4N1B3C", "command": "90AF000020…00", "expires_in": 30 } }
```

Senden Sie `command` (Hex) **unverändert** an die Karte und deren Antwort in Schritt 2 – innerhalb von 30 Sekunden.

### 4.6 `POST /cards/authentications/{authentication}` – Schritt 2

Body: `{"response": "<Antwort der Karte als Hex, normal 68 Zeichen inkl. 9100>"}` – auch eine Ablehnung der Karte unverändert senden. `201` – die **Vorlage** (Presentment):

```json
{
  "data": {
    "presentment_id": "0199a1b2-8d4e-7000-9000-5f6a7b8c9d0e",
    "expires_at": "2026-10-07T12:01:00+02:00",
    "method": "card",
    "voucher": {
      "id": "0199a0f1-…",
      "number": "2351 5576 9132 5161",
      "status": "active",
      "balance": 5000,
      "currency": "EUR",
      "expires_at": null,
      "redeemable": true
    },
    "card": { "number": "B-2026-0001-0042" },
    "rules": { "allow_partial_redemption": true, "max_debit_per_transaction": 50000 }
  }
}
```

- `redeemable: false` → Gutschein gesperrt, abgelaufen oder leer: zeigen Sie `status` an, bieten Sie nichts an.
- Die Vorlage gilt **60 Sekunden** und für **eine** Einlösung **an dieser Kasse**.

### 4.7 `POST /vouchers/scan` – gedruckter Gutschein (QR-Code)

Body: `{"code": "GCPV1.gdRf85597UUS3oen74yGTUZ1I_6zulhCW5gVjPJoniA"}` (der Text im QR-Code). `201` wie 4.6 mit
`"method": "qr"` und `"card": null`.

QR-Gutscheine beginnen immer mit `GCPV1.`. Andere QR-Codes müssen Sie nicht senden.

### 4.8 `POST /redemptions` – einlösen

Header zusätzlich `Idempotency-Key: <UUID>`. Body:

```json
{ "presentment_id": "0199a1b2-8d4e-7000-9000-5f6a7b8c9d0e", "amount": 4500, "reference": "Bon 4711", "staff": "Max" }
```

| Feld | Pflicht | |
|---|---|---|
| `presentment_id` | ja | aus 4.6 / 4.7 |
| `amount` | ja | Cent, ≥ 1 |
| `reference` | nein | Ihre Bon-/Rechnungsnummer (max. 64) – erscheint im Dashboard und Export des Restaurants |
| `staff` | nein | Name der Bedienung (max. 60) |

`201` (neu gebucht) oder `200` (Wiederholung mit gleichem Schlüssel):

```json
{
  "data": {
    "id": "0199a1b2-9e5f-7000-a000-6a7b8c9d0e1f",
    "amount": 4500,
    "currency": "EUR",
    "balance_after": 500,
    "voucher_id": "0199a0f1-…",
    "voucher_number": "2351 5576 9132 5161",
    "reference": "Bon 4711",
    "created_at": "2026-10-07T12:00:30+02:00",
    "replayed": false
  }
}
```

Drucken Sie `balance_after` gern auf den Bon („Restguthaben € 5,00").

### 4.9 `GET /redemptions/{Idempotency-Key}` – wurde gebucht?

Für den Fall, dass die Antwort auf 4.8 verloren ging:

```json
{ "data": { "status": "not_booked" } }
```

oder `{"data": {"status": "booked", …Felder wie 4.8…}}`. Nur Einlösungen Ihrer Kassen in diesem Restaurant.

### 4.10 `POST /redemptions/{id}/cancellation` – Storno

Der Bon wurde storniert: Der Betrag kommt auf den Gutschein zurück. Body: `{"reason": "Bon storniert"}`.

```json
{ "data": { "id": "…", "cancelled_redemption_id": "0199a1b2-9e5f-…", "amount": 4500, "currency": "EUR", "balance_after": 5000, "created_at": "…" } }
```

- Nur eigene Einlösungen (Ihre Kassen, dieses Restaurant), **innerhalb von 60 Minuten**, jede einmal.
- Danach: `409 TRANSACTION_NOT_REVERSIBLE` mit `context.reason = too_late` – das Restaurant korrigiert es im Dashboard.

## 5. NFC – die Karte lesen

Die Geschenkkarten sind **NXP NTAG 424 DNA** (ISO 14443-4, ISO-DEP). Auf Android: `NfcAdapter.enableReaderMode`
mit `FLAG_READER_NFC_A | FLAG_READER_SKIP_NDEF_CHECK | FLAG_READER_NO_PLATFORM_SOUNDS`, dann `IsoDep.get(tag)`,
`connect()`, `timeout = 2000`.

| # | Befehl (APDU, Hex) | Erwartete Antwort | Bedeutung |
|---|---|---|---|
| 1 | `00A4040007D276000085010100` | `9000` | NDEF-Anwendung wählen |
| 2 | `00A4000C02E104` | `9000` | NDEF-Datei wählen |
| 3 | `00B0000000` | Daten + `9000` | NDEF-Datei lesen → `tap_url` |
| 4 | `9071000002030000` | 16 Byte + `91AF` | Authentifizierung starten (Schlüssel 3) → `challenge` |
| 5 | `command` vom Server | 32 Byte + `9100` | Authentifizierung beenden → `response` |

- `rf_uid` = `Tag.getId()` als Hex (7 Byte, 14 Zeichen, Großbuchstaben).
- `tap_url` = URI des ersten NDEF-Datensatzes (2 Byte NLEN, dann die Nachricht; URI-Präfix `0x04` = `https://`).
- Antwortet die Karte bei 1–4 anders: keine GiftCard-Pro-Karte oder zu früh weggezogen → „Karte erneut
  halten".
- Bei 5 senden Sie die Antwort **immer** an den Server, auch wenn sie nicht `9100` endet – er entscheidet.
- Die ganze Lesung dauert ca. 300 ms; der Gast hält die Karte, bis Ihre App „Guthaben" zeigt.

Die Kasse schreibt **nie** auf die Karte; sie liest nur, was jedes Telefon lesen kann, und reicht die
Authentifizierung weiter.

## 6. Doppelte Buchungen vermeiden (Idempotenz)

Netzwerke fallen aus, besonders im Gastgarten. So wird ein Gutschein trotzdem **nie doppelt** belastet:

1. Erzeugen Sie für jede Einlösung **eine** UUID als `Idempotency-Key` und speichern Sie sie mit dem Bon.
2. Kommt keine Antwort: `GET /redemptions/{Key}`.
    - `booked` → fertig, das ist das Ergebnis.
    - `not_booked` → `POST /redemptions` **mit demselben Key** erneut senden (die Vorlage gilt 60 s; danach Karte
      erneut lesen).
3. Derselbe Key mit anderem Inhalt → `409 IDEMPOTENCY_CONFLICT`.

Das Kotlin-Modul (§10) macht das automatisch.

## 7. Fehler – was die Kasse anzeigt

| HTTP | Code | Bedeutung | Vorschlag für die Kasse |
|---|---|---|---|
| 401 | `UNAUTHENTICATED` | Partner-Schlüssel fehlt, falsch oder gesperrt | Einrichtung prüfen |
| 403 | `CONNECTION_REVOKED` | Restaurant hat die Verbindung getrennt / unbekannt | „GiftCard Pro ist für dieses Lokal nicht verbunden" |
| 403 | `RESTAURANT_SUSPENDED` | Restaurant bei GiftCard Pro gesperrt | wie oben |
| 403 | `DEVICE_REVOKED` | diese Kasse wurde unter Geräte gesperrt | „Diese Kasse ist gesperrt" |
| 403 | `CARD_AUTHENTICATION_FAILED` | Karte nicht echt oder Antwort falsch | „Karte nicht erkannt" |
| 403 | `SUN_REPLAYED`, `SUN_VERIFICATION_FAILED` | kopierte / manipulierte Karte | „Karte nicht erkannt" |
| 422 | `CARD_NOT_USABLE` | Karte gesperrt, ersetzt, anderes Restaurant (`context.reason`) | „Karte nicht verwendbar" |
| 422 | `MEDIUM_NOT_RECOGNIZED` | QR-Code unbekannt / gesperrt / anderes Restaurant | „Gutschein nicht erkannt" |
| 422 | `PRESENTMENT_METHOD_NOT_ALLOWED` | z. B. QR eines Gutscheins, der auf eine Karte übertragen wurde | „Bitte die Karte verwenden" |
| 422 | `PRESENTMENT_INVALID` | Vorlage abgelaufen, schon verwendet, andere Kasse (`context.reason`) | Karte / QR erneut lesen |
| 422 | `VOUCHER_BLOCKED`, `VOUCHER_EXPIRED`, `VOUCHER_NOT_REDEEMABLE` | Gutschein-Status | Status anzeigen |
| 422 | `INSUFFICIENT_BALANCE` | Betrag > Guthaben | Betrag korrigieren |
| 422 | `INVALID_AMOUNT` | z. B. Teilbetrag, wo nur ganze Einlösung erlaubt ist | Betrag = Guthaben |
| 422 | `DEBIT_LIMIT_EXCEEDED` | Limit pro Einlösung oder pro Tag (`context.limit`, `context.max`) | kleineren Betrag |
| 422 | `LINK_CODE_INVALID` | Verbindungscode ungültig | neuen Code beim Inhaber |
| 422 | `VALIDATION_FAILED` | Feld fehlt / falsch (`errors`) | Programmfehler |
| 409 | `IDEMPOTENCY_CONFLICT` | Key mit anderem Inhalt | neue UUID |
| 409 | `TRANSACTION_NOT_REVERSIBLE` | Storno nicht möglich (`context.reason`) | Restaurant korrigiert im Dashboard |
| 429 | `PRESENTMENT_THROTTLED` | zu viele fehlgeschlagene Lesungen an dieser Kasse | `context.retry_after` Sekunden warten |
| 429 | `VELOCITY_LIMIT_EXCEEDED` | zu viele Einlösungen dieses Gutscheins pro Stunde | später |
| 429 | `TOO_MANY_REQUESTS` | Ratenlimit | `Retry-After` beachten |
| 5xx | – | Serverfehler | §6 (Outcome abfragen), dann erneut |

## 8. Regeln und Grenzen

- Vorlage (Karte/QR): **60 s**, **eine** Einlösung, **dieselbe Kasse**.
- Kartenauthentifizierung: Schritt 2 innerhalb **30 s** nach Schritt 1.
- Storno: eigene Einlösungen, **60 min**.
- Ratenlimits: 600 Anfragen/min pro Restaurant-Verbindung, 90/min pro Kasse für Karte/QR/Einlösung,
  10/min für `POST /connections`.
- Nach 10 fehlgeschlagenen Lesungen in 5 Minuten wird eine Kasse kurz gebremst (`PRESENTMENT_THROTTLED`).
- Eine Karte oder ein QR-Code gehört genau einem Restaurant; in einem anderen wird sie nicht erkannt.

## 9. Sicherheit und Datenschutz

- **Keine Gastdaten:** Die Schnittstelle liefert weder Namen noch E-Mail-Adressen der Gäste – nur Gutscheinnummer,
  Guthaben und Status.
- **Keine Schlüssel auf der Kasse:** Kartenschlüssel liegen nur im Server (verschlüsselter Schlüsselspeicher).
- **Jede Buchung ist nachvollziehbar:** Kasse, Bon-Nummer, Bedienung, Zeit – im Dashboard und im unveränderlichen
  Journal des Restaurants.
- **Partner-Schlüssel** nur serverseitig oder verschlüsselt speichern; nie in Logs, Crash-Reports oder Screenshots.
- Das Restaurant kann jederzeit eine einzelne Kasse sperren oder Ihr ganzes Kassensystem trennen.

## 10. Kotlin-Modul für Android

Wir liefern eine fertige, getestete Implementierung (`integrations/android-pos/`), ohne Abhängigkeiten außer
Android selbst:

```kotlin
val gcp = GiftCardProClient(
    partnerKey = secrets.giftCardProKey,          // gcpp_…
    connectionId = restaurant.giftCardProId,      // aus connect()
    terminalId = device.serialNumber,
    terminalName = "Theke",
    language = "de",
)

// Karte liegt auf dem Gerät (Reader Mode, Hintergrund-Thread):
val vorlage = gcp.readCard(IsoDepCardChannel(isoDep))
// oder gedruckter Gutschein:  val vorlage = gcp.scanQr(qrText)

val betrag = vorlage.payable(rechnungInCent)      // berücksichtigt Guthaben und Regeln des Lokals
if (betrag > 0 && gastBestaetigt(betrag)) {
    val einloesung = gcp.redeem(vorlage.id, betrag, reference = bon.nummer, staff = kellner.name)
    bon.abziehen(einloesung.amount, restguthaben = einloesung.balanceAfter)
}
```

- `readCard` führt die fünf NFC-Befehle aus und spricht mit dem Server (≈ 300 ms).
- `redeem` erzeugt den Idempotency-Key und löst verlorene Antworten selbst auf (§6).
- `cancelRedemption(id, grund)` storniert; `connect(code)` verbindet ein Restaurant.
- Fehler: `GiftCardProException` mit `code`, `message` (in der gewählten Sprache) und `reason`;
  `CardProtocolException`, wenn die Karte nicht antwortet.

## 11. Testen und Go-live

1. **Testzugang:** Sie erhalten einen Partner-Schlüssel und ein **Testrestaurant** mit Testgutscheinen und
   einigen echten Test-Geschenkkarten (per Post).
2. **Verbinden:** Wir senden Ihnen einen Verbindungscode des Testrestaurants.
3. **Prüfliste vor dem Livegang:**
   - [ ] Karte lesen, Guthaben anzeigen, Teilbetrag einlösen, Restguthaben auf dem Bon
   - [ ] gedruckten Gutschein (QR) einlösen
   - [ ] gesperrte Karte → Meldung; Gutschein mit 0 € → nicht angeboten
   - [ ] Netzwerk während der Einlösung trennen → keine Doppelbuchung (§6)
   - [ ] Storno eines Bons innerhalb von 60 min
   - [ ] Karte zu früh wegziehen → „erneut halten"
   - [ ] getrennte Verbindung / gesperrte Kasse → verständliche Meldung
4. **Livegang:** Restaurants verbinden sich selbst mit ihrem Code (§2.2).

**OpenAPI:** `openapi.yaml` (diese Schnittstelle maschinenlesbar, z. B. für Postman oder Code-Generatoren).

**Kontakt:** GiftCard Pro, Wien.
