# Monitoring-Leitfaden

*Überwachung von GiftCard Pro im Produktivbetrieb: Healthcheck, Uptime, Container, Queue, Scheduler, Integritätsprüfung, Kennzahlen, Alarmregeln, Dashboards und Bereitschaftsroutine.*

---

## 1. Ziele

Die Kellner-App und die Web-Kassa werden während des Service verwendet. Ein Ausfall am Freitagabend bedeutet, dass Gäste ihren Gutschein nicht einlösen können. Das Monitoring soll deshalb:

1. einen Ausfall innerhalb von 2 Minuten melden,
2. Missbrauchsversuche (erratene oder kopierte QR-Codes, Passwortangriffe) und jede Manipulation der Finanzhistorie sichtbar machen,
3. schleichende Probleme (volle Festplatte, wachsende Queue, fehlende Backups) vor dem Ausfall erkennen.

Zielverfügbarkeit laut Angebot: 99,5 % pro Monat (Ziel, keine Garantie im Tarif Start).

## 2. Healthcheck `/up`

| Eigenschaft | Wert |
|---|---|
| URL | `https://<APP_DOMAIN>/up` (vom Gateway an Laravel geleitet) |
| Erfolg | HTTP 200 |
| Prüft | PHP-FPM und Laravel laufen, **Datenbank** antwortet, **Cache** (Redis) ist erreichbar |
| Fehler | HTTP 500, wenn Datenbank oder Cache nicht erreichbar sind; 503 im Wartungsmodus |
| Verwendet von | Kontrollen nach dem Deployment, externem Uptime-Monitoring |

`/up` prüft nicht die Web-App (Next.js). Deshalb zusätzlich die Anmeldeseite überwachen.

## 3. Uptime-Monitoring (extern)

Einen externen Dienst verwenden (z. B. Better Stack, UptimeRobot), der **nicht** auf demselben Server läuft.

| Monitor | URL | Intervall | Erwartung | Alarm nach |
|---|---|---|---|---|
| API + DB + Cache | `https://app.giftcardpro.at/up` | 1 min | Status 200 | 2 Fehlschlägen |
| Web-App | `https://app.giftcardpro.at/login` | 1 min | Status 200 | 2 Fehlschlägen |
| Konfiguration der Kellner-App | `https://app.giftcardpro.at/api/v1/app/config` | 5 min | Status 200, JSON | 2 Fehlschlägen |
| TLS-Zertifikat | `app.giftcardpro.at:443` | täglich | gültig > 14 Tage | sofort |
| Backup-Heartbeat | Heartbeat-URL aus der [Backup-Anleitung](backup-guide.md#6-backup-jobs-überwachen) | täglich | Signal bis 04:00 (Serverzeit) | ausbleibendem Signal |

Empfehlung: öffentliche Statusseite des Monitoring-Dienstes unter `[status.giftcardpro.at]` für die Lokale.

## 4. Container-Gesundheit

| Dienst | Healthcheck (in `docker-compose.coolify.yml`) | Intervall |
|---|---|---|
| `gateway` | `GET /gateway-health` | 15 s |
| `api` | php-fpm-Ping über FastCGI, Startfenster 300 s (Warten auf MySQL, Migrationen) | 15 s |
| `worker` | `pgrep -f queue:work` | 30 s |
| `scheduler` | `pgrep -f schedule:work` | 30 s |
| `web` | `GET /login` | 15 s |
| `mysql` | `mysqladmin ping` | 10 s, 12 Versuche |
| `redis` | `redis-cli ping` | 10 s, 10 Versuche |
| `backup` | kein Healthcheck (siehe Backup-Überwachung) | – |

Alle Dienste laufen mit `restart: unless-stopped`: Docker startet abgestürzte Container neu, aber **nicht** Container, die nur als `unhealthy` markiert sind.

Prüfung: Coolify zeigt den Status jedes Dienstes in der Ressource. Am Server (als root):

```bash
docker ps --filter health=unhealthy
docker stats --no-stream
```

Empfehlung: ein Cron-Job, der alle 5 Minuten `docker ps --filter health=unhealthy --format '{{.Names}}'` auswertet und bei nicht-leerer Ausgabe alarmiert.

## 5. Queue

### 5.1 Was in der Queue läuft

Der Dienst `worker` arbeitet die Redis-Queues `default` und `notifications` ab (`--tries=5`, Neustart nach 1 Stunde oder 1.000 Jobs). **Jede** E-Mail wird aus der Queue versendet: Gäste-E-Mails (Kauf, Aufladung, Ablauferinnerung), Einladungen und Passwort-Links. Mailserver, die nicht antworten, werden nach `MAIL_TIMEOUT` (10 s) aufgegeben und der Job wird wiederholt.

### 5.2 Queue-Monitor

Der Scheduler führt alle 5 Minuten aus:

```
queue:monitor redis:default,redis:notifications --max=500
```

Liegen mehr als 500 Jobs in einer Queue, löst Laravel das Ereignis `QueueBusy` aus.

> **Benachrichtigung:** Der Listener `AlertOnQueueBacklog` schreibt dann einen `critical`-Eintrag ins Log und schickt eine E-Mail an `OPS_ALERT_EMAIL` (leer: die Support-Adresse aus den Systemeinstellungen) – höchstens einmal pro Queue alle 30 Minuten. Die E-Mail wird direkt versendet, nicht über die Queue, damit sie auch bei ausgefallenem Worker ankommt.

Manuelle Prüfung im Container **api**:

```bash
php artisan queue:monitor redis:default,redis:notifications --max=500
php artisan queue:failed
```

| Befund | Bedeutung | Maßnahme |
|---|---|---|
| Queue > 0 über längere Zeit, wächst | Worker hängt oder läuft nicht | Log des Dienstes `worker` prüfen, Dienst in Coolify neu starten |
| Viele fehlgeschlagene Jobs | Mailversand gestört (Zugangsdaten, Limit des Versanddienstleisters) | Ursache beheben, dann `php artisan queue:retry all` |

Fehlgeschlagene Jobs werden täglich um 03:30 nach 30 Tagen entfernt (`queue:prune-failed --hours=720`). Jeder Versandversuch steht zusätzlich in `notification_logs`.

## 6. Scheduler und Integritätsprüfung

Im Container **api**: `php artisan schedule:list`. Erwartete Einträge (Zeiten in `SCHEDULE_TIMEZONE`, Standard `Europe/Vienna`):

| Befehl | Zeitplan |
|---|---|
| `vouchers:expire` | täglich 00:15 |
| `giftcard:verify-chains` | täglich 04:00 |
| `queue:prune-failed --hours=720` | täglich 03:30 |
| `vouchers:notify-expiring` | täglich 10:00 |
| `auth:clear-resets` | alle 15 Minuten |
| `queue:monitor redis:default,redis:notifications --max=500` | alle 5 Minuten |

**Integritätsprüfung.** `giftcard:verify-chains` berechnet jede Hash-Kette (Ledger, Zahlungen, Audit-Log je Lokal und Plattform) und jedes Gutscheinguthaben neu. Bei einer Abweichung schreibt es `Integrity check failed: financial history or audit log does not verify` als `critical` ins Log und sendet eine E-Mail an `OPS_ALERT_EMAIL`. **Eine fehlgeschlagene Integritätsprüfung ist ein Sicherheitsvorfall** (P1, siehe [Incident-Response-Leitfaden](../07-security/incident-response-guide.md)): Datenbank und Backups sichern, bevor irgendetwas geändert wird.

Nachweis, dass der Ablauf-Job gelaufen ist: Im Audit-Log erscheinen Einträge `voucher.expired` mit Zeitstempel kurz nach 00:15 Wiener Zeit (nur, wenn an diesem Tag Gutscheine abgelaufen sind). Das Guthaben bleibt dabei erhalten; es entsteht keine Buchung.

```sql
SELECT DATE(created_at) AS day, COUNT(*) FROM audit_logs
WHERE action = 'voucher.expired' AND created_at > NOW() - INTERVAL 7 DAY GROUP BY day;
```

## 7. Sicherheitsereignisse im Log

Diese Meldungen eignen sich für Alarme:

| Log-Meldung | Level | Kontextfelder | Auslöser |
|---|---|---|---|
| `Account locked after repeated failed logins` | `warning` | `user_id`, `ip`, `attempts` | 10 aufeinanderfolgende falsche Passwörter (`LOGIN_LOCKOUT_THRESHOLD`) |
| `Integrity check failed: financial history or audit log does not verify` | `critical` | Befunde | nächtliche oder manuelle Integritätsprüfung |
| `Queue backlog above threshold` | `critical` | `queue`, `size` | mehr als 500 Jobs |

Suche: Coolify → *Logs* → Dienst **api** bzw. **scheduler**, oder am Server `docker logs --since 24h <api-container> 2>&1 | grep -E "Account locked|Integrity check failed"`.

Fehlgeschlagene Scans (ein gescannter Text, der kein gültiger Gutschein dieses Lokals ist) stehen im Audit-Log:

```sql
SELECT restaurant_id, device_id, action, COUNT(*) AS n
FROM audit_logs
WHERE created_at > NOW() - INTERVAL 1 DAY AND action IN ('presentment.failed', 'presentment.rejected')
GROUP BY restaurant_id, device_id, action ORDER BY n DESC;
```

Nach `PRESENTMENT_FAILURE_LIMIT` (10) Fehlversuchen in 5 Minuten je Lokal, Person und Gerät antwortet die API mit `429 PRESENTMENT_THROTTLED`.

## 8. Kennzahlen

| Kennzahl | Quelle | Normalbereich (Richtwert) | Warnung |
|---|---|---|---|
| Verfügbarkeit `/up` | Uptime-Monitor | 100 % | jeder Ausfall |
| Antwortzeit `/up` | Uptime-Monitor | < 300 ms | > 1 s über 5 min |
| HTTP-5xx-Anteil | Gateway-Access-Log (JSON, Feld `status`) | ~0 | > 1 % über 5 min |
| HTTP-429-Anzahl | Gateway-Access-Log | gering | plötzlicher Anstieg (Angriff oder zu knappes Limit) |
| Queue-Länge | `queue:monitor` | 0–wenige | > 500 |
| Fehlgeschlagene Jobs | `queue:failed` | 0 | > 0 neu pro Tag |
| Integritätsprüfung | Log `scheduler`, E-Mail | ohne Befund | jeder Befund |
| Fehlgeschlagene Scans | Audit-Log | vereinzelt (verschmutzte oder falsche QR-Codes) | ≥ 10 pro Stunde und Gerät |
| Kontosperren | Log / Audit-Log | selten | ≥ 3 pro Stunde |
| Festplatte | `df -h` | < 70 % | > 80 % |
| RAM | `free -m`, `docker stats` | < 75 % | > 90 % |
| Redis-Speicher | `redis-cli INFO memory` | niedrig | wachsend; bei `noeviction` führt voller Speicher zu Schreibfehlern (Sessions, Queue) |
| MySQL-Verbindungen | `SHOW STATUS LIKE 'Threads_connected'` | niedrig | nahe `max_connections` |
| Backup-Alter | Log des Dienstes `backup`, Heartbeat | < 24 h | > 26 h |
| Zertifikatslaufzeit | Uptime-Monitor | > 30 Tage | < 14 Tage |

Richtwerte sind Schätzungen für den Pilotbetrieb und nach den ersten Wochen anhand echter Werte anzupassen.

## 9. Alarmregeln

| Priorität | Regel | Reaktion |
|---|---|---|
| **P1 – sofort** | `/up` oder Web-App nicht erreichbar (2 Prüfungen) | Bereitschaft sofort, auch abends |
| **P1** | HTTP-5xx > 5 % über 5 min | sofort |
| **P1** | Container `api`, `mysql` oder `redis` unhealthy | sofort |
| **P1** | Integritätsprüfung meldet einen Befund | sofort, als Sicherheitsvorfall |
| **P2 – gleicher Tag** | gehäufte `presentment.failed` auf einem Gerät oder in einem Lokal | Lokal informieren, Gerät prüfen, ggf. unter **Devices** widerrufen |
| **P2** | ≥ 3 `Account locked` pro Stunde, oder mehrere Konten von einer IP | IP prüfen, ggf. in der Firewall sperren |
| **P2** | Queue > 500 oder neue fehlgeschlagene Jobs | Mailversand prüfen |
| **P2** | Backup älter als 26 h oder Off-site-Sync fehlgeschlagen | Backup manuell nachholen |
| **P2** | Festplatte > 80 % | aufräumen (Abschnitt 9 der [Wartungsanleitung](maintenance-guide.md#9-speicherplatz-freigeben)) |
| **P3 – Wochenroutine** | Zertifikat < 30 Tage, `composer audit`/`npm audit` meldet Lücken | einplanen |

Die Log-basierten Regeln setzen einen Log-Versand voraus (siehe [Logging-Leitfaden](logging-guide.md#log-versand-empfehlung)). Ohne Log-Versand: täglicher Cron-Job mit den Abfragen aus Abschnitt 7, der das Ergebnis per E-Mail sendet. Integritätsprüfung und Queue-Rückstau alarmieren unabhängig davon per E-Mail.

## 10. Fehlertracking (optional)

Für Ausnahmen mit Stacktrace kann Sentry ergänzt werden (`sentry/sentry-laravel` im Backend, `@sentry/nextjs` im Frontend). Beide Pakete sind derzeit **nicht** installiert; die Integration ist eine Codeänderung mit eigenem Release. Beim Einsatz personenbezogene Daten ausfiltern (`send_default_pii` deaktiviert lassen) und einen EU-Datenstandort wählen.

## 11. Dashboards (Vorschlag)

| Dashboard | Inhalte |
|---|---|
| **Betrieb** | Verfügbarkeit, Antwortzeit `/up`, 5xx-Rate, Requests pro Minute (Gateway), Container-Status, CPU/RAM/Festplatte |
| **Hintergrund** | Queue-Länge, fehlgeschlagene Jobs, letzte Ausführung der nächtlichen Jobs und der Integritätsprüfung, Backup-Alter |
| **Sicherheit** | fehlgeschlagene Scans nach Lokal und Gerät, Kontosperren, 429-Antworten, Top-IPs mit 4xx |
| **Geschäft** (Plattform) | aktive Lokale, verkaufte Gutscheine, Einlösungen pro Tag – aus `GET /admin/stats` bzw. SQL |

Umsetzung z. B. mit Grafana + Loki (Log-Versand über Promtail oder Vector) oder direkt im Dashboard eines Log-Dienstes mit EU-Standort.

## 12. Bereitschaftsroutine

### 12.1 Täglich (5 Minuten, vormittags)

- [ ] Uptime-Monitor: keine Vorfälle in den letzten 24 h
- [ ] Coolify: alle Dienste `running`/`healthy`
- [ ] Keine Warn-E-Mail an `OPS_ALERT_EMAIL` (Integritätsprüfung, Queue)
- [ ] Backup von heute vorhanden, off-site synchronisiert
- [ ] Sicherheitsereignisse der letzten 24 h geprüft
- [ ] `queue:failed` leer

### 12.2 Bereitschaftszeiten

Hauptlast der Lokale: mittags (11:00–14:30) und abends (17:30–23:00), besonders Freitag, Samstag und in der Adventzeit. Während dieser Zeiten muss eine Person innerhalb von 15 Minuten reagieren können. Keine Deployments und keine Wartung in diesen Zeitfenstern.

### 12.3 Vorgehen bei P1

1. Alarm bestätigen, Uhrzeit notieren.
2. `curl -fsS https://app.giftcardpro.at/up` und den Status der Dienste in Coolify prüfen.
3. Logs der letzten Minuten: Coolify → *Logs* → `api`, `gateway`, `mysql`, `redis`.
4. Häufige Ursachen und Sofortmaßnahmen:

| Symptom | Maßnahme |
|---|---|
| `mysql` oder `redis` unhealthy | Festplatte prüfen (`df -h`), Dienst neu starten |
| `api` unhealthy nach Deployment | Rollback ([Deployment-Anleitung](deployment-guide.md#9-rollback)) |
| Festplatte voll | Docker-Images und Build-Cache bereinigen (`docker image prune -f`, `docker builder prune -f`), alte Dumps prüfen |
| Zertifikatsfehler | DNS prüfen, Domain des Dienstes `gateway` in Coolify prüfen |
| Integritätsprüfung meldet Befund | Nichts ändern; Datenbank und Backups sichern; [Incident-Response-Leitfaden](../07-security/incident-response-guide.md) |

5. Dauert der Ausfall länger als 15 Minuten: Wartungshinweis setzen (sofern API erreichbar) und Lokale per E-Mail informieren. Während des Ausfalls kann kein Gutschein eingelöst werden: Jede Einlösung braucht einen frischen Scan des Gutscheins, und die Gutscheinnummer ist kein Ersatz dafür. Gäste bezahlen in dieser Zeit anders oder lösen den Gutschein beim nächsten Besuch ein.
6. Nach dem Vorfall: kurzer Bericht (Ursache, Dauer, Auswirkung, Maßnahmen).

---

Version 2.0 · Stand: September 2026
