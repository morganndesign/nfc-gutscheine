# GiftCard Pro — Brošura proizvoda

*Tekst i upute za prelom brošure od 12 stranica (A5 uspravno, štampa i PDF). Svaka stranica: napomena o prelomu, zatim tekst onako kako se štampa.*

**Opća pravila preloma:** font Geist (zamjena za štampu: Inter), naslovi Semibold sa zbijenim razmakom slova, osnovni tekst 10,5 pt / 1,5. Boje prema priručniku brenda: Tinta #0F172A za naslove i površine, Papir #FAFAFA kao pozadina, Šafran #E8A33D najviše 10 % po stranici. Brojevi s tabelarnim ciframa. Fotografije: pravi restorani, prirodno svjetlo, ruke i trenuci — bez stock fotografija. Dok fotografije ne budu spremne, rezervisana mjesta u uglastim zagradama ostaju.

---

## Stranica 1 — Naslovnica

**Prelom:** cijela površina u boji Tinte. Gore lijevo logo (kartica sa šafran NFC lukovima, logotip u bijeloj, „Pro" u boji Kamen). Sredina: veliki naslov u bijeloj. Donja polovina: `[Fotografija: ruka drži tamnu poklon karticu uz pametni telefon, restoran zamućen u pozadini]`. Dolje sitno web-adresa.

> # Poklon kartice koje se koriste kao da plaćate karticom.
>
> NFC poklon kartice za restorane, kafiće i barove.
>
> giftcardpro.at

---

## Stranica 2 — Problem

**Prelom:** lijeva polovina fotografija `[Fotografija: registrator s papirnim bonovima pored kase, hemijska olovka, lista za precrtavanje]`. Desna polovina tekst, četiri kratka pasusa s linijskim ikonama.

> ## Poklon bonovi su dobar posao. Papir ga otežava.
>
> **Traje.** Gost plaća bonom. Konobar traži listu, provjerava broj, precrtava i zapisuje ostatak — dok sto čeka.
>
> **Nesigurno je.** Papir se može kopirati, iznosi promijeniti, bon iskoristiti dvaput. Najčešće se primijeti kad je već kasno.
>
> **Nejasno je.** Koliko je novca od bonova trenutno otvoreno? Svaki prodani, a neiskorišteni bon je novac koji Vaši gosti još imaju kod Vas. Mnogi objekti taj broj ne znaju tačno.
>
> **Djeluje sitno.** List papira u koverti za poklon od 100 € — to ne dolikuje Vašem restoranu.

---

## Stranica 3 — Kartica

**Prelom:** velika slika prednje i zadnje strane kartice (`../../screenshots/print-card.png`) na pozadini boje Papir, blago pomaknute. Ispod tri karakteristike jedna pored druge.

> ## Poklon koji nešto znači.
>
> GiftCard Pro kartica ima format bankovne kartice (85,6 × 54 mm) i štampana je s obje strane u Vašem dizajnu. Naprijed: Vaš restoran, vrijednost, ime osobe kojoj se poklanja. Pozadi: QR kod, 16-cifreni broj kartice, rok važenja i uputa za prislanjanje.
>
> **Na kartici nema novca.** U čipu i QR kodu nalazi se samo siguran, nasumičan link. Stanje i historija nalaze se na serveru. Ako se kartica izgubi, stanje prebacite na novu — stara odmah prestaje raditi.
>
> **Tri varijante.**
> - NFC kartica (NTAG215, preporučeno) — prislanjanje i QR kod
> - NFC kartica sa zaštitom od kopiranja (NTAG 424 DNA, u paketu Pro) — svaki dodir kriptografski potpisan
> - QR kartica — štampate je sami, besplatno
>
> Štampani tekstovi na jeziku Vašeg restorana (njemački ili engleski).

---

## Stranica 4 — Aplikacija za konobare

**Prelom:** tri ekrana telefona u redu (`../../screenshots/waiter-ready.png`, `../../screenshots/waiter-amount.png`, `../../screenshots/waiter-success.png`), iznad naslov, ispod tri koraka s brojevima u šafran krugovima.

> ## Prisloni. Iskoristi. Gotovo.
>
> **1. Očitajte karticu.** Na Androidu jednom dodirnite **„Scan card"** — nakon toga se svaka kartica očita čim dotakne telefon. Na iPhoneu prislonite karticu uz gornji dio uređaja ili skenirajte QR kod kamerom. Bez čipa i kamere: ukucajte broj kartice.
>
> **2. Ukucajte iznos.** Tastatura kao na kasi: `2 4 9 0` daje 24,90 €. Ili **„Full balance"** za cijelo stanje.
>
> **3. Iskoristite.** Veliko dugme **„Redeem"**, zelena kvačica, preostalo stanje za gosta. Sljedeća kartica može se odmah prisloniti.
>
> Provjera kartice oko 0,1 sekunde, iskorištavanje u sistemu oko 0,5 sekundi (izmjereno). Naš cilj za stolom, uključujući čovjeka: manje od 5 sekundi.
>
> Aplikacija radi u pregledniku svakog pametnog telefona i stavlja se na početni ekran — bez App Storea. Jasne poruke kad je kartica blokirana, zamijenjena ili istekla. Interfejs je trenutno na engleskom; njemačka verzija planirana je za četvrti kvartal 2026.

---

## Stranica 5 — Kontrolna tabla za Vas

**Prelom:** snimak ekrana `../../screenshots/owner-dashboard.png` preko cijele širine, ispod četiri pokazatelja kao pločice, dolje napomena o tamnom prikazu s malim `../../screenshots/dark-dashboard.png`.

> ## Svaki euro se može pratiti.
>
> | Pokazatelj | Šta Vam govori |
> |---|---|
> | **Outstanding balance** | Koliko je novca od poklon kartica još otvoreno i na koliko kartica — Vaša otvorena obaveza. |
> | **Revenue this month** | Prodaja kartica i dopune, u poređenju s prethodnim mjesecom. |
> | **Redeemed this month** | Koliko su gosti platili poklon karticama, uključujući danas. |
> | **Cards sold** | Prodane kartice i koliko ih je u upotrebi. |
>
> Uz to grafikoni za 7, 30 i 90 dana, mjesečni prihodi, lista kartica s pretragom i filterima, nepromjenjiv dnevnik transakcija i podaci o kupcima po želji. Izvoz u CSV s decimalnim zarezom — otvara se direktno u Excelu, spreman za Vašeg knjigovođu.
>
> Prodati karticu, dopuniti, prebaciti stanje, zamijeniti izgubljenu karticu, blokirati, stornirati transakciju: sve s nekoliko klikova, sve zapisano. Na laptopu, tabletu i telefonu, u svijetlom ili tamnom prikazu.

---

## Stranica 6 — Sigurnost

**Prelom:** pozadina u boji Tinte, bijela slova. Tri bloka s linijskim ikonama u šafranu. Dolje napomena o hostingu.

> ## Zaštita od prevara i grešaka.
>
> **Kartica**
> - Samo nasumičan 122-bitni link, bez novca, bez podataka
> - Brojevi kartica nasumični, ne redni
> - Vezanje čipa prepoznaje kopirane kartice
> - NTAG 424 DNA: kriptografski potpis i brojač — kopije i ponavljanja se odbijaju
>
> **Transakcije**
> - Svaka transakcija nepromjenjivo u dnevniku; zbir transakcija = stanje
> - Dvostruki dodir ili greška mreže nikad ne knjiže dvaput
> - Testirano 20 istovremenih iskorištavanja na jednoj kartici: nikad se ne skine više nego što postoji
> - Storno kao protuknjiženje — ništa se ne briše
>
> **Ljudi i uređaji**
> - Svaka osoba ima svoju prijavu; uloge za vlasnika, menadžera i konobare
> - Svaki uređaj je vidljiv; izgubljeni telefon blokirate jednim klikom
> - Zapisnik aktivnosti (audit log): ko, kada, šta — upozorenja kod sumnjivih radnji
>
> Hosting kod Hetzner Online GmbH u podatkovnim centrima u Njemačkoj (EU). Noćne sigurnosne kopije, šifrovane veze, bez kolačića za praćenje.

---

## Stranica 7 — Za Vaše goste

**Prelom:** fotografija `[Fotografija: gost prislanja karticu uz svoj telefon, vidi se stranica sa stanjem]` lijevo, `../../screenshots/public-balance.png` desno u okviru telefona.

> ## Pokloniti i iskoristiti bez komplikacija.
>
> **Ko poklanja**, dobija karticu koju je lijepo predati — s imenom osobe kojoj je namijenjena. Po želji stiže potvrda e-mailom.
>
> **Ko dobija poklon**, prisloni karticu uz svoj telefon ili skenira QR kod i odmah vidi stanje, status i rok važenja — na jeziku Vašeg restorana, bez aplikacije i bez prijave. Po želji e-mail podsjeti 30 dana prije isteka ili kad je stanje nisko.
>
> **Pri plaćanju** dovoljna je kartica. Nema koverte koja ostane kod kuće, nema traženja broja. Moguće je djelimično iskorištavanje; ostatak ostaje na kartici.
>
> Vi odlučujete je li stranica sa stanjem javna i šalju li se e-mailovi.

---

## Stranica 8 — Cijene

**Prelom:** tri kartice s cijenama jedna pored druge (na A5 moguće jedna ispod druge), Pro sa šafran okvirom. Ispod cijene kartica i 0 % provizije u posebnom okviru.

> ## Fer cijene. 0 % provizije.
>
> | | **Start** | **Pro** | **Gruppe** (Grupa) |
> |---|---|---|---|
> | Mjesečno | 29 € | 59 € | od 129 € (do 3 lokacije) + 39 € po dodatnoj lokaciji |
> | Godišnje | 290 € | 590 € | individualno |
> | Idealno za | jedan restoran, kafić, bar | mnogo kartica, visoki sigurnosni zahtjevi | lance, više lokacija, hotele |
>
> **Start:** 1 lokacija · neograničeno kartica i transakcija (fer korištenje) · neograničeno članova tima i uređaja · QR i NFC kartice (NTAG213/215/216) · aplikacija za konobare · kontrolna tabla · izvoz · e-mailovi za goste · stranica sa stanjem · podrška e-mailom (odgovor u roku od jednog radnog dana) · video-uvođenje
>
> **Pro:** sve iz paketa Start · NTAG 424 DNA kartice sa zaštitom od kopiranja · API pristup (npr. za povezivanje s kasom) · lično uvođenje (online ili na licu mjesta u Beču) · telefonska podrška · odgovor u roku od 4 radna sata · pomoć pri dizajnu kartice
>
> **Gruppe:** sve iz paketa Pro za svaku lokaciju · jedna kontakt-osoba · uvođenje za sve lokacije · individualni ugovor i SLA. Svaka lokacija trenutno se vodi kao zaseban račun.
>
> **0 % provizije** na prodaju i iskorištavanje. Bez naknade za postavljanje. Mjesečni otkaz; godišnji paket = 2 mjeseca gratis.
>
> **Kartice:** 100 štampanih NFC kartica, okvirna cijena 249 € · 250 kartica 499 € · NTAG 424 DNA oko 4–6 € po kartici · QR kartice sami štampate besplatno. *Okvirne cijene, zavisno od količine i štampe — obavezujuća ponuda na upit.*
>
> **Postavljanje i obuka na licu mjesta:** 149 € jednokratno (opcionalno).
>
> Sve cijene neto, uz 20 % PDV-a (Austrija). Samo za firme.

---

## Stranica 9 — Spremni za jedan dan

**Prelom:** uspravna vremenska linija s četiri stanice, desno mali `../../screenshots/new-card.png`. Dolje okvir „30 dana besplatnog testiranja".

> ## Danas se prijavite, večeras naplaćujete poklon karticom.
>
> **1. Odredite pravila kartica.** Najmanja i najveća vrijednost, djelimično iskorištavanje, dopuna, rok važenja. Preporučujemo da standardni rok važenja postavite na „bez ograničenja", osim ako Vaš pravni savjetnik ne preporuči drugi model.
>
> **2. Pozovite tim.** Svaka osoba dobija svoj poziv e-mailom i sama postavlja lozinku. Bez zajedničkih prijava.
>
> **3. Kreirajte prvu karticu.** Odaberite iznos, **„Create card"**, upišite čip Android telefonom ili odštampajte QR karticu.
>
> **4. Isprobajte Waiter mode.** Svaki konobar iskoristi probnu karticu. To traje nekoliko minuta po osobi.
>
> Kontrolna tabla Vas kroz sve korake vodi panelom dobrodošlice. U paketu Pro Vas lično pratimo; na licu mjesta u Beču po želji za 149 € jednokratno.
>
> **30 dana besplatnog testiranja.** Bez kreditne kartice, sa svim Pro funkcijama.

---

## Stranica 10 — Česta pitanja (1)

**Prelom:** dvije kolone, pitanja podebljano, odgovori kratki. Bez slika.

> ## Česta pitanja
>
> **Trebaju li moji konobari obuku?**
> Jedva. Prisloniti karticu, ukucati iznos, „Redeem". Većina to savlada nakon jedne probne kartice.
>
> **Radi li to s iPhoneom i Androidom?**
> Da. Android očitava karticu direktno u aplikaciji, iPhone je otvara preko sistemske obavijesti ili kamere. Kao rezerva uvijek se može ukucati broj kartice.
>
> **Šta ako nestane interneta?**
> GiftCard Pro treba internetsku vezu. Ako WiFi ne radi, aplikacija radi preko mobilnih podataka telefona. Offline način rada ne postoji — zato se nikad ništa ne knjiži dvaput ili pogrešno.
>
> **Zamjenjuje li GiftCard Pro moju fiskalnu kasu?**
> Ne. Prodaju i iskorištavanje i dalje knjižite na fiskalnoj kasi, onako kako propiše Vaš porezni savjetnik. GiftCard Pro vodi kartice, stanja i dokaze.
>
> **Mogu li poklon bonove prodavati online?**
> Još ne. Kartice se prodaju u restoranu. Online prodaja planirana je za prvi kvartal 2027.
>
> **Je li interfejs na mom jeziku?**
> Sve za goste — kartica, stranica sa stanjem, e-mailovi — dostupno je na njemačkom i engleskom. Interfejs za osoblje trenutno je na engleskom; njemačka verzija planirana je za četvrti kvartal 2026.

---

## Stranica 11 — Česta pitanja (2)

**Prelom:** kao stranica 10. Dolje sivo osjenčen okvir s pravnom napomenom.

> **Koliko dugo važe poklon kartice?**
> To Vi podešavate. U Austriji plaćeni poklon bonovi bez ograničenja važe 30 godina; ograničenje na tri godine ili manje u općim uslovima prema austrijskom Vrhovnom sudu (OGH) u pravilu nije valjano. Zato preporučujemo „bez ograničenja", osim ako Vaš pravni savjetnik ne preporuči drugačije.
>
> **Šta je s PDV-om i knjigovodstvom?**
> Vrijednosni bonovi za hranu i piće u pravilu su višenamjenski bonovi; PDV nastaje pri iskorištavanju. Otvoreni iznos i sve transakcije u svakom trenutku izvozite za svog knjigovođu.
>
> **Čiji su podaci?**
> Vaši. Sve u svakom trenutku izvozite kao CSV. Nakon isteka ugovora brišemo Vaše podatke nakon 30 dana, osim ako postoji zakonska obaveza čuvanja.
>
> **Gdje su podaci i kako stoji zaštita podataka?**
> Na serverima Hetznera u Njemačkoj (EU). Ugovor o obradi podataka po nalogu prema čl. 28 GDPR-a dobijate uz ugovor. Aplikacija koristi samo tehnički neophodne kolačiće.
>
> **Koliko sam vezan ugovorom?**
> Mjesečni paketi mogu se otkazati do kraja mjeseca, godišnji do kraja ugovornog perioda.
>
> **Šta ako gost izgubi karticu?**
> Ako se kartica može pronaći na kontrolnoj tabli — po broju kartice, imenu kupca, imenu primaoca ili bilješci —, zamijenite je opcijom **„Replace lost card"**. Stanje prelazi na novu karticu, stara je odmah blokirana.
>
> *Nije pravni ni porezni savjet. Informacije se odnose na Austriju. Pravna i porezna pitanja molimo provjerite s poreznim savjetnikom odnosno advokatom.*

---

## Stranica 12 — Kontakt (zadnja strana)

**Prelom:** pozadina u boji Tinte, logo u sredini, ispod kontakt u bijeloj. Okvir s pilot-ponudom sa šafran obrubom. Dolje `[QR kod ka giftcardpro.at]` i sitno red s impresumom.

> ## Isprobajte u svom restoranu.
>
> **Pilot-program u Beču, oktobar–novembar 2026. — 10 mjesta:**
> 3 mjeseca besplatno · zatim 12 mjeseci 50 % · postavljanje na licu mjesta gratis · 50 kartica gratis
>
> **[Ime], osnivačica**
> hallo@giftcardpro.at · [Telefon]
> giftcardpro.at
>
> *„Restoranima dajemo sistem poklon kartica koji radi jednako dobro kao njihova usluga: brzo, pouzdano i lijepo."*
>
> [Firmenname] [Rechtsform] · [Anschrift], 1xxx Wien · [Firmenbuchnummer], [Firmenbuchgericht: Handelsgericht Wien] · UID [UID-Nummer]

---

Verzija 1.0 · Stanje: septembar 2026.
