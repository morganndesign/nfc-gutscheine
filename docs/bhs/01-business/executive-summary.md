# Sažetak poslovanja (Executive Summary) — GiftCard Pro

*Kratak pregled za investitore, institucije za podsticaje, partnere i savjetnike: šta gradimo, za koga, zašto sada i šta nam je sljedeće potrebno.*

---

## Ukratko

| | |
|---|---|
| **Proizvod** | GiftCard Pro — sistem poklon kartica za ugostiteljstvo (NFC i QR kartice, softver u oblaku) |
| **Osnovno obećanje** | Kartica prislonjena, iznos unesen, gotovo — za manje od 5 sekundi. Svaki euro se može pratiti. |
| **Ciljno tržište** | Prvo Austrija (Beč → Graz, Linz, Salzburg, Innsbruck), od 2027. Njemačka, 2027–2028. Švicarska, Hrvatska, Bosna i Hercegovina, Srbija |
| **Poslovni model** | Mjesečna pretplata od 29 € neto, 0 % provizije, prodaja kartica po principu cost-plus |
| **Stanje** | Proizvod je razvijen i testiran; pilot s 5–10 bečkih restorana od oktobra 2026.; još nema korisnika koji plaćaju |
| **Izlazak na tržište** | Novembar 2026. — prije sezone Adventa i Božića |
| **Pružalac usluge** | [Naziv firme] [Pravni oblik], [Adresa], 1xxx Beč |

---

## 1. Problem

Poklon bonovi su za restorane dobar posao: novac stiže prije posjete, a obdareni gosti često dovedu i društvo. U svakodnevici većine objekata to ipak izgleda ovako:

- **Papirni bonovi i Excel tabela.** Blok numerisanih bonova, iznosi upisani rukom, pečat. Preostali iznos se na bonu precrta i ponovo napiše — ili se ne upiše uopće.
- **Falsifikovanje i višestruko korištenje.** Za kopiju papirnog bona dovoljna je fotokopirna mašina u boji. Da li je bon već iskorišten, često zna samo osoba koja ga je tada primila.
- **Nema pregleda otvorene obaveze.** Svaki prodani, a još neiskorišteni bon je obaveza prema gostu. Rijetki vlasnici i vlasnice mogu jednim klikom reći koliki je taj iznos. Kod objekata koji vode dvojno knjigovodstvo on ide u bilans; kod svih ostalih je barem poslovni rizik.
- **Pravne zamke.** Mnogi papirni bonovi imaju rok važenja koji prema austrijskoj sudskoj praksi može biti ništavan (OGH: opće ograničenje plaćenih bonova na 3 godine ili manje u općim uslovima poslovanja je grubo nepovoljno za kupca). Gosti tada imaju pravo na iskorištavanje do 30 godina.
- **Online prodavnice bonova ne odgovaraju svima.** Većina ponuđača na tržištu prodaje PDF bonove preko web stranice i naplaćuje proviziju od 3,9–4,9 % po prodaji ili znatno veće naknade za postavljanje. Za restoran koji bonove prodaje uglavnom za šankom i pred Božić, to je pogrešan fokus.

## 2. Rješenje

GiftCard Pro je platforma u oblaku na kojoj restorani izdaju, prodaju, naplaćuju i upravljaju **fizičkim poklon karticama s NFC čipom i QR kodom**.

- **Kartica ne čuva novac.** Čip i QR kod sadrže samo nasumičan, siguran link. Stanje, historija i podaci o gostima nalaze se isključivo na serveru. Kopirana ili izgubljena kartica može se blokirati ili zamijeniti — iznos ostaje sačuvan.
- **Iskorištavanje za stolom za nekoliko sekundi.** Konobar ili konobarica prisloni karticu na svoj pametni telefon (Android preko Web NFC-a, iPhone preko sistemskog obavještenja ili kamere), ukuca iznos kao na kasi i potvrdi. Sistemsko vrijeme za cijeli postupak iznosi oko 0,5 sekundi; cilj je manje od 5 sekundi zajedno s čovjekom za stolom.
- **Jasan pregled otvorenih iznosa.** Dashboard u svakom trenutku prikazuje ukupni otvoreni iznos („Outstanding balance“) na svim karticama, uz prodaju, iskorištavanja i nepromjenjivi dnevnik transakcija s CSV izvozom za poreznog savjetnika.
- **Zaštita od prevare i grešaka.** Svako knjiženje je atomsko i idempotentno (dvostruki dodir nikad ne knjiži dvaput), dnevnik je nepromjenjiv, a klonirane kartice se prepoznaju preko serijskog broja čipa, odnosno kriptografski kod kartica NTAG 424 DNA.
- **Poklon koji izgleda kao poklon.** Format bankovne kartice, obostrano štampan u dizajnu restorana — umjesto papirića u koverti.
- **Pošteno.** 0 % provizije na prodaju i iskorištavanje, zauvijek.

GiftCard Pro ne zamjenjuje fiskalnu kasu. Prodaja i iskorištavanje se i dalje knjiže u vlastitoj fiskalnoj kasi; GiftCard Pro uz to vodi evidenciju poklon kartica.

![Dashboard vlasnika s otvorenim iznosom poklon kartica](../../screenshots/owner-dashboard.png)

## 3. Zašto sada

1. **Pred nama je najjača sezona poklon bonova.** Advent i Božić su glavno vrijeme prodaje poklon bonova u ugostiteljstvu. Ko pređe na kartice u novembru, već božićne bonove prodaje na karticama. Zato je izlazak na tržište namjerno u novembru 2026.
2. **Papir je pravi konkurent.** Većina malih objekata i dalje radi s papirnim bonovima ili funkcijom bonova u kasi. Prelazak je jednostavan jer nije potrebna nova kasa niti nova oprema osim kartica i postojećih pametnih telefona.
3. **Svijest o prevarama i greškama raste.** Kopirani papirni bonovi, dvostruko naplaćeni iznosi i nedostatak dokaza koštaju novac koji u restoranima s tijesnom kalkulacijom nedostaje.
4. **Obaveza postaje vidljiva.** Sudska praksa o rokovima važenja i porezni tretman bonova (EU direktiva o vaučerima, od 2019.) čine urednu evidenciju važnijom. Mnogi objekti jednostavno ne znaju kolika je njihova otvorena obaveza po bonovima.
5. **NFC je dio svakodnevice.** Gosti poznaju prislanjanje od beskontaktnog plaćanja; konobari imaju pametni telefon u džepu. Web NFC na Androidu i prepoznavanje NFC linkova na iPhoneu čine posebnu aplikaciju suvišnom.

## 4. Stanje proizvoda

Proizvod je razvijen do kraja, automatski testiran i spreman za pilot:

| Oblast | Stanje |
|---|---|
| Aplikacija za konobare (web aplikacija, može se instalirati na početni ekran) | gotovo — NFC, QR skeniranje, ručni unos broja kartice, tastatura kao na kasi |
| Dashboard za vlasnike i menadžere | gotovo — ključni pokazatelji, grafikoni, kartice, transakcije, kupci, tim, uređaji, zapisnik aktivnosti, postavke |
| Životni ciklus kartice | gotovo — izdavanje, aktivacija, iskorištavanje (cijelo/djelimično), dopuna, prenos, zamjena, blokiranje, storno |
| Sigurnost | gotovo — razdvojeni podaci svakog restorana, nepromjenjivi dnevnik, zaštita od kloniranja, vezivanje za uređaj, zaštita od napada pogađanjem |
| Javna stranica sa stanjem za goste | gotovo (njemački/engleski) |
| Osiguranje kvaliteta | 113 automatskih backend testova, test prihvatanja u pregledniku, provjera pristupačnosti (WCAG 2.1 AA), test s 20 istovremenih iskorištavanja jedne kartice |
| Hosting | Hetzner, podatkovni centri u Njemačkoj (EU), noćne sigurnosne kopije uključujući vanjsku kopiju |
| Interfejs za osoblje | trenutno na engleskom; njemački interfejs planiran za Q4 2026. (visok prioritet) |

Tehnologija: Laravel 12 / PHP 8.4, MySQL 8.4, Redis, Next.js 15 / TypeScript, Docker, Caddy, GitHub Actions.

## 5. Tržište

**Austrija** (izvor: WKO Branchendaten Gastronomie, februar 2025.):

- **31.038 ugostiteljskih preduzeća** (2023.), od toga **90,9 % s 0–9 zaposlenih**
- 153.171 zaposleni, promet 11,645 mlrd. € (2022.)
- Članstvo u WKO 2024.: 7.912 restorana, 5.016 gostionica (Gasthäuser), 5.154 kafane (Kaffeehäuser)
- Beč: 32,6 % zaposlenosti u ugostiteljstvu

**Njemačka** (izvor: DEHOGA-Zahlenspiegel, 4. kvartal 2025.):

- **150.218 ugostiteljskih preduzeća** (obveznici PDV-a, 2023.), 202.110 u cijeloj ugostiteljskoj djelatnosti
- realni promet 2025. i dalje 14,8 % ispod nivoa iz 2019. — objekti traže planiv dodatni prihod

**Švicarska, Hrvatska, Bosna i Hercegovina, Srbija:** broj objekata tek treba utvrditi (GastroSuisse Branchenspiegel, DZS Hrvatska, Agencija za statistiku BiH, RZS Srbija). Osnivačica govori njemački, bosanski/hrvatski/srpski i engleski; to otvara prirodan pristup ugostiteljima porijeklom s prostora bivše Jugoslavije u Beču, a kasnije i u zemljama regiona.

**Procjena (pretpostavka):** Ako do kraja 2028. dostignemo oko 800 restorana koji plaćaju, to uz fokus na Austriju znači nizak jednocifreni procentualni udio ugostiteljskih preduzeća u Austriji i Njemačkoj zajedno. Rast ne zavisi od velikog tržišnog udjela.

## 6. Poslovni model i cijene

Sve cijene su neto, uvećane za 20 % PDV-a (Austrija). Mjesečni otkaz moguć; kod godišnjeg plaćanja 2 mjeseca su besplatna.

| Paket | Mjesečno | Godišnje | Za koga |
|---|---|---|---|
| **Start** | 29 € | 290 € | jedan restoran, kafić, bar |
| **Pro** | 59 € | 590 € | prometni objekti, veliki broj kartica, povećan rizik od prevare |
| **Gruppe** (Grupa) | od 129 € za do 3 lokacije, + 39 € za svaku dodatnu lokaciju | individualno | lanci, više lokacija, hoteli s više ugostiteljskih jedinica |

Ostali prihodi:

- **Kartice (cost-plus):** početni paket od 100 štampanih NFC kartica (NTAG215) — okvirna cijena 249 €, 250 kartica 499 €, kartice NTAG 424 DNA okvirno 4–6 € po kartici. *Okvirna cijena, zavisi od količine i štampe — obavezujuća ponuda na upit.*
- **Postavljanje na licu mjesta i obuka:** opcionalno, jednokratno 149 €. Samostalno postavljanje je besplatno.

Šta namjerno ne naplaćujemo: **nikakvu proviziju** na prodaju ili iskorištavanje kartica, nikakvu naknadu za postavljanje kod samostalnog uvođenja, nikakvu naknadu po kartici ili transakciji (fer korištenje).

**30 dana besplatnog probnog perioda**, bez kreditne kartice, sa svim Pro funkcijama.

## 7. Dosadašnji rezultati — iskreno

- Proizvod je izgrađen, testiran i spreman za produkcijski rad.
- **Pilot od oktobra 2026.** s 5–10 restorana u Beču. Uslovi: 3 mjeseca besplatno, zatim 12 mjeseci 50 % popusta (Start 14,50 € / Pro 29,50 €), besplatno postavljanje na licu mjesta i 50 besplatnih kartica; zauzvrat razgovori o iskustvima i — nakon odobrenja — navođenje kao referenca.
- **Još nemamo korisnika koji plaćaju, nemamo reference niti studije slučaja.** Prve rezultate pilota očekujemo od novembra 2026. [Pilot objekti i izjave nakon odobrenja]

## 8. Tim

- **[Ime], osnivačica** — iskustvo u web razvoju, dizajnu za restorane, automatizaciji te testiranju softvera i osiguranju kvaliteta (QA). Govori njemački, bosanski/hrvatski/srpski i engleski. U početnoj fazi odgovorna za proizvod, prodaju i podršku korisnicima.
- Vanjska podrška: [porezni savjetnik], [advokat/advokatica], [štamparija kartica].
- Planirano (pretpostavka): honorarna saradnja za prodaju i podršku od sredine 2027., 2–3 ekvivalenta punog radnog vremena do kraja 2028.

## 9. Plan razvoja — glavne tačke

| Period | Planirano |
|---|---|
| Q4 2026. | Njemački interfejs za osoblje; automatizovano fakturisanje (Stripe); pilot i izlazak na tržište u Beču |
| Q1 2027. | Online prodaja poklon kartica preko web stranice restorana — bez provizije za GiftCard Pro (naknade pružaoca platnih usluga obračunavaju se posebno) |
| 2027. | Pregled više lokacija; povezivanje s fiskalnim kasama preko API-ja; izlazak na njemačko tržište; kartice u novčaniku (Apple/Google Wallet) |
| 2027–2028. | Švicarska (CHF), Hrvatska, Bosna i Hercegovina (BAM), Srbija (RSD); lokalizovani interfejsi |

## 10. Finansijski izgledi (pretpostavke)

*Svi brojevi su planske pretpostavke koje ćemo provjeriti tokom pilota.*

| | Kraj 2026. | Kraj 2027. | Kraj 2028. |
|---|---|---|---|
| Restorani koji plaćaju (uključujući pilot objekte) | ≈ 25 | ≈ 250 | ≈ 800 |
| MRR (pretpostavka ARPA 42 €) | 1.050 € | 10.500 € | 33.600 € |
| Prihod u kalendarskoj godini (pretplate, kartice, postavljanje) | 6.327 € (samo Q4) | 164.250 € | 509.571 € |
| Rezultat prije poreza | − 4.957 € | + 14.189 € | + 118.942 € |

- ARPA (prosječni mjesečni prihod po korisničkom računu) 42 € uz omjer 70 % Start, 25 % Pro, 5 % Gruppe, umanjeno za pilot popuste.
- Mjesečni odljev korisnika 1,5 %, trošak pridobijanja korisnika ispod 300 €, povrat ulaganja za manje od 8 mjeseci.
- **Prag rentabilnosti (break-even) na oko 150–180 restorana koji plaćaju**, uključujući platu osnivačice (izračun u [poslovnom planu](business-plan.md#9-finansijski-plan)).

Detalji: [Poslovni plan](business-plan.md) · [Model prihoda](revenue-model.md) · [Strategija cijena](pricing-strategy.md)

## 11. Sljedeći koraci i potrebe

**Šta radimo u narednih 90 dana:**

1. U oktobru 2026. pokrećemo pilot s 5–10 bečkih restorana i mjerimo: vrijeme iskorištavanja za stolom, prodaju kartica, upite podršci, zadovoljstvo konobara.
2. Prije izlaska na tržište završavamo njemački interfejs i pravne tekstove (opći uslovi poslovanja, ugovor o obradi podataka po nalogu, impresum, izjava o zaštiti podataka).
3. Ugovorom osiguravamo isporuku kartica sa štamparijom — rok isporuke i minimalne količine za sezonu Adventa.
4. Izlazak na tržište u novembru 2026. s fokusom na Beč, direktnu prodaju i partnere iz redova poreznih savjetnika i prodavaca kasa.

**Šta tražimo:**

- **Finansiranje** od oko 40.000–45.000 € (pretpostavka) za početne gubitke, predfinansiranje kartica, pravne tekstove i rezervu likvidnosti — po mogućnosti iz vlastitih sredstava i programa podsticaja (aws, FFG, Wirtschaftsagentur Wien; ispunjavanje uslova se provjerava).
- **Pilot objekte** u Beču: restorane, kafane, heurigere i barove koji žele prije Božića preći na poklon kartice.
- **Partnere:** kancelarije poreznih savjetnika specijalizovane za ugostiteljstvo, prodavce kasa, štamparije kartica.

Kontakt: [Ime], osnivačica · hallo@giftcardpro.at · [Telefon] · giftcardpro.at

---

Verzija 1.0 · Stanje: septembar 2026.
