# Vodič za podršku GiftCard Pro

*Model podrške za korisnike i interni priručnik za tim podrške: kanali, radno vrijeme, ciljana vremena odgovora, prioriteti, eskalacija, obavještavanje o statusu, predlošci odgovora i ton komunikacije.*

---

## 1. Kanali podrške

| Kanal | Paket | Dostupnost | Namjena |
|---|---|---|---|
| **E-mail:** support@giftcardpro.at | svi paketi | prijem 24 sata, obrada u radno vrijeme podrške | standardni kanal za sve upite; svaki upit dobija broj tiketa |
| **Telefon:** [Telefon] | Pro, Gruppe | u radno vrijeme podrške | hitni upiti, pitanja tokom servisa |
| **Lična kontakt osoba** | Gruppe | prema ugovoru | centralna koordinacija za sve lokacije |
| **Zaštita podataka:** datenschutz@giftcardpro.at | svi | – | informacije, obrada podataka po nalogu, upiti prema GDPR-u |
| **Sigurnost:** security@giftcardpro.at | svi | – | prijava sigurnosnih propusta, sumnja na zloupotrebu |
| **Prodaja:** hallo@giftcardpro.at | – | – | paketi, narudžbe kartica, ponude |

Trenutno **nema chata u aplikaciji** niti funkcije podrške unutar aplikacije. Upite uvijek šaljite e-mailom ili (Pro/Gruppe) telefonom.

## 2. Radno vrijeme podrške

**Ponedjeljak do petak, 9:00–17:00 (bečko vrijeme)**, osim austrijskih zakonskih praznika (Nova godina, Sveta tri kralja, Uskrsni ponedjeljak, Praznik rada 1. maja, Uzašašće, Duhovski ponedjeljak, Tijelovo, Velika Gospa, Nacionalni praznik 26. oktobra, Svi sveti, Bezgrešno začeće, Božić, Sveti Stjepan). 24. i 31. decembar: [odrediti pravilo, npr. 9:00–12:00].

Izvan radnog vremena e-mailovi se obrađuju sljedećeg radnog dana. Upiti prioriteta P1 izvan radnog vremena obrađuju se prema najboljim mogućnostima – dežurstvo je dio samo individualnih ugovora za paket Gruppe.

## 3. Ciljana vremena odgovora po paketu

„Odgovor" znači: lični, sadržajni prvi odgovor (ne automatska potvrda prijema).

| Paket | Ciljano vrijeme odgovora | Kanali |
|---|---|---|
| **Start** | u roku od **1 radnog dana** | e-mail |
| **Pro** | u roku od **4 radna sata** (prioritet u redu čekanja) | e-mail, telefon |
| **Gruppe** | prema individualnom ugovoru/SLA | e-mail, telefon, centralna kontakt osoba |
| **Probni period (30 dana)** | kao Pro | e-mail |
| **Pilot restorani** | kao Pro, plus dnevne provjere u prvoj sedmici | e-mail, telefon, na licu mjesta |

Dostupnost platforme postavljena je kao **ciljana vrijednost od 99,5 % mjesečno**; u paketu Start to nije garancija, a u paketu Gruppe može se ugovoriti SLA.

## 4. Prioriteti (nivoi ozbiljnosti)

Tim podrške određuje prioritet prema uticaju, a ne prema tonu upita.

| Nivo | Definicija | Primjeri | Interni ciljevi (prvi odgovor / interval ažuriranja) |
|---|---|---|---|
| **P1 – kritično** | Usluga nedostupna ili **greška u knjiženju novca**; više restorana ili jedan restoran potpuno pogođen tokom servisa | aplikacija nedostupna; iskorištavanje ne uspijeva ni na jednom uređaju; stanje se ne slaže s dnevnikom transakcija; sumnja na dvostruko knjiženje; sumnja na pristup podacima od strane neovlaštenih osoba | odmah, najkasnije 1 radni sat / svakog sata |
| **P2 – visoko** | Važna funkcija za jedan restoran ne radi, postoji zaobilazno rješenje | NFC čitanje ne radi ni na jednom Android uređaju (QR radi); pozivnice ili e-mailovi za kupce općenito ne stižu; vlasnica ne može pristupiti | 4 radna sata / dnevno |
| **P3 – normalno** | Pogođena jedna osoba ili jedan uređaj, ili pitanje o korištenju | konobarica se ne može prijaviti; kartica se ne može upisati; CSV se pogrešno otvara | prema paketu / kod promjene |
| **P4 – nisko** | Želja, prijedlog za poboljšanje, opća informacija | nova funkcija, izmjena teksta, pitanje o planu razvoja | prema paketu / bez redovnih ažuriranja |

Napomena uz P1 „knjiženje novca": svaka promjena stanja tehnički je atomska, idempotentna i zabilježena u nepromjenjivom dnevniku transakcija (zbir transakcija = stanje). Pretpostavljena greška u knjiženju ipak je uvijek P1 dok se ne provjeri.

Ciljane vrijednosti važe u radno vrijeme podrške i interni su ciljevi, ne ugovorna obaveza (izuzetak: ugovor Gruppe sa SLA).

## 5. Šta sadrži dobar upit

Molimo navedite:

1. **Naziv restorana** i Vašu ulogu (Owner, Manager, Waiter).
2. **Šta se desilo, a šta ste očekivali?**
3. **Kada** (datum, okvirno vrijeme)?
4. **Broj kartice** (16 cifara) – samo broj kartice, bez podataka o kupcu.
5. **Uređaj i preglednik** (npr. „Samsung Galaxy A54, Chrome" ili „iPhone 13, Safari"), naziv uređaja iz **Devices**.
6. **Tačan tekst poruke**, najbolje snimak ekrana.
7. **Koliko osoba ili uređaja** je pogođeno, da li servis radi dalje?

**Nikada nam e-mailom ne šaljite lozinke, API tokene ili kompletne liste kupaca.** Nikada Vas nećemo pitati za lozinku.

## 6. Put eskalacije

| Nivo | Ko | Kada |
|---|---|---|
| 0 | Interno u restoranu: konobar → menadžer → vlasnik/vlasnica | kod svake poruke u aplikaciji koju kratko uputstvo ne rješava |
| 1 | Podrška (prvi nivo): support@ odnosno telefon | pitanja o korištenju, račun, e-mailovi, uređaji, kartice |
| 2 | Tehnika (drugi nivo) | greške u sistemu, provjera podataka, nepravilnosti u dnevniku transakcija, sumnja na klonirane kartice |
| 3 | Uprava [Geschäftsführung] | P1 duže od 2 sata; sigurnosni incident; incident zaštite podataka; pritužba na podršku; ugovorna pitanja |

**Sigurnosni incidenti i incidenti zaštite podataka** uvijek se odmah eskaliraju na nivo 2 i 3. Kod povrede zaštite ličnih podataka pružatelj kao izvršitelj obrade obavještava restoran (voditelj obrade) bez nepotrebnog odgađanja, kako bi restoran mogao ispuniti obavezu prijave (72 sata, čl. 33 GDPR).

**Eskalacija od strane korisnika:** ako niste zadovoljni obradom, u predmet e-maila upišite „Eskalacija" ili telefonom zatražite vođu tima.

## 7. Obavještavanje o statusu

| Situacija | Kanal | Vrijeme |
|---|---|---|
| Planirano održavanje | **Baner s obavještenjem o održavanju** u aplikaciji (vidljiv svim prijavljenim osobama, postavlja se u sistemskim postavkama platforme) + e-mail vlasnicima | najmanje 3 radna dana ranije; održavanje samo izvan uobičajenog vremena servisa (npr. utorak–četvrtak, 03:00–06:00) i nikada vikendom u decembru |
| Neplanirani prekid (P1) | Baner (ako je aplikacija dostupna) + e-mail pogođenim vlasnicima; Pro/Gruppe dodatno telefonom | prva informacija u roku od 1 sata, zatim svakog sata |
| Prekid otklonjen | Ukloniti baner, e-mail „riješeno" s uzrokom i posljedicama | odmah nakon otklanjanja |
| Naknadni izvještaj (P1) | E-mail pogođenim restoranima | u roku od 5 radnih dana |

Javna stranica sa statusom trenutno ne postoji.

**Predložak banera (kratko, najviše jedan red):**
„Planirano održavanje [datum], [vrijeme od–do]. GiftCard Pro u tom periodu nije dostupan. Molimo zabilježite poklon kartice u tom periodu i proknjižite ih nakon toga."

## 8. Interni priručnik podrške

### 8.1 Osnovna pravila

1. Svaki upit dobija broj tiketa i prioritet.
2. Prije odgovora provjeriti: paket, ulogu osobe koja pita, pogođenu karticu odnosno uređaj u zapisniku aktivnosti.
3. **Pristup podacima restorana** („Open restaurant" u administraciji platforme) samo kada je potreban za rješenje, uz bilješku u tiketu. Svaki pristup se bilježi i vidljivo je označen za restoran.
4. **Nikada** u ime restorana ne knjižiti stanje, ne stornirati i ne zamjenjivati kartice bez pisanog naloga vlasnika/vlasnice.
5. Brojeve kartica u e-mailovima ponavljati samo maskirano (npr. „kartica •••• 6488").
6. Pravna i porezna pitanja: dati opću informaciju, uvijek s napomenom „nije pravni ni porezni savjet".
7. Tiket zatvoriti tek kada restoran potvrdi rješenje ili nakon 3 radna dana bez odgovora (uz najavu).

### 8.2 Deset najčešćih upita – predlošci odgovora

Predlošci su za restorane u Austriji napisani na njemačkom (vidi njemačku verziju). Za korisnike koji komuniciraju na BHS koristite sljedeće tekstove.

**O1 – Račun zaključan nakon neuspješnih pokušaja**
> Poštovani/Poštovana [ime],
> nakon 10 pogrešnih unosa lozinke GiftCard Pro iz sigurnosnih razloga zaključava račun na 15 minuta. Molimo sačekajte to vrijeme i zatim se ponovo prijavite. Ako ne znate lozinku, na stranici za prijavu koristite **„Forgot password?"** (zaboravljena lozinka). Link u e-mailu vrijedi 60 minuta.
> Srdačan pozdrav, [ime], GiftCard Pro podrška

**O2 – Pozivnica istekla**
> Poštovani/Poštovana [ime],
> linkovi za pozivnicu vrijede 72 sata. Vaš vlasnik/vlasnica Vam pod **Team → ⋯ → „Resend invitation"** (ponovo pošalji pozivnicu) može poslati novi link. Molimo provjerite i folder za neželjenu poštu.
> Srdačan pozdrav, …

**O3 – NFC ne radi na Androidu**
> Poštovani/Poštovana [ime],
> molimo provjerite tri stvari: 1. NFC je uključen u sistemskim postavkama telefona. 2. GiftCard Pro je otvoren u **Chromeu** (drugi preglednici ne podržavaju čitanje NFC kartica). 3. Chrome smije koristiti NFC za app.giftcardpro.at (postavke stranice → NFC → dozvoli). Zatim u načinu rada za konobare jednom pritisnite **„Scan card"**. Do tada **„Scan QR code"** uvijek radi.
> Srdačan pozdrav, …

**O4 – iPhone ne čita karticu**
> Poštovani/Poštovana [ime],
> iPhone od modela XS čita karticu kada je ekran uključen i otključan: karticu prislonite uz gornju ivicu poleđine i dodirnite obavijest. Aplikacija kamere pri tome ne smije biti otvorena, a način rada u avionu mora biti isključen. Kod starijih modela koristite **„Scan QR code"** ili **„Card number"**. Ako iPhone ništa ne prikazuje, kartica možda još nije upisana – pošaljite nam broj kartice.
> Srdačan pozdrav, …

**O5 – „No connection to the server" – da li je proknjiženo?**
> Poštovani/Poštovana [ime],
> kod ove poruke **ništa nije proknjiženo**. Iskorištavanje možete bez rizika ponoviti čim veza ponovo radi – GiftCard Pro nikada ne knjiži dvaput, ni kod višestrukog pritiska. Svaku transakciju možete provjeriti u historiji kartice.
> Srdačan pozdrav, …

**O6 – Iskorišten pogrešan iznos**
> Poštovani/Poštovana [ime],
> menadžer ili vlasnik otvara karticu (ili **Transactions**), kod odgovarajuće transakcije bira ↺ **„Reverse"** (storniraj) i razlog, npr. „Wrong amount". Stanje se vraća protuknjiženjem; originalna transakcija ostaje vidljiva. Zatim ponovo iskoristite ispravan iznos i odgovarajuće ispravite fiskalnu kasu.
> Srdačan pozdrav, …

**O7 – Gost je izgubio karticu**
> Poštovani/Poštovana [ime],
> otvorite karticu (pretraga po kupcu, primaocu ili broju) i izaberite **⋯ → „Replace lost card"**, razlog „Lost". Preostalo stanje prelazi na novu karticu s novim brojem, stara kartica odmah prestaje raditi. Zamjensku karticu izdajte samo ako se kartica može nedvosmisleno povezati s gostom.
> Srdačan pozdrav, …

**O8 – Kupac nije dobio e-mail**
> Poštovani/Poštovana [ime],
> molimo provjerite: 1. Da li je pod **Settings → Gift cards** uključena opcija **„Customer e-mails"**? 2. Da li je kod kupca unesena e-mail adresa (anonimne kartice ne dobijaju e-mail)? 3. Da li je e-mail u folderu za neželjenu poštu gosta? Ako je sve u redu, pošaljite nam broj kartice i vrijeme prodaje, provjerit ćemo slanje.
> Srdačan pozdrav, …

**O9 – CSV u Excelu izgleda pogrešno**
> Poštovani/Poštovana [ime],
> izvoz koristi tačku-zarez kao separator i – kod postavke Deutsch (Österreich) – decimalni zarez. Provjerite pod **Settings → Restaurant** polje **„Language & number format"**. Ako je tamo engleski, iznosi se izvoze s decimalnom tačkom. Alternativno u Excelu uvezite datoteku putem **Podaci → Iz teksta/CSV-a** i izaberite separator „tačka-zarez".
> Srdačan pozdrav, …

**O10 – Telefon izgubljen ili ukraden**
> Poštovani/Poštovana [ime],
> vlasnik/vlasnica blokira uređaj pod **Devices → „Revoke"**. Od tog trenutka uređaj više ne može skenirati niti iskorištavati kartice. Ako se neko na uređaju prijavio ličnim računom, preporučujemo i novu lozinku – time se odjavljuju sve ostale sesije.
> Srdačan pozdrav, …

### 8.3 Makroi (sistem za tikete)

| Makro | Djelovanje |
|---|---|
| `#prijem` | Automatska potvrda: „Primili smo Vaš upit [broj tiketa] i javit ćemo se u roku od [ciljano vrijeme prema paketu]." |
| `#nedostaje-info` | Traži podatke iz odjeljka 5 (restoran, vrijeme, broj kartice, uređaj, poruka, snimak ekrana). |
| `#p1-start` | Postavlja P1, obavještava tehniku i upravu, šalje restoranu: „Radimo na tome s prioritetom. Sljedeća informacija najkasnije u [vrijeme]." |
| `#p1-update` | Predložak za međustanje: stanje, sljedeći koraci, sljedeća informacija u [vrijeme]. |
| `#rijeseno` | „Upit je riješen: [kratak sažetak]. Ako je još nešto otvoreno, jednostavno odgovorite na ovaj e-mail." |
| `#zelja` | Zahvala za prijedlog, unos na listu želja, bez obećanja termina. |
| `#pravo` | Opća informacija + „Nije pravni ni porezni savjet – molimo provjerite s Vašim poreznim savjetnikom odnosno advokatom." |
| `#sigurnost` | Eskalacija tehnici i na security@, zamoliti restoran da blokira pogođene kartice/uređaje. |
| `#najava-zatvaranja` | „Zatvaramo tiket za 3 radna dana ako se ne javite." |

### 8.4 Ton komunikacije

- **„Vi"** (velikim slovom), kratke rečenice, aktivni glagoli, konkretni koraci s tačnim nazivima dugmadi podebljano i objašnjenjem.
- Prvo rješenje, zatim objašnjenje.
- Mirno i precizno – kao dobar šef sale. Bez pretjerivanja i praznih fraza.
- Greške na našoj strani jasno priznati: „To je bila greška kod nas. Otklonili smo je u [vrijeme]."
- Ne obećavati ništa što nije u proizvodu ili planu razvoja. Ne obećavati termine za nove funkcije.
- Bez emojija, najviše jedan uzvičnik po e-mailu – bolje nijedan.
- Gosti restorana koji nam se obrate direktno: ljubazno ih uputiti na restoran (restoran je ugovorni partner i odgovoran je za stanja i podatke kupaca).

---

Verzija 1.0 · Stanje: septembar 2026.
