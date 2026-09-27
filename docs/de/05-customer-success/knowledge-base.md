# Wissensdatenbank GiftCard Pro

*20 Hilfeartikel für Inhaberinnen und Inhaber, Manager und Servicekräfte – jeweils mit Kurzfassung, Schritten und verwandten Artikeln.*

---

Die Mitarbeiter-Oberfläche ist derzeit auf Englisch. Schaltflächen stehen im englischen Original in Fettdruck mit deutscher Bedeutung. Die Rolle in Klammern nennt, wer den Schritt ausführen darf.

## Inhalt

| Nr. | Artikel | Rolle |
|---|---|---|
| KB-01 | Erste Gutscheinkarte verkaufen | Manager, Owner |
| KB-02 | NFC-Karte mit Android beschreiben | Manager, Owner |
| KB-03 | Karte ausdrucken | Manager, Owner |
| KB-04 | Karte aktivieren | Manager, Owner |
| KB-05 | Karte sperren und entsperren | Manager, Owner |
| KB-06 | Verlorene Karte ersetzen | Manager, Owner |
| KB-07 | Kartenguthaben übertragen | Manager, Owner |
| KB-08 | Buchung stornieren | Manager, Owner |
| KB-09 | Gültigkeit richtig einstellen (Rechtshinweis) | Owner |
| KB-10 | Kellner einladen | Owner |
| KB-11 | Einladung abgelaufen | Owner, alle |
| KB-12 | Passwort vergessen | alle |
| KB-13 | Gerät sperren | Owner |
| KB-14 | Web-App auf dem Handy-Startbildschirm installieren | alle |
| KB-15 | Export für die Steuerberatung | Manager, Owner |
| KB-16 | Registrierkasse und Gutscheine (allgemein) | Owner |
| KB-17 | Kundendaten anonymisieren | Manager, Owner |
| KB-18 | E-Mail-Vorlagen anpassen | Owner |
| KB-19 | Öffentliche Guthabenabfrage ausschalten | Owner |
| KB-20 | API-Token erstellen (Pro) | Owner |

---

## KB-01 Erste Gutscheinkarte verkaufen

**Kurzfassung:** Eine Karte wird im Dashboard angelegt, danach beschrieben (NFC) oder gedruckt (QR). Die Bezahlung erfolgt an Ihrer Registrierkasse.

**Schritte**
1. **Gift cards → „New gift card"** (Neue Gutscheinkarte).
2. **„Value"** (Wert): Betrag wählen (€ 25/50/75/100/150) oder unter **„Amount"** frei eingeben (innerhalb Ihres Mindest- und Höchstwerts).
3. **„Valid until"** (Gültig bis) prüfen – siehe KB-09.
4. **„Customer"**: **„Anonymous"**, **„Existing"** oder **„New customer"** (Name, E-Mail, Telefon). Mit E-Mail erhält der Gast eine Kaufbestätigung.
5. Optional **„Recipient name"** (wird auf die Karte gedruckt) und **„Internal notes"** (nur intern sichtbar).
6. **„Card type"** wählen (Empfehlung: NTAG215; **„QR only"** für gedruckte Karten ohne Chip). **„Activate immediately"** eingeschaltet lassen.
7. **„Create card"**. Im Fenster **„Card created"**: **„Write NFC tag"** (KB-02) oder **„Print"** (KB-03).
8. Verkauf in der Registrierkasse buchen (KB-16).

**Verwandt:** KB-02, KB-03, KB-09, KB-16

---

## KB-02 NFC-Karte mit Android beschreiben

**Kurzfassung:** Mit einem Android-Handy und Chrome wird die Karte in einem Schritt beschrieben. Auf den Chip kommt nur ein sicherer Link, kein Guthaben.

**Schritte**
1. Auf dem Android-Handy in Chrome anmelden; NFC in den Systemeinstellungen einschalten.
2. Karte öffnen → **⋯ → „Write NFC tag"** (bzw. direkt nach **„Create card"**).
3. **„Card type"** prüfen. **„Lock tag after writing"** (Chip nach dem Schreiben sperren) für den Echtbetrieb einschalten – dauerhaft, verhindert Überschreiben.
4. **„Write NFC tag"** drücken und die leere Karte ruhig an die Rückseite halten.
5. Bestätigung: **„The card can now be scanned by your staff."** Die Chip-Seriennummer wird automatisch verknüpft (Klonschutz).
6. Test: im Kellner-Modus einmal scannen.

**Ohne Android:** Link aus dem Dialog kopieren, mit einer NFC-Schreib-App als URL-Eintrag schreiben, **„Mark as written"**. Die Karte gilt dann als „nicht geprüft“ und ist nicht an den Chip gebunden.

**Verwandt:** KB-01, KB-03, Fehlerbehebung Abschnitt 2

---

## KB-03 Karte ausdrucken

**Kurzfassung:** Jede Karte hat ein Drucklayout im Kreditkartenformat (85,6 × 54 mm) mit Vorderseite (Lokal, Wert, Empfänger) und Rückseite (QR-Code, Kartennummer, Gültigkeit, Scan-Hinweis) in der Sprache Ihres Lokals.

**Schritte**
1. Karte öffnen → **⋯ → „Print card / QR"** (oder **„Print"** nach dem Anlegen).
2. Im Druckdialog **Skalierung 100 %** bzw. „Tatsächliche Größe" wählen (nicht „An Seite anpassen"). Hintergrundgrafiken einschalten.
3. Drucken, entlang der Ränder schneiden. Für eine stabile Karte auf festem Papier drucken oder laminieren.
4. Mit dem Handy den QR-Code testen.

**Tipp:** QR-Karten können Sie kostenlos selbst drucken. Bedruckte NFC-Karten mit Ihrem Design bestellen Sie über hallo@giftcardpro.at (Richtpreis, abhängig von Menge und Druck – verbindliches Angebot auf Anfrage).

**Verwandt:** KB-01, KB-02

---

## KB-04 Karte aktivieren

**Kurzfassung:** Karten ohne **„Activate immediately"** haben den Status **„Inactive"** und können nicht eingelöst werden – nützlich, wenn Karten vorbereitet und erst bei Bezahlung freigeschaltet werden.

**Schritte**
1. Karte suchen (**Gift cards**, Filter **Status: Inactive**).
2. Karte öffnen → **⋯ → „Activate"** (Aktivieren).
3. Meldung **„Card activated"**. Die Karte ist sofort einlösbar.

**Verwandt:** KB-01, KB-05

---

## KB-05 Karte sperren und entsperren

**Kurzfassung:** Eine gesperrte Karte kann weder eingelöst noch aufgeladen werden. Die Sperre ist umkehrbar und wird mit Grund protokolliert.

**Schritte – sperren**
1. Karte öffnen → **⋯ → „Block card"** (Karte sperren).
2. Grund wählen: **„Reported stolen"**, **„Reported lost"**, **„Suspicious use"** oder eigenen Text.
3. Bestätigen. Servicekräfte sehen beim Scannen eine rote Warnung.

**Schritte – entsperren**
1. Karte öffnen → **⋯ → „Unblock"** (Entsperren).

**Wann ersetzen statt sperren?** Wenn der Gast eine neue Karte bekommen soll (KB-06).

**Verwandt:** KB-06, KB-07

---

## KB-06 Verlorene Karte ersetzen

**Kurzfassung:** Das Restguthaben wandert auf eine neue Karte mit neuer Nummer und neuem Link. Die alte Karte funktioniert sofort nicht mehr.

**Schritte**
1. Karte suchen – nach Kunde, Empfänger, Notiz oder Nummer.
2. Nur fortfahren, wenn die Karte eindeutig dem Gast zugeordnet ist (z. B. Kaufbestätigung, Kassabeleg).
3. **⋯ → „Replace lost card"**, Grund **„Lost"**, **„Damaged"** oder **„Stolen"**.
4. **„Issue replacement"** (Ersatz ausstellen). Die neue Karte öffnet sich direkt zum Beschreiben bzw. Drucken.
5. Die Historie verknüpft beide Karten („Replacement for …" / „Replaced by …").

**Verwandt:** KB-02, KB-03, KB-05

---

## KB-07 Kartenguthaben übertragen

**Kurzfassung:** Guthaben kann ganz oder teilweise von einer aktiven oder gesperrten Karte auf eine andere Karte Ihres Lokals übertragen werden, z. B. um zwei Karten zusammenzulegen.

**Schritte**
1. Quellkarte öffnen → **⋯ → „Transfer balance"** (Guthaben übertragen).
2. **„Target card number"** (Zielkartennummer) eingeben.
3. **„Amount"** leer lassen für das volle Guthaben, oder Teilbetrag eingeben.
4. Bestätigen. Beide Karten zeigen die Buchung (**„Transfer out"** / **„Transfer in"**).

**Hinweis:** Die Zielkarte muss Guthaben aufnehmen können (nicht ersetzt oder abgelaufen, Höchstguthaben beachten).

**Verwandt:** KB-06, KB-08

---

## KB-08 Buchung stornieren

**Kurzfassung:** Fehlbuchungen werden durch eine Gegenbuchung korrigiert. Die ursprüngliche Zeile bleibt im Buchungsjournal – nichts wird gelöscht.

**Schritte**
1. **Transactions** (oder Kartenhistorie) öffnen, Buchung suchen.
2. ↺ **„Reverse"** (Stornieren) wählen, Grund: **„Wrong amount"**, **„Wrong card"**, **„Guest cancelled"** oder eigener Text.
3. Bestätigen. Das Guthaben ist wiederhergestellt; eine Zeile **„Reversal"** erscheint.
4. Bei Bedarf richtigen Betrag neu einlösen. Registrierkasse entsprechend korrigieren.

**Grenzen:** Buchungen ersetzter oder abgelaufener Karten und bereits stornierte Buchungen können nicht storniert werden.

**Verwandt:** KB-07, KB-15

---

## KB-09 Gültigkeit richtig einstellen (Rechtshinweis)

**Kurzfassung:** Bezahlte Gutscheine verjähren in Österreich grundsätzlich nach 30 Jahren (§ 1478 ABGB). Eine pauschale Befristung auf 3 Jahre oder weniger ist laut OGH in der Regel gröblich benachteiligend (§ 879 Abs 3 ABGB) und unwirksam. Die Werkseinstellung von GiftCard Pro beträgt 36 Monate – bitte ändern.

**Schritte**
1. **Settings → Gift cards**.
2. **„Default validity (months)"** auf **0** setzen (kein Ablauf), außer Ihre Rechtsberatung genehmigt ein anderes Modell (der OGH hat z. B. 1 Jahr Gültigkeit mit anschließender 3-jähriger Umtausch- bzw. Rückerstattungsfrist akzeptiert).
3. Speichern. Gilt für neue Karten; bestehende Karten einzeln unter **⋯ → „Edit details"** → **„Valid until"** anpassen.
4. Aktions- oder Gratisgutscheine dürfen befristet werden – bei der Karte individuell setzen.

**Wichtig:** Läuft eine Karte ab, bucht GiftCard Pro das Restguthaben aus. Der Gast kann trotzdem Anspruch haben; dann Ersatzkarte (KB-06) oder Übertragung (KB-07). Eine Änderung der Werkseinstellung ist geplant.

*Keine Rechtsberatung – mit Steuerberatung bzw. Rechtsanwältin oder Rechtsanwalt prüfen.*

**Verwandt:** KB-06, KB-07, KB-16

---

## KB-10 Kellner einladen

**Kurzfassung:** Jede Person erhält eine eigene Einladung und setzt ihr Passwort selbst. Anmeldedaten werden nie geteilt – jede Buchung trägt den Namen der Person.

**Schritte**
1. **Team → „Invite"** (Einladen).
2. **„Name"**, **„E-mail"**, **„Role"**: **„Waiter"** (nur scannen und einlösen), **„Manager"** oder **„Owner"**.
3. **„Send invitation"**. Die Person erhält eine E-Mail, Link 72 Stunden gültig.
4. Die Person öffnet den Link, sieht **„Welcome to GiftCard Pro"** und wählt ein Passwort (mind. 12 Zeichen, Groß-/Kleinbuchstaben, Ziffer).
5. Status in **Team**: **„Invited"** → **„Active"**.

**Verlässt jemand das Lokal:** **⋯ → „Deactivate"**. Buchungen bleiben mit Namen erhalten.

**Verwandt:** KB-11, KB-12, KB-14

---

## KB-11 Einladung abgelaufen

**Kurzfassung:** Einladungslinks gelten 72 Stunden und nur einmal. Danach erscheint eine Fehlermeldung beim Setzen des Passworts.

**Schritte**
1. Inhaberin bzw. Inhaber: **Team** → Person (Status **„Invited"**) → **⋯ → „Resend invitation"**.
2. Die Person verwendet den **neuesten** Link, innerhalb von 72 Stunden.
3. Keine E-Mail? Spam-Ordner prüfen; Adresse unter **⋯ → „Edit"** korrigieren.

**Verwandt:** KB-10, KB-12

---

## KB-12 Passwort vergessen

**Kurzfassung:** Über **„Forgot password?"** erhalten Sie einen Link, der 60 Minuten gültig ist.

**Schritte**
1. Anmeldeseite → **„Forgot password?"** (Passwort vergessen).
2. E-Mail-Adresse eingeben. Die Bestätigung **„Check your inbox"** erscheint immer – aus Sicherheitsgründen auch für unbekannte Adressen.
3. Link in der E-Mail innerhalb von 60 Minuten öffnen, neues Passwort setzen.
4. Alle anderen Sitzungen werden abgemeldet.

**Alternativ:** Inhaberin bzw. Inhaber sendet unter **Team → ⋯ → „Send password reset"** einen Link.
**Konto gesperrt?** Nach 10 Fehlversuchen 15 Minuten warten.

**Verwandt:** KB-10, KB-11

---

## KB-13 Gerät sperren

**Kurzfassung:** Jedes Gerät, das sich anmeldet, wird automatisch registriert. Ein verlorenes oder gestohlenes Gerät kann sofort gesperrt werden.

**Schritte**
1. **Devices** (Geräte) öffnen.
2. Gerät anhand von Name, Person und letzter Nutzung finden. Tipp: Geräte gleich nach der ersten Anmeldung umbenennen (Stift-Symbol, z. B. „Bar iPhone").
3. **„Revoke"** (Sperren) und bestätigen. Das Gerät kann ab sofort keine Karten mehr scannen oder einlösen.
4. Wiedergefunden: **„Restore"** (Wiederherstellen).
5. Bei gestohlenem Gerät zusätzlich das Passwort der dort angemeldeten Person ändern.

**Verwandt:** KB-12, KB-14

---

## KB-14 Web-App auf dem Handy-Startbildschirm installieren

**Kurzfassung:** GiftCard Pro ist eine Web-App – kein Download aus dem App Store nötig. Ein Symbol am Startbildschirm öffnet sie wie eine App.

**Android (Chrome)**
1. app.giftcardpro.at in **Chrome** öffnen und anmelden (**„Keep me signed in on this device"** auf Diensthandys).
2. Menü **⋮ → „App installieren"** bzw. **„Zum Startbildschirm hinzufügen"**.
3. Künftig über das Symbol starten – NFC funktioniert nur in Chrome.

**iPhone (Safari)**
1. app.giftcardpro.at in **Safari** öffnen und anmelden.
2. **Teilen-Symbol → „Zum Home-Bildschirm"**.
3. Über das Symbol starten.

**Verwandt:** KB-10, KB-13

---

## KB-15 Export für die Steuerberatung

**Kurzfassung:** Kartenliste und Buchungsjournal lassen sich als CSV exportieren – mit Strichpunkt und Dezimalkomma, direkt in Excel lesbar.

**Schritte**
1. Einmalig: **Settings → Restaurant → „Language & number format"** auf **Deutsch (Österreich)**, **„Time zone"** Europe/Vienna.
2. **Transactions** → Zeitraum mit **From / To** setzen (z. B. Monat oder Geschäftsjahr), optional Typ filtern → **„Export CSV"**.
3. **Gift cards** → optional Status filtern → **„Export CSV"** (Guthaben je Karte zum Stichtag).
4. Zusätzlich den Wert **„Outstanding balance"** (offene Verbindlichkeit) am Stichtag notieren.
5. Dateien an die Steuerberatung senden; abklären, ob das Format passt.

**Hinweis:** Das Buchungsjournal ist unveränderlich und wird aufbewahrt (Aufbewahrungspflicht 7 Jahre, § 132 BAO). *Keine Steuerberatung.*

**Verwandt:** KB-08, KB-16

---

## KB-16 Registrierkasse und Gutscheine (allgemein, mit Hinweis)

**Kurzfassung:** GiftCard Pro ist **keine Registrierkasse**, nicht RKSV-zertifiziert und erstellt keine Belege. Verkauf und Einlösung buchen Sie zusätzlich in Ihrer Registrierkasse, so wie es Ihre Steuerberatung festlegt.

**Allgemeine Informationen**
- **Umsatzsteuer:** Seit 2019 wird zwischen Einzweckgutschein (USt bei Verkauf) und Mehrzweckgutschein (USt bei Einlösung) unterschieden. Wertgutscheine für Speisen (10 %) und Getränke (20 %) sind typischerweise Mehrzweckgutscheine – die Umsatzsteuer entsteht dann bei der Einlösung.
- **Registrierkasse:** Die Gutscheintasten bzw. Zahlungsarten in der Kassa richtet Ihr Kassenanbieter nach Vorgabe der Steuerberatung ein.
- **Ertragsteuer:** Bei Einnahmen-Ausgaben-Rechnung wird der Gutscheinverkauf in der Regel bei Zufluss erfasst; bei Bilanzierung wird Umsatz bei Einlösung erfasst, offene Gutscheine sind eine Verbindlichkeit (**„Outstanding balance"**).
- **Schnittstelle:** Eine direkte Kassenanbindung gibt es noch nicht; im Tarif Pro steht eine API zur Verfügung (KB-20).

**Ablauf im Service (Beispiel, mit Steuerberatung abstimmen)**
1. Verkauf: Karte in GiftCard Pro anlegen, Betrag in der Kassa als Gutscheinverkauf kassieren.
2. Einlösung: Karte in GiftCard Pro einlösen, in der Kassa als Zahlungsart „Gutschein" buchen.

*Keine Rechts- oder Steuerberatung – mit Steuerberatung prüfen.*

**Verwandt:** KB-09, KB-15, KB-20

---

## KB-17 Kundendaten anonymisieren

**Kurzfassung:** Auf Wunsch eines Gastes (Recht auf Löschung, DSGVO) entfernt **„Anonymize"** Name, E-Mail, Telefon und Notizen sowie Empfängernamen auf seinen Karten. Karten, Guthaben und Buchungen bleiben für die Buchhaltung erhalten.

**Schritte**
1. **Customers** → Kunden suchen → öffnen.
2. **„Anonymize customer"** wählen.
3. Hinweis lesen (**„Irreversibly removes name, e-mail, phone and notes …"**) und bestätigen. Der Vorgang ist nicht umkehrbar.
4. Dem Gast die Löschung bestätigen.

**Hinweis:** Ihr Lokal ist Verantwortlicher für die Kundendaten; GiftCard Pro verarbeitet sie in Ihrem Auftrag.

**Verwandt:** KB-18

---

## KB-18 E-Mail-Vorlagen anpassen

**Kurzfassung:** Vier Kunden-E-Mails sind auf Deutsch und Englisch vorbereitet und anpassbar: Karte gekauft, Karte aufgeladen, Karte läuft bald ab (30 Tage vorher), niedriges Guthaben (unter € 5).

**Schritte**
1. **Settings → E-mails**.
2. Vorlage wählen (Ihre Sprache steht zuerst).
3. **„Subject"** (Betreff) und **„Message"** (Text) bearbeiten. Platzhalter in `{{ … }}` nicht verändern.
4. Speichern. Die Vorschau zeigt den echten Namen Ihres Lokals.
5. Fußzeile mit Firmendaten (Firmenbuch, Anschrift): **Settings → Gift cards → „E-mail footer"**.
6. Versand insgesamt ein/aus: **„Customer e-mails"**.

**Verwandt:** KB-01, KB-17

---

## KB-19 Öffentliche Guthabenabfrage ausschalten

**Kurzfassung:** Gäste können ihr Guthaben durch Scannen der Karte mit dem eigenen Handy prüfen (Guthaben, Status, Gültigkeit, maskierte Nummer). Diese Seite lässt sich abschalten.

**Schritte**
1. **Settings → Gift cards**.
2. **„Public balance check"** (öffentliche Guthabenabfrage) ausschalten, speichern.
3. Gäste sehen danach: „Bitte fragen Sie im Restaurant nach Ihrem Guthaben."
4. Angemeldete Mitarbeiter öffnen Karten weiterhin normal.

**Verwandt:** KB-14, KB-18

---

## KB-20 API-Token erstellen (Pro)

**Kurzfassung:** Im Tarif Pro können Sie Schnittstellen-Zugänge (API-Tokens) für Integrationen, z. B. mit einer Registrierkasse, erstellen. Tokens haben begrenzte Rechte, eine Laufzeit von höchstens 365 Tagen und sind jederzeit widerrufbar.

**Schritte**
1. **Settings → API**.
2. **„Name"** (z. B. „Kassa Bar"), **„Abilities"** (Rechte – nur die nötigen wählen), **„Expires"** (Ablaufdatum) setzen.
3. Erstellen. Der Token (beginnt mit `gcp_`) wird **nur einmal** angezeigt – sofort sicher an Ihren Integrationspartner übergeben, nie per unverschlüsselter E-Mail.
4. Nicht mehr benötigt oder kompromittiert: Token widerrufen.

**Verwandt:** KB-16

---

Version 1.0 · Stand: September 2026
