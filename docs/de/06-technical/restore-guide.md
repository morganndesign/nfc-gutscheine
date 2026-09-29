# Restore-Anleitung

*Schritt-für-Schritt-Wiederherstellung von GiftCard Pro im Coolify-Stack: Untersuchung einzelner Datensätze, vollständiger Datenbank-Restore, Totalverlust des Servers, Grenzen der Point-in-Time-Wiederherstellung, Prüfabfragen und Kommunikation mit den Lokalen. Englische Referenz: [docs/DEPLOYMENT.md → Backups](../../DEPLOYMENT.md#backups).*

---

## 1. Grundregeln

1. **Das Produktiv-Ledger wird nie überschrieben, um einzelne Fehler zu korrigieren.** Ledger, Zahlungen und Audit-Log sind append-only (Datenbank-Trigger) und über Hash-Ketten verknüpft. Einzelne falsche Buchungen werden in der Anwendung mit einer Gegenbuchung (**Reverse**) korrigiert. Ein Restore der gesamten Datenbank ist nur bei Datenbankverlust oder -beschädigung zulässig.
2. **Vor jedem Eingriff ein aktuelles Backup ziehen** – auch vom beschädigten Zustand.
3. **Zuerst in eine separate Restore-Datenbank einspielen und prüfen**, dann entscheiden.
4. Jeder Restore wird protokolliert: Zeitpunkt, verwendete Datei, Grund, handelnde Person, Ergebnis der Prüfabfragen und von `giftcard:verify-chains`.
5. Restore-Datenbanken enthalten personenbezogene Daten – nach Abschluss löschen.

Alle Befehle laufen im Coolify-*Terminal* der Ressource, im jeweils genannten Container: **backup** (hat den MySQL-Client, die Dumps unter `/backups` und das Root-Passwort in `MYSQL_ROOT_PASSWORD`) oder **api** (Artisan). Die Befehle verwenden die Umgebungsvariable, damit das Passwort nicht auf der Kommandozeile erscheint.

## 2. Szenarioübersicht

| Szenario | Anlass | Produktion betroffen? | Abschnitt |
|---|---|---|---|
| A | Einzelne Datensätze prüfen, monatlicher Test-Restore | nein | 3 |
| B | Datenbank beschädigt, fehlerhafte Migration, versehentliche Massenänderung | ja, Ausfallzeit | 4 |
| C | Server verloren oder nicht mehr startfähig | ja, Ausfallzeit | 5 |
| D | Server-Snapshot zurückspielen | ja, Ausfallzeit | 6 |

## 3. Szenario A – Untersuchung in einer Restore-Datenbank

Anwendungsfälle: Ein Lokal meldet, dass Kundendaten oder Einstellungen „gestern noch anders“ waren; Nachweis eines früheren Gutscheinstands; monatlicher Test-Restore.

### 3.1 Backup auswählen

Im Container **backup**:

```bash
ls -lh /backups                                   # local (BACKUP_KEEP_DAYS)
```

Ältere Dateien liegen off-site; am Server (als root) zurückholen:

```bash
rclone ls storagebox:giftcard-backups
rclone copy storagebox:giftcard-backups/giftcard_pro_20261014T013001Z.sql.gz /var/lib/docker/volumes/<name>/_data/
```

Die Zeitstempel im Dateinamen sind UTC.

### 3.2 In eine separate Datenbank einspielen

Im Container **backup**:

```bash
FILE=/backups/giftcard_pro_20261014T013001Z.sql.gz
mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS restore_test; CREATE DATABASE restore_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
gunzip -c "$FILE" | mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" restore_test
```

Die Produktivdatenbank bleibt unberührt; der Betrieb läuft weiter.

### 3.3 Untersuchen

```bash
mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" restore_test
```

Beispiele:

```sql
-- voucher state at backup time (voucher_number is internal, staff and support only)
SELECT voucher_number, kind, status, balance, expires_at, updated_at
FROM vouchers WHERE voucher_number = '5285105870986488';

-- customer record in backup vs. production
SELECT r.first_name, r.last_name, r.email, p.first_name, p.last_name, p.email
FROM restore_test.customers r
JOIN giftcard_pro.customers p ON p.id = r.id
WHERE r.id = '<customer-uuid>';

-- ledger entries of a voucher that are not in the backup yet
SELECT p.created_at, p.type, p.amount, p.balance_after
FROM giftcard_pro.voucher_transactions p
LEFT JOIN restore_test.voucher_transactions r ON r.id = p.id
WHERE p.voucher_id = '<voucher-uuid>' AND r.id IS NULL
ORDER BY p.created_at;
```

### 3.4 Korrigieren – nur über die Anwendung

| Befund | Korrektur |
|---|---|
| Falsche Einlösung oder Aufladung | **Reverse** in Transactions bzw. `POST /transactions/{id}/reverse` (neuer, gegengleicher Eintrag) |
| Gutschein versehentlich abgelaufen | **Reinstate** (Inhaberin bzw. Inhaber, mit Grund) |
| Kundendaten versehentlich überschrieben | Werte aus der Restore-Datenbank ablesen und unter Customers → Edit neu eintragen |
| Gutscheinregeln des Lokals geändert | Werte unter Settings → Vouchers neu setzen |

Keine Zeilen aus der Restore-Datenbank per SQL in die Produktion kopieren. Direkte SQL-Änderungen umgehen Ledger, Hash-Ketten, Audit-Log und Zeilensperren; `UPDATE` und `DELETE` auf Ledger, Zahlungen und Audit-Log lehnen die Trigger ohnehin ab.

### 3.5 Aufräumen

```bash
mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE restore_test"
```

Dumps, die nur für die Untersuchung von der Storage Box in das Volume kopiert wurden, danach wieder löschen – sonst spiegelt der nächste `rclone sync` sie in den Tagesordner.

Beim monatlichen Test-Restore vor dem Löschen die Prüfabfragen aus Abschnitt 8 gegen `restore_test` ausführen und das Ergebnis dokumentieren.

## 4. Szenario B – Vollständiger Datenbank-Restore

Anlass: Die Produktivdatenbank ist beschädigt oder durch einen Fehler unbrauchbar, der Server selbst ist intakt.

**Folge:** Alle Änderungen zwischen dem Zeitpunkt des Dumps und dem Restore gehen verloren (bis zu 24 Stunden, siehe Abschnitt 7). Vorher prüfen, ob Binärlogs eine genauere Wiederherstellung erlauben (Abschnitt 7.2).

### 4.1 Ablauf

1. **Entscheidung dokumentieren** (wer, warum, welches Backup).
2. **Lokale informieren** (Abschnitt 9) und Wartungshinweis setzen, solange die API noch läuft: Plattformadministration → System settings → Maintenance notice.
3. **Wartungsmodus:** Container **api** → `php artisan down` (Dashboard und App zeigen Wartung).
4. **Aktuellen Zustand sichern** (auch wenn er beschädigt ist) – Container **backup**:

```bash
mysqldump -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers --no-tablespaces "$MYSQL_DATABASE" | gzip > /backups/manual_$(date -u +%Y%m%dT%H%M%SZ).sql.gz
```

5. **Backup auf Lesbarkeit prüfen** und optional zuerst als Szenario A einspielen und prüfen (empfohlen).
6. **Datenbank ersetzen** – Container **backup**:

```bash
FILE=/backups/giftcard_pro_20261014T013001Z.sql.gz
gzip -t "$FILE"
gunzip -c "$FILE" | mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"
```

Der Dump enthält für jede Tabelle `DROP TABLE IF EXISTS` und die Append-only-Trigger; die Berechtigungen des Anwendungsbenutzers beziehen sich auf den Datenbanknamen und bleiben erhalten.

7. **Ressource → *Redeploy*** (bringt die Anwendung zurück; `php artisan up` ist damit nicht nötig). Beim Start führt der erste Laravel-Container offene Migrationen aus.
8. **Integrität prüfen** – Container **api**:

```bash
php artisan giftcard:verify-chains      # restored chains and balances must verify
```

Danach die Prüfabfragen aus Abschnitt 8 ausführen.

9. **Sessions:** Sessions liegen in Redis und verweisen unter Umständen auf Daten, die es nach dem Restore nicht mehr gibt. Empfohlen: alle abmelden – Container **redis** → `redis-cli -a "$REDIS_PASSWORD" --no-auth-warning FLUSHALL`, danach Container **api** → `php artisan queue:restart`. `FLUSHALL` leert auch Queue und Cache (Folgen: siehe [Backup-Anleitung](backup-guide.md#31-redis--was-ein-verlust-bedeutet)).
10. **DSGVO-Nacharbeit:** Anonymisierungen von Kundinnen und Kunden, die nach dem Zeitpunkt des Dumps erfolgt sind, erneut ausführen (Liste aus dem Audit-Log des gesicherten beschädigten Zustands oder aus den Anfragen der Lokale).
11. **Wartungshinweis entfernen** und Lokale informieren.

## 5. Szenario C – Totalverlust des Servers

Anlass: Server gelöscht, kompromittiert oder nicht mehr startfähig, kein brauchbarer Snapshot.

> Automatische Hetzner-Backups gehören zum Server. Wird der Server gelöscht, stehen sie in der Regel nicht mehr zur Verfügung – deshalb ist die Off-site-Kopie auf der Storage Box die maßgebliche Quelle. Bei einem **kompromittierten** Server keinen Snapshot dieses Servers verwenden und alle Secrets rotieren (Abschnitt 5.4).

### 5.1 Voraussetzungen

- Zugang zu Hetzner Cloud Console, DNS, GitHub und Storage Box
- Passwortmanager mit: `APP_KEY`, SMTP-Zugangsdaten, `rclone`-Zugang zur Storage Box (und ggf. `crypt`-Passwort)
- Commit des zuletzt laufenden Deployments (Coolify → *Deployments*, oder `main`)

### 5.2 Neuen Server aufbauen

1. Server mit Coolify nach [Deployment-Anleitung](deployment-guide.md), Abschnitte 2 und 3, einrichten: Ressource aus dem Repository anlegen, Gateway-Domain, `APP_KEY` aus dem Passwortmanager und die `MAIL_*`-Werte als Environment Variables setzen.
2. DNS: A-/AAAA-Records auf die neue IP umstellen (die TTL bestimmt, wie schnell die Umstellung wirkt).
3. *Deploy*. Die Laravel-Container legen ein leeres Schema und die Referenzdaten an.

### 5.3 Daten wiederherstellen

Am Server (als root) den neuesten Dump in das Volume `mysql-backups` holen:

```bash
apt -y install rclone && rclone config                 # remote "storagebox" as before
docker volume ls | grep mysql-backups
rclone copy storagebox:giftcard-backups /var/lib/docker/volumes/<name>/_data/ --max-age 48h
```

Dann wie in Szenario B, Schritte 3 und 6–9: `php artisan down`, Dump im Container **backup** einspielen, *Redeploy*, `php artisan giftcard:verify-chains`, Prüfabfragen aus Abschnitt 8.

Coolify stellt das TLS-Zertifikat neu aus. Let's Encrypt begrenzt die Anzahl identischer Zertifikate pro Woche – wiederholte Neuinstallationen innerhalb kurzer Zeit vermeiden.

Danach: Off-site-Sync wieder einrichten ([Backup-Anleitung](backup-guide.md)), Hetzner-Backups und Firewall aktivieren, Uptime-Monitor auf den neuen Server prüfen.

### 5.4 Zusätzlich bei Kompromittierung

- `SERVICE_PASSWORD_MYSQL`, `SERVICE_PASSWORD_MYSQLROOT`, `SERVICE_PASSWORD_REDIS` (neuer Server, neue Werte), `MAIL_PASSWORD` und SSH-Schlüssel neu erzeugen; die GitHub-App-Verbindung von Coolify neu autorisieren.
- `APP_KEY` neu erzeugen: Alle Sessions werden ungültig (gewollt).
- Alle API-Tokens der Lokale und alle Gerätetokens der Kellner-App als kompromittiert betrachten: unter `/admin/api-tokens` widerrufen, Lokale informieren, Integrationstokens neu anlegen lassen; Servicekräfte melden sich in der App neu an.
- QR-Codes der Gutscheine: Der Server speichert nur Hashes; ein Angreifer mit Datenbankzugriff kann daraus keinen QR-Code erzeugen. Einlösen verlangt ohnehin einen Scan durch eine angemeldete Person auf einem registrierten Gerät.
- `php artisan giftcard:verify-chains` auf dem wiederhergestellten Stand ausführen: Eine veränderte Buchung fällt als gebrochene Kette auf.
- Meldepflichten nach DSGVO prüfen (Abschnitt 9.3).

## 6. Szenario D – Server-Snapshot zurückspielen

Wenn der Server noch existiert und ein Hetzner-Backup bzw. Snapshot vorliegt, ist das der schnellste Weg: Hetzner Cloud Console → Server → Backups/Snapshots → **Rebuild** bzw. **Restore**.

- Der Server kehrt vollständig auf den Stand des Snapshots zurück (Coolify, Datenbank, Redis, Volumes, Zertifikate).
- Datenverlust: alles seit dem Snapshot-Zeitpunkt. Liegt ein neuerer logischer Dump vor (z. B. 01:30 UTC des aktuellen Tages, Snapshot vom Vortag), danach zusätzlich Szenario B mit dem neueren Dump ausführen.
- Nach dem Start `php artisan giftcard:verify-chains` und die Prüfabfragen aus Abschnitt 8 ausführen – der Snapshot ist nur absturzkonsistent; InnoDB führt beim Start eine Wiederherstellung durch.

## 7. Point-in-Time-Grenzen und Verbesserung

### 7.1 Ist-Stand

- Tägliche Dumps um `BACKUP_TIME` (Standard 01:30 UTC) → **RPO bis zu 24 Stunden**. Eine Beschädigung um 21:00 bedeutet ohne weitere Maßnahmen den Verlust aller Buchungen seit dem letzten Dump.
- Die Dumps enthalten keine Binärlog-Position (der Dienst `backup` verwendet kein `--source-data`).

### 7.2 Binärlogs nutzen, wenn der Server intakt ist

MySQL 8.4 schreibt standardmäßig Binärlogs in das Datenverzeichnis (Volume `mysql-data`). Prüfen:

```sql
SHOW VARIABLES LIKE 'log_bin';
SHOW VARIABLES LIKE 'binlog_expire_logs_seconds';
SHOW BINARY LOGS;
```

Sind Binärlogs vorhanden, lassen sich nach Einspielen des Dumps die Änderungen bis kurz vor dem Fehler nachspielen (nur mit Erfahrung in MySQL-Administration und zuerst in einer Restore-Datenbank; Container **mysql**):

```bash
mysqlbinlog --start-datetime="2026-10-14 01:30:00" --stop-datetime="2026-10-14 20:59:00" /var/lib/mysql/binlog.0000* > /tmp/replay.sql
```

Da der Dump keine exakte Binlog-Position enthält, ist der Startzeitpunkt nur näherungsweise bestimmbar. Doppelbuchungen weist der eindeutige `idempotency_key` im Ledger ab, und jede Lücke oder Doppelung in einer Hash-Kette meldet `php artisan giftcard:verify-chains`; das Ergebnis ist trotzdem sorgfältig mit den Prüfabfragen zu kontrollieren. Die Zeitangaben von `mysqlbinlog` beziehen sich auf die Zeitzone des MySQL-Containers (UTC).

Bei Totalverlust des Servers sind die Binärlogs mit dem Volume verloren.

### 7.3 Empfohlene Verbesserung (Roadmap Betrieb)

| Maßnahme | Wirkung |
|---|---|
| `--source-data=2` im Dienst `backup` | exakte Binlog-Position im Dump |
| Binärlogs laufend off-site kopieren (z. B. `mysqlbinlog --read-from-remote-server --raw --stop-never` in einem eigenen Dienst oder `rclone copy` alle 5 Minuten) | RPO wenige Minuten auch bei Totalverlust |
| Alternativ: Managed MySQL mit Point-in-Time-Recovery | RPO im Minutenbereich ohne Eigenbetrieb |
| Zweiter Server als Replica (Standby) | kurze RTO bei Serverausfall |

## 8. Prüfabfragen nach einem Restore

Gegen die wiederhergestellte Datenbank ausführen (Produktivdatenbank oder `restore_test`).

**0. Hash-Ketten und Guthaben (Pflicht, nur Produktivdatenbank):** Container **api** → `php artisan giftcard:verify-chains`. Berechnet jede Kette von Ledger, Zahlungen und Audit-Log sowie jedes Guthaben neu; jede Abweichung ist ein Befund.

**1. Ledger-Konsistenz – Summe der Buchungen = Guthaben je Gutschein (Pflicht, Ergebnis muss leer sein):**

```sql
SELECT v.id, v.voucher_number, v.balance, COALESCE(SUM(t.amount), 0) AS ledger_sum
FROM vouchers v
LEFT JOIN voucher_transactions t ON t.voucher_id = v.id
GROUP BY v.id, v.voucher_number, v.balance
HAVING v.balance <> COALESCE(SUM(t.amount), 0);
```

**2. Letzte Buchung jedes Gutscheins stimmt mit dem Guthaben überein (Ergebnis muss leer sein):**

```sql
SELECT v.id, v.voucher_number, v.balance, t.balance_after
FROM vouchers v
JOIN voucher_transactions t ON t.id = (
  SELECT t2.id FROM voucher_transactions t2
  WHERE t2.voucher_id = v.id
  ORDER BY t2.created_at DESC, t2.id DESC LIMIT 1)
WHERE t.balance_after <> v.balance;
```

**3. Jeder Verkauf und jede Aufladung hat eine Zahlung, jede Einlösung einen Scan (Ergebnis muss leer sein):**

```sql
SELECT id, type FROM voucher_transactions
WHERE (type IN ('issue', 'reload') AND payment_id IS NULL)
   OR (type = 'redemption' AND presentment_id IS NULL);
```

**4. Zeitpunkt des Datenstands:**

```sql
SELECT MAX(created_at) AS last_transaction FROM voucher_transactions;
SELECT MAX(created_at) AS last_payment FROM payments;
SELECT MAX(created_at) AS last_audit FROM audit_logs;
```

**5. Offene Verbindlichkeit je Lokal** (mit dem Dashboard-Wert „Outstanding balance“ und mit Angaben der Lokale vergleichen):

```sql
SELECT r.name, COUNT(*) AS vouchers, SUM(v.balance) / 100 AS outstanding_eur
FROM vouchers v JOIN restaurants r ON r.id = v.restaurant_id
WHERE v.balance > 0
GROUP BY r.name ORDER BY r.name;
```

**6. Mengengerüst** (Vergleich mit dem Vortag bzw. dem letzten Test-Restore):

```sql
SELECT (SELECT COUNT(*) FROM restaurants) AS restaurants,
       (SELECT COUNT(*) FROM users) AS users,
       (SELECT COUNT(*) FROM vouchers) AS vouchers,
       (SELECT COUNT(*) FROM payments) AS payments,
       (SELECT COUNT(*) FROM voucher_transactions) AS transactions,
       (SELECT COUNT(*) FROM audit_logs) AS audit_entries;
```

**7. Schema und Anwendung:** Container **api** → `php artisan migrate:status`; `curl -fsS https://app.giftcardpro.at/up`.

**8. Funktionsprüfung:** Anmeldung, Gutschein öffnen, Testeinlösung von € 0,01 auf einem internen Testgutschein und Storno (siehe [Deployment-Anleitung](deployment-guide.md#8-kontrollen-nach-dem-deployment)).

Meldet `giftcard:verify-chains` einen Befund oder weicht Abfrage 1, 2 oder 3 ab: Restore **nicht** freigeben, Datenbank nicht in Betrieb nehmen, älteren Dump prüfen und die Entwicklung einbeziehen.

## 9. Kommunikation mit den Lokalen

### 9.1 Grundsätze

- Früh informieren, auch wenn noch nicht alles klar ist. Kurze, sachliche Sätze.
- Konkreten **Zeitraum** nennen, dessen Daten betroffen sind (in Wiener Zeit).
- Klar sagen, **was das Lokal tun muss** – und was nicht.
- Kanäle: Wartungshinweis in der App (**Maintenance notice**), E-Mail an alle Inhaberinnen und Inhaber, bei Pro- und Gruppe-Kunden zusätzlich telefonisch.

### 9.2 Vorlage: Ausfall mit Datenverlust

> **Betreff:** GiftCard Pro – Wiederherstellung am [Datum], bitte Buchungen von [Uhrzeit] bis [Uhrzeit] prüfen
>
> Guten Tag,
>
> am [Datum] war GiftCard Pro von [Uhrzeit] bis [Uhrzeit] nicht verfügbar. Ursache: [kurze, sachliche Beschreibung]. Wir haben die Daten aus der Sicherung von [Datum, Uhrzeit] wiederhergestellt.
>
> **Was das für Sie bedeutet:** Buchungen, die zwischen [Uhrzeit Backup] und [Uhrzeit Ausfall] in GiftCard Pro erfasst wurden (Verkäufe, Einlösungen, Aufladungen), sind nicht mehr enthalten.
>
> **Bitte so vorgehen:**
> 1. Öffnen Sie **Transactions** und filtern Sie auf den [Datum].
> 2. Vergleichen Sie die Liste mit den Gutschein-Buchungen Ihrer Registrierkasse im selben Zeitraum.
> 3. **Fehlende Verkäufe:** Der gedruckte QR-Code eines in diesem Zeitraum verkauften Gutscheins wird nicht mehr erkannt. Verkaufen Sie den Gutschein unter **Vouchers → Sell voucher** neu, erfassen Sie als Zahlung die ursprüngliche Zahlung (z. B. Kartenterminal mit der ursprünglichen Belegnummer) und geben Sie dem Gast das neue Druckblatt.
> 4. **Fehlende Einlösungen oder Aufladungen:** Eine Einlösung braucht immer den Gutschein selbst. Sperren Sie betroffene Gutscheine mit **Block** und dem Vermerk „Nacherfassung [Datum]“; wenn der Gast den Gutschein wieder vorlegt, entsperren Sie ihn und erfassen die fehlende Buchung mit diesem Vermerk im Feld Reference. Fehlende Aufladungen erfassen Sie mit **Reload** und der ursprünglichen Zahlung.
>
> Alle anderen Daten – Gutscheine, Guthaben, Kundinnen und Kunden, Einstellungen – sind vollständig. Ihre Gäste können ihre Gutscheine ohne Einschränkung weiter verwenden.
>
> Bei Fragen erreichen Sie uns unter support@giftcardpro.at oder [Telefon].
>
> Wir entschuldigen uns für die Unannehmlichkeiten.
>
> [Name], GiftCard Pro

### 9.3 Datenschutzverletzung

Ist ein Restore Folge eines Sicherheitsvorfalls (z. B. unbefugter Zugriff), gilt zusätzlich:

- GiftCard Pro ist für die Gästedaten Auftragsverarbeiter und muss die Lokale als Verantwortliche **unverzüglich** informieren (Art. 33 Abs. 2 DSGVO).
- Die Lokale prüfen die Meldung an die Österreichische Datenschutzbehörde innerhalb von 72 Stunden (Art. 33 Abs. 1 DSGVO).
- Für eigene Kundendaten (Konten der Lokale) ist GiftCard Pro selbst Verantwortlicher.
- Keine Rechtsberatung – mit Rechtsanwalt prüfen.

---

Version 2.0 · Stand: September 2026
