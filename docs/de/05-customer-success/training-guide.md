# Schulungsleitfaden GiftCard Pro

*Schulungsprogramm für Servicekräfte, Manager und Inhaberinnen und Inhaber: Lernziele, Ablauf, Übungen, Rollenspiele, Quiz und Teilnahmebestätigung.*

---

## 1. Überblick

| Modul | Zielgruppe | Dauer | Ergebnis |
|---|---|---|---|
| **A – Einlösen am Tisch** | Servicekräfte (Rolle **„Waiter"**) | 15 Minuten | Jede Servicekraft löst eine Karte in unter 5 Sekunden ein und weiß, wann sie eine Karte nicht annimmt. |
| **B – Karten verwalten** | Betriebsleitung, Manager (Rolle **„Manager"**) | 45 Minuten | Karten verkaufen, beschreiben, drucken, stornieren, sperren, ersetzen, übertragen; Tagesabschluss kontrollieren. |
| **C – Zahlen, Regeln, Team** | Inhaberin, Inhaber (Rolle **„Owner"**) | 30 Minuten | Kartenregeln rechtssicher einstellen, Team und Geräte verwalten, Kennzahlen und Exporte für die Steuerberatung verstehen. |

**Sprache der Oberfläche:** Die Mitarbeiter-Oberfläche ist derzeit auf Englisch. In diesem Leitfaden stehen die Schaltflächen daher im englischen Original in Fettdruck, gefolgt von der deutschen Bedeutung, z. B. **„Redeem"** (Einlösen). Eine deutsche Mitarbeiter-Oberfläche ist für Q4 2026 geplant. Alles, was Gäste sehen (Guthabenseite, gedruckte Karte, E-Mails), erscheint bereits auf Deutsch.

**Rechte je Rolle (Standard):**

| Aktion | Waiter | Manager | Owner |
|---|---|---|---|
| Karte scannen und einlösen | ✓ | ✓ | ✓ |
| Karte verkaufen, aufladen, beschreiben, drucken | – | ✓ | ✓ |
| Sperren, entsperren, ersetzen, übertragen, ablaufen lassen | – | ✓ | ✓ |
| Buchung stornieren, Exporte | – | ✓ | ✓ |
| Kundendaten bearbeiten und anonymisieren | – | ✓ | ✓ |
| Prüfprotokoll (**„Audit log"**) ansehen | – | ✓ | ✓ |
| Geräte ansehen | – | ✓ | ✓ |
| Geräte sperren (**„Revoke"**), Team einladen, Einstellungen, API-Tokens | – | – | ✓ |

### Vorbereitung durch die Trainerin bzw. den Trainer

- [ ] Alle Teilnehmenden haben eine eigene Einladung angenommen und ein eigenes Passwort gesetzt (Einladungslink 72 Stunden gültig).
- [ ] Mindestens **drei Testkarten** à € 5 angelegt (**„New gift card"**), beschrieben bzw. als QR-Karte gedruckt. Im Feld **„Internal notes"** den Vermerk „TESTKARTE Schulung" eintragen.
- [ ] Je ein Android-Handy (Chrome, NFC ein) und ein iPhone (XS oder neuer) bereit, auf beiden ist die Web-App am Startbildschirm installiert.
- [ ] Ausgedruckte Kurzanleitung für Servicekräfte (Abschnitt 2.4) in ausreichender Zahl.
- [ ] Nach der Schulung: Testbuchungen stornieren, Testkarten sperren (**„Block card"**, Grund „Suspicious use" oder eigener Text „Schulung").

---

## 2. Modul A – Servicekräfte (15 Minuten)

### 2.1 Lernziele

Nach diesem Modul kann jede Servicekraft:

1. sich auf dem Diensthandy anmelden und den Kellner-Modus (**„Waiter mode"**) öffnen,
2. eine Karte per NFC, QR-Code oder Kartennummer aufrufen,
3. einen Teilbetrag und das volle Guthaben einlösen,
4. die fünf wichtigsten Meldungen erkennen und richtig reagieren,
5. erklären, warum man Anmeldedaten nie teilt.

### 2.2 Ablauf

| Minute | Inhalt | Methode |
|---|---|---|
| 0–2 | Warum Gutscheinkarten? Die Karte trägt kein Geld, nur einen sicheren Link. Jede Buchung trägt Ihren Namen. | Kurzvortrag |
| 2–5 | Anmelden, **„Keep me signed in on this device"** (auf diesem Gerät angemeldet bleiben), Kellner-Modus. Android: einmal **„Scan card"** drücken. iPhone: Karte oben an das Handy halten, Mitteilung antippen. | Vorzeigen |
| 5–10 | Übungen A1–A3 (siehe unten) | Jede Person selbst |
| 10–13 | Meldungen und Reaktion (Tabelle 2.4), Rollenspiel 1 | Rollenspiel |
| 13–15 | Quiz (5 Fragen), Fragen | Mündlich |

### 2.3 Übungen

**Übung A1 – Teilbetrag einlösen (Android)**
1. **„Scan card"** (Karte scannen) drücken. Die Karte flach an die obere Rückseite des Handys halten, etwa 1 Sekunde.
2. Auf dem Ziffernfeld `2` `5` `0` tippen → € 2,50.
3. **„Redeem € 2,50"** (€ 2,50 einlösen) drücken.
4. Grüner Haken: **„Remaining balance"** (Restguthaben) dem Gast nennen.
5. Nächste Karte direkt antippen oder **„Next card"** (Nächste Karte). Nach 8 Sekunden kehrt die App von selbst zurück.

**Übung A2 – iPhone oder QR-Code**
1. iPhone entsperren, Karte an die Oberkante halten, die Mitteilung antippen – die Karte öffnet sich im Kellner-Modus.
2. Alternativ **„Scan QR code"** (QR-Code scannen) und die Kamera auf die Rückseite der Karte richten.
3. **„Full balance"** (Volles Guthaben) drücken, dann **„Redeem"**.

**Übung A3 – Kartennummer eintippen**
1. **„Card number"** (Kartennummer) wählen.
2. Die 16 Ziffern unter dem QR-Code eintippen, **„Find card"** (Karte suchen).
3. € 1 einlösen.

> Ziel: Jede Übung in unter 5 Sekunden ab dem Antippen der Karte.

### 2.4 Kurzanleitung zum Ausdrucken (für die Kassa)

| Die App zeigt | Bedeutung | Was Sie tun |
|---|---|---|
| **„More than the balance. Redeem € X and collect the rest otherwise."** | Rechnung höher als Guthaben | **„Full balance"** einlösen, den Rest bar oder mit Karte kassieren. |
| **„This card is blocked"** (rot) | Karte gesperrt | Karte nicht annehmen. Manager holen. |
| **„This card was replaced … Ask the guest for the new card."** (rot) | Karte wurde ersetzt | Nach der neuen Karte fragen. Alte Karte nicht annehmen. |
| **„This card has expired."** | Karte abgelaufen | Nicht einlösen. Manager holen – der Gast hat eventuell trotzdem Anspruch. |
| **„This card has no balance left."** | Guthaben € 0 | Freundlich mitteilen, Rechnung normal kassieren. |
| **„This card is not activated yet."** | Karte noch nicht aktiviert | Manager holen (Aktivierung im Dashboard). |
| **„No card with this number."** | Tippfehler | Ziffern prüfen und neu eingeben. |
| **„This is not one of our gift cards."** | Fremde oder unbekannte Karte | Nicht annehmen. |
| **„No connection to the server."** | Kein Internet | WLAN prüfen, erneut drücken. **Es wurde nichts gebucht, die App bucht nie doppelt.** |

**Wichtig:** Sale (Verkauf) und Einlösung müssen zusätzlich in der Registrierkasse gebucht werden – so, wie es Ihre Betriebsleitung festgelegt hat. GiftCard Pro ist keine Registrierkasse.

### 2.5 Rollenspiele

**Rollenspiel 1 – Gast mit gesperrter Karte**
*Situation:* Der Gast reicht eine Karte, die App zeigt rot **„This card is blocked: Reported lost"**.
*Richtige Reaktion:* ruhig bleiben, keine Vorwürfe. „Diese Karte ist bei uns gesperrt. Ich hole kurz meine Kollegin, sie klärt das mit Ihnen." Manager prüft in der Kartenhistorie, wer wann gesperrt hat. Ist der Gast rechtmäßiger Besitzer (z. B. Karte wiedergefunden), kann der Manager entsperren (**„Unblock"**) oder eine Ersatzkarte ausstellen.
*Fehler, die vermieden werden:* Betrag trotzdem abziehen „auf Vertrauen", Karte einbehalten ohne Rücksprache, Diskussion am Tisch.

**Rollenspiel 2 – Karte wird nicht gefunden**
*Situation:* Nach Eintippen der Nummer erscheint **„No card with this number. Check the digits and try again."**
*Richtige Reaktion:* Ziffern in Viererblöcken laut mitlesen, erneut eingeben. Erscheint beim Scannen **„This is not one of our gift cards."**, fragen: „Könnte die Karte von einem anderen Lokal sein?" Nicht mehr als zwei, drei Versuche – nach vielen Fehlversuchen bremst die App (**„Too many failed card lookups. Please wait a moment and try again."**).

**Rollenspiel 3 – Betrag höher als Guthaben**
*Situation:* Rechnung € 68,40, Guthaben € 50.
*Richtige Reaktion:* „Auf Ihrer Karte sind noch € 50. Ich buche diese ab; die restlichen € 18,40 – bar oder mit Karte?" → **„Full balance"**, **„Redeem € 50,00"**, Rest kassieren.

### 2.6 Quiz Modul A (mit Lösungen)

1. *Was ist auf der Karte gespeichert?* – Nur ein sicherer Link, kein Geld und keine persönlichen Daten.
2. *Die App meldet „No connection to the server". Wurde gebucht?* – Nein. Verbindung prüfen und erneut drücken; doppelt gebucht wird nie.
3. *Die Karte ist rot als „replaced" markiert. Was tun?* – Nicht annehmen, den Gast nach der neuen Karte fragen.
4. *Darf ich mich mit dem Login einer Kollegin anmelden?* – Nein. Jede Buchung wird mit Name, Zeit und Gerät gespeichert.
5. *Wie tippen Sie € 7,00 ein?* – `7` `0` `0`.

---

## 3. Modul B – Manager (45 Minuten)

### 3.1 Lernziele

1. Eine Karte verkaufen, mit Kundendaten anlegen und aktivieren.
2. NFC-Karte mit Android beschreiben oder QR-Karte drucken.
3. Am Schreibtisch einlösen und aufladen.
4. Eine Fehlbuchung stornieren, eine Karte sperren, entsperren und ersetzen, Guthaben übertragen.
5. Kartenliste und Buchungsjournal durchsuchen, CSV exportieren.
6. Sicherheitswarnungen im Prüfprotokoll erkennen.

### 3.2 Ablauf

| Minute | Inhalt |
|---|---|
| 0–5 | Rundgang: **Dashboard**, **Gift cards** (Karten), **Transactions** (Buchungen), **Customers** (Kunden), **Devices** (Geräte), **Audit log** (Prüfprotokoll) |
| 5–15 | Übung B1 – Karte verkaufen und beschreiben/drucken |
| 15–20 | Übung B2 – Einlösen und Aufladen am Schreibtisch |
| 20–30 | Übung B3 – Storno, Sperren, Entsperren |
| 30–37 | Übung B4 – Ersetzen und Übertragen |
| 37–42 | Suche, Filter, **„Export CSV"**, Prüfprotokoll |
| 42–45 | Quiz und Fragen |

### 3.3 Übungen

**Übung B1 – Karte verkaufen**
1. **Gift cards → „New gift card"** (Neue Gutscheinkarte).
2. Wert wählen (Chips € 25/50/75/100/150) oder frei eingeben (**„Amount"**).
3. **„Valid until"** (Gültig bis): Standard aus den Einstellungen übernehmen – empfohlen „ohne Ablauf", siehe Modul C.
4. **„Customer"**: **„Anonymous"** (anonym), **„Existing"** (bestehender Kunde) oder **„New customer"** mit Name, E-Mail, Telefon. Mit E-Mail erhält der Kunde eine Kaufbestätigung (wenn Kunden-E-Mails eingeschaltet sind).
5. **„Recipient name"** (Name des Beschenkten, wird auf die Karte gedruckt), **„Card type"** (Kartentyp, meist NTAG215), **„Activate immediately"** (sofort aktivieren) eingeschaltet lassen.
6. **„Create card"** (Karte anlegen). Es erscheint **„Card created"**.
7. Android mit Chrome: **„Write NFC tag"** (NFC-Chip beschreiben) → leere Karte an die Rückseite halten. Sonst: **„Print"** (Drucken) für eine QR-Karte.
8. Verkauf in der Registrierkasse buchen.

**Übung B2 – Am Schreibtisch einlösen und aufladen**
Karte in **Gift cards** suchen (Nummer, Kunde, Empfänger oder Notiz), öffnen, **„Redeem"** (Einlösen) € 3; dann **„Reload"** (Aufladen) € 10. Hinweis: Aufladen ist nur möglich, wenn es in den Einstellungen erlaubt ist.

**Übung B3 – Stornieren, Sperren, Entsperren**
1. In der Kartenhistorie oder unter **Transactions** bei der Einlösung ↺ **„Reverse"** (Stornieren) wählen, Grund „Wrong amount". Die Korrektur erscheint als neue Zeile; nichts wird gelöscht.
2. **⋯ → „Block card"** (Karte sperren), Grund **„Reported stolen"**. Mit dem Diensthandy scannen: rote Meldung.
3. **⋯ → „Unblock"** (Entsperren).

**Übung B4 – Ersetzen und Übertragen**
1. **⋯ → „Replace lost card"** (Verlorene Karte ersetzen), Grund **„Lost"**, **„Issue replacement"** (Ersatz ausstellen). Neue Nummer, neuer Link, Guthaben wandert mit; die alte Karte ist sofort ungültig. Die App öffnet die neue Karte direkt zum Beschreiben.
2. Alte Karte scannen: **„This card was replaced …"**.
3. Zweite Testkarte öffnen, **⋯ → „Transfer balance"** (Guthaben übertragen), **„Target card number"** (Zielkartennummer) eingeben, Betrag leer lassen = volles Guthaben.

### 3.4 Rollenspiele

**Rollenspiel 4 – Gast hat seine Karte verloren**
Der Gast nennt Namen und Kaufdatum. Manager sucht unter **Gift cards** nach Kunde oder Empfänger. Findet er die Karte eindeutig, **„Replace lost card"**. Findet er sie nicht eindeutig, keine Ersatzkarte ausstellen – Belege (Kaufbestätigung per E-Mail, Kassabeleg) erbitten.

**Rollenspiel 5 – Servicekraft hat falschen Betrag gebucht**
€ 42 statt € 24 gebucht. Buchung stornieren (**„Reverse"**, Grund „Wrong amount"), dann die Karte im Kellner-Modus mit € 24 neu einlösen. Registrierkasse entsprechend korrigieren.

### 3.5 Quiz Modul B (mit Lösungen)

1. *Wie korrigieren Sie eine Fehlbuchung?* – Über **„Reverse"**; es entsteht eine Gegenbuchung, die Originalzeile bleibt.
2. *Was passiert mit der alten Karte bei „Replace lost card"?* – Sie funktioniert sofort nicht mehr; das Guthaben liegt auf der neuen Karte mit neuer Nummer.
3. *Wann sperren statt ersetzen?* – Sperren bei Verdacht oder bis zur Klärung (umkehrbar); ersetzen, wenn der Gast eine neue Karte bekommen soll.
4. *Kann man eine Buchung einer ersetzten oder abgelaufenen Karte stornieren?* – Nein (**„Transactions of replaced or expired cards cannot be reversed."**).
5. *Wo sehen Sie, wer eine Karte gesperrt hat?* – In der Kartenhistorie und im **„Audit log"**.
6. *Mit welchem Gerät beschreiben Sie eine Karte in einem Schritt?* – Android-Handy mit Chrome.

---

## 4. Modul C – Inhaberinnen und Inhaber (30 Minuten)

### 4.1 Lernziele

1. Kartenregeln unter **Settings → Gift cards** bewusst einstellen, insbesondere die Gültigkeit.
2. Team einladen, Rollen vergeben, Personen deaktivieren; Geräte benennen und sperren.
3. Die vier Kennzahlen verstehen und für Buchhaltung und Haftung nutzen.
4. Exporte für die Steuerberatung erstellen.
5. Kunden-E-Mails und Datenschutzfunktionen kennen.

### 4.2 Ablauf

| Minute | Inhalt |
|---|---|
| 0–8 | **Settings → Gift cards**: Mindest-/Höchstwert (Standard € 5 / € 1.000), maximales Kartenguthaben (€ 2.000), maximale Einzeleinlösung, **„Default validity (months)"**, **„Max. redemptions per card per hour"** (Standard 10), Aufladen, Teileinlösung, öffentliche Guthabenabfrage, Klonschutz, Kunden-E-Mails, Markenfarbe, E-Mail-Fußzeile |
| 8–14 | **Team → „Invite"**, Rollen, **„Resend invitation"**, **„Deactivate"**; **Devices**: umbenennen, **„Revoke"** |
| 14–22 | **Dashboard**: **„Outstanding balance"**, **„Revenue this month"**, **„Redeemed this month"**, **„Cards sold"**; Diagramme |
| 22–27 | **„Export CSV"** in **Gift cards** und **Transactions**; Registrierkasse und Steuerberatung |
| 27–30 | Quiz, offene Fragen |

### 4.3 Rechtshinweis Gültigkeit (Pflichtteil)

Bezahlte Gutscheine verjähren in Österreich grundsätzlich erst nach 30 Jahren (§ 1478 ABGB). Laut OGH ist eine pauschale Befristung auf 3 Jahre oder weniger in Allgemeinen Geschäftsbedingungen in der Regel gröblich benachteiligend (§ 879 Abs 3 ABGB) und damit unwirksam. Die Werkseinstellung von GiftCard Pro ist 36 Monate. **Empfehlung: „Default validity (months)" auf 0 (kein Ablauf) setzen**, außer Ihre Rechtsberatung genehmigt ein anderes Modell. Läuft eine Karte ab, bucht GiftCard Pro das Restguthaben aus; der Gast kann trotzdem einen Anspruch haben – dann eine Ersatzkarte ausstellen oder Guthaben übertragen. Eine Änderung der Werkseinstellung ist geplant.
*Keine Rechtsberatung – mit Steuerberatung bzw. Rechtsanwältin oder Rechtsanwalt prüfen.*

### 4.4 Übungen

**Übung C1 – Kartenregeln:** **„Default validity (months)"** prüfen und nach Rücksprache auf 0 setzen; **„Partial redemption"** (Teileinlösung) und **„Allow reloading"** (Aufladen erlauben) bewusst festlegen.
**Übung C2 – Team:** Eine Testperson mit Rolle **„Waiter"** einladen (**„Send invitation"**), Einladung erneut senden, danach deaktivieren.
**Übung C3 – Geräte:** Das Schulungshandy unter **Devices** mit dem Stift in „Bar Schulung" umbenennen, **„Revoke"** (Sperren) bestätigen, mit dem Handy scannen (Meldung **„This device has been revoked. Please contact your manager."**), dann **„Restore"** (Wiederherstellen).
**Übung C4 – Export:** **Transactions** nach Zeitraum filtern, **„Export CSV"**, Datei in Excel öffnen.

### 4.5 Rollenspiel 6 – Steuerberaterin fragt nach offenen Gutscheinen

„Wie hoch sind die offenen Gutscheine zum 31. Dezember?" → **„Outstanding balance"** am Stichtag notieren bzw. Kartenliste als CSV exportieren (Guthaben je Karte). Buchungsjournal für den Zeitraum exportieren. Hinweis: Die umsatzsteuerliche Behandlung (Einzweck- oder Mehrzweckgutschein) legt die Steuerberatung fest.

### 4.6 Quiz Modul C (mit Lösungen)

1. *Welche Kennzahl zeigt Ihre offene Verbindlichkeit?* – **„Outstanding balance"**.
2. *Was bedeutet „Default validity" = 0?* – Neue Karten laufen nicht ab.
3. *Ein Diensthandy ist gestohlen. Was tun?* – **Devices → „Revoke"**; wirkt sofort.
4. *Wie lange ist eine Einladung gültig?* – 72 Stunden; danach **„Resend invitation"**.
5. *Ersetzt GiftCard Pro die Registrierkasse?* – Nein. Verkauf und Einlösung werden zusätzlich in der Registrierkasse gebucht.
6. *Was bewirkt „Anonymize" bei einem Kunden?* – Name, E-Mail, Telefon und Notizen werden entfernt; Karten, Guthaben und Buchungen bleiben.

---

## 5. Teilnahmebestätigung

> **Teilnahmebestätigung**
>
> [Vorname Nachname] hat am [Datum] die Schulung **GiftCard Pro – Modul [A / B / C]: [Titel]** im Lokal [Name des Lokals] erfolgreich abgeschlossen.
>
> Inhalte: [Lernziele des Moduls in Stichworten]
> Praktische Übungen: Testeinlösung, Storno, Sperren, Ersetzen – durchgeführt.
> Quiz: [x] von [y] Fragen richtig.
>
> [Ort], am [Datum]
>
> ______________________ ______________________
> Trainerin / Trainer Teilnehmerin / Teilnehmer
>
> [Firmenname] · [Anschrift], 1xxx Wien

---

## 6. Train-the-Trainer: neue Mitarbeiterinnen und Mitarbeiter einschulen

Die Schulung neuer Servicekräfte übernimmt in der Regel eine erfahrene Kollegin oder ein Manager im Lokal.

**Vor dem ersten Dienst**
1. Inhaberin bzw. Inhaber lädt die Person mit eigener E-Mail-Adresse ein (**Team → „Invite"**, Rolle **„Waiter"**).
2. Die neue Person setzt ihr Passwort selbst (mindestens 12 Zeichen, Groß- und Kleinbuchstaben, eine Ziffer).
3. Anmeldung einmal am Diensthandy – das Gerät wird automatisch registriert.

**Im ersten Dienst (10 Minuten in einer ruhigen Phase)**
- Übungen A1–A3 mit einer Testkarte; Kurzanleitung 2.4 gemeinsam lesen.
- Die erste echte Einlösung begleitet eine erfahrene Kraft.

**Tipps für Trainerinnen und Trainer**
- Zeigen, nicht erklären: jede Person tippt selbst.
- Die drei Sätze, die jede Servicekraft kennen muss: „Ich buche das Guthaben ab." – „Diese Karte ist gesperrt, ich hole kurz die Kollegin." – „Es wurde nichts gebucht, ich versuche es noch einmal."
- Testkarten deutlich kennzeichnen und nach der Schulung sperren.
- Wer das Lokal verlässt: am letzten Tag **„Deactivate"** (Deaktivieren). Buchungen bleiben mit dem Namen erhalten.
- Fragen, die Sie nicht beantworten können: support@giftcardpro.at.

**Materialien:** Kurzanleitung (Abschnitt 2.4), Video „Einlösen am Tisch" (siehe Videoskripte), Wissensdatenbank.

---

Version 1.0 · Stand: September 2026
