# Installationsanleitung

*Lokale Entwicklungsumgebung, Voraussetzungen für den Produktivbetrieb, Datenbankschema, erster Plattform-Administrator, erstes Lokal, Demodaten und Tests für GiftCard Pro. Englische Referenz: [docs/INSTALLATION.md](../../INSTALLATION.md).*

---

## 1. Überblick

GiftCard Pro besteht aus drei Anwendungen und den Hintergrunddiensten:

| Komponente | Technologie | Aufgabe |
|---|---|---|
| API | Laravel 12 / PHP 8.4 | Geschäftslogik, Vorlagen, Ledger, Authentifizierung, Hintergrundjobs |
| Web-App | Next.js 15 / TypeScript | Dashboard, Web-Kassa (`/waiter`), Druckblatt der Gutscheine |
| Kellner-App (GiftCard Waiter) | Flutter, Android und iPhone | QR-Scan → Vorlage → Einlösung; Verkauf für Betriebsleitung und Inhaberin bzw. Inhaber |
| Datenbank | MySQL 8.4 | Mandanten, Gutscheine, Zahlungen, Ledger, Audit-Log |
| Redis | 7.x | Sessions, Cache, Queues, Rate Limits, Sperren |
| Mailpit | nur Entwicklung | Fängt alle E-Mails ab (Weboberfläche auf Port 8025) |

In der Entwicklung laufen API und Web-App nativ (Hot Reload); nur MySQL, Redis und Mailpit laufen in Docker. In Produktion läuft alles als Coolify-Ressource – siehe [Deployment-Anleitung](deployment-guide.md). Schritt-für-Schritt-Befehle für jede Komponente stehen zusätzlich in [RUNNING_THE_PROJECT.md](../../../RUNNING_THE_PROJECT.md).

## 2. Voraussetzungen

### 2.1 Lokale Entwicklung

| Komponente | Version |
|---|---|
| PHP | 8.4 mit den Erweiterungen `intl`, `pdo_mysql`, `pdo_sqlite`, `gd`, `zip`, `bcmath`, `redis` (oder `predis`) |
| Composer | 2.x |
| Node.js | 22 LTS |
| MySQL | 8.4 |
| Redis | 7.x |
| Docker | 24+ mit Compose-Plugin (für die Hintergrunddienste) |

Wer nur mit Docker arbeitet, benötigt ausschließlich Docker 24+ mit dem Compose-Plugin.

### 2.2 Produktivbetrieb

| Bereich | Anforderung |
|---|---|
| Server | Server mit Coolify, Ubuntu 24.04, ≥ 2 vCPU / 4 GB RAM (Hetzner CX32/CPX31 in Falkenstein oder Nürnberg, EU) |
| Netzwerk | Firewall: Port 22 (nur eigene IPs), 80, 443 |
| DNS | A-/AAAA-Record für die App-Domain (z. B. `app.giftcardpro.at`) auf den Server |
| Quellcode | Das Repository auf GitHub; Coolify baut jedes Image auf dem Server |
| E-Mail | SMTP-Zugang eines Versanddienstleisters (Vorlage: Postmark, `smtp.postmarkapp.com:587`) – `[E-Mail-Versanddienstleister mit EU-Hosting]` |
| Off-site-Speicher | z. B. Hetzner Storage Box (für `rclone`) |
| Passwortmanager | Für `APP_KEY` und die von Coolify erzeugten Passwörter |

Die vollständige Serverinstallation beschreibt die [Deployment-Anleitung](deployment-guide.md).

## 3. Lokale Installation

### 3.1 Hintergrunddienste starten

```bash
docker compose -f docker-compose.dev.yml up -d
```

Damit starten:

| Dienst | Port | Zugangsdaten |
|---|---|---|
| MySQL 8.4 | 3306 | Datenbank `giftcard_pro`, Benutzer `giftcard`, Passwort `secret` (root: `root`) |
| Redis 7.4 | 6379 | ohne Passwort |
| Mailpit | SMTP 1025, Web 8025 | http://localhost:8025 – jede E-Mail der App landet hier |

MySQL läuft mit `--log-bin-trust-function-creators=1`, das die Append-only-Trigger brauchen.

### 3.2 API (Laravel)

```bash
cd backend
cp .env.example .env
composer install
php artisan key:generate
```

In `.env` `DB_PASSWORD=secret` für die Dev-Compose-Datei setzen. E-Mail braucht keine Einstellung: `MAIL_MAILER=failover` sendet an Mailpit, wenn es läuft, und schreibt sonst ins Log.

Danach Datenbank anlegen und Dienste starten:

```bash
php artisan migrate --seed      # schema + roles/permissions + e-mail templates + settings + demo data (local only)
php artisan serve               # http://localhost:8000
php artisan queue:work          # second terminal: every e-mail is sent from the queue
php artisan schedule:work       # optional: nightly expiry, integrity check and reminders
```

> **Modus ohne Abhängigkeiten:** Mit `DB_CONNECTION=sqlite`, `SESSION_DRIVER=database`, `CACHE_STORE=database` und `QUEUE_CONNECTION=sync` sowie einer leeren Datei `database/database.sqlite` läuft die API ohne MySQL und Redis. Zeilensperren sind unter SQLite wirkungslos – für alles, was Geld oder Nebenläufigkeit betrifft, MySQL verwenden.

### 3.3 Web-App (Next.js)

```bash
cd dashboard
cp .env.example .env.local      # BACKEND_INTERNAL_URL=http://localhost:8000
npm install
npm run dev                     # http://localhost:3000
```

Der Dev-Server leitet `/api/*` und `/sanctum/*` an Laravel weiter. Der Browser spricht damit mit einem einzigen Origin, und die Sanctum-Session-Cookies funktionieren genau wie auf einem Server. Die Anwendung ist unter **http://localhost:3000** erreichbar (nicht unter Port 8000). Das Scannen von QR-Codes in der Web-Kassa braucht eine Kamera und eine sichere Seite (`https://…` oder `http://localhost`).

### 3.4 Kellner-App (Flutter)

Die App liest ihre Umgebung beim Build aus `waiter-app/config/<umgebung>.json`; für die Entwicklung zeigt `config/development.json` auf den eigenen Rechner. Befehle und Details: [waiter-app/README.md](../../../waiter-app/README.md) und [Umgebungsvariablen](environment-variables.md#4-kellner-app-waiter-appconfigumgebungjson).

### 3.5 Kurzfassung

```bash
docker compose -f docker-compose.dev.yml up -d        # MySQL, Redis, Mailpit

cd backend
cp .env.example .env && composer install && php artisan key:generate
php artisan migrate --seed                             # includes the demo restaurants
php artisan serve                                      # http://localhost:8000

cd ../dashboard
cp .env.example .env.local && npm install
npm run dev                                            # http://localhost:3000
```

## 4. Demodaten

`php artisan migrate --seed` legt in den Umgebungen `local`, `testing` und `staging` automatisch Demo-Lokale an. In anderen Umgebungen nur mit `SEED_DEMO_DATA=true` – **in Produktion nie** (der Coolify-Stack setzt es fest auf `false`).

Demo-Zugänge (Passwort jeweils `Password123!`):

| E-Mail | Rolle |
|---|---|
| `admin@giftcardpro.test` | Plattform-Administrator |
| `owner@bellavista.test` | Inhaber/in – Trattoria Bella Vista |
| `manager@bellavista.test` | Betriebsleitung |
| `waiter@bellavista.test` | Servicekraft (öffnet direkt die Web-Kassa) |
| `owner@goldenerhirsch.test` | Inhaber/in eines zweiten Lokals (zur Demonstration der Mandantentrennung) |

## 5. Datenbankschema

Das Schema besteht aus sieben Migrationen, `backend/database/migrations/2026_01_01_000001` … `000007` (siehe [docs/DATABASE.md](../../DATABASE.md)). Eine leere Datenbank wird mit `php artisan migrate --seed` eingerichtet; eine bestehende Datenbank wird mit folgendem Befehl vollständig gelöscht und neu aufgebaut:

```bash
php artisan migrate:fresh --seed        # drops every table, creates the schema, seeds reference data
```

Referenzdaten (Rollen und Berechtigungen, Gäste-E-Mail-Vorlagen, Systemeinstellungen) werden idempotent angelegt; die Laravel-Container legen sie bei jedem Start an. Nach `migrate:fresh` auf einem Server den Plattform-Administrator erneut anlegen (`php artisan platform:create-admin`).

Um lokal wie in Produktion ohne Demodaten zu starten, nur Schema und Referenzdaten anlegen:

```bash
php artisan migrate --force && php artisan db:seed --class='Database\Seeders\RolesAndPermissionsSeeder' \
  && php artisan db:seed --class='Database\Seeders\NotificationTemplateSeeder' && php artisan db:seed --class='Database\Seeders\SystemSettingsSeeder'
php artisan platform:create-admin you@company.com --name="Your Name"
```

## 6. Erster Plattform-Administrator

Demodaten werden in Produktion nie angelegt. Das Betreiberkonto wird interaktiv erstellt (auf einem Server: Coolify → *Terminal* → Container **api**):

```bash
php artisan platform:create-admin you@company.com --name="Your Name"
```

Anschließend:

1. Als Plattform-Administrator anmelden und **System settings → E-mail delivery** öffnen: Die Seite zeigt Mailer und SMTP-Server. **Send test e-mail** drücken (standardmäßig an die eigene Adresse oder an ein eingegebenes Postfach). Ein rotes Banner auf den Plattformseiten bedeutet, dass E-Mails nur ins Log geschrieben werden (`MAIL_MAILER=log`).
2. **Restaurants → Onboard restaurant** öffnen und das Lokal anlegen.
3. Die Inhaberin bzw. der Inhaber erhält eine Willkommens-E-Mail mit einem Link zum Setzen des Passworts (72 Stunden gültig). Die Liste zeigt den Einladungsstatus jeder Inhaberin bzw. jedes Inhabers (ausstehend, abgelaufen, nicht zugestellt).
4. Ist der Link abgelaufen oder die Adresse vertippt: **⋯ → Invite again** (die Adresse kann dort korrigiert werden).

## 7. Erstes Lokal

Beim ersten Anmelden der Inhaberin bzw. des Inhabers zeigt das Dashboard ein **Welcome**-Panel mit vier Schritten, die jeweils zur richtigen Seite führen:

1. **Gutscheinregeln prüfen** (Settings → Vouchers): Werte, Grenzen, Gültigkeit, Aufladungen, Teileinlösung, Kunden-E-Mails. Ohne Gültigkeitseinstellung haben Gutscheine kein Ablaufdatum; eine eingestellte Gültigkeit beträgt mindestens 36 Monate (keine Rechtsberatung – mit Rechtsanwalt prüfen).
2. **Team einladen** (Team): Betriebsleitung und Servicekräfte erhalten eine eigene 72-Stunden-Einladung.
3. **Ersten Gutschein verkaufen** (Vouchers → Sell voucher): Zahlung erfassen und den QR-Code drucken.
4. **Kellner-App installieren**: Servicekräfte melden sich auf den Handys des Lokals in GiftCard Waiter an (oder nutzen **Redeem** im Browser).

Für die Schulung des Personals das einseitige [User Guide](../../USER_GUIDE.md); für den ersten Tag die [Pilot-Checkliste](../../PILOT_CHECKLIST.md).

## 8. NFC

GiftCard Pro liest, beschreibt und programmiert derzeit keine NFC-Tags; Gutscheine werden über ihren gedruckten QR-Code eingelöst. Physische Karten sind als NTAG 424 DNA mit Live-Authentifizierung über einen Krypto-Dienst vorgesehen; ihre Schlüssel liegen in einem Hardware-Sicherheitsmodul, nie in der Konfiguration. Details: [docs/NFC.md](../../NFC.md).

## 9. Tests ausführen

### 9.1 Backend und Frontend

```bash
cd backend && php artisan test          # SQLite in memory
cd dashboard && npm run lint && npm run typecheck && npm test && npm run build
```

Einzelne Test-Suite:

```bash
php artisan test --filter=VoucherLifecycleTest
```

Missbrauchstests (jede verbotene Aktion wird versucht, auch jeder entfernte Pfad) liegen in `backend/tests/Feature/Abuse/`.

Statische Analyse und Code-Stil (müssen fehlerfrei sein):

```bash
vendor/bin/phpstan analyse      # Larastan
vendor/bin/pint --test
```

### 9.2 Tests gegen MySQL

SQLite prüft keine echten Zeilensperren. Für Tests mit echtem Locking siehe [docs/DEVELOPMENT.md](../../DEVELOPMENT.md#testing-against-mysql). Die CI-Pipeline führt die Suite bei jedem Push sowohl mit SQLite als auch mit MySQL 8.4 aus, legt danach Demodaten auf MySQL an und prüft alle Hash-Ketten und Guthaben mit `php artisan giftcard:verify-chains`.

## 10. Browser-Abnahmetest (E2E)

`e2e/pilot-journey.mjs` spielt den ersten Tag eines neuen Lokals in echten Browsern durch (Desktop für die Inhaberin bzw. den Inhaber, ein Handy für die Servicekraft) und schlägt bei jedem fehlerhaften Schritt, jedem Konsolenfehler und jeder Barrierefreiheitsverletzung fehl:

1. Plattform-Administrator legt ein Lokal an
2. Inhaber/in nimmt die Einladung an
3. lädt eine Servicekraft ein
4. verkauft einen druckbaren Gutschein (bar)
5. Servicekraft scannt den QR-Code am Handy und löst ein
6. Inhaber/in lädt auf und sperrt den Gutschein
7. der nächste Scan der Servicekraft zeigt ihn gesperrt
8. Ledger-Export
9. axe-Barrierefreiheitsprüfung (WCAG 2.1 AA)

Die Handykamera wird simuliert: Der Test liefert der Web-Kassa genau die QR-Nutzlast, die gedruckt wird.

**Voraussetzungen:** API mit `MAIL_MAILER=log` und `LOG_LEVEL=debug` (die Einladungslinks werden aus dem Laravel-Log gelesen), Web-App auf Port 3000, ein Plattform-Administrator existiert.

```bash
cd e2e
npm install && npx playwright install chromium
ADMIN_EMAIL=admin@giftcardpro.test ADMIN_PASSWORD='Password123!' npm test
```

Weitere Abläufe: `npm run test:waiter-api` (API der Kellner-App) und `npm run test:admin` (Plattformadministration). Jeder Lauf legt ein neues Lokal mit eindeutigen Adressen an und kann daher beliebig oft gegen dieselbe Datenbank laufen. **Den Test vor jedem Release ausführen.**

## 11. Häufige Probleme

| Symptom | Ursache und Lösung |
|---|---|
| `419 CSRF_TOKEN_MISMATCH` beim Login | App über Port 8000 statt 3000 geöffnet, oder Host fehlt in `SANCTUM_STATEFUL_DOMAINS`. Immer http://localhost:3000 verwenden. |
| E-Mails kommen nicht an | `php artisan queue:work` läuft nicht, oder Mailpit läuft nicht (dann stehen die E-Mails im Log). |
| `SQLSTATE[HY000] [1045]` | `DB_PASSWORD=secret` in `backend/.env` fehlt. |
| Migration scheitert beim Anlegen der Trigger | MySQL ohne `--log-bin-trust-function-creators=1` gestartet. `docker-compose.dev.yml` verwenden. |
| QR-Scanner der Web-Kassa startet nicht | Die Kamera braucht eine sichere Seite (`https://…` oder `http://localhost`) und die Kamerafreigabe im Browser. |
| Nächtliche Jobs laufen nicht | `php artisan schedule:work` starten; Zeiten gelten in `SCHEDULE_TIMEZONE` (Standard `Europe/Vienna`). |

## Weiterführend

- [Deployment-Anleitung](deployment-guide.md)
- [Umgebungsvariablen](environment-variables.md)
- [API-Dokumentation](api-documentation.md)

---

Version 2.0 · Stand: September 2026
