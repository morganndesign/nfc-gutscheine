# Performance-Leitfaden

*Leistungsziel, Kapazitätsschätzung, Rate Limits, Datenbank-Indizes und Zeilensperren, Hash-Ketten, Caching, Skalierung, Checkliste und Messmethoden für GiftCard Pro.*

---

## 1. Leistungsziel

Das wichtigste Ziel ist fachlich: **Eine Einlösung am Tisch dauert inklusive Mensch unter 5 Sekunden** – QR-Code scannen, Betrag tippen, fertig. Der Scan gilt 60 Sekunden; das System selbst soll davon nur einen Bruchteil verbrauchen.

Eine Einlösung besteht aus zwei Requests:

1. `POST /presentments` – Hash des gescannten Geheimnisses nachschlagen, Scan speichern (eine Zeile).
2. `POST /vouchers/{id}/redemptions` – in einer Transaktion Scan und Gutschein sperren, prüfen, Ledger- und Audit-Eintrag anhängen, Guthaben aktualisieren.

## 2. Messen statt schätzen

Die Laufzeiten der Einlösung werden mit dem Abnahmetest gemessen (Abschnitt 9.1) und je Release im Release-Protokoll festgehalten. Die Nebenläufigkeitstests (`IdempotencyAndConcurrencyTest`, in CI auch gegen MySQL 8.4) belegen, dass gleichzeitige Einlösungen desselben Gutscheins nie mehr als das Guthaben abbuchen und die Summe des Ledgers dem Guthaben entspricht. Werte aus Testumgebungen mit wenig Last belegen, dass der Softwarepfad schnell ist; sie sind keine Aussage über das Verhalten unter hoher Last (siehe Abschnitt 3).

## 3. Kapazität eines einzelnen Servers

### 3.1 Referenzsystem

| Komponente | Einstellung |
|---|---|
| Server | Hetzner CX32/CPX31: 4 vCPU, 8 GB RAM (Minimum für den Stack: 2 vCPU / 4 GB) |
| PHP-FPM | `pm = dynamic`, `pm.max_children = 24`, `pm.max_requests = 1000`, `request_terminate_timeout = 30s`, OPcache + JIT (`infra/docker/php/`) |
| Queue-Worker | 1 Container, `--max-jobs=1000`, `--max-time=3600` |
| MySQL | 8.4, `innodb-buffer-pool-size=512M`, `READ-COMMITTED` |
| Redis | 7.4, AOF, `noeviction` |
| Gateway | Caddy, Kompression `zstd`/`gzip`; TLS beim Coolify-Proxy |

### 3.2 Schätzung

Die folgende Rechnung ist eine **Schätzung** und vor dem Wachstum über den Pilotbetrieb hinaus durch einen Lasttest zu bestätigen.

| Annahme | Wert |
|---|---|
| Serverzeit eines typischen API-Requests | 20–100 ms |
| Gleichzeitige PHP-Prozesse | 24 |
| Theoretischer Durchsatz der API | ca. 240–1.000 Requests/s |
| Requests pro Einlösung (Scan + Einlösung + Aktualisierung der Ansicht) | ca. 3–5 |
| Einlösungen in der Spitze pro Lokal | 1–2 pro Minute (Annahme für einen gut gehenden Abend im Advent) |

Selbst 500 Lokale mit 2 Einlösungen pro Minute ergeben rund 17 Einlösungen pro Sekunde, also etwa 50–85 Requests/s – deutlich unter dem geschätzten Durchsatz. Engpässe sind eher:

- **Arbeitsspeicher**: 24 PHP-Prozesse, MySQL-Buffer-Pool 512 MB, Redis, Next.js teilen sich den Arbeitsspeicher.
- **Exporte und Dashboards großer Lokale** (Aggregationen über viele Buchungen).
- **Integritätsprüfung** (`giftcard:verify-chains`, 04:00): berechnet jede Hash-Kette vollständig neu; die Laufzeit wächst linear mit Ledger, Zahlungen und Audit-Log.
- **E-Mail-Spitzen** (z. B. Erinnerungen um 10:00) – laufen über die Queue und blockieren keine Requests.

## 4. Rate Limits

Rate Limits schützen vor Missbrauch und begrenzen zugleich die Last einzelner Clients:

| Limiter | Grenze | Wirkung auf Performance |
|---|---|---|
| `api` | 240/min je Person | begrenzt fehlerhafte Integrationen (Endlosschleifen) |
| `presentment` | 90/min je Person und Endgerät; fehlgeschlagene Scans zusätzlich 10 je 5 min je Lokal, Person und Gerät | eine Servicekraft mit zwei Geräten wird nicht gebremst; Gäste hinter derselben IP zählen nie mit |
| `voucher-operation` | 90/min je Person und Endgerät | Verkauf, Einlösung, Aufladung, Einlösungsergebnis |
| `login` | 5/min je E-Mail + IP, 30/min je IP | Schutz vor Passwortangriffen |
| `password-reset` | 5/min je IP | |
| `app-config` | 60/min je IP | Startkonfiguration der Kellner-App |

Die Zähler liegen in Redis. Eine Kassenintegration, die regelmäßig 240/min erreicht, sollte ihr Abfrageverhalten ändern (z. B. keine Abfrage aller Gutscheine im Sekundentakt), statt ein höheres Limit zu verlangen.

## 5. Datenbank

### 5.1 Indizes

| Tabelle | Indizes | Nutzen |
|---|---|---|
| `vouchers` | `(restaurant_id, voucher_number)` unique, `(restaurant_id, status, created_at)`, `status`, `expires_at` | Gutscheinliste, Suche nach interner Nummer, nächtlicher Ablauf |
| `media` | `secret_hash` unique, `(voucher_id, type, status)` | Scan-Prüfung: ein Index-Lookup je Scan |
| `presentments` | `(restaurant_id, created_at)` | Auswertung, Aufräumen |
| `voucher_transactions` | `(restaurant_id, idempotency_key)` unique, `presentment_id`, `payment_id`, `related_transaction_id` unique, `(restaurant_id, created_at)`, `(restaurant_id, type, created_at)`, `(voucher_id, created_at)` | Idempotenz, Einlösungsergebnis, Verlauf, Buchungsliste |
| `payments` | `(restaurant_id, method, created_at)` | Auswertung nach Zahlungsart |
| `customers` | `(restaurant_id, email)`, `(restaurant_id, last_name)` | Suche |
| `audit_logs` | `(restaurant_id, created_at)`, `action`, `(auditable_type, auditable_id)` | Audit-Ansicht, Sicherheitsauswertung |
| Hash-Ketten | `(chain_scope, chain_seq)` unique in Ledger, Zahlungen und Audit-Log | Anhängen und Prüfen der Kette |

Alle Primärschlüssel sind zeitlich geordnete UUIDv7 – neue Zeilen landen am Ende des Index (gute Lokalität beim Schreiben).

### 5.2 Zeilensperren und Hash-Ketten

Jede Guthabenänderung läuft in einer Transaktion mit `SELECT … FOR UPDATE`:

- Bei einer Einlösung werden **der Scan und der eine Gutschein** gesperrt (Reihenfolge Scan → Gutschein), nicht die Tabelle. Einlösungen verschiedener Gutscheine laufen parallel.
- Gleichzeitige Einlösungen **desselben** Gutscheins werden serialisiert – das ist gewollt und verhindert Doppelausgaben. Nach der Sperre wird der Idempotency-Key erneut geprüft; eine wartende Wiederholung erhält das erste Ergebnis.
- Beim Anhängen an eine Hash-Kette wird deren Kopf in `chain_heads` gesperrt (Reihenfolge Zahlungen → Ledger → Audit-Log). Buchungen **eines Lokals** werden dadurch für die Dauer des Anhängens kurz hintereinander geschrieben; Lokale untereinander blockieren sich nicht.
- `READ-COMMITTED` hält Sperren kurz; bei einem Deadlock wird die Transaktion bis zu 3-mal wiederholt.
- E-Mails werden erst **nach** dem Commit eingereiht (`ShouldDispatchAfterCommit`) – der Mailversand verlängert die Sperre nicht.

### 5.3 Langsame Abfragen finden

```sql
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 0.5;
SHOW VARIABLES LIKE 'slow_query_log_file';
```

Die Einstellung gilt bis zum Neustart des MySQL-Containers. Auswertung mit `mysqldumpslow` im Container. Nach der Analyse wieder deaktivieren.

## 6. Caching

| Ebene | Was | Wo |
|---|---|---|
| Laravel-Bootstrap | Konfiguration, Routen, Views und Events werden bei jedem Containerstart gecacht | Dateisystem des Containers |
| PHP | OPcache + JIT | Arbeitsspeicher |
| Berechtigungen | Rollen → Berechtigungen, je Rolle gecacht | Redis |
| Systemeinstellungen | `system_settings` gecacht | Redis |
| HTTP | API-Antworten `Cache-Control: no-store, private` (außer `/app/config`: `public, max-age=60`) – bewusst **kein** HTTP-Caching von Guthaben | – |
| Browser | React Query hält Serverdaten im Client und invalidiert gezielt nach Änderungen | Browser |
| Statische Dateien | Next.js-Assets mit Hash im Dateinamen; das Gateway komprimiert mit `zstd`/`gzip` | Browser, Gateway |

Guthaben werden nie gecacht – jede Einlösung liest den gesperrten Datensatz aus der Datenbank.

## 7. Frontend

- Diagramme des Dashboards werden erst nach den Kennzahlen geladen (`next/dynamic`) – Kennzahlen erscheinen zuerst.
- Web-Kassa und Kellner-App zählen die Gültigkeit des Scans ab Empfang herunter (`expires_in`), unabhängig von der Uhr des Geräts.
- Nach einer Einlösung ist der Scanner sofort für den nächsten QR-Code bereit.
- Die Oberfläche passt ohne Scrollen auf kleine Handys (iPhone SE), was Bedienzeit spart.

## 8. Skalierung

| Stufe | Maßnahme | Wann |
|---|---|---|
| 1 | Größerer Server (mehr vCPU/RAM), `pm.max_children` und `innodb-buffer-pool-size` anheben | RAM > 80 % oder CPU in Spitzen > 70 % |
| 2 | MySQL auf einen eigenen Server oder Managed MySQL auslagern (`DB_HOST` usw. setzen, Dienste `mysql`/`backup` entfernen) | Datenbank konkurriert mit PHP um Ressourcen |
| 3 | Read Replica für Exporte und Auswertungen | große Exporte beeinflussen die Antwortzeiten |
| 4 | Eigene Coolify-Ressource je Großkunde (Single Tenant) aus demselben Repository | Isolationsanforderung eines Gruppe-Kunden |

Die Anwendung ist zustandslos; Sessions, Cache und Sperren liegen in Redis. Der Scheduler darf nur **einmal** laufen (`onOneServer()` ist gesetzt und nutzt Redis-Sperren). Migrationen laufen dank einer Redis-Sperre nur in einem Container.

## 9. Messen

### 9.1 Abnahmetest

Der Abnahmetest `e2e/pilot-journey.mjs` spielt Verkauf, QR-Scan und Einlösung am Handy durch. Vor jedem Release ausführen und die gemessene Zeit der Einlösung im Release-Protokoll festhalten – ein Anstieg gegenüber dem vorigen Release ist ein Warnsignal.

```bash
cd e2e
ADMIN_EMAIL=admin@giftcardpro.test ADMIN_PASSWORD='Password123!' npm test
```

### 9.2 Antwortzeiten in Produktion

```bash
curl -o /dev/null -s -w "connect=%{time_connect}s tls=%{time_appconnect}s total=%{time_total}s\n" https://app.giftcardpro.at/up
```

Das Zugriffslog des Gateways enthält je Request das Feld `duration` (Sekunden). Am Server (als root):

```bash
docker logs --since 1h <gateway-container> 2>&1 \
  | jq -r 'select(.request.uri? | test("^/api/v1/(presentments|vouchers/[^/]+/redemptions)")) | .duration' \
  | sort -n | awk '{a[NR]=$1} END {print "p50="a[int(NR*0.5)]" p95="a[int(NR*0.95)]" n="NR}'
```

### 9.3 Lasttest (Empfehlung)

Lasttests nur gegen eine **Staging-Umgebung** mit gleicher Servergröße, nie gegen Produktion (Rate Limits, unveränderliche Ledger-Einträge). Werkzeug z. B. k6; Szenario: viele Endgeräte mit eigener `X-Device-Id` und eigenem Token, je Gerät Scan eines Test-QR-Codes und Einlösung mit neuem `Idempotency-Key`. Nach dem Test `php artisan giftcard:verify-chains` und die Prüfabfragen aus der [Restore-Anleitung](restore-guide.md#8-prüfabfragen-nach-einem-restore) ausführen.

## 10. Checkliste

- [ ] `APP_DEBUG=false`, `APP_ENV=production` (sonst deutlich langsamer)
- [ ] `CACHE_STORE=redis`, `SESSION_DRIVER=redis`, `QUEUE_CONNECTION=redis` (im Coolify-Stack Standard)
- [ ] Dienst `worker` läuft (sonst warten E-Mails, nicht die Requests)
- [ ] `/up` antwortet in < 300 ms
- [ ] Abnahmetest: Einlösung < 1 s Systemzeit
- [ ] Integritätsprüfung endet deutlich vor dem Morgen
- [ ] RAM < 75 %, keine Swap-Nutzung
- [ ] Festplatte < 70 %
- [ ] Keine wachsende Queue
- [ ] Neue Datenbankabfragen in Pull Requests mit `EXPLAIN` geprüft; neue Filter nur mit passendem Index
- [ ] Neue Geldpfade sperren nur den betroffenen Gutschein, keine Tabellen
- [ ] Keine Guthaben- oder Berechtigungsdaten im HTTP-Cache

---

Version 2.0 · Stand: September 2026
