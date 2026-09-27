# Deployment-Anleitung

*Einrichtung des Produktivservers bei Hetzner, DNS, Firewall, Secrets, Docker Compose, CI/CD mit GitHub Actions, Release-Prozess, Rollout ohne Unterbrechung, Kontrollen nach dem Deployment und Rollback.*

---

## 1. Zielarchitektur

Die Referenzinstallation betreibt das gesamte Produkt auf **einem Hetzner-Cloud-Server** (CPX31: 4 vCPU / 8 GB RAM) mit Docker Compose. Das reicht nach Einschätzung der Entwicklung für mehrere hundert Restaurants (Schätzung, siehe [Performance-Leitfaden](performance-guide.md)).

```
                ┌──────────────── Hetzner host ─────────────────┐
 Internet ──443─▶ caddy ──/api,/sanctum,/up──▶ api (php-fpm)    │
                │   │                          queue, scheduler │
                │   └──────── everything else ─▶ web (Next.js)  │
                │                     mysql 8.4 · redis 7.4     │
                └────────────────────────────────────────────────┘
```

| Dienst (Compose) | Image | Aufgabe |
|---|---|---|
| `caddy` | `caddy:2.8-alpine` | TLS (Let's Encrypt, automatisch), HTTP/3, HSTS, Routing nach Pfad. Einziger Dienst mit veröffentlichten Ports (80, 443, 443/udp). |
| `api` | `giftcard-pro-api` (`CONTAINER_ROLE=app`) | PHP-FPM auf Port 9000 (intern). Führt beim Start Migrationen und Referenz-Seeder aus. |
| `queue` | `giftcard-pro-api` (`CONTAINER_ROLE=worker`) | `queue:work redis --queue=default,notifications --tries=5` |
| `scheduler` | `giftcard-pro-api` (`CONTAINER_ROLE=scheduler`) | `schedule:work` – nächtliche Jobs |
| `web` | `giftcard-pro-web` | Next.js-Standalone-Server auf Port 3000 (intern) |
| `mysql` | `mysql:8.4` | `READ-COMMITTED`, `utf8mb4`, Buffer Pool 512 MB |
| `redis` | `redis:7.4-alpine` | AOF-Persistenz, `noeviction`, Passwort |
| `backup` | `mysql:8.4` (Profil `backup`) | Nur bei Aufruf: `infra/scripts/backup.sh` |

Da Web-App und API denselben Origin nutzen, sind Sanctum-Cookies First-Party-Cookies und es gibt keine CORS-Konfiguration.

## 2. Server einrichten

### 2.1 Server anlegen

1. In der Hetzner Cloud Console einen Server **Ubuntu 24.04** am Standort **Falkenstein oder Nürnberg** (Deutschland, EU) anlegen, Typ CPX31.
2. Eigenen SSH-Schlüssel hinterlegen.
3. **Backups** aktivieren (tägliche Server-Snapshots durch Hetzner).
4. Eine **Cloud Firewall** zuweisen:

| Richtung | Protokoll | Port | Quelle |
|---|---|---|---|
| eingehend | TCP | 22 | nur eigene feste IP-Adressen |
| eingehend | TCP | 80 | beliebig (HTTP → HTTPS, ACME-Challenge) |
| eingehend | TCP | 443 | beliebig |
| eingehend | UDP | 443 | beliebig (HTTP/3) |

MySQL (3306) und Redis (6379) werden in Produktion **nicht** veröffentlicht; nur Caddy hat Ports.

### 2.2 DNS

Für die App-Domain (`APP_DOMAIN`, z. B. `app.giftcardpro.at`) einen **A-Record** (IPv4) und einen **AAAA-Record** (IPv6) auf den Server setzen. Caddy holt das Zertifikat erst, wenn die Domain auf den Server zeigt.

> **Wichtig:** Die Domain in `CARD_BASE_URL` wird auf jede NFC-Karte und jeden QR-Code geschrieben. Eine spätere Änderung macht bereits ausgegebene Karten unbrauchbar. Vor dem ersten Kartendruck eine Domain wählen, die dauerhaft bleibt.

### 2.3 Härten und Docker installieren

```bash
adduser deploy && usermod -aG sudo deploy
# /etc/ssh/sshd_config: PasswordAuthentication no, PermitRootLogin no
apt update && apt -y upgrade && apt -y install unattended-upgrades fail2ban git
curl -fsSL https://get.docker.com | sh && usermod -aG docker deploy
```

Nach der Änderung von `sshd_config` den SSH-Dienst neu laden und in einer zweiten Sitzung prüfen, dass die Anmeldung als `deploy` mit Schlüssel funktioniert, bevor die erste Sitzung geschlossen wird.

Für Off-site-Backups zusätzlich `rclone` installieren und ein Remote `storagebox` (SFTP zur Hetzner Storage Box) einrichten – siehe [Backup-Anleitung](backup-guide.md).

## 3. Anwendungsverzeichnis und Secrets

```bash
sudo mkdir -p /opt/giftcard-pro && sudo chown deploy: /opt/giftcard-pro
cd /opt/giftcard-pro
git clone git@github.com:your-org/giftcard-pro.git .
cp .env.production.example .env.production           # compose variables
cp backend/.env.production.example backend/.env.production
```

Es gibt **zwei** Konfigurationsdateien:

| Datei | Inhalt |
|---|---|
| `/opt/giftcard-pro/.env.production` | Compose-Ebene: `APP_DOMAIN`, `ACME_EMAIL`, `REGISTRY`, `IMAGE_TAG`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`, `DB_ROOT_PASSWORD`, `REDIS_PASSWORD`, optional `WAITER_IOS_APP_IDS`, `WAITER_ANDROID_PACKAGE`, `WAITER_ANDROID_CERT_SHA256` (native Kellner-App) |
| `/opt/giftcard-pro/backend/.env.production` | Laravel-Konfiguration für `api`, `queue`, `scheduler` und `backup` |

`DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` und `REDIS_PASSWORD` müssen in **beiden** Dateien identisch sein. In `backend/.env.production` gilt `DB_HOST=mysql` und `REDIS_HOST=redis` (Dienstnamen im Compose-Netz). Beide Dateien sind in `.gitignore` eingetragen und dürfen nie eingecheckt werden.

Secrets erzeugen:

```bash
openssl rand -base64 36                               # DB / Redis passwords
echo "base64:$(openssl rand -base64 32)"                                            # APP_KEY
docker run --rm --entrypoint php ghcr.io/your-org/giftcard-pro-api:latest artisan giftcard:nfc-keys   # NTAG 424 keys (optional)
```

> `APP_KEY` und die NTAG-424-Schlüssel im Passwortmanager ablegen. Geht `APP_KEY` verloren, werden alle Personen abgemeldet. Gehen die NFC-Schlüssel verloren, sind NTAG-424-DNA-Karten nicht mehr prüfbar.

Pflichtwerte in `backend/.env.production` prüfen: `APP_ENV=production`, `APP_DEBUG=false`, `APP_URL`, `FRONTEND_URL` und `CARD_BASE_URL` mit `https://<APP_DOMAIN>`, `SESSION_DOMAIN` und `SANCTUM_STATEFUL_DOMAINS` = `<APP_DOMAIN>`, `SESSION_SECURE_COOKIE=true`, `LOG_CHANNEL=stderr`, `LOG_LEVEL=info`, `SEED_DEMO_DATA=false`, `MAIL_*`. Details: [Umgebungsvariablen](environment-variables.md).

## 4. Erster Start

```bash
docker login ghcr.io
docker compose --env-file .env.production up -d
docker compose --env-file .env.production exec api php artisan platform:create-admin you@company.com
```

Ablauf beim ersten Start:

1. `mysql` und `redis` starten und melden sich über ihre Healthchecks als gesund.
2. `api` führt `migrate --force --isolated` und die Referenz-Seeder aus, cacht Konfiguration, Routen, Views und Events und startet danach PHP-FPM. Der Healthcheck (`pgrep -f "php-fpm: master"`) wird erst dann grün (Startfenster 120 s).
3. `queue` und `scheduler` starten erst, wenn `api` gesund ist – sie laufen nie gegen ein nicht migriertes Schema.
4. Caddy fordert beim ersten HTTPS-Aufruf das TLS-Zertifikat an.

Kontrolle:

```bash
docker compose --env-file .env.production ps
curl -fsS https://app.giftcardpro.at/up        # expected: HTTP 200
```

## 5. CI/CD mit GitHub Actions

### 5.1 Workflows

| Workflow | Auslöser | Inhalt |
|---|---|---|
| `ci.yml` | jeder Pull Request, jeder Push auf `main` | Backend: Pint, Larastan, PHPUnit mit SQLite **und** MySQL 8.4, `composer audit`. Frontend: ESLint, `tsc`, `next build`, `npm audit --omit=dev --audit-level=high`. Danach Build beider Docker-Images (ohne Push). |
| `deploy.yml` | Tag `v*` oder manuell (`workflow_dispatch`) | Baut beide Images, pusht sie nach GHCR mit dem Commit-SHA und `latest` als Tag, verbindet sich per SSH mit dem Server und führt `infra/scripts/deploy.sh` aus. Läuft in der Environment `production`; parallele Deployments werden serialisiert (`concurrency: deploy-production`). |

### 5.2 Repository-Konfiguration

| Name | Typ | Wert |
|---|---|---|
| `DEPLOY_HOST` | Secret | IP oder Hostname des Servers |
| `DEPLOY_USER` | Secret | `deploy` |
| `DEPLOY_SSH_KEY` | Secret | privater Schlüssel eines Deploy-Keys, der am Server erlaubt ist |
| `DEPLOY_HOST_FINGERPRINT` | Secret | `ssh-keyscan -t ed25519 host \| ssh-keygen -lf -` |
| `GHCR_READ_TOKEN` | Secret | Personal Access Token mit `read:packages` |
| `APP_DOMAIN` | Variable | `app.giftcardpro.at` |
| `production` | Environment | erforderliche Reviewer für manuelle Freigabe eintragen |

Der Server-Schritt in `deploy.yml` führt aus:

```bash
cd /opt/giftcard-pro
git fetch --tags --quiet && git checkout --quiet <commit-sha>
echo "<GHCR_READ_TOKEN>" | docker login ghcr.io -u <owner> --password-stdin
IMAGE_TAG=<commit-sha> APP_DOMAIN=<APP_DOMAIN> ./infra/scripts/deploy.sh
```

Der Server braucht deshalb Lesezugriff auf das Git-Repository (z. B. einen Deploy-Key des Benutzers `deploy`).

## 6. Release-Prozess

1. Alle Änderungen sind auf `main`, `ci.yml` ist grün.
2. Browser-Abnahmetest (`e2e/pilot-journey.mjs`) gegen eine Staging- oder lokale Umgebung ausführen – siehe [Installationsanleitung](installation-guide.md#10-browser-abnahmetest-e2e).
3. `CHANGELOG.md` ergänzen (was und warum), Versionsnummer nach SemVer festlegen – siehe [Upgrade-Anleitung](upgrade-guide.md).
4. Tag setzen und pushen:

```bash
git tag v1.4.0 && git push --tags
```

5. `deploy.yml` startet; nach Freigabe durch die Reviewer der Environment `production` wird ausgerollt.
6. Kontrollen nach dem Deployment (Abschnitt 8) durchführen.

Deployments nicht während der Hauptservicezeiten der Restaurants auslösen (Empfehlung: vormittags vor 11:00 oder nachmittags zwischen 14:30 und 17:00 Uhr Wiener Zeit) und nicht zwischen 00:00 und 00:30 Uhr (Kartenablauf um 00:15) oder um 02:30 Uhr (Backup).

## 7. Rollout ohne Unterbrechung

`infra/scripts/deploy.sh` läuft in folgenden Schritten:

| Schritt | Befehl | Zweck |
|---|---|---|
| 1 | `docker compose … pull api queue scheduler web` | Neue Images laden, während die alte Version weiterläuft |
| 2 | `docker compose … up -d --no-deps api` | Neuer API-Container; Einstiegspunkt führt `migrate --force --isolated` und Seeder aus |
| 3 | `exec -T api php artisan migrate:status` | Bricht ab, falls die API nicht erreichbar ist |
| 4 | `up -d --no-deps queue scheduler web caddy` | Worker, Scheduler, Web-App und Proxy tauschen |
| 5 | `exec -T api php artisan queue:restart` | Worker beenden laufende Jobs sauber und starten mit neuem Code |
| 6 | bis zu 30 × `curl -fsS https://${APP_DOMAIN}/up` im Abstand von 2 s | Healthcheck; bei Erfolg `docker image prune -f`, sonst Exit-Code 1 |

Grundsätze, die den Rollout ohne sichtbare Unterbrechung ermöglichen:

- **Rückwärtskompatible Migrationen (expand → migrate → contract).** Eine Migration darf nie etwas entfernen oder umbenennen, das die vorherige Version noch braucht. Spalten werden zuerst ergänzt (Release N), Code umgestellt (Release N), alte Spalten erst in Release N+1 entfernt. Dadurch arbeitet der alte `web`-Container während des Rollouts weiter.
- **`migrate --isolated`** setzt eine Cache-Sperre: Zwei App-Container migrieren nie gleichzeitig.
- **Healthchecks steuern die Reihenfolge.** `queue` und `scheduler` hängen von `api: service_healthy` ab; der API-Healthcheck wird erst grün, wenn PHP-FPM nach Migration und Cache-Aufbau läuft.
- **Geldbewegungen sind idempotent.** Trifft ein Einlöse-Request während des Container-Tauschs auf einen Fehler, wiederholt die Kellner-App ihn mit demselben `Idempotency-Key` – es wird nie doppelt gebucht.

Einschränkung: Beim Austausch eines Containers entsteht eine kurze Lücke von wenigen Sekunden, in der Caddy für diesen Dienst Fehler liefern kann (ein Host, keine Replikate). Deshalb Deployments außerhalb der Servicezeiten.

## 8. Kontrollen nach dem Deployment

```bash
cd /opt/giftcard-pro
docker compose --env-file .env.production ps                       # all services "running"/"healthy"
curl -fsS https://app.giftcardpro.at/up                            # 200
docker compose --env-file .env.production exec api php artisan about
docker compose --env-file .env.production exec api php artisan migrate:status
docker compose --env-file .env.production exec scheduler php artisan schedule:list
docker compose --env-file .env.production exec api php artisan queue:failed
docker compose --env-file .env.production logs --since 10m api queue | grep -iE "error|critical|emergency"
```

Funktionsprüfung (etwa 5 Minuten):

| Prüfung | Erwartung |
|---|---|
| Anmeldung als Plattform-Administrator | Dashboard lädt, keine Fehlermeldung |
| Test-Restaurant: Karte suchen, Kartendetails öffnen | Verlauf und Guthaben korrekt |
| Kellner-App auf einem Testgerät: Testkarte scannen | Karte öffnet sich in unter 1 s |
| Öffentliche Guthabenseite einer Testkarte | Guthaben sichtbar (sofern aktiviert) |
| Testeinlösung von € 0,01 auf einer internen Testkarte, danach Storno | Buchung und Gegenbuchung im Ledger |
| Uptime-Monitor | grün |

## 9. Rollback

### 9.1 Anwendung zurückrollen

Images bleiben in GHCR mit ihrem Commit-SHA erhalten. Rollback auf den vorherigen Stand:

**Variante A – über GitHub Actions:** `deploy.yml` manuell starten (**Run workflow**) und als Ref den vorherigen Tag wählen (z. B. `v1.3.0`). Die Images werden aus diesem Stand gebaut und ausgerollt.

**Variante B – direkt am Server** (schneller, ohne Neubau):

```bash
cd /opt/giftcard-pro
git fetch --tags && git checkout <previous-release-sha>
IMAGE_TAG=<previous-release-sha> APP_DOMAIN=app.giftcardpro.at ./infra/scripts/deploy.sh
```

### 9.2 Migrationen und Rollback

- Migrationen werden beim Rollback **nicht** automatisch zurückgenommen. Durch das Expand-/Contract-Prinzip läuft die vorherige Version mit dem neueren Schema.
- `php artisan migrate:rollback` in Produktion nur nach Prüfung der betroffenen Migration und nach einem frischen Backup ausführen. Migrationen, die Daten verändern, niemals ohne Restore-Plan zurücknehmen.
- Ist das Schema beschädigt, gilt die [Restore-Anleitung](restore-guide.md).

### 9.3 Wann zurückrollen

| Situation | Maßnahme |
|---|---|
| `/up` liefert nach dem Deployment kein 200 | Logs prüfen (`docker compose logs api`); ohne schnelle Lösung sofort Rollback |
| Einlösungen schlagen fehl (5xx) | Sofort Rollback, danach Analyse |
| Einzelne Oberflächenfehler ohne Geldbezug | Fix-Release statt Rollback |

## 10. Nächtliche Jobs

Der `scheduler`-Container führt `schedule:work` aus. Zeiten gelten in `SCHEDULE_TIMEZONE` (Standard `Europe/Vienna`):

| Zeit | Job |
|---|---|
| 00:15 | `giftcards:expire` – abgelaufene Karten ausbuchen (im Ledger und Audit-Log; eine fehlerhafte Karte stoppt den Lauf nicht) |
| 03:30 | `queue:prune-failed --hours=720` – fehlgeschlagene Jobs älter als 30 Tage entfernen |
| 10:00 | `giftcards:notify-expiring` – Erinnerungs-E-Mails, nur für aktive Restaurants |
| alle 15 Minuten | `auth:clear-resets` |
| alle 5 Minuten | `queue:monitor redis:default,redis:notifications --max=500` |

Zusätzlich per Cron des Benutzers `deploy`: Datenbank-Backup um 02:30 und Off-site-Sync um 02:45 (Serverzeit) – siehe [Backup-Anleitung](backup-guide.md).

## 11. Skalierung

| Bedarf | Schritt |
|---|---|
| Mehr Webverkehr | Mehrere `api`- und `web`-Replikate hinter Caddy (`reverse_proxy` akzeptiert mehrere Upstreams). Die Anwendung ist zustandslos – Sessions, Cache und Sperren liegen in Redis. |
| Datenbank | Managed MySQL oder dedizierter Server; Read Replica für Exporte und Auswertungen |
| Isolation für Großkunden | Dieselben Images je Kunde separat betreiben (Single Tenant) – ohne Codeänderung |

Details: [Performance-Leitfaden](performance-guide.md).

---

Version 1.0 · Stand: September 2026
