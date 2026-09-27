# Notfallwiederherstellungsplan (Disaster Recovery)

*Wie GiftCard Pro nach schweren Störungen den Betrieb wiederherstellt – Zielwerte, Rollen, Szenarien, Schritt-für-Schritt-Abläufe und Kommunikation. Für das Betriebsteam von GiftCard Pro; Lokale und Partner erhalten diesen Plan zur Information.*

---

## 1. Geltungsbereich

Dieser Plan gilt für die Produktivumgebung von GiftCard Pro:

| Komponente | Beschreibung |
|---|---|
| Server | Hetzner Cloud, Ubuntu 24.04, Rechenzentrum in Deutschland (Falkenstein oder Nürnberg), Docker Compose |
| Dienste | Caddy (TLS, Proxy), Laravel-API, Next.js-Web, Queue-Worker, Scheduler, MySQL 8.4, Redis |
| Daten | MySQL-Datenbank (Karten, Journal, Audit-Log, Kunden, Benutzer, Einstellungen); Redis enthält nur Sitzungen, Cache und Warteschlangen |
| Sicherungen | Nächtlicher MySQL-Dump 02:30 Uhr, 14 Tage lokal; Übertragung auf Hetzner Storage Box 02:45 Uhr; tägliche Hetzner-Server-Snapshots |
| Code & Images | GitHub-Repository, Container-Images in der GitHub Container Registry (GHCR), je Version mit Commit gekennzeichnet |
| Geheimnisse | `APP_KEY`, Datenbank- und Redis-Passwörter, NTAG-424-Schlüssel, Deploy-Schlüssel – im Passwortmanager des Betreibers |
| Domain & DNS | `giftcardpro.at`, `app.giftcardpro.at` bei `[Domain-Registrar / DNS-Anbieter]` |

Nicht Gegenstand dieses Plans: Geräte, WLAN und Registrierkasse der Lokale. Für diese ist das jeweilige Lokal verantwortlich.

---

## 2. Zielwerte

| Kennzahl | Zielwert | Grundlage |
|---|---|---|
| **RPO** (maximaler Datenverlust) | **≤ 24 Stunden** | tägliche Datenbank-Dumps und Server-Snapshots |
| **RTO** (Wiederherstellung nach Totalverlust des Servers) | **4 Stunden (Ziel)** | Neuaufbau aus Images, Konfiguration und letztem Dump |
| RTO bei Anwendungsfehler nach einem Update | 30 Minuten (Ziel) | Rückkehr zum vorherigen Image |
| Verfügbarkeit | 99,5 % pro Monat (Ziel) | im Tarif Start keine Garantie; Gruppe mit vertraglichem SLA möglich |

Die Werte sind **Ziele**, keine zugesicherten Eigenschaften, sofern nicht vertraglich anders vereinbart.

**Folge des RPO für Lokale:** Im schlimmsten Fall fehlen nach einer Wiederherstellung die Buchungen seit dem letzten nächtlichen Dump. Weil jedes Lokal Verkauf und Einlösung zusätzlich in seiner Registrierkasse bucht, lassen sich fehlende Buchungen anhand der Kassenbelege nachtragen. Abschnitt 6.2 beschreibt das Vorgehen.

---

## 3. Rollen

| Rolle | Aufgabe | Besetzung |
|---|---|---|
| **Notfallleitung** | Entscheidet über die Ausrufung des Notfalls, das Szenario und die Kommunikation | [Name], Gründerin |
| **Technische Wiederherstellung** | Führt die Runbooks aus | [Name / technische Vertretung] |
| **Kommunikation** | Informiert Lokale, beantwortet Support-Anfragen | [Name] bzw. Notfallleitung |
| **Vertretung** | Übernimmt, wenn eine der obigen Personen nicht erreichbar ist | [Name der Vertretung] |

Da GiftCard Pro ein kleines Team ist, können mehrere Rollen bei einer Person liegen. Entscheidend ist, dass die **Vertretung** (Abschnitt 5.8) Zugang zu Passwortmanager, Hetzner, GitHub und DNS hat und diesen Plan kennt.

**Notfallkontakte** (in der Offline-Kopie dieses Plans ausfüllen): Notfallleitung `[Telefon]`, Vertretung `[Telefon]`, Hetzner-Support `[Kundennummer]`, Domain-Registrar `[Kundennummer]`, E-Mail-Versanddienstleister `[Kundennummer]`.

---

## 4. Voraussetzungen (vorab sicherstellen)

- [ ] Passwortmanager enthält: `APP_KEY`, `.env.production`-Inhalte (API und Compose), NTAG-424-Schlüssel, Zugänge zu Hetzner, Storage Box, GitHub, Registrar/DNS, E-Mail-Versand.
- [ ] Zwei-Faktor-Authentisierung für Hetzner, GitHub, Registrar; Wiederherstellungscodes offline verwahrt.
- [ ] Ausgedruckte bzw. offline gespeicherte Kopie dieses Plans und der Notfallkontakte.
- [ ] Mindestens zwei Personen mit Zugriff auf den Passwortmanager.
- [ ] Letzter erfolgreicher Restore-Test ist nicht älter als drei Monate.

---

## 5. Szenarien

### 5.1 Totalverlust des Servers

*Beispiele: Hardwaredefekt, versehentliches Löschen, Server nicht mehr startbar.*

1. **Feststellen:** `/up` nicht erreichbar, Server in der Hetzner-Konsole nicht startbar. Notfallleitung informieren, Notfall ausrufen, Status an Lokale (Vorlage A).
2. **Entscheiden:** Wiederherstellung aus Hetzner-Snapshot (schneller, Stand bis 24 h alt) oder Neuaufbau mit letztem Dump (Stand 02:30 Uhr desselben Tages). Ist der letzte Dump jünger als der Snapshot, wird er nach dem Snapshot-Restore zusätzlich eingespielt.
3. **Variante A – Snapshot:** In der Hetzner-Konsole neuen Server aus dem letzten Snapshot erzeugen (gleicher Typ, EU-Standort), Cloud Firewall zuweisen (22 nur von Betreiber-IPs, 80, 443).
4. **Variante B – Neuaufbau:**
   1. Neuen Server anlegen, SSH-Schlüssel hinterlegen, Firewall zuweisen.
   2. Härtung und Docker gemäß Deployment-Handbuch (Benutzer `deploy`, keine Passwort- und Root-Anmeldung, `unattended-upgrades`, `fail2ban`, Docker).
   3. Repository nach `/opt/giftcard-pro` klonen, `.env.production` und `backend/.env.production` aus dem Passwortmanager wiederherstellen – **mit dem ursprünglichen `APP_KEY`** und den ursprünglichen NTAG-424-Schlüsseln.
   4. Letzten Dump von der Storage Box holen (`rclone copy storagebox:giftcard-backups/<datei> ./backups/`).
   5. Nur MySQL starten, Dump einspielen: `gunzip -c backups/<datei>.sql.gz | docker compose --env-file .env.production exec -T mysql mysql -u root -p <datenbank>`.
   6. Alle Dienste starten: `docker compose --env-file .env.production up -d`.
5. **DNS:** A/AAAA-Einträge von `app.giftcardpro.at` auf die neue IP umstellen. Caddy holt das TLS-Zertifikat beim ersten Aufruf automatisch.
6. **Prüfen:** `/up` liefert 200; Anmeldung als Plattform-Administration; Stichprobe: Karte eines Testlokals scannen; Summe der Journalbuchungen je Karte entspricht dem Guthaben (Konsistenzprüfung); Scheduler und Queue laufen (`schedule:list`, Queue-Überwachung).
7. **Nacharbeit:** Cronjobs für Backup und Off-Site-Sync auf dem neuen Server einrichten und manuell einmal ausführen. Lokale über den Datenstand informieren (Vorlage C), Nachbuchung koordinieren (Abschnitt 6.2).

### 5.2 Datenbank beschädigt

*Beispiele: MySQL startet nicht, inkonsistente Tabellen, fehlerhafte Migration.*

1. Schreibzugriffe stoppen: Web, API, Worker und Scheduler anhalten (`docker compose stop web api queue scheduler`), damit keine weiteren Buchungen auf beschädigten Daten entstehen. Wartungshinweis (Vorlage A).
2. Zustand sichern: Datenvolume bzw. Datenbankverzeichnis als Kopie ablegen (für die Analyse, nicht überschreiben).
3. Versuch der Reparatur nur, wenn Ursache und Umfang klar sind. Andernfalls:
4. Neue, leere Datenbank anlegen (z. B. `giftcard_pro_restore`), letzten Dump einspielen, Konsistenzprüfung (Guthaben = Summe der Buchungen je Karte, Anzahl Karten/Buchungen plausibel).
5. Konfiguration auf die wiederhergestellte Datenbank umstellen, Dienste starten, prüfen wie in 5.1 Schritt 6.
6. Buchungen zwischen Dump und Ausfall ermitteln (siehe 6.2) und Lokale informieren.

### 5.3 Ausfall des Rechenzentrums bzw. Standorts

*Beispiel: Hetzner-Standort längere Zeit nicht verfügbar.*

1. Hetzner-Statusseite prüfen; bei erwarteter Dauer über 2 Stunden Neuaufbau an einem anderen EU-Standort von Hetzner (z. B. Nürnberg statt Falkenstein) nach 5.1 Variante B.
2. Der Dump wird von der Storage Box geholt. Ist diese ebenfalls nicht erreichbar, wird der jüngste erreichbare Stand verwendet; das RPO kann dann überschritten werden.
3. DNS umstellen, prüfen, informieren.

Hinweis: Ein zweiter, dauerhaft bereitstehender Standort ist derzeit nicht eingerichtet (siehe Verbesserungsliste).

### 5.4 Ransomware oder Kompromittierung des Servers

*Beispiele: verschlüsselte Dateien, unbekannte Prozesse, veränderte Konfiguration, Hinweise auf Zugriff durch Dritte.*

1. **Nicht** herunterfahren, bevor Beweise gesichert sind, außer es werden aktiv Daten zerstört. Server in der Hetzner-Konsole vom Netz trennen (Firewall: alle Regeln entfernen) und Snapshot für die Forensik erstellen.
2. Parallel den [Leitfaden Incident Response](incident-response-guide.md) starten (Schweregrad SEV-1, Datenschutzprüfung).
3. **Alle Geheimnisse als kompromittiert behandeln:** neuen `APP_KEY` erzeugen (alle Benutzer werden abgemeldet), neue Datenbank- und Redis-Passwörter, neuer Deploy-Schlüssel, GHCR-Token, Storage-Box-Zugang erneuern. NTAG-424-Schlüssel nur tauschen, wenn sie nachweislich betroffen sind (ein Tausch erfordert die Neuprogrammierung der Karten).
4. Neuaufbau auf einem **neuen** Server nach 5.1 Variante B – nie den kompromittierten Server weiterverwenden.
5. Dump auswählen, der **vor** dem Kompromittierungszeitpunkt liegt; die Integrität wird durch Konsistenzprüfung und Vergleich mit älteren Dumps bestätigt. Achtung: Die Off-Site-Kopie wird per `rclone sync` gespiegelt und enthält wie der Server die Dumps der letzten 14 Tage. Sie ist vom Produktivserver aus beschreibbar und daher nicht automatisch vor einem Angreifer geschützt – Hetzner-Snapshots und die Storage-Box-Stände getrennt auf Unversehrtheit prüfen (siehe Verbesserungsliste Nr. 5).
6. Nach Wiederherstellung: Passwort-Reset für alle Plattform-Administratoren, Lokale auffordern, API-Tokens zu erneuern.

### 5.5 Versehentliche Datenänderung

*Beispiele: Karte irrtümlich gesperrt oder abgelaufen, falsche Einlösung, falsche Einstellung.*

Die Anwendung löscht keine Daten, Buchungen werden nicht überschrieben. Die meisten Fehler werden **in der Anwendung** korrigiert, nicht durch eine Wiederherstellung:

| Fehler | Korrektur |
|---|---|
| Falsche Einlösung oder Aufladung | Storno (Gegenbuchung) im Kartenverlauf oder unter Transactions |
| Karte irrtümlich gesperrt | **„Unblock"** |
| Karte irrtümlich abgelaufen | Guthaben per Ersatzkarte bzw. Übertragung wieder verfügbar machen |
| Benutzer irrtümlich deaktiviert | Reaktivieren |
| Gerät irrtümlich gesperrt | **„Restore"** |
| Kunde irrtümlich anonymisiert | nicht umkehrbar; Personendaten aus Unterlagen des Lokals neu erfassen |

Nur wenn ein Fehler auf Datenbankebene passiert (z. B. fehlerhafte manuelle Abfrage durch den Betreiber): betroffene Datensätze aus dem letzten Dump in eine separate Datenbank einspielen und gezielt vergleichen. **Nie** die gesamte Produktivdatenbank auf einen älteren Stand zurücksetzen, nur um einen Einzelfehler zu beheben.

### 5.6 Verlust von Domain oder DNS

*Beispiele: Domain nicht verlängert, DNS-Anbieter ausgefallen, DNS-Einträge manipuliert.*

1. Beim Registrar Status prüfen; bei Ablauf sofort verlängern. Bei Manipulation: Registrar-Konto sichern (Passwort, 2FA), Einträge korrigieren, Registrar-Sperre (Transfer Lock) aktivieren.
2. Bei längerem Ausfall des DNS-Anbieters: Nameserver auf einen Ersatzanbieter umstellen (Zonendaten aus der Dokumentation).
3. **Wichtig:** Der Link auf jeder Karte zeigt auf `app.giftcardpro.at`. Die Domain darf nie aufgegeben werden, solange Karten im Umlauf sind. Bis zur Wiederherstellung können Servicekräfte Karten nicht einlösen. Eine Ausweichadresse hilft nur für die Kartennummer-Eingabe, nicht für bereits beschriebene Chips.
4. Lokale informieren (Vorlage A).

### 5.7 Sperre des Kontos beim Hosting-Anbieter

*Beispiele: Zahlungsproblem, Sperre wegen Missbrauchsverdacht, Verlust des Zugangs.*

1. Hetzner-Support kontaktieren, Sperrgrund klären.
2. Ist keine rasche Aufhebung möglich: Neuaufbau bei einem **anderen Konto bzw. EU-Anbieter** mit den Off-Site-Sicherungen. Voraussetzung: Die Off-Site-Kopie muss unabhängig vom gesperrten Konto erreichbar sein (siehe Verbesserungsliste – derzeit liegt auch die Storage Box bei Hetzner).
3. DNS umstellen, Lokale informieren, den Auftragsverarbeitungsvertrag bezüglich des neuen Unterauftragsverarbeiters aktualisieren und die Lokale darüber informieren.

### 5.8 Schlüsselperson nicht verfügbar

*Beispiele: Krankheit, Urlaub ohne Erreichbarkeit, Unfall.*

1. Die Vertretung übernimmt gemäß Abschnitt 3.
2. Zugang über den Passwortmanager, auf den die Vertretung gemäß Abschnitt 4 Zugriff hat.
3. Diese Dokumentation sowie das Deployment-Handbuch ermöglichen Neuaufbau und Wiederherstellung ohne Vorwissen.
4. Lokale werden nur informiert, wenn Supportzeiten betroffen sind.

---

## 6. Allgemeine Abläufe

### 6.1 Wiederherstellung aus einem Dump (Kurzfassung)

```bash
cd /opt/giftcard-pro
rclone copy storagebox:giftcard-backups/<giftcard_pro_YYYYMMDDTHHMMSSZ.sql.gz> ./backups/
docker compose --env-file .env.production up -d mysql
gunzip -c backups/<datei>.sql.gz | docker compose --env-file .env.production exec -T mysql mysql -u root -p <datenbank>
docker compose --env-file .env.production up -d
curl -fsS https://app.giftcardpro.at/up
```

### 6.2 Nachbuchen von Buchungen zwischen Dump und Ausfall

1. Zeitpunkt des Dumps (Dateiname, UTC) und Zeitpunkt des Ausfalls festhalten.
2. Aus Anwendungs- und Proxy-Protokollen, soweit vorhanden, betroffene Lokale und Karten ermitteln.
3. Jedem betroffenen Lokal eine Liste der Karten mit Stand zum Dump-Zeitpunkt senden und um Abgleich mit den Belegen der Registrierkasse bitten.
4. Fehlende Einlösungen, Verkäufe und Aufladungen bucht das Lokal (oder der Betreiber im Auftrag und über „Open restaurant", auditiert) mit Vermerk „Nachbuchung nach Wiederherstellung" nach.
5. Karten, die in diesem Zeitraum neu ausgegeben wurden, existieren nach der Wiederherstellung nicht. Sie sind neu anzulegen; der beschriebene Chip muss neu beschrieben werden (neue Kennung).

### 6.3 Rückkehr zum vorherigen Release

Container-Images sind mit dem Commit gekennzeichnet. Bei einem fehlerhaften Update wird das vorherige Image erneut ausgerollt. Datenbankmigrationen sind rückwärtskompatibel (erst erweitern, dann umstellen, dann bereinigen), sodass die vorherige Version mit dem neuen Schema weiterläuft.

---

## 7. Kommunikationsvorlagen

### Vorlage A – Störung (Erstinformation)

> **Betreff: GiftCard Pro – Störung seit [Uhrzeit]**
>
> Sehr geehrte Damen und Herren,
>
> seit [Uhrzeit] ist GiftCard Pro nicht bzw. nur eingeschränkt erreichbar. Betroffen ist: [Einlösen / Dashboard / alles]. Wir arbeiten an der Behebung und melden uns spätestens um [Uhrzeit] erneut.
>
> **Bis dahin empfehlen wir:** Nehmen Sie Gutscheinkarten nur an, wenn Sie Kartennummer und Betrag notieren und die Einlösung nach der Wiederherstellung nachbuchen. Kennzeichnen Sie diese Fälle in der Registrierkasse. Bei hohen Beträgen oder unbekannten Gästen empfehlen wir, die Einlösung auf einen späteren Besuch zu verschieben.
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
> **Datenstand:** [Alle Buchungen sind vollständig erhalten.] **oder** [Die Daten wurden auf den Stand vom [Datum, Uhrzeit] wiederhergestellt. Buchungen zwischen [Uhrzeit] und [Uhrzeit] fehlen. Für Ihr Lokal betrifft das voraussichtlich [Anzahl] Karten; die Liste finden Sie im Anhang. Bitte gleichen Sie diese mit Ihrer Registrierkasse ab und buchen Sie fehlende Vorgänge nach. Wir unterstützen Sie gerne dabei.]
>
> Notierte Einlösungen aus der Ausfallszeit buchen Sie bitte jetzt nach. Einen ausführlichen Bericht erhalten Sie bis [Datum].
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
| **Vollständiger Restore-Test** | **vierteljährlich** | Dump von der Storage Box holen, auf separatem Testserver vollständige Umgebung aufbauen, Anmeldung und Kartenscan testen, Dauer messen | Bericht mit gemessener Dauer gegen RTO |
| **DR-Übung** | **jährlich** | Szenario durchspielen (z. B. 5.1 oder 5.4) inkl. Vertretung, Kommunikation und DNS-Umstellung auf einer Testdomain | Bericht, Maßnahmen in Verbesserungsliste |
| Plan-Review | jährlich und nach jedem Notfall | Kontakte, Zugänge, Befehle, Zielwerte prüfen | neue Version dieses Dokuments |

---

## 9. Verbesserungsliste

| Nr. | Maßnahme | Nutzen | Status |
|---|---|---|---|
| 1 | Binärlogs (Binlogs) von MySQL aktivieren und laufend off-site sichern → Wiederherstellung auf einen beliebigen Zeitpunkt (PITR) | RPO von 24 h auf wenige Minuten | geplant |
| 2 | Zweiter Standort bzw. zweite Region mit Replikat der Datenbank | RTO bei Standortausfall deutlich kürzer | geplant |
| 3 | Off-Site-Kopie zusätzlich bei einem vom Hosting unabhängigen EU-Anbieter bzw. in einem getrennten Konto | Schutz bei Kontosperre (5.7) | geplant |
| 4 | Verschlüsselung der Sicherungsdateien vor der Übertragung | Schutz der Backups bei Zugriff auf den Speicher | geplant |
| 5 | Unveränderliche Sicherungsstände (Append-only / Versionierung) auf dem Off-Site-Speicher | Schutz gegen Ransomware, die auch Backups verschlüsselt | geplant |
| 6 | Öffentliche Statusseite | schnellere Information der Lokale | geplant |
| 7 | Automatisierter Restore-Test in der CI | laufender Nachweis der Wiederherstellbarkeit | geplant |

---

Version 1.0 · Stand: September 2026
