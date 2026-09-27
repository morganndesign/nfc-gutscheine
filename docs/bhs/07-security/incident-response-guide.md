# Vodič za odgovor na incidente

*Kako GiftCard Pro otkriva, procjenjuje, obuzdava i obrađuje sigurnosne incidente – s kontrolnim listama, playbookovima i predlošcima za prijavu povreda zaštite podataka. Za operativni tim GiftCard Pro i radi informacije restorana.*

> **Napomena:** Navodi o GDPR-u nisu pravni savjet. U konkretnom slučaju provjeriti s advokatom odnosno savjetnikom za zaštitu podataka.

---

## 1. Šta je sigurnosni incident?

Sigurnosni incident je svaki događaj koji narušava ili bi mogao narušiti **povjerljivost, integritet ili dostupnost** GiftCard Pro, stanja na karticama ili ličnih podataka. Primjeri:

- neovlašten pristup računu restorana ili administracije platforme,
- kopirane ili izmanipulisane kartice, neuobičajena iskorištavanja,
- gubitak uređaja s otvorenom sesijom,
- objavljen ili proslijeđen API token,
- znaci pristupa serveru, bazi podataka ili sigurnosnim kopijama,
- povreda zaštite podataka (čl. 4 tač. 12 GDPR-a): uništenje, gubitak, izmjena, neovlašteno otkrivanje ličnih podataka ili neovlašten pristup njima.

---

## 2. Faze

| Faza | Cilj | Ključni zadaci |
|---|---|---|
| **1. Pripremiti** | biti spreman za djelovanje prije nego što se nešto dogodi | odrediti uloge i zamjenu, lista kontakata, pristupi (menadžer lozinki, Hetzner, GitHub, DNS), postavljeni zapisnici i upozorenja, vježbe |
| **2. Otkriti** | rano primijetiti incidente | sigurnosna upozorenja u zapisniku aktivnosti i zapisniku aplikacije (`warning`: *Suspicious gift card scan*, *Account locked*), nadzor dostupnosti preko `/up`, prijave restorana na security@, nadzor redova čekanja |
| **3. Analizirati** | odrediti vrstu, obim i nivo ozbiljnosti | vremenska linija, pogođeni restorani, kartice, korisnici, podaci; provjeriti vezu sa zaštitom podataka |
| **4. Obuzdati** | zaustaviti štetu | blokirati uređaje, deaktivirati korisnike, opozvati tokene, blokirati kartice, suspendovati restoran, izolovati server |
| **5. Otkloniti** | ukloniti uzrok | otkloniti slabost, obnoviti tajne, ponovo izgraditi kompromitovane sisteme |
| **6. Oporaviti** | siguran normalan rad | osloboditi servise, ispraviti podatke (storna, zamjenske kartice), pojačano nadzirati |
| **7. Učiti** | spriječiti ponavljanje | izvještaj, mjere, dopuniti testove, ažurirati dokumentaciju |

---

## 3. Nivoi ozbiljnosti

| Nivo | Opis | Primjeri | Reakcija | Informisanje restorana |
|---|---|---|---|---|
| **SEV-1 kritično** | šteta na nivou cijele platforme ili sumnja na odliv podataka | server kompromitovan, preuzet račun administratora platforme, izvod iz baze podataka u opticaju, probijeno odvajanje klijenata | odmah, 24/7 | svi odnosno svi pogođeni, bez odgađanja |
| **SEV-2 visoko** | šteta u jednom ili nekoliko restorana, pogođeni novac ili lični podaci | preuzet Owner račun, talas kopiranja sa štetom, objavljen API token s pravima pisanja | u roku od 1 sata | pogođeni restorani bez odgađanja |
| **SEV-3 srednje** | ograničen rizik, obuzdan ili bez štete | odbijena pojedinačna kopirana kartica, izgubljen i blokiran telefon, brute-force pokušaj sa zaključavanjem računa | istog radnog dana | pogođeni restoran |
| **SEV-4 nisko** | upadljivost bez prepoznatljivog rizika | pojedinačni neuspjeli pokušaji, skeniranje strane kartice | u redovnom radu | nije potrebno |

U slučaju sumnje odabrati **viši** nivo i kasnije ga smanjiti.

---

## 4. Uloge

| Uloga | Zadatak |
|---|---|
| **Rukovodstvo incidenta** | koordinira, odlučuje o nivou ozbiljnosti, mjerama i komunikaciji; vodi vremensku liniju |
| **Tehnika** | analiza, obuzdavanje, otklanjanje, osiguranje dokaza |
| **Komunikacija** | obavještava restorane, po potrebi partnere i javnost; koristi predloške |
| **Zaštita podataka** | provjerava postoji li povreda zaštite podataka; priprema informacije za voditelje obrade odnosno prijavu tijelu za zaštitu podataka; kontakt datenschutz@giftcardpro.at |
| **Restoran (korisnik)** | provodi mjere u vlastitom računu (uređaji, tim, kartice); kao voditelj obrade nadležan za prijavu tijelu za zaštitu podataka kod podataka o gostima |

U malom timu jedna osoba preuzima više uloga. Rukovodstvo incidenta je kod [Ime], osnivačica, zamjena [Ime].

---

## 5. Prvih 60 minuta

**Minuta 0–15: Evidentirati**

- [ ] Dokumentovati prijavu odnosno upozorenje: vrijeme, izvor, ko prijavljuje, šta tačno.
- [ ] Odrediti rukovodstvo incidenta, otvoriti tiket odnosno dokument incidenta, započeti vremensku liniju (UTC i bečko vrijeme).
- [ ] Odrediti privremeni nivo ozbiljnosti.
- [ ] **Ne** uništavati dokaze: ništa ne brisati, ne restartovati server, ne dozvoliti rotaciju zapisnika.

**Minuta 15–30: Obuzdati**

- [ ] Identifikovati pogođene račune, uređaje, tokene, kartice (zapisnik aktivnosti, historija kartice, zapisnik skeniranja, Request-ID-ovi).
- [ ] Hitne mjere prema playbooku (odjeljak 7): blokirati uređaj, deaktivirati korisnika, opozvati token, blokirati karticu, po potrebi suspendovati restoran ili izolovati server.
- [ ] Kod SEV-1/SEV-2: obavijestiti druge članove tima i zamjenu.

**Minuta 30–60: Procijeniti i obavijestiti**

- [ ] Procijeniti obim: koji restorani? koji podaci? koji period? novčana šteta?
- [ ] **Provjera zaštite podataka:** Jesu li pogođeni lični podaci? Ako da: teče rok za obavezu prijave (odjeljak 8). Zabilježiti trenutak saznanja.
- [ ] Osigurati dokaze (odjeljak 6).
- [ ] Prva informacija pogođenim restoranima kod SEV-1/SEV-2 (predložak 9.1).
- [ ] Odrediti sljedeći termin za obavještenje o statusu.

---

## 6. Osiguranje dokaza

| Izvor | Sadržaj | Osiguranje |
|---|---|---|
| **Zapisnik aktivnosti** (baza podataka, nepromjenjiv) | radnja, osoba, uređaj, IP adresa, vrijeme (mikrosekunde), Request-ID, stare/nove vrijednosti (lični podaci zatamnjeni) | izvoz relevantnih zapisa (kontrolna tabla odnosno audit platforme) |
| **Historija kartice / dnevnik** | svako knjiženje sa stanjem prije/poslije, ključ idempotentnosti, uređaj, osoba | CSV izvoz Transactions; izvod iz baze podataka |
| **Zapisnik skeniranja** (`nfc_scans`) | svako skeniranje uklj. neuspjeh, razlog (npr. odstupanje UID-a, nevažeći potpis, replay), IP | izvod iz baze podataka |
| **Zapisnik aplikacije** (Laravel) | upozorenja *Suspicious gift card scan*, *Account locked*, greške | `docker compose logs api` sačuvati u datoteku |
| **Zapisnik proxyja** (Caddy, JSON) | svaki HTTP zahtjev s vremenom, IP adresom, putanjom, statusom | `docker compose logs caddy` sačuvati u datoteku |
| **API tokeni** | posljednja upotreba (vrijeme, IP), kreator, dozvole | izvod iz baze podataka |
| **Uređaji** | identifikator uređaja, naziv, posljednja aktivnost, status | izvod iz baze podataka |
| **Server** | datotečni sistem, procesi, prijave | Hetzner snapshot prije svake promjene |

**Request-ID:** Svaki zahtjev dobija identifikator korelacije (`X-Request-Id`) koji se nalazi u zapisniku aktivnosti i u odgovoru. Time se zapisi u zapisniku aktivnosti, zapisniku aplikacije i proxyja mogu povezati s jednim zahtjevom.

**Pravila:** Kopije spremati s vremenskom oznakom i SHA-256 kontrolnim zbirom, pristup ograničiti na rukovodstvo incidenta, svaku radnju s vremenom zabilježiti u vremenskoj liniji. Lične podatke u dokazima koristiti samo u mjeri u kojoj je potrebno.

---

## 7. Playbookovi

### 7.1 Kompromitovan račun zaposlenog

*Znaci: knjiženja izvan radnog vremena, nepoznat uređaj, prijava osobe, zaključavanje računa bez vlastitih neuspjelih pokušaja.*

1. **Restoran (Owner):** Team → ⋯ → **„Deactivate"**. Završava sve sesije i opoziva sve API tokene osobe.
2. Pod **Devices** blokirati nepoznate uređaje.
3. Provjeriti zapisnik aktivnosti i transakcije osobe od pretpostavljenog trenutka; neovlaštena iskorištavanja stornirati, pogođene kartice po potrebi blokirati i zamijeniti.
4. S osobom razjasniti kako je lozinka postala poznata (ponovna upotreba, phishing, zapisana).
5. Ponovo aktivirati tek nakon reseta lozinke preko **„Send password reset"**; osoba postavlja novu lozinku.
6. Kod Owner računa: nivo SEV-2; GiftCard Pro pomaže preko security@. Ako su podaci o kupcima pregledani ili izvezeni, provjera zaštite podataka (odjeljak 8).

### 7.2 Ukraden ili izgubljen telefon

1. **Devices** → uređaj → **„Revoke"**. Djeluje od sljedećeg zahtjeva; odbija se i još otvorena sesija.
2. Resetovati lozinku osobe ako je bila spremljena na uređaju ili uređaj nije bio zaključan.
3. Zapisnik aktivnosti: provjeriti aktivnost tog uređaja od trenutka gubitka.
4. Pronađen uređaj: **„Restore"**.

### 7.3 Talas kopiranja (card cloning)

*Znaci: više upozorenja „Cloned card rejected" ili replay upozorenja, gosti prijavljuju stanje koje nisu potrošili, ista kartica u kratkom vremenu za različitim stolovima.*

1. Pogođene kartice odmah **blokirati** (razlog: Suspicious use).
2. Analizirati zapisnik skeniranja: koje kartice, koji uređaji, koje IP adrese, koja vremena.
3. Provjeriti je li zaštita od kopiranja aktivirana i jesu li kartice vezane za serijski broj čipa. Nevezane kartice (npr. označene kao upisane bez serijskog broja) naknadno osigurati: izdati zamjensku karticu s vezivanjem.
4. Dokumentovati iskorištavanja koja su dokazano izvršena kopijama; stanje zakonitih vlasnika prenijeti pomoću **„Replace lost card"** na novu karticu.
5. Smanjiti ograničenja protiv zloupotrebe (iskorištavanja na sat, maksimalan pojedinačni iznos).
6. Informisati konobare: koristiti samo skeniranje Androidom (s provjerom serijskog broja), ozbiljno shvatiti crvena upozorenja.
7. Srednjoročno: za visoke vrijednosti preći na NTAG 424 DNA.
8. Kod novčane štete: restoran razmatra prijavu policiji; GiftCard Pro stavlja zapisnike na raspolaganje.

### 7.4 Sumnja na povredu zaštite podataka

*Znaci: neobjašnjiv izvoz, pristup iz stranog restorana, izvod iz baze podataka u opticaju, pogrešno poslani e-mailovi.*

1. Proglasiti SEV-1 ili SEV-2, zabilježiti trenutak saznanja.
2. Obuzdati: zatvoriti pristup (račun, token, server), provjeriti puteve izvoza.
3. Utvrditi obim: koji restorani (voditelji obrade)? koje kategorije podataka (ime, e-mail, telefon, bilješke, imena primalaca)? koliko pogođenih osoba? koji period?
4. Procjena rizika za pogođene osobe (npr. rizik od phishinga zbog e-mail adresa).
5. **Pogođene restorane obavijestiti bez nepotrebnog odgađanja** (predložak 9.2) – GiftCard Pro kao izvršitelj obrade, čl. 33 st. 2 GDPR-a.
6. Restoran kao voditelj obrade odlučuje o prijavi tijelu za zaštitu podataka (72 sata) i obavještavanju gostiju (čl. 34). GiftCard Pro dostavlja sve potrebne informacije.
7. Ako incident pogađa podatke za koje je GiftCard Pro sam voditelj obrade (npr. ugovorni podaci i podaci za fakturisanje restorana), GiftCard Pro sam prijavljuje tijelu za zaštitu podataka.
8. Sve dokumentovati (čl. 33 st. 5) – i kada prijava nije potrebna.

### 7.5 Objavljen ili proslijeđen API token

*Znaci: token u repozitoriju koda, chatu, e-mailu, na snimku ekrana; „posljednja upotreba" s nepoznate IP adrese.*

1. **Settings → API → Revoke** – odmah, bez dodatnih pitanja. Tokeni počinju s `gcp_`; to olakšava pretragu u repozitorijima.
2. Provjeriti zapisnik aktivnosti i transakcije radnji koje je pokrenuo token (token djeluje kao osoba koja ga je kreirala i bilježi se s njenim identifikatorom).
3. Neovlaštena knjiženja stornirati, pogođene kartice blokirati ili zamijeniti.
4. Kreirati novi token s minimalnim dozvolama i kratkim trajanjem, sigurno ga pohraniti u ciljnoj aplikaciji.
5. Otkloniti uzrok (npr. ukloniti token iz historije repozitorija, obavijestiti partnera za integraciju).

### 7.6 Kompromitacija računa administracije platforme

*Nivo ozbiljnosti uvijek SEV-1 – ovaj račun može djelovati u svakom restoranu.*

1. Račun odmah blokirati na strani servera: status korisnika u bazi podataka postaviti na neaktivan (neaktivni korisnici se odbijaju pri sljedećem zahtjevu), opozvati otvorene API tokene, završiti sesije u Redisu. Za račune platforme za to trenutno ne postoji posebno sučelje; koraci se izvode preko serverske konzole odnosno baze podataka i dokumentuju se u vremenskoj liniji.
2. Analizirati audit platforme: koji su restorani otvoreni preko „Open restaurant"? koje radnje, izvozi, postavke, suspenzije, sistemske postavke?
3. Obnoviti lozinke svih ostalih računa administracije platforme; po potrebi kreirati novi račun s `php artisan platform:create-admin`.
4. Provjeriti jesu li kreirani novi računi, pozivnice ili API tokeni; opozvati ih.
5. Kod sumnje na širi pristup serveru: scenarij 5.4 iz plana oporavka od katastrofe (ponovna izgradnja, obnova svih tajni).
6. Obavijestiti sve pogođene restorane; provjera zaštite podataka.

---

## 8. GDPR: prijava povreda zaštite podataka

| Konstelacija | Ko prijavljuje tijelu za zaštitu podataka? | Rok | Uloga GiftCard Pro |
|---|---|---|---|
| Podaci o gostima i kupcima restorana (GiftCard Pro = izvršitelj obrade) | **restoran** kao voditelj obrade (čl. 33 st. 1) | 72 sata od saznanja voditelja obrade, osim ako povreda vjerovatno ne dovodi do rizika | obavještenje restoranu **bez nepotrebnog odgađanja** nakon saznanja (čl. 33 st. 2), podrška prema čl. 28 st. 3 tač. f |
| Vlastiti podaci o korisnicima i ugovorima (GiftCard Pro = voditelj obrade) | **GiftCard Pro** | 72 sata | sam odgovoran |
| Visok rizik za pogođene osobe | obavještavanje osoba od strane voditelja obrade (čl. 34) | bez nepotrebnog odgađanja | podrška, dostavljanje informacija |

- Nadležno nadzorno tijelo u Austriji: **Österreichische Datenschutzbehörde** (austrijsko tijelo za zaštitu podataka), Barichgasse 40–42, 1030 Beč, [dsb.gv.at](https://www.dsb.gv.at).
- Interni cilj za obavještavanje restorana: **u roku od 24 sata** nakon potvrde sumnje, po potrebi u fazama (čl. 33 st. 4). Ugovorno je mjerodavan ugovor o obradi podataka po nalogu.
- Svaka povreda zaštite podataka dokumentuje se s činjenicama, posljedicama i korektivnim mjerama (čl. 33 st. 5), i kada prijava nije potrebna.

---

## 9. Predlošci

### 9.1 Prva informacija restoranu (sigurnosni incident)

> **Predmet: Sigurnosna napomena u vezi s Vašim GiftCard Pro računom – [datum]**
>
> Poštovani/a [ime],
>
> dana [datum, vrijeme] utvrdili smo [kratak, činjeničan opis]. Prema trenutnom stanju pogođeno je [obim].
>
> **Već provedeno:** [npr. token opozvan, uređaj blokiran].
> **Molimo Vas da poduzmete:** [npr. resetovati lozinke, provjeriti kartice].
>
> Javit ćemo se najkasnije [datum, vrijeme] s daljnjim informacijama. Kontakt osoba: [ime], security@giftcardpro.at, [Telefon].
>
> Srdačan pozdrav
> [ime], GiftCard Pro

### 9.2 Prijava povrede zaštite podataka restoranu (čl. 33 st. 2 GDPR-a)

> **Predmet: Obavještenje o povredi zaštite ličnih podataka u skladu s čl. 33 st. 2 GDPR-a**
>
> Poštovani/a [ime],
>
> kao Vaš izvršitelj obrade obavještavamo Vas o povredi zaštite ličnih podataka koja se odnosi na Vaš restoran [naziv restorana].
>
> 1. **Vrijeme:** povreda dana/od [datum, vrijeme]; poznata nam je od [datum, vrijeme].
> 2. **Vrsta povrede:** [neovlašten pristup / otkrivanje / gubitak / izmjena].
> 3. **Kategorije pogođenih osoba:** [npr. gosti koji su kupili poklon kartice; primaoci].
> 4. **Približan broj pogođenih osoba:** [broj]; **zapisa:** [broj].
> 5. **Kategorije ličnih podataka:** [ime, e-mail adresa, broj telefona, bilješke, ime primaoca].
> 6. **Vjerovatne posljedice:** [npr. rizik od phishing e-mailova].
> 7. **Poduzete mjere:** [obuzdavanje, otklanjanje].
> 8. **Preporučene mjere za Vas odnosno pogođene osobe:** [npr. upozoriti goste na lažne e-mailove].
> 9. **Kontakt:** [ime], datenschutz@giftcardpro.at, [Telefon].
>
> Kao voditelj obrade odlučujete o prijavi austrijskom tijelu za zaštitu podataka (rok: 72 sata od saznanja) i o obavještavanju pogođenih osoba. Sve daljnje informacije dostavit ćemo Vam čim budu dostupne.
>
> Srdačan pozdrav
> [ime], GiftCard Pro

### 9.3 Predložak za obavještavanje gostiju (za restoran)

> **Predmet: Važna informacija o Vašim podacima u [naziv restorana]**
>
> Poštovani/a [ime],
>
> obavještavamo Vas da je dana [datum] [opis jasnim jezikom]. Pogođeni su sljedeći podaci: [kategorije]. Stanje Vašeg poklon bona [nije pogođeno / pogođeno je kako slijedi: …].
>
> Poduzeli smo [mjere]. Preporučujemo Vam: [npr. oprez kod e-mailova koji navodno dolaze od nas i traže podatke za plaćanje].
>
> Pitanja: [kontakt restorana].
>
> Srdačan pozdrav
> [naziv restorana]

---

## 10. Predložak: izvještaj nakon incidenta

| Polje | Sadržaj |
|---|---|
| Broj / naziv incidenta | |
| Nivo ozbiljnosti (početni / konačni) | |
| Rukovodstvo incidenta, učesnici | |
| Vremenska linija | otkrivanje, obuzdavanje, otklanjanje, završetak (s vremenima) |
| Sažetak | 3–5 rečenica, razumljivo za restorane |
| Uzrok (root cause) | |
| Učinak | pogođeni restorani, kartice, osobe, novčani iznosi, vrijeme ispada |
| Zaštita podataka | povreda zaštite podataka da/ne, obrazloženje, prijave (ko, kada) |
| Šta je dobro funkcionisalo | |
| Šta nije dobro funkcionisalo | |
| Mjere | mjera · odgovorna osoba · rok · status |
| Novi testovi / nadzor | |
| Ažurirani dokumenti | |

Izvještaj se izrađuje u roku od 10 radnih dana nakon završetka; pogođeni restorani dobijaju razumljivu kratku verziju.

---

## 11. Prijave izvana

Sigurnosne propuste i sumnjive slučajeve molimo prijavite na **security@giftcardpro.at**. Prijem potvrđujemo u roku od 2 radna dana i obavještavamo Vas o stanju.

---

Verzija 1.0 · Stanje: septembar 2026.
