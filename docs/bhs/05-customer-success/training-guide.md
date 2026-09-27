# Vodič za obuku GiftCard Pro

*Program obuke za konobare, menadžere i vlasnike: ciljevi učenja, tok obuke, vježbe, igre uloga, kviz i potvrda o učešću.*

---

## 1. Pregled

| Modul | Ciljna grupa | Trajanje | Rezultat |
|---|---|---|---|
| **A – Iskorištavanje kartice za stolom** | Konobari (uloga **„Waiter"**) | 15 minuta | Svaki konobar iskoristi karticu za manje od 5 sekundi i zna kada karticu ne smije prihvatiti. |
| **B – Upravljanje karticama** | Menadžeri (uloga **„Manager"**) | 45 minuta | Prodaja, upisivanje, štampanje, storno, blokiranje, zamjena i prijenos stanja; kontrola na kraju dana. |
| **C – Brojke, pravila, tim** | Vlasnici (uloga **„Owner"**) | 30 minuta | Pravno ispravna podešavanja kartica, upravljanje timom i uređajima, razumijevanje pokazatelja i izvoza za poreznog savjetnika. |

**Jezik sučelja:** Sučelje za zaposlene je trenutno na engleskom. U ovom vodiču su dugmad navedena u engleskom originalu podebljano, uz značenje, npr. **„Redeem"** (iskoristi). Sučelje za zaposlene na njemačkom planirano je za Q4 2026. Sve što vide gosti (stranica sa stanjem, odštampana kartica, e-mailovi) dostupno je na njemačkom ili engleskom.

**Prava po ulozi (standard):**

| Radnja | Waiter | Manager | Owner |
|---|---|---|---|
| Skeniranje i iskorištavanje kartice | ✓ | ✓ | ✓ |
| Prodaja, dopuna, upisivanje, štampanje kartice | – | ✓ | ✓ |
| Blokiranje, deblokiranje, zamjena, prijenos, isticanje | – | ✓ | ✓ |
| Storno transakcije, izvozi | – | ✓ | ✓ |
| Uređivanje i anonimizacija podataka kupaca | – | ✓ | ✓ |
| Pregled zapisnika aktivnosti (**„Audit log"**) | – | ✓ | ✓ |
| Pregled uređaja | – | ✓ | ✓ |
| Blokiranje uređaja (**„Revoke"**), pozivanje tima, postavke, API tokeni | – | – | ✓ |

### Priprema trenera

- [ ] Svi učesnici su prihvatili vlastitu pozivnicu i postavili vlastitu lozinku (link za pozivnicu vrijedi 72 sata).
- [ ] Pripremljene najmanje **tri testne kartice** od po 5 € (**„New gift card"**), upisane ili odštampane kao QR kartice. U polje **„Internal notes"** upisati „TESTNA KARTICA obuka".
- [ ] Spreman po jedan Android telefon (Chrome, NFC uključen) i jedan iPhone (XS ili noviji); na oba je web-aplikacija instalirana na početnom ekranu.
- [ ] Odštampano dovoljno primjeraka kratkog uputstva za konobare (odjeljak 2.4).
- [ ] Nakon obuke: stornirati testne transakcije, blokirati testne kartice (**„Block card"**, razlog „Suspicious use" ili vlastiti tekst „Obuka").

---

## 2. Modul A – Konobari (15 minuta)

### 2.1 Ciljevi učenja

Nakon ovog modula svaki konobar zna:

1. prijaviti se na službeni telefon i otvoriti način rada za konobare (**„Waiter mode"**),
2. otvoriti karticu putem NFC-a, QR koda ili broja kartice,
3. iskoristiti djelimičan iznos i cijelo stanje,
4. prepoznati pet najvažnijih poruka i pravilno reagovati,
5. objasniti zašto se podaci za prijavu nikada ne dijele.

### 2.2 Tok obuke

| Minuta | Sadržaj | Metoda |
|---|---|---|
| 0–2 | Zašto poklon kartice? Na kartici nema novca, samo siguran link. Svaka transakcija nosi Vaše ime. | Kratko izlaganje |
| 2–5 | Prijava, **„Keep me signed in on this device"** (ostani prijavljen na ovom uređaju), način rada za konobare. Android: jednom pritisnuti **„Scan card"**. iPhone: karticu prisloniti uz gornji dio telefona, dodirnuti obavijest. | Demonstracija |
| 5–10 | Vježbe A1–A3 (vidi dolje) | Svako samostalno |
| 10–13 | Poruke i reakcije (tabela 2.4), igra uloga 1 | Igra uloga |
| 13–15 | Kviz (5 pitanja), pitanja | Usmeno |

### 2.3 Vježbe

**Vježba A1 – Djelimično iskorištavanje (Android)**
1. Pritisnite **„Scan card"** (skeniraj karticu). Karticu ravno prislonite uz gornji dio poleđine telefona, oko 1 sekunde.
2. Na tastaturi ukucajte `2` `5` `0` → 2,50 €.
3. Pritisnite **„Redeem € 2,50"** (iskoristi 2,50 €).
4. Zelena kvačica: gostu recite **„Remaining balance"** (preostalo stanje).
5. Sljedeću karticu direktno prislonite ili pritisnite **„Next card"** (sljedeća kartica). Nakon 8 sekundi aplikacija se sama vraća.

**Vježba A2 – iPhone ili QR kod**
1. Otključajte iPhone, prislonite karticu uz gornju ivicu, dodirnite obavijest – kartica se otvara u načinu rada za konobare.
2. Alternativno **„Scan QR code"** (skeniraj QR kod) i usmjerite kameru na poleđinu kartice.
3. Pritisnite **„Full balance"** (cijelo stanje), zatim **„Redeem"**.

**Vježba A3 – Ukucavanje broja kartice**
1. Izaberite **„Card number"** (broj kartice).
2. Ukucajte 16 cifara ispod QR koda, **„Find card"** (pronađi karticu).
3. Iskoristite 1 €.

> Cilj: svaka vježba za manje od 5 sekundi od prislanjanja kartice.

### 2.4 Kratko uputstvo za štampanje (za kasu)

| Aplikacija prikazuje | Značenje | Šta radite |
|---|---|---|
| **„More than the balance. Redeem € X and collect the rest otherwise."** | Račun je veći od stanja | Iskoristite **„Full balance"**, ostatak naplatite gotovinom ili karticom. |
| **„This card is blocked"** (crveno) | Kartica je blokirana | Ne prihvatajte karticu. Pozovite menadžera. |
| **„This card was replaced … Ask the guest for the new card."** (crveno) | Kartica je zamijenjena | Pitajte za novu karticu. Staru ne prihvatajte. |
| **„This card has expired."** | Kartica je istekla | Ne iskorištavajte. Pozovite menadžera – gost možda ipak ima pravo. |
| **„This card has no balance left."** | Stanje 0 € | Ljubazno obavijestite gosta, račun naplatite normalno. |
| **„This card is not activated yet."** | Kartica još nije aktivirana | Pozovite menadžera (aktivacija u kontrolnoj tabli). |
| **„No card with this number."** | Greška pri kucanju | Provjerite cifre i ukucajte ponovo. |
| **„This is not one of our gift cards."** | Strana ili nepoznata kartica | Ne prihvatajte. |
| **„No connection to the server."** | Nema interneta | Provjerite Wi-Fi, pritisnite ponovo. **Ništa nije proknjiženo, aplikacija nikada ne knjiži dvaput.** |

**Važno:** Prodaja i iskorištavanje moraju se dodatno proknjižiti u fiskalnoj kasi – onako kako je odredila uprava restorana. GiftCard Pro nije fiskalna kasa.

### 2.5 Igre uloga

**Igra uloga 1 – Gost s blokiranom karticom**
*Situacija:* Gost daje karticu, aplikacija crveno prikazuje **„This card is blocked: Reported lost"**.
*Ispravna reakcija:* ostati miran, bez prigovora. „Ova kartica je kod nas blokirana. Pozvat ću kolegicu, ona će to riješiti s Vama." Menadžer u historiji kartice provjerava ko je i kada blokirao. Ako je gost zakoniti vlasnik (npr. kartica je pronađena), menadžer može deblokirati (**„Unblock"**) ili izdati zamjensku karticu.
*Greške koje izbjegavamo:* ipak skinuti iznos „na povjerenje", zadržati karticu bez dogovora, raspravljati za stolom.

**Igra uloga 2 – Kartica nije pronađena**
*Situacija:* Nakon ukucavanja broja pojavljuje se **„No card with this number. Check the digits and try again."**
*Ispravna reakcija:* cifre naglas čitati u blokovima po četiri, ponovo ukucati. Ako se pri skeniranju pojavi **„This is not one of our gift cards."**, pitati: „Da li je kartica možda iz drugog restorana?" Ne više od dva-tri pokušaja – nakon mnogo neuspješnih pokušaja aplikacija usporava (**„Too many failed card lookups. Please wait a moment and try again."**).

**Igra uloga 3 – Iznos veći od stanja**
*Situacija:* Račun 68,40 €, stanje 50 €.
*Ispravna reakcija:* „Na Vašoj kartici je još 50 €. Skinut ću taj iznos; preostalih 18,40 € – gotovinom ili karticom?" → **„Full balance"**, **„Redeem € 50,00"**, naplatiti ostatak.

### 2.6 Kviz modul A (s odgovorima)

1. *Šta je sačuvano na kartici?* – Samo siguran link, bez novca i bez ličnih podataka.
2. *Aplikacija javlja „No connection to the server". Da li je proknjiženo?* – Ne. Provjeriti vezu i pritisnuti ponovo; dvostrukog knjiženja nikada nema.
3. *Kartica je crveno označena kao „replaced". Šta raditi?* – Ne prihvatiti, pitati gosta za novu karticu.
4. *Smijem li se prijaviti podacima kolegice?* – Ne. Svaka transakcija se čuva s imenom, vremenom i uređajem.
5. *Kako ukucavate 7,00 €?* – `7` `0` `0`.

---

## 3. Modul B – Menadžeri (45 minuta)

### 3.1 Ciljevi učenja

1. Prodati karticu, kreirati je s podacima kupca i aktivirati.
2. Upisati NFC karticu Androidom ili odštampati QR karticu.
3. Iskoristiti i dopuniti karticu za radnim stolom.
4. Stornirati pogrešnu transakciju, blokirati, deblokirati i zamijeniti karticu, prenijeti stanje.
5. Pretraživati listu kartica i dnevnik transakcija, izvesti CSV.
6. Prepoznati sigurnosna upozorenja u zapisniku aktivnosti.

### 3.2 Tok obuke

| Minuta | Sadržaj |
|---|---|
| 0–5 | Obilazak: **Dashboard**, **Gift cards** (kartice), **Transactions** (transakcije), **Customers** (kupci), **Devices** (uređaji), **Audit log** (zapisnik aktivnosti) |
| 5–15 | Vježba B1 – prodaja kartice i upisivanje/štampanje |
| 15–20 | Vježba B2 – iskorištavanje i dopuna za radnim stolom |
| 20–30 | Vježba B3 – storno, blokiranje, deblokiranje |
| 30–37 | Vježba B4 – zamjena i prijenos |
| 37–42 | Pretraga, filteri, **„Export CSV"**, zapisnik aktivnosti |
| 42–45 | Kviz i pitanja |

### 3.3 Vježbe

**Vježba B1 – Prodaja kartice**
1. **Gift cards → „New gift card"** (nova poklon kartica).
2. Izaberite vrijednost (25/50/75/100/150 €) ili je unesite slobodno (**„Amount"**).
3. **„Valid until"** (vrijedi do): preuzeti standard iz postavki – preporuka „bez isteka", vidi modul C.
4. **„Customer"**: **„Anonymous"** (anonimno), **„Existing"** (postojeći kupac) ili **„New customer"** s imenom, e-mailom, telefonom. S e-mailom kupac dobija potvrdu kupovine (ako su e-mailovi za kupce uključeni).
5. **„Recipient name"** (ime obdarene osobe, štampa se na kartici), **„Card type"** (tip kartice, obično NTAG215), **„Activate immediately"** (odmah aktiviraj) ostaviti uključeno.
6. **„Create card"** (kreiraj karticu). Pojavljuje se **„Card created"**.
7. Android s Chromeom: **„Write NFC tag"** (upiši NFC čip) → praznu karticu prisloniti uz poleđinu. Inače: **„Print"** (štampaj) za QR karticu.
8. Prodaju proknjižiti u fiskalnoj kasi.

**Vježba B2 – Iskorištavanje i dopuna za radnim stolom**
Karticu potražiti u **Gift cards** (broj, kupac, primalac ili napomena), otvoriti, **„Redeem"** (iskoristi) 3 €; zatim **„Reload"** (dopuni) 10 €. Napomena: dopuna je moguća samo ako je dozvoljena u postavkama.

**Vježba B3 – Storno, blokiranje, deblokiranje**
1. U historiji kartice ili pod **Transactions** kod iskorištavanja izabrati ↺ **„Reverse"** (storniraj), razlog „Wrong amount". Ispravka se pojavljuje kao novi red; ništa se ne briše.
2. **⋯ → „Block card"** (blokiraj karticu), razlog **„Reported stolen"**. Skenirati službenim telefonom: crvena poruka.
3. **⋯ → „Unblock"** (deblokiraj).

**Vježba B4 – Zamjena i prijenos**
1. **⋯ → „Replace lost card"** (zamijeni izgubljenu karticu), razlog **„Lost"**, **„Issue replacement"** (izdaj zamjenu). Novi broj, novi link, stanje prelazi na novu karticu; stara kartica odmah prestaje važiti. Aplikacija odmah otvara novu karticu za upisivanje.
2. Skenirati staru karticu: **„This card was replaced …"**.
3. Otvoriti drugu testnu karticu, **⋯ → „Transfer balance"** (prenesi stanje), unijeti **„Target card number"** (broj ciljne kartice), iznos ostaviti prazan = cijelo stanje.

### 3.4 Igre uloga

**Igra uloga 4 – Gost je izgubio karticu**
Gost navodi ime i datum kupovine. Menadžer pretražuje **Gift cards** po kupcu ili primaocu. Ako karticu nedvosmisleno pronađe, **„Replace lost card"**. Ako je ne pronađe nedvosmisleno, ne izdavati zamjensku karticu – zatražiti dokaz (potvrda kupovine e-mailom, fiskalni račun).

**Igra uloga 5 – Konobar je proknjižio pogrešan iznos**
Proknjiženo 42 € umjesto 24 €. Stornirati transakciju (**„Reverse"**, razlog „Wrong amount"), zatim karticu u načinu rada za konobare ponovo iskoristiti s 24 €. Ispraviti i fiskalnu kasu.

### 3.5 Kviz modul B (s odgovorima)

1. *Kako ispravljate pogrešnu transakciju?* – Putem **„Reverse"**; nastaje protuknjiženje, originalni red ostaje.
2. *Šta se dešava sa starom karticom kod „Replace lost card"?* – Odmah prestaje raditi; stanje je na novoj kartici s novim brojem.
3. *Kada blokirati umjesto zamijeniti?* – Blokirati kod sumnje ili do razjašnjenja (povratno); zamijeniti kada gost treba dobiti novu karticu.
4. *Može li se stornirati transakcija zamijenjene ili istekle kartice?* – Ne (**„Transactions of replaced or expired cards cannot be reversed."**).
5. *Gdje vidite ko je blokirao karticu?* – U historiji kartice i u **„Audit log"**.
6. *Kojim uređajem upisujete karticu u jednom koraku?* – Android telefonom s Chromeom.

---

## 4. Modul C – Vlasnici (30 minuta)

### 4.1 Ciljevi učenja

1. Svjesno podesiti pravila kartica pod **Settings → Gift cards**, posebno rok važenja.
2. Pozvati tim, dodijeliti uloge, deaktivirati osobe; imenovati i blokirati uređaje.
3. Razumjeti četiri pokazatelja i koristiti ih za knjigovodstvo i obaveze.
4. Pripremiti izvoze za poreznog savjetnika.
5. Poznavati e-mailove za kupce i funkcije zaštite podataka.

### 4.2 Tok obuke

| Minuta | Sadržaj |
|---|---|
| 0–8 | **Settings → Gift cards**: minimalna/maksimalna vrijednost (standard 5 € / 1.000 €), maksimalno stanje kartice (2.000 €), maksimalno pojedinačno iskorištavanje, **„Default validity (months)"**, **„Max. redemptions per card per hour"** (standard 10), dopuna, djelimično iskorištavanje, javna provjera stanja, zaštita od kloniranja, e-mailovi za kupce, boja brenda, podnožje e-maila |
| 8–14 | **Team → „Invite"**, uloge, **„Resend invitation"**, **„Deactivate"**; **Devices**: preimenovanje, **„Revoke"** |
| 14–22 | **Dashboard**: **„Outstanding balance"**, **„Revenue this month"**, **„Redeemed this month"**, **„Cards sold"**; grafikoni |
| 22–27 | **„Export CSV"** u **Gift cards** i **Transactions**; fiskalna kasa i porezni savjetnik |
| 27–30 | Kviz, otvorena pitanja |

### 4.3 Pravna napomena o roku važenja (obavezni dio)

Plaćeni poklon bonovi u Austriji u pravilu zastarijevaju tek nakon 30 godina (§ 1478 ABGB). Prema OGH (Vrhovni sud Austrije), paušalno ograničenje na 3 godine ili manje u općim uslovima poslovanja u pravilu je grubo nepovoljno (§ 879 st. 3 ABGB) i stoga nevažeće. Tvornička postavka GiftCard Pro je 36 mjeseci. **Preporuka: „Default validity (months)" postaviti na 0 (bez isteka)**, osim ako Vaš pravni savjetnik odobri drugi model. Kada kartica istekne, GiftCard Pro otpisuje preostalo stanje; gost ipak može imati pravo – tada izdajte zamjensku karticu ili prenesite stanje. Promjena tvorničke postavke je planirana.
*Nije pravni savjet – provjerite s poreznim savjetnikom odnosno advokatom.*

### 4.4 Vježbe

**Vježba C1 – Pravila kartica:** provjeriti **„Default validity (months)"** i nakon konsultacije postaviti na 0; svjesno odrediti **„Partial redemption"** (djelimično iskorištavanje) i **„Allow reloading"** (dozvoli dopunu).
**Vježba C2 – Tim:** pozvati testnu osobu s ulogom **„Waiter"** (**„Send invitation"**), ponovo poslati pozivnicu, zatim je deaktivirati.
**Vježba C3 – Uređaji:** telefon za obuku pod **Devices** olovkom preimenovati u „Bar obuka", potvrditi **„Revoke"** (blokiraj), skenirati tim telefonom (poruka **„This device has been revoked. Please contact your manager."**), zatim **„Restore"** (vrati).
**Vježba C4 – Izvoz:** filtrirati **Transactions** po periodu, **„Export CSV"**, otvoriti datoteku u Excelu.

### 4.5 Igra uloga 6 – Porezna savjetnica pita za otvorene bonove

„Koliki su otvoreni poklon bonovi na dan 31. decembra?" → zabilježiti **„Outstanding balance"** na taj dan odnosno izvesti listu kartica kao CSV (stanje po kartici). Izvesti dnevnik transakcija za period. Napomena: poreski tretman PDV-a (bon za jednu namjenu ili za više namjena) određuje porezni savjetnik.

### 4.6 Kviz modul C (s odgovorima)

1. *Koji pokazatelj prikazuje Vašu otvorenu obavezu?* – **„Outstanding balance"**.
2. *Šta znači „Default validity" = 0?* – Nove kartice ne ističu.
3. *Službeni telefon je ukraden. Šta raditi?* – **Devices → „Revoke"**; djeluje odmah.
4. *Koliko dugo vrijedi pozivnica?* – 72 sata; nakon toga **„Resend invitation"**.
5. *Da li GiftCard Pro zamjenjuje fiskalnu kasu?* – Ne. Prodaja i iskorištavanje se dodatno knjiže u fiskalnoj kasi.
6. *Šta radi „Anonymize" kod kupca?* – Uklanja ime, e-mail, telefon i napomene; kartice, stanja i transakcije ostaju.

---

## 5. Potvrda o učešću

> **Potvrda o učešću**
>
> [Ime Prezime] je dana [datum] uspješno završio/završila obuku **GiftCard Pro – modul [A / B / C]: [naziv]** u restoranu [naziv restorana].
>
> Sadržaj: [ciljevi modula u natuknicama]
> Praktične vježbe: testno iskorištavanje, storno, blokiranje, zamjena – izvršeno.
> Kviz: [x] od [y] pitanja tačno.
>
> [Mjesto], dana [datum]
>
> ______________________ ______________________
> Trener/trenerica Učesnik/učesnica
>
> [Firmenname] · [Anschrift], 1xxx Wien

---

## 6. Obuka trenera: uvođenje novih zaposlenih

Obuku novih konobara u pravilu preuzima iskusna kolegica ili menadžer u restoranu.

**Prije prve smjene**
1. Vlasnik/vlasnica poziva osobu na njenu vlastitu e-mail adresu (**Team → „Invite"**, uloga **„Waiter"**).
2. Nova osoba sama postavlja lozinku (najmanje 12 znakova, velika i mala slova, jedna cifra).
3. Jedna prijava na službeni telefon – uređaj se automatski registruje.

**U prvoj smjeni (10 minuta u mirnijem periodu)**
- Vježbe A1–A3 s testnom karticom; zajedno pročitati kratko uputstvo 2.4.
- Prvo pravo iskorištavanje prati iskusna osoba.

**Savjeti za trenere**
- Pokazati, ne objašnjavati: svaka osoba sama kuca.
- Tri rečenice koje svaki konobar mora znati: „Skinut ću iznos s kartice." – „Ova kartica je blokirana, pozvat ću kolegicu." – „Ništa nije proknjiženo, pokušat ću ponovo."
- Testne kartice jasno označiti i nakon obuke blokirati.
- Ko napušta restoran: posljednjeg dana **„Deactivate"** (deaktiviraj). Transakcije ostaju s imenom.
- Pitanja na koja ne znate odgovor: support@giftcardpro.at.

**Materijali:** kratko uputstvo (odjeljak 2.4), video „Iskorištavanje za stolom" (vidi scenarije za videe), baza znanja.

---

Verzija 1.0 · Stanje: septembar 2026.
