# Fehlerbehebung GiftCard Pro

*Symptom → Ursache → Lösung: Anmeldung, NFC, QR-Code, Kartenmeldungen, Verbindung, Geräte, E-Mails, Exporte, Dashboard und Druck.*

---

**So verwenden Sie diesen Leitfaden:** Suchen Sie die Meldung, die die App anzeigt (englischer Originaltext in Fettdruck), oder das Symptom. Die Mitarbeiter-Oberfläche ist derzeit auf Englisch; die deutsche Bedeutung steht jeweils dabei. Hilft keine Lösung, schreiben Sie an support@giftcardpro.at (Angaben siehe Support-Leitfaden, Abschnitt 5).

**Grundregel für Servicekräfte:** Im Zweifel die Karte nicht einlösen und den Manager holen. Eine Buchung kann später jederzeit nachgeholt werden.

---

## 1. Anmeldung und Konto

| Symptom / Meldung | Ursache | Lösung |
|---|---|---|
| **„Too many failed attempts. Try again in 15 minutes."** (Zu viele Fehlversuche) | Nach 10 falschen Passworteingaben wird das Konto 15 Minuten gesperrt. | 15 Minuten warten, dann erneut anmelden. Passwort unbekannt → **„Forgot password?"**. Das Team sieht das Konto in dieser Zeit als **„Locked"**. |
| **„Too many requests. Please slow down."** (Zu viele Anfragen) | Mehr als 5 Anmeldeversuche pro Minute. | Eine Minute warten. |
| Anmeldung schlägt fehl, Passwort sicher richtig | Tippfehler in der E-Mail-Adresse, Konto deaktiviert oder Lokal pausiert | E-Mail prüfen (Kleinschreibung egal). Inhaberin bzw. Inhaber prüft unter **Team**, ob die Person **„Active"** ist. Meldung **„This restaurant account is suspended. Please contact support."** → Support kontaktieren. |
| Einladungslink funktioniert nicht, Meldung wie **„This password reset token is invalid."** | Einladungslink älter als **72 Stunden** oder bereits verwendet | Inhaberin bzw. Inhaber: **Team → ⋯ → „Resend invitation"** (Einladung erneut senden). Immer den neuesten Link verwenden. |
| Link aus **„Forgot password?"** funktioniert nicht | Link älter als **60 Minuten** oder bereits verwendet, oder ein neuerer Link wurde angefordert | Neuen Link anfordern und sofort verwenden. |
| Keine E-Mail nach **„Forgot password?"** | Aus Sicherheitsgründen lautet die Bestätigung immer gleich – auch wenn es die Adresse nicht gibt. | Richtige Adresse verwenden, Spam-Ordner prüfen. Inhaberin bzw. Inhaber kann unter **Team → ⋯ → „Send password reset"** einen Link senden. |
| Passwort wird nicht akzeptiert | Mindestanforderungen nicht erfüllt | Mindestens 12 Zeichen, Groß- und Kleinbuchstaben und eine Ziffer. |
| Nach Passwortänderung auf anderen Geräten abgemeldet | Gewollt: Passwortänderung meldet alle anderen Sitzungen ab. | Auf den anderen Geräten neu anmelden. |
| **„This session belongs to another device. Please sign in again."** (Sitzung gehört zu einem anderen Gerät) | Sitzungen sind an das Gerät gebunden; die Browserdaten wurden gelöscht, kopiert oder das Gerät gewechselt. | Neu anmelden. Das Gerät wird dabei neu registriert. |
| **„Your session has expired. Please reload the page."** (Sitzung abgelaufen) | Seite war lange offen, Sicherheits-Token veraltet | Seite neu laden. |
| Nach einigen Stunden ohne Nutzung abgemeldet | Sitzungen enden nach 8 Stunden Inaktivität. | Beim Anmelden **„Keep me signed in on this device"** aktivieren (nur auf Diensthandys des Lokals). |

---

## 2. NFC – Android

| Symptom / Meldung | Ursache | Lösung |
|---|---|---|
| **„NFC is turned off or not available. Enable NFC in the phone settings."** | NFC ist ausgeschaltet. | Einstellungen → Verbindungen → NFC einschalten. Zurück zur App, **„Scan card"**. |
| **„To tap cards, switch on NFC and open this page in Chrome. Until then, scan the QR code."** | Anderer Browser (Samsung Internet, Firefox …) oder NFC aus | App in **Chrome** öffnen, am besten über das Symbol am Startbildschirm, das aus Chrome installiert wurde. |
| **„NFC permission was denied. Allow NFC for this site in the browser settings."** | NFC-Berechtigung für die Seite abgelehnt | Chrome → Schloss-Symbol neben der Adresse → Berechtigungen → NFC → Zulassen. Seite neu laden. |
| **„NFC is not supported on this device."** | Gerät hat keinen NFC-Chip | **„Scan QR code"** oder **„Card number"** verwenden; für den Service ein NFC-fähiges Gerät einplanen. |
| Nichts passiert beim Antippen | **„Scan card"** wurde noch nicht gedrückt, oder falsche Stelle | Einmal **„Scan card"** drücken. Karte flach an die obere Rückseite halten (Position des NFC-Chips je Modell unterschiedlich), ca. 1 Sekunde, Hülle ggf. abnehmen. |
| **„The tag was removed too early. Please hold it still and try again."** / **„The card could not be read. Hold it still against the back of the phone."** | Karte zu kurz oder bewegt gehalten | Ruhig halten, bis das Handy vibriert. |
| **„This tag does not contain a gift card."** (Chip enthält keine Gutscheinkarte) | Leere Karte, fremder NFC-Chip (z. B. Bankomatkarte, Zutrittskarte) oder falsch beschriebene Karte | Richtige Karte verwenden. Eigene Karte leer → im Dashboard **⋯ → „Write NFC tag"** erneut schreiben. |
| **„This NFC tag is already linked to another active card."** (beim Beschreiben) | Dieser Chip ist schon mit einer anderen aktiven Karte verknüpft. | Neue, leere Karte verwenden. |
| Karte lässt sich nicht beschreiben | Chip ist dauerhaft gesperrt (**„Lock tag after writing"**) oder defekt | Neue Karte verwenden. Gesperrte Chips können nicht überschrieben werden – das ist gewollt. |

## 3. NFC – iPhone

| Symptom | Ursache | Lösung |
|---|---|---|
| Keine Mitteilung beim Antippen | iPhone älter als XS, Bildschirm aus oder gesperrt, Kamera-App bzw. Wallet geöffnet, Flugmodus an | iPhone entsperren, Karte an die **Oberkante der Rückseite** halten. Ältere Modelle: **„Scan QR code"**. |
| Mitteilung erscheint, öffnet aber die Guthabenseite für Gäste | Auf dem iPhone ist niemand in GiftCard Pro angemeldet (bzw. in einem anderen Browser). | Im gleichen Browser (Safari bzw. Web-App) als Servicekraft anmelden. Angemeldete Personen landen direkt im Kellner-Modus mit geöffneter Karte. |
| Keine Reaktion bei einer bestimmten Karte, andere funktionieren | Karte nicht beschrieben (leer) | Im Dashboard prüfen, ob unter **„NFC tag"** ein Schreibdatum steht; sonst beschreiben. |
| Mitteilung mit anderem Inhalt (z. B. fremde Website) | Chip wurde überschrieben (nicht gesperrt) | Karte nicht annehmen, Manager holen. Karte ersetzen, künftig **„Lock tags after writing"** einschalten. |

**Hinweis:** iPhones können Karten nicht selbst beschreiben. Zum Beschreiben ein Android-Handy mit Chrome oder eine NFC-Schreib-App verwenden (URL aus dem Dialog kopieren, danach **„Mark as written"**).

## 4. QR-Code und Kamera

| Symptom / Meldung | Ursache | Lösung |
|---|---|---|
| **„Camera access was denied."** | Kamerazugriff abgelehnt | Browser-Einstellungen → Website → Kamera → Zulassen. iPhone: Einstellungen → Safari → Kamera → Fragen/Erlauben. Seite neu laden. |
| **„Camera unavailable."** | Kamera von einer anderen App belegt | Andere Apps (Kamera, Videoanruf) schließen. |
| **„QR scanning is not supported on this device."** | Browser unterstützt den eingebauten QR-Scanner nicht | Mit der normalen Kamera-App den Code scannen (öffnet die Karte) oder **„Card number"** verwenden. |
| QR-Code wird nicht erkannt | Schlechte Beleuchtung, Code verkratzt, Ausdruck zu klein | Näher/weiter halten, Licht verbessern. Druck immer in **100 %** (siehe Abschnitt 10). |

---

## 5. Meldungen zur Karte

| Meldung | Bedeutung | Lösung |
|---|---|---|
| **„No card with this number. Check the digits and try again."** | Eingetippte Nummer existiert nicht (die Prüfziffer passt nicht oder Karte unbekannt). | Ziffern in Viererblöcken vergleichen, neu eingeben. |
| **„This is not one of our gift cards."** | Gescannter Link gehört zu keiner Karte dieses Lokals. | Nicht annehmen. Karte eines anderen Lokals oder ungültig. |
| **„This gift card was issued by a different restaurant and cannot be used here."** | Karte eines anderen Lokals (auch eines anderen Standorts derselben Gruppe – jeder Standort ist ein eigenes Konto) | Nicht annehmen. Gast an das ausstellende Lokal verweisen. |
| **„This card is blocked"** (rot, ggf. mit Grund) | Karte gesperrt (z. B. **„Reported lost"**, **„Reported stolen"**, **„Suspicious use"**) | Nicht annehmen, Manager holen. Manager prüft Historie, entsperrt (**„Unblock"**) oder ersetzt. |
| **„This card was replaced and is no longer valid. Ask the guest for the new card."** (rot) | Karte wurde durch eine Ersatzkarte abgelöst; das Guthaben liegt auf der neuen Karte. | Nach der neuen Karte fragen. Hat der Gast sie nicht, Manager holen – auf der Kartenseite steht **„This card was replaced by …"** mit Link zur neuen Karte. |
| **„This card has expired."** | Gültigkeitsdatum überschritten; das Restguthaben wurde automatisch um 00:15 Uhr ausgebucht. | Nicht einlösen, Manager holen. Der Gast kann rechtlich trotzdem Anspruch haben (siehe Rechtshinweis unten). |
| **„This card is not activated yet."** (gelb) | Karte wurde ohne **„Activate immediately"** angelegt. | Manager: Karte öffnen → **⋯ → „Activate"**. |
| **„This card has no balance left."** (gelb) | Guthaben € 0 | Gast informieren; ggf. aufladen, wenn erlaubt. |
| **„More than the balance. Redeem € X and collect the rest otherwise."** | Eingegebener Betrag höher als das Guthaben | **„Full balance"**, einlösen, Rest anders kassieren. |
| **„This restaurant only allows redeeming the full balance."** | Teileinlösung ist ausgeschaltet. | Nur volles Guthaben einlösen, oder Inhaberin/Inhaber schaltet **„Partial redemption"** ein. |
| **„The amount exceeds the maximum allowed for a single redemption."** | Höchstbetrag pro Einlösung überschritten | Aufteilen ist nicht vorgesehen – Manager prüft; Inhaberin/Inhaber passt **„Maximum single redemption"** an. |
| **„The resulting balance would exceed the maximum allowed card balance."** | Beim Aufladen wäre das Kartenguthaben höher als erlaubt (Standard € 2.000). | Geringeren Betrag laden. |
| **„Reloading gift cards is disabled for this restaurant."** | Aufladen ausgeschaltet | Einstellung **„Allow reloading"** prüfen. |
| **„The NFC chip does not match the registered card. The card may be cloned."** | Chip-Seriennummer passt nicht zur Karte → Verdacht auf Kopie | Nicht annehmen. Manager sperrt die Karte, prüft **„Audit log"** (rote Sicherheitswarnung). Support informieren. |
| **„This NFC read was already used. Please tap the card again."** / **„The secure NFC signature could not be verified."** | NTAG 424 DNA: kopierter Link oder unvollständige Lesung | Karte erneut antippen. Wiederholt sich die Meldung: nicht annehmen, Manager holen. |

**Rechtshinweis Ablauf:** Bezahlte Gutscheine sind in Österreich grundsätzlich 30 Jahre einlösbar; kurze Befristungen sind oft unwirksam. Bei berechtigtem Anspruch stellt der Manager eine neue Karte aus oder überträgt den Betrag. Empfehlung: **„Default validity (months)"** auf 0 setzen. *Keine Rechtsberatung – mit Steuerberatung bzw. Rechtsanwältin oder Rechtsanwalt prüfen.*

---

## 6. Verbindung

| Meldung | Bedeutung | Lösung |
|---|---|---|
| **„No connection to the server. Check the internet connection and try again."** | Das Handy erreicht den Server nicht (WLAN weg, Mobilfunk schwach). **Es wurde nichts gebucht.** | WLAN bzw. mobile Daten prüfen, dann denselben Knopf erneut drücken. **Wiederholen ist sicher:** Jede Einlösung trägt einen eindeutigen Schlüssel; der Server bucht sie nie doppelt, auch nicht, wenn die erste Anfrage doch angekommen ist. Zur Kontrolle: Kartenhistorie. |
| **„Something went wrong. Please try again."** | Unerwarteter Fehler | Erneut versuchen. Bleibt es, Bildschirmfoto und Uhrzeit an den Support. |
| App lädt überhaupt nicht, auf allen Geräten | Mögliche Störung oder Wartung | Banner in der App bzw. E-Mail prüfen, Support kontaktieren (P1). Gutscheine in der Zwischenzeit mit Kartennummer, Betrag und Uhrzeit notieren und später buchen. |

## 7. Sicherheitsgrenzen (Rate Limits)

| Meldung | Ursache | Lösung |
|---|---|---|
| **„Too many failed card lookups. Please wait a moment and try again."** | Mehr als 10 erfolglose oder verdächtige Kartenabfragen in 5 Minuten (Schutz gegen Ausprobieren von Nummern) | Einige Minuten warten. Häufen sich Fehlabfragen, Ursache klären (falsche Karten, Tippfehler). |
| **„Too many redemptions on this card in a short period. Please contact a manager."** | Betrugsgrenze: mehr Einlösungen pro Karte und Stunde als erlaubt (Standard 10) | Manager prüft die Kartenhistorie. Bei Bedarf passt die Inhaberin/der Inhaber **„Max. redemptions per card per hour"** an. |
| **„Too many requests. Please slow down."** | Allgemeine Mengenbegrenzung | Kurz warten, dann weiterarbeiten. |

## 8. Geräte

| Meldung / Symptom | Ursache | Lösung |
|---|---|---|
| **„This device has been revoked. Please contact your manager."** (Fehler 403) | Das Gerät wurde unter **Devices** gesperrt (**„Revoke"**). | Ist das Gerät wieder gefunden bzw. versehentlich gesperrt: Inhaberin/Inhaber → **Devices → „Restore"**. Sonst anderes Gerät verwenden. |
| Gerät erscheint doppelt in **Devices** | Browserdaten gelöscht oder anderer Browser verwendet → neue Gerätekennung | Altes Gerät sperren, neues sinnvoll umbenennen (Stift-Symbol, z. B. „Bar iPhone"). |
| Servicekraft sieht nur den Kellner-Modus | Gewollt: Rolle **„Waiter"** darf nur scannen und einlösen. | Weitere Rechte nur über die Rolle **„Manager"**. |

## 9. E-Mails

| Symptom | Ursache | Lösung |
|---|---|---|
| Gast erhält keine Kauf- oder Aufladebestätigung | **„Customer e-mails"** ausgeschaltet, keine E-Mail beim Kunden hinterlegt (anonyme Karte), Tippfehler oder Spam | Einstellung prüfen, Kundendaten unter **Customers** prüfen/korrigieren, Gast bitten, im Spam-Ordner zu suchen. |
| Kein Ablauf-Hinweis beim Gast | Karte ohne Ablaufdatum (dann gibt es keinen Hinweis) oder s. o. | Erinnerungen werden 30 Tage vor Ablauf um 10:00 Uhr versendet. |
| Keine Hinweis-E-Mail bei niedrigem Guthaben | Guthaben nicht unter € 5, oder s. o. | – |
| Einladung kommt nicht an | Spam-Ordner, falsche Adresse, Firmen-Mailfilter | Spam prüfen; Adresse unter **Team → ⋯ → „Edit"** korrigieren und **„Resend invitation"**. |
| E-Mail zeigt falsche Firmendaten | E-Mail-Fußzeile bzw. Vorlagen nicht angepasst | **Settings → Gift cards → „E-mail footer"**, **Settings → E-mails** (Vorlagen DE und EN). |

## 10. Export, Dashboard, Druck

| Symptom | Ursache | Lösung |
|---|---|---|
| CSV in Excel: alles in einer Spalte | Excel mit englischen Ländereinstellungen erwartet Beistrich statt Strichpunkt. | Excel → **Daten → Aus Text/CSV** → Trennzeichen „Semikolon", Dateiursprung UTF-8. |
| CSV: Beträge als Datum oder Text (z. B. „12.50") | Restaurant steht auf englischem Zahlenformat. | **Settings → Restaurant → „Language & number format"** auf **Deutsch (Österreich)** setzen und neu exportieren. |
| Umlaute falsch dargestellt | Datei mit einem Programm ohne UTF-8-Erkennung geöffnet | Über **Daten → Aus Text/CSV** mit UTF-8 importieren. |
| **„Outstanding balance"** ≠ **„Revenue this month"** | Unterschiedliche Kennzahlen: offenes Guthaben aller Karten (Verbindlichkeit) vs. Verkäufe + Aufladungen im laufenden Monat | Kein Fehler. Siehe Wissensdatenbank „Export für die Steuerberatung". |
| **„Outstanding balance"** über Nacht gesunken, ohne Einlösung | Karten sind um 00:15 Uhr abgelaufen; Restguthaben wurde ausgebucht. | Buchungsjournal nach Typ „Expiration" filtern. Gültigkeitseinstellung prüfen. |
| Tageswerte passen nicht zur Kassa | Zeitzone falsch oder Verkauf nicht in beiden Systemen gebucht | **Settings → Restaurant → „Time zone"** = Europe/Vienna; Kassa-Buchungen abgleichen. |
| Storno erscheint als zusätzliche Zeile | Gewollt: Stornos sind Gegenbuchungen, nichts wird gelöscht. | – |
| Gedruckte Karte zu groß oder zu klein | Drucker skaliert („An Seite anpassen") | Im Druckdialog **Skalierung 100 %** bzw. „Tatsächliche Größe" wählen, dann entlang der Ränder schneiden. Ergebnis: 85,6 × 54 mm. |
| Druck ohne Farben/Hintergrund | Browser druckt keine Hintergrundgrafiken | Im Druckdialog „Hintergrundgrafiken" aktivieren. |

---

Version 1.0 · Stand: September 2026
