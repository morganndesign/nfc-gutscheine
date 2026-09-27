# Executive Summary — GiftCard Pro

*Kurzfassung für Investorinnen und Investoren, Förderstellen, Partner und Beratung: Was wir bauen, für wen, warum jetzt und was wir als Nächstes brauchen.*

---

## Auf einen Blick

| | |
|---|---|
| **Produkt** | GiftCard Pro — Gutscheinkarten-System für die Gastronomie (NFC- und QR-Karten, Cloud-Software) |
| **Kernversprechen** | Karte antippen, Betrag eingeben, fertig — in unter 5 Sekunden. Jeder Euro nachvollziehbar. |
| **Zielmarkt** | Österreich zuerst (Wien → Graz, Linz, Salzburg, Innsbruck), ab 2027 Deutschland, 2027–2028 Schweiz, Kroatien, Bosnien und Herzegowina, Serbien |
| **Geschäftsmodell** | Monatsabo ab € 29 netto, 0 % Provision, Kartenverkauf zu Cost-plus-Preisen |
| **Stand** | Produkt fertig entwickelt und getestet; Pilot mit 5–10 Wiener Restaurants ab Oktober 2026; noch keine zahlenden Kundinnen und Kunden |
| **Markteintritt** | November 2026 — vor der Advent- und Weihnachtssaison |
| **Anbieter** | [Firmenname] [Rechtsform], [Anschrift], 1xxx Wien |

---

## 1. Das Problem

Gutscheine sind für Restaurants ein gutes Geschäft: Das Geld kommt vor dem Besuch, und Beschenkte bringen oft Begleitung mit. Im Alltag der meisten Betriebe sieht die Abwicklung aber so aus:

- **Papiergutscheine und eine Excel-Liste.** Ein Block mit nummerierten Gutscheinen, handschriftliche Beträge, Stempel. Restbeträge werden auf dem Gutschein durchgestrichen und neu geschrieben — oder gar nicht.
- **Fälschung und Mehrfacheinlösung.** Ein Farbkopierer reicht, um einen Papiergutschein zu duplizieren. Ob ein Gutschein schon eingelöst wurde, weiß oft nur die Person, die ihn damals angenommen hat.
- **Keine Übersicht über die offene Haftung.** Jeder verkaufte, noch nicht eingelöste Gutschein ist eine Verbindlichkeit gegenüber dem Gast. Die wenigsten Inhaberinnen und Inhaber können auf Knopfdruck sagen, wie hoch dieser Betrag ist. Bei bilanzierenden Betrieben gehört er in die Bilanz; bei allen anderen ist er zumindest ein betriebswirtschaftliches Risiko.
- **Rechtliche Stolperfallen.** Viele Papiergutscheine tragen eine Befristung, die nach österreichischer Rechtsprechung unwirksam sein kann (OGH: generelle Befristung bezahlter Gutscheine auf 3 Jahre oder weniger in AGB ist gröblich benachteiligend). Gäste haben dann bis zu 30 Jahre Anspruch.
- **Online-Gutscheinshops passen nicht für alle.** Die meisten Anbieter am Markt verkaufen PDF-Gutscheine über die Website und verlangen dafür eine Provision von 3,9–4,9 % je Verkauf oder deutlich höhere Einrichtungsgebühren. Für ein Lokal, das Gutscheine vor allem an der Schank und zu Weihnachten verkauft, ist das der falsche Schwerpunkt.

## 2. Die Lösung

GiftCard Pro ist eine Cloud-Plattform, mit der Restaurants **physische Gutscheinkarten mit NFC-Chip und QR-Code** ausgeben, verkaufen, einlösen und verwalten.

- **Die Karte speichert kein Geld.** Chip und QR-Code enthalten nur einen zufälligen, sicheren Link. Guthaben, Verlauf und Kundendaten liegen ausschließlich auf dem Server. Eine kopierte oder verlorene Karte lässt sich sperren oder ersetzen — das Guthaben bleibt erhalten.
- **Einlösen am Tisch in Sekunden.** Die Servicekraft hält die Karte an ihr Smartphone (Android per Web NFC, iPhone über den Systemhinweis oder die Kamera), tippt den Betrag wie an einer Kassa und bestätigt. Die Systemzeit für den gesamten Einlösevorgang liegt bei rund 0,5 Sekunden; das Ziel inklusive Mensch am Tisch ist unter 5 Sekunden.
- **Klarheit über offene Beträge.** Das Dashboard zeigt jederzeit den offenen Gutscheinbetrag („Outstanding balance“) über alle Karten, dazu Verkäufe, Einlösungen und ein unveränderliches Buchungsjournal mit CSV-Export für die Steuerberatung.
- **Sicher gegen Betrug und Fehler.** Jede Buchung ist atomar und idempotent (Doppeltipps buchen nie doppelt), das Journal ist unveränderlich, Kartenklone werden über die Chip-Seriennummer bzw. bei NTAG-424-DNA-Karten kryptografisch erkannt.
- **Ein Geschenk, das nach etwas aussieht.** Scheckkartenformat, beidseitig bedruckt im Design des Restaurants — statt Papierzettel im Kuvert.
- **Fair.** 0 % Provision auf Verkauf und Einlösung, für immer.

GiftCard Pro ersetzt nicht die Registrierkasse. Verkauf und Einlösung werden weiterhin in der eigenen Registrierkasse gebucht; GiftCard Pro führt das Gutscheinkonto dazu.

![Owner-Dashboard mit offenem Gutscheinbetrag](../../screenshots/owner-dashboard.png)

## 3. Warum jetzt

1. **Die stärkste Gutscheinsaison steht bevor.** Advent und Weihnachten sind die Hauptverkaufszeit für Gastronomie-Gutscheine. Wer im November umstellt, verkauft die Weihnachtsgutscheine bereits auf Karten. Deshalb liegt der Marktstart bewusst im November 2026.
2. **Papier ist das eigentliche Konkurrenzprodukt.** Die Mehrzahl der kleinen Betriebe arbeitet noch mit Papiergutscheinen oder der Gutscheinfunktion ihrer Kassa. Der Umstieg ist einfach, weil keine neue Kassa und keine neue Hardware außer Karten und den vorhandenen Smartphones nötig ist.
3. **Betrugs- und Fehlerbewusstsein steigt.** Kopierte Papiergutscheine, doppelt eingelöste Beträge und fehlende Nachweise kosten Geld, das in knapp kalkulierten Betrieben fehlt.
4. **Haftung wird sichtbar.** Die Rechtsprechung zur Befristung und die umsatzsteuerliche Behandlung von Gutscheinen (EU-Gutscheinrichtlinie, seit 2019) machen saubere Aufzeichnungen wichtiger. Viele Betriebe kennen ihre offene Gutscheinverbindlichkeit schlicht nicht.
5. **NFC ist im Alltag angekommen.** Gäste kennen das Antippen vom kontaktlosen Bezahlen; Servicekräfte haben ein Smartphone in der Tasche. Web NFC auf Android und die NFC-Link-Erkennung auf dem iPhone machen eine eigene App überflüssig.

## 4. Produktstand

Das Produkt ist fertig entwickelt, automatisiert getestet und für den Pilotbetrieb bereit:

| Bereich | Stand |
|---|---|
| Kellner-App (Web-App, auf dem Startbildschirm installierbar) | fertig — NFC, QR-Scan, manuelle Kartennummer, Kassa-Tastenfeld |
| Dashboard für Inhaberin/Inhaber und Management | fertig — Kennzahlen, Diagramme, Karten, Buchungen, Kundschaft, Team, Geräte, Prüfprotokoll, Einstellungen |
| Kartenlebenszyklus | fertig — ausgeben, aktivieren, einlösen (voll/teilweise), aufladen, übertragen, ersetzen, sperren, stornieren |
| Sicherheit | fertig — Mandantentrennung, unveränderliches Journal, Klonschutz, Gerätebindung, Brute-Force-Schutz |
| Öffentliche Guthabenseite für Gäste | fertig (Deutsch/Englisch) |
| Qualitätssicherung | 113 automatisierte Backend-Tests, Browser-Abnahmetest, Barrierefreiheits-Scan (WCAG 2.1 AA), Test mit 20 gleichzeitigen Einlösungen auf eine Karte |
| Hosting | Hetzner, Rechenzentren in Deutschland (EU), nächtliche Backups inkl. externer Kopie |
| Oberfläche für Personal | derzeit Englisch; deutsche Oberfläche geplant für Q4 2026 (hohe Priorität) |

Technologie: Laravel 12 / PHP 8.4, MySQL 8.4, Redis, Next.js 15 / TypeScript, Docker, Caddy, GitHub Actions.

## 5. Markt

**Österreich** (Quelle: WKO Branchendaten Gastronomie, Februar 2025):

- **31.038 Gastronomie-Unternehmen** (2023), davon **90,9 % mit 0–9 Beschäftigten**
- 153.171 Beschäftigte, Umsatz € 11,645 Mrd. (2022)
- WKO-Mitgliedschaften 2024: 7.912 Restaurants, 5.016 Gasthäuser, 5.154 Kaffeehäuser
- Wien: 32,6 % der Beschäftigung in der Gastronomie

**Deutschland** (Quelle: DEHOGA-Zahlenspiegel 4. Quartal 2025):

- **150.218 Gastronomie-Unternehmen** (umsatzsteuerpflichtig, 2023), 202.110 im gesamten Gastgewerbe
- realer Umsatz 2025 weiterhin 14,8 % unter 2019 — Betriebe suchen nach planbaren Zusatzumsätzen

**Schweiz, Kroatien, Bosnien und Herzegowina, Serbien:** Betriebszahlen sind noch zu erheben (GastroSuisse Branchenspiegel, DZS Hrvatska, Agencija za statistiku BiH, RZS Srbija). Die Gründerin spricht Deutsch, Bosnisch/Kroatisch/Serbisch und Englisch; das eröffnet einen natürlichen Zugang zur ex-jugoslawischen Gastronomie in Wien und später in den Herkunftsländern.

**Einordnung (Annahme):** Erreichen wir bis Ende 2028 rund 800 zahlende Restaurants, entspricht das bei einem österreichischen Schwerpunkt einem niedrigen einstelligen Prozentanteil der Gastronomie-Unternehmen in Österreich und Deutschland zusammen. Das Wachstum hängt nicht von einem großen Marktanteil ab.

## 6. Geschäftsmodell und Preise

Alle Preise netto, zzgl. 20 % USt. Monatlich kündbar; bei jährlicher Zahlung sind 2 Monate gratis.

| Tarif | Monatlich | Jährlich | Für |
|---|---|---|---|
| **Start** | € 29 | € 290 | ein Restaurant, Café, eine Bar |
| **Pro** | € 59 | € 590 | stark frequentierte Betriebe, hohes Kartenvolumen, erhöhtes Betrugsrisiko |
| **Gruppe** | ab € 129 für bis zu 3 Standorte, + € 39 je weiterem Standort | individuell | Ketten, mehrere Standorte, Hotels mit mehreren Outlets |

Weitere Erlöse:

- **Karten (Cost-plus):** Starter-Set 100 bedruckte NFC-Karten (NTAG215) Richtpreis € 249, 250 Karten € 499, NTAG-424-DNA-Karten Richtpreis € 4–6 je Karte. *Richtpreis, abhängig von Menge und Druck — verbindliches Angebot auf Anfrage.*
- **Einrichtung vor Ort und Schulung:** optional € 149 einmalig. Selbst-Onboarding ist kostenlos.

Was wir bewusst nicht verlangen: **keine Provision** auf Kartenverkauf oder Einlösung, keine Einrichtungsgebühr beim Selbst-Onboarding, keine Gebühr pro Karte oder Transaktion (Fair Use).

**30 Tage kostenlos testen**, ohne Kreditkarte, mit allen Pro-Funktionen.

## 7. Traktion — ehrlich

- Das Produkt ist gebaut, getestet und in Produktion lauffähig.
- **Pilot ab Oktober 2026** mit 5–10 Restaurants in Wien. Konditionen: 3 Monate gratis, danach 12 Monate 50 % Rabatt (Start € 14,50 / Pro € 29,50), kostenlose Einrichtung vor Ort und 50 Gratiskarten; im Gegenzug Feedbackgespräche und — nach Freigabe — Nennung als Referenz.
- **Es gibt noch keine zahlenden Kundinnen und Kunden, keine Referenzen und keine Fallstudien.** Erste Ergebnisse aus dem Pilot erwarten wir ab November 2026. [Pilotbetriebe und Zitate nach Freigabe]

## 8. Team

- **[Name], Gründerin** — Hintergrund in Webentwicklung, Design für Restaurants, Automatisierung sowie Software- und QA-Testing. Spricht Deutsch, Bosnisch/Kroatisch/Serbisch und Englisch. Verantwortet Produkt, Vertrieb und Kundenbetreuung in der Startphase.
- Unterstützung extern: [Steuerberatung], [Rechtsanwältin/Rechtsanwalt], [Kartendruckerei].
- Geplant (Annahme): freie Mitarbeit für Vertrieb und Support ab Mitte 2027, 2–3 Vollzeitäquivalente bis Ende 2028.

## 9. Roadmap — Schwerpunkte

| Zeitraum | Vorhaben |
|---|---|
| Q4 2026 | Deutsche Oberfläche für Personal; automatisierte Abrechnung (Stripe); Pilot und Marktstart Wien |
| Q1 2027 | Online-Gutscheinverkauf über die Website des Restaurants — ohne Provision von GiftCard Pro (Gebühren des Zahlungsdienstleisters fallen gesondert an) |
| 2027 | Übersicht über mehrere Standorte; Registrierkassen-Anbindungen über die API; Marktstart Deutschland; Wallet-Karten (Apple/Google) |
| 2027–2028 | Schweiz (CHF), Kroatien, Bosnien und Herzegowina (BAM), Serbien (RSD); lokalisierte Oberflächen |

## 10. Finanzausblick (Annahmen)

*Alle Zahlen sind Planungsannahmen und werden im Pilot überprüft.*

| | Ende 2026 | Ende 2027 | Ende 2028 |
|---|---|---|---|
| Zahlende Restaurants (inkl. Pilotbetriebe) | ≈ 25 | ≈ 250 | ≈ 800 |
| MRR (Annahme ARPA € 42) | € 1.050 | € 10.500 | € 33.600 |
| Umsatz im Kalenderjahr (Abo, Karten, Einrichtung) | € 6.327 (nur Q4) | € 164.250 | € 509.571 |
| Ergebnis vor Steuern | − € 4.957 | + € 14.189 | + € 118.942 |

- ARPA (durchschnittlicher Monatsumsatz je Konto) € 42 bei einem Mix aus 70 % Start, 25 % Pro, 5 % Gruppe, abzüglich Pilotrabatte.
- Monatliche Abwanderung 1,5 %, Kundenakquisitionskosten unter € 300, Amortisation unter 8 Monaten.
- **Break-even bei rund 150–180 zahlenden Restaurants** inklusive Unternehmerlohn der Gründerin (Herleitung im [Business-Plan](business-plan.md#9-finanzplan)).

Details: [Business-Plan](business-plan.md) · [Erlösmodell](revenue-model.md) · [Preisstrategie](pricing-strategy.md)

## 11. Nächste Schritte und Bedarf

**Was wir in den nächsten 90 Tagen tun:**

1. Pilot mit 5–10 Wiener Restaurants im Oktober 2026 starten und messen: Einlösezeit am Tisch, Kartenverkäufe, Supportanfragen, Zufriedenheit der Servicekräfte.
2. Deutsche Oberfläche und Rechtstexte (AGB, Auftragsverarbeitungsvertrag, Impressum, Datenschutzerklärung) vor dem Marktstart fertigstellen.
3. Kartenlieferung mit einer Druckerei vertraglich absichern — Lieferzeit und Mindestmengen für die Adventsaison.
4. Marktstart im November 2026 mit Fokus Wien, Direktvertrieb und Partnern aus Steuerberatung und Kassenhandel.

**Was wir suchen:**

- **Finanzierung** von rund € 40.000–45.000 (Annahme) für Anlaufverluste, Kartenvorfinanzierung, Rechtstexte und einen Liquiditätspuffer — bevorzugt über Eigenmittel und Förderprogramme (aws, FFG, Wirtschaftsagentur Wien; Eignung wird geprüft).
- **Pilotbetriebe** in Wien: Restaurants, Kaffeehäuser, Heurige und Bars, die vor Weihnachten auf Gutscheinkarten umstellen wollen.
- **Partner:** Steuerberatungskanzleien mit Gastronomie-Schwerpunkt, Kassenhändler, Kartendruckereien.

Kontakt: [Name], Gründerin · hallo@giftcardpro.at · [Telefon] · giftcardpro.at

---

Version 1.0 · Stand: September 2026
