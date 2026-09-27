# Model prihoda — GiftCard Pro

*Od čega GiftCard Pro zarađuje, šta namjerno ne naplaćujemo i kako se računaju pokazatelji po korisniku. Svi iznosi su neto, uvećani za 20 % PDV-a; pokazatelji su pretpostavke.*

---

## 1. Osnovni princip

GiftCard Pro zarađuje na **softveru koji restoran koristi** — ne na poklon bonovima koje restoran prodaje. Novac gostiju ide direktno u fiskalnu kasu restorana; mi ga nikad ne vidimo i ne uzimamo nikakav udio. Iz toga slijede tri pravila:

1. **Ponavljajući prihod od pretplata je glavni izvor.** Predvidiv je, raste s brojem restorana i pokriva fiksne troškove.
2. **Kartice prodajemo po principu cost-plus.** One su sredstvo, a ne izvor zarade.
3. **Bez provizije, nikad.** Ni na prodaju ni na iskorištavanje — ni kada od 2027. bude uvedena online prodaja.

## 2. Izvori prihoda

### 2.1 Pretplate (ponavljajuće)

| Paket | Mjesečno | Godišnje (2 mjeseca besplatno) | Ciljna grupa |
|---|---|---|---|
| **Start** | 29 € | 290 € | jedan restoran, kafić, bar |
| **Pro** | 59 € | 590 € | prometni objekti, veliki broj kartica, povećan rizik od prevare |
| **Gruppe** | od 129 € za do 3 lokacije, + 39 € za svaku dodatnu lokaciju | individualno | lanci, više lokacija, hoteli s više ugostiteljskih jedinica |

Usluge po paketu: vidi [Paketi i usluge](subscription-plans.md).

**Planirani omjer paketa (pretpostavka):** 70 % Start, 25 % Pro, 5 % Gruppe.

Izračunata ARPA bez popusta:

| Paket | Udio | Cijena | Ponderisano |
|---|---:|---:|---:|
| Start | 70 % | 29 € | 20,30 € |
| Pro | 25 % | 59 € | 14,75 € |
| Gruppe (prosječno 4 lokacije: 129 € + 39 €) | 5 % | 168 € | 8,40 € |
| **Ukupno** | | | **43,45 €** |

Nakon odbitka pilot popusta (10 objekata: 3 mjeseca besplatno, zatim 12 mjeseci 50 %) i godišnjih plaćanja s 2 besplatna mjeseca dobija se **planska ARPA od 42 €** za prvu godinu (pretpostavka). Pilot popusti ističu najkasnije početkom 2028.; plan ipak konzervativno računa s 42 € za sve godine.

### 2.2 Kartice (oprema, jednokratno i pri ponovnoj narudžbi)

| Proizvod | Okvirna cijena | po kartici |
|---|---:|---:|
| Početni paket od 100 NFC kartica (NTAG215, obostrano u punoj boji, u dizajnu restorana) | 249 € | ≈ 2,49 € |
| 250 NFC kartica (NTAG215) | 499 € | ≈ 2,00 € |
| Kartice NTAG 424 DNA (zaštita od kloniranja kriptografskim potpisom, paket Pro) | na upit | 4–6 € |
| QR kartice za samostalnu štampu pomoću šablona | besplatno | — |

*Okvirna cijena, zavisi od količine i štampe — obavezujuća ponuda na upit.*

**Logika cijene (cost-plus):** cijena kartice = nabavna cijena (prazna kartica + čip + štampa + personalizacija) + udio dostave i manipulacije + marža. Cilj je **bruto marža od oko 35 %**. Time pokrivamo rad na usklađivanju (probni otisak dizajna, narudžba, kontrola kvaliteta, dostava) i škart, a kartica ne postaje skuplja nego na slobodnom tržištu.

Primjer početnog paketa (pretpostavka):

| Pozicija | Iznos |
|---|---:|
| Prodajna cijena 100 kartica | 249,00 € |
| Nabavna vrijednost uključujući dostavu (65 %) | 161,85 € |
| **Bruto dobit (35 %)** | **87,15 €** |

U planu računamo s prosječnom prvom narudžbom od **150 kartica po prosječno 350 €** (između nivoa od 100 i 250 kartica) i bruto dobiti od **≈ 122,50 € po prvoj narudžbi**. Ponovljene narudžbe nisu uključene u plan; one su dodatni potencijal.

### 2.3 Postavljanje na licu mjesta i obuka (opcionalno, jednokratno)

- **149 €** jednokratno: postavljanje u objektu u Beču, zajedničko definisanje pravila za kartice, pozivanje tima, obuka konobara, upisivanje prvih kartica.
- Za pilot objekte besplatno; u paketu Pro uključeno je lično uvođenje (na daljinu ili na licu mjesta u Beču).
- Samostalno uvođenje uz video je uvijek besplatno.
- Planska pretpostavka: 20 % novih korisnika izvan pilota naručuje postavljanje.

### 2.4 Kasniji dodatni moduli (plan razvoja, cijene otvorene)

Moguća proširenja koja se naplaćuju, uvijek kao fiksni mjesečni iznos i nikad kao udio u prometu:

| Modul | Period | Model cijene (prijedlog, treba validirati) |
|---|---|---|
| Online prodaja poklon kartica preko web stranice restorana | Q1 2027. | uključeno u paket Pro ili kao fiksna doplata za Start — **0 % provizije**; naknade pružaoca platnih usluga restoran plaća direktno |
| Pregled više lokacija | 2027. | uključeno u paket Gruppe |
| Kartice u Apple/Google novčaniku | 2027. | doplata po lokaciji i mjesecu [iznos otvoren] |
| Gotova povezivanja s fiskalnim kasama | 2027. | uključeno u paket Pro; individualna povezivanja prema utrošku rada |

## 3. Šta namjerno ne naplaćujemo

| Ne naplaćujemo | Zašto |
|---|---|
| **Proviziju na prodaju ili iskorištavanje kartica** | Novac pripada restoranu. Provizije kažnjavaju upravo objekte koji prodaju mnogo bonova. Konkurenti s modelom provizije naplaćuju 3,9–4,9 % po prodaji. |
| Naknadu po kartici ili transakciji | Neograničen broj kartica i knjiženja (fer korištenje) — nema razloga za oklijevanje pri izdavanju. |
| Naknadu za postavljanje kod samostalnog uvođenja | Prepreka za probni period treba biti nula. |
| Dodatne osobe ili uređaje | Konobari se mijenjaju; svaka osoba treba imati vlastiti pristup kako bi zapisnik aktivnosti bio tačan. |
| Izvoz podataka | Podaci pripadaju restoranu — CSV izvoz u svakom trenutku, i nakon otkaza do isteka ugovora. |
| Kreditnu karticu za probni period | 30 dana sa svim Pro funkcijama, bez podataka za plaćanje. |
| Minimalno trajanje kod mjesečnih paketa | Otkaz na kraju mjeseca. Korisnike želimo zadržati zato što ih proizvod uvjerava. |

## 4. Pokazatelji po korisniku (unit economics)

*Sve vrijednosti su pretpostavke koje treba provjeriti u pilotu.*

### 4.1 Definicije i formule

| Pokazatelj | Formula |
|---|---|
| **ARPA** (Average Revenue per Account) | prihod od pretplata u mjesecu ÷ broj računa koji plaćaju |
| **Bruto marža pretplate** | (ARPA − varijabilni troškovi po računu) ÷ ARPA |
| **Odljev korisnika (churn)** | otkazani računi u mjesecu ÷ računi na početku mjeseca |
| **Trajanje korisničkog odnosa** | 1 ÷ mjesečni odljev |
| **LTV** (Customer Lifetime Value) | ARPA × bruto marža ÷ mjesečni odljev |
| **CAC** (Customer Acquisition Cost) | troškovi prodaje i marketinga ÷ novi računi |
| **Povrat ulaganja (payback)** | CAC ÷ (ARPA × bruto marža) |

### 4.2 Izračunate vrijednosti

| Pokazatelj | Pretpostavka / izračun | Rezultat |
|---|---|---|
| ARPA | omjer paketa i popusti, vidi 2.1 | **42 € / mjesečno** |
| Varijabilni troškovi po računu | naknade za plaćanje (≈ 2 % ≈ 0,84 €), udio hostinga i e-mailova, vrijeme podrške | **≈ 4 € / mjesečno** |
| Doprinos pokriću | 42 € − 4 € | **38 € / mjesečno** |
| Bruto marža pretplate | 38 € ÷ 42 € | **≈ 90 %** |
| Odljev korisnika | pretpostavka | **1,5 % / mjesečno** (≈ 83 % zadržavanja godišnje, 0,985¹²) |
| Trajanje korisničkog odnosa | 1 ÷ 0,015 | **≈ 67 mjeseci** |
| LTV (samo pretplata) | 38 € ÷ 0,015 | **≈ 2.533 €** |
| LTV uključujući prvu narudžbu kartica | 2.533 € + 122,50 € | **≈ 2.656 €** |
| CAC | cilj: prodaja koju vodi osnivačica, događaji, partneri | **< 300 €** |
| LTV : CAC | 2.533 € ÷ 300 € | **≈ 8 : 1** |
| Povrat ulaganja | 300 € ÷ 38 € | **≈ 7,9 mjeseci** (cilj < 8 mjeseci) |
| Povrat ulaganja uključujući bruto dobit od kartica | (300 € − 122,50 €) ÷ 38 € | **≈ 4,7 mjeseci** |

### 4.3 Procjena

- Omjer LTV : CAC od 3 : 1 smatra se održivim u SaaS modelima. Naša planska vrijednost od oko 8 : 1 ostavlja prostor za odstupanja — npr. veći odljev ili veće troškove pridobijanja pri ulasku na nova tržišta.
- **Osjetljivost na odljev:** uz 3 % umjesto 1,5 % LTV se prepolovi na ≈ 1.267 €; LTV : CAC bi tada bio ≈ 4 : 1.
- **Osjetljivost na CAC:** uz 500 € umjesto 300 € povrat ulaganja raste na ≈ 13 mjeseci; to bi bio signal za jačanje partnerskog kanala i ciljanije planiranje posjeta na terenu.
- **Mjesečni budžet za CAC:** uz marketinški budžet od 1.500 € i cilj < 300 € najmanje 5 novih korisnika mjesečno mora doći iz plaćenih aktivnosti; vrijeme osnivačice sadržano je u njenoj plati i bit će posebno iskazano u CAC-u čim se zaposli prodajno osoblje.

### 4.4 Primjer tipičnog restorana

Bečki restoran u paketu Start s godišnjim plaćanjem, početni paket od 100 kartica, samostalno uvođenje:

| Prva godina | Iznos |
|---|---:|
| Pretplata Start, godišnje | 290 € |
| Početni paket od 100 kartica | 249 € |
| **Prihod GiftCard Pro u prvoj godini** | **539 €** |
| od toga bruto dobit (pretplata ≈ 90 %, kartice ≈ 35 %) | ≈ 348 € |

Poređenja radi, na strani restorana: ako objekat u Adventu proda 100 poklon kartica po prosječno 50 €, to je 5.000 € prometa od poklon bonova. Model s provizijom od 4,9 % zadržao bi od toga 245 € — kod GiftCard Pro svih 5.000 € ostaje restoranu.

## 5. Struktura prihoda kroz plan

| Udio u prihodu | 2026. (okt.–dec.) | 2027. | 2028. |
|---|---:|---:|---:|
| Pretplate | 10 % | 42 % | 52 % |
| Kartice | 83 % | 53 % | 44 % |
| Postavljanje | 7 % | 5 % | 4 % |
| Ukupan prihod | 6.327 € | 164.250 € | 509.571 € |

S rastom broja korisnika prihod se pomjera prema pretplatama. Zato je upravljačka veličina **MRR** (Monthly Recurring Revenue — mjesečni ponavljajući prihod), a ne ukupan prihod: krajem 2026. ≈ 1.050 €, krajem 2027. ≈ 10.500 €, krajem 2028. ≈ 33.600 € (pretpostavka). Detalji u [poslovnom planu, poglavlje 9](business-plan.md#9-finansijski-plan).

## 6. Pravila za nove izvore prihoda

Svaki novi izvor prihoda mora na tri pitanja dobiti odgovor „da“:

1. Da li je cijena fiksan iznos poznat unaprijed — bez udjela u prometu restorana od poklon bonova?
2. Da li restoran dobija jasnu, mjerljivu korist (vrijeme, sigurnost, promet)?
3. Da li podaci ostaju vlasništvo restorana, bez preprodaje i bez oglašavanja?

---

Verzija 1.0 · Stanje: septembar 2026.
