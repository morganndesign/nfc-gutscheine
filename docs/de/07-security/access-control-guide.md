# Leitfaden Zugriffskontrolle

*Rollen, Berechtigungen, Geräte, API-Tokens und Prozesse für Eintritt, Wechsel und Austritt – abgeleitet aus der tatsächlichen Umsetzung in GiftCard Pro. Für Inhaberinnen und Inhaber, die Betriebsleitung und die IT-Betreuung von Lokalen.*

---

## 1. Grundsätze

1. **Jede Aktion verlangt eine Berechtigung.** Jede Schnittstelle von GiftCard Pro prüft serverseitig eine konkrete Berechtigung. Die Oberfläche blendet nur aus, was eine Person nicht darf – maßgeblich ist immer die Prüfung am Server.
2. **Berechtigungen hängen an der Rolle.** Jede Person hat genau eine Rolle. Die Berechtigungen je Rolle sind fest vorgegeben und für alle Lokale gleich; individuelle Anpassungen sind nicht über die Oberfläche möglich.
3. **Geringste Rechte.** Vergeben Sie die niedrigste Rolle, mit der eine Person ihre Arbeit erledigen kann.
4. **Mandantentrennung.** Alle Berechtigungen gelten nur im eigenen Lokal. Auch eine Inhaberin sieht nie Daten eines anderen Lokals.
5. **Persönliche Konten.** Ein Konto pro Person, keine Sammelkonten – nur so ist das Audit-Log aussagekräftig.
6. **Einlösen braucht den Gutschein.** Keine Berechtigung erlaubt eine Abbuchung ohne frische Vorlage des Gutscheins (QR-Scan); die Gutscheinnummer ist nie ein Berechtigungsnachweis.

---

## 2. Rollen

| Rolle | Bezeichnung in der App | Rang | Typische Personen |
|---|---|---|---|
| **Plattform-Administration** | Platform Administrator | 100 | Betreiberteam von GiftCard Pro – nie im Lokal vergeben |
| **Inhaber/in** | Restaurant Owner | 30 | Inhaberin, Inhaber, Geschäftsführung |
| **Betriebsleitung** | Manager | 20 | Betriebsleitung, Schichtleitung, Restaurantleitung |
| **Servicekraft** | Waiter | 10 | Kellnerinnen, Kellner, Bar, Aushilfen |

---

## 3. Berechtigungsmatrix

✔ = standardmäßig erteilt · – = nicht erteilt

Die Plattform-Administration hat ausschließlich Plattformberechtigungen: Sie betreibt Lokale, handelt aber nie innerhalb eines Lokals und berührt nie Gutscheine (Abschnitt 6).

| Bereich | Berechtigung | Bedeutung | Plattform-Admin | Owner | Manager | Waiter |
|---|---|---|:-:|:-:|:-:|:-:|
| Dashboard | `dashboard.view` | Dashboard mit Kennzahlen und Diagrammen ansehen | – | ✔ | ✔ | – |
| Gutscheine | `vouchers.view` | Gutscheinliste und Details ansehen | – | ✔ | ✔ | – |
| | `vouchers.sell` | Gutschein verkaufen (mit Zahlung) | – | ✔ | ✔ | – |
| | `vouchers.sell_complimentary` | Gutschein ohne Zahlung ausgeben (Zahlungsart `complimentary`, mit Begründung) | – | ✔ | – | – |
| | `vouchers.update` | Details bearbeiten (Kundin bzw. Kunde, Empfänger, Notizen) | – | ✔ | ✔ | – |
| | `vouchers.redeem` | Guthaben einlösen (nur mit Vorlage des Gutscheins) | – | ✔ | ✔ | ✔ |
| | `vouchers.reload` | Gutschein aufladen (mit Zahlung) | – | ✔ | ✔ | – |
| | `vouchers.block` | Gutschein sperren | – | ✔ | ✔ | – |
| | `vouchers.unblock` | Sperre aufheben | – | ✔ | ✔ | – |
| | `vouchers.expire` | Gutschein sofort ablaufen lassen (Guthaben bleibt, mit Begründung) | – | ✔ | – | – |
| | `vouchers.reinstate` | abgelaufenen Gutschein wieder freigeben | – | ✔ | – | – |
| | `vouchers.export` | Gutscheinliste als CSV exportieren | – | ✔ | ✔ | – |
| Transaktionen | `transactions.view` | Buchungsjournal ansehen | – | ✔ | ✔ | – |
| | `transactions.reverse` | Einlösung oder Aufladung stornieren | – | ✔ | ✔ | – |
| | `transactions.export` | Transaktionen als CSV exportieren | – | ✔ | ✔ | – |
| Kunden | `customers.view` | Kundenliste und Details ansehen | – | ✔ | ✔ | – |
| | `customers.manage` | Kunden anlegen, bearbeiten, anonymisieren | – | ✔ | ✔ | – |
| Team | `users.view` | Teamliste und Rollen ansehen | – | ✔ | – | – |
| | `users.manage` | einladen, bearbeiten, Rolle ändern, deaktivieren, Einladung erneut senden | – | ✔ | – | – |
| Geräte | `devices.view` | Geräteliste ansehen | – | ✔ | ✔ | – |
| | `devices.manage` | Geräte umbenennen, sperren, wiederherstellen | – | ✔ | – | – |
| Einstellungen | `settings.manage` | Gutscheinregeln, Lokalprofil, E-Mail-Vorlagen | – | ✔ | – | – |
| | `api_tokens.manage` | API-Tokens erstellen und widerrufen | – | ✔ | – | – |
| Audit | `audit.view` | Audit-Log des Lokals ansehen | – | ✔ | ✔ | – |
| Plattform | `platform.restaurants.manage` | Lokale anlegen, bearbeiten, deaktivieren, archivieren, löschen; Einladungen erneut senden; Tokens widerrufen | ✔ | – | – | – |
| | `platform.settings.manage` | Systemeinstellungen (Wartungshinweis, Support-E-Mail, Mindestversionen der App), E-Mail-Diagnose | ✔ | – | – | – |
| | `platform.audit.view` | plattformweites Audit-Log ansehen | ✔ | – | – | – |
| **Summe** | | | **3** | **24** | **16** | **1** |

**Hinweise zur Matrix**

- Servicekräfte können **nur einlösen** – mit dem gescannten QR-Code des Gutscheins. Sie können nicht verkaufen, aufladen, sperren oder Buchungen sehen. Legen Sie fest, dass ein auffälliger Gutschein nicht angenommen und die Schichtleitung sofort verständigt wird.
- Die Betriebsleitung führt den laufenden Gutscheinbetrieb (verkaufen, aufladen, sperren, stornieren), sieht Audit-Log und Geräteliste, verwaltet aber **weder Team noch Geräte, Einstellungen oder API-Tokens**. Ablauf, Wiederfreigabe und Gratis-Gutscheine sind der Inhaberin bzw. dem Inhaber vorbehalten. Ein verlorenes Gerät kann standardmäßig nur ein Owner sperren.
- Jede Person kann ihr **eigenes** Gerät abfragen, ihr Profil (Name, Sprache) bearbeiten und ihr Passwort ändern.

---

## 4. Ränge: Wer darf wen verwalten?

Teammitglieder verwalten darf nur, wer `users.manage` besitzt (standardmäßig Owner) **und** im Rang über der Zielperson steht. Ausnahme: Owner dürfen auch andere Owner verwalten.

| Handelnde Rolle | darf verwalten (einladen, bearbeiten, Rolle vergeben, deaktivieren) |
|---|---|
| Plattform-Administration | legt beim Anlegen eines Lokals das Inhaberkonto an und sendet Einladungen erneut; verwaltet kein Team innerhalb eines Lokals |
| Owner | Owner, Manager, Waiter im eigenen Lokal |
| Manager | niemanden (keine Berechtigung `users.manage`) |
| Waiter | niemanden |

**Schutzregeln [technisch erzwungen]**

- **Keine Selbstbeförderung:** Niemand kann die eigene Rolle ändern.
- **Keine Selbstsperre:** Niemand kann das eigene Konto deaktivieren.
- **Letzte Inhaberin / letzter Inhaber:** Ein Lokal muss immer mindestens eine aktive Person mit der Rolle Owner behalten. Die letzte kann nicht deaktiviert werden.
- **Plattform-Rolle:** Die Rolle „Platform Administrator“ kann in keinem Lokal vergeben werden. Einladungen erlauben nur Owner, Manager oder Waiter. Plattform-Konten werden ausschließlich über die Server-Konsole angelegt (`php artisan platform:create-admin`).
- **Mandantenbindung:** Personen eines anderen Lokals sind weder sichtbar noch verwaltbar.
- **Nichts wird gelöscht:** Benutzer werden deaktiviert, nicht gelöscht. Ihre Buchungen bleiben mit Namen im Verlauf.

Benutzerstatus: **Invited** (Einladung offen) → **Active** · **Locked** (vorübergehend nach 10 Fehlversuchen) · **Deactivated**.

---

## 5. Geräte und Sitzungen

- **Automatische Registrierung:** Jedes Gerät (Handy, Tablet, PC, Kassa), das sich anmeldet, wird unter **Devices** erfasst. Umbenennen mit dem Stift-Symbol, z. B. „Bar iPhone“.
- **Gerätebindung im Browser:** Eine Sitzung ist an die zufällige Gerätekennung gebunden, mit der sie begonnen hat. Ein kopiertes Sitzungs-Cookie funktioniert auf einem anderen Gerät nicht.
- **„Keep me signed in on this device“:** ist standardmäßig aus. Eine so wiederhergestellte Sitzung wird nur auf einem aktiven Gerät akzeptiert, das die Person bereits verwendet hat.
- **Kellner-App (GiftCard Waiter):** Die Anmeldung erzeugt ein Token, das nur mit der Kennung dieses Telefons funktioniert und nur die Anfragen der App erreicht (Vorlage, Einlösung, Abfrage eines unklaren Einlöseergebnisses; Betriebsleitung und Owner zusätzlich Verkauf). Es läuft nach 30 Tagen ohne Nutzung ab.
- **Sperren:** **„Revoke“** (mit Bestätigung) weist das Gerät ab der nächsten Anfrage ab – unabhängig von offenen Sitzungen oder Tokens – und beendet „Keep me signed in“ seiner Personen. **„Restore“** hebt die Sperre auf.
- **Sitzungsdauer:** 8 Stunden Inaktivität.
- **Passwortwechsel oder -zurücksetzung** widerruft alle Tokens der Person (Kellner-App und Integrationen) und beendet „Keep me signed in“ und alle anderen Browser-Sitzungen.
- **Deaktivieren** eines Benutzers beendet seine Sitzungen und widerruft seine Tokens.
- **Deaktivierte oder archivierte Lokale:** Wird ein Lokal von der Plattform-Administration deaktiviert oder archiviert, können seine Personen und Geräte nicht mehr arbeiten.

---

## 6. Plattform-Administration

Die Plattform-Administration betreibt die Plattform, nicht die Lokale:

- Sie hat **keinen** Zugriff auf Gutscheine, Buchungen, Kundendaten oder Teams eines Lokals. Restaurant-Schnittstellen antworten ihr mit `403 TENANT_NOT_RESOLVED`; einen Arbeitsmodus „im Lokal“ gibt es nicht.
- Sie legt Lokale mit Inhaberkonto an, bearbeitet, deaktiviert, archiviert und löscht sie (Löschen nur ohne Gutscheine, Buchungen und Kundendaten), sendet Einladungen erneut, pflegt Systemeinstellungen und widerruft bei einem Sicherheitsvorfall Tokens (`/admin/api-tokens`).
- Sie kann **keine API-Tokens anlegen oder verwenden** und meldet sich immer ausdrücklich an („Keep me signed in“ gilt für sie nicht).
- Alle Plattformaktionen werden im plattformweiten Audit-Log protokolliert.
- Unterstützung bei einem Problem im Lokal erfolgt über das Lokal selbst (Owner teilt Bildschirm, beschreibt Schritte) – siehe [Passwortrichtlinie](password-policy.md), Abschnitt 9.

---

## 7. API-Tokens

| Eigenschaft | Regel |
|---|---|
| Wer darf erstellen | Personen mit `api_tokens.manage` (standardmäßig Owner); nie die Plattform-Administration |
| Berechtigungen (Abilities) | frei wählbar, aber **immer eine Teilmenge der Berechtigungen der erstellenden Person** |
| Identität | Das Token handelt als die erstellende Person; Buchungen und Audit-Einträge tragen deren Kennung |
| Laufzeit | höchstens 365 Tage |
| Speicherung | nur als SHA-256-Hash; Klartext wird einmal angezeigt; Präfix `gcp_` |
| Kontrolle | letzte Verwendung (Zeit, IP-Adresse) sichtbar |
| Widerruf | jederzeit manuell; automatisch beim Deaktivieren der erstellenden Person und bei deren Passwortwechsel oder -zurücksetzung; bei einem Vorfall auch durch die Plattform-Administration |
| Cookies | Tokens verwenden keine Cookies und sind daher von CSRF nicht betroffen |

**Empfehlung für eine Kassa-Anbindung:** nur `vouchers.view` und `vouchers.redeem` (Einlösen mit Vorlage des gescannten QR-Codes) und – falls die Kassa Gutscheine verkauft oder auflädt – `vouchers.sell` bzw. `vouchers.reload`. Laufzeit 90–180 Tage, Erneuerung im Kalender eintragen. Das Token von einer Person erstellen lassen, die dem Lokal voraussichtlich lange angehört – beim Deaktivieren dieser Person und bei ihrem Passwortwechsel wird das Token widerrufen.

---

## 8. Eintritt, Wechsel, Austritt (Joiner – Mover – Leaver)

### 8.1 Eintritt

1. Owner: **Team → „Invite“** → Name, persönliche E-Mail-Adresse, Rolle nach geringsten Rechten → **„Send invitation“**.
2. Die neue Person öffnet den Link (72 Stunden gültig) und wählt ihr Passwort.
3. Erste Anmeldung auf dem Dienstgerät bzw. in der Kellner-App; Owner benennt das Gerät unter **Devices**.
4. Einweisung: [Sicherheits-Best-Practices](security-best-practices.md), insbesondere Bildschirmsperre, keine Passwortweitergabe, Gutscheine nur per Scan einlösen.

### 8.2 Wechsel (Rollenänderung)

1. Owner: **Team → ⋯ → „Edit“** → neue Rolle. Die neuen Berechtigungen gelten ab der nächsten Anfrage; die Kellner-App übernimmt sie spätestens bei der täglichen Verlängerung ihres Tokens (die Rolle wird zusätzlich bei jeder Anfrage geprüft).
2. Bei einer Herabstufung prüfen, ob die Person API-Tokens erstellt hat, die nun zu weitreichend sind – diese widerrufen und neu erstellen.
3. Wird eine Person Owner, prüfen, ob ihr Konto den Regeln für Owner entspricht (Passwortmanager).

### 8.3 Austritt

Am **letzten Arbeitstag**:

1. **Team → ⋯ → „Deactivate“** – beendet Sitzungen, widerruft Tokens.
2. **Devices:** private Geräte der Person sperren.
3. Wenn die Person API-Tokens für Integrationen erstellt hat: vorab neue Tokens durch eine verbleibende Person erstellen und in der Integration hinterlegen, sonst fällt die Integration aus.
4. Bei Austritt einer Inhaberin bzw. eines Inhabers: zuerst eine neue Person als Owner einladen, dann das alte Konto deaktivieren (Schutz der letzten Inhaberin bzw. des letzten Inhabers).
5. Audit-Log der letzten Tage stichprobenartig auf Auffälligkeiten prüfen.

---

## 9. Vierteljährliche Zugriffsprüfung

Einmal pro Quartal (z. B. im Jänner, April, Juli, Oktober) durch einen Owner, Dauer ca. 15 Minuten:

- [ ] **Team:** Alle aktiven Personen arbeiten noch im Lokal. Offene Einladungen („Invited“) sind noch nötig.
- [ ] **Rollen:** Jede Person hat die niedrigste passende Rolle. Anzahl der Owner ist so klein wie möglich, aber mindestens zwei erreichbare Personen können im Notfall Geräte sperren (bei nur einem Owner: Vertretungsregel festlegen).
- [ ] **Geräte:** Keine unbekannten oder ausgemusterten Geräte aktiv; alle Geräte eindeutig benannt.
- [ ] **API-Tokens:** Jedes Token wird noch gebraucht, hat minimale Berechtigungen, läuft nicht unbemerkt ab; letzte Verwendung und IP-Adresse plausibel.
- [ ] **Audit-Log:** fehlgeschlagene Vorlagen (`presentment.failed`) und Kontosperren des Quartals nachvollzogen; Gratis-Gutscheine, Storni, Ablauf und Wiederfreigaben plausibel.
- [ ] **Einstellungen:** Grenzen je Einlösung, je Gutschein und Tag und je Stunde passend; Gültigkeit entspricht den Geschäftsbedingungen.
- [ ] **Ergebnis dokumentiert:** Datum, prüfende Person, Änderungen (z. B. in einer kurzen Notiz oder im Betriebshandbuch des Lokals).

---

Version 2.0 · Stand: September 2026
