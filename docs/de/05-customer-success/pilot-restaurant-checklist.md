# Pilotprogramm – Checkliste für Pilotlokale

*Checkliste aus Sicht von Customer Success für das Pilotprogramm (Oktober–November 2026, 5–10 Lokale in Wien): Auswahl, Vereinbarung, Kickoff, erste Woche, Erfolgskennzahlen, Feedback-Interview, Kriterien für den allgemeinen Marktstart und Referenzfreigabe. Technische Go-live-Punkte stehen im englischen Dokument PILOT_CHECKLIST.md.*

---

## 1. Ziele des Pilotprogramms

1. Nachweisen, dass Einlösen am Tisch im Alltag **unter 5 Sekunden** dauert (inklusive Mensch).
2. Nachweisen, dass Servicekräfte **ohne lange Schulung** zurechtkommen (Modul A: 15 Minuten).
3. Fehler, Missverständnisse und fehlende Funktionen vor dem Marktstart im **November 2026** finden – rechtzeitig vor Advent und Weihnachten.
4. Die Planungsannahmen (Preise, Kartenmengen, Supportaufwand) überprüfen.
5. Mit Zustimmung der Lokale erste Referenzen gewinnen.

## 2. Auswahlkriterien für Pilotlokale

**Muss-Kriterien**
- [ ] Lokal in Wien, für Vor-Ort-Termine erreichbar.
- [ ] Inhaberin oder Inhaber entscheidet selbst und nimmt an Kickoff und Abschlussgespräch teil.
- [ ] Gutscheine werden heute schon verkauft (Papier, Kassa-Funktion oder anderes System) oder sind für die Weihnachtssaison fest geplant.
- [ ] Mindestens ein Android-Handy mit NFC und Chrome für das Beschreiben der Karten verfügbar (oder wird bereitgestellt); stabiles WLAN im Gastraum.
- [ ] Registrierkasse vorhanden und Steuerberatung erreichbar (für die Gutscheinbuchung in der Kassa).
- [ ] Bereitschaft zu Feedbackgesprächen (siehe Abschnitt 3).

**Soll-Kriterien (für eine ausgewogene Gruppe)**
- [ ] Mischung der Betriebsarten: Restaurant, Gasthaus/Beisl, Kaffeehaus, Bar; möglichst ein Betrieb mit hohem Gutscheinvolumen.
- [ ] Mischung der Geräte: Android und iPhone im Service.
- [ ] Mindestens ein Lokal mit mehrsprachigem Team (Deutsch/BHS/Englisch), da die Mitarbeiter-Oberfläche derzeit englisch ist.
- [ ] Mindestens ein Lokal mit Interesse an NTAG 424 DNA (Klonschutz, Tarif Pro).
- [ ] Mindestens ein Lokal, das Kunden-E-Mails nutzen möchte.

**Ausschlusskriterien für den Pilot**
- Mehrere Standorte, die ein gemeinsames Dashboard erwarten (gibt es noch nicht; jeder Standort ist ein eigenes Konto).
- Bedarf an Online-Gutscheinverkauf oder Zahlungsabwicklung (nicht Teil des Produkts; Fahrplan Q1 2027).
- Erwartung einer direkten Kassenanbindung ab Tag 1.

## 3. Pilotvereinbarung – Eckpunkte

| Punkt | Inhalt |
|---|---|
| Teilnehmende | die ersten 10 Lokale in Wien, Oktober–November 2026 |
| Leistung Anbieter | **3 Monate kostenlos**, danach **12 Monate 50 % Rabatt** (Start € 14,50 / Pro € 29,50 pro Monat, netto zzgl. 20 % USt); **kostenlose Einrichtung vor Ort** inkl. Schulung (sonst € 149); **50 kostenlose Karten** |
| Leistung Lokal | Feedbackgespräche (Kickoff, Woche 1, Woche 4, Abschluss), Teilnahme an kurzen Umfragen, Meldung von Fehlern; **Nennung als Referenz nur nach ausdrücklicher Freigabe** |
| Tarifwahl | Start oder Pro; Wechsel jederzeit |
| Laufzeit & Kündigung | B2B-Vertrag; monatlich kündbar zum Monatsende; nach Ende des Rabattzeitraums regulärer Preis |
| Daten | Datenexport jederzeit; Löschung 30 Tage nach Vertragsende (ausgenommen gesetzliche Aufbewahrung); Auftragsverarbeitungsvertrag wird abgeschlossen |
| Verfügbarkeit | Zielwert 99,5 % pro Monat, keine Garantie |
| Support | wie Pro (4 Arbeitsstunden), zusätzlich tägliche Check-ins in Woche 1 |

*Die Vereinbarung ist eine Vorlage – vor Verwendung durch eine in Österreich zugelassene Rechtsanwältin bzw. einen Rechtsanwalt prüfen lassen.*

## 4. Vor dem Kickoff (Customer Success)

- [ ] Pilotvereinbarung und Auftragsverarbeitungsvertrag unterschrieben.
- [ ] Technische Checkliste Abschnitt A (PILOT_CHECKLIST.md) erledigt: Server, Domain, E-Mail-Versand, Backups, Monitoring.
- [ ] Restaurant in der Plattformverwaltung angelegt (**Onboard restaurant**), Einladung an Inhaberin/Inhaber verschickt und angenommen.
- [ ] Kartendesign abgestimmt, 50 Pilotkarten (NTAG215) bestellt; Testkarten pro Handymodell vorhanden.
- [ ] Kickoff-Termin (60–90 Minuten, außerhalb der Servicezeit) vereinbart; Teilnehmende: Inhaber/in, Manager, 1–3 Servicekräfte.
- [ ] Steuerberatung des Lokals über Buchung von Gutscheinen in der Registrierkasse informiert (Lokal klärt, wir stellen Info bereit).
- [ ] Ansprechpartner im Lokal und Erreichbarkeit (Telefon, bevorzugte Uhrzeit) im CRM notiert.

## 5. Kickoff vor Ort (Tag 0)

1. [ ] Ziele und Ablauf des Pilots erklären; Erwartungen klären (was das Produkt kann und was nicht: keine Registrierkasse, kein Online-Shop, Mitarbeiter-Oberfläche englisch).
2. [ ] **Welcome-Panel** gemeinsam durcharbeiten:
   - [ ] **Card rules:** **„Default validity (months)"** = 0 (Rechtshinweis besprechen, Werkseinstellung 36 Monate ändern), Mindest-/Höchstwert, Aufladen, Teileinlösung.
   - [ ] **Restaurant profile:** Firmenname, UID-Nummer, Adresse, **Deutsch (Österreich)**, Zeitzone Europe/Vienna.
   - [ ] Markenfarbe, E-Mail-Fußzeile, Kunden-E-Mails ein/aus.
   - [ ] **Team** einladen – jede Person mit eigener E-Mail.
3. [ ] Testkarte € 5 verkaufen, mit Android beschreiben, Guthabenseite auf iPhone und Android prüfen.
4. [ ] Auf **jedem Diensthandy**: anmelden, Web-App am Startbildschirm installieren, Testkarte scannen, € 1 einlösen, **„Next card"**; Gerät unter **Devices** umbenennen.
5. [ ] Schulung Modul A (Servicekräfte), Modul B (Manager), Modul C (Inhaber) – siehe Schulungsleitfaden.
6. [ ] Gemeinsam: Test-Einlösung stornieren, Testkarte sperren, ersetzen.
7. [ ] Kurzanleitung an der Kassa platzieren.
8. [ ] Gutscheinbuchung in der Registrierkasse durchspielen (Verkauf und Einlösung).
9. [ ] Ausgangswerte erheben (Abschnitt 7: Baseline).
10. [ ] Nächste Termine fixieren: tägliche Check-ins Woche 1, Gespräch Woche 4, Abschlussgespräch.

## 6. Woche 1 – tägliche Check-ins (5–10 Minuten, telefonisch oder vor Ort)

| Tag | Fokus | Checkpunkte |
|---|---|---|
| 1 | Erste echte Verkäufe und Einlösungen | [ ] Karten verkauft? [ ] Einlösungen ohne Hilfe? [ ] Meldungen aufgetreten? [ ] Kassa-Buchung klar? |
| 2 | Geräte und Anmeldung | [ ] Alle Diensthandys angemeldet und benannt? [ ] Abmeldungen, gesperrte Konten? [ ] NFC auf Android, iPhone-Lesen OK? |
| 3 | Dashboard mit Inhaber/in | [ ] **Outstanding balance** und **Recent activity** gemeinsam angesehen [ ] Zahlen plausibel? |
| 4 | Sonderfälle | [ ] Storno, Sperre, Ersatz nötig gewesen? [ ] Rückfragen von Gästen (Guthabenseite, E-Mails)? |
| 5 | Sicherheit und Wochenabschluss | [ ] **Audit log** auf rote Sicherheitswarnungen geprüft [ ] **Transactions → Export CSV** an die Buchhaltung, Format OK? [ ] Feedback der Servicekräfte gesammelt |

**Pro Check-in dokumentieren:** Datum, Gesprächspartner, Anzahl Verkäufe/Einlösungen seit letztem Check-in, Probleme (mit Ticketnummer), Zitate, nächste Schritte.

**Regel:** Alles, was mehr als einen Tipp braucht oder eine Rückfrage auslöst, wird als Verbesserungsvorschlag erfasst.

## 7. Erfolgskennzahlen

| Kennzahl | Messung | Zielwert Pilot (Annahme) |
|---|---|---|
| Verkaufte Karten | Dashboard **Cards sold**, je Lokal und Woche | Baseline des Lokals (Papiergutscheine Vorjahreszeitraum) erreicht oder übertroffen |
| Verkaufswert | **Revenue this month** | wird erhoben, kein Zielwert |
| Einlösezeit am Tisch | Stoppuhr-Stichprobe: 10 Einlösungen pro Lokal, vom Übergeben der Karte bis zum Erfolgsbildschirm | Median < 5 Sekunden |
| Schulungszeit Servicekraft | Dauer Modul A | ≤ 15 Minuten |
| Fehlbedienungen | Anzahl Stornos (**„Reversal"**) im Verhältnis zu Einlösungen | < 2 % |
| Technische Fehler | Tickets P1/P2 | 0 P1; P2 innerhalb von 1 Werktag gelöst |
| Supportaufwand | Tickets und Minuten pro Lokal und Woche | wird erhoben (Planungsgrundlage) |
| Sicherheitswarnungen | Einträge im **Audit log** | alle geklärt |
| Zufriedenheit Inhaber/in | **NPS**-Frage im Abschlussgespräch (0–10) | ≥ 30 über alle Pilotlokale |
| Zufriedenheit Servicekräfte | Kurzumfrage 1–5 „Wie einfach ist das Einlösen?" | Durchschnitt ≥ 4 |
| Weiterführung | Lokal bleibt nach den 3 Gratismonaten | ≥ 80 % der Pilotlokale |

Alle Zielwerte sind Planungsannahmen und werden im Pilot überprüft.

**NPS-Frage:** „Wie wahrscheinlich ist es, dass Sie GiftCard Pro einer befreundeten Gastronomin oder einem befreundeten Gastronomen empfehlen? (0 = gar nicht, 10 = sehr wahrscheinlich)" – anschließend: „Was ist der wichtigste Grund für Ihre Bewertung?"

## 8. Leitfaden für das Feedbackgespräch (Woche 4 und Abschluss, 30–45 Minuten)

**Einstieg**
1. Wie haben Sie Gutscheine vor GiftCard Pro verwaltet, und was hat Sie daran gestört?
2. Was war Ihr erster Eindruck in der ersten Woche?

**Service am Tisch**
3. Wie reagieren Ihre Servicekräfte auf das Einlösen? Gab es Situationen, in denen jemand nicht weiterwusste?
4. Welche Meldung in der App war unklar?
5. Wie gut funktioniert das Lesen der Karten mit Ihren Handys (Android, iPhone, QR)?
6. Wie stark stört die englische Oberfläche Ihr Team?

**Verkauf und Gäste**
7. Wie reagieren Gäste auf die Karte im Vergleich zum Papiergutschein?
8. Nutzen Gäste die Guthabenseite oder die E-Mails? Gab es Rückfragen?
9. Wie läuft der Verkauf ab – wer legt die Karte an, wie lange dauert es?

**Verwaltung und Zahlen**
10. Welche Zahl im Dashboard schauen Sie sich an, und welche fehlt Ihnen?
11. Wie hat die Buchhaltung bzw. Steuerberatung auf den Export reagiert?
12. Wie gut passt der Ablauf mit Ihrer Registrierkasse?

**Wert und Preis**
13. Welches Problem löst GiftCard Pro für Sie am meisten?
14. Wie beurteilen Sie den regulären Preis im Verhältnis zum Nutzen?
15. Was müsste passieren, damit Sie nach dem Pilot nicht weitermachen?

**Abschluss**
16. Wenn Sie eine Sache ändern könnten – welche?
17. NPS-Frage (siehe Abschnitt 7).
18. Dürfen wir Sie als Referenz nennen bzw. eine Fallstudie schreiben? (siehe Abschnitt 10)

**Gesprächsregeln:** offen fragen, nicht verteidigen, konkrete Beispiele erbitten („Wann war das zuletzt?"), wörtliche Zitate mitschreiben und nur nach Freigabe verwenden.

## 9. Kriterien für „bereit für den allgemeinen Marktstart"

Der Marktstart im November 2026 erfolgt, wenn **alle** Muss-Kriterien erfüllt sind:

**Muss**
- [ ] Mindestens 5 Pilotlokale haben mindestens 2 Wochen lang echte Karten verkauft und eingelöst.
- [ ] Kein offener Fehler der Priorität P1 oder P2.
- [ ] Keine Abweichung zwischen Buchungsjournal und Kartenguthaben festgestellt.
- [ ] Median Einlösezeit am Tisch < 5 Sekunden in allen Lokalen.
- [ ] Servicekräfte aller Pilotlokale lösen ohne Hilfe ein.
- [ ] Datensicherung inkl. Wiederherstellungstest bestätigt; Überwachung aktiv.
- [ ] Onboarding-Unterlagen, Wissensdatenbank und Videos (mindestens Video 2, 3, 5, 6) veröffentlicht.
- [ ] Standardverträge, AGB und Auftragsverarbeitungsvertrag rechtlich geprüft.
- [ ] Supportprozess (Ticketnummern, Makros, Eskalation) im Einsatz erprobt.

**Soll**
- [ ] NPS ≥ 30; Servicekräfte-Zufriedenheit ≥ 4.
- [ ] Mindestens 2 freigegebene Referenzen.
- [ ] Die drei häufigsten Verbesserungsvorschläge bewertet und eingeplant (z. B. deutsche Mitarbeiter-Oberfläche).

Sind Muss-Kriterien nicht erfüllt, entscheidet die Geschäftsführung über Verschiebung oder Start mit bekannten Einschränkungen; die Entscheidung wird dokumentiert.

## 10. Referenz- und Fallstudienfreigabe

- [ ] Referenz nur mit **schriftlicher Freigabe** der Inhaberin bzw. des Inhabers (E-Mail genügt), getrennt nach Nutzungsart:
  - [ ] Nennung von Name und Logo des Lokals (Website, Präsentationen)
  - [ ] Zitat – nur im freigegebenen Wortlaut: `[Zitat nach Freigabe]`
  - [ ] Fotos im Lokal (Personen auf Fotos geben separat ihre Zustimmung)
  - [ ] Fallstudie mit Kennzahlen – nur freigegebene Zahlen
  - [ ] Bereitschaft für Anrufe von Interessenten
- [ ] Freigabe jederzeit widerrufbar; bei Widerruf Entfernung binnen [Frist, z. B. 14 Tagen].
- [ ] Vor Veröffentlichung Entwurf zur Freigabe vorlegen.
- [ ] Freigaben zentral ablegen (Datum, Umfang, Person).

**Vorlage Freigabe-E-Mail**
> Guten Tag [Name],
> danke für Ihre Teilnahme am Pilotprogramm. Dürfen wir [Name des Lokals] als Referenz nennen? Konkret bitten wir um Ihre Zustimmung zu: [Liste der Nutzungsarten]. Den Text legen wir Ihnen vor der Veröffentlichung vor. Sie können die Zustimmung jederzeit widerrufen.
> Freundliche Grüße, [Name], GiftCard Pro

## 11. Abschluss des Pilots je Lokal

- [ ] Abschlussgespräch geführt, NPS erhoben, Protokoll abgelegt.
- [ ] Übergang in den regulären Betrieb bestätigt (Tarif, 50 % Rabatt für 12 Monate nach den 3 Gratismonaten, Rechnungsstellung).
- [ ] Offene Tickets geklärt oder mit Termin versehen.
- [ ] Danke-Schreiben verschickt.

---

Version 1.0 · Stand: September 2026
