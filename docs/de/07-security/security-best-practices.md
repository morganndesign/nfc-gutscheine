# Sicherheits-Best-Practices für Lokale

*Konkrete Maßnahmen, mit denen Sie Ihre Gutscheinkarten, Ihr Team-Konto und die Daten Ihrer Gäste schützen – für Inhaberinnen und Inhaber sowie Manager.*

GiftCard Pro bringt viele Schutzmechanismen mit. Einige davon müssen Sie aktivieren, andere wirken nur, wenn Ihr Team sie im Alltag anwendet. Diese Checkliste ist nach Themen geordnet; jeder Punkt ist in wenigen Minuten umsetzbar.

---

## Auf einen Blick

| Nr. | Maßnahme | Wann |
|---|---|---|
| 1 | Ein eigenes Konto pro Person | bei Einrichtung, bei jedem Neuzugang |
| 2 | Starke Passwörter, Passwortmanager | sofort |
| 3 | Bildschirmsperre und Updates auf allen Handys | sofort |
| 4 | Verlorene Geräte sofort sperren | im Anlassfall |
| 5 | Rollen nach geringsten Rechten | bei jedem Neuzugang, vierteljährlich prüfen |
| 6 | NTAG 424 DNA für hohe Werte | bei der Kartenbestellung |
| 7 | Chips nach dem Beschreiben sperren | bei Einrichtung |
| 8 | Kopierschutz eingeschaltet lassen | bei Einrichtung |
| 9 | Missbrauchsgrenzen einstellen | bei Einrichtung |
| 10 | Sicherheitswarnungen im Audit-Log prüfen | wöchentlich |
| 11 | Verdächtige Karten sperren | im Anlassfall |
| 12 | Vorsicht in öffentlichen WLANs | laufend |
| 13 | Austritte am selben Tag deaktivieren | im Anlassfall |
| 14 | API-Tokens sparsam und sicher verwenden | bei Integrationen |
| 15 | Karten-Rohlinge und Druckdaten nicht offen liegen lassen | laufend |
| 16 | Phishing erkennen | laufend |

---

## 1. Ein Konto pro Person

- Legen Sie für jede Person ein eigenes Konto an: **Team → „Invite"** → Name, E-Mail, Rolle → **„Send invitation"**.
- Teilen Sie niemals ein Konto („Kellner Bar" für alle). Nur mit persönlichen Konten zeigt das Audit-Log, wer welche Einlösung gebucht hat – das schützt auch Ihre ehrlichen Mitarbeiterinnen und Mitarbeiter.
- Die eingeladene Person wählt ihr Passwort selbst über einen Link, der 72 Stunden gültig ist. Ist der Link abgelaufen, nutzen Sie **„Resend invitation"**.

## 2. Starke Passwörter und Passwortmanager

- GiftCard Pro verlangt mindestens 12 Zeichen mit Groß- und Kleinbuchstaben und einer Ziffer. Bekannte, bereits geleakte Passwörter werden abgelehnt.
- Empfehlen Sie Ihrem Team **Passphrasen** aus mehreren Wörtern, z. B. „Schnitzel-Laterne-Radweg-47". Sie sind lang und trotzdem merkbar.
- Für Inhaber und Manager: Verwenden Sie einen **Passwortmanager** (z. B. Bitwarden, 1Password, KeePassXC oder den integrierten Manager Ihres Browsers oder Handys).
- Verwenden Sie das GiftCard-Pro-Passwort nirgendwo anders.
- Details: [Passwortrichtlinie](password-policy.md).

## 3. Handys und Tablets absichern

Die Kellner-App läuft im Browser jedes Smartphones. Das Gerät ist damit Teil Ihrer Kassenumgebung.

- **Bildschirmsperre** mit PIN (mindestens 6 Stellen), Muster oder biometrisch; automatische Sperre nach spätestens 1–2 Minuten.
- **Betriebssystem und Browser aktuell halten** (automatische Updates einschalten). Geräte ohne Sicherheitsupdates des Herstellers sollten ersetzt werden.
- **Geräte benennen:** Unter **Devices** jedes Gerät mit dem Stift-Symbol umbenennen („Bar iPhone", „Terrasse Android"). Dann wissen Sie im Verlustfall sofort, welches Gerät Sie sperren müssen.
- Private Handys von Servicekräften sind möglich. Vereinbaren Sie dann schriftlich, dass Bildschirmsperre und Updates aktiv sind und ein Verlust sofort gemeldet wird.

## 4. Verlorene oder gestohlene Geräte

1. **Devices** öffnen, das Gerät suchen, **„Revoke"** wählen und bestätigen. Das Gerät wird ab der nächsten Anfrage abgewiesen – auch wenn die Sitzung noch offen war.
2. Wenn das Gerät nicht entsperrt war oder das Passwort darauf gespeichert sein könnte: Passwort der betroffenen Person zurücksetzen (Team → ⋯ → **„Send password reset"**). Ein Passwortwechsel meldet alle anderen Sitzungen ab.
3. Im Audit-Log prüfen, ob nach dem Verlustzeitpunkt noch Buchungen von diesem Gerät kamen.
4. Wird das Gerät wiedergefunden: **„Restore"**.

Geräte sperren kann standardmäßig nur die Rolle Owner. Stellen Sie sicher, dass im Anlassfall immer eine Inhaberin oder ein Inhaber erreichbar ist.

## 5. Rollen nach dem Prinzip der geringsten Rechte

| Rolle | Für wen | Was sie kann |
|---|---|---|
| **Waiter** | Servicekräfte | Karten scannen und einlösen – sonst nichts |
| **Manager** | Betriebsleitung, Schichtleitung | Karten verkaufen, aufladen, sperren, ersetzen, stornieren, Exporte, Audit-Log – aber kein Team, keine Einstellungen, keine API-Tokens |
| **Owner** | Inhaberinnen und Inhaber | alles im eigenen Lokal |

- Vergeben Sie die Rolle Owner nur an Personen, die das Lokal tatsächlich verantworten.
- Wer nur einlöst, bekommt **Waiter**.
- Prüfen Sie die Teamliste einmal pro Quartal (Checkliste im [Leitfaden Zugriffskontrolle](access-control-guide.md)).

## 6. NTAG 424 DNA für hohe Kartenwerte

- Standardkarten (NTAG215) sind durch die Bindung an die Chip-Seriennummer geschützt. Diese Prüfung funktioniert aber nur beim Scannen mit Android; iPhone, QR-Code und manuelle Nummerneingabe übermitteln keine Seriennummer.
- NTAG 424 DNA-Karten erzeugen bei jedem Antippen eine neue kryptografische Signatur und sind praktisch nicht kopierbar – auf Android und iPhone.
- **Empfehlung:** Für Karten ab etwa € 100 oder bei Firmenkunden mit großen Stückzahlen NTAG 424 DNA verwenden (im Tarif Pro enthalten).

## 7. Chips nach dem Beschreiben sperren

- **Settings → Gift cards:** „Lock tags after writing" einschalten.
- Ein gesperrter NTAG21x-Chip kann nicht mehr überschrieben werden. Das verhindert, dass jemand den Link auf einer Karte durch einen anderen ersetzt.
- Achtung: Die Sperre ist endgültig. Testen Sie das Beschreiben vorher mit einer Probekarte.

## 8. Kopierschutz eingeschaltet lassen

- **Settings → Gift cards:** Kopierschutz (Clone protection / Chip-UID-Bindung) eingeschaltet lassen.
- Beim Beschreiben mit Android wird der Chip nach dem Schreiben erneut gelesen und geprüft; erst dann wird die Seriennummer gespeichert. Mit einer anderen NFC-App beschriebene Karten (**„Mark as written"**) sind nicht an den Chip gebunden. Beschreiben Sie Karten deshalb mit einem Android-Handy und Chrome – für viele Karten auf einmal unter **Gift cards → „Program NFC tags“**.

## 9. Missbrauchsgrenzen einstellen

Unter **Settings → Gift cards** legen Sie Obergrenzen fest, die einen möglichen Schaden begrenzen:

| Einstellung | Standard | Empfehlung |
|---|---|---|
| Minimaler / maximaler Kartenwert | € 5 / € 1.000 | an Ihr Angebot anpassen |
| Maximales Kartenguthaben | € 2.000 | nicht höher als nötig |
| Maximaler Einzelbetrag pro Einlösung | – | z. B. höchster realistischer Rechnungsbetrag |
| Einlösungen pro Karte und Stunde | 10 | für die meisten Lokale ausreichend; eher senken als erhöhen |
| Aufladen erlauben | ein | ausschalten, wenn Sie keine Aufladungen anbieten |
| Teil-Einlösung erlauben | ein | nur ausschalten, wenn Karten immer vollständig eingelöst werden sollen |
| Öffentliche Guthabenabfrage | ein | ausschalten, wenn Gäste ihr Guthaben nicht selbst abfragen sollen |

## 10. Audit-Log wöchentlich prüfen

- Öffnen Sie einmal pro Woche **Audit log** und filtern Sie nach Sicherheitsereignissen. Sicherheitswarnungen sind rot mit Schild-Symbol markiert:
  - **Cloned card rejected** – eine Karte mit falscher Chip-Seriennummer oder ungültiger Signatur wurde gescannt,
  - **wiederholter NFC-Tap** (Replay) – ein alter NTAG 424 DNA-Link wurde erneut verwendet,
  - **fremde Karte** – eine Karte eines anderen Lokals wurde gescannt,
  - **Account locked** – ein Konto wurde nach 10 Fehlversuchen gesperrt.
- Prüfen Sie auffällige Muster: Stornos außerhalb der Öffnungszeiten, viele Einlösungen auf einer Karte in kurzer Zeit, Buchungen von unbekannten Geräten.
- Einzelne Warnungen haben oft harmlose Ursachen (Tippfehler, Gast mit Karte eines anderen Lokals). Mehrere Warnungen zur selben Karte oder zum selben Konto sind ein Grund zu handeln.

## 11. Verdächtige Karten

1. Karte öffnen → **⋯ → „Block card"** → Grund wählen (Reported stolen, Reported lost, Suspicious use). Eine gesperrte Karte wird in der Kellner-App rot angezeigt und kann nicht eingelöst werden.
2. Kartenverlauf ansehen: Wann, wo, von wem wurde zuletzt eingelöst?
3. Gehört die Karte nachweislich einem Gast, übertragen Sie das Guthaben mit **„Replace lost card"** auf eine neue Karte. Die alte Karte wird dauerhaft stillgelegt.
4. Bei mehreren verdächtigen Karten in kurzer Zeit: Melden Sie sich bei security@giftcardpro.at.

Servicekräfte haben standardmäßig kein Recht, Karten zu sperren. Vereinbaren Sie: Eine Karte, die rot angezeigt wird oder merkwürdig wirkt, wird nicht angenommen, und die Schichtleitung wird sofort informiert.

## 12. Öffentliche WLANs

- Die Verbindung zu GiftCard Pro ist immer verschlüsselt (HTTPS mit HSTS). Trotzdem gilt: Melden Sie sich nicht auf fremden, geteilten Computern an (Hotel-PC, Internetcafé).
- Betreiben Sie ein **eigenes WLAN für Gäste**, getrennt vom WLAN für Kassa und Servicegeräte.
- Wenn Sie sich doch an einem fremden Gerät anmelden: „Keep me signed in on this device" **nicht** anhaken, danach abmelden und das Gerät unter **Devices** sperren.

## 13. Austritte: am selben Tag deaktivieren

- Wenn jemand das Lokal verlässt: **Team → ⋯ → „Deactivate"** – am letzten Arbeitstag, nicht später.
- Deaktivieren beendet alle Sitzungen, widerruft alle API-Tokens dieser Person und verhindert jede weitere Anmeldung. Die Buchungshistorie bleibt vollständig erhalten.
- Hat die Person ein privates Handy verwendet, sperren Sie auch dieses Gerät unter **Devices**.
- Beim Wechsel der Rolle (z. B. von Manager zu Waiter) passen Sie die Rolle sofort an.

## 14. API-Tokens

API-Tokens verbinden GiftCard Pro mit anderen Systemen (z. B. einer Kassa).

- Nur so viele Berechtigungen (Abilities) wählen, wie die Integration wirklich braucht – z. B. nur Scannen und Einlösen.
- Kurze Laufzeit wählen (höchstens 365 Tage sind möglich) und vor Ablauf erneuern.
- Das Token wird **nur einmal** angezeigt. Speichern Sie es im Passwortmanager oder direkt in der Zielanwendung – nicht in E-Mails, Chats oder Tabellen.
- Nicht mehr benötigte Tokens sofort widerrufen (**Settings → API → Revoke**).
- Das Token handelt im Namen der Person, die es erstellt hat. Deaktivieren Sie diese Person, werden auch ihre Tokens widerrufen. Planen Sie das bei Personalwechseln ein.
- Prüfen Sie „zuletzt verwendet" (Zeit und IP-Adresse): Eine unbekannte IP-Adresse ist ein Warnsignal.

## 15. Karten und Kartennummern

- Beschriebene, aber noch nicht verkaufte Karten sicher verwahren, wie Bargeld.
- **„Activate immediately"** nur einschalten, wenn die Karte im selben Moment verkauft wird. Vorbereitete Karten bleiben inaktiv, bis sie bezahlt sind.
- Kartennummern, Druckbögen und CSV-Exporte nicht offen liegen lassen, nicht in sozialen Medien zeigen, nicht an Dritte weitergeben. Auf Werbefotos Nummer und QR-Code unkenntlich machen.
- CSV-Exporte enthalten Kundendaten: auf geschützten Geräten speichern und nach Gebrauch löschen.

## 16. Phishing erkennen

- **GiftCard Pro fragt Sie niemals nach Ihrem Passwort** – nicht per E-Mail, nicht am Telefon, nicht per Chat.
- Echte E-Mails von GiftCard Pro enthalten nur Links auf `giftcardpro.at` bzw. `app.giftcardpro.at`. Prüfen Sie die Adresse im Browser, bevor Sie ein Passwort eingeben.
- Seien Sie misstrauisch bei Zeitdruck („Ihr Konto wird in 2 Stunden gesperrt") und bei Anhängen.
- Einladungs- und Passwort-Links kommen nur, wenn jemand in Ihrem Lokal sie ausgelöst hat. Unerwartete Mails dieser Art bitte nicht anklicken und an security@giftcardpro.at weiterleiten.
- Unsere Supportmitarbeitenden können Ihnen helfen, ohne Ihr Passwort zu kennen.

---

## Wöchentliche Mini-Routine (5 Minuten)

- [ ] Audit-Log: rote Sicherheitswarnungen der letzten 7 Tage angesehen
- [ ] Devices: keine unbekannten Geräte, verlorene Geräte gesperrt
- [ ] Team: niemand aktiv, der nicht mehr im Lokal arbeitet
- [ ] Transaktionen: Stornos der Woche nachvollziehbar

## Kontakt

Verdacht auf Missbrauch oder Sicherheitslücke: **security@giftcardpro.at**. Allgemeine Fragen: support@giftcardpro.at.

---

Version 1.0 · Stand: September 2026
