# Sicherheit – Häufige Fragen

*Kurze, ehrliche Antworten auf die Fragen, die uns Inhaberinnen und Inhaber, Steuerberatung und IT-Betreuung zur Sicherheit von GiftCard Pro stellen.*

---

## Gutscheine

### 1. Was steht auf dem Gutschein?

Ein QR-Code und der Name Ihres Lokals – sonst nichts. Der QR-Code enthält ein zufälliges 256-Bit-Geheimnis (`GCPV1.` gefolgt von 43 Zeichen). Er ist kein Link und enthält weder Guthaben noch Wert, Gutscheinnummer, Name oder E-Mail-Adresse. Guthaben und Verlauf liegen ausschließlich auf dem Server, und der Server speichert vom Geheimnis nur einen SHA-256-Hash.

### 2. Kann jemand einen Gutschein kopieren oder erraten?

Erraten: praktisch nein – 256 Bit Zufall. Zusätzlich sind fehlgeschlagene Scans auf 10 pro 5 Minuten je Lokal, Person und Gerät begrenzt, und jeder Fehlversuch steht im Audit-Log.

Kopieren: Wer ein Foto des QR-Codes hat, hat den Gutschein – wie bei einem Geldschein. Behandeln Sie Druckblätter deshalb wie Bargeld. Eingelöst werden kann ein Gutschein nur in Ihrem Lokal, von einer angemeldeten Person auf einem registrierten Gerät; jede Einlösung steht mit Person und Gerät im Verlauf. Die interne Gutscheinnummer ist kein Berechtigungsnachweis und kann nicht zum Einlösen verwendet werden.

### 3. Gibt es physische Karten mit NFC?

Physische Karten sind als **NTAG 424 DNA**-Karten mit Live-Authentifizierung vorgesehen: Die Kellner-App leitet die Kommunikation des Chips an einen Krypto-Dienst weiter, der die Kartenschlüssel in einem Hardware-Sicherheitsmodul hält und beweist, dass der echte Chip in diesem Moment vorliegt. Solange dieser Dienst nicht in Betrieb ist, liest, beschreibt und programmiert GiftCard Pro keine NFC-Chips, und die App hat keine NFC-Berechtigung. Einfache NFC-Aufkleber mit einem Link werden nie unterstützt, weil sie sich kopieren lassen.

### 4. Was passiert, wenn ein Gast seinen Gutschein verliert?

Sie sperren den Gutschein (**„Block“**). Ab sofort kann er nirgends eingelöst werden; wer das Druckblatt findet, kann damit nichts anfangen. Wird es wiedergefunden, heben Sie die Sperre auf (**„Unblock“**).

### 5. Wie funktioniert eine Einlösung – und warum ist das sicher?

1. Die Servicekraft scannt den QR-Code. Der Server prüft ihn und bestätigt den **Scan**: gültig 60 Sekunden, nur für eine Abbuchung, gebunden an Ihr Lokal, diesen Gutschein, die Person und das Gerät.
2. Die Servicekraft tippt den Betrag. Die Einlösung verbraucht den Scan; eine zweite Einlösung braucht einen neuen Scan.

Ohne den Gutschein selbst kann also niemand abbuchen – auch nicht mit Gutscheinnummer, Screenshot eines alten Scans oder der Anmeldung einer anderen Person.

### 6. Kann eine Servicekraft einen Gutschein doppelt belasten, etwa durch Doppel-Tippen?

Nein. Jede Einlösung trägt einen eindeutigen Idempotenzschlüssel. Kommt dieselbe Anfrage zweimal an – durch Doppel-Tippen oder weil das Netz kurz weg war –, wird sie nur einmal gebucht. Bleibt eine Antwort aus, fragt die App mit diesem Schlüssel beim Server nach, ob gebucht wurde, statt erneut abzubuchen.

### 7. Was passiert, wenn zwei Servicekräfte gleichzeitig denselben Gutschein einlösen?

Die Datenbank sperrt den Gutschein für die Dauer jeder Buchung, die Einlösungen werden nacheinander verarbeitet. Ein Guthaben kann dadurch nie doppelt ausgegeben werden oder unter null fallen. Automatisierte Tests prüfen das bei jeder Änderung, auch gegen MySQL.

### 8. Kann eine Buchung nachträglich verändert oder gelöscht werden?

Nein. Buchungsjournal, Zahlungen und Audit-Log sind unveränderlich: Die Datenbank selbst lehnt Änderungen und Löschungen ab, und jeder Eintrag ist über eine Hash-Kette mit dem vorigen verknüpft. Jede Nacht berechnet GiftCard Pro alle Ketten und Guthaben neu und alarmiert bei der kleinsten Abweichung. Fehler werden durch ein Storno korrigiert, das als Gegenbuchung sichtbar bleibt. Das Guthaben entspricht immer der Summe aller Buchungen.

### 9. Verfällt ein Gutschein?

Nur, wenn Sie eine Gültigkeit einstellen (mindestens 36 Monate). Ein abgelaufener Gutschein behält sein Guthaben, und die Inhaberin bzw. der Inhaber kann ihn wieder freigeben.

---

## Betrieb und Verfügbarkeit

### 10. Was passiert bei Internetausfall im Lokal?

Einlösen erfordert eine Verbindung zum Server – das ist Absicht, denn nur der Server kann Doppelbuchungen sicher verhindern und den Scan prüfen. Bei WLAN-Ausfall funktioniert die Kellner-App auch über mobile Daten des Handys. Fällt beides aus, kann nicht eingelöst werden; die Einlösung lässt sich auch nicht später ohne den Gutschein nachbuchen. Der Gast bezahlt in diesem Fall anders oder löst beim nächsten Besuch ein.

### 11. Was passiert, wenn GiftCard Pro ausfällt?

Wir streben eine Verfügbarkeit von 99,5 % pro Monat an. Bei einem Ausfall informieren wir Sie per E-Mail. Unsere Zielwerte für schwere Ausfälle: höchstens 24 Stunden Datenverlust (tägliche Sicherung) und Wiederherstellung innerhalb von 4 Stunden. Fehlende Buchungen lassen sich anhand Ihrer Registrierkassen-Belege nachvollziehen. Details im [Notfallwiederherstellungsplan](disaster-recovery-plan.md).

### 12. Wie werden die Daten gesichert?

Jede Nacht wird die Datenbank gesichert, einschließlich der Schutzmechanismen der Finanzhistorie. Die Sicherungen werden 14 Tage auf dem Server aufbewahrt und zusätzlich auf einen separaten Speicher (Hetzner Storage Box) kopiert. Außerdem erstellt Hetzner täglich einen Snapshot des gesamten Servers. Nach jeder Wiederherstellung wird die Unversehrtheit aller Buchungen geprüft.

### 13. Kann ich meine Daten selbst exportieren?

Ja. Gutscheine und Transaktionen exportieren Sie jederzeit als CSV (**„Export CSV“**), mit Strichpunkt und Dezimalkomma für Excel; Transaktionen mit der Zahlungsart.

---

## Daten und Datenschutz

### 14. Wo liegen die Daten?

Bei Hetzner Online GmbH in Rechenzentren in Deutschland, also in der EU. Transaktions-E-Mails versendet ein Dienstleister mit EU-Hosting (`[E-Mail-Versanddienstleister mit EU-Hosting]`). Alle Unterauftragsverarbeiter sind im Auftragsverarbeitungsvertrag aufgelistet.

### 15. Welche Daten über Gäste speichert GiftCard Pro?

Nur was Sie eingeben – und das ist optional. Ein Gutschein kann vollständig anonym verkauft werden. Wenn Sie Kundendaten erfassen: Name, E-Mail, Telefon, Notizen, Marketing-Einwilligung und den Empfängernamen am Gutschein. Gäste-E-Mails sind Quittungen mit Betrag, Lokal, Datum und Zahlungsart; sie enthalten nie QR-Code, Gutscheinnummer, Link oder Guthaben.

### 16. Wer bei GiftCard Pro kann meine Daten sehen?

Die Plattform-Administration von GiftCard Pro verwaltet Lokale (anlegen, deaktivieren, archivieren) und sieht dafür Kennzahlen wie die Anzahl der Gutscheine – aber **keine** Gutscheine, Buchungen, Kundendaten oder Teammitglieder Ihres Lokals. Einen Zugang „in Ihr Lokal hinein“ gibt es nicht; die Anwendung weist ihn technisch ab. Unterstützung erfolgt, indem Sie uns Ihren Bildschirm zeigen oder die Schritte beschreiben. Andere Lokale sehen Ihre Daten nie. Wer Zugriff auf den Server selbst hat, ist auf wenige namentlich bekannte Personen beschränkt.

### 17. Wie wird verhindert, dass ein anderes Lokal meine Daten sieht?

Jede Datenbankabfrage wird automatisch auf Ihr Lokal eingeschränkt, und diese Trennung wird auf mehreren Ebenen zusätzlich geprüft. Kennungen fremder Datensätze verhalten sich wie nicht vorhandene; ein QR-Code eines anderen Lokals wird wie ein unbekannter behandelt. Automatisierte Tests sichern das dauerhaft ab.

### 18. Ist GiftCard Pro DSGVO-konform?

GiftCard Pro ist nach den Grundsätzen der DSGVO gebaut: Hosting in der EU, Datenminimierung, keine Personendaten im Audit-Log, Anonymisierung auf Knopfdruck, keine Tracking-Cookies. Für Gästedaten sind Sie als Lokal Verantwortlicher, GiftCard Pro ist Ihr Auftragsverarbeiter; dafür schließen wir einen Auftragsverarbeitungsvertrag ab. Ihre Informationspflichten gegenüber Gästen bleiben bei Ihnen.

### 19. Was passiert, wenn ein Gast die Löschung seiner Daten verlangt?

Unter Customers wählen Sie beim Gast die Anonymisierung. Alle Personendaten werden entfernt, auch Empfängernamen auf seinen Gutscheinen und seine E-Mail-Adresse im Versandprotokoll. Die Buchungen bleiben für die Buchhaltung erhalten (Aufbewahrungspflicht nach BAO).

### 20. Verwendet die App Cookies oder Tracking?

Nur technisch notwendige Cookies: das Sitzungs-Cookie, ein Schutz-Cookie gegen CSRF-Angriffe und – nur wenn Sie „Keep me signed in“ wählen – ein Cookie für die dauerhafte Anmeldung. Im Browser-Speicher liegt eine zufällige Gerätekennung für die Gerätebindung. Keine Analyse, keine Werbung, keine Cookies von Dritten.

### 21. Was passiert mit meinen Daten nach Vertragsende?

Sie können vorher alle Daten exportieren. 30 Tage nach Vertragsende werden die Daten gelöscht, soweit keine gesetzliche Aufbewahrungspflicht besteht.

---

## Konten und Zugriff

### 22. Wie sind die Konten meines Teams geschützt?

Passwörter mit mindestens 12 Zeichen (Groß- und Kleinbuchstaben, Ziffer); bekannte geleakte Passwörter werden abgelehnt. Nach 10 Fehlversuchen wird das Konto 15 Minuten gesperrt – ohne dass ein Angreifer an der Antwort erkennt, ob eine Adresse existiert oder gesperrt ist. Jede Sitzung ist an das Gerät gebunden, auf dem sie begonnen hat. Ein Passwortwechsel widerruft alle Anmeldungen der Person auf anderen Geräten. Neue Mitarbeitende setzen ihr Passwort selbst über einen Einladungslink; Passwörter werden nie per E-Mail verschickt.

### 23. Was tue ich, wenn ein Handy gestohlen wird?

Unter **Devices** das Gerät auswählen und **„Revoke“** – es wird ab sofort abgewiesen, auch mit offener Sitzung oder angemeldeter Kellner-App. Danach ggf. das Passwort der Person zurücksetzen.

### 24. Was können Servicekräfte sehen und tun?

Standardmäßig nur Gutscheine per QR-Scan einlösen. Sie sehen weder das Dashboard noch Kundenlisten, Buchungen, Exporte, Einstellungen oder das Team. Die Anmeldung der Kellner-App erreicht technisch nur die wenigen Funktionen, die die App braucht. Die vollständige Übersicht finden Sie im [Leitfaden Zugriffskontrolle](access-control-guide.md).

### 25. Kann ein Manager sich selbst zum Inhaber machen?

Nein. Niemand kann die eigene Rolle ändern. Die Betriebsleitung kann standardmäßig keine Teammitglieder verwalten; das dürfen nur Inhaberinnen und Inhaber. Ein Lokal behält immer mindestens eine aktive Inhaberin oder einen aktiven Inhaber.

### 26. Wie sicher ist die Anbindung an meine Kassa über die API?

API-Tokens haben nur die Berechtigungen, die Sie beim Erstellen auswählen (höchstens die Ihres eigenen Kontos), laufen nach spätestens 365 Tagen ab und können jederzeit widerrufen werden. Sie werden nur einmal angezeigt und bei uns nur als Hash gespeichert. Zeit und IP-Adresse der letzten Verwendung sind sichtbar. Auch eine Kassa muss zum Einlösen den QR-Code des Gutscheins scannen.

### 27. Merke ich, wenn jemand etwas Verdächtiges versucht?

Ja. Im Audit-Log stehen fehlgeschlagene Scans (ein Code, der kein gültiger Gutschein Ihres Lokals ist), gesperrte Konten, Gratis-Gutscheine und Storni. Wir empfehlen, diese einmal pro Woche anzusehen.

---

## Zertifizierung und Prüfung

### 28. Ist GiftCard Pro zertifiziert?

Nein. GiftCard Pro hat keine Zertifizierung nach ISO 27001 oder SOC 2. PCI DSS ist nicht einschlägig, weil GiftCard Pro keine Zahlungskartendaten verarbeitet und keine Zahlungen abwickelt – bezahlt wird an Ihrer eigenen Kassa; GiftCard Pro hält nur fest, wie bezahlt wurde. Wir beschreiben unsere Schutzmaßnahmen stattdessen offen und nachprüfbar in unserem [Sicherheits-Whitepaper](security-whitepaper.md).

### 29. Wurde GiftCard Pro von einem externen Dienstleister auf Sicherheit getestet?

Bisher nicht. Der Code wurde intern umfassend geprüft, und die Befunde dieser Prüfungen sind behoben. Für jede Regel, die etwas verbietet, gibt es einen automatisierten Missbrauchstest, der den verbotenen Weg versucht (Einlösen ohne Scan, fremder Scan, abgelaufener Scan, Zugriffe auf fremde Lokale, Rechteausweitung, Manipulation der Finanzhistorie, Gratis-Verkauf ohne Berechtigung); diese Tests laufen bei jeder Änderung.

### 30. Ist GiftCard Pro eine Registrierkasse?

Nein. GiftCard Pro erstellt keine Belege und ist nicht RKSV-zertifiziert. Verkauf und Einlösung von Gutscheinen buchen Sie in Ihrer Registrierkasse nach Vorgabe Ihrer Steuerberatung.

---

## Meldungen

### 31. Wie melde ich eine Sicherheitslücke?

Per E-Mail an **security@giftcardpro.at** mit einer möglichst genauen Beschreibung (was, wo, wie reproduzierbar). Wir bestätigen den Eingang innerhalb von 2 Werktagen. Bitte veröffentlichen Sie Details erst nach Behebung, testen Sie nicht mit den Daten anderer Lokale und beeinträchtigen Sie nicht den Betrieb.

### 32. Fragt GiftCard Pro jemals nach meinem Passwort?

Nie – weder per E-Mail noch am Telefon noch im Chat. Wenn jemand im Namen von GiftCard Pro nach Ihrem Passwort fragt, handelt es sich um einen Betrugsversuch. Bitte leiten Sie solche Nachrichten an security@giftcardpro.at weiter.

---

Version 2.0 · Stand: September 2026
