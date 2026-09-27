# Installationsanleitung

*Lokale Entwicklungsumgebung, Voraussetzungen für den Produktivbetrieb, erster Plattform-Administrator, leere Plattform, Demodaten und Tests für GiftCard Pro.*

---

## 1. Überblick

GiftCard Pro besteht aus zwei Anwendungen und drei Hintergrunddiensten:

| Komponente | Technologie | Aufgabe |
|---|---|---|
| API | Laravel 12 / PHP 8.4 | Geschäftslogik, Ledger, Authentifizierung, Hintergrundjobs |
| Web-App | Next.js 15 / TypeScript | Dashboard, Kellner-App, Guthabenseite für Gäste, Druckansicht |
| Datenbank | MySQL 8.4 (MariaDB 10.11+ funktioniert ebenfalls) | Mandanten, Karten, Ledger, Audit-Log |
| Redis | 7.x | Sessions, Cache, Queues, Rate Limits, Locks |
| Mailpit | nur Entwicklung | Fängt alle E-Mails ab (Weboberfläche auf Port 8025) |

In der Entwicklung laufen API und Web-App nativ (Hot Reload); nur MySQL, Redis und Mailpit laufen in Docker. In Produktion läuft alles in Docker Compose – siehe [Deployment-Anleitung](deployment-guide.md).

## 2. Voraussetzungen

### 2.1 Lokale Entwicklung

| Komponente | Version |
|---|---|
| PHP | 8.4 mit den Erweiterungen `intl`, `pdo_mysql`, `gd`, `zip`, `bcmath`, `redis` (oder `predis`) |
| Composer | 2.x |
| Node.js | 22 LTS |
| MySQL | 8.4 (MariaDB 10.11+ ebenfalls möglich) |
| Redis | 7.x |
| Docker | 24+ mit Compose-Plugin (für die Hintergrunddienste) |

Wer nur mit Docker arbeitet, benötigt ausschließlich Docker 24+ mit dem Compose-Plugin.

### 2.2 Produktivbetrieb

| Bereich | Anforderung |
|---|---|
| Server | Ein Hetzner-Cloud-Server, Referenz: CPX31 (4 vCPU / 8 GB RAM), Ubuntu 24.04, Standort Falkenstein oder Nürnberg (EU) |
| Software | Docker (über `get.docker.com`), Compose-Plugin, `git`, `unattended-upgrades`, `fail2ban`, `rclone` (für Off-site-Backups) |
| Netzwerk | Hetzner Cloud Firewall: Port 22 (nur eigene IPs), 80, 443 (TCP und UDP für HTTP/3) |
| DNS | A-/AAAA-Record für die App-Domain (z. B. `app.giftcardpro.at`) auf den Server |
| Registry | Zugriff auf GitHub Container Registry (`ghcr.io`) mit einem Token mit `read:packages` |
| E-Mail | SMTP-Zugang eines Versanddienstleisters (Vorlage: Postmark, `smtp.postmarkapp.com:587`) – `[E-Mail-Versanddienstleister mit EU-Hosting]` |
| Off-site-Speicher | Hetzner Storage Box (für `rclone`) |
| Passwortmanager | Für `APP_KEY`, Datenbank- und Redis-Passwörter sowie NTAG-424-Schlüssel |

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

### 3.2 API (Laravel)

```bash
cd backend
cp .env.example .env
composer install
php artisan key:generate
```

In `.env` anpassen:

| Variable | Wert für die Dev-Compose-Datei |
|---|---|
| `DB_PASSWORD` | `secret` |
| `MAIL_HOST` | `127.0.0.1` |
| `MAIL_PORT` | `1025` |

Danach Datenbank anlegen und Dienste starten:

```bash
php artisan migrate --seed      # schema + roles/permissions + e-mail templates + demo data (local only)
php artisan serve               # http://localhost:8000
php artisan queue:work          # in a second terminal (e-mails)
php artisan schedule:work       # optional: nightly expiration & reminders
```

> **Modus ohne Abhängigkeiten:** Mit `DB_CONNECTION=sqlite`, `SESSION_DRIVER=database`, `CACHE_STORE=database` und `QUEUE_CONNECTION=sync` sowie einer leeren Datei `database/database.sqlite` läuft die API ohne MySQL und Redis. Zeilensperren sind unter SQLite wirkungslos – für alles über reine Oberflächenarbeit hinaus MySQL verwenden.

### 3.3 Web-App (Next.js)

```bash
cd dashboard
cp .env.example .env.local      # BACKEND_INTERNAL_URL=http://localhost:8000
npm install
npm run dev                     # http://localhost:3000
```

Der Dev-Server leitet `/api/*` und `/sanctum/*` an Laravel weiter. Der Browser spricht damit mit einem einzigen Origin, und die Sanctum-Session-Cookies funktionieren genau wie in Produktion. Die Anwendung ist unter **http://localhost:3000** erreichbar (nicht unter Port 8000).

### 3.4 Kurzfassung

```bash
docker compose -f docker-compose.dev.yml up -d        # MySQL, Redis, Mailpit

cd backend
cp .env.example .env && composer install && php artisan key:generate
php artisan migrate --seed                             # includes the demo restaurant
php artisan serve                                      # http://localhost:8000

cd ../dashboard
cp .env.example .env.local && npm install
npm run dev                                            # http://localhost:3000
```

## 4. Demodaten

`php artisan migrate --seed` legt in den Umgebungen `local` und `staging` automatisch ein Demo-Restaurant an. In anderen Umgebungen nur mit `SEED_DEMO_DATA=true` – **in Produktion nie**.

Demo-Zugänge (Passwort jeweils `Password123!`):

| E-Mail | Rolle |
|---|---|
| `admin@giftcardpro.test` | Plattform-Administrator |
| `owner@bellavista.test` | Inhaber/in – Trattoria Bella Vista |
| `manager@bellavista.test` | Manager |
| `waiter@bellavista.test` | Servicekraft (öffnet direkt die Kellner-App) |
| `owner@goldenerhirsch.test` | Inhaber/in eines zweiten Restaurants (zur Demonstration der Mandantentrennung) |

Lokale Datenbank zurücksetzen und neu befüllen:

```bash
php artisan migrate:fresh --seed
```

## 5. Installation mit leerer Plattform

Um lokal wie in Produktion ohne Demodaten zu starten, werden nur Schema und Referenzdaten (Rollen, Berechtigungen, E-Mail-Vorlagen, Systemeinstellungen) angelegt:

```bash
php artisan migrate --force && php artisan db:seed --class='Database\Seeders\RolesAndPermissionsSeeder' \
  && php artisan db:seed --class='Database\Seeders\NotificationTemplateSeeder' && php artisan db:seed --class='Database\Seeders\SystemSettingsSeeder'
php artisan platform:create-admin you@company.com --name="Your Name"
```

In Produktion erledigt das der Container-Einstiegspunkt (`infra/docker/php/entrypoint.sh`) bei jedem Start des `api`-Containers automatisch: `migrate --force --isolated`, danach die drei Referenz-Seeder. Die Seeder sind idempotent.

## 6. Erster Plattform-Administrator

Demodaten werden in Produktion nie angelegt. Das Betreiberkonto wird interaktiv erstellt:

```bash
# local
php artisan platform:create-admin you@company.com --name="Your Name"

# production (inside the running API container)
docker compose --env-file .env.production exec api php artisan platform:create-admin you@company.com
```

Anschließend:

1. Als Plattform-Administrator anmelden.
2. **Restaurants → Onboard restaurant** öffnen und das Restaurant anlegen.
3. Die Inhaberin bzw. der Inhaber erhält eine Willkommens-E-Mail mit einem Link zum Setzen des Passworts (72 Stunden gültig).
4. Ist der Link abgelaufen: Restaurant öffnen (**Open restaurant**) → **Team** → **Resend invitation**.

## 7. Erstes Restaurant

Beim ersten Anmelden der Inhaberin bzw. des Inhabers zeigt das Dashboard ein **Welcome**-Panel mit vier Schritten, die jeweils zur richtigen Seite führen:

1. **Kartenregeln prüfen** (Settings → Gift cards): Mindest-/Höchstwert, Standard-Gültigkeit, Aufladungen, Teileinlösung, Kunden-E-Mails. Empfehlung: **Default validity auf 0 (kein Ablauf) setzen**, solange die Rechtsberatung des Restaurants kein anderes Modell freigibt – die Werkseinstellung von 36 Monaten ist in Österreich rechtlich problematisch (keine Rechtsberatung – mit Steuerberatung/Rechtsanwalt prüfen).
2. **Team einladen** (Team → Invite): Manager und Servicekräfte erhalten eine eigene 72-Stunden-Einladung.
3. **Erste Gutscheinkarte ausgeben** (Gift cards → New gift card), danach NFC-Tag beschreiben oder Karte drucken.
4. **Kellner-Modus auf den Handys öffnen** (als Servicekraft anmelden – die Kellner-App öffnet sich automatisch).

Das Panel verschwindet nach dem ersten Kartenverkauf.

## 8. NFC-Schlüssel (nur für NTAG 424 DNA)

```bash
php artisan giftcard:nfc-keys
```

Die beiden ausgegebenen Schlüssel in `NTAG424_META_READ_KEY` und `NTAG424_FILE_READ_KEY` eintragen und im Passwortmanager sichern. Ohne diese Schlüssel sind bereits programmierte NTAG-424-DNA-Karten nicht mehr prüfbar. Für NTAG213/215/216 und QR-Karten sind keine Schlüssel nötig.

## 9. Tests ausführen

### 9.1 Backend und Frontend

```bash
cd backend && php artisan test          # 113 tests, SQLite in-memory (fast)
cd dashboard && npm run lint && npm run typecheck && npm run build
```

Einzelne Test-Suite:

```bash
php artisan test --filter=GiftCardLifecycleTest
```

Statische Analyse und Code-Stil (müssen fehlerfrei sein):

```bash
vendor/bin/phpstan analyse      # Larastan, Level 8
vendor/bin/pint --test
```

### 9.2 Tests gegen MySQL

SQLite prüft keine echten Zeilensperren. Für Tests mit echtem Locking:

```bash
docker compose -f docker-compose.dev.yml up -d mysql
mysql -h127.0.0.1 -uroot -proot -e "CREATE DATABASE giftcard_test"
sed -e 's#<env name="DB_CONNECTION" value="sqlite"/>#<env name="DB_CONNECTION" value="mysql"/><env name="DB_HOST" value="127.0.0.1"/><env name="DB_USERNAME" value="root"/><env name="DB_PASSWORD" value="root"/>#' \
    -e 's#<env name="DB_DATABASE" value=":memory:"/>#<env name="DB_DATABASE" value="giftcard_test"/>#' phpunit.xml > phpunit.mysql.xml
php artisan test --configuration=phpunit.mysql.xml
```

Die CI-Pipeline führt die Suite bei jedem Push sowohl mit SQLite als auch mit MySQL 8.4 aus.

## 10. Browser-Abnahmetest (E2E)

`e2e/pilot-journey.mjs` spielt den ersten Tag eines neuen Restaurants in echten Browsern durch (Desktop für die Inhaberin bzw. den Inhaber, ein Pixel 7 für die Servicekraft) und schlägt bei jedem fehlerhaften Schritt, jedem Konsolenfehler und jeder Barrierefreiheitsverletzung fehl:

1. Plattform-Administrator legt ein Restaurant an
2. Inhaber/in nimmt die Einladung an
3. lädt eine Servicekraft ein
4. verkauft eine Karte
5. Servicekraft löst am Handy ein (muss unter 5 Sekunden bleiben)
6. Inhaber/in lädt auf und ersetzt die „verlorene" Karte
7. die alte Karte wird abgewiesen
8. CSV-Export (Dezimalkomma)
9. axe-Barrierefreiheitsprüfung (WCAG 2.1 AA)

**Voraussetzungen:** API mit `MAIL_MAILER=log` und `LOG_LEVEL=debug` (die Einladungslinks werden aus dem Log-Mailer gelesen), Web-App auf Port 3000, ein Plattform-Administrator existiert.

```bash
cd e2e
npm install && npx playwright install chromium
ADMIN_EMAIL=admin@giftcardpro.test ADMIN_PASSWORD='Password123!' npm test
```

| Variable | Standard |
|---|---|
| `BASE_URL` | `http://localhost:3000` |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | Demo-Administrator |
| `LARAVEL_LOG_DIR` | `../backend/storage/logs/` |
| `CHROMIUM_PATH` | Chromium von Playwright |

Jeder Lauf legt ein neues Restaurant mit eindeutigen Adressen an und kann daher beliebig oft gegen dieselbe Datenbank laufen. **Den Test vor jedem Release ausführen.** Referenzwert aus Version 1.2.0: Einlösung durch die Servicekraft in 0,48 s inklusive Eingabe der Kartennummer.

## 11. Häufige Probleme

| Symptom | Ursache und Lösung |
|---|---|
| `419 CSRF_TOKEN_MISMATCH` beim Login | App über Port 8000 statt 3000 geöffnet, oder Host fehlt in `SANCTUM_STATEFUL_DOMAINS`. Immer http://localhost:3000 verwenden. |
| E-Mails kommen nicht an | `php artisan queue:work` läuft nicht, oder `MAIL_HOST`/`MAIL_PORT` zeigen nicht auf Mailpit. |
| `SQLSTATE[HY000] [1045]` | `DB_PASSWORD=secret` in `backend/.env` fehlt. |
| Web NFC funktioniert lokal nicht | Web NFC braucht HTTPS (oder `localhost`) und Chrome auf Android. Für echte NFC-Tests eine HTTPS-Umgebung verwenden. |
| Nächtliche Jobs laufen nicht | `php artisan schedule:work` starten; Zeiten gelten in `SCHEDULE_TIMEZONE` (Standard `Europe/Vienna`). |

## Weiterführend

- [Deployment-Anleitung](deployment-guide.md)
- [Umgebungsvariablen](environment-variables.md)
- [API-Dokumentation](api-documentation.md)

---

Version 1.0 · Stand: September 2026
