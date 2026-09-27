# Tekstovi početne stranice giftcardpro.at

*Svrha: Kompletni tekstovi početne stranice marketinškog sajta – navigacija, hero s dvije A/B varijante, sve sekcije, cijene, česta pitanja, podnožje, SEO metapodaci i mikrotekstovi, uključujući formular za demo.*

---

## SEO metapodaci

| Polje | Tekst |
|---|---|
| SEO naslov | GiftCard Pro – NFC poklon kartice za restorane u Austriji |
| Meta opis | Poklon kartice s NFC čipom i QR kodom za Vaš restoran. Naplata za stolom u sekundi, svaki euro evidentiran, 0 % provizije. Od 29 € mjesečno. |
| OG naslov | Poklon kartice jednostavne kao plaćanje karticom |
| OG opis | Sistem poklon kartica za ugostiteljstvo: brz za stolom, siguran od prevara, pošten – bez provizije. |
| OG slika | `[Slika 1200 × 630: poklon kartica u Tinti sa šafran NFC lukovima na drvenom stolu, pored telefon s ekranom uspjeha]` |
| Canonical | `https://giftcardpro.at/bhs/` |
| Jezik | `bs` / `hr` / `sr-Latn` (hreflang alternativa: `de-AT` na `/`) |
| Strukturirani podaci | `Organization`, `SoftwareApplication` (applicationCategory: BusinessApplication, offers: 29 € / 59 € neto), `FAQPage` |

---

## Navigacija

**Raspored:** Ljepljivo zaglavlje, bijelo, visine 64 px, tanka linija (#E4E4E7) ispod. Logo lijevo, meni u sredini, dugmad desno. Na mobitelu: logo + hamburger meni + dugme „Isprobajte“.

| Element | Tekst | Cilj |
|---|---|---|
| Logo | GiftCard Pro | `/bhs/` |
| Meni 1 | Funkcije ▾ | Padajući meni (vidi ispod) |
| Meni 2 | Cijene | `/bhs/cijene` |
| Meni 3 | Sigurnost | `/bhs/funkcije/sigurnost` |
| Meni 4 | Pitanja | `/bhs/#pitanja` |
| Meni 5 | Kontakt | `/bhs/kontakt` |
| Jezik | DE · BHS | `/` |
| Sekundarno dugme | Prijava | `app.giftcardpro.at` |
| Primarno dugme | Isprobajte besplatno | `/registracija` |

**Padajući meni „Funkcije“:**
- Konobarska aplikacija – *Naplata u sekundi*
- NFC i QR kartice – *Kartice koje ostavljaju utisak*
- Kontrolna tabla – *Otvoreni iznosi na oku*
- Sigurnost i zaštita od prevara – *Na kartici nema novca*
- Tim i uređaji – *Ko smije šta, na kojem uređaju*
- Zaštita podataka i pravo – *Hosting u EU, GDPR, rok važenja*

---

## 1. Hero

**Raspored:** Tekst lijevo (najviše 560 px širine), desno kompozicija odštampane kartice i telefona s ekranom uspjeha. Pozadina Papir.

### Varijanta A (korist)

**Naslov (H1):** Poklon kartice jednostavne kao plaćanje karticom.
**Podnaslov:** Prave kartice s NFC čipom za Vaš restoran. Naplata za stolom telefonom, svaki euro evidentiran, bez provizije.

### Varijanta B (radnja)

**Naslov (H1):** Prislonite. Naplatite. Gotovo.
**Podnaslov:** GiftCard Pro je sistem poklon kartica za ugostiteljstvo: kartica na telefon, upišete iznos, vidite preostalo stanje – za nekoliko sekundi i bez obuke.

**Hipoteza testa:** Varijanta A se obraća vlasnicima kroz vrijednost i utisak, varijanta B kroz brzinu u usluzi. Primarna metrika: klikovi na „Isprobajte besplatno“. Sekundarna: zahtjevi za demo. Trajanje najmanje 2 sedmice ili 1.000 posjeta po varijanti.

**Primarni CTA:** Isprobajte besplatno
**Sekundarni CTA:** Zatražite demo
**Mikrotekst:** 30 dana sve Pro funkcije · bez kreditne kartice · 0 % provizije

---

## 2. Traka povjerenja

**Raspored:** Četiri oznake u jednom redu, ikona + kratak tekst, Kamen na bijeloj.

- `badge-percent` 0 % provizije
- `server` Hosting u EU
- `smartphone` Bez instalacije aplikacije
- `map-pin` Razvijeno u Beču

**Placeholder (nakon odobrenja):** `[Logotipi pilot restorana – tek nakon pisanog odobrenja]`

---

## 3. Problem

**Raspored:** Uska kolona teksta, centrirana, puno praznog prostora.

**H2:** Papirni poklon bonovi koštaju više nego što se čini.

Papirić sa štambiljem, spisak u Excelu, poziv šefu da li bon još važi. Za stolom to traje, lako se kopira, a na kraju godine nema jasne brojke. Online prodavnice poklon bonova rješavaju dio toga – i za to često zadrže procenat od svake prodaje.

---

## 4. Rješenje: pet stubova

**Raspored:** Pet redova naizmjenično tekst/slika (cik-cak), svaki sa snimkom ekrana. Na mobitelu: slika ispod teksta.

**H2:** Sistem poklon kartica koji radi jednako dobro kao Vaša usluga.

### Brzo za stolom
Konobarska aplikacija radi u pregledniku na svakom telefonu. Prislonite karticu ili skenirajte QR kod, upišite iznos kao na kasi, potvrdite. Sistemu za to treba oko pola sekunde. Za stolom ciljamo ispod pet sekundi – s čovjekom.
Snimak ekrana: `../../screenshots/waiter-amount.png` · Link: Konobarska aplikacija →

### Zaštićeno od prevara i grešaka
Na kartici nije pohranjen novac, samo nasumičan link. Svaka transakcija se knjiži tačno jednom, čak i kad se pritisne dvaput. Kopirane kartice sistem prepoznaje po oznaci čipa – s NTAG 424 DNA čak i kriptografski.
Snimak ekrana: `../../screenshots/card-detail.png` · Link: Sigurnost →

### Jasan pregled otvorenih iznosa
Kontrolna tabla pokazuje koliko stanja je još otvoreno i na koliko kartica – dakle, šta još dugujete gostima. Uz to prodaja, iskorištavanja i dopune po mjesecu.
Snimak ekrana: `../../screenshots/owner-dashboard.png` · Link: Kontrolna tabla →

### Poklon koji nešto znači
Kartice veličine bankovne kartice, odštampane u Vašem dizajnu, s iznosom i imenom osobe kojoj su namijenjene. Gost sam provjerava stanje svojim telefonom.
Snimak ekrana: `../../screenshots/print-card.png` · Link: Kartice →

### Pošteno: bez provizije
Plaćate fiksnu mjesečnu pretplatu. Ono što prodate kroz poklon kartice, u potpunosti je Vaše. I podaci su Vaši – izvoz u svakom trenutku.
Link: Cijene →

---

## 5. Kako funkcioniše

**H2:** Od prve kartice do naplate

1. **Postavljanje.** Otvorite nalog, odredite pravila za kartice, pozovite tim e-mailom. Panel dobrodošlice vodi Vas kroz sve korake.
2. **Izdavanje kartice.** Izaberite iznos, po želji upišite gosta i primaoca, upišite čip jednim dodirom ili odštampajte karticu.
3. **Prodaja.** Gost plaća na Vašoj fiskalnoj kasi, Vi mu predajete karticu.
4. **Naplata.** Konobar prisloni karticu na telefon, upiše iznos i vidi preostalo stanje.

**Mikrotekst:** GiftCard Pro ne zamjenjuje fiskalnu kasu. Prodaju i iskorištavanje knjižite kao i obično u svojoj kasi.

---

## 6. Za koga

**Raspored:** Tri kolone s ulogama.

**H2:** Napravljeno za sve koji s tim rade.

| Vlasnice i vlasnici | Menadžeri | Konobari i konobarice |
|---|---|---|
| Otvoreni iznosi, promet i iskorištavanja na prvi pogled. Bez provizije, jasni mjesečni troškovi. | Pozovite tim, dodijelite uloge, upravljajte uređajima, pratite svaku transakciju. | Tri dodira umjesto pitanja. Jasne poruke kad je kartica blokirana ili istekla. |

---

## 7. Cijene

**Raspored:** Prekidač „Mjesečno / Godišnje (2 mjeseca gratis)“ na vrhu. Tri kartice paketa, srednja istaknuta. Ispod cijene kartica i link na pitanja.

**H2:** Jasne cijene. 0 % provizije.
**Uvod:** Svi paketi uključuju neograničen broj kartica, transakcija, članova tima i uređaja. Otkaz svaki mjesec.

### Kartica paketa Start
- **Naziv:** Start
- **Za:** Jedan restoran, kafić ili bar
- **Cijena:** 29 € / mjesečno · godišnje 290 €
- **Uključeno:**
  - 1 lokacija
  - Neograničeno kartica i transakcija (fer korištenje)
  - Neograničeno članova tima i uređaja
  - QR kartice i NFC kartice (NTAG213/215/216)
  - Konobarska aplikacija, kontrolna tabla, CSV izvoz
  - E-mailovi za goste i stranica sa stanjem za goste
  - Podrška e-mailom, odgovor u roku od 1 radnog dana
  - Video uvođenje
- **Dugme:** Isprobajte besplatno

### Kartica paketa Pro *(oznaka: „Preporuka“)*
- **Naziv:** Pro
- **Za:** Lokale s mnogo kartica i visokim zahtjevima za sigurnost
- **Cijena:** 59 € / mjesečno · godišnje 590 €
- **Uključeno – sve iz Starta, plus:**
  - Kartice zaštićene od kopiranja s NTAG 424 DNA
  - API pristup (npr. za povezivanje s kasom)
  - Lično uvođenje – putem videa ili u restoranu u Beču
  - Podrška telefonom
  - Prioritetni odgovor u roku od 4 radna sata
  - Pomoć pri dizajnu kartica
- **Dugme:** Isprobajte besplatno

### Kartica paketa Gruppe
- **Naziv:** Gruppe (grupa)
- **Za:** Lance, više lokacija, hotele s više ugostiteljskih jedinica
- **Cijena:** od 129 € / mjesečno za do 3 lokacije, svaka sljedeća 39 €
- **Uključeno – sve iz Pro za svaku lokaciju, plus:**
  - Centralna kontakt osoba
  - Uvođenje za sve lokacije
  - Individualni ugovor i SLA po dogovoru
- **Dugme:** Zatražite ponudu

**Fusnota:** Sve cijene neto, plus 20 % PDV-a (Austrija). Godišnje plaćanje: 2 mjeseca gratis. Plaćanje SEPA direktnim zaduženjem ili uplatom na račun. Samo za firme. Svaka lokacija je trenutno zaseban nalog; zajednička kontrolna tabla za više lokacija planirana je za 2027.

### Kartice i postavljanje

| Usluga | Cijena |
|---|---|
| Početni set: 100 NFC kartica (NTAG215), obostrano u punoj boji, u Vašem dizajnu | okvirno 249 € (oko 2,49 € po kartici) |
| 250 NFC kartica | okvirno 499 € |
| NTAG 424 DNA kartice | na upit, okvirno 4–6 € po kartici |
| QR kartice za samostalnu štampu | besplatno |
| Postavljanje i obuka u restoranu | jednokratno 149 € |
| Samostalno postavljanje | besplatno |

*Cijene kartica: okvirna cijena, zavisi od količine i štampe – obavezujuća ponuda na upit. Sve cijene neto, plus 20 % PDV-a.*

**Mikrotekst ispod tabele:** Isprobajte 30 dana besplatno, sa svim Pro funkcijama. Bez kreditne kartice.

---

## 8. Sigurnost (kratko)

**H2:** Napravljeno kao knjiga blagajne.

- Na kartici nema stanja – samo nasumičan link koji se ne može pogoditi.
- Svaka transakcija atomarna i jednokratna; nepromjenjiv dnevnik čiji zbir je uvijek jednak stanju.
- Storno kao protivknjiženje, ništa se ne briše.
- Svaki restoran strogo odvojen od drugih.
- Hosting kod Hetznera u Njemačkoj, noćne sigurnosne kopije s vanjskom kopijom.
- 113 automatizovanih testova, pristupačnost provjerena prema WCAG 2.1 AA.

**Link:** Sigurnost detaljno →

---

## 9. Šta GiftCard Pro nije

**Raspored:** Diskretna siva kutija. Ova sekcija je namjerna: gradi povjerenje.

**H2:** Iskreno rečeno

- **Nije online prodavnica.** Kartice se prodaju u restoranu. Online prodaja je planirana za prvi kvartal 2027.
- **Nije fiskalna kasa.** I dalje knjižite u svojoj kasi. Za povezivanje postoji API.
- **Nije program lojalnosti niti sistem rezervacija.** Radimo jednu stvar i radimo je kako treba.
- **Aplikacija za tim je trenutno na engleskom.** Njemačka verzija stiže u četvrtom kvartalu 2026. Sve što gosti vide dostupno je na njemačkom ili engleskom.

---

## 10. Česta pitanja

**H2 (sidro `#pitanja`):** Česta pitanja

**Moram li instalirati aplikaciju?**
Ne. GiftCard Pro radi u pregledniku. Na telefonu konobarsku aplikaciju možete dodati na početni ekran – tada se otvara kao prava aplikacija.

**Radi li s mojom kasom?**
GiftCard Pro radi nezavisno od Vaše fiskalne kase. Prodaju i iskorištavanje i dalje knjižite u njoj. U paketu Pro na raspolaganju je API za povezivanje.

**Koliko su kartice sigurne?**
Na kartici nije pohranjeno stanje, samo nasumičan link. Kartice se mogu vezati za svoj čip, a kopije se prepoznaju. NTAG 424 DNA kartice (Pro) kriptografski su zaštićene od kopiranja i ponovljenog skeniranja.

**Šta ako gost izgubi karticu?**
Izdate zamjensku karticu. Stanje se prenosi, a stara kartica je odmah blokirana.

**Mogu li ograničiti rok važenja?**
Tehnički da. Pravno je u Austriji paušalno ograničenje plaćenih poklon bonova na tri godine ili manje uglavnom nevaljano. Preporučujemo „bez roka važenja“. *Nije pravni savjet – provjerite s poreznim savjetnikom ili advokatom.*

**Kako se poklon bonovi tretiraju porezno?**
Vrijednosni bonovi za hranu i piće u pravilu su bonovi za više namjena (Mehrzweckgutschein): PDV nastaje pri iskorištavanju. CSV izvozi daju Vašem poreznom savjetniku potrebne podatke. *Nije porezni savjet – dogovorite se sa svojim poreznim savjetnikom.*

**Mogu li otkazati?**
Mjesečne pakete do kraja mjeseca, godišnje do isteka ugovora. Svoje podatke možete izvesti u svakom trenutku.

**Gdje su moji podaci?**
U data centrima Hetznera u Njemačkoj, dakle u EU. Za podatke Vaših gostiju mi smo izvršitelj obrade prema čl. 28 GDPR-a.

---

## 11. Završni CTA

**Raspored:** Površina u Tinti, bijeli tekst, centrirano.

**H2:** Sljedeća sezona poklona sigurno dolazi.
**Tekst:** Postavite GiftCard Pro za jedno popodne. 30 dana besplatno, bez kreditne kartice.
**Primarni CTA:** Isprobajte besplatno
**Sekundarni CTA:** Zatražite demo

---

## 12. Podnožje

**Raspored:** Četiri kolone, ispod pravni red.

| Proizvod | Firma | Pomoć | Pravno |
|---|---|---|---|
| Funkcije | O nama | Uputstvo | Impresum |
| Cijene | Kontakt | Prvi koraci (video) | Zaštita podataka |
| Sigurnost | Mediji | support@giftcardpro.at | Uslovi poslovanja (AGB) |
| Novosti | Pilot program | Prijavite sigurnosni propust (security@giftcardpro.at) | Kolačići |

**Pravni red:** © 2026 `[Naziv firme]` `[Pravni oblik]` · `[Adresa], 1xxx Beč` · Sve cijene neto, plus 20 % PDV-a.
**Red sa sloganom:** Poklon kartice za ugostiteljstvo. Razvijeno u Beču.

---

## 13. Mikrotekstovi

### Dugmad

| Kontekst | Tekst |
|---|---|
| Registracija | Isprobajte besplatno |
| Demo | Zatražite demo |
| Gruppe | Zatražite ponudu |
| Pilot | Prijavite se za pilot |
| Prijava | Prijava |
| Slanje formulara | Pošaljite upit |
| Nakon slanja (učitava) | Šalje se … |
| Dalje | Saznajte više |
| Cijene | Uporedite pakete |

### Formular za demo

**Naslov:** Zatražite demo
**Uvod:** 15 minuta, putem videa ili kod Vas u restoranu u Beču. Pokazat ćemo Vam izdavanje, naplatu i kontrolnu tablu na Vašem primjeru.

| Polje | Oznaka | Placeholder | Obavezno | Validacija / poruka o grešci |
|---|---|---|---|---|
| Ime | Vaše ime | Ime i prezime | da | „Molimo upišite svoje ime.“ |
| Restoran | Naziv lokala | npr. Restoran Lipa | da | „Molimo upišite naziv svog lokala.“ |
| E-mail | E-mail adresa | ime@restoran.at | da | prazno: „Molimo upišite svoju e-mail adresu.“ · neispravno: „Čini se da ova e-mail adresa nije potpuna.“ |
| Telefon | Telefon (nije obavezno) | +43 … | ne | neispravno: „Molimo provjerite broj telefona.“ |
| Mjesto | Mjesto | npr. Beč | da | „Molimo upišite mjesto.“ |
| Lokacije | Broj lokacija | Izbor: 1 · 2–3 · 4 ili više | da | „Molimo izaberite jednu opciju.“ |
| Termin | Kako želite demo? | Izbor: Putem videa · U restoranu u Beču | da | „Molimo izaberite jednu opciju.“ |
| Poruka | Poruka (nije obavezno) | Šta Vam je važno? | ne | najviše 1.000 znakova: „Molimo skratite poruku na 1.000 znakova.“ |
| Zaštita podataka | Pročitao/la sam izjavu o zaštiti podataka. | – | da | „Molimo potvrdite izjavu o zaštiti podataka.“ |

**Napomena ispod formulara:** Vaše podatke koristimo samo da odgovorimo na Vaš upit. Bez newslettera bez Vašeg pristanka.

**Poruka o uspjehu:**
**Hvala, Vaš upit je stigao.**
Javit ćemo Vam se u roku od jednog radnog dana e-mailom s prijedlozima termina. Ako Vam se žuri: `[Telefon]`.

**Poruka o grešci (server/mreža):**
**Nešto nije uspjelo.**
Vaš upit nije poslan. Molimo pokušajte ponovo ili pišite na hallo@giftcardpro.at.

**Sažetak grešaka (iznad formulara, kod više grešaka):** Molimo provjerite označena polja.

### Zahtjev za probni pristup (`/registracija`)

GiftCard Pro nema automatsku samostalnu registraciju: svaki probni pristup postavlja tim, kako bi svaki restoran krenuo uredno postavljen. Stranica `/registracija` je zato kratak formular, a ne dijalog za otvaranje računa.

**Naslov:** 30 dana besplatno
**Uvod:** Postavljamo Vaš probni pristup i u roku od jednog radnog dana šaljemo Vam pozivnicu e-mailom. Sve funkcije paketa Pro, bez kreditne kartice.

| Polje | Oznaka | Obavezno |
|---|---|---|
| Ime | Vaše ime | da |
| Restoran | Naziv lokala | da |
| E-mail | E-mail adresa (prima pozivnicu) | da |
| Telefon | Telefon (neobavezno) | ne |
| Mjesto | Mjesto | da |
| Saglasnost | Pročitao/la sam [Izjavu o zaštiti podataka](/bhs/zastita-podataka). | da |

**Dugme:** Zatražite probni pristup
**Poruka o uspjehu:** **Hvala. Vaš probni pristup je u pripremi.** U roku od jednog radnog dana dobićete e-mail „Welcome to GiftCard Pro" s linkom za postavljanje lozinke. Link važi 72 sata.

### Ostali mikrotekstovi

- Prekidač cijena: Mjesečno · Godišnje – 2 mjeseca gratis
- Oznaka paketa: Preporuka
- Obavještenje o kolačićima (samo ako ubuduće bude potrebno): Ovaj sajt koristi samo neophodne kolačiće. Više pod Kolačići.
- 404: Ova stranica ne postoji. Na početnu →
- Izbor jezika: Deutsch · BHS

---

Verzija 1.0 · Stanje: septembar 2026.
