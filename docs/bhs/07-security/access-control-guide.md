# Vodič za kontrolu pristupa

*Uloge, dozvole, uređaji, API tokeni i procesi za dolazak, promjenu i odlazak – izvedeno iz stvarne implementacije u GiftCard Pro. Za vlasnike i vlasnice, menadžere i IT podršku restorana.*

---

## 1. Principi

1. **Svaka radnja zahtijeva dozvolu.** Svako sučelje GiftCard Pro na strani servera provjerava konkretnu dozvolu. Sučelje samo sakriva ono što osoba ne smije – mjerodavna je uvijek provjera na serveru.
2. **Dozvole zavise od uloge.** Svaka osoba ima tačno jednu ulogu. Dozvole po ulozi su fiksno zadane i iste za sve restorane; pojedinačna prilagođavanja trenutno nisu moguća preko sučelja.
3. **Najmanja prava.** Dodijelite najnižu ulogu s kojom osoba može obavljati svoj posao.
4. **Odvajanje klijenata.** Sve dozvole važe samo u vlastitom restoranu. Ni vlasnica nikada ne vidi podatke drugog restorana.
5. **Lični računi.** Jedan račun po osobi, bez zajedničkih računa – samo tako je zapisnik aktivnosti smislen.

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

Za administraciju platforme dozvole restorana važe samo u radnom načinu „Open restaurant" (odjeljak 6).

| Oblast | Dozvola | Značenje | Admin platforme | Owner | Manager | Waiter |
|---|---|---|:-:|:-:|:-:|:-:|
| Kontrolna tabla | `dashboard.view` | pregled kontrolne table s pokazateljima i grafikonima | ✔ | ✔ | ✔ | – |
| Kartice | `cards.view` | pregled liste kartica i detalja kartice | ✔ | ✔ | ✔ | – |
| | `cards.scan` | skenirati karticu odnosno tražiti po broju (aplikacija za konobare) | ✔ | ✔ | ✔ | ✔ |
| | `cards.create` | izdati novu poklon karticu | ✔ | ✔ | ✔ | – |
| | `cards.update` | uređivati detalje (kupac, primalac, bilješke, važenje) | ✔ | ✔ | ✔ | – |
| | `cards.activate` | aktivirati neaktivnu karticu | ✔ | ✔ | ✔ | – |
| | `cards.redeem` | iskoristiti stanje | ✔ | ✔ | ✔ | ✔ |
| | `cards.reload` | dopuniti karticu | ✔ | ✔ | ✔ | – |
| | `cards.block` | blokirati karticu | ✔ | ✔ | ✔ | – |
| | `cards.unblock` | ukinuti blokadu | ✔ | ✔ | ✔ | – |
| | `cards.expire` | odmah pustiti da kartica istekne | ✔ | ✔ | ✔ | – |
| | `cards.transfer` | prenijeti stanje između kartica | ✔ | ✔ | ✔ | – |
| | `cards.replace` | zamijeniti izgubljenu karticu | ✔ | ✔ | ✔ | – |
| | `cards.write_nfc` | upisati NFC čip i vezati ga za karticu | ✔ | ✔ | ✔ | – |
| | `cards.export` | izvesti listu kartica kao CSV | ✔ | ✔ | ✔ | – |
| Transakcije | `transactions.view` | pregled dnevnika knjiženja | ✔ | ✔ | ✔ | – |
| | `transactions.reverse` | stornirati iskorištavanje ili dopunu | ✔ | ✔ | ✔ | – |
| | `transactions.export` | izvesti transakcije kao CSV | ✔ | ✔ | ✔ | – |
| Kupci | `customers.view` | pregled liste kupaca i detalja | ✔ | ✔ | ✔ | – |
| | `customers.manage` | kreirati, uređivati, anonimizirati kupce | ✔ | ✔ | ✔ | – |
| Tim | `users.view` | pregled liste tima i uloga | ✔ | ✔ | – | – |
| | `users.manage` | pozivati, uređivati, mijenjati ulogu, deaktivirati, resetovati lozinku | ✔ | ✔ | – | – |
| Uređaji | `devices.view` | pregled liste uređaja | ✔ | ✔ | ✔ | – |
| | `devices.manage` | preimenovati, blokirati, vratiti uređaje | ✔ | ✔ | – | – |
| Postavke | `settings.manage` | pravila kartica, profil restorana, e-mail predlošci | ✔ | ✔ | – | – |
| | `api_tokens.manage` | kreirati i opozivati API tokene | ✔ | ✔ | – | – |
| Audit | `audit.view` | pregled zapisnika aktivnosti restorana | ✔ | ✔ | ✔ | – |
| Platforma | `platform.restaurants.manage` | kreirati, uređivati, suspendovati, ponovo aktivirati restorane | ✔ | – | – | – |
| | `platform.settings.manage` | sistemske postavke (standardni paket, obavještenje o održavanju, e-mail podrške) | ✔ | – | – | – |
| | `platform.audit.view` | pregled zapisnika aktivnosti cijele platforme | ✔ | – | – | – |
| **Ukupno** | | | **30** | **27** | **22** | **2** |

**Napomene uz matricu**

- Konobari **ne mogu blokirati** kartice. Odredite da se upadljiva kartica ne prihvata i da se voditelj smjene odmah obavještava.
- Menadžeri vode kompletno poslovanje s karticama, vide zapisnik aktivnosti i listu uređaja, ali **ne upravljaju ni timom ni uređajima, postavkama ili API tokenima**. Izgubljeni uređaj standardno može blokirati samo Owner.
- Svaka osoba može provjeriti **vlastiti** uređaj, uređivati svoj profil (ime, jezik) i promijeniti svoju lozinku.

---

## 4. Rangovi: ko smije upravljati kim?

Članovima tima smije upravljati samo onaj ko ima `users.manage` (standardno Owner) **i** ima viši rang od ciljne osobe. Izuzetak: Owneri smiju upravljati i drugim Ownerima.

| Uloga koja djeluje | smije upravljati (pozivati, uređivati, dodjeljivati ulogu, deaktivirati) |
|---|---|
| Administracija platforme | svim ulogama u svakom restoranu |
| Owner | Ownerima, Managerima, Waiterima u vlastitom restoranu |
| Manager | nikim (nema dozvolu `users.manage`) |
| Waiter | nikim |

**Zaštitna pravila [tehnički provedeno]**

- **Nema samounapređenja:** Niko ne može promijeniti vlastitu ulogu.
- **Nema samoblokade:** Niko ne može deaktivirati vlastiti račun.
- **Posljednji vlasnik / posljednja vlasnica:** Restoran uvijek mora zadržati najmanje jednu aktivnu osobu s ulogom Owner. Posljednja se ne može deaktivirati.
- **Uloga platforme:** Uloga „Platform Administrator" ne može se dodijeliti ni u jednom restoranu. Pozivnice dozvoljavaju samo Owner, Manager ili Waiter. Računi platforme kreiraju se isključivo preko serverske konzole.
- **Vezanost za klijenta:** Osobe drugog restorana nisu ni vidljive ni upravljive.
- **Ništa se ne briše:** Korisnici se deaktiviraju, ne brišu. Njihova knjiženja ostaju s imenom u historiji.

Status korisnika: **Invited** (pozivnica otvorena) → **Active** · **Locked** (privremeno nakon 10 neuspjelih pokušaja) · **Deactivated**.

---

## 5. Uređaji i sesije

- **Automatska registracija:** Svaki uređaj (telefon, tablet, računar) koji se prijavi bilježi se pod **Devices** i imenuje prema hardveru i pregledniku, npr. „iPhone · Safari". Preimenovanje simbolom olovke, npr. „Šank iPhone".
- **Vezivanje za uređaj:** Sesija je vezana za slučajni identifikator uređaja s kojim je započeta. Kopirani kolačić sesije ne radi na drugom uređaju.
- **Blokiranje:** **„Revoke"** (s potvrdom) odbija uređaj od sljedećeg zahtjeva – nezavisno od otvorenih sesija. **„Restore"** ukida blokadu.
- **Trajanje sesije:** 8 sati neaktivnosti; duže samo uz „Keep me signed in on this device".
- **Promjena lozinke** završava sve druge sesije osobe.
- **Deaktivacija** korisnika završava njegove sesije i opoziva njegove API tokene.
- **Suspendovani restorani:** Ako administracija platforme suspenduje restoran, njegovi korisnici se više ne mogu prijaviti.

---

## 6. Administracija platforme: radni način „Open restaurant"

Administracija platforme bez izričitog odabira restorana **nema** pristup podacima restorana: zahtjevi prema sučeljima restorana bez odabranog restorana se odbijaju.

- Preko **„Open restaurant"** administracija bira restoran. Jasan baner pokazuje radni način i može se u svakom trenutku zatvoriti.
- Svaka radnja u tom načinu bilježi se u zapisniku aktivnosti restorana s identitetom administratorice odnosno administratora, uređajem, IP adresom i Request-ID-om.
- Način se koristi samo za postavljanje, podršku i na zahtjev restorana (vidi [Politika lozinki](password-policy.md), odjeljak 9).
- Radnje platforme (kreirati, uređivati, suspendovati, ponovo aktivirati restoran, sistemske postavke) bilježe se u zapisniku aktivnosti cijele platforme.

---

## 7. API tokeni

| Osobina | Pravilo |
|---|---|
| Ko smije kreirati | osobe s `api_tokens.manage` (standardno Owner) |
| Dozvole (abilities) | slobodno odabrane, ali **uvijek podskup dozvola osobe koja kreira token** |
| Identitet | token djeluje kao osoba koja ga je kreirala; knjiženja i zapisi u zapisniku aktivnosti nose njen identifikator |
| Trajanje | najviše 365 dana |
| Spremanje | samo kao SHA-256 hash; tekst se prikazuje jednom; prefiks `gcp_` |
| Kontrola | vidljiva posljednja upotreba (vrijeme, IP adresa) |
| Opoziv | u svakom trenutku ručno; automatski pri deaktivaciji osobe koja ga je kreirala |
| Kolačići | tokeni ne koriste kolačiće i stoga ih CSRF ne pogađa |

**Preporuka za povezivanje s kasom:** samo `cards.scan`, `cards.redeem` i – ako kasa prodaje kartice – `cards.create` odnosno `cards.reload`. Trajanje 90–180 dana, obnovu upisati u kalendar. Token neka kreira osoba koja će vjerovatno dugo ostati u restoranu – pri deaktivaciji te osobe token se opoziva.

---

## 8. Dolazak, promjena, odlazak (joiner – mover – leaver)

### 8.1 Dolazak

1. Owner: **Team → „Invite"** → ime, lična e-mail adresa, uloga po principu najmanjih prava → **„Send invitation"**.
2. Nova osoba otvara link (važi 72 sata) i bira svoju lozinku.
3. Prva prijava na službenom uređaju; Owner imenuje uređaj pod **Devices**.
4. Uvod: [Najbolje sigurnosne prakse](security-best-practices.md), posebno zaključavanje ekrana, bez prosljeđivanja lozinki, ponašanje kod crvenih upozorenja.

### 8.2 Promjena (promjena uloge)

1. Owner: **Team → ⋯ → „Edit"** → nova uloga. Nove dozvole važe od sljedećeg zahtjeva.
2. Kod smanjenja uloge provjeriti je li osoba kreirala API tokene koji su sada preširoki – te opozvati i ponovo kreirati.
3. Ako osoba postane Owner, provjeriti odgovara li njen račun pravilima za Ownere (menadžer lozinki).

### 8.3 Odlazak

**Posljednjeg radnog dana:**

1. **Team → ⋯ → „Deactivate"** – završava sesije, opoziva API tokene.
2. **Devices:** blokirati privatne uređaje osobe.
3. Ako je osoba kreirala API tokene za integracije: unaprijed neka preostala osoba kreira nove tokene i pohrani ih u integraciji, inače integracija prestaje raditi.
4. Kod odlaska vlasnika ili vlasnice: prvo pozvati novu osobu kao Owner, zatim deaktivirati stari račun (zaštita posljednjeg vlasnika ili vlasnice).
5. Nasumično provjeriti zapisnik aktivnosti posljednjih dana na upadljivosti.

---

## 9. Tromjesečna provjera pristupa

Jednom u tromjesečju (npr. u januaru, aprilu, julu, oktobru) od strane Ownera, trajanje oko 15 minuta:

- [ ] **Tim:** Sve aktivne osobe još rade u restoranu. Otvorene pozivnice („Invited") su još potrebne.
- [ ] **Uloge:** Svaka osoba ima najnižu odgovarajuću ulogu. Broj Ownera je što manji, ali najmanje dvije dostupne osobe mogu u hitnom slučaju blokirati uređaje (kod samo jednog Ownera: odrediti pravilo zamjene).
- [ ] **Uređaji:** Nema aktivnih nepoznatih ili rashodovanih uređaja; svi uređaji jasno imenovani.
- [ ] **API tokeni:** Svaki token je još potreban, ima minimalne dozvole, ne ističe neprimjetno; posljednja upotreba i IP adresa su uvjerljive.
- [ ] **Zapisnik aktivnosti:** Sigurnosna upozorenja tromjesečja razjašnjena; zaključavanja računa objašnjena.
- [ ] **Postavke:** Zaštita od kopiranja aktivna, zaključavanje čipova aktivno, ograničenja protiv zloupotrebe odgovarajuća.
- [ ] **Rezultat dokumentovan:** datum, osoba koja provjerava, promjene (npr. u kratkoj bilješci ili u operativnom priručniku restorana).

---

Verzija 1.0 · Stanje: septembar 2026.
