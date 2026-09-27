# Finansijske pretpostavke GiftCard Pro 2026.–2028.

*Svrha: sve planske pretpostavke za prihode, troškove, razvoj broja korisnika, ekonomiku po korisniku, prag rentabilnosti i potrebu za kapitalom na jednom mjestu — s tri scenarija, analizom osjetljivosti i uputstvom za ažuriranje nakon pilota. Godišnje vrijednosti odgovaraju finansijskom planu u [Poslovnom planu](business-plan.md#9-finansijski-plan) i [Modelu prihoda](revenue-model.md).*

> **Svi brojevi u ovom dokumentu su pretpostavke**, osim ako nije drugačije navedeno. To su planske veličine, a ne prognoze, i provjeravaju se u pilotu (oktobar–novembar 2026.) i u prvim mjesecima nakon lansiranja. Iznosi u eurima, neto (bez PDV-a). Porez na dobit i poticaji nisu uzeti u obzir. Kalendarske godine; 2026. obuhvata samo oktobar do decembra. Moguće su razlike zbog zaokruživanja. Nije porezni savjet — provjerite s poreznim savjetnikom.

---

## 1. Pregled osnovnog scenarija

| Pokazatelj | 2026. (okt–dec) | 2027. | 2028. |
|---|---|---|---|
| Restorani koji plaćaju na kraju godine (uključujući pilot) | 25 | 250 | 800 |
| MRR (ponavljajući mjesečni prihod) na kraju godine | 1.050 € | 10.500 € | 33.600 € |
| Prihod (pretplate + kartice + postavljanje) | 6.327 € | 164.250 € | 509.571 € |
| Troškovi | 11.284 € | 150.061 € | 390.630 € |
| Rezultat prije poreza | −4.957 € | +14.189 € | +118.942 € |
| Kumulativni rezultat | −4.957 € | +9.232 € | +128.174 € |

Prag rentabilnosti kod **≈ 150–180 restorana koji plaćaju**, uključujući platu osnivačice (odjeljak 9). Potreba za finansiranjem prema poslovnom planu: **43.000 €** (odjeljak 12).

---

## 2. Cijene (odlučeno)

| Paket | Mjesečno | Godišnje | Sadržaj (ukratko) |
|---|---|---|---|
| Start | 29 € | 290 € | 1 lokacija, neograničeno kartica i transakcija (fer korištenje), članova tima i uređaja; podrška e-mailom |
| Pro | 59 € | 590 € | sve iz Start + NTAG 424 DNA, API, lični onboarding, telefon, prioritet |
| Gruppe | od 129 € za do 3 lokacije, + 39 € po dodatnoj lokaciji | individualno | sve iz Pro po lokaciji, centralna kontakt-osoba, ugovor/SLA |
| Postavljanje i obuka na licu mjesta | 149 € jednokratno | — | za pilot-objekte besplatno |
| Provizija | 0 % | — | trajno |

Godišnja pretplata = 2 mjeseca besplatno. Pilot-program (prvih 10 restorana): 3 mjeseca besplatno, zatim 12 mjeseci 50 % popusta (Start 14,50 € / Pro 29,50 €), besplatno postavljanje na licu mjesta, 50 besplatnih kartica. Sve cijene uvećane za 20 % PDV-a.

**Kartice (okvirne cijene, zavise od količine i štampe — obavezujuća ponuda na upit):** 100 NFC kartica (NTAG215) 249 € (≈ 2,49 €/kartica), 250 kartica 499 €, NTAG 424 DNA 4–6 € po kartici. QR kartice se mogu besplatno samostalno odštampati.

---

## 3. Omjer paketa i ARPA

| Paket | Cjenovnik / mjesečno | Udio (pretpostavka) | Doprinos |
|---|---|---|---|
| Start | 29 € | 70 % | 20,30 € |
| Pro | 59 € | 25 % | 14,75 € |
| Gruppe (ulaz) | 129 € | 5 % | 6,45 € |
| **Omjer prema cjenovniku** | | 100 % | **41,50 €** |

| Faktor uticaja | Smjer |
|---|---|
| Godišnje pretplate (2 mjeseca besplatno) | smanjuje |
| Pilot-popusti (3 mjeseca besplatno, 12 mjeseci 50 %) | smanjuje |
| Dodatne lokacije u paketu Gruppe (39 € po lokaciji) | povećava |
| Prelazak Start → Pro | povećava |

**Planska vrijednost ARPA: 42 € mjesečno** (pretpostavka), računato konstantno za sve godine, bez povećanja cijena. Pilot-popusti ističu najkasnije početkom 2028.; konstantna vrijednost je stoga oprezna. Izvođenje: [Model prihoda](revenue-model.md).

---

## 4. Razvoj broja korisnika

### 4.1 Po kvartalima (osnovni scenarij)

| Kvartal | Novi restorani (bruto) | Otkazi | Restorani koji plaćaju na kraju kvartala | MRR na kraju kvartala (× 42 €) |
|---|---|---|---|---|
| 2026. Q4 | 25 (od toga 10 pilot) | 0 | 25 | 1.050 € |
| 2027. Q1 | 27 | 2 | 50 | 2.100 € |
| 2027. Q2 | 44 | 4 | 90 | 3.780 € |
| 2027. Q3 | 57 | 7 | 140 | 5.880 € |
| 2027. Q4 | 122 | 12 | 250 | 10.500 € |
| 2028. Q1 | 95 | 15 | 330 | 13.860 € |
| 2028. Q2 | 120 | 20 | 430 | 18.060 € |
| 2028. Q3 | 155 | 25 | 560 | 23.520 € |
| 2028. Q4 | 275 | 35 | 800 | 33.600 € |
| **Ukupno 2027.** | **250** | **25** | | |
| **Ukupno 2028.** | **645** | **95** | | |

Raspodjela u Q4 2026. (pretpostavka): oktobar 8, novembar 15, decembar 25 restorana. Četvrti kvartal je uvijek najjači (božićna sezona).

**Po tržištu (pretpostavka):** kraj 2027. ≈ 230 Austrija, ≈ 20 Njemačka; kraj 2028. ≈ 580 Austrija, ≈ 200 Njemačka, ≈ 20 ostala tržišta (CH, HR, BA, RS).

### 4.2 Otkazi (churn)

| Veličina | Vrijednost |
|---|---|
| Mjesečna stopa otkaza | **1,5 %** (pretpostavka) |
| Odgovara zadržavanju korisnika godišnje | ≈ 83 % (0,985¹²) |
| Prosječno trajanje korisničkog odnosa | 1 ÷ 0,015 ≈ **67 mjeseci** |
| Način izračuna u godišnjem planu | otkazi ≈ 1,5 % × 12 × prosječan broj korisnika |

---

## 5. Kartice (hardver) i postavljanje

| Pretpostavka | Vrijednost |
|---|---|
| Prva narudžba po novom restoranu (izvan pilota) | 1 narudžba, u prosjeku 150 kartica |
| Prihod od prve narudžbe | u prosjeku 350 € (između paketa od 100 i 250 kartica) |
| Bruto marža na karticama | ≈ 35 % → ≈ 122,50 € po prvoj narudžbi; nabavna vrijednost ≈ 65 % |
| Ponovne narudžbe | **nisu uračunate** (dodatni potencijal) |
| Besplatne kartice za pilot | 10 × 50 kartica po ≈ 1,62 € → ≈ 810 € nabavne vrijednosti 2026. |
| Postavljanje na licu mjesta (149 €) | 20 % novih restorana izvan pilota |
| Tok novca za kartice | štampariji se plaća unaprijed ili pri isporuci, restoranu se fakturiše pri isporuci → kratkoročno predfinansiranje u oktobru/novembru |

Prihod od kartica je prolazna stavka s niskom maržom. Znatno povećava prihod (2027.: 87.500 €), ali bruto dobit samo umjereno. Upravljačka veličina je **MRR**, a ne ukupni prihod.

---

## 6. Struktura troškova

### 6.1 Mjesečne pretpostavke troškova

| Vrsta troška | 2026. | 2027. | 2028. | Napomena |
|---|---|---|---|---|
| Hosting i infrastruktura | 250 € | 300 € | 600 € | Hetzner, sigurnosne kopije, monitoring (raspon prve godine: 150–300 €) |
| Slanje e-mailova | 50 € | 50 € | 100 € | transakcijski e-mailovi (raspon prve godine: 20–50 €) |
| Softverski alati | 150 € | 150 € | 250 € | razvoj, podrška, knjigovodstvo |
| Osiguranje, pravni i porezni savjetnici | 400 € | 400 € | 600 € | obim osiguranja razjasniti |
| Marketing i prodaja (uključujući sajmove, putovanja) | 1.500 € | 2.000 € | 4.000 € | raspon prve godine: 1.000–2.000 € |
| Naknade za plaćanje | 2 % prihoda od pretplata | 2 % | 2 % | automatizovana naplata od Q4 2026. |
| Plata osnivačice | 0 € | 4.000 € | 4.000 € | uključujući socijalno osiguranje |
| Osoblje / vanjska saradnja | — | 1.500 € od jula (vanjska saradnja podrška/prodaja) | 2,5 ekvivalenta punog radnog vremena po 3.800 € troška poslodavca | vidi 6.3 |
| Ulazak na tržišta CH/HR/BA/RS (jednokratno) | — | — | ukupno 10.000 € | pravni savjeti, prevod |

### 6.2 Troškovi po godinama

| Stavka | 2026. (okt–dec) | 2027. | 2028. |
|---|---:|---:|---:|
| Nabavna vrijednost kartica (uključujući besplatne pilot-kartice) | 4.222 | 56.875 | 146.738 |
| Naknade za plaćanje | 13 | 1.386 | 5.292 |
| Hosting i infrastruktura | 750 | 3.600 | 7.200 |
| Slanje e-mailova | 150 | 600 | 1.200 |
| Softverski alati | 450 | 1.800 | 3.000 |
| Osiguranje, pravni i porezni savjetnici | 1.200 | 4.800 | 7.200 |
| Marketing i prodaja | 4.500 | 24.000 | 48.000 |
| Plata osnivačice | 0 | 48.000 | 48.000 |
| Osoblje / vanjska saradnja | 0 | 9.000 | 114.000 |
| Ulazak na tržišta CH/HR/BA/RS | 0 | 0 | 10.000 |
| **Ukupni troškovi** | **11.284** | **150.061** | **390.630** |

### 6.3 Plan osoblja (pretpostavka)

| Vrijeme | Uloga | Troškovi |
|---|---|---|
| do juna 2027. | osnivačica sama (prodaja, onboarding, podrška, razvoj) | plata od januara 2027. |
| od jula 2027. | vanjska saradnja **Customer Success / podrška** i podrška prodaji | 1.500 € / mjesečno |
| 2028. | 2,5 ekvivalenta punog radnog vremena: **podrška i onboarding (Customer Success)**, **prodaja Austrija**, **prodaja Njemačka** | 2,5 × 3.800 € × 12 = 114.000 € |

Zapošljavanja su vezana za okidače (odjeljak 12).

---

## 7. Prihod i rezultat

| Stavka | 2026. (okt–dec) | 2027. | 2028. |
|---|---:|---:|---:|
| Prosječan broj korisnika | — (15 računa izvan pilota koji plaćaju, 1 mjesec) | 137,5 | 525 |
| **Prihod od pretplata** | 630 | 69.300 | 264.600 |
| **Prihod od kartica** | 5.250 | 87.500 | 225.750 |
| **Prihod od postavljanja** | 447 | 7.450 | 19.221 |
| **Ukupan prihod** | **6.327** | **164.250** | **509.571** |
| Ukupni troškovi | 11.284 | 150.061 | 390.630 |
| **Rezultat prije poreza** | **−4.957** | **+14.189** | **+118.942** |

Način izračuna: pretplate = prosječan broj korisnika (prosjek početka i kraja godine) × 42 € × 12; kartice = novi restorani izvan pilota × 350 €; postavljanje = novi restorani izvan pilota × 20 % × 149 €.

| Udio u prihodu | 2026. | 2027. | 2028. |
|---|---:|---:|---:|
| Pretplate | 10 % | 42 % | 52 % |
| Kartice | 83 % | 53 % | 44 % |
| Postavljanje | 7 % | 5 % | 4 % |

**Napomena za provjeru načina izračuna:** prosjek broja korisnika na početku i kraju godine precjenjuje prihod od pretplata kada je rast koncentrisan u četvrtom kvartalu. Mjesečni izračun s kvartalnim tokom iz odjeljka 4.1 daje za 2027. **≈ 58.600 € prihoda od pretplata umjesto 69.300 €** i rezultat od **≈ +3.700 € umjesto +14.189 €** (2028.: ≈ +105.700 € umjesto +118.942 €). Smjer ostaje isti; pri ažuriranju nakon pilota prelazi se na mjesečni izračun (odjeljak 13).

---

## 8. Ekonomika po korisniku: CAC, LTV, povrat

| Pokazatelj | Formula | Vrijednost (pretpostavka) |
|---|---|---|
| Varijabilni troškovi po računu | naknade za plaćanje (≈ 2 % ≈ 0,84 €), udio hostinga i e-maila, vrijeme podrške | ≈ 4 € / mjesečno |
| Doprinos pokrića pretplate | ARPA − varijabilni troškovi = 42 € − 4 € | **38 € / mjesečno** |
| Bruto marža pretplate | 38 € ÷ 42 € | **≈ 90 %** |
| LTV (samo pretplata) | doprinos ÷ churn = 38 € ÷ 0,015 | **≈ 2.533 €** |
| LTV uključujući prvu narudžbu kartica | 2.533 € + 122,50 € | **≈ 2.656 €** |
| Cilj CAC | troškovi prodaje i marketinga ÷ novi restorani | **< 300 €** |
| LTV : CAC | 2.533 € ÷ 300 € | **≈ 8 : 1** |
| Povrat (samo pretplata) | CAC ÷ doprinos = 300 € ÷ 38 € | **≈ 7,9 mjeseci** (cilj < 8) |
| Povrat uključujući bruto dobit od kartica | (300 € − 122,50 €) ÷ 38 € | **≈ 4,7 mjeseci** |

**CAC u planu:** marketing i prodaja 2027. 24.000 € ÷ 250 novih restorana = **≈ 96 €** (bez vremena osnivačice). Ako se polovina plate osnivačice doda kao vrijeme za prodaju (24.000 €), dobija se potpuno opterećen CAC od **≈ 192 €**. 2028.: (48.000 € + 2 ekvivalenta za prodaju 91.200 €) ÷ 645 ≈ **216 €**. Sve vrijednosti su ispod cilja od 300 €.

---

## 9. Izračun praga rentabilnosti

**Formula:**

```
Prag rentabilnosti (broj restorana koji plaćaju) = mjesečni fiksni troškovi ÷ doprinos pokrića po restoranu i mjesecu

Doprinos pokrića po restoranu = ARPA − varijabilni troškovi po računu = 42 € − 4 € = 38 €
```

**Mjesečni fiksni troškovi uključujući platu osnivačice (4.000 €), rasponi troškova iz glavnog briefinga:**

| Scenarij | Hosting | E-mail | Alati | Osig./pravni/porezni | Marketing | Plata osnivačice | **Ukupno** | **Prag (÷ 38 €)** |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| nizak | 150 | 20 | 150 | 400 | 1.000 | 4.000 | **5.720** | **≈ 151** |
| srednji | 250 | 50 | 150 | 400 | 1.500 | 4.000 | **6.350** | **≈ 167** |
| visok | 300 | 50 | 150 | 400 | 2.000 | 4.000 | **6.900** | **≈ 182** |

**Dodatne varijante:**

| Varijanta | Račun | Prag |
|---|---|---|
| srednji, uključujući bruto dobit od kartica raspoređenu na trajanje odnosa (122,50 € ÷ 67 ≈ 1,83 € / mjesečno) | 6.350 € ÷ 39,83 € | ≈ 159 |
| bez plate osnivačice (srednji) | 2.350 € ÷ 38 € | ≈ 62 |
| osnova troškova 2027. od jula (visok + vanjska saradnja 1.500 €) | 8.400 € ÷ 38 € | ≈ 221 |
| osnova troškova 2028. (uključujući 2,5 ekvivalenta, ulazak na tržišta proporcionalno) | 19.883 € ÷ 38 € | ≈ 523 |

**Zaključak:** s platom osnivačice prag rentabilnosti je kod **≈ 150–180 restorana koji plaćaju**. U toku plana prag se u tekućem mjesecu dostiže oko sredine 2027. (mjesečni izračun: prvi put septembar 2027. kod ≈ 140 restorana), jer prve narudžbe kartica novih restorana donose dodatnu bruto dobit. Svako zapošljavanje znatno podiže prag — zato okidači u odjeljku 12.

---

## 10. Tri scenarija

Isti troškovi u svim scenarijima (uključujući plan osoblja). Način izračuna kao u odjeljku 7.

| Pretpostavka / rezultat | Konzervativni | **Osnovni** | Optimistični |
|---|---|---|---|
| Novi restorani (bruto) | 60 % osnovnog | 25 / 250 / 645 | 140 % osnovnog |
| Mjesečni churn | 2,5 % | 1,5 % | 1,0 % |
| ARPA | 38 € | 42 € | 46 € |
| Restorani na kraju 2026. / 2027. / 2028. | 19 / 144 / 443 | 25 / 250 / 800 | 31 / 358 / 1.169 |
| MRR na kraju 2028. | 16.846 € | 33.600 € | 53.777 € |
| Prihod 2027. | 94.243 € | 164.250 € | 240.205 € |
| Prihod 2028. | 280.998 € | 509.571 € | 764.343 € |
| Rezultat 2026. | −6.154 € | −4.957 € | −3.715 € |
| Rezultat 2027. | −32.427 € | +14.189 € | +66.635 € |
| Rezultat 2028. | −48.324 € | +118.942 € | +311.883 € |
| Kumulativni rezultat na kraju 2028. | −86.906 € | +128.174 € | +374.803 € |

**Konzervativni scenarij bez zapošljavanja** (bez vanjske saradnje 2027., bez osoblja i ulaska na tržišta 2028.): rezultat 2027. ≈ −23.400 €, 2028. ≈ +75.700 €, kumulativno na kraju 2028. ≈ +46.100 €. Zapošljavanja su dakle najveća poluga za ublažavanje sporijeg rasta.

---

## 11. Analiza osjetljivosti (osnovni scenarij)

| Promjena | Restorani na kraju 2028. | MRR na kraju 2028. | Rezultat 2027. | Rezultat 2028. | LTV (pretplata) | Povrat | Prag (srednji) |
|---|---|---|---|---|---|---|---|
| Osnovni | 800 | 33.600 € | +14.189 € | +118.942 € | 2.533 € | 7,9 mjeseci | ≈ 167 |
| **Cijena −20 %** (ARPA 33,60 €, doprinos 29,60 €) | 800 | 26.902 € | +652 € | +67.254 € | 1.973 € | 10,1 mjesec | ≈ 215 |
| **Churn ×2** (3,0 % mjesečno) | 706 | 29.648 € | +9.061 € | +90.578 € | 1.267 € | 7,9 mjeseci | ≈ 167 |

**Tumačenje:**

- **Sniženje cijene za 20 %** gotovo prepolovljuje rezultat 2028., produžava povrat iznad cilja od 8 mjeseci i podiže prag rentabilnosti za ≈ 50 restorana. Popusti stoga ostaju ograničeni na pravila iz [Strategije cijena](pricing-strategy.md) (najviše 20 %, vremenski ograničeno).
- **Udvostručenje churna** do kraja 2028. košta ≈ 95 restorana i prepolovljuje LTV (LTV : CAC ≈ 4 : 1). Nakon 2028. uticaj je jači, jer svaki izgubljeni korisnik znači izgubljene naredne godine. Zadržavanje korisnika je najmanje jednako važno kao pridobijanje novih.

---

## 12. Potreba za kapitalom

### 12.1 Potreba prema poslovnom planu (pretpostavka)

| Namjena | Iznos |
|---|---:|
| Početni gubitak Q4 2026. | 5.000 |
| Početni gubici 1. polugodište 2027. | 9.000 |
| Predfinansiranje kartica (prazne kartice, štampa prije Adventa) | 5.000 |
| Pravni tekstovi, provjera žiga, osiguranje (jednokratno) | 4.000 |
| Rezerva likvidnosti (≈ 3 mjeseca fiksnih troškova) | 20.000 |
| **Ukupno** | **43.000** |

### 12.2 Kontrolni mjesečni izračun

| Scenarij | Najniže stanje tekućih rezultata (bez jednokratnih troškova i rezerve) | Vrijeme |
|---|---|---|
| Osnovni | ≈ −22.000 € | avgust 2027. |
| Konzervativni (s planom osoblja) | ≈ −112.000 € | septembar 2028. |

U mjesečnom izračunu početni gubici iznose ≈ 22.000 € umjesto 14.000 €, jer prihod od pretplata 2027. sporije raste (vidi napomenu u odjeljku 7). S predfinansiranjem kartica, jednokratnim troškovima i rezervom okvir bi iznosio **≈ 51.000 €**. **Preporuka:** zadržati 43.000 € kao plansku vrijednost, ali predvidjeti dodatni okvirni kredit ili vlastita sredstva od ≈ 10.000 € i nakon pilota ponovo izračunati. Konzervativni scenarij je održiv samo uz odgođena zapošljavanja.

Opcije finansiranja (bootstrapping, poticaji aws, FFG i Wirtschaftsagentur Wien — podobnost provjeriti u svakom slučaju —, bankovni kredit, kasnije poslovni anđeli): vidi [Poslovni plan, poglavlje 11](business-plan.md).

### 12.3 Okidači za zapošljavanje (prijedlog)

| Korak | Okidač |
|---|---|
| Vanjska saradnja Customer Success / podrška (jul 2027.) | ≥ 100 restorana koji plaćaju **i** MRR ≥ 4.000 € **i** churn ≤ 2 % |
| 2,5 ekvivalenta uključujući prodaju u Njemačkoj (2028.) | ≥ 250 restorana koji plaćaju, ispunjeni kriteriji ulaska za DE (vidi [Strategija rasta](growth-strategy.md)), povrat ≤ 8 mjeseci, stanje novca ≥ 6 mjeseci troškova osoblja |

Ako okidači nisu ispunjeni, zapošljavanje se pomjera za po jedan kvartal.

---

## 13. Ažuriranje nakon pilota

Nakon završetka pilota (kraj decembra 2026.), a zatim **mjesečno**, pretpostavke se zamjenjuju stvarnim vrijednostima. Od januara 2027. plan se vodi kao **mjesečni izračun** (jedan red po mjesecu):

```
Restorani(t)          = Restorani(t−1) × (1 − churn) + Novi restorani(t)
Prihod pretplata(t)   = restorani koji plaćaju(t) × ARPA   (pilot-računi sa stvarnim popustom)
Prihod kartica(t)     = Novi restorani izvan pilota(t) × udio s narudžbom kartica × prosječna vrijednost narudžbe
                        + ponovne narudžbe(t)
Postavljanje(t)       = Novi restorani izvan pilota(t) × stopa rezervacija × 149 €
Troškovi(t)           = Prihod kartica(t) × (1 − marža kartica) + Prihod pretplata(t) × 2 % + fiksni troškovi(t) + osoblje(t)
Rezultat(t)           = Prihodi(t) − Troškovi(t);   Stanje novca(t) = Stanje novca(t−1) + Rezultat(t) ± predfinansiranje kartica
```

| Pretpostavka | Zamijeniti sa | Izvor podataka | Od kada |
|---|---|---|---|
| ARPA 42 € | prihod od pretplata ÷ računi koji plaćaju | naplata | januar 2027. |
| Omjer paketa 70/25/5 | raspodjela odabranih paketa, udio godišnjeg plaćanja | naplata | januar 2027. |
| Churn 1,5 % | otkazi ÷ računi na početku mjeseca (prosjek 3 mjeseca) | naplata | od marta 2027. |
| Svaki novi korisnik naručuje 150 kartica za 350 € | stvarni udio i vrijednost narudžbe | narudžbe kartica | decembar 2026. |
| Bez ponovnih narudžbi | stvarne ponovne narudžbe | narudžbe kartica | od Q4 2027. |
| Marža na karticama 35 % | nabavna cijena prema ponudi štamparije | računi dobavljača | oktobar 2026. |
| 20 % postavljanja na licu mjesta | udio rezervisanih postavljanja | računi | januar 2027. |
| Varijabilni troškovi 4 € | naknade za plaćanje, dodatni troškovi hostinga i e-maila, vrijeme podrške ÷ računi | računi troškova, evidencija vremena | kvartalno |
| CAC < 300 € | marketing + proporcionalno vrijeme prodaje ÷ novi korisnici | knjigovodstvo, CRM | kvartalno |
| Novi korisnici mjesečno | zaključeni poslovi; stopa prelaska s testa na pretplatu | administracija platforme, CRM | mjesečno |
| Prelazak pilot-objekata | udio pilot-objekata koji plaćaju nakon 3 besplatna mjeseca | naplata | februar 2027. |

**Pravila:**

1. Svaku promjenu upisati s datumom i razlogom u protokol promjena; istovremeno uskladiti poslovni plan i model prihoda.
2. Ako je neki pokazatelj tri mjeseca zaredom više od 20 % ispod pretpostavke, dalje se planira s konzervativnim scenarijem i plan osoblja se provjerava.
3. Pokazatelji iz manje od 20 računa smatraju se naznakom, a ne dokazom.

**Protokol promjena**

| Datum | Promjena | Razlog |
|---|---|---|
| septembar 2026. | prva verzija | — |

---

Verzija 1.0 · Stanje: septembar 2026.
