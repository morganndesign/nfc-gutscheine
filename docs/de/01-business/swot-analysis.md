# SWOT-Analyse GiftCard Pro

*Zweck: Stärken, Schwächen, Chancen und Risiken von GiftCard Pro zum Start der Markteinführung (November 2026) und daraus abgeleitete Strategien (TOWS) mit konkreten Maßnahmen, Verantwortlichen und Zeitrahmen.*

> Grundlage sind der Produktstand 1.2.0 (Pilot-Release), die [Marktanalyse](market-analysis.md) und die [Wettbewerbsanalyse](competitor-analysis.md). Zahlen ohne Quelle sind Annahmen. Verantwortliche sind derzeit fast ausschließlich die Gründerin; ab Juli 2027 unterstützt eine freie Mitarbeiterin oder ein freier Mitarbeiter Customer Success und Vertrieb, 2028 folgt ein Team von 2,5 Vollzeitäquivalenten (siehe [Finanzannahmen](financial-assumptions.md)).

---

## 1. Überblick

| **Stärken (intern)** | **Schwächen (intern)** |
|---|---|
| S1 Einlösung am Tisch in Sekunden | W1 Kein Online-Shop, keine Zahlungsabwicklung |
| S2 Physische Premium-NFC-Karte | W2 Personal-Oberfläche auf Englisch |
| S3 Sicherheit und unveränderliches Journal | W3 Keine Kassenintegration (nur API) |
| S4 0 % Provision, transparente Preise | W4 Keine Referenzen, keine Kundinnen und Kunden |
| S5 Kassenunabhängig | W5 Kleines Team, Abhängigkeit von der Gründerin |
| S6 Überblick über offene Verbindlichkeit | W6 Keine Wallet-Pässe, keine native App |
| S7 Produktqualität geprüft (Tests, Barrierefreiheit) | W7 Nur EUR |
| S8 Dreisprachige Gründerin mit Gastronomie-Erfahrung | W8 Kein konsolidiertes Mehrstandort-Dashboard |
| S9 Keine Installation, jedes Smartphone | W9 Hardware-Logistik (Kartendruck, Vorfinanzierung) |
| **Chancen (extern)** | **Risiken (extern)** |
| O1 Weihnachtsgeschäft 2026 direkt nach Launch | T1 Kassenhersteller bauen Gutscheinfunktionen aus |
| O2 Papiergutscheine sind der häufigste „Mitbewerber" | T2 Online-Shops ergänzen physische Karten |
| O3 Provisionsmüdigkeit | T3 Wirtschaftlicher Druck in der Gastronomie |
| O4 Personalmangel | T4 Starke Saisonalität |
| O5 Steuerberatung als Multiplikator | T5 Rechtsrisiko bei Gutscheinbefristung |
| O6 Kassenhändler und Druckereien als Partner | T6 Etablierte österreichische Anbieter mit Referenzen |
| O7 Diaspora-Gastronomie in Wien | T7 Technische Abhängigkeiten (Web NFC, iPhone-Verhalten) |
| O8 Deutschland: 150.218 Gastronomie-Unternehmen | T8 Preisdruck und Gratistarife |
| O9 Mehrzweckgutschein-Regeln schaffen Dokumentationsbedarf | T9 Ausfall oder Sicherheitsvorfall |

---

## 2. Stärken

**S1 — Einlösung am Tisch in Sekunden.** Karte antippen, Betrag eingeben, einlösen: Die Kartenabfrage dauert ≈ 0,1 s, der gesamte Einlöseablauf inklusive Eintippen der Kartennummer ≈ 0,5 s System- und Oberflächenzeit. Ziel am Tisch inklusive Mensch: unter 5 Sekunden. Das ist im Stress des Service der wichtigste Nutzen.

**S2 — Physische Premium-NFC-Karte.** Scheckkartenformat (85,6 × 54 mm), vollfarbig, mit Design des Lokals und Name der oder des Beschenkten. Ein Geschenk, das nach etwas aussieht — klarer Unterschied zu PDF-Gutscheinen.

**S3 — Sicherheit und unveränderliches Journal.** Auf der Karte ist kein Geld, nur ein zufälliger Link (122-Bit-UUID). Jede Buchung ist atomar, idempotent und im unveränderlichen Journal (Summe der Buchungen = Guthaben). Klonschutz per Chip-UID-Bindung oder NTAG 424 DNA mit kryptografischer Signatur. Getestet mit 20 gleichzeitigen Einlösungen auf einer Karte.

**S4 — 0 % Provision, transparente Preise.** Start € 29, Pro € 59, Gruppe ab € 129 pro Monat (netto). Keine Provision auf Verkauf oder Einlösung, dauerhaft. Das ist leicht verständlich und rechnet sich bei hohen Gutscheinwerten.

**S5 — Kassenunabhängig.** Funktioniert neben jeder Registrierkasse. Kein Kassenwechsel, kein Projekt mit dem Kassenhändler nötig.

**S6 — Überblick über offene Verbindlichkeit.** Der KPI „Outstanding balance" zeigt, wie viel Geld in offenen Gutscheinen steckt. Das beantwortet eine Frage, die Inhaberinnen, Inhaber und Steuerberatung regelmäßig stellen.

**S7 — Geprüfte Produktqualität.** 113 automatisierte Backend-Tests, ein Browser-Abnahmetest des gesamten ersten Tages eines Restaurants, WCAG-2.1-AA-Prüfung ohne Befund, Hosting in der EU. Gute Grundlage für Vertrauen ohne Zertifikate zu behaupten.

**S8 — Gründerin mit passendem Profil.** Webentwicklung, Design für Restaurants, Automatisierung, Qualitätssicherung; Deutsch, BHS und Englisch. Das öffnet die Wiener Gastronomie mit Wurzeln im ehemaligen Jugoslawien und später die Märkte HR, BA, RS.

**S9 — Keine Installation.** Web-App auf jedem Smartphone, auf dem Startbildschirm installierbar. Unbegrenzte Teammitglieder und Geräte in jedem Tarif — keine Kosten pro Kellnerin oder Kellner.

## 3. Schwächen

**W1 — Kein Online-Shop, keine Zahlungsabwicklung.** Gutscheine können derzeit nur im Lokal verkauft werden. Ein Teil des Marktes erwartet Online-Verkauf. Roadmap: Q1 2027.

**W2 — Personal-Oberfläche auf Englisch.** Gästeseite, Karte und E-Mails sind auf Deutsch, die Oberfläche für Servicekräfte und Inhaber aber noch nicht. Für viele Betriebe ein Einwand. Roadmap: Q4 2026, hohe Priorität.

**W3 — Keine Kassenintegration.** Verkauf und Einlösung müssen zusätzlich in der Registrierkasse gebucht werden (Doppelerfassung). Eine API existiert (Tarif Pro), fertige Anbindungen nicht.

**W4 — Keine Referenzen.** Es gibt noch keine Kundinnen und Kunden, keine Fallstudien. Käufer in der Gastronomie vertrauen stark auf Empfehlungen.

**W5 — Kleines Team.** Vertrieb, Support, Entwicklung und Kartenlogistik hängen an einer Person. Engpass vor Weihnachten, Risiko bei Krankheit.

**W6 — Keine Wallet-Pässe, keine native App.** Gäste können die Karte nicht in Apple oder Google Wallet speichern; manche Betriebe erwarten eine App aus dem App Store.

**W7 — Nur EUR.** CHF, BAM und RSD fehlen; das blockiert die Schweiz, Bosnien und Herzegowina und Serbien.

**W8 — Kein Mehrstandort-Dashboard.** Jeder Standort ist ein eigenes Konto. Für Gruppen und Hotels ein Nachteil. Roadmap: 2027.

**W9 — Hardware-Logistik.** Karten müssen gedruckt, codiert und geliefert werden. Das bindet Kapital (Vorauszahlung Kartenbestand) und Zeit, besonders im November.

## 4. Chancen

**O1 — Weihnachtsgeschäft 2026.** Der Launch im November trifft die stärkste Gutscheinsaison. Betriebe haben einen konkreten Anlass, jetzt zu entscheiden.

**O2 — Papier ist der häufigste „Mitbewerber".** Viele Betriebe haben noch gar kein System. Wechsel von Papier ist leichter als Wechsel von einem anderen Anbieter.

**O3 — Provisionsmüdigkeit.** Gastronomie zahlt bereits Provisionen an Liefer- und Reservierungsplattformen. Ein System mit 0 % Provision trifft einen Nerv (Annahme, im Pilot zu bestätigen).

**O4 — Personalmangel.** Jede Lösung, die ohne Schulung funktioniert, spart Zeit und Fehler — ein Argument, das jede Betriebsleitung versteht.

**O5 — Steuerberatung als Multiplikator.** Steuerberaterinnen und Steuerberater betreuen viele Gastronomiebetriebe und wollen saubere Gutscheinaufzeichnungen. Eine Empfehlung von dort wiegt schwer.

**O6 — Partner im Umfeld.** Kassenhändler und Druckereien stehen bereits im Kontakt mit den Betrieben und suchen Zusatzangebote.

**O7 — Diaspora-Gastronomie in Wien.** Zahlreiche Lokale mit Inhaberinnen und Inhabern aus dem ehemaligen Jugoslawien; Beratung auf BHS schafft Vertrauen und Empfehlungen (Größe zu erheben).

**O8 — Deutschland.** 150.218 Gastronomie-Unternehmen ([DEHOGA-Zahlenspiegel 4. Quartal 2025](https://www.dehoga-bundesverband.de)), gleiche Sprache und Währung. Der reale Umsatz liegt noch 14,8 % unter 2019 — Gutscheine als Vorauszahlung sind dort attraktiv.

**O9 — Dokumentationsbedarf durch Umsatzsteuerregeln.** Seit 2019 ist die Unterscheidung Einzweck-/Mehrzweckgutschein verbindlich; Betriebe brauchen nachvollziehbare Verkaufs- und Einlösedaten.

## 5. Risiken

**T1 — Kassenhersteller bauen Gutscheinfunktionen aus.** Wenn die Kassa Gutscheine gut genug kann, sinkt der Bedarf an einem separaten System.

**T2 — Online-Shops ergänzen physische Karten.** Größere Anbieter könnten NFC-Karten und Einlöse-Apps nachrüsten.

**T3 — Wirtschaftlicher Druck.** Kostensteigerungen und Schließungen verringern Budgets und erhöhen die Kündigungsrate.

**T4 — Saisonalität.** Ein großer Teil der Abschlüsse und Kartenbestellungen fällt in Q4. Verpasst man das Fenster, verschiebt sich Wachstum um ein Jahr.

**T5 — Rechtsrisiko bei Befristung.** Betriebe, die Gutscheine unzulässig kurz befristen, riskieren Konflikte mit Gästen. Negativer Ruf könnte auf das System abfärben.

**T6 — Etablierte Anbieter mit Referenzen.** incert nennt Figlmüller und Plachutta als Referenzen; neue Anbieter müssen Vertrauen erst aufbauen.

**T7 — Technische Abhängigkeiten.** Web NFC funktioniert nur in Chrome auf Android; iPhones lesen Karten über die Systembenachrichtigung. Änderungen durch Apple oder Google können Abläufe beeinflussen.

**T8 — Preisdruck.** Gratistarife (z. B. gurado) und gebührenbasierte Modelle ohne Monatspreis (Gutschein Direkt) setzen einen niedrigen Referenzpreis.

**T9 — Ausfall oder Sicherheitsvorfall.** Ein Ausfall am Samstagabend oder ein Datenvorfall wäre für ein junges Produkt schwer zu verkraften.

---

## 6. TOWS-Strategien

### 6.1 SO — Stärken nutzen, um Chancen zu ergreifen

| Nr. | Strategie | Konkrete Maßnahmen | Verantwortlich | Zeitrahmen |
|---|---|---|---|---|
| SO1 | **Weihnachtsoffensive mit Premium-Karte** (S2, S1 × O1) | 40 persönliche Besuche in Wien; Demo-Karte im Gespräch antippen lassen; Kartenbestellung bis 10. November ermöglichen | [Name], Gründerin | Oktober–November 2026 |
| SO2 | **„Papier raus"-Kampagne** (S3, S6 × O2) | Rechenbeispiel „Wie viel steckt in Ihren offenen Gutscheinen?"; Umstiegshilfe: bestehende Papiergutscheine als Karten mit Restwert erfassen | Gründerin | ab November 2026 |
| SO3 | **Provisionsvergleich als Kernbotschaft** (S4 × O3) | Provisionsrechner auf der Website; Battlecard „Online-Shop mit Provision" | Gründerin | Dezember 2026 |
| SO4 | **Steuerberatungs-Paket** (S6, S3 × O5, O9) | 2-seitiges Informationsblatt, Beispiel-Export, 3 Vorträge bei Steuerberatungskanzleien | Gründerin | Q1 2027 |
| SO5 | **BHS-Netzwerk in Wien** (S8 × O7) | Ansprache von 30 Lokalen mit BHS-sprachigen Inhaberinnen und Inhabern; Unterlagen auf BHS | Gründerin | November 2026–Februar 2027 |

### 6.2 ST — Stärken nutzen, um Risiken abzuwehren

| Nr. | Strategie | Konkrete Maßnahmen | Verantwortlich | Zeitrahmen |
|---|---|---|---|---|
| ST1 | **Kassenhändler als Partner statt Gegner** (S5 × T1) | 5 Kassenhändler in Wien ansprechen; API-Dokumentation für Integrationen; Empfehlungsprovision prüfen | Gründerin | Q1–Q2 2027 |
| ST2 | **Vorsprung bei Geschwindigkeit und Sicherheit dokumentieren** (S1, S3 × T2) | Messung der Einlösezeit im Pilot; Video „Karte antippen bis Restguthaben" | Gründerin | November 2026 |
| ST3 | **Rechtssichere Voreinstellungen** (S3 × T5) | Onboarding-Checkliste: „Default validity" auf 0; Plattform-Voreinstellung ändern | Gründerin (Produkt) | Q4 2026 / Q1 2027 |
| ST4 | **Wert statt Rabatt** (S4, S6 × T8) | Kein Gratistarif; stattdessen 30 Tage Test mit allen Pro-Funktionen und Zeitersparnis-Rechnung | Gründerin | laufend |
| ST5 | **Vertrauen durch Offenheit** (S7 × T6, T9) | Öffentliche Sicherheitsseite, Statusseite, Verfügbarkeitsziel 99,5 % transparent machen | Gründerin | Q1 2027 |

### 6.3 WO — Schwächen abbauen, um Chancen zu nutzen

| Nr. | Strategie | Konkrete Maßnahmen | Verantwortlich | Zeitrahmen |
|---|---|---|---|---|
| WO1 | **Deutsche Oberfläche vor der Hauptsaison** (W2 × O1, O8) | Übersetzung aller Oberflächentexte, Test mit Pilotbetrieben | Gründerin (Entwicklung) | Q4 2026 |
| WO2 | **Referenzen aus dem Pilot** (W4 × O1, O2) | 10 Pilotbetriebe; nach Freigabe Zitate und Fotos; 3 Kurzfallstudien | Gründerin | Dezember 2026–Februar 2027 |
| WO3 | **Online-Shop für das Frühjahrsgeschäft** (W1 × O3) | Online-Verkauf mit Zahlungsanbieter, weiterhin ohne Provision von unserer Seite | Gründerin (Entwicklung) | Q1 2027 (vor Valentinstag/Ostern) |
| WO4 | **Erste Kassenanbindung mit Partner** (W3 × O6) | Die im Pilot am häufigsten genutzte Kassa identifizieren; Integration mit einem Kassenhändler planen | Gründerin + Kassenhändler | Q2–Q3 2027 |
| WO5 | **Kartenlogistik über Druckereipartner** (W9 × O6) | Rahmenvertrag mit einer Druckerei, Mindestbestand, Lieferzeit ≤ 10 Werktage (Annahme) | Gründerin | Oktober 2026 |

### 6.4 WT — Schwächen und Risiken gleichzeitig begrenzen

| Nr. | Strategie | Konkrete Maßnahmen | Verantwortlich | Zeitrahmen |
|---|---|---|---|---|
| WT1 | **Entlastung der Gründerin** (W5 × T4, T9) | Support-Makros, Video-Onboarding, freie Mitarbeit Customer Success/Support | Gründerin; ab Juli 2027 freie Mitarbeit | ab Juli 2027 (Annahme, an Auslöser gekoppelt) |
| WT2 | **Ausfallsicherheit und Notfallplan** (W5 × T9) | Notfall-Anleitung für Betriebe (Karten später nachbuchen), Monitoring, Wiederherstellungstest der Backups | Gründerin | Q4 2026 |
| WT3 | **Saisonplan gegen Q4-Abhängigkeit** (W1 × T4) | Frühjahrskampagnen (Valentinstag, Ostern, Muttertag, Vatertag) mit Online-Shop ab 2027 | Gründerin | ab Jänner 2027 |
| WT4 | **Währungen erst mit Marktbeweis** (W7 × T3) | CHF/BAM/RSD erst entwickeln, wenn Einstiegskriterien je Markt erfüllt sind | Gründerin | 2027–2028 |
| WT5 | **Fokus statt Funktionsvielfalt** (W6, W8 × T2) | Keine Loyalty-, CRM- oder Reservierungsmodule; Wallet und Mehrstandort nur nach Nachfrage priorisieren | Gründerin | laufend |

---

## 7. Prioritäten für die nächsten 6 Monate

1. **WO1** Deutsche Oberfläche (Q4 2026)
2. **SO1** Weihnachtsoffensive in Wien (Oktober–November 2026)
3. **WO2** Referenzen aus dem Pilot (bis Februar 2027)
4. **ST3** Rechtssichere Voreinstellungen (Q4 2026)
5. **WO3** Online-Shop (Q1 2027)
6. **SO4** Steuerberatungs-Paket (Q1 2027)

Diese SWOT wird nach dem Pilot (Dezember 2026) und danach halbjährlich überprüft.

---

Version 1.0 · Stand: September 2026
