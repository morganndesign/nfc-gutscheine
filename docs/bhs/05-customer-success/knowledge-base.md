# Baza znanja GiftCard Pro

*20 članaka pomoći za vlasnike, menadžere i konobare – svaki sa sažetkom, koracima i povezanim člancima.*

---

Sučelje za zaposlene je trenutno na engleskom. Dugmad su navedena u engleskom originalu podebljano, uz značenje. Uloga u zagradi navodi ko smije izvršiti korak.

## Sadržaj

| Br. | Članak | Uloga |
|---|---|---|
| KB-01 | Prodaja prve poklon kartice | Manager, Owner |
| KB-02 | Upisivanje NFC kartice Androidom | Manager, Owner |
| KB-03 | Štampanje kartice | Manager, Owner |
| KB-04 | Aktiviranje kartice | Manager, Owner |
| KB-05 | Blokiranje i deblokiranje kartice | Manager, Owner |
| KB-06 | Zamjena izgubljene kartice | Manager, Owner |
| KB-07 | Prijenos stanja kartice | Manager, Owner |
| KB-08 | Storniranje transakcije | Manager, Owner |
| KB-09 | Ispravno podešavanje roka važenja (pravna napomena) | Owner |
| KB-10 | Pozivanje konobara | Owner |
| KB-11 | Pozivnica je istekla | Owner, svi |
| KB-12 | Zaboravljena lozinka | svi |
| KB-13 | Blokiranje uređaja | Owner |
| KB-14 | Instaliranje web-aplikacije na početni ekran telefona | svi |
| KB-15 | Izvoz za poreznog savjetnika | Manager, Owner |
| KB-16 | Fiskalna kasa i poklon bonovi (općenito) | Owner |
| KB-17 | Anonimizacija podataka kupaca | Manager, Owner |
| KB-18 | Prilagođavanje predložaka e-mailova | Owner |
| KB-19 | Isključivanje javne provjere stanja | Owner |
| KB-20 | Kreiranje API tokena (Pro) | Owner |

---

## KB-01 Prodaja prve poklon kartice

**Sažetak:** Kartica se kreira u kontrolnoj tabli, zatim upisuje (NFC) ili štampa (QR). Plaćanje se obavlja na Vašoj fiskalnoj kasi.

**Koraci**
1. **Gift cards → „New gift card"** (nova poklon kartica).
2. **„Value"** (vrijednost): izabrati iznos (25/50/75/100/150 €) ili ga slobodno unijeti pod **„Amount"** (unutar Vaše minimalne i maksimalne vrijednosti).
3. Provjeriti **„Valid until"** (vrijedi do) – vidi KB-09.
4. **„Customer"**: **„Anonymous"**, **„Existing"** ili **„New customer"** (ime, e-mail, telefon). S e-mailom gost dobija potvrdu kupovine.
5. Opcionalno **„Recipient name"** (štampa se na kartici) i **„Internal notes"** (vidljivo samo interno).
6. Izabrati **„Card type"** (preporuka: NTAG215; **„QR only"** za štampane kartice bez čipa). **„Activate immediately"** ostaviti uključeno.
7. **„Create card"**. U prozoru **„Card created"**: **„Write NFC tag"** (KB-02) ili **„Print"** (KB-03).
8. Prodaju proknjižiti u fiskalnoj kasi (KB-16).

**Povezano:** KB-02, KB-03, KB-09, KB-16

---

## KB-02 Upisivanje NFC kartice Androidom

**Sažetak:** Android telefonom i Chromeom kartica se upisuje u jednom koraku. Na čip se upisuje samo siguran link, nikada stanje.

**Koraci**
1. Na Android telefonu se prijaviti u Chromeu; uključiti NFC u sistemskim postavkama.
2. Otvoriti karticu → **⋯ → „Write NFC tag"** (odnosno direktno nakon **„Create card"**).
3. Provjeriti **„Card type"**. Za stvarni rad uključiti **„Lock tag after writing"** (zaključaj čip nakon upisivanja) – trajno, sprečava prepisivanje.
4. Pritisnuti **„Write NFC tag"** i praznu karticu mirno držati uz poleđinu.
5. Potvrda: **„The card can now be scanned by your staff."** Serijski broj čipa automatski se povezuje (zaštita od kloniranja).
6. Test: jednom skenirati u načinu rada za konobare.

**Bez Androida:** kopirati link iz dijaloga, upisati ga aplikacijom za NFC kao URL zapis, **„Mark as written"**. Kartica se tada vodi kao „neprovjerena“ i nije vezana za čip.

**Povezano:** KB-01, KB-03, Rješavanje problema odjeljak 2

---

## KB-03 Štampanje kartice

**Sažetak:** Svaka kartica ima izgled za štampu u formatu kreditne kartice (85,6 × 54 mm) s prednjom stranom (restoran, vrijednost, primalac) i poleđinom (QR kod, broj kartice, rok važenja, uputa za skeniranje) na jeziku Vašeg restorana.

**Koraci**
1. Otvoriti karticu → **⋯ → „Print card / QR"** (ili **„Print"** nakon kreiranja).
2. U dijalogu za štampu izabrati **skaliranje 100 %** odnosno „Stvarna veličina" (ne „Prilagodi stranici"). Uključiti pozadinsku grafiku.
3. Odštampati, izrezati po ivicama. Za čvrstu karticu štampati na debelom papiru ili plastificirati.
4. Telefonom testirati QR kod.

**Savjet:** QR kartice možete besplatno štampati sami. Odštampane NFC kartice s Vašim dizajnom naručujete putem hallo@giftcardpro.at (orijentaciona cijena, zavisno od količine i štampe – obavezujuća ponuda na upit).

**Povezano:** KB-01, KB-02

---

## KB-04 Aktiviranje kartice

**Sažetak:** Kartice bez **„Activate immediately"** imaju status **„Inactive"** i ne mogu se iskoristiti – korisno kada se kartice pripremaju unaprijed, a aktiviraju tek pri plaćanju.

**Koraci**
1. Potražiti karticu (**Gift cards**, filter **Status: Inactive**).
2. Otvoriti karticu → **⋯ → „Activate"** (aktiviraj).
3. Poruka **„Card activated"**. Kartica se odmah može iskoristiti.

**Povezano:** KB-01, KB-05

---

## KB-05 Blokiranje i deblokiranje kartice

**Sažetak:** Blokirana kartica ne može se ni iskoristiti ni dopuniti. Blokada je povratna i bilježi se s razlogom.

**Koraci – blokiranje**
1. Otvoriti karticu → **⋯ → „Block card"** (blokiraj karticu).
2. Izabrati razlog: **„Reported stolen"**, **„Reported lost"**, **„Suspicious use"** ili vlastiti tekst.
3. Potvrditi. Konobari pri skeniranju vide crveno upozorenje.

**Koraci – deblokiranje**
1. Otvoriti karticu → **⋯ → „Unblock"** (deblokiraj).

**Kada zamijeniti umjesto blokirati?** Kada gost treba dobiti novu karticu (KB-06).

**Povezano:** KB-06, KB-07

---

## KB-06 Zamjena izgubljene kartice

**Sažetak:** Preostalo stanje prelazi na novu karticu s novim brojem i novim linkom. Stara kartica odmah prestaje raditi.

**Koraci**
1. Potražiti karticu – po kupcu, primaocu, napomeni ili broju.
2. Nastaviti samo ako je kartica nedvosmisleno povezana s gostom (npr. potvrda kupovine, fiskalni račun).
3. **⋯ → „Replace lost card"**, razlog **„Lost"**, **„Damaged"** ili **„Stolen"**.
4. **„Issue replacement"** (izdaj zamjenu). Nova kartica se odmah otvara za upisivanje odnosno štampanje.
5. Historija povezuje obje kartice („Replacement for …" / „Replaced by …").

**Povezano:** KB-02, KB-03, KB-05

---

## KB-07 Prijenos stanja kartice

**Sažetak:** Stanje se može u cijelosti ili djelimično prenijeti s aktivne ili blokirane kartice na drugu karticu Vašeg restorana, npr. radi spajanja dvije kartice.

**Koraci**
1. Otvoriti izvornu karticu → **⋯ → „Transfer balance"** (prenesi stanje).
2. Unijeti **„Target card number"** (broj ciljne kartice).
3. **„Amount"** ostaviti prazno za cijelo stanje ili unijeti djelimičan iznos.
4. Potvrditi. Obje kartice prikazuju transakciju (**„Transfer out"** / **„Transfer in"**).

**Napomena:** ciljna kartica mora moći primiti stanje (nije zamijenjena ni istekla, paziti na maksimalno stanje).

**Povezano:** KB-06, KB-08

---

## KB-08 Storniranje transakcije

**Sažetak:** Pogrešne transakcije ispravljaju se protuknjiženjem. Originalni red ostaje u dnevniku transakcija – ništa se ne briše.

**Koraci**
1. Otvoriti **Transactions** (ili historiju kartice), pronaći transakciju.
2. Izabrati ↺ **„Reverse"** (storniraj), razlog: **„Wrong amount"**, **„Wrong card"**, **„Guest cancelled"** ili vlastiti tekst.
3. Potvrditi. Stanje je vraćeno; pojavljuje se red **„Reversal"**.
4. Po potrebi ponovo iskoristiti ispravan iznos. Odgovarajuće ispraviti fiskalnu kasu.

**Ograničenja:** transakcije zamijenjenih ili isteklih kartica i već stornirane transakcije ne mogu se stornirati.

**Povezano:** KB-07, KB-15

---

## KB-09 Ispravno podešavanje roka važenja (pravna napomena)

**Sažetak:** Plaćeni poklon bonovi u Austriji u pravilu zastarijevaju nakon 30 godina (§ 1478 ABGB). Paušalno ograničenje na 3 godine ili manje prema OGH-u je u pravilu grubo nepovoljno (§ 879 st. 3 ABGB) i nevažeće. Tvornička postavka GiftCard Pro je 36 mjeseci – molimo promijenite je.

**Koraci**
1. **Settings → Gift cards**.
2. **„Default validity (months)"** postaviti na **0** (bez isteka), osim ako Vaš pravni savjetnik odobri drugi model (OGH je npr. prihvatio rok od 1 godine uz naknadni rok od 3 godine za zamjenu odnosno povrat novca).
3. Sačuvati. Važi za nove kartice; postojeće kartice prilagoditi pojedinačno pod **⋯ → „Edit details"** → **„Valid until"**.
4. Promotivni ili besplatni bonovi smiju biti vremenski ograničeni – podesiti pojedinačno kod kartice.

**Važno:** kada kartica istekne, GiftCard Pro otpisuje preostalo stanje. Gost ipak može imati pravo; tada zamjenska kartica (KB-06) ili prijenos (KB-07). Promjena tvorničke postavke je planirana.

*Nije pravni savjet – provjerite s poreznim savjetnikom odnosno advokatom.*

**Povezano:** KB-06, KB-07, KB-16

---

## KB-10 Pozivanje konobara

**Sažetak:** Svaka osoba dobija vlastitu pozivnicu i sama postavlja lozinku. Podaci za prijavu se nikada ne dijele – svaka transakcija nosi ime osobe.

**Koraci**
1. **Team → „Invite"** (pozovi).
2. **„Name"**, **„E-mail"**, **„Role"**: **„Waiter"** (samo skeniranje i iskorištavanje), **„Manager"** ili **„Owner"**.
3. **„Send invitation"**. Osoba dobija e-mail, link vrijedi 72 sata.
4. Osoba otvara link, vidi **„Welcome to GiftCard Pro"** i bira lozinku (najmanje 12 znakova, velika/mala slova, cifra).
5. Status u **Team**: **„Invited"** → **„Active"**.

**Kada neko napusti restoran:** **⋯ → „Deactivate"**. Transakcije ostaju s imenom.

**Povezano:** KB-11, KB-12, KB-14

---

## KB-11 Pozivnica je istekla

**Sažetak:** Linkovi za pozivnicu vrijede 72 sata i samo jednom. Nakon toga se pri postavljanju lozinke pojavljuje poruka o grešci.

**Koraci**
1. Vlasnik/vlasnica: **Team** → osoba (status **„Invited"**) → **⋯ → „Resend invitation"**.
2. Osoba koristi **najnoviji** link, u roku od 72 sata.
3. Nema e-maila? Provjeriti neželjenu poštu; adresu ispraviti pod **⋯ → „Edit"**.

**Povezano:** KB-10, KB-12

---

## KB-12 Zaboravljena lozinka

**Sažetak:** Putem **„Forgot password?"** dobijate link koji vrijedi 60 minuta.

**Koraci**
1. Stranica za prijavu → **„Forgot password?"** (zaboravljena lozinka).
2. Unijeti e-mail adresu. Potvrda **„Check your inbox"** se uvijek pojavljuje – iz sigurnosnih razloga i za nepoznate adrese.
3. Link u e-mailu otvoriti u roku od 60 minuta, postaviti novu lozinku.
4. Sve ostale sesije se odjavljuju.

**Alternativno:** vlasnik/vlasnica šalje link pod **Team → ⋯ → „Send password reset"**.
**Račun zaključan?** Nakon 10 neuspješnih pokušaja sačekati 15 minuta.

**Povezano:** KB-10, KB-11

---

## KB-13 Blokiranje uređaja

**Sažetak:** Svaki uređaj koji se prijavi automatski se registruje. Izgubljen ili ukraden uređaj može se odmah blokirati.

**Koraci**
1. Otvoriti **Devices** (uređaji).
2. Pronaći uređaj po nazivu, osobi i posljednjem korištenju. Savjet: uređaje preimenovati odmah nakon prve prijave (ikona olovke, npr. „Bar iPhone").
3. **„Revoke"** (blokiraj) i potvrditi. Uređaj od tog trenutka ne može skenirati niti iskorištavati kartice.
4. Pronađen: **„Restore"** (vrati).
5. Kod ukradenog uređaja dodatno promijeniti lozinku osobe koja je na njemu bila prijavljena.

**Povezano:** KB-12, KB-14

---

## KB-14 Instaliranje web-aplikacije na početni ekran telefona

**Sažetak:** GiftCard Pro je web-aplikacija – preuzimanje iz App Storea nije potrebno. Ikona na početnom ekranu otvara je kao aplikaciju.

**Android (Chrome)**
1. Otvoriti app.giftcardpro.at u **Chromeu** i prijaviti se (**„Keep me signed in on this device"** na službenim telefonima).
2. Meni **⋮ → „Instaliraj aplikaciju"** odnosno **„Dodaj na početni ekran"**.
3. Ubuduće pokretati preko ikone – NFC radi samo u Chromeu.

**iPhone (Safari)**
1. Otvoriti app.giftcardpro.at u **Safariju** i prijaviti se.
2. **Ikona za dijeljenje → „Dodaj na početni ekran"**.
3. Pokretati preko ikone.

**Povezano:** KB-10, KB-13

---

## KB-15 Izvoz za poreznog savjetnika

**Sažetak:** Lista kartica i dnevnik transakcija mogu se izvesti kao CSV – s tačkom-zarezom i decimalnim zarezom, direktno čitljivo u Excelu.

**Koraci**
1. Jednom: **Settings → Restaurant → „Language & number format"** na **Deutsch (Österreich)**, **„Time zone"** Europe/Vienna.
2. **Transactions** → postaviti period s **From / To** (npr. mjesec ili poslovna godina), opcionalno filtrirati tip → **„Export CSV"**.
3. **Gift cards** → opcionalno filtrirati status → **„Export CSV"** (stanje po kartici na određeni dan).
4. Dodatno zabilježiti vrijednost **„Outstanding balance"** (otvorena obaveza) na taj dan.
5. Datoteke poslati poreznom savjetniku; dogovoriti da li format odgovara.

**Napomena:** dnevnik transakcija je nepromjenjiv i čuva se (obaveza čuvanja 7 godina, § 132 BAO). *Nije porezni savjet.*

**Povezano:** KB-08, KB-16

---

## KB-16 Fiskalna kasa i poklon bonovi (općenito, s napomenom)

**Sažetak:** GiftCard Pro **nije fiskalna kasa**, nije certificiran prema RKSV-u i ne izdaje račune. Prodaju i iskorištavanje dodatno knjižite u svojoj fiskalnoj kasi, onako kako odredi Vaš porezni savjetnik.

**Opće informacije (austrijski propisi)**
- **PDV:** od 2019. razlikuju se bon za jednu namjenu (PDV pri prodaji) i bon za više namjena (PDV pri iskorištavanju). Vrijednosni bonovi za hranu (10 %) i pića (20 %) tipično su bonovi za više namjena – PDV tada nastaje pri iskorištavanju.
- **Fiskalna kasa:** tipke za bonove odnosno načine plaćanja u kasi podešava Vaš dobavljač kase prema uputama poreznog savjetnika.
- **Porez na dobit:** kod jednostavnog knjigovodstva (Einnahmen-Ausgaben-Rechnung) prodaja bona se u pravilu evidentira pri prilivu; kod dvojnog knjigovodstva prihod se evidentira pri iskorištavanju, otvoreni bonovi su obaveza (**„Outstanding balance"**).
- **Sučelje:** direktna veza s kasom još ne postoji; u paketu Pro dostupan je API (KB-20).

**Tok u servisu (primjer, uskladiti s poreznim savjetnikom)**
1. Prodaja: kreirati karticu u GiftCard Pro, iznos u kasi naplatiti kao prodaju bona.
2. Iskorištavanje: iskoristiti karticu u GiftCard Pro, u kasi proknjižiti kao način plaćanja „poklon bon".

*Nije pravni ni porezni savjet – provjerite s poreznim savjetnikom.*

**Povezano:** KB-09, KB-15, KB-20

---

## KB-17 Anonimizacija podataka kupaca

**Sažetak:** Na zahtjev gosta (pravo na brisanje, GDPR) **„Anonymize"** uklanja ime, e-mail, telefon i napomene, kao i imena primalaca na njegovim karticama. Kartice, stanja i transakcije ostaju sačuvani za knjigovodstvo.

**Koraci**
1. **Customers** → potražiti kupca → otvoriti.
2. Izabrati **„Anonymize customer"**.
3. Pročitati napomenu (**„Irreversibly removes name, e-mail, phone and notes …"**) i potvrditi. Postupak je nepovratan.
4. Potvrditi gostu brisanje.

**Napomena:** Vaš restoran je voditelj obrade za podatke kupaca; GiftCard Pro ih obrađuje po Vašem nalogu.

**Povezano:** KB-18

---

## KB-18 Prilagođavanje predložaka e-mailova

**Sažetak:** Četiri e-maila za kupce pripremljena su na njemačkom i engleskom i mogu se prilagoditi: kartica kupljena, kartica dopunjena, kartica uskoro ističe (30 dana ranije), nisko stanje (ispod 5 €).

**Koraci**
1. **Settings → E-mails**.
2. Izabrati predložak (Vaš jezik je prvi).
3. Urediti **„Subject"** (predmet) i **„Message"** (tekst). Ne mijenjati oznake u `{{ … }}`.
4. Sačuvati. Pregled prikazuje stvarni naziv Vašeg restorana.
5. Podnožje s podacima o firmi (sudski registar, adresa): **Settings → Gift cards → „E-mail footer"**.
6. Slanje ukupno uključiti/isključiti: **„Customer e-mails"**.

**Povezano:** KB-01, KB-17

---

## KB-19 Isključivanje javne provjere stanja

**Sažetak:** Gosti mogu provjeriti stanje skeniranjem kartice vlastitim telefonom (stanje, status, rok važenja, maskirani broj). Ova stranica se može isključiti.

**Koraci**
1. **Settings → Gift cards**.
2. Isključiti **„Public balance check"** (javna provjera stanja), sačuvati.
3. Gosti zatim vide: „Bitte fragen Sie im Restaurant nach Ihrem Guthaben." (Molimo pitajte u restoranu za Vaše stanje.)
4. Prijavljeni zaposleni i dalje normalno otvaraju kartice.

**Povezano:** KB-14, KB-18

---

## KB-20 Kreiranje API tokena (Pro)

**Sažetak:** U paketu Pro možete kreirati pristupe za sučelje (API tokene) za integracije, npr. s fiskalnom kasom. Tokeni imaju ograničena prava, trajanje najviše 365 dana i mogu se opozvati u bilo kojem trenutku.

**Koraci**
1. **Settings → API**.
2. Postaviti **„Name"** (npr. „Kasa bar"), **„Abilities"** (prava – izabrati samo potrebna), **„Expires"** (datum isteka).
3. Kreirati. Token (počinje s `gcp_`) prikazuje se **samo jednom** – odmah ga sigurno predati partneru za integraciju, nikada nešifrovanim e-mailom.
4. Više nije potreban ili je kompromitovan: opozvati token.

**Povezano:** KB-16

---

Verzija 1.0 · Stanje: septembar 2026.
