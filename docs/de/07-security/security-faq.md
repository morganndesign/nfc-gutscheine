# Sicherheit – Häufige Fragen

*Kurze, ehrliche Antworten auf die Fragen, die uns Inhaberinnen und Inhaber, Steuerberatung und IT-Betreuung zur Sicherheit von GiftCard Pro stellen.*

---

## Karten

### 1. Was ist auf der Karte gespeichert?

Nur ein Link: `https://app.giftcardpro.at/c/` gefolgt von einer zufälligen Kennung (UUID v4). Kein Guthaben, kein Name, keine E-Mail-Adresse. Derselbe Link steht als QR-Code auf der Rückseite. Guthaben und Verlauf liegen ausschließlich auf dem Server.

### 2. Kann jemand eine Karte kopieren?

Den Link auf einer einfachen NFC-Karte kann man auslesen und auf einen anderen Chip schreiben. Deshalb prüft GiftCard Pro zusätzlich:

- **Standardkarten (NTAG213/215/216):** Die Karte ist an die ab Werk eingebrannte Seriennummer des Chips gebunden. Eine Kopie auf einem anderen Chip wird beim Scannen mit Android abgelehnt und im Audit-Log als Sicherheitswarnung markiert. Diese Prüfung greift nicht beim iPhone, beim QR-Code und bei der manuellen Nummerneingabe, und es gibt Spezialchips mit veränderbarer Seriennummer.
- **NTAG 424 DNA-Karten:** Der Chip erzeugt bei jedem Antippen eine neue kryptografische Signatur mit Zähler. Kopien und wiederverwendete Links werden abgelehnt – auf Android und iPhone.

Für hohe Kartenwerte empfehlen wir NTAG 424 DNA.

### 3. Kann jemand eine Kartennummer oder einen Link erraten?

Praktisch nein. Die Kennung im Link enthält 122 Bit Zufall, die 16-stellige Kartennummer ist zufällig (nicht fortlaufend). Zusätzlich sind fehlgeschlagene Abfragen auf 10 pro 5 Minuten je Benutzer und je IP-Adresse begrenzt, und jeder Versuch wird protokolliert.

### 4. Was passiert, wenn ein Gast seine Karte verliert?

Sie sperren die Karte oder wählen **„Replace lost card"**. Das Guthaben wandert auf eine neue Karte mit neuer Kennung; die alte Karte funktioniert ab sofort nirgends mehr. Wer die alte Karte findet, kann damit nichts anfangen.

### 5. Kann jemand den Chip auf der Karte überschreiben?

Wenn in den Einstellungen „Lock tags after writing" aktiv ist, wird der Chip nach dem Beschreiben dauerhaft schreibgeschützt. NTAG 424 DNA-Karten werden bei der Programmierung mit eigenen Schlüsseln geschützt. Selbst ein überschriebener Chip könnte nur auf einen anderen Link zeigen – Guthaben lässt sich damit nicht verändern.

### 6. Kann eine Servicekraft eine Karte doppelt belasten, etwa durch Doppel-Tippen?

Nein. Jede Einlösung trägt einen eindeutigen Idempotenzschlüssel. Kommt dieselbe Anfrage zweimal an – durch Doppel-Tippen oder weil das Netz kurz weg war –, wird sie nur einmal gebucht.

### 7. Was passiert, wenn zwei Servicekräfte gleichzeitig dieselbe Karte einlösen?

Die Datenbank sperrt die Karte für die Dauer jeder Buchung, die Einlösungen werden nacheinander verarbeitet. Ein Guthaben kann dadurch nie doppelt ausgegeben werden oder unter null fallen. Wir haben das intern mit 20 gleichzeitigen Einlösungen auf eine Karte getestet.

### 8. Kann eine Buchung nachträglich verändert oder gelöscht werden?

Nein. Das Buchungsjournal ist unveränderlich. Fehler werden durch ein Storno korrigiert, das als Gegenbuchung sichtbar bleibt. Das Guthaben entspricht immer der Summe aller Buchungen.

---

## Betrieb und Verfügbarkeit

### 9. Was passiert bei Internetausfall im Lokal?

Einlösen erfordert eine Verbindung zum Server – das ist Absicht, denn nur der Server kann Doppelbuchungen sicher verhindern. Bei WLAN-Ausfall funktioniert die Kellner-App auch über mobile Daten des Handys. Fällt beides aus, notieren Sie Kartennummer und Betrag und buchen die Einlösung nach, sobald die Verbindung zurück ist; bei hohen Beträgen oder unbekannten Gästen empfehlen wir, die Einlösung zu verschieben.

### 10. Was passiert, wenn GiftCard Pro ausfällt?

Wir streben eine Verfügbarkeit von 99,5 % pro Monat an. Bei einem Ausfall informieren wir Sie per E-Mail. Unsere Zielwerte für schwere Ausfälle: höchstens 24 Stunden Datenverlust (tägliche Sicherung) und Wiederherstellung innerhalb von 4 Stunden. Fehlende Buchungen lassen sich anhand Ihrer Registrierkassen-Belege nachtragen. Details im [Notfallwiederherstellungsplan](disaster-recovery-plan.md).

### 11. Wie werden die Daten gesichert?

Jede Nacht wird die Datenbank gesichert. Die Sicherungen werden 14 Tage auf dem Server aufbewahrt und zusätzlich auf einen separaten Speicher (Hetzner Storage Box) kopiert. Außerdem erstellt Hetzner täglich einen Snapshot des gesamten Servers.

### 12. Kann ich meine Daten selbst exportieren?

Ja. Karten und Transaktionen exportieren Sie jederzeit als CSV (**„Export CSV"**), mit Strichpunkt und Dezimalkomma für Excel.

---

## Daten und Datenschutz

### 13. Wo liegen die Daten?

Bei Hetzner Online GmbH in Rechenzentren in Deutschland, also in der EU. Transaktions-E-Mails versendet ein Dienstleister mit EU-Hosting (`[E-Mail-Versanddienstleister mit EU-Hosting]`). Alle Unterauftragsverarbeiter sind im Auftragsverarbeitungsvertrag aufgelistet.

### 14. Welche Daten über Gäste speichert GiftCard Pro?

Nur was Sie eingeben – und das ist optional. Eine Karte kann vollständig anonym verkauft werden. Wenn Sie Kundendaten erfassen: Name, E-Mail, Telefon, Notizen, Marketing-Einwilligung und den Empfängernamen auf der Karte.

### 15. Wer bei GiftCard Pro kann meine Daten sehen?

Nur die Plattform-Administration von GiftCard Pro, und zwar ausschließlich über die Funktion „Open restaurant". Dabei ist deutlich ein Banner sichtbar, und jede Aktion wird im Audit-Log mit der handelnden Person erfasst. Wir nutzen diesen Zugang nur für Einrichtung und Support oder auf Ihren Wunsch. Andere Lokale sehen Ihre Daten nie.

### 16. Wie wird verhindert, dass ein anderes Lokal meine Daten sieht?

Jede Datenbankabfrage wird automatisch auf Ihr Lokal eingeschränkt, und diese Trennung wird auf mehreren Ebenen zusätzlich geprüft. Kennungen fremder Datensätze verhalten sich wie nicht vorhandene. Automatisierte Tests sichern das dauerhaft ab.

### 17. Ist GiftCard Pro DSGVO-konform?

GiftCard Pro ist nach den Grundsätzen der DSGVO gebaut: Hosting in der EU, Datenminimierung, keine Personendaten im Audit-Log, Anonymisierung auf Knopfdruck, keine Tracking-Cookies. Für Gästedaten sind Sie als Lokal Verantwortlicher, GiftCard Pro ist Ihr Auftragsverarbeiter; dafür schließen wir einen Auftragsverarbeitungsvertrag ab. Ihre Informationspflichten gegenüber Gästen bleiben bei Ihnen.

### 18. Was passiert, wenn ein Gast die Löschung seiner Daten verlangt?

Unter Customers wählen Sie beim Gast die Anonymisierung. Alle Personendaten werden entfernt, auch Empfängernamen auf seinen Karten und seine E-Mail-Adresse im Versandprotokoll. Die Buchungen bleiben für die Buchhaltung erhalten (Aufbewahrungspflicht nach BAO).

### 19. Verwendet die App Cookies oder Tracking?

Nur technisch notwendige Cookies: das Sitzungs-Cookie und ein Schutz-Cookie gegen CSRF-Angriffe. Im Browser-Speicher liegt eine zufällige Gerätekennung für die Gerätebindung. Keine Analyse, keine Werbung, keine Cookies von Dritten.

### 20. Was passiert mit meinen Daten nach Vertragsende?

Sie können vorher alle Daten exportieren. 30 Tage nach Vertragsende werden die Daten gelöscht, soweit keine gesetzliche Aufbewahrungspflicht besteht.

---

## Konten und Zugriff

### 21. Wie sind die Konten meines Teams geschützt?

Passwörter mit mindestens 12 Zeichen (Groß- und Kleinbuchstaben, Ziffer); bekannte geleakte Passwörter werden abgelehnt. Nach 10 Fehlversuchen wird das Konto 15 Minuten gesperrt. Jede Sitzung ist an das Gerät gebunden, auf dem sie begonnen hat. Neue Mitarbeitende setzen ihr Passwort selbst über einen Einladungslink; Passwörter werden nie per E-Mail verschickt.

### 22. Was tue ich, wenn ein Handy gestohlen wird?

Unter **Devices** das Gerät auswählen und **„Revoke"** – es wird ab sofort abgewiesen, auch mit offener Sitzung. Danach ggf. das Passwort der Person zurücksetzen.

### 23. Was können Servicekräfte sehen und tun?

Standardmäßig nur Karten scannen und einlösen. Sie sehen weder das Dashboard noch Kundenlisten, Exporte, Einstellungen oder das Team. Die vollständige Übersicht finden Sie im [Leitfaden Zugriffskontrolle](access-control-guide.md).

### 24. Kann ein Manager sich selbst zum Inhaber machen?

Nein. Niemand kann die eigene Rolle ändern. Manager können standardmäßig keine Teammitglieder verwalten; das dürfen nur Inhaberinnen und Inhaber. Ein Lokal behält immer mindestens eine aktive Inhaberin oder einen aktiven Inhaber.

### 25. Wie sicher ist die Anbindung an meine Kassa über die API?

API-Tokens haben nur die Berechtigungen, die Sie beim Erstellen auswählen (höchstens die Ihres eigenen Kontos), laufen nach spätestens 365 Tagen ab und können jederzeit widerrufen werden. Sie werden nur einmal angezeigt und bei uns nur als Hash gespeichert. Zeit und IP-Adresse der letzten Verwendung sind sichtbar.

### 26. Merke ich, wenn jemand etwas Verdächtiges versucht?

Ja. Im Audit-Log sind Sicherheitswarnungen rot markiert: kopierte Karte abgewiesen, wiederholter NFC-Tap, Karte eines fremden Lokals, gesperrtes Konto. Wir empfehlen, diese einmal pro Woche anzusehen.

---

## Zertifizierung und Prüfung

### 27. Ist GiftCard Pro zertifiziert?

Nein. GiftCard Pro hat derzeit keine Zertifizierung nach ISO 27001 oder SOC 2. PCI DSS ist nicht einschlägig, weil GiftCard Pro keine Zahlungskartendaten verarbeitet und keine Zahlungen abwickelt – bezahlt wird an Ihrer eigenen Kassa. Wir beschreiben unsere Schutzmaßnahmen stattdessen offen und nachprüfbar in unserem [Sicherheits-Whitepaper](security-whitepaper.md).

### 28. Wurde GiftCard Pro von einem externen Dienstleister auf Sicherheit getestet?

Bisher nicht. Der Code wurde intern umfassend geprüft, einschließlich intern durchgeführter Angriffs- und Lasttests (gleichzeitige Einlösungen, Brute Force, gefälschte Kennungen, Zugriffe auf fremde Lokale, Einschleusen von Code). Diese Fälle sind als automatisierte Tests dauerhaft abgesichert: 113 Backend-Tests laufen bei jeder Änderung.

### 29. Ist GiftCard Pro eine Registrierkasse?

Nein. GiftCard Pro erstellt keine Belege und ist nicht RKSV-zertifiziert. Verkauf und Einlösung von Gutscheinkarten buchen Sie in Ihrer Registrierkasse nach Vorgabe Ihrer Steuerberatung.

---

## Meldungen

### 30. Wie melde ich eine Sicherheitslücke?

Per E-Mail an **security@giftcardpro.at** mit einer möglichst genauen Beschreibung (was, wo, wie reproduzierbar). Wir bestätigen den Eingang innerhalb von 2 Werktagen. Bitte veröffentlichen Sie Details erst nach Behebung, testen Sie nicht mit den Daten anderer Lokale und beeinträchtigen Sie nicht den Betrieb.

### 31. Fragt GiftCard Pro jemals nach meinem Passwort?

Nie – weder per E-Mail noch am Telefon noch im Chat. Wenn jemand im Namen von GiftCard Pro nach Ihrem Passwort fragt, handelt es sich um einen Betrugsversuch. Bitte leiten Sie solche Nachrichten an security@giftcardpro.at weiter.

---

Version 1.0 · Stand: September 2026
