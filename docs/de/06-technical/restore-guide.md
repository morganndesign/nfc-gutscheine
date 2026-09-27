# Restore-Anleitung

*Schritt-für-Schritt-Wiederherstellung von GiftCard Pro: Untersuchung einzelner Datensätze, vollständiger Datenbank-Restore, Totalverlust des Servers, Grenzen der Point-in-Time-Wiederherstellung, Prüfabfragen und Kommunikation mit den Restaurants.*

---

## 1. Grundregeln

1. **Das Produktiv-Ledger wird nie überschrieben, um einzelne Fehler zu korrigieren.** Einzelne falsche Buchungen werden in der Anwendung mit einer Gegenbuchung (**Reverse**) bzw. einer neuen Buchung korrigiert. Ein Restore der gesamten Datenbank ist nur bei Datenbankverlust oder -beschädigung zulässig.
2. **Vor jedem Eingriff ein aktuelles Backup ziehen** – auch vom beschädigten Zustand.
3. **Zuerst in eine separate Restore-Datenbank einspielen und prüfen**, dann entscheiden.
4. Jeder Restore wird protokolliert: Zeitpunkt, verwendete Datei, Grund, handelnde Person, Ergebnis der Prüfabfragen.
5. Restore-Datenbanken enthalten personenbezogene Daten – nach Abschluss löschen.

Alle Befehle gelten auf dem Server im Verzeichnis `/opt/giftcard-pro` als Benutzer `deploy`. Abkürzung für diese Anleitung:

```bash
cd /opt/giftcard-pro
alias dc='docker compose --env-file .env.production'
```

Das MySQL-Root-Passwort steht im MySQL-Container als Umgebungsvariable `MYSQL_ROOT_PASSWORD` zur Verfügung; die folgenden Befehle verwenden sie, damit das Passwort nicht auf der Kommandozeile des Hosts erscheint.

## 2. Szenarioübersicht

| Szenario | Anlass | Produktion betroffen? | Abschnitt |
|---|---|---|---|
| A | Einzelne Datensätze prüfen, monatlicher Test-Restore | nein | 3 |
| B | Datenbank beschädigt, fehlerhafte Migration, versehentliche Massenänderung | ja, Ausfallzeit | 4 |
| C | Server verloren oder nicht mehr startfähig | ja, Ausfallzeit | 5 |
| D | Server-Snapshot zurückspielen | ja, Ausfallzeit | 6 |

## 3. Szenario A – Untersuchung in einer Restore-Datenbank

Anwendungsfälle: Ein Restaurant meldet, dass Kundendaten oder Einstellungen „gestern noch anders" waren; Nachweis eines früheren Kartenstands; monatlicher Test-Restore.

### 3.1 Backup auswählen

```bash
ls -lh backups/                                   # local (14 days)
rclone ls storagebox:giftcard-backups             # off-site
# fetch an older file from the Storage Box:
rclone copy storagebox:giftcard-backups/giftcard_pro_20261014T023001Z.sql.gz backups/
```

Die Zeitstempel im Dateinamen sind UTC.

### 3.2 In eine separate Datenbank einspielen

```bash
FILE=backups/giftcard_pro_20261014T023001Z.sql.gz

dc exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS giftcard_pro_restore; CREATE DATABASE giftcard_pro_restore CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"'
gunzip -c "$FILE" | dc exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" giftcard_pro_restore'
```

Die Produktivdatenbank `giftcard_pro` bleibt unberührt; der Betrieb läuft weiter.

### 3.3 Untersuchen

```bash
dc exec mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" giftcard_pro_restore'
```

Beispiele:

```sql
-- card state at backup time
SELECT card_number, status, balance, expires_at, updated_at
FROM gift_cards WHERE card_number = '5285105870986488';

-- customer record in backup vs. production
SELECT r.first_name, r.last_name, r.email, p.first_name, p.last_name, p.email
FROM giftcard_pro_restore.customers r
JOIN giftcard_pro.customers p ON p.id = r.id
WHERE r.id = '<customer-uuid>';

-- transactions of a card that are not in the backup yet
SELECT p.created_at, p.type, p.amount, p.balance_after
FROM giftcard_pro.gift_card_transactions p
LEFT JOIN giftcard_pro_restore.gift_card_transactions r ON r.id = p.id
WHERE p.gift_card_id = '<card-uuid>' AND r.id IS NULL
ORDER BY p.created_at;
```

### 3.4 Korrigieren – nur über die Anwendung

| Befund | Korrektur |
|---|---|
| Falsche Einlösung oder Aufladung | **Reverse** in Transactions bzw. `POST /transactions/{id}/reverse` |
| Guthaben muss auf eine andere Karte | **Transfer balance** |
| Kundendaten versehentlich überschrieben | Werte aus der Restore-Datenbank ablesen und unter Customers → Edit neu eintragen |
| Karteneinstellungen des Restaurants geändert | Werte unter Settings → Gift cards neu setzen |

Keine Zeilen aus der Restore-Datenbank per SQL in die Produktion kopieren. Direkte SQL-Änderungen umgehen Ledger, Audit-Log und Zeilensperren.

### 3.5 Aufräumen

```bash
dc exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE giftcard_pro_restore"'
```

Dumps, die nur für die Untersuchung von der Storage Box (z. B. aus einem Wochen- oder Monatsordner) nach `backups/` kopiert wurden, danach wieder löschen – sonst spiegelt der nächste `rclone sync` sie in den Tagesordner.

Beim monatlichen Test-Restore vor dem Löschen die Prüfabfragen aus Abschnitt 8 gegen `giftcard_pro_restore` ausführen und das Ergebnis dokumentieren.

## 4. Szenario B – Vollständiger Datenbank-Restore

Anlass: Die Produktivdatenbank ist beschädigt oder durch einen Fehler unbrauchbar, der Server selbst ist intakt.

**Folge:** Alle Änderungen zwischen dem Zeitpunkt des Dumps und dem Restore gehen verloren (bis zu 24 Stunden, siehe Abschnitt 7). Vorher prüfen, ob Binärlogs eine genauere Wiederherstellung erlauben (Abschnitt 7.2).

### 4.1 Ablauf

1. **Entscheidung dokumentieren** (wer, warum, welches Backup).
2. **Restaurants informieren** (Abschnitt 9) und Wartungshinweis setzen, solange die API noch läuft: Plattformadministration → System settings → Maintenance notice.
3. **Schreibende Dienste stoppen:**

```bash
dc stop queue scheduler api
```

Die Web-App zeigt danach Fehler bei API-Aufrufen; Caddy und `web` laufen weiter.

4. **Aktuellen Zustand sichern** (auch wenn er beschädigt ist):

```bash
dc --profile backup run --rm backup
```

5. **Backup auf Lesbarkeit prüfen** und optional zuerst als Szenario A einspielen und prüfen (empfohlen).
6. **Datenbank ersetzen:**

```bash
FILE=backups/giftcard_pro_20261014T023001Z.sql.gz
gzip -t "$FILE"

dc exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE giftcard_pro; CREATE DATABASE giftcard_pro CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"'
gunzip -c "$FILE" | dc exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" giftcard_pro'
```

Die Berechtigungen des Benutzers `giftcard` beziehen sich auf den Datenbanknamen und bleiben erhalten.

7. **Prüfabfragen** aus Abschnitt 8 ausführen.
8. **Dienste starten:**

```bash
dc up -d api
dc ps                                   # wait for api "healthy"
dc up -d queue scheduler web caddy
curl -fsS https://app.giftcardpro.at/up
```

Der `api`-Container führt beim Start `migrate --isolated` aus. Stammt der Dump von einer älteren Version, bringen die Migrationen das Schema auf den aktuellen Stand.

9. **Sessions:** Sessions liegen in Redis und verweisen unter Umständen auf Daten, die es nach dem Restore nicht mehr gibt. Empfohlen: alle abmelden.

```bash
dc exec redis redis-cli -a "$(grep '^REDIS_PASSWORD=' .env.production | cut -d= -f2-)" --no-auth-warning FLUSHALL
dc exec api php artisan queue:restart
```

`FLUSHALL` leert auch Queue und Cache (Folgen: siehe [Backup-Anleitung](backup-guide.md#31-redis--was-ein-verlust-bedeutet)). Das Redis-Passwort wird aus `.env.production` gelesen, weil der Redis-Container es nur als Startparameter kennt.

10. **DSGVO-Nacharbeit:** Anonymisierungen von Kundinnen und Kunden, die nach dem Zeitpunkt des Dumps erfolgt sind, erneut ausführen (Liste aus dem Audit-Log des gesicherten beschädigten Zustands oder aus den Anfragen der Restaurants).
11. **Wartungshinweis entfernen** und Restaurants informieren.

## 5. Szenario C – Totalverlust des Servers

Anlass: Server gelöscht, kompromittiert oder nicht mehr startfähig, kein brauchbarer Snapshot.

> Automatische Hetzner-Backups gehören zum Server. Wird der Server gelöscht, stehen sie in der Regel nicht mehr zur Verfügung – deshalb ist die Off-site-Kopie auf der Storage Box die maßgebliche Quelle. Bei einem **kompromittierten** Server keinen Snapshot dieses Servers verwenden und alle Secrets rotieren (Abschnitt 5.4).

### 5.1 Voraussetzungen

- Zugang zu Hetzner Cloud Console, DNS, GitHub und Storage Box
- Passwortmanager mit: Inhalt von `.env.production` und `backend/.env.production` (insbesondere `APP_KEY`, NTAG-424-Schlüssel), `rclone`-Zugang zur Storage Box (und ggf. `crypt`-Passwort)
- SHA bzw. Tag des zuletzt laufenden Releases (GitHub Actions → letzter erfolgreicher `Deploy`-Lauf)

### 5.2 Neuen Server aufbauen

1. Server nach [Deployment-Anleitung](deployment-guide.md), Abschnitte 2 und 3, anlegen, härten und Docker installieren.
2. Repository klonen und auf das zuletzt laufende Release setzen:

```bash
cd /opt/giftcard-pro
git clone git@github.com:your-org/giftcard-pro.git .
git checkout <release-sha>
```

3. `.env.production` und `backend/.env.production` aus dem Passwortmanager wiederherstellen. In `.env.production` `IMAGE_TAG=<release-sha>` setzen.
4. DNS: A-/AAAA-Records auf die neue IP umstellen (die TTL bestimmt, wie schnell die Umstellung wirkt).

### 5.3 Daten wiederherstellen

```bash
sudo apt -y install rclone && rclone config            # remote "storagebox" as before
mkdir -p backups
rclone copy storagebox:giftcard-backups backups/ --max-age 48h
ls -lh backups/

docker login ghcr.io
dc up -d mysql redis                                   # creates empty database and user
dc ps                                                  # wait for mysql "healthy"

FILE=$(ls -t backups/giftcard_pro_*.sql.gz | head -1)
gzip -t "$FILE"
gunzip -c "$FILE" | dc exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" giftcard_pro'
```

Prüfabfragen aus Abschnitt 8 ausführen, dann alle Dienste starten:

```bash
dc up -d
dc ps
curl -fsS https://app.giftcardpro.at/up
dc exec scheduler php artisan schedule:list
```

Caddy stellt das TLS-Zertifikat beim ersten HTTPS-Aufruf neu aus. Let's Encrypt begrenzt die Anzahl identischer Zertifikate pro Woche – wiederholte Neuinstallationen innerhalb kurzer Zeit vermeiden.

Danach: Cron-Jobs für Backup und Off-site-Sync wieder einrichten ([Backup-Anleitung](backup-guide.md)), Hetzner-Backups und Firewall aktivieren, GitHub-Secret `DEPLOY_HOST` und `DEPLOY_HOST_FINGERPRINT` auf den neuen Server aktualisieren.

### 5.4 Zusätzlich bei Kompromittierung

- `DB_PASSWORD`, `DB_ROOT_PASSWORD`, `REDIS_PASSWORD`, `MAIL_PASSWORD`, Deploy-SSH-Schlüssel und `GHCR_READ_TOKEN` neu erzeugen.
- `APP_KEY` neu erzeugen: Alle Sessions werden ungültig (gewollt).
- Alle API-Tokens der Restaurants als kompromittiert betrachten: Restaurants informieren, Tokens widerrufen und neu anlegen lassen.
- NTAG-424-Schlüssel: Ein Wechsel macht bereits programmierte NTAG-424-DNA-Karten unprüfbar. Entscheidung gemeinsam mit den betroffenen Restaurants; ggf. Karten tauschen.
- Meldepflichten nach DSGVO prüfen (Abschnitt 9.3).

## 6. Szenario D – Server-Snapshot zurückspielen

Wenn der Server noch existiert und ein Hetzner-Backup bzw. Snapshot vorliegt, ist das der schnellste Weg: Hetzner Cloud Console → Server → Backups/Snapshots → **Rebuild** bzw. **Restore**.

- Der Server kehrt vollständig auf den Stand des Snapshots zurück (Datenbank, Redis, `.env`, Zertifikate).
- Datenverlust: alles seit dem Snapshot-Zeitpunkt. Liegt ein neuerer logischer Dump vor (z. B. 02:30 des aktuellen Tages, Snapshot vom Vortag), danach zusätzlich Szenario B mit dem neueren Dump ausführen.
- Nach dem Start die Prüfabfragen aus Abschnitt 8 ausführen – der Snapshot ist nur absturzkonsistent; InnoDB führt beim Start eine Wiederherstellung durch.

## 7. Point-in-Time-Grenzen und Verbesserung

### 7.1 Ist-Stand

- Tägliche Dumps um 02:30 → **RPO bis zu 24 Stunden**. Eine Beschädigung um 21:00 bedeutet ohne weitere Maßnahmen den Verlust aller Buchungen seit 02:30.
- Die Dumps enthalten keine Binärlog-Position (`backup.sh` verwendet kein `--source-data`).

### 7.2 Binärlogs nutzen, wenn der Server intakt ist

MySQL 8.4 schreibt standardmäßig Binärlogs in das Datenverzeichnis (Volume `mysql_data`). Prüfen:

```sql
SHOW VARIABLES LIKE 'log_bin';
SHOW VARIABLES LIKE 'binlog_expire_logs_seconds';
SHOW BINARY LOGS;
```

Sind Binärlogs vorhanden, lassen sich nach Einspielen des Dumps die Änderungen bis kurz vor dem Fehler nachspielen (nur mit Erfahrung in MySQL-Administration und zuerst in einer Restore-Datenbank):

```bash
dc exec mysql sh -c 'mysqlbinlog --start-datetime="2026-10-14 02:30:00" --stop-datetime="2026-10-14 20:59:00" /var/lib/mysql/binlog.0000* > /tmp/replay.sql'
```

Da der Dump keine exakte Binlog-Position enthält, ist der Startzeitpunkt nur näherungsweise bestimmbar; Doppelbuchungen werden durch den eindeutigen `idempotency_key` im Ledger zwar abgewiesen, das Ergebnis ist trotzdem sorgfältig mit den Prüfabfragen zu kontrollieren. Die Zeitangaben von `mysqlbinlog` beziehen sich auf die Zeitzone des MySQL-Containers (UTC).

Bei Totalverlust des Servers sind die Binärlogs mit dem Volume verloren.

### 7.3 Empfohlene Verbesserung (Roadmap Betrieb)

| Maßnahme | Wirkung |
|---|---|
| `--source-data=2` in `backup.sh` (benötigt zusätzliche MySQL-Rechte für den Backup-Benutzer) | exakte Binlog-Position im Dump |
| Binärlogs laufend off-site kopieren (z. B. `mysqlbinlog --read-from-remote-server --raw --stop-never` in einem eigenen Dienst oder `rclone copy` alle 5 Minuten) | RPO wenige Minuten auch bei Totalverlust |
| Alternativ: Managed MySQL mit Point-in-Time-Recovery | RPO im Minutenbereich ohne Eigenbetrieb |
| Zweiter Server als Replica (Standby) | kurze RTO bei Serverausfall |

## 8. Prüfabfragen nach einem Restore

Gegen die wiederhergestellte Datenbank ausführen (`giftcard_pro` oder `giftcard_pro_restore`).

**1. Ledger-Konsistenz – Summe der Buchungen = Guthaben je Karte (Pflicht, Ergebnis muss leer sein):**

```sql
SELECT g.id, g.card_number, g.balance, COALESCE(SUM(t.amount), 0) AS ledger_sum
FROM gift_cards g
LEFT JOIN gift_card_transactions t ON t.gift_card_id = g.id
GROUP BY g.id, g.card_number, g.balance
HAVING g.balance <> COALESCE(SUM(t.amount), 0);
```

**2. Letzte Buchung jeder Karte stimmt mit dem Guthaben überein (Ergebnis muss leer sein):**

```sql
SELECT g.id, g.card_number, g.balance, t.balance_after
FROM gift_cards g
JOIN gift_card_transactions t ON t.id = (
  SELECT t2.id FROM gift_card_transactions t2
  WHERE t2.gift_card_id = g.id
  ORDER BY t2.created_at DESC, t2.id DESC LIMIT 1)
WHERE t.balance_after <> g.balance;
```

**3. Zeitpunkt des Datenstands:**

```sql
SELECT MAX(created_at) AS last_transaction FROM gift_card_transactions;
SELECT MAX(created_at) AS last_audit FROM audit_logs;
SELECT MAX(created_at) AS last_scan FROM nfc_scans;
```

**4. Offene Verbindlichkeit je Restaurant** (mit dem Dashboard-Wert „Outstanding balance" und mit Angaben der Restaurants vergleichen):

```sql
SELECT r.name, COUNT(*) AS cards, SUM(g.balance) / 100 AS outstanding_eur
FROM gift_cards g JOIN restaurants r ON r.id = g.restaurant_id
WHERE g.status IN ('active', 'inactive', 'blocked') AND g.deleted_at IS NULL
GROUP BY r.name ORDER BY r.name;
```

**5. Mengengerüst** (Vergleich mit dem Vortag bzw. dem letzten Test-Restore):

```sql
SELECT (SELECT COUNT(*) FROM restaurants) AS restaurants,
       (SELECT COUNT(*) FROM users) AS users,
       (SELECT COUNT(*) FROM gift_cards) AS cards,
       (SELECT COUNT(*) FROM gift_card_transactions) AS transactions,
       (SELECT COUNT(*) FROM audit_logs) AS audit_entries;
```

**6. Schema und Anwendung:**

```bash
dc exec api php artisan migrate:status
curl -fsS https://app.giftcardpro.at/up
```

**7. Funktionsprüfung:** Anmeldung, Karte öffnen, Testeinlösung von € 0,01 auf einer internen Testkarte und Storno (siehe [Deployment-Anleitung](deployment-guide.md#8-kontrollen-nach-dem-deployment)).

Weicht Abfrage 1 oder 2 ab: Restore **nicht** freigeben, Datenbank nicht in Betrieb nehmen, älteren Dump prüfen und die Entwicklung einbeziehen.

## 9. Kommunikation mit den Restaurants

### 9.1 Grundsätze

- Früh informieren, auch wenn noch nicht alles klar ist. Kurze, sachliche Sätze.
- Konkreten **Zeitraum** nennen, dessen Daten betroffen sind (in Wiener Zeit).
- Klar sagen, **was das Restaurant tun muss** – und was nicht.
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
> 3. Fehlende Einlösungen erfassen Sie auf der jeweiligen Karte mit **Redeem** und dem Vermerk „Nacherfassung [Datum]" im Feld Reference. Fehlende Verkäufe legen Sie als **New gift card** neu an – bitte kontaktieren Sie uns vorher, damit die bereits beschriebene NFC-Karte weiter funktioniert.
>
> Alle anderen Daten – Karten, Guthaben, Kundinnen und Kunden, Einstellungen – sind vollständig. Ihre Gäste können die Karten ohne Einschränkung weiter verwenden.
>
> Bei Fragen erreichen Sie uns unter support@giftcardpro.at oder [Telefon].
>
> Wir entschuldigen uns für die Unannehmlichkeiten.
>
> [Name], GiftCard Pro

Hinweis: Eine Karte, die im verlorenen Zeitraum verkauft wurde, existiert nach dem Restore nicht mehr; ihr Token auf dem NFC-Chip ist unbekannt. Diese Karten werden mit Unterstützung des Supports neu ausgegeben und neu beschrieben bzw. getauscht.

### 9.3 Datenschutzverletzung

Ist ein Restore Folge eines Sicherheitsvorfalls (z. B. unbefugter Zugriff), gilt zusätzlich:

- GiftCard Pro ist für die Gästedaten Auftragsverarbeiter und muss die Restaurants als Verantwortliche **unverzüglich** informieren (Art. 33 Abs. 2 DSGVO).
- Die Restaurants prüfen die Meldung an die Österreichische Datenschutzbehörde innerhalb von 72 Stunden (Art. 33 Abs. 1 DSGVO).
- Für eigene Kundendaten (Konten der Restaurants) ist GiftCard Pro selbst Verantwortlicher.
- Keine Rechtsberatung – mit Rechtsanwalt prüfen.

---

Version 1.0 · Stand: September 2026
