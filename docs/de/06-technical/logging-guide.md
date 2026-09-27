# Logging-Leitfaden

> **Hinweis (Coolify-Deployment):** Produktion läuft seit 1.4.2 auf **Coolify** mit `docker-compose.coolify.yml` (Build aus dem Quellcode, kein GHCR, keine Deploy-Skripte). Befehle mit `docker compose --env-file .env.production`, `infra/scripts/…`, `deploy.yml` oder Caddy auf dem Host in diesem Dokument sind überholt. Maßgeblich sind [docs/DEPLOYMENT.md](../../DEPLOYMENT.md) (Deployment, Backups, Restore, Betrieb) und [docs/ENVIRONMENT.md](../../ENVIRONMENT.md).

*Log-Quellen von GiftCard Pro, Log-Level, Abgrenzung zu Audit-Log und Scan-Protokoll, personenbezogene Daten, Korrelation über X-Request-Id, Suche, Aufbewahrung und DSGVO.*

---

## 1. Überblick

GiftCard Pro kennt drei Arten von Aufzeichnungen mit unterschiedlichem Zweck:

| Art | Speicherort | Zweck | Aufbewahrung |
|---|---|---|---|
| **Betriebslogs** | Docker-Logs der Container (stdout/stderr) | Fehlersuche, Monitoring, Sicherheitsalarme | kurz (Rotation, siehe Abschnitt 3) |
| **Audit-Log** | Tabelle `audit_logs` (append-only) | Nachvollziehbarkeit sicherheits- und geldrelevanter Aktionen für Restaurants und Plattform | dauerhaft (nichts wird gelöscht) |
| **Scan-Protokoll** | Tabelle `nfc_scans` (append-only) | jede Kartenabfrage mit Ergebnis – Betrugserkennung | dauerhaft |

Das **Ledger** (`gift_card_transactions`) ist keine Log-Datei, sondern die buchhalterische Wahrheit: Jede Guthabenänderung ist dort mit Person, Gerät, IP und Zeitstempel gespeichert.

## 2. Log-Quellen

| Quelle | Container | Format | Inhalt |
|---|---|---|---|
| Laravel (API) | `api` | Text, eine Zeile pro Eintrag, Kontext als JSON (Monolog-Standardformat) | Fehler und Ausnahmen, Sicherheitswarnungen, Hinweise |
| PHP-FPM | `api` | Text | Ausgaben der Worker (`catch_workers_output = yes`), PHP-Fehler (`log_errors = On`); je nach Basis-Image zusätzlich FPM-Zugriffszeilen |
| Queue-Worker | `queue` | Text | Verarbeitete Jobs (`RUNNING`/`DONE`/`FAIL`), Fehler beim Mailversand |
| Scheduler | `scheduler` | Text | Ausgeführte Befehle der nächtlichen Jobs |
| Caddy | `caddy` | **JSON** | Zugriffslog (jeder Request: Methode, URI, Status, Dauer, Client-IP, User-Agent, Header) und Caddy-eigene Meldungen (Zertifikate) |
| Next.js | `web` | Text | Start, serverseitige Fehler |
| MySQL | `mysql` | Text | Start, Fehler, Warnungen |
| Redis | `redis` | Text | Start, AOF-Meldungen, Fehler |

Konfiguration der Laravel-Ausgabe (aus `backend/.env.production.example`):

```dotenv
LOG_CHANNEL=stderr
LOG_LEVEL=info
```

Der Kanal `stderr` schreibt nach `php://stderr`; Docker sammelt die Ausgabe. Für JSON-Ausgabe kann die Laravel-Standardvariable `LOG_STDERR_FORMATTER=Monolog\Formatter\JsonFormatter` gesetzt werden (ist in der Vorlage nicht gesetzt; erleichtert maschinelle Auswertung bei einem Log-Versand).

Lokal (`backend/.env.example`): `LOG_CHANNEL=stack`, `LOG_STACK=daily`, `LOG_LEVEL=debug` → Dateien `backend/storage/logs/laravel-YYYY-MM-DD.log`, 14 Tage (`LOG_DAILY_DAYS`).

## 3. Rotation der Container-Logs

Alle Dienste in `docker-compose.yml` verwenden:

```yaml
logging:
  driver: json-file
  options: { max-size: "20m", max-file: "5" }
```

Pro Container werden höchstens 5 Dateien à 20 MB (= 100 MB) aufbewahrt; ältere Einträge werden überschrieben. Wie viele Tage das abdeckt, hängt vom Verkehr ab – bei `caddy` (ein Eintrag pro Request) am wenigsten. Wird ein Container neu erstellt (z. B. bei jedem Deployment), beginnen seine Logs neu; die alten sind danach nicht mehr über `docker compose logs` abrufbar.

**Folge:** Container-Logs sind kein Archiv. Was länger gebraucht wird, steht im Audit-Log, in `nfc_scans` oder muss per Log-Versand gesichert werden (Abschnitt 8).

## 4. Log-Level

| Level | Verwendung in GiftCard Pro |
|---|---|
| `debug` | Nur lokal. Der `log`-Mailer schreibt E-Mails (Einladungen, Reset-Links) auf dieser Ebene – **in Produktion nie aktivieren**, sonst stehen gültige Links im Log. |
| `info` | Produktionsstandard (`LOG_LEVEL=info`) |
| `notice` | Framework-Hinweise |
| `warning` | **Sicherheitsereignisse**: `Suspicious gift card scan`, `Account locked after repeated failed logins` |
| `error` | Ausnahmen, fehlgeschlagene Jobs, nicht erreichbare Dienste |
| `critical`, `alert`, `emergency` | Schwerwiegende Fehler |

Empfehlungen:

- Produktion: `info`. `warning` wäre möglich, spart aber kaum Volumen und verdeckt Kontext.
- Fehlersuche in Produktion: `LOG_LEVEL` nicht auf `debug` stellen (siehe oben). Stattdessen gezielt mit `X-Request-Id` suchen.
- Eine Änderung von `LOG_LEVEL` wirkt erst nach Neustart der Container (`config:cache` beim Start).

## 5. Was wo protokolliert wird

| Ereignis | Betriebslog | Audit-Log | `nfc_scans` | Ledger |
|---|---|---|---|---|
| Kartenabfrage erfolgreich | – | – | ✓ (`ok`) | – |
| Karte nicht gefunden | – | – | ✓ (`not_found`) | – |
| Fremde Karte, UID-Abweichung, ungültige Signatur, Replay | ✓ `warning` | ✓ (Sicherheitsereignis) | ✓ | – |
| Abfrage gedrosselt (`throttled`) | ✓ `warning` | – | ✓ | – |
| Einlösung, Aufladung, Transfer, Storno, Ablauf, Verkauf | – | ✓ | – | ✓ |
| Karte sperren, entsperren, ersetzen, aktivieren | – | ✓ | – | ✓ bei Guthabenbewegung |
| Anmeldung, Abmeldung | – | ✓ | – | – |
| Einzelne fehlgeschlagene Anmeldung | – | – (Zähler am Benutzerkonto) | – | – |
| Kontosperre | ✓ `warning` | ✓ | – | – |
| Team-, Geräte-, Token-, Einstellungsänderungen | – | ✓ | – | – |
| Plattform-Administrator handelt in einem Restaurant | – | ✓ | – | – |
| Ausnahme / Serverfehler | ✓ `error` | – | – | – |
| E-Mail-Versand | Queue-Log | – | – | – (Tabelle `notification_logs`) |
| HTTP-Request | Caddy ✓ | – | – | – |

### Inhalte des Audit-Logs

`audit_logs` enthält: `restaurant_id`, `user_id`, `device_id`, `action` (z. B. `gift_card.blocked`), betroffenes Objekt, `old_values`, `new_values`, `metadata`, `ip_address`, `user_agent`, `request_id`, `created_at` (Mikrosekunden). Einsehbar für Restaurants unter **Audit log** (`audit.view`), für die Plattform unter der Plattformadministration.

### Inhalte von `nfc_scans`

`restaurant_id`, `gift_card_id` (leer bei unbekannten oder fremden Karten), `user_id`, `device_id`, `method`, `result` (`ok`, `not_found`, `foreign_restaurant`, `uid_mismatch`, `invalid_signature`, `replay`, `throttled`), `nfc_uid`, `read_counter`, `ip_address`, `user_agent`, `created_at`.

## 6. Personenbezogene Daten in Logs

| Aufzeichnung | Personenbezogene Daten | Schutzmaßnahme |
|---|---|---|
| Audit-Log `old_values`/`new_values` | **keine** Kundennamen, E-Mail-Adressen, Telefonnummern, Notizen oder Empfängernamen – nur die Tatsache, dass sie geändert wurden | `AuditLogger` redigiert Passwörter, Tokens und Karten-Tokens; personenbezogene Felder werden nicht kopiert (Test `HardeningTest`) |
| Audit-Log `ip_address`, `user_agent`, `user_id` | IP-Adressen und Browserkennung der Mitarbeitenden | Zweck: Sicherheit und Nachvollziehbarkeit; Zugriff nur mit `audit.view` |
| `nfc_scans` | IP-Adresse, User-Agent, Chip-UID | Zweck: Betrugserkennung |
| Ledger | Benutzer, Gerät, IP | Aufbewahrungspflicht (BAO § 132) |
| Laravel-Log (`warning`) | `user_id`, `ip`, `nfc_uid` | kurze Aufbewahrung durch Rotation |
| Caddy-Zugriffslog | Client-IP, User-Agent, vollständige URI – auch `/c/{token}` und `/api/v1/public/cards/{token}` (Karten-Token) | Caddy schwärzt standardmäßig `Cookie`, `Set-Cookie` und `Authorization`; kurze Aufbewahrung durch Rotation |
| `notification_logs` | E-Mail-Adresse der Empfänger | wird bei DSGVO-Anonymisierung entfernt |

Hinweise:

- **Karten-Tokens im Zugriffslog:** Wer das Caddy-Log liest, sieht Karten-URLs. Ein Token erlaubt nur die öffentliche Guthabenanzeige (sofern aktiviert), keine Einlösung. Trotzdem: Zugriff auf Server-Logs auf das Betriebsteam beschränken und Logs bei einem Versand nicht an Dritte außerhalb der EU übermitteln.
- **Keine Gästedaten in Betriebslogs:** Namen, E-Mail-Adressen und Telefonnummern von Gästen erscheinen nicht in den Laravel-Logs. Bei eigenen Erweiterungen niemals Request-Bodies oder Modelle mit Kundendaten loggen.
- **Keine Passwörter:** Werden nirgends protokolliert.

## 7. Korrelation über `X-Request-Id`

Jeder API-Request erhält eine Korrelations-ID:

1. Der Client sendet `X-Request-Id` (8–64 Zeichen `[A-Za-z0-9-]`) – sonst erzeugt der Server eine UUID.
2. Die ID steht in **jeder** Laravel-Logzeile dieses Requests (Kontextfeld `request_id`).
3. Sie wird im Audit-Log gespeichert (`audit_logs.request_id`).
4. Sie wird in der Antwort als Header `X-Request-Id` zurückgegeben – und erscheint damit auch im Caddy-Zugriffslog unter den Antwort-Headern.

Vorgehen bei einer Support-Anfrage („Einlösung um 20:14 hat nicht funktioniert"):

```bash
# 1. find the request in the Caddy log (time range, path, status)
docker compose --env-file .env.production logs --no-log-prefix --since 2h caddy \
  | jq -c 'select(.request.uri? | test("/redeem")) | {ts, status, uri: .request.uri, rid: .resp_headers["X-Request-Id"]}'

# 2. Laravel entries for this id
docker compose --env-file .env.production logs --since 2h api | grep "<request-id>"
```

```sql
-- 3. audit entries for this id
SELECT created_at, action, user_id, device_id, ip_address FROM audit_logs WHERE request_id = '<request-id>';
```

Integrationen (z. B. Kassen) sollten eine eigene `X-Request-Id` senden und protokollieren.

## 8. Logs durchsuchen

```bash
cd /opt/giftcard-pro
alias dc='docker compose --env-file .env.production'

dc logs -f api queue                          # live
dc logs --since 1h api                        # last hour
dc logs --since 2026-10-14T18:00:00 --until 2026-10-14T19:00:00 api
dc logs --since 24h api | grep -E "ERROR|CRITICAL"
dc logs --since 24h api | grep -E "Suspicious gift card scan|Account locked"
dc logs --since 24h queue | grep FAIL

# Caddy (JSON): all 5xx of the last hour
dc logs --no-log-prefix --since 1h caddy | jq -c 'select(.status? >= 500) | {ts, status, uri: .request.uri, ip: .request.client_ip}'

# Caddy: requests per status
dc logs --no-log-prefix --since 1h caddy | jq -r 'select(.status?) | .status' | sort | uniq -c
```

`jq` auf dem Server installieren: `sudo apt -y install jq`.

### Log-Versand (Empfehlung)

Für Alarme auf Log-Zeilen und Aufbewahrung über die Rotation hinaus die Container-Logs an ein zentrales System senden, z. B. mit Vector oder Promtail an Loki/Grafana oder an einen Log-Dienst mit **EU-Standort**. Dabei gilt:

- Auftragsverarbeitungsvertrag mit dem Anbieter abschließen und in die Liste der Sub-Auftragsverarbeiter aufnehmen.
- Aufbewahrung im Zielsystem gemäß Abschnitt 9 konfigurieren.

## 9. Aufbewahrung und DSGVO

| Aufzeichnung | Ist-Stand | Empfehlung | Begründung |
|---|---|---|---|
| Container-Logs | Rotation 5 × 20 MB je Container | so belassen | kurzfristige Fehlersuche |
| Zentral gesammelte Logs (falls eingerichtet) | – | 30 Tage, Sicherheitsereignisse (`warning`) 90 Tage | Fehlersuche, Nachweis von Angriffen |
| Audit-Log | dauerhaft | dauerhaft behalten; IP-Adressen nach [z. B. 12 Monaten] pseudonymisieren (derzeit keine Funktion – Roadmap Betrieb) | Nachvollziehbarkeit geldrelevanter Aktionen, berechtigtes Interesse (Art. 6 Abs. 1 lit. f DSGVO) |
| `nfc_scans` | dauerhaft | wie Audit-Log | Betrugserkennung |
| Ledger | dauerhaft | dauerhaft (mindestens 7 Jahre, BAO § 132) | gesetzliche Aufbewahrungspflicht |
| Backups | 14 Tage (siehe [Backup-Anleitung](backup-guide.md)) | siehe dort | Wiederherstellung |

Weitere Punkte:

- Die Aufbewahrungsfristen gehören in das Verzeichnis der Verarbeitungstätigkeiten und in die technischen und organisatorischen Maßnahmen (TOM) zum Auftragsverarbeitungsvertrag mit den Restaurants.
- Auskunftsersuchen (Art. 15 DSGVO) von Mitarbeitenden der Restaurants betreffen auch IP-Adressen im Audit-Log; die Restaurants sind dafür Verantwortliche, GiftCard Pro unterstützt als Auftragsverarbeiter.
- Keine Rechtsberatung – mit Rechtsanwalt prüfen.

---

Version 1.0 · Stand: September 2026
