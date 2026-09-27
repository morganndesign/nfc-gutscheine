# Leitfaden Incident Response

*Wie GiftCard Pro Sicherheitsvorfälle erkennt, bewertet, eindämmt und aufarbeitet – mit Checklisten, Playbooks und Vorlagen für die Meldung von Datenschutzverletzungen. Für das Betriebsteam von GiftCard Pro und zur Information der Lokale.*

> **Hinweis:** Die Ausführungen zur DSGVO sind keine Rechtsberatung. Im Anlassfall mit Rechtsanwältin/Rechtsanwalt bzw. Datenschutzberatung prüfen.

---

## 1. Was ist ein Sicherheitsvorfall?

Ein Sicherheitsvorfall ist jedes Ereignis, das die **Vertraulichkeit, Integrität oder Verfügbarkeit** von GiftCard Pro, von Kartenguthaben oder von personenbezogenen Daten beeinträchtigt oder beeinträchtigen könnte. Beispiele:

- unbefugter Zugriff auf ein Konto eines Lokals oder der Plattform-Administration,
- kopierte oder manipulierte Karten, ungewöhnliche Einlösungen,
- Verlust eines Geräts mit offener Sitzung,
- veröffentlichtes oder weitergegebenes API-Token,
- Hinweise auf Zugriff auf Server, Datenbank oder Sicherungen,
- Datenschutzverletzung (Art. 4 Nr. 12 DSGVO): Vernichtung, Verlust, Veränderung, unbefugte Offenlegung von oder unbefugter Zugang zu personenbezogenen Daten.

---

## 2. Phasen

| Phase | Ziel | Kernaufgaben |
|---|---|---|
| **1. Vorbereiten** | handlungsfähig sein, bevor etwas passiert | Rollen und Vertretung festlegen, Kontaktliste, Zugänge (Passwortmanager, Hetzner, GitHub, DNS), Protokolle und Warnungen eingerichtet, Übungen |
| **2. Erkennen** | Vorfälle früh bemerken | Sicherheitswarnungen im Audit-Log und Anwendungsprotokoll (`warning`: *Suspicious gift card scan*, *Account locked*), Verfügbarkeitsüberwachung über `/up`, Meldungen von Lokalen an security@, Warteschlangen-Überwachung |
| **3. Analysieren** | Art, Umfang, Schweregrad bestimmen | Zeitlinie, betroffene Lokale, Karten, Benutzer, Daten; Datenschutzbezug prüfen |
| **4. Eindämmen** | Schaden stoppen | Geräte sperren, Benutzer deaktivieren, Tokens widerrufen, Karten sperren, Lokal suspendieren, Server isolieren |
| **5. Beseitigen** | Ursache entfernen | Schwachstelle beheben, Geheimnisse erneuern, kompromittierte Systeme neu aufbauen |
| **6. Wiederherstellen** | sicherer Normalbetrieb | Dienste freigeben, Daten korrigieren (Stornos, Ersatzkarten), verstärkt überwachen |
| **7. Lernen** | Wiederholung verhindern | Bericht, Maßnahmen, Tests ergänzen, Dokumentation aktualisieren |

---

## 3. Schweregrade

| Stufe | Beschreibung | Beispiele | Reaktion | Information der Lokale |
|---|---|---|---|---|
| **SEV-1 kritisch** | Plattformweiter Schaden oder Verdacht auf Datenabfluss | Server kompromittiert, Plattform-Admin-Konto übernommen, Datenbankauszug im Umlauf, Mandantentrennung durchbrochen | sofort, rund um die Uhr | alle bzw. alle betroffenen, unverzüglich |
| **SEV-2 hoch** | Schaden in einem oder wenigen Lokalen, Geld oder Personendaten betroffen | Owner-Konto übernommen, Kopierwelle mit Geldschaden, API-Token mit Schreibrechten veröffentlicht | innerhalb 1 Stunde | betroffene Lokale unverzüglich |
| **SEV-3 mittel** | begrenztes Risiko, eingedämmt oder ohne Schaden | einzelne kopierte Karte abgewiesen, Handy verloren und gesperrt, Brute-Force-Versuch mit Kontosperre | am selben Werktag | betroffenes Lokal |
| **SEV-4 niedrig** | Auffälligkeit ohne erkennbares Risiko | einzelne Fehlversuche, Scan einer fremden Karte | im Regelbetrieb | nicht nötig |

Im Zweifel die **höhere** Stufe wählen und später herabstufen.

---

## 4. Rollen

| Rolle | Aufgabe |
|---|---|
| **Incident-Leitung** | koordiniert, entscheidet über Schweregrad, Maßnahmen und Kommunikation; führt die Zeitlinie |
| **Technik** | Analyse, Eindämmung, Beseitigung, Beweissicherung |
| **Kommunikation** | Lokale, ggf. Partner und Öffentlichkeit informieren; Vorlagen verwenden |
| **Datenschutz** | prüft, ob eine Datenschutzverletzung vorliegt; bereitet Informationen an die Verantwortlichen bzw. die Meldung an die Datenschutzbehörde vor; Kontakt datenschutz@giftcardpro.at |
| **Lokal (Kunde)** | setzt Maßnahmen im eigenen Konto um (Geräte, Team, Karten); als Verantwortlicher zuständig für die Meldung an die Datenschutzbehörde bei Gästedaten |

In einem kleinen Team übernimmt eine Person mehrere Rollen. Die Incident-Leitung liegt bei [Name], Gründerin, Vertretung [Name].

---

## 5. Die ersten 60 Minuten

**Minute 0–15: Aufnehmen**

- [ ] Meldung bzw. Warnung dokumentieren: Uhrzeit, Quelle, wer meldet, was genau.
- [ ] Incident-Leitung bestimmen, Ticket bzw. Vorfallsdokument anlegen, Zeitlinie beginnen (UTC und Wiener Zeit).
- [ ] Vorläufigen Schweregrad festlegen.
- [ ] **Keine** Beweise vernichten: nichts löschen, Server nicht neu starten, Protokolle nicht rotieren lassen.

**Minute 15–30: Eindämmen**

- [ ] Betroffene Konten, Geräte, Tokens, Karten identifizieren (Audit-Log, Kartenverlauf, Scan-Protokoll, Request-IDs).
- [ ] Sofortmaßnahmen nach Playbook (Abschnitt 7): Gerät sperren, Benutzer deaktivieren, Token widerrufen, Karte sperren, notfalls Lokal suspendieren oder Server isolieren.
- [ ] Bei SEV-1/SEV-2: weitere Teammitglieder und Vertretung verständigen.

**Minute 30–60: Bewerten und informieren**

- [ ] Umfang abschätzen: Welche Lokale? Welche Daten? Welcher Zeitraum? Geldschaden?
- [ ] **Datenschutzprüfung:** Sind personenbezogene Daten betroffen? Wenn ja: Uhr für die Meldepflicht läuft (Abschnitt 8). Zeitpunkt der Kenntnisnahme festhalten.
- [ ] Beweise sichern (Abschnitt 6).
- [ ] Erstinformation an betroffene Lokale bei SEV-1/SEV-2 (Vorlage 9.1).
- [ ] Nächsten Statuszeitpunkt festlegen.

---

## 6. Beweissicherung

| Quelle | Inhalt | Sicherung |
|---|---|---|
| **Audit-Log** (Datenbank, unveränderlich) | Aktion, Person, Gerät, IP-Adresse, Zeit (Mikrosekunden), Request-ID, alte/neue Werte (Personendaten geschwärzt) | Export der relevanten Einträge (Dashboard bzw. Plattform-Audit) |
| **Kartenverlauf / Journal** | jede Buchung mit Saldo vorher/nachher, Idempotenzschlüssel, Gerät, Person | CSV-Export Transactions; Datenbankauszug |
| **Scan-Protokoll** (`nfc_scans`) | jeder Scan inkl. Fehlschlag, Grund (z. B. UID-Abweichung, ungültige Signatur, Replay), IP | Datenbankauszug |
| **Anwendungsprotokoll** (Laravel) | Warnungen *Suspicious gift card scan*, *Account locked*, Fehler | `docker compose logs api` in Datei sichern |
| **Proxy-Protokoll** (Caddy, JSON) | jede HTTP-Anfrage mit Zeit, IP, Pfad, Status | `docker compose logs caddy` in Datei sichern |
| **API-Tokens** | letzte Verwendung (Zeit, IP), Ersteller, Berechtigungen | Datenbankauszug |
| **Geräte** | Gerätekennung, Name, letzte Aktivität, Status | Datenbankauszug |
| **Server** | Dateisystem, Prozesse, Anmeldungen | Hetzner-Snapshot vor jeder Veränderung |

**Request-ID:** Jede Anfrage erhält eine Korrelationskennung (`X-Request-Id`), die im Audit-Log und in der Antwort steht. Damit lassen sich Audit-Einträge, Anwendungs- und Proxy-Protokoll einer einzelnen Anfrage zuordnen.

**Regeln:** Kopien mit Zeitstempel und SHA-256-Prüfsumme ablegen, Zugriff auf die Incident-Leitung beschränken, jede Handlung mit Uhrzeit in der Zeitlinie vermerken. Personenbezogene Daten in Beweismitteln nur so weit wie nötig verwenden.

---

## 7. Playbooks

### 7.1 Kompromittiertes Konto einer Mitarbeiterin / eines Mitarbeiters

*Anzeichen: Buchungen außerhalb der Arbeitszeit, unbekanntes Gerät, Meldung der Person, Kontosperre ohne eigene Fehlversuche.*

1. **Lokal (Owner):** Team → ⋯ → **„Deactivate"**. Beendet alle Sitzungen und widerruft alle API-Tokens der Person.
2. Unter **Devices** unbekannte Geräte sperren.
3. Audit-Log und Transaktionen der Person ab dem vermuteten Zeitpunkt prüfen; unberechtigte Einlösungen stornieren, betroffene Karten ggf. sperren und ersetzen.
4. Mit der Person klären, wie das Passwort bekannt wurde (Wiederverwendung, Phishing, notiert).
5. Reaktivieren erst nach Passwort-Reset über **„Send password reset"**; die Person setzt ein neues Passwort.
6. Bei Owner-Konto: Schweregrad SEV-2; GiftCard Pro unterstützt über security@. Wurden Kundendaten eingesehen oder exportiert, Datenschutzprüfung (Abschnitt 8).

### 7.2 Gestohlenes oder verlorenes Handy

1. **Devices** → Gerät → **„Revoke"**. Wirkt ab der nächsten Anfrage; auch eine noch offene Sitzung wird abgewiesen.
2. Passwort der Person zurücksetzen, falls es auf dem Gerät gespeichert war oder das Gerät nicht gesperrt war.
3. Audit-Log: Aktivität dieses Geräts ab dem Verlustzeitpunkt prüfen.
4. Wiedergefundenes Gerät: **„Restore"**.

### 7.3 Kopierwelle (Card Cloning)

*Anzeichen: mehrere Warnungen „Cloned card rejected" oder Replay-Warnungen, Gäste berichten von Guthaben, das sie nicht verbraucht haben, gleiche Karte in kurzer Zeit an verschiedenen Tischen.*

1. Betroffene Karten sofort **sperren** (Grund: Suspicious use).
2. Scan-Protokoll auswerten: welche Karten, welche Geräte, welche IP-Adressen, welche Uhrzeiten.
3. Prüfen, ob Kopierschutz aktiviert ist und die Karten an ihre Chip-Seriennummer gebunden sind. Nicht gebundene Karten (z. B. ohne Seriennummer als beschrieben markiert) nachträglich absichern: Ersatzkarte mit Bindung ausgeben.
4. Einlösungen, die nachweislich mit Kopien erfolgt sind, dokumentieren; das Guthaben rechtmäßiger Inhaberinnen und Inhaber per **„Replace lost card"** auf eine neue Karte übertragen.
5. Missbrauchsgrenzen senken (Einlösungen pro Stunde, maximaler Einzelbetrag).
6. Servicekräfte informieren: nur Android-Scan (mit Seriennummernprüfung) verwenden, rote Warnungen ernst nehmen.
7. Mittelfristig: für hohe Werte auf NTAG 424 DNA umstellen.
8. Bei Geldschaden: Anzeige durch das Lokal erwägen; GiftCard Pro stellt die Protokolle bereit.

### 7.4 Verdacht auf Datenschutzverletzung

*Anzeichen: unerklärlicher Export, Zugriff aus fremdem Lokal, Datenbankauszug im Umlauf, falsch versendete E-Mails.*

1. SEV-1 oder SEV-2 ausrufen, Zeitpunkt der Kenntnisnahme festhalten.
2. Eindämmen: Zugang schließen (Konto, Token, Server), Exportwege prüfen.
3. Umfang ermitteln: Welche Lokale (Verantwortliche)? Welche Kategorien von Daten (Name, E-Mail, Telefon, Notizen, Empfängernamen)? Wie viele betroffene Personen? Welcher Zeitraum?
4. Risikobewertung für die betroffenen Personen (z. B. Phishing-Risiko durch E-Mail-Adressen).
5. **Betroffene Lokale unverzüglich informieren** (Vorlage 9.2) – GiftCard Pro als Auftragsverarbeiter, Art. 33 Abs. 2 DSGVO.
6. Das Lokal entscheidet als Verantwortlicher über die Meldung an die Datenschutzbehörde (72 Stunden) und die Benachrichtigung der Gäste (Art. 34). GiftCard Pro liefert alle dafür nötigen Informationen.
7. Betrifft der Vorfall Daten, für die GiftCard Pro selbst Verantwortlicher ist (z. B. Vertrags- und Rechnungsdaten der Lokale), meldet GiftCard Pro selbst an die Datenschutzbehörde.
8. Alles dokumentieren (Art. 33 Abs. 5) – auch wenn keine Meldung erfolgt.

### 7.5 Veröffentlichtes oder weitergegebenes API-Token

*Anzeichen: Token in Code-Repository, Chat, E-Mail, Screenshot; „zuletzt verwendet" von unbekannter IP.*

1. **Settings → API → Revoke** – sofort, ohne Rückfrage. Tokens beginnen mit `gcp_`; das erleichtert die Suche in Repositories.
2. Audit-Log und Transaktionen der vom Token ausgelösten Aktionen prüfen (Token handelt als die erstellende Person, mit deren Kennung protokolliert).
3. Unberechtigte Buchungen stornieren, betroffene Karten sperren oder ersetzen.
4. Neues Token mit minimalen Berechtigungen und kurzer Laufzeit erstellen, sicher in der Zielanwendung hinterlegen.
5. Ursache beseitigen (z. B. Token aus Repository-Verlauf entfernen, Integrationspartner informieren).

### 7.6 Kompromittierung eines Plattform-Administrationskontos

*Schweregrad immer SEV-1 – dieses Konto kann in jedem Lokal handeln.*

1. Konto sofort serverseitig sperren: Status des Benutzers in der Datenbank auf inaktiv setzen (inaktive Benutzer werden bei der nächsten Anfrage abgewiesen), offene API-Tokens widerrufen, Sitzungen in Redis beenden. Für Plattform-Konten gibt es dafür derzeit keine eigene Oberfläche; die Schritte erfolgen über Server-Konsole bzw. Datenbank und werden in der Zeitlinie dokumentiert.
2. Plattform-Audit auswerten: Welche Lokale wurden über „Open restaurant" geöffnet? Welche Aktionen, Exporte, Einstellungen, Suspendierungen, Systemeinstellungen?
3. Passwörter aller weiteren Plattform-Administrationskonten erneuern; bei Bedarf ein neues Konto mit `php artisan platform:create-admin` anlegen.
4. Prüfen, ob neue Konten, Einladungen oder API-Tokens angelegt wurden; diese widerrufen.
5. Bei Verdacht auf weitergehenden Serverzugriff: Disaster-Recovery-Szenario 5.4 (Neuaufbau, alle Geheimnisse erneuern).
6. Alle betroffenen Lokale informieren; Datenschutzprüfung.

---

## 8. DSGVO: Meldung von Datenschutzverletzungen

| Konstellation | Wer meldet an die Datenschutzbehörde? | Frist | Rolle von GiftCard Pro |
|---|---|---|---|
| Gäste- und Kundendaten eines Lokals (GiftCard Pro = Auftragsverarbeiter) | **das Lokal** als Verantwortlicher (Art. 33 Abs. 1) | 72 Stunden ab Kenntnis des Verantwortlichen, außer die Verletzung führt voraussichtlich nicht zu einem Risiko | Meldung an das Lokal **unverzüglich** nach Bekanntwerden (Art. 33 Abs. 2), Unterstützung nach Art. 28 Abs. 3 lit. f |
| Eigene Kunden- und Vertragsdaten (GiftCard Pro = Verantwortlicher) | **GiftCard Pro** | 72 Stunden | selbst verantwortlich |
| Hohes Risiko für betroffene Personen | Benachrichtigung der Personen durch den Verantwortlichen (Art. 34) | unverzüglich | Unterstützung, Bereitstellung von Informationen |

- Zuständige Aufsichtsbehörde in Österreich: **Österreichische Datenschutzbehörde**, Barichgasse 40–42, 1030 Wien, [dsb.gv.at](https://www.dsb.gv.at).
- Internes Ziel für die Information der Lokale: **innerhalb von 24 Stunden** nach Bestätigung des Verdachts, bei Bedarf in Etappen (Art. 33 Abs. 4). Vertraglich maßgeblich ist der Auftragsverarbeitungsvertrag.
- Jede Datenschutzverletzung wird mit Fakten, Auswirkungen und Abhilfemaßnahmen dokumentiert (Art. 33 Abs. 5), auch wenn keine Meldung nötig ist.

---

## 9. Vorlagen

### 9.1 Erstinformation an ein Lokal (Sicherheitsvorfall)

> **Betreff: Sicherheitshinweis zu Ihrem GiftCard-Pro-Konto – [Datum]**
>
> Sehr geehrte/r [Name],
>
> am [Datum, Uhrzeit] haben wir [kurze, sachliche Beschreibung] festgestellt. Betroffen ist nach aktuellem Stand [Umfang].
>
> **Bereits umgesetzt:** [z. B. Token widerrufen, Gerät gesperrt].
> **Bitte veranlassen Sie:** [z. B. Passwörter zurücksetzen, Karten prüfen].
>
> Wir melden uns spätestens am [Datum, Uhrzeit] mit weiteren Informationen. Ansprechperson: [Name], security@giftcardpro.at, [Telefon].
>
> Mit freundlichen Grüßen
> [Name], GiftCard Pro

### 9.2 Meldung einer Datenschutzverletzung an ein Lokal (Art. 33 Abs. 2 DSGVO)

> **Betreff: Meldung einer Verletzung des Schutzes personenbezogener Daten gemäß Art. 33 Abs. 2 DSGVO**
>
> Sehr geehrte/r [Name],
>
> als Ihr Auftragsverarbeiter informieren wir Sie über eine Verletzung des Schutzes personenbezogener Daten, die Ihr Lokal [Name des Lokals] betrifft.
>
> 1. **Zeitpunkt:** Verletzung am/seit [Datum, Uhrzeit]; uns bekannt seit [Datum, Uhrzeit].
> 2. **Art der Verletzung:** [unbefugter Zugriff / Offenlegung / Verlust / Veränderung].
> 3. **Kategorien betroffener Personen:** [z. B. Gäste, die Gutscheinkarten gekauft haben; Empfängerinnen und Empfänger].
> 4. **Ungefähre Zahl betroffener Personen:** [Zahl]; **Datensätze:** [Zahl].
> 5. **Kategorien personenbezogener Daten:** [Name, E-Mail-Adresse, Telefonnummer, Notizen, Empfängername].
> 6. **Wahrscheinliche Folgen:** [z. B. Risiko von Phishing-E-Mails].
> 7. **Ergriffene Maßnahmen:** [Eindämmung, Behebung].
> 8. **Empfohlene Maßnahmen für Sie bzw. die Betroffenen:** [z. B. Gäste vor gefälschten E-Mails warnen].
> 9. **Kontakt:** [Name], datenschutz@giftcardpro.at, [Telefon].
>
> Als Verantwortlicher entscheiden Sie über die Meldung an die Österreichische Datenschutzbehörde (Frist: 72 Stunden nach Kenntnis) und über eine Benachrichtigung der betroffenen Personen. Wir stellen Ihnen alle weiteren Informationen zur Verfügung, sobald sie vorliegen.
>
> Mit freundlichen Grüßen
> [Name], GiftCard Pro

### 9.3 Vorlage für die Benachrichtigung von Gästen (für das Lokal)

> **Betreff: Wichtige Information zu Ihren Daten bei [Name des Lokals]**
>
> Sehr geehrte/r [Name],
>
> wir informieren Sie, dass am [Datum] [Beschreibung in klarer Sprache]. Betroffen sind folgende Daten: [Kategorien]. Ihr Gutscheinguthaben ist [nicht betroffen / wie folgt betroffen: …].
>
> Wir haben [Maßnahmen]. Wir empfehlen Ihnen: [z. B. Vorsicht bei E-Mails, die angeblich von uns stammen und nach Zahlungsdaten fragen].
>
> Fragen: [Kontakt des Lokals].
>
> Mit freundlichen Grüßen
> [Name des Lokals]

---

## 10. Vorlage: Bericht nach dem Vorfall

| Feld | Inhalt |
|---|---|
| Vorfallsnummer / Titel | |
| Schweregrad (anfänglich / final) | |
| Incident-Leitung, Beteiligte | |
| Zeitlinie | Erkennung, Eindämmung, Behebung, Abschluss (mit Uhrzeiten) |
| Zusammenfassung | 3–5 Sätze, verständlich für Lokale |
| Ursache (Root Cause) | |
| Auswirkung | betroffene Lokale, Karten, Personen, Geldbeträge, Ausfallzeit |
| Datenschutz | Datenschutzverletzung ja/nein, Begründung, Meldungen (wer, wann) |
| Was gut funktioniert hat | |
| Was nicht gut funktioniert hat | |
| Maßnahmen | Maßnahme · verantwortlich · Termin · Status |
| Neue Tests / Überwachung | |
| Aktualisierte Dokumente | |

Der Bericht wird innerhalb von 10 Werktagen nach Abschluss erstellt; eine verständliche Kurzfassung erhalten die betroffenen Lokale.

---

## 11. Meldungen von außen

Sicherheitslücken und Verdachtsfälle bitte an **security@giftcardpro.at**. Wir bestätigen den Eingang innerhalb von 2 Werktagen und halten Sie über den Stand informiert.

---

Version 1.0 · Stand: September 2026
