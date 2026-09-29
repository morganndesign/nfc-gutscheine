# Upgrade-Anleitung

*Aktualisierung von GiftCard Pro auf neue Releases, Kellner-App-Versionen, Wechsel von Major-Versionen bei PHP, Node.js und MySQL, Rollback-Strategie und Versionierungsrichtlinie.*

---

## 1. Versionierung

GiftCard Pro folgt **Semantic Versioning** (`MAJOR.MINOR.PATCH`). Backend, Dashboard und Kellner-App tragen dieselbe Plattformversion (z. B. `2.0.0`; die App zusätzlich eine Build-Nummer, siehe [docs/MOBILE_RELEASE.md](../../MOBILE_RELEASE.md)).

| Teil | Wird erhöht bei | Folgen für den Betrieb |
|---|---|---|
| **PATCH** | Fehlerbehebungen, Sicherheitsupdates, Abhängigkeits- und Basis-Image-Updates ohne Verhaltensänderung | Einspielen ohne Vorbereitung |
| **MINOR** | Neue Funktionen und Verbesserungen, rückwärtskompatibel; neue optionale Umgebungsvariablen; additive Migrationen | Changelog lesen, neue Variablen prüfen |
| **MAJOR** | Inkompatible Änderungen: Entfernen oder Ändern von API-Feldern/Endpunkten, Pflicht-Umgebungsvariablen, Änderungen, die manuelle Schritte erfordern | Eigene Hinweise im Changelog, Vorankündigung an Lokale mit API-Integration |

Die **API** ist zusätzlich im Pfad versioniert (`/api/v1`). Inkompatible API-Änderungen erscheinen unter einem neuen Pfad (`/api/v2`) und werden den Lokalen mit Integration vorab angekündigt.

Server-Stack und Web-App werden als Ganzes versioniert: Coolify baut alle Images eines Deployments aus demselben Commit und rollt sie gemeinsam aus.

## 2. Release-Upgrade (Standardfall)

### 2.1 Vorbereitung

1. **Changelog lesen.** `CHANGELOG.md` beschreibt für jede Version, *was* sich geändert hat und *warum*. Besonders beachten: Betrieb, Sicherheit, Geld und Ledger, neue Einstellungen, geänderte Standardwerte.
2. **Neue Umgebungsvariablen erkennen:**

```bash
git diff <current-commit> <new-commit> -- .env.production.example docker-compose.coolify.yml infra/
```

Jede Variable hat im Compose-Stack einen funktionierenden Standard. Neue Werte, die Sie abweichend setzen möchten, **vor** dem Deployment in Coolify unter *Environment Variables* eintragen.

3. **Migrationen sichten:** `git diff --stat <current-commit> <new-commit> -- backend/database/migrations/`. Neue Migrationen auf lang laufende Operationen prüfen (z. B. ein Index auf `voucher_transactions` oder `audit_logs`) – solche Releases im Wartungsfenster ausrollen. Migrationen dürfen Ledger, Zahlungen und Audit-Log nie ändern (Append-only-Trigger).
4. **Zeitpunkt wählen:** außerhalb der Servicezeiten (siehe [Wartungsanleitung](maintenance-guide.md#71-wartungsfenster)).
5. **Backup:** manuelles Backup ([Backup-Anleitung](backup-guide.md), Abschnitt 2.2). Bei MAJOR-Releases oder umfangreichen Migrationen zusätzlich einen **Hetzner-Snapshot** anlegen.

### 2.2 Ausrollen

Merge bzw. Push auf `main` (oder *Redeploy* in Coolify). Coolify

1. baut die neuen Images aus dem Commit,
2. ersetzt die Container; der erste neue Laravel-Container führt offene Migrationen unter einer Redis-Sperre aus, `api` legt die Referenzdaten an,
3. `api`, `worker` und `scheduler` bedienen erst danach Anfragen.

Migrationen laufen damit **automatisch**. Ein manuelles `php artisan migrate` ist nicht nötig. Beim Austausch der Container gibt es wenige Sekunden Unterbrechung.

### 2.3 Prüfen

- Kontrollen nach dem Deployment aus der [Deployment-Anleitung](deployment-guide.md#8-kontrollen-nach-dem-deployment).
- Container **api**: `php artisan migrate:status` – alle Migrationen `Ran`.
- Container **api**: `php artisan giftcard:verify-chains` – ohne Befund.
- Stichprobe der Ledger-Konsistenz (Abfrage 1 aus der [Restore-Anleitung](restore-guide.md#8-prüfabfragen-nach-einem-restore)).
- Bei Releases mit sichtbaren Änderungen: Lokale kurz informieren (Wartungshinweis oder E-Mail) – bei Änderungen an der Kellner-App besonders, weil das Personal geschult ist.

### 2.4 Mehrere Versionen überspringen

Migrationen sind kumulativ; ein Sprung über mehrere MINOR-Versionen ist technisch möglich. Aber:

- Die Verträglichkeit von Anwendung und Schema ist nur zwischen **aufeinanderfolgenden** Releases zugesichert. Ein Rollback ist nur auf das unmittelbar zuvor laufende Release sicher.
- Enthält der Changelog einer übersprungenen Version manuelle Schritte, diese in der angegebenen Reihenfolge ausführen.
- Empfehlung: MINOR-Versionen nacheinander einspielen, wenn eine davon Spalten entfernt.

## 3. Kellner-App aktualisieren

- Neue Versionen erscheinen über Google Play und App Store (TestFlight für Tests); Ablauf in [docs/MOBILE_RELEASE.md](../../MOBILE_RELEASE.md).
- Die App fragt beim Start `GET /app/config` ab. Liegt ihre Version unter der Mindestversion (`app.min_version.android`, `app.min_version.ios` in den Systemeinstellungen), zeigt sie „Update required“ und öffnet den Store-Eintrag.
- Die Mindestversion erst anheben, wenn die neue Version in **beiden** Stores verfügbar ist: Plattformadministration → **System settings**.
- Backend zuerst ausrollen, wenn eine neue App-Version neue Endpunkte braucht. Gerätetokens bleiben bei einem App-Update gültig.

## 4. Rollback-Strategie

| Situation | Vorgehen |
|---|---|
| Fehler in der Anwendung, Schema unverändert oder nur erweitert | Anwendung auf das vorherige Deployment zurückrollen: Coolify → *Deployments* → früheres Deployment → *Redeploy* ([Deployment-Anleitung](deployment-guide.md#9-rollback)) |
| Migration fehlgeschlagen (Container `api` startet nicht) | Log prüfen (Ressource → *Logs*, Dienst `api`). Die fehlgeschlagene Migration ist nicht als `Ran` markiert. Anwendung zurückrollen; Migration korrigieren und als Patch-Release neu ausrollen |
| Migration hat Stammdaten falsch verändert | Kein `migrate:rollback` auf gut Glück. Betroffene Daten in einer Restore-Datenbank analysieren ([Restore-Anleitung, Szenario A](restore-guide.md#3-szenario-a--untersuchung-in-einer-restore-datenbank)); im Ernstfall Szenario B mit dem Backup von unmittelbar vor dem Deployment |
| Major-Upgrade von MySQL gescheitert | Siehe Abschnitt 5.3 – Rückweg ist der logische Dump |

Grundregeln:

- Schemaänderungen werden so geschrieben, dass die **vorherige** Version mit dem **neuen** Schema läuft (erst ergänzen, Code umstellen, erst im Folgerelease entfernen). Damit ist der Rollback der Anwendung ohne Schema-Rollback möglich.
- `down()`-Methoden von Migrationen werden in Produktion nur nach Prüfung und frischem Backup ausgeführt.
- Ledger, Zahlungen und Audit-Log werden nie durch einen Rollback „bereinigt“. Buchungen, die mit der neuen Version entstanden sind, bleiben gültig; die Hash-Ketten laufen weiter.

## 5. Plattform-Upgrades (PHP, Node.js, MySQL, Redis, Caddy)

### 5.1 Wo die Versionen festgelegt sind

| Komponente | Aktuell | Festgelegt in |
|---|---|---|
| PHP | 8.4 | `backend/Dockerfile` (`FROM php:8.4-fpm-alpine`), `.github/workflows/ci.yml`, `backend/composer.json` |
| Laravel | 12 | `backend/composer.json` (`"laravel/framework": "^12.0"`) |
| Node.js | 22 LTS | `dashboard/Dockerfile` (`FROM node:22-alpine`), `ci.yml`, `dashboard/package.json` (`engines`) |
| Next.js | 15 | `dashboard/package.json` |
| MySQL | 8.4 LTS | `docker-compose.coolify.yml`, `docker-compose.dev.yml`, `ci.yml` (Service `mysql:8.4`) |
| Redis | 7.4 | `docker-compose.coolify.yml`, `docker-compose.dev.yml` |
| Caddy (Gateway) | 2 | `infra/docker/gateway/Dockerfile` (`FROM caddy:2-alpine`) |
| Flutter (Kellner-App) | laut `waiter-app/pubspec.yaml` | `ci.yml`, `.github/workflows/testflight.yml` |

Jedes Deployment baut die Images neu und übernimmt Patch-Versionen automatisch. Minor- und Major-Wechsel werden bewusst in allen genannten Dateien gemeinsam geändert, damit CI, Entwicklung und Produktion dieselbe Version testen.

### 5.2 PHP oder Node.js

1. Branch anlegen, Version in allen Dateien aus 5.1 anheben (z. B. `php:8.5-fpm-alpine`).
2. PHP: Erweiterungen im Dockerfile prüfen, `composer update`, Deprecations im Testlauf beachten.
3. Node.js: nur LTS-Versionen verwenden; `npm ci`, `npm run build`.
4. CI muss vollständig grün sein (SQLite, MySQL mit Integritätsprüfung, Larastan, Builds, Coolify-Stack).
5. Abnahmetest (`e2e/pilot-journey.mjs`) gegen den neuen Build.
6. Als MINOR- oder PATCH-Release ausrollen (für den Betrieb unsichtbar). Rollback wie jedes Release.

Laravel- oder Next.js-Major-Wechsel (z. B. Laravel 13, Next.js 16) sind eigene Entwicklungsvorhaben mit dem Upgrade-Leitfaden des jeweiligen Frameworks.

### 5.3 MySQL (Major- bzw. LTS-Wechsel)

MySQL aktualisiert das Datenverzeichnis beim ersten Start einer neueren Version automatisch; ein **Zurück auf die alte Version ist mit demselben Datenverzeichnis nicht möglich**. Deshalb:

1. Zielversion in `docker-compose.dev.yml` und `ci.yml` anheben, CI und lokale Tests grün (inklusive der Append-only-Trigger und `giftcard:verify-chains`).
2. Staging mit einer Kopie der Produktionsdaten (Restore aus Dump) auf der Zielversion testen, inklusive Prüfabfragen und Abnahmetest.
3. Produktion im Wartungsfenster: frischen Dump ziehen (der Rückweg) und einen Hetzner-Snapshot anlegen; Wartungsmodus (`php artisan down`); Image-Version von `mysql` und `backup` in `docker-compose.coolify.yml` anheben und ausrollen; im Log von `mysql` auf die Upgrade-Meldungen und „ready for connections“ warten.
4. `php artisan giftcard:verify-chains`, Prüfabfragen aus der [Restore-Anleitung](restore-guide.md#8-prüfabfragen-nach-einem-restore), Funktionsprüfung.
5. **Rückweg bei Problemen:** alte Image-Version wiederherstellen, Volume `mysql-data` durch ein neues, leeres ersetzen und den Dump aus Schritt 3 einspielen (Szenario B der Restore-Anleitung) – oder den Snapshot zurückspielen.

Alternative mit geringerem Risiko: eine Staging-Ressource mit der Zielversion aufsetzen, Dump einspielen, prüfen und erst dann die Produktion umstellen.

### 5.4 Redis und Caddy

- **Redis:** Minor-Updates innerhalb 7.x durch Anheben des Tags und Neuausrollen. Kurze Unterbrechung; Sessions und Queue bleiben durch AOF erhalten. Bei einem Major-Wechsel Kompatibilität der AOF-Datei laut Release Notes prüfen; im schlimmsten Fall ist Redis-Verlust verkraftbar (siehe [Backup-Anleitung](backup-guide.md#31-redis--was-ein-verlust-bedeutet)).
- **Caddy (Gateway):** Das Gateway terminiert kein TLS (das macht der Coolify-Proxy) und hat keine Zertifikate. `infra/docker/gateway/Caddyfile` bei Major-Wechseln gegen die Release Notes prüfen, besonders die Filter, die Tokens und Header aus den Logs entfernen.

### 5.5 Betriebssystem und Coolify

Sicherheitsupdates installiert `unattended-upgrades`. Coolify selbst über dessen Oberfläche aktualisieren (vorher Snapshot). Ein Wechsel der Ubuntu-LTS-Version (z. B. 24.04 → 26.04) erfolgt am besten durch **Neuaufbau** eines Servers nach der [Deployment-Anleitung](deployment-guide.md) und Umzug der Daten (Dump + Restore, DNS-Umstellung) statt durch ein In-Place-Upgrade.

## 6. Checkliste Upgrade

- [ ] Changelog der Zielversion (und übersprungener Versionen) gelesen
- [ ] Neue Umgebungsvariablen geprüft und bei Bedarf in Coolify eingetragen
- [ ] Migrationen gesichtet; lange Operationen → Wartungsfenster
- [ ] Wartungshinweis gesetzt (falls Unterbrechung erwartet)
- [ ] Backup erstellt, bei MAJOR zusätzlich Snapshot
- [ ] Abnahmetest der Zielversion bestanden
- [ ] Deployment ausgerollt
- [ ] `/up` = 200, `migrate:status` vollständig, `giftcard:verify-chains` ohne Befund
- [ ] Funktionsprüfung (QR-Scan, Testeinlösung, Storno)
- [ ] Mindestversion der Kellner-App erst angehoben, wenn die neue App in beiden Stores ist
- [ ] Wartungshinweis entfernt, Lokale bei sichtbaren Änderungen informiert
- [ ] Upgrade im Betriebsprotokoll dokumentiert

---

Version 2.0 · Stand: September 2026
