# Monitoring-Leitfaden

> **Hinweis (Coolify-Deployment):** Produktion läuft seit 1.4.2 auf **Coolify** mit `docker-compose.coolify.yml` (Build aus dem Quellcode, kein GHCR, keine Deploy-Skripte). Befehle mit `docker compose --env-file .env.production`, `infra/scripts/…`, `deploy.yml` oder Caddy auf dem Host in diesem Dokument sind überholt. Maßgeblich sind [docs/DEPLOYMENT.md](../../DEPLOYMENT.md) (Deployment, Backups, Restore, Betrieb) und [docs/ENVIRONMENT.md](../../ENVIRONMENT.md).

*Überwachung von GiftCard Pro im Produktivbetrieb: Healthcheck, Uptime, Container, Queue, Scheduler, Kennzahlen, Alarmregeln, Dashboards und Bereitschaftsroutine.*

---

## 1. Ziele

Die Kellner-App wird während des Service verwendet. Ein Ausfall am Freitagabend bedeutet, dass Gäste ihre Karte nicht einlösen können. Das Monitoring soll deshalb:

1. einen Ausfall innerhalb von 2 Minuten melden,
2. Betrugsversuche (geklonte oder kopierte Karten, Passwortangriffe) sichtbar machen,
3. schleichende Probleme (volle Festplatte, wachsende Queue, fehlende Backups) vor dem Ausfall erkennen.

Zielverfügbarkeit laut Angebot: 99,5 % pro Monat (Ziel, keine Garantie im Tarif Start).

## 2. Healthcheck `/up`

| Eigenschaft | Wert |
|---|---|
| URL | `https://<APP_DOMAIN>/up` (von Caddy an Laravel geleitet) |
| Erfolg | HTTP 200 |
| Prüft | PHP-FPM und Laravel laufen, **Datenbank** antwortet (`select 1`), **Cache** (Redis) ist beschreib- und lesbar |
| Fehler | HTTP 500, wenn Datenbank oder Cache nicht erreichbar sind |
| Verwendet von | `deploy.sh` (nach jedem Deployment), externem Uptime-Monitoring |

`/up` prüft nicht die Web-App (Next.js). Deshalb zusätzlich die Startseite überwachen.

## 3. Uptime-Monitoring (extern)

Einen externen Dienst verwenden (z. B. Better Stack, UptimeRobot), der **nicht** auf demselben Server läuft.

| Monitor | URL | Intervall | Erwartung | Alarm nach |
|---|---|---|---|---|
| API + DB + Cache | `https://app.giftcardpro.at/up` | 1 min | Status 200 | 2 Fehlschlägen |
| Web-App | `https://app.giftcardpro.at/login` | 1 min | Status 200 | 2 Fehlschlägen |
| TLS-Zertifikat | `app.giftcardpro.at:443` | täglich | gültig > 14 Tage | sofort |
| Backup-Heartbeat | Heartbeat-URL aus der [Backup-Anleitung](backup-guide.md#6-backup-jobs-überwachen) | täglich | Signal bis 03:30 (Serverzeit) | ausbleibendem Signal |

Empfehlung: öffentliche Statusseite des Monitoring-Dienstes unter `[status.giftcardpro.at]` für die Restaurants.

## 4. Container-Gesundheit

| Dienst | Healthcheck (in `docker-compose.yml`) | Intervall |
|---|---|---|
| `api` | `pgrep -f "php-fpm: master"` (erst nach Migration und Cache-Aufbau), Startfenster 120 s | 10 s |
| `queue` | `pgrep -f queue:work` | 30 s |
| `scheduler` | `pgrep -f schedule:work` | 30 s |
| `mysql` | `mysqladmin ping` | 10 s, 10 Versuche |
| `redis` | `redis-cli ping` | 10 s, 10 Versuche |
| `caddy`, `web` | kein Healthcheck | – |

Alle Dienste laufen mit `restart: unless-stopped`: Docker startet abgestürzte Container neu, aber **nicht** Container, die nur als `unhealthy` markiert sind.

Prüfung:

```bash
cd /opt/giftcard-pro
docker compose --env-file .env.production ps
docker ps --filter health=unhealthy
docker stats --no-stream
```

Empfehlung: ein Cron-Job, der alle 5 Minuten `docker ps --filter health=unhealthy --format '{{.Names}}'` auswertet und bei nicht-leerer Ausgabe alarmiert.

## 5. Queue

### 5.1 Was in der Queue läuft

Queue-Worker (`queue`) arbeiten die Redis-Queues `default` und `notifications` ab (`--tries=5`, Neustart nach 1 Stunde oder 1.000 Jobs). In `notifications` liegen die Kunden-E-Mails (Kauf, Aufladung, Ablauf-Erinnerung, niedriges Guthaben) und Einladungen.

### 5.2 Queue-Monitor

Der Scheduler führt alle 5 Minuten aus:

```
queue:monitor redis:default,redis:notifications --max=500
```

Liegen mehr als 500 Jobs in einer Queue, löst Laravel das Ereignis `QueueBusy` aus.

> **Benachrichtigung:** Der Listener `AlertOnQueueBacklog` schreibt dann einen `critical`-Eintrag ins Log und schickt eine E-Mail an `OPS_ALERT_EMAIL` (leer: die Support-Adresse aus den Systemeinstellungen) – höchstens einmal pro Queue alle 30 Minuten. Die E-Mail wird direkt versendet, nicht über die Queue, damit sie auch bei ausgefallenem Worker ankommt.

Manuelle Prüfung:

```bash
docker compose --env-file .env.production exec api php artisan queue:monitor redis:default,redis:notifications --max=500
docker compose --env-file .env.production exec api php artisan queue:failed
```

| Befund | Bedeutung | Maßnahme |
|---|---|---|
| Queue > 0 über längere Zeit, wächst | Worker hängt oder läuft nicht | `docker compose … logs queue`, `docker compose … restart queue` |
| Viele fehlgeschlagene Jobs | Mailversand gestört (Zugangsdaten, Limit des Versanddienstleisters) | Ursache beheben, dann `php artisan queue:retry all` |

Fehlgeschlagene Jobs werden täglich um 03:30 nach 30 Tagen entfernt (`queue:prune-failed --hours=720`).

## 6. Scheduler

```bash
docker compose --env-file .env.production exec scheduler php artisan schedule:list
```

Erwartete Einträge (Zeiten in `SCHEDULE_TIMEZONE`, Standard `Europe/Vienna`):

| Befehl | Zeitplan |
|---|---|
| `giftcards:expire` | täglich 00:15 |
| `giftcards:notify-expiring` | täglich 10:00 |
| `queue:prune-failed --hours=720` | täglich 03:30 |
| `auth:clear-resets` | alle 15 Minuten |
| `queue:monitor redis:default,redis:notifications --max=500` | alle 5 Minuten |

Nachweis, dass der Ablauf-Job gelaufen ist: Im Audit-Log bzw. Ledger erscheinen Buchungen vom Typ `expiration` mit Zeitstempel kurz nach 00:15 Wiener Zeit (nur, wenn an diesem Tag Karten abgelaufen sind).

```sql
SELECT DATE(created_at) AS day, COUNT(*) FROM gift_card_transactions
WHERE type = 'expiration' AND created_at > NOW() - INTERVAL 7 DAY GROUP BY day;
```

## 7. Sicherheitsereignisse im Log

Zwei Meldungen werden auf Ebene `warning` geschrieben und eignen sich für Alarme:

| Log-Meldung | Kontextfelder | Auslöser |
|---|---|---|
| `Suspicious gift card scan` | `result`, `method`, `restaurant_id`, `user_id`, `device_id`, `ip`, `nfc_uid`, `request_id` | Scan mit Ergebnis `foreign_restaurant`, `uid_mismatch`, `invalid_signature`, `replay` oder `throttled` (nicht bei `ok` und `not_found`) |
| `Account locked after repeated failed logins` | `user_id`, `ip`, `attempts`, `request_id` | 10 aufeinanderfolgende falsche Passwörter (`LOGIN_LOCKOUT_THRESHOLD`) |

Suche:

```bash
docker compose --env-file .env.production logs --since 24h api | grep -E "Suspicious gift card scan|Account locked"
```

Ergänzend liefert die Tabelle `nfc_scans` jede Kartenabfrage:

```sql
SELECT restaurant_id, result, COUNT(*) AS n
FROM nfc_scans
WHERE created_at > NOW() - INTERVAL 1 DAY AND result <> 'ok'
GROUP BY restaurant_id, result ORDER BY n DESC;
```

## 8. Kennzahlen

| Kennzahl | Quelle | Normalbereich (Richtwert) | Warnung |
|---|---|---|---|
| Verfügbarkeit `/up` | Uptime-Monitor | 100 % | jeder Ausfall |
| Antwortzeit `/up` | Uptime-Monitor | < 300 ms | > 1 s über 5 min |
| HTTP-5xx-Anteil | Caddy-Access-Log (JSON, Feld `status`) | ~0 | > 1 % über 5 min |
| HTTP-429-Anzahl | Caddy-Access-Log | gering | plötzlicher Anstieg (Angriff oder zu knappes Limit) |
| Queue-Länge | `queue:monitor` | 0–wenige | > 500 |
| Fehlgeschlagene Jobs | `queue:failed` | 0 | > 0 neu pro Tag |
| Verdächtige Scans | Log / `nfc_scans` | 0 | ≥ 1 (Info), ≥ 5 pro Stunde und Restaurant (Warnung) |
| Kontosperren | Log | selten | ≥ 3 pro Stunde |
| Festplatte | `df -h` | < 70 % | > 80 % |
| RAM | `free -m`, `docker stats` | < 75 % | > 90 % |
| Redis-Speicher | `redis-cli INFO memory` | niedrig | wachsend; bei `noeviction` führt voller Speicher zu Schreibfehlern (Sessions, Queue) |
| MySQL-Verbindungen | `SHOW STATUS LIKE 'Threads_connected'` | niedrig | nahe `max_connections` |
| Backup-Alter | Dateisystem, Heartbeat | < 24 h | > 26 h |
| Zertifikatslaufzeit | Uptime-Monitor | > 30 Tage | < 14 Tage |

Richtwerte sind Schätzungen für den Pilotbetrieb und nach den ersten Wochen anhand echter Werte anzupassen.

## 9. Alarmregeln

| Priorität | Regel | Reaktion |
|---|---|---|
| **P1 – sofort** | `/up` oder Web-App nicht erreichbar (2 Prüfungen) | Bereitschaft sofort, auch abends |
| **P1** | HTTP-5xx > 5 % über 5 min | sofort |
| **P1** | Container `api`, `mysql` oder `redis` unhealthy | sofort |
| **P2 – gleicher Tag** | `Suspicious gift card scan` mit `uid_mismatch`, `invalid_signature` oder `replay` | Restaurant informieren, Karte prüfen, ggf. sperren |
| **P2** | ≥ 3 `Account locked` pro Stunde, oder mehrere Konten von einer IP | IP prüfen, ggf. in Firewall sperren |
| **P2** | Queue > 500 oder neue fehlgeschlagene Jobs | Mailversand prüfen |
| **P2** | Backup älter als 26 h oder Off-site-Sync fehlgeschlagen | Backup manuell nachholen |
| **P2** | Festplatte > 80 % | aufräumen (Abschnitt 9 der [Wartungsanleitung](maintenance-guide.md#9-speicherplatz-freigeben)) |
| **P3 – Wochenroutine** | Zertifikat < 30 Tage, `composer audit`/`npm audit` meldet Lücken | einplanen |

Die Log-basierten Regeln (P2 Sicherheit) setzen einen Log-Versand voraus (siehe [Logging-Leitfaden](logging-guide.md#log-versand-empfehlung)). Ohne Log-Versand: täglicher Cron-Job mit der `grep`-Abfrage aus Abschnitt 7, der das Ergebnis per E-Mail sendet.

## 10. Fehlertracking (optional)

Für Ausnahmen mit Stacktrace kann Sentry ergänzt werden (`sentry/sentry-laravel` im Backend, `@sentry/nextjs` im Frontend). Beide Pakete sind derzeit **nicht** installiert; die Integration ist eine Codeänderung mit eigenem Release. Beim Einsatz personenbezogene Daten ausfiltern (`send_default_pii` deaktiviert lassen) und einen EU-Datenstandort wählen.

## 11. Dashboards (Vorschlag)

| Dashboard | Inhalte |
|---|---|
| **Betrieb** | Verfügbarkeit, Antwortzeit `/up`, 5xx-Rate, Requests pro Minute (Caddy), Container-Status, CPU/RAM/Festplatte |
| **Hintergrund** | Queue-Länge, fehlgeschlagene Jobs, letzte Ausführung der nächtlichen Jobs, Backup-Alter |
| **Sicherheit** | verdächtige Scans nach Ergebnis und Restaurant, Kontosperren, 429-Antworten, Top-IPs mit 4xx |
| **Geschäft** (Plattform) | aktive Restaurants, ausgegebene Karten, Einlösungen pro Tag – aus `GET /admin/stats` bzw. SQL |

Umsetzung z. B. mit Grafana + Loki (Log-Versand über Promtail oder Vector) oder direkt im Dashboard eines Log-Dienstes mit EU-Standort.

## 12. Bereitschaftsroutine

### 12.1 Täglich (5 Minuten, vormittags)

- [ ] Uptime-Monitor: keine Vorfälle in den letzten 24 h
- [ ] `docker compose … ps`: alle Dienste `running`/`healthy`
- [ ] Backup von heute vorhanden, off-site synchronisiert
- [ ] Sicherheitsmeldungen der letzten 24 h geprüft
- [ ] `queue:failed` leer

### 12.2 Bereitschaftszeiten

Hauptlast der Restaurants: mittags (11:00–14:30) und abends (17:30–23:00), besonders Freitag, Samstag und in der Adventzeit. Während dieser Zeiten muss eine Person innerhalb von 15 Minuten reagieren können. Keine Deployments und keine Wartung in diesen Zeitfenstern.

### 12.3 Vorgehen bei P1

1. Alarm bestätigen, Uhrzeit notieren.
2. `curl -fsS https://app.giftcardpro.at/up` und `docker compose … ps` prüfen.
3. Logs der letzten Minuten: `docker compose … logs --since 15m api caddy mysql redis`.
4. Häufige Ursachen und Sofortmaßnahmen:

| Symptom | Maßnahme |
|---|---|
| `mysql` oder `redis` unhealthy | Festplatte prüfen (`df -h`), Container neu starten |
| `api` unhealthy nach Deployment | Rollback ([Deployment-Anleitung](deployment-guide.md#9-rollback)) |
| Festplatte voll | Docker-Images bereinigen (`docker image prune -f`), alte Dumps prüfen |
| Zertifikatsfehler | `docker compose … logs caddy`, DNS prüfen |

5. Dauert der Ausfall länger als 15 Minuten: Wartungshinweis setzen (sofern API erreichbar) und Restaurants per E-Mail informieren. Die Restaurants notieren Einlösungen während des Ausfalls mit Kartennummer und Betrag und erfassen sie danach mit **Redeem** nach.
6. Nach dem Vorfall: kurzer Bericht (Ursache, Dauer, Auswirkung, Maßnahmen).

---

Version 1.0 · Stand: September 2026
