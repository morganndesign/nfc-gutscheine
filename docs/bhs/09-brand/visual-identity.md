# Vizuelni identitet

*Svrha: Obavezna specifikacija tipografije, boja, ikona, fotografije, ilustracije i dizajna poklon kartica. Za dizajn, razvoj, agencije i štamparije.*

Vizuelni jezik prati interfejs proizvoda: mnogo bijelog, gotovo crna slova, mirne zaobljene kartice, tanke linije, Lucide ikone – i jedan jedini topli akcent u Šafranu. Reference: `../../screenshots/owner-dashboard.png`, `../../screenshots/dark-dashboard.png`, `../../screenshots/waiter-amount.png`, `../../screenshots/print-card.png`.

**Nazivi boja:** u BHS dokumentima koriste se prevedeni nazivi; u datotekama i kodu važe njemački/engleski nazivi (Tinte/Ink itd.) i hex vrijednosti.

---

## 1. Tipografija

### 1.1 Porodica fontova

| Font | Upotreba | Rezovi |
|---|---|---|
| **Geist** (Sans) | sve: naslovi, tekst, interfejs, kartice, prezentacije | Regular 400, Medium 500, Semibold 600, Bold 700 (samo iznosi na karticama i u aplikaciji za konobare) |
| **Geist Mono** | samo kod, tehnički ID-ovi, API primjeri, UUID-ovi | Regular 400, Medium 500 |

**Licenca:** Geist i Geist Mono su pod licencom SIL Open Font License 1.1 – besplatno za web, štampu i aplikacije, i komercijalno; ugrađivanje dozvoljeno; font se ne smije prodavati samostalno. Izvor: službeni Geist repozitorij kompanije Vercel.

**Rezervni niz (web):**
```css
font-family: "Geist", ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
font-family: "Geist Mono", ui-monospace, "SF Mono", Menlo, Consolas, monospace; /* samo kod/ID-ovi */
```

**Rezervni font za štampu i Office:** Inter (također SIL OFL). Ako nisu dostupni ni Geist ni Inter (npr. e-mail potpis, tuđe Office okruženje): Arial.

### 1.2 Osnovna pravila

- **Naslovi:** Semibold 600, uzak razmak slova (−2 % do −3 %), poravnati lijevo.
- **Tekst:** Regular 400, 16 px / visina reda 1,5, dužina reda 60–75 znakova.
- **Brojke:** uvijek **tabelarne cifre** (`font-variant-numeric: tabular-nums;`), da iznosi stoje uredno jedan ispod drugog i ne „skaču" pri kucanju u aplikaciji za konobare.
- **Mali natpisi (overline):** verzal, Medium 500, 11–12 px, razmak slova +8 % – kao „GUTSCHEIN" na štampanoj kartici.
- **Bez** kurziva za isticanje u interfejsu; isticanje debljinom (Medium/Semibold).
- **Bez** verzala za cijele rečenice ili naslove.

### 1.3 Tipografska skala za web i aplikaciju

| Nivo | Veličina / visina reda | Debljina | Razmak slova | Upotreba |
|---|---|---|---|---|
| Display | 56 / 60 px (mobilno 40 / 44) | 600 | −3 % | glavni naslov web stranice |
| H1 | 40 / 44 px (mobilno 32 / 36) | 600 | −2,5 % | naslov stranice na webu |
| H2 | 32 / 38 px (mobilno 26 / 32) | 600 | −2 % | odjeljci |
| H3 | 24 / 30 px | 600 | −1,5 % | naslov stranice u aplikaciji („Dashboard"), naslovi kartica |
| H4 | 18 / 26 px | 600 | −1 % | naslov kartice na kontrolnoj tabli („Card status") |
| Body L | 18 / 28 px | 400 | 0 | uvodi, web |
| Body | 16 / 24 px | 400 | 0 | standardni tekst |
| Small | 14 / 20 px | 400 / 500 | 0 | oznake u interfejsu, navigacija, tabele |
| Caption | 12 / 16 px | 400 | 0 | metapodaci („••1503 · Maria Huber · prije 1 minute") |
| Overline | 11 / 16 px | 500 | +8 % | natpisi u verzalu |
| KPI brojka | 28 / 32 px | 600 | −2 % | ključni pokazatelji na kontrolnoj tabli („€ 258,00" u interfejsu) |
| Iznos u aplikaciji za konobare | 48 / 52 px | 600 | −2 % | uneseni/iskorišteni iznos |

### 1.4 Tipografska skala za štampu

| Nivo | Veličina / prored | Debljina | Upotreba |
|---|---|---|---|
| Naslov | 28 / 32 pt | 600 | naslov letka, plakati A4 |
| Podnaslov velikog nivoa | 18 / 22 pt | 600 | odjeljci, naslovi slajdova u štampi |
| Podnaslov | 12 / 16 pt | 500 | podnaslovi |
| Tekst | 9,5 / 13,5 pt | 400 | letak, brošura |
| Sitno | 7 / 9 pt | 400 | fusnote, impresum |
| **Kartica:** overline | 5,5 pt, +12 % | 500 | „GUTSCHEIN" / „POKLON BON" |
| **Kartica:** naziv restorana | 9–11 pt | 600 | prednja strana |
| **Kartica:** iznos | 18–22 pt | 600/700 | prednja strana |
| **Kartica:** broj kartice | 8 pt, tabelarne cifre | 600 | zadnja strana |
| **Kartica:** tekst uputstva | 6 pt (minimum) | 400 | zadnja strana |

Minimalna veličina fonta u štampi: 6 pt (tamno na svijetlom), 7 pt za bijela slova na Tinti.

---

## 2. Boje

### 2.1 Osnovna paleta

CMYK vrijednosti su približne za premazni papir (PSO Coated v3 / FOGRA51) i moraju se uskladiti s probnim otiskom štamparije.

| Naziv (BHS) | Naziv (DE/EN) | Hex | RGB | CMYK (približno) | Upotreba |
|---|---|---|---|---|---|
| **Tinta** | Tinte (Ink) | #0F172A | 15 · 23 · 42 | 90 · 78 · 45 · 65 | primarna boja brenda, standardna boja kartice, naslovi |
| **Grafit** | Graphit | #18181B | 24 · 24 · 27 | 70 · 65 · 60 · 80 | tekst u interfejsu, primarna dugmad |
| **Kamen** | Stein (Stone) | #71717A | 113 · 113 · 122 | 55 · 45 · 38 · 20 | sekundarni tekst, „Pro" u logotipu |
| **Linija** | Linie (Line) | #E4E4E7 | 228 · 228 · 231 | 10 · 7 · 6 · 0 | okviri, razdjelnici |
| **Papir** | Papier (Paper) | #FAFAFA | 250 · 250 · 250 | 2 · 1 · 1 · 0 | pozadine |
| **Bijela** | Weiß | #FFFFFF | 255 · 255 · 255 | 0 · 0 · 0 · 0 | površine, kartice u interfejsu |
| **Šafran** | Safran (Saffron) | #E8A33D | 232 · 163 · 61 | 5 · 40 · 85 · 0 | akcent – toplina, isticanje, najviše 10 % površine |
| **Žalfija** | Salbei (Sage/Success) | #047857 | 4 · 120 · 87 | 88 · 20 · 75 · 15 | uspjeh, pozitivni iznosi |
| **Paprika** | Paprika (Error) | #B91C1C | 185 · 28 · 28 | 15 · 100 · 100 · 5 | greške, blokirano |
| **Nebo** | Himmel (Chart blue) | #2563EB | 37 · 99 · 235 | 85 · 60 · 0 · 0 | samo podaci i grafikoni |

### 2.2 Kontrast (WCAG 2.1 AA)

AA traži 4,5 : 1 za normalan tekst i 3 : 1 za veliki tekst (od 24 px odnosno 18,66 px podebljano) i grafičke kontrole. Vrijednosti izračunate prema WCAG formuli.

| Kombinacija | Kontrast | Normalan tekst | Veliki tekst / grafika |
|---|---|---|---|
| Tinta na Bijeloj | 17,9 : 1 | ✓ | ✓ |
| Grafit na Bijeloj | 17,7 : 1 | ✓ | ✓ |
| Grafit na Papiru | 17,0 : 1 | ✓ | ✓ |
| Bijela na Tinti | 17,9 : 1 | ✓ | ✓ |
| **Kamen na Bijeloj** | **4,8 : 1** | ✓ | ✓ |
| Kamen na Papiru | 4,6 : 1 | ✓ (tijesno) | ✓ |
| Kamen na #F4F4F5 (siva površina) | 4,4 : 1 | ✗ | ✓ |
| Kamen na Tinti | 3,7 : 1 | ✗ | ✓ |
| Žalfija na Bijeloj | 5,5 : 1 | ✓ | ✓ |
| Bijela na Žalfiji | 5,5 : 1 | ✓ | ✓ |
| Paprika na Bijeloj | 6,5 : 1 | ✓ | ✓ |
| Bijela na Paprici | 6,5 : 1 | ✓ | ✓ |
| Nebo na Bijeloj | 5,2 : 1 | ✓ | ✓ |
| Šafran na Tinti | 8,3 : 1 | ✓ | ✓ |
| Tinta na Šafranu | 8,3 : 1 | ✓ | ✓ |
| **Šafran na Bijeloj** | **2,2 : 1** | ✗ | ✗ |
| Linija na Bijeloj | 1,3 : 1 | ✗ | ✗ (samo dekorativno) |

**Iz toga slijedi:**
- Šafran **nikad** kao boja teksta ili jedini znak raspoznavanja na svijetloj podlozi. Na bijelom samo kao površina s tamnim tekstom (Tinta na Šafranu) ili kao dekorativni akcent pored teksta. Za tekst s dojmom Šafrana na bijelom: **tamni Šafran #B45309** (5,0 : 1).
- Kamen za tekst samo na Bijeloj ili Papiru; na sivim površinama i na Tinti samo za veliki tekst. Na Tinti umjesto njega #A1A1AA (7,0 : 1).
- Linija nikad ne nosi informaciju. Polja za unos trebaju obrub s najmanje 3 : 1 – za to **jaka Linija #8A8A93** (3,4 : 1 na Bijeloj) – i jasno stanje fokusa. #A1A1AA na Bijeloj postiže samo 2,6 : 1 i namijenjena je isključivo tamnom režimu.
- Status nikad samo bojom: uvijek s ikonom i tekstom („✓ Active", „⊘ Blocked").

### 2.3 Omjer upotrebe

| Boja | Udio na tipičnoj površini |
|---|---|
| Bijela / Papir | 70–80 % |
| Grafit / Tinta (tekst, dugmad, kartice) | 15–20 % |
| Kamen / Linija | 5–10 % |
| Šafran | **najviše 10 %** – obično znatno manje (lukovi, jedno isticanje, podvlaka) |
| Žalfija / Paprika | samo za status, nikad dekorativno |
| Nebo | samo u grafikonima |

Izuzetak: poklon kartice i grafike za društvene mreže smiju imati do 90 % Tinte.

### 2.4 Tamni režim

Aplikacija podržava svijetli i tamni režim (`../../screenshots/dark-dashboard.png`).

| Token | Svijetlo | Tamno | Kontrast tamno |
|---|---|---|---|
| Pozadina | #FAFAFA | #09090B | – |
| Površina (kartice) | #FFFFFF | #18181B | – |
| Linija | #E4E4E7 | #27272A | – |
| Primarni tekst | #18181B | #FAFAFA | 17,0 : 1 na #18181B |
| Sekundarni tekst | #71717A | #A1A1AA | 6,9 : 1 na #18181B |
| Primarno dugme | Grafit, tekst Bijela | Bijela, tekst Grafit | 17,7 : 1 |
| Akcent | #E8A33D | #E8A33D | 8,2 : 1 na #18181B |
| Uspjeh | #047857 | #34D399 | 9,2 : 1 |
| Greška | #B91C1C | #F87171 | 6,4 : 1 |
| Grafikon | #2563EB | #60A5FA | 7,0 : 1 |

U tamnom režimu kartica u Tinti (logotip, pregled kartice) odvaja se od pozadine obrubom od 1 px u #27272A.

### 2.5 Vizualizacija podataka

| Redoslijed | Naziv | Hex | Upotreba |
|---|---|---|---|
| 1 | Nebo | #2563EB | glavna serija (npr. „Prodano") |
| 2 | Bakar (izveden iz Šafrana) | #B45309 | serija za poređenje (npr. „Iskorišteno"), 5,0 : 1 na Bijeloj |
| 3 | Škriljac | #475569 | treća serija, prethodna godina |
| 4 | Svijetlo nebo | #93C5FD | samo površine i rasponi iza drugih podataka (1,8 : 1 na Bijeloj – nikad kao jedini nosilac podatka) |
| Status | Žalfija · Paprika · Kamen | kao gore | samo za status (aktivno, blokirano, zamijenjeno/neaktivno) |

**Pravila:** najviše četiri serije po grafikonu; ose i mreža u Liniji #E4E4E7, oznake u Kamenu 12 px; iznosi u formatu „1.000 €" (u interfejsu prema postavci jezika restorana); legenda uvijek s tekstom; bez 3D grafikona, bez kružnih grafikona s više od četiri segmenta; važne vrijednosti označiti direktno.

> Napomena: pojedini tonovi u trenutnoj aplikaciji (npr. svjetlija zelena u krugu uspjeha aplikacije za konobare, ton serije „Redeemed") blago odstupaju od ove palete. Uskladit će se pri sljedećem ažuriranju dizajna; do tada za sve nove materijale važi ova specifikacija.

---

## 3. Ikone

**Stil:** Lucide (aplikacija koristi Lucide). Isključivo linijske ikone.

| Svojstvo | Vrijednost |
|---|---|
| Mreža | 24 × 24 px, 2 px unutrašnji razmak (aktivna površina 20 × 20 px) |
| Debljina linije | 1,5 px (standard u interfejsu i marketingu) · 2 px od 32 px veličine prikaza ili u aplikaciji za konobare |
| Krajevi i uglovi linija | zaobljeni (`stroke-linecap: round; stroke-linejoin: round`) |
| Radijus uglova u oblicima | 2 px (npr. simbol kartice `credit-card`) |
| Veličine | 16 px (tabele, bedževi) · 20 px (navigacija) · 24 px (standard) · 32–48 px (marketing) |
| Boja | `currentColor` – Grafit, Kamen ili Bijela; Šafran samo za jednu istaknutu ikonu po površini |

**Standardne ikone (Lucide nazivi):** `credit-card` (kartica), `nfc` odnosno `wifi` zarotiran za 90° (prislanjanje), `wallet` (otvoreni iznos), `euro` (promet), `arrow-down-right` (iskorišteno), `shuffle` (prijenos), `shield-check` (sigurnost), `scroll-text` (zapisnik aktivnosti), `smartphone` (uređaji), `users` (tim), `printer` (štampa), `qr-code` (QR).

**Ovako:**
- jedna ikona po značenju, uvijek ista;
- ikone uvijek s tekstualnom oznakom, osim kod opće poznatih radnji (zatvori, meni) – tada s `aria-label`;
- ikona i tekst optički centrirani, razmak 8 px.

**Ne ovako:**
- ispunjene ikone, dvobojne ikone, emojiji kao ikone;
- miješanje ikona iz različitih setova;
- ikone u obojenim krugovima kao ukras (izuzetak: lista aktivnosti na kontrolnoj tabli s krugovima u tonu od 10 %);
- skaliranje debljine linije (`vector-effect: non-scaling-stroke` odnosno odgovarajuća debljina po veličini).

---

## 4. Fotografija

### 4.1 Principi

- **Pravi austrijski ugostiteljski objekti** – bez stock fotografija, bez studija.
- **Prirodno svjetlo**, topli tonovi, mala dubinska oštrina.
- **Ruke i trenuci** umjesto poziranih lica: kartica se predaje, telefon se dodiruje, gazda stoji za šankom.
- **Bez stock osmijeha, bez namještenih „high-five" poza**, bez gledanja u kameru s podignutim palcem.
- **Raznolikost ugostiteljstva:** gostionica (Wirtshaus), bečka kafana (Kaffeehaus), vinska krčma (Heuriger), moderni bistro, bar, hotelski restoran – i ljudi koji tamo rade: mladi i stariji, različitog porijekla, žene i muškarci u usluzi i za šankom.
- **Kartica na slici:** uvijek s realnim dizajnom (logotip restorana, iznos) – nikad s natpisom „GiftCard Pro" na prednjoj strani.

### 4.2 Tehnika

| Tema | Pravilo |
|---|---|
| Svjetlo | dnevno svjetlo ili postojeće toplo svjetlo objekta; bez direktnog blica |
| Boja | toplo, prirodno, blago desaturisano; bez filter efekata |
| Dubinska oštrina | blenda f/1,8–f/2,8, fokus na ruci/kartici/ekranu |
| Kompozicija | mnogo mira, jedan motiv, prostor za tekst (pravilo trećina) |
| Formati | vodoravno 3 : 2 i 16 : 9, uspravno 4 : 5 i 9 : 16 |
| Rezolucija | najmanje 4000 px duža stranica, štampa 300 dpi |
| Prava | pisana saglasnost svih prepoznatljivih osoba i objekta; prava na fotografije pisano |
| Ekrani | pravi ekrani aplikacije s uvjerljivim primjerima podataka; bez stvarnih podataka korisnika |

### 4.3 Lista snimaka (20 motiva)

| # | Motiv | Mjesto | Upotreba |
|---|---|---|---|
| 1 | Konobarica prislanja poklon karticu na Android telefon, fokus na kartici | gostionica, drveni sto | glavna slika web stranice |
| 2 | Gost predaje karticu u koverti drugoj osobi | bečka kafana, mramorni sto | darivanje, advent |
| 3 | Ruka drži karticu iznad postavljenog stola, toplo večernje svjetlo | moderni bistro | mreže, OG slika |
| 4 | Gazda za šankom, telefon s ekranom uspjeha pored fiskalne kase | gostionica | sigurnost/jednostavnost |
| 5 | Snop kartica s dizajnom restorana pored kase, detalj | kafana | početni set |
| 6 | Konobar pokazuje gostu iznos na ekranu | Heuriger, bašta | povjerenje |
| 7 | Vlasnica za laptopom u kancelariji iza kuhinje, vidljiva kontrolna tabla | kancelarija restorana | kontrolna tabla |
| 8 | Krupni plan: gornja ivica iPhonea dodiruje karticu | neutralan sto | objašnjenje NFC-a |
| 9 | Kartica u poklon pakovanju s mašnom, grančica jele | kafana | Božić |
| 10 | Sto u vinskoj krčmi s čašom vina, kartica pored računa | Heuriger | sezonski, jesen |
| 11 | Konobar kuca iznos na tastaturi aplikacije, palac u fokusu | bistro | aplikacija za konobare |
| 12 | Gost provjerava stanje vlastitim telefonom, kartica u ruci | ulica ispred objekta | provjera stanja |
| 13 | Dogovor tima prije smjene, telefon ide iz ruke u ruku | kuhinja gostionice | postavljanje, obuka |
| 14 | Knjigovođa s CSV izvozom u Excelu, laptop, računi | kancelarija | izvoz, B2B |
| 15 | Kartice se vade iz kutije štamparije | skladište/objekat | narudžba kartica |
| 16 | Majčin dan: cvijeće i kartica na stolu za doručak | kafić | Majčin dan |
| 17 | Barmen prima karticu, šank u prvom planu zamućen | bar | barovi |
| 18 | Hotelska recepcija/ugostiteljska jedinica s više dizajna kartica | hotel | paket Gruppe |
| 19 | Osnivačica na licu mjesta pri postavljanju, objašnjava aplikaciju vlasnici | bečki restoran | O nama `[Foto nakon odobrenja]` |
| 20 | Detalj: zadnja strana kartice s QR kodom i brojem kartice, makro | sto, dnevno svjetlo | detalj proizvoda |

---

## 5. Ilustracija

- **Stil:** minimalni linijski crteži u Grafitu, linija 1,5–2 px (na mreži od 24 px) odnosno proporcionalno veća, zaobljeni krajevi – isti dojam kao ikone.
- **Jedan jedini akcent u Šafranu** po ilustraciji (npr. NFC lukovi, cjenovna etiketa, svijeća).
- **Bez** 3D mrlja, prelaza boja, izometrije, figura s prenaglašenim udovima i sjenki.
- **Motivi:** kartica, telefon, ruka, sto, tanjir, šoljica kafe, čaša vina, šank, kalendar (sezona), koverta.
- **Površine:** najviše jedna površina u Papiru #FAFAFA ili Liniji #E4E4E7 radi strukture.
- **Upotreba:** prazna stanja u aplikaciji, grafike s objašnjenjem (postupak „prislonite – iznos – gotovo"), uvodni koraci, karuseli na mrežama.
- **Ljudi:** stilizovani, bez detalja lica, raznoliki kroz odjeću i držanje, ne kroz stereotipe.

---

## 6. Predlošci poklon kartica

Poklon kartice nose brend **restorana**, ne GiftCard Pro. Ova pravila osiguravaju čitljivost, funkciju i kvalitet štampe.

### 6.1 Format i podaci za štampu

| Svojstvo | Vrijednost |
|---|---|
| Konačni format | ISO/IEC 7810 ID-1: 85,6 × 54 mm, radijus uglova 3,18 mm |
| Porez (bleed) | 2 mm sa svih strana → format podataka 89,6 × 58 mm |
| Sigurnosna zona | 3 mm unutar konačnog formata → površina za sadržaj 79,6 × 48 mm |
| Režim boja | CMYK, profil prema uputi štamparije (tipično PSO Coated v3 / FOGRA51) |
| Ukupno nanošenje boje | najviše 300 % |
| Površina u Tinti | kao duboka četverobojna crna prema probnom otisku (približno C 90 · M 78 · Y 45 · K 65) |
| Sitan tekst, broj kartice, QR | 100 % K odnosno jednobojno – nikad iz četiri boje |
| Slike | najmanje 300 dpi u konačnoj veličini |
| Fontovi | ugrađeni ili pretvoreni u krivulje |
| Format datoteke | PDF/X-4, jedna stranica po strani kartice, oznake za rezanje |
| Metal, folija, toplotni tisak | ne preko područja antene NFC čipa; uskladiti sa štamparijom |

### 6.2 Prednja strana

```
┌──────────────────────────────────────────┐
│ GUTSCHEIN / POKLON BON         ))) NFC   │  ← overline 5,5 pt · NFC simbol gore desno
│ [Logotip / naziv restorana]              │  ← zona logotipa: najviše 30 × 12 mm, gore lijevo
│                                          │
│                                          │
│ Za: [ime primaoca]                       │  ← opcionalno, 7–8 pt
│ 50,00 €                                  │  ← iznos 18–22 pt, dolje lijevo
└──────────────────────────────────────────┘
```

| Zona | Pravilo |
|---|---|
| Zona logotipa | gore lijevo, unutar sigurnosne zone, najviše 30 × 12 mm |
| Overline | „GUTSCHEIN", „POKLON BON" ili „POKLON KARTICA" na jeziku restorana, 5,5 pt, verzal, +12 % |
| Iznos | dolje lijevo, 18–22 pt Semibold/Bold, tabelarne cifre; format valute prema jeziku kartice (DE: „€ 50,00") |
| Primalac | opcionalno, iznad iznosa, 7–8 pt |
| NFC simbol | gore desno, tri luka, visina 6–8 mm; pokazuje gostima i konobarima gdje se prislanja |
| Pozadina | standardno Tinta #0F172A; alternativno boja brenda restorana, kontrast prema tekstu najmanje 4,5 : 1 |

### 6.3 Zadnja strana

```
┌──────────────────────────────────────────┐
│ ┌────────┐  7650 3531 2221 9919          │  ← broj kartice 8 pt, blokovi po četiri
│ │   QR   │  Bez roka važenja             │  ← važenje
│ │        │  Skenirajte kod ili prislonite│  ← uputstvo 6 pt
│ └────────┘  karticu na telefon da biste  │
│             provjerili stanje.           │
│ [adresa · telefon · web restorana]  Powered by GiftCard Pro │
└──────────────────────────────────────────┘
```

| Zona | Pravilo |
|---|---|
| QR kod | najmanje 18 × 18 mm, tiha zona najmanje 4 modula (kod 18 mm oko 2,5 mm), crno na bijelom, nije invertovan, nije obojen |
| Broj kartice | 16 cifara u blokovima po četiri, 8 pt Semibold, tabelarne cifre |
| Važenje | „Važi do 26. 9. 2029." ili „Bez roka važenja" – preporuka: bez roka važenja (vidi napomenu ispod) |
| Tekst uputstva | „Skenirajte kod ili prislonite karticu na telefon da biste provjerili stanje." na jeziku restorana |
| Kontakt | adresa, telefon, web stranica restorana, 6 pt |
| Linija pošiljaoca | „Powered by GiftCard Pro", 5,5 pt, Kamen, dolje desno – opcionalno, nikad veće od kontakt podataka |
| Pozadina | Bijela (sigurna čitljivost QR koda) |

> **Važenje – nije pravni savjet:** Za plaćene poklon bonove u Austriji je, prema praksi Vrhovnog suda (OGH), opće ograničenje na tri godine ili kraće u pravilu nevažeće. Preporuka: štampati „bez roka važenja", osim ako pravni savjetnik restorana ne odobri drugi model. Provjerite s poreznim savjetnikom ili advokatom.

Napomena: štampani tekstovi na kartici su trenutno na njemačkom ili engleskom (jezik restorana u postavkama).

### 6.4 Vlastita štampa (samo QR)

Raspored za štampu u aplikaciji (`../../screenshots/print-card.png`) pravi prednju i zadnju stranu u formatu kartice. Štampati u mjerilu 100 % (ne „prilagodi stranici"), na kartonu od najmanje 300 g/m², izrezati po ivicama. Ove kartice nemaju NFC čip; iskorištavaju se preko QR koda ili broja kartice.

### 6.5 Odobrenje prije štampe

1. Digitalni probni otisak (PDF) restoranu na odobrenje.
2. QR kod iz probnog otiska testirati s dva telefona (Android i iPhone).
3. Kod NFC kartica: upisati i prisloniti uzorak kartice prije štampe cijelog tiraža.
4. Arhivirati pisano odobrenje restorana poslano e-mailom.

---

Verzija 1.0 · Stanje: septembar 2026.
