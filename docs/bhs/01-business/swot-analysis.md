# SWOT analiza GiftCard Pro

*Svrha: snage, slabosti, prilike i prijetnje za GiftCard Pro na početku lansiranja na tržište (novembar 2026.) i iz njih izvedene strategije (TOWS) s konkretnim mjerama, odgovornim osobama i rokovima.*

> Osnova su stanje proizvoda 1.2.0 (pilot-izdanje), [Analiza tržišta](market-analysis.md) i [Analiza konkurencije](competitor-analysis.md). Brojevi bez izvora su pretpostavke. Odgovorna je trenutno gotovo isključivo osnivačica; od jula 2027. Customer Success i prodaju podržava vanjski saradnik ili saradnica, a 2028. slijedi tim od 2,5 ekvivalenta punog radnog vremena (vidi [Finansijske pretpostavke](financial-assumptions.md)).

---

## 1. Pregled

| **Snage (interno)** | **Slabosti (interno)** |
|---|---|
| S1 Iskorištavanje za stolom za nekoliko sekundi | W1 Nema online shopa, nema obrade plaćanja |
| S2 Fizička premium NFC kartica | W2 Sučelje za osoblje na engleskom |
| S3 Sigurnost i nepromjenjiv dnevnik | W3 Nema integracije s kasom (samo API) |
| S4 0 % provizije, transparentne cijene | W4 Nema referenci, nema korisnika |
| S5 Nezavisno od kase | W5 Mali tim, zavisnost od osnivačice |
| S6 Pregled otvorene obaveze | W6 Nema Wallet passova, nema izvorne aplikacije |
| S7 Provjeren kvalitet proizvoda (testovi, pristupačnost) | W7 Samo EUR |
| S8 Trojezična osnivačica s iskustvom u ugostiteljstvu | W8 Nema objedinjene kontrolne table za više lokacija |
| S9 Bez instalacije, svaki pametni telefon | W9 Logistika hardvera (štampa kartica, predfinansiranje) |
| **Prilike (eksterno)** | **Prijetnje (eksterno)** |
| O1 Božićna sezona 2026. odmah nakon lansiranja | T1 Proizvođači kasa proširuju funkcije poklon bonova |
| O2 Papirni poklon bonovi su najčešći „konkurent" | T2 Online shopovi dodaju fizičke kartice |
| O3 Zamor od provizija | T3 Ekonomski pritisak u ugostiteljstvu |
| O4 Nedostatak osoblja | T4 Izražena sezonalnost |
| O5 Porezni savjetnici kao multiplikatori | T5 Pravni rizik kod ograničenja validnosti |
| O6 Prodavci kasa i štamparije kao partneri | T6 Etablirani austrijski ponuđači s referencama |
| O7 Ugostiteljstvo dijaspore u Beču | T7 Tehničke zavisnosti (Web NFC, ponašanje iPhonea) |
| O8 Njemačka: 150.218 ugostiteljskih preduzeća | T8 Cjenovni pritisak i besplatni paketi |
| O9 Pravila o vaučerima za više namjena stvaraju potrebu za dokumentacijom | T9 Ispad ili sigurnosni incident |

---

## 2. Snage

**S1 — Iskorištavanje za stolom za nekoliko sekundi.** Prisloniti karticu, unijeti iznos, iskoristiti: pretraga kartice traje ≈ 0,1 s, cijeli postupak iskorištavanja uključujući unos broja kartice ≈ 0,5 s sistemskog vremena i vremena sučelja. Cilj za stolom uključujući čovjeka: manje od 5 sekundi. To je u gužvi najvažnija korist.

**S2 — Fizička premium NFC kartica.** Format bankovne kartice (85,6 × 54 mm), u punoj boji, s dizajnom restorana i imenom obdarene osobe. Poklon koji izgleda vrijedno — jasna razlika u odnosu na PDF poklon bonove.

**S3 — Sigurnost i nepromjenjiv dnevnik.** Na kartici nema novca, samo nasumičan link (UUID od 122 bita). Svako knjiženje je atomarno, idempotentno i u nepromjenjivom dnevniku (zbir knjiženja = stanje). Zaštita od kloniranja vezivanjem UID-a čipa ili NTAG 424 DNA s kriptografskim potpisom. Testirano s 20 istovremenih iskorištavanja na jednoj kartici.

**S4 — 0 % provizije, transparentne cijene.** Start 29 €, Pro 59 €, Gruppe od 129 € mjesečno (neto). Bez provizije na prodaju ili iskorištavanje, trajno. To je lako razumljivo i isplati se kod visokih vrijednosti poklon bonova.

**S5 — Nezavisno od kase.** Radi pored svake fiskalne kase. Nije potrebna promjena kase ni projekat s prodavcem kase.

**S6 — Pregled otvorene obaveze.** KPI „Outstanding balance" pokazuje koliko je novca u otvorenim poklon bonovima. To odgovara na pitanje koje vlasnici i porezni savjetnici redovno postavljaju.

**S7 — Provjeren kvalitet proizvoda.** 113 automatizovanih backend testova, test prihvatanja u pregledniku za cijeli prvi dan restorana, provjera WCAG 2.1 AA bez nalaza, hosting u EU. Dobra osnova za povjerenje bez tvrdnji o certifikatima.

**S8 — Osnivačica s odgovarajućim profilom.** Web razvoj, dizajn za restorane, automatizacija, osiguranje kvaliteta; njemački, BHS i engleski. To otvara bečko ugostiteljstvo s korijenima u bivšoj Jugoslaviji i kasnije tržišta HR, BA, RS.

**S9 — Bez instalacije.** Web aplikacija na svakom pametnom telefonu, može se instalirati na početni ekran. Neograničen broj članova tima i uređaja u svakom paketu — nema troškova po konobaru ili konobarici.

## 3. Slabosti

**W1 — Nema online shopa, nema obrade plaćanja.** Poklon bonovi se trenutno mogu prodavati samo u restoranu. Dio tržišta očekuje online prodaju. Plan: Q1 2027.

**W2 — Sučelje za osoblje na engleskom.** Stranica za goste, kartica i e-mailovi su na njemačkom, ali sučelje za konobare i vlasnike još nije. Za mnoge objekte to je prigovor. Plan: Q4 2026., visok prioritet.

**W3 — Nema integracije s kasom.** Prodaja i iskorištavanje moraju se dodatno knjižiti u fiskalnoj kasi (dvostruki unos). API postoji (paket Pro), gotove integracije ne.

**W4 — Nema referenci.** Još nema korisnika ni studija slučaja. Kupci u ugostiteljstvu snažno se oslanjaju na preporuke.

**W5 — Mali tim.** Prodaja, podrška, razvoj i logistika kartica zavise od jedne osobe. Usko grlo prije Božića, rizik u slučaju bolesti.

**W6 — Nema Wallet passova, nema izvorne aplikacije.** Gosti ne mogu sačuvati karticu u Apple ili Google Wallet; neki objekti očekuju aplikaciju iz App Storea.

**W7 — Samo EUR.** Nedostaju CHF, BAM i RSD; to blokira Švicarsku, Bosnu i Hercegovinu i Srbiju.

**W8 — Nema kontrolne table za više lokacija.** Svaka lokacija je poseban račun. Nedostatak za grupe i hotele. Plan: 2027.

**W9 — Logistika hardvera.** Kartice treba odštampati, programirati i isporučiti. To veže kapital (predfinansiranje kartica) i vrijeme, posebno u novembru.

## 4. Prilike

**O1 — Božićna sezona 2026.** Lansiranje u novembru pogađa najjaču sezonu poklon bonova. Objekti imaju konkretan povod da odluče sada.

**O2 — Papir je najčešći „konkurent".** Mnogi objekti još nemaju nikakav sistem. Prelazak s papira je lakši od prelaska s drugog ponuđača.

**O3 — Zamor od provizija.** Ugostiteljstvo već plaća provizije platformama za dostavu i rezervacije. Sistem s 0 % provizije pogađa bolnu tačku (pretpostavka, potvrditi u pilotu).

**O4 — Nedostatak osoblja.** Svako rješenje koje radi bez obuke štedi vrijeme i greške — argument koji razumije svaki menadžer.

**O5 — Porezni savjetnici kao multiplikatori.** Porezni savjetnici vode mnoge ugostiteljske objekte i žele uredne evidencije poklon bonova. Preporuka od njih ima veliku težinu.

**O6 — Partneri u okruženju.** Prodavci kasa i štamparije već su u kontaktu s objektima i traže dodatne ponude.

**O7 — Ugostiteljstvo dijaspore u Beču.** Brojni objekti s vlasnicima iz bivše Jugoslavije; savjetovanje na BHS stvara povjerenje i preporuke (veličinu prikupiti).

**O8 — Njemačka.** 150.218 ugostiteljskih preduzeća ([DEHOGA-Zahlenspiegel 4. kvartal 2025.](https://www.dehoga-bundesverband.de)), isti jezik i valuta. Realni prihod je još 14,8 % ispod 2019. — poklon bonovi kao plaćanje unaprijed su tamo privlačni.

**O9 — Potreba za dokumentacijom zbog pravila o PDV-u.** Od 2019. razlikovanje vaučera za jednu i za više namjena je obavezujuće; objekti trebaju provjerljive podatke o prodaji i iskorištavanju.

## 5. Prijetnje

**T1 — Proizvođači kasa proširuju funkcije poklon bonova.** Ako kasa dovoljno dobro radi s poklon bonovima, pada potreba za posebnim sistemom.

**T2 — Online shopovi dodaju fizičke kartice.** Veći ponuđači mogli bi naknadno uvesti NFC kartice i aplikacije za iskorištavanje.

**T3 — Ekonomski pritisak.** Rast troškova i zatvaranja smanjuju budžete i povećavaju stopu otkaza.

**T4 — Sezonalnost.** Velik dio zaključenih poslova i narudžbi kartica pada u Q4. Ako se propusti taj prozor, rast se pomjera za godinu dana.

**T5 — Pravni rizik kod ograničenja validnosti.** Objekti koji nedopušteno kratko ograniče poklon bonove rizikuju sukobe s gostima. Loš glas mogao bi se prenijeti na sistem.

**T6 — Etablirani ponuđači s referencama.** incert navodi Figlmüller i Plachuttu kao reference; novi ponuđači moraju tek izgraditi povjerenje.

**T7 — Tehničke zavisnosti.** Web NFC radi samo u Chromeu na Androidu; iPhone čita kartice preko sistemske obavijesti. Promjene od strane Applea ili Googlea mogu uticati na procese.

**T8 — Cjenovni pritisak.** Besplatni paketi (npr. gurado) i modeli zasnovani na naknadama bez mjesečne cijene (Gutschein Direkt) postavljaju nisku referentnu cijenu.

**T9 — Ispad ili sigurnosni incident.** Ispad u subotu uveče ili incident s podacima bio bi za mlad proizvod teško podnošljiv.

---

## 6. TOWS strategije

### 6.1 SO — koristiti snage da se iskoriste prilike

| Br. | Strategija | Konkretne mjere | Odgovorna | Rok |
|---|---|---|---|---|
| SO1 | **Božićna ofanziva s premium karticom** (S2, S1 × O1) | 40 ličnih posjeta u Beču; u razgovoru dati da prislone demo karticu; omogućiti narudžbu kartica do 10. 11. | [Ime], osnivačica | oktobar–novembar 2026. |
| SO2 | **Kampanja „Papir van"** (S3, S6 × O2) | primjer računa „Koliko je u Vašim otvorenim poklon bonovima?"; pomoć pri prelasku: postojeće papirne bonove evidentirati kao kartice s ostatkom iznosa | osnivačica | od novembra 2026. |
| SO3 | **Poređenje provizija kao ključna poruka** (S4 × O3) | kalkulator provizija na web stranici; battlecard „Online shop s provizijom" | osnivačica | decembar 2026. |
| SO4 | **Paket za porezne savjetnike** (S6, S3 × O5, O9) | informativni list od 2 stranice, primjer izvoza, 3 predavanja u poreznim kancelarijama | osnivačica | Q1 2027. |
| SO5 | **BHS mreža u Beču** (S8 × O7) | obraćanje 30 objekata s vlasnicima koji govore BHS; materijali na BHS | osnivačica | novembar 2026.–februar 2027. |

### 6.2 ST — koristiti snage da se odbiju prijetnje

| Br. | Strategija | Konkretne mjere | Odgovorna | Rok |
|---|---|---|---|---|
| ST1 | **Prodavci kasa kao partneri umjesto protivnika** (S5 × T1) | obratiti se 5 prodavaca kasa u Beču; API dokumentacija za integracije; provjeriti proviziju za preporuke | osnivačica | Q1–Q2 2027. |
| ST2 | **Dokumentovati prednost u brzini i sigurnosti** (S1, S3 × T2) | mjerenje vremena iskorištavanja u pilotu; video „od prislanjanja kartice do ostatka stanja" | osnivačica | novembar 2026. |
| ST3 | **Pravno sigurne podrazumijevane postavke** (S3 × T5) | kontrolna lista za postavljanje: „Default validity" na 0; promijeniti podrazumijevanu postavku platforme | osnivačica (proizvod) | Q4 2026. / Q1 2027. |
| ST4 | **Vrijednost umjesto popusta** (S4, S6 × T8) | bez besplatnog paketa; umjesto toga 30 dana testa sa svim Pro funkcijama i računica uštede vremena | osnivačica | stalno |
| ST5 | **Povjerenje kroz otvorenost** (S7 × T6, T9) | javna stranica o sigurnosti, stranica statusa, transparentno prikazati cilj dostupnosti od 99,5 % | osnivačica | Q1 2027. |

### 6.3 WO — smanjiti slabosti da se iskoriste prilike

| Br. | Strategija | Konkretne mjere | Odgovorna | Rok |
|---|---|---|---|---|
| WO1 | **Njemačko sučelje prije glavne sezone** (W2 × O1, O8) | prevod svih tekstova sučelja, test s pilot-objektima | osnivačica (razvoj) | Q4 2026. |
| WO2 | **Reference iz pilota** (W4 × O1, O2) | 10 pilot-objekata; nakon odobrenja citati i fotografije; 3 kratke studije slučaja | osnivačica | decembar 2026.–februar 2027. |
| WO3 | **Online shop za proljetnu sezonu** (W1 × O3) | online prodaja s pružaocem usluga plaćanja, i dalje bez provizije s naše strane | osnivačica (razvoj) | Q1 2027. (prije Valentinova/Uskrsa) |
| WO4 | **Prvo povezivanje s kasom uz partnera** (W3 × O6) | identifikovati kasu koja se u pilotu najčešće koristi; planirati integraciju s prodavcem kasa | osnivačica + prodavac kasa | Q2–Q3 2027. |
| WO5 | **Logistika kartica preko partnerske štamparije** (W9 × O6) | okvirni ugovor sa štamparijom, minimalna zaliha, rok isporuke ≤ 10 radnih dana (pretpostavka) | osnivačica | oktobar 2026. |

### 6.4 WT — istovremeno ograničiti slabosti i prijetnje

| Br. | Strategija | Konkretne mjere | Odgovorna | Rok |
|---|---|---|---|---|
| WT1 | **Rasterećenje osnivačice** (W5 × T4, T9) | makroi za podršku, video-onboarding, vanjska saradnja za Customer Success/podršku | osnivačica; od jula 2027. vanjska saradnja | od jula 2027. (pretpostavka, vezano za okidače) |
| WT2 | **Otpornost na ispade i plan za hitne slučajeve** (W5 × T9) | uputstvo za hitne slučajeve za objekte (kartice knjižiti naknadno), monitoring, test obnove iz sigurnosnih kopija | osnivačica | Q4 2026. |
| WT3 | **Sezonski plan protiv zavisnosti od Q4** (W1 × T4) | proljetne kampanje (Valentinovo, Uskrs, Majčin dan, Očev dan) s online shopom od 2027. | osnivačica | od januara 2027. |
| WT4 | **Valute tek s dokazom tržišta** (W7 × T3) | CHF/BAM/RSD razvijati tek kada su ispunjeni kriteriji ulaska za tržište | osnivačica | 2027.–2028. |
| WT5 | **Fokus umjesto mnoštva funkcija** (W6, W8 × T2) | bez modula za lojalnost, CRM ili rezervacije; Wallet i više lokacija prioritizovati samo prema potražnji | osnivačica | stalno |

---

## 7. Prioriteti za narednih 6 mjeseci

1. **WO1** Njemačko sučelje (Q4 2026.)
2. **SO1** Božićna ofanziva u Beču (oktobar–novembar 2026.)
3. **WO2** Reference iz pilota (do februara 2027.)
4. **ST3** Pravno sigurne podrazumijevane postavke (Q4 2026.)
5. **WO3** Online shop (Q1 2027.)
6. **SO4** Paket za porezne savjetnike (Q1 2027.)

Ova SWOT analiza se provjerava nakon pilota (decembar 2026.), a zatim svakih šest mjeseci.

---

Verzija 1.0 · Stanje: septembar 2026.
