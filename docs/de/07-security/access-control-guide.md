# Leitfaden Zugriffskontrolle

*Rollen, Berechtigungen, Geräte, API-Tokens und Prozesse für Eintritt, Wechsel und Austritt – abgeleitet aus der tatsächlichen Umsetzung in GiftCard Pro. Für Inhaberinnen und Inhaber, Manager und die IT-Betreuung von Lokalen.*

---

## 1. Grundsätze

1. **Jede Aktion verlangt eine Berechtigung.** Jede Schnittstelle von GiftCard Pro prüft serverseitig eine konkrete Berechtigung. Die Oberfläche blendet nur aus, was eine Person nicht darf – maßgeblich ist immer die Prüfung am Server.
2. **Berechtigungen hängen an der Rolle.** Jede Person hat genau eine Rolle. Die Berechtigungen je Rolle sind fest vorgegeben und für alle Lokale gleich; individuelle Anpassungen sind derzeit nicht über die Oberfläche möglich.
3. **Geringste Rechte.** Vergeben Sie die niedrigste Rolle, mit der eine Person ihre Arbeit erledigen kann.
4. **Mandantentrennung.** Alle Berechtigungen gelten nur im eigenen Lokal. Auch eine Inhaberin sieht nie Daten eines anderen Lokals.
5. **Persönliche Konten.** Ein Konto pro Person, keine Sammelkonten – nur so ist das Audit-Log aussagekräftig.

---

## 2. Rollen

| Rolle | Bezeichnung in der App | Rang | Typische Personen |
|---|---|---|---|
| **Plattform-Administration** | Platform Administrator | 100 | Betreiberteam von GiftCard Pro – nie im Lokal vergeben |
| **Inhaber/in** | Restaurant Owner | 30 | Inhaberin, Inhaber, Geschäftsführung |
| **Manager** | Manager | 20 | Betriebsleitung, Schichtleitung, Restaurantleitung |
| **Servicekraft** | Waiter | 10 | Kellnerinnen, Kellner, Bar, Aushilfen |

---

## 3. Berechtigungsmatrix

✔ = standardmäßig erteilt · – = nicht erteilt

Für die Plattform-Administration gelten Berechtigungen eines Lokals nur im Arbeitsmodus „Open restaurant" (Abschnitt 6).

| Bereich | Berechtigung | Bedeutung | Plattform-Admin | Owner | Manager | Waiter |
|---|---|---|:-:|:-:|:-:|:-:|
| Dashboard | `dashboard.view` | Dashboard mit Kennzahlen und Diagrammen ansehen | ✔ | ✔ | ✔ | – |
| Karten | `cards.view` | Kartenliste und Kartendetails ansehen | ✔ | ✔ | ✔ | – |
| | `cards.scan` | Karte scannen bzw. per Nummer suchen (Kellner-App) | ✔ | ✔ | ✔ | ✔ |
| | `cards.create` | neue Gutscheinkarte ausgeben | ✔ | ✔ | ✔ | – |
| | `cards.update` | Details bearbeiten (Kunde, Empfänger, Notizen, Gültigkeit) | ✔ | ✔ | ✔ | – |
| | `cards.activate` | inaktive Karte aktivieren | ✔ | ✔ | ✔ | – |
| | `cards.redeem` | Guthaben einlösen | ✔ | ✔ | ✔ | ✔ |
| | `cards.reload` | Karte aufladen | ✔ | ✔ | ✔ | – |
| | `cards.block` | Karte sperren | ✔ | ✔ | ✔ | – |
| | `cards.unblock` | Sperre aufheben | ✔ | ✔ | ✔ | – |
| | `cards.expire` | Karte sofort ablaufen lassen | ✔ | ✔ | ✔ | – |
| | `cards.transfer` | Guthaben zwischen Karten übertragen | ✔ | ✔ | ✔ | – |
| | `cards.replace` | verlorene Karte ersetzen | ✔ | ✔ | ✔ | – |
| | `cards.write_nfc` | NFC-Chip beschreiben und an die Karte binden | ✔ | ✔ | ✔ | – |
| | `cards.export` | Kartenliste als CSV exportieren | ✔ | ✔ | ✔ | – |
| Transaktionen | `transactions.view` | Buchungsjournal ansehen | ✔ | ✔ | ✔ | – |
| | `transactions.reverse` | Einlösung oder Aufladung stornieren | ✔ | ✔ | ✔ | – |
| | `transactions.export` | Transaktionen als CSV exportieren | ✔ | ✔ | ✔ | – |
| Kunden | `customers.view` | Kundenliste und Details ansehen | ✔ | ✔ | ✔ | – |
| | `customers.manage` | Kunden anlegen, bearbeiten, anonymisieren | ✔ | ✔ | ✔ | – |
| Team | `users.view` | Teamliste und Rollen ansehen | ✔ | ✔ | – | – |
| | `users.manage` | einladen, bearbeiten, Rolle ändern, deaktivieren, Passwort-Reset | ✔ | ✔ | – | – |
| Geräte | `devices.view` | Geräteliste ansehen | ✔ | ✔ | ✔ | – |
| | `devices.manage` | Geräte umbenennen, sperren, wiederherstellen | ✔ | ✔ | – | – |
| Einstellungen | `settings.manage` | Kartenregeln, Lokalprofil, E-Mail-Vorlagen | ✔ | ✔ | – | – |
| | `api_tokens.manage` | API-Tokens erstellen und widerrufen | ✔ | ✔ | – | – |
| Audit | `audit.view` | Audit-Log des Lokals ansehen | ✔ | ✔ | ✔ | – |
| Plattform | `platform.restaurants.manage` | Lokale anlegen, bearbeiten, suspendieren, reaktivieren | ✔ | – | – | – |
| | `platform.settings.manage` | Systemeinstellungen (Standardtarif, Wartungshinweis, Support-E-Mail) | ✔ | – | – | – |
| | `platform.audit.view` | plattformweites Audit-Log ansehen | ✔ | – | – | – |
| **Summe** | | | **30** | **27** | **22** | **2** |

**Hinweise zur Matrix**

- Servicekräfte können Karten **nicht sperren**. Legen Sie fest, dass eine auffällige Karte nicht angenommen und die Schichtleitung sofort verständigt wird.
- Manager führen den kompletten Kartenbetrieb, sehen Audit-Log und Geräteliste, verwalten aber **weder Team noch Geräte, Einstellungen oder API-Tokens**. Ein verlorenes Gerät kann standardmäßig nur ein Owner sperren.
- Jede Person kann ihr **eigenes** Gerät abfragen, ihr Profil (Name, Sprache) bearbeiten und ihr Passwort ändern.

---

## 4. Ränge: Wer darf wen verwalten?

Teammitglieder verwalten darf nur, wer `users.manage` besitzt (standardmäßig Owner) **und** im Rang über der Zielperson steht. Ausnahme: Owner dürfen auch andere Owner verwalten.

| Handelnde Rolle | darf verwalten (einladen, bearbeiten, Rolle vergeben, deaktivieren) |
|---|---|
| Plattform-Administration | alle Rollen in jedem Lokal |
| Owner | Owner, Manager, Waiter im eigenen Lokal |
| Manager | niemanden (keine Berechtigung `users.manage`) |
| Waiter | niemanden |

**Schutzregeln [technisch erzwungen]**

- **Keine Selbstbeförderung:** Niemand kann die eigene Rolle ändern.
- **Keine Selbstsperre:** Niemand kann das eigene Konto deaktivieren.
- **Letzte Inhaberin / letzter Inhaber:** Ein Lokal muss immer mindestens eine aktive Person mit der Rolle Owner behalten. Die letzte kann nicht deaktiviert werden.
- **Plattform-Rolle:** Die Rolle „Platform Administrator" kann in keinem Lokal vergeben werden. Einladungen erlauben nur Owner, Manager oder Waiter. Plattform-Konten werden ausschließlich über die Server-Konsole angelegt.
- **Mandantenbindung:** Personen eines anderen Lokals sind weder sichtbar noch verwaltbar.
- **Nichts wird gelöscht:** Benutzer werden deaktiviert, nicht gelöscht. Ihre Buchungen bleiben mit Namen im Verlauf.

Benutzerstatus: **Invited** (Einladung offen) → **Active** · **Locked** (vorübergehend nach 10 Fehlversuchen) · **Deactivated**.

---

## 5. Geräte und Sitzungen

- **Automatische Registrierung:** Jedes Gerät (Handy, Tablet, PC), das sich anmeldet, wird unter **Devices** erfasst und nach Hardware und Browser benannt, z. B. „iPhone · Safari". Umbenennen mit dem Stift-Symbol, z. B. „Bar iPhone".
- **Gerätebindung:** Eine Sitzung ist an die zufällige Gerätekennung gebunden, mit der sie begonnen hat. Ein kopiertes Sitzungs-Cookie funktioniert auf einem anderen Gerät nicht.
- **Sperren:** **„Revoke"** (mit Bestätigung) weist das Gerät ab der nächsten Anfrage ab – unabhängig von offenen Sitzungen. **„Restore"** hebt die Sperre auf.
- **Sitzungsdauer:** 8 Stunden Inaktivität; länger nur mit „Keep me signed in on this device".
- **Passwortwechsel** beendet alle anderen Sitzungen der Person.
- **Deaktivieren** eines Benutzers beendet seine Sitzungen und widerruft seine API-Tokens.
- **Suspendierte Lokale:** Wird ein Lokal von der Plattform-Administration suspendiert, können sich seine Benutzer nicht mehr anmelden.

---

## 6. Plattform-Administration: Arbeitsmodus „Open restaurant"

Die Plattform-Administration hat ohne ausdrückliche Auswahl eines Lokals **keinen** Zugriff auf Daten von Lokalen: Anfragen an Schnittstellen eines Lokals ohne ausgewähltes Lokal werden abgewiesen.

- Über **„Open restaurant"** wählt die Administration ein Lokal aus. Ein deutliches Banner zeigt den Arbeitsmodus an und kann jederzeit geschlossen werden.
- Jede Aktion in diesem Modus wird im Audit-Log des Lokals mit der Identität der Administratorin bzw. des Administrators, Gerät, IP-Adresse und Request-ID erfasst.
- Der Modus wird nur für Einrichtung, Support und auf Wunsch des Lokals verwendet (siehe [Passwortrichtlinie](password-policy.md), Abschnitt 9).
- Plattformaktionen (Lokal anlegen, bearbeiten, suspendieren, reaktivieren, Systemeinstellungen) werden im plattformweiten Audit-Log protokolliert.

---

## 7. API-Tokens

| Eigenschaft | Regel |
|---|---|
| Wer darf erstellen | Personen mit `api_tokens.manage` (standardmäßig Owner) |
| Berechtigungen (Abilities) | frei wählbar, aber **immer eine Teilmenge der Berechtigungen der erstellenden Person** |
| Identität | Das Token handelt als die erstellende Person; Buchungen und Audit-Einträge tragen deren Kennung |
| Laufzeit | höchstens 365 Tage |
| Speicherung | nur als SHA-256-Hash; Klartext wird einmal angezeigt; Präfix `gcp_` |
| Kontrolle | letzte Verwendung (Zeit, IP-Adresse) sichtbar |
| Widerruf | jederzeit manuell; automatisch beim Deaktivieren der erstellenden Person |
| Cookies | Tokens verwenden keine Cookies und sind daher von CSRF nicht betroffen |

**Empfehlung für eine Kassa-Anbindung:** nur `cards.scan`, `cards.redeem` und – falls die Kassa Karten verkauft – `cards.create` bzw. `cards.reload`. Laufzeit 90–180 Tage, Erneuerung im Kalender eintragen. Das Token von einer Person erstellen lassen, die dem Lokal voraussichtlich lange angehört – beim Deaktivieren dieser Person wird das Token widerrufen.

---

## 8. Eintritt, Wechsel, Austritt (Joiner – Mover – Leaver)

### 8.1 Eintritt

1. Owner: **Team → „Invite"** → Name, persönliche E-Mail-Adresse, Rolle nach geringsten Rechten → **„Send invitation"**.
2. Die neue Person öffnet den Link (72 Stunden gültig) und wählt ihr Passwort.
3. Erste Anmeldung auf dem Dienstgerät; Owner benennt das Gerät unter **Devices**.
4. Einweisung: [Sicherheits-Best-Practices](security-best-practices.md), insbesondere Bildschirmsperre, keine Passwortweitergabe, Verhalten bei roten Warnungen.

### 8.2 Wechsel (Rollenänderung)

1. Owner: **Team → ⋯ → „Edit"** → neue Rolle. Die neuen Berechtigungen gelten ab der nächsten Anfrage.
2. Bei einer Herabstufung prüfen, ob die Person API-Tokens erstellt hat, die nun zu weitreichend sind – diese widerrufen und neu erstellen.
3. Wird eine Person Owner, prüfen, ob ihr Konto den Regeln für Owner entspricht (Passwortmanager).

### 8.3 Austritt

Am **letzten Arbeitstag**:

1. **Team → ⋯ → „Deactivate"** – beendet Sitzungen, widerruft API-Tokens.
2. **Devices:** private Geräte der Person sperren.
3. Wenn die Person API-Tokens für Integrationen erstellt hat: vorab neue Tokens durch eine verbleibende Person erstellen und in der Integration hinterlegen, sonst fällt die Integration aus.
4. Bei Austritt einer Inhaberin bzw. eines Inhabers: zuerst eine neue Person als Owner einladen, dann das alte Konto deaktivieren (Schutz der letzten Inhaberin bzw. des letzten Inhabers).
5. Audit-Log der letzten Tage stichprobenartig auf Auffälligkeiten prüfen.

---

## 9. Vierteljährliche Zugriffsprüfung

Einmal pro Quartal (z. B. im Jänner, April, Juli, Oktober) durch einen Owner, Dauer ca. 15 Minuten:

- [ ] **Team:** Alle aktiven Personen arbeiten noch im Lokal. Offene Einladungen („Invited") sind noch nötig.
- [ ] **Rollen:** Jede Person hat die niedrigste passende Rolle. Anzahl der Owner ist so klein wie möglich, aber mindestens zwei erreichbare Personen können im Notfall Geräte sperren (bei nur einem Owner: Vertretungsregel festlegen).
- [ ] **Geräte:** Keine unbekannten oder ausgemusterten Geräte aktiv; alle Geräte eindeutig benannt.
- [ ] **API-Tokens:** Jedes Token wird noch gebraucht, hat minimale Berechtigungen, läuft nicht unbemerkt ab; letzte Verwendung und IP-Adresse plausibel.
- [ ] **Audit-Log:** Sicherheitswarnungen des Quartals nachvollzogen; Kontosperren erklärt.
- [ ] **Einstellungen:** Kopierschutz aktiv, Chip-Sperre aktiv, Missbrauchsgrenzen passend.
- [ ] **Ergebnis dokumentiert:** Datum, prüfende Person, Änderungen (z. B. in einer kurzen Notiz oder im Betriebshandbuch des Lokals).

---

Version 1.0 · Stand: September 2026
