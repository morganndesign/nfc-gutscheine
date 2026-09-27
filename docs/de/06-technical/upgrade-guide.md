# Upgrade-Anleitung

> **Hinweis (Coolify-Deployment):** Produktion läuft seit 1.4.2 auf **Coolify** mit `docker-compose.coolify.yml` (Build aus dem Quellcode, kein GHCR, keine Deploy-Skripte). Befehle mit `docker compose --env-file .env.production`, `infra/scripts/…`, `deploy.yml` oder Caddy auf dem Host in diesem Dokument sind überholt. Maßgeblich sind [docs/DEPLOYMENT.md](../../DEPLOYMENT.md) (Deployment, Backups, Restore, Betrieb) und [docs/ENVIRONMENT.md](../../ENVIRONMENT.md).

*Aktualisierung von GiftCard Pro auf neue Releases, Wechsel von Major-Versionen bei PHP, Node.js und MySQL, Rollback-Strategie und Versionierungsrichtlinie.*

---

## 1. Versionierung

GiftCard Pro folgt **Semantic Versioning** (`MAJOR.MINOR.PATCH`), Git-Tags im Format `vMAJOR.MINOR.PATCH` (z. B. `v1.2.0`).

| Teil | Wird erhöht bei | Beispiele | Folgen für den Betrieb |
|---|---|---|---|
| **PATCH** | Fehlerbehebungen, Sicherheitsupdates, Abhängigkeits- und Basis-Image-Updates ohne Verhaltensänderung | `v1.2.1` | Einspielen ohne Vorbereitung |
| **MINOR** | Neue Funktionen und Verbesserungen, rückwärtskompatibel; neue optionale Umgebungsvariablen; additive Migrationen | `v1.1.0` (Hardening), `v1.2.0` (Pilot-Release) | Changelog lesen, neue Variablen prüfen |
| **MAJOR** | Inkompatible Änderungen: Entfernen oder Ändern von API-Feldern/Endpunkten, Pflicht-Umgebungsvariablen, Änderungen, die manuelle Schritte erfordern | `v2.0.0` | Eigene Upgrade-Hinweise im Changelog, Vorankündigung an Restaurants mit API-Integration |

Die **API** ist zusätzlich im Pfad versioniert (`/api/v1`). Inkompatible API-Änderungen erscheinen unter einem neuen Pfad (`/api/v2`); `/api/v1` bleibt für eine angekündigte Übergangszeit (Empfehlung: mindestens 6 Monate) bestehen.

Die Anwendung wird als Ganzes versioniert: API-Image und Web-Image eines Releases tragen denselben Commit-SHA und werden immer gemeinsam ausgerollt.

## 2. Release-Upgrade (Standardfall)

### 2.1 Vorbereitung

1. **Changelog lesen.** `CHANGELOG.md` beschreibt für jede Version, *was* sich geändert hat und *warum*. Besonders beachten: Abschnitte zu Betrieb („Operations"), Sicherheit, Geld und Ledger, neue Einstellungen, geänderte Standardwerte.
2. **Neue Umgebungsvariablen erkennen:**

```bash
cd /opt/giftcard-pro
git fetch --tags
git diff <current-tag> <new-tag> -- backend/.env.production.example .env.production.example docker-compose.yml infra/

# variables present in the template but missing in your own file:
comm -23 <(git show <new-tag>:backend/.env.production.example | grep -o '^[A-Z0-9_]*=' | sort) \
         <(grep -o '^[A-Z0-9_]*=' backend/.env.production | sort)
```

Neue Variablen **vor** dem Deployment in `backend/.env.production` bzw. `.env.production` eintragen.

3. **Migrationen sichten:** `git diff --stat <current-tag> <new-tag> -- backend/database/migrations/`. Neue Migrationen auf lang laufende Operationen prüfen (z. B. Index auf `gift_card_transactions`) – solche Releases im Wartungsfenster ausrollen.
4. **Zeitpunkt wählen:** außerhalb der Servicezeiten (siehe [Wartungsanleitung](maintenance-guide.md#71-wartungsfenster)).
5. **Backup:**

```bash
docker compose --env-file .env.production --profile backup run --rm backup
```

Bei MAJOR-Releases oder umfangreichen Migrationen zusätzlich einen **Hetzner-Snapshot** anlegen.

### 2.2 Ausrollen

```bash
git tag v1.3.0 && git push --tags        # in the development repository
```

GitHub Actions (`deploy.yml`) baut die Images, wartet auf die Freigabe in der Environment `production` und führt `infra/scripts/deploy.sh` aus:

1. neue Images ziehen,
2. `api` neu starten → `migrate --force --isolated` und Referenz-Seeder,
3. `queue`, `scheduler`, `web`, `caddy` neu starten, `queue:restart`,
4. Healthcheck `/up` (bis zu 60 Sekunden).

Migrationen laufen damit **automatisch**. Ein manuelles `php artisan migrate` ist nicht nötig.

### 2.3 Prüfen

- Kontrollen nach dem Deployment aus der [Deployment-Anleitung](deployment-guide.md#8-kontrollen-nach-dem-deployment).
- `docker compose --env-file .env.production exec api php artisan migrate:status` – alle Migrationen `Ran`.
- Stichprobe der Ledger-Konsistenz (Abfrage 1 aus der [Restore-Anleitung](restore-guide.md#8-prüfabfragen-nach-einem-restore)).
- Bei Releases mit sichtbaren Änderungen: Restaurants kurz informieren (Wartungshinweis oder E-Mail) – bei Änderungen an der Kellner-App besonders, weil das Personal geschult ist.

### 2.4 Mehrere Versionen überspringen

Migrationen sind kumulativ; ein Sprung von `v1.1.0` auf `v1.3.0` ist technisch möglich. Aber:

- Das Expand-/Contract-Prinzip garantiert nur die Verträglichkeit zwischen **aufeinanderfolgenden** Releases. Ein Rollback ist nur auf das unmittelbar zuvor laufende Release sicher.
- Enthält der Changelog einer übersprungenen Version manuelle Schritte, diese in der angegebenen Reihenfolge ausführen.
- Empfehlung: MINOR-Versionen nacheinander einspielen, wenn eine davon Contract-Migrationen (Entfernen von Spalten) enthält.

## 3. Rollback-Strategie

| Situation | Vorgehen |
|---|---|
| Fehler in der Anwendung, Schema unverändert oder nur erweitert | Anwendung auf das vorherige Release zurückrollen ([Deployment-Anleitung](deployment-guide.md#9-rollback)): `IMAGE_TAG=<vorheriger-sha> ./infra/scripts/deploy.sh` nach `git checkout <vorheriger-sha>` |
| Migration fehlgeschlagen (Container `api` startet nicht) | Logs prüfen (`docker compose … logs api`). Die fehlgeschlagene Migration ist nicht als `Ran` markiert. Anwendung zurückrollen; Migration korrigieren und als Patch-Release neu ausrollen |
| Migration hat Daten falsch verändert | Kein `migrate:rollback` auf gut Glück. Betroffene Daten in einer Restore-Datenbank analysieren ([Restore-Anleitung, Szenario A](restore-guide.md#3-szenario-a--untersuchung-in-einer-restore-datenbank)); im Ernstfall Szenario B mit dem Backup von unmittelbar vor dem Deployment |
| Major-Upgrade von MySQL gescheitert | Siehe Abschnitt 4.3 – Rückweg ist der logische Dump |

Grundregeln:

- Migrationen werden so geschrieben, dass die **vorherige** Version mit dem **neuen** Schema läuft (expand → migrate → contract). Damit ist der Rollback der Anwendung ohne Schema-Rollback möglich.
- `down()`-Methoden von Migrationen werden in Produktion nur nach Prüfung und frischem Backup ausgeführt.
- Das Ledger wird nie durch einen Rollback „bereinigt". Buchungen, die mit der neuen Version entstanden sind, bleiben gültig.

## 4. Plattform-Upgrades (PHP, Node.js, MySQL, Redis, Caddy)

### 4.1 Wo die Versionen festgelegt sind

| Komponente | Aktuell | Festgelegt in |
|---|---|---|
| PHP | 8.4 | `backend/Dockerfile` (`FROM php:8.4-fpm-alpine`), `.github/workflows/ci.yml` (`php-version: "8.4"`), `backend/composer.json` (`"php": "^8.2"`) |
| Laravel | 12 | `backend/composer.json` (`"laravel/framework": "^12.0"`) |
| Node.js | 22 LTS | `dashboard/Dockerfile` (`FROM node:22-alpine`), `ci.yml` (`node-version: 22`), `dashboard/package.json` (`engines`) |
| Next.js | 15 | `dashboard/package.json` |
| MySQL | 8.4 LTS | `docker-compose.yml`, `docker-compose.dev.yml`, `ci.yml` (Service `mysql:8.4`) |
| Redis | 7.4 | `docker-compose.yml`, `docker-compose.dev.yml` |
| Caddy | 2.8 | `docker-compose.yml` |

Ein Neubau der Images übernimmt Patch-Versionen automatisch. Minor- und Major-Wechsel werden bewusst in allen genannten Dateien gemeinsam geändert, damit CI, Entwicklung und Produktion dieselbe Version testen.

### 4.2 PHP oder Node.js

1. Branch anlegen, Version in allen Dateien aus 4.1 anheben (z. B. `php:8.5-fpm-alpine` und `php-version: "8.5"`).
2. PHP: Erweiterungen im Dockerfile prüfen (`pdo_mysql intl gd zip bcmath opcache pcntl redis`), `composer update`, Deprecations im Testlauf beachten.
3. Node.js: nur LTS-Versionen verwenden; `npm ci`, `npm run build`.
4. CI muss vollständig grün sein (SQLite, MySQL, Larastan, Build).
5. Abnahmetest (`e2e/pilot-journey.mjs`) gegen den neuen Build.
6. Als MINOR- oder PATCH-Release ausrollen (für den Betrieb unsichtbar). Rollback wie jedes Release.

Laravel- oder Next.js-Major-Wechsel (z. B. Laravel 13, Next.js 16) sind eigene Entwicklungsvorhaben mit Upgrade-Leitfaden des jeweiligen Frameworks.

### 4.3 MySQL (Major- bzw. LTS-Wechsel)

MySQL aktualisiert das Datenverzeichnis beim ersten Start einer neueren Version automatisch; ein **Zurück auf die alte Version ist mit demselben Datenverzeichnis nicht möglich**. Deshalb:

1. Zielversion in `docker-compose.dev.yml` und `ci.yml` anheben, CI und lokale Tests grün.
2. Staging mit einer Kopie der Produktionsdaten (Restore aus Dump) auf der Zielversion testen, inklusive Prüfabfragen und Abnahmetest.
3. Produktion im Wartungsfenster:

```bash
cd /opt/giftcard-pro
alias dc='docker compose --env-file .env.production'
dc --profile backup run --rm backup                   # fresh dump = way back
# additionally create a Hetzner snapshot
dc stop queue scheduler api
# raise the mysql image version in docker-compose.yml (via release/Git), then:
dc pull mysql
dc up -d mysql
dc logs -f mysql                                      # wait for upgrade messages, "ready for connections"
dc up -d api && dc up -d queue scheduler web caddy
```

4. Prüfabfragen aus der [Restore-Anleitung](restore-guide.md#8-prüfabfragen-nach-einem-restore), Funktionsprüfung.
5. **Rückweg bei Problemen:** alte Image-Version wiederherstellen, Volume `mysql_data` durch ein neues, leeres ersetzen und den Dump aus Schritt 3 einspielen (Szenario B der Restore-Anleitung) – oder den Snapshot zurückspielen.

Alternative mit geringerem Risiko: neuen MySQL-Container mit der Zielversion und eigenem Volume parallel starten, Dump einspielen, prüfen und erst dann umschalten.

### 4.4 Redis und Caddy

- **Redis:** Minor-Updates innerhalb 7.x durch Anheben des Tags und `dc up -d redis`. Kurze Unterbrechung; Sessions und Queue bleiben durch AOF erhalten. Bei einem Major-Wechsel Kompatibilität der AOF-Datei laut Release Notes prüfen; im schlimmsten Fall ist Redis-Verlust verkraftbar (siehe [Backup-Anleitung](backup-guide.md#31-redis--was-ein-verlust-bedeutet)).
- **Caddy:** Tag anheben, `dc up -d caddy`. Zertifikate liegen im Volume `caddy_data` und bleiben erhalten. `infra/caddy/Caddyfile` gegen die Release Notes prüfen.

### 4.5 Betriebssystem

Sicherheitsupdates installiert `unattended-upgrades`. Ein Wechsel der Ubuntu-LTS-Version (z. B. 24.04 → 26.04) erfolgt am besten durch **Neuaufbau** eines Servers nach der [Deployment-Anleitung](deployment-guide.md) und Umzug der Daten (Dump + Restore, DNS-Umstellung) statt durch ein In-Place-Upgrade.

## 5. Checkliste Upgrade

- [ ] Changelog der Zielversion (und übersprungener Versionen) gelesen
- [ ] Neue Umgebungsvariablen eingetragen
- [ ] Migrationen gesichtet; lange Operationen → Wartungsfenster
- [ ] Wartungshinweis gesetzt (falls Unterbrechung erwartet)
- [ ] Backup erstellt, bei MAJOR zusätzlich Snapshot
- [ ] Abnahmetest der Zielversion bestanden
- [ ] Tag gesetzt, Deployment freigegeben
- [ ] `/up` = 200, `migrate:status` vollständig, Ledger-Stichprobe leer
- [ ] Funktionsprüfung (Scan, Testeinlösung, Storno)
- [ ] Wartungshinweis entfernt, Restaurants bei sichtbaren Änderungen informiert
- [ ] Upgrade im Betriebsprotokoll dokumentiert

---

Version 1.0 · Stand: September 2026
