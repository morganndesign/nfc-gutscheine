# Plan razvoja proizvoda GiftCard Pro

*Šta gradimo sljedeće, kojim redoslijedom i zašto. Period: Q4 2026 do 2028. Za korisnike, partnere i tim.*

> **Napomena:** ovaj plan razvoja opisuje naše trenutno planiranje, a ne ugovornu obavezu. Redoslijed i rokovi mogu se promijeniti ako tokom pilot-faze nešto naučimo, ako se promijene pravni zahtjevi ili ako trebaju sudjelovati partneri. Obavezujuće je samo ono što je dostupno u proizvodu.

---

## 1. Pregled: sada · sljedeće · kasnije

| **Sada** (Q4 2026) | **Sljedeće** (Q1–Q2 2027) | **Kasnije** (Q3 2027–2028) |
|---|---|---|
| Interfejs za osoblje na njemačkom | Online prodaja poklon bonova na web stranici restorana | Preduslovi za ulazak na njemačko tržište |
| Zadani rok važenja „neograničeno" | Povezivanje s kasama (u provjeri) | Valute CHF, BAM, RSD |
| Automatsko obračunavanje (Stripe) | Kontrolna tabla za grupe s više lokacija | Interfejs na bosanskom/hrvatskom/srpskom |
| Usluga naručivanja kartica | Apple Wallet i Google Wallet | Ulazak na tržišta Hrvatske, Bosne i Hercegovine, Srbije |
| Web stranica | | |

Status se navodi ovako: **u izradi** · **planirano** · **u provjeri** (razjašnjavaju se izvodljivost, partneri ili potražnja).

---

## 2. Kvartalni plan

### Q4 2026 — početak u Austriji

Cilj: proizvod je za austrijske restorane upotrebljiv bez prepreka, a prodaja i obračun teku bez ručnog rada. Pilot u oktobru, izlazak na tržište u novembru, na vrijeme pred advent.

| Projekat | Korist | Status |
|---|---|---|
| **Interfejs za osoblje na njemačkom** (kontrolna tabla i aplikacija za konobare); bosanski/hrvatski/srpski slijedi kasnije | Konobari i menadžeri rade na svom jeziku. Najviši prioritet, prije ili neposredno nakon izlaska na tržište | planirano (visok prioritet) |
| **Zadani rok važenja „neograničeno"** za nove restorane (umjesto dosadašnjih 36 mjeseci) | U skladu s austrijskom sudskom praksom o plaćenim poklon bonovima (ograničenje na 3 godine ili manje u općim uslovima je ništavo). Do tada rok važenja pri postavljanju postavljamo na **0** (bez isteka) | planirano |
| **Automatsko obračunavanje preko Stripea** | Mjesečni i godišnji računi automatski, plaćanje SEPA direktnim zaduženjem, bez ručnih računa | planirano |
| **Usluga naručivanja kartica** | Strukturirano naručivanje štampanih NFC kartica: dizajn, količina, vrsta kartice, ponuda, isporuka | planirano |
| **Web stranica** giftcardpro.at | Proizvod, cijene, prijava za testiranje i pilot-program na jednom mjestu | planirano |

### Q1 2027 — prodaja online, povezivanje kase

| Projekat | Korist | Status |
|---|---|---|
| **Online prodaja poklon bonova** na web stranici restorana: gost bira iznos i plaća online, dobija PDF bon i po želji karticu poštom | Prodaja 24 sata, i na daljinu. **I dalje 0 % naše provizije** — plaćaju se samo naknade pružaoca platnih usluga | planirano |
| **Povezivanje s kasama:** ready2order, orderbird, SumUp POS | Iskorištavanja bez dvostrukog unosa u kasu i GiftCard Pro. Osnova je postojeći API | u provjeri |

### Q2 2027 — grupe i Wallet

| Projekat | Korist | Status |
|---|---|---|
| **Kontrolna tabla za grupe s više lokacija** | Brojke svih lokacija u jednom pregledu; da li kartice trebaju biti upotrebljive na svim lokacijama, razjasnit ćemo s grupama tokom pilot-faze | planirano |
| **Apple Wallet i Google Wallet** | Gosti dodatno nose poklon karticu u telefonu; stanje uvijek pri ruci | planirano |

### Q3 2027 — preduslovi za Njemačku

| Projekat | Korist | Status |
|---|---|---|
| Pravni tekstovi i ugovorna dokumentacija za Njemačku | Pravno sigurna prodaja njemačkim objektima | planirano |
| Porezne napomene za Njemačku (PDV, Kassensicherungsverordnung) u dokumentaciji | Jasno uputstvo za knjiženje u vlastitoj kasi | planirano |
| Prilagođavanje zadanih vrijednosti za Njemačku (format brojeva de-DE već je dostupan, rok važenja prema njemačkom pravu) | Smislene postavke od prvog dana | planirano |
| Povezivanje s kasama raširenim u Njemačkoj | Rezultat provjere iz Q1 2027 | u provjeri |

### 2028 — regija i jezici

| Projekat | Korist | Status |
|---|---|---|
| **Valute CHF, BAM, RSD** | Preduslov za Švicarsku, Bosnu i Hercegovinu i Srbiju. Hrvatska već koristi euro | planirano |
| **Interfejs na bosanskom/hrvatskom/srpskom** (osoblje i gosti) | Rad i iskorištavanje na jeziku zemlje | planirano |
| **Ulazak na tržišta Hrvatske, Bosne i Hercegovine, Srbije** | Uključujući lokalne napomene o fiskalizaciji: prodaja i iskorištavanje i dalje se knjiže u fiskalnoj kasi | planirano |
| Švicarska | Procjenjuju se tržište i partneri | u provjeri |

---

## 3. Stalno, svakog kvartala

- **Sigurnost i pouzdanost:** ažuriranja, provjere, testovi opterećenja. Pravilo „zbir dnevnika = stanje" automatski se provjerava pri svakoj promjeni.
- **Brzina za stolom:** proces iskorištavanja mjeri se u svakoj verziji. Nijedna verzija ga ne smije usporiti.
- **Pristupačnost:** provjera prema WCAG 2.1 AA za svaki novi interfejs.
- **Poboljšanja iz pilot-faze:** male izmjene koje smetaju u svakodnevnom radu imaju prednost pred novim funkcijama.

---

## 4. Namjerno nije u planu razvoja

Ove teme se stalno traže. Namjerno ih ne gradimo kako bi GiftCard Pro ostao jednostavan:

| Tema | Obrazloženje |
|---|---|
| **Programi lojalnosti, kartice s pečatima, bodovi** | Drugi proizvod s drugim procesima; postoje specijalizovani dobavljači |
| **Rezervacije** | Zasebna kategorija s etabliranim rješenjima |
| **CRM i marketinške kampanje, newsletteri** | Podaci gostiju pripadaju restoranu; ne koristimo ih za kampanje |
| **Funkcija kase, izdavanje računa, RKSV** | Za to služi fiskalna kasa. Povezujemo, umjesto da zamjenjujemo |
| **Naručivanje za stolom** | Nije naš osnovni proces |
| **Vlastita aplikacija u App Storeu** | Web aplikacija ispunjava sve zahtjeve i ne treba ažuriranja preko prodavnice |

---

## 5. Kako određujemo prioritete

Svaki projekat ocjenjuje se prema pet pitanja, ovim redoslijedom:

1. **Pravo i pouzdanost.** Da li je pravno neophodan ili štiti novac i podatke? Onda ide prvi (primjer: zadani rok važenja „neograničeno").
2. **Trenutak za stolom.** Da li čini iskorištavanje bržim ili sigurnijim — ili ga barem ne usporava?
3. **Potražnja.** Koliko je restorana to tražilo i koliko prometa ili truda zavisi od toga? Povratne informacije iz pilot-programa računaju se dvostruko.
4. **Sezona.** Da li pomaže prije jakih sezona poklon bonova: advent i Božić, Valentinovo, Uskrs, Majčin dan, Očev dan?
5. **Trud i jednostavnost.** Može li se izgraditi a da proizvod ne postane teži za razumijevanje?

Ono na što je odgovor na neko od ovih pitanja jasno „ne" — na primjer, jer usporava iskorištavanje ili pretpostavlja proviziju — ne gradimo.

**Želje i povratne informacije:** support@giftcardpro.at. Svaki upit se čita i uzima u obzir pri planiranju.

---

## 6. Napomena

Plan razvoja provjerava se svakog kvartala i po potrebi prilagođava. Rokovi su ciljni kvartali. Odluke o kupovini trebaju se zasnivati na trenutnom obimu funkcija, a ne na planiranim funkcijama.

---

Verzija 1.0 · Stanje: septembar 2026.
