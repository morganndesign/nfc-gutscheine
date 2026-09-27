# Poslovni plan — GiftCard Pro

*Cjelovit poslovni plan za osnivanje, zahtjeve bankama i institucijama za podsticaje te interno upravljanje 2026–2028. Svi finansijski podaci su pretpostavke koje ćemo provjeriti tokom pilota.*

---

## Sadržaj

1. [Sažetak](#1-sažetak)
2. [Preduzeće i osnivanje](#2-preduzeće-i-osnivanje)
3. [Proizvod](#3-proizvod)
4. [Tržište i ciljne grupe](#4-tržište-i-ciljne-grupe)
5. [Konkurencija](#5-konkurencija)
6. [Marketing i prodaja](#6-marketing-i-prodaja)
7. [Poslovanje i organizacija](#7-poslovanje-i-organizacija)
8. [Ključne etape 2026–2028](#8-ključne-etape-20262028)
9. [Finansijski plan](#9-finansijski-plan)
10. [Rizici i mjere](#10-rizici-i-mjere)
11. [Potrebe za finansiranjem](#11-potrebe-za-finansiranjem)

---

## 1. Sažetak

GiftCard Pro je sistem poklon kartica za ugostiteljstvo. Restorani pomoću njega izdaju fizičke poklon kartice s NFC čipom i QR kodom, prodaju ih u svom objektu i naplaćuju ih za stolom pametnim telefonom konobara. Kartica ne čuva novac, nego samo nasumičan link; stanje i historija nalaze se u nepromjenjivom dnevniku transakcija na serveru.

**Naše obećanje:** Poklon kartice koje se koriste kao plaćanje — prislonite karticu, unesite iznos, gotovo, za manje od 5 sekundi. Svaki euro se može pratiti, 0 % provizije.

**Tržište:** 31.038 ugostiteljskih preduzeća u Austriji (2023.), od toga 90,9 % s 0–9 zaposlenih (WKO, februar 2025.). Većina vodi poklon bonove na papiru ili u kasi. Ponuđači online prodavnica bonova fokusirani su na prodaju preko weba i često naplaćuju proviziju.

**Poslovni model:** mjesečna pretplata (Start 29 €, Pro 59 €, Gruppe od 129 €, sve neto), prodaja kartica po principu cost-plus, opcionalno postavljanje na licu mjesta (149 €).

**Stanje:** proizvod je gotov i testiran; pilot s 5–10 bečkih restorana od oktobra 2026.; izlazak na tržište u novembru 2026. Još nema korisnika koji plaćaju.

**Ciljevi (pretpostavka):** ≈ 25 restorana koji plaćaju krajem 2026., ≈ 250 krajem 2027., ≈ 800 krajem 2028. Prag rentabilnosti na oko 150–180 restorana, uključujući platu osnivačice, predviđeno u drugoj polovini 2027.

**Potrebno finansiranje (pretpostavka):** oko 40.000–45.000 €, po mogućnosti iz vlastitih sredstava i podsticaja.

## 2. Preduzeće i osnivanje

| | |
|---|---|
| Naziv firme | [Naziv firme] |
| Pravni oblik | [Pravni oblik] |
| Sjedište | [Adresa], 1xxx Beč |
| Sudski registar (Firmenbuch) | [Broj u sudskom registru], [Registarski sud: Handelsgericht Wien] |
| PDV broj (UID) | [UID broj] |
| Uprava | [Uprava] |
| Osnivanje | [Datum osnivanja] |
| Djelatnost (Gewerbe) | [Naziv djelatnosti, npr. usluge automatske obrade podataka i informacionih tehnologija] — dogovoriti s nadležnim organom i WKO |
| Komora | Privredna komora Beča (Wirtschaftskammer Wien), [strukovna grupa] |
| Osnovni kapital / vlastita sredstva | [Iznos] |
| Kontakt | hallo@giftcardpro.at · [Telefon] · giftcardpro.at |

**Osnivačica:** [Ime], osnivačica. Iskustvo u web razvoju, dizajnu za restorane, automatizaciji i testiranju softvera (QA). Govori njemački, bosanski/hrvatski/srpski i engleski. Proizvod je sama razvila, a procese u bečkim ugostiteljskim objektima poznaje iz dizajnerskih projekata.

**Izbor pravnog oblika:** [odrediti s poreznim savjetnikom — kriteriji: odgovornost, socijalno osiguranje, ulazak novih ortaka, pravo na podsticaje].

**Naziv brenda:** „GiftCard Pro“ je radni naziv. Konačan brend bit će određen i zaštićen prije širenja na Njemačku. Do tada važe domene i e-mail adrese (giftcardpro.at).

**Misija:** Restoranima dajemo sistem poklon bonova koji funkcioniše jednako dobro kao njihova usluga: brzo, pouzdano i lijepo.

**Vizija:** Svaki poklon bon postaje povod za sljedeću posjetu — i nijedan se ne gubi.

**Vrijednosti:** Jasnoća · Pouzdanost · Gostoprimstvo · Poštenje · Zanat.

## 3. Proizvod

### 3.1 Osnovne funkcije

| Oblast | Funkcije |
|---|---|
| **Izdavanje kartica** | vrijednost (brzi izbor 25/50/75/100/150 € ili slobodan iznos), rok važenja, kupac opcionalno, ime obdarene osobe (štampa se), interna napomena, vrsta kartice, trenutna aktivacija; 16-cifreni broj kartice s kontrolnom cifrom |
| **Upisivanje i štampa kartica** | upis NFC taga jednim prislanjanjem (Android + Chrome) ili bilo kojom NFC aplikacijom; vezivanje za serijski broj čipa nakon provjerenog upisa (Android), opcionalno trajno zaključavanje taga; izgled za štampu u formatu bankovne kartice (85,6 × 54 mm) |
| **Aplikacija za konobare** | web aplikacija na svakom pametnom telefonu; NFC (Android), NFC link ili QR preko kamere (iPhone), broj kartice kao rezervna opcija; tastatura kao na kasi, „Full balance“, veliko dugme za iskorištavanje, preostalo stanje, „Next card“ |
| **Upravljanje karticama** | iskorištavanje (cijelo/djelimično), dopuna, prenos stanja, zamjena izgubljene kartice, blokiranje/deblokiranje, trenutno isticanje, storno knjiženja (kao protuknjiženje) |
| **Dashboard** | otvoreni iznos poklon kartica, promet u mjesecu, iskorištavanja, prodane kartice; grafikoni; lista kartica s pretragom i filterima; dnevnik transakcija; kupci s anonimizacijom prema GDPR-u; tim; uređaji; zapisnik aktivnosti |
| **Gosti** | javna stranica sa stanjem (njemački/engleski, može se isključiti); e-mailovi pri kupovini, dopuni, skorom isteku i niskom stanju |
| **Porezni savjetnik** | CSV izvoz sa tačkom-zarezom i decimalnim zarezom — otvara se direktno u Excelu |
| **Povezivanje** | API tokeni s ograničenim pravima, npr. za povezivanje s kasom (paket Pro) |

### 3.2 Sigurnost

Potpuno razdvojeni podaci svakog restorana; stanje nikad nije na kartici; atomska, idempotentna knjiženja u nepromjenjivom dnevniku (testirano s 20 istovremenih iskorištavanja jedne kartice); zaštita od kloniranja preko serijskog broja čipa (NTAG21x), odnosno kriptografskog potpisa s brojačem (NTAG 424 DNA); zaključavanje računa nakon 10 neuspjelih prijava; sesije vezane za uređaj; samo HTTPS; bez kolačića za praćenje u aplikaciji; ništa se ne briše, a podaci o kupcima se po potrebi anonimiziraju. Hosting kod Hetznera u Njemačkoj, noćne sigurnosne kopije (14 dana lokalno i vanjska kopija).

### 3.3 Razgraničenje

GiftCard Pro **nije fiskalna kasa** i ne izdaje fiskalne račune. Prodaja i iskorištavanje knjiže se u fiskalnoj kasi restorana, prema uputama poreznog savjetnika. Trenutno **nema online prodavnice poklon bonova** niti **obrade plaćanja** (planirano od Q1 2027.), nema izvorne aplikacije u App Storeu, nema pregleda više lokacija (planirano 2027.) i nema kartica u novčaniku. Interfejs za osoblje je trenutno na engleskom; njemački interfejs planiran je za Q4 2026. Programi lojalnosti, rezervacije i marketinški moduli namjerno nisu dio proizvoda.

### 3.4 Tehnologija

Laravel 12 / PHP 8.4, MySQL 8.4, Redis, Next.js 15 / TypeScript, Docker, Caddy (automatski HTTPS), CI/CD preko GitHub Actions. 113 automatskih backend testova, test prihvatanja u pregledniku, provjera pristupačnosti prema WCAG 2.1 AA.

### 3.5 Plan razvoja

| Period | Planirano |
|---|---|
| Q4 2026. | Njemački interfejs za osoblje; automatizovano fakturisanje (Stripe); standardni rok važenja platforme promijeniti na „bez isteka“ |
| Q1 2027. | Online prodaja poklon kartica preko web stranice restorana (bez provizije za GiftCard Pro) |
| 2027. | Pregled više lokacija; povezivanje s fiskalnim kasama; Apple/Google Wallet; izlazak na njemačko tržište |
| 2027–2028. | Valute CHF, BAM, RSD; interfejsi na dodatnim jezicima |

## 4. Tržište i ciljne grupe

### 4.1 Veličina tržišta

**Austrija** (izvor: [WKO Branchendaten Gastronomie, februar 2025.](https://www.wko.at/oe/tourismus-freizeitwirtschaft/gastronomie/gastronomie-branchendaten-februar-2025.pdf)):

| Pokazatelj | Vrijednost |
|---|---|
| Ugostiteljska preduzeća (2023.) | 31.038 |
| Udio s 0–9 zaposlenih | 90,9 % |
| Zaposleni | 153.171 |
| Promet (2022.) | 11,645 mlrd. € |
| Članovi WKO 2024.: restorani / gostionice / kafane | 7.912 / 5.016 / 5.154 |
| Udio Beča u zaposlenosti | 32,6 % |

**Njemačka** (izvor: DEHOGA-Zahlenspiegel, 4. kvartal 2025.): 150.218 ugostiteljskih preduzeća koja su obveznici PDV-a (2023.), 202.110 u cijeloj ugostiteljskoj djelatnosti; realni promet 2025. za 14,8 % ispod nivoa iz 2019.

**Švicarska, Hrvatska, Bosna i Hercegovina, Srbija:** broj objekata tek treba utvrditi (izvori za provjeru: GastroSuisse Branchenspiegel, DZS Hrvatska, Agencija za statistiku BiH, RZS Srbija). Kvalitativno: jaka kultura kafana i restorana, u Hrvatskoj visok udio turizma, u Bosni i Hercegovini i Srbiji niži nivo cijena i često objekti koje vode sami vlasnici.

### 4.2 Dostupno tržište (procjena)

| Nivo | Obuhvat | Veličina |
|---|---|---|
| Ukupno tržište AT | sva ugostiteljska preduzeća | 31.038 |
| Osnovni segment AT | restorani, gostionice, kafane (članovi WKO 2024.) | 18.082 |
| Dostižno do 2028. | udio u osnovnom segmentu AT plus prvi korisnici u DE (pretpostavka) | ≈ 800 restorana |

Uz 800 restorana i ARPA od 42 € dobija se godišnji ponavljajući prihod od oko 403.000 € (pretpostavka). Za taj cilj nije potreban veliki tržišni udio.

### 4.3 Persone

**Vlasnik ili vlasnica (odluka).** 35–60 godina, vodi jedan do tri objekta, i sam/sama radi u njemu. Razmišlja o novcu, obavezama i ugledu kuće. Nema vremena za softverske projekte.
*Treba:* brz pregled otvorenih iznosa, zaštitu od prevare, poklon koji odgovara kući, poštene i predvidive troškove.
*Prigovori:* „Papir funkcioniše.“ „Još jedan sistem.“ „Koliko to stvarno košta?“

**Menadžer (upravljanje).** Organizuje raspored smjena, kasu i obračun.
*Treba:* sljedive transakcije, prava po ulogama, brzo rješavanje upita gostiju, uredne mjesečne obračune.

**Konobar ili konobarica (korištenje).** Često promjenljivi timovi, pomoćno osoblje, više jezika.
*Treba:* nula obuke, velika dugmad, jasne poruke, bez čekanja za stolom.

**Gost koji poklanja (kupovina).** Traži poklon za Božić, rođendan, Majčin dan.
*Treba:* nešto što izgleda kao poklon — karticu umjesto papirića.

**Gost koji dobija poklon (iskorištavanje).** Želi iskoristiti karticu bez rasprave i vidjeti preostalo stanje.
*Treba:* stranicu sa stanjem na vlastitom telefonu i jednostavno iskorištavanje, i u djelimičnim iznosima.

**Porezni savjetnik ili savjetnica (uticaj).** Vodi mnogo ugostiteljskih objekata.
*Treba:* uredne izvoze, stanje otvorenih bonova na određeni datum, jasno razdvajanje evidencije kartica i fiskalne kase.

### 4.4 Segmenti i redoslijed

1. **Beč** — restorani, kafane, heurigeri, barovi, hotelski restorani; ugostiteljska zajednica porijeklom s prostora bivše Jugoslavije kao topla mreža osnivačice.
2. **Glavni gradovi austrijskih pokrajina** — Graz, Linz, Salzburg, Innsbruck (2027.).
3. **Njemačka** — početak preko pograničnih regija i velikih gradova s velikim brojem restorana (2027.).
4. **Švicarska, Hrvatska, Bosna i Hercegovina, Srbija** (2027–2028.).

## 5. Konkurencija

Kratak pregled; detaljno u [analizi konkurencije](competitor-analysis.md).

| Kategorija | Primjeri | Cjenovna sidra (izvor: medienkraft.at, poređenje sistema poklon bonova) |
|---|---|---|
| Online prodavnice bonova s pretplatom | gurado, simpliby, LiveTable VariBon | gurado besplatno / 29 € / 49 € / 89 €; simpliby 29 € / 49 € / 89 €; VariBon 25 € / 45 € mjesečno |
| Prodavnice s provizijom | firstvoucher, Gutschein Direkt | firstvoucher postavljanje 0 € / 499 € / 1.199 € plus 4,9 % odnosno 3,9 %; Gutschein Direkt 0 € mjesečno, naplata po naknadama |
| Individualna rješenja | incert (Beč), e-guma, gutschein.software, Jolioo, apro gutschein-modul, gastronaut | na upit, odnosno zavisno od ponuđača |
| NFC vezan za kasu | leaf systems | vezano za vlastiti kasni sistem |
| Postojeće stanje | papirni bonovi s Excel tabelom, funkcija bonova u fiskalnoj kasi | naizgled besplatno |

**Naša niša:** premium kartica s NFC-om, iskorištavanje za stolom za nekoliko sekundi, dnevnik zaštićen od prevare i bez provizije — nezavisno od fiskalne kase. Većina konkurenata optimizuje online prodaju; mi optimizujemo trenutak za stolom i kontrolu nad otvorenim iznosima.

## 6. Marketing i prodaja

### 6.1 Pozicioniranje

Kategorija: „NFC poklon kartice za restorane“. Vodeća poruka: **„Poklon kartice koje se koriste kao plaćanje.“** Stubovi: brzo za stolom · zaštita od prevare i grešaka · jasan pregled otvorenih iznosa · poklon koji izgleda kao poklon · pošteno, bez provizije.

### 6.2 Prodaja

- **Direktna prodaja koju vodi osnivačica** u Beču: posjete na licu mjesta prije podne ili rano poslijepodne, demonstracija za 15 minuta, probni period od 30 dana, zaključenje.
- **Topla mreža:** postojeći klijenti osnivačice iz dizajnerskih projekata i ugostitelji porijeklom s prostora bivše Jugoslavije u Beču, na njemačkom ili na našem jeziku.
- **Partneri:** porezni savjetnici, prodavci kasa, štamparije kartica — uz dogovor o preporukama (uslovi u strategiji prodaje).
- **Događaji:** manifestacije WKO za ugostiteljstvo, sajam „Alles für den Gast“ u Salzburgu (termin provjeriti).

Detalji: [Strategija prodaje](sales-strategy.md) i [Strategija izlaska na tržište](go-to-market-strategy.md).

### 6.3 Marketing

- Web stranica giftcardpro.at s video demonstracijom, cijenama i registracijom za probni period; bez kolačića za praćenje.
- Sezonske kampanje prije Adventa, Valentinova, Uskrsa, Majčinog dana i Očevog dana — poruka objektima: „Za Božić prodajte kartice umjesto papirića.“
- Set uzoraka kartica za demonstracije; fotografije iz stvarnih objekata [nakon odobrenja].
- Budžet u prvoj godini: 1.000–2.000 € mjesečno (pretpostavka).

## 7. Poslovanje i organizacija

### 7.1 Hosting i tehnika

| Oblast | Provedba |
|---|---|
| Hosting | Hetzner Online GmbH, podatkovni centri u Njemačkoj (EU) |
| Sigurnosne kopije | noćne kopije baze podataka, 14 dana lokalno plus vanjska kopija (Hetzner Storage Box); dnevni snimci servera |
| Nadzor | provjera ispravnosti `/up` (baza podataka i keš) |
| Noćni zadaci (bečko vrijeme) | isticanje kartica 00:15, čišćenje 03:30, e-mail podsjetnici 10:00 |
| Dostupnost | ciljna vrijednost 99,5 % mjesečno (u paketu Start bez garancije; u paketu Gruppe moguć ugovorni SLA) |
| Isporuka | Docker, CI/CD preko GitHub Actions |
| Troškovi | 150–300 € mjesečno u prvoj godini (pretpostavka) |

### 7.2 Podrška

- Podrška e-mailom na support@giftcardpro.at, od ponedjeljka do petka od 9 do 17 sati, osim austrijskih praznika.
- Vrijeme odgovora: Start u roku od 1 radnog dana; Pro i Gruppe prioritetno u roku od 4 radna sata, uz podršku telefonom.
- Uvođenje (onboarding): Start putem videa; Pro lično (na daljinu ili na licu mjesta u Beču); Gruppe za sve lokacije.
- Baza znanja i materijali za obuku konobara (jedna stranica po ulozi).
- Sigurnosne prijave: security@giftcardpro.at; zaštita podataka: datenschutz@giftcardpro.at.

### 7.3 Logistika kartica

1. Restoran naručuje kartice (početni paket od 100, 250 ili individualna količina); dizajn na osnovu logotipa i boja, odobrenje putem PDF probnog otiska.
2. Štampa u [štampariji kartica] — NTAG215 obostrano u punoj boji; NTAG 424 DNA na upit. Rok isporuke [x radnih dana — dogovoriti sa štamparijom].
3. Isporuka restoranu poštom ili lično u Beču.
4. Restoran upisuje kartice pri izdavanju (jedno prislanjanje na Android telefon) — nema unaprijed upisanih kartica, pa ni vrijednosti koja se može izgubiti u transportu.
5. QR kartice restoran po potrebi štampa sam pomoću šablona za štampu, besplatno.

Prije sezone Adventa držimo sigurnosnu zalihu neštampanih NFC kartica (predfinansiranje, vidi poglavlje 11).

### 7.4 Organizacija

| Period | Uloge |
|---|---|
| 2026. | Osnivačica: proizvod, prodaja, uvođenje, podrška; vanjski saradnici: porezni savjetnik, pravni savjetnik, štamparija |
| od jula 2027. | dodatno honorarna saradnja za prodaju i podršku (pretpostavka) |
| 2028. | 2–3 ekvivalenta punog radnog vremena: podrška i uvođenje, prodaja Austrija, prodaja Njemačka (pretpostavka) |

## 8. Ključne etape 2026–2028

| Termin | Etapa | Mjerilo |
|---|---|---|
| Oktobar 2026. | Pilot s 5–10 restorana u Beču pokrenut | najmanje 5 aktivnih objekata, prve kartice prodane |
| Novembar 2026. | Pravni tekstovi i njemački interfejs spremni; izlazak na tržište | opći uslovi, ugovor o obradi podataka po nalogu, impresum, izjava o zaštiti podataka objavljeni |
| 29. 11. 2026. | Prva adventska nedjelja — kampanja u toku | kartice isporučene prije Adventa |
| Decembar 2026. | ≈ 25 restorana uključujući pilot | MRR ≈ 1.050 € (pretpostavka) |
| Q1 2027. | Online prodaja pokrenuta; prve reference objavljene | najmanje 3 odobrene reference |
| Sredina 2027. | Prag rentabilnosti u tekućem mjesecu | 150–180 restorana koji plaćaju |
| 2027. | Graz, Linz, Salzburg, Innsbruck; izlazak na njemačko tržište | prvih 20 korisnika u DE |
| Decembar 2027. | ≈ 250 restorana | MRR ≈ 10.500 € |
| 2028. | Švicarska, Hrvatska, Bosna i Hercegovina, Srbija | prvi korisnici u svakoj zemlji |
| Decembar 2028. | ≈ 800 restorana | MRR ≈ 33.600 € |

## 9. Finansijski plan

*Sve vrijednosti su pretpostavke (stanje planiranja: septembar 2026.), u eurima, neto. Kalendarske godine; 2026. obuhvata samo period od oktobra do decembra. Moguće su razlike zbog zaokruživanja.*

### 9.1 Pretpostavke

| Pretpostavka | Vrijednost |
|---|---|
| ARPA (mjesečni prihod po korisničkom računu) | 42 € — omjer 70 % Start, 25 % Pro, 5 % Gruppe, umanjeno za pilot popuste; računato kao konstanta za sve godine (bez povećanja cijena) |
| Restorani koji plaćaju na kraju godine | 2026. ≈ 25 (uključujući pilot), 2027. ≈ 250, 2028. ≈ 800 |
| Prosječan broj korisnika | 2027.: 137,5; 2028.: 525 (prosjek početka i kraja godine) |
| Mjesečni odljev korisnika | 1,5 % (odgovara zadržavanju od oko 83 % godišnje) |
| Novi korisnici (bruto) | 2026.: 25; 2027.: 250 (225 neto + 25 odlazaka); 2028.: 645 (550 neto + 95 odlazaka) |
| Prva narudžba kartica | prosječno 150 kartica po prosječno 350 € po narudžbi; bruto marža na karticama ≈ 35 %; ponovljene narudžbe nisu uračunate |
| Pilot objekti | 10 objekata, po 50 besplatnih kartica (trošak ≈ 1,62 € po kartici), bez prihoda od pretplate u 2026. |
| Postavljanje na licu mjesta | 20 % novih korisnika izvan pilota naručuje uslugu za 149 € |
| Naknade za plaćanje | 2 % prihoda od pretplata |
| Plata osnivačice | 2026.: 0 €; od 2027.: 4.000 € mjesečno (uključujući socijalno osiguranje) |
| Osoblje | 2027.: honorarna saradnja od jula, 1.500 € mjesečno; 2028.: 2,5 ekvivalenta punog radnog vremena po 3.800 € troška poslodavca mjesečno |

### 9.2 Planirani bilans uspjeha

| Pozicija | 2026. (okt.–dec.) | 2027. | 2028. |
|---|---:|---:|---:|
| Restorani koji plaćaju (kraj godine) | 25 | 250 | 800 |
| MRR na kraju godine | 1.050 | 10.500 | 33.600 |
| **Prihod od pretplata** | 630 | 69.300 | 264.600 |
| **Prihod od kartica** | 5.250 | 87.500 | 225.750 |
| **Prihod od postavljanja** | 447 | 7.450 | 19.221 |
| **Ukupan prihod** | **6.327** | **164.250** | **509.571** |
| Nabavna vrijednost kartica (uključujući besplatne pilot kartice) | 4.222 | 56.875 | 146.738 |
| Naknade za plaćanje | 13 | 1.386 | 5.292 |
| Hosting i infrastruktura | 750 | 3.600 | 7.200 |
| Slanje e-mailova | 150 | 600 | 1.200 |
| Softverski alati | 450 | 1.800 | 3.000 |
| Osiguranje, pravno i porezno savjetovanje | 1.200 | 4.800 | 7.200 |
| Marketing i prodaja (uključujući sajmove, putovanja) | 4.500 | 24.000 | 48.000 |
| Plata osnivačice | 0 | 48.000 | 48.000 |
| Osoblje / honorarna saradnja | 0 | 9.000 | 114.000 |
| Ulazak na tržišta CH/HR/BA/RS (pravo, prevod, jednokratno) | 0 | 0 | 10.000 |
| **Ukupni troškovi** | **11.284** | **150.061** | **390.630** |
| **Rezultat prije poreza** | **− 4.957** | **+ 14.189** | **+ 118.942** |

Mjesečne stavke troškova: 2026. hosting 250 €, e-mail 50 €, alati 150 €, osiguranje/pravo/porez 400 €, marketing 1.500 €; 2027. hosting 300 €, e-mail 50 €, alati 150 €, osiguranje/pravo/porez 400 €, marketing 2.000 €; 2028. hosting 600 €, e-mail 100 €, alati 250 €, osiguranje/pravo/porez 600 €, marketing 4.000 €.

**Kako čitati tabelu:** prihodi od kartica su visoki, ali s niskom maržom (≈ 35 %). Vrijednost preduzeća leži u ponavljajućem prihodu od pretplata. Pozitivan rezultat u 2027. nastaje tek u drugoj polovini godine; u prvoj polovini 2027. računamo s mjesečnim gubicima.

### 9.3 Izračun praga rentabilnosti

Doprinos pokriću po restoranu i mjesecu (pretpostavka):

- ARPA: 42 €
- varijabilni troškovi po računu (naknade za plaćanje, udio hostinga i e-mailova, vrijeme podrške): ≈ 4 €
- **Doprinos pokriću: ≈ 38 € mjesečno**

Mjesečni fiksni troškovi uključujući platu osnivačice (4.000 €):

| Scenarij | Hosting | E-mail | Alati | Osig./pravo/porez | Marketing | Plata osnivačice | **Ukupno** | **Prag rentabilnosti (ukupno ÷ 38 €)** |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| nizak | 150 | 20 | 150 | 400 | 1.000 | 4.000 | **5.720** | **≈ 151 restoran** |
| srednji | 250 | 50 | 150 | 400 | 1.500 | 4.000 | **6.350** | **≈ 167 restorana** |
| visok | 300 | 50 | 150 | 400 | 2.000 | 4.000 | **6.900** | **≈ 182 restorana** |

**Rezultat:** prag rentabilnosti na oko 150–180 restorana koji plaćaju. Bruto dobit od prodaje kartica (≈ 122 € po prvoj narudžbi) nije uračunata i dodatno snižava prag. Prema planu, prag se prelazi sredinom 2027.

### 9.4 Pokazatelji po korisniku

| Pokazatelj | Vrijednost (pretpostavka) | Izračun |
|---|---|---|
| Bruto marža pretplate | ≈ 90 % | (42 € − 4 €) ÷ 42 € |
| Prosječno trajanje korisničkog odnosa | ≈ 67 mjeseci | 1 ÷ 1,5 % |
| Vrijednost korisnika tokom trajanja odnosa (LTV) | ≈ 2.533 € | 38 € ÷ 1,5 % |
| Trošak pridobijanja korisnika (CAC) | < 300 € | cilj |
| Povrat ulaganja | ≈ 7,9 mjeseci | 300 € ÷ 38 € |
| LTV : CAC | ≈ 8 : 1 | 2.533 € ÷ 300 € |

Izvođenje u [modelu prihoda](revenue-model.md).

### 9.5 Likvidnost

Računi za pretplatu izdaju se mjesečno ili godišnje unaprijed; godišnja plaćanja poboljšavaju likvidnost. Kartice se štampariji plaćaju unaprijed ili pri isporuci, a račun restoranu izdaje se pri isporuci — iz toga nastaje kratkoročna potreba za predfinansiranjem, posebno u oktobru i novembru. Najniža tačka likvidnosti očekuje se u prvoj polovini 2027.

## 10. Rizici i mjere

| Rizik | Vjerovatnoća | Uticaj | Mjera |
|---|---|---|---|
| Sporije pridobijanje korisnika od planiranog | srednja | visok | pilot kao osnova za reference; partnerski kanali (porezni savjetnici, prodavci kasa); niski fiksni troškovi; postepeno odobravanje marketinškog budžeta |
| Engleski interfejs odbija objekte | visoka | srednji | njemački interfejs u Q4 2026. s najvišim prioritetom; do tada materijali za obuku na njemačkom koji tačno navode engleske nazive dugmadi |
| Kašnjenje isporuke kartica prije Božića | srednja | visok | ugovorno vezati štampariju; držati zalihu praznih kartica; QR kartice za samostalnu štampu kao privremeno rješenje |
| Pravne greške kod rokova važenja bonova | srednja | srednji | preporuka „bez isteka“ pri svakom uvođenju; standardna vrijednost platforme se mijenja; uputa na porezno i pravno savjetovanje |
| Nesporazum „GiftCard Pro je kasa“ | srednja | srednji | jasna komunikacija: knjiženje u vlastitoj fiskalnoj kasi; usklađivanje s poreznim savjetnikom pri uvođenju |
| Ispad ili gubitak podataka | niska | visok | sigurnosne kopije s vanjskom kopijom, snimci, provjera ispravnosti, dokumentovan postupak oporavka; ciljna dostupnost 99,5 % |
| Sigurnosni incident | niska | visok | razdvojeni podaci restorana, nepromjenjivi dnevnik, zaštita od kloniranja, vezivanje za uređaj, zapisnik aktivnosti; kanal za prijave security@giftcardpro.at; plan za slučaj povrede podataka |
| Zavisnost od jedne osobe | visoka | visok | dokumentacija, automatski testovi i isporuke; honorarna saradnja od 2027.; [plan zamjene] |
| Pritisak konkurencije na cijene | srednja | srednji | razlikovanje preko NFC kartice, brzine za stolom, 0 % provizije; godišnje cijene; bez utrke prema dnu |
| Konkurenti vezani za kase razvijaju NFC | srednja | srednji | nezavisnost od kase kao argument; API za povezivanje s kasama |
| Naziv brenda nije moguće zaštititi | srednja | srednji | provjera žiga prije ulaska u DE; rano osiguranje domena |
| Kurs i nivo cijena u HR/BA/RS | srednja | nizak | lokalizovani cjenovni nivoi, prvo validirati |

## 11. Potrebe za finansiranjem

### 11.1 Potrebe (pretpostavka)

| Namjena | Iznos (€) |
|---|---:|
| Početni gubitak Q4 2026. | 5.000 |
| Početni gubici u prvoj polovini 2027. | 9.000 |
| Predfinansiranje kartica (prazne kartice, štampa prije Adventa) | 5.000 |
| Pravni tekstovi, provjera žiga, osiguranje (jednokratno) | 4.000 |
| Rezerva likvidnosti (≈ 3 mjeseca fiksnih troškova) | 20.000 |
| **Ukupno** | **43.000** |

### 11.2 Opcije

1. **Vlastito finansiranje (bootstrapping, prednost).** Vlastita sredstva osnivačice [iznos], prihodi od godišnjih pretplata i prodaje kartica, dodatni prihodi od savjetovanja. Prednost: puna kontrola, bez razvodnjavanja vlasništva. Nedostatak: sporiji rast, zavisnost od jedne osobe.
2. **Programi podsticaja — ispunjavanje uslova treba provjeriti za svaki program; odobrenje ne postoji:**
   - **aws (Austria Wirtschaftsservice):** programi za inovativna osnivanja i finansiranje u ranoj fazi (npr. aws Preseed, aws Seedfinancing) te garancije za bankarske kredite — provjeriti uslove programa, stepen inovativnosti i rokove prijave.
   - **FFG (Österreichische Forschungsförderungsgesellschaft):** osnovni program (Basisprogramm) za razvojne projekte, npr. za planirano povezivanje s kasama ili online prodaju — provjeriti da li se daljnji razvoj može finansirati.
   - **Wirtschaftsagentur Wien:** programi podsticaja za bečka preduzeća u oblastima osnivanja, digitalizacije i inovacija — provjeriti aktuelne pozive i rokove.
   - Savjetovanje: WKO Gründerservice, [porezni savjetnik].
3. **Bankarski kredit ili okvirni kredit po tekućem računu** za predfinansiranje kartica, po potrebi uz garanciju aws-a.
4. **Poslovni anđeli** iz ugostiteljstva ili trgovine kasama — tek nakon potvrđenih rezultata pilota, kako vrijednost preduzeća ne bi bila prerano utvrđena.

### 11.3 Korištenje i kontrola

Sredstva se odobravaju postepeno: marketinški budžet tek nakon mjerenja stope zaključenja u pilotu; osoblje tek kada je mjesečni priliv novih korisnika stabilno iznad plana. Mjesečni izvještaj o MRR-u, broju korisnika, odljevu, CAC-u i likvidnosti.

---

*Ovaj plan ne sadrži pravno ni porezno savjetovanje. Pravne i porezne navode treba provjeriti s poreznim savjetnikom, odnosno advokatom ili advokaticom.*

Verzija 1.0 · Stanje: septembar 2026.
