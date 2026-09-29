# API-Dokumentation

*Vollständige Referenz der REST-API v1 von GiftCard Pro: Begriffe, Authentifizierung, Header, Fehlercodes, Rate Limits, alle Endpunkte und Beispiele.*

---

## 1. Grundlagen

| Eigenschaft | Wert |
|---|---|
| Basis-URL | `https://<APP_DOMAIN>/api/v1` (z. B. `https://app.giftcardpro.at/api/v1`) |
| Format | ausschließlich JSON, UTF-8 (Ausnahme: CSV-Exporte) |
| Beträge | immer in **Minor Units (Cent)** als strikte Ganzzahl: `1850` = € 18,50 |
| Zeitstempel | ISO 8601 in UTC, z. B. `2029-09-13T21:59:59+00:00` |
| IDs | UUID |
| Pflicht-Header | `Accept: application/json`; bei Requests mit Body `Content-Type: application/json` |

Routen: `backend/routes/api.php`. Ressourcen: `backend/app/Http/Resources/*`, Feld für Feld abgebildet in `dashboard/src/lib/api/types.ts`.

Die API ist mandantengetrennt: Jeder Zugriff sieht ausschließlich die Daten des eigenen Lokals. IDs anderer Lokale verhalten sich wie nicht existierende IDs (`404`).

## 2. Begriffe

- **Gutschein (Voucher)** – das Konto, das ein Guthaben hält. `kind` ist `card` oder `digital`; `status` ist `active`, `blocked` oder `expired`. Ein *leerer* Gutschein ist ein `active`-Gutschein mit `balance` 0 (es gibt keinen eigenen Status). `voucher_number` ist eine interne 16-stellige Nummer für Personal und Support. Sie wird nie auf einen Gutschein gedruckt und nie als Berechtigungsnachweis akzeptiert.
- **Medium** – wie ein Gutschein vorgezeigt wird. Das einzige Medium ist derzeit der **druckbare QR-Code** eines digitalen Gutscheins (`GCPV1.` + 43 base64url-Zeichen = ein zufälliges 256-Bit-Geheimnis). Der Server speichert nur dessen SHA-256-Hash; die Nutzlast wird einmal zurückgegeben, in der Antwort des Verkaufs.
- **Vorlage (Presentment)** – der Nachweis, dass das Medium eines Gutscheins jetzt hier ist. Jede Abbuchung verbraucht eine Vorlage. Einmalig verwendbar, 60 Sekunden gültig, gebunden an Lokal, Gutschein, Zweck, Person und Gerät.
- **Zahlung (Payment)** – wie ein Verkauf oder eine Aufladung bezahlt wurde: `cash`, `card_terminal`, `bank_transfer`, `complimentary`.
- **Ledger** – `voucher_transactions` (`issue`, `redemption`, `reload`, `reversal`). Ledger, Zahlungen und Audit-Log sind nur erweiterbar (append-only) und über eine Hash-Kette verknüpft.

## 3. Authentifizierung

Es gibt drei Verfahren.

### 3.1 Browser (Dashboard, Web-Kassa) – Sanctum-SPA-Cookies

```http
GET  /sanctum/csrf-cookie                     → sets XSRF-TOKEN cookie
POST /api/v1/auth/login                       headers: X-XSRF-TOKEN: <cookie value>
     {"email":"…","password":"…","remember":false}
```

- Das Session-Cookie ist `httpOnly`, `Secure` und `SameSite=Lax`; es ist für JavaScript nicht lesbar.
- Jeder zustandsändernde Request sendet den Header `X-XSRF-TOKEN` mit dem aktuellen Wert des Cookies `XSRF-TOKEN`.
- Requests müssen von einem Host kommen, der in `SANCTUM_STATEFUL_DOMAINS` eingetragen ist. Da Web-App und API denselben Origin nutzen, gibt es keine CORS-Freigaben.
- Eine Session ist an die `X-Device-Id` gebunden, die sie zuerst gesendet hat; eine andere ID mit demselben Session-Cookie meldet die Session ab (`401`).
- Eine aus einem „Angemeldet bleiben“-Cookie wiederhergestellte Session wird nur auf einem aktiven Gerät akzeptiert, das diese Person bereits verwendet hat; sonst `401` und neue Anmeldung.
- Sitzungen enden nach `SESSION_LIFETIME` Minuten Inaktivität (Standard 480 = 8 Stunden).

### 3.2 Integrationen (Kassa, Buchhaltung) – API-Tokens

Tokens legt die Inhaberin bzw. der Inhaber unter **Settings → API** an (Berechtigung `api_tokens.manage`). Übergabe:

```http
Authorization: Bearer gcp_…
```

| Eigenschaft | Verhalten |
|---|---|
| Identität | Handelt als die Person, die das Token angelegt hat |
| Abilities | Eingeschränkt auf die beim Anlegen gewählten Berechtigungen – immer eine Teilmenge der Berechtigungen dieser Person |
| Laufzeit | höchstens `API_TOKEN_MAX_DAYS` (Standard 365 Tage) |
| Anzeige | Der Klartext (`plain_text_token`) wird **nur einmal** beim Anlegen zurückgegeben |
| Speicherung | SHA-256-Hash; Präfix `gcp_` ermöglicht Secret Scanning (z. B. GitHub Push Protection) |
| Widerruf | jederzeit über **Settings → API** oder `POST /api-tokens/{id}/revoke`; Deaktivierung sowie Passwortänderung oder -zurücksetzung der Person widerrufen ihre Tokens |
| Nachverfolgung | `last_used_at`, `last_used_ip` |

Plattform-Administratoren können keine Tokens anlegen oder verwenden. API-Tokens verwenden keine Cookies und benötigen daher kein CSRF-Token.

**Empfehlung für Kassenintegrationen:** ein eigenes Token je Kassa mit nur den nötigen Abilities (z. B. `vouchers.view`, `vouchers.redeem`), Laufzeit so kurz wie praktikabel, und eine feste `X-Device-Id` je Kassa.

### 3.3 Native Kellner-App (GiftCard Waiter) – gerätegebundene Tokens

```http
POST /api/v1/auth/token
     {"email":"…","password":"…","device_id":"<16–64 chars [A-Za-z0-9-]>","device_name":"Pixel 7","platform":"android"|"ios"}
→ 201 {"data": {"token": "gcp_…", "expires_at": "…", "user": SessionUser}}
```

Das Token wird als `Authorization: Bearer …` gesendet, **immer zusammen mit derselben `X-Device-Id`**. Eigenschaften:

| Eigenschaft | Verhalten |
|---|---|
| Abilities | `vouchers.redeem`; für Rollen mit `vouchers.sell` (Betriebsleitung, Inhaberin bzw. Inhaber) zusätzlich `vouchers.sell`. Die Rolle wird zusätzlich bei jedem Request geprüft; bei der täglichen Verlängerung folgen die Abilities der Rolle |
| Erreichbare Requests | Nur die folgenden Methoden- und Pfadpaare (`EnforceDeviceToken`); alles andere → `403 FORBIDDEN` |
| Gerätebindung | Gilt nur mit der `X-Device-Id`, für die es ausgestellt wurde; eine andere ID → `401 UNAUTHENTICATED` |
| Gerätesperre | Wird das Gerät unter **Devices** widerrufen, endet der Zugriff sofort (`403 DEVICE_REVOKED`); nach dem Wiederherstellen funktioniert das Token wieder |
| Laufzeit | Läuft nach `DEVICE_TOKEN_DAYS` (Standard 30) Tagen ohne Nutzung ab und wird verlängert, solange das Telefon verwendet wird |
| Ersetzung und Widerruf | Meldet sich dieselbe Person auf demselben Telefon erneut an, wird das bisherige Token ersetzt; `POST /auth/logout` widerruft es; eine Passwortzurücksetzung oder -änderung widerruft es |
| Anzeige | Gerätetokens erscheinen nicht unter **Settings → API**; Plattform-Administratoren sehen sie unter `/admin/api-tokens` (`kind: device`) |

| Methode | Pfad |
|---|---|
| GET | `/auth/me` |
| POST | `/auth/logout` |
| GET | `/devices/current` |
| POST | `/presentments` |
| POST | `/vouchers/{voucher}/redemptions` |
| GET | `/vouchers/{voucher}/redemptions/{idempotencyKey}` |
| POST | `/vouchers` (Verkauf; braucht `vouchers.sell`) |

Die Anmeldung hat dieselbe Kontosperre, dasselbe Rate Limit und dieselben Kontoprüfungen wie `/auth/login`. Ein deaktiviertes Konto erhält hier und bei jedem späteren Request mit seinem Token `401 ACCOUNT_DEACTIVATED`. Plattform-Administratoren und Rollen ohne `vouchers.redeem` erhalten `403 FORBIDDEN`.

### 3.4 Fehlgeschlagene Anmeldung

Ein falsches Passwort, eine unbekannte Adresse und ein vorübergehend gesperrtes Konto erhalten alle dieselbe Antwort `422 VALIDATION_FAILED` mit derselben Meldung zu `email`. Das Passwort wird immer gehasht, daher ist auch die Antwortzeit gleich. Nach `LOGIN_LOCKOUT_THRESHOLD` (10) aufeinanderfolgenden Fehlversuchen wird das Konto für `LOGIN_LOCKOUT_MINUTES` (15) gesperrt.

## 4. Header

| Header | Richtung | Bedeutung |
|---|---|---|
| `Idempotency-Key` | Request | **Pflicht** bei `POST /vouchers`, `POST /vouchers/{id}/redemptions` und `POST /vouchers/{id}/reloads`. Siehe 4.1. |
| `X-Device-Id` | Request | Stabile, zufällige ID des Endgeräts (16–64 Zeichen `[A-Za-z0-9-]`). Registriert das Gerät im Lokal; widerrufene Geräte erhalten `403 DEVICE_REVOKED`. Pflicht mit einem Gerätetoken. |
| `X-Request-Id` | beide | Korrelations-ID (8–64 Zeichen). Wird zurückgegeben; fehlt sie, erzeugt der Server eine. Erscheint im Audit-Log. |
| `X-XSRF-TOKEN` | Request | Nur Browser-Sessions: CSRF-Schutz |
| `Retry-After` | Response | Bei `429` eines Rate Limiters: Sekunden bis zum nächsten erlaubten Versuch |

### 4.1 Regeln für den Idempotency-Key

- Länge 8–96 Zeichen, erlaubt sind `A–Z`, `a–z`, `0–9`, `-`, `_`, `.`.
- **Ein neuer Schlüssel pro logischem Vorgang** – am besten eine UUID. Derselbe Schlüssel wird für alle Wiederholungen dieses Vorgangs verwendet.
- Wiederholung mit demselben Schlüssel und identischem Request: Der Server liefert das ursprüngliche Ergebnis mit `"replayed": true` (HTTP 200) und bucht **nicht** erneut.
- Derselbe Schlüssel für einen **anderen** Request (anderer Gutschein, anderer Betrag): `409 IDEMPOTENCY_CONFLICT`.
- Der Schlüssel ist je Lokal eindeutig im Ledger gespeichert.
- Ein Schlüssel, der später mit `GET /vouchers/{id}/redemptions/{key}` abgefragt werden soll, muss `[A-Za-z0-9_-]{16,100}` entsprechen (eine UUID erfüllt das).
- Bei Netzwerkfehlern oder Timeouts: das Ergebnis mit demselben Schlüssel abfragen (Einlösung, siehe 8.3.3) bzw. mit **demselben** Schlüssel wiederholen. Bei einer endgültigen Ablehnung (4xx, z. B. `INSUFFICIENT_BALANCE`) für den nächsten Versuch einen **neuen** Schlüssel erzeugen.
- Fehlt der Schlüssel oder ist er ungültig: `400 IDEMPOTENCY_KEY_REQUIRED`.

## 5. Fehler

Jeder Fehler hat dieselbe Struktur:

```json
{ "message": "The voucher balance is insufficient for this amount.",
  "code": "INSUFFICIENT_BALANCE",
  "context": { "balance": 3150, "requested": 3151 } }
```

`context` ist nur vorhanden, wenn es Inhalt hat. Bei Validierungsfehlern enthält `errors` die Meldungen je Feld. Integrationen reagieren auf `code`, nicht auf `message` (der Text kann sich ändern).

| HTTP | `code` | Wann |
|---|---|---|
| 400 | `IDEMPOTENCY_KEY_REQUIRED` | `Idempotency-Key` fehlt oder ist ungültig |
| 401 | `UNAUTHENTICATED` | Keine oder abgelaufene Session bzw. Token; Gerätetoken mit anderer `X-Device-Id`; Session von einem anderen Gerät verwendet |
| 401 | `ACCOUNT_DEACTIVATED` | Anmeldung der Kellner-App und jeder Request mit dem Gerätetoken eines deaktivierten Kontos |
| 403 | `FORBIDDEN` | Berechtigung fehlt, oder ein Gerätetoken außerhalb seiner erlaubten Requests |
| 403 | `TENANT_NOT_RESOLVED` | Restaurant-Endpunkt ohne Lokal aufgerufen (Plattform-Administratoren) |
| 403 | `TENANT_MISMATCH` | Ein Datensatz eines anderen Lokals wurde angesprochen |
| 403 | `RESTAURANT_SUSPENDED` | Das Lokal ist gesperrt |
| 403 | `DEVICE_REVOKED` | Das Endgerät wurde widerrufen |
| 403 | `ROLE_ASSIGNMENT_FORBIDDEN` | Rolle oder Token über dem eigenen Rang bzw. den eigenen Berechtigungen; Plattform-Administrator legt ein Token an |
| 403 | `COMPLIMENTARY_NOT_ALLOWED` | Zahlungsart `complimentary` ohne `vouchers.sell_complimentary` |
| 404 | `NOT_FOUND` | Unbekannte Ressource oder Ressource eines anderen Lokals |
| 409 | `IDEMPOTENCY_CONFLICT` | Schlüssel für einen anderen Request wiederverwendet |
| 409 | `INVALID_VOUCHER_STATE` | Statuswechsel im aktuellen Status nicht erlaubt |
| 409 | `TRANSACTION_NOT_REVERSIBLE` | Falscher Buchungstyp oder bereits storniert |
| 409 | `IMMUTABLE_RECORD` | Versuch, einen unveränderlichen Datensatz zu ändern |
| 409 | `RESTAURANT_NOT_DELETABLE`, `INVITATION_NOT_POSSIBLE` | Plattformadministration (siehe dort) |
| 419 | `CSRF_TOKEN_MISMATCH` | `/sanctum/csrf-cookie` neu abrufen und wiederholen |
| 422 | `VALIDATION_FAILED` | `errors` enthält Feldmeldungen (auch jede fehlgeschlagene Anmeldung) |
| 422 | `MEDIUM_NOT_RECOGNIZED` | Der gescannte Text ist kein gültiger Gutschein dieses Lokals (unbekannt, widerrufen und fremd sehen gleich aus) |
| 422 | `PRESENTMENT_METHOD_UNAVAILABLE` | Für die Methode gibt es keinen Prüfer (`live_auth`) |
| 422 | `PRESENTMENT_METHOD_NOT_ALLOWED` | Die Art des Gutscheins kann mit dieser Methode nicht eingelöst werden |
| 422 | `PRESENTMENT_INVALID` | Die Vorlage kann diese Einlösung nicht decken; `context.reason`: `not_found`, `already_used`, `expired`, `wrong_purpose`, `wrong_voucher`, `other_user`, `other_device`, `method_not_allowed_for_kind`, `medium_revoked` |
| 422 | `VOUCHER_BLOCKED`, `VOUCHER_EXPIRED`, `VOUCHER_NOT_REDEEMABLE` | Status des Gutscheins |
| 422 | `INSUFFICIENT_BALANCE`, `INVALID_AMOUNT`, `BALANCE_LIMIT_EXCEEDED`, `RELOAD_NOT_ALLOWED` | Geschäftsregeln |
| 422 | `DEBIT_LIMIT_EXCEEDED` | `context.limit`: `per_transaction` oder `per_voucher_per_day`, `context.max`, beim Tageslimit zusätzlich `context.remaining` |
| 422 | `INVITATION_NOT_DELIVERED`, `MAIL_NOT_DELIVERED`, `MAIL_RECIPIENT_REJECTED` | Plattformadministration (siehe dort) |
| 429 | `TOO_MANY_REQUESTS` | Rate Limiter (`retry_after`) |
| 429 | `PRESENTMENT_THROTTLED` | Zu viele fehlgeschlagene Vorlagen für dieses Lokal, diese Person und dieses Gerät (`context.retry_after`) |
| 429 | `VELOCITY_LIMIT_EXCEEDED` | Einlösungen je Gutschein und Stunde erreicht (`context.retry_after`: Sekunden, bis wieder eine Einlösung möglich ist) |

## 6. Rate Limits

| Limiter | Grenze | Gilt für |
|---|---|---|
| `login` | 5/min je E-Mail + IP, 30/min je IP | `/auth/login`, `/auth/token` |
| `password-reset` | 5/min je IP | `/auth/forgot-password`, `/auth/reset-password` |
| `app-config` | 60/min je IP | `/app/config` |
| `presentment` | 90/min je Person und `X-Device-Id` | `POST /presentments` |
| `voucher-operation` | 90/min je Person und `X-Device-Id` | Verkauf, Einlösung, Aufladung, Einlösungsergebnis |
| `api` | 240/min je Person | jeder authentifizierte Request |

Fehlgeschlagene Vorlagen (der gescannte Text beweist nichts) werden gesondert gezählt: Nach `PRESENTMENT_FAILURE_LIMIT` (10) innerhalb von `PRESENTMENT_FAILURE_DECAY` (300 s) je Lokal, Person und Gerät antwortet `POST /presentments` mit `429 PRESENTMENT_THROTTLED`. Scans anderer Gäste hinter derselben öffentlichen IP-Adresse zählen nie mit.

Zusätzliche fachliche Grenzen je Lokal (**Settings → Vouchers**): maximale Einzelabbuchung, maximale Abbuchung je Gutschein und Tag, Einlösungen je Gutschein und Stunde (Standard 10), maximales Guthaben.

Bei `429` den Header `Retry-After` bzw. `retry_after` beachten und nicht sofort wiederholen.

## 7. Paginierung

Listen-Endpunkte akzeptieren `page` und `per_page` (höchstens 100) und liefern:

```json
{ "data": [ … ], "links": { … }, "meta": { "current_page": 1, "last_page": 4, "per_page": 25, "total": 88 } }
```

## 8. Endpunkte

Berechtigungen stehen in eckigen Klammern. Alle Pfade sind relativ zu `/api/v1`. Alle Endpunkte außer *Öffentlich* und der Anmeldung verlangen eine Authentifizierung; Restaurant-Endpunkte verlangen zusätzlich ein Lokal (Plattform-Administratoren erhalten `403 TENANT_NOT_RESOLVED`).

### 8.1 Authentifizierung

| Methode | Pfad | Beschreibung |
|---|---|---|
| POST | `/auth/login` | `{email, password, remember?}` → `{data: SessionUser}` |
| POST | `/auth/token` | Anmeldung der nativen Kellner-App (siehe 3.3) → `201 {data: {token, expires_at, user}}` |
| POST | `/auth/logout` | Beendet die Session bzw. widerruft das aktuelle Token |
| GET | `/auth/me` | `SessionUser`: `id, name, email, locale, role {slug, name}, is_platform_admin, permissions[]` (mit Token: nur, was das Token darf), `restaurant {id, name, slug, currency, timezone, locale, status, settings}`, `platform {support_email, notice}` |
| PUT | `/auth/profile` | `{name?, locale? (en \| de)}` |
| PUT | `/auth/password` | `{current_password, password, password_confirmation}` – widerruft alle Tokens und „Angemeldet bleiben“ dieser Person |
| POST | `/auth/forgot-password` | `{email}` – antwortet immer gleich mit `200`; der Link wird aus der Queue versendet, nur an aktive Konten, die ihre Einladung angenommen haben |
| POST | `/auth/reset-password` | `{token, email, password, password_confirmation}` – nimmt auch eine Einladung an (aktiviert das Konto); widerruft alle Tokens und „Angemeldet bleiben“. Jeder Fehler antwortet mit demselben `422` |

Links für Passwortzurücksetzung und Einladung tragen das Token im URL-Fragment (`/reset-password#token=…&email=…`), das der Browser nie an einen Server sendet.

### 8.2 Vorlagen `[vouchers.redeem]`

```http
POST /presentments
{ "purpose": "spend", "method": "printable_qr", "credential": "GCPV1.q7Jx…" }
```

| Feld | Beschreibung |
|---|---|
| `purpose` | `spend` |
| `method` | `printable_qr` (geprüft); `live_auth` ist für physische Karten vorgesehen und antwortet mit `422 PRESENTMENT_METHOD_UNAVAILABLE`, solange es keinen Prüfer dafür gibt |
| `credential` | Der gescannte QR-Text (max. 512 Zeichen) |

```json
→ 201 { "data": {
    "id": "…", "purpose": "spend", "method": "printable_qr", "level": "A1",
    "expires_at": "2026-09-29T12:01:00+00:00", "expires_in": 60,
    "voucher": { "id": "…", "kind": "digital", "restaurant_name": "Trattoria Bella Vista",
      "voucher_number": "1223 5616 2557 6350", "status": "active", "currency": "EUR", "balance": 3390,
      "expires_at": null, "is_expired": false, "blocked_reason": null,
      "allow_partial_redemption": true, "max_debit_per_transaction": 25000,
      "actions": { "redeem": true } } } }
```

`expires_in` ist die aus Sicht des Servers verbleibende Zeit in Sekunden; Clients zählen ab Empfang herunter, unabhängig von ihrer eigenen Uhr. Der Gutscheinteil (`PresentedVoucher`) enthält nie Kundendaten. Response-Header `Cache-Control: no-store, private`.

Regeln: Die Vorlage gilt 60 Sekunden und für eine Abbuchung. Sie ist an dieses Lokal, diesen Gutschein, den Zweck, die Person und das Gerät gebunden (eine ohne Gerät erstellte Vorlage kann nur ohne Gerät verwendet werden). Einlöseregeln je Art: Ein `digital`-Gutschein wird nur mit einer QR-Methode eingelöst, ein `card`-Gutschein nur mit `live_auth`. Eine fehlgeschlagene Vorlage wird im Audit-Log festgehalten (`presentment.failed`) und zählt zur Sperre.

### 8.3 Gutscheine

| Methode | Pfad | Berechtigung | Body / Hinweise |
|---|---|---|---|
| GET | `/vouchers` | vouchers.view | `search` (Ziffern der Gutscheinnummer, Empfängerin bzw. Empfänger, Notizen, Kundin bzw. Kunde), `status[]` oder kommagetrennt (`active`, `blocked`, `expired`), `kind`, `customer_id`, `created_from/to`, `expires_from/to`, `min_balance`, `max_balance`, `sort` (±`created_at`, ±`balance`, ±`expires_at`, ±`voucher_number`, ±`last_used_at`), `page`, `per_page` |
| GET | `/vouchers/export` | vouchers.export | Dieselben Filter → gestreamte CSV (`;`, UTF-8 mit BOM, Dezimalkomma bei deutschsprachigen Locales, lesbare Statusnamen, gegen Formel-Injection geschützt) |
| POST | `/vouchers` | vouchers.sell | **Idempotency-Key** · Verkauf eines digitalen Gutscheins, siehe 8.3.1 |
| GET | `/vouchers/{id}` | vouchers.view | `Voucher` mit `customer`, `issued_by`, `media[]`, `payments[]` |
| PATCH | `/vouchers/{id}` | vouchers.update | `{customer_id?, recipient_name?, notes?}` |
| POST | `/vouchers/{id}/redemptions` | vouchers.redeem | **Idempotency-Key** · siehe 8.3.2 |
| GET | `/vouchers/{id}/redemptions/{idempotencyKey}` | vouchers.redeem | Ergebnis eines eigenen Einlöseversuchs, siehe 8.3.3 |
| POST | `/vouchers/{id}/reloads` | vouchers.reload | **Idempotency-Key** · `{amount, payment: {method, reference?, reason?}, note?}` → `201 {data: {voucher, transaction}, replayed}` |
| POST | `/vouchers/{id}/block` | vouchers.block | `{reason}` (3–500 Zeichen) |
| POST | `/vouchers/{id}/unblock` | vouchers.unblock | Zurück auf `active`, oder auf `expired`, wenn das Ablaufdatum während der Sperre überschritten wurde |
| POST | `/vouchers/{id}/expire` | vouchers.expire | `{reason}` – nur `active`-Gutscheine; **das Guthaben bleibt erhalten** |
| POST | `/vouchers/{id}/reinstate` | vouchers.reinstate | `{reason, expires_on?}` – nur `expired`-Gutscheine; `expires_on` (`YYYY-MM-DD`, nach heute) ist der neue letzte Gültigkeitstag in der Zeitzone des Lokals, fehlend oder `null` = kein Ablauf |
| GET | `/vouchers/{id}/history` | vouchers.view | Ledger-Einträge und Statusereignisse, neueste zuerst: `{id, kind: transaction \| event, type, label, amount, balance_after, reference, note, payment_method, reversed, user, device, created_at}` |

`Voucher`: `id, kind, voucher_number, voucher_number_formatted, status, currency, initial_value, balance, total_loaded, total_redeemed, expires_at, is_expired, blocked_at, blocked_reason, expired_at, recipient_name, notes, customer, issued_by, media[] {id, type, role, status, created_at, revoked_at}, payments[], last_used_at, created_at, updated_at`. `total_loaded` = Verkauf + Aufladungen.

**Ablauf.** Ohne Gültigkeitseinstellung hat ein Gutschein kein Ablaufdatum. Mit einer Einstellung (`validity_months`, mindestens 36) wird der letzte Gültigkeitstag beim Verkauf festgelegt, in der Zeitzone des Lokals. Bei Ablauf wird der Gutschein `expired` und behält sein Guthaben; die Inhaberin bzw. der Inhaber kann ihn wieder freigeben.

#### 8.3.1 Verkauf

```http
POST /vouchers
Idempotency-Key: 7b1c…
{ "value": 5000, "form": "printable",
  "payment": { "method": "card_terminal", "reference": "4711" },
  "customer": { "first_name": "Anna", "email": "anna@example.com" },
  "recipient_name": "Anna", "notes": "Geburtstag" }
```

| Feld | Beschreibung |
|---|---|
| `value` | Minor Units; innerhalb von `min_voucher_value` und `max_voucher_balance` des Lokals |
| `form` | `printable` (ein digitaler Gutschein mit druckbarem QR-Code) |
| `payment.method` | `cash`, `card_terminal` (verlangt `reference`: Terminalbeleg), `bank_transfer` (verlangt `reference`), `complimentary` (verlangt `reason`, 3–500 Zeichen, und `vouchers.sell_complimentary`) |
| `customer_id` oder `customer` | Optional: eine bestehende Kundin bzw. ein bestehender Kunde oder neu (`first_name, last_name, email, phone, marketing_consent`) |
| `recipient_name`, `notes` | Optional |

```json
→ 201 { "data": Voucher, "transaction": Transaction, "payment": Payment,
        "printable": { "payload": "GCPV1.q7Jx…", "qr_svg": "<svg …>" }, "replayed": false }
```

Ohne `vouchers.view` (z. B. das App-Token der Betriebsleitung) ist `data` nur `{id, kind, balance, currency}`. `printable.payload` wird nur hier zurückgegeben und kann nicht erneut abgerufen werden; das Druckblatt zeigt den QR-Code und das Lokal, nie die Gutscheinnummer oder den Wert. Eine Wiederholung mit demselben Schlüssel liefert denselben Verkauf (`"replayed": true`, 200). Kommt die Wiederholung innerhalb von 15 Minuten von derselben Person und demselben Gerät und ist der Gutschein noch aktiv und unbenutzt, enthält sie einen neuen QR-Code und der ungesehene wird widerrufen; sonst ist `printable` `null`.

#### 8.3.2 Einlösung

```http
POST /vouchers/{voucher}/redemptions
Idempotency-Key: 3f0e…
{ "amount": 1850, "presentment_id": "…", "reference": "Rechnung 4711", "note": null }
```

```json
→ 201 { "data": { "voucher": Voucher | PresentedVoucher, "transaction": Transaction }, "replayed": false }
```

Der Gutscheinteil ist der vollständige `Voucher` für Personen mit `vouchers.view`, sonst `PresentedVoucher`. In einer Datenbanktransaktion sperrt der Server die Vorlage und die Gutscheinzeile, sucht den Idempotency-Key erneut (eine Wiederholung, die auf die Sperre gewartet hat, erhält das erste Ergebnis), verbraucht die Vorlage, prüft Status, Guthaben, Teileinlösung, die Grenzen je Einlösung und je Tag sowie das Stundenlimit und schreibt den Ledger-Eintrag. Eine abgelehnte Einlösung lässt die Vorlage unverbraucht; sie bleibt bis zu ihrem Ablauf gültig.

#### 8.3.3 Ergebnis einer Einlösung

```http
GET /vouchers/{voucher}/redemptions/{idempotencyKey}
→ 200 { "data": { "status": "not_booked" } }
→ 200 { "data": { "status": "booked", "voucher": PresentedVoucher, "transaction": Transaction } }
```

Eine Kassa, deren Request unbeantwortet blieb, fragt hier nach, statt die Abbuchung erneut zu senden. Sichtbar sind nur die eigenen Versuche der anfragenden Person für diesen Gutschein; die Abfrage bucht nie etwas. `not_booked` ist erst endgültig, wenn der Versuch auf dem Server nicht mehr laufen kann; Clients warten nach ihrem letzten Request 60 Sekunden, bevor sie es als endgültig behandeln. `Cache-Control: no-store, private`.

### 8.4 Buchungen (Transactions)

| Methode | Pfad | Berechtigung | Parameter |
|---|---|---|---|
| GET | `/transactions` | transactions.view | `type[]` oder kommagetrennt (`issue`, `redemption`, `reload`, `reversal`), `voucher_id`, `user_id`, `from`, `to` (lokale Daten des Lokals), `search` (Referenz oder Gutscheinnummer) |
| GET | `/transactions/export` | transactions.export | CSV mit lesbaren Typnamen (`Sale`, `Redemption`, `Reload`, `Reversal`) und der Zahlungsart |
| GET | `/transactions/{id}` | transactions.view | |
| POST | `/transactions/{id}/reverse` | transactions.reverse | `{reason}` – ein neuer, gegengleicher Eintrag zu einer Einlösung oder Aufladung; höchstens einmal je Eintrag, innerhalb der Guthabengrenze → `201 {data: Transaction}` |

`Transaction`: `id, type, type_label, amount` (mit Vorzeichen), `balance_before, balance_after, currency, reference, note, reversed, reversed_at, reversible, related_transaction_id, payment, voucher {id, kind, voucher_number, status}, user, device, created_at`. `reversed` wird aus dem Stornoeintrag abgeleitet, der auf das Original zeigt; kein Eintrag wird je geändert. `Payment`: `id, method, method_label, amount, currency, reference, reason, created_at`.

### 8.5 Dashboard `[dashboard.view]`

| Methode | Pfad | Inhalt |
|---|---|---|
| GET | `/dashboard/stats` | `currency, vouchers_sold, vouchers_sold_this_month, vouchers_active, vouchers_empty, vouchers_blocked, vouchers_expired, outstanding_balance, outstanding_vouchers, today_transactions, today_redeemed, monthly_revenue, previous_month_revenue, monthly_redeemed, expiring_soon` |
| GET | `/dashboard/charts?days=7\|30\|90` | `daily[] {date, sold, redeemed, transactions}`, `monthly[] {month, revenue, redeemed}` (12 Monate), `status_distribution[] {status, count, balance}` |
| GET | `/dashboard/activity?limit=10` | Letzte Buchungen (max. 50) |

### 8.6 Kundinnen und Kunden

| Methode | Pfad | Berechtigung | Hinweis |
|---|---|---|---|
| GET | `/customers` | customers.view | `search` |
| POST | `/customers` | customers.manage | `{first_name, last_name?, email?, phone?, notes?, marketing_consent?}` |
| GET | `/customers/{id}` | customers.view | `{data: Customer, vouchers: Voucher[]}` |
| PATCH | `/customers/{id}` | customers.manage | Dieselben Felder; anonymisierte Datensätze sind nicht bearbeitbar (`409`) |
| POST | `/customers/{id}/anonymize` | customers.manage | DSGVO-Löschung: entfernt personenbezogene Daten, die Empfängernamen ihrer Gutscheine und die E-Mail-Adresse im Benachrichtigungsprotokoll; das Ledger bleibt vollständig |

### 8.7 Team, Rollen, Geräte

| Methode | Pfad | Berechtigung | Hinweis |
|---|---|---|---|
| GET | `/roles` | users.view | |
| GET | `/users` | users.view | |
| POST | `/users` | users.manage | `{name, email, role: owner\|manager\|waiter, password?, locale?}` – ohne Passwort wird eine Einladung versendet (Link 72 Stunden gültig) |
| GET | `/users/{id}` | users.view | |
| PATCH | `/users/{id}` | users.manage | |
| POST | `/users/{id}/deactivate` | users.manage | widerruft Tokens und Sitzungen |
| POST | `/users/{id}/activate` | users.manage | |
| POST | `/users/{id}/password-reset` | users.manage | sendet Personen, die sich nie angemeldet haben, die Einladung erneut |
| GET | `/devices` | devices.view | |
| GET | `/devices/current` | angemeldet | Gerät dieses Requests oder `null` |
| PATCH | `/devices/{id}` | devices.manage | `{name?, type? (phone, tablet, desktop, pos, integration)}` |
| POST | `/devices/{id}/revoke` | devices.manage | Gerät sofort sperren; beendet auch „Angemeldet bleiben“ seiner Personen |
| POST | `/devices/{id}/restore` | devices.manage | Gerät wieder zulassen |

### 8.8 Einstellungen `[settings.manage]`

| Methode | Pfad | Inhalt |
|---|---|---|
| GET | `/settings` | Lokal- und Gutscheineinstellungen (mit den Plattformobergrenzen) |
| PUT | `/settings/restaurant` | Profil, Adresse, `country`, `timezone`, `locale` (`de-AT`, `de-DE`, `de-CH`, `en-GB`, `en-US`) |
| PUT | `/settings/vouchers` | `validity_months` (`null` = kein Ablauf, sonst 36–360), `min_voucher_value`, `max_voucher_balance`, `max_debit_per_transaction`, `max_debit_per_voucher_per_day` (jeweils höchstens die Plattformobergrenze), `max_redemptions_per_voucher_per_hour` (0 = aus), `allow_reload`, `allow_partial_redemption`, `send_customer_emails`, `brand_color`, `receipt_footer` |
| GET | `/settings/notification-templates` | Wirksame Gäste-E-Mail-Vorlagen (`voucher_issued`, `voucher_reloaded`, `voucher_expiring`) |
| PUT | `/settings/notification-templates/{key}` | `{subject, body, is_active?, locale? (en \| de)}` – legt einen Override des Lokals an |

Gäste-E-Mails enthalten nie ein Guthaben, einen Betrag, die Gutscheinnummer oder einen Link zum Gutschein.

| Methode | Pfad | Berechtigung | Inhalt |
|---|---|---|---|
| GET / POST | `/api-tokens` | api_tokens.manage | POST `{name, abilities[], expires_at?}` → `{data: ApiToken, plain_text_token}` (**einmalig** angezeigt) |
| POST | `/api-tokens/{id}/revoke` | api_tokens.manage | |
| GET | `/audit-logs` | audit.view | Filter `action` (Präfix), `user_id`, `auditable_id`, `from`, `to` |

### 8.9 Öffentlich (ohne Anmeldung)

| Methode | Pfad | Inhalt |
|---|---|---|
| GET | `/app/config?platform=android\|ios&version=2.0.0` | Startkonfiguration der Kellner-App → `{data: {min_version: {android, ios}, update_required, maintenance_notice, support_email}}`. `update_required` ist `null` ohne `platform` und `version`. Die Mindestversionen sind Systemeinstellungen (`app.min_version.*`). `Cache-Control: public, max-age=60`; Rate Limit `app-config` |
| GET | `/up` (außerhalb von `/api/v1`) | Healthcheck: Datenbank und Cache |

Es gibt keine öffentliche Gutscheinseite und keine öffentliche Gutscheinabfrage.

### 8.10 Plattformadministration `[platform.restaurants.manage]`

Plattform-Administratoren betreiben Lokale; sie handeln nie innerhalb eines Lokals und berühren nie Gutscheine.

| Methode | Pfad | Inhalt |
|---|---|---|
| GET | `/admin/stats` | `restaurants_total, restaurants_active, restaurants_archived, vouchers_total, vouchers_active, transactions_this_month, volume_sold_this_month` |
| GET | `/admin/restaurants?search=&status=active\|suspended\|archived` | Jeweils mit `owner {…, invitation}` und `archived_at` |
| POST | `/admin/restaurants` | `{name, slug?, …, currency? (EUR, CHF, USD, GBP), owner: {name, email, password?}}` – legt Lokal und Inhaberkonto an und versendet die Einladung → `201 {data, owner}` |
| GET | `/admin/restaurants/{id}` | Auch archivierte: `{data, users[], business_data {vouchers, transactions, customers}}` |
| PATCH | `/admin/restaurants/{id}` | Profilfelder, `plan`, `currency` |
| POST | `/admin/restaurants/{id}/suspend` `{reason}` · `/reactivate` | „Deaktivieren“ / „Aktivieren“ |
| POST | `/admin/restaurants/{id}/archive` `{reason?}` · `/restore` | Archivieren = Soft Delete: ausgeblendet, Personen und Geräte ausgesperrt, Daten bleiben erhalten |
| DELETE | `/admin/restaurants/{id}` | `{confirm: "<slug>"}` – endgültig; `409 RESTAURANT_NOT_DELETABLE` (Anzahlen in `context`), wenn Gutscheine, Buchungen oder Kundendaten existieren. Das Audit-Log bleibt erhalten |
| POST | `/admin/restaurants/{id}/invitation` · `/admin/restaurants/{id}/users/{user}/invitation` | `{name?, email?}` – neue Einladung (der vorherige Link funktioniert nicht mehr; korrigiert eine vertippte Adresse). Versand aus der Queue: `202` solange eingereiht, `200` wenn versendet, `422 INVITATION_NOT_DELIVERED`, wenn der Mailserver ablehnt oder die Plattform E-Mails nur protokolliert; `409 INVITATION_NOT_POSSIBLE` für angenommene, deaktivierte oder archivierte Konten |
| GET | `/admin/api-tokens?restaurant_id=&active=` | Tokens aller Lokale, Integration und Gerät (`kind`) |
| POST | `/admin/api-tokens/{id}/revoke` | Reaktion auf Sicherheitsvorfälle |
| GET | `/admin/audit-logs?restaurant_id=&action=` | `[platform.audit.view]`, `action` = Präfix |
| GET / PUT | `/admin/system-settings` | `[platform.settings.manage]` – PUT `{settings: [{key, value}]}` |
| GET | `/admin/mail` | `[platform.settings.manage]` → `{mailer, delivers, from_address, from_name, host, port, problem}` (keine Zugangsdaten) |
| POST | `/admin/mail/test` | `[platform.settings.manage]` `{to?}` – Test-E-Mail an `to` oder die angemeldete Person; die Empfängeradresse wird zuerst geprüft (mit `MAIL_VERIFY_DOMAINS` muss ihre Domain einen Mailserver haben). `422 MAIL_RECIPIENT_REJECTED` (550–553), `422 MAIL_NOT_DELIVERED` bei anderen Fehlern |

Einladungen: Das Konto existiert von Anfang an mit einem unbekannten Zufallspasswort. Die E-Mail enthält ein einmalig verwendbares Token des Passwort-Brokers `invitations` (eigene Tabelle `invitation_tokens`, gehasht gespeichert, 72 h gültig; eine neue Einladung ersetzt es). Wer mit `POST /auth/reset-password` ein Passwort wählt, aktiviert das Konto (`user.invitation_accepted` im Audit-Log). Jeder Versuch wird in `notification_logs` festgehalten (`template_key = staff_invitation`). Die E-Mail verwendet die Sprache des Lokals, wenn es eine Übersetzung gibt (`de-*` → `de`, `en-*` → `en`), sonst `MAIL_LOCALE` (Standard `de`).

### 8.11 Systemendpunkte

| Methode | Pfad | Inhalt |
|---|---|---|
| GET | `/sanctum/csrf-cookie` | setzt `XSRF-TOKEN` (nur Browser) |
| GET | `/up` | Healthcheck: 200, wenn Datenbank und Cache erreichbar sind (außerhalb von `/api/v1`) |

## 9. Datenstrukturen

`dashboard/src/lib/api/types.ts` bildet jede Ressource Feld für Feld ab (`Voucher`, `PresentedVoucher`, `Presentment`, `Transaction`, `Payment`, `HistoryEntry`, `Customer`, `StaffUser`, `Device`, `Restaurant`, `AuditLog`, `ApiToken`, …). Diese Datei ist die maßgebliche Typreferenz.

## 10. Beispiele mit curl

Für die Beispiele:

```bash
export BASE=https://app.giftcardpro.at/api/v1
export TOKEN=gcp_…                      # API token from Settings → API
export DEVICE=pos-01-4f9c2a7e1b3d5a     # fixed ID per till (16–64 chars)
```

### 10.1 Gutschein vorlegen und einlösen

```bash
P=$(curl -s -X POST $BASE/presentments \
  -H "Authorization: Bearer $TOKEN" -H "X-Device-Id: $DEVICE" -H "Content-Type: application/json" -H "Accept: application/json" \
  -d "{\"purpose\":\"spend\",\"method\":\"printable_qr\",\"credential\":\"$QR\"}")
VOUCHER=$(echo "$P" | jq -r .data.voucher.id)
KEY=$(uuidgen)
curl -X POST "$BASE/vouchers/$VOUCHER/redemptions" \
  -H "Authorization: Bearer $TOKEN" -H "X-Device-Id: $DEVICE" -H "Content-Type: application/json" -H "Accept: application/json" \
  -H "Idempotency-Key: $KEY" \
  -d "{\"amount\": 1850, \"presentment_id\": \"$(echo "$P" | jq -r .data.id)\", \"reference\": \"Bill 4711\"}"
```

### 10.2 Ergebnis nach einer verlorenen Antwort abfragen

Die Abbuchung wird nicht erneut gesendet; stattdessen wird mit demselben Schlüssel nachgefragt:

```bash
curl -s "$BASE/vouchers/$VOUCHER/redemptions/$KEY" \
  -H "Authorization: Bearer $TOKEN" -H "X-Device-Id: $DEVICE" -H "Accept: application/json"
# → {"data":{"status":"booked", …}}  or  {"data":{"status":"not_booked"}}
```

### 10.3 Aufladen

```bash
curl -X POST $BASE/vouchers/$VOUCHER/reloads \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" \
  -H "X-Device-Id: $DEVICE" -H "Idempotency-Key: $(uuidgen)" \
  -d '{"amount": 2500, "payment": {"method": "cash"}}'
```

### 10.4 Buchung stornieren

```bash
curl -X POST $BASE/transactions/$TRANSACTION/reverse \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" \
  -d '{"reason": "Wrong amount"}'
```

### 10.5 Buchungen eines Zeitraums als CSV exportieren

```bash
curl -G $BASE/transactions/export \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode "from=2026-10-01" --data-urlencode "to=2026-10-31" \
  -o transactions-2026-10.csv
```

### 10.6 Browser-Login (zu Testzwecken)

```bash
curl -c jar.txt -b jar.txt https://app.giftcardpro.at/sanctum/csrf-cookie
XSRF=$(grep XSRF-TOKEN jar.txt | awk '{print $7}' | python3 -c 'import sys,urllib.parse;print(urllib.parse.unquote(sys.stdin.read().strip()))')
curl -c jar.txt -b jar.txt -X POST https://app.giftcardpro.at/api/v1/auth/login \
  -H "Accept: application/json" -H "Content-Type: application/json" \
  -H "Referer: https://app.giftcardpro.at" -H "X-XSRF-TOKEN: $XSRF" \
  -d '{"email":"owner@example.at","password":"…","remember":false}'
```

## 11. Hinweise für Integrationen

- **Kein Ersatz für die Registrierkasse.** GiftCard Pro stellt keine Belege aus. Verkauf und Einlösung werden zusätzlich in der Registrierkasse des Lokals gebucht (keine Rechtsberatung – mit Steuerberatung prüfen).
- Eine Einlösung braucht immer eine frische Vorlage des Gutscheins (`POST /presentments`); die Gutscheinnummer ist kein Berechtigungsnachweis.
- Beträge immer in Cent übertragen; keine Gleitkommazahlen.
- `reference` für die Belegnummer der Kassa nutzen – das erleichtert den Abgleich.
- Auf `code` reagieren; bei `429` `Retry-After` beachten; bei unbekanntem Ergebnis einer Einlösung `GET /vouchers/{id}/redemptions/{key}` abfragen statt erneut abzubuchen.
- `X-Request-Id` mitsenden und im eigenen System protokollieren – das beschleunigt die Fehlersuche im Support.
- Sicherheitsmeldungen an `security@giftcardpro.at`.

---

Version 2.0 · Stand: September 2026
