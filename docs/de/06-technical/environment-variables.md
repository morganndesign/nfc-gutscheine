# Umgebungsvariablen

*Alle Konfigurationsvariablen von GiftCard Pro – API, Web-App, Docker Compose, Container und Abnahmetest – mit Standardwert, Beispiel, Beschreibung und Empfehlung für den Produktivbetrieb.*

---

## 1. Konfigurationsdateien

| Datei | Verwendung | Vorlage |
|---|---|---|
| `backend/.env` | API lokal | `backend/.env.example` |
| `backend/.env.production` | API in Produktion (Container `api`, `queue`, `scheduler`, `backup`) | `backend/.env.production.example` |
| `.env.production` (neben `docker-compose.yml`) | Compose-Ebene in Produktion | `.env.production.example` |
| `dashboard/.env.local` | Web-App lokal | `dashboard/.env.example` |

**Legende der Spalten:**

- **Lokal** – Wert in `backend/.env.example`
- **Produktion** – Wert in `backend/.env.production.example` bzw. Empfehlung
- „—" bedeutet: nicht gesetzt, es gilt der Standard aus `backend/config/*.php`

Änderungen an `backend/.env.production` werden erst nach einem Neustart der Container wirksam, weil der Einstiegspunkt die Konfiguration bei jedem Start cacht (`config:cache`):

```bash
docker compose --env-file .env.production up -d --force-recreate api queue scheduler
```

## 2. API (`backend/.env`)

### 2.1 Anwendung

| Variable | Lokal | Produktion | Beschreibung und Empfehlung |
|---|---|---|---|
| `APP_NAME` | `"GiftCard Pro"` | `"GiftCard Pro"` | Name in E-Mails und als Standard für Cookie- und Cache-Präfixe. |
| `APP_ENV` | `local` | `production` | `local`, `testing`, `staging`, `production`. In `local`/`staging` werden Demodaten automatisch angelegt. |
| `APP_KEY` | leer → `php artisan key:generate` | `base64:…` | Schlüssel für Cookies, Sessions und verschlüsselte Werte. Erzeugen mit `php artisan key:generate --show`. **Nicht ohne Plan wechseln** – alle Sessions werden ungültig. Im Passwortmanager sichern. |
| `APP_DEBUG` | `true` | `false` | In Produktion **zwingend** `false` (Stacktraces verraten Secrets). |
| `APP_URL` | `http://localhost:8000` | `https://app.giftcardpro.at` | Öffentlicher Origin der API; bei der Standardinstallation identisch mit der Web-App. |
| `APP_TIMEZONE` | `UTC` | — | Dokumentarisch: `config/app.php` setzt die Zeitzone fest auf `UTC`. Alle Zeitstempel werden in UTC gespeichert und je Restaurant umgerechnet. |
| `SCHEDULE_TIMEZONE` | `Europe/Vienna` | `Europe/Vienna` | Lokale Uhr der nächtlichen Jobs: Kartenablauf 00:15, Erinnerungen 10:00, Bereinigung 03:30. |
| `APP_LOCALE` | `en` | `en` | Sprache der Anwendung (Oberfläche für Mitarbeitende derzeit Englisch). |
| `APP_FALLBACK_LOCALE` | `en` | — (`en`) | Ersatzsprache. |
| `APP_FAKER_LOCALE` | `de_AT` | `de_AT` | Nur für Demodaten und Tests. |
| `APP_MAINTENANCE_DRIVER` | `cache` | — (`file`) | Speicherort des Wartungsmodus (`php artisan down`). Mit `file` gilt der Wartungsmodus nur für den Container, in dem der Befehl lief (in der Praxis `api`). |
| `FRONTEND_URL` | `http://localhost:3000` | `https://app.giftcardpro.at` | Basis für Links in E-Mails (Passwort-Reset, Einladungen). |
| `CARD_BASE_URL` | `http://localhost:3000` | `https://app.giftcardpro.at` | Basis der URL auf NFC-Tags und QR-Codes: `{CARD_BASE_URL}/c/{token}`. Fällt auf `FRONTEND_URL` zurück. **Eine Änderung nach dem Beschreiben von Karten macht diese unbrauchbar** – eine dauerhafte Domain wählen. |
| `BCRYPT_ROUNDS` | `12` | — (`12`) | Kostenfaktor für Passwort-Hashes. 12 beibehalten. |

### 2.2 Logging

| Variable | Lokal | Produktion | Beschreibung und Empfehlung |
|---|---|---|---|
| `LOG_CHANNEL` | `stack` | `stderr` | In Containern `stderr` – Docker sammelt die Ausgabe. |
| `LOG_STACK` | `daily` | — | Kanäle des `stack`-Kanals; `daily` schreibt `storage/logs/laravel-YYYY-MM-DD.log`. |
| `LOG_LEVEL` | `debug` | `info` | `info` in Produktion. Sicherheitswarnungen (gesperrte Konten, verdächtige Scans) sind `warning`. Lokal `debug`: Der `log`-Mailer schreibt Einladungen und Reset-Links auf Debug-Ebene (nötig für den E2E-Test). |

Laravel-Standardvariablen aus `config/logging.php`, die nicht in den Vorlagen stehen, aber gesetzt werden können: `LOG_DAILY_DAYS` (Aufbewahrung für `daily`, Standard 14) und `LOG_STDERR_FORMATTER` (z. B. `Monolog\Formatter\JsonFormatter` für JSON-Ausgabe auf `stderr`). Siehe [Logging-Leitfaden](logging-guide.md).

### 2.3 Datenbank

| Variable | Lokal | Produktion | Beschreibung und Empfehlung |
|---|---|---|---|
| `DB_CONNECTION` | `mysql` | `mysql` | `mysql` (Produktion), `mariadb`, `sqlite` (Entwicklung/Tests). |
| `DB_HOST` | `127.0.0.1` | `mysql` | In Compose der Dienstname `mysql`. |
| `DB_PORT` | `3306` | `3306` | |
| `DB_DATABASE` | `giftcard_pro` | `giftcard_pro` | Muss mit `DB_DATABASE` in `.env.production` (Compose) übereinstimmen. |
| `DB_USERNAME` | `giftcard` | `giftcard` | Wie oben. |
| `DB_PASSWORD` | leer (Dev-Compose: `secret`) | `change-me-long-random` | Zufällig erzeugen (`openssl rand -base64 36`); identisch mit Compose-Datei. |

### 2.4 Redis, Cache, Queues

| Variable | Lokal | Produktion | Beschreibung und Empfehlung |
|---|---|---|---|
| `REDIS_CLIENT` | `phpredis` | `phpredis` | PHP-Erweiterung `redis`. |
| `REDIS_HOST` | `127.0.0.1` | `redis` | Dienstname in Compose. |
| `REDIS_PASSWORD` | `null` | `change-me-long-random` | Muss `REDIS_PASSWORD` der Compose-Datei entsprechen (`requirepass`). |
| `REDIS_PORT` | `6379` | `6379` | |
| `CACHE_STORE` | `redis` | `redis` | Trägt auch Rate Limiting, Sperren und den Berechtigungs-Cache. |
| `CACHE_PREFIX` | `giftcardpro` | `giftcardpro` | Präfix der Cache-Schlüssel. |
| `QUEUE_CONNECTION` | `redis` | `redis` | E-Mails laufen auf der Queue `notifications`. |
| `QUEUE_FAILED_DRIVER` | `database-uuids` | `database-uuids` | Fehlgeschlagene Jobs mit UUID-Schlüssel in `failed_jobs`. |
| `BROADCAST_CONNECTION` | `log` | — | Wird nicht genutzt. |
| `FILESYSTEM_DISK` | `local` | — (`local`) | Die Anwendung speichert keine Uploads. |

### 2.5 Sessions und Authentifizierung

| Variable | Lokal | Produktion | Beschreibung und Empfehlung |
|---|---|---|---|
| `SESSION_DRIVER` | `redis` | `redis` | |
| `SESSION_LIFETIME` | `480` | `480` | Minuten Inaktivität bis zur Abmeldung (eine Serviceschicht). Ohne Angabe gilt Laravels Standard 120. |
| `SESSION_ENCRYPT` | `true` | `true` | Session-Inhalte verschlüsselt speichern. |
| `SESSION_PATH` | `/` | — (`/`) | |
| `SESSION_DOMAIN` | `null` | `app.giftcardpro.at` | Host der Web-App. |
| `SESSION_SECURE_COOKIE` | `false` | `true` | Cookie nur über HTTPS. In Produktion zwingend `true`. |
| `SESSION_SAME_SITE` | `lax` | `lax` | Zusätzlicher CSRF-Schutz. |
| `SESSION_COOKIE` | `giftcardpro_session` | `giftcardpro_session` | Name des Session-Cookies (in der Datenschutzerklärung genannt – nicht ändern). |
| `SANCTUM_STATEFUL_DOMAINS` | `localhost:3000,127.0.0.1:3000` | `app.giftcardpro.at` | Hosts, deren Browser-Requests Cookie-Sessions nutzen (kommagetrennt, in der Entwicklung mit Port). |
| `SANCTUM_TOKEN_PREFIX` | `gcp_` | `gcp_` | Präfix der API-Tokens – ermöglicht Secret Scanning. |

### 2.6 E-Mail

| Variable | Lokal | Produktion | Beschreibung und Empfehlung |
|---|---|---|---|
| `MAIL_MAILER` | `smtp` | `smtp` | Für den E2E-Test lokal `log`. |
| `MAIL_HOST` | `127.0.0.1` (Mailpit) | `smtp.postmarkapp.com` | SMTP-Server des Versanddienstleisters. |
| `MAIL_PORT` | `1025` | `587` | |
| `MAIL_USERNAME` | `null` | leer | Zugangsdaten des Versanddienstleisters. |
| `MAIL_PASSWORD` | `null` | leer | Wie oben; als Secret behandeln. |
| `MAIL_FROM_ADDRESS` | `"no-reply@giftcardpro.app"` | `"no-reply@giftcardpro.at"` | Absender. Für die Absenderdomain SPF, DKIM und DMARC einrichten. |
| `MAIL_FROM_NAME` | `"${APP_NAME}"` | `"${APP_NAME}"` | |

### 2.7 Sicherheit

| Variable | Standard | Beschreibung und Empfehlung |
|---|---|---|
| `SCAN_FAILURE_LIMIT` | `10` | Fehlgeschlagene oder verdächtige Kartenabfragen je Benutzer **und** je IP, bevor Abfragen blockiert werden. |
| `SCAN_FAILURE_DECAY` | `300` | Zeitfenster in Sekunden für den obigen Wert. |
| `LOGIN_LOCKOUT_THRESHOLD` | `10` | Aufeinanderfolgende falsche Passwörter bis zur Kontosperre. |
| `LOGIN_LOCKOUT_MINUTES` | `15` | Dauer der Sperre. |
| `API_TOKEN_MAX_DAYS` | `365` | Maximale Laufzeit von Integrations-Tokens. Leer = 365. |
| `DEVICE_TOKEN_DAYS` | `30` | Anmeldedauer der nativen Kellner-App (GiftCard Waiter). Wird verlängert, solange das Telefon genutzt wird; nur ein so lange unbenutztes Telefon muss sich neu anmelden. |

Diese Werte stehen in `.env.example`, nicht in `.env.production.example`; in Produktion gelten ohne Eintrag dieselben Standardwerte. Empfehlung: Standardwerte beibehalten.

### 2.8 NFC (nur NTAG 424 DNA)

| Variable | Standard | Beschreibung und Empfehlung |
|---|---|---|
| `NTAG424_META_READ_KEY` | leer | AES-128-Schlüssel (32 Hex-Zeichen), entschlüsselt die PICC-Daten (UID + Tap-Zähler). |
| `NTAG424_FILE_READ_KEY` | leer | AES-128-Master-Schlüssel für den SUN-CMAC. |
| `NTAG424_DIVERSIFY_KEYS` | `true` | `true`: MAC-Schlüssel je Chip = HMAC-SHA256(Master, UID)[0..16]. Empfohlen. |

Erzeugen mit `php artisan giftcard:nfc-keys`. In Produktion eindeutige, geheime Werte setzen, sobald NTAG-424-DNA-Karten ausgegeben werden, und im Passwortmanager sichern. Nach dem Programmieren von Karten nicht mehr ändern.

### 2.9 Benachrichtigungen

| Variable | Standard | Beschreibung |
|---|---|---|
| `CARD_EXPIRING_NOTICE_DAYS` | `30` | Erinnerungs-E-Mail so viele Tage vor Ablauf. |
| `CARD_LOW_BALANCE_THRESHOLD` | `500` | Cent. E-Mail „Guthaben niedrig", wenn eine Einlösung diese Grenze unterschreitet (€ 5). |
| `OPS_ALERT_EMAIL` | *(Support-Adresse)* | Empfängt Betriebswarnungen, z. B. eine Queue mit mehr als 500 wartenden Jobs (höchstens eine E-Mail je Queue alle 30 Minuten). Leer: die Support-Adresse aus den Systemeinstellungen. |

### 2.10 Sonstiges

| Variable | Standard | Beschreibung und Empfehlung |
|---|---|---|
| `SEED_DEMO_DATA` | `false` | `true` legt das Demo-Restaurant auch außerhalb von `local`/`staging` an. **In Produktion nie.** |

## 3. Container-Variablen (in `docker-compose.yml` gesetzt)

| Variable | Werte | Beschreibung |
|---|---|---|
| `CONTAINER_ROLE` | `app`, `worker`, `scheduler` | Rolle des API-Images: PHP-FPM, Queue-Worker oder Scheduler. |
| `RUN_MIGRATIONS` | `true` | Nur Rolle `app`: `migrate --force --isolated` und Referenz-Seeder beim Start. |

Diese Werte werden nicht in `.env`-Dateien gepflegt.

## 4. Web-App (`dashboard/.env.local`)

| Variable | Lokal | Beschreibung |
|---|---|---|
| `BACKEND_INTERNAL_URL` | `http://localhost:8000` | Nur Entwicklung: Ziel, an das `next dev` die Pfade `/api` und `/sanctum` weiterleitet. In Produktion leitet Caddy diese Pfade an Laravel, bevor sie Next.js erreichen. |

Die Web-App hat **keine Secrets** – sie spricht nur mit ihrem eigenen Origin.

## 5. Compose (`.env.production` neben `docker-compose.yml`)

| Variable | Beispiel | Beschreibung und Empfehlung |
|---|---|---|
| `APP_DOMAIN` | `app.giftcardpro.at` | Öffentlicher Hostname; Caddy holt dafür das TLS-Zertifikat. Pflicht. |
| `ACME_EMAIL` | `ops@giftcardpro.at` | E-Mail für das Let's-Encrypt-Konto (Ablaufwarnungen). Pflicht. |
| `REGISTRY` | `ghcr.io/your-org` | Container-Registry. Standard `ghcr.io/your-org`. |
| `IMAGE_TAG` | `latest` | Zu startender Image-Tag. Die Deploy-Pipeline setzt den Commit-SHA; Umgebungsvariablen der Shell haben Vorrang vor der Datei. |
| `DB_DATABASE` | `giftcard_pro` | Datenbank, die der MySQL-Container beim ersten Start anlegt. |
| `DB_USERNAME` | `giftcard` | Anwendungsbenutzer. |
| `DB_PASSWORD` | `change-me-long-random` | Pflicht. Identisch mit `backend/.env.production`. |
| `DB_ROOT_PASSWORD` | `change-me-long-random` | Pflicht. Root-Passwort von MySQL; nur für Administration und Restore. |
| `REDIS_PASSWORD` | `change-me-long-random` | Pflicht. Identisch mit `backend/.env.production`. |
| `WAITER_IOS_APP_IDS` | `TEAMID.eu.tapredeem.waiter` | App-IDs der nativen Kellner-App für iPhone Universal Links, Format `TEAMID.bundle.id` (kommagetrennt). Wird als `/.well-known/apple-app-site-association` ausgeliefert. Leer = 404. |
| `WAITER_ANDROID_PACKAGE` | `eu.tapredeem.waiter` | Paketname der Android-Kellner-App für App Links (`/.well-known/assetlinks.json`). |
| `WAITER_ANDROID_CERT_SHA256` | `AB:CD:…` | SHA-256-Fingerprints der Signaturzertifikate (Play App Signing, für interne Builds zusätzlich der Upload-Schlüssel), kommagetrennt. |

`DB_*`-Werte wirken beim MySQL-Container nur beim **ersten** Start mit leerem Volume `mysql_data`. Spätere Passwortänderungen müssen zusätzlich in MySQL selbst erfolgen (`ALTER USER`).

## 6. Abnahmetest (`e2e/`)

| Variable | Standard | Beschreibung |
|---|---|---|
| `BASE_URL` | `http://localhost:3000` | Adresse der Web-App |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | Demo-Administrator | Zugang des Plattform-Administrators |
| `LARAVEL_LOG_DIR` | `../backend/storage/logs/` | Einladungslinks werden aus dem Log-Mailer gelesen |
| `CHROMIUM_PATH` | Chromium von Playwright | Eigener Browserpfad (optional) |

## 7. GitHub Actions

| Name | Typ | Beschreibung |
|---|---|---|
| `DEPLOY_HOST` | Secret | IP oder Hostname des Servers |
| `DEPLOY_USER` | Secret | `deploy` |
| `DEPLOY_SSH_KEY` | Secret | Privater Deploy-Schlüssel |
| `DEPLOY_HOST_FINGERPRINT` | Secret | Host-Fingerprint (ed25519) |
| `GHCR_READ_TOKEN` | Secret | PAT mit `read:packages` |
| `APP_DOMAIN` | Variable | Domain für den Healthcheck nach dem Deployment |

## 8. Checkliste Produktion

- [ ] `APP_ENV=production`, `APP_DEBUG=false`
- [ ] `APP_KEY` gesetzt und im Passwortmanager
- [ ] `APP_URL`, `FRONTEND_URL`, `CARD_BASE_URL` mit `https://` und dauerhafter Domain
- [ ] `SESSION_SECURE_COOKIE=true`, `SESSION_DOMAIN` und `SANCTUM_STATEFUL_DOMAINS` = App-Domain
- [ ] `LOG_CHANNEL=stderr`, `LOG_LEVEL=info`
- [ ] `DB_PASSWORD`, `DB_ROOT_PASSWORD`, `REDIS_PASSWORD` zufällig und in beiden Dateien konsistent
- [ ] `MAIL_*` mit echtem Versanddienstleister; SPF/DKIM/DMARC eingerichtet
- [ ] `SEED_DEMO_DATA=false`
- [ ] NTAG-424-Schlüssel gesetzt (falls NTAG 424 DNA verwendet wird)
- [ ] `WAITER_IOS_APP_IDS`, `WAITER_ANDROID_PACKAGE`, `WAITER_ANDROID_CERT_SHA256` vor der ersten Store-Veröffentlichung der nativen Kellner-App gesetzt, damit Kartenlinks die App öffnen

---

Version 1.0 · Stand: September 2026
