# Deployment-Anleitung

*Betrieb von GiftCard Pro als eine Coolify-Ressource: Architektur, Voraussetzungen, erstes Deployment Schritt für Schritt, Datenbankschema, Updates, Kontrollen, Rollback, nächtliche Jobs, Fehlerbehebung und Skalierung. Englische Referenz: [docs/DEPLOYMENT.md](../../DEPLOYMENT.md).*

---

## 1. Zielarchitektur

GiftCard Pro läuft in Produktion als **eine Coolify-Ressource**, gebaut aus diesem Repository mit [`docker-compose.coolify.yml`](../../../docker-compose.coolify.yml). Coolify klont das Repository, baut jedes Image auf Ihrem Server, startet den Stack und stellt HTTPS bereit. Es gibt keine Container-Registry, kein vorgefertigtes Image und keinen Deploy-Schritt in GitHub Actions.

```
Internet ──HTTPS──▶ Coolify proxy (TLS certificate for your domain)
                      │
                      ▼ HTTP, internal network
                    gateway :80  (Caddy, infra/docker/gateway)
                      ├─ /api/*  /sanctum/*  /up  ──FastCGI──▶ api :9000   (Laravel, php-fpm)
                      └─ everything else  ─────────HTTP────▶ web :3000   (Next.js dashboard and web till)

  worker    queue:work (every e-mail is sent from the queue)
  scheduler schedule:work (nightly expiry, integrity check, reminders…)
  mysql     MySQL 8.4            volume mysql-data
  redis     Redis 7.4 (AOF)      volume redis-data     sessions, cache, locks, queues
  backup    daily mysqldump      volume mysql-backups  (kept 14 days)
```

| Dienst | Gebaut aus | Öffentlich | Healthcheck | Volume |
|---|---|---|---|---|
| `gateway` | `infra/docker/gateway/` (Caddy) | **ja** – der einzige Dienst mit Domain | `GET /gateway-health` | — |
| `api` | `backend/Dockerfile` | nein (über das Gateway) | php-fpm-Ping | `laravel-storage` |
| `worker` | `backend/Dockerfile` | nein | Prozessprüfung | `laravel-storage` |
| `scheduler` | `backend/Dockerfile` | nein | Prozessprüfung | `laravel-storage` |
| `web` | `dashboard/Dockerfile` | nein (über das Gateway) | `GET /login` | — |
| `mysql` | Image `mysql:8.4` | nein | `mysqladmin ping` | `mysql-data` |
| `redis` | Image `redis:7.4-alpine` | nein | `redis-cli ping` | `redis-data` |
| `backup` | Image `mysql:8.4` | nein | — | `mysql-backups` |

Alle Dienste laufen mit `restart: unless-stopped`. Warum ein Gateway: Das Produkt ist **ein Origin** – Dashboard, Web-Kassa, API und die Sanctum-Cookies teilen eine Domain. Das Gateway übernimmt das Routing nach Pfad innerhalb des Stacks; Coolify muss nur eine Domain auf einen Container leiten.

**Startreihenfolge.** Die Compose-Datei hat **kein `depends_on`** – Coolify startet alle acht Container gleichzeitig. Die Reihenfolge wird in den Laravel-Containern erzwungen (`infra/docker/php/entrypoint.sh`): warten, bis MySQL und Redis Verbindungen annehmen (bei frischen Volumes bis zu 15 Minuten) → Migrationen ausführen (eine Redis-Sperre lässt genau einen Container migrieren, die anderen warten, bis nichts mehr offen ist) → `api` legt die Referenzdaten an (Rollen und Berechtigungen, E-Mail-Vorlagen, Systemeinstellungen) → Start. Bis dahin antwortet das Gateway für die API mit 502. Eine fehlschlagende Migration stoppt den Container mit dem Fehler im Log (Ressource → *Logs*).

## 2. Voraussetzungen

- Ein Server mit **Coolify** (Ubuntu 24.04, ≥ 2 vCPU / 4 GB RAM; Hetzner CX32/CPX31 in Falkenstein oder Nürnberg für Datenhaltung in der EU). Installation: `curl -fsSL https://cdn.coollabs.io/coolify/install.sh | sudo bash`.
- Die Domain, z. B. `app.giftcardpro.at`, mit einem **A-Record** (und AAAA bei IPv6) auf diesen Server.
- Dieses Repository auf GitHub (privat ist in Ordnung).
- SMTP-Zugangsdaten eines E-Mail-Dienstes (Postmark, Mailgun, Brevo, …) – Einladungen und Passwort-Links brauchen ihn.

Firewall: nur 22 (SSH, eingeschränkt auf eigene IP-Adressen), 80 und 443 öffnen. Kein Dienst des Stacks veröffentlicht einen Host-Port.

## 3. Erstes Deployment – Schritt für Schritt

1. **DNS.** `A  app  →  <Server-IPv4>` anlegen (und `AAAA` für IPv6). Warten, bis `dig +short app.giftcardpro.at` die IP liefert. Erst dann kann Coolify das Zertifikat holen.
2. **GitHub verbinden** (einmal je Coolify): *Sources* → *+ Add* → *GitHub App* → dem Assistenten folgen und die App im Repository installieren.
3. **Ressource anlegen:** *Projects* → Ihr Projekt → *+ New* → *Private Repository (with GitHub App)* → Repository und Branch (`main`) wählen.
   - **Build Pack:** `Docker Compose`
   - **Base Directory:** `/`
   - **Docker Compose Location:** `/docker-compose.coolify.yml`
   - *Continue*. Coolify liest die Datei und listet die Dienste.
4. **Domain:** in der Seite *General* der Ressource, *Domains for gateway* → `https://app.giftcardpro.at`. Alle anderen Dienste bleiben ohne Domain.
5. **Environment Variables** (Ressource → *Environment Variables* → *Developer view*):
   - prüfen, dass `SERVICE_PASSWORD_MYSQL`, `SERVICE_PASSWORD_MYSQLROOT` und `SERVICE_PASSWORD_REDIS` Werte haben (Coolify erzeugt sie) und `SERVICE_URL_GATEWAY` `https://app.giftcardpro.at` zeigt;
   - die E-Mail-Einstellungen aus [`.env.production.example`](../../../.env.production.example) ergänzen: `MAIL_MAILER=smtp`, `MAIL_HOST`, `MAIL_PORT`, `MAIL_SCHEME`, `MAIL_USERNAME`, `MAIL_PASSWORD` (optional: `MAIL_FROM_ADDRESS`, `OPS_ALERT_EMAIL`). Alles andere hat Produktionsstandards. Details: [Umgebungsvariablen](environment-variables.md).
6. **Deploy.** Der erste Build dauert 5–10 Minuten (PHP-Erweiterungen, Composer, Next.js). Am Ende sind alle acht Dienste *healthy* (beim ersten Deploy brauchen die Laravel-Dienste 1–3 Minuten: MySQL initialisiert, dann laufen die Migrationen).
7. **Erster Plattform-Administrator:** Ressource → *Terminal* → Container **api** →
   ```bash
   php artisan platform:create-admin you@giftcardpro.at --name="Your Name"
   ```
   (fragt nach einem Passwort, mindestens 12 Zeichen, Groß- und Kleinbuchstaben und eine Ziffer).
8. **Prüfen:**
   - `https://app.giftcardpro.at/up` → grüne Seite („Application up“; prüft Datenbank und Cache)
   - `https://app.giftcardpro.at/api/v1/app/config?platform=android&version=2.0.0` → JSON
   - `https://app.giftcardpro.at` → Anmeldeseite; anmelden, ein Test-Lokal anlegen, Eingang der Willkommens-E-Mail bestätigen.
9. **APP_KEY sichern** (beim ersten Deploy erzeugt): *Terminal* → Container **api** → `cat storage/app/.app-key`. Im Passwortmanager ablegen und idealerweise als `APP_KEY` in die Environment Variables eintragen (dann hängt der Schlüssel nicht mehr am Volume). Auf einem laufenden System nie ändern.
10. **Automatische Deployments:** Ressource → *Advanced* → *Auto Deploy* ein (Standard mit der GitHub App). Jeder Push auf `main` baut und rollt aus; Migrationen laufen automatisch.

Für keinen dieser Schritte muss im Repository etwas geändert werden, und es wird keine `.env`-Datei benötigt: Die gesamte Konfiguration kommt aus den Environment Variables der Coolify-Ressource.

## 4. Datenbankschema

Das Schema besteht aus sieben Migrationen, `backend/database/migrations/2026_01_01_000001` … `000007` (siehe [docs/DATABASE.md](../../DATABASE.md)). Die Laravel-Container führen offene Migrationen bei jedem Start aus. Ein Schema wird mit folgenden Befehlen vollständig neu installiert (löscht alle Daten): *Terminal* → Container **api** →

```bash
php artisan migrate:fresh --seed --force
php artisan platform:create-admin you@giftcardpro.at --name="Your Name"
php artisan giftcard:verify-chains
```

MySQL läuft mit `--log-bin-trust-function-creators=1` (gesetzt in `docker-compose.coolify.yml`), damit der Anwendungsbenutzer die Append-only-Trigger anlegen kann.

## 5. Updates und Release-Prozess

1. Alle Änderungen sind auf `main`, CI (`.github/workflows/ci.yml`) ist grün: Backend (Pint, Larastan, PHPUnit mit SQLite **und** MySQL 8.4, Demodaten auf MySQL mit anschließender Integritätsprüfung, `composer audit`), Dashboard (Lint, Typecheck, Tests, Build, `npm audit`), Kellner-App (Analyse, Tests, Android- und iOS-Build) und ein Build des Coolify-Stacks.
2. `CHANGELOG.md` ergänzen (was und warum), Versionsnummer nach SemVer festlegen – siehe [Upgrade-Anleitung](upgrade-guide.md).
3. Push auf `main` (oder *Redeploy*). Coolify baut die neuen Images und ersetzt danach die Container; der erste neue Laravel-Container führt offene Migrationen aus, `api`/`worker`/`scheduler` bedienen erst danach Anfragen. Beim Austausch der Container gibt es wenige Sekunden Unterbrechung.
4. Kontrollen nach dem Deployment (Abschnitt 8) durchführen.

Deployments nicht während der Hauptservicezeiten der Lokale auslösen (Empfehlung: vormittags vor 11:00 oder nachmittags zwischen 14:30 und 17:00 Uhr Wiener Zeit) und nicht um 00:15 (Gutscheinablauf), 01:30 UTC (Backup) oder 02:30 (Integritätsprüfung).

Geldbewegungen sind idempotent: Trifft eine Einlösung während des Container-Tauschs auf einen Fehler, fragen Kellner-App und Web-Kassa das Ergebnis mit demselben `Idempotency-Key` ab (`GET /vouchers/{id}/redemptions/{key}`) – es wird nie doppelt gebucht.

## 6. Backups

Der Dienst `backup` schreibt täglich um `BACKUP_TIME` (UTC, Standard 01:30) `giftcard_pro_<UTC-Zeitstempel>.sql.gz` in das Volume `mysql-backups` und löscht Dumps, die älter als `BACKUP_KEEP_DAYS` (Standard 14) sind. Die Dumps sind konsistent (`--single-transaction`) und enthalten die Append-only-Trigger (`--triggers`). Eine Off-site-Kopie ist für echte Daten Pflicht. Details: [Backup-Anleitung](backup-guide.md), Wiederherstellung: [Restore-Anleitung](restore-guide.md).

## 7. Betrieb

| Aufgabe | Wo |
|---|---|
| Logs eines Dienstes | Ressource → *Logs* (alle Dienste loggen nach stdout/stderr; Laravel mit `LOG_CHANNEL=stderr`) |
| Artisan-Befehl | *Terminal* → **api** → `php artisan …` (z. B. `migrate:status`, `schedule:list`, `queue:failed`) |
| Integritätsprüfung sofort | *Terminal* → **api** → `php artisan giftcard:verify-chains` (berechnet jede Hash-Kette und jedes Gutscheinguthaben neu) |
| Einstellung ändern | *Environment Variables* → *Redeploy* (die Konfiguration wird beim Containerstart gecacht) |
| Monitoring | Uptime-Check auf `https://<domain>/up`; `OPS_ALERT_EMAIL` erhält eine E-Mail, wenn eine Queue 500 Jobs überschreitet und wenn die nächtliche Integritätsprüfung fehlschlägt. Eine fehlgeschlagene Integritätsprüfung ist ein Sicherheitsvorfall: Datenbank und Backups sichern, bevor irgendetwas geändert wird |
| Logs ohne Secrets | Access- und Error-Logs des Gateways lassen Tokens, E-Mail-Query-Parameter, Cookies, `Authorization`, `X-Device-Id` und `Idempotency-Key` weg; jeder Dienst rotiert sein Docker-Log bei 10 MB × 5 Dateien |

## 8. Kontrollen nach dem Deployment

In Coolify: alle acht Dienste *healthy*, das Deploy-Log ohne Fehler. Dann im *Terminal* des Containers **api**:

```bash
curl -fsS https://app.giftcardpro.at/up        # from anywhere: 200
php artisan about
php artisan migrate:status
php artisan schedule:list
php artisan queue:failed
php artisan giftcard:verify-chains
```

Funktionsprüfung (etwa 5 Minuten):

| Prüfung | Erwartung |
|---|---|
| Anmeldung als Plattform-Administrator | Plattformseiten laden, kein rotes E-Mail-Banner |
| Test-Lokal: Gutschein verkaufen (Zahlung erfassen) und Druckblatt öffnen | QR-Code und Wert sichtbar, keine Gutscheinnummer auf dem Blatt |
| Kellner-App auf einem Testgerät: Test-QR scannen | Scan mit Countdown, Guthaben korrekt |
| Testeinlösung von € 0,01 auf einem internen Testgutschein, danach Storno | Buchung und Gegenbuchung im Ledger |
| `giftcard:verify-chains` | ohne Befund |
| Uptime-Monitor | grün |

## 9. Rollback

### 9.1 Anwendung zurückrollen

Ressource → *Deployments* → ein früheres Deployment wählen → *Redeploy*. Die Datenbank wird dabei nicht zurückgesetzt; ein Backup wird nur bei echtem Datenverlust eingespielt ([Restore-Anleitung](restore-guide.md)).

### 9.2 Migrationen und Rollback

- Migrationen werden beim Rollback **nicht** automatisch zurückgenommen. Eine Schemaänderung ist so zu schreiben, dass die vorherige Version mit dem neueren Schema weiterläuft.
- `php artisan migrate:rollback` in Produktion nur nach Prüfung der betroffenen Migration und nach einem frischen Backup ausführen.
- Ledger, Zahlungen und Audit-Log werden nie per Rollback oder SQL korrigiert; Korrekturen sind neue Einträge (Storno, Wiederfreigabe).

### 9.3 Wann zurückrollen

| Situation | Maßnahme |
|---|---|
| `/up` liefert nach dem Deployment kein 200 | Logs prüfen (Ressource → *Logs*, Dienst `api`); ohne schnelle Lösung sofort Rollback |
| Scans oder Einlösungen schlagen fehl (5xx) | Sofort Rollback, danach Analyse |
| Einzelne Oberflächenfehler ohne Geldbezug | Fix-Release statt Rollback |

## 10. Nächtliche Jobs

Der Container `scheduler` führt `schedule:work` aus. Zeiten gelten in `SCHEDULE_TIMEZONE` (Standard `Europe/Vienna`):

| Zeit | Job |
|---|---|
| 00:15 | `vouchers:expire` – aktive Gutscheine, deren letzter Gültigkeitstag vorbei ist, werden `expired`; das Guthaben bleibt erhalten, gesperrte Gutscheine werden übersprungen |
| 02:30 | `giftcard:verify-chains` – berechnet jede Hash-Kette und jedes Guthaben neu; bei einem Befund E-Mail an `OPS_ALERT_EMAIL` |
| 03:30 | `queue:prune-failed --hours=720` – fehlgeschlagene Jobs älter als 30 Tage entfernen |
| 10:00 | `vouchers:notify-expiring` – eine Erinnerung je Gutschein mit Guthaben, `VOUCHER_EXPIRING_NOTICE_DAYS` vor Ablauf |
| alle 15 Minuten | `auth:clear-resets` |
| alle 5 Minuten | `queue:monitor redis:default,redis:notifications --max=500` |

Das tägliche Datenbank-Backup läuft im Dienst `backup` um `BACKUP_TIME` (UTC) – siehe [Backup-Anleitung](backup-guide.md). Kontrolle: `php artisan schedule:list` im Container `api`.

## 11. Staging

Eine zweite Coolify-Ressource aus demselben Repository und derselben Compose-Datei, mit eigener Domain (z. B. `https://staging.giftcardpro.at`) und `APP_ENV=staging` in ihren Environment Variables (Branch `main` oder ein Branch `staging`). Sie hat eigene Datenbank, eigenes Redis und eigene Volumes. Für Staging gelten dieselben Regeln wie für Produktion (https-URLs).

## 12. Fehlerbehebung

| Symptom | Ursache / Lösung |
|---|---|
| `api`/`worker`/`scheduler` stoppen mit „No public URL“ | Das Gateway hat keine Domain. Schritt 4. |
| `api` meldet „app.url must be the https URL …“ | Die Gateway-Domain ist `http://…` (z. B. Coolifys erzeugte sslip.io-Domain). Eine `https://`-Domain verwenden; für einen schnellen Test ohne eigene Domain funktioniert `https://<beliebig>.<server-ip>.sslip.io`. |
| `api` stoppt mit „DB_PASSWORD is empty“ | Coolify hat `SERVICE_PASSWORD_MYSQL` nicht erzeugt (ältere Coolify-Versionen). `SERVICE_PASSWORD_MYSQL`, `SERVICE_PASSWORD_MYSQLROOT` und `SERVICE_PASSWORD_REDIS` **vor** dem ersten Deploy selbst setzen (lange Zufallswerte), dann *Redeploy*. |
| Log von `api` wiederholt „MySQL not ready: … Access denied“ nach einer Passwortänderung | Das MySQL-Volume behält das Passwort seines ersten Starts. Den alten Wert zurücksetzen oder (nur ohne Daten) das Volume `mysql-data` löschen. |
| Ein Host antwortet mit `503 no available server` und dem Zertifikat `TRAEFIK DEFAULT CERT` | Dieser Host ist **keinem Dienst zugeordnet**. Das ganze Produkt, API inklusive, wird vom `gateway` auf seiner Domain ausgeliefert (`https://app.giftcardpro.at/api/v1`). Der Container `api` hat absichtlich keine Traefik-Labels und keinen HTTP-Server. Einen weiteren Host unter *Domains for gateway* kommagetrennt ergänzen (kanonische Domain zuerst), dann *Redeploy*. `api` nie eine Domain geben. |
| Zertifikat wird nicht ausgestellt / „nicht sicher“ | DNS zeigt noch nicht auf den Server, oder die Ports 80/443 sind geschlossen. |
| 419 / Anmeldeschleife im Dashboard | Die Browser-URL weicht von der Gateway-Domain ab (Cookies sind an sie gebunden). Genau die konfigurierte Domain verwenden. |
| Deployment stoppt mit `required variable SERVICE_… is missing a value` | Fail-fast von `docker-compose.coolify.yml`: Es wird kein Container angelegt. `SERVICE_URL_GATEWAY` → dem Dienst **gateway** eine `https://`-Domain geben (Schritt 4) und neu ausrollen. `SERVICE_PASSWORD_*` → in *Environment Variables* prüfen und nur selbst setzen, wenn sie fehlen. |
| Einladungen oder Passwort-E-Mails kommen nie an; rotes Banner „E-mails are not delivered“ | `MAIL_MAILER` ist noch `log`. `MAIL_MAILER=smtp` und die `MAIL_*`-Werte setzen (Schritt 5), *Redeploy*, dann **System settings → Send test e-mail** und **⋯ → Invite again** für Inhaberinnen und Inhaber, die nichts erhalten haben. Jeder Versuch steht in `notification_logs`. |
| Das Log endet nach *Pulling & building required images* | Coolify blendet die Build-Ausgabe aus: das Deployment öffnen und die Debug-Ansicht einschalten. Der erste Build dauert auf 2 vCPU / 4 GB 5–15 min. Bei Speichermangel (`dmesg -T \| grep -i oom`) Swap ergänzen oder einen größeren Server wählen. |
| Build scheitert bei `pecl install redis`, `composer install` oder `npm ci` | Vorübergehender Ausfall von pecl.php.net, GitHub oder npm. *Redeploy*. |

Weitere Fälle: [docs/DEPLOYMENT.md → Troubleshooting](../../DEPLOYMENT.md#troubleshooting).

## 13. Skalierung

| Bedarf | Schritt |
|---|---|
| Mehr Webverkehr | `pm.max_children` in `infra/docker/php/www.conf` erhöhen, dem Server mehr CPU geben; die Anwendung ist zustandslos (Sessions, Cache, Sperren in Redis). |
| Datenbank | MySQL auf eine verwaltete Datenbank verlegen: `DB_HOST`, `DB_PASSWORD` usw. setzen und die Dienste `mysql`/`backup` entfernen. |
| Isolation für Großkunden | Dasselbe Repository je Kunde als eigene Coolify-Ressource betreiben (Single Tenant) – ohne Codeänderung. |

Details: [Performance-Leitfaden](performance-guide.md).

---

Version 2.0 · Stand: September 2026
