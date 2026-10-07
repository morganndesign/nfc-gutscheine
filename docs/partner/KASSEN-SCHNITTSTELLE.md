# GiftCard Pro – Kassen-Schnittstelle (POS-API)

**Version 1.1 · Oktober 2026** · für Kassenanbieter, die Gutscheine und Geschenkkarten von GiftCard Pro direkt in
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
4. Der Gast bestätigt, wie viel er verwenden möchte – vorgeschlagen wird `min(max_amount, Rechnung)` (§4.7).
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

Es gibt **zwei Schlüssel** – einen für Ihre Firma, einen pro Restaurant:

| Schlüssel | Beginnt mit | Wer hat ihn | Wofür |
|---|---|---|---|
| **Partner-Schlüssel** | `gcpp_` | nur Ihr Backend / Ihre Einrichtung | Restaurants verbinden (§2.2), Kassen-Token erneuern |
| **Kassen-Token** | `gcpc_` | die Kassen **eines** Restaurants | alles an der Kasse: Karte, QR, Einlösung, Storno |

So kann eine gestohlene Kasse höchstens ihr eigenes Restaurant erreichen – nie die anderen Restaurants Ihrer Kunden.

### 2.1 Partner-Schlüssel (einmal pro Kassenanbieter)

GiftCard Pro stellt Ihnen einen **Partner-Schlüssel** aus (`gcpp_…`, 45 Zeichen). Er identifiziert Ihr
Kassensystem bei allen Restaurants.

- Speichern Sie ihn wie ein Passwort, **nur im Backend** Ihres Kassensystems – **nie auf einer Kasse**, nie im
  Quellcode oder in Logs.
- Bei Verdacht auf Missbrauch stellen wir sofort einen neuen aus; der alte gilt dann nicht mehr. Die Kassen der
  Restaurants arbeiten mit ihren Kassen-Token weiter.

### 2.2 Verbindung pro Restaurant (Verbindungscode)

Jedes Restaurant entscheidet selbst, ob Ihr Kassensystem seine Gutscheine einlösen darf:

1. Der Inhaber öffnet im GiftCard-Pro-Dashboard **Einstellungen › Kassensysteme** und klickt
   **„Verbindungscode erstellen"**. Er erhält einen Code wie `K7QF-M2XP` (24 Stunden gültig, einmal verwendbar).
2. Er gibt den Code Ihnen oder trägt ihn selbst in Ihrer Kassen-Einrichtung ein.
3. Ihr Backend ruft `POST /connections` mit dem Code auf und erhält die **Verbindungs-ID** und den
   **Kassen-Token** (`gcpc_…`) dieses Restaurants. Der Token wird **nur dieses eine Mal** angezeigt.
4. Speichern Sie den Token wie ein Passwort beim Restaurant und geben Sie ihn den Kassen dieses Restaurants
   (z. B. verschlüsselt im Android Keystore). Er gilt, bis der Inhaber die Verbindung trennt.
5. Token verloren oder verdächtig? `POST /connections/{id}/token` gibt einen neuen; der alte gilt sofort nicht mehr
   (§4.4).

Der Inhaber erhält bei jeder neuen Verbindung eine E-Mail. Codes, die er nicht mehr braucht, widerruft er unter
**Einstellungen › Kassensysteme**.

### 2.3 Kassen-ID (jedes Gerät)

Jedes Kassengerät sendet eine eigene, gleichbleibende **Kassen-ID** (`X-Terminal-Id`, 4–64 Zeichen
`A–Z a–z 0–9 . _ -`), z. B. Ihre Geräte-Seriennummer, und optional einen Namen (`X-Terminal-Name`, z. B. „Theke").

- Jede Kasse erscheint beim Restaurant unter **Geräte** als „Ihr Kassensystem · Theke". Eine verlorene oder
  gestohlene Kasse sperrt der Inhaber dort sofort, ohne die anderen Kassen zu stören.
- Der Name wird nur beim ersten Kontakt übernommen. Umbenennen kann der Inhaber die Kasse unter **Geräte**; ein
  später geänderter `X-Terminal-Name` überschreibt das nicht.
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
| `Authorization` | immer | Einrichtung (§4.1–4.4): `Bearer gcpp_…` (Partner-Schlüssel) · Kasse (§4.5–4.11): `Bearer gcpc_…` (Kassen-Token) |
| `X-Terminal-Id` | Karten, QR, Einlösungen, Storno | gleichbleibende Kassen-ID |
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

Mit dem **Partner-Schlüssel** (Ihr Backend): 4.1–4.4. Mit dem **Kassen-Token** (die Kasse): 4.5–4.11. Ein
Schlüssel am falschen Endpunkt ergibt `401 UNAUTHENTICATED`.

### 4.1 `GET /me` – Partner-Schlüssel prüfen

Partner-Schlüssel.

```json
{ "data": { "partner": { "id": "0199…", "name": "Kassa Wien GmbH" }, "connections": 12 } }
```

### 4.2 `POST /connections` – Restaurant verbinden

Partner-Schlüssel. Body: `{"code": "K7QF-M2XP"}` (Groß-/Kleinschreibung, Leerzeichen und Bindestrich egal).

`201`:

```json
{
  "data": {
    "id": "0199a1b2-7c3d-7000-8000-4e5f6a7b8c9d",
    "status": "active",
    "connected_at": "2026-10-07T11:58:02+02:00",
    "restaurant": { "name": "Trattoria Bella Vista", "currency": "EUR", "locale": "de-AT", "timezone": "Europe/Vienna" },
    "rules": { "allow_partial_redemption": true, "max_debit_per_transaction": 50000 },
    "token": "gcpc_9fK2…"
  }
}
```

`token` ist der Kassen-Token dieses Restaurants – **nur in dieser Antwort**, danach nie wieder.

Fehler: `422 LINK_CODE_INVALID` (unbekannt, schon verwendet, widerrufen oder älter als 24 Stunden). Ein Restaurant,
das schon verbunden war, wird mit einem neuen Code wieder verbunden (gleiche ID, **neuer** Token; der alte gilt
nicht mehr).

### 4.3 `GET /connections` – alle verbundenen Restaurants

Partner-Schlüssel. `data` ist eine Liste wie in 4.2, ohne `token` (nur aktive Verbindungen).

### 4.4 `POST /connections/{id}/token` – neuer Kassen-Token

Partner-Schlüssel. Kein Body. `201` wie 4.2 mit neuem `token`; der alte Token gilt **sofort** nicht mehr. Für einen
verlorenen oder verdächtigen Token – danach den neuen an alle Kassen des Restaurants verteilen. Getrennte oder fremde
Verbindung: `403 CONNECTION_REVOKED`.

### 4.5 `GET /connection` – das Restaurant der Kasse und seine Regeln

Kassen-Token. Antwort wie 4.2 ohne `token`. Gut als Prüfung beim Start der Kasse.

| Regel | Bedeutung |
|---|---|
| `allow_partial_redemption` | `false`: ein Gutschein wird nur **ganz** eingelöst (Betrag = Guthaben) |
| `max_debit_per_transaction` | Höchstbetrag pro Einlösung in Cent (`null` = keiner) |

### 4.6 `POST /cards/authentications` – Geschenkkarte, Schritt 1

Kassen-Token + `X-Terminal-Id`. Body (Werte aus dem Kartenlesen, §5):

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

### 4.7 `POST /cards/authentications/{authentication}` – Schritt 2

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
      "redeemable": true,
      "max_amount": 5000
    },
    "card": { "number": "B-2026-0001-0042" },
    "rules": { "allow_partial_redemption": true, "max_debit_per_transaction": 50000 }
  }
}
```

- `redeemable: false` → Gutschein gesperrt, abgelaufen oder leer: zeigen Sie `status` an, bieten Sie nichts an.
- `max_amount` → der **höchste Betrag, den GiftCard Pro jetzt annimmt**: Guthaben, Limit pro Einlösung und pro Tag
  des Lokals; wo nur ganze Gutscheine eingelöst werden, das ganze Guthaben oder `0`. Schlagen Sie
  `min(max_amount, Rechnung)` vor (bei ganzer Einlösung: `max_amount`, wenn ≤ Rechnung). `0` → nichts anbieten.
- Die Vorlage gilt **60 Sekunden** und für **eine** Einlösung **an dieser Kasse**.

### 4.8 `POST /vouchers/scan` – gedruckter Gutschein (QR-Code)

Body: `{"code": "GCPV1.gdRf85597UUS3oen74yGTUZ1I_6zulhCW5gVjPJoniA"}` (der Text im QR-Code). `201` wie 4.7 mit
`"method": "qr"` und `"card": null`.

QR-Gutscheine beginnen immer mit `GCPV1.`. Andere QR-Codes müssen Sie nicht senden.

### 4.9 `POST /redemptions` – einlösen

Header zusätzlich `Idempotency-Key: <UUID>`. Body:

```json
{ "presentment_id": "0199a1b2-8d4e-7000-9000-5f6a7b8c9d0e", "amount": 4500, "reference": "Bon 4711", "staff": "Max" }
```

| Feld | Pflicht | |
|---|---|---|
| `presentment_id` | ja | aus 4.7 / 4.8 |
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

### 4.10 `GET /redemptions/{Idempotency-Key}` – wurde gebucht?

Für den Fall, dass die Antwort auf 4.9 verloren ging oder ein Serverfehler (5xx) kam:

```json
{ "data": { "status": "not_booked" } }
```

oder `{"data": {"status": "booked", …Felder wie 4.9…}}`. Nur Einlösungen Ihrer Kassen in diesem Restaurant.

### 4.11 `POST /redemptions/{id}/cancellation` – Storno

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
2. Kommt **keine Antwort** oder ein **Serverfehler (HTTP 5xx)**, ist offen, ob gebucht wurde: `GET /redemptions/{Key}`.
    - `booked` → fertig, das ist das Ergebnis.
    - `not_booked` → `POST /redemptions` **mit demselben Key** erneut senden (die Vorlage gilt 60 s; danach Karte
      erneut lesen).
3. Bleibt es offen (Server nicht erreichbar), den Bon **nicht** als bezahlt oder unbezahlt abschließen: später mit
   demselben Key erneut fragen.
4. Eine Ablehnung (4xx, z. B. `INSUFFICIENT_BALANCE`) ist endgültig: es wurde nichts gebucht.
5. Derselbe Key mit anderem Inhalt → `409 IDEMPOTENCY_CONFLICT`.

Das Kotlin-Modul (§10) macht das automatisch.

## 7. Fehler – was die Kasse anzeigt

| HTTP | Code | Bedeutung | Vorschlag für die Kasse |
|---|---|---|---|
| 401 | `UNAUTHENTICATED` | Schlüssel/Token fehlt, falsch, erneuert, gesperrt – oder am falschen Endpunkt | Einrichtung prüfen |
| 403 | `CONNECTION_REVOKED` | Restaurant hat die Verbindung getrennt | „GiftCard Pro ist für dieses Lokal nicht verbunden" |
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
| 422 | `DEBIT_LIMIT_EXCEEDED` | Limit pro Einlösung oder pro Tag (`context.limit`, `context.max`) | höchstens `max_amount` |
| 422 | `LINK_CODE_INVALID` | Verbindungscode ungültig | neuen Code beim Inhaber |
| 422 | `VALIDATION_FAILED` | Feld fehlt / falsch (`errors`) | Programmfehler |
| 409 | `IDEMPOTENCY_CONFLICT` | Key mit anderem Inhalt | neue UUID |
| 409 | `TRANSACTION_NOT_REVERSIBLE` | Storno nicht möglich (`context.reason`) | Restaurant korrigiert im Dashboard |
| 429 | `PRESENTMENT_THROTTLED` | zu viele fehlgeschlagene Lesungen an dieser Kasse | `context.retry_after` Sekunden warten |
| 429 | `VELOCITY_LIMIT_EXCEEDED` | zu viele Einlösungen dieses Gutscheins pro Stunde | später |
| 429 | `TOO_MANY_REQUESTS` | Ratenlimit | `Retry-After` beachten |
| 5xx | – | Serverfehler – bei `POST /redemptions` ist offen, ob gebucht wurde | §6 (Ergebnis abfragen), dann erneut |

## 8. Regeln und Grenzen

- Vorlage (Karte/QR): **60 s**, **eine** Einlösung, **dieselbe Kasse**.
- Kartenauthentifizierung: Schritt 2 innerhalb **30 s** nach Schritt 1.
- Storno: eigene Einlösungen, **60 min**.
- Ratenlimits: 600 Anfragen/min pro Schlüssel bzw. Kassen-Token, 90/min pro Kasse für Karte/QR/Einlösung,
  10/min für `POST /connections` und `POST /connections/{id}/token`.
- Nach 10 fehlgeschlagenen Lesungen in 5 Minuten wird eine Kasse kurz gebremst (`PRESENTMENT_THROTTLED`).
- Eine Karte oder ein QR-Code gehört genau einem Restaurant; in einem anderen wird sie nicht erkannt.

## 9. Sicherheit und Datenschutz

- **Keine Gastdaten:** Die Schnittstelle liefert weder Namen noch E-Mail-Adressen der Gäste – nur Gutscheinnummer,
  Guthaben und Status.
- **Keine Schlüssel auf der Kasse:** Kartenschlüssel liegen nur im Server (verschlüsselter Schlüsselspeicher).
- **Jede Buchung ist nachvollziehbar:** Kasse, Bon-Nummer, Bedienung, Zeit – im Dashboard und im unveränderlichen
  Journal des Restaurants.
- **Partner-Schlüssel nur im Backend**, nie auf einer Kasse. Auf den Kassen liegt nur der **Kassen-Token** ihres
  Restaurants (verschlüsselt, z. B. Android Keystore) – eine gestohlene Kasse erreicht so nur dieses eine Restaurant.
  Beide nie in Logs, Crash-Reports oder Screenshots.
- Das Restaurant kann jederzeit eine einzelne Kasse sperren oder Ihr ganzes Kassensystem trennen; der Inhaber wird
  bei jeder neuen Verbindung per E-Mail informiert.
- Stornos Ihrer Kassen werden wie die des Personals überwacht: viele Stornos an einem Tag melden wir dem Restaurant.

## 10. Kotlin-Modul für Android

Wir liefern eine fertige, getestete Implementierung (`integrations/android-pos/`), ohne Abhängigkeiten außer
Android selbst:

Einrichtung – **in Ihrem Backend**, mit dem Partner-Schlüssel:

```kotlin
val partner = GiftCardProPartner(partnerKey = secrets.giftCardProKey)   // gcpp_…
val zugang = partner.connect(codeVomInhaber)        // einmal pro Restaurant
restaurant.gcpToken = zugang.token                  // gcpc_… – wie ein Passwort speichern, an die Kassen verteilen
// verloren/verdächtig:  restaurant.gcpToken = partner.newToken(zugang.connection.id).token
```

An der Kasse – mit dem Kassen-Token ihres Restaurants:

```kotlin
val gcp = GiftCardProClient(
    connectionToken = restaurant.gcpToken,        // gcpc_…
    terminalId = device.serialNumber,
    terminalName = "Theke",
    language = "de",
)

// Karte liegt auf dem Gerät (Reader Mode, Hintergrund-Thread):
val vorlage = gcp.readCard(IsoDepCardChannel(isoDep))
// oder gedruckter Gutschein:  val vorlage = gcp.scanQr(qrText)

val betrag = vorlage.payable(rechnungInCent)      // nutzt max_amount: Guthaben, Limits und Regeln des Lokals
if (betrag > 0 && gastBestaetigt(betrag)) {
    val einloesung = gcp.redeem(vorlage.id, betrag, reference = bon.nummer, staff = kellner.name)
    bon.abziehen(einloesung.amount, restguthaben = einloesung.balanceAfter)
}
```

- `readCard` führt die fünf NFC-Befehle aus und spricht mit dem Server (≈ 300 ms).
- `redeem` erzeugt den Idempotency-Key und löst verlorene Antworten und Serverfehler selbst auf (§6). Bleibt das
  Ergebnis offen: `RedemptionOutcomeUnknownException` mit `idempotencyKey` – später `redemptionOutcome(key)` fragen.
- `cancelRedemption(id, grund)` storniert.
- Fehler: `GiftCardProException` mit `status`, `code`, `message` (in der gewählten Sprache) und `reason`;
  `CardProtocolException`, wenn die Karte nicht mitmacht – `step = "tag_lost"`, wenn sie weggezogen wurde
  („Karte erneut halten").

## 11. Testen und Go-live

1. **Testzugang:** Sie erhalten einen Partner-Schlüssel und ein **Testrestaurant** mit Testgutscheinen und
   einigen echten Test-Geschenkkarten (per Post). Es gibt keine eigene Test-URL: das Testrestaurant ist ein normales
   Restaurant auf `https://app.giftcardpro.at`, nur mit Testgutscheinen ohne echten Wert. Einlösungen dort betreffen
   nur diese Testgutscheine; stornieren Sie sie frei (§4.11).
2. **Verbinden:** Wir senden Ihnen einen Verbindungscode des Testrestaurants; Ihr Backend erhält damit den
   Kassen-Token für Ihre Testkassen.
3. **Prüfliste vor dem Livegang:**
   - [ ] Karte lesen, Guthaben anzeigen, Teilbetrag einlösen, Restguthaben auf dem Bon
   - [ ] gedruckten Gutschein (QR) einlösen
   - [ ] gesperrte Karte → Meldung; Gutschein mit 0 € → nicht angeboten
   - [ ] Netzwerk während der Einlösung trennen → keine Doppelbuchung (§6)
   - [ ] Storno eines Bons innerhalb von 60 min
   - [ ] Karte zu früh wegziehen → „erneut halten"
   - [ ] getrennte Verbindung / gesperrte Kasse → verständliche Meldung
   - [ ] Partner-Schlüssel liegt nur im Backend; die Kasse kennt nur den Kassen-Token
   - [ ] Betrag über `max_amount` wird nicht angeboten
4. **Livegang:** Restaurants verbinden sich selbst mit ihrem Code (§2.2).

**OpenAPI:** `openapi.yaml` (diese Schnittstelle maschinenlesbar, z. B. für Postman oder Code-Generatoren).

**Kontakt:** GiftCard Pro, Wien.
