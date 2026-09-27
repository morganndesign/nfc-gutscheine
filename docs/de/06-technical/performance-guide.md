# Performance-Leitfaden

*Gemessene Werte, Kapazitätsschätzung, Rate Limits, Datenbank-Indizes und Zeilensperren, Caching, Skalierung, Checkliste und Messmethoden für GiftCard Pro.*

---

## 1. Leistungsziel

Das wichtigste Ziel ist fachlich: **Eine Einlösung am Tisch dauert inklusive Mensch unter 5 Sekunden** – Karte antippen, Betrag tippen, fertig. Das System selbst soll davon nur einen Bruchteil verbrauchen.

## 2. Gemessene Werte

| Messung | Ergebnis | Quelle |
|---|---|---|
| Kartenabfrage (`POST /scan`) | **92 ms** (~0,1 s) | E2E-Messung, Release 1.1.0 |
| Kompletter UI-Ablauf in der Kellner-App (Antippen → Betrag → Einlösen → Fertig) | **545 ms** (~0,5 s) | E2E-Messung, Release 1.1.0 |
| Einlösung durch die Servicekraft inkl. Eingabe der Kartennummer | **0,48 s** | Abnahmetest `pilot-journey.mjs`, Release 1.2.0 |
| JavaScript beim ersten Laden des Dashboards | **142 kB** (vorher 251 kB) | Build-Ausgabe, Release 1.2.0 – Diagramme werden nachgeladen (`next/dynamic`) |
| 20 gleichzeitige Einlösungen auf einer Karte | genau die leistbare Anzahl erfolgreich, Ledger-Summe = Guthaben | Nebenläufigkeitstest gegen MariaDB |

Die Werte stammen aus Testumgebungen mit wenig Last. Sie belegen, dass der Softwarepfad schnell ist; sie sind keine Aussage über das Verhalten unter hoher Last (siehe Abschnitt 3).

## 3. Kapazität eines einzelnen Servers

### 3.1 Referenzsystem

| Komponente | Einstellung |
|---|---|
| Server | Hetzner CPX31: 4 vCPU, 8 GB RAM |
| PHP-FPM | `pm = dynamic`, `pm.max_children = 24`, `pm.max_requests = 1000`, OPcache + JIT |
| Queue-Worker | 1 Container, `--max-jobs=1000`, `--max-time=3600` |
| MySQL | 8.4, `innodb-buffer-pool-size=512M`, `READ-COMMITTED` |
| Redis | 7.4, AOF, `noeviction` |
| Caddy | HTTP/3, Kompression `zstd`/`gzip` |

### 3.2 Schätzung

Die folgende Rechnung ist eine **Schätzung** und vor dem Wachstum über den Pilotbetrieb hinaus durch einen Lasttest zu bestätigen.

| Annahme | Wert |
|---|---|
| Serverzeit eines typischen API-Requests | 20–100 ms |
| Gleichzeitige PHP-Prozesse | 24 |
| Theoretischer Durchsatz der API | ca. 240–1.000 Requests/s |
| Requests pro Einlösung (Scan + Einlösung + Aktualisierung der Ansicht) | ca. 3–5 |
| Einlösungen in der Spitze pro Restaurant | 1–2 pro Minute (Annahme für einen gut gehenden Abend im Advent) |

Selbst 500 Restaurants mit 2 Einlösungen pro Minute ergeben rund 17 Einlösungen pro Sekunde, also etwa 50–85 Requests/s – deutlich unter dem geschätzten Durchsatz. Die Aussage der Entwicklung „ein CPX31 reicht für mehrere hundert Restaurants" ist damit plausibel. Engpässe sind eher:

- **Arbeitsspeicher**: 24 PHP-Prozesse, MySQL-Buffer-Pool 512 MB, Redis, Next.js teilen sich 8 GB.
- **Exporte und Dashboards großer Restaurants** (Aggregationen über viele Buchungen).
- **E-Mail-Spitzen** (z. B. Erinnerungen um 10:00) – laufen über die Queue und blockieren keine Requests.

## 4. Rate Limits

Rate Limits schützen vor Missbrauch und begrenzen zugleich die Last einzelner Clients:

| Limiter | Grenze | Wirkung auf Performance |
|---|---|---|
| `api` | 240/min je Benutzer | begrenzt fehlerhafte Integrationen (Endlosschleifen) |
| `card-scan` | 90/min je Benutzer und Endgerät; Fehlversuche 10 je 5 min je Benutzer und IP | eine Servicekraft mit zwei Geräten wird nicht gebremst |
| `card-operation` | 90/min je Benutzer und Endgerät | |
| `login` | 5/min je E-Mail + IP, 30/min je IP | Schutz vor Passwortangriffen |
| `password-reset` | 5/min je IP | |
| `public-card` | 20/min je IP | Guthabenseite der Gäste |

Die Zähler liegen in Redis. Eine Kassenintegration, die regelmäßig 240/min erreicht, sollte ihr Abfrageverhalten ändern (z. B. keine Abfrage aller Karten im Sekundentakt), statt ein höheres Limit zu verlangen.

## 5. Datenbank

### 5.1 Indizes

| Tabelle | Indizes | Nutzen |
|---|---|---|
| `gift_cards` | `(restaurant_id, card_number)` unique, `(restaurant_id, status, created_at)`, `(restaurant_id, nfc_uid)`, `nfc_uid_active` unique, `public_token` unique, `expires_at`, `status` | Scan per Token oder Nummer, Kartenliste, Klonprüfung, nächtlicher Ablauf |
| `gift_card_transactions` | `idempotency_key` unique je Restaurant, Fremdschlüssel auf Karte | Idempotenz, Kartenverlauf |
| `customers` | `(restaurant_id, email)`, `(restaurant_id, last_name)` | Suche |
| `nfc_scans` | `created_at`, `(restaurant_id, result, created_at)` | Sicherheitsauswertung |
| `audit_logs` | `(restaurant_id, created_at)` | Audit-Ansicht |

Alle Primärschlüssel sind zeitlich geordnete UUIDv7 – neue Zeilen landen am Ende des Index (gute Lokalität beim Schreiben).

### 5.2 Zeilensperren

Jede Guthabenänderung läuft in einer Transaktion mit `SELECT … FROM gift_cards WHERE id = ? FOR UPDATE`:

- Gesperrt wird **nur die eine Karte**, nicht die Tabelle. Einlösungen verschiedener Karten laufen parallel.
- Gleichzeitige Einlösungen **derselben** Karte werden serialisiert – das ist gewollt und verhindert Doppelausgaben.
- `READ-COMMITTED` hält Sperren kurz; Transfers sperren beide Karten in fester Reihenfolge (keine Deadlocks); bei einem Deadlock wird die Transaktion bis zu 3-mal wiederholt.
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
| Laravel-Bootstrap | `config:cache`, `route:cache`, `view:cache`, `event:cache` bei jedem Containerstart | Dateisystem des Containers |
| PHP | OPcache + JIT | Arbeitsspeicher |
| Berechtigungen | Rollen → Berechtigungen, je Rolle gecacht | Redis |
| Systemeinstellungen | `system_settings` gecacht | Redis |
| HTTP | API-Antworten `Cache-Control: no-store, private` – bewusst **kein** HTTP-Caching von Kontoständen | – |
| Browser | React Query hält Serverdaten im Client und invalidiert gezielt nach Änderungen | Browser |
| Statische Dateien | Next.js-Assets mit Hash im Dateinamen; Caddy komprimiert mit `zstd`/`gzip` | Browser, Caddy |

Guthaben werden nie gecacht – jede Einlösung liest den gesperrten Datensatz aus der Datenbank.

## 7. Frontend

- Diagramme des Dashboards werden erst nach den Kennzahlen geladen (`next/dynamic`) – Kennzahlen erscheinen zuerst.
- Die Kellner-App hält den NFC-Leser aktiv, auch auf dem Erfolgsbildschirm; die nächste Karte kann sofort angetippt werden.
- Die Oberfläche passt ohne Scrollen auf kleine Handys (iPhone SE), was Bedienzeit spart.

## 8. Skalierung

| Stufe | Maßnahme | Wann |
|---|---|---|
| 1 | Größerer Server (mehr vCPU/RAM), `pm.max_children` und `innodb-buffer-pool-size` anheben | RAM > 80 % oder CPU in Spitzen > 70 % |
| 2 | Mehrere `api`- und `web`-Replikate hinter Caddy (`reverse_proxy` mit mehreren Upstreams). Die Anwendung ist zustandslos; Sessions, Cache und Sperren liegen in Redis. | CPU-Engpass bei PHP |
| 3 | MySQL auf einen eigenen Server oder Managed MySQL auslagern | Datenbank konkurriert mit PHP um Ressourcen |
| 4 | Read Replica für Exporte und Auswertungen | große Exporte beeinflussen die Antwortzeiten |
| 5 | Eigene Instanz je Großkunde (Single Tenant) mit denselben Images | Isolationsanforderung eines Gruppe-Kunden |

Hinweise für Stufe 2: Der Scheduler darf nur **einmal** laufen (`onOneServer()` ist gesetzt und nutzt Redis-Sperren, ein zusätzlicher Scheduler-Container ist trotzdem nicht nötig). Migrationen laufen durch `--isolated` nur in einem Container.

## 9. Messen

### 9.1 Abnahmetest

Der Abnahmetest `e2e/pilot-journey.mjs` misst die Einlösung durch die Servicekraft und schlägt fehl, wenn sie 5 Sekunden überschreitet. Vor jedem Release ausführen und die gemessene Zeit im Release-Protokoll festhalten – ein Anstieg gegenüber dem Referenzwert (0,48 s) ist ein Warnsignal.

```bash
cd e2e
ADMIN_EMAIL=admin@giftcardpro.test ADMIN_PASSWORD='Password123!' npm test
```

### 9.2 Antwortzeiten in Produktion

```bash
curl -o /dev/null -s -w "connect=%{time_connect}s tls=%{time_appconnect}s total=%{time_total}s\n" https://app.giftcardpro.at/up
```

Das Caddy-Zugriffslog enthält je Request das Feld `duration` (Sekunden):

```bash
docker compose --env-file .env.production logs --no-log-prefix --since 1h caddy \
  | jq -r 'select(.request.uri? | startswith("/api/v1/scan")) | .duration' \
  | sort -n | awk '{a[NR]=$1} END {print "p50="a[int(NR*0.5)]" p95="a[int(NR*0.95)]" n="NR}'
```

### 9.3 Lasttest (Empfehlung)

Lasttests nur gegen eine **Staging-Umgebung** mit gleicher Servergröße, nie gegen Produktion (Rate Limits, Ledger-Einträge). Werkzeug z. B. k6; Szenario: viele Endgeräte mit eigenen `X-Device-Id` und API-Tokens, je Gerät Scan + Einlösung mit neuem `Idempotency-Key`. Nach dem Test die Ledger-Prüfung aus der [Restore-Anleitung](restore-guide.md#8-prüfabfragen-nach-einem-restore) ausführen.

## 10. Checkliste

- [ ] `APP_DEBUG=false`, `APP_ENV=production` (sonst deutlich langsamer)
- [ ] `CACHE_STORE=redis`, `SESSION_DRIVER=redis`, `QUEUE_CONNECTION=redis`
- [ ] Container `queue` läuft (sonst warten E-Mails, nicht die Requests)
- [ ] `/up` antwortet in < 300 ms
- [ ] Abnahmetest: Einlösung < 1 s Systemzeit
- [ ] RAM < 75 %, keine Swap-Nutzung
- [ ] Festplatte < 70 %
- [ ] Keine wachsende Queue
- [ ] Neue Datenbankabfragen in Pull Requests mit `EXPLAIN` geprüft; neue Filter nur mit passendem Index
- [ ] Neue Geldpfade sperren nur die betroffenen Karten, keine Tabellen
- [ ] Keine Guthaben- oder Berechtigungsdaten im HTTP-Cache

---

Version 1.0 · Stand: September 2026
