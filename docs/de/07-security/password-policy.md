# Passwortrichtlinie

*Verbindliche Regeln für Passwörter, Einladungen, Kontosperren und API-Tokens bei GiftCard Pro – für alle Benutzerinnen und Benutzer der Lokale sowie für die Plattform-Administration.*

---

## 1. Zweck und Geltungsbereich

Diese Richtlinie legt fest, wie Zugänge zu GiftCard Pro geschützt werden. Sie gilt für

- alle Benutzerkonten eines Lokals (Owner, Manager, Waiter),
- alle Konten der Plattform-Administration von GiftCard Pro,
- API-Tokens für Integrationen.

Abschnitte, die mit **[technisch erzwungen]** markiert sind, setzt GiftCard Pro automatisch durch. Abschnitte mit **[organisatorisch]** liegen in der Verantwortung der jeweiligen Personen bzw. des Lokals.

---

## 2. Anforderungen an Passwörter [technisch erzwungen]

| Anforderung | Wert |
|---|---|
| Mindestlänge | **12 Zeichen** |
| Zeichenarten | mindestens ein **Großbuchstabe**, ein **Kleinbuchstabe** und eine **Ziffer** |
| Bekannte Passwörter | Passwörter aus öffentlich bekannten Datenlecks werden abgelehnt (Abgleich über das k-Anonymitäts-Verfahren von „Have I Been Pwned"; es werden nur die ersten fünf Zeichen eines SHA-1-Hash-Werts übertragen, nie das Passwort) |
| Neues Passwort | muss sich beim Ändern vom bisherigen unterscheiden und zweimal identisch eingegeben werden |
| Speicherung | ausschließlich als **bcrypt-Hash**; das Passwort selbst wird nie gespeichert und ist auch für GiftCard Pro nicht einsehbar |

Ein erzwungener, periodischer Passwortwechsel ist bewusst **nicht** vorgesehen. Er führt erfahrungsgemäß zu schwächeren Passwörtern. Passwörter werden bei Verdacht gewechselt (Abschnitt 7).

## 3. Empfehlungen über die Mindestanforderungen hinaus [organisatorisch]

- **Passphrasen** aus vier oder mehr zufälligen Wörtern mit Ziffer verwenden, z. B. „Kaiserschmarrn-Fahrrad-Donau-Wolke-9". Länge schlägt Komplexität.
- **Passwortmanager** für Inhaberinnen, Inhaber und die Betriebsleitung (z. B. Bitwarden, 1Password, KeePassXC, integrierter Manager von Browser bzw. Betriebssystem). Zufällig erzeugte Passwörter mit mindestens 16 Zeichen.
- **Einmaligkeit:** Das Passwort für GiftCard Pro wird nirgendwo anders verwendet.
- **Keine persönlichen Bezüge:** kein Name des Lokals, keine Geburtsdaten, keine Straßennamen.
- **Nicht notieren** auf Zetteln, in der Kassa-Lade, auf dem Handy-Hintergrund oder in Chat-Gruppen.

---

## 4. Kontosperre und Schutz vor Durchprobieren [technisch erzwungen]

| Regel | Wert |
|---|---|
| Anmeldeversuche | höchstens 5 pro Minute je E-Mail-Adresse und IP-Adresse, 30 pro Minute je IP-Adresse |
| Kontosperre | nach **10 aufeinanderfolgenden Fehlversuchen** für **15 Minuten** |
| Protokollierung | Fehlversuche bei bekannten Konten und Sperren erscheinen im Audit-Log (`auth.failed`, `auth.locked`); eine Sperre zusätzlich als Warnung im Anwendungsprotokoll |
| Einheitliche Antwort | Ein falsches Passwort, eine unbekannte Adresse und ein gesperrtes Konto erhalten **dieselbe** Meldung in derselben Antwortzeit (das Passwort wird immer geprüft) – die Antwort verrät weder, ob eine Adresse existiert, noch, ob ein Konto gesperrt ist |
| Passwort vergessen | höchstens 5 Anfragen pro Minute je IP-Adresse; die Antwort ist für bekannte und unbekannte Adressen identisch |

Nach Ablauf der Sperre kann sich die Person wieder anmelden. Wer seine Sperre nicht selbst verursacht hat, meldet das der Inhaberin bzw. dem Inhaber – das kann ein Angriffsversuch sein.

---

## 5. Einladungen und Zurücksetzen [technisch erzwungen]

| Vorgang | Regel |
|---|---|
| Neues Teammitglied | erhält per E-Mail einen **einmaligen Einladungslink**, gültig **72 Stunden**, und wählt das Passwort selbst |
| Abgelaufene Einladung | eine neue Einladung erzeugt einen neuen Link; der alte funktioniert nicht mehr |
| Passwort vergessen / zurücksetzen | Link per E-Mail, gültig **60 Minuten**, nur einmal verwendbar |
| Getrennte Verfahren | Einladungen und Zurücksetzungen verwenden getrennte Token-Speicher mit eigenen Laufzeiten; eine Anfrage „Passwort vergessen“ kann eine offene Einladung nie ersetzen, und Konten mit offener Einladung erhalten keinen Reset-Link |
| Kein Token in Logs | Das Token steht im URL-Fragment (`#token=…`), das der Browser nie an einen Server sendet |
| Wirkung | Eine Zurücksetzung widerruft alle Tokens der Person und beendet „Keep me signed in“ |
| Neue Inhaberin / neuer Inhaber eines Lokals | wird bei der Einrichtung durch die Plattform-Administration ebenfalls per Einladungslink eingeladen |

---

## 6. Keine Weitergabe von Passwörtern [organisatorisch und technisch]

- GiftCard Pro verschickt **nie** Passwörter per E-Mail und fragt **nie** per E-Mail, Telefon oder Chat nach einem Passwort.
- Passwörter werden **nicht** zwischen Personen weitergegeben – auch nicht von der Inhaberin an die Servicekraft. Jede Person hat ein eigenes Konto.
- Support durch GiftCard Pro erfolgt ohne Kenntnis Ihres Passworts.
- Anfragen nach Passwörtern sind als Betrugsversuch zu behandeln und an security@giftcardpro.at zu melden.

---

## 7. Wechsel bei Verdacht [organisatorisch]

Das Passwort ist **sofort** zu ändern (**Account** → Passwort ändern) bzw. durch die Inhaberin oder den Inhaber zurückzusetzen, wenn

- es jemand anderem bekannt geworden sein könnte,
- es auf einem verlorenen oder gestohlenen Gerät gespeichert war,
- es auch für einen anderen Dienst verwendet wurde, der von einem Datenleck betroffen ist,
- eine Phishing-Nachricht angeklickt und dort Daten eingegeben wurden,
- das Audit-Log Aktionen zeigt, die die Person nicht selbst durchgeführt hat,
- eine Kontosperre auftrat, die die Person nicht selbst verursacht hat.

Ein Passwortwechsel oder eine Zurücksetzung widerruft **alle Tokens** der Person (Kellner-App und Integrationen), beendet „Keep me signed in“ und meldet **alle anderen Sitzungen** automatisch ab [technisch erzwungen].

---

## 8. Sitzungen [technisch erzwungen]

- Sitzungen enden nach **8 Stunden Inaktivität**, außer die Option „Keep me signed in on this device“ wurde gewählt. Sie ist standardmäßig aus; eine so wiederhergestellte Sitzung wird nur auf einem aktiven Gerät akzeptiert, das die Person bereits verwendet hat. Die Option nur auf eigenen, gesperrten Geräten verwenden.
- Jede Sitzung ist an das Gerät gebunden, auf dem sie begonnen hat.
- Die Anmeldung der Kellner-App gilt nur auf dem Telefon, für das sie ausgestellt wurde, und läuft nach 30 Tagen ohne Nutzung ab.
- Gesperrte Geräte und deaktivierte Benutzer werden bei der nächsten Anfrage abgewiesen.

---

## 9. Zusätzliche Regeln für die Plattform-Administration [organisatorisch]

Konten der Plattform-Administration betreiben die Plattform: Sie legen Lokale an, sperren und archivieren sie und pflegen Systemeinstellungen. Sie handeln nie innerhalb eines Lokals, berühren nie Gutscheine und können keine API-Tokens anlegen oder verwenden [technisch erzwungen]. Für sie gilt zusätzlich:

1. Passwort aus dem Passwortmanager, zufällig erzeugt, mindestens **20 Zeichen**.
2. Anmeldung nur von betreuten Geräten mit Festplattenverschlüsselung, Bildschirmsperre und aktuellen Updates; nie von fremden oder geteilten Geräten.
3. Plattform-Konten melden sich immer ausdrücklich an; „Keep me signed in on this device“ gilt für sie nicht [technisch erzwungen].
4. Zugänge zu Hetzner, Coolify, GitHub, Domain-Registrar, E-Mail-Versand und Passwortmanager sind mit Zwei-Faktor-Authentisierung geschützt.
5. Support für ein Lokal erfolgt über das Lokal selbst (die Inhaberin bzw. der Inhaber teilt den Bildschirm oder beschreibt die Schritte); jede Plattformaktion wird im plattformweiten Audit-Log erfasst.
6. Plattform-Konten werden nur über die Server-Konsole angelegt und nie in einem Lokal vergeben.
7. Die Liste der Plattform-Administrationskonten wird vierteljährlich überprüft; nicht mehr benötigte Konten werden sofort deaktiviert.
8. Server-Geheimnisse (`APP_KEY`, SMTP-Zugangsdaten, Signaturschlüssel der Kellner-App) werden ausschließlich im Passwortmanager bzw. in Coolify und den GitHub-Secrets verwahrt. Kartenschlüssel sind nie Teil der Konfiguration; sie liegen in einem Hardware-Sicherheitsmodul hinter dem Krypto-Dienst.

---

## 10. API-Tokens

| Regel | Umsetzung |
|---|---|
| Erstellung | nur durch Personen mit der Berechtigung `api_tokens.manage` (standardmäßig Owner) unter **Settings → API**; nie durch die Plattform-Administration [technisch erzwungen] |
| Berechtigungen | frei wählbare Abilities, **höchstens die Berechtigungen der erstellenden Person** [technisch erzwungen]; nur das Nötigste wählen [organisatorisch] |
| Laufzeit | höchstens **365 Tage** [technisch erzwungen]; kürzere Laufzeit empfohlen [organisatorisch] |
| Anzeige | Klartext wird **nur einmal** angezeigt; gespeichert wird nur ein SHA-256-Hash [technisch erzwungen] |
| Erkennbarkeit | Tokens beginnen mit `gcp_`, damit sie in Code und Dokumenten gefunden werden können |
| Nachverfolgung | Zeitpunkt und IP-Adresse der letzten Verwendung werden gespeichert |
| Widerruf | jederzeit möglich; automatisch, wenn die erstellende Person deaktiviert wird oder ihr Passwort ändert bzw. zurücksetzt [technisch erzwungen] |
| Aufbewahrung | nur im Passwortmanager oder direkt in der Zielanwendung; nie in E-Mails, Chats, Tabellen oder Code-Repositories [organisatorisch] |

---

## 11. Verantwortlichkeiten

| Rolle | Verantwortung |
|---|---|
| **Jede Benutzerin, jeder Benutzer** | eigenes Passwort gemäß Abschnitt 2–3 wählen, geheim halten, bei Verdacht wechseln, Verdachtsfälle melden |
| **Owner (Inhaber/in)** | Konten für jede Person anlegen, Austritte am selben Tag deaktivieren, API-Tokens verwalten, Richtlinie im Team bekannt machen |
| **Manager (Betriebsleitung)** | auf Einhaltung im Tagesbetrieb achten, Auffälligkeiten an den Owner melden |
| **GiftCard Pro** | technische Durchsetzung, sichere Speicherung, Plattform-Administrationskonten gemäß Abschnitt 9, Unterstützung bei Vorfällen |

---

## 12. Durchsetzung

- Technische Regeln werden von der Anwendung automatisch durchgesetzt; Passwörter, die sie nicht erfüllen, werden abgelehnt.
- Verstöße gegen organisatorische Regeln (z. B. geteilte Konten, weitergegebene Passwörter) regelt jedes Lokal intern. GiftCard Pro empfiehlt, diese Richtlinie in die Dienstanweisung für das Team aufzunehmen.
- Bei Verdacht auf Missbrauch kann GiftCard Pro zum Schutz der Plattform Tokens widerrufen bzw. ein Lokal deaktivieren und informiert das betroffene Lokal unverzüglich.
- Diese Richtlinie wird jährlich und nach sicherheitsrelevanten Vorfällen überprüft.

---

Version 2.0 · Stand: September 2026
