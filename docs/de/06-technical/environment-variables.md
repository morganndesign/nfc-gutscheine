# Umgebungsvariablen

*Alle Konfigurationsvariablen von GiftCard Pro – API, Web-App, Kellner-App und Coolify-Stack – mit Standardwert, Beispiel, Beschreibung und Empfehlung für den Produktivbetrieb. Englische Referenz: [docs/ENVIRONMENT.md](../../ENVIRONMENT.md).*

---

## 1. Umgebungen – eine Strategie für jede Komponente

Jede Komponente bezieht ihre Adressen aus **einer Quelle je Umgebung**; keine Serveradresse steht im Code. Der Code enthält nur lokale Entwicklungsstandards (`localhost`), und jede Komponente verweigert in Staging oder Produktion den Start mit einem solchen Standard.

| | Entwicklung (eigener Rechner) | Staging | Produktion |
|---|---|---|---|
| **Backend** (`backend/`) | `backend/.env` aus `.env.example` · `APP_ENV=local` | Coolify-Ressource *Environment Variables* (`APP_ENV=staging`, eigene Domain) – Referenz: `.env.production.example` | Coolify-Ressource *Environment Variables* – Referenz: `.env.production.example` |
| **Server-Stack** | `docker-compose.dev.yml` (MySQL, Redis, Mailpit; keine Variablen) | `docker-compose.coolify.yml` (dieselbe Datei) | `docker-compose.coolify.yml` |
| **Web-App** (`dashboard/`) | `dashboard/.env.local` aus `.env.example` (`BACKEND_INTERNAL_URL`) | nichts – gleicher Origin, das Gateway leitet `/api` weiter | nichts – gleicher Origin, das Gateway leitet `/api` weiter |
| **Kellner-App** (`waiter-app/`) | `config/development.json` (+ eigene `development.local.json`) · `APP_ENV=development` | `config/staging.json` · `APP_ENV=staging` | `config/production.json` · `APP_ENV=production` |

Backend und Web-App lesen ihre Einstellungen **zur Laufzeit**; die Kellner-App liest ihre Datei **beim Build** (ein Telefon hat keine serverseitigen Dateien), daher gehört ein App-Build genau zu einer Umgebung.

| Risiko | Schutz |
|---|---|
| Produktions-App spricht mit einem Entwicklungs- oder Staging-Server | Builds mit `APP_ENV=production` akzeptieren nur https und können ihren Server in der App nicht ändern (eine gespeicherte Abweichung wird ignoriert); `tool/release.sh` verweigert eine Konfigurationsdatei, deren `APP_ENV` nicht zur angeforderten Umgebung passt. |
| Entwicklungs-App spricht versehentlich mit Produktion | `config/development.json` zeigt auf den eigenen Rechner. Ein Build ohne Konfigurationsdatei hält bei „App not set up correctly“ an (keine Standardadresse). |
| Eine Anmeldung eines Servers wird an einen anderen gesendet | Die App merkt sich, zu welchem Server eine Anmeldung gehört, und verwirft sie, wenn sich der Server unterscheidet (relevant am iPhone, wo alle Umgebungen dieselbe Bundle-ID teilen). |
| Staging-/Produktions-API erzeugt `localhost`-Links | Die API startet nicht, wenn `APP_ENV` `staging`/`production` ist und `APP_URL` oder `FRONTEND_URL` fehlt, nicht https ist, ein Platzhalter, `localhost`/`127.0.0.1`/`10.0.2.2` oder `*.test`/`*.local` ist (`App\Support\EnvironmentGuard`). |
| Produktions-Web-App leitet `/api` an einen Entwicklungsrechner weiter | `BACKEND_INTERNAL_URL` hat keinen Standard; es wird nur in der Entwicklung gesetzt (`next dev` bricht mit einer Meldung ab, wenn es fehlt). |

Innerhalb einer Umgebung abgestimmt halten: `API_BASE_URL` der App = `APP_URL` + `/api/v1`.

## 2. API (`backend/.env`)

**Spalten:** **Lokal** – Wert in `backend/.env.example`; **Produktion** – Wert im Coolify-Stack bzw. Empfehlung; „—“ bedeutet: nicht gesetzt, es gilt der Standard aus `backend/config/*.php`.

Änderungen werden erst nach einem *Redeploy* wirksam, weil die Container die Konfiguration beim Start cachen.

### 2.1 Anwendung

| Variable | Lokal | Produktion | Beschreibung und Empfehlung |
|---|---|---|---|
| `APP_NAME` | `"GiftCard Pro"` | `"GiftCard Pro"` | Name in E-Mails. |
| `APP_ENV` | `local` | `production` | `local`, `testing`, `staging`, `production`. Demodaten werden in `local`, `testing` und `staging` angelegt. |
| `APP_KEY` | leer → `php artisan key:generate` | `base64:…` | Schlüssel für Cookies, Sessions und verschlüsselte Werte (`php artisan key:generate --show`). Eine Änderung meldet alle ab und macht verschlüsselte Werte unlesbar. Im Passwortmanager sichern. |
| `APP_DEBUG` | `true` | `false` | Außerhalb der Entwicklung **zwingend** `false`. |
| `APP_URL` | `http://localhost:8000` | `https://app.giftcardpro.at` | Öffentlicher Origin der API (derselbe wie die Web-App). |
| `FRONTEND_URL` | `http://localhost:3000` | `https://app.giftcardpro.at` | Basis der Einladungs- und Passwort-Reset-Links. |
| `BCRYPT_ROUNDS` | `12` | — (`12`) | Kostenfaktor für Passwort-Hashes. |
| `APP_TIMEZONE` | `UTC` | — | `UTC` beibehalten: Zeitstempel werden in UTC gespeichert und je Lokal umgerechnet. |
| `SCHEDULE_TIMEZONE` | `Europe/Vienna` | `Europe/Vienna` | Lokale Uhr der nächtlichen Jobs: Ablauf 00:15, Integritätsprüfung 02:30, Bereinigung 03:30, Ablauferinnerungen 10:00. |
| `APP_LOCALE` | `en` | `en` | Sprache der Anwendung. |
| `APP_FALLBACK_LOCALE` | `en` | — (`en`) | Ersatzsprache. |
| `APP_FAKER_LOCALE` | `de_AT` | — | Nur für Demodaten und Tests. |
| `APP_MAINTENANCE_DRIVER` | `cache` | — (`file`) | Speicherort des Wartungsmodus (`php artisan down`). |

### 2.2 Logging

| Variable | Lokal | Produktion | Beschreibung und Empfehlung |
|---|---|---|---|
| `LOG_CHANNEL` | `stack` | `stderr` | In Containern `stderr` (im Compose-Stack fest gesetzt). |
| `LOG_STACK` | `daily` | — | Kanäle des `stack`-Kanals; `daily` schreibt `storage/logs/laravel-YYYY-MM-DD.log`. |
| `LOG_LEVEL` | `debug` | `info` | `info` in Produktion (gesperrte Konten werden als `warning` protokolliert, eine fehlgeschlagene Integritätsprüfung als `critical`). Lokal `debug`: Der `log`-Mailer schreibt E-Mails auf Debug-Ebene. |

Siehe [Logging-Leitfaden](logging-guide.md).

### 2.3 Datenbank, Cache, Queues

| Variable | Lokal | Produktion | Beschreibung und Empfehlung |
|---|---|---|---|
| `DB_CONNECTION` | `mysql` | `mysql` | `mysql` (Produktion), `sqlite` (Entwicklung, Tests). Die Append-only-Trigger gibt es für MySQL/MariaDB und SQLite. |
| `DB_HOST` / `DB_PORT` | `127.0.0.1` / `3306` | `mysql` / `3306` | Im Stack der Dienstname `mysql`. |
| `DB_DATABASE` / `DB_USERNAME` | `giftcard_pro` / `giftcard` | `giftcard_pro` / `giftcard` | In Coolify nur vor dem ersten Deploy änderbar. |
| `DB_PASSWORD` | leer (Dev-Compose: `secret`) | aus `SERVICE_PASSWORD_MYSQL` | Coolify erzeugt das Passwort. |
| `REDIS_HOST` / `REDIS_PORT` / `REDIS_PASSWORD` / `REDIS_CLIENT` | `127.0.0.1` / `6379` / `null` / `phpredis` | `redis` / `6379` / aus `SERVICE_PASSWORD_REDIS` / `phpredis` | Redis für Cache, Sessions, Queues und Rate Limits. |
| `CACHE_STORE` | `redis` | `redis` | Trägt auch Rate Limiting und die Sperre für fehlgeschlagene Vorlagen. |
| `CACHE_PREFIX` | `giftcardpro` | — | Präfix der Cache-Schlüssel. |
| `QUEUE_CONNECTION` | `redis` | `redis` | Jede E-Mail wird aus der Queue versendet (`default`, `notifications`). |
| `QUEUE_FAILED_DRIVER` | `database-uuids` | `database-uuids` | Fehlgeschlagene Jobs mit UUID-Schlüssel. |

### 2.4 Sessions und Authentifizierung

| Variable | Lokal | Produktion | Beschreibung und Empfehlung |
|---|---|---|---|
| `SESSION_DRIVER` | `redis` | `redis` | |
| `SESSION_LIFETIME` | `480` | `480` | Minuten Inaktivität bis zur Abmeldung (eine volle Serviceschicht). |
| `SESSION_ENCRYPT` | `true` | `true` | Session-Inhalte verschlüsselt speichern. |
| `SESSION_SECURE_COOKIE` | `false` | `true` | Cookie nur über HTTPS. Auf Servern zwingend `true`. |
| `SESSION_SAME_SITE` | `lax` | `lax` | |
| `SESSION_DOMAIN` | `null` | `app.giftcardpro.at` | Host der Web-App. |
| `SESSION_COOKIE` | `giftcardpro_session` | — | Name des Session-Cookies. |
| `SANCTUM_STATEFUL_DOMAINS` | `localhost:3000,127.0.0.1:3000` | `app.giftcardpro.at` | Hosts, deren Browser-Requests Cookie-Sessions nutzen (kommagetrennt, in der Entwicklung mit Port). |
| `SANCTUM_TOKEN_PREFIX` | `gcp_` | `gcp_` | Präfix der Tokens – ermöglicht Secret Scanning. |

### 2.5 Sicherheit

| Variable | Standard | Beschreibung und Empfehlung |
|---|---|---|
| `PRESENTMENT_FAILURE_LIMIT` | `10` | Fehlgeschlagene Gutschein-Scans je Lokal, Person und Gerät vor einer kurzen Sperre (`429 PRESENTMENT_THROTTLED`). |
| `PRESENTMENT_FAILURE_DECAY` | `300` | Zeitfenster in Sekunden für den obigen Wert. |
| `LOGIN_LOCKOUT_THRESHOLD` | `10` | Aufeinanderfolgende falsche Passwörter bis zur Kontosperre. |
| `LOGIN_LOCKOUT_MINUTES` | `15` | Dauer der Sperre. |
| `API_TOKEN_MAX_DAYS` | `365` | Maximale Laufzeit von Integrations-Tokens. |
| `DEVICE_TOKEN_DAYS` | `30` | Anmeldedauer der Kellner-App; wird verlängert, solange das Telefon genutzt wird. |

Fest in `config/giftcard.php`: Gültigkeit einer Vorlage 60 s, Wiederholungsfenster für Verkäufe 15 min, Länge des Idempotency-Keys ≤ 96. Empfehlung: Standardwerte beibehalten.

### 2.6 Gutscheingrenzen (Plattformobergrenzen)

| Variable | Standard | Beschreibung |
|---|---|---|
| `LIMIT_MAX_VOUCHER_BALANCE` | `50000` | Höchster `max_voucher_balance`, den ein Lokal einstellen darf (Cent). |
| `LIMIT_MAX_DEBIT_PER_TRANSACTION` | `25000` | Höchster `max_debit_per_transaction`. |
| `LIMIT_MAX_DEBIT_PER_VOUCHER_PER_DAY` | `50000` | Höchster `max_debit_per_voucher_per_day`. |

Die Gültigkeit eines Lokals beträgt mindestens 36 Monate (`min_validity_months`, fest).

### 2.7 E-Mail und Benachrichtigungen

| Variable | Standard | Beschreibung |
|---|---|---|
| `MAIL_MAILER` | `failover` (Entwicklung), `log` (Coolify-Standard) | `smtp` für echte Zustellung. Mit `log` werden E-Mails nur ins Log geschrieben und die Plattformadministration zeigt ein rotes Banner. |
| `MAIL_HOST`, `MAIL_PORT`, `MAIL_SCHEME`, `MAIL_USERNAME`, `MAIL_PASSWORD` | | SMTP-Server (`MAIL_SCHEME`: `smtp` = STARTTLS auf 587, `smtps` = TLS auf 465). Zugangsdaten als Secret behandeln. |
| `MAIL_FROM_ADDRESS`, `MAIL_FROM_NAME` | `no-reply@<domain>`, `GiftCard Pro` | Absender. Für die Absenderdomain SPF, DKIM und DMARC einrichten. |
| `MAIL_TIMEOUT` | `10` | Sekunden, bis ein langsamer Mailserver aufgegeben wird (der Job wird wiederholt). |
| `MAIL_LOCALE` | `de` | Sprache der Einladungs-E-Mails, wenn es für die Sprache des Lokals keine Übersetzung gibt. |
| `MAIL_VERIFY_DOMAINS` | `true` | *Send test e-mail* lehnt eine Empfängerdomain ohne Mailserver ab. |
| `VOUCHER_EXPIRING_NOTICE_DAYS` | `30` | Ablauferinnerung so viele Tage vor dem letzten Gültigkeitstag. |
| `OPS_ALERT_EMAIL` | *(Support-Adresse)* | Betriebswarnungen: eine Queue mit mehr als 500 wartenden Jobs, eine fehlgeschlagene Integritätsprüfung. |

### 2.8 Nur Entwicklung

| Variable | Beschreibung |
|---|---|
| `NTAG424_META_READ_KEY`, `NTAG424_FILE_READ_KEY`, `NTAG424_DIVERSIFY_KEYS` | Lokale Testschlüssel (je 32 Hex-Zeichen) für die SUN-Prüfbibliothek (`app/Services/Nfc`, gelesen über `config/giftcard.php → nfc.ntag424`). Kein Endpunkt verwendet die Bibliothek, und ihre Unit-Tests bringen eigene Schlüssel mit. Sie gehören nicht zur Produktionskonfiguration; Kartenschlüssel liegen im Krypto-Dienst ([docs/NFC.md](../../NFC.md)). |
| `SEED_DEMO_DATA` | `true` legt die Demo-Lokale auch außerhalb von `local`/`testing`/`staging` an. Der Coolify-Stack setzt es fest auf `false`. |

## 3. Web-App (`dashboard/.env.local`)

| Variable | Lokal | Beschreibung |
|---|---|---|
| `BACKEND_INTERNAL_URL` | `http://localhost:8000` | Nur Entwicklung: Ziel, an das `next dev` die Pfade `/api` und `/sanctum` weiterleitet. Auf Servern leitet das Gateway (Caddy, `infra/docker/gateway`) diese Pfade an Laravel, bevor sie Next.js erreichen. |

Die Web-App hat **keine Secrets** – sie spricht nur mit ihrem eigenen Origin.

## 4. Kellner-App (`waiter-app/config/<umgebung>.json`)

| Schlüssel | Beschreibung |
|---|---|
| `APP_ENV` | `development`, `staging`, `production`. http ist nur in der Entwicklung erlaubt; Entwicklung und Staging haben eine eigene Android-Application-ID und ein Eckabzeichen. |
| `API_BASE_URL` | API-Wurzel, endet auf `/api/v1`. |
| `APP_STORE_URL` | App-Store-Eintrag, den „Update required“ öffnet (iOS-Produktion). |
| `PLAY_STORE_URL` | Optional; Standard ist der Play-Eintrag des Pakets. |

## 5. Produktion und Staging (Coolify)

Der Server-Stack ist `docker-compose.coolify.yml`; seine Variablen werden in Coolify gesetzt (Ressource → *Environment Variables*). **Jede Variable hat einen funktionierenden Standard** – die kommentierte Liste ist [`.env.production.example`](../../../.env.production.example). Die oben genannten Laravel-Variablen, die dort nicht stehen, sind in der Compose-Datei fest gesetzt (Redis-Sessions, sichere Cookies, `LOG_CHANNEL=stderr`, `SEED_DEMO_DATA=false`) oder behalten ihren Standard aus `config/giftcard.php`.

| Gesetzt von | Variablen |
|---|---|
| Coolify, automatisch | `SERVICE_URL_GATEWAY` / `SERVICE_FQDN_GATEWAY` (Domain des Dienstes `gateway` → `APP_URL`, `FRONTEND_URL`, `SESSION_DOMAIN`, `SANCTUM_STATEFUL_DOMAINS`, Standard für `MAIL_FROM_ADDRESS`, abgeleitet in `infra/docker/php/entrypoint.sh`), `SERVICE_PASSWORD_MYSQL`, `SERVICE_PASSWORD_MYSQLROOT`, `SERVICE_PASSWORD_REDIS` |
| Der erste Deploy, automatisch | `APP_KEY` (im Volume `laravel-storage` aufbewahrt, sofern Sie `APP_KEY` nicht selbst setzen) |
| Sie (für den echten Betrieb nötig) | `MAIL_MAILER=smtp` und die `MAIL_*`-Werte |
| Sie (optional) | `APP_ENV` (`staging`), `APP_URL`, `APP_LOCALE`, `OPS_ALERT_EMAIL`, `MAIL_LOCALE`, `MAIL_TIMEOUT`, `SCHEDULE_TIMEZONE`, `LOG_LEVEL`, `BACKUP_TIME`, `BACKUP_KEEP_DAYS`, `DB_DATABASE`/`DB_USERNAME` (nur vor dem ersten Deploy) |

Der Dienst `web` braucht keine Variablen. Kartenschlüssel stehen nie in Umgebungsvariablen.

## 6. Checkliste Produktion

- [ ] Gateway-Domain mit `https://` gesetzt (daraus folgen `APP_URL`, `FRONTEND_URL`, `SESSION_DOMAIN`, `SANCTUM_STATEFUL_DOMAINS`)
- [ ] `SERVICE_PASSWORD_MYSQL`, `SERVICE_PASSWORD_MYSQLROOT`, `SERVICE_PASSWORD_REDIS` von Coolify erzeugt
- [ ] `APP_KEY` gesichert (Passwortmanager) und idealerweise als Variable gesetzt
- [ ] `MAIL_MAILER=smtp` und `MAIL_*` mit echtem Versanddienstleister; SPF/DKIM/DMARC eingerichtet; Test-E-Mail erfolgreich
- [ ] `OPS_ALERT_EMAIL` erreicht jemanden, der auf Betriebswarnungen reagiert
- [ ] Kellner-App mit `config/production.json` gebaut; `API_BASE_URL` = `APP_URL` + `/api/v1`

---

Version 2.0 · Stand: September 2026
