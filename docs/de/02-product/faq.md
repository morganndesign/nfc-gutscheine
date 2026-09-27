# Häufige Fragen zu GiftCard Pro

*Antworten auf die Fragen, die Inhaberinnen und Inhaber, Betriebsleitung und Steuerberatung am häufigsten stellen. Ehrlich, auch wenn etwas (noch) nicht geht.*

---

## Allgemein

**1. Was ist GiftCard Pro?**
Ein Gutscheinkarten-System für die Gastronomie. Sie verkaufen hochwertige Geschenkkarten mit NFC-Chip und QR-Code, Ihre Servicekräfte lösen sie am Tisch mit dem Handy in Sekunden ein, und Sie sehen jederzeit, wie viel Gutscheingeld noch offen ist.

**2. Für welche Betriebe ist GiftCard Pro geeignet?**
Für Restaurants, Gasthäuser, Kaffeehäuser, Bars, Heurige und Hotelrestaurants — vom Einzelbetrieb bis zur Gruppe mit mehreren Standorten. Voraussetzung ist nur, dass Sie Gutscheine verkaufen wollen und Ihr Team ein Smartphone nutzt.

**3. Brauche ich zusätzliche Hardware?**
Nein, außer den Karten selbst. Die Kellner-App läuft auf vorhandenen Smartphones, das Dashboard in jedem Browser. Ein Android-Handy mit NFC ist praktisch, um Chips zu beschreiben und Karten mit einem Tippen zu lesen.

**4. Wie schnell bin ich startklar?**
Die Einrichtung dauert in der Regel einen Nachmittag: Kartenregeln festlegen, Team einladen, erste Karte anlegen, Kellner-Modus öffnen. Der **Welcome**-Bereich im Dashboard führt Sie durch diese Schritte. Für die bedruckten Karten rechnen Sie zusätzlich die Druck- und Lieferzeit ein.

**5. Ist die Oberfläche auf Deutsch?**
Noch nicht. Die Oberfläche für Personal (Dashboard und Kellner-App) ist derzeit Englisch. Alles, was Gäste sehen — gedruckte Karte, Guthabenseite, E-Mails —, gibt es auf Deutsch und Englisch. Die deutsche Oberfläche für Personal ist für Q4 2026 geplant und hat höchste Priorität. Die Kellner-App kommt mit wenigen, großen Knöpfen aus; unsere Anleitungen erklären jede Bezeichnung auf Deutsch.

**6. Gibt es GiftCard Pro als App im App Store?**
Noch nicht. Eine native App „GiftCard Waiter" für Android und iPhone wurde entwickelt, ist aber noch nicht im App Store und bei Google Play veröffentlicht. Sie dient ausschließlich dem Scannen und Einlösen. Bis zur Veröffentlichung verwenden Sie wie bisher die Kellner-App als Web-App, die Sie auf den Startbildschirm legen. Sie verhält sich wie eine App, braucht keine Installation über den Store und ist immer aktuell.

---

## Karten und NFC

**7. Was ist auf der Karte gespeichert?**
Nur ein Link der Form `https://<domain>/c/<zufällige Kennung>`. Kein Guthaben, kein Name, keine Kartennummer im Chip. Alles andere liegt auf dem Server.

**8. Welche Karten kann ich verwenden?**
NFC-Karten mit NTAG213, NTAG215 (empfohlen) oder NTAG216, im Tarif Pro auch NTAG 424 DNA. Außerdem reine QR-Karten ohne Chip, die Sie mit der Druckvorlage selbst drucken.

**9. Wo bekomme ich die Karten, und was kosten sie?**
Wir liefern bedruckte Karten in Ihrem Design, beidseitig vollfarbig. Richtpreise: Starterset 100 NFC-Karten (NTAG215) € 249, 250 Karten € 499, NTAG 424 DNA € 4–6 pro Karte. Richtpreise sind abhängig von Menge und Druck — verbindliches Angebot auf Anfrage. Sie können auch eigene Standard-NFC-Karten verwenden.

**10. Wie kommt der Link auf den Chip?**
Mit einem Android-Handy und Chrome tippen Sie auf **Write NFC tag** und halten die Karte ans Handy — fertig. Ohne Android kopieren Sie die angezeigte Adresse in eine NFC-Schreib-App (z. B. NFC Tools), schreiben den Chip und klicken auf **Mark as written**.

**11. Kann ich Karten auch ohne NFC nutzen?**
Ja. Jede Karte hat einen QR-Code und eine 16-stellige Kartennummer. Reine QR-Karten drucken Sie kostenlos selbst im Scheckkartenformat.

**12. Welche Handys können die Karten lesen?**
Android-Handys mit NFC und Chrome lesen die Karte direkt in der Kellner-App. iPhones ab dem Modell XS lesen die Karte, wenn man sie an die Oberkante hält; die Mitteilung öffnet die Karte. Jedes Handy mit Kamera kann den QR-Code scannen. Die Kartennummer lässt sich auf jedem Gerät eintippen.

**13. Kann eine Karte kopiert werden?**
Den Link kann jemand kopieren — aber er enthält kein Geld. Bei NTAG21x-Karten wird die Chip-Seriennummer gebunden: Eine Kopie auf einem anderen Chip wird beim Scannen mit Android abgelehnt und im Prüfprotokoll gemeldet. Bei iPhone-, QR- oder Nummern-Abfragen wird keine Seriennummer übertragen. Für Karten mit hohem Wert empfehlen wir deshalb NTAG 424 DNA (Pro): Diese Chips erzeugen bei jedem Antippen eine kryptografische Signatur, Kopien und Wiederholungen werden abgelehnt.

**14. Was passiert, wenn ein Gast die Karte verliert?**
Ist die Karte einer Kundin oder einem Kunden zugeordnet oder kennt der Gast die Kartennummer, ersetzen Sie sie mit **⋯ → Replace lost card**. Das Guthaben geht auf eine neue Karte, die alte funktioniert sofort nicht mehr. Bei anonym verkauften Karten ohne Nummer ist das nicht möglich — wie bei Bargeld.

**15. Kann ich das Design der Karte selbst gestalten?**
Ja. Die bedruckten Karten werden mit Ihrem Design produziert. Im Tarif Pro helfen wir beim Kartendesign. Die Druckvorlage für QR-Karten zeigt Name des Lokals, Wert und beschenkte Person auf der Vorderseite, QR-Code, Nummer und Gültigkeit auf der Rückseite.

![Druckvorlage](../../screenshots/print-card.png)

---

## Einlösung

**16. Wie läuft eine Einlösung am Tisch ab?**
Karte antippen oder scannen, Betrag auf der Tastatur eintippen (`2 4 9 0` → € 24,90) oder **Full balance** wählen, dann **Redeem € 24,90** drücken. Der Erfolgsbildschirm zeigt das Restguthaben für den Gast. Ziel: unter fünf Sekunden inklusive Mensch.

**17. Kann ein Gast einen Gutschein in mehreren Teilen einlösen?**
Ja, Teileinlösungen sind möglich. Sie können sie in den Einstellungen abschalten, dann wird immer das ganze Guthaben eingelöst.

**18. Was ist, wenn die Rechnung höher ist als das Guthaben?**
Die App zeigt einen Hinweis. Die Servicekraft löst das ganze Guthaben ein und kassiert den Rest bar oder mit Karte.

**19. Was passiert, wenn das Internet ausfällt?**
Ohne Verbindung wird nichts gebucht, und die App zeigt das an. Sobald die Verbindung wieder da ist, drückt die Servicekraft erneut. Eine Buchung wird nie doppelt ausgeführt, auch nicht bei Wiederholungen.

**20. Können zwei Servicekräfte dieselbe Karte gleichzeitig einlösen?**
Sie können es versuchen, aber das Guthaben wird nie überzogen. Jede Buchung sperrt die Karte in der Datenbank kurz. Wir haben das mit 20 gleichzeitigen Einlösungen auf eine Karte getestet.

**21. Eine Servicekraft hat einen falschen Betrag eingelöst. Was tun?**
Unter **Transactions** oder im Verlauf der Karte die Buchung mit **Reverse** stornieren und einen Grund wählen (Wrong amount, Wrong card, Guest cancelled). Die Korrektur wird als Gegenbuchung eingetragen; nichts wird gelöscht.

**22. Kann ich Karten aufladen?**
Ja, mit **Reload** auf der Kartenseite. Das Aufladen kann in den Einstellungen abgeschaltet werden.

**23. Was sieht die Servicekraft bei einer gesperrten oder ersetzten Karte?**
Eine rote Warnung und einen großen **Next card**-Knopf. Bei einer ersetzten Karte steht zusätzlich „Ask the guest for the new card". Inaktive und leere Karten zeigen eine gelbe Warnung, abgelaufene Karten eine eigene Meldung.

---

## Gäste

**24. Wie prüft ein Gast sein Guthaben?**
Er hält die Karte an sein Handy oder scannt den QR-Code. Es öffnet sich eine Seite in der Sprache Ihres Lokals mit Guthaben, Status, Gültigkeit und maskierter Kartennummer. Sie können diese Seite in den Einstellungen abschalten.

**25. Bekommen Gäste E-Mails?**
Nur, wenn Sie eine E-Mail-Adresse erfassen und die Funktion eingeschaltet ist: beim Kauf, beim Aufladen, 30 Tage vor Ablauf und bei einem Guthaben unter € 5. Die Vorlagen auf Deutsch und Englisch können Sie bearbeiten.

**26. Muss ich Daten der Käuferin oder des Käufers erfassen?**
Nein. Karten können anonym verkauft werden. Mit Kontaktdaten können Sie eine verlorene Karte aber leichter ersetzen und Bestätigungen senden.

**27. Kann ein Gast die Karte in Apple Wallet oder Google Wallet speichern?**
Noch nicht. Wallet-Karten sind für Q2 2027 geplant.

---

## Sicherheit und Betrug

**28. Wie wird verhindert, dass jemand Kartennummern errät?**
Kartennummern sind zufällig und nicht fortlaufend, die Links enthalten eine zufällige 122-Bit-Kennung. Fehlgeschlagene Kartenabfragen werden gedrosselt, und nach zu vielen Fehlversuchen wird gesperrt.

**29. Was passiert, wenn ein Diensthandy verloren geht?**
Unter **Devices** auf **Revoke** klicken. Das Handy kann ab sofort keine Karten mehr scannen oder einlösen. Sitzungen sind an das Gerät gebunden; eine kopierte Sitzung funktioniert auf keinem anderen Gerät.

**30. Sehe ich, wer welche Buchung gemacht hat?**
Ja. Jede Buchung steht mit Person, Zeit, Gerät und Guthaben danach im Verlauf. Das **Audit log** zeigt zusätzlich alle sicherheitsrelevanten Aktionen mit IP-Adresse; Warnungen wie eine kopierte Karte sind rot markiert. Deshalb sollte jede Person einen eigenen Zugang haben.

**31. Gibt es eine Betrugsgrenze?**
Ja. Standardmäßig sind höchstens 10 Einlösungen pro Karte und Stunde möglich. Zusätzlich können Sie eine maximale Einzeleinlösung und ein maximales Kartenguthaben festlegen.

**32. Ist GiftCard Pro zertifiziert (ISO 27001, SOC 2, PCI DSS)?**
Nein. Wir haben keine solchen Zertifizierungen und behaupten das auch nicht. PCI DSS betrifft Zahlungskarten; Gutscheinkarten sind keine. Die umgesetzten Sicherheitsmaßnahmen beschreiben wir offen in unserer Sicherheitsdokumentation.

---

## Datenschutz

**33. Wo werden die Daten gespeichert?**
Bei der Hetzner Online GmbH in Rechenzentren in Deutschland (EU). Datenbank-Backups werden nächtlich erstellt, 14 Tage lokal und zusätzlich außer Haus aufbewahrt.

**34. Wer ist datenschutzrechtlich verantwortlich?**
Für die Daten Ihrer Gäste ist Ihr Lokal Verantwortlicher, wir sind Auftragsverarbeiter nach Art. 28 DSGVO. Dafür schließen wir einen Auftragsverarbeitungsvertrag ab. Für die Daten Ihres Kundenkontos bei uns sind wir selbst verantwortlich.

**35. Setzt die App Cookies ein?**
Nur technisch notwendige: das Sitzungs-Cookie und ein Cookie zum Schutz gegen gefälschte Anfragen (CSRF). Dazu eine zufällige Gerätekennung im Browser-Speicher für die Gerätebindung. Keine Analyse-, Werbe- oder Drittanbieter-Cookies.

**36. Ein Gast verlangt die Löschung seiner Daten. Was tun?**
Öffnen Sie die Kundin oder den Kunden und wählen Sie Anonymisieren. Name, E-Mail und Telefon werden entfernt, die Buchungen bleiben für die Aufbewahrungspflicht erhalten.

---

## Recht und Steuern

> **Keine Rechtsberatung.** Die folgenden Antworten sind allgemeine Hinweise für Österreich. Klären Sie Ihren Fall mit Ihrer Steuerberatung oder einer Rechtsanwältin bzw. einem Rechtsanwalt.

**37. Wie lange muss ein Gutschein gültig sein?**
Bezahlte Gutscheine sind ohne Befristung 30 Jahre gültig (§ 1478 ABGB). Nach der Rechtsprechung des OGH ist eine Befristung auf drei Jahre oder weniger in allgemeinen Geschäftsbedingungen in der Regel gröblich benachteiligend und unwirksam (§ 879 Abs 3 ABGB). Wir empfehlen daher, die Standard-Gültigkeit (**Default validity**) bei der Einrichtung auf **0** (kein Ablauf) zu stellen — die Werkseinstellung ist derzeit 36 Monate. Ab Q4 2026 wird „unbegrenzt" die Werkseinstellung für neue Restaurants. Quelle: WKO „Gutscheine – Befristung".

**38. Was passiert, wenn eine Karte trotzdem abläuft?**
GiftCard Pro bucht das Restguthaben als Ablauf aus. Der Gast kann rechtlich dennoch einen Anspruch haben. Sie können das Guthaben mit einer Ersatzkarte oder einer Übertragung wieder verfügbar machen.

**39. Wann fällt Umsatzsteuer an?**
Seit 2019 unterscheidet man Einzweck- und Mehrzweckgutscheine. Restaurantgutscheine über einen Wert, die für Speisen (10 %) und Getränke (20 %) eingelöst werden können, sind in der Regel Mehrzweckgutscheine: Die Umsatzsteuer entsteht bei der Einlösung, nicht beim Verkauf. Quelle: WKO „Umsatzsteuerliche Behandlung von Gutscheinen".

**40. Ersetzt GiftCard Pro meine Registrierkasse?**
Nein. GiftCard Pro ist keine Registrierkasse, nicht RKSV-zertifiziert und stellt keine Belege aus. Verkauf und Einlösung buchen Sie in Ihrer Registrierkasse nach den Vorgaben Ihrer Steuerberatung.

**41. Was zeigt mir die offene Verbindlichkeit?**
Die Kennzahl **Outstanding balance** ist die Summe aller Guthaben, die Gäste noch einlösen können. Für bilanzierende Betriebe ist das eine Verbindlichkeit; bei Einnahmen-Ausgaben-Rechnung wird der Verkauf in der Regel bereits beim Zufluss erfasst. Welche Behandlung für Sie gilt, klärt Ihre Steuerberatung.

**42. Wie lange bleiben die Buchungen gespeichert?**
Buchungen werden nie gelöscht. Damit können Sie die Aufbewahrungspflicht von 7 Jahren (§ 132 BAO) erfüllen. Nach Vertragsende haben Sie 30 Tage Zeit für den Export; danach werden die Daten gelöscht, soweit keine gesetzliche Aufbewahrung besteht.

---

## Preise und Vertrag

**43. Was kostet GiftCard Pro?**
Start € 29 pro Monat (€ 290 jährlich), Pro € 59 pro Monat (€ 590 jährlich), Gruppe ab € 129 pro Monat für bis zu drei Standorte plus € 39 je weiterem Standort. Alle Preise netto, zzgl. 20 % USt. Bei jährlicher Zahlung sind zwei Monate gratis.

**44. Verlangen Sie eine Provision?**
Nein. 0 % Provision auf Kartenverkäufe und Einlösungen — heute und auch beim geplanten Online-Verkauf.

**45. Gibt es eine Einrichtungsgebühr?**
Nein, wenn Sie selbst einrichten. Optional richten wir vor Ort ein und schulen Ihr Team, einmalig € 149 (für Pilotbetriebe kostenlos).

**46. Kann ich GiftCard Pro testen?**
Ja, 30 Tage kostenlos, ohne Kreditkarte, mit allen Pro-Funktionen.

**47. Was ist das Pilotprogramm?**
Für die ersten 10 Restaurants in Wien (Oktober–November 2026): 3 Monate gratis, danach 12 Monate 50 % Rabatt (Start € 14,50, Pro € 29,50), kostenlose Einrichtung vor Ort und 50 Karten gratis. Im Gegenzug bitten wir um regelmäßige Feedback-Gespräche und — nach Ihrer Freigabe — die Erlaubnis, Sie als Referenz zu nennen.

**48. Wie kann ich kündigen?**
Monatstarife sind zum Monatsende kündbar, Jahrestarife zum Ende der Laufzeit. GiftCard Pro richtet sich nur an Unternehmen.

**49. Wie wird abgerechnet?**
Derzeit per Monats- oder Jahresrechnung, bezahlt per SEPA-Lastschrift oder Überweisung. Ab Q4 2026 erfolgt die Abrechnung automatisch über Stripe.

**50. Kann ich Gutscheine online verkaufen?**
Noch nicht. Heute verkaufen Sie Karten im Lokal und kassieren an Ihrer eigenen Registrierkasse. Der Online-Verkauf über Ihre Website — mit Online-Zahlung, PDF-Gutschein und optional Karte per Post — ist für Q1 2027 geplant. Auch dann verlangen wir keine Provision; es fallen nur die Gebühren des Zahlungsanbieters an.

---

## Technik

**51. Kann ich GiftCard Pro an meine Kassa anbinden?**
Im Tarif Pro gibt es eine API mit eingeschränkten API-Schlüsseln (bis 365 Tage gültig, jederzeit widerrufbar). Damit kann ein Kassenanbieter oder Dienstleister Karten abfragen und einlösen. Fertige Anbindungen an ready2order, orderbird und SumUp POS sind in Prüfung (Q1 2027).

**52. Kann ich mehrere Standorte verwalten?**
Ja, jeder Standort ist derzeit ein eigenes Restaurantkonto. Ein gemeinsames Dashboard für Gruppen ist für Q2 2027 geplant.

**53. Wie verfügbar ist der Dienst?**
Unser Ziel ist eine Verfügbarkeit von 99,5 % pro Monat. Im Tarif Start ist das ein Ziel, keine Garantie; im Tarif Gruppe kann ein vertragliches SLA vereinbart werden.

**54. Welche Währungen werden unterstützt?**
Derzeit nur Euro. Schweizer Franken, Konvertible Mark und Serbischer Dinar sind für 2028 geplant.

**55. Wie öffne ich die Exporte in Excel?**
Klicken Sie auf **Export CSV** unter **Gift cards** oder **Transactions**. Die Datei verwendet Strichpunkt und Dezimalkomma und öffnet sich direkt in der österreichischen bzw. deutschen Excel-Version.

---

## Support

**56. Wie erreiche ich den Support?**
Per E-Mail an support@giftcardpro.at. Im Tarif Start antworten wir innerhalb eines Werktags, im Tarif Pro zusätzlich per Telefon und mit Priorität (innerhalb von 4 Arbeitsstunden). Im Tarif Gruppe gibt es eine zentrale Ansprechperson.

**57. In welchen Sprachen gibt es Support?**
Deutsch und Englisch; Anfragen auf Bosnisch, Kroatisch oder Serbisch beantworten wir ebenfalls.

**58. Hilft mir jemand beim Einrichten?**
Im Tarif Start gibt es ein Video-Onboarding. Im Tarif Pro richten wir persönlich mit Ihnen ein — remote oder vor Ort in Wien. Die Einrichtung vor Ort mit Teamschulung können Sie in jedem Tarif für einmalig € 149 dazubuchen.

**59. Wie melde ich eine Sicherheitslücke?**
Bitte per E-Mail an security@giftcardpro.at, mit einer kurzen Beschreibung, wie sich das Problem nachvollziehen lässt. Bitte veröffentlichen Sie Details erst, wenn wir das Problem beheben konnten.

---

Version 1.0 · Stand: September 2026
