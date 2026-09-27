# Wartungsanleitung

*Wiederkehrende Betriebsaufgaben für GiftCard Pro – täglich, wöchentlich, monatlich, quartalsweise – sowie Wartungsfenster, Wartungshinweis und Aktualisierung von Abhängigkeiten.*

---

## 1. Grundsätze

- Wartung findet **außerhalb der Servicezeiten** der Restaurants statt (siehe Abschnitt 6).
- Vor jedem Eingriff, der Daten oder Schema betrifft: **manuelles Backup** (`docker compose --env-file .env.production --profile backup run --rm backup`).
- Jede Wartung wird kurz protokolliert: Datum, Person, Tätigkeit, Ergebnis. Vorlage: `[Link zum Betriebsprotokoll]`.
- Was automatisch läuft, wird trotzdem regelmäßig **kontrolliert**.

Abkürzung für alle Befehle (auf dem Server als `deploy`):

```bash
cd /opt/giftcard-pro
alias dc='docker compose --env-file .env.production'
```

## 2. Was automatisch läuft

| Aufgabe | Mechanismus | Zeit |
|---|---|---|
| Abgelaufene Karten ausbuchen | Scheduler `giftcards:expire` | täglich 00:15 (Wien) |
| Erinnerungs-E-Mails vor Ablauf | Scheduler `giftcards:notify-expiring` | täglich 10:00 (Wien) |
| Fehlgeschlagene Jobs älter als 30 Tage entfernen | Scheduler `queue:prune-failed --hours=720` | täglich 03:30 (Wien) |
| Abgelaufene Passwort-Reset-Tokens entfernen | Scheduler `auth:clear-resets` | alle 15 Minuten |
| Queue-Länge prüfen | Scheduler `queue:monitor … --max=500` | alle 5 Minuten |
| Datenbank-Backup | Cron `deploy` | täglich 02:30 (Serverzeit) |
| Off-site-Sync | Cron `deploy` | täglich 02:45 (Serverzeit) |
| Server-Snapshot | Hetzner Backups | täglich |
| TLS-Zertifikat erneuern | Caddy (Let's Encrypt), automatisch vor Ablauf | laufend |
| Sicherheitsupdates des Betriebssystems | `unattended-upgrades` | täglich |
| Log-Rotation der Container | Docker `json-file`, 5 × 20 MB | laufend |
| Abhängigkeitsprüfung | `composer audit`, `npm audit` in `ci.yml` | bei jedem Push und Pull Request |

## 3. Täglich (ca. 5 Minuten)

- [ ] Uptime-Monitor ohne Vorfälle; Container gesund: `dc ps`
- [ ] Backup von heute vorhanden und off-site: `ls -lh backups | tail -3`, `rclone ls storagebox:giftcard-backups | tail -3`
- [ ] Sicherheitsereignisse der letzten 24 h: `dc logs --since 24h api | grep -E "Suspicious gift card scan|Account locked"`
- [ ] Fehlgeschlagene Jobs: `dc exec api php artisan queue:failed`
- [ ] Support-Postfach auf Meldungen der Restaurants geprüft

Details: [Monitoring-Leitfaden](monitoring-guide.md#12-bereitschaftsroutine).

## 4. Wöchentlich (ca. 30 Minuten, z. B. Dienstag vormittags)

| Aufgabe | Befehl / Ort |
|---|---|
| Festplatte und Docker-Speicher | `df -h`, `docker system df` |
| Nicht mehr benötigte Images entfernen | `docker image prune -f` (geschieht auch nach jedem Deployment) |
| Neustart nach Kernel-Update nötig? | `ls /var/run/reboot-required` – falls vorhanden, Neustart im Wartungsfenster |
| Nächtliche Jobs gelaufen | `dc exec scheduler php artisan schedule:list`; `expiration`-Buchungen im Ledger (siehe Monitoring-Leitfaden) |
| Sicherheitsereignisse der Woche auswerten | `nfc_scans` nach Ergebnis und Restaurant (Abfrage im [Monitoring-Leitfaden](monitoring-guide.md#7-sicherheitsereignisse-im-log)); auffällige Restaurants kontaktieren |
| Letzte CI-Läufe auf `main` | GitHub Actions: `composer audit` und `npm audit` grün? |
| Offene Sicherheitshinweise der Abhängigkeiten | GitHub → Security (sofern aktiviert) |

## 5. Monatlich (ca. 2 Stunden)

### 5.1 Test-Restore

Einen aktuellen Dump in eine separate Datenbank einspielen und die Prüfabfragen ausführen – Vorgehen: [Restore-Anleitung, Szenario A](restore-guide.md#3-szenario-a--untersuchung-in-einer-restore-datenbank). Ergebnis protokollieren (Datei, Dauer, Ledger-Prüfung leer).

### 5.2 API-Tokens mit baldigem Ablauf

API-Tokens laufen nach höchstens 365 Tagen ab. Läuft das Token einer Kassenintegration unbemerkt ab, schlägt die Integration fehl.

```sql
SELECT r.name AS restaurant, t.name AS token, t.expires_at, t.last_used_at
FROM personal_access_tokens t
JOIN restaurants r ON r.id = t.restaurant_id
WHERE t.revoked_at IS NULL
  AND t.expires_at < NOW() + INTERVAL 30 DAY
ORDER BY t.expires_at;
```

Betroffene Restaurants informieren, damit sie rechtzeitig unter **Settings → API** ein neues Token anlegen und das alte widerrufen. Ungenutzte Tokens (`last_used_at` leer oder älter als 90 Tage) zum Widerruf empfehlen.

### 5.3 Benutzer- und Gerätereview

```sql
-- invitations not accepted for more than 7 days
SELECT r.name, u.name, u.email, u.created_at
FROM users u LEFT JOIN restaurants r ON r.id = u.restaurant_id
WHERE u.last_login_at IS NULL AND u.created_at < NOW() - INTERVAL 7 DAY AND u.deleted_at IS NULL;

-- currently locked accounts
SELECT u.email, u.locked_until, u.failed_login_attempts FROM users u WHERE u.locked_until > NOW();

-- platform administrators (should be named persons only)
SELECT u.name, u.email, u.last_login_at FROM users u WHERE u.restaurant_id IS NULL AND u.deleted_at IS NULL;
```

- Plattform-Administratoren, die nicht mehr im Team sind: deaktivieren.
- Restaurants auf nicht angenommene Einladungen hinweisen (**Resend invitation**).
- Restaurants empfehlen, unter **Team** ausgeschiedene Mitarbeitende zu deaktivieren und unter **Devices** unbekannte Geräte zu widerrufen.

### 5.4 Plattform-Audit

In der Plattformadministration das Audit-Log des Monats sichten: „Open restaurant"-Sitzungen der Plattform-Administratoren (Grund bekannt?), Sperren und Reaktivierungen von Restaurants, Änderungen an Systemeinstellungen.

### 5.5 Zertifikat, Speicher, Datenbank

- Zertifikatslaufzeit prüfen (erneuert Caddy automatisch; bei < 14 Tagen stimmt etwas nicht): `echo | openssl s_client -connect app.giftcardpro.at:443 -servername app.giftcardpro.at 2>/dev/null | openssl x509 -noout -enddate`
- MySQL-Binärlogs belegen Platz im Volume `mysql_data`: `SHOW BINARY LOGS;` – bei Platzmangel Aufbewahrung (`binlog_expire_logs_seconds`) prüfen.
- Größe der großen Tabellen beobachten:

```sql
SELECT table_name, ROUND((data_length + index_length) / 1024 / 1024) AS mb, table_rows
FROM information_schema.tables WHERE table_schema = 'giftcard_pro'
ORDER BY (data_length + index_length) DESC LIMIT 10;
```

### 5.6 Basis-Images aktualisieren

Ein neues Release (auch ohne Codeänderung, z. B. Patch-Version) baut die Images neu und übernimmt dabei Patch-Updates von PHP 8.4, Node 22 und Alpine. Empfehlung: mindestens monatlich ein Release, sonst bleiben bekannte Lücken der Basis-Images offen. Die Images von `mysql:8.4`, `redis:7.4-alpine` und `caddy:2.8-alpine` aktualisieren sich mit:

```bash
dc pull mysql redis caddy
dc up -d mysql redis caddy
```

Im Wartungsfenster ausführen – der Neustart von MySQL und Redis unterbricht den Dienst für einige Sekunden.

## 6. Quartalsweise (ca. ½ Tag)

| Aufgabe | Details |
|---|---|
| Abhängigkeiten aktualisieren | Abschnitt 8 |
| Wiederherstellungsübung Totalverlust | [Restore-Anleitung, Szenario C](restore-guide.md#5-szenario-c--totalverlust-des-servers) in einem separaten Hetzner-Projekt durchspielen, Zeit messen (RTO), Server danach löschen |
| Zugänge prüfen | SSH-Schlüssel in `~deploy/.ssh/authorized_keys`, Mitglieder der GitHub-Organisation, Reviewer der Environment `production`, Zugang zu Hetzner Console und Storage Box |
| Secrets | `GHCR_READ_TOKEN` erneuern (Ablaufdatum des PAT), Passwortmanager auf Vollständigkeit prüfen (`APP_KEY`, NTAG-424-Schlüssel, `.env`-Inhalte, `rclone`-Konfiguration) |
| Firewall | Hetzner Cloud Firewall: nur 22 (eigene IPs), 80, 443 |
| Kapazität | RAM-, CPU- und Festplattentrend der letzten 3 Monate; Serverwechsel planen, bevor 70 % erreicht werden |
| Dokumentation | Diese Anleitungen mit dem tatsächlichen Stand abgleichen |
| Aufbewahrung | Backups, Log-Versand, Audit-Log gegen die Vorgaben der [Backup-Anleitung](backup-guide.md#7-aufbewahrung) und des [Logging-Leitfadens](logging-guide.md#9-aufbewahrung-und-dsgvo) |

## 7. Wartungsfenster und Wartungshinweis

### 7.1 Wartungsfenster

| Art | Zeitfenster (Wiener Zeit) | Vorankündigung |
|---|---|---|
| Deployment ohne Ausfall | Mo–Do vor 11:00 oder 14:30–17:00 | keine (Changelog) |
| Wartung mit kurzer Unterbrechung (< 5 min) | Di oder Mi 06:00–07:00 | 3 Werktage vorher per Wartungshinweis |
| Wartung mit längerer Unterbrechung | Di oder Mi 06:00–08:00 | 7 Tage vorher per Wartungshinweis und E-Mail an alle Inhaberinnen und Inhaber |
| Notfallwartung | sofort | so früh wie möglich |

Nicht warten: Freitag bis Sonntag, an Feiertagen, zwischen 00:00 und 00:30 (Kartenablauf) und in der Adventzeit nur im Notfall.

### 7.2 Wartungshinweis in der App

Die Plattform hat die Systemeinstellung `platform.maintenance_notice`: ein Banner, das **jeder angemeldeten Person** angezeigt wird. Leer = kein Banner.

**Über die Oberfläche:** Plattformadministration → **System settings** → Maintenance notice → Text eintragen → speichern.

**Über die API:**

```bash
curl -X PUT https://app.giftcardpro.at/api/v1/admin/system-settings \
  -b jar.txt -H "X-XSRF-TOKEN: $XSRF" -H "Accept: application/json" -H "Content-Type: application/json" \
  -d '{"settings":[{"key":"platform.maintenance_notice","value":"Geplante Wartung am Dienstag, 14. Oktober 2026, 06:00–06:30 Uhr. In dieser Zeit ist GiftCard Pro kurz nicht erreichbar."}]}'
```

(Browser-Session eines Plattform-Administrators; Anmeldung wie in der [API-Dokumentation](api-documentation.md#96-browser-login-zu-testzwecken).)

Formulierung: Datum, Uhrzeit, erwartete Auswirkung, ein Satz. Das Personal der Restaurants liest den Hinweis in der Kellner-App – kurz halten. Nach der Wartung den Text wieder leeren.

### 7.3 Laravel-Wartungsmodus

`php artisan down` versetzt die API in den Wartungsmodus (HTTP 503 für alle API-Aufrufe **einschließlich `/up`** – Uptime-Monitor vorher pausieren):

```bash
dc exec api php artisan down --retry=60
# … maintenance …
dc exec api php artisan up
```

Da `APP_MAINTENANCE_DRIVER` in Produktion nicht gesetzt ist (Standard `file`), gilt der Modus nur für den `api`-Container und endet, wenn dieser neu erstellt wird. In den meisten Fällen genügen Wartungshinweis und ein kurzer Neustart; der Wartungsmodus ist für längere Eingriffe an der Datenbank gedacht.

## 8. Abhängigkeiten aktualisieren

### 8.1 Laufend (CI)

`ci.yml` führt bei jedem Push auf `main` und jedem Pull Request `composer audit` und `npm audit --omit=dev --audit-level=high` aus. Ein roter Lauf blockiert das Release, bis die Lücke behoben ist.

Da CI nur bei Änderungen läuft, werden neu bekannt gewordene Lücken in unveränderten Abhängigkeiten nicht automatisch gemeldet. Empfehlungen:

- Wöchentlich den CI-Workflow manuell anstoßen oder lokal `composer audit` und `npm audit` ausführen.
- GitHub Dependabot (Security Updates) für `backend/` (Composer), `dashboard/` und `e2e/` (npm) sowie die Dockerfiles aktivieren (derzeit nicht eingerichtet).

### 8.2 Quartalsweise Aktualisierung

```bash
git checkout -b chore/dependencies-2026-q4

cd backend
composer outdated --direct
composer update --with-all-dependencies
php artisan test && vendor/bin/phpstan analyse && vendor/bin/pint --test

cd ../dashboard
npm outdated
npm update
npm run lint && npm run typecheck && npm run build && npm audit --omit=dev --audit-level=high

cd ../e2e && npm update
```

- Innerhalb der Major-Versionen aktualisieren (Laravel 12, Next.js 15). Major-Wechsel sind eigene Vorhaben – siehe [Upgrade-Anleitung](upgrade-guide.md).
- Pull Request erstellen; CI muss auf SQLite **und** MySQL grün sein.
- Vor dem Release den Abnahmetest ausführen.
- Als Patch- oder Minor-Release ausrollen und im Changelog vermerken.

## 9. Speicherplatz freigeben

| Verursacher | Prüfen | Maßnahme |
|---|---|---|
| Alte Docker-Images | `docker system df` | `docker image prune -f` (bzw. `docker image prune -a` für alle nicht verwendeten Images – danach sind Rollback-Images nur noch in GHCR) |
| Lokale Dumps | `du -sh backups` | werden nach 14 Tagen automatisch gelöscht |
| MySQL-Binärlogs | `SHOW BINARY LOGS;` | `PURGE BINARY LOGS BEFORE NOW() - INTERVAL 7 DAY;` (nur wenn nicht für Point-in-Time-Recovery benötigt) |
| Container-Logs | `du -sh /var/lib/docker/containers` | begrenzt auf 100 MB je Container |
| Journal des Systems | `journalctl --disk-usage` | `sudo journalctl --vacuum-time=30d` |
| Backup-Log | `ls -lh /var/log/giftcard-backup.log` | logrotate-Regel ergänzen |

## 10. Jährlich

- Deploy-SSH-Schlüssel und Storage-Box-Schlüssel erneuern.
- Auftragsverarbeitungsverträge und Sub-Auftragsverarbeiter-Liste mit der tatsächlichen Infrastruktur abgleichen.
- Notfallkontakte und Bereitschaftsplan aktualisieren.
- Wiederherstellungsübung mit vollständigem Protokoll (RPO, RTO) als Nachweis für die TOM.

---

Version 1.0 · Stand: September 2026
