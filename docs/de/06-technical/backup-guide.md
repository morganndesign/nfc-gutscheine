# Backup-Anleitung

*Was bei GiftCard Pro gesichert wird und was nicht, wie die Sicherung im Coolify-Stack läuft, wie sie verschlüsselt, geprüft und überwacht wird, und welche Aufbewahrung empfohlen ist. Englische Referenz: [docs/DEPLOYMENT.md → Backups](../../DEPLOYMENT.md#backups).*

---

## 1. Überblick

Die Datenbank ist das einzige System, dessen Verlust nicht ersetzbar ist: Sie enthält das Ledger (jede Buchung jedes Gutscheins), die Zahlungen, die Gutscheinstatus, die Hashes der QR-Codes, Kundendaten und das Audit-Log. Alles andere lässt sich aus Git (Coolify baut jedes Image aus dem Quellcode) oder dem Passwortmanager neu aufbauen.

| Ebene | Was | Wann | Aufbewahrung | Ort |
|---|---|---|---|---|
| 1 | Logischer MySQL-Dump (`mysqldump`, gzip) im Dienst `backup` | täglich um `BACKUP_TIME` (UTC, Standard 01:30) | `BACKUP_KEEP_DAYS` (Standard 14 Tage) | Docker-Volume `mysql-backups` am Server |
| 2 | Off-site-Kopie der Dumps (`rclone sync`, Root-Cron am Server) | täglich, nach Ebene 1 | spiegelt Ebene 1 (siehe Abschnitt 7) | z. B. Hetzner Storage Box |
| 3 | Server-Snapshot (Hetzner Backups) | täglich, Zeitfenster von Hetzner | durch Hetzner rotiert (bis zu 7 Sicherungen) | Hetzner Cloud |

Alle Daten bleiben in Rechenzentren von Hetzner in Deutschland (EU).

## 2. Was gesichert wird

### 2.1 Datenbank-Dump

Der Dienst `backup` in `docker-compose.coolify.yml` (Image `mysql:8.4`) wartet bis `BACKUP_TIME` (UTC) und schreibt dann:

```sh
mysqldump -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --quick --routines --triggers --no-tablespaces "$MYSQL_DATABASE" \
  | gzip -9 > /backups/giftcard_pro_<UTC timestamp>.sql.gz
find /backups -name 'giftcard_pro_*.sql.gz' -mtime +"$BACKUP_KEEP_DAYS" -delete
```

| Eigenschaft | Wert |
|---|---|
| Dateiname | `giftcard_pro_<YYYYMMDD>T<HHMMSS>Z.sql.gz` (Zeitstempel in UTC) |
| Konsistenz | `--single-transaction`: konsistenter Stand aller InnoDB-Tabellen ohne Sperren – der Betrieb läuft weiter |
| Umfang | gesamte Datenbank inklusive Routinen und der **Append-only-Trigger** (`--triggers`) |
| Schreibweise | zuerst `.part`, erst nach Erfolg umbenannt; ein Fehler schreibt „Backup FAILED“ ins Log des Dienstes |
| Lokale Aufbewahrung | Dateien älter als `BACKUP_KEEP_DAYS` werden beim nächsten Lauf gelöscht |

Enthalten sind damit alle Tabellen: `restaurants`, `restaurant_settings`, `system_settings`, `roles`, `permissions`, `permission_role`, `users`, `password_reset_tokens`, `invitation_tokens`, `sessions`, `devices`, `personal_access_tokens`, `customers`, `vouchers`, `media`, `presentments`, `payments`, `voucher_transactions` (Ledger), `chain_heads`, `audit_logs`, `notification_templates`, `notification_logs`, `cache`, `cache_locks`, `job_batches`, `failed_jobs`. Ledger, Zahlungen und Audit-Log werden mit ihren Hash-Ketten gesichert; nach jedem Restore bestätigt `php artisan giftcard:verify-chains`, dass sie vollständig und unverändert sind.

### 2.2 Sofortiges Backup

Vor einem Eingriff: Coolify → *Terminal* → Container **backup** →

```bash
mysqldump -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers --no-tablespaces "$MYSQL_DATABASE" | gzip > /backups/manual_$(date -u +%Y%m%dT%H%M%SZ).sql.gz
ls -lh /backups
```

### 2.3 Off-site-Kopie einrichten

Das Volume liegt auf derselben Festplatte wie die Datenbank. Auf dem Server (als root):

```bash
docker volume ls | grep mysql-backups          # full volume name
apt -y install rclone
rclone config                                  # new remote "storagebox", type sftp, host <user>.your-storagebox.de, port 23, SSH key
rclone lsd storagebox:                         # test the connection
```

```cron
# crontab -e (root) — after BACKUP_TIME (UTC; Hetzner images run in UTC)
0 3 * * * rclone sync /var/lib/docker/volumes/<name>/_data storagebox:giftcard-backups
```

### 2.4 Server-Snapshots

In der Hetzner Cloud Console **Backups** aktivieren. Hetzner erstellt täglich ein Abbild der gesamten Festplatte (inklusive Docker-Volumes, Redis-AOF, `laravel-storage` mit dem erzeugten `APP_KEY` und lokaler Dumps). Vor größeren Eingriffen (Major-Upgrade, Betriebssystem-Update) zusätzlich einen manuellen **Snapshot** anlegen.

Snapshots sind absturzkonsistent, nicht transaktionskonsistent: Für die Datenbank ist der logische Dump die maßgebliche Quelle, der Snapshot die Rückfallebene für den ganzen Server.

## 3. Was nicht gesichert wird

| Bestandteil | Gesichert? | Auswirkung bei Verlust | Maßnahme |
|---|---|---|---|
| **Redis** (Sessions, Cache, Queues, Rate-Limit-Zähler, Sperren) | Nur im Server-Snapshot (AOF), nicht im Dump | Siehe 3.1 | Bewusst so; kein eigenes Backup nötig |
| Environment Variables der Coolify-Ressource (Secrets) | In Coolify; nur im Server-Snapshot | Ohne `APP_KEY` werden alle abgemeldet und verschlüsselte Werte sind unlesbar | `APP_KEY` und SMTP-Zugangsdaten **im Passwortmanager** führen – Pflicht |
| Docker-Images | nein – Coolify baut sie aus Git | keine | keine |
| Quellcode, Caddyfile, Compose-Datei | in Git | keine | keine |
| Container-Logs | nein (Rotation 10 MB × 5) | Historische Logs fehlen | bei Bedarf Log-Versand, siehe [Logging-Leitfaden](logging-guide.md) |

Kartenschlüssel sind nicht Teil der Anwendung und ihrer Backups: Schlüssel für NTAG-424-DNA-Karten liegen in einem Hardware-Sicherheitsmodul hinter dem Krypto-Dienst ([docs/NFC.md](../../NFC.md)).

### 3.1 Redis – was ein Verlust bedeutet

Redis enthält nur flüchtige Daten. Geht Redis verloren (z. B. Restore auf einen neuen Server ohne Snapshot):

| Redis-Inhalt | Folge | Einschätzung |
|---|---|---|
| Sessions | Alle Personen im Browser werden abgemeldet und melden sich neu an. Geräte und Tokens der Kellner-App bleiben gültig (Tabellen `devices`, `personal_access_tokens`). | harmlos, einmaliger Aufwand für das Personal |
| Queue (`default`, `notifications`) | Noch nicht versendete E-Mails (Kauf, Aufladung, Ablauferinnerung, Einladungen, Passwort-Links) gehen verloren. Buchungen sind davon nicht betroffen – E-Mails werden erst nach dem Commit der Buchung eingereiht. | gering; Einladungen mit **Invite again** neu senden |
| Cache | Wird automatisch neu aufgebaut (Berechtigungen, Systemeinstellungen). | keine |
| Rate-Limit-Zähler, Zähler fehlgeschlagener Vorlagen | Zähler beginnen bei 0. Die Kontosperre selbst (`locked_until`) liegt in der Datenbank. | keine |
| Vorlagen (Presentments) | liegen in der Datenbank, nicht in Redis; sie laufen ohnehin nach 60 s ab | keine |
| Sperren (Migrationssperre, `withoutOverlapping`) | werden neu gesetzt | keine |

Die Konfiguration `--appendonly yes` und `--maxmemory-policy noeviction` schützt Queues und Sessions bei normalen Neustarts.

## 4. Verschlüsselung

Die Dumps sind mit gzip komprimiert, aber **nicht verschlüsselt**. Sie enthalten personenbezogene Daten (Namen, E-Mail-Adressen, Telefonnummern von Kundinnen und Kunden, Empfängernamen, IP-Adressen im Audit-Log) sowie Passwort-Hashes, Token-Hashes und die Hashes der QR-Geheimnisse (die Geheimnisse selbst werden nie gespeichert).

Empfehlungen:

1. **Off-site verschlüsselt ablegen:** In `rclone` ein Remote vom Typ `crypt` über dem Storage-Box-Remote anlegen (z. B. `storagebox-crypt:`) und im Cron statt `storagebox:giftcard-backups` verwenden. Passwort und Salt des `crypt`-Remotes im Passwortmanager sichern – ohne sie ist kein Restore möglich.
2. **Alternative:** Dumps vor dem Sync mit `age` oder `gpg` asymmetrisch verschlüsseln; der private Schlüssel liegt nicht auf dem Server.
3. **Transport:** Storage Box nur über SFTP/SSH (Port 23) mit Schlüssel ansprechen, Samba/FTP in der Storage-Box-Verwaltung deaktivieren.
4. **Zugriff:** Das Volume-Verzeichnis unter `/var/lib/docker/volumes/` ist nur für root lesbar; SSH-Zugang zum Server auf wenige Personen beschränken.
5. **Server-Festplatte:** Die Referenzinstallation verschlüsselt die Serverfestplatte nicht mit einem eigenen Schlüssel; der Schutz beruht auf Zugriffskontrolle (SSH-Schlüssel, Firewall) und dem Rechenzentrum. Für Dumps, die den Server verlassen, gilt deshalb Punkt 1.

## 5. Backups prüfen

### 5.1 Täglich (automatisierbar)

Coolify → *Logs* → Dienst **backup**: die letzte Zeile lautet „Backup written: /backups/giftcard_pro_…sql.gz“. Im Container **backup**:

```bash
ls -lh /backups | tail -n 3                                 # newest file from today?
gzip -t /backups/$(ls -t /backups | head -1) && echo OK
```

Am Server: `rclone ls storagebox:giftcard-backups | tail -n 3` (off-site vorhanden?).

Plausibilität: Die Größe des Dumps wächst langsam (das Ledger wird nie kleiner). Ein Dump, der deutlich kleiner als der Vortag ist, ist ein Alarmzeichen.

### 5.2 Monatlich – Test-Restore

Ein Backup gilt erst als funktionierend, wenn es wiederhergestellt wurde. Einmal im Monat in eine separate Datenbank einspielen und prüfen – das Vorgehen beschreibt die [Restore-Anleitung](restore-guide.md), Szenario A. Ergebnis dokumentieren (Datum, Datei, Dauer, Ergebnis der Prüfabfragen).

## 6. Backup-Jobs überwachen

| Prüfung | Methode | Alarm, wenn |
|---|---|---|
| Dump erstellt | Alter der neuesten Datei in `/backups`; Log des Dienstes `backup` | älter als 26 Stunden oder „Backup FAILED“ |
| Dump lesbar | `gzip -t` | Fehler |
| Off-site-Sync | `rclone`-Exit-Code, Anzahl der Dateien auf der Storage Box | Exit-Code ≠ 0 oder neueste Datei fehlt |
| Speicherplatz | `df -h /var/lib/docker` | über 80 % belegt |
| Server-Snapshots | Hetzner Cloud Console | letztes Backup älter als 26 Stunden |

Empfehlung: Die Cron-Zeile um einen „Dead Man's Switch“ ergänzen (ein Heartbeat-Dienst, der nur bei Erfolg aufgerufen wird und bei ausbleibendem Signal alarmiert):

```cron
0 3 * * * rclone sync /var/lib/docker/volumes/<name>/_data storagebox:giftcard-backups && curl -fsS -m 10 [heartbeat-url-offsite] >/dev/null
```

## 7. Aufbewahrung

### 7.1 Ist-Stand

- Lokal: `BACKUP_KEEP_DAYS` (Standard 14 Tage).
- Off-site: `rclone sync` **spiegelt** das Volume – lokal gelöschte Dateien werden auch auf der Storage Box gelöscht. Off-site liegen damit ebenfalls rund 14 Tage.
- Server-Snapshots: Rotation durch Hetzner.

Ein Fehler, der erst nach mehr als 14 Tagen bemerkt wird (z. B. eine fehlerhafte Massenänderung von Stammdaten), lässt sich mit dem Ist-Stand nicht mehr aus einem Backup rekonstruieren. Ledger, Zahlungen und Audit-Log sind unveränderlich; Stammdaten (Kundinnen und Kunden, Einstellungen) aber nicht.

### 7.2 Empfehlung: Großvater-Vater-Sohn off-site

| Stufe | Anzahl | Quelle |
|---|---|---|
| täglich | 14 | Dump des Tages |
| wöchentlich | 8 | Dump vom Sonntag |
| monatlich | 12 | Dump vom 1. des Monats |

Umsetzungsvarianten (Empfehlung, nicht Teil des Repositorys):

- **Storage-Box-Snapshots:** In der Hetzner-Verwaltung automatische Snapshots der Storage Box aktivieren und passend rotieren lassen.
- **Getrennte Verzeichnisse mit `rclone copy`:** zusätzlich zum `sync`-Job ein wöchentlicher und ein monatlicher Job, der den neuesten Dump nach `giftcard-backups-weekly/` bzw. `giftcard-backups-monthly/` kopiert, plus Bereinigung mit `rclone delete --min-age`:

```cron
0 4 * * 0  D=/var/lib/docker/volumes/<name>/_data; rclone copy "$D/$(ls -t $D | head -1)" storagebox:giftcard-backups-weekly && rclone delete --min-age 56d storagebox:giftcard-backups-weekly
0 4 1 * *  D=/var/lib/docker/volumes/<name>/_data; rclone copy "$D/$(ls -t $D | head -1)" storagebox:giftcard-backups-monthly && rclone delete --min-age 365d storagebox:giftcard-backups-monthly
```

(In Crontab-Zeilen muss `%` maskiert werden; die obigen Zeilen enthalten keines.)

### 7.3 Aufbewahrung und DSGVO

- Die Aufbewahrungspflicht für Bücher und Aufzeichnungen (BAO § 132, 7 Jahre) wird durch das **Ledger in der laufenden Datenbank** erfüllt, nicht durch Backups. Backups dienen der Wiederherstellung.
- Anonymisierte Kundendaten (DSGVO-Löschung) bleiben in älteren Backups bis zu deren Rotation erhalten. Mit 12 Monaten Aufbewahrung beträgt diese Frist höchstens 12 Monate; in der Datenschutzinformation und im Verzeichnis der Verarbeitungstätigkeiten angeben. Nach einem Restore müssen zwischenzeitlich durchgeführte Anonymisierungen erneut ausgeführt werden (siehe [Restore-Anleitung](restore-guide.md)).
- Keine Rechtsberatung – mit Steuerberatung/Rechtsanwalt prüfen.

## 8. Recovery-Ziele

| Kennzahl | Ist-Stand | Bedeutung |
|---|---|---|
| RPO (maximaler Datenverlust) | bis zu 24 Stunden | Tägliche Dumps; Buchungen seit dem letzten Dump sind bei Totalverlust ohne Snapshot verloren |
| RTO (Wiederherstellungszeit) | Schätzung: 1–2 Stunden für neuen Server + Restore | abhängig von Datenbankgröße und Vorbereitung |

Verbesserungen (Binärlog/Point-in-Time-Recovery) beschreibt die [Restore-Anleitung](restore-guide.md#7-point-in-time-grenzen-und-verbesserung).

---

Version 2.0 · Stand: September 2026
