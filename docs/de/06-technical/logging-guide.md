# Logging-Leitfaden

*Log-Quellen von GiftCard Pro, Log-Level, Abgrenzung zu Audit-Log und Ledger, personenbezogene Daten, Korrelation über X-Request-Id, Suche, Aufbewahrung und DSGVO.*

---

## 1. Überblick

GiftCard Pro kennt drei Arten von Aufzeichnungen mit unterschiedlichem Zweck:

| Art | Speicherort | Zweck | Aufbewahrung |
|---|---|---|---|
| **Betriebslogs** | Docker-Logs der Container (stdout/stderr), in Coolify unter Ressource → *Logs* | Fehlersuche, Monitoring, Sicherheitsalarme | kurz (Rotation, siehe Abschnitt 3) |
| **Audit-Log** | Tabelle `audit_logs` (append-only, Hash-Kette je Lokal) | Nachvollziehbarkeit sicherheits- und geldrelevanter Aktionen für Lokale und Plattform, auch jede fehlgeschlagene Vorlage | dauerhaft (nichts wird geändert oder gelöscht) |
| **Ledger und Zahlungen** | Tabellen `voucher_transactions`, `payments` (append-only, Hash-Kette je Lokal) | Buchhalterische Wahrheit: jede Guthabenänderung mit Person, Gerät, IP und Zeitstempel; jede Zahlung eines Verkaufs oder einer Aufladung | dauerhaft |

Datenbank-Trigger lehnen `UPDATE` und `DELETE` auf Ledger, Zahlungen und Audit-Log ab; `php artisan giftcard:verify-chains` prüft jede Nacht, dass keine Zeile geändert, gelöscht, eingefügt oder umsortiert wurde.

## 2. Log-Quellen

| Quelle | Container | Format | Inhalt |
|---|---|---|---|
| Laravel (API) | `api` | Text, eine Zeile pro Eintrag, Kontext als JSON (Monolog-Standardformat) | Fehler und Ausnahmen, Sicherheitswarnungen, Hinweise |
| PHP-FPM | `api` | Text | Ausgaben der Worker, PHP-Fehler; Requests werden nach 30 s beendet (`request_terminate_timeout`) |
| Queue-Worker | `worker` | Text | Verarbeitete Jobs (`RUNNING`/`DONE`/`FAIL`), Fehler beim Mailversand |
| Scheduler | `scheduler` | Text | Ausgeführte Befehle der nächtlichen Jobs, Ergebnis der Integritätsprüfung |
| Gateway (Caddy) | `gateway` | **JSON** | Zugriffslog (jeder Request: Methode, URI ohne sensible Query-Parameter, Status, Dauer, Client-IP, User-Agent, Header ohne Geheimnisse) und Caddy-eigene Meldungen |
| Next.js | `web` | Text | Start, serverseitige Fehler |
| MySQL | `mysql` | Text | Start, Fehler, Warnungen |
| Redis | `redis` | Text | Start, AOF-Meldungen, Fehler |
| Backup | `backup` | Text | „Backup written: …“ bzw. „Backup FAILED“ |

Die Laravel-Ausgabe ist im Coolify-Stack fest auf `LOG_CHANNEL=stderr` gesetzt; `LOG_LEVEL` ist `info` (in Coolify änderbar). Für JSON-Ausgabe kann die Laravel-Standardvariable `LOG_STDERR_FORMATTER=Monolog\Formatter\JsonFormatter` gesetzt werden (erleichtert maschinelle Auswertung bei einem Log-Versand).

Lokal (`backend/.env.example`): `LOG_CHANNEL=stack`, `LOG_STACK=daily`, `LOG_LEVEL=debug` → Dateien `backend/storage/logs/laravel-YYYY-MM-DD.log`, 14 Tage (`LOG_DAILY_DAYS`).

## 3. Rotation der Container-Logs

Alle Dienste in `docker-compose.coolify.yml` verwenden:

```yaml
logging:
  driver: json-file
  options: { max-size: "10m", max-file: "5" }
```

Pro Container werden höchstens 5 Dateien à 10 MB (= 50 MB) aufbewahrt; ältere Einträge werden überschrieben. Wie viele Tage das abdeckt, hängt vom Verkehr ab – beim `gateway` (ein Eintrag pro Request) am wenigsten. Wird ein Container neu erstellt (z. B. bei jedem Deployment), beginnen seine Logs neu.

**Folge:** Container-Logs sind kein Archiv. Was länger gebraucht wird, steht im Audit-Log oder muss per Log-Versand gesichert werden (Abschnitt 8).

## 4. Log-Level

| Level | Verwendung in GiftCard Pro |
|---|---|
| `debug` | Nur lokal. Der `log`-Mailer schreibt E-Mails auf dieser Ebene – **in Produktion nie aktivieren**. |
| `info` | Produktionsstandard (`LOG_LEVEL=info`), z. B. „Platform test e-mail requested“ |
| `warning` | **Sicherheitsereignis**: `Account locked after repeated failed logins` (mit `user_id`, `ip`, `attempts`) |
| `error` | Ausnahmen, fehlgeschlagene Jobs, nicht zustellbare Betriebswarnungen |
| `critical` | `Integrity check failed: financial history or audit log does not verify`, `Queue backlog above threshold` |
| `alert`, `emergency` | Schwerwiegende Fehler |

Empfehlungen:

- Produktion: `info`.
- Fehlersuche in Produktion: `LOG_LEVEL` nicht auf `debug` stellen. Stattdessen gezielt mit `X-Request-Id` suchen.
- Eine Änderung von `LOG_LEVEL` wirkt erst nach *Redeploy* (die Konfiguration wird beim Containerstart gecacht).

## 5. Was wo protokolliert wird

| Ereignis | Betriebslog | Audit-Log | Ledger / Zahlungen |
|---|---|---|---|
| Vorlage erfolgreich (`POST /presentments`) | – | – (Zeile in `presentments`) | – |
| Vorlage fehlgeschlagen (QR unbekannt, widerrufen, fremd) | – | ✓ `presentment.failed` | – |
| Vorlage abgelehnt (falsche Methode, gedrosselt) | – | ✓ `presentment.rejected` | – |
| Verkauf, Einlösung, Aufladung, Storno | – | ✓ `voucher.sold`, `voucher.redeemed`, `voucher.reloaded`, `transaction.reversed` | ✓ (Verkauf und Aufladung mit Zahlung) |
| Gutschein sperren, entsperren, ablaufen, wieder freigeben, bearbeiten | – | ✓ `voucher.blocked`, `voucher.unblocked`, `voucher.expired`, `voucher.reinstated`, `voucher.updated` | – (das Guthaben bleibt) |
| Anmeldung, Abmeldung | – | ✓ `auth.login`, `auth.logout` | – |
| Fehlgeschlagene Anmeldung bei bekanntem Konto | – | ✓ `auth.failed`, bei gesperrtem Konto `auth.locked_attempt` | – |
| Kontosperre | ✓ `warning` | ✓ `auth.locked` | – |
| Passwortänderung oder -zurücksetzung (widerruft Zugänge) | – | ✓ `user.password_changed`, `auth.access_revoked` | – |
| Team-, Geräte-, Token-, Einstellungsänderungen | – | ✓ | – |
| Plattformadministration (Lokal anlegen, sperren, archivieren, löschen) | – | ✓ `restaurant.*` | – |
| Integritätsprüfung schlägt fehl | ✓ `critical` + E-Mail an `OPS_ALERT_EMAIL` | – | – |
| Ausnahme / Serverfehler | ✓ `error` | – | – |
| E-Mail-Versand | Log des `worker` | – | – (Tabelle `notification_logs`) |
| HTTP-Request | Gateway ✓ | – | – |

### Inhalte des Audit-Logs

`audit_logs` enthält: `restaurant_id`, `user_id`, `device_id`, `action` (z. B. `voucher.blocked`, `presentment.failed`), betroffenes Objekt, `old_values`, `new_values`, `metadata`, `ip_address`, `user_agent`, `request_id`, `created_at` (Mikrosekunden) sowie die Hash-Kette (`chain_scope`, `chain_seq`, `prev_hash`, `entry_hash`). Einsehbar für Lokale unter **Audit log** (`audit.view`), für die Plattform unter der Plattformadministration.

## 6. Personenbezogene Daten in Logs

| Aufzeichnung | Personenbezogene Daten | Schutzmaßnahme |
|---|---|---|
| Audit-Log `old_values`/`new_values`/`metadata` | **keine** Kundennamen, E-Mail-Adressen, Telefonnummern, Notizen oder Empfängernamen – nur die Tatsache, dass sie geändert wurden | `AuditLogger` redigiert Passwörter, Tokens und Geheimnis-Hashes; personenbezogene Felder werden nicht kopiert |
| Audit-Log `ip_address`, `user_agent`, `user_id` | IP-Adressen und Browserkennung der Mitarbeitenden | Zweck: Sicherheit und Nachvollziehbarkeit; Zugriff nur mit `audit.view` |
| Ledger, Zahlungen | Person, Gerät, IP; Belegreferenz | Aufbewahrungspflicht (BAO § 132) |
| Laravel-Log (`warning`) | `user_id`, `ip` | kurze Aufbewahrung durch Rotation |
| Gateway-Zugriffslog | Client-IP, User-Agent, URI | Die Query-Parameter `token`, `email`, `e`, `m` und die Header `Cookie`, `Authorization`, `X-Device-Id`, `Idempotency-Key` und `Set-Cookie` werden nicht protokolliert; kurze Aufbewahrung durch Rotation |
| `notification_logs` | E-Mail-Adresse der Empfänger | wird bei DSGVO-Anonymisierung entfernt |

Hinweise:

- **Keine Geheimnisse in Logs:** Tokens für Passwortzurücksetzung und Einladung stehen im URL-Fragment und erreichen nie einen Server. Die QR-Nutzlast eines Gutscheins ist keine URL und wird im Body gesendet; sie erscheint weder im Zugriffslog noch im Audit-Log.
- **Keine Gästedaten in Betriebslogs:** Namen, E-Mail-Adressen und Telefonnummern von Gästen erscheinen nicht in den Laravel-Logs. Bei eigenen Erweiterungen niemals Request-Bodies oder Modelle mit Kundendaten loggen.
- **Keine Passwörter:** Werden nirgends protokolliert.

## 7. Korrelation über `X-Request-Id`

Jeder API-Request erhält eine Korrelations-ID:

1. Der Client sendet `X-Request-Id` (8–64 Zeichen) – sonst erzeugt der Server eine.
2. Die ID steht im Kontext der Laravel-Logzeilen dieses Requests.
3. Sie wird im Audit-Log gespeichert (`audit_logs.request_id`).
4. Sie wird in der Antwort als Header `X-Request-Id` zurückgegeben – und erscheint damit auch im Gateway-Zugriffslog unter den Antwort-Headern.

Vorgehen bei einer Support-Anfrage („Einlösung um 20:14 hat nicht funktioniert“): Coolify → *Logs* → Dienst **gateway** bzw. **api** im Zeitraum durchsuchen, oder am Server (als root; Container-Namen mit `docker ps` ermitteln):

```bash
# 1. find the request in the gateway log (time range, path, status)
docker logs --since 2h <gateway-container> 2>&1 \
  | jq -c 'select(.request.uri? | test("/redemptions")) | {ts, status, uri: .request.uri, rid: .resp_headers["X-Request-Id"]}'

# 2. Laravel entries for this id
docker logs --since 2h <api-container> 2>&1 | grep "<request-id>"
```

```sql
-- 3. audit entries for this id
SELECT created_at, action, user_id, device_id, ip_address FROM audit_logs WHERE request_id = '<request-id>';
```

Ob eine Einlösung trotz verlorener Antwort gebucht wurde, beantwortet `GET /vouchers/{id}/redemptions/{idempotencyKey}` – Kellner-App und Web-Kassa fragen das selbst ab. Integrationen (z. B. Kassen) sollten eine eigene `X-Request-Id` senden und protokollieren.

## 8. Logs durchsuchen

In Coolify: Ressource → *Logs* → Dienst wählen (Live-Ansicht und Suche). Am Server (als root):

```bash
docker ps --format '{{.Names}}' | grep -E 'api|worker|gateway'   # container names
docker logs -f <api-container>                                    # live
docker logs --since 1h <api-container>                            # last hour
docker logs --since 24h <api-container> 2>&1 | grep -E "ERROR|CRITICAL"
docker logs --since 24h <api-container> 2>&1 | grep -E "Account locked|Integrity check failed"
docker logs --since 24h <worker-container> 2>&1 | grep FAIL

# gateway (JSON): all 5xx of the last hour
docker logs --since 1h <gateway-container> 2>&1 | jq -c 'select(.status? >= 500) | {ts, status, uri: .request.uri, ip: .request.client_ip}'

# gateway: requests per status
docker logs --since 1h <gateway-container> 2>&1 | jq -r 'select(.status?) | .status' | sort | uniq -c
```

`jq` auf dem Server installieren: `apt -y install jq`. Fehlgeschlagene Vorlagen stehen nicht im Betriebslog, sondern im Audit-Log (**Audit log**, Filter `presentment.`).

### Log-Versand (Empfehlung)

Für Alarme auf Log-Zeilen und Aufbewahrung über die Rotation hinaus die Container-Logs an ein zentrales System senden, z. B. mit Vector oder Promtail an Loki/Grafana oder an einen Log-Dienst mit **EU-Standort**. Dabei gilt:

- Auftragsverarbeitungsvertrag mit dem Anbieter abschließen und in die Liste der Sub-Auftragsverarbeiter aufnehmen.
- Aufbewahrung im Zielsystem gemäß Abschnitt 9 konfigurieren.

## 9. Aufbewahrung und DSGVO

| Aufzeichnung | Ist-Stand | Empfehlung | Begründung |
|---|---|---|---|
| Container-Logs | Rotation 5 × 10 MB je Container | so belassen | kurzfristige Fehlersuche |
| Zentral gesammelte Logs (falls eingerichtet) | – | 30 Tage, Sicherheitsereignisse (`warning` und höher) 90 Tage | Fehlersuche, Nachweis von Angriffen |
| Audit-Log | dauerhaft, unveränderlich | dauerhaft behalten | Nachvollziehbarkeit geldrelevanter Aktionen, berechtigtes Interesse (Art. 6 Abs. 1 lit. f DSGVO) |
| Ledger und Zahlungen | dauerhaft, unveränderlich | dauerhaft (mindestens 7 Jahre, BAO § 132) | gesetzliche Aufbewahrungspflicht |
| Backups | `BACKUP_KEEP_DAYS` (siehe [Backup-Anleitung](backup-guide.md)) | siehe dort | Wiederherstellung |

Weitere Punkte:

- Die Aufbewahrungsfristen gehören in das Verzeichnis der Verarbeitungstätigkeiten und in die technischen und organisatorischen Maßnahmen (TOM) zum Auftragsverarbeitungsvertrag mit den Lokalen.
- Auskunftsersuchen (Art. 15 DSGVO) von Mitarbeitenden der Lokale betreffen auch IP-Adressen im Audit-Log; die Lokale sind dafür Verantwortliche, GiftCard Pro unterstützt als Auftragsverarbeiter.
- Keine Rechtsberatung – mit Rechtsanwalt prüfen.

---

Version 2.0 · Stand: September 2026
