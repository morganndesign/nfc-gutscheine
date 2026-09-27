# Handbuch für die Betriebsleitung

*Der tägliche Betrieb mit GiftCard Pro: Karten verkaufen und vorbereiten, einlösen und aufladen, Fehler korrigieren, Verlust und Sperre, abgelaufene Karten, Kundendaten und Übergabe zwischen Schichten.*

Die Oberfläche ist derzeit auf Englisch. Schaltflächen stehen hier genau so, wie Sie sie sehen, beim ersten Vorkommen mit deutscher Bedeutung, z. B. **„Redeem“** (Einlösen).

---

## 1. Ihre Rechte als Manager

Mit der Rolle **Manager** dürfen Sie: Karten verkaufen, NFC-Chips beschreiben, einlösen, aufladen, Guthaben übertragen, Karten ersetzen, sperren, entsperren und ablaufen lassen, Buchungen stornieren und exportieren, Kunden verwalten sowie Audit-Log und Geräte ansehen.

Nur die Inhaberin / der Inhaber darf: Einstellungen ändern, Team einladen oder deaktivieren, Geräte sperren (**„Revoke“**) und API-Tokens verwalten.

---

## 2. Eine Karte verkaufen

![Neue Gutscheinkarte](../../screenshots/new-card.png)

1. **„Gift cards“** (Gutscheinkarten) → **„New gift card“** (Neue Gutscheinkarte). Oder direkt im **„Dashboard“** oben rechts.
2. **„Value“** (Wert): € 25, 50, 75, 100 oder 150 antippen – oder einen eigenen Betrag unter **„Amount“** (Betrag) eintippen.
3. **„Valid until“** (gültig bis): zeigt die Standard-Gültigkeit Ihres Restaurants. Nur ändern, wenn Ihre Inhaberin / Ihr Inhaber es so vorgibt.
4. **„Customer“** (Kunde):
   - **„Anonymous“** (anonym) – keine Daten, schnellste Variante;
   - **„Existing“** (bestehender Kunde) – suchen und auswählen;
   - **„New customer“** (neuer Kunde) – Vorname, Nachname, E-Mail, Telefon. Mit E-Mail bekommt der Gast eine Kaufbestätigung.
   Tipp: Bitten Sie um eine E-Mail-Adresse. Bei Verlust finden Sie die Karte dann über den Namen.
5. **„Recipient name“** (Name der beschenkten Person): wird auf die Karte gedruckt, z. B. „Für Oma Anni“.
6. **„Card type“** (Kartentyp): wie Ihre Kartenlieferung – in der Regel **NTAG215**; **QR only** für Papierkarten.
7. **„Activate immediately“** (sofort aktivieren): eingeschaltet lassen.
8. **„Internal notes“** (interne Notizen): nur für Ihr Team sichtbar, z. B. „Firmenfeier Müller, Rechnung Nr. 123“.
9. **„Create card“** (Karte erstellen).
10. **In der Registrierkasse bonieren** – Taste „Gutschein-Verkauf“ nach Vorgabe Ihrer Steuerberatung. GiftCard Pro ist keine Registrierkasse und erstellt keinen Beleg.

---

## 3. NFC-Chip beschreiben oder Karte drucken

Nach **„Create card“** erscheint **„Card created“** (Karte erstellt) mit dem Schritt **„Program the card“** (Karte programmieren).

### Android-Handy mit Chrome (empfohlen)

1. **„Write NFC tag“** (NFC-Chip beschreiben) drücken.
2. Leere Karte flach an die obere Rückseite des Handys halten, etwa eine Sekunde.
3. Das Handy prüft, ob der Chip frei ist, erkennt den Chiptyp (NTAG213/215/216), schreibt den Link, liest ihn zur Kontrolle erneut und speichert erst dann die Chip-Seriennummer für den Kopierschutz. Auf Wunsch wird der Chip danach schreibgeschützt (**„Lock tag after writing“**).
4. Gehört der Chip schon zu einer anderen Karte, wird nichts geschrieben und die andere Kartennummer angezeigt.

**Viele Karten auf einmal:** **Gift cards → „Program NFC tags“** zeigt nacheinander jede Karte ohne Chip; pro Karte einen leeren Chip ans Handy halten und mit der angezeigten Kartennummer beschriften.

### iPhone oder PC

1. Den angezeigten Link kopieren.
2. Mit einer NFC-App (z. B. *NFC Tools*) einen **URL-Eintrag** mit diesem Link auf die Karte schreiben, optional sperren.
3. Den Chiptyp wählen und **„Mark as written“** (als beschrieben markieren). Die Karte gilt als „nicht geprüft“; ohne Prüfung wird keine Seriennummer gespeichert, der Kopierschutz greift für diese Karte nicht.

### QR-Karte drucken

**„Print“** (Drucken) öffnet das Drucklayout in Scheckkartengröße (85,6 × 54 mm): Vorderseite mit Restaurant, Wert, beschenkter Person; Rückseite mit QR-Code, Kartennummer, Gültigkeit und Scan-Hinweis. Später erreichbar über die Karte → **⋯ → „Print card / QR“**.

![Drucklayout](../../screenshots/print-card.png)

Danach: **„Open card“** (Karte öffnen) oder **„Create another“** (weitere Karte erstellen).

**Karte vor der Übergabe testen:** kurz mit dem Diensthandy antippen – die Karte muss sich mit dem richtigen Betrag öffnen.

---

## 4. Eine Karte finden

![Kartenliste](../../screenshots/gift-cards.png)

**„Gift cards“** → Suchfeld: Kartennummer (auch nur die letzten Ziffern), Kundenname, Name der beschenkten Person oder Notiz.

- **Status-Filter:** Active, Inactive, Redeemed, Blocked, Expired, Replaced.
- **Sortierung:** „Newest first“ (neueste zuerst), „Highest balance“ (höchstes Guthaben), „Expiring soonest“ (zuerst ablaufend), „Recently used“ (zuletzt verwendet) u. a.
- Oder Karte einfach mit dem Diensthandy antippen.

---

## 5. Einlösen und Aufladen am Pult

![Kartendetail](../../screenshots/card-detail.png)

Karte öffnen, dann:

- **„Redeem“** (Einlösen): Betrag, optional **„Reference“** (Referenz, z. B. Tisch 12 oder Rechnungsnummer) und **„Note“** (Notiz) → bestätigen.
- **„Reload“** (Aufladen): Betrag eingeben → bestätigen. Nur möglich, wenn Aufladen erlaubt ist. **In der Registrierkasse wie ein Gutschein-Verkauf bonieren.**
- **„History“** (Verlauf): jede Buchung mit Zeit, Person, Gerät und Guthaben danach.

Am Tisch lösen Servicekräfte schneller über den **„Waiter mode“** (Kellner-Modus) ein – siehe Kurzanleitung für Servicekräfte.

---

## 6. Weitere Aktionen im Menü ⋯

| Aktion | Wofür |
|---|---|
| **„Activate“** (aktivieren) | Karte, die ohne **„Activate immediately“** angelegt wurde, freischalten |
| **„Edit details“** (Details bearbeiten) | Kunde, beschenkte Person, Notizen, Gültigkeit ändern |
| **„Write NFC tag“** | Chip (neu) beschreiben |
| **„Print card / QR“** | Drucklayout erneut öffnen |
| **„Transfer balance“** (Guthaben übertragen) | Guthaben auf eine andere Karte verschieben (**„Target card number“** – Zielkartennummer) |
| **„Replace lost card“** (verlorene Karte ersetzen) | siehe Abschnitt 7 |
| **„Block card“** / **„Unblock“** (sperren / entsperren) | siehe Abschnitt 8 |
| **„Expire now“** (sofort ablaufen lassen) | Karte schließen und Restguthaben ausbuchen – nur nach Rücksprache mit der Inhaberin / dem Inhaber (siehe Abschnitt 10) |

---

## 7. Verlorene oder beschädigte Karte ersetzen

1. Karte finden: über Kartennummer (Gast hat ein Foto?), Kundenname oder Name der beschenkten Person. Ohne Kartennummer und ohne Kundendaten lässt sich eine Karte in der Regel nicht eindeutig zuordnen – dann ist ein Ersatz nicht möglich.
2. Karte öffnen → **⋯ → „Replace lost card“**.
3. Grund wählen: **„Lost“** (verloren), **„Damaged“** (beschädigt) oder **„Stolen“** (gestohlen).
4. Das Guthaben geht sofort auf eine **neue Karte mit neuer Nummer**. Die alte Karte funktioniert ab diesem Moment nicht mehr und zeigt an der Kassa „replaced“ (ersetzt).
5. Neue Karte beschreiben oder drucken (Abschnitt 3) und dem Gast übergeben.

Ein Ersatz ist **keine neue Einnahme** – in der Registrierkasse wird dafür nichts boniert (im Zweifel mit der Steuerberatung abstimmen).

---

## 8. Sperren und Entsperren

**Sperren**, wenn: ein Gast den Verlust meldet und noch nicht klar ist, ob ersetzt wird; ein Diebstahl gemeldet wird; eine Nutzung verdächtig ist; eine Sicherheitswarnung im Audit-Log auftaucht.

Karte öffnen → **⋯ → „Block card“** → Grund angeben (z. B. „Reported lost“, „Reported stolen“, „Suspicious use“). Eine gesperrte Karte wird an jeder Kassa rot abgelehnt. Das Guthaben bleibt unverändert.

**Entsperren:** **⋯ → „Unblock“**, wenn sich der Fall geklärt hat (z. B. Karte wiedergefunden).

---

## 9. Fehler korrigieren (Storno)

Falscher Betrag eingelöst oder aufgeladen?

1. **„Transactions“** (Buchungen) oder im Verlauf der Karte die falsche Buchung suchen.
2. ↺ **„Reverse“** (stornieren) → Grund eintragen → bestätigen.
3. Die Korrektur wird als **Gegenbuchung** gespeichert. Die ursprüngliche Buchung bleibt sichtbar. Nichts wird gelöscht.
4. Dann den richtigen Betrag neu buchen.
5. Die Registrierkasse entsprechend korrigieren.

Nicht möglich bei Karten mit Status **Replaced** oder **Expired**. In diesen Fällen: Inhaberin / Inhaber informieren.

---

## 10. Abgelaufene Karten

Ist bei einer Karte ein Ablaufdatum gesetzt, schaltet GiftCard Pro sie in der Nacht nach Ablauf (00:15 Uhr) auf **Expired** (abgelaufen) und bucht das Restguthaben aus. An der Kassa erscheint „This card has expired.“

> **Rechtlicher Hinweis:** In Österreich ist eine Befristung bezahlter Gutscheine auf drei Jahre oder weniger in AGB nach der Rechtsprechung des OGH in der Regel unwirksam; dann gilt eine Frist von 30 Jahren. Ein Gast mit abgelaufener Karte kann also weiterhin einen Anspruch haben.
>
> *Keine Rechtsberatung – bitte mit Ihrer Rechtsanwältin / Ihrem Rechtsanwalt prüfen.*

**So gehen Sie vor:**

1. Den Gast freundlich empfangen – nicht abweisen. Karte in **„Gift cards“** öffnen.
2. Im **„History“** den ausgebuchten Betrag (Buchung „Expiration“) nachsehen.
3. Nach Vorgabe der Inhaberin / des Inhabers: **„New gift card“** über diesen Betrag ausstellen, in **„Internal notes“** vermerken: „Ersatz für abgelaufene Karte [Nummer]“. Die neue Karte erscheint im Buchungsjournal als Verkauf – bitte die Inhaberin / den Inhaber informieren, damit die Steuerberatung sie richtig zuordnet. In der Registrierkasse erst nach Vorgabe der Steuerberatung buchen.

**Vorbeugen ist besser:** Sortieren Sie die Kartenliste einmal pro Woche mit **„Expiring soonest“**. Karten, die bald ablaufen, verlängern Sie über **⋯ → „Edit details“** → **„Valid until“** – das geht nur, solange die Karte noch nicht abgelaufen ist.

---

## 11. Kunden

**„Customers“** (Kunden): Liste aller erfassten Gäste. Kunde öffnen → alle Karten dieses Gastes mit Guthaben und Gültigkeit; Kontaktdaten bearbeiten.

- Erfassen Sie nur Daten, die der Gast freiwillig angibt.
- Wünscht ein Gast die Löschung seiner Daten, geben Sie das an die Inhaberin / den Inhaber weiter (Funktion **„Anonymize customer“**).
- Geben Sie keine Kundendaten am Telefon heraus, ohne die Person eindeutig zu erkennen.

---

## 12. Tägliche und wöchentliche Kontrollen

### Täglich (5 Minuten, bei Schichtende)

- **„Dashboard“** → **„Redeemed this month“** (heute eingelöst) mit der Zahlungsart „Gutschein“ der Registrierkasse abgleichen.
- **„Recent activity“** überfliegen: ungewöhnliche Beträge, Stornos?
- Neue verkaufte Karten in beiden Systemen erfasst?

### Wöchentlich (15 Minuten)

- **„Audit log“** (Prüfprotokoll): rot markierte **„Security alert“** (Sicherheitswarnungen) prüfen.
- **„Gift cards“** → Status **Blocked**: offene Fälle klären.
- **„Gift cards“** → **„Expiring soonest“**: bald ablaufende Karten.
- **„Transactions“**: Stornos der Woche mit Grund – plausibel?
- **„Devices“**: Sind alle Geräte bekannt? Unbekanntes Gerät → Inhaberin / Inhaber (**„Revoke“**).
- Karten- und Druckmaterial: genug leere Karten vorrätig?

---

## 13. Übergabe zwischen Schichten

Kurze Notiz an die nächste Schicht (Übergabebuch oder Nachricht):

- [ ] Offene Fälle: gesperrte Karten, verlorene Karten, Gäste, die sich melden
- [ ] Stornos dieser Schicht und Grund
- [ ] Probleme mit Handys, NFC oder WLAN
- [ ] Neue Mitarbeitende, die noch kein Login haben (nie eigenes Login weitergeben)
- [ ] Anzahl leerer Karten

**Handy verloren?** Sofort die Inhaberin / den Inhaber anrufen: **„Devices“** → **„Revoke“** sperrt das Gerät augenblicklich.

---

## 14. Häufige Fragen

**Der Gast will den Rest bar ausbezahlt bekommen.** Das entscheidet die Inhaberin / der Inhaber laut Gutscheinbedingungen. In GiftCard Pro wird eine Auszahlung wie eine Einlösung gebucht.

**Der Betrag ist höher als das Guthaben.** Volles Guthaben einlösen (**„Full balance“**), den Rest bar oder mit Karte kassieren.

**„No connection to the server“.** Nichts wurde gebucht. WLAN prüfen, erneut drücken. GiftCard Pro bucht nie doppelt.

**Karte eines anderen Restaurants.** Wird abgelehnt: „This is not one of our gift cards.“

---

Version 1.0 · Stand: September 2026
