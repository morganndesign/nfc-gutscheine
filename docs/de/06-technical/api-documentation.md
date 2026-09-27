# API-Dokumentation

*Vollständige Referenz der REST-API v1 von GiftCard Pro: Authentifizierung, Header, Fehlercodes, Rate Limits, alle Endpunkte und Beispiele.*

---

## 1. Grundlagen

| Eigenschaft | Wert |
|---|---|
| Basis-URL | `https://<APP_DOMAIN>/api/v1` (z. B. `https://app.giftcardpro.at/api/v1`) |
| Format | ausschließlich JSON, UTF-8 (Ausnahmen: CSV-Exporte, QR-Code als SVG) |
| Beträge | immer in **Minor Units (Cent)** als Ganzzahl: `1850` = € 18,50 |
| Zeitstempel | ISO 8601 in UTC, z. B. `2029-09-13T21:59:59+00:00` |
| IDs | UUID |
| Pflicht-Header | `Accept: application/json`; bei Requests mit Body `Content-Type: application/json` |

Die API ist mandantengetrennt: Jeder Zugriff sieht ausschließlich die Daten des eigenen Restaurants. IDs anderer Restaurants verhalten sich wie nicht existierende IDs (`404`).

## 2. Authentifizierung

Es gibt drei Verfahren.

### 2.1 Browser (Dashboard, Kellner-App im Browser) – Sanctum-SPA-Cookies

```http
GET  /sanctum/csrf-cookie                     → sets XSRF-TOKEN cookie
POST /api/v1/auth/login                       headers: X-XSRF-TOKEN: <cookie value>
     {"email":"…","password":"…","remember":true}
```

- Das Session-Cookie (`giftcardpro_session`) ist `httpOnly`, `Secure` und `SameSite=Lax`; es ist für JavaScript nicht lesbar.
- Jeder zustandsändernde Request muss den Header `X-XSRF-TOKEN` mit dem aktuellen Wert des Cookies `XSRF-TOKEN` senden.
- Requests müssen von einem Host kommen, der in `SANCTUM_STATEFUL_DOMAINS` eingetragen ist. Da Web-App und API denselben Origin nutzen, gibt es keine CORS-Freigaben.
- Eine Browser-Session ist an die Geräte-ID gebunden, mit der die Anmeldung erfolgte (siehe `X-Device-Id`).
- Sitzungen enden nach `SESSION_LIFETIME` Minuten Inaktivität (Standard 480 = 8 Stunden). Eine Passwortänderung meldet alle anderen Sitzungen ab.

### 2.2 Integrationen (Kassa, Buchhaltung) – API-Tokens

Tokens legt die Inhaberin bzw. der Inhaber unter **Settings → API** an (Berechtigung `api_tokens.manage`). Übergabe:

```http
Authorization: Bearer gcp_…
```

Eigenschaften eines Tokens:

| Eigenschaft | Verhalten |
|---|---|
| Identität | Handelt als die Person, die das Token angelegt hat |
| Abilities | Eingeschränkt auf die beim Anlegen gewählten Berechtigungen – immer eine Teilmenge der Berechtigungen dieser Person |
| Laufzeit | höchstens `API_TOKEN_MAX_DAYS` (Standard 365 Tage); ohne Angabe wird das Maximum gesetzt |
| Anzeige | Der Klartext (`plain_text_token`) wird **nur einmal** beim Anlegen zurückgegeben |
| Speicherung | SHA-256-Hash; Präfix `gcp_` ermöglicht Secret Scanning (z. B. GitHub Push Protection) |
| Widerruf | jederzeit über **Settings → API** oder `POST /api-tokens/{id}/revoke`; wird ein Benutzer deaktiviert, werden seine Tokens widerrufen |
| Nachverfolgung | `last_used_at`, `last_used_ip` |

API-Tokens verwenden keine Cookies und benötigen daher kein CSRF-Token.

**Empfehlung für Kassenintegrationen:** ein eigenes Token je Kassa mit nur den nötigen Abilities (z. B. `cards.scan`, `cards.view`, `cards.redeem`), Laufzeit so kurz wie praktikabel, und ein fester `X-Device-Id` je Kassa.

### 2.3 Native Kellner-App (GiftCard Waiter) – gerätegebundene Tokens

Die native App für Android und iPhone meldet sich nicht mit Cookies an, sondern holt sich ein an das Gerät gebundenes Token:

```http
POST /api/v1/auth/token
     {"email":"…","password":"…","device_id":"<16–64 chars>","device_name":"Pixel 7","platform":"android"|"ios"}
→ 201 {"data": {"token": "gcp_…", "expires_at": "…", "user": SessionUser}}
```

Das Token wird als `Authorization: Bearer …` gesendet, **immer zusammen mit demselben `X-Device-Id`**. Eigenschaften:

| Eigenschaft | Verhalten |
|---|---|
| Umfang | Nur Scannen und Einlösen (Abilities `cards.scan`, `cards.redeem`); erreichbar sind ausschließlich `auth/me`, `auth/logout`, `scan`, `cards/{id}/redeem` und `devices/current` – auch für Inhaberinnen und Inhaber |
| Gerätebindung | Gilt nur mit dem `X-Device-Id`, für den es ausgestellt wurde; eine andere ID → `401` |
| Gerätesperre | Wird das Gerät unter **Devices** widerrufen, endet der Zugriff sofort (`403 DEVICE_REVOKED`); nach dem Wiederherstellen funktioniert das Token wieder |
| Laufzeit | Läuft nach `DEVICE_TOKEN_DAYS` (Standard 30) Tagen ohne Nutzung ab und wird verlängert, solange das Telefon verwendet wird |
| Ersetzung | Meldet sich dieselbe Person auf demselben Telefon erneut an, wird das bisherige Token ersetzt; `POST /auth/logout` widerruft es |
| Anzeige | Gerätetokens erscheinen nicht unter **Settings → API** |

Es gelten dieselbe Kontosperre (`423 ACCOUNT_LOCKED`), dasselbe Rate Limit (`login`) und dieselben Kontoprüfungen wie bei `/auth/login`. Ein deaktiviertes Konto erhält hier und bei jedem späteren Request mit seinem Token `401 ACCOUNT_DEACTIVATED`. Plattform-Administratoren und Rollen ohne Scan- und Einlöseberechtigung erhalten `403 FORBIDDEN`.

## 3. Header

| Header | Richtung | Bedeutung |
|---|---|---|
| `Idempotency-Key` | Request | **Pflicht** bei `redeem`, `reload`, `transfer`; optional bei `POST /cards`. Siehe 3.1. |
| `X-Device-Id` | Request | Stabile, zufällige ID des Endgeräts (16–64 Zeichen `[A-Za-z0-9-]`; ungültige Werte werden ignoriert). Registriert das Gerät; widerrufene Geräte erhalten `403 DEVICE_REVOKED`. Eine Browser-Session ist an die Geräte-ID der Anmeldung gebunden – eine andere ID mit demselben Session-Cookie führt zu `401`. |
| `X-Restaurant-Id` | Request | Nur Plattform-Administratoren: im Kontext eines Restaurants handeln. |
| `X-Request-Id` | beide | Korrelations-ID (8–64 Zeichen `[A-Za-z0-9-]`). Wird zurückgegeben; fehlt sie oder ist sie ungültig, erzeugt der Server eine UUID. Erscheint im Audit-Log und in den Anwendungslogs. |
| `X-XSRF-TOKEN` | Request | Nur Browser-Sessions: CSRF-Schutz |
| `Retry-After` | Response | Bei `429`: Sekunden bis zum nächsten erlaubten Versuch |

### 3.1 Regeln für den Idempotency-Key

- Länge 8–96 Zeichen, erlaubt sind `A–Z`, `a–z`, `0–9`, `-`, `_`, `.`. Der Doppelpunkt `:` ist für interne Ledger-Buchungen reserviert.
- **Ein neuer Schlüssel pro logischem Vorgang** – am besten eine UUID. Derselbe Schlüssel wird für alle Wiederholungen dieses Vorgangs verwendet.
- Wiederholung mit demselben Schlüssel und identischem Request: Der Server liefert das ursprüngliche Ergebnis mit `"replayed": true` und bucht **nicht** erneut.
- Derselbe Schlüssel für einen **anderen** Request (andere Karte, anderer Betrag): `409 IDEMPOTENCY_CONFLICT`.
- Der Schlüssel ist je Restaurant eindeutig im Ledger gespeichert.
- Bei Netzwerkfehlern oder Timeouts: mit **demselben** Schlüssel wiederholen. Bei einer endgültigen Ablehnung (4xx, z. B. `INSUFFICIENT_BALANCE`) für den nächsten Versuch einen **neuen** Schlüssel erzeugen.
- Fehlt der Schlüssel oder ist er ungültig: `400 IDEMPOTENCY_KEY_REQUIRED`.

## 4. Fehler

Jeder Fehler hat dieselbe Struktur:

```json
{ "message": "The gift card balance is insufficient for this amount.",
  "code": "INSUFFICIENT_BALANCE",
  "context": { "balance": 3150, "requested": 3151 } }
```

Bei Validierungsfehlern enthält `errors` die Meldungen je Feld. Integrationen sollten auf `code` reagieren, nicht auf `message` (der Text kann sich ändern).

| HTTP | `code` | Wann |
|---|---|---|
| 400 | `IDEMPOTENCY_KEY_REQUIRED` | `Idempotency-Key` fehlt oder ist ungültig |
| 401 | `UNAUTHENTICATED` | Keine oder abgelaufene Session bzw. Token |
| 401 | `ACCOUNT_DEACTIVATED` | Nur native Kellner-App (Anmeldung und jeder Request mit Gerätetoken): Das Konto wurde deaktiviert |
| 403 | `FORBIDDEN` | Berechtigung fehlt |
| 403 | `TENANT_NOT_RESOLVED` | Plattform-Administrator ruft einen Restaurant-Endpunkt ohne `X-Restaurant-Id` auf |
| 403 | `RESTAURANT_SUSPENDED` | Restaurant ist gesperrt |
| 403 | `DEVICE_REVOKED` | Endgerät wurde widerrufen |
| 403 | `CARD_FOREIGN_RESTAURANT` | Karte gehört zu einem anderen Restaurant |
| 403 | `NFC_UID_MISMATCH` | Chip weicht vom gebundenen Chip ab (Verdacht auf Klon) |
| 403 | `NFC_SIGNATURE_INVALID` | NTAG-424-SUN-MAC ungültig oder fehlt |
| 403 | `NFC_REPLAY_DETECTED` | NTAG-424-Tap-Zähler steigt nicht (kopierte URL) |
| 409 | `NFC_TAG_IN_USE` | Chip gehört zu einer anderen nutzbaren Karte |
| 409 | `NFC_ATTEMPT_INVALID` | NFC-Programmierschritt ohne passenden offenen Versuch |
| 409 | `NFC_CARD_ALREADY_PROGRAMMED` | Programmierstation: Die Karte wurde inzwischen auf einem anderen Gerät programmiert |
| 422 | `NFC_VERIFICATION_FAILED` | Zurückgelesener Tag stimmt nicht (`context.reason`: `URL_MISMATCH` oder `TAG_SWAPPED`); nichts gespeichert |
| 403 | `ROLE_ASSIGNMENT_FORBIDDEN` | Rollen- oder Benutzerverwaltung über dem eigenen Rang |
| 404 | `NOT_FOUND`, `CARD_NOT_FOUND` | Unbekannte Ressource (oder Ressource eines anderen Restaurants) |
| 409 | `INVALID_CARD_STATE` | Aktion im aktuellen Kartenstatus nicht erlaubt |
| 409 | `IDEMPOTENCY_CONFLICT` | Schlüssel für einen anderen Request wiederverwendet |
| 409 | `TRANSACTION_NOT_REVERSIBLE` | Bereits storniert oder falscher Buchungstyp |
| 419 | `CSRF_TOKEN_MISMATCH` | `/sanctum/csrf-cookie` neu abrufen und wiederholen |
| 422 | `VALIDATION_FAILED` | `errors` enthält Feldmeldungen |
| 422 | `INSUFFICIENT_BALANCE`, `INVALID_AMOUNT`, `CARD_BLOCKED`, `CARD_EXPIRED`, `CARD_NOT_REDEEMABLE`, `BALANCE_LIMIT_EXCEEDED`, `RELOAD_NOT_ALLOWED` | Geschäftsregeln |
| 423 | `ACCOUNT_LOCKED` | Zu viele fehlgeschlagene Anmeldungen (`retry_after` in Sekunden, auch in `context`) |
| 429 | `TOO_MANY_REQUESTS`, `SCAN_THROTTLED`, `VELOCITY_LIMIT_EXCEEDED` | Rate Limits bzw. Betrugslimits. `VELOCITY_LIMIT_EXCEEDED` enthält `context.retry_after` (Sekunden, bis im Einstundenfenster der Karte wieder eine Einlösung möglich ist) |

## 5. Rate Limits

| Limiter | Grenze |
|---|---|
| `login` | 5/min je E-Mail + IP, 30/min je IP (Anmeldung im Browser und in der nativen Kellner-App) |
| `app-config` | 60/min je IP |
| `password-reset` | 5/min je IP |
| `public-card` | 20/min je IP |
| `card-scan` | 90/min je Benutzer **und Endgerät** (`X-Device-Id`); fehlgeschlagene oder verdächtige Abfragen (nicht gefunden, fremde Karte, UID-Abweichung, ungültige SUN-Signatur, Replay) zusätzlich 10 je 5 Minuten je Benutzer und je IP (`SCAN_FAILURE_LIMIT`, `SCAN_FAILURE_DECAY`) |
| `card-operation` | 90/min je Benutzer und Endgerät (`redeem`, `reload`, `transfer`) |
| `api` | 240/min je Benutzer (alle authentifizierten Endpunkte) |

Zusätzliche fachliche Grenzen je Restaurant (Settings → Gift cards): maximale Einlösungen pro Karte und Stunde (Standard 10, Fehler `VELOCITY_LIMIT_EXCEEDED`), maximale Einzeleinlösung, maximales Kartenguthaben. Nach 10 aufeinanderfolgenden falschen Passwörtern wird das Konto 15 Minuten gesperrt (`LOGIN_LOCKOUT_THRESHOLD`, `LOGIN_LOCKOUT_MINUTES`).

Bei `429` den Header `Retry-After` beachten und nicht sofort wiederholen.

## 6. Paginierung

Listen-Endpunkte akzeptieren `page` und `per_page` (höchstens 100) und liefern:

```json
{ "data": [ … ], "links": { "next": "…" }, "meta": { "current_page": 1, "last_page": 4, "per_page": 25, "total": 88 } }
```

## 7. Endpunkte

Berechtigungen stehen in eckigen Klammern. `→` zeigt den Response-Body. Alle Pfade sind relativ zu `/api/v1`.

### 7.1 Authentifizierung

| Methode | Pfad | Beschreibung |
|---|---|---|
| POST | `/auth/login` | `{email, password, remember}` → `{data: SessionUser}` (Rate Limit `login`) |
| POST | `/auth/token` | Anmeldung der nativen Kellner-App (siehe 2.3) → `201 {data: {token, expires_at, user}}` (Rate Limit `login`) |
| POST | `/auth/logout` | Beendet die Session bzw. widerruft das aktuelle API-Token |
| GET | `/auth/me` | Angemeldete Person inkl. `permissions[]`, Restaurant-Einstellungen und Plattformhinweisen (`support_email`, `notice`) |
| PUT | `/auth/profile` | `{name?, locale?}` |
| PUT | `/auth/password` | `{current_password, password, password_confirmation}` – meldet andere Sitzungen ab |
| POST | `/auth/forgot-password` | `{email}` – antwortet immer mit 200 (keine Kontoermittlung möglich) |
| POST | `/auth/reset-password` | `{token, email, password, password_confirmation}` |

### 7.2 Scan – Einstiegspunkt der Servicekraft `[cards.scan]`

```http
POST /scan
{ "method": "nfc", "token": "https://app.example.com/c/3f2b…a6c", "nfc_uid": "04:A2:3F:1B:6C:80:12" }
```

| Feld | Beschreibung |
|---|---|
| `method` | `nfc` · `qr` · `link` · `manual` · `api` |
| `token` | Rohe URL oder Token vom Tag bzw. QR-Code (SUN-Parameter `picc`/`cmac` werden aus der URL übernommen) |
| `card_number` | Statt `token` bei manueller Eingabe |
| `nfc_uid` | Seriennummer des Chips (Web NFC `serialNumber`) – aktiviert die Klonerkennung |
| `picc`, `cmac` | NTAG-424-DNA-SUN-Werte (falls nicht in der URL) |

```json
→ { "data": { "id": "…", "restaurant_name": "Trattoria Bella Vista", "card_number": "1223 5616 2557 6350",
     "status": "active", "currency": "EUR", "balance": 3390, "expires_at": "2029-09-13T21:59:59+00:00",
     "is_expired": false, "blocked_reason": null, "allow_partial_redemption": true,
     "actions": { "redeem": true, "reload": false, "history": false, "block": false, "activate": false } } }
```

`/scan` liefert **nie** Kundendaten. Jeder Versuch wird in der Tabelle `nfc_scans` protokolliert; verdächtige Ergebnisse zusätzlich als `warning` im Anwendungslog.

### 7.3 Karten

| Methode | Pfad | Berechtigung | Body / Hinweise |
|---|---|---|---|
| GET | `/cards` | cards.view | `search, status[] (csv), customer_id, created_from/to, expires_from/to, min_balance, max_balance, sort (±created_at, ±balance, ±expires_at, ±card_number, ±last_used_at), page, per_page` |
| GET | `/cards/export` | cards.export | Dieselben Filter → gestreamte CSV (`;`, UTF-8 mit BOM, Dezimalkomma bei deutschsprachigen Locales, lesbare Statusnamen, gegen Formel-Injection geschützt) |
| POST | `/cards` | cards.create | `{value, expires_at?, customer_id? \| customer{first_name,last_name,email,phone}?, recipient_name?, notes?, activate?=true, nfc_tag_type?}` → `{data: GiftCard, transaction, nfc: {url, tag_type_hint, ndef_template}}`. `Idempotency-Key` optional. |
| GET | `/cards/{id}` | cards.view | |
| PATCH | `/cards/{id}` | cards.update | `{customer_id?, recipient_name?, notes?, expires_at?}` |
| POST | `/cards/{id}/redeem` | cards.redeem | **Idempotency-Key** · `{amount, reference?, note?}` → `201 {data:{card, transaction}, replayed}` |
| POST | `/cards/{id}/reload` | cards.reload | **Idempotency-Key** · `{amount, reference?, note?}` |
| POST | `/cards/{id}/transfer` | cards.transfer | **Idempotency-Key** · `{target_card_id \| target_card_number, amount? (Standard: gesamtes Guthaben), note?}` |
| POST | `/cards/{id}/activate` | cards.activate | inaktiv → aktiv |
| POST | `/cards/{id}/block` | cards.block | `{reason}` |
| POST | `/cards/{id}/unblock` | cards.unblock | |
| POST | `/cards/{id}/expire` | cards.expire | `{reason?}` – bucht das Restguthaben aus |
| POST | `/cards/{id}/replace` | cards.replace | `{reason, nfc_tag_type?}` → neue Karte (201) mit dem Restguthaben; alte Karte erhält Status `replaced` |
| GET | `/cards/{id}/history` | cards.view | Ledger und Ereignisse, neueste zuerst |
| GET | `/cards/{id}/nfc` | cards.write_nfc | NFC-Nutzlast (URL, NTAG-424-Vorlage, Sperrrichtlinie) |
| POST | `/cards/{id}/nfc/check` | cards.write_nfc | Programmierschritt 2: `{attempt_id (uuid), uid, current_url?}` → `status` `available` · `already_programmed` · `refused` (mit `reason`, `conflict`, `content`, `expected_url`) |
| POST | `/cards/{id}/nfc` | cards.write_nfc | Tag erfassen. `method: web_nfc` → `{attempt_id, tag_type (ntag213/215/216), uid, read_back: {uid, url}}` – der Chip wird nur gespeichert, wenn der zurückgelesene Chip derselbe ist und exakt den Kartenlink trägt. `manual` · `provisioned` (NTAG 424) · `printed` (QR) – nie mit `uid` |
| POST | `/cards/{id}/nfc/lock` | cards.write_nfc | `{attempt_id}` – geprüfter Tag wurde schreibgeschützt |
| POST | `/cards/{id}/nfc/attempts` | cards.write_nfc | Fehler aus dem Browser melden: `{attempt_id, stage, result (failed · refused · cancelled), error_code, …}` |
| GET | `/cards/{id}/nfc/attempts` | cards.write_nfc | Die letzten 50 Programmierversuche der Karte |
| GET | `/cards/{id}/qr` | cards.write_nfc | `image/svg+xml` – QR-Code der Karten-URL |

**Ablaufdatum (`expires_at`)** ist ein lokales Datum `YYYY-MM-DD`: Die Karte gilt bis 23:59:59 dieses Tages in der Zeitzone des Restaurants. Bei `POST /cards` gilt: Wird der Schlüssel *weggelassen*, gilt die Standard-Gültigkeit des Restaurants; wird ausdrücklich `null` gesendet, entsteht eine Karte ohne Ablauf. Vergangene Daten → `422`.

**Kartenstatus:** `inactive`, `active`, `redeemed`, `blocked`, `expired`, `replaced`.

### 7.4 Buchungen (Transactions)

| Methode | Pfad | Berechtigung | Parameter |
|---|---|---|---|
| GET | `/transactions` | transactions.view | `type[] (csv), gift_card_id, user_id, from, to (lokale Daten des Restaurants), search` |
| GET | `/transactions/export` | transactions.export | CSV mit lesbaren Typnamen (`Sale`, `Redemption`, `Reload`, `Transfer in/out`, …) |
| GET | `/transactions/{id}` | transactions.view | |
| POST | `/transactions/{id}/reverse` | transactions.reverse | `{reason}` – Gegenbuchung zu einer Einlösung oder Aufladung |

Buchungstypen im Ledger: `issue`, `redemption`, `reload`, `transfer_out`, `transfer_in`, `expiration`, `reversal`, `adjustment`. Das Ledger ist unveränderlich; Korrekturen erfolgen ausschließlich als Gegenbuchung.

### 7.5 Dashboard `[dashboard.view]`

| Methode | Pfad | Inhalt |
|---|---|---|
| GET | `/dashboard/stats` | Kennzahlen: `outstanding_balance` + `outstanding_cards` (offene Verbindlichkeit und Anzahl der Karten), `monthly_revenue` / `previous_month_revenue`, `monthly_redeemed` / `today_redeemed`, verkaufte Karten (gesamt / dieser Monat / aktiv), `expiring_soon` |
| GET | `/dashboard/charts?days=7\|30\|90` | `daily[] {date, sold, redeemed, transactions}`, `monthly[]` (12 Monate), `status_distribution[]` |
| GET | `/dashboard/activity?limit=10` | Letzte Buchungen |

### 7.6 Kundinnen und Kunden

| Methode | Pfad | Berechtigung | Hinweis |
|---|---|---|---|
| GET | `/customers` | customers.view | |
| POST | `/customers` | customers.manage | |
| GET | `/customers/{id}` | customers.view | |
| PATCH | `/customers/{id}` | customers.manage | |
| POST | `/customers/{id}/anonymize` | customers.manage | DSGVO-Löschung: entfernt personenbezogene Daten, Ledger bleibt vollständig |

### 7.7 Team, Rollen, Geräte

| Methode | Pfad | Berechtigung | Hinweis |
|---|---|---|---|
| GET | `/roles` | users.view | |
| GET | `/users` | users.view | |
| POST | `/users` | users.manage | `{name, email, role: owner\|manager\|waiter, password?}` – ohne Passwort wird eine Einladung versendet (Link 72 Stunden gültig) |
| GET | `/users/{id}` | users.view | |
| PATCH | `/users/{id}` | users.manage | |
| POST | `/users/{id}/deactivate` | users.manage | widerruft Tokens und Sitzungen |
| POST | `/users/{id}/activate` | users.manage | |
| POST | `/users/{id}/password-reset` | users.manage | sendet Passwort-Reset; bei Personen, die sich nie angemeldet haben, erneut die Einladung |
| GET | `/devices` | devices.view | |
| GET | `/devices/current` | angemeldet | aktuelles Gerät |
| PATCH | `/devices/{id}` | devices.manage | z. B. Umbenennen |
| POST | `/devices/{id}/revoke` | devices.manage | Gerät sofort sperren |
| POST | `/devices/{id}/restore` | devices.manage | Gerät wieder zulassen |

### 7.8 Einstellungen `[settings.manage]`

| Methode | Pfad | Inhalt |
|---|---|---|
| GET | `/settings` | Restaurant- und Karteneinstellungen |
| PUT | `/settings/restaurant` | Profil, Locale, Zeitzone |
| PUT | `/settings/cards` | Kartenregeln (siehe Tabelle `restaurant_settings`) |
| GET | `/settings/notification-templates` | Wirksame Vorlagen (Restaurant-Override oder Standard) |
| PUT | `/settings/notification-templates/{key}` | `{locale, subject, body, is_active}` – legt einen Restaurant-Override an. Schlüssel: `card_issued`, `card_reloaded`, `card_expiring`, `balance_low` |
| GET | `/api-tokens` | `[api_tokens.manage]` – Tokenliste |
| POST | `/api-tokens` | `[api_tokens.manage]` – liefert `plain_text_token` **einmalig** |
| POST | `/api-tokens/{id}/revoke` | `[api_tokens.manage]` |
| GET | `/audit-logs` | `[audit.view]` – Filter `action` (Präfix), `user_id`, `auditable_id`, `from`, `to` |

### 7.9 Öffentlich (ohne Anmeldung)

| Methode | Pfad | Inhalt |
|---|---|---|
| GET | `/public/cards/{token}` | Daten der Guthabenseite für Gäste (maskierte Kartennummer, Guthaben, Status, Ablauf, Restaurantname). Je Restaurant abschaltbar. 20/min je IP. |
| GET | `/app/config?platform=android\|ios&version=1.2.0` | Startkonfiguration der nativen Kellner-App → `{data: {min_version: {android, ios}, update_required, maintenance_notice, support_email, card_domains}}`. `update_required` ist `null`, wenn `platform`/`version` fehlen. Die Mindestversionen sind Systemeinstellungen (`app.min_version.*`). `Cache-Control: public, max-age=60`; Rate Limit `app-config`. |

### 7.10 Plattformadministration

| Methode | Pfad | Berechtigung | Inhalt |
|---|---|---|---|
| GET | `/admin/stats` | platform.restaurants.manage | Plattformkennzahlen |
| GET | `/admin/restaurants` | platform.restaurants.manage | |
| POST | `/admin/restaurants` | platform.restaurants.manage | `{name, …, owner:{name, email, password?}}` – legt Mandant und Einladung der Inhaberin bzw. des Inhabers an |
| GET | `/admin/restaurants/{id}` | platform.restaurants.manage | |
| PATCH | `/admin/restaurants/{id}` | platform.restaurants.manage | |
| POST | `/admin/restaurants/{id}/suspend` | platform.restaurants.manage | `{reason}` |
| POST | `/admin/restaurants/{id}/reactivate` | platform.restaurants.manage | |
| GET | `/admin/audit-logs` | platform.audit.view | Plattformweites Audit-Log |
| GET | `/admin/system-settings` | platform.settings.manage | |
| PUT | `/admin/system-settings` | platform.settings.manage | `{settings: [{key, value}]}` – z. B. `platform.maintenance_notice`, `platform.support_email`, `platform.default_plan` |

Für Restaurant-Endpunkte senden Plattform-Administratoren zusätzlich `X-Restaurant-Id`.

### 7.11 Systemendpunkte

| Methode | Pfad | Inhalt |
|---|---|---|
| GET | `/sanctum/csrf-cookie` | setzt `XSRF-TOKEN` (nur Browser) |
| GET | `/up` | Healthcheck: 200, wenn Datenbank und Cache erreichbar sind (außerhalb von `/api/v1`) |

## 8. Datenstrukturen

`dashboard/src/lib/api/types.ts` bildet jede Ressource Feld für Feld ab (`GiftCard`, `ScannedCard`, `Transaction`, `HistoryEntry`, `Customer`, `StaffUser`, `Device`, `Restaurant`, `AuditLog`, `ApiToken`, …). Diese Datei ist die maßgebliche Typreferenz.

## 9. Beispiele mit curl

Für die Beispiele:

```bash
export BASE=https://app.giftcardpro.at/api/v1
export TOKEN=gcp_…                      # API token from Settings → API
export DEVICE=pos-01-4f9c2a7e1b3d5a     # fixed ID per till (16–64 chars)
```

### 9.1 Karte per Kartennummer suchen

```bash
curl -X POST $BASE/scan \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" \
  -H "X-Device-Id: $DEVICE" \
  -d '{"method": "api", "card_number": "1223561625576350"}'
```

### 9.2 Einlösen

```bash
curl -X POST https://app.example.com/api/v1/cards/$CARD/redeem \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"amount": 1850, "reference": "Bill 4711"}'
```

Robuste Wiederholung bei Netzwerkfehlern – Schlüssel einmal erzeugen und wiederverwenden:

```bash
KEY=$(uuidgen)
for i in 1 2 3; do
  curl -fsS -X POST $BASE/cards/$CARD/redeem \
    -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" \
    -H "X-Device-Id: $DEVICE" -H "Idempotency-Key: $KEY" \
    -d '{"amount": 1850, "reference": "Bill 4711"}' && break
  sleep 2
done
```

### 9.3 Aufladen

```bash
curl -X POST $BASE/cards/$CARD/reload \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" \
  -H "X-Device-Id: $DEVICE" -H "Idempotency-Key: $(uuidgen)" \
  -d '{"amount": 2500, "reference": "Bill 4712"}'
```

### 9.4 Buchung stornieren

```bash
curl -X POST $BASE/transactions/$TRANSACTION/reverse \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" \
  -d '{"reason": "Wrong amount"}'
```

### 9.5 Buchungen eines Zeitraums als CSV exportieren

```bash
curl -G $BASE/transactions/export \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode "from=2026-10-01" --data-urlencode "to=2026-10-31" \
  -o transactions-2026-10.csv
```

### 9.6 Browser-Login (zu Testzwecken)

```bash
curl -c jar.txt -b jar.txt https://app.giftcardpro.at/sanctum/csrf-cookie
XSRF=$(grep XSRF-TOKEN jar.txt | awk '{print $7}' | python3 -c 'import sys,urllib.parse;print(urllib.parse.unquote(sys.stdin.read().strip()))')
curl -c jar.txt -b jar.txt -X POST https://app.giftcardpro.at/api/v1/auth/login \
  -H "Accept: application/json" -H "Content-Type: application/json" \
  -H "Referer: https://app.giftcardpro.at" -H "X-XSRF-TOKEN: $XSRF" \
  -d '{"email":"owner@example.at","password":"…","remember":false}'
```

## 10. Hinweise für Integrationen

- **Kein Ersatz für die Registrierkasse.** GiftCard Pro stellt keine Belege aus. Verkauf und Einlösung werden zusätzlich in der Registrierkasse des Restaurants gebucht (keine Rechtsberatung – mit Steuerberatung prüfen).
- Beträge immer in Cent übertragen; keine Gleitkommazahlen.
- `reference` für die Belegnummer der Kassa nutzen – das erleichtert den Abgleich.
- Auf `code` reagieren; bei `429` `Retry-After` beachten; bei Netzwerkfehlern mit demselben `Idempotency-Key` wiederholen.
- `X-Request-Id` mitsenden und im eigenen System protokollieren – das beschleunigt die Fehlersuche im Support.
- Sicherheitsmeldungen an `security@giftcardpro.at`.

---

Version 1.0 · Stand: September 2026
