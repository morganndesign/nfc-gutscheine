# DSGVO-Leitfaden für GiftCard Pro

> **Muster/Vorlage — vor Verwendung durch eine in Österreich zugelassene Rechtsanwältin / einen Rechtsanwalt prüfen lassen.**
> Dieses Dokument ist keine Rechtsberatung. Es beschreibt den technischen Stand von GiftCard Pro und gibt eine Arbeitsgrundlage für die datenschutzrechtliche Prüfung. Stellen mit **[Prüfen: …]** bedürfen einer besonderen rechtlichen Prüfung. Platzhalter in eckigen Klammern sind vor Verwendung zu ersetzen.

*Zweck: Datenschutz-Leitfaden nach DSGVO und österreichischem DSG für den Anbieter von GiftCard Pro und für Restaurants, die GiftCard Pro nutzen — Rollen, Rechtsgrundlagen, Datenbestand, Betroffenenrechte, Verzeichnis, TOMs, Datenpannen und Checkliste.*

---

## 1. Überblick

GiftCard Pro ist eine Cloud-Plattform (SaaS), mit der Restaurants physische Gutscheinkarten mit NFC-Chip und QR-Code ausgeben, verkaufen, einlösen und verwalten. Die Karte selbst speichert weder Geld noch personenbezogene Daten: Chip und QR-Code enthalten nur einen Link der Form `https://<domain>/c/<zufällige UUID v4>`. Guthaben, Buchungsverlauf und Kundendaten liegen ausschließlich auf dem Server.

Rechtsrahmen:

- Datenschutz-Grundverordnung (DSGVO, Verordnung (EU) 2016/679)
- österreichisches Datenschutzgesetz (DSG), insbesondere § 6 DSG (Datengeheimnis)
- § 165 Abs 3 TKG 2021 (Cookies und Speicherung im Endgerät) — siehe [Cookie-Richtlinie](cookie-policy.md)
- Aufsichtsbehörde: Österreichische Datenschutzbehörde, Barichgasse 40–42, 1030 Wien, [www.dsb.gv.at](https://www.dsb.gv.at)

Weitere Dokumente dieses Pakets: [Auftragsverarbeitungsvertrag](data-processing-agreement.md), [Datenschutzerklärung](privacy-policy.md), [Cookie-Richtlinie](cookie-policy.md), [AGB](terms-of-service.md), [Rechtliche Hinweise für Restaurants](austrian-legal-notes.md).

## 2. Rollen: Wer ist wofür verantwortlich?

| Verarbeitung | Verantwortlicher (Art 4 Z 7 DSGVO) | Auftragsverarbeiter (Art 4 Z 8, Art 28 DSGVO) |
|---|---|---|
| Daten von Gästen/Kundinnen und Kunden des Restaurants (Käufer/in, Beschenkte/r, Kartendaten, Buchungen, Kunden-E-Mails) | **Restaurant** | **Anbieter** ([Firmenname]) |
| Daten der Mitarbeiterinnen und Mitarbeiter des Restaurants als Nutzer der Plattform (Name, E-Mail, Rolle, Login-IP, Geräte, Audit-Log) | **Restaurant** | **Anbieter** |
| Vertrags-, Rechnungs- und Kontaktdaten des Restaurants als Kunde des Anbieters (Ansprechperson, Rechnungsadresse, Zahlungsdaten, Support-Anfragen) | **Anbieter** | — (Unterauftragnehmer nur für eigene Zwecke des Anbieters) |
| Besucherinnen und Besucher der Website `giftcardpro.at`, Interessentinnen und Interessenten (Anfragen, Demo-Termine) | **Anbieter** | — |
| Plattformbetrieb, Sicherheit, Missbrauchsabwehr auf Infrastrukturebene (Server-Logs) | **Anbieter** [Prüfen: Abgrenzung eigene Zwecke vs. Auftrag] | — |

**Konsequenzen:**

- Das Restaurant entscheidet über Zweck und Mittel der Verarbeitung von Gästedaten (ob Kundendaten erfasst werden, welche, ob Kunden-E-Mails versendet werden, welche Gültigkeit Karten haben). Es muss seine Gäste informieren (Art 13 DSGVO), Betroffenenrechte erfüllen und ein Verzeichnis führen.
- Der Anbieter verarbeitet diese Daten nur auf dokumentierte Weisung des Restaurants. Grundlage ist der [Auftragsverarbeitungsvertrag (AVV)](data-processing-agreement.md), der Bestandteil der AGB ist.
- Für eigene Kunden-, Rechnungs- und Websitedaten ist der Anbieter selbst verantwortlich; dafür gilt die [Datenschutzerklärung](privacy-policy.md).

## 3. Rechtsgrundlagen

| Verarbeitung | Rechtsgrundlage | Hinweis |
|---|---|---|
| Ausgabe, Verwaltung und Einlösung einer Gutscheinkarte; Zuordnung zu einer Käuferin / einem Käufer | Art 6 Abs 1 lit b DSGVO (Vertrag über den Gutschein) | Kundendaten sind optional. Anonyme Karten sind möglich und datenschutzfreundlich. |
| Name der beschenkten Person (auf der Karte gedruckt) | Art 6 Abs 1 lit b DSGVO (Vertragserfüllung auf Wunsch der Käuferin / des Käufers) bzw. lit f | [Prüfen: Rechtsgrundlage gegenüber der beschenkten Person] |
| Transaktions-E-Mails an Gäste (Karte gekauft, aufgeladen, läuft bald ab, niedriges Guthaben) | Art 6 Abs 1 lit b DSGVO (Information zum Gutscheinvertrag); ergänzend lit f | Nur, wenn das Restaurant „Customer e-mails" aktiviert hat. Keine Werbung in diesen E-Mails. [Prüfen: Einordnung der Ablauf-Erinnerung] |
| Aufbewahrung des Buchungsjournals (Verkauf, Einlösung, Aufladung, Storno) | Art 6 Abs 1 lit c DSGVO iVm § 132 BAO (7 Jahre) | Buchungen werden bei Anonymisierung eines Kunden nicht gelöscht. |
| Sicherheitsprotokolle (Audit-Log, NFC-Scan-Protokoll, Geräte, Login-IP) | Art 6 Abs 1 lit f DSGVO (berechtigtes Interesse: Betrugs- und Missbrauchsabwehr, Nachvollziehbarkeit von Geldbewegungen) | Interessenabwägung dokumentieren (siehe 3.1). |
| Nutzerkonten der Mitarbeiterinnen und Mitarbeiter | Art 6 Abs 1 lit b DSGVO (Arbeitsvertrag) bzw. lit f; Arbeitsverfassungsrecht beachten (§§ 96, 96a ArbVG) | [Prüfen: Betriebsvereinbarung bei Kontrollmaßnahmen bzw. Personaldatensystemen, falls Betriebsrat vorhanden] |
| E-Mail-Werbung an Gäste (Newsletter, Aktionen) | **Einwilligung**, Art 6 Abs 1 lit a DSGVO und § 174 TKG 2021 | GiftCard Pro versendet keine Werbung. Das Feld **Marketing consent** dokumentiert nur, ob eine Einwilligung vorliegt. [Prüfen: Paragraph TKG 2021] |
| Eigene Kunden- und Rechnungsdaten des Anbieters | Art 6 Abs 1 lit b und c DSGVO | Siehe [Datenschutzerklärung](privacy-policy.md). |

### 3.1 Interessenabwägung für Sicherheitsprotokolle (Kurzfassung)

- **Interesse:** Eine Gutscheinkarte ist Geld. Das Restaurant muss nachvollziehen können, wer wann auf welchem Gerät welchen Betrag gebucht hat, und Betrug (geklonte Karten, wiederholte Scans, Kontoübernahmen) erkennen können.
- **Erforderlichkeit:** Protokolliert werden nur technische Kennzeichen (Benutzer, Gerät, IP-Adresse, User-Agent, Zeitpunkt, Aktion). Namen, E-Mail-Adressen, Telefonnummern, Notizen und Empfängernamen von Gästen werden **nicht** in das Audit-Log kopiert — nur die Tatsache, dass sie geändert wurden. Passwörter und Tokens werden geschwärzt.
- **Erwartung der Betroffenen:** Mitarbeiterinnen und Mitarbeiter, die mit Geldwerten arbeiten, müssen mit einer Protokollierung rechnen; sie sind darüber zu informieren.
- **Ergebnis:** Überwiegendes berechtigtes Interesse, sofern Speicherdauer begrenzt und Zugriff auf Inhaber/in und Manager beschränkt ist. [Prüfen: Speicherdauer, siehe Abschnitt 4]

## 4. Datenbestand (Dateninventar)

Die folgende Tabelle beschreibt die in GiftCard Pro tatsächlich gespeicherten Datenkategorien.

| Kategorie | Datenfelder | Betroffene | Zweck | Rechtsgrundlage | Speicherdauer |
|---|---|---|---|---|---|
| Kundendaten (optional) | Vorname, Nachname, E-Mail, Telefon, Notizen, Marketing-Einwilligung (ja/nein) | Gäste (Käufer/innen) | Zuordnung von Karten, Service bei Verlust, Transaktions-E-Mails | Art 6 Abs 1 lit b; Marketing: lit a | Bis zur Anonymisierung durch das Restaurant bzw. Vertragsende + 30 Tage; [Prüfen: Löschkonzept des Restaurants, z. B. X Jahre nach letzter Kartennutzung] |
| Kartendaten | Kartennummer, Token (UUID), Status, Guthaben, Gültigkeit, Empfängername, interne Notizen, Chip-Seriennummer, Chip-Zähler | Gäste (Käufer/in, beschenkte Person) | Gutscheinverwaltung, Fälschungsschutz | Art 6 Abs 1 lit b, f | Empfängername und Notizen: bis Anonymisierung; Kartendaten ohne Personenbezug: wie Buchungsjournal |
| Buchungsjournal (Transaktionen) | Typ, Betrag, Saldo vorher/nachher, Zeitpunkt, Benutzer, Gerät, IP-Adresse, Referenz, Notiz | Gäste (indirekt), Mitarbeitende | Nachweis aller Geldbewegungen, Buchhaltung | Art 6 Abs 1 lit c (§ 132 BAO), lit f | 7 Jahre (BAO); unveränderlich; Löschung beim Anbieter 30 Tage nach Vertragsende — das Restaurant muss vorher exportieren |
| Nutzerkonten (Personal) | Name, E-Mail, Rolle, Status, Sprache, letzter Login (Zeit, IP), Passwort (bcrypt-Hash), fehlgeschlagene Logins | Mitarbeitende des Restaurants | Zugang, Berechtigungen, Kontoschutz | Art 6 Abs 1 lit b, f | Während des Vertrags; deaktivierte Konten bleiben zur Nachvollziehbarkeit erhalten [Prüfen: Frist] |
| Geräte | Name, Typ, Plattform/User-Agent, Geräte-Fingerabdruck (Hash einer zufälligen Geräte-ID), letzte IP, zuletzt gesehen, zuletzt angemeldeter Benutzer | Mitarbeitende | Gerätebindung, Sperre verlorener Geräte | Art 6 Abs 1 lit f | Während des Vertrags [Prüfen: Frist für widerrufene Geräte] |
| Audit-Log | Aktion, Benutzer, Gerät, alte/neue Werte (ohne Gästedaten, Geheimnisse geschwärzt), IP-Adresse, User-Agent, Request-ID, Zeitpunkt | Mitarbeitende, indirekt Gäste | Sicherheit, Nachvollziehbarkeit | Art 6 Abs 1 lit f | Derzeit unbefristet während des Vertrags (append-only) [Prüfen: Höchstfrist festlegen, z. B. 7 Jahre für geldrelevante, kürzer für sonstige Einträge] |
| NFC-Scan-Protokoll | Karte (falls gefunden), Benutzer, Gerät, Methode, Ergebnis, Chip-UID, Zähler, IP-Adresse, User-Agent | Mitarbeitende (Scans in der Servicekraft-App; die öffentliche Guthabenabfrage durch Gäste wird hier nicht protokolliert) | Betrugserkennung (Klone, Replays, Ratenbegrenzung) | Art 6 Abs 1 lit f | Derzeit unbefristet während des Vertrags [Prüfen: Frist, z. B. 12 Monate] |
| E-Mail-Versandprotokoll | Vorlage, Empfängeradresse, Status, Zeitpunkt | Gäste, Mitarbeitende | Zustellnachweis | Art 6 Abs 1 lit f | E-Mail-Adresse wird bei Anonymisierung entfernt [Prüfen: Frist] |
| API-Tokens | Name, Hash, Berechtigungen, zuletzt verwendet (Zeit, IP) | Mitarbeitende | Integrationen (z. B. Kassensystem) | Art 6 Abs 1 lit b, f | Max. 365 Tage gültig; widerrufene Tokens bleiben protokolliert |
| Sitzungen | Sitzungs-ID, Benutzer, Gerät | Mitarbeitende | Anmeldung | Art 6 Abs 1 lit b | 8 Stunden Inaktivität |
| Backups | Vollständige Datenbank | alle oben | Wiederherstellung | Art 6 Abs 1 lit f, Art 32 | Rollierend ca. 14 Tage (lokal und extern bei Hetzner) + tägliche Server-Snapshots |
| Webserver-Protokolle | IP-Adresse, Zeitpunkt, URL, User-Agent, Statuscode | alle Aufrufenden | Betrieb, Angriffserkennung | Art 6 Abs 1 lit f | [Prüfen: Frist festlegen, z. B. 14 Tage] |

**Keine besonderen Kategorien** (Art 9 DSGVO) sind vorgesehen. Restaurants sollten in Freitextfeldern (**Internal notes**, Kundennotizen) keine Gesundheitsdaten (z. B. Allergien), keine Zahlungskartendaten und keine sonstigen sensiblen Angaben speichern.

**Datenminimierung im Produkt:** Kundendaten sind optional (**Anonymous** ist wählbar), die Karte trägt keine personenbezogenen Daten, die öffentliche Guthabenseite zeigt nur Guthaben, Status, Gültigkeit und eine maskierte Kartennummer und kann abgeschaltet werden.

> **Hinweis zur Speicherbegrenzung (Art 5 Abs 1 lit e DSGVO):** GiftCard Pro löscht aus Integritätsgründen keine Datensätze im laufenden Betrieb (Soft Deletes, unveränderliches Journal und Audit-Log). Personenbezogene Gästedaten können jederzeit durch Anonymisierung entfernt werden. Für Audit-Log, NFC-Scan-Protokoll und E-Mail-Protokoll ist eine automatische Bereinigung nach festgelegten Fristen vorzusehen. [Prüfen: Fristen festlegen; technische Umsetzung auf der Roadmap des Anbieters]

## 5. Betroffenenrechte und ihre Erfüllung im Produkt

Anfragen von Gästen richten sich an das Restaurant (Verantwortlicher). Der Anbieter unterstützt nach Art 28 Abs 3 lit e DSGVO. Frist: grundsätzlich **ein Monat** ab Eingang (Art 12 Abs 3 DSGVO), Verlängerung um zwei Monate bei Komplexität mit Begründung.

| Recht | Artikel | So erfüllen Sie es in GiftCard Pro |
|---|---|---|
| Auskunft | Art 15 | **Customers** → Kunde öffnen → Stammdaten und zugeordnete Karten ansehen. Kartenverlauf auf der jeweiligen Kartenseite. Für eine Kopie: **Gift cards** bzw. **Transactions** nach Kunde/Kartennummer filtern und **Export CSV**. Ergänzend angeben: Zwecke, Empfänger (Anbieter als Auftragsverarbeiter, Hetzner), Speicherdauer, Rechte. |
| Berichtigung | Art 16 | **Customers** → Kunde → bearbeiten; Empfängername auf der Karte über **⋯ → Edit details**. |
| Löschung | Art 17 | **Customers** → Kunde → **Anonymize** (DSGVO-Anonymisierung). Entfernt Name, E-Mail, Telefon, Notizen des Kunden und Empfängernamen auf seinen Karten; E-Mail-Adressen im Versandprotokoll werden ebenfalls entfernt. **Buchungen bleiben** — Aufbewahrungspflicht nach § 132 BAO (Art 17 Abs 3 lit b DSGVO). Guthaben bleibt auf der Karte nutzbar. |
| Einschränkung | Art 18 | Kundendaten nicht weiter verwenden, Karte ggf. mit Begründung sperren (**Block card**) oder Vermerk in Notizen; bei Bedarf Anbieter kontaktieren. |
| Datenübertragbarkeit | Art 20 | CSV-Export (strukturiert, maschinenlesbar). |
| Widerspruch | Art 21 | Bei Verarbeitungen auf Basis lit f prüfen; E-Mails an diesen Gast deaktivieren (Kundendaten entfernen oder anonymisieren). Widerspruch gegen Werbung: **Marketing consent** deaktivieren — immer zu beachten. |
| Widerruf der Einwilligung | Art 7 Abs 3 | **Marketing consent** deaktivieren; Datum des Widerrufs dokumentieren. |
| Mitarbeitende | Art 15–21 | **Team** → Person bearbeiten/deaktivieren; Auskunft über Login-Daten und Audit-Einträge über **Audit log** (Filter nach Person) — bei Bedarf Unterstützung durch den Support. |

**Identitätsprüfung:** Auskunft nur an nachweislich berechtigte Personen erteilen (z. B. Rückbestätigung an die gespeicherte E-Mail-Adresse). Kartennummer allein ist kein Identitätsnachweis.

**Dokumentation:** Jede Anfrage mit Datum, Inhalt, Antwort und Antwortdatum festhalten.

## 6. Datenschutz-Folgenabschätzung (DSFA, Art 35 DSGVO)

**Einschätzung: Eine DSFA ist voraussichtlich nicht erforderlich.** [Prüfen: im Einzelfall bestätigen]

Begründung:

- Keine besonderen Kategorien personenbezogener Daten (Art 9, 10 DSGVO).
- Kein Profiling, keine automatisierte Entscheidung mit Rechtswirkung, kein Scoring, keine Werbeanalyse.
- Keine systematische Überwachung öffentlich zugänglicher Bereiche; keine Standortdaten.
- Datenmenge je Restaurant gering; Kundendaten optional.
- Die Protokollierung von Mitarbeitenden dient der Nachvollziehbarkeit von Geldbuchungen und ist auf Buchungs- und Sicherheitsereignisse beschränkt; sie ist keine Leistungs- oder Verhaltenskontrolle.
- Die Kriterien der österreichischen DSFA-Verordnung (Liste der Verarbeitungen, für die eine DSFA durchzuführen ist) und der DSFA-Ausnahmenverordnung sind im Einzelfall abzugleichen. [Prüfen: aktuelle Fassung]

Eine DSFA wird empfohlen, wenn ein Restaurant GiftCard Pro mit umfangreichen Kundenprofilen, Marketing-Auswertungen oder einer Verknüpfung mit anderen Systemen (z. B. Kundenbindungsprogramm) kombiniert.

## 7. Verzeichnis von Verarbeitungstätigkeiten (Art 30 DSGVO) — Vorlage

### 7.1 Für das Restaurant (Verantwortlicher)

| Feld | Eintrag |
|---|---|
| Verantwortlicher | [Name des Restaurants / Rechtsträger], [Anschrift], [E-Mail], [Telefon] |
| Vertreter / Datenschutzbeauftragte/r | [falls bestellt; sonst „nicht bestellt"] |
| Bezeichnung der Verarbeitung | Verwaltung von Gutscheinkarten (GiftCard Pro) |
| Zwecke | Verkauf, Ausgabe, Einlösung und Verwaltung von Gutscheinkarten; Kundenservice (Verlust, Ersatz); Transaktions-E-Mails; Betrugsabwehr; Buchhaltung |
| Kategorien betroffener Personen | Gäste (Käufer/innen, Beschenkte), Mitarbeitende |
| Kategorien personenbezogener Daten | Gäste: Name, E-Mail, Telefon, Notizen, Marketing-Einwilligung, Empfängername, Kartendaten, Buchungen. Mitarbeitende: Name, E-Mail, Rolle, Login-Zeit/IP, Geräte, Audit-Einträge |
| Rechtsgrundlagen | Art 6 Abs 1 lit b, c, f DSGVO; Marketing: lit a |
| Empfänger | [Firmenname] (Auftragsverarbeiter, GiftCard Pro); Unterauftragsverarbeiter lt. AVV Anlage 3; Steuerberatung [Name]; Behörden bei gesetzlicher Pflicht |
| Drittlandübermittlung | Keine [Prüfen: E-Mail-Versanddienstleister] |
| Löschfristen | Buchungen 7 Jahre (§ 132 BAO); Kundendaten [z. B. 3 Jahre nach letzter Kartennutzung bzw. auf Anfrage]; Sicherheitsprotokolle [Frist] |
| TOMs | Verweis auf AVV Anlage 2 und eigene Maßnahmen im Restaurant (Geräteschutz, Kontenverwaltung) |

### 7.2 Für den Anbieter als Auftragsverarbeiter (Art 30 Abs 2)

| Feld | Eintrag |
|---|---|
| Auftragsverarbeiter | [Firmenname], [Rechtsform], [Anschrift], 1xxx Wien, datenschutz@giftcardpro.at |
| Verantwortliche | Alle Restaurants mit aktivem Vertrag (Kundenliste: [intern geführt, Speicherort]) |
| Kategorien von Verarbeitungen | Hosting und Betrieb von GiftCard Pro; Speicherung und Verarbeitung von Gutschein-, Kunden- und Nutzerdaten; Versand von Transaktions-E-Mails; Backups; Support |
| Drittlandübermittlung | Keine [Prüfen: E-Mail-Versanddienstleister] |
| TOMs | AVV Anlage 2 |

### 7.3 Für den Anbieter als Verantwortlicher

Eigene Einträge für: Kunden- und Vertragsverwaltung, Rechnungslegung, Support, Website und Kontaktanfragen, Interessentenverwaltung, Personalverwaltung (eigene Mitarbeitende). Inhalte siehe [Datenschutzerklärung](privacy-policy.md).

## 8. Technische und organisatorische Maßnahmen (Zusammenfassung)

Die vollständige Liste steht in Anlage 2 des [AVV](data-processing-agreement.md).

- **Mandantentrennung:** Jedes Restaurant sieht ausschließlich seine eigenen Daten; auf mehreren Ebenen technisch erzwungen und automatisiert getestet.
- **Keine Werte auf der Karte:** nur ein zufälliger 122-Bit-Link; Kartennummern zufällig, nicht fortlaufend.
- **Integrität von Geldbuchungen:** atomar mit Datenbanksperre, idempotent (keine Doppelbuchungen), unveränderliches Journal; Stornos als Gegenbuchung.
- **Zugangsschutz:** Passwörter mindestens 12 Zeichen mit Groß-, Kleinbuchstaben und Ziffer, bcrypt-Hashing; Ratenbegrenzung; Kontosperre nach 10 Fehlversuchen für 15 Minuten; Einladungslinks (72 h) statt Passwortversand; Passwort-Reset-Link 60 Minuten gültig.
- **Rollen und Rechte:** Inhaber/in, Manager, Servicekraft; Servicekräfte können nur scannen und einlösen (und ggf. sperren).
- **Geräte- und Sitzungsbindung:** Sitzungen an das Gerät gebunden, widerrufene Geräte sofort gesperrt, Sitzungsende nach 8 Stunden Inaktivität.
- **Fälschungsschutz:** Bindung an die Chip-Seriennummer (NTAG21x), kryptografische Signatur und Zähler (NTAG 424 DNA).
- **Transport und Anwendung:** ausschließlich HTTPS (TLS, HSTS), Sicherheits-Header, Content-Security-Policy, CSRF-Schutz, kein Cross-Origin-Zugriff, keine Tracking-Cookies.
- **Protokollierung:** unveränderliches Audit-Log mit Person, Gerät, IP und Zeit; Gästedaten und Geheimnisse werden nicht protokolliert.
- **Verfügbarkeit:** Hosting bei Hetzner in Deutschland; nächtliche Datenbank-Backups (14 Tage) plus externe Kopie; tägliche Server-Snapshots; Health-Check.
- **Organisatorisch:** Verpflichtung auf das Datengeheimnis (§ 6 DSG), Zugriff des Anbieters auf Restaurantdaten nur im Support-Fall über die Funktion „Open restaurant" mit Hinweisbanner und vollständiger Protokollierung.

## 9. Internationale Datenübermittlungen

- Standard: **keine Übermittlung in Drittländer**. Hosting und Backups erfolgen bei der Hetzner Online GmbH in Rechenzentren in Deutschland.
- **E-Mail-Versand:** Der eingesetzte E-Mail-Versanddienstleister ([E-Mail-Versanddienstleister mit EU-Hosting]) ist vor Vertragsschluss zu prüfen: Serverstandort, Konzernmutter in einem Drittland, Zugriff aus Drittländern (Support, Wartung), Unterauftragnehmer. Bei Drittlandbezug sind Angemessenheitsbeschluss (z. B. EU-US Data Privacy Framework, Zertifizierung prüfen) oder Standardvertragsklauseln samt Transfer-Folgenabschätzung erforderlich. [Prüfen]
- **Zahlungsdienstleister** (falls eingesetzt, z. B. Stripe Payments Europe Ltd.): verarbeitet nur Abrechnungsdaten des Anbieters, nicht die Gästedaten der Restaurants. Drittlandbezug im Konzern prüfen. [Prüfen]

## 10. Verletzung des Schutzes personenbezogener Daten (Datenpanne)

### 10.1 Pflichten

- **Restaurant (Verantwortlicher):** Meldung an die Datenschutzbehörde **binnen 72 Stunden** ab Kenntnis, sofern ein Risiko für Betroffene nicht unwahrscheinlich ist (Art 33 DSGVO). Benachrichtigung der Betroffenen bei voraussichtlich hohem Risiko (Art 34 DSGVO). Dokumentation jeder Panne, auch wenn keine Meldung erfolgt (Art 33 Abs 5).
- **Anbieter (Auftragsverarbeiter):** Meldung an das Restaurant **unverzüglich**, Zielwert **spätestens 48 Stunden** nach Kenntnis (Art 33 Abs 2 DSGVO; siehe AVV § 9), mit allen verfügbaren Informationen; Nachreichung zulässig.
- **Anbieter als Verantwortlicher** (eigene Kundendaten): eigene Meldung nach Art 33/34.

### 10.2 Ablauf beim Anbieter

1. **Erkennen und melden:** Jede Beobachtung an security@giftcardpro.at. Sicherheitswarnungen im Audit-Log (geklonte Karte, kopierter NFC-Scan, fremde Karte, gesperrtes Konto) und Anwendungs-Logs werden überwacht.
2. **Eindämmen:** betroffene Konten, Tokens oder Geräte sperren; Zugangsdaten rotieren; Lücke schließen.
3. **Bewerten:** Welche Daten, welche Restaurants, wie viele Betroffene, welches Risiko?
4. **Informieren:** betroffene Restaurants mit Art, Kategorien und ungefährer Zahl der Betroffenen, wahrscheinlichen Folgen und ergriffenen Maßnahmen; Ansprechperson benennen.
5. **Unterstützen:** Vorlagen und Informationen für die Meldung des Restaurants an die Datenschutzbehörde und ggf. an Betroffene.
6. **Dokumentieren und nachbereiten:** Pannenprotokoll, Ursachenanalyse, Maßnahmen.

### 10.3 Ablauf im Restaurant

- Verlorenes oder gestohlenes Handy: in **Devices** sofort **Revoke**; Konto der Person prüfen, ggf. Passwort zurücksetzen.
- Verdacht auf fremden Zugriff: Person unter **Team** deaktivieren, **Audit log** prüfen, Anbieter informieren.
- Datenpanne mit Gästedaten: binnen 72 Stunden bewerten und ggf. melden (Formular auf [dsb.gv.at](https://www.dsb.gv.at)).

## 11. Checkliste für Restaurants

- [ ] AGB und AVV mit dem Anbieter akzeptiert und abgelegt.
- [ ] Verzeichnis von Verarbeitungstätigkeiten um „Gutscheinkarten (GiftCard Pro)" ergänzt (Vorlage Abschnitt 7.1).
- [ ] Datenschutzhinweis für Gäste an der Kassa bzw. auf der Website ergänzt (Textbausteine unten).
- [ ] Kundendaten nur erfassen, wenn nötig; sonst **Anonymous** wählen.
- [ ] **Marketing consent** nur aktivieren, wenn eine nachweisbare Einwilligung vorliegt (Datum, Wortlaut, Form).
- [ ] Keine Gesundheits-, Zahlungskarten- oder sonstigen sensiblen Daten in Notizfeldern.
- [ ] Rollen sparsam vergeben; Servicekräfte erhalten die Rolle **Waiter**.
- [ ] Mitarbeitende über Protokollierung (Logins, Geräte, Buchungen) informiert; ggf. Betriebsrat eingebunden.
- [ ] Mitarbeitende auf das Datengeheimnis (§ 6 DSG) verpflichtet.
- [ ] Diensthandys mit Bildschirmsperre; verlorene Geräte sofort unter **Devices** widerrufen.
- [ ] Ausgeschiedene Mitarbeitende am letzten Arbeitstag unter **Team** deaktivieren.
- [ ] Ablauf für Auskunfts- und Löschanfragen festgelegt (zuständige Person, Monatsfrist).
- [ ] Löschkonzept für Kundendaten festgelegt (z. B. Anonymisierung X Jahre nach letzter Kartennutzung).
- [ ] Vor Vertragsende Daten exportieren (**Export CSV**) — Aufbewahrung 7 Jahre liegt beim Restaurant.

### 11.1 Aushang / Info-Text für Gäste an der Kassa (Kurzfassung)

> **Datenschutz bei Gutscheinkarten**
> Wenn Sie beim Kauf einer Gutscheinkarte Ihren Namen, Ihre E-Mail-Adresse oder Telefonnummer angeben, verarbeiten wir diese Daten, um die Karte Ihnen zuzuordnen, Ihnen Informationen zur Karte zu senden und Ihnen bei Verlust zu helfen (Art 6 Abs 1 lit b DSGVO). Die Angabe ist freiwillig — Karten sind auch ohne Namen erhältlich. Buchungen auf der Karte bewahren wir aus steuerlichen Gründen 7 Jahre auf. Wir nutzen dafür den Dienst GiftCard Pro ([Firmenname], Wien) mit Servern in Deutschland. Werbung per E-Mail erhalten Sie nur mit Ihrer ausdrücklichen Einwilligung. Verantwortlich: [Restaurant, Anschrift, E-Mail]. Mehr unter [Link zur Datenschutzerklärung] oder auf Nachfrage.

### 11.2 Baustein für die Datenschutzerklärung der Restaurant-Website

> **Gutscheinkarten**
> Wir bieten Gutscheinkarten mit NFC-Chip und QR-Code an. Auf der Karte selbst sind weder Guthaben noch personenbezogene Daten gespeichert, sondern nur ein zufälliger Link zu unserem Gutscheinsystem.
>
> *Welche Daten:* Kartennummer, Guthaben, Gültigkeit, Buchungen (Kauf, Einlösung, Aufladung); freiwillig: Vor- und Nachname, E-Mail-Adresse, Telefonnummer der Käuferin / des Käufers, Name der beschenkten Person, Ihre Einwilligung zu Werbe-E-Mails (ja/nein).
>
> *Zwecke und Rechtsgrundlagen:* Ausgabe und Einlösung des Gutscheins und Service bei Verlust (Art 6 Abs 1 lit b DSGVO); Informations-E-Mails zu Ihrer Karte (z. B. Kaufbestätigung, Hinweis vor Ablauf, niedriges Guthaben) (Art 6 Abs 1 lit b DSGVO); Aufbewahrung der Buchungen aufgrund steuerrechtlicher Pflichten (Art 6 Abs 1 lit c DSGVO iVm § 132 BAO); Schutz vor Missbrauch und Betrug (Art 6 Abs 1 lit f DSGVO); Werbe-E-Mails nur mit Einwilligung (Art 6 Abs 1 lit a DSGVO), jederzeit widerrufbar.
>
> *Guthabenabfrage:* Wenn Sie Ihre Karte mit Ihrem Smartphone scannen, sehen Sie Guthaben, Status und Gültigkeit. Dabei werden technisch notwendige Daten (IP-Adresse, Browsertyp, Zeitpunkt) kurzfristig in Server-Protokollen verarbeitet, um den Dienst bereitzustellen und vor Missbrauch zu schützen (Art 6 Abs 1 lit f DSGVO).
>
> *Empfänger:* [Firmenname], [Anschrift], Wien, als unser Auftragsverarbeiter (Betreiber von GiftCard Pro); Hosting bei Hetzner Online GmbH in Deutschland; [E-Mail-Versanddienstleister] für den Versand von E-Mails; unsere Steuerberatung. Eine Übermittlung in Länder außerhalb der EU findet nicht statt. [Prüfen]
>
> *Speicherdauer:* Buchungen 7 Jahre; Ihre Kontaktdaten bis zu Ihrem Löschwunsch bzw. [X Jahre] nach der letzten Nutzung der Karte. Bei Löschung werden Ihre Daten anonymisiert; das Guthaben bleibt erhalten.
>
> *Ihre Rechte:* Auskunft, Berichtigung, Löschung, Einschränkung, Datenübertragbarkeit, Widerspruch, Widerruf einer Einwilligung sowie Beschwerde bei der Österreichischen Datenschutzbehörde (Barichgasse 40–42, 1030 Wien, www.dsb.gv.at). Kontakt: [E-Mail des Restaurants].

---

Version 1.0 · Stand: September 2026
