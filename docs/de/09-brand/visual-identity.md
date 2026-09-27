# Visuelle Identität

*Zweck: Verbindliche Spezifikation für Typografie, Farben, Icons, Fotografie, Illustration und die Gestaltung von Gutscheinkarten. Für Design, Entwicklung, Agenturen und Druckereien.*

Die visuelle Sprache folgt der Produktoberfläche: viel Weiß, fast schwarze Schrift, ruhige abgerundete Karten, feine Linien, Lucide-Icons – und ein einziger warmer Akzent in Safran. Referenzen: `../../screenshots/owner-dashboard.png`, `../../screenshots/dark-dashboard.png`, `../../screenshots/waiter-amount.png`, `../../screenshots/print-card.png`.

---

## 1. Typografie

### 1.1 Schriftfamilie

| Schrift | Einsatz | Schnitte |
|---|---|---|
| **Geist** (Sans) | alles: Headlines, Fließtext, UI, Karten, Präsentationen | Regular 400, Medium 500, Semibold 600, Bold 700 (nur Beträge auf Karten und Kellner-App) |
| **Geist Mono** | nur Code, technische IDs, API-Beispiele, UUIDs | Regular 400, Medium 500 |

**Lizenz:** Geist und Geist Mono stehen unter der SIL Open Font License 1.1 – kostenlos für Web, Druck und Apps, auch kommerziell; Einbetten erlaubt; die Schrift darf nicht einzeln verkauft werden. Quelle: offizielles Geist-Repository von Vercel.

**Fallback-Stack (Web):**
```css
font-family: "Geist", ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
font-family: "Geist Mono", ui-monospace, "SF Mono", Menlo, Consolas, monospace; /* nur Code/IDs */
```

**Fallback Druck und Office:** Inter (ebenfalls SIL OFL). Wenn weder Geist noch Inter verfügbar ist (z. B. E-Mail-Signatur, fremde Office-Umgebung): Arial.

### 1.2 Grundregeln

- **Headlines:** Semibold 600, Laufweite eng (−2 % bis −3 %), linksbündig.
- **Fließtext:** Regular 400, 16 px / Zeilenhöhe 1,5, Zeilenlänge 60–75 Zeichen.
- **Zahlen:** immer **Tabellenziffern** (`font-variant-numeric: tabular-nums;`), damit Beträge sauber untereinanderstehen und beim Tippen in der Kellner-App nicht springen.
- **Overline-Labels:** Versalien, Medium 500, 11–12 px, Laufweite +8 % – wie „GUTSCHEIN" auf der gedruckten Karte.
- **Keine** Kursivschrift für Hervorhebung im UI; Hervorhebung über Gewicht (Medium/Semibold).
- **Keine** Versalien für ganze Sätze oder Headlines.

### 1.3 Schriftskala Web und App

| Stufe | Größe / Zeilenhöhe | Gewicht | Laufweite | Einsatz |
|---|---|---|---|---|
| Display | 56 / 60 px (mobil 40 / 44) | 600 | −3 % | Website-Hero |
| H1 | 40 / 44 px (mobil 32 / 36) | 600 | −2,5 % | Seitentitel Website |
| H2 | 32 / 38 px (mobil 26 / 32) | 600 | −2 % | Abschnitte |
| H3 | 24 / 30 px | 600 | −1,5 % | App-Seitentitel („Dashboard"), Karten-Headlines |
| H4 | 18 / 26 px | 600 | −1 % | Kartentitel im Dashboard („Card status") |
| Body L | 18 / 28 px | 400 | 0 | Einleitungen, Website |
| Body | 16 / 24 px | 400 | 0 | Standardtext |
| Small | 14 / 20 px | 400 / 500 | 0 | UI-Labels, Navigation, Tabellen |
| Caption | 12 / 16 px | 400 | 0 | Metadaten („••1503 · Maria Huber · vor 1 Minute") |
| Overline | 11 / 16 px | 500 | +8 % | Labels in Versalien |
| KPI-Zahl | 28 / 32 px | 600 | −2 % | Kennzahlen im Dashboard („€ 258,00") |
| Betrag Kellner-App | 48 / 52 px | 600 | −2 % | eingegebener/eingelöster Betrag |

### 1.4 Schriftskala Druck

| Stufe | Größe / Zeilenabstand | Gewicht | Einsatz |
|---|---|---|---|
| Titel | 28 / 32 pt | 600 | Flyer-Titel, Plakate A4 |
| Headline | 18 / 22 pt | 600 | Abschnitte, Folientitel im Druck |
| Subline | 12 / 16 pt | 500 | Unterzeilen |
| Fließtext | 9,5 / 13,5 pt | 400 | Flyer, Broschüre |
| Klein | 7 / 9 pt | 400 | Fußnoten, Impressum |
| **Karte:** Overline | 5,5 pt, +12 % | 500 | „GUTSCHEIN" |
| **Karte:** Restaurantname | 9–11 pt | 600 | Vorderseite |
| **Karte:** Betrag | 18–22 pt | 600/700 | Vorderseite |
| **Karte:** Kartennummer | 8 pt, Tabellenziffern | 600 | Rückseite |
| **Karte:** Hinweistext | 6 pt (Minimum) | 400 | Rückseite |

Mindestschriftgrad im Druck: 6 pt (positiv), 7 pt bei weißer Schrift auf Tinte.

---

## 2. Farben

### 2.1 Kernpalette

CMYK-Werte sind Näherungen für gestrichenes Papier (PSO Coated v3 / FOGRA51) und müssen mit einem Proof der Druckerei abgestimmt werden.

| Name | Hex | RGB | CMYK (Näherung) | Einsatz |
|---|---|---|---|---|
| **Tinte** (Ink) | #0F172A | 15 · 23 · 42 | 90 · 78 · 45 · 65 | Primäre Markenfarbe, Standard-Kartenfarbe, Headlines |
| **Graphit** | #18181B | 24 · 24 · 27 | 70 · 65 · 60 · 80 | UI-Text, primäre Buttons |
| **Stein** (Stone) | #71717A | 113 · 113 · 122 | 55 · 45 · 38 · 20 | Sekundärtext, „Pro" in der Wortmarke |
| **Linie** (Line) | #E4E4E7 | 228 · 228 · 231 | 10 · 7 · 6 · 0 | Rahmen, Trennlinien |
| **Papier** (Paper) | #FAFAFA | 250 · 250 · 250 | 2 · 1 · 1 · 0 | Hintergründe |
| **Weiß** | #FFFFFF | 255 · 255 · 255 | 0 · 0 · 0 · 0 | Flächen, Karten im UI |
| **Safran** (Saffron) | #E8A33D | 232 · 163 · 61 | 5 · 40 · 85 · 0 | Akzent – Wärme, Hervorhebung, max. 10 % einer Fläche |
| **Salbei** (Sage/Success) | #047857 | 4 · 120 · 87 | 88 · 20 · 75 · 15 | Erfolg, positive Beträge |
| **Paprika** (Error) | #B91C1C | 185 · 28 · 28 | 15 · 100 · 100 · 5 | Fehler, gesperrt |
| **Himmel** (Chart blue) | #2563EB | 37 · 99 · 235 | 85 · 60 · 0 · 0 | nur Daten und Diagramme |

### 2.2 Kontrast (WCAG 2.1 AA)

AA verlangt 4,5 : 1 für normalen Text und 3 : 1 für großen Text (ab 24 px bzw. 18,66 px fett) und grafische Bedienelemente. Werte berechnet nach WCAG-Formel.

| Kombination | Kontrast | Normaler Text | Großer Text / Grafik |
|---|---|---|---|
| Tinte auf Weiß | 17,9 : 1 | ✓ | ✓ |
| Graphit auf Weiß | 17,7 : 1 | ✓ | ✓ |
| Graphit auf Papier | 17,0 : 1 | ✓ | ✓ |
| Weiß auf Tinte | 17,9 : 1 | ✓ | ✓ |
| **Stein auf Weiß** | **4,8 : 1** | ✓ | ✓ |
| Stein auf Papier | 4,6 : 1 | ✓ (knapp) | ✓ |
| Stein auf #F4F4F5 (graue Fläche) | 4,4 : 1 | ✗ | ✓ |
| Stein auf Tinte | 3,7 : 1 | ✗ | ✓ |
| Salbei auf Weiß | 5,5 : 1 | ✓ | ✓ |
| Weiß auf Salbei | 5,5 : 1 | ✓ | ✓ |
| Paprika auf Weiß | 6,5 : 1 | ✓ | ✓ |
| Weiß auf Paprika | 6,5 : 1 | ✓ | ✓ |
| Himmel auf Weiß | 5,2 : 1 | ✓ | ✓ |
| Safran auf Tinte | 8,3 : 1 | ✓ | ✓ |
| Tinte auf Safran | 8,3 : 1 | ✓ | ✓ |
| **Safran auf Weiß** | **2,2 : 1** | ✗ | ✗ |
| Linie auf Weiß | 1,3 : 1 | ✗ | ✗ (nur dekorativ) |

**Daraus folgt:**
- Safran **nie** als Textfarbe oder einziges Erkennungsmerkmal auf hellem Grund. Auf Weiß nur als Fläche mit dunklem Text (Tinte auf Safran) oder als dekorativer Akzent neben Text. Für Text in Safran-Anmutung auf Weiß: **Safran dunkel #B45309** (5,0 : 1).
- Stein nur auf Weiß oder Papier für Fließtext; auf grauen Flächen und auf Tinte nur für große Texte. Auf Tinte stattdessen #A1A1AA (7,0 : 1).
- Linie ist nie Träger von Information. Eingabefelder brauchen eine Kontur mit mindestens 3 : 1 – dafür **Linie stark #8A8A93** (3,4 : 1 auf Weiß) – und einen deutlichen Fokuszustand. #A1A1AA erreicht auf Weiß nur 2,6 : 1 und ist ausschließlich für den Dark Mode gedacht.
- Status nie nur über Farbe: immer Icon und Text dazu („✓ Active", „⊘ Blocked").

### 2.3 Mengenverhältnis

| Farbe | Anteil an einer typischen Fläche |
|---|---|
| Weiß / Papier | 70–80 % |
| Graphit / Tinte (Text, Buttons, Karten) | 15–20 % |
| Stein / Linie | 5–10 % |
| Safran | **max. 10 %** – meist deutlich weniger (Bögen, eine Hervorhebung, ein Unterstrich) |
| Salbei / Paprika | nur für Status, nie dekorativ |
| Himmel | nur in Diagrammen |

Ausnahme: Gutscheinkarten und Social-Grafiken dürfen bis zu 90 % Tinte haben.

### 2.4 Dark Mode

Die App unterstützt hellen und dunklen Modus (`../../screenshots/dark-dashboard.png`).

| Token | Hell | Dunkel | Kontrast dunkel |
|---|---|---|---|
| Hintergrund | #FAFAFA | #09090B | – |
| Fläche (Karten) | #FFFFFF | #18181B | – |
| Linie | #E4E4E7 | #27272A | – |
| Text primär | #18181B | #FAFAFA | 17,0 : 1 auf #18181B |
| Text sekundär | #71717A | #A1A1AA | 6,9 : 1 auf #18181B |
| Primärbutton | Graphit, Text Weiß | Weiß, Text Graphit | 17,7 : 1 |
| Akzent | #E8A33D | #E8A33D | 8,2 : 1 auf #18181B |
| Erfolg | #047857 | #34D399 | 9,2 : 1 |
| Fehler | #B91C1C | #F87171 | 6,4 : 1 |
| Diagramm | #2563EB | #60A5FA | 7,0 : 1 |

Im Dark Mode wird die Tinte-Karte (Logo, Kartenvorschau) durch eine 1 px Kontur #27272A vom Hintergrund getrennt.

### 2.5 Datenvisualisierung

| Reihenfolge | Name | Hex | Einsatz |
|---|---|---|---|
| 1 | Himmel | #2563EB | Hauptreihe (z. B. „Verkauft") |
| 2 | Kupfer (abgeleitet von Safran) | #B45309 | Vergleichsreihe (z. B. „Eingelöst"), 5,0 : 1 auf Weiß |
| 3 | Schiefer | #475569 | dritte Reihe, Vorjahr |
| 4 | Himmel hell | #93C5FD | nur Flächen und Bereiche hinter anderen Daten (1,8 : 1 auf Weiß – nie als alleiniger Datenträger) |
| Status | Salbei · Paprika · Stein | wie oben | nur für Status (Aktiv, Gesperrt, Ersetzt/Inaktiv) |

**Regeln:** max. vier Reihen pro Diagramm; Achsen und Gitter in Linie #E4E4E7, Beschriftung in Stein 12 px; Beträge im Format „€ 1.000"; Legende immer mit Text; keine 3D-Diagramme, keine Kreisdiagramme mit mehr als vier Segmenten; wichtige Werte direkt beschriften.

> Hinweis: Einzelne Farbtöne der aktuellen App (z. B. das hellere Grün im Erfolgskreis der Kellner-App, der Farbton der Reihe „Redeemed") weichen leicht von dieser Palette ab. Sie werden beim nächsten Design-Update angeglichen; bis dahin gilt für alle neuen Materialien diese Spezifikation.

---

## 3. Icons

**Stil:** Lucide (die App verwendet Lucide). Ausschließlich Linien-Icons.

| Eigenschaft | Wert |
|---|---|
| Raster | 24 × 24 px, 2 px Innenabstand (aktive Fläche 20 × 20 px) |
| Strichstärke | 1,5 px (Standard in UI und Marketing) · 2 px ab 32 px Darstellungsgröße oder in der Kellner-App |
| Linienenden und -ecken | rund (`stroke-linecap: round; stroke-linejoin: round`) |
| Eckradius in Formen | 2 px (z. B. Kartensymbol `credit-card`) |
| Größen | 16 px (Tabellen, Badges) · 20 px (Navigation) · 24 px (Standard) · 32–48 px (Marketing) |
| Farbe | `currentColor` – Graphit, Stein oder Weiß; Safran nur für ein einziges hervorgehobenes Icon pro Fläche |

**Standard-Icons (Lucide-Namen):** `credit-card` (Karte), `nfc` bzw. `wifi` 90° gedreht (Antippen), `wallet` (offener Betrag), `euro` (Umsatz), `arrow-down-right` (eingelöst), `shuffle` (Übertragen), `shield-check` (Sicherheit), `scroll-text` (Prüfprotokoll), `smartphone` (Geräte), `users` (Team), `printer` (Drucken), `qr-code` (QR).

**So:**
- ein Icon pro Bedeutung, immer dasselbe;
- Icons immer mit Text-Label, außer bei allgemein bekannten Aktionen (Schließen, Menü) – dann mit `aria-label`;
- Icon und Text optisch mittig ausgerichtet, Abstand 8 px.

**So nicht:**
- gefüllte Icons, Duoton-Icons, Emojis als Icons;
- Icons aus anderen Sets mischen;
- Icons in farbigen Kreisen als Dekoration (Ausnahme: Aktivitätsliste im Dashboard mit 10 % getönten Kreisen);
- Strichstärke skalieren lassen (`vector-effect: non-scaling-stroke` bzw. passende Stärke je Größe).

---

## 4. Fotografie

### 4.1 Grundsätze

- **Echte österreichische Lokale** – keine Stockfotos, keine Studios.
- **Natürliches Licht**, warme Töne, geringe Schärfentiefe.
- **Hände und Momente** statt posierender Gesichter: eine Karte wird überreicht, ein Handy wird angetippt, der Wirt steht an der Schank.
- **Keine Stock-Lächeln, keine inszenierten High-Fives**, kein Blick in die Kamera mit erhobenem Daumen.
- **Vielfalt der Gastronomie:** Wirtshaus, Kaffeehaus, Heuriger, modernes Bistro, Bar, Hotelrestaurant – und die Menschen, die dort arbeiten: jung und alt, unterschiedliche Herkunft, Frauen und Männer im Service und hinter der Schank.
- **Karte im Bild:** immer mit realistischem Design (Restaurantlogo, Betrag) – nie mit „GiftCard Pro" als Kartenaufdruck auf der Vorderseite.

### 4.2 Technik

| Thema | Vorgabe |
|---|---|
| Licht | Tageslicht oder vorhandenes warmes Lokallicht; kein direkter Blitz |
| Farbe | warm, natürlich, leicht entsättigt; keine Filter-Looks |
| Schärfentiefe | Blende f/1,8–f/2,8, Fokus auf Hand/Karte/Display |
| Komposition | viel Ruhe, ein Motiv, Platz für Text (Drittelregel) |
| Formate | Querformat 3 : 2 und 16 : 9, Hochformat 4 : 5 und 9 : 16 |
| Auflösung | mind. 4000 px lange Kante, Druck 300 dpi |
| Rechte | schriftliche Einwilligung aller erkennbaren Personen und des Lokals; Bildrechte schriftlich |
| Displays | echte App-Screens mit plausiblen Beispieldaten; keine echten Kundendaten |

### 4.3 Shotlist (20 Motive)

| # | Motiv | Ort | Einsatz |
|---|---|---|---|
| 1 | Kellnerin tippt Gutscheinkarte an ein Android-Handy, Fokus auf Karte | Wirtshaus, Holztisch | Website-Hero |
| 2 | Gast überreicht eine Karte im Kuvert an eine andere Person | Kaffeehaus, Marmortisch | Schenken, Advent |
| 3 | Hand hält die Karte über einen gedeckten Tisch, warmes Abendlicht | modernes Bistro | Social, OG-Bild |
| 4 | Wirt an der Schank, Handy mit Erfolgsbildschirm neben der Registrierkasse | Wirtshaus | Sicherheit/Einfachheit |
| 5 | Kartenstapel mit Restaurantdesign neben Kassa, Detail | Kaffeehaus | Starterset |
| 6 | Servicekraft zeigt dem Gast den Betrag auf dem Display | Heuriger, Garten | Vertrauen |
| 7 | Inhaberin am Laptop im Büro hinter der Küche, Dashboard sichtbar | Restaurant-Büro | Dashboard |
| 8 | Nahaufnahme: iPhone-Oberkante berührt die Karte | neutraler Tisch | NFC erklären |
| 9 | Karte in Geschenkverpackung mit Schleife, Tannenzweig | Kaffeehaus | Weihnachten |
| 10 | Heurigentisch mit Weinglas, Karte liegt neben der Rechnung | Heuriger | Saisonal, Herbst |
| 11 | Kellner tippt Betrag auf der Tastatur der Kellner-App, Daumen im Fokus | Bistro | Kellner-App |
| 12 | Gast prüft Guthaben mit eigenem Handy, Karte in der Hand | Straße vor dem Lokal | Guthabenabfrage |
| 13 | Team-Briefing vor Schichtbeginn, Handy wird herumgereicht | Wirtshausküche/Pass | Einrichtung, Schulung |
| 14 | Steuerberaterin mit CSV-Export in Excel, Laptop, Belege | Kanzlei | Export, B2B |
| 15 | Karten werden aus dem Druckerei-Karton genommen | Lager/Lokal | Kartenbestellung |
| 16 | Muttertag: Blumen und Karte auf Frühstückstisch | Café | Muttertag |
| 17 | Barkeeper nimmt Karte entgegen, Theke im Vordergrund unscharf | Bar | Bars |
| 18 | Hotelrezeption/Outlet mit mehreren Kartendesigns | Hotel | Tarif Gruppe |
| 19 | Gründerin vor Ort bei der Einrichtung, erklärt einer Wirtin die App | Wiener Lokal | Über uns `[Foto nach Freigabe]` |
| 20 | Detail: Kartenrückseite mit QR-Code und Kartennummer, Makro | Studio-Tisch, Tageslicht | Produktdetail |

---

## 5. Illustration

- **Stil:** minimale Linienzeichnungen in Graphit, Strich 1,5–2 px (bei 24-px-Raster) bzw. proportional größer, runde Enden – dieselbe Anmutung wie die Icons.
- **Ein einziger Safran-Akzent** pro Illustration (z. B. die NFC-Bögen, ein Preisschild, eine Kerze).
- **Keine** 3D-Blobs, keine Verläufe, keine Isometrie, keine Figuren mit übergroßen Gliedmaßen, keine Schatten.
- **Motive:** Karte, Handy, Hand, Tisch, Teller, Kaffeetasse, Weinglas, Schank, Kalender (Saison), Kuvert.
- **Flächen:** höchstens eine Fläche in Papier #FAFAFA oder Linie #E4E4E7 zur Gliederung.
- **Einsatz:** leere Zustände in der App, Erklärgrafiken (Ablauf „Antippen – Betrag – fertig"), Onboarding, Social-Karussells.
- **Menschen:** stilisiert, ohne Gesichtsdetails, vielfältig durch Kleidung und Haltung, nicht durch Klischees.

---

## 6. Gutscheinkarten-Vorlagen

Gutscheinkarten tragen die Marke des **Restaurants**, nicht die von GiftCard Pro. Diese Regeln sichern Lesbarkeit, Funktion und Druckqualität.

### 6.1 Format und Druckdaten

| Merkmal | Wert |
|---|---|
| Endformat | ISO/IEC 7810 ID-1: 85,6 × 54 mm, Eckradius 3,18 mm |
| Beschnitt | 2 mm rundum → Datenformat 89,6 × 58 mm |
| Sicherheitsabstand | 3 mm innerhalb des Endformats → Satzspiegel 79,6 × 48 mm |
| Farbmodus | CMYK, Profil nach Vorgabe der Druckerei (typisch PSO Coated v3 / FOGRA51) |
| Gesamtfarbauftrag | max. 300 % |
| Tinte-Fläche | als Vierfarb-Tiefschwarz nach Proof (Näherung C 90 · M 78 · Y 45 · K 65) |
| Kleiner Text, Kartennummer, QR | 100 % K bzw. einfarbig – nie aus vier Farben aufgebaut |
| Bilder | mind. 300 dpi in Endgröße |
| Schriften | eingebettet oder in Pfade umgewandelt |
| Dateiformat | PDF/X-4, eine Seite pro Kartenseite, Beschnittmarken |
| Metall, Folie, Heißprägung | nicht über dem Antennenbereich des NFC-Chips; mit Druckerei abstimmen |

### 6.2 Vorderseite

```
┌──────────────────────────────────────────┐
│ GUTSCHEIN                      ))) NFC   │  ← Overline 5,5 pt · NFC-Symbol oben rechts
│ [Logo / Name des Restaurants]            │  ← Logozone: max. 30 × 12 mm, oben links
│                                          │
│                                          │
│ Für: [Name der beschenkten Person]       │  ← optional, 7–8 pt
│ € 50,00                                  │  ← Betrag 18–22 pt, unten links
└──────────────────────────────────────────┘
```

| Zone | Regel |
|---|---|
| Logozone | oben links, innerhalb des Sicherheitsabstands, max. 30 × 12 mm |
| Overline | „GUTSCHEIN" bzw. „GESCHENKKARTE" in der Sprache des Restaurants, 5,5 pt, Versalien, +12 % |
| Betrag | unten links, 18–22 pt Semibold/Bold, Tabellenziffern; bei aufladbaren Karten optional ohne Betrag |
| Empfänger/in | optional, über dem Betrag, 7–8 pt |
| NFC-Symbol | oben rechts, drei Bögen, 6–8 mm hoch; zeigt Gästen und Servicekräften, wo getippt wird |
| Hintergrund | Standard Tinte #0F172A; alternativ Markenfarbe des Restaurants, Kontrast zum Text mind. 4,5 : 1 |

### 6.3 Rückseite

```
┌──────────────────────────────────────────┐
│ ┌────────┐  7650 3531 2221 9919          │  ← Kartennummer 8 pt, Viererblöcke
│ │   QR   │  Ohne Ablaufdatum             │  ← Gültigkeit
│ │        │  Code scannen oder Karte ans  │  ← Hinweis 6 pt
│ └────────┘  Handy halten, um das         │
│             Guthaben zu prüfen.          │
│ [Adresse · Telefon · Web des Lokals]  Powered by GiftCard Pro │
└──────────────────────────────────────────┘
```

| Zone | Regel |
|---|---|
| QR-Code | mind. 18 × 18 mm, Ruhezone mind. 4 Module (bei 18 mm ca. 2,5 mm), schwarz auf weiß, nicht invertiert, nicht eingefärbt |
| Kartennummer | 16 Stellen in Viererblöcken, 8 pt Semibold, Tabellenziffern |
| Gültigkeit | „Gültig bis 26.09.2029" oder „Ohne Ablaufdatum" – Empfehlung: ohne Ablaufdatum (siehe Hinweis unten) |
| Hinweistext | „Code scannen oder Karte ans Handy halten, um das Guthaben zu prüfen." in der Sprache des Restaurants |
| Kontaktdaten | Adresse, Telefon, Website des Restaurants, 6 pt |
| Absenderzeile | „Powered by GiftCard Pro", 5,5 pt, Stein, unten rechts – optional, nie größer als die Kontaktdaten |
| Hintergrund | Weiß (sichere QR-Lesbarkeit) |

> **Gültigkeit – keine Rechtsberatung:** Bei bezahlten Gutscheinen ist eine allgemeine Befristung auf drei Jahre oder weniger in Österreich laut OGH-Rechtsprechung in der Regel unwirksam. Empfehlung: „Ohne Ablaufdatum" drucken, sofern die Rechtsberatung des Restaurants kein anderes Modell freigibt. Mit Steuerberatung/Rechtsanwalt prüfen.

### 6.4 Selbstdruck (nur QR)

Das Druck-Layout der App (`../../screenshots/print-card.png`) erzeugt Vorder- und Rückseite im Kartenformat. Druck mit 100 % Skalierung (nicht „an Seite anpassen"), auf mind. 300 g/m² Karton, entlang der Kanten schneiden. Diese Karten haben keinen NFC-Chip; eingelöst wird über den QR-Code oder die Kartennummer.

### 6.5 Freigabe vor dem Druck

1. Digitaler Proof (PDF) an das Restaurant zur Freigabe.
2. QR-Code mit zwei Handys (Android und iPhone) aus dem Proof testen.
3. Bei NFC-Karten: Musterkarte beschreiben und antippen, bevor die Auflage gedruckt wird.
4. Schriftliche Freigabe des Restaurants per E-Mail archivieren.

---

Version 1.0 · Stand: September 2026
