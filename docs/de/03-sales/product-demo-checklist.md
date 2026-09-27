# GiftCard Pro — Checkliste Produktdemo

*Vorher, währenddessen, danach: alles, was für eine reibungslose Vorführung im Restaurant gebraucht wird. Zum Ausdrucken und Abhaken. Gesprächsablauf siehe `restaurant-demo-script.md`.*

---

## 1. Einmalig: Demo-Umgebung einrichten

### Demo-Konto

- [ ] Eigenes Demo-Restaurant angelegt, z. B. „Gasthaus Demo" — nie ein echtes Kundenkonto für Demos verwenden
- [ ] Restaurant-Profil ausgefüllt: Name, Adresse `[Demo-Adresse], 1xxx Wien`, Sprache **de-AT**, Zeitzone Europe/Vienna
- [ ] **Settings → Gift cards:** Default validity **0** (keine Befristung) — so, wie wir es Betrieben empfehlen
- [ ] Teileinlösung und Aufladen aktiviert, öffentliche Guthabenseite aktiviert
- [ ] Markenfarbe gesetzt (Tinte #0F172A oder Demo-Farbe)
- [ ] Team: ein Owner-Login (für Sie), ein Manager, zwei Servicekraft-Logins („Demo Service 1", „Demo Service 2")
- [ ] Geräte umbenannt: „Demo Android", „Demo iPhone", „Demo Laptop"
- [ ] Gästetexte und E-Mail-Vorlagen auf Deutsch geprüft

### Demo-Daten (damit das Dashboard nicht leer ist)

- [ ] 30–50 Karten mit Beträgen zwischen € 25 und € 150, verteilt über die letzten 90 Tage
- [ ] Einlösungen, Teileinlösungen und Aufladungen, damit Diagramme und **Outstanding balance** realistisch aussehen
- [ ] Mindestens je eine Karte im Status **Redeemed**, **Blocked**, **Expired**, **Replaced**, **Inactive**
- [ ] Einige Karten mit erfundenen Beispiel-Kundinnen und -Kunden (eindeutig fiktiv, z. B. „Maria Muster") — keine echten Personen
- [ ] Eine Storno-Buchung im Journal, um **Reverse** zeigen zu können
- [ ] Ein Eintrag im Audit log (z. B. gesperrtes Gerät)

### Demo-Karten (physisch)

- [ ] 5 gedruckte NFC-Karten (NTAG215) im Demo-Design, beschrieben, mit Chip-Seriennummer gebunden
  - „Tisch 7" — € 100 Guthaben (für den Wow-Moment)
  - „Geschenk" — € 50
  - „Gesperrt" — Status Blocked (für die rote Meldung)
  - „Ersetzt" — Status Replaced
  - „Leer" — € 0 Restguthaben
- [ ] 3 unbeschriebene NFC-Karten für **Write NFC tag** live
- [ ] 2 gedruckte QR-Karten (für iPhone-Kamera und als Rückfall)
- [ ] 1 NTAG-424-DNA-Karte, wenn Pro gezeigt wird
- [ ] Karten in einem schönen Etui oder Kuvert — so, wie ein Gast sie bekommen würde

---

## 2. Vor jeder Demo (am Vortag bzw. vor Abfahrt)

### Geräte

- [ ] **Android-Handy** (Chrome aktuell, NFC eingeschaltet), GiftCard Pro am Startbildschirm, als „Demo Service 1" angemeldet
- [ ] **iPhone** (iOS aktuell, NFC-Lesen im Hintergrund funktioniert), GiftCard Pro am Startbildschirm, als „Demo Service 2" angemeldet
- [ ] **Laptop oder Tablet** mit Owner-Login, Browser-Tabs vorbereitet: Dashboard, Gift cards, Transactions, Devices
- [ ] Alle Geräte **voll geladen**, Powerbank und Ladekabel dabei
- [ ] **Mobiler Hotspot** getestet (eigenes Datenvolumen); nie auf das WLAN des Lokals angewiesen sein
- [ ] Nicht stören / Flugmodus für Benachrichtigungen (WLAN und Daten an), Bildschirmsperre auf „nie" oder lang
- [ ] Probedurchlauf: jede Demo-Karte an beiden Handys einmal gelesen; Einlösung und **Reverse** getestet
- [ ] Guthaben der Karte „Tisch 7" wieder auf € 100 gebracht (per **Reload** oder Reverse)

### Unterlagen

- [ ] Ein-Seiten-Übersicht, 2 Exemplare (`one-page-sales-sheet.md` als PDF)
- [ ] Preisblatt mit Kartenpreisen (Richtpreise, „verbindliches Angebot auf Anfrage")
- [ ] ROI-Rechnung, leeres Formular zum Ausfüllen (`roi-explanation.md`, Abschnitt 7)
- [ ] Pilot-Vereinbarung, falls Wien und Plätze frei `[Vorlage Pilotvereinbarung]`
- [ ] Rechtliche Unterlagen: AGB, Auftragsverarbeitungsvertrag, Datenschutzinformation, TOM-Übersicht `[aus 08-legal]`
- [ ] Hinweisblatt Gültigkeit und Registrierkasse mit Vermerk „keine Rechts- oder Steuerberatung"
- [ ] Kurzanleitung Waiter mode für das Team (Tasten auf Englisch, Erklärung auf Deutsch)
- [ ] BHS-Unterlagen, falls das Team oder die Inhaber BHS-sprachig sind
- [ ] Visitenkarten

### Recherche zum Betrieb

- [ ] Name, Adresse, Art des Lokals, ungefähre Größe (Plätze, Service-Team)
- [ ] Website und Social Media: Werden Gutscheine erwähnt? Online-Shop vorhanden?
- [ ] Wer entscheidet? Inhaber/in anwesend?
- [ ] Welche Registrierkasse ist im Einsatz (falls bekannt)?
- [ ] Passender Betriebstyp im Demo-Skript ausgewählt

### Termin und Raum

- [ ] Termin außerhalb der Stoßzeiten (typisch 14:30–17:00 Uhr oder vor dem Mittagsservice), 30 Minuten eingeplant, 15 Minuten Demo
- [ ] Am Vortag kurz bestätigt (Anruf oder Nachricht)
- [ ] 10 Minuten früher vor Ort; Tisch mit Platz für Laptop und zwei Handys, nicht direkt an der Schank
- [ ] Wenn möglich: eine Servicekraft für zwei Minuten dazubitten

---

## 3. Während der Demo

- [ ] Bedarfsfragen gestellt, Antworten wörtlich notiert
- [ ] Wow-Moment: Gegenüber hält die Karte selbst an das Handy
- [ ] Guthabenseite am eigenen Handy des Gegenübers gezeigt (nur Kamera/NFC, keine Anmeldung, keine Installation)
- [ ] Englische Personal-Oberfläche offen angesprochen, deutsche Version für Q4 2026 geplant
- [ ] „Keine Registrierkasse, keine Zahlungsabwicklung, noch kein Online-Verkauf" klar gesagt
- [ ] Gültigkeit „keine Befristung" empfohlen, mit Hinweis „keine Rechtsberatung"
- [ ] Preise korrekt genannt: netto, zzgl. 20 % USt, monatlich kündbar, 0 % Provision
- [ ] Kartenpreise als Richtpreise genannt
- [ ] Keine Funktion versprochen, die nicht in den Unterlagen steht; Roadmap als Planung bezeichnet
- [ ] Nächster Schritt mit Datum vereinbart

### Testkonto direkt vor Ort (wenn gewünscht)

- [ ] Lokalname, rechtlicher Name, UID-Nummer, E-Mail der Inhaberin/des Inhabers aufgenommen
- [ ] Restaurant in der Plattform-Administration angelegt, Owner-Einladung versendet
- [ ] Gegenüber hat die Einladung am eigenen Gerät geöffnet und ein Passwort gesetzt (mind. 12 Zeichen)
- [ ] **Settings → Gift cards:** Default validity auf **0** gesetzt (Werkseinstellung 36 Monate geändert)
- [ ] Mindest-/Höchstwert, Teileinlösung, Aufladen besprochen und eingestellt
- [ ] Mindestens eine Servicekraft eingeladen
- [ ] Erste Karte gemeinsam angelegt (QR-Karte gedruckt oder Demo-Karte als Leihgabe beschrieben)
- [ ] Einrichtungstermin bzw. Kartenbestellung vereinbart
- [ ] Hinweis: Testphase 30 Tage, ohne Kreditkarte, alle Pro-Funktionen

---

## 4. Nach der Demo

### Am selben Tag

- [ ] Follow-up-E-Mail gesendet (Vorlage im Demo-Skript), Anhänge: Ein-Seiten-Übersicht, ROI-Rechnung mit den Zahlen des Betriebs
- [ ] Gesprächsnotizen im CRM bzw. in der Verkaufsliste: Bedarf, Einwände, Entscheider, Kassa, Handys, nächster Schritt
- [ ] Offene Fragen, die Sie nicht beantworten konnten, an hallo@giftcardpro.at weitergeleitet — mit Termin für die Antwort
- [ ] Bei Pilot-Zusage: Platz in der Pilotliste reserviert (max. 10)

### Demo-Umgebung zurücksetzen

- [ ] Geräte, die das Gegenüber verwendet hat, unter **Devices → Revoke** gesperrt
- [ ] Karte „Tisch 7" wieder auf € 100
- [ ] Neu beschriebene Karten notiert oder im Demo-Konto gesperrt
- [ ] Handys und Powerbank laden

### Nachfassen

- [ ] Nach 2 Werktagen: Anruf, falls keine Antwort
- [ ] Bei Testkonto: nach 7 Tagen kurzer Anruf („Wie viele Karten haben Sie schon verkauft? Kommt das Team zurecht?")
- [ ] Nach 25 Tagen: Termin für den Rückblick vor Ende der Testphase, mit echten Zahlen aus dem Dashboard
- [ ] Bei Absage: Grund notieren, freundlich verabschieden, vor Advent bzw. nach Einführung der deutschen Oberfläche erneut melden, wenn das der Grund war

---

Version 1.0 · Stand: September 2026
