# Wartungsanleitung

*Wiederkehrende Betriebsaufgaben für GiftCard Pro – täglich, wöchentlich, monatlich, quartalsweise – sowie Wartungsfenster, Wartungshinweis und Aktualisierung von Abhängigkeiten.*

---

## 1. Grundsätze

- Wartung findet **außerhalb der Servicezeiten** der Lokale statt (siehe Abschnitt 7).
- Vor jedem Eingriff, der Daten oder Schema betrifft: **manuelles Backup** ([Backup-Anleitung](backup-guide.md), Abschnitt 2.2).
- Jede Wartung wird kurz protokolliert: Datum, Person, Tätigkeit, Ergebnis. Vorlage: `[Link zum Betriebsprotokoll]`.
- Was automatisch läuft, wird trotzdem regelmäßig **kontrolliert**.
- Ledger, Zahlungen und Audit-Log werden nie per SQL geändert; Korrekturen sind neue Einträge in der Anwendung.

Befehle laufen im Coolify-*Terminal* der Ressource (Container **api** für `php artisan …`, **backup** für `mysql`/`mysqldump`) oder, wo angegeben, am Server als root.

## 2. Was automatisch läuft

| Aufgabe | Mechanismus | Zeit |
|---|---|---|
| Abgelaufene Gutscheine auf `expired` setzen (Guthaben bleibt) | Scheduler `vouchers:expire` | täglich 00:15 (Wien) |
| Integritätsprüfung: Hash-Ketten und Guthaben | Scheduler `giftcard:verify-chains` | täglich 02:30 (Wien) |
| Fehlgeschlagene Jobs älter als 30 Tage entfernen | Scheduler `queue:prune-failed --hours=720` | täglich 03:30 (Wien) |
| Erinnerungs-E-Mails vor Ablauf | Scheduler `vouchers:notify-expiring` | täglich 10:00 (Wien) |
| Abgelaufene Passwort-Reset-Tokens entfernen | Scheduler `auth:clear-resets` | alle 15 Minuten |
| Queue-Länge prüfen | Scheduler `queue:monitor … --max=500` | alle 5 Minuten |
| Datenbank-Backup | Dienst `backup` | täglich `BACKUP_TIME` (Standard 01:30 UTC) |
| Off-site-Sync | Root-Cron am Server (`rclone`) | täglich nach dem Backup |
| Server-Snapshot | Hetzner Backups | täglich |
| TLS-Zertifikat erneuern | Coolify-Proxy (Let's Encrypt), automatisch vor Ablauf | laufend |
| Sicherheitsupdates des Betriebssystems | `unattended-upgrades` | täglich |
| Log-Rotation der Container | Docker `json-file`, 5 × 10 MB | laufend |
| Abhängigkeitsprüfung | `composer audit`, `npm audit` in `ci.yml` | bei jedem Push und Pull Request |

## 3. Täglich (ca. 5 Minuten)

- [ ] Uptime-Monitor ohne Vorfälle; in Coolify alle acht Dienste *healthy*
- [ ] Keine Warn-E-Mail an `OPS_ALERT_EMAIL` (Integritätsprüfung, Queue-Rückstau)
- [ ] Backup von heute vorhanden und off-site (Log des Dienstes `backup`: „Backup written“; `rclone ls storagebox:giftcard-backups | tail -3`)
- [ ] Sicherheitsereignisse der letzten 24 h: Log `api` nach „Account locked“; im Audit-Log `presentment.failed` und `auth.locked`
- [ ] Fehlgeschlagene Jobs: `php artisan queue:failed`
- [ ] Support-Postfach auf Meldungen der Lokale geprüft

Details: [Monitoring-Leitfaden](monitoring-guide.md#12-bereitschaftsroutine).

## 4. Wöchentlich (ca. 30 Minuten, z. B. Dienstag vormittags)

| Aufgabe | Befehl / Ort |
|---|---|
| Festplatte und Docker-Speicher | am Server: `df -h`, `docker system df` |
| Nicht mehr benötigte Images entfernen | am Server: `docker image prune -f` |
| Neustart nach Kernel-Update nötig? | `ls /var/run/reboot-required` – falls vorhanden, Neustart im Wartungsfenster |
| Nächtliche Jobs gelaufen | `php artisan schedule:list`; Log `scheduler`; Ergebnis von `giftcard:verify-chains` |
| Sicherheitsereignisse der Woche auswerten | `presentment.failed`/`presentment.rejected` je Lokal und Gerät (Abfrage im [Monitoring-Leitfaden](monitoring-guide.md#7-sicherheitsereignisse-im-log)); auffällige Lokale kontaktieren |
| Letzte CI-Läufe auf `main` | GitHub Actions: `composer audit` und `npm audit` grün? |
| Offene Sicherheitshinweise der Abhängigkeiten | GitHub → Security (sofern aktiviert) |

## 5. Monatlich (ca. 2 Stunden)

### 5.1 Test-Restore

Einen aktuellen Dump in eine separate Datenbank einspielen und die Prüfabfragen ausführen – Vorgehen: [Restore-Anleitung, Szenario A](restore-guide.md#3-szenario-a--untersuchung-in-einer-restore-datenbank). Ergebnis protokollieren (Datei, Dauer, Prüfabfragen leer).

### 5.2 API-Tokens mit baldigem Ablauf

Integrationstokens laufen nach höchstens `API_TOKEN_MAX_DAYS` (365) Tagen ab. Läuft das Token einer Kassenintegration unbemerkt ab, schlägt die Integration fehl.

```sql
SELECT r.name AS restaurant, t.name AS token, t.expires_at, t.last_used_at
FROM personal_access_tokens t
JOIN restaurants r ON r.id = t.restaurant_id
WHERE t.revoked_at IS NULL AND t.device_id IS NULL
  AND t.expires_at < NOW() + INTERVAL 30 DAY
ORDER BY t.expires_at;
```

Betroffene Lokale informieren, damit sie rechtzeitig unter **Settings → API** ein neues Token anlegen und das alte widerrufen. Ungenutzte Tokens (`last_used_at` leer oder älter als 90 Tage) zum Widerruf empfehlen. Gerätetokens der Kellner-App (`device_id` gesetzt) verlängern sich selbst, solange das Telefon genutzt wird.

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
- Lokale auf nicht angenommene Einladungen hinweisen (**⋯ → Invite again** in der Plattformadministration).
- Lokalen empfehlen, unter **Team** ausgeschiedene Mitarbeitende zu deaktivieren und unter **Devices** unbekannte Geräte zu widerrufen.

### 5.4 Plattform-Audit

In der Plattformadministration das Audit-Log des Monats sichten: Anlegen, Sperren, Archivieren und Löschen von Lokalen, erneute Einladungen, Änderungen an Systemeinstellungen, widerrufene Tokens.

### 5.5 Zertifikat, Speicher, Datenbank

- Zertifikatslaufzeit prüfen (erneuert der Coolify-Proxy automatisch; bei < 14 Tagen stimmt etwas nicht): `echo | openssl s_client -connect app.giftcardpro.at:443 -servername app.giftcardpro.at 2>/dev/null | openssl x509 -noout -enddate`
- MySQL-Binärlogs belegen Platz im Volume `mysql-data`: `SHOW BINARY LOGS;` – bei Platzmangel Aufbewahrung (`binlog_expire_logs_seconds`) prüfen.
- Größe der großen Tabellen beobachten (Ledger, Zahlungen, Audit-Log und Vorlagen wachsen stetig):

```sql
SELECT table_name, ROUND((data_length + index_length) / 1024 / 1024) AS mb, table_rows
FROM information_schema.tables WHERE table_schema = DATABASE()
ORDER BY (data_length + index_length) DESC LIMIT 10;
```

### 5.6 Basis-Images aktualisieren

Jedes Deployment baut die Images neu und übernimmt dabei Patch-Updates von PHP 8.4, Node 22, Caddy und Alpine. Empfehlung: mindestens monatlich neu ausrollen (*Redeploy* genügt), sonst bleiben bekannte Lücken der Basis-Images offen. Auch `mysql:8.4` und `redis:7.4-alpine` werden dabei neu gezogen. Im Wartungsfenster ausführen – der Neustart von MySQL und Redis unterbricht den Dienst für einige Sekunden.

## 6. Quartalsweise (ca. ½ Tag)

| Aufgabe | Details |
|---|---|
| Abhängigkeiten aktualisieren | Abschnitt 8 |
| Wiederherstellungsübung Totalverlust | [Restore-Anleitung, Szenario C](restore-guide.md#5-szenario-c--totalverlust-des-servers) auf einem separaten Server durchspielen, Zeit messen (RTO), Server danach löschen |
| Zugänge prüfen | SSH-Schlüssel am Server, Coolify-Konten, Mitglieder der GitHub-Organisation und die GitHub-App von Coolify, Zugang zu Hetzner Console und Storage Box |
| Secrets | Passwortmanager auf Vollständigkeit prüfen (`APP_KEY`, SMTP-Zugangsdaten, `rclone`-Konfiguration); App-Store-Connect-Schlüssel und Android-Signaturschlüssel vorhanden |
| Firewall | nur 22 (eigene IPs), 80, 443 |
| Kapazität | RAM-, CPU- und Festplattentrend der letzten 3 Monate; Serverwechsel planen, bevor 70 % erreicht werden |
| Dokumentation | Diese Anleitungen mit dem tatsächlichen Stand abgleichen |
| Aufbewahrung | Backups, Log-Versand, Audit-Log gegen die Vorgaben der [Backup-Anleitung](backup-guide.md#7-aufbewahrung) und des [Logging-Leitfadens](logging-guide.md#9-aufbewahrung-und-dsgvo) |

## 7. Wartungsfenster und Wartungshinweis

### 7.1 Wartungsfenster

| Art | Zeitfenster (Wiener Zeit) | Vorankündigung |
|---|---|---|
| Deployment (wenige Sekunden Unterbrechung) | Mo–Do vor 11:00 oder 14:30–17:00 | keine (Changelog) |
| Wartung mit kurzer Unterbrechung (< 5 min) | Di oder Mi 06:00–07:00 | 3 Werktage vorher per Wartungshinweis |
| Wartung mit längerer Unterbrechung | Di oder Mi 06:00–08:00 | 7 Tage vorher per Wartungshinweis und E-Mail an alle Inhaberinnen und Inhaber |
| Notfallwartung | sofort | so früh wie möglich |

Nicht warten: Freitag bis Sonntag, an Feiertagen, um 00:15 (Gutscheinablauf), 02:30 (Integritätsprüfung) und in der Adventzeit nur im Notfall.

### 7.2 Wartungshinweis in der App

Die Plattform hat die Systemeinstellung `platform.maintenance_notice`: ein Banner, das **jeder angemeldeten Person** angezeigt wird, und der Wert `maintenance_notice` in `/app/config` für die Kellner-App. Leer = kein Banner.

**Über die Oberfläche:** Plattformadministration → **System settings** → Maintenance notice → Text eintragen → speichern.

**Über die API:**

```bash
curl -X PUT https://app.giftcardpro.at/api/v1/admin/system-settings \
  -b jar.txt -H "X-XSRF-TOKEN: $XSRF" -H "Accept: application/json" -H "Content-Type: application/json" \
  -d '{"settings":[{"key":"platform.maintenance_notice","value":"Geplante Wartung am Dienstag, 14. Oktober 2026, 06:00–06:30 Uhr. In dieser Zeit ist GiftCard Pro kurz nicht erreichbar."}]}'
```

(Browser-Session eines Plattform-Administrators; Anmeldung wie in der [API-Dokumentation](api-documentation.md#106-browser-login-zu-testzwecken).)

Formulierung: Datum, Uhrzeit, erwartete Auswirkung, ein Satz. Das Personal der Lokale liest den Hinweis in der Kellner-App – kurz halten. Nach der Wartung den Text wieder leeren.

### 7.3 Laravel-Wartungsmodus

`php artisan down` versetzt die API in den Wartungsmodus (HTTP 503 für alle API-Aufrufe **einschließlich `/up`** – Uptime-Monitor vorher pausieren). Im Container **api**:

```bash
php artisan down --retry=60
# … maintenance …
php artisan up
```

Da `APP_MAINTENANCE_DRIVER` in Produktion nicht gesetzt ist (Standard `file`), gilt der Modus nur für den `api`-Container und endet, wenn dieser neu erstellt wird (z. B. durch *Redeploy*). In den meisten Fällen genügen Wartungshinweis und ein kurzer Neustart; der Wartungsmodus ist für längere Eingriffe an der Datenbank gedacht.

## 8. Abhängigkeiten aktualisieren

### 8.1 Laufend (CI)

`ci.yml` führt bei jedem Push auf `main` und jedem Pull Request `composer audit` und `npm audit --omit=dev --audit-level=high` aus. Ein roter Lauf blockiert das Release, bis die Lücke behoben ist.

Da CI nur bei Änderungen läuft, werden neu bekannt gewordene Lücken in unveränderten Abhängigkeiten nicht automatisch gemeldet. Empfehlungen:

- Wöchentlich den CI-Workflow manuell anstoßen oder lokal `composer audit` und `npm audit` ausführen.
- GitHub Dependabot (Security Updates) für `backend/` (Composer), `dashboard/` und `e2e/` (npm), `waiter-app/` (pub) sowie die Dockerfiles aktivieren.

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
npm run lint && npm run typecheck && npm test && npm run build && npm audit --omit=dev --audit-level=high

cd ../e2e && npm update
```

- Innerhalb der Major-Versionen aktualisieren (Laravel 12, Next.js 15). Major-Wechsel sind eigene Vorhaben – siehe [Upgrade-Anleitung](upgrade-guide.md).
- Pull Request erstellen; CI muss auf SQLite **und** MySQL grün sein, einschließlich der Integritätsprüfung.
- Vor dem Release den Abnahmetest ausführen.
- Als Patch- oder Minor-Release ausrollen und im Changelog vermerken.

## 9. Speicherplatz freigeben

| Verursacher | Prüfen | Maßnahme |
|---|---|---|
| Alte Docker-Images und Build-Cache | `docker system df` | `docker image prune -f`, `docker builder prune -f` (Coolify baut jedes Deployment neu) |
| Lokale Dumps | Volume `mysql-backups` | werden nach `BACKUP_KEEP_DAYS` automatisch gelöscht |
| MySQL-Binärlogs | `SHOW BINARY LOGS;` | `PURGE BINARY LOGS BEFORE NOW() - INTERVAL 7 DAY;` (nur wenn nicht für Point-in-Time-Recovery benötigt) |
| Container-Logs | `du -sh /var/lib/docker/containers` | begrenzt auf 50 MB je Container |
| Journal des Systems | `journalctl --disk-usage` | `journalctl --vacuum-time=30d` |

## 10. Jährlich

- SSH-Schlüssel und Storage-Box-Schlüssel erneuern.
- Auftragsverarbeitungsverträge und Sub-Auftragsverarbeiter-Liste mit der tatsächlichen Infrastruktur abgleichen.
- Notfallkontakte und Bereitschaftsplan aktualisieren.
- Wiederherstellungsübung mit vollständigem Protokoll (RPO, RTO, Ergebnis von `giftcard:verify-chains`) als Nachweis für die TOM.

---

Version 2.0 · Stand: September 2026
