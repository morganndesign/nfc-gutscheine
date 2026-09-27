# Identitet brenda GiftCard Pro

*Svrha: Temelj brenda – priča, misija, vizija, vrijednosti, ličnost, obećanje brenda, pozicioniranje i arhitektura brenda. Obavezna osnova za sve ostale dokumente u ovom folderu.*

> **Napomena o imenu:** „GiftCard Pro" je radni naziv. Konačan naziv proizvoda se trenutno provjerava – vidi [name-alternatives.md](name-alternatives.md). Do odluke svi materijali koriste „GiftCard Pro". Vrijednosti, ličnost i dizajn iz ovog dokumenta važe nezavisno od imena.

---

## 1. Priča brenda

Petak uveče u jednom bečkom restoranu. Za stolom broj 7 gost stavlja na sto papirni poklon bon – ručno popunjen, pečat napola razmazan. Konobarica ide do šanka, traži u Excel tabeli, ne nalazi unos, pita šeficu. Nakon četiri minute jasno je: bon važi. Gost čeka, a čeka i sljedeći sto.

Ovakve scene poznaje svaki ugostitelj. Poklon bonovi su jedan od najljepših poklona koje restoran može prodati – a u svakodnevnom radu jedan od najzamornijih. Papir se lako kopira, tabele nikad nisu ažurne, a na kraju godine niko tačno ne zna koliko je novca još u neiskorištenim bonovima.

GiftCard Pro je nastao jer taj posao ne mora biti naporan. Osnivačica dolazi iz web razvoja, dizajna za restorane, automatizacije i testiranja softvera. Vidjela je koliko pažnje ugostitelji ulažu u kuhinju i uslugu – i koliko malo toga stigne do poklon bona.

Odgovor je kartica koja nešto znači: u formatu bankovne kartice, s NFC čipom i QR kodom, u dizajnu restorana. Konobar prisloni karticu na telefon, unese iznos i gotovo – za manje od 5 sekundi. U pozadini se svaki euro bilježi u nepromjenjivom dnevniku transakcija. Novac nikad nije na kartici, nego sigurno na serveru. I restoran ne plaća proviziju – nikad.

Ne gradimo alat koji se gura u prvi plan. Gradimo alat koji radi kao dobar šef sale: tu je kad zatreba, nevidljiv kad ne treba.

---

## 2. Misija

> **„Restoranima dajemo sistem poklon kartica koji radi jednako dobro kao njihova usluga: brzo, pouzdano i lijepo."**

*(Njemački original: „Wir geben Restaurants ein Gutscheinsystem, das so gut funktioniert wie ihr Service: schnell, verlässlich und schön.")*

Misija opisuje šta radimo danas. Nose je tri riječi:

| Riječ | Šta konkretno znači |
|---|---|
| **brzo** | Iskorištavanje za stolom za manje od 5 sekundi, uključujući čovjeka. Pretraga kartice oko 0,1 s, cijeli postupak iskorištavanja oko 0,5 s sistemskog i vremena rada u aplikaciji. |
| **pouzdano** | Svako knjiženje je atomarno i nepromjenjivo, dvostruki dodir nikad ne knjiži dvaput; testirano s 20 istovremenih iskorištavanja na jednoj kartici. |
| **lijepo** | Kartica koju je lijepo pokloniti – i aplikacija koju je lijepo koristiti. |

## 3. Vizija

> **„Svaki poklon bon postaje povod za sljedeću posjetu – i nijedan se ne izgubi."**

*(Njemački original: „Jeder Gutschein wird zum Anlass für den nächsten Besuch – und keiner geht verloren.")*

Vizija opisuje kuda idemo. Poklon bon nije knjigovodstveni problem, nego pozivnica: ko ga iskoristi, dolazi u restoran, možda dovede nekoga i vraća se. „Nijedan se ne izgubi" znači dvoje: nijedan bon nije krivotvoren ni zaboravljen, i nijedan euro ne nestaje iz pregleda.

---

## 4. Ključne vrijednosti

Pet vrijednosti. Svaka ima značenje, vidljivo ponašanje i jasnu granicu.

### 4.1 Jasnoća (Klarheit)

**Značenje:** Kažemo kako jeste – brojkama, kratkim rečenicama, bez sitnih slova. Vlasnica treba na prvi pogled vidjeti koliko je otvoreno; konobar treba bez obuke znati šta da radi.

**Ovako se vidi:**
- Kontrolna tabla počinje otvorenim iznosom: „258,00 € – otvorena obaveza na 4 kartice".
- Cijene su javno na web stranici, neto, plus 20 % austrijskog PDV-a.
- Poruke o greškama kažu šta se desilo i šta sada uraditi.
- Otvoreno kažemo šta proizvod ne radi (npr. nije fiskalna kasa, nema online prodavnice – još ne).

**Ovako ne:**
- „Cijena na upit" za standardne pakete.
- Stručni žargon bez objašnjenja („idempotency key nije uspio").
- Pregled s dvanaest jednako glasnih brojki.

### 4.2 Pouzdanost (Verlässlichkeit)

**Značenje:** Novac mora biti tačan. Uvijek. Svaka funkcija, svaka tvrdnja i svaki rok moraju vrijediti.

**Ovako se vidi:**
- Nepromjenjiv dnevnik transakcija: zbir knjiženja = stanje, u svakom trenutku.
- Storno se bilježi kao protuknjiženje, ništa se ne briše.
- Obećavamo vrijeme odgovora koje držimo (paket Start: 1 radni dan, paket Pro: 4 radna sata).
- Navodimo samo brojke koje su izmjerene ili dokazane.

**Ovako ne:**
- „Garantovana dostupnost 99,99 %" – naš cilj je 99,5 % mjesečno, i tako to kažemo.
- Nagovještavati certifikate ili broj korisnika koji ne postoje.
- Funkcije iz plana razvoja predstavljati kao dostupne.

### 4.3 Gostoprimstvo (Gastfreundschaft)

**Značenje:** Prema restoranima se odnosimo kao što se dobri restorani odnose prema gostima: pažljivo, ljubazno, nenametljivo. I uvijek mislimo i na gosta za stolom.

**Ovako se vidi:**
- Podrška odgovara imenom, punim rečenicama i s rješenjem.
- Provjera stanja za goste je na jeziku restorana i bez prijave.
- Na njemačkom, engleskom i BHS – govorimo jezik mnogih bečkih restorana.
- Postavljanje na licu mjesta u Beču, ako to želite.

**Ovako ne:**
- Automatski odgovori bez sadržaja („Vaš tiket je zaprimljen").
- Pritisak prodaje tokom probnog perioda, pozivi bez povoda.
- Gosta nazivati „saobraćajem krajnjih korisnika".

### 4.4 Fer odnos (Fairness)

**Značenje:** 0 % provizije na prodaju i iskorištavanje – nikad. Transparentne cijene. Podaci pripadaju restoranu.

**Ovako se vidi:**
- Fiksna mjesečna cijena umjesto procenta od prometa.
- Mjesečni otkaz, izvoz podataka kao CSV u svakom trenutku.
- Kartice se prodaju po okvirnoj cijeni, bez skrivenih doplata.
- Cijene kartica su označene kao „okvirna cijena, zavisi od količine i štampe – obavezujuća ponuda na upit".

**Ovako ne:**
- Loše govoriti o konkurenciji po imenu. Poredimo modele („provizija ili fiksna cijena"), ne firme.
- Vezivanje korisnika zatvorenim formatima.
- Naknade za postavljanje koje se pojave tek u sitnim slovima.

### 4.5 Zanat (Handwerk)

**Značenje:** Pažnja do detalja – kao u dobroj kuhinji. Kartica, aplikacija, tekst: sve je promišljeno.

**Ovako se vidi:**
- Tabelarne cifre, da iznosi stoje uredno jedan ispod drugog.
- Aplikacija za konobare radi na iPhone SE bez skrolanja.
- 113 automatizovanih backend testova, provjera pristupačnosti prema WCAG 2.1 AA.
- Podaci za štampu s porezom (bleed), sigurnosnom zonom i provjerenim QR kodom.

**Ovako ne:**
- „Ma, može" kod pravopisa, razmaka ili vrijednosti boja.
- Snimci ekrana s testnim podacima poput „asdf" u prodajnim materijalima.
- Ukrasi bez funkcije.

---

## 5. Ličnost brenda

### 5.1 Arhetip

**Šef sale (Oberkellner)** – u klasičnom modelu brenda spoj *Njegovatelja* (Caregiver) i *Mudraca* (Sage), s dozom *Stvaraoca* (Creator).

Odličan šef sale poznaje kuću, drži pregled, tiho rješava probleme i pušta goste da zablistaju. Nikad nije najglasniji u prostoriji. Tek kad ga jednom nema, primijeti se koliko je dobar.

| On je … | On nije … |
|---|---|
| miran, prisutan, predusretljiv | užurban, nametljiv, brbljiv |
| precizan s brojkama | približan, „otprilike" |
| topao i pun poštovanja | napadno familijaran ili ponizan |
| samouvjeren bez buke | hvalisav |

### 5.2 Osobine kao klizači

Pozicija ● pokazuje gdje brend stoji. Skala ima pet stepeni.

| Lijevi pol | Skala | Desni pol | Objašnjenje |
|---|---|---|---|
| miran | ●○○○○ | glasan | Bez uskličnika, bez superlativa, bez odbrojavanja. |
| precizan | ●○○○○ | neodređen | Brojke umjesto pridjeva: „0,5 s", ne „munjevito". |
| topao | ○●○○○ | hladan | Ljudski i ljubazno, ali ne slatkasto. |
| ozbiljan | ○●○○○ | razigran | Osmijeh smije, šala rijetko. Novac je ozbiljna stvar. |
| samouvjeren | ○●○○○ | suzdržan | Jasno kažemo šta znamo. Ne moramo to naglašavati. |
| jednostavan | ●○○○○ | složen | Jedna misao po rečenici. Tehnika samo kad pomaže. |
| lokalan | ○●○○○ | međunarodan | Na njemačkom austrijski izrazi; na BHS neutralno, razumljivo u BiH, HR i RS. |
| moderan | ○○●○○ | tradicionalan | Moderan alat koji poštuje gostionicu i kafanu. |

---

## 6. Obećanje brenda

> **Prislonite karticu, unesite iznos, gotovo – za manje od 5 sekundi. I svaki euro se može pratiti.**

Obećanje spaja dvije stvari koje restoranima najviše trebaju: brzinu za stolom i sigurnost u kancelariji. Sve što komuniciramo mora ispuniti barem jednu od te dvije polovine.

**Dokazi za obećanje** (koristiti samo ove):

| Tvrdnja | Dokaz |
|---|---|
| manje od 5 sekundi za stolom | pretraga kartice oko 0,1 s, postupak iskorištavanja oko 0,5 s sistemskog vremena i rada u aplikaciji; cilj < 5 s uključujući čovjeka |
| svaki euro se može pratiti | nepromjenjiv dnevnik transakcija, zapisnik aktivnosti s osobom, vremenom i uređajem |
| sigurno od dvostrukih knjiženja | atomarna, idempotentna knjiženja; testirano s 20 istovremenih iskorištavanja |
| sigurno od kopija | stanje nikad nije na kartici; zaštita od kloniranja preko UID-a čipa, NTAG 424 DNA s kriptografskim potpisom |
| fer | 0 % provizije, mjesečni otkaz |
| podaci u EU | hosting kod Hetzner Online GmbH, podatkovni centri u Njemačkoj |

---

## 7. Pozicioniranje

**Kategorija:** sistem poklon kartica za ugostiteljstvo · NFC poklon kartice za restorane

**Izjava o pozicioniranju:**
Za vlasnike i vlasnice restorana, kafića, barova i gostionica u Austriji koji prodaju poklon bonove, a ne žele za to plaćati proviziju ni gubiti pregled, GiftCard Pro je sistem poklon kartica koji fizičke NFC kartice čini iskoristivim za stolom u nekoliko sekundi i bez praznina dokumentuje svaki euro. Za razliku od online prodavnica bonova koje zarađuju na svakoj prodaji, i za razliku od papirnih bonova s Excel tabelom, GiftCard Pro spaja kvalitetnu karticu, brzo iskorištavanje, dnevnik transakcija otporan na krivotvorenje i fiksnu cijenu bez provizije – nezavisno od fiskalne kase.

**Jedna rečenica:** „Poklon kartice koje se koriste kao plaćanje karticom." *(DE: „Gutscheinkarten, die sich wie Bezahlen anfühlen.")*
**Alternativa:** „Prislonite. Iskoristite. Gotovo." *(DE: „Antippen. Einlösen. Fertig.")*

**Pet stubova:**

| # | Stub | Ključna poruka |
|---|---|---|
| 1 | Brzo za stolom | Prislonite, iznos, gotovo. Bez obuke. |
| 2 | Sigurno od prevara i grešaka | Nema stanja na kartici, nema dvostrukih knjiženja, zaštita od kloniranja. |
| 3 | Jasan pregled otvorenih iznosa | Otvorena obaveza je uvijek vidljiva. |
| 4 | Poklon koji nešto znači | Kartica u formatu bankovne kartice umjesto papirića. |
| 5 | Fer | 0 % provizije. Fiksna cijena od 29 € mjesečno. |

**Šta namjerno nismo:** online prodavnica bonova (plan razvoja Q1 2027), fiskalna kasa, program lojalnosti, sistem rezervacija. Ovo razgraničenje je dio brenda: jednu stvar radimo vrlo dobro.

---

## 8. Arhitektura brenda

### 8.1 Struktura

GiftCard Pro je **monolitni brend** (branded house): jedan krovni brend, ispod njega opisni nazivi funkcija i paketa bez vlastitih logotipa.

```
GiftCard Pro  (krovni brend, radni naziv)
│
├── Paketi:        Start · Pro · Gruppe
│
├── Aplikacije:    Kontrolna tabla (Dashboard) · Aplikacija za konobare · Provjera stanja
│
├── Funkcije:      Pravila kartica · Zaštita od kloniranja · Dnevnik transakcija ·
│                  Zapisnik aktivnosti · Upravljanje uređajima · E-mailovi za kupce · CSV izvoz
│
└── Usluge:        Početni set (kartice) · Postavljanje na licu mjesta · Pomoć pri dizajnu kartica (paket Pro)
```

### 8.2 Nazivi paketa

| Paket | Cijena (neto, plus 20 % austrijskog PDV-a) | Za |
|---|---|---|
| **Start** | 29 € / mjesec · 290 € / godina | jedan restoran, kafić, bar |
| **Pro** | 59 € / mjesec · 590 € / godina | prometni objekti, veliki broj kartica, osjetljivi na prevare |
| **Gruppe** (grupa) | od 129 € / mjesec za do 3 lokacije, + 39 € za svaku dodatnu lokaciju | grupe, više lokacija, hoteli s više ugostiteljskih jedinica |

**Pravila za nazive paketa:**
- Nazivi Start, Pro i Gruppe ostaju nepromijenjeni – i kod eventualne promjene imena proizvoda.
- U tekstu uvijek uz riječ „paket": „u paketu Pro", „paket Gruppe". Razlog: treba izbjeći „GiftCard Pro Pro".
- Nazivi paketa se ne prevode – ni na BHS ni na engleski. Gdje je potrebno, objašnjenje stoji u zagradi: „Gruppe (grupa)".
- Nikad „Pro verzija", „Premium" ili „Business" kao sinonim.
- Pisati kao vlastito ime; bez verzala („PRO"), osim u malim natpisima (overline).

### 8.3 Nazivi funkcija

| Naziv (marketing, BHS) | Naziv u aplikaciji (trenutno engleski) | Opis |
|---|---|---|
| **Kontrolna tabla** | Dashboard | web pregled za vlasnika i menadžera |
| **Aplikacija za konobare** | Waiter mode | web aplikacija za konobare za skeniranje i iskorištavanje |
| **Provjera stanja** | Public balance page | stranica na kojoj gosti provjeravaju stanje |
| **Pravila kartica** | Settings → Gift cards | minimalni/maksimalni iznosi, važenje, djelimično iskorištavanje, dopuna |
| **Zaštita od kloniranja** | Clone protection | vezivanje za UID čipa odnosno NTAG 424 DNA potpis |
| **Dnevnik transakcija** | Transactions | nepromjenjiva lista svih knjiženja |
| **Zapisnik aktivnosti** | Audit log | radnje važne za sigurnost i novac |
| **Upravljanje uređajima** | Devices | registrovani telefoni, tableti, računari |
| **E-mailovi za kupce** | Settings → E-mails | kupovina, dopuna, podsjetnik o isteku, nisko stanje |

**Pravila za nazive funkcija:**
1. **Opisno prije izmišljenog.** Naziv kaže šta funkcija radi: „Provjera stanja", ne „BalanceBuddy".
2. **Na jeziku čitaoca**, osim ako je izraz ustaljen u ugostiteljstvu (Dashboard, aplikacija).
3. **Na njemačkom** se funkcija za konobare zove „Kellner-App"; na BHS „aplikacija za konobare". Oba naziva označavaju istu funkciju.
4. **Bez „Smart", „Pro", „Plus", „360", „AI"** u nazivima funkcija. „Pro" je isključivo dio naziva proizvoda i paketa.
5. **Bez vlastitih logotipa i boja** za funkcije. Funkcija se prikazuje Lucide ikonom i nazivom.
6. **Citirati oznake iz aplikacije:** dok je interfejs za osoblje na engleskom, oznaka se dodaje podebljano u navodnicima: „aplikacija za konobare (u meniju **„Waiter mode"**)". Njemački interfejs je planiran za Q4 2026.
7. **Funkcije iz plana razvoja** do lansiranja nose dodatak „(planirano)" i nemaju gotov marketinški naziv.

### 8.4 Pisanje krovnog brenda

| Ispravno | Pogrešno |
|---|---|
| GiftCard Pro | Giftcard Pro, GiftcardPro, Gift Card Pro, GIFTCARD PRO, GCP |
| GiftCard Pro se ne sklanja: „s GiftCard Pro", „u GiftCard Pro" | „s GiftCard Proom", „GiftCard Pro-a" |
| giftcardpro.at (domena, malim slovima) | GiftCardPro.at |

Bez znaka ® ili ™ dok žig nije registrovan.

---

## 9. Povezani dokumenti

- [tone-of-voice.md](tone-of-voice.md) – jezik, stil, lista riječi, mikrotekst
- [logo-and-naming.md](logo-and-naming.md) – logotip, slogani, ideje za nazive
- [visual-identity.md](visual-identity.md) – tipografija, boje, ikone, fotografija, dizajn kartica
- [brand-guidelines.md](brand-guidelines.md) – sažete smjernice za partnere i agencije
- [social-media-style-guide.md](social-media-style-guide.md) – društvene mreže
- [name-alternatives.md](name-alternatives.md) – provjera naziva (poseban dokument)

---

Verzija 1.0 · Stanje: septembar 2026.
