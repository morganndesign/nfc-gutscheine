# Vodič za kontrolu pristupa

*Uloge, dozvole, uređaji, API tokeni i procesi za dolazak, promjenu i odlazak – izvedeno iz stvarne implementacije u GiftCard Pro. Za vlasnike i vlasnice, menadžere i IT podršku restorana.*

---

## 1. Principi

1. **Svaka radnja zahtijeva dozvolu.** Svako sučelje GiftCard Pro na strani servera provjerava konkretnu dozvolu. Sučelje samo sakriva ono što osoba ne smije – mjerodavna je uvijek provjera na serveru.
2. **Dozvole zavise od uloge.** Svaka osoba ima tačno jednu ulogu. Dozvole po ulozi su fiksno zadane i iste za sve restorane; pojedinačna prilagođavanja nisu moguća preko sučelja.
3. **Najmanja prava.** Dodijelite najnižu ulogu s kojom osoba može obavljati svoj posao.
4. **Odvajanje klijenata.** Sve dozvole važe samo u vlastitom restoranu. Ni vlasnica nikada ne vidi podatke drugog restorana.
5. **Lični računi.** Jedan račun po osobi, bez zajedničkih računa – samo tako je zapisnik aktivnosti smislen.
6. **Iskorištavanje zahtijeva vaučer.** Nijedna dozvola ne omogućava terećenje bez svježeg skeniranja vaučera; broj vaučera nikada nije dokaz ovlaštenja.

---

## 2. Uloge

| Uloga | Naziv u aplikaciji | Rang | Tipične osobe |
|---|---|---|---|
| **Administracija platforme** | Platform Administrator | 100 | operativni tim GiftCard Pro – nikada se ne dodjeljuje u restoranu |
| **Vlasnik/vlasnica** | Restaurant Owner | 30 | vlasnica, vlasnik, uprava |
| **Menadžer** | Manager | 20 | voditelj objekta, voditelj smjene, šef sale |
| **Konobar/konobarica** | Waiter | 10 | konobari, konobarice, šank, pomoćno osoblje |

---

## 3. Matrica dozvola

✔ = standardno dodijeljeno · – = nije dodijeljeno

Administracija platforme ima isključivo dozvole platforme: upravlja restoranima, ali nikada ne djeluje unutar restorana i nikada ne dira vaučere (odjeljak 6).

| Oblast | Dozvola | Značenje | Admin platforme | Owner | Manager | Waiter |
|---|---|---|:-:|:-:|:-:|:-:|
| Dashboard | `dashboard.view` | pregled dashboarda s pokazateljima i grafikonima | – | ✔ | ✔ | – |
| Vaučeri | `vouchers.view` | pregled liste vaučera i detalja | – | ✔ | ✔ | – |
| | `vouchers.sell` | prodaja vaučera (s plaćanjem) | – | ✔ | ✔ | – |
| | `vouchers.sell_complimentary` | izdavanje vaučera bez plaćanja (način plaćanja `complimentary`, s obrazloženjem) | – | ✔ | – | – |
| | `vouchers.update` | uređivanje detalja (kupac, primalac, napomene) | – | ✔ | ✔ | – |
| | `vouchers.redeem` | iskorištavanje stanja (samo uz skeniranje vaučera) | – | ✔ | ✔ | ✔ |
| | `vouchers.reload` | dopuna vaučera (s plaćanjem) | – | ✔ | ✔ | – |
| | `vouchers.block` | blokiranje vaučera | – | ✔ | ✔ | – |
| | `vouchers.unblock` | ukidanje blokade | – | ✔ | ✔ | – |
| | `vouchers.expire` | trenutni istek vaučera (stanje ostaje, s obrazloženjem) | – | ✔ | – | – |
| | `vouchers.reinstate` | ponovna aktivacija isteklog vaučera | – | ✔ | – | – |
| | `vouchers.export` | izvoz liste vaučera kao CSV | – | ✔ | ✔ | – |
| Transakcije | `transactions.view` | pregled dnevnika knjiženja | – | ✔ | ✔ | – |
| | `transactions.reverse` | storniranje iskorištavanja ili dopune | – | ✔ | ✔ | – |
| | `transactions.export` | izvoz transakcija kao CSV | – | ✔ | ✔ | – |
| Kupci | `customers.view` | pregled liste kupaca i detalja | – | ✔ | ✔ | – |
| | `customers.manage` | kreiranje, uređivanje, anonimizacija kupaca | – | ✔ | ✔ | – |
| Tim | `users.view` | pregled liste tima i uloga | – | ✔ | – | – |
| | `users.manage` | pozivanje, uređivanje, promjena uloge, deaktivacija, ponovno slanje pozivnice | – | ✔ | – | – |
| Uređaji | `devices.view` | pregled liste uređaja | – | ✔ | ✔ | – |
| | `devices.manage` | preimenovanje, blokiranje, vraćanje uređaja | – | ✔ | – | – |
| Postavke | `settings.manage` | pravila vaučera, profil restorana, predlošci e-mailova | – | ✔ | – | – |
| | `api_tokens.manage` | kreiranje i opoziv API tokena | – | ✔ | – | – |
| Audit | `audit.view` | pregled zapisnika aktivnosti restorana | – | ✔ | ✔ | – |
| Platforma | `platform.restaurants.manage` | kreiranje, uređivanje, onemogućavanje, arhiviranje, brisanje restorana; ponovno slanje pozivnica; opoziv tokena | ✔ | – | – | – |
| | `platform.settings.manage` | sistemske postavke (obavještenje o održavanju, e-mail podrške, minimalne verzije aplikacije), dijagnostika e-maila | ✔ | – | – | – |
| | `platform.audit.view` | pregled zapisnika aktivnosti cijele platforme | ✔ | – | – | – |
| **Ukupno** | | | **3** | **24** | **16** | **1** |

**Napomene uz matricu**

- Konobari mogu **samo iskorištavati** – sa skeniranim QR kodom vaučera. Ne mogu prodavati, dopunjavati, blokirati niti vidjeti knjiženja. Odredite da se upadljiv vaučer ne prihvata i da se voditelj smjene odmah obavještava.
- Menadžeri vode tekuće poslovanje s vaučerima (prodaja, dopuna, blokiranje, storno), vide zapisnik aktivnosti i listu uređaja, ali **ne upravljaju ni timom ni uređajima, postavkama ili API tokenima**. Istek, ponovna aktivacija i besplatni vaučeri rezervisani su za vlasnika ili vlasnicu. Izgubljeni uređaj standardno može blokirati samo Owner.
- Svaka osoba može provjeriti **vlastiti** uređaj, uređivati svoj profil (ime, jezik) i promijeniti svoju lozinku.

---

## 4. Rangovi: ko smije upravljati kim?

Članovima tima smije upravljati samo onaj ko ima `users.manage` (standardno Owner) **i** ima viši rang od ciljne osobe. Izuzetak: Owneri smiju upravljati i drugim Ownerima.

| Uloga koja djeluje | smije upravljati (pozivati, uređivati, dodjeljivati ulogu, deaktivirati) |
|---|---|
| Administracija platforme | pri kreiranju restorana kreira račun vlasnika i ponovo šalje pozivnice; ne upravlja timom unutar restorana |
| Owner | Ownerima, Managerima, Waiterima u vlastitom restoranu |
| Manager | nikim (nema dozvolu `users.manage`) |
| Waiter | nikim |

**Zaštitna pravila [tehnički provedeno]**

- **Nema samounapređenja:** Niko ne može promijeniti vlastitu ulogu.
- **Nema samoblokade:** Niko ne može deaktivirati vlastiti račun.
- **Posljednji vlasnik / posljednja vlasnica:** Restoran uvijek mora zadržati najmanje jednu aktivnu osobu s ulogom Owner. Posljednja se ne može deaktivirati.
- **Uloga platforme:** Uloga „Platform Administrator“ ne može se dodijeliti ni u jednom restoranu. Pozivnice dozvoljavaju samo Owner, Manager ili Waiter. Računi platforme kreiraju se isključivo preko serverske konzole (`php artisan platform:create-admin`).
- **Vezanost za klijenta:** Osobe drugog restorana nisu ni vidljive ni upravljive.
- **Ništa se ne briše:** Korisnici se deaktiviraju, ne brišu. Njihova knjiženja ostaju s imenom u historiji.

Status korisnika: **Invited** (pozivnica otvorena) → **Active** · **Locked** (privremeno nakon 10 neuspjelih pokušaja) · **Deactivated**.

---

## 5. Uređaji i sesije

- **Automatska registracija:** Svaki uređaj (telefon, tablet, računar, kasa) koji se prijavi bilježi se pod **Devices**. Preimenovanje simbolom olovke, npr. „Šank iPhone“.
- **Vezivanje za uređaj u pregledniku:** Sesija je vezana za slučajni identifikator uređaja s kojim je započeta. Kopirani kolačić sesije ne radi na drugom uređaju.
- **„Keep me signed in on this device“:** standardno je isključeno. Tako obnovljena sesija prihvata se samo na aktivnom uređaju koji je osoba već koristila.
- **Aplikacija za konobare (GiftCard Waiter):** prijava kreira token koji radi samo s identifikatorom tog telefona i dopire samo do zahtjeva aplikacije (skeniranje, iskorištavanje, provjera nejasnog ishoda iskorištavanja; menadžeri i Owneri dodatno prodaja). Ističe nakon 30 dana bez korištenja.
- **Blokiranje:** **„Revoke“** (s potvrdom) odbija uređaj od sljedećeg zahtjeva – nezavisno od otvorenih sesija ili tokena – i završava „Keep me signed in“ njegovih korisnika. **„Restore“** ukida blokadu.
- **Trajanje sesije:** 8 sati neaktivnosti.
- **Promjena ili resetovanje lozinke** opoziva sve tokene osobe (aplikacija za konobare i integracije) i završava „Keep me signed in“ i sve druge sesije u pregledniku.
- **Deaktivacija** korisnika završava njegove sesije i opoziva njegove tokene.
- **Onemogućeni ili arhivirani restorani:** Ako administracija platforme onemogući ili arhivira restoran, njegovi korisnici i uređaji više ne mogu raditi.

---

## 6. Administracija platforme

Administracija platforme upravlja platformom, ne restoranima:

- **Nema** pristup vaučerima, knjiženjima, podacima kupaca ni timovima restorana. Sučelja restorana joj odgovaraju s `403 TENANT_NOT_RESOLVED`; radni način „unutar restorana“ ne postoji.
- Kreira restorane s računom vlasnika, uređuje ih, onemogućava, arhivira i briše (brisanje samo bez vaučera, knjiženja i podataka kupaca), ponovo šalje pozivnice, održava sistemske postavke i kod sigurnosnog incidenta opoziva tokene (`/admin/api-tokens`).
- **Ne može kreirati niti koristiti API tokene** i uvijek se prijavljuje izričito („Keep me signed in“ za nju ne važi).
- Sve radnje platforme bilježe se u zapisniku aktivnosti cijele platforme.
- Podrška kod problema u restoranu odvija se preko samog restorana (Owner dijeli ekran, opisuje korake) – vidi [Politika lozinki](password-policy.md), odjeljak 9.

---

## 7. API tokeni

| Osobina | Pravilo |
|---|---|
| Ko smije kreirati | osobe s `api_tokens.manage` (standardno Owner); nikada administracija platforme |
| Dozvole (abilities) | slobodno odabrane, ali **uvijek podskup dozvola osobe koja kreira token** |
| Identitet | token djeluje kao osoba koja ga je kreirala; knjiženja i zapisi u zapisniku aktivnosti nose njen identifikator |
| Trajanje | najviše 365 dana |
| Spremanje | samo kao SHA-256 hash; tekst se prikazuje jednom; prefiks `gcp_` |
| Kontrola | vidljiva posljednja upotreba (vrijeme, IP adresa) |
| Opoziv | u svakom trenutku ručno; automatski pri deaktivaciji osobe koja ga je kreirala i pri promjeni ili resetovanju njene lozinke; kod incidenta i od strane administracije platforme |
| Kolačići | tokeni ne koriste kolačiće i stoga ih CSRF ne pogađa |

**Preporuka za povezivanje s kasom:** samo `vouchers.view` i `vouchers.redeem` (iskorištavanje uz skeniranje QR koda) i – ako kasa prodaje ili dopunjuje vaučere – `vouchers.sell` odnosno `vouchers.reload`. Trajanje 90–180 dana, obnovu upisati u kalendar. Token neka kreira osoba koja će vjerovatno dugo ostati u restoranu – pri deaktivaciji te osobe i pri promjeni njene lozinke token se opoziva.

---

## 8. Dolazak, promjena, odlazak (joiner – mover – leaver)

### 8.1 Dolazak

1. Owner: **Team → „Invite“** → ime, lična e-mail adresa, uloga po principu najmanjih prava → **„Send invitation“**.
2. Nova osoba otvara link (važi 72 sata) i bira svoju lozinku.
3. Prva prijava na službenom uređaju odnosno u aplikaciji za konobare; Owner imenuje uređaj pod **Devices**.
4. Uvod: [Najbolje sigurnosne prakse](security-best-practices.md), posebno zaključavanje ekrana, bez prosljeđivanja lozinki, vaučere iskorištavati samo skeniranjem.

### 8.2 Promjena (promjena uloge)

1. Owner: **Team → ⋯ → „Edit“** → nova uloga. Nove dozvole važe od sljedećeg zahtjeva; aplikacija za konobare ih preuzima najkasnije pri dnevnom produženju svog tokena (uloga se dodatno provjerava pri svakom zahtjevu).
2. Kod smanjenja uloge provjeriti je li osoba kreirala API tokene koji su sada preširoki – te opozvati i ponovo kreirati.
3. Ako osoba postane Owner, provjeriti odgovara li njen račun pravilima za Ownere (menadžer lozinki).

### 8.3 Odlazak

**Posljednjeg radnog dana:**

1. **Team → ⋯ → „Deactivate“** – završava sesije, opoziva tokene.
2. **Devices:** blokirati privatne uređaje osobe.
3. Ako je osoba kreirala API tokene za integracije: unaprijed neka preostala osoba kreira nove tokene i pohrani ih u integraciji, inače integracija prestaje raditi.
4. Kod odlaska vlasnika ili vlasnice: prvo pozvati novu osobu kao Owner, zatim deaktivirati stari račun (zaštita posljednjeg vlasnika ili vlasnice).
5. Nasumično provjeriti zapisnik aktivnosti posljednjih dana na upadljivosti.

---

## 9. Tromjesečna provjera pristupa

Jednom u tromjesečju (npr. u januaru, aprilu, julu, oktobru) od strane Ownera, trajanje oko 15 minuta:

- [ ] **Tim:** Sve aktivne osobe još rade u restoranu. Otvorene pozivnice („Invited“) su još potrebne.
- [ ] **Uloge:** Svaka osoba ima najnižu odgovarajuću ulogu. Broj Ownera je što manji, ali najmanje dvije dostupne osobe mogu u hitnom slučaju blokirati uređaje (kod samo jednog Ownera: odrediti pravilo zamjene).
- [ ] **Uređaji:** Nema aktivnih nepoznatih ili rashodovanih uređaja; svi uređaji jasno imenovani.
- [ ] **API tokeni:** Svaki token je još potreban, ima minimalne dozvole, ne ističe neprimjetno; posljednja upotreba i IP adresa su uvjerljive.
- [ ] **Zapisnik aktivnosti:** neuspjela skeniranja (`presentment.failed`) i zaključavanja računa u tromjesečju razjašnjena; besplatni vaučeri, storna, istek i ponovne aktivacije uvjerljivi.
- [ ] **Postavke:** granice po iskorištavanju, po vaučeru i danu i po satu odgovarajuće; važenje odgovara uslovima poslovanja.
- [ ] **Rezultat dokumentovan:** datum, osoba koja provjerava, promjene (npr. u kratkoj bilješci ili u operativnom priručniku restorana).

---

Verzija 2.0 · Stanje: septembar 2026.
