# Vodič za usklađenost s GDPR-om za GiftCard Pro

> **Ovo je prijevod. Pravno mjerodavna je njemačka verzija.**
>
> **Uzorak/predložak — prije upotrebe dati na provjeru advokatu (odvjetniku) ovlaštenom u Austriji.**
> Ovaj dokument nije pravni savjet. Opisuje tehničko stanje GiftCard Pro i služi kao radna osnova za provjeru zaštite podataka. Mjesta označena s **[Provjeriti: …]** zahtijevaju posebnu pravnu provjeru. Zamjenske oznake u uglastim zagradama treba zamijeniti prije upotrebe.

*Svrha: vodič za zaštitu podataka prema GDPR-u (njem. DSGVO) i austrijskom Zakonu o zaštiti podataka (DSG) za pružaoca usluge GiftCard Pro i za restorane koji koriste GiftCard Pro — uloge, pravni osnovi, inventar podataka, prava ispitanika, evidencija, tehničke i organizacijske mjere, povrede podataka i kontrolna lista.*

---

## 1. Pregled

GiftCard Pro je cloud platforma (SaaS) na kojoj restorani izdaju, prodaju, iskorištavaju i upravljaju fizičkim poklon karticama s NFC čipom i QR kodom. Sama kartica ne čuva ni novac ni lične podatke: čip i QR kod sadrže samo link oblika `https://<domain>/c/<nasumični UUID v4>`. Stanje, historija knjiženja i podaci o kupcima nalaze se isključivo na serveru.

Pravni okvir:

- Opća uredba o zaštiti podataka (GDPR, Uredba (EU) 2016/679; njem. DSGVO)
- austrijski Zakon o zaštiti podataka (DSG), posebno § 6 DSG (tajnost podataka)
- § 165 st. 3 TKG 2021 (kolačići i pohrana na uređaju) — vidi [Politiku kolačića](cookie-policy.md)
- Nadzorni organ: Österreichische Datenschutzbehörde (austrijsko tijelo za zaštitu podataka), Barichgasse 40–42, 1030 Beč, [www.dsb.gv.at](https://www.dsb.gv.at)

Ostali dokumenti ovog paketa: [Ugovor o obradi podataka po nalogu](data-processing-agreement.md), [Izjava o zaštiti podataka](privacy-policy.md), [Politika kolačića](cookie-policy.md), [Opći uslovi poslovanja](terms-of-service.md), [Pravne napomene za restorane](austrian-legal-notes.md).

## 2. Uloge: ko je za šta odgovoran?

| Obrada | Voditelj obrade (čl. 4 t. 7 GDPR) | Izvršitelj obrade (čl. 4 t. 8, čl. 28 GDPR) |
|---|---|---|
| Podaci gostiju/kupaca restorana (kupac, primalac poklona, podaci o kartici, knjiženja, e-mailovi kupcima) | **Restoran** | **Pružalac usluge** ([Naziv firme]) |
| Podaci zaposlenih u restoranu kao korisnika platforme (ime, e-mail, uloga, IP pri prijavi, uređaji, audit log) | **Restoran** | **Pružalac usluge** |
| Ugovorni podaci, podaci za račune i kontakt podaci restorana kao klijenta pružaoca usluge (kontakt osoba, adresa za račun, podaci o plaćanju, zahtjevi podršci) | **Pružalac usluge** | — (podizvršitelji samo za vlastite svrhe pružaoca usluge) |
| Posjetioci web stranice `giftcardpro.at`, zainteresovani klijenti (upiti, termini za demo) | **Pružalac usluge** | — |
| Rad platforme, sigurnost, zaštita od zloupotrebe na nivou infrastrukture (serverski logovi) | **Pružalac usluge** [Provjeriti: razgraničenje vlastite svrhe / nalog] | — |

**Posljedice:**

- Restoran odlučuje o svrsi i sredstvima obrade podataka gostiju (da li se evidentiraju podaci o kupcima i koji, da li se šalju e-mailovi kupcima, koliko dugo kartice važe). Restoran mora informisati goste (čl. 13 GDPR), ostvarivati prava ispitanika i voditi evidenciju.
- Pružalac usluge obrađuje te podatke samo prema dokumentovanim uputama restorana. Osnova je [Ugovor o obradi podataka po nalogu](data-processing-agreement.md), koji je sastavni dio Općih uslova poslovanja.
- Za vlastite podatke o klijentima, računima i web stranici pružalac usluge je sam voditelj obrade; za to važi [Izjava o zaštiti podataka](privacy-policy.md).

## 3. Pravni osnovi

| Obrada | Pravni osnov | Napomena |
|---|---|---|
| Izdavanje, upravljanje i iskorištavanje poklon kartice; dodjela kupcu | čl. 6 st. 1 lit. b GDPR (ugovor o poklon bonu) | Podaci o kupcu nisu obavezni. Anonimne kartice su moguće i povoljne za zaštitu podataka. |
| Ime primaoca poklona (odštampano na kartici) | čl. 6 st. 1 lit. b GDPR (ispunjenje ugovora na zahtjev kupca) odnosno lit. f | [Provjeriti: pravni osnov u odnosu na primaoca poklona] |
| Transakcijski e-mailovi gostima (kartica kupljena, dopunjena, uskoro ističe, nisko stanje) | čl. 6 st. 1 lit. b GDPR (informacija o ugovoru o poklon bonu); dodatno lit. f | Samo ako je restoran uključio „Customer e-mails". Bez reklame u tim e-mailovima. [Provjeriti: kvalifikacija podsjetnika o isteku] |
| Čuvanje dnevnika knjiženja (prodaja, iskorištavanje, dopuna, storno) | čl. 6 st. 1 lit. c GDPR u vezi s § 132 BAO (7 godina) | Knjiženja se ne brišu pri anonimizaciji kupca. |
| Sigurnosni zapisi (audit log, zapisnik NFC skeniranja, uređaji, IP pri prijavi) | čl. 6 st. 1 lit. f GDPR (legitimni interes: zaštita od prevare i zloupotrebe, sljedivost novčanih kretanja) | Dokumentovati odvagivanje interesa (vidi 3.1). |
| Korisnički računi zaposlenih | čl. 6 st. 1 lit. b GDPR (ugovor o radu) odnosno lit. f; poštovati austrijsko radno-ustavno pravo (§§ 96, 96a ArbVG) | [Provjeriti: sporazum s radničkim vijećem (Betriebsvereinbarung) kod kontrolnih mjera odnosno sistema ličnih podataka, ako postoji radničko vijeće] |
| Reklamni e-mailovi gostima (newsletter, akcije) | **Pristanak**, čl. 6 st. 1 lit. a GDPR i § 174 TKG 2021 | GiftCard Pro ne šalje reklame. Polje **Marketing consent** samo bilježi da li pristanak postoji. [Provjeriti: paragraf TKG 2021] |
| Vlastiti podaci o klijentima i računima pružaoca usluge | čl. 6 st. 1 lit. b i c GDPR | Vidi [Izjavu o zaštiti podataka](privacy-policy.md). |

### 3.1 Odvagivanje interesa za sigurnosne zapise (sažetak)

- **Interes:** Poklon kartica je novac. Restoran mora moći utvrditi ko je, kada, na kojem uređaju i koji iznos knjižio te prepoznati prevaru (klonirane kartice, ponovljena skeniranja, preuzimanje računa).
- **Nužnost:** Bilježe se samo tehnički identifikatori (korisnik, uređaj, IP adresa, user agent, vrijeme, radnja). Imena, e-mail adrese, brojevi telefona, bilješke i imena primalaca poklona **ne** kopiraju se u audit log — bilježi se samo činjenica da su promijenjeni. Lozinke i tokeni se zatamnjuju.
- **Očekivanja ispitanika:** Zaposleni koji rade s novčanim vrijednostima moraju računati s bilježenjem; o tome ih treba informisati.
- **Rezultat:** Prevladava legitimni interes, pod uslovom da je rok čuvanja ograničen i da pristup imaju samo vlasnik/vlasnica i menadžer. [Provjeriti: rok čuvanja, vidi odjeljak 4]

## 4. Inventar podataka

Sljedeća tabela opisuje kategorije podataka koje se stvarno čuvaju u GiftCard Pro.

| Kategorija | Polja | Ispitanici | Svrha | Pravni osnov | Rok čuvanja |
|---|---|---|---|---|---|
| Podaci o kupcu (neobavezno) | ime, prezime, e-mail, telefon, bilješke, pristanak na marketing (da/ne) | gosti (kupci) | dodjela kartica, pomoć pri gubitku, transakcijski e-mailovi | čl. 6 st. 1 lit. b; marketing: lit. a | do anonimizacije od strane restorana odnosno kraj ugovora + 30 dana; [Provjeriti: koncept brisanja restorana, npr. X godina nakon posljednjeg korištenja kartice] |
| Podaci o kartici | broj kartice, token (UUID), status, stanje, rok važenja, ime primaoca, interne bilješke, serijski broj čipa, brojač čipa | gosti (kupac, primalac poklona) | upravljanje poklon bonovima, zaštita od krivotvorenja | čl. 6 st. 1 lit. b, f | ime primaoca i bilješke: do anonimizacije; podaci o kartici bez ličnih podataka: kao dnevnik knjiženja |
| Dnevnik knjiženja (transakcije) | vrsta, iznos, stanje prije/poslije, vrijeme, korisnik, uređaj, IP adresa, referenca, bilješka | gosti (posredno), zaposleni | dokaz svih novčanih kretanja, knjigovodstvo | čl. 6 st. 1 lit. c (§ 132 BAO), lit. f | 7 godina (BAO); nepromjenjiv; brisanje kod pružaoca usluge 30 dana nakon kraja ugovora — restoran mora prethodno izvesti podatke |
| Korisnički računi (osoblje) | ime, e-mail, uloga, status, jezik, posljednja prijava (vrijeme, IP), lozinka (bcrypt hash), neuspjele prijave | zaposleni u restoranu | pristup, ovlaštenja, zaštita računa | čl. 6 st. 1 lit. b, f | tokom trajanja ugovora; deaktivirani računi ostaju radi sljedivosti [Provjeriti: rok] |
| Uređaji | naziv, vrsta, platforma/user agent, otisak uređaja (hash nasumičnog ID-a uređaja), posljednja IP adresa, posljednje viđen, posljednji prijavljeni korisnik | zaposleni | vezivanje za uređaj, blokiranje izgubljenih uređaja | čl. 6 st. 1 lit. f | tokom trajanja ugovora [Provjeriti: rok za opozvane uređaje] |
| Audit log | radnja, korisnik, uređaj, stare/nove vrijednosti (bez podataka gostiju, tajne zatamnjene), IP adresa, user agent, ID zahtjeva, vrijeme | zaposleni, posredno gosti | sigurnost, sljedivost | čl. 6 st. 1 lit. f | trenutno neograničeno tokom trajanja ugovora (samo dodavanje) [Provjeriti: odrediti maksimalni rok, npr. 7 godina za unose vezane uz novac, kraće za ostale] |
| Zapisnik NFC skeniranja | kartica (ako je pronađena), korisnik, uređaj, metoda, rezultat, UID čipa, brojač, IP adresa, user agent | zaposleni (skeniranja u aplikaciji za konobare; javna provjera stanja od strane gostiju se ovdje ne bilježi) | otkrivanje prevare (klonovi, ponavljanja, ograničenje učestalosti) | čl. 6 st. 1 lit. f | trenutno neograničeno tokom trajanja ugovora [Provjeriti: rok, npr. 12 mjeseci] |
| Zapisnik slanja e-mailova | predložak, adresa primaoca, status, vrijeme | gosti, zaposleni | dokaz dostave | čl. 6 st. 1 lit. f | e-mail adresa se uklanja pri anonimizaciji [Provjeriti: rok] |
| API tokeni | naziv, hash, ovlaštenja, posljednja upotreba (vrijeme, IP) | zaposleni | integracije (npr. kasa) | čl. 6 st. 1 lit. b, f | važe najviše 365 dana; opozvani tokeni ostaju zabilježeni |
| Sesije | ID sesije, korisnik, uređaj | zaposleni | prijava | čl. 6 st. 1 lit. b | 8 sati neaktivnosti |
| Sigurnosne kopije | cijela baza podataka | svi navedeni | obnova | čl. 6 st. 1 lit. f, čl. 32 | rotirajuće oko 14 dana (lokalno i eksterno kod Hetznera) + dnevni snimci servera |
| Logovi web servera | IP adresa, vrijeme, URL, user agent, statusni kod | svi koji pristupaju | rad sistema, otkrivanje napada | čl. 6 st. 1 lit. f | [Provjeriti: odrediti rok, npr. 14 dana] |

**Posebne kategorije** (čl. 9 GDPR) nisu predviđene. Restorani u slobodna tekstualna polja (**Internal notes**, bilješke o kupcu) ne bi trebali unositi zdravstvene podatke (npr. alergije), podatke o platnim karticama niti druge osjetljive podatke.

**Smanjenje količine podataka u proizvodu:** podaci o kupcu nisu obavezni (može se odabrati **Anonymous**), kartica ne nosi lične podatke, javna stranica za provjeru stanja prikazuje samo stanje, status, rok važenja i maskirani broj kartice i može se isključiti.

> **Napomena o ograničenju pohrane (čl. 5 st. 1 lit. e GDPR):** Radi integriteta, GiftCard Pro u redovnom radu ne briše zapise (soft delete, nepromjenjiv dnevnik i audit log). Lični podaci gostiju mogu se u svakom trenutku ukloniti anonimizacijom. Za audit log, zapisnik NFC skeniranja i zapisnik e-mailova treba predvidjeti automatsko čišćenje nakon utvrđenih rokova. [Provjeriti: utvrditi rokove; tehnička realizacija je na planu razvoja pružaoca usluge]

## 5. Prava ispitanika i njihovo ostvarivanje u proizvodu

Zahtjevi gostiju upućuju se restoranu (voditelju obrade). Pružalac usluge pomaže prema čl. 28 st. 3 lit. e GDPR. Rok: u pravilu **jedan mjesec** od prijema (čl. 12 st. 3 GDPR), uz obrazloženo produženje za dva mjeseca kod složenih zahtjeva.

| Pravo | Član | Kako ga ostvarujete u GiftCard Pro |
|---|---|---|
| Pristup | čl. 15 | **Customers** → otvoriti kupca → pogledati osnovne podatke i dodijeljene kartice. Historija kartice na stranici pojedine kartice. Za kopiju: u **Gift cards** odnosno **Transactions** filtrirati po kupcu/broju kartice i **Export CSV**. Dodatno navesti: svrhe, primaoce (pružalac usluge kao izvršitelj obrade, Hetzner), rok čuvanja, prava. |
| Ispravka | čl. 16 | **Customers** → kupac → uređivanje; ime primaoca na kartici putem **⋯ → Edit details**. |
| Brisanje | čl. 17 | **Customers** → kupac → **Anonymize** (anonimizacija prema GDPR-u). Uklanja ime, e-mail, telefon, bilješke kupca i imena primalaca na njegovim karticama; uklanjaju se i e-mail adrese u zapisniku slanja. **Knjiženja ostaju** — obaveza čuvanja prema § 132 BAO (čl. 17 st. 3 lit. b GDPR). Stanje na kartici ostaje iskoristivo. |
| Ograničenje obrade | čl. 18 | Ne koristiti dalje podatke o kupcu, po potrebi blokirati karticu uz obrazloženje (**Block card**) ili zabilježiti u bilješkama; po potrebi kontaktirati pružaoca usluge. |
| Prenosivost | čl. 20 | Izvoz u CSV (strukturirano, mašinski čitljivo). |
| Prigovor | čl. 21 | Provjeriti kod obrada na osnovu lit. f; isključiti e-mailove tom gostu (ukloniti ili anonimizirati podatke o kupcu). Prigovor na reklamu: isključiti **Marketing consent** — uvijek poštovati. |
| Povlačenje pristanka | čl. 7 st. 3 | Isključiti **Marketing consent**; dokumentovati datum povlačenja. |
| Zaposleni | čl. 15–21 | **Team** → uređivanje/deaktivacija osobe; informacije o prijavama i unosima u audit logu putem **Audit log** (filter po osobi) — po potrebi uz pomoć podrške. |

**Provjera identiteta:** informacije dati samo osobama čije je pravo dokazano (npr. potvrda na sačuvanu e-mail adresu). Sam broj kartice nije dokaz identiteta.

**Dokumentacija:** svaki zahtjev evidentirati s datumom, sadržajem, odgovorom i datumom odgovora.

## 6. Procjena učinka na zaštitu podataka (DPIA, čl. 35 GDPR)

**Procjena: procjena učinka vjerovatno nije potrebna.** [Provjeriti: potvrditi u konkretnom slučaju]

Obrazloženje:

- Nema posebnih kategorija ličnih podataka (čl. 9, 10 GDPR).
- Nema profilisanja, automatizovanog odlučivanja s pravnim učinkom, bodovanja ni analize u reklamne svrhe.
- Nema sistematskog nadzora javno dostupnih prostora; nema podataka o lokaciji.
- Mala količina podataka po restoranu; podaci o kupcima nisu obavezni.
- Bilježenje aktivnosti zaposlenih služi sljedivosti novčanih knjiženja i ograničeno je na knjiženja i sigurnosne događaje; nije kontrola učinka ni ponašanja.
- Kriterije austrijske uredbe o listi obrada za koje je procjena obavezna (DSFA-V) i uredbe o izuzecima (DSFA-AV) treba uporediti u konkretnom slučaju. [Provjeriti: važeća verzija]

Procjena učinka se preporučuje ako restoran GiftCard Pro kombinuje s opsežnim profilima kupaca, marketinškim analizama ili povezivanjem s drugim sistemima (npr. program lojalnosti).

## 7. Evidencija aktivnosti obrade (čl. 30 GDPR) — predložak

### 7.1 Za restoran (voditelj obrade)

| Polje | Unos |
|---|---|
| Voditelj obrade | [Naziv restorana / pravni subjekt], [adresa], [e-mail], [telefon] |
| Predstavnik / službenik za zaštitu podataka | [ako je imenovan; inače „nije imenovan"] |
| Naziv obrade | Upravljanje poklon karticama (GiftCard Pro) |
| Svrhe | prodaja, izdavanje, iskorištavanje i upravljanje poklon karticama; usluga kupcima (gubitak, zamjena); transakcijski e-mailovi; zaštita od prevare; knjigovodstvo |
| Kategorije ispitanika | gosti (kupci, primaoci poklona), zaposleni |
| Kategorije ličnih podataka | gosti: ime, e-mail, telefon, bilješke, pristanak na marketing, ime primaoca, podaci o kartici, knjiženja. Zaposleni: ime, e-mail, uloga, vrijeme/IP prijave, uređaji, unosi u audit logu |
| Pravni osnovi | čl. 6 st. 1 lit. b, c, f GDPR; marketing: lit. a |
| Primaoci | [Naziv firme] (izvršitelj obrade, GiftCard Pro); podizvršitelji prema Prilogu 3 Ugovora o obradi; porezni savjetnik [naziv]; organi vlasti kod zakonske obaveze |
| Prijenos u treće zemlje | nema [Provjeriti: pružalac usluge slanja e-mailova] |
| Rokovi brisanja | knjiženja 7 godina (§ 132 BAO); podaci o kupcima [npr. 3 godine nakon posljednjeg korištenja kartice odnosno na zahtjev]; sigurnosni zapisi [rok] |
| Tehničke i organizacijske mjere | upućivanje na Prilog 2 Ugovora o obradi i vlastite mjere u restoranu (zaštita uređaja, upravljanje računima) |

### 7.2 Za pružaoca usluge kao izvršitelja obrade (čl. 30 st. 2)

| Polje | Unos |
|---|---|
| Izvršitelj obrade | [Naziv firme], [pravni oblik], [adresa], 1xxx Beč, datenschutz@giftcardpro.at |
| Voditelji obrade | svi restorani s aktivnim ugovorom (lista klijenata: [vodi se interno, lokacija]) |
| Kategorije obrada | hosting i rad GiftCard Pro; pohrana i obrada podataka o poklon bonovima, kupcima i korisnicima; slanje transakcijskih e-mailova; sigurnosne kopije; podrška |
| Prijenos u treće zemlje | nema [Provjeriti: pružalac usluge slanja e-mailova] |
| Tehničke i organizacijske mjere | Prilog 2 Ugovora o obradi |

### 7.3 Za pružaoca usluge kao voditelja obrade

Vlastiti unosi za: upravljanje klijentima i ugovorima, izdavanje računa, podršku, web stranicu i kontakt upite, upravljanje potencijalnim klijentima, upravljanje vlastitim zaposlenima. Sadržaj vidi u [Izjavi o zaštiti podataka](privacy-policy.md).

## 8. Tehničke i organizacijske mjere (sažetak)

Potpuna lista nalazi se u Prilogu 2 [Ugovora o obradi podataka po nalogu](data-processing-agreement.md).

- **Razdvajanje klijenata:** svaki restoran vidi isključivo svoje podatke; tehnički osigurano na više nivoa i automatski testirano.
- **Nema vrijednosti na kartici:** samo nasumični 122-bitni link; brojevi kartica nasumični, ne uzastopni.
- **Integritet novčanih knjiženja:** atomarno uz zaključavanje reda u bazi, idempotentno (bez dvostrukih knjiženja), nepromjenjiv dnevnik; storno kao protuknjiženje.
- **Zaštita pristupa:** lozinke najmanje 12 znakova s velikim i malim slovima i brojem, bcrypt hash; ograničenje učestalosti; zaključavanje računa nakon 10 neuspjelih pokušaja na 15 minuta; pozivni linkovi (72 h) umjesto slanja lozinke; link za reset lozinke važi 60 minuta.
- **Uloge i ovlaštenja:** vlasnik/vlasnica, menadžer, konobar/konobarica; konobari mogu samo skenirati i iskorištavati (i eventualno blokirati).
- **Vezivanje uređaja i sesije:** sesija vezana za uređaj, opozvani uređaji odmah blokirani, kraj sesije nakon 8 sati neaktivnosti.
- **Zaštita od krivotvorenja:** vezivanje za serijski broj čipa (NTAG21x), kriptografski potpis i brojač (NTAG 424 DNA).
- **Prijenos i aplikacija:** isključivo HTTPS (TLS, HSTS), sigurnosna zaglavlja, Content-Security-Policy, CSRF zaštita, bez cross-origin pristupa, bez kolačića za praćenje.
- **Bilježenje:** nepromjenjiv audit log s osobom, uređajem, IP adresom i vremenom; podaci gostiju i tajne se ne bilježe.
- **Dostupnost:** hosting kod Hetznera u Njemačkoj; noćne sigurnosne kopije baze (14 dana) plus eksterna kopija; dnevni snimci servera; provjera ispravnosti (health check).
- **Organizacijski:** obaveza čuvanja tajnosti podataka (§ 6 DSG); pristup pružaoca usluge podacima restorana samo u slučaju podrške putem funkcije „Open restaurant", uz obavještajni baner i potpuno bilježenje.

## 9. Međunarodni prijenosi podataka

- Standardno: **nema prijenosa u treće zemlje**. Hosting i sigurnosne kopije su kod Hetzner Online GmbH u podatkovnim centrima u Njemačkoj.
- **Slanje e-mailova:** pružaoca usluge slanja e-mailova ([pružalac usluge slanja e-mailova s hostingom u EU]) treba provjeriti prije sklapanja ugovora: lokacija servera, matična firma u trećoj zemlji, pristup iz trećih zemalja (podrška, održavanje), podizvršitelji. Kod veze s trećom zemljom potrebna je odluka o primjerenosti (npr. EU-US Data Privacy Framework, provjeriti certifikaciju) ili standardne ugovorne klauzule s procjenom učinka prijenosa. [Provjeriti]
- **Pružalac platnih usluga** (ako se koristi, npr. Stripe Payments Europe Ltd.): obrađuje samo podatke o naplati pružaoca usluge, ne podatke gostiju restorana. Provjeriti vezu s trećom zemljom unutar koncerna. [Provjeriti]

## 10. Povreda zaštite ličnih podataka

### 10.1 Obaveze

- **Restoran (voditelj obrade):** prijava austrijskom tijelu za zaštitu podataka **u roku od 72 sata** od saznanja, osim ako nije vjerovatno da povreda predstavlja rizik za ispitanike (čl. 33 GDPR). Obavještavanje ispitanika kod vjerovatno visokog rizika (čl. 34 GDPR). Dokumentovanje svake povrede, i kada nema prijave (čl. 33 st. 5).
- **Pružalac usluge (izvršitelj obrade):** obavještavanje restorana **bez nepotrebnog odlaganja**, ciljna vrijednost **najkasnije 48 sati** od saznanja (čl. 33 st. 2 GDPR; vidi § 9 Ugovora o obradi), sa svim dostupnim informacijama; naknadna dopuna je dozvoljena.
- **Pružalac usluge kao voditelj obrade** (vlastiti podaci o klijentima): vlastita prijava prema čl. 33/34.

### 10.2 Postupak kod pružaoca usluge

1. **Prepoznati i prijaviti:** svako zapažanje na security@giftcardpro.at. Prate se sigurnosna upozorenja u audit logu (klonirana kartica, kopirano NFC skeniranje, strana kartica, zaključan račun) i logovi aplikacije.
2. **Ograničiti:** blokirati pogođene račune, tokene ili uređaje; promijeniti pristupne podatke; zatvoriti propust.
3. **Procijeniti:** koji podaci, koji restorani, koliko ispitanika, kakav rizik?
4. **Informisati:** pogođene restorane o vrsti, kategorijama i približnom broju ispitanika, vjerovatnim posljedicama i preduzetim mjerama; imenovati kontakt osobu.
5. **Pomoći:** predlošci i informacije za prijavu restorana tijelu za zaštitu podataka i eventualno ispitanicima.
6. **Dokumentovati i analizirati:** zapisnik o povredi, analiza uzroka, mjere.

### 10.3 Postupak u restoranu

- Izgubljen ili ukraden telefon: u **Devices** odmah **Revoke**; provjeriti račun osobe, po potrebi resetovati lozinku.
- Sumnja na neovlašten pristup: deaktivirati osobu u **Team**, provjeriti **Audit log**, obavijestiti pružaoca usluge.
- Povreda s podacima gostiju: u roku od 72 sata procijeniti i po potrebi prijaviti (obrazac na [dsb.gv.at](https://www.dsb.gv.at)).

## 11. Kontrolna lista za restorane

- [ ] Prihvaćeni i arhivirani Opći uslovi poslovanja i Ugovor o obradi s pružaocem usluge.
- [ ] Evidencija aktivnosti obrade dopunjena stavkom „Poklon kartice (GiftCard Pro)" (predložak 7.1).
- [ ] Obavještenje o zaštiti podataka za goste dodano na kasi odnosno na web stranici (tekstovi ispod).
- [ ] Podatke o kupcima unositi samo kad je potrebno; inače odabrati **Anonymous**.
- [ ] **Marketing consent** uključiti samo ako postoji dokaziv pristanak (datum, tekst, oblik).
- [ ] Bez zdravstvenih podataka, podataka o platnim karticama ili drugih osjetljivih podataka u poljima za bilješke.
- [ ] Uloge dodjeljivati štedljivo; konobari dobijaju ulogu **Waiter**.
- [ ] Zaposleni informisani o bilježenju (prijave, uređaji, knjiženja); po potrebi uključeno radničko vijeće.
- [ ] Zaposleni obavezani na tajnost podataka (§ 6 DSG).
- [ ] Službeni telefoni sa zaključavanjem ekrana; izgubljene uređaje odmah opozvati u **Devices**.
- [ ] Zaposlene koji odlaze deaktivirati u **Team** posljednjeg radnog dana.
- [ ] Utvrđen postupak za zahtjeve za pristup i brisanje (odgovorna osoba, rok od mjesec dana).
- [ ] Utvrđen koncept brisanja podataka o kupcima (npr. anonimizacija X godina nakon posljednjeg korištenja kartice).
- [ ] Prije kraja ugovora izvesti podatke (**Export CSV**) — čuvanje 7 godina obaveza je restorana.

### 11.1 Obavještenje / informativni tekst za goste na kasi (kratka verzija)

> **Zaštita podataka kod poklon kartica**
> Ako pri kupovini poklon kartice navedete ime, e-mail adresu ili broj telefona, obrađujemo te podatke kako bismo Vam dodijelili karticu, slali informacije o kartici i pomogli Vam u slučaju gubitka (čl. 6 st. 1 lit. b GDPR). Navođenje podataka je dobrovoljno — kartice se mogu kupiti i bez imena. Knjiženja na kartici čuvamo 7 godina iz poreznih razloga. Za to koristimo uslugu GiftCard Pro ([Naziv firme], Beč) sa serverima u Njemačkoj. Reklamne e-mailove dobijate samo uz Vaš izričit pristanak. Voditelj obrade: [restoran, adresa, e-mail]. Više na [link na izjavu o zaštiti podataka] ili na upit.

### 11.2 Tekst za izjavu o zaštiti podataka na web stranici restorana

> **Poklon kartice**
> Nudimo poklon kartice s NFC čipom i QR kodom. Na samoj kartici nisu sačuvani ni stanje ni lični podaci, nego samo nasumični link na naš sistem poklon bonova.
>
> *Koji podaci:* broj kartice, stanje, rok važenja, knjiženja (kupovina, iskorištavanje, dopuna); dobrovoljno: ime i prezime, e-mail adresa, broj telefona kupca, ime primaoca poklona, Vaš pristanak na reklamne e-mailove (da/ne).
>
> *Svrhe i pravni osnovi:* izdavanje i iskorištavanje poklon bona i pomoć pri gubitku (čl. 6 st. 1 lit. b GDPR); informativni e-mailovi o Vašoj kartici (npr. potvrda kupovine, napomena prije isteka, nisko stanje) (čl. 6 st. 1 lit. b GDPR); čuvanje knjiženja zbog poreznih obaveza (čl. 6 st. 1 lit. c GDPR u vezi s § 132 BAO); zaštita od zloupotrebe i prevare (čl. 6 st. 1 lit. f GDPR); reklamni e-mailovi samo uz pristanak (čl. 6 st. 1 lit. a GDPR), koji se može povući u svakom trenutku.
>
> *Provjera stanja:* kada karticu skenirate svojim pametnim telefonom, vidite stanje, status i rok važenja. Pritom se tehnički potrebni podaci (IP adresa, vrsta preglednika, vrijeme) kratkoročno obrađuju u serverskim logovima radi pružanja usluge i zaštite od zloupotrebe (čl. 6 st. 1 lit. f GDPR).
>
> *Primaoci:* [Naziv firme], [adresa], Beč, kao naš izvršitelj obrade (operater GiftCard Pro); hosting kod Hetzner Online GmbH u Njemačkoj; [pružalac usluge slanja e-mailova] za slanje e-mailova; naš porezni savjetnik. Prijenos u zemlje izvan EU se ne vrši. [Provjeriti]
>
> *Rok čuvanja:* knjiženja 7 godina; Vaši kontakt podaci do Vašeg zahtjeva za brisanje odnosno [X godina] nakon posljednjeg korištenja kartice. Pri brisanju se Vaši podaci anonimiziraju; stanje na kartici ostaje.
>
> *Vaša prava:* pristup, ispravka, brisanje, ograničenje obrade, prenosivost podataka, prigovor, povlačenje pristanka te pritužba austrijskom tijelu za zaštitu podataka (Barichgasse 40–42, 1030 Beč, www.dsb.gv.at). Kontakt: [e-mail restorana].

---

Verzija 1.0 · Stanje: septembar 2026.
