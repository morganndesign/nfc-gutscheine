# Produktüberblick GiftCard Pro

*Was GiftCard Pro ist, für wen es gemacht ist, wie es funktioniert und was es bewusst nicht ist. Für Interessentinnen und Interessenten, Partner, neue Teammitglieder und alle, die das Produkt in fünf Minuten verstehen wollen.*

---

## 1. In einem Satz

GiftCard Pro ist ein Gutscheinkarten-System für die Gastronomie: Restaurants verkaufen hochwertige Geschenkkarten mit NFC-Chip und QR-Code, lösen sie am Tisch in unter fünf Sekunden mit jedem Smartphone ein und sehen jederzeit, welcher Betrag noch offen ist — ohne Provision.

> **„Gutscheinkarten, die sich wie Bezahlen anfühlen."**

![Dashboard für Inhaberinnen und Inhaber](../../screenshots/owner-dashboard.png)

---

## 2. Für wen GiftCard Pro gemacht ist

| Zielgruppe | Typische Betriebe | Was sie brauchen |
|---|---|---|
| **Einzelbetriebe** | Restaurant, Gasthaus, Kaffeehaus, Bar, Heuriger | Ein Gutscheinsystem, das ohne Schulung funktioniert und nach etwas aussieht |
| **Stark frequentierte Betriebe** | Lokale mit vielen verkauften Gutscheinen, hohem Durchschnittswert, Saisonspitzen zu Weihnachten | Tempo am Tisch, Schutz vor Kopien und Missbrauch, saubere Zahlen |
| **Gruppen** | Mehrere Standorte, Hotels mit mehreren Outlets | Einheitliche Abläufe, ein Ansprechpartner, gemeinsames Onboarding |

**Personen im Betrieb:**

- **Inhaberin oder Inhaber** — entscheidet, denkt an Geld, Haftung und Außenwirkung, hat wenig Zeit.
- **Betriebsleitung / Manager** — verkauft Karten, kümmert sich um Ersatzkarten, Team und tägliche Kontrolle.
- **Servicekräfte** — lösen Karten am Tisch ein. Sie brauchen keine Schulung.
- **Gäste** — die Schenkenden wollen etwas Schönes überreichen, die Beschenkten wollen ohne Umstände einlösen.
- **Steuerberatung** — braucht saubere, vollständige Exporte.

Startmarkt ist **Österreich**, beginnend mit Wien.

---

## 3. So funktioniert es

```
 ┌────────────┐   ┌──────────────┐   ┌────────────┐   ┌────────────┐   ┌────────────┐
 │ 1 Verkauf  │ → │ 2 Karte      │ → │ 3 Antippen │ → │ 4 Einlösen │ → │ 5 Bericht  │
 │   im Lokal │   │ beschreiben  │   │   am Tisch │   │   Betrag   │   │ Dashboard  │
 │            │   │ oder drucken │   │   NFC / QR │   │  eintippen │   │  & Export  │
 └────────────┘   └──────────────┘   └────────────┘   └────────────┘   └────────────┘
```
1. **Verkaufen.** Im Dashboard unter **Gift cards → New gift card** wählen Sie den Wert (Schnellwahl € 25 / 50 / 75 / 100 / 150 oder freier Betrag), die Gültigkeit und optional Kundin oder Kunde sowie den Namen der beschenkten Person. **Create card** legt die Karte an. Die Zahlung nimmt Ihr Lokal wie gewohnt an der eigenen Registrierkasse entgegen.
2. **Karte programmieren.** Mit einem Android-Handy und Chrome schreiben Sie den Chip mit einem Tippen (**Write NFC tag**). Alternativ kopieren Sie die angezeigte Adresse in eine beliebige NFC-Schreib-App und klicken **Mark as written**. Reine QR-Karten drucken Sie im Scheckkartenformat selbst aus.
3. **Antippen.** Der Gast legt die Karte beim Bezahlen vor. Die Servicekraft hält sie an ihr Handy (NFC), scannt den QR-Code oder tippt die 16-stellige Kartennummer ein.
4. **Einlösen.** Betrag eintippen (`2 4 9 0` → € 24,90) oder **Full balance** wählen, dann **Redeem € 24,90**. Der Erfolgsbildschirm zeigt das Restguthaben für den Gast. Die nächste Karte kann sofort angetippt werden.
5. **Auswerten.** Das Dashboard zeigt den offenen Gesamtbetrag, Umsatz, Einlösungen und verkaufte Karten. Jede Buchung steht im unveränderlichen Journal und lässt sich als CSV direkt in Excel öffnen.

| ![Kellner-App: bereit](../../screenshots/waiter-ready.png) | ![Kellner-App: Betrag](../../screenshots/waiter-amount.png) | ![Kellner-App: erledigt](../../screenshots/waiter-success.png) |
|---|---|---|
| Bereit zum Antippen | Betrag eintippen | Eingelöst, Restguthaben |

**Wichtig:** Auf der Karte ist kein Geld gespeichert. Chip und QR-Code enthalten nur einen sicheren Link mit einer zufälligen Kennung. Guthaben, Verlauf und Kundendaten liegen ausschließlich auf dem Server.

---

## 4. Funktionen nach Rolle

### Servicekraft (Kellner-App)

- Web-App auf jedem Smartphone, auf dem Startbildschirm installierbar — keine App aus dem App Store nötig. Eine native App „GiftCard Waiter" für Android und iPhone ist entwickelt, aber noch nicht in den Stores veröffentlicht; bis dahin wird wie bisher die Web-App verwendet.
- **Android (Chrome):** einmal **Scan card** drücken, danach wird jede Karte beim Antippen gelesen.
- **iPhone:** Karte an die Oberkante halten und die Mitteilung antippen, oder **Scan QR code**.
- Notfalls: **Card number** und 16 Ziffern eintippen.
- Kassenähnliche Zifferntastatur, **Full balance**, großer **Redeem**-Knopf, Restguthaben, **Next card**, automatische Rückkehr nach 8 Sekunden, Vibration als Bestätigung (Android).
- Klare Meldungen: gesperrt (rot), ersetzt („ask the guest for the new card"), abgelaufen, kein Guthaben, nicht gefunden.
- Funktioniert ohne Scrollen auch auf kleinen Handys wie dem iPhone SE.

### Betriebsleitung / Manager

- Karten verkaufen, suchen (Nummer, Kunde, beschenkte Person, Notiz), filtern, sortieren, exportieren.
- Einlösen und Aufladen am Pult, Guthaben zwischen Karten übertragen.
- Verlorene oder beschädigte Karte ersetzen: Das Guthaben wandert auf eine neue Karte, die alte ist sofort ungültig.
- Karten sperren und entsperren (mit Grund), Fehlbuchungen stornieren — als Gegenbuchung, nichts wird gelöscht.
- Kundinnen und Kunden verwalten, Team einladen, Geräte verwalten, Prüfprotokoll einsehen (je nach Berechtigung).

### Inhaberin / Inhaber

- Kennzahlen: **Outstanding balance** (offene Verbindlichkeit auf N Karten), **Revenue this month**, **Redeemed this month**, **Cards sold**.
- Diagramme: täglich verkauft vs. eingelöst (7/30/90 Tage), Monatsumsatz (12 Monate), Karten nach Status, letzte Aktivität.
- Alle Einstellungen: Kartenregeln, Restaurantprofil, Gäste-E-Mails, API-Schlüssel.
- Team, Rollen, Geräte und das vollständige Prüfprotokoll mit Sicherheitswarnungen.

### Gast

- Hochwertige Karte im Scheckkartenformat mit Name des Lokals, Wert und Name der beschenkten Person.
- Guthabenabfrage mit dem eigenen Handy: Karte antippen oder QR-Code scannen — Guthaben, Status und Gültigkeit in der Sprache des Lokals (abschaltbar).
- Optionale E-Mails: Kauf, Aufladung, Ablauf in 30 Tagen, niedriges Guthaben.

![Guthabenseite für Gäste](../../screenshots/public-balance.png)

---

## 5. Was in den Tarifen enthalten ist

Alle Preise netto, zzgl. 20 % USt. Monatlich kündbar; bei jährlicher Zahlung sind zwei Monate gratis.

| | **Start** | **Pro** | **Gruppe** |
|---|---|---|---|
| Preis monatlich | € 29 | € 59 | ab € 129 für bis zu 3 Standorte, + € 39 je weiterem Standort |
| Preis jährlich | € 290 | € 590 | individuell |
| Für | Einzelnes Restaurant, Café, Bar | Stark frequentierte Betriebe, viele Karten, hohe Sicherheitsanforderungen | Ketten, mehrere Standorte, Hotels mit mehreren Outlets |
| Standorte | 1 | 1 | ab 3 |
| Karten und Buchungen | unbegrenzt (Fair Use) | unbegrenzt (Fair Use) | unbegrenzt (Fair Use) |
| Teammitglieder und Geräte | unbegrenzt | unbegrenzt | unbegrenzt |
| QR-Karten, NTAG213/215/216 | ✓ | ✓ | ✓ |
| Kellner-App, Dashboard, Exporte | ✓ | ✓ | ✓ |
| Gäste-E-Mails, Guthabenseite | ✓ | ✓ | ✓ |
| NTAG 424 DNA (kopiergeschützt) | — | ✓ | ✓ |
| API-Zugang (z. B. Kassenanbindung) | — | ✓ | ✓ |
| Onboarding | Video | persönlich (remote oder vor Ort in Wien) | für alle Standorte |
| Support | E-Mail, Antwort innerhalb 1 Werktag | zusätzlich Telefon, Priorität (4 Arbeitsstunden) | zentrale Ansprechperson, individueller Vertrag/SLA |
| Hilfe beim Kartendesign | — | ✓ | ✓ |

- **0 % Provision** auf Kartenverkäufe und Einlösungen.
- **Keine Einrichtungsgebühr** bei Selbst-Onboarding. Optional: Einrichtung und Teamschulung vor Ort, einmalig € 149.
- **30 Tage kostenlos testen**, ohne Kreditkarte, mit allen Pro-Funktionen.
- **Karten** (Richtpreis, abhängig von Menge und Druck — verbindliches Angebot auf Anfrage): Starterset 100 bedruckte NFC-Karten (NTAG215, beidseitig vollfarbig, in Ihrem Design) € 249; 250 Karten € 499; NTAG 424 DNA € 4–6 pro Karte. QR-Karten drucken Sie kostenlos selbst.

---

## 6. Technik und Sicherheit

| Bereich | Umsetzung |
|---|---|
| **Karte** | Chip und QR enthalten nur `https://<domain>/c/<zufällige UUID>` (122 Bit Zufall). Kartennummern sind zufällig, nicht fortlaufend, mit Prüfziffer. |
| **Buchungen** | Jede Guthabenänderung ist atomar (Datenbank-Sperre), idempotent (Doppeltipps und Netzwerk-Wiederholungen buchen nie doppelt) und steht in einem unveränderlichen Journal. Summe des Journals = Guthaben. Getestet mit 20 gleichzeitigen Einlösungen auf eine Karte. |
| **Kopierschutz** | NTAG21x: Bindung an die Seriennummer des Chips. NTAG 424 DNA: kryptografische Signatur (SUN/AES-CMAC) und Zähler bei jedem Antippen — Kopien und Wiederholungen werden abgelehnt. |
| **Zugang** | Passwörter mind. 12 Zeichen (Groß-, Kleinbuchstaben, Ziffer), bcrypt; Sperre nach 10 Fehlversuchen für 15 Minuten; Sitzungen an das Gerät gebunden; widerrufene Geräte sofort gesperrt. |
| **Mandantentrennung** | Jedes Restaurant sieht nur seine eigenen Daten, auf mehreren Ebenen durchgesetzt. |
| **Nachvollziehbarkeit** | Nichts wird gelöscht. Jede sicherheits- und geldrelevante Aktion steht mit Person, Zeit und IP-Adresse im Prüfprotokoll. |
| **Übertragung** | Nur HTTPS (TLS, HSTS), Sicherheits-Header, CSP, CSRF-Schutz; keine Tracking-Cookies in der App. |
| **Hosting** | Hetzner Online GmbH, Rechenzentren in Deutschland (EU). Nächtliche Datenbank-Backups, 14 Tage lokal plus Kopie außer Haus; tägliche Server-Snapshots. |
| **Qualität** | 113 automatisierte Backend-Tests, Browser-Abnahmetest, Barrierefreiheitsprüfung nach WCAG 2.1 AA. |
| **Technologie** | Laravel 12 / PHP 8.4, MySQL 8.4, Redis, Next.js 15 / TypeScript, Docker, Caddy, GitHub Actions. |

Gemessen im Abnahmetest: Kartenabfrage rund 0,1 Sekunden, der gesamte Einlöseablauf inklusive Eintippen der Kartennummer rund 0,5 Sekunden System- und Oberflächenzeit. Ziel am Tisch, inklusive Mensch: unter 5 Sekunden.

---

## 7. Was GiftCard Pro nicht ist

Ehrlichkeit spart beiden Seiten Zeit. Stand heute gilt:

| GiftCard Pro ist nicht … | Was das für Sie bedeutet | Geplant? |
|---|---|---|
| **… ein Online-Gutscheinshop** | Karten werden im Lokal verkauft. Es gibt noch keinen Verkauf über Ihre Website und keine Zahlungsabwicklung. | Ja, Q1 2027 |
| **… eine Registrierkasse** | GiftCard Pro ist nicht RKSV-zertifiziert und stellt keine Belege aus. Verkauf und Einlösung buchen Sie in Ihrer Registrierkasse. | Kassenanbindungen in Prüfung; API ab Pro verfügbar |
| **… auf Deutsch bedienbar (Personal)** | Die Oberfläche für Personal ist derzeit Englisch. Texte für Gäste (Karte, Guthabenseite, E-Mails) gibt es auf Deutsch und Englisch. | Ja, Q4 2026 |
| **… eine App aus dem App Store** | Die Kellner-App ist eine Web-App, die Sie auf den Startbildschirm legen. Eine native App „GiftCard Waiter" für Android und iPhone (Scannen und Einlösen) ist entwickelt, aber noch nicht im App Store und bei Google Play veröffentlicht. Bis dahin nutzen Sie wie bisher die Web-App. | Ja, native App entwickelt; Veröffentlichungstermin offen |
| **… ein Mehrstandort-Dashboard** | Jeder Standort ist ein eigenes Restaurantkonto. | Ja, Q2 2027 |
| **… Wallet-fähig** | Keine Apple- oder Google-Wallet-Karten. | Ja, Q2 2027 |
| **… mehrwährungsfähig** | Nur Euro. | CHF, BAM, RSD 2028 |
| **… ein Treue-, CRM-, Reservierungs- oder Marketingsystem** | Bewusst nicht Teil des Produkts. | Nein |
| **… zertifiziert** | Keine ISO-27001-, SOC-2- oder PCI-DSS-Zertifizierung. Gutscheinkarten sind keine Zahlungskarten im Sinne von PCI DSS. | Nicht geplant |

---

## 8. Systemvoraussetzungen

| Zweck | Voraussetzung |
|---|---|
| **Dashboard** | Aktueller Browser (Chrome, Edge, Firefox, Safari) auf Computer, Tablet oder Handy; Hell- und Dunkelmodus |
| **NFC-Karten beschreiben** | Android-Handy mit NFC und Chrome (Web NFC). Alternativ jedes Gerät mit einer NFC-Schreib-App (z. B. NFC Tools) |
| **NFC-Karten lesen, Android** | Android-Handy mit NFC und Chrome |
| **NFC-Karten lesen, iPhone** | iPhone XS oder neuer: Karte an die Oberkante halten, Mitteilung antippen |
| **QR-Code lesen** | Jedes Handy mit Kamera |
| **Ohne Chip und Kamera** | Kartennummer eintippen — funktioniert auf jedem Gerät mit Browser |
| **Verbindung** | Internetverbindung (WLAN oder Mobilfunk). Ohne Verbindung wird nichts gebucht; die App bucht bei Wiederholung nie doppelt |
| **Karten** | NTAG213, NTAG215 (empfohlen), NTAG216, NTAG 424 DNA (Pro) oder reine QR-Karten |
| **Druck** | Scheckkartenformat ISO ID-1 (85,6 × 54 mm), Vorder- und Rückseite |

Hinweis: Beim Lesen über iPhone, QR-Code oder Kartennummer wird keine Chip-Seriennummer übertragen. Für Karten mit hohem Wert empfehlen wir daher NTAG 424 DNA.

---

## 9. Sprachen

| Bereich | Sprachen heute | Geplant |
|---|---|---|
| Oberfläche für Personal (Dashboard, Kellner-App) | Englisch | Deutsch Q4 2026; Bosnisch/Kroatisch/Serbisch 2028 |
| Gedruckte Karte, Guthabenseite | Deutsch, Englisch (Sprache des Lokals) | BHS mit Markteintritt 2028 |
| Gäste-E-Mails | Vorlagen Deutsch und Englisch, bearbeitbar | BHS mit Markteintritt 2028 |
| Zahlen- und Datumsformat | de-AT, de-DE, de-CH, en-GB, en-US | — |
| Exporte | CSV mit Strichpunkt und Dezimalkomma — öffnet direkt in Excel | — |
| Support | Deutsch, Englisch, Bosnisch/Kroatisch/Serbisch | — |

In deutschen Anleitungen zitieren wir die englischen Schaltflächen wörtlich, zum Beispiel **„Redeem"** (Einlösen).

---

## 10. Kontakt

- Vertrieb: hallo@giftcardpro.at
- Support: support@giftcardpro.at
- Website: giftcardpro.at · App: app.giftcardpro.at

---

Version 1.0 · Stand: September 2026
