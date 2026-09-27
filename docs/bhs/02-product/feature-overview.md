# Pregled funkcija GiftCard Pro

*Potpuni katalog svih funkcija, grupisan po područjima, s dostupnošću po paketu i statusom. Za prodaju, ponude, podršku i korisnike koji žele tačno znati šta je uključeno.*

---

## Legenda

| Znak | Značenje |
|---|---|
| ✓ | uključeno u paket |
| — | nije uključeno u paket |
| otvoreno | paket će biti određen pri objavljivanju |
| **dostupno** | danas se može koristiti u proizvodu |
| **planirano Qx GGGG** | u planu razvoja, ciljni kvartal (nije obećanje, vidi [plan razvoja](product-roadmap.md)) |
| **u provjeri** | razjašnjavaju se izvodljivost ili partneri |

Paketi: **Start** 29 € / mjesečno · **Pro** 59 € / mjesečno · **Gruppe** (grupa) od 129 € / mjesečno (do 3 lokacije, + 39 € po svakoj dodatnoj). Sve cijene su neto, uz dodatak 20 % PDV-a (Austrija). Probni period od 30 dana uključuje sve Pro funkcije.

Interfejs za osoblje je trenutno na engleskom. Engleski nazivi napisani su **podebljano**, npr. **„Redeem"** (iskoristi).

---

## 1. Kartice

![Kreiranje nove poklon kartice](../../screenshots/new-card.png)

| Funkcija | Opis | Start | Pro | Gruppe | Status |
|---|---|:-:|:-:|:-:|---|
| Kreiranje kartice (**New gift card**) | Vrijednost brzim izborom (25 / 50 / 75 / 100 / 150 €) ili slobodno unutar granica; **Create card** | ✓ | ✓ | ✓ | dostupno |
| Rok važenja (**Valid until**) | Zadano iz postavki, vlastiti datum ili „bez isteka"; važi do 23:59 po lokalnom vremenu | ✓ | ✓ | ✓ | dostupno |
| Dodjela kupca | **Anonymous**, **Existing** ili **New customer** (ime, e-mail, telefon) | ✓ | ✓ | ✓ | dostupno |
| Ime primaoca poklona (**Recipient name**) | Štampa se na kartici | ✓ | ✓ | ✓ | dostupno |
| Interne bilješke (**Internal notes**) | Vidljive samo timu, pretražive | ✓ | ✓ | ✓ | dostupno |
| Odmah aktivirati (**Activate immediately**) | Ili karticu prvo kreirati neaktivnu i aktivirati je pri prodaji | ✓ | ✓ | ✓ | dostupno |
| Broj kartice | 16 cifara, slučajan, s kontrolnom cifrom (Luhn), čitljivo formatiran („5285 1058 7098 6488"); opcionalni prefiks | ✓ | ✓ | ✓ | dostupno |
| Vrste kartica NTAG213, NTAG215 (preporučeno), NTAG216 | Standardni NFC čipovi | ✓ | ✓ | ✓ | dostupno |
| Kartice samo s QR kodom | Bez čipa, besplatno se sami štampaju | ✓ | ✓ | ✓ | dostupno |
| Vrsta kartice NTAG 424 DNA | Kriptografski zaštićena od kopiranja (SUN/AES-CMAC, brojač) | — | ✓ | ✓ | dostupno |
| Upis NFC čipa (**Write NFC tag**) | Jedan dodir s Androidom i Chromeom; alternativno kopirati adresu, upisati aplikacijom za NFC, **Mark as written** | ✓ | ✓ | ✓ | dostupno |
| Vezivanje serijskog broja čipa | Pohranjuje serijski broj (UID) za prepoznavanje kopija | ✓ | ✓ | ✓ | dostupno |
| Trajno zaključavanje čipa (**Lock tag after writing**) | Čip postaje zaštićen od upisa, link se ne može prepisati | ✓ | ✓ | ✓ | dostupno |
| Predložak za štampu (**Print card / QR**) | Format bankovne kartice ISO ID-1 (85,6 × 54 mm); prednja strana restoran, vrijednost, primalac; zadnja strana QR kod, broj, rok važenja, napomena; na jeziku restorana | ✓ | ✓ | ✓ | dostupno |
| Statusi | Active, Inactive, Redeemed, Blocked, Expired, Replaced | ✓ | ✓ | ✓ | dostupno |
| Iskorištavanje (**Redeem**) | Potpuno ili djelimično; djelimično iskorištavanje može se isključiti | ✓ | ✓ | ✓ | dostupno |
| Dopuna (**Reload**) | Povećanje stanja; može se isključiti | ✓ | ✓ | ✓ | dostupno |
| Prenos stanja (**Transfer balance**) | Potpuno ili djelimično na drugu karticu | ✓ | ✓ | ✓ | dostupno |
| Zamjenska kartica (**Replace lost card**) | Razlog jednim dodirom (Lost / Damaged / Stolen); stanje prelazi na novu karticu, stara odmah prestaje važiti | ✓ | ✓ | ✓ | dostupno |
| Blokiranje / deblokiranje (**Block card** / **Unblock**) | S razlogom (Reported stolen, Reported lost, Suspicious use) | ✓ | ✓ | ✓ | dostupno |
| Trenutni istek (**Expire now**) | Preostalo stanje knjiži se kao istek | ✓ | ✓ | ✓ | dostupno |
| Aktiviranje (**Activate**) | Aktivira neaktivnu karticu | ✓ | ✓ | ✓ | dostupno |
| Uređivanje detalja (**Edit details**) | Kupac, primalac, bilješke, rok važenja | ✓ | ✓ | ✓ | dostupno |
| Storno (**Reverse**) | Storniranje iskorištavanja ili dopune kao protuknjiženje; razlog jednim dodirom; ništa se ne briše | ✓ | ✓ | ✓ | dostupno |
| Historija kartice | Svako knjiženje i događaj s vremenom, osobom, uređajem i stanjem nakon toga | ✓ | ✓ | ✓ | dostupno |
| Lista kartica | Pretraga (broj, kupac, primalac, bilješka), filter statusa, sortiranje | ✓ | ✓ | ✓ | dostupno |
| Usluga naručivanja kartica | Strukturirano naručivanje štampanih kartica | ✓ | ✓ | ✓ | planirano Q4 2026 |
| Apple Wallet / Google Wallet | Poklon kartica dodatno u telefonu gosta | otvoreno | otvoreno | otvoreno | planirano Q2 2027 |
| Online prodaja poklon bonova | Prodaja na web stranici restorana s plaćanjem, PDF-om i po želji karticom poštom; 0 % naše provizije | otvoreno | otvoreno | otvoreno | planirano Q1 2027 |

Paket za planirane funkcije određuje se pri objavljivanju.

---

## 2. Iskorištavanje / aplikacija za konobare

![Aplikacija za konobare: unos iznosa](../../screenshots/waiter-amount.png)

| Funkcija | Opis | Start | Pro | Gruppe | Status |
|---|---|:-:|:-:|:-:|---|
| Web aplikacija bez App Storea | Radi u pregledniku svakog pametnog telefona, može se instalirati na početni ekran | ✓ | ✓ | ✓ | dostupno |
| Očitavanje NFC-a Androidom (**Scan card**) | Pritisnuti jednom, nakon toga se svaka kartica očitava pri prinošenju (Chrome, Web NFC) | ✓ | ✓ | ✓ | dostupno |
| Očitavanje NFC-a iPhoneom | Prinijeti karticu gornjem rubu, dodirnuti obavještenje (iPhone XS ili noviji) | ✓ | ✓ | ✓ | dostupno |
| Skeniranje QR koda (**Scan QR code**) | Kamerom bilo kojeg telefona | ✓ | ✓ | ✓ | dostupno |
| Unos broja kartice (**Card number**, **Find card**) | Rješenje u nuždi bez čipa i kamere | ✓ | ✓ | ✓ | dostupno |
| Tastatura kao na kasi | `2 4 9 0` → 24,90 € | ✓ | ✓ | ✓ | dostupno |
| Cijelo stanje (**Full balance**) | Jedan dodir za cijeli iznos; napomena ako iznos premašuje stanje | ✓ | ✓ | ✓ | dostupno |
| Dugme za iskorištavanje (**Redeem X €**) | Veliko dugme s iznosom | ✓ | ✓ | ✓ | dostupno |
| Ekran potvrde | Preostalo stanje za gosta, **Next card**, automatski povratak nakon 8 sekundi | ✓ | ✓ | ✓ | dostupno |
| Direktno prinošenje sljedeće kartice | NFC nastavlja očitavati i na ekranu potvrde | ✓ | ✓ | ✓ | dostupno |
| Vibracija kao potvrda | Na Androidu | ✓ | ✓ | ✓ | dostupno |
| Jasna upozorenja | Blokirana/zamijenjena crveno („Ask the guest for the new card"), neaktivna/prazna žuto, istekla, nije pronađena | ✓ | ✓ | ✓ | dostupno |
| Uputstva prilagođena uređaju | iPhone, Android s NFC-om ili bez njega dobijaju odgovarajuće uputstvo | ✓ | ✓ | ✓ | dostupno |
| Mali ekrani | Nije potrebno skrolanje, ni na iPhoneu SE | ✓ | ✓ | ✓ | dostupno |
| Blokiranje iz aplikacije za konobare | Ako uloga to dozvoljava | ✓ | ✓ | ✓ | dostupno |
| Nikad dvostruko knjiženje | Dvostruki dodiri i ponovljeni mrežni zahtjevi se prepoznaju | ✓ | ✓ | ✓ | dostupno |
| Aplikacija za konobare na njemačkom | Interfejs na njemačkom | ✓ | ✓ | ✓ | planirano Q4 2026 |

---

## 3. Kontrolna tabla i izvještaji

| Funkcija | Opis | Start | Pro | Gruppe | Status |
|---|---|:-:|:-:|:-:|---|
| Pokazatelj **Outstanding balance** | Otvorena obaveza („Open liability on N cards") | ✓ | ✓ | ✓ | dostupno |
| Pokazatelj **Revenue this month** | Prodaja kartica plus dopune, u poređenju s prethodnim mjesecom | ✓ | ✓ | ✓ | dostupno |
| Pokazatelj **Redeemed this month** | Iskorišteni iznos u mjesecu i danas | ✓ | ✓ | ✓ | dostupno |
| Pokazatelj **Cards sold** | Prodane kartice ukupno, u mjesecu, u upotrebi | ✓ | ✓ | ✓ | dostupno |
| Grafikon prodano vs. iskorišteno | Po danu, period 7 / 30 / 90 dana | ✓ | ✓ | ✓ | dostupno |
| Grafikon mjesečnog prometa | Posljednjih 12 mjeseci | ✓ | ✓ | ✓ | dostupno |
| Kartice po statusu | Raspodjela svih kartica | ✓ | ✓ | ✓ | dostupno |
| Nedavne aktivnosti | Najnovija knjiženja, **View all** otvara dnevnik | ✓ | ✓ | ✓ | dostupno |
| Područje dobrodošlice (**Welcome**) | Prvi koraci: pravila kartica → pozvati tim → prva kartica → način za konobare | ✓ | ✓ | ✓ | dostupno |
| Dnevnik knjiženja (**Transactions**) | Nepromjenjiv; filteri po datumu, vrsti, pretraga; storno | ✓ | ✓ | ✓ | dostupno |
| CSV izvoz kartica i knjiženja (**Export CSV**) | Tačka-zarez, decimalni zarez, čitljivi statusi i vrste knjiženja — otvara se direktno u Excelu | ✓ | ✓ | ✓ | dostupno |
| Svijetli i tamni način | Na računaru, tabletu i telefonu | ✓ | ✓ | ✓ | dostupno |
| Kontrolna tabla za više lokacija | Sve lokacije jedne grupe u jednom pregledu | — | — | ✓ | planirano Q2 2027 |

![Dnevnik knjiženja](../../screenshots/transactions.png)

---

## 4. Kupci

| Funkcija | Opis | Start | Pro | Gruppe | Status |
|---|---|:-:|:-:|:-:|---|
| Lista kupaca | Svi kupci restorana | ✓ | ✓ | ✓ | dostupno |
| Detalji kupca | Kontakt podaci i sve pripadajuće kartice | ✓ | ✓ | ✓ | dostupno |
| Uređivanje | Ime, e-mail, telefon | ✓ | ✓ | ✓ | dostupno |
| Anonimizacija (GDPR) | Uklanja lične podatke, finansijski podaci ostaju | ✓ | ✓ | ✓ | dostupno |

---

## 5. Tim i uređaji

| Funkcija | Opis | Start | Pro | Gruppe | Status |
|---|---|:-:|:-:|:-:|---|
| Uloge | Owner, Manager, Waiter s vlastitim ovlaštenjima | ✓ | ✓ | ✓ | dostupno |
| Neograničen broj članova tima | Bez troškova po osobi | ✓ | ✓ | ✓ | dostupno |
| Pozivanje (**Invite**) | E-mailom, link važi 72 sata, osoba bira vlastitu lozinku | ✓ | ✓ | ✓ | dostupno |
| Ponovno slanje pozivnice, resetovanje lozinke | Link važi 60 minuta; lozinke se nikad ne šalju e-mailom | ✓ | ✓ | ✓ | dostupno |
| Deaktiviranje / ponovno aktiviranje | Odmah završava sve sesije i API ključeve osobe | ✓ | ✓ | ✓ | dostupno |
| Status | Invited → Active, Locked, Deactivated | ✓ | ✓ | ✓ | dostupno |
| Upravljanje uređajima (**Devices**) | Svaki uređaj se pri prijavi automatski registruje i imenuje (npr. „iPhone · Safari") | ✓ | ✓ | ✓ | dostupno |
| Preimenovanje uređaja | Npr. „Bar iPhone" | ✓ | ✓ | ✓ | dostupno |
| Opoziv / vraćanje uređaja (**Revoke** / **Restore**) | Opozvani uređaj je odmah blokiran; potvrda prije opoziva | ✓ | ✓ | ✓ | dostupno |
| Neograničen broj uređaja | Bez troškova po uređaju | ✓ | ✓ | ✓ | dostupno |

---

## 6. Postavke

| Funkcija | Opis | Start | Pro | Gruppe | Status |
|---|---|:-:|:-:|:-:|---|
| Min./maks. vrijednost kartice | Zadano 5 € / 1.000 € | ✓ | ✓ | ✓ | dostupno |
| Maksimalno stanje kartice | Zadano 2.000 € | ✓ | ✓ | ✓ | dostupno |
| Maksimalno pojedinačno iskorištavanje | Gornja granica po iskorištavanju | ✓ | ✓ | ✓ | dostupno |
| Zadani rok važenja | U mjesecima, 0 = bez isteka. Tvornička postavka 36 mjeseci — **preporučujemo 0** (vidi česta pitanja, pravo) | ✓ | ✓ | ✓ | dostupno |
| Tvornička postavka „neograničeno" | Novi restorani počinju bez isteka | ✓ | ✓ | ✓ | planirano Q4 2026 |
| Granica za prevare | Maks. iskorištavanja po kartici i satu, zadano 10 | ✓ | ✓ | ✓ | dostupno |
| Dozvoliti dopunu | Uklj./isklj. | ✓ | ✓ | ✓ | dostupno |
| Dozvoliti djelimično iskorištavanje | Uklj./isklj. | ✓ | ✓ | ✓ | dostupno |
| Javna stranica stanja | Uklj./isklj. | ✓ | ✓ | ✓ | dostupno |
| Zaštita od kopiranja (vezivanje čipa) | Uklj./isklj. | ✓ | ✓ | ✓ | dostupno |
| Zaključavanje čipova nakon upisa | Uklj./isklj. | ✓ | ✓ | ✓ | dostupno |
| E-mailovi za goste | Uklj./isklj. | ✓ | ✓ | ✓ | dostupno |
| Prefiks broja kartice, boja brenda, podnožje e-maila | Izgled | ✓ | ✓ | ✓ | dostupno |
| Profil restorana | Naziv, pravni naziv, UID broj (PDV), e-mail, telefon, web stranica, adresa | ✓ | ✓ | ✓ | dostupno |
| Jezik i format brojeva | de-AT, de-DE, de-CH, en-GB, en-US | ✓ | ✓ | ✓ | dostupno |
| Vremenska zona | Rok važenja i dnevne vrijednosti prema lokalnom vremenu | ✓ | ✓ | ✓ | dostupno |
| Valuta | Euro | ✓ | ✓ | ✓ | dostupno |
| Valute CHF, BAM, RSD | Za Švicarsku, Bosnu i Hercegovinu, Srbiju | ✓ | ✓ | ✓ | planirano 2028. |

---

## 7. E-mailovi za goste

| Funkcija | Opis | Start | Pro | Gruppe | Status |
|---|---|:-:|:-:|:-:|---|
| Kartica kupljena | Potvrda kupcu | ✓ | ✓ | ✓ | dostupno |
| Kartica dopunjena | Potvrda s novim stanjem | ✓ | ✓ | ✓ | dostupno |
| Kartica uskoro ističe | 30 dana prije isteka | ✓ | ✓ | ✓ | dostupno |
| Nisko stanje | Ispod 5 € | ✓ | ✓ | ✓ | dostupno |
| Uređivanje predložaka | Njemački i engleski, naslov i tekst, pregled sa stvarnim imenom restorana | ✓ | ✓ | ✓ | dostupno |
| Predlošci na BHS | S ulaskom na tržište | ✓ | ✓ | ✓ | planirano 2028. |

E-mailovi se šalju samo ako je unesena e-mail adresa i funkcija je uključena.

---

## 8. Gosti: stranica stanja

| Funkcija | Opis | Start | Pro | Gruppe | Status |
|---|---|:-:|:-:|:-:|---|
| Samostalna provjera stanja | Prinijeti karticu vlastitom telefonu ili skenirati QR kod | ✓ | ✓ | ✓ | dostupno |
| Prikazani podaci | Stanje, status, rok važenja, maskirani broj kartice — bez ličnih podataka | ✓ | ✓ | ✓ | dostupno |
| Jezik | Jezik restorana (njemački ili engleski) | ✓ | ✓ | ✓ | dostupno |
| Može se isključiti | U postavkama | ✓ | ✓ | ✓ | dostupno |

---

## 9. Sigurnost

| Funkcija | Opis | Start | Pro | Gruppe | Status |
|---|---|:-:|:-:|:-:|---|
| Nema novca na kartici | Samo slučajna 122-bitna oznaka u linku | ✓ | ✓ | ✓ | dostupno |
| Atomska, idempotentna knjiženja | Zaključavanje u bazi, nikad dvostruko knjiženje; testirano s 20 istovremenih iskorištavanja | ✓ | ✓ | ✓ | dostupno |
| Nepromjenjivi dnevnik | Zbir dnevnika = stanje | ✓ | ✓ | ✓ | dostupno |
| Prepoznavanje kopija NTAG21x | Vezivanje za serijski broj čipa (kod skeniranja Androidom) | ✓ | ✓ | ✓ | dostupno |
| Zaštita od kopiranja NTAG 424 DNA | Kriptografski potpis i brojač; kopije i ponavljanja se odbijaju | — | ✓ | ✓ | dostupno |
| Zaštita od pogađanja | Ograničenja zahtjeva, zaključavanje računa nakon 10 neuspjelih pokušaja (15 minuta), usporena pretraga kartica | ✓ | ✓ | ✓ | dostupno |
| Sesije vezane za uređaj | Kopirane sesije ne rade na drugim uređajima; promjena lozinke odjavljuje ostale sesije | ✓ | ✓ | ✓ | dostupno |
| Pravila lozinki | Najmanje 12 znakova, velika i mala slova, cifra; bcrypt | ✓ | ✓ | ✓ | dostupno |
| Zapisnik aktivnosti (**Audit log**) | Svaka radnja relevantna za sigurnost ili novac s osobom, vremenom, IP adresom; upozorenja (kopirana kartica, kopirano prinošenje, strana kartica, zaključan račun) označena crveno | ✓ | ✓ | ✓ | dostupno |
| Odvojenost korisnika | Svaki restoran vidi samo svoje podatke | ✓ | ✓ | ✓ | dostupno |
| Šifrovani prenos | Samo HTTPS (TLS, HSTS), CSP, CSRF zaštita | ✓ | ✓ | ✓ | dostupno |
| Sigurnosne kopije | Noćne, 14 dana lokalno plus kopija na drugoj lokaciji; dnevni snimci servera | ✓ | ✓ | ✓ | dostupno |

---

## 10. Zaštita podataka

| Funkcija | Opis | Start | Pro | Gruppe | Status |
|---|---|:-:|:-:|:-:|---|
| Hosting u EU | Hetzner Online GmbH, podatkovni centri u Njemačkoj | ✓ | ✓ | ✓ | dostupno |
| Ugovor o obradi podataka po nalogu | Restoran je voditelj obrade, pružalac je izvršitelj obrade (čl. 28 GDPR) | ✓ | ✓ | ✓ | dostupno |
| Samo neophodni kolačići | Bez analitičkih, oglasnih ili kolačića trećih strana u aplikaciji | ✓ | ✓ | ✓ | dostupno |
| Kupac opcionalan | Kartice se mogu prodavati anonimno | ✓ | ✓ | ✓ | dostupno |
| Anonimizacija | Uklanjanje ličnih podataka, finansijski podaci ostaju (obaveza čuvanja) | ✓ | ✓ | ✓ | dostupno |
| Bez ličnih podataka u zapisniku aktivnosti | Izmjene se bilježe kao „[personal data]" | ✓ | ✓ | ✓ | dostupno |
| Izvoz podataka | U svakom trenutku; brisanje 30 dana nakon isteka ugovora (osim zakonskog čuvanja) | ✓ | ✓ | ✓ | dostupno |

---

## 11. Administracija platforme (operater)

Ove funkcije koristi operater platforme GiftCard Pro, a ne restoran. Ovdje su navedene radi potpunosti.

![Administracija platforme](../../screenshots/platform-admin.png)

| Funkcija | Opis | Status |
|---|---|---|
| Kreiranje restorana | Kreira korisnički prostor i pozivnicu za vlasnika | dostupno |
| Suspendovanje / ponovno aktiviranje restorana | S razlogom | dostupno |
| **Open restaurant** | Rad unutar restorana (npr. za podršku), s vidljivim bannerom upozorenja, potpuno zabilježeno | dostupno |
| Zapisnik aktivnosti platforme | Sve radnje na platformi | dostupno |
| Sistemske postavke | Zadani paket, obavještenje o održavanju, e-mail podrške | dostupno |
| Automatsko obračunavanje | Stripe, SEPA direktno zaduženje | planirano Q4 2026 |

---

## 12. Integracije i API

| Funkcija | Opis | Start | Pro | Gruppe | Status |
|---|---|:-:|:-:|:-:|---|
| REST API | Kartice, knjiženja, iskorištavanje, dopuna, prenos, kupci, pokazatelji, izvozi | — | ✓ | ✓ | dostupno |
| API ključevi (**Settings → API**) | Ograničena ovlaštenja, važe najviše 365 dana, mogu se opozvati u svakom trenutku, bilježi se posljednja upotreba | — | ✓ | ✓ | dostupno |
| Idempotentna knjiženja preko API-ja | Ponovljeni zahtjevi nikad ne knjiže dvaput | — | ✓ | ✓ | dostupno |
| Povezivanje s kasama ready2order, orderbird, SumUp POS | Gotove integracije | — | ✓ | ✓ | u provjeri (Q1 2027) |
| CSV izvoz | Za poreznog savjetnika i knjigovodstvo | ✓ | ✓ | ✓ | dostupno |

---

## 13. Postavljanje i podrška

| Usluga | Start | Pro | Gruppe | Status |
|---|:-:|:-:|:-:|---|
| Video postavljanje | ✓ | ✓ | ✓ | dostupno |
| Lično postavljanje (na daljinu ili na licu mjesta u Beču) | — | ✓ | ✓ | dostupno |
| Postavljanje i obuka tima na licu mjesta (jednokratno 149 €, za pilot-restorane besplatno) | opcionalno | opcionalno | ✓ | dostupno |
| Podrška e-mailom, odgovor u roku od 1 radnog dana | ✓ | ✓ | ✓ | dostupno |
| Podrška telefonom, prioritet (4 radna sata) | — | ✓ | ✓ | dostupno |
| Pomoć pri dizajnu kartice | — | ✓ | ✓ | dostupno |
| Centralna kontakt osoba, individualni ugovor/SLA | — | — | ✓ | dostupno |

---

Verzija 1.0 · Stanje: septembar 2026.
