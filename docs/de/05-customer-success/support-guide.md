# Support-Leitfaden GiftCard Pro

*Supportmodell für Kundinnen und Kunden sowie internes Handbuch für das Support-Team: Kanäle, Zeiten, Reaktionsziele, Prioritäten, Eskalation, Statuskommunikation, Antwortvorlagen und Tonalität.*

---

## 1. Supportkanäle

| Kanal | Tarif | Erreichbar | Verwendung |
|---|---|---|---|
| **E-Mail:** support@giftcardpro.at | alle Tarife | Eingang rund um die Uhr, Bearbeitung zu Supportzeiten | Standardkanal für alle Anliegen; jede Anfrage erhält eine Ticketnummer |
| **Telefon:** [Telefon] | Pro, Gruppe | zu Supportzeiten | dringende Anliegen, Fragen während des Service |
| **Persönlicher Ansprechpartner** | Gruppe | laut Vertrag | zentrale Abstimmung für alle Standorte |
| **Datenschutz:** datenschutz@giftcardpro.at | alle | – | Auskunft, Auftragsverarbeitung, DSGVO-Anfragen |
| **Sicherheit:** security@giftcardpro.at | alle | – | Meldung von Sicherheitslücken, Verdacht auf Missbrauch |
| **Vertrieb:** hallo@giftcardpro.at | – | – | Tarife, Kartenbestellungen, Angebote |

Es gibt derzeit **keinen Chat in der App** und keine Supportfunktion innerhalb der Anwendung. Anfragen bitte immer per E-Mail oder (Pro/Gruppe) telefonisch.

## 2. Supportzeiten

**Montag bis Freitag, 9:00–17:00 Uhr (Wien)**, ausgenommen österreichische gesetzliche Feiertage (Neujahr, Heilige Drei Könige, Ostermontag, Staatsfeiertag 1. Mai, Christi Himmelfahrt, Pfingstmontag, Fronleichnam, Mariä Himmelfahrt, Nationalfeiertag, Allerheiligen, Mariä Empfängnis, Christtag, Stefanitag). 24. und 31. Dezember: [Regelung festlegen, z. B. 9:00–12:00 Uhr].

Außerhalb der Supportzeiten werden E-Mails am nächsten Werktag bearbeitet. Anfragen der Priorität P1 werden außerhalb der Supportzeiten nach bestem Bemühen bearbeitet – eine Rufbereitschaft ist nur Bestandteil individueller Gruppe-Verträge.

## 3. Reaktionsziele je Tarif

„Reaktion" bedeutet: eine persönliche, inhaltliche Erstantwort (keine automatische Eingangsbestätigung).

| Tarif | Reaktionsziel | Kanäle |
|---|---|---|
| **Start** | innerhalb von **1 Werktag** | E-Mail |
| **Pro** | innerhalb von **4 Arbeitsstunden** (Priorität in der Warteschlange) | E-Mail, Telefon |
| **Gruppe** | laut individuellem Vertrag/SLA | E-Mail, Telefon, zentraler Ansprechpartner |
| **Testphase (30 Tage)** | wie Pro | E-Mail |
| **Pilotlokale** | wie Pro, zusätzlich tägliche Check-ins in Woche 1 | E-Mail, Telefon, vor Ort |

Die Verfügbarkeit der Plattform ist mit **99,5 % pro Monat als Zielwert** angesetzt; im Tarif Start ist das keine Garantie, im Tarif Gruppe kann ein vertragliches SLA vereinbart werden.

## 4. Prioritäten (Schweregrade)

Die Priorität setzt das Support-Team nach der Auswirkung, nicht nach dem Tonfall der Anfrage.

| Stufe | Definition | Beispiele | Interne Ziele (Erstreaktion / Update-Intervall) |
|---|---|---|---|
| **P1 – kritisch** | Dienst nicht verfügbar oder **Geldbuchungen fehlerhaft**; mehrere Lokale oder ein Lokal im laufenden Service vollständig betroffen | App nicht erreichbar; Einlösungen schlagen bei allen Geräten fehl; Guthaben stimmt nicht mit dem Buchungsjournal überein; Verdacht auf Doppelbuchung; Verdacht auf Datenzugriff durch Unbefugte | sofort, spätestens 1 Arbeitsstunde / stündlich |
| **P2 – hoch** | Wichtige Funktion für ein Lokal gestört, Umgehung möglich | NFC-Lesen fällt auf allen Android-Geräten aus (QR funktioniert); Einladungs- oder Kunden-E-Mails kommen generell nicht an; Inhaberin ausgesperrt | 4 Arbeitsstunden / täglich |
| **P3 – normal** | Einzelne Person oder einzelnes Gerät betroffen, oder Frage zur Bedienung | Kellnerin kann sich nicht anmelden; Karte lässt sich nicht beschreiben; CSV öffnet falsch | laut Tarif / bei Änderung |
| **P4 – niedrig** | Wunsch, Verbesserungsvorschlag, allgemeine Information | neue Funktion, Textänderung, Frage zum Fahrplan | laut Tarif / keine laufenden Updates |

Hinweis zu P1 „Geldbuchungen": Jede Guthabenänderung ist technisch atomar, idempotent und im unveränderlichen Buchungsjournal erfasst (Summe der Buchungen = Guthaben). Ein vermuteter Buchungsfehler ist trotzdem immer P1, bis er geprüft ist.

Die Zielwerte gelten innerhalb der Supportzeiten und sind interne Ziele, keine vertragliche Zusage (Ausnahme: Gruppe-Vertrag mit SLA).

## 5. Was eine gute Anfrage enthält

Bitte teilen Sie uns mit:

1. **Name des Lokals** und Ihre Rolle (Owner, Manager, Waiter).
2. **Was ist passiert, was haben Sie erwartet?**
3. **Wann** (Datum, ungefähre Uhrzeit)?
4. **Kartennummer** (16 Ziffern) – bitte nur die Kartennummer, keine Kundendaten.
5. **Gerät und Browser** (z. B. „Samsung Galaxy A54, Chrome" oder „iPhone 13, Safari"), Name des Geräts aus **Devices**.
6. **Genauer Wortlaut der Meldung**, am besten ein Bildschirmfoto.
7. **Wie viele Personen oder Geräte** sind betroffen, läuft der Service weiter?

**Senden Sie uns nie Passwörter, API-Tokens oder vollständige Kundenlisten per E-Mail.** Wir fragen nie nach Ihrem Passwort.

## 6. Eskalationspfad

| Stufe | Wer | Wann |
|---|---|---|
| 0 | Lokal intern: Servicekraft → Manager → Inhaberin bzw. Inhaber | bei jeder Meldung in der App, die die Kurzanleitung nicht löst |
| 1 | Support (First Level): support@ bzw. Telefon | Bedienfragen, Konto, E-Mails, Geräte, Karten |
| 2 | Technik (Second Level) | Fehler im System, Datenprüfung, Auffälligkeiten im Buchungsjournal, Verdacht auf geklonte Karten |
| 3 | Geschäftsführung [Geschäftsführung] | P1 länger als 2 Stunden; Sicherheitsvorfall; Datenschutzvorfall; Beschwerde über den Support; vertragliche Fragen |

**Sicherheits- und Datenschutzvorfälle** werden immer sofort auf Stufe 2 und 3 eskaliert. Bei einer Verletzung des Schutzes personenbezogener Daten informiert der Anbieter als Auftragsverarbeiter das Lokal (Verantwortlicher) ohne unangemessene Verzögerung, damit dieses seine Meldepflicht (72 Stunden, Art. 33 DSGVO) wahrnehmen kann.

**Kundenseitige Eskalation:** Sind Sie mit der Bearbeitung nicht zufrieden, schreiben Sie „Eskalation" in den Betreff oder verlangen Sie am Telefon die Teamleitung.

## 7. Statuskommunikation

| Situation | Kanal | Zeitpunkt |
|---|---|---|
| Geplante Wartung | **Wartungshinweis-Banner** in der App (für alle angemeldeten Personen sichtbar, gesetzt unter Plattform-Systemeinstellungen) + E-Mail an Inhaberinnen und Inhaber | mindestens 3 Werktage vorher; Wartung nur außerhalb typischer Servicezeiten (z. B. Dienstag–Donnerstag, 03:00–06:00 Uhr) und nie im Dezember an Wochenenden |
| Ungeplante Störung (P1) | Banner (sofern die App erreichbar ist) + E-Mail an betroffene Inhaberinnen und Inhaber; Pro/Gruppe zusätzlich telefonisch | erste Information binnen 1 Stunde, dann stündlich |
| Störung behoben | Banner entfernen, E-Mail „behoben" mit Ursache und Folgen | sofort nach Behebung |
| Nachbericht (P1) | E-Mail an betroffene Lokale | innerhalb von 5 Werktagen |

Eine öffentliche Statusseite gibt es derzeit nicht.

**Vorlage Banner (kurz, max. eine Zeile):**
„Geplante Wartung am [Datum], [Uhrzeit von–bis]. GiftCard Pro ist in dieser Zeit nicht erreichbar. Bitte Gutscheine in dieser Zeit notieren und danach buchen."

## 8. Internes Support-Playbook

### 8.1 Grundregeln

1. Jede Anfrage bekommt eine Ticketnummer und eine Priorität.
2. Vor der Antwort prüfen: Tarif, Rolle der anfragenden Person, betroffene Karte bzw. Gerät im Prüfprotokoll.
3. **Zugriff auf Daten eines Lokals** („Open restaurant" in der Plattformverwaltung) nur, wenn für die Lösung nötig, und im Ticket vermerken. Jeder Zugriff wird protokolliert und ist für das Lokal sichtbar markiert.
4. **Nie** im Namen des Lokals Guthaben buchen, stornieren oder Karten ersetzen, ohne schriftlichen Auftrag der Inhaberin bzw. des Inhabers.
5. Kartennummern in E-Mails nur maskiert wiederholen (z. B. „Karte ••••  6488").
6. Rechtliche und steuerliche Fragen: allgemeine Information geben, immer mit dem Hinweis „keine Rechts- oder Steuerberatung".
7. Ticket erst schließen, wenn das Lokal die Lösung bestätigt hat oder 3 Werktage ohne Rückmeldung vergangen sind (mit Ankündigung).

### 8.2 Die 10 häufigsten Anfragen – Antwortvorlagen

**V1 – Konto gesperrt nach Fehlversuchen**
> Guten Tag [Name],
> nach 10 falschen Passworteingaben sperrt GiftCard Pro das Konto aus Sicherheitsgründen für 15 Minuten. Bitte warten Sie diese Zeit ab und melden Sie sich dann erneut an. Falls Sie Ihr Passwort nicht mehr wissen, nutzen Sie auf der Anmeldeseite **„Forgot password?"** (Passwort vergessen). Der Link in der E-Mail ist 60 Minuten gültig.
> Freundliche Grüße, [Name], GiftCard Pro Support

**V2 – Einladung abgelaufen**
> Guten Tag [Name],
> Einladungslinks sind 72 Stunden gültig. Ihre Inhaberin bzw. Ihr Inhaber kann Ihnen unter **Team → ⋯ → „Resend invitation"** (Einladung erneut senden) einen neuen Link schicken. Bitte prüfen Sie auch den Spam-Ordner.
> Freundliche Grüße, …

**V3 – NFC funktioniert auf Android nicht**
> Guten Tag [Name],
> bitte prüfen Sie drei Punkte: 1. NFC ist in den Systemeinstellungen des Handys eingeschaltet. 2. GiftCard Pro ist in **Chrome** geöffnet (andere Browser unterstützen das Lesen von NFC-Karten nicht). 3. Chrome darf NFC für app.giftcardpro.at verwenden (Website-Einstellungen → NFC → Zulassen). Danach im Kellner-Modus einmal **„Scan card"** drücken. Bis dahin funktioniert **„Scan QR code"** jederzeit.
> Freundliche Grüße, …

**V4 – iPhone liest die Karte nicht**
> Guten Tag [Name],
> iPhones ab Modell XS lesen die Karte, wenn der Bildschirm eingeschaltet und entsperrt ist: Karte an die Oberkante der Rückseite halten und die Mitteilung antippen. Die Kamera-App darf dabei nicht geöffnet sein, der Flugmodus muss aus sein. Bei älteren iPhones verwenden Sie bitte **„Scan QR code"** oder **„Card number"**. Zeigt das iPhone gar nichts an, ist die Karte möglicherweise noch nicht beschrieben – bitte senden Sie uns die Kartennummer.
> Freundliche Grüße, …

**V5 – „No connection to the server" – wurde gebucht?**
> Guten Tag [Name],
> bei dieser Meldung wurde **nichts gebucht**. Sie können die Einlösung gefahrlos wiederholen, sobald die Verbindung wieder steht – GiftCard Pro bucht nie doppelt, auch nicht bei mehrfachem Drücken. Sie können jede Buchung in der Kartenhistorie kontrollieren.
> Freundliche Grüße, …

**V6 – Falscher Betrag eingelöst**
> Guten Tag [Name],
> eine Manager- oder Inhaberperson öffnet die Karte (oder **Transactions**), wählt bei der betreffenden Buchung ↺ **„Reverse"** (Stornieren) und einen Grund, z. B. „Wrong amount". Das Guthaben wird durch eine Gegenbuchung wiederhergestellt; die ursprüngliche Buchung bleibt sichtbar. Danach den richtigen Betrag neu einlösen und die Registrierkasse entsprechend korrigieren.
> Freundliche Grüße, …

**V7 – Gast hat Karte verloren**
> Guten Tag [Name],
> öffnen Sie die Karte (Suche nach Kunde, Empfänger oder Nummer) und wählen Sie **⋯ → „Replace lost card"**, Grund „Lost". Das Restguthaben wandert auf eine neue Karte mit neuer Nummer, die alte Karte funktioniert sofort nicht mehr. Stellen Sie eine Ersatzkarte bitte nur aus, wenn die Karte eindeutig dem Gast zugeordnet werden kann.
> Freundliche Grüße, …

**V8 – Kunde hat keine E-Mail erhalten**
> Guten Tag [Name],
> bitte prüfen Sie: 1. Ist unter **Settings → Gift cards** die Option **„Customer e-mails"** eingeschaltet? 2. Ist beim Kunden eine E-Mail-Adresse hinterlegt (anonyme Karten erhalten keine E-Mail)? 3. Liegt die E-Mail im Spam-Ordner des Gastes? Wenn alles stimmt, senden Sie uns bitte Kartennummer und Uhrzeit des Verkaufs, wir prüfen den Versand.
> Freundliche Grüße, …

**V9 – CSV sieht in Excel falsch aus**
> Guten Tag [Name],
> der Export verwendet Strichpunkt als Trennzeichen und – bei der Einstellung Deutsch (Österreich) – das Dezimalkomma. Prüfen Sie unter **Settings → Restaurant** das Feld **„Language & number format"**. Steht dort Englisch, werden Beträge mit Dezimalpunkt exportiert. Alternativ in Excel über **Daten → Aus Text/CSV** importieren und Trennzeichen „Semikolon" wählen.
> Freundliche Grüße, …

**V10 – Handy verloren oder gestohlen**
> Guten Tag [Name],
> die Inhaberin bzw. der Inhaber sperrt das Gerät unter **Devices → „Revoke"**. Ab diesem Moment kann das Gerät keine Karten mehr scannen oder einlösen. Falls sich jemand mit einem persönlichen Konto auf dem Gerät angemeldet hatte, empfehlen wir zusätzlich ein neues Passwort – dadurch werden alle anderen Sitzungen abgemeldet.
> Freundliche Grüße, …

### 8.3 Makros (Ticketsystem)

| Makro | Wirkung |
|---|---|
| `#eingang` | Automatische Bestätigung: „Wir haben Ihre Anfrage [Ticketnummer] erhalten und melden uns innerhalb von [Reaktionsziel laut Tarif]." |
| `#info-fehlt` | Bittet um die Angaben aus Abschnitt 5 (Lokal, Zeit, Kartennummer, Gerät, Meldung, Bildschirmfoto). |
| `#p1-start` | Setzt P1, informiert Technik und Geschäftsführung, sendet dem Lokal: „Wir arbeiten mit Priorität daran. Nächste Information spätestens um [Uhrzeit]." |
| `#p1-update` | Zwischenstand-Vorlage: Stand, nächste Schritte, nächste Information um [Uhrzeit]. |
| `#geloest` | „Das Anliegen ist gelöst: [kurze Zusammenfassung]. Falls noch etwas offen ist, antworten Sie einfach auf diese E-Mail." |
| `#wunsch` | Dank für den Vorschlag, Aufnahme in die Wunschliste, keine Terminzusage. |
| `#recht` | Allgemeine Information + „Keine Rechts- oder Steuerberatung – bitte mit Ihrer Steuerberatung bzw. Rechtsanwältin oder Rechtsanwalt prüfen." |
| `#sicherheit` | Eskalation an Technik und security@, Lokal um Sperre betroffener Karten/Geräte bitten. |
| `#schliessen-ankuendigen` | „Wir schließen das Ticket in 3 Werktagen, wenn wir nichts mehr von Ihnen hören." |

### 8.4 Tonalität

- **„Sie"**, kurze Sätze, aktive Verben, konkrete Schritte mit den exakten Schaltflächennamen in Fettdruck und deutscher Erklärung.
- Zuerst die Lösung, dann die Erklärung.
- Ruhig und präzise – wie ein guter Oberkellner. Keine Übertreibungen, keine Floskeln wie „Wir freuen uns, Ihnen mitteilen zu dürfen".
- Fehler auf unserer Seite klar zugeben: „Das war ein Fehler bei uns. Wir haben ihn um [Uhrzeit] behoben."
- Nichts versprechen, was nicht im Produkt oder im Fahrplan steht. Keine Termine für neue Funktionen zusagen.
- Keine Emojis, höchstens ein Rufzeichen pro E-Mail – besser keines.
- Gäste des Lokals, die sich direkt an uns wenden: freundlich an das Lokal verweisen (das Lokal ist Vertragspartner und für Guthaben und Kundendaten verantwortlich).

---

Version 1.0 · Stand: September 2026
