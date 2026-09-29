# Notfallwiederherstellungsplan (Disaster Recovery)

*Wie GiftCard Pro nach schweren Störungen den Betrieb wiederherstellt – Zielwerte, Rollen, Szenarien, Schritt-für-Schritt-Abläufe und Kommunikation. Für das Betriebsteam von GiftCard Pro; Lokale und Partner erhalten diesen Plan zur Information. Technische Details: [Deployment-Anleitung](../06-technical/deployment-guide.md), [Backup-Anleitung](../06-technical/backup-guide.md), [Restore-Anleitung](../06-technical/restore-guide.md).*

---

## 1. Geltungsbereich

Dieser Plan gilt für die Produktivumgebung von GiftCard Pro:

| Komponente | Beschreibung |
|---|---|
| Server | Hetzner Cloud, Ubuntu 24.04, Rechenzentrum in Deutschland (Falkenstein oder Nürnberg), Coolify |
| Dienste | eine Coolify-Ressource aus `docker-compose.coolify.yml`: Gateway (Caddy), Laravel-API, Next.js-Web, Queue-Worker, Scheduler, MySQL 8.4, Redis, Backup-Dienst; TLS über den Coolify-Proxy |
| Daten | MySQL-Datenbank (Gutscheine, Hashes der QR-Codes, Zahlungen, Ledger, Audit-Log, Kunden, Benutzer, Einstellungen); Ledger, Zahlungen und Audit-Log sind append-only und über Hash-Ketten verknüpft. Redis enthält nur Sitzungen, Cache und Warteschlangen |
| Sicherungen | Täglicher MySQL-Dump um `BACKUP_TIME` (Standard 01:30 UTC) im Dienst `backup`, 14 Tage im Volume `mysql-backups`; Übertragung auf Hetzner Storage Box (Root-Cron); tägliche Hetzner-Server-Snapshots |
| Code | GitHub-Repository; Coolify baut jedes Image aus dem Quellcode, jedes Deployment ist einem Commit zugeordnet |
| Kellner-App | GiftCard Waiter über Google Play und App Store; die Serveradresse ist beim Build festgelegt (`config/production.json`) |
| Geheimnisse | `APP_KEY`, SMTP-Zugangsdaten, von Coolify erzeugte Datenbank- und Redis-Passwörter, Signaturschlüssel der App – im Passwortmanager des Betreibers bzw. in Coolify und den GitHub-Secrets. Kartenschlüssel sind nie Teil dieser Umgebung |
| Domain & DNS | `giftcardpro.at`, `app.giftcardpro.at` bei `[Domain-Registrar / DNS-Anbieter]` |

Nicht Gegenstand dieses Plans: Geräte, WLAN und Registrierkasse der Lokale. Für diese ist das jeweilige Lokal verantwortlich.

---

## 2. Zielwerte

| Kennzahl | Zielwert | Grundlage |
|---|---|---|
| **RPO** (maximaler Datenverlust) | **≤ 24 Stunden** | tägliche Datenbank-Dumps und Server-Snapshots |
| **RTO** (Wiederherstellung nach Totalverlust des Servers) | **4 Stunden (Ziel)** | Neuaufbau mit Coolify aus dem Repository, Konfiguration und letztem Dump |
| RTO bei Anwendungsfehler nach einem Update | 30 Minuten (Ziel) | Redeploy des vorherigen Deployments in Coolify |
| Verfügbarkeit | 99,5 % pro Monat (Ziel) | im Tarif Start keine Garantie; Gruppe mit vertraglichem SLA möglich |

Die Werte sind **Ziele**, keine zugesicherten Eigenschaften, sofern nicht vertraglich anders vereinbart.

**Folge des RPO für Lokale:** Im schlimmsten Fall fehlen nach einer Wiederherstellung die Buchungen seit dem letzten nächtlichen Dump. Weil jedes Lokal Verkauf und Einlösung zusätzlich in seiner Registrierkasse bucht, lassen sich fehlende Buchungen anhand der Kassenbelege feststellen. Abschnitt 6.2 beschreibt das Vorgehen.

---

## 3. Rollen

| Rolle | Aufgabe | Besetzung |
|---|---|---|
| **Notfallleitung** | Entscheidet über die Ausrufung des Notfalls, das Szenario und die Kommunikation | [Name], Gründerin |
| **Technische Wiederherstellung** | Führt die Runbooks aus | [Name / technische Vertretung] |
| **Kommunikation** | Informiert Lokale, beantwortet Support-Anfragen | [Name] bzw. Notfallleitung |
| **Vertretung** | Übernimmt, wenn eine der obigen Personen nicht erreichbar ist | [Name der Vertretung] |

Da GiftCard Pro ein kleines Team ist, können mehrere Rollen bei einer Person liegen. Entscheidend ist, dass die **Vertretung** (Abschnitt 5.8) Zugang zu Passwortmanager, Hetzner, Coolify, GitHub und DNS hat und diesen Plan kennt.

**Notfallkontakte** (in der Offline-Kopie dieses Plans ausfüllen): Notfallleitung `[Telefon]`, Vertretung `[Telefon]`, Hetzner-Support `[Kundennummer]`, Domain-Registrar `[Kundennummer]`, E-Mail-Versanddienstleister `[Kundennummer]`.

---

## 4. Voraussetzungen (vorab sicherstellen)

- [ ] Passwortmanager enthält: `APP_KEY`, SMTP-Zugangsdaten, Zugänge zu Hetzner, Coolify, Storage Box, GitHub, Registrar/DNS, E-Mail-Versand, App Store Connect und Google Play.
- [ ] Zwei-Faktor-Authentisierung für Hetzner, Coolify, GitHub, Registrar; Wiederherstellungscodes offline verwahrt.
- [ ] Ausgedruckte bzw. offline gespeicherte Kopie dieses Plans und der Notfallkontakte.
- [ ] Mindestens zwei Personen mit Zugriff auf den Passwortmanager.
- [ ] Letzter erfolgreicher Restore-Test (mit `giftcard:verify-chains` ohne Befund) ist nicht älter als drei Monate.

---

## 5. Szenarien

### 5.1 Totalverlust des Servers

*Beispiele: Hardwaredefekt, versehentliches Löschen, Server nicht mehr startbar.*

1. **Feststellen:** `/up` nicht erreichbar, Server in der Hetzner-Konsole nicht startbar. Notfallleitung informieren, Notfall ausrufen, Status an Lokale (Vorlage A).
2. **Entscheiden:** Wiederherstellung aus Hetzner-Snapshot (schneller, Stand bis 24 h alt) oder Neuaufbau mit letztem Dump. Ist der letzte Dump jünger als der Snapshot, wird er nach dem Snapshot-Restore zusätzlich eingespielt.
3. **Variante A – Snapshot:** In der Hetzner-Konsole neuen Server aus dem letzten Snapshot erzeugen (gleicher Typ, EU-Standort), Firewall zuweisen (22 nur von Betreiber-IPs, 80, 443).
4. **Variante B – Neuaufbau** ([Restore-Anleitung, Szenario C](../06-technical/restore-guide.md#5-szenario-c--totalverlust-des-servers)):
   1. Neuen Server anlegen, SSH-Schlüssel hinterlegen, Firewall zuweisen, Coolify installieren.
   2. Coolify-Ressource aus dem Repository anlegen wie in der [Deployment-Anleitung](../06-technical/deployment-guide.md) – Gateway-Domain, `MAIL_*` und **der ursprüngliche `APP_KEY`** aus dem Passwortmanager als Environment Variables.
   3. *Deploy*; Coolify erzeugt die Datenbank- und Redis-Passwörter, die Container legen ein leeres Schema an.
   4. Letzten Dump von der Storage Box in das Volume `mysql-backups` holen, Wartungsmodus (`php artisan down`), Dump im Container **backup** einspielen, *Redeploy*.
5. **DNS:** A/AAAA-Einträge von `app.giftcardpro.at` auf die neue IP umstellen. Coolify holt das TLS-Zertifikat automatisch.
6. **Prüfen:** `/up` liefert 200; `php artisan giftcard:verify-chains` ohne Befund; Anmeldung als Plattform-Administration; Stichprobe: Test-QR eines Testlokals scannen; Scheduler und Queue laufen (`schedule:list`, Queue-Überwachung).
7. **Nacharbeit:** Off-Site-Sync auf dem neuen Server einrichten und einmal manuell ausführen. Lokale über den Datenstand informieren (Vorlage C), Nacherfassung koordinieren (Abschnitt 6.2).

### 5.2 Datenbank beschädigt

*Beispiele: MySQL startet nicht, inkonsistente Tabellen, fehlerhafte Migration, Integritätsprüfung meldet einen Befund.*

1. Schreibzugriffe stoppen: Wartungsmodus (`php artisan down`) bzw. Dienste `api`, `worker` und `scheduler` in Coolify anhalten, damit keine weiteren Buchungen auf beschädigten Daten entstehen. Wartungshinweis (Vorlage A).
2. Zustand sichern: frischen Dump und Snapshot des Volumes `mysql-data` anlegen (für die Analyse, nicht überschreiben). Meldet die Integritätsprüfung einen Befund, zusätzlich den [Leitfaden Incident Response](incident-response-guide.md) (Playbook 7.7) starten.
3. Versuch der Reparatur nur, wenn Ursache und Umfang klar sind. Ledger, Zahlungen und Audit-Log werden nie per SQL korrigiert. Andernfalls:
4. Letzten Dump zuerst in eine separate Datenbank einspielen und mit den Prüfabfragen der [Restore-Anleitung](../06-technical/restore-guide.md#8-prüfabfragen-nach-einem-restore) prüfen (Guthaben = Summe der Buchungen, jede Buchung mit Zahlung bzw. Scan, Mengen plausibel).
5. Produktivdatenbank aus diesem Dump wiederherstellen (Restore-Anleitung, Szenario B), *Redeploy*, `php artisan giftcard:verify-chains`, prüfen wie in 5.1 Schritt 6.
6. Buchungen zwischen Dump und Ausfall ermitteln (siehe 6.2) und Lokale informieren.

### 5.3 Ausfall des Rechenzentrums bzw. Standorts

*Beispiel: Hetzner-Standort längere Zeit nicht verfügbar.*

1. Hetzner-Statusseite prüfen; bei erwarteter Dauer über 2 Stunden Neuaufbau an einem anderen EU-Standort von Hetzner (z. B. Nürnberg statt Falkenstein) nach 5.1 Variante B.
2. Der Dump wird von der Storage Box geholt. Ist diese ebenfalls nicht erreichbar, wird der jüngste erreichbare Stand verwendet; das RPO kann dann überschritten werden.
3. DNS umstellen, prüfen, informieren.

Hinweis: Ein zweiter, dauerhaft bereitstehender Standort ist nicht eingerichtet (siehe Verbesserungsliste).

### 5.4 Ransomware oder Kompromittierung des Servers

*Beispiele: verschlüsselte Dateien, unbekannte Prozesse, veränderte Konfiguration, Hinweise auf Zugriff durch Dritte, gebrochene Hash-Kette.*

1. **Nicht** herunterfahren, bevor Beweise gesichert sind, außer es werden aktiv Daten zerstört. Server in der Hetzner-Konsole vom Netz trennen (Firewall: alle Regeln entfernen) und Snapshot für die Forensik erstellen.
2. Parallel den [Leitfaden Incident Response](incident-response-guide.md) starten (Schweregrad SEV-1, Datenschutzprüfung).
3. **Alle Geheimnisse als kompromittiert behandeln:** neuen `APP_KEY` erzeugen (alle Benutzer werden abgemeldet), neue Datenbank- und Redis-Passwörter (neue Coolify-Ressource), SMTP-Passwort, SSH-Schlüssel, Storage-Box-Zugang und die GitHub-Verbindung von Coolify erneuern. Alle API- und Gerätetokens widerrufen. Die QR-Codes der Gutscheine bleiben gültig: Der Server speichert nur Hashes, aus denen sich kein QR-Code erzeugen lässt.
4. Neuaufbau auf einem **neuen** Server nach 5.1 Variante B – nie den kompromittierten Server weiterverwenden.
5. Dump auswählen, der **vor** dem Kompromittierungszeitpunkt liegt; die Integrität wird mit `php artisan giftcard:verify-chains` und dem Vergleich mit älteren Dumps bestätigt. Achtung: Die Off-Site-Kopie wird per `rclone sync` gespiegelt und enthält wie der Server die Dumps der letzten 14 Tage. Sie ist vom Produktivserver aus beschreibbar und daher nicht automatisch vor einem Angreifer geschützt – Hetzner-Snapshots und die Storage-Box-Stände getrennt auf Unversehrtheit prüfen (siehe Verbesserungsliste Nr. 5).
6. Nach Wiederherstellung: Passwort-Reset für alle Plattform-Administratoren, Lokale auffordern, API-Tokens neu zu erstellen; Servicekräfte melden sich in der Kellner-App neu an.

### 5.5 Versehentliche Datenänderung

*Beispiele: Gutschein irrtümlich gesperrt oder abgelaufen, falsche Einlösung, falsche Einstellung.*

Die Anwendung löscht keine Finanzdaten, Buchungen werden nie überschrieben. Die meisten Fehler werden **in der Anwendung** korrigiert, nicht durch eine Wiederherstellung:

| Fehler | Korrektur |
|---|---|
| Falsche Einlösung oder Aufladung | Storno (Gegenbuchung) im Gutscheinverlauf oder unter Transactions |
| Gutschein irrtümlich gesperrt | **„Unblock“** |
| Gutschein irrtümlich abgelaufen | **„Reinstate“** (Owner, mit Grund); das Guthaben ist beim Ablauf erhalten geblieben |
| Benutzer irrtümlich deaktiviert | Reaktivieren |
| Gerät irrtümlich gesperrt | **„Restore“** |
| Kunde irrtümlich anonymisiert | nicht umkehrbar; Personendaten aus Unterlagen des Lokals neu erfassen |

Nur wenn ein Fehler auf Datenbankebene passiert (z. B. fehlerhafte manuelle Abfrage durch den Betreiber an Stammdaten): betroffene Datensätze aus dem letzten Dump in eine separate Datenbank einspielen und gezielt vergleichen. **Nie** die gesamte Produktivdatenbank auf einen älteren Stand zurücksetzen, nur um einen Einzelfehler zu beheben.

### 5.6 Verlust von Domain oder DNS

*Beispiele: Domain nicht verlängert, DNS-Anbieter ausgefallen, DNS-Einträge manipuliert.*

1. Beim Registrar Status prüfen; bei Ablauf sofort verlängern. Bei Manipulation: Registrar-Konto sichern (Passwort, 2FA), Einträge korrigieren, Registrar-Sperre (Transfer Lock) aktivieren.
2. Bei längerem Ausfall des DNS-Anbieters: Nameserver auf einen Ersatzanbieter umstellen (Zonendaten aus der Dokumentation).
3. **Wichtig:** Die QR-Codes der Gutscheine enthalten keine Domain und bleiben gültig. Die Kellner-App ist jedoch fest mit `https://app.giftcardpro.at/api/v1` gebaut, und die Browser-Sitzungen sind an diese Domain gebunden. Bis zur Wiederherstellung der Domain können Servicekräfte nicht einlösen; eine Ausweichdomain würde einen neuen App-Build und eine neue Store-Veröffentlichung erfordern. Die Domain darf daher nie aufgegeben werden.
4. Lokale informieren (Vorlage A).

### 5.7 Sperre des Kontos beim Hosting-Anbieter

*Beispiele: Zahlungsproblem, Sperre wegen Missbrauchsverdacht, Verlust des Zugangs.*

1. Hetzner-Support kontaktieren, Sperrgrund klären.
2. Ist keine rasche Aufhebung möglich: Neuaufbau bei einem **anderen Konto bzw. EU-Anbieter** mit Coolify und den Off-Site-Sicherungen. Voraussetzung: Die Off-Site-Kopie muss unabhängig vom gesperrten Konto erreichbar sein (siehe Verbesserungsliste – derzeit liegt auch die Storage Box bei Hetzner).
3. DNS umstellen, Lokale informieren, den Auftragsverarbeitungsvertrag bezüglich des neuen Unterauftragsverarbeiters aktualisieren und die Lokale darüber informieren.

### 5.8 Schlüsselperson nicht verfügbar

*Beispiele: Krankheit, Urlaub ohne Erreichbarkeit, Unfall.*

1. Die Vertretung übernimmt gemäß Abschnitt 3.
2. Zugang über den Passwortmanager, auf den die Vertretung gemäß Abschnitt 4 Zugriff hat.
3. Diese Dokumentation sowie die Deployment-Anleitung ermöglichen Neuaufbau und Wiederherstellung ohne Vorwissen.
4. Lokale werden nur informiert, wenn Supportzeiten betroffen sind.

---

## 6. Allgemeine Abläufe

### 6.1 Wiederherstellung aus einem Dump (Kurzfassung)

1. Container **api**: `php artisan down`.
2. Container **backup**: `gunzip -c /backups/<giftcard_pro_YYYYMMDDTHHMMSSZ>.sql.gz | mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"`.
3. Ressource → *Redeploy*.
4. Container **api**: `php artisan giftcard:verify-chains`; `curl -fsS https://app.giftcardpro.at/up`.

Details und Prüfabfragen: [Restore-Anleitung](../06-technical/restore-guide.md).

### 6.2 Nacherfassung von Buchungen zwischen Dump und Ausfall

1. Zeitpunkt des Dumps (Dateiname, UTC) und Zeitpunkt des Ausfalls festhalten.
2. Aus Anwendungs- und Gateway-Protokollen, soweit vorhanden, betroffene Lokale ermitteln.
3. Jedem betroffenen Lokal eine Liste der Gutscheine mit Stand zum Dump-Zeitpunkt senden und um Abgleich mit den Belegen der Registrierkasse bitten.
4. **Verkäufe** im verlorenen Zeitraum existieren nach der Wiederherstellung nicht; ihr QR-Code wird nicht mehr erkannt. Das Lokal verkauft den Gutschein neu, erfasst die ursprüngliche Zahlung (z. B. Kartenterminal mit der ursprünglichen Belegnummer) und übergibt dem Gast das neue Druckblatt.
5. **Aufladungen** erfasst das Lokal neu mit der ursprünglichen Zahlung und dem Vermerk „Nacherfassung nach Wiederherstellung“.
6. **Einlösungen** verlangen immer einen Scan des Gutscheins. Betroffene Gutscheine sperrt das Lokal mit diesem Vermerk; legt der Gast den Gutschein wieder vor, wird er entsperrt und die fehlende Einlösung mit Vermerk erfasst. Die Plattform-Administration bucht nie im Auftrag eines Lokals.

### 6.3 Rückkehr zum vorherigen Deployment

Jedes Deployment ist einem Commit zugeordnet. Bei einem fehlerhaften Update wird in Coolify das vorherige Deployment erneut ausgerollt (*Deployments* → *Redeploy*). Schemaänderungen sind so geschrieben, dass die vorherige Version mit dem neueren Schema weiterläuft; die Datenbank wird dabei nicht zurückgesetzt.

---

## 7. Kommunikationsvorlagen

### Vorlage A – Störung (Erstinformation)

> **Betreff: GiftCard Pro – Störung seit [Uhrzeit]**
>
> Sehr geehrte Damen und Herren,
>
> seit [Uhrzeit] ist GiftCard Pro nicht bzw. nur eingeschränkt erreichbar. Betroffen ist: [Einlösen / Verkauf / Dashboard / alles]. Wir arbeiten an der Behebung und melden uns spätestens um [Uhrzeit] erneut.
>
> **Bis dahin:** Gutscheine können in dieser Zeit nicht eingelöst werden – jede Einlösung braucht eine Prüfung des Gutscheins durch unseren Server, und die Gutscheinnummer ist dafür kein Ersatz. Bitten Sie Gäste, anders zu bezahlen oder den Gutschein beim nächsten Besuch einzulösen. Verkaufen Sie in dieser Zeit keine Gutscheine.
>
> Aktuelle Informationen: [Statusseite / E-Mail]. Fragen: support@giftcardpro.at, [Telefon].
>
> Mit freundlichen Grüßen
> Ihr GiftCard-Pro-Team

### Vorlage B – Update während der Störung

> **Betreff: GiftCard Pro – Update [Uhrzeit]**
>
> Stand [Uhrzeit]: [Ursache, soweit bekannt]. [Was bereits wiederhergestellt ist]. Voraussichtliche Wiederherstellung: [Uhrzeit]. Nächstes Update: [Uhrzeit].

### Vorlage C – Wiederherstellung abgeschlossen

> **Betreff: GiftCard Pro ist wieder verfügbar**
>
> Sehr geehrte Damen und Herren,
>
> GiftCard Pro ist seit [Uhrzeit] wieder vollständig verfügbar. Ursache war [kurze Beschreibung].
>
> **Datenstand:** [Alle Buchungen sind vollständig erhalten.] **oder** [Die Daten wurden auf den Stand vom [Datum, Uhrzeit] wiederhergestellt. Buchungen zwischen [Uhrzeit] und [Uhrzeit] fehlen. Für Ihr Lokal betrifft das voraussichtlich [Anzahl] Gutscheine; die Liste finden Sie im Anhang. Bitte gleichen Sie diese mit Ihrer Registrierkasse ab. Gutscheine, die in diesem Zeitraum verkauft wurden, verkaufen Sie bitte mit der ursprünglichen Zahlung neu und geben dem Gast das neue Druckblatt; fehlende Einlösungen erfassen Sie, sobald der Gast den Gutschein wieder vorlegt. Wir unterstützen Sie gerne dabei.]
>
> Einen ausführlichen Bericht erhalten Sie bis [Datum].
>
> Wir entschuldigen uns für die Unannehmlichkeiten.
>
> Mit freundlichen Grüßen
> Ihr GiftCard-Pro-Team

---

## 8. Tests und Übungen

| Übung | Häufigkeit | Inhalt | Nachweis |
|---|---|---|---|
| Stichproben-Restore | monatlich | letzten Dump in eine Testdatenbank einspielen, Zeilenzahlen und Konsistenz prüfen | Protokolleintrag |
| **Vollständiger Restore-Test** | **vierteljährlich** | Dump von der Storage Box holen, auf separatem Testserver mit Coolify vollständige Umgebung aufbauen, `giftcard:verify-chains`, Anmeldung und QR-Scan testen, Dauer messen | Bericht mit gemessener Dauer gegen RTO |
| **DR-Übung** | **jährlich** | Szenario durchspielen (z. B. 5.1 oder 5.4) inkl. Vertretung, Kommunikation und DNS-Umstellung auf einer Testdomain | Bericht, Maßnahmen in Verbesserungsliste |
| Plan-Review | jährlich und nach jedem Notfall | Kontakte, Zugänge, Befehle, Zielwerte prüfen | neue Version dieses Dokuments |

---

## 9. Verbesserungsliste

| Nr. | Maßnahme | Nutzen | Status |
|---|---|---|---|
| 1 | Binärlogs (Binlogs) von MySQL laufend off-site sichern → Wiederherstellung auf einen beliebigen Zeitpunkt (PITR) | RPO von 24 h auf wenige Minuten | geplant |
| 2 | Zweiter Standort bzw. zweite Region mit Replikat der Datenbank | RTO bei Standortausfall deutlich kürzer | geplant |
| 3 | Off-Site-Kopie zusätzlich bei einem vom Hosting unabhängigen EU-Anbieter bzw. in einem getrennten Konto | Schutz bei Kontosperre (5.7) | geplant |
| 4 | Verschlüsselung der Sicherungsdateien vor der Übertragung | Schutz der Backups bei Zugriff auf den Speicher | geplant |
| 5 | Unveränderliche Sicherungsstände (Append-only / Versionierung) auf dem Off-Site-Speicher | Schutz gegen Ransomware, die auch Backups verschlüsselt | geplant |
| 6 | Öffentliche Statusseite | schnellere Information der Lokale | geplant |
| 7 | Automatisierter Restore-Test mit Integritätsprüfung in der CI | laufender Nachweis der Wiederherstellbarkeit | geplant |

---

Version 2.0 · Stand: September 2026
