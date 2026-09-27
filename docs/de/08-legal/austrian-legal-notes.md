# Rechtliche und steuerliche Hinweise für Restaurants (Österreich)

> **Muster/Vorlage — vor Verwendung durch eine in Österreich zugelassene Rechtsanwältin / einen Rechtsanwalt prüfen lassen.**
> Keine Rechtsberatung — mit Steuerberatung/Rechtsanwalt prüfen. Die folgenden Hinweise fassen die allgemeine Rechtslage in Österreich (Stand September 2026) für die Praxis zusammen. Sie ersetzen keine Beratung im Einzelfall. Stellen mit **[Prüfen: …]** bedürfen besonderer Prüfung.

*Zweck: Praxishinweise für Restaurants, die mit GiftCard Pro Gutscheinkarten ausgeben — Gültigkeit, Gutscheinbedingungen für Gäste, Umsatzsteuer, Registrierkasse, Ertragsteuer, Aufbewahrung, Verbraucherschutz.*

---

## 1. Auf einen Blick

| Thema | Kurzfassung | Einstellung / Funktion in GiftCard Pro |
|---|---|---|
| Gültigkeit bezahlter Gutscheine | Ohne Befristung 30 Jahre. Befristung auf 3 Jahre oder weniger in AGB ist in der Regel unwirksam. | **Settings → Gift cards → Default validity (months) = 0** (keine Ablaufzeit). Werkseinstellung 36 Monate bei der Einrichtung ändern. |
| Umsatzsteuer | Restaurant-Wertgutscheine sind meist **Mehrzweckgutscheine** → USt bei Einlösung. | Keine automatische USt-Berechnung; Exporte für die Steuerberatung. |
| Registrierkasse | GiftCard Pro ist **keine** Registrierkasse. Verkauf und Einlösung in der eigenen Kassa buchen. | Gutschein-Tasten in der Kassa mit der Steuerberatung einrichten. |
| Offener Betrag | Nicht eingelöstes Guthaben ist eine Verbindlichkeit gegenüber Gästen. | Kennzahl **Outstanding balance** im Dashboard. |
| Aufbewahrung | 7 Jahre (§ 132 BAO). | Unveränderliches Buchungsjournal, **Export CSV**. |
| Abgelaufene Karten | Anspruch des Gastes kann weiter bestehen. Keine automatische „Ausbuchung" als Ertrag. | Ablauf ist umkehrbar über Ersatzkarte bzw. Guthabenübertrag. |
| Verbraucherschutz | Das KSchG gilt zwischen Restaurant und Gast (nicht zwischen Anbieter und Restaurant). | Gutscheinbedingungen verständlich und fair gestalten (Vorlage Abschnitt 3). |

## 2. Gültigkeit von Gutscheinen

### 2.1 Rechtslage

- **Grundsatz:** Ein bezahlter Gutschein ohne Befristung kann innerhalb der allgemeinen Verjährungsfrist von **30 Jahren** eingelöst werden (§ 1478 ABGB).
- **Befristung in AGB:** Nach der Rechtsprechung des Obersten Gerichtshofs (OGH) ist eine Befristung bezahlter Gutscheine auf **3 Jahre oder weniger** in Allgemeinen Geschäftsbedingungen in der Regel **gröblich benachteiligend** (§ 879 Abs 3 ABGB) und damit unwirksam, sofern keine sachliche Rechtfertigung vorliegt. Folge: Es gilt wieder die 30-jährige Frist. [Prüfen: aktuelle OGH-Geschäftszahlen durch Rechtsberatung ergänzen]
- **Vom OGH akzeptiertes Modell:** Eine kürzere Einlösefrist (z. B. **1 Jahr**) ist denkbar, wenn der Gast danach noch eine angemessene Frist (z. B. **3 Jahre**) hat, den Gutschein **umzutauschen oder den Wert erstattet** zu bekommen.
- **Geschenkte Gutscheine** (Gratis- oder Aktionsgutscheine, z. B. „€ 10 Bonus bei Kauf über € 100", Gewinnspiel): dürfen kürzer befristet werden, weil der Gast dafür nichts bezahlt hat. Die Befristung ist klar auf der Karte anzugeben.
- **Leistungsgutscheine** (z. B. „Menü für zwei Personen"): Preisänderungen während langer Laufzeit sind ein bekanntes Streitthema. Empfehlung: Wertgutscheine in Euro ausgeben. [Prüfen: Umgang mit Preisanpassung bei Leistungsgutscheinen]

Quellen: WKO „Gutscheine – Befristung" ([wko.at/vertragsrecht/gutscheine-befristung](https://www.wko.at/vertragsrecht/gutscheine-befristung)); Verein für Konsumenteninformation ([konsument.at](https://www.konsument.at)); Arbeiterkammer ([arbeiterkammer.at](https://www.arbeiterkammer.at)).

### 2.2 Empfehlung für GiftCard Pro

- **Default validity = 0** (keine Ablaufzeit) setzen, es sei denn, Ihre Rechtsanwältin oder Ihr Rechtsanwalt gibt ein anderes Modell frei. Die Werkseinstellung ist derzeit 36 Monate und muss bei der Einrichtung geändert werden. Eine Änderung dieser Werkseinstellung ist auf der Roadmap des Anbieters vorgesehen.
- Die Gültigkeit einzelner Karten kann beim Ausstellen (**Valid until**) oder später (**⋯ → Edit details**) angepasst werden, z. B. für Aktionsgutscheine.
- **Was bei Ablauf passiert:** Läuft eine Karte ab, bucht GiftCard Pro das Restguthaben aus (Buchungstyp „expiration"; Status **Expired**). Das ist eine technische Buchung — der Gast kann rechtlich weiterhin Anspruch haben. Das Restaurant kann den Wert über **Replace lost card** bzw. **Transfer balance** auf eine neue Karte bringen oder eine Gegenbuchung vornehmen. Die ausgebuchten Beträge sind im Buchungsjournal nachvollziehbar.
- Nächtlicher Ablauf-Lauf: 00:15 Uhr (Wiener Zeit). Erinnerungs-E-Mail an Gäste 30 Tage vor Ablauf, sofern **Customer e-mails** aktiviert und eine E-Mail-Adresse hinterlegt ist.

## 3. Gutscheinbedingungen für Gäste (Vorlage)

Diese Bedingungen gelten zwischen dem Restaurant und seinen Gästen. Sie müssen dem Gast **vor dem Kauf** zugänglich sein (z. B. Aushang an der Kassa, Beiblatt, Website) und sollten in Kurzform auf der Kartenrückseite oder einem Kartenträger stehen. Ungewöhnliche Klauseln werden nicht Vertragsbestandteil, wenn nicht besonders darauf hingewiesen wird (§ 864a ABGB). Klauseln, die Verbraucherinnen und Verbraucher gröblich benachteiligen, sind unwirksam (§ 879 Abs 3 ABGB, § 6 KSchG).

### 3.1 Kurzfassung für die Kartenrückseite

> Wertgutschein von [Restaurant]. Einlösbar für Speisen und Getränke in [Restaurant, Adresse]. Teileinlösung möglich. Keine Barauszahlung, soweit gesetzlich zulässig. Guthaben abfragen: Karte mit dem Handy scannen. Bei Verlust bitte sofort melden — Ersatz mit Kartennummer möglich. Bedingungen: [Link / Aushang].

Hinweis: Die Rückseite des GiftCard-Pro-Drucklayouts enthält QR-Code, Kartennummer, Gültigkeit und einen Scan-Hinweis. Weitere Texte können auf einem Kartenträger oder Beiblatt stehen.

### 3.2 Gutscheinbedingungen (Langfassung)

> **Gutscheinbedingungen von [Name des Restaurants]**
>
> **1. Aussteller.** Die Gutscheinkarte wird ausgestellt von [Rechtsträger, Anschrift, UID-Nummer] („Restaurant").
>
> **2. Einlösung.** Die Gutscheinkarte kann in [Restaurant, Adresse / alle Standorte: …] für Speisen und Getränke eingelöst werden. [Ausgenommen: …, falls zutreffend]. Das Restaurant prüft Guthaben und Gültigkeit beim Einlösen elektronisch.
>
> **3. Teileinlösung.** Die Karte kann in mehreren Teilbeträgen eingelöst werden. Das Restguthaben bleibt auf der Karte gespeichert. Übersteigt der Rechnungsbetrag das Guthaben, ist die Differenz auf andere Weise zu bezahlen.
>
> **4. Barauszahlung.** Eine Auszahlung des Guthabens in bar ist ausgeschlossen, soweit nicht gesetzlich etwas anderes vorgesehen ist (z. B. wenn das Restaurant die Leistung dauerhaft nicht mehr erbringen kann). [Prüfen]
>
> **5. Gültigkeit.** *Variante A (empfohlen):* Die Gutscheinkarte ist unbefristet gültig; es gelten die gesetzlichen Verjährungsfristen. *Variante B (nur nach anwaltlicher Freigabe):* Die Gutscheinkarte kann bis [Datum auf der Karte] eingelöst werden. Danach kann der Gast den Restwert noch [3] Jahre lang in eine neue Gutscheinkarte umtauschen oder sich erstatten lassen. *Gratis- und Aktionsgutscheine* sind nur bis zum angegebenen Datum gültig.
>
> **6. Übertragbarkeit.** Die Gutscheinkarte ist übertragbar. Das Restaurant darf an jede Person leisten, die die Karte vorlegt, und muss deren Berechtigung nicht prüfen. [Prüfen]
>
> **7. Verlust, Diebstahl, Beschädigung.** Bitte melden Sie den Verlust sofort. Ist die Kartennummer bekannt (z. B. über Kaufbeleg oder Kundenkonto), sperrt das Restaurant die Karte und überträgt das zu diesem Zeitpunkt vorhandene Restguthaben auf eine Ersatzkarte; die alte Karte ist danach nicht mehr verwendbar. Für Einlösungen vor der Verlustmeldung haftet das Restaurant nicht, außer bei eigenem Verschulden. [Prüfen] Für die Ersatzkarte kann ein Kostenbeitrag von [€ …] verrechnet werden. [Prüfen]
>
> **8. Aufladung.** Die Karte kann [nicht / an der Kassa] aufgeladen werden.
>
> **9. Guthabenabfrage.** Das Guthaben kann durch Scannen der Karte mit einem Smartphone oder an der Kassa abgefragt werden.
>
> **10. Missbrauch.** Das Restaurant kann Karten bei begründetem Verdacht auf Fälschung, Manipulation oder Missbrauch vorübergehend sperren und klärt den Sachverhalt mit dem Gast.
>
> **11. Datenschutz.** Angaben zur Person beim Kauf sind freiwillig. Informationen zur Datenverarbeitung: [Link zur Datenschutzerklärung / Aushang].
>
> **12. Schließung des Restaurants / Betriebsübergang.** [Regelung durch Rechtsberatung ergänzen, z. B. Erstattung des Restguthabens oder Einlösung beim Nachfolgebetrieb.] [Prüfen]

### 3.3 Einstellungen passend zu den Bedingungen

| Bedingung | Einstellung in GiftCard Pro |
|---|---|
| Teileinlösung erlaubt | **Allow partial redemption** = an |
| Aufladung erlaubt/verboten | **Allow reloads** |
| Gültigkeit | **Default validity (months)** (0 = unbefristet), je Karte **Valid until** |
| Guthabenabfrage durch Gäste | **Public balance check** |
| Ersatz bei Verlust | **Replace lost card** (Guthaben wandert auf neue Karte, alte Karte sofort ungültig) |
| Sperre bei Verdacht | **Block card** mit Begründung |

## 4. Umsatzsteuer: Einzweck- und Mehrzweckgutscheine

Seit 1. Jänner 2019 (Umsetzung der EU-Gutschein-Richtlinie (EU) 2016/1065 im UStG 1994) wird unterschieden:

| | Einzweckgutschein | Mehrzweckgutschein |
|---|---|---|
| Definition | Ort der Leistung und geschuldete Umsatzsteuer stehen **bei Ausgabe** fest. | Ort oder Steuersatz steht bei Ausgabe **nicht** fest. |
| Beispiel Gastronomie | Gutschein nur für Speisen (einheitlich 10 %) in einem österreichischen Lokal [Prüfen] | Wertgutschein über € 50 für Speisen (10 %) **und** Getränke (20 %) |
| Umsatzsteuer entsteht | beim **Verkauf** des Gutscheins | erst bei **Einlösung**, nach dem tatsächlich Konsumierten |
| Rechnung/Beleg beim Verkauf | mit USt | ohne USt (kein steuerbarer Umsatz) |

- **Typischer Fall:** Ein Restaurant-Wertgutschein, der für Speisen und Getränke verwendet werden kann, ist ein **Mehrzweckgutschein** → Umsatzsteuer bei Einlösung.
- **Nicht eingelöste Mehrzweckgutscheine** lösen grundsätzlich keine Umsatzsteuer aus. [Prüfen: Behandlung bei Verfall]
- GiftCard Pro berechnet keine Umsatzsteuer und ordnet Einlösungen keinen Steuersätzen zu. Die steuerlich maßgebliche Aufteilung ergibt sich aus der Rechnung in der Registrierkasse.

Quelle: WKO „Umsatzsteuerliche Behandlung von Gutscheinen" ([wko.at](https://www.wko.at), Suche nach dem Titel); Bundesministerium für Finanzen ([bmf.gv.at](https://www.bmf.gv.at)).

## 5. Registrierkasse (RKSV)

- **GiftCard Pro ist keine Registrierkasse**, ist nicht nach der Registrierkassensicherheitsverordnung (RKSV) zertifiziert und erstellt keine Belege. Registrierkassen- und Belegerteilungspflicht (§§ 131b, 132a BAO) bleiben unverändert beim Restaurant.
- **Verkauf** einer Gutscheinkarte und **Einlösung** müssen in der Registrierkasse des Restaurants gebucht werden — nach Anweisung Ihrer Steuerberatung.
- Üblich sind eigene Kassentasten bzw. Zahlungsarten, z. B. „Gutscheinverkauf" (bei Mehrzweckgutschein ohne USt) und Zahlungsart „Gutschein" bei der Einlösung. Die konkrete Einrichtung hängt vom Kassensystem ab. [Prüfen: mit Steuerberatung und Kassenhersteller]
- **Abgleich:** Summen aus **Transactions → Export CSV** (Verkäufe, Aufladungen, Einlösungen je Tag/Monat) regelmäßig mit der Kassa abstimmen.
- Eine direkte Kassenanbindung gibt es derzeit nicht; über die API (Tarif Pro) ist eine Integration technisch möglich.

## 6. Ertragsteuer und Bilanzierung

- **Einnahmen-Ausgaben-Rechnung** (Zufluss-Abfluss-Prinzip, § 19 EStG): Der Verkaufserlös ist grundsätzlich im Zeitpunkt des Zuflusses zu erfassen, also beim Verkauf der Karte. [Prüfen]
- **Bilanzierende Betriebe:** Erlös erst bei Einlösung; bis dahin ist das nicht eingelöste Guthaben eine **Verbindlichkeit** gegenüber den Gästen.
- **Outstanding balance** im Dashboard zeigt die offene Verbindlichkeit („Open liability on N cards") tagesaktuell — hilfreich für Monats- und Jahresabschluss.
- Keine automatische Ertragsbuchung von Restguthaben („Breakage"): Ob und wann nicht eingelöste Guthaben erfolgswirksam aufgelöst werden dürfen, entscheidet die Steuerberatung — in der Regel erst, wenn mit einer Inanspruchnahme nicht mehr zu rechnen ist. Wegen der 30-jährigen Frist ist Zurückhaltung geboten. [Prüfen]

## 7. Aufbewahrung

- Bücher, Aufzeichnungen und Belege sind **7 Jahre** aufzubewahren (§ 132 BAO); länger, solange sie für ein anhängiges Verfahren von Bedeutung sind.
- GiftCard Pro speichert alle Buchungen unveränderlich (Stornos als Gegenbuchung). Nach Vertragsende werden die Daten **30 Tage** später beim Anbieter gelöscht. **Exportieren Sie vorher** Karten, Transaktionen und Kunden (**Export CSV**) und bewahren Sie die Dateien selbst auf.
- Die Aufbewahrungspflicht geht datenschutzrechtlichen Löschwünschen vor (Art 17 Abs 3 lit b DSGVO): Kundendaten werden anonymisiert, Buchungen bleiben.

## 8. Abgelaufene Karten und Ausbuchungen — Rechtsrisiko

- Ein Ablauf in GiftCard Pro ist keine rechtliche Bewertung. War die Befristung unwirksam (Abschnitt 2), besteht der Anspruch des Gastes weiter.
- Wenn ein Gast mit einer abgelaufenen Karte kommt: Anspruch prüfen, im Zweifel Wert über eine Ersatzkarte oder Übertrag wiederherstellen. Die Buchung ist im Journal nachvollziehbar.
- Ausgebuchte Beträge nicht ohne Rücksprache mit der Steuerberatung als Ertrag verbuchen.
- Aktions- und Gratisgutscheine (ohne Gegenleistung ausgegeben) können mit klarer Befristung verfallen.

## 9. Verbraucherschutz gegenüber Gästen

- Das **Konsumentenschutzgesetz (KSchG)** gilt nicht für den Vertrag zwischen Anbieter und Restaurant (reines Unternehmergeschäft), **wohl aber** zwischen Restaurant und Gast.
- Relevante Punkte: transparente und verständliche Bedingungen (§ 6 Abs 3 KSchG), keine gröblich benachteiligenden Klauseln (§ 879 Abs 3 ABGB), Preisangaben inklusive USt, keine überraschenden Klauseln (§ 864a ABGB).
- Gutscheinkarten werden im Lokal verkauft; ein Fernabsatzgeschäft (Rücktrittsrecht nach FAGG) liegt dabei nicht vor. Ein späterer Online-Verkauf wäre gesondert zu prüfen. [Prüfen]
- Werbe-E-Mails an Gäste nur mit vorheriger Einwilligung (§ 174 TKG 2021) [Prüfen: Paragraph]; das Feld **Marketing consent** dokumentiert die Einwilligung.

## 10. Keine automatische „Breakage"

„Breakage" bezeichnet Guthaben, das nie eingelöst wird. GiftCard Pro bucht nicht eingelöstes Guthaben **nicht** als Ertrag und schüttet es niemandem aus. Das Guthaben bleibt als offene Verbindlichkeit sichtbar, bis es eingelöst, übertragen oder (bei einer Befristung) durch den Ablauf-Lauf ausgebucht wird. Ob ein Ertrag entsteht, ist eine steuerliche und rechtliche Frage (Abschnitte 6 und 8). GiftCard Pro verlangt **keine Provision** auf Verkäufe oder Einlösungen.

## 11. Quellen und weiterführende Informationen

- WKO: Gutscheine – Befristung — [https://www.wko.at/vertragsrecht/gutscheine-befristung](https://www.wko.at/vertragsrecht/gutscheine-befristung)
- WKO: Umsatzsteuerliche Behandlung von Gutscheinen — [https://www.wko.at](https://www.wko.at) (Suche nach dem Titel)
- Rechtsinformationssystem des Bundes (ABGB, KSchG, BAO, UStG 1994, EStG 1988, RKSV) — [https://www.ris.bka.gv.at](https://www.ris.bka.gv.at)
- Bundesministerium für Finanzen (Registrierkassen, Umsatzsteuer) — [https://www.bmf.gv.at](https://www.bmf.gv.at)
- Unternehmensserviceportal — [https://www.usp.gv.at](https://www.usp.gv.at)
- Verein für Konsumenteninformation — [https://www.konsument.at](https://www.konsument.at)
- Arbeiterkammer — [https://www.arbeiterkammer.at](https://www.arbeiterkammer.at)
- Österreichische Datenschutzbehörde — [https://www.dsb.gv.at](https://www.dsb.gv.at)

## 12. Haftungsausschluss

Diese Hinweise dienen der allgemeinen Information und wurden sorgfältig zusammengestellt. Sie sind keine Rechts- oder Steuerberatung und können eine individuelle Prüfung nicht ersetzen. Die Rechtslage und Rechtsprechung können sich ändern. [Firmenname] übernimmt keine Haftung für Entscheidungen, die allein auf Grundlage dieser Hinweise getroffen werden. Bitte lassen Sie Gutscheinbedingungen, Gültigkeitsmodell, Kasseneinrichtung und steuerliche Behandlung von Ihrer Rechtsanwältin / Ihrem Rechtsanwalt und Ihrer Steuerberatung bestätigen.

---

Version 1.0 · Stand: September 2026
