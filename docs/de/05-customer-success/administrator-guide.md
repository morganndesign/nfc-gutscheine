# Handbuch für die Plattform-Administration

*Für das Betriebsteam von GiftCard Pro: Restaurants aufnehmen, Inhaber/innen einladen, in einem Restaurant unterstützen, sperren und reaktivieren, Plattform-Protokoll, Systemeinstellungen, Überwachung, Vertragsende und Sicherheitspflichten.*

Die Oberfläche ist auf Englisch. Schaltflächen stehen hier genau so, wie Sie sie sehen, beim ersten Vorkommen mit deutscher Bedeutung.

---

## 1. Rolle und Grundsätze

Die Rolle **Platform Administrator** (Plattform-Administrator/in) hat Zugriff auf alle Restaurants. Das ist die mächtigste Rolle im System. Daraus folgen drei Grundsätze:

1. **Zugriff nur mit Anlass.** Sie öffnen ein Restaurant nur, wenn die Inhaberin / der Inhaber darum bittet oder ein Support- bzw. Sicherheitsfall es erfordert. Rechtlich sind wir **Auftragsverarbeiter** (Art 28 DSGVO) für die Daten der Gäste; das Restaurant ist Verantwortlicher.
2. **Alles wird protokolliert.** Jede Aktion erscheint im Prüfprotokoll des Restaurants und im **„Platform audit“** (Plattform-Protokoll).
3. **Geld wird nicht bewegt.** Einlösungen, Aufladungen, Stornos und Übertragungen führt das Restaurant selbst durch. Ausnahmen nur auf schriftlichen Auftrag der Inhaberin / des Inhabers.

Administrator-Konten werden ausschließlich technisch angelegt (`php artisan platform:create-admin`); in der Oberfläche kann niemand diese Rolle vergeben.

![Plattform-Administration](../../screenshots/platform-admin.png)

---

## 2. Übersicht

Nach der Anmeldung sehen Sie **„Restaurants“**:

- Kennzahlen: **„Restaurants“** (Anzahl, davon aktiv), **„Gift cards“** (Karten, davon aktiv), **„Transactions this month“** (Buchungen dieses Monats), **„Volume sold this month“** (verkauftes Volumen dieses Monats).
- Liste aller Restaurants mit **„Status“** (Active / Suspended), **„Cards“**, **„Outstanding“** (offenes Guthaben), **„Users“** (Personen), **„Created“** (angelegt am).
- **„Search restaurants…“** (Restaurants suchen).

---

## 3. Ein Restaurant aufnehmen

**Voraussetzungen:** Vertrag unterschrieben (nur Unternehmer, B2B), Auftragsverarbeitungsvertrag unterschrieben, Tarif festgelegt, E-Mail-Adresse der Inhaberin / des Inhabers bestätigt.

1. **„Onboard restaurant“** (Restaurant aufnehmen).
2. Restaurant: **„Restaurant name“**, **„E-mail“**, **„Phone“**, **„Street“**, **„Postal code“**, **„City“**.
3. **„Owner account“** (Konto der Inhaberin / des Inhabers): **„Name“**, **„E-mail“**.
4. **„Create restaurant“** (Restaurant anlegen).

Das System legt ein vollständig getrenntes Restaurant-Konto an und sendet die Einladung. Der Link ist **72 Stunden** gültig; die Person wählt ihr Passwort selbst. Passwörter werden nie per E-Mail verschickt – auch nicht von uns.

**Danach:** Onboarding-Termin vereinbaren, Onboarding-Leitfaden und Einrichtungs-Checkliste schicken. Weisen Sie ausdrücklich darauf hin, dass **„Default validity (months)“** von der Werkseinstellung 36 auf **0** gestellt werden sollte, sofern die Rechtsberatung des Restaurants nichts anderes freigibt.

---

## 4. Einladung erneut senden

Die Einladung ist abgelaufen oder nicht angekommen:

1. Restaurant in der Liste öffnen → **„Open restaurant“** (Restaurant öffnen).
2. **„Team“** → bei der Inhaberin / beim Inhaber **⋯ → „Resend invitation“** (Einladung erneut senden).
3. Vorher prüfen: Stimmt die E-Mail-Adresse? Falls nicht: **⋯ → „Edit“**, Adresse korrigieren, dann erneut senden.
4. Den Spam-Ordner erwähnen.

Auf demselben Weg richten Sie – auf schriftlichen Wunsch der Inhaberin / des Inhabers – eine **zweite Person mit Inhaberrechten** ein: **„Team“** → **„Invite“** → Rolle **Restaurant Owner**. Inhaber/innen selbst können nur Manager und Servicekräfte einladen.

---

## 5. In einem Restaurant arbeiten („Open restaurant“)

Mit **„Open restaurant“** sehen und bedienen Sie das Restaurant so, wie es die Inhaberin / der Inhaber sieht.

- Oben erscheint ein gelber Hinweis: **„Viewing [Restaurant] as platform administrator. All actions are audited.“** (Sie sehen dieses Restaurant als Plattform-Administrator/in. Alle Aktionen werden protokolliert.)
- Jede Aktion wird mit Ihrem Namen im **„Audit log“** des Restaurants gespeichert. Die Inhaberin / der Inhaber sieht also, was Sie getan haben.
- Mit **„Exit“** (verlassen) kehren Sie zur Plattform-Übersicht zurück. Verlassen Sie das Restaurant immer, sobald die Aufgabe erledigt ist.

**Typische Anlässe:** Einladung erneut senden, Einstellungen gemeinsam am Telefon prüfen, Sicherheitswarnungen gemeinsam analysieren, Fehlerbild nachvollziehen.

**Nicht erlaubt ohne schriftlichen Auftrag:** Kartenbuchungen, Stornos, Änderungen an Kartenregeln, Kundendaten ansehen oder exportieren über das zur Fehlerbehebung Notwendige hinaus.

---

## 6. Sperren und Reaktivieren

Restaurant öffnen → **„Suspend“** (sperren) → bestätigen.

- **Alle Personen dieses Restaurants werden sofort abgemeldet** und können sich nicht mehr anmelden. Karten behalten ihr Guthaben und funktionieren nach der Reaktivierung wieder.
- **„Reactivate“** (reaktivieren) hebt die Sperre auf.

**Anlässe:** Zahlungsverzug nach Mahnung gemäß Vertrag, begründeter Sicherheitsverdacht (z. B. übernommenes Konto), Wunsch der Inhaberin / des Inhabers, Vertragsende.

**Wichtig:** Eine Sperre betrifft auch die Gäste des Restaurants – deren Karten können in dieser Zeit nicht eingelöst werden. Sperren Sie wegen Zahlungsverzug deshalb nur mit Vorankündigung (Frist gemäß Vertrag) und dokumentieren Sie den Grund.

---

## 7. Plattform-Protokoll

**„Platform audit“** zeigt sicherheitsrelevante Ereignisse aller Restaurants: Anmeldungen, gesperrte Konten, Sicherheitswarnungen (**„Cloned card rejected“**, **„Copied NFC tap rejected“**, **„Invalid NFC signature rejected“**, **„Card of another restaurant scanned“**, **„Account locked after failed sign-ins“**), Aktionen von Administrator/innen, Sperren und Reaktivierungen. Einträge können nicht geändert oder gelöscht werden.

**Täglich prüfen:** rot markierte Einträge. Häufungen bei einem Restaurant (z. B. viele gesperrte Konten, wiederholte Kopierwarnungen) → Inhaberin / Inhaber am selben Tag informieren.

---

## 8. Systemeinstellungen

**„System settings“** (Systemeinstellungen):

| Einstellung | Wirkung | Hinweis |
|---|---|---|
| **„Maintenance notice“** (Wartungshinweis) | Text, der als Banner allen angemeldeten Personen angezeigt wird | mindestens 3 Werktage vor geplanten Wartungen setzen (siehe Support-Leitfaden), mit Datum, Uhrzeit (Wiener Zeit) und erwarteter Dauer; danach leeren |
| **„Support e-mail“** (Support-E-Mail) | Adresse, die in der App als Kontakt erscheint | support@giftcardpro.at |
| **„Default plan“** (Standardtarif) | Tarif für neu aufgenommene Restaurants | laut aktuellem Angebot |

Nach Änderungen **„Save“** drücken.

---

## 9. Überwachung und Support

### Täglich

- Erreichbarkeit: Überwachung von `https://app.giftcardpro.at/up` (Datenbank und Cache) – Alarm prüfen.
- **„Platform audit“** auf rote Einträge prüfen.
- Nächtliche Datensicherung erfolgreich? (Backups 14 Tage lokal plus externe Kopie.)
- Nächtliche Aufgaben gelaufen: Ablauf fälliger Karten 00:15, Bereinigung 03:30, Erinnerungs-E-Mails 10:00 (Wiener Zeit).
- Support-Postfach: Antwort innerhalb eines Werktags (Start) bzw. innerhalb von 4 Arbeitsstunden (Pro).

### Wöchentlich

- Neue Restaurants: Einladung angenommen? Falls nicht nach 3 Tagen: nachfassen.
- Restaurants ohne Aktivität seit zwei Wochen: Unterstützung anbieten.
- Zustellung der E-Mails (Einladungen, Gästebenachrichtigungen) stichprobenartig prüfen.

### Monatlich

- Liste der Administrator-Konten prüfen (siehe Abschnitt 11).
- Eine Wiederherstellung aus der Datensicherung testen.
- Verfügbarkeit des Vormonats festhalten (Ziel: 99,5 %).

### Supportfälle – Grundregeln

- Identität prüfen: Anfragen zu Konten nur von der hinterlegten E-Mail-Adresse der Inhaberin / des Inhabers bearbeiten.
- Nie nach Passwörtern fragen. Für vergessene Passwörter: **„Forgot password?“** (Passwort vergessen) auf der Anmeldeseite oder Link über **„Send password reset“**.
- Fragen zu Steuer und Recht: auf die Steuerberatung bzw. Rechtsberatung des Restaurants verweisen.
- Anfragen von Gästen an das Restaurant weiterleiten – das Restaurant ist Verantwortlicher für deren Daten.

---

## 10. Vertragsende: Datenexport und Löschung

1. **Vor dem Vertragsende** die Inhaberin / den Inhaber schriftlich erinnern, die Daten zu exportieren:
   - **„Transactions“** → gesamter Zeitraum → **„Export CSV“** (Buchungsjournal – für die siebenjährige Aufbewahrungspflicht nach § 132 BAO trägt das Restaurant selbst die Verantwortung),
   - **„Gift cards“** → **„Export CSV“** (alle Karten mit Guthaben).
   Weitere Daten (z. B. Kundenliste, Prüfprotokoll) auf Anfrage als Export durch das Technikteam.
2. Auf das **offene Guthaben** hinweisen: Gäste haben weiterhin Ansprüche gegenüber dem Restaurant. Wie das Restaurant sie künftig bedient, entscheidet es selbst.
3. Zum Vertragsende das Restaurant **sperren** (**„Suspend“**).
4. **30 Tage nach Vertragsende** werden die Daten gelöscht, soweit keine gesetzliche Aufbewahrungspflicht des Anbieters entgegensteht. Die Löschung führt das Technikteam als dokumentierten Vorgang durch; in der Administrationsoberfläche gibt es dafür keine Schaltfläche.
5. Löschung schriftlich bestätigen.

---

## 11. Sicherheitspflichten

- **Höchstens zwei Administrator-Konten.** Jedes Konto gehört genau einer Person. Keine geteilten oder Sammelkonten.
- **Starke, einzigartige Passwörter** (System: mindestens 12 Zeichen, Groß- und Kleinbuchstaben, Zahl; empfohlen: 16+ Zeichen aus einem Passwortmanager).
- **Keine Anmeldung auf fremden oder öffentlichen Geräten.** Arbeitsgeräte mit aktueller Software, verschlüsselter Festplatte und Bildschirmsperre.
- **Ausscheiden:** Administrator-Konto am selben Tag durch das Technikteam deaktivieren lassen und die Liste der Konten prüfen.
- **Verdacht auf Missbrauch** eines Administrator-Kontos: sofort Passwort ändern (meldet andere Sitzungen ab), security@giftcardpro.at informieren, Platform audit sichern.
- **Datenschutzvorfall** (Verletzung des Schutzes personenbezogener Daten): betroffene Restaurants unverzüglich informieren, damit sie ihre Meldepflicht gegenüber der Datenschutzbehörde (72 Stunden) erfüllen können. Den Vorfall dokumentieren.
- **Vertraulichkeit:** Daten der Restaurants und ihrer Gäste werden nicht an Dritte weitergegeben, nicht für eigene Zwecke verwendet und nicht außerhalb der Plattform gespeichert.

---

Version 1.0 · Stand: September 2026
