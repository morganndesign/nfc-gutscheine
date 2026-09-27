# Vorlage: Release Notes für Kundinnen und Kunden

*Wie wir Neuerungen an GiftCard Pro für Restaurants beschreiben: Aufbau, Regeln, Tonalität und ein ausgefülltes Beispiel für Version 1.2.0. Für alle, die Release Notes schreiben oder freigeben.*

---

## 1. Wozu Release Notes

Das technische Änderungsprotokoll (`CHANGELOG.md`, siehe [Vorlage Changelog](changelog-template.md)) richtet sich an Entwicklung und Betrieb. Release Notes richten sich an Inhaberinnen und Inhaber, Betriebsleitung und Servicekräfte. Sie beantworten drei Fragen:

1. **Was ist neu oder anders?**
2. **Was bedeutet das für meinen Betrieb?**
3. **Muss ich etwas tun?**

Release Notes erscheinen auf der Website, per E-Mail an Kundinnen und Kunden (bei Minor- und Major-Versionen) und im Hilfebereich.

---

## 2. Aufbau

```markdown
# GiftCard Pro <Version> — <kurzer, sprechender Titel>

*Veröffentlicht am <Datum> · <Zielgruppe in einem Satz>*

## Das Wichtigste in Kürze
<2–4 Sätze: der größte Nutzen zuerst.>

## Müssen Sie etwas tun?
<„Nein. Alle Änderungen sind automatisch aktiv." — oder konkrete Schritte mit Pfad in der App.>

## Neu
- **<Nutzen als Überschrift>.** <Was es ist, wo es zu finden ist, UI-Bezeichnung fett.>

## Verbessert
- **<Nutzen>.** <Vorher → jetzt.>

## Behoben
- **<Was jetzt richtig funktioniert>.** <Wann der Fehler auftrat, falls für Kundinnen und Kunden relevant.>

## Sicherheit
- <Nur beschreiben, was Kundinnen und Kunden wissen müssen. Keine Angriffsdetails vor der Behebung.>

## Für Ihr Team
<Optional: was Servicekräfte am nächsten Abend anders sehen. Druckbar, max. 5 Punkte.>

## Fragen?
support@giftcardpro.at

---
Version <Version> · <Datum>
```

Abschnitte ohne Inhalt entfallen. Die Reihenfolge ist fix.

---

## 3. Regeln

### Inhalt

1. **Nutzen vor Funktion.** Nicht „Neuer API-Endpunkt `outstanding_cards`", sondern „Sie sehen jetzt, auf wie vielen Karten Ihr offener Betrag liegt."
2. **Nur, was Kundinnen und Kunden bemerken.** Interne Umbauten, Tests und Werkzeuge gehören ins Changelog, nicht in die Release Notes.
3. **Konkrete Wege in der App.** „**Settings → Gift cards → Default validity**", nicht „in den Einstellungen".
4. **UI-Bezeichnungen wörtlich und fett**, solange die Oberfläche Englisch ist, mit deutscher Erklärung beim ersten Vorkommen: **„Redeem"** (Einlösen).
5. **„Müssen Sie etwas tun?" steht immer drin**, auch wenn die Antwort „Nein" ist.
6. **Zahlen nur mit Beleg.** Messwerte nennen, wie sie gemessen wurden („rund 0,5 Sekunden im Abnahmetest").
7. **Keine Versprechen zu Zukünftigem.** Hinweise auf geplante Funktionen nur mit Verweis auf die Roadmap und dem Zusatz „geplant".
8. **Sicherheit:** Behobene Lücken erst beschreiben, wenn sie in allen Umgebungen behoben sind. Keine Anleitung zum Ausnutzen.
9. **Rechtliche Themen** (Gültigkeit, Steuer) immer mit „keine Rechtsberatung — mit Steuerberatung/Rechtsanwalt prüfen".

### Sprache und Ton

- „Sie", kurze Sätze, aktive Verben, österreichisches Deutsch (Lokal, Servicekraft, Registrierkasse, Jänner).
- Ruhig und präzise. Kein „Wir freuen uns, Ihnen mitteilen zu dürfen", kein „revolutionär", „nahtlos", „Game-Changer", kein Ausrufezeichen.
- Fehler offen benennen: „Auf kleinen Handys war der Einlöseknopf nicht sichtbar. Das ist behoben." Nicht beschönigen, nicht dramatisieren.
- Beträge „€ 24,90", Tausender „€ 1.000", Datum „9. November 2026".
- Länge: so kurz wie möglich. Patch-Versionen: 3–8 Zeilen. Minor-Versionen: eine Bildschirmseite. Screenshots nur, wenn sie etwas zeigen, das schwer zu beschreiben ist.

### Freigabe

| Schritt | Wer |
|---|---|
| Entwurf aus dem Changelog | Entwicklung |
| Umschreiben für Kundinnen und Kunden | Produkt |
| Prüfung auf Richtigkeit (jede Aussage im Produkt nachvollziehen) | Support |
| BHS-Übersetzung | Produkt / Übersetzung |
| Veröffentlichung | Produkt |

---

## 4. Ausgefülltes Beispiel: Version 1.2.0

---

# GiftCard Pro 1.2.0 — Bereit für den ersten Abend

*Veröffentlicht im September 2026 · Für Inhaberinnen und Inhaber, Betriebsleitung und Servicekräfte*

## Das Wichtigste in Kürze

Wir haben jeden Bildschirm so durchgespielt, wie ihn ein neues Restaurant am ersten Tag nutzt — auf Computer, Tablet, großen und kleinen Handys. Was verwirrend, langsam oder unnötig war, haben wir geändert. Die Kellner-App passt jetzt auch auf kleine Handys ohne Scrollen, das Dashboard zeigt als Erstes Ihre offene Verbindlichkeit, und Karten, Guthabenseite und Exporte sprechen die Sprache Ihres Lokals.

## Müssen Sie etwas tun?

Nein. Alle Änderungen sind automatisch aktiv.

Unsere Empfehlung, falls noch nicht geschehen: Stellen Sie unter **Settings → Gift cards** die Standard-Gültigkeit (**Default validity**) auf **0** (kein Ablauf). Hintergrund: In Österreich sind Befristungen bezahlter Gutscheine auf drei Jahre oder weniger in der Regel unwirksam. Keine Rechtsberatung — bitte mit Ihrer Steuerberatung oder Rechtsanwältin bzw. Rechtsanwalt prüfen.

## Neu

- **Ein Willkommensbereich für neue Restaurants.** Das Dashboard führt Sie in vier Schritten zum Start: Kartenregeln prüfen → Team einladen → erste Karte anlegen → Kellner-Modus öffnen. Nach dem ersten Verkauf verschwindet er.
- **Gründe mit einem Tipp.** Beim Sperren (Reported stolen, Reported lost, Suspicious use), Ersetzen (Lost, Damaged, Stolen) und Stornieren (Wrong amount, Wrong card, Guest cancelled) wählen Sie den Grund mit einem Tipp. Das spart Zeit, und das Prüfprotokoll bleibt einheitlich.
- **Deutschsprachige Karten und Guthabenseite.** Druckvorlage (Gutschein, Gültig bis, Hinweis zum Scannen) und Guthabenseite für Gäste erscheinen vollständig in der Sprache Ihres Lokals — auch der Status („Gültig", „Vollständig eingelöst").

## Verbessert

### Kellner-App

- **Alles auf einen Blick, auch auf dem iPhone SE.** Guthaben, Kartennummer und Status stehen in einer kompakten Zeile. Betrag, Tastatur und **Redeem**-Knopf passen ohne Scrollen auf kleine Handys.
- **Klare Farben bei Problemen.** Gesperrte und ersetzte Karten zeigen eine rote Warnung, inaktive und leere Karten eine gelbe. Bei ersetzten Karten steht „Ask the guest for the new card".
- **Ein großer „Next card"-Knopf**, wenn eine Karte nicht verwendet werden kann. Vorher gab es nur ein kleines ✕.
- **Verständliche Meldungen** statt Fachbegriffen, z. B. „No card with this number. Check the digits and try again."
- **Passende Hinweise je Handy.** iPhones zeigen, wie man die Karte an die Oberkante hält; Android-Handys ohne NFC den Hinweis, NFC einzuschalten und Chrome zu verwenden.

### Dashboard

- **Die Zahlen, nach denen Sie fragen.** **Outstanding balance** (offene Verbindlichkeit, mit Anzahl der Karten), **Revenue this month** (mit Vergleich zum Vormonat), **Redeemed this month** (mit heutigem Betrag) und **Cards sold**.
- **Ehrlichere Diagramme.** Verkäufe und Einlösungen pro Tag erscheinen als Balken statt als geglättete Linie, die Verkäufe an Tagen ohne Verkauf vortäuschte. Leere Zeiträume zeigen „No sales in this period".
- **Schneller am Handy.** Die Kennzahlen erscheinen zuerst, die Diagramme laden danach.

### Karten und Exporte

- **Kartenliste und Journal auf dem Handy lesbar**, ohne seitliches Scrollen: Nummer und Kunde links, Guthaben und Status rechts.
- **Verständliche Beträge im Kartenverlauf.** „Total loaded" heißt jetzt **Reloaded** und zeigt nur Aufladungen; der Verkauf wurde vorher doppelt gezählt.
- **Buchungsart „Sale"** statt „Issued", in der App und im Export.
- **Exporte für die Steuerberatung.** Status und Buchungsarten erscheinen im CSV lesbar (*Active*, *Sale*) statt als technische Kürzel.
- **Kartennummern immer im Druckformat** („7666 5628 6896 4312"), auch in Ersatzvermerken.

### Team, Geräte, Prüfprotokoll

- **Geräte heißen wie das Gerät**, z. B. „iPhone · Safari".
- **Prüfprotokoll in Klartext**, z. B. „Card replaced", „Cloned card rejected". Sicherheitswarnungen sind rot mit Schild-Symbol markiert.
- **Rückfrage vor dem Widerrufen eines Geräts**, damit niemand mitten im Service versehentlich ausgesperrt wird.

### Barrierefreiheit

- Bessere Kontraste bei grünen Beträgen und Warnungen, beschriftete Auswahlfelder für Bildschirmleser. Alle Hauptbildschirme erfüllen WCAG 2.1 AA im Hell- und Dunkelmodus.

## Behoben

- Auf kleinen Handys lag der **Redeem**-Knopf unterhalb des sichtbaren Bereichs.
- Android-Handys zeigten die Anleitung für das iPhone.
- Die Kartenseite war auf dem iPad unübersichtlich (Knöpfe untereinander, abgeschnittener Status).
- Die Liste der E-Mail-Vorlagen zeigte Platzhalter statt Ihres Restaurantnamens.

## Für Ihr Team

- Karte antippen, Betrag eintippen, **Redeem** — der Knopf ist jetzt immer sichtbar.
- **Rot** heißt: Karte nicht annehmen, Betriebsleitung holen.
- **Gelb** heißt: Karte leer oder noch nicht aktiviert.
- Bei „Ask the guest for the new card" hat der Gast eine Ersatzkarte.
- Die nächste Karte können Sie direkt antippen.

## Fragen?

support@giftcardpro.at

---

Version 1.0 · Stand: September 2026
