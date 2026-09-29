# Sicherheits-Best-Practices für Lokale

*Konkrete Maßnahmen, mit denen Sie Ihre Gutscheine, Ihr Team-Konto und die Daten Ihrer Gäste schützen – für Inhaberinnen und Inhaber sowie die Betriebsleitung.*

GiftCard Pro bringt viele Schutzmechanismen mit. Einige davon stellen Sie ein, andere wirken nur, wenn Ihr Team sie im Alltag anwendet. Diese Checkliste ist nach Themen geordnet; jeder Punkt ist in wenigen Minuten umsetzbar.

---

## Auf einen Blick

| Nr. | Maßnahme | Wann |
|---|---|---|
| 1 | Ein eigenes Konto pro Person | bei Einrichtung, bei jedem Neuzugang |
| 2 | Starke Passwörter, Passwortmanager | sofort |
| 3 | Bildschirmsperre und Updates auf allen Handys | sofort |
| 4 | Verlorene Geräte sofort sperren | im Anlassfall |
| 5 | Rollen nach geringsten Rechten | bei jedem Neuzugang, vierteljährlich prüfen |
| 6 | Einlösen nur per Scan | laufend |
| 7 | Jeden Verkauf mit der richtigen Zahlung erfassen | bei jedem Verkauf und jeder Aufladung |
| 8 | Druckblätter wie Bargeld behandeln | laufend |
| 9 | Missbrauchsgrenzen einstellen | bei Einrichtung |
| 10 | Audit-Log prüfen | wöchentlich |
| 11 | Verdächtige Gutscheine sperren | im Anlassfall |
| 12 | Vorsicht in öffentlichen WLANs | laufend |
| 13 | Austritte am selben Tag deaktivieren | im Anlassfall |
| 14 | API-Tokens sparsam und sicher verwenden | bei Integrationen |
| 15 | Exporte und interne Nummern schützen | laufend |
| 16 | Phishing erkennen | laufend |

---

## 1. Ein Konto pro Person

- Legen Sie für jede Person ein eigenes Konto an: **Team → „Invite“** → Name, E-Mail, Rolle → **„Send invitation“**.
- Teilen Sie niemals ein Konto („Kellner Bar“ für alle). Nur mit persönlichen Konten zeigt das Audit-Log, wer welche Einlösung gebucht hat – das schützt auch Ihre ehrlichen Mitarbeiterinnen und Mitarbeiter.
- Die eingeladene Person wählt ihr Passwort selbst über einen Link, der 72 Stunden gültig ist. Ist der Link abgelaufen, senden Sie die Einladung erneut.

## 2. Starke Passwörter und Passwortmanager

- GiftCard Pro verlangt mindestens 12 Zeichen mit Groß- und Kleinbuchstaben und einer Ziffer. Bekannte, bereits geleakte Passwörter werden abgelehnt.
- Empfehlen Sie Ihrem Team **Passphrasen** aus mehreren Wörtern, z. B. „Schnitzel-Laterne-Radweg-47“. Sie sind lang und trotzdem merkbar.
- Für Inhaberinnen, Inhaber und die Betriebsleitung: Verwenden Sie einen **Passwortmanager** (z. B. Bitwarden, 1Password, KeePassXC oder den integrierten Manager Ihres Browsers oder Handys).
- Verwenden Sie das GiftCard-Pro-Passwort nirgendwo anders.
- Details: [Passwortrichtlinie](password-policy.md).

## 3. Handys und Tablets absichern

Die Kellner-App GiftCard Waiter (Android und iPhone) bzw. die Web-Kassa im Browser läuft auf den Handys Ihres Teams. Das Gerät ist damit Teil Ihrer Kassenumgebung.

- **Bildschirmsperre** mit PIN (mindestens 6 Stellen), Muster oder biometrisch; automatische Sperre nach spätestens 1–2 Minuten.
- **Betriebssystem, App und Browser aktuell halten** (automatische Updates einschalten). Geräte ohne Sicherheitsupdates des Herstellers sollten ersetzt werden.
- **Geräte benennen:** Unter **Devices** jedes Gerät mit dem Stift-Symbol umbenennen („Bar iPhone“, „Terrasse Android“). Dann wissen Sie im Verlustfall sofort, welches Gerät Sie sperren müssen.
- Private Handys von Servicekräften sind möglich. Vereinbaren Sie dann schriftlich, dass Bildschirmsperre und Updates aktiv sind und ein Verlust sofort gemeldet wird.

## 4. Verlorene oder gestohlene Geräte

1. **Devices** öffnen, das Gerät suchen, **„Revoke“** wählen und bestätigen. Das Gerät wird ab der nächsten Anfrage abgewiesen – auch wenn die Sitzung oder die Anmeldung der Kellner-App noch offen war.
2. Wenn das Gerät nicht gesperrt war oder das Passwort darauf gespeichert sein könnte: Passwort der betroffenen Person zurücksetzen (Team → ⋯ → **„Send password reset“**). Eine Zurücksetzung widerruft alle Tokens der Person und meldet alle anderen Sitzungen ab.
3. Im Audit-Log prüfen, ob nach dem Verlustzeitpunkt noch Buchungen von diesem Gerät kamen.
4. Wird das Gerät wiedergefunden: **„Restore“**.

Geräte sperren kann standardmäßig nur die Rolle Owner. Stellen Sie sicher, dass im Anlassfall immer eine Inhaberin oder ein Inhaber erreichbar ist.

## 5. Rollen nach dem Prinzip der geringsten Rechte

| Rolle | Für wen | Was sie kann |
|---|---|---|
| **Waiter** | Servicekräfte | Gutscheine per QR-Scan einlösen – sonst nichts |
| **Manager** | Betriebsleitung, Schichtleitung | Gutscheine verkaufen, aufladen, sperren, stornieren, Exporte, Audit-Log – aber kein Team, keine Einstellungen, keine API-Tokens, kein Ablauf, keine Gratis-Gutscheine |
| **Owner** | Inhaberinnen und Inhaber | alles im eigenen Lokal |

- Vergeben Sie die Rolle Owner nur an Personen, die das Lokal tatsächlich verantworten.
- Wer nur einlöst, bekommt **Waiter**.
- Prüfen Sie die Teamliste einmal pro Quartal (Checkliste im [Leitfaden Zugriffskontrolle](access-control-guide.md)).

## 6. Einlösen nur per Scan

- Ein Gutschein wird **nur** eingelöst, indem sein QR-Code gescannt wird – in der Kellner-App oder unter **Redeem** im Browser. Der Scan erzeugt eine Vorlage, die 60 Sekunden gilt und genau eine Einlösung erlaubt.
- Die interne Gutscheinnummer ist **kein** Zahlungsmittel. Sie steht nicht auf dem Druckblatt und kann nicht zum Einlösen eingegeben werden. Wer eine Nummer am Telefon oder per Foto „einlösen“ möchte, wird abgewiesen.
- Zeigt die App „nicht erkannt“, ist der QR-Code kein gültiger Gutschein Ihres Lokals (unbekannt, widerrufen oder von einem anderen Lokal). Nicht mehrfach probieren – nach 10 Fehlversuchen in 5 Minuten sperrt GiftCard Pro das Gerät kurz.
- Bleibt nach einer Einlösung die Antwort aus, zeigt die App „Ergebnis unklar“ und fragt beim Server nach. **Nicht** erneut abbuchen, bis das Ergebnis feststeht.
- Physische Karten sind als NTAG-424-DNA-Karten mit Live-Prüfung vorgesehen; bis dahin gibt es in GiftCard Pro nur digitale Gutscheine mit QR-Code.

## 7. Jeden Verkauf mit der richtigen Zahlung erfassen

- Jeder Verkauf und jede Aufladung verlangt eine Zahlungsart: **bar**, **Kartenterminal** (mit Belegnummer), **Überweisung** (mit Referenz) oder **gratis** (nur Owner, mit Begründung).
- Erfassen Sie Verkauf und Einlösung zusätzlich in Ihrer Registrierkasse. Die Zahlungen in GiftCard Pro erleichtern den Abgleich.
- Prüfen Sie Gratis-Gutscheine regelmäßig im Audit-Log.

## 8. Druckblätter wie Bargeld behandeln

- Der QR-Code auf dem Druckblatt **ist** der Gutschein: Wer ihn scannen lässt, kann das Guthaben einlösen. Das Druckblatt zeigt weder Wert noch Gutscheinnummer.
- Druckblätter sofort dem Gast übergeben; nicht offen liegen lassen, nicht fotografieren, nicht in sozialen Medien zeigen.
- Der QR-Code wird nur einmal – beim Verkauf – angezeigt und kann nicht erneut abgerufen werden. Ging die Antwort des Verkaufs verloren, liefert die Wiederholung desselben Verkaufs innerhalb von 15 Minuten auf demselben Gerät einen neuen QR-Code, solange der Gutschein unbenutzt ist; der ungesehene alte wird ungültig.
- Meldet ein Gast den Verlust seines Druckblatts: Gutschein sofort sperren (Abschnitt 11).

## 9. Missbrauchsgrenzen einstellen

Unter **Settings → Vouchers** legen Sie Obergrenzen fest, die einen möglichen Schaden begrenzen:

| Einstellung | Standard | Empfehlung |
|---|---|---|
| Minimaler Gutscheinwert | € 5 | an Ihr Angebot anpassen |
| Maximales Guthaben | € 500 | nicht höher als nötig |
| Maximaler Betrag pro Einlösung | € 250 | höchster realistischer Rechnungsbetrag |
| Maximaler Betrag pro Gutschein und Tag | € 500 | nicht höher als nötig |
| Einlösungen pro Gutschein und Stunde | 10 | für die meisten Lokale ausreichend; eher senken als erhöhen |
| Aufladen erlauben | ein | ausschalten, wenn Sie keine Aufladungen anbieten |
| Teil-Einlösung erlauben | ein | nur ausschalten, wenn Gutscheine immer vollständig eingelöst werden sollen |
| Gültigkeit | kein Ablauf | wenn überhaupt, mindestens 36 Monate; ein abgelaufener Gutschein behält sein Guthaben |

Die Plattform setzt Obergrenzen, die kein Lokal überschreiten kann.

## 10. Audit-Log wöchentlich prüfen

- Öffnen Sie einmal pro Woche **Audit log** und achten Sie auf:
  - **fehlgeschlagene Vorlagen** (`presentment.failed`) – ein gescannter Code war kein gültiger Gutschein Ihres Lokals; gehäuft auf einem Gerät ist das ein Warnsignal,
  - **Kontosperren** (`auth.locked`) – ein Konto wurde nach 10 Fehlversuchen gesperrt,
  - **Gratis-Gutscheine, Storni, Ablauf und Wiederfreigaben** – nachvollziehbar und begründet?
- Prüfen Sie auffällige Muster: Storni außerhalb der Öffnungszeiten, viele Einlösungen auf einem Gutschein in kurzer Zeit, Buchungen von unbekannten Geräten.
- Einzelne Warnungen haben oft harmlose Ursachen (verschmutzter QR-Code, Gutschein eines anderen Lokals). Mehrere Warnungen zum selben Gerät oder zum selben Konto sind ein Grund zu handeln.
- Der Verlauf ist unveränderlich: Niemand – auch nicht GiftCard Pro – kann Buchungen oder Audit-Einträge nachträglich ändern oder löschen; eine nächtliche Prüfung würde jede Änderung bemerken.

## 11. Verdächtige Gutscheine

1. Gutschein öffnen → **„Block“** → Grund angeben (z. B. Verlust gemeldet, verdächtige Nutzung). Ein gesperrter Gutschein kann nicht eingelöst werden.
2. Verlauf ansehen: Wann, auf welchem Gerät, von wem wurde zuletzt eingelöst?
3. Ist der Verdacht ausgeräumt: **„Unblock“**.
4. Bei mehreren verdächtigen Gutscheinen in kurzer Zeit: Melden Sie sich bei security@giftcardpro.at.

Servicekräfte haben standardmäßig kein Recht, Gutscheine zu sperren. Vereinbaren Sie: Ein Gutschein, der gesperrt angezeigt wird oder merkwürdig wirkt, wird nicht angenommen, und die Schichtleitung wird sofort informiert.

## 12. Öffentliche WLANs

- Die Verbindung zu GiftCard Pro ist immer verschlüsselt (HTTPS mit HSTS). Trotzdem gilt: Melden Sie sich nicht auf fremden, geteilten Computern an (Hotel-PC, Internetcafé).
- Betreiben Sie ein **eigenes WLAN für Gäste**, getrennt vom WLAN für Kassa und Servicegeräte.
- Wenn Sie sich doch an einem fremden Gerät anmelden: „Keep me signed in on this device“ **nicht** anhaken, danach abmelden und das Gerät unter **Devices** sperren.

## 13. Austritte: am selben Tag deaktivieren

- Wenn jemand das Lokal verlässt: **Team → ⋯ → „Deactivate“** – am letzten Arbeitstag, nicht später.
- Deaktivieren beendet alle Sitzungen, widerruft alle Tokens dieser Person (auch die Anmeldung der Kellner-App) und verhindert jede weitere Anmeldung. Die Buchungshistorie bleibt vollständig erhalten.
- Hat die Person ein privates Handy verwendet, sperren Sie auch dieses Gerät unter **Devices**.
- Beim Wechsel der Rolle (z. B. von Manager zu Waiter) passen Sie die Rolle sofort an.

## 14. API-Tokens

API-Tokens verbinden GiftCard Pro mit anderen Systemen (z. B. einer Kassa).

- Nur so viele Berechtigungen (Abilities) wählen, wie die Integration wirklich braucht – z. B. nur Ansehen und Einlösen.
- Kurze Laufzeit wählen (höchstens 365 Tage sind möglich) und vor Ablauf erneuern.
- Das Token wird **nur einmal** angezeigt. Speichern Sie es im Passwortmanager oder direkt in der Zielanwendung – nicht in E-Mails, Chats oder Tabellen.
- Nicht mehr benötigte Tokens sofort widerrufen (**Settings → API → Revoke**).
- Das Token handelt im Namen der Person, die es erstellt hat. Deaktivieren Sie diese Person oder ändert sie ihr Passwort, werden auch ihre Tokens widerrufen. Planen Sie das bei Personalwechseln ein.
- Prüfen Sie „zuletzt verwendet“ (Zeit und IP-Adresse): Eine unbekannte IP-Adresse ist ein Warnsignal.

## 15. Exporte und interne Nummern schützen

- Gutscheinnummern sind intern (für Personal und Support). Sie sind kein Zahlungsmittel, gehören aber trotzdem nicht in soziale Medien oder an Dritte.
- CSV-Exporte enthalten Kundendaten: auf geschützten Geräten speichern und nach Gebrauch löschen.
- Gäste-E-Mails enthalten nie Guthaben, Betrag, Gutscheinnummer oder einen Link zum Gutschein. Eine E-Mail, die angeblich von GiftCard Pro kommt und ein Guthaben zeigt oder zum „Abrufen“ eines Gutscheins auffordert, ist gefälscht.

## 16. Phishing erkennen

- **GiftCard Pro fragt Sie niemals nach Ihrem Passwort** – nicht per E-Mail, nicht am Telefon, nicht per Chat.
- Echte E-Mails von GiftCard Pro enthalten nur Links auf `giftcardpro.at` bzw. `app.giftcardpro.at`. Prüfen Sie die Adresse im Browser, bevor Sie ein Passwort eingeben.
- Seien Sie misstrauisch bei Zeitdruck („Ihr Konto wird in 2 Stunden gesperrt“) und bei Anhängen.
- Einladungs- und Passwort-Links kommen nur, wenn jemand in Ihrem Lokal sie ausgelöst hat. Unerwartete Mails dieser Art bitte nicht anklicken und an security@giftcardpro.at weiterleiten.
- Unsere Supportmitarbeitenden können Ihnen helfen, ohne Ihr Passwort zu kennen.

---

## Wöchentliche Mini-Routine (5 Minuten)

- [ ] Audit-Log: fehlgeschlagene Vorlagen, Kontosperren, Gratis-Gutscheine der letzten 7 Tage angesehen
- [ ] Devices: keine unbekannten Geräte, verlorene Geräte gesperrt
- [ ] Team: niemand aktiv, der nicht mehr im Lokal arbeitet
- [ ] Transaktionen: Storni der Woche nachvollziehbar, Zahlungen passen zur Registrierkasse

## Kontakt

Verdacht auf Missbrauch oder Sicherheitslücke: **security@giftcardpro.at**. Allgemeine Fragen: support@giftcardpro.at.

---

Version 2.0 · Stand: September 2026
