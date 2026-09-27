# Backup-Anleitung

> **Hinweis (Coolify-Deployment):** Produktion läuft seit 1.4.2 auf **Coolify** mit `docker-compose.coolify.yml` (Build aus dem Quellcode, kein GHCR, keine Deploy-Skripte). Befehle mit `docker compose --env-file .env.production`, `infra/scripts/…`, `deploy.yml` oder Caddy auf dem Host in diesem Dokument sind überholt. Maßgeblich sind [docs/DEPLOYMENT.md](../../DEPLOYMENT.md) (Deployment, Backups, Restore, Betrieb) und [docs/ENVIRONMENT.md](../../ENVIRONMENT.md).

*Was bei GiftCard Pro gesichert wird und was nicht, wie die Sicherung eingerichtet, verschlüsselt, geprüft und überwacht wird, und welche Aufbewahrung empfohlen ist.*

---

## 1. Überblick

Die Datenbank ist das einzige System, dessen Verlust nicht ersetzbar ist: Sie enthält das Ledger (jede Buchung jeder Karte), die Kartenstatus, Kundendaten und das Audit-Log. Alles andere lässt sich aus Git, der Container-Registry oder dem Passwortmanager neu aufbauen.

| Ebene | Was | Wann | Aufbewahrung | Ort |
|---|---|---|---|---|
| 1 | Logischer MySQL-Dump (`mysqldump`, gzip) | täglich 02:30 | 14 Tage | Server: `/opt/giftcard-pro/backups/` |
| 2 | Off-site-Kopie der Dumps (`rclone sync`) | täglich 02:45 | spiegelt Ebene 1 (siehe Abschnitt 7) | Hetzner Storage Box |
| 3 | Server-Snapshot (Hetzner Backups) | täglich, Zeitfenster von Hetzner | durch Hetzner rotiert (bis zu 7 Sicherungen) | Hetzner Cloud |

Alle Daten bleiben in Rechenzentren von Hetzner in Deutschland (EU).

## 2. Was gesichert wird

### 2.1 Datenbank-Dump

`infra/scripts/backup.sh` läuft im Compose-Dienst `backup` (Image `mysql:8.4`, Profil `backup`) und nutzt die Zugangsdaten aus `backend/.env.production`:

```sh
mysqldump --single-transaction --quick --routines --triggers \
  -h "${DB_HOST}" -u "${DB_USERNAME}" -p"${DB_PASSWORD}" "${DB_DATABASE}" | gzip -9 > "${FILE}"
find /backups -name 'giftcard_pro_*.sql.gz' -mtime +14 -delete
```

| Eigenschaft | Wert |
|---|---|
| Dateiname | `giftcard_pro_<YYYYMMDD>T<HHMMSS>Z.sql.gz` (Zeitstempel in UTC) |
| Konsistenz | `--single-transaction`: konsistenter Stand aller InnoDB-Tabellen ohne Sperren – der Betrieb läuft weiter |
| Umfang | gesamte Datenbank `giftcard_pro` inklusive Routinen und Trigger |
| Lokale Aufbewahrung | Dateien älter als 14 Tage werden beim nächsten Lauf gelöscht |

Enthalten sind damit alle Tabellen: `restaurants`, `restaurant_settings`, `users`, `roles`/`permissions`, `personal_access_tokens`, `devices`, `customers`, `gift_cards`, `gift_card_transactions` (Ledger), `nfc_scans`, `audit_logs`, `notification_templates`, `notification_logs`, `system_settings`, `sessions`, `password_reset_tokens`, `failed_jobs`, `cache`, `cache_locks`, `job_batches`.

### 2.2 Einrichtung (Cron des Benutzers `deploy`)

```cron
# crontab -e (deploy user)
30 2 * * * cd /opt/giftcard-pro && docker compose --env-file .env.production --profile backup run --rm backup >> /var/log/giftcard-backup.log 2>&1
45 2 * * * rclone sync /opt/giftcard-pro/backups storagebox:giftcard-backups
```

Vorbereitung:

```bash
sudo touch /var/log/giftcard-backup.log && sudo chown deploy: /var/log/giftcard-backup.log
sudo apt -y install rclone
rclone config          # new remote "storagebox", type sftp, host <user>.your-storagebox.de, port 23, SSH key
rclone lsd storagebox:  # test the connection
```

> **Zeitzone:** Cron verwendet die Zeitzone des Servers. Hetzner-Images laufen standardmäßig in UTC – 02:30 UTC entspricht 03:30 (Winterzeit) bzw. 04:30 (Sommerzeit) in Wien. Beides liegt außerhalb der Servicezeiten. Wer die Zeiten in Wiener Zeit möchte: `sudo timedatectl set-timezone Europe/Vienna`. Die Anwendungsjobs sind davon unabhängig (`SCHEDULE_TIMEZONE`).

Sofortiges Backup, z. B. vor einem Update:

```bash
cd /opt/giftcard-pro
docker compose --env-file .env.production --profile backup run --rm backup
```

### 2.3 Server-Snapshots

Beim Anlegen des Servers **Backups** in der Hetzner Cloud Console aktivieren. Hetzner erstellt täglich ein Abbild der gesamten Festplatte (inklusive Docker-Volumes, `.env`-Dateien, Redis-AOF und lokaler Dumps). Vor größeren Eingriffen (Major-Upgrade, Betriebssystem-Update) zusätzlich einen manuellen **Snapshot** anlegen.

Snapshots sind absturzkonsistent, nicht transaktionskonsistent: Für die Datenbank ist der logische Dump die maßgebliche Quelle, der Snapshot die Rückfallebene für den ganzen Server.

## 3. Was nicht gesichert wird

| Bestandteil | Gesichert? | Auswirkung bei Verlust | Maßnahme |
|---|---|---|---|
| **Redis** (Sessions, Cache, Queues, Rate-Limit-Zähler, Sperren) | Nur im Server-Snapshot (AOF), nicht im Dump | Siehe 3.1 | Bewusst so; kein eigenes Backup nötig |
| `.env.production`, `backend/.env.production` (Secrets) | Nur im Server-Snapshot | Ohne `APP_KEY` werden alle abgemeldet; ohne NTAG-424-Schlüssel sind NTAG-424-DNA-Karten nicht prüfbar | **Im Passwortmanager** führen – Pflicht |
| Caddy-Volumes (`caddy_data`, `caddy_config`) | Nur im Server-Snapshot | Zertifikate werden automatisch neu ausgestellt | keine |
| Docker-Images | in GHCR (je Commit-SHA) | keine | keine |
| Quellcode, Caddyfile, Compose-Datei | in Git | keine | keine |
| Container-Logs | nein | Historische Logs fehlen | bei Bedarf Log-Versand, siehe [Logging-Leitfaden](logging-guide.md) |

### 3.1 Redis – was ein Verlust bedeutet

Redis enthält nur flüchtige Daten. Geht Redis verloren (z. B. Restore auf einen neuen Server ohne Snapshot):

| Redis-Inhalt | Folge | Einschätzung |
|---|---|---|
| Sessions | Alle Personen werden abgemeldet und melden sich neu an. Geräte bleiben registriert (Tabelle `devices`). | harmlos, einmaliger Aufwand für das Personal |
| Queue (`default`, `notifications`) | Noch nicht versendete Kunden-E-Mails (Kauf, Aufladung, Erinnerung, niedriges Guthaben) gehen verloren. Buchungen sind davon nicht betroffen – E-Mails werden erst nach dem Commit der Buchung eingereiht. | gering; betroffene Gäste können über die Guthabenseite nachsehen |
| Cache | Wird automatisch neu aufgebaut (Berechtigungen, Systemeinstellungen). | keine |
| Rate-Limit-Zähler, Login-Sperrzähler | Zähler beginnen bei 0. Die Kontosperre selbst (`locked_until`) liegt in der Datenbank. | keine |
| Sperren (`migrate --isolated`, `withoutOverlapping`) | werden neu gesetzt | keine |

Die Konfiguration `--appendonly yes` und `noeviction` schützt Queues und Sessions bei normalen Neustarts.

## 4. Verschlüsselung

Die Dumps sind mit gzip komprimiert, aber **nicht verschlüsselt**. Sie enthalten personenbezogene Daten (Namen, E-Mail-Adressen, Telefonnummern von Kundinnen und Kunden, Empfängernamen, IP-Adressen im Audit-Log) sowie Passwort-Hashes und Token-Hashes.

Empfehlungen:

1. **Off-site verschlüsselt ablegen:** In `rclone` ein Remote vom Typ `crypt` über dem Storage-Box-Remote anlegen (z. B. `storagebox-crypt:`) und im Cron statt `storagebox:giftcard-backups` verwenden. Passwort und Salt des `crypt`-Remotes im Passwortmanager sichern – ohne sie ist kein Restore möglich.
2. **Alternative:** Dumps vor dem Sync mit `age` oder `gpg` asymmetrisch verschlüsseln; der private Schlüssel liegt nicht auf dem Server.
3. **Transport:** Storage Box nur über SFTP/SSH (Port 23) mit Schlüssel ansprechen, Samba/FTP in der Storage-Box-Verwaltung deaktivieren.
4. **Zugriff:** Verzeichnis `/opt/giftcard-pro/backups` nur für `deploy` lesbar (`chmod 700`).
5. **Server-Festplatte:** Die Referenzinstallation verschlüsselt die Serverfestplatte nicht mit einem eigenen Schlüssel; der Schutz beruht auf Zugriffskontrolle (SSH-Schlüssel, Firewall) und dem Rechenzentrum. Für Dumps, die den Server verlassen, gilt deshalb Punkt 1.

## 5. Backups prüfen

### 5.1 Täglich (automatisierbar)

```bash
ls -lh /opt/giftcard-pro/backups | tail -n 3               # newest file from today?
gzip -t /opt/giftcard-pro/backups/$(ls -t /opt/giftcard-pro/backups | head -1) && echo OK
tail -n 5 /var/log/giftcard-backup.log                      # "Backup written: …"
rclone ls storagebox:giftcard-backups | tail -n 3           # present off-site?
```

Plausibilität: Die Größe des Dumps wächst langsam. Ein Dump, der deutlich kleiner als der Vortag ist, ist ein Alarmzeichen.

### 5.2 Monatlich – Test-Restore

Ein Backup gilt erst als funktionierend, wenn es wiederhergestellt wurde. Einmal im Monat in eine separate Datenbank einspielen und prüfen – das Vorgehen beschreibt die [Restore-Anleitung](restore-guide.md), Szenario A. Ergebnis dokumentieren (Datum, Datei, Dauer, Prüfergebnis der Ledger-Abfrage).

## 6. Backup-Jobs überwachen

| Prüfung | Methode | Alarm, wenn |
|---|---|---|
| Dump erstellt | Alter der neuesten Datei in `backups/` | älter als 26 Stunden |
| Dump lesbar | `gzip -t` | Fehler |
| Off-site-Sync | `rclone`-Exit-Code, Anzahl der Dateien auf der Storage Box | Exit-Code ≠ 0 oder neueste Datei fehlt |
| Speicherplatz | `df -h /opt` | über 80 % belegt |
| Server-Snapshots | Hetzner Cloud Console | letztes Backup älter als 26 Stunden |

Empfehlung: Beide Cron-Zeilen um einen „Dead Man's Switch" ergänzen (z. B. ein Heartbeat-Dienst, der nur bei Erfolg aufgerufen wird und bei ausbleibendem Signal alarmiert):

```cron
30 2 * * * cd /opt/giftcard-pro && docker compose --env-file .env.production --profile backup run --rm backup >> /var/log/giftcard-backup.log 2>&1 && curl -fsS -m 10 [heartbeat-url-backup] >/dev/null
45 2 * * * rclone sync /opt/giftcard-pro/backups storagebox:giftcard-backups && curl -fsS -m 10 [heartbeat-url-offsite] >/dev/null
```

## 7. Aufbewahrung

### 7.1 Ist-Stand

- Lokal: 14 Tage.
- Off-site: `rclone sync` **spiegelt** das lokale Verzeichnis – lokal gelöschte Dateien werden auch auf der Storage Box gelöscht. Off-site liegen damit ebenfalls rund 14 Tage.
- Server-Snapshots: Rotation durch Hetzner.

Ein Fehler, der erst nach mehr als 14 Tagen bemerkt wird (z. B. eine fehlerhafte Massenänderung), lässt sich mit dem Ist-Stand nicht mehr aus einem Backup rekonstruieren. Das Ledger ist zwar unveränderlich, Stammdaten (Kunden, Einstellungen) aber nicht.

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
0 4 * * 0  rclone copy "/opt/giftcard-pro/backups/$(ls -t /opt/giftcard-pro/backups | head -1)" storagebox:giftcard-backups-weekly && rclone delete --min-age 56d storagebox:giftcard-backups-weekly
0 4 1 * *  rclone copy "/opt/giftcard-pro/backups/$(ls -t /opt/giftcard-pro/backups | head -1)" storagebox:giftcard-backups-monthly && rclone delete --min-age 365d storagebox:giftcard-backups-monthly
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

Version 1.0 · Stand: September 2026
