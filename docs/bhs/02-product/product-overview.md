# Pregled proizvoda GiftCard Pro

*Šta je GiftCard Pro, za koga je napravljen, kako funkcioniše i šta namjerno nije. Za zainteresovane ugostitelje, partnere, nove članove tima i sve koji žele razumjeti proizvod za pet minuta.*

---

## 1. U jednoj rečenici

GiftCard Pro je sistem poklon kartica za ugostiteljstvo: restorani prodaju kvalitetne poklon kartice s NFC čipom i QR kodom, iskorištavaju ih za stolom za manje od pet sekundi bilo kojim pametnim telefonom i u svakom trenutku vide koliki je iznos još otvoren — bez provizije.

> **„Poklon kartice koje se koriste kao plaćanje karticom."**

![Kontrolna tabla za vlasnike](../../screenshots/owner-dashboard.png)

---

## 2. Za koga je GiftCard Pro

| Ciljna grupa | Tipični objekti | Šta im treba |
|---|---|---|
| **Pojedinačni objekti** | Restoran, gostionica, kafana, kafić, bar | Sistem poklon bonova koji radi bez obuke i izgleda kvalitetno |
| **Objekti s velikim prometom** | Restorani s mnogo prodanih bonova, visokom prosječnom vrijednošću, sezonskim vrhuncima pred Božić | Brzina za stolom, zaštita od kopiranja i zloupotrebe, čiste brojke |
| **Grupe** | Više lokacija, hoteli s više ugostiteljskih jedinica | Jedinstveni procesi, jedna kontakt osoba, zajedničko postavljanje |

**Osobe u objektu:**

- **Vlasnik / vlasnica** — odlučuje, misli na novac, obaveze i imidž, nema vremena.
- **Menadžer** — prodaje kartice, brine o zamjenskim karticama, timu i svakodnevnoj kontroli.
- **Konobari i konobarice** — iskorištavaju kartice za stolom. Ne treba im obuka.
- **Gosti** — oni koji poklanjaju žele uručiti nešto lijepo, a oni koji dobiju poklon žele ga iskoristiti bez komplikacija.
- **Porezni savjetnik / knjigovođa** — treba čiste i potpune izvoze podataka.

Početno tržište je **Austrija**, počevši od Beča.

---

## 3. Kako funkcioniše

```
 ┌────────────┐   ┌──────────────┐   ┌────────────┐   ┌────────────┐   ┌────────────┐
 │ 1 Prodaja  │ → │ 2 Programi-  │ → │ 3 Prinesi  │ → │ 4 Iskoristi│ → │ 5 Izvještaj│
 │ u objektu  │   │ ranje ili    │   │  za stolom │   │   unesi    │   │ kontrolna  │
 │            │   │ štampa       │   │  NFC / QR  │   │   iznos    │   │ tabla, CSV │
 └────────────┘   └──────────────┘   └────────────┘   └────────────┘   └────────────┘
```

1. **Prodaja.** Na kontrolnoj tabli pod **Gift cards → New gift card** birate vrijednost (brzi izbor 25 / 50 / 75 / 100 / 150 € ili slobodan iznos), rok važenja i po želji kupca te ime osobe koja dobija poklon. **Create card** kreira karticu. Plaćanje Vaš objekat naplaćuje kao i obično, na vlastitoj fiskalnoj kasi.
2. **Programiranje kartice.** Android telefonom i Chromeom čip upisujete jednim dodirom (**Write NFC tag**). Alternativno, prikazanu adresu kopirate u bilo koju aplikaciju za upis NFC-a i kliknete **Mark as written**. Kartice samo s QR kodom sami štampate u formatu bankovne kartice.
3. **Prinošenje.** Gost pri plaćanju pokaže karticu. Konobar je prinese svom telefonu (NFC), skenira QR kod ili ukuca 16-cifreni broj kartice.
4. **Iskorištavanje.** Unesite iznos (`2 4 9 0` → 24,90 €) ili izaberite **Full balance**, zatim **Redeem 24,90 €**. Ekran potvrde prikazuje preostalo stanje za gosta. Sljedeća kartica može se odmah prinijeti.
5. **Pregled.** Kontrolna tabla prikazuje ukupni otvoreni iznos, promet, iskorištene iznose i prodane kartice. Svaka transakcija stoji u nepromjenjivom dnevniku i može se kao CSV otvoriti direktno u Excelu.

| ![Aplikacija za konobare: spremno](../../screenshots/waiter-ready.png) | ![Aplikacija za konobare: iznos](../../screenshots/waiter-amount.png) | ![Aplikacija za konobare: gotovo](../../screenshots/waiter-success.png) |
|---|---|---|
| Spremno za prinošenje | Unos iznosa | Iskorišteno, preostalo stanje |

**Važno:** na kartici nije pohranjen novac. Čip i QR kod sadrže samo siguran link sa slučajnom oznakom. Stanje, historija i podaci o kupcima nalaze se isključivo na serveru.

---

## 4. Funkcije po ulogama

### Konobar / konobarica (aplikacija za konobare)

- Web aplikacija na svakom pametnom telefonu, može se instalirati na početni ekran — nije potrebna aplikacija iz App Storea. Nativna aplikacija „GiftCard Waiter" za Android i iPhone je razvijena, ali još nije objavljena u prodavnicama aplikacija; do tada se, kao i do sada, koristi web aplikacija.
- **Android (Chrome):** jednom pritisnite **Scan card**, nakon toga se svaka kartica očitava čim se prinese.
- **iPhone:** prinesite karticu gornjem rubu telefona i dodirnite obavještenje, ili **Scan QR code**.
- U nuždi: **Card number** i unos 16 cifara.
- Tastatura kao na kasi, **Full balance**, veliko dugme **Redeem**, preostalo stanje, **Next card**, automatski povratak nakon 8 sekundi, vibracija kao potvrda (Android).
- Jasne poruke: blokirana (crveno), zamijenjena („ask the guest for the new card"), istekla, nema stanja, nije pronađena.
- Radi bez skrolanja i na malim telefonima kao što je iPhone SE.

### Menadžer

- Prodaja kartica, pretraga (broj, kupac, primalac poklona, bilješka), filtriranje, sortiranje, izvoz.
- Iskorištavanje i dopuna na pultu, prenos stanja između kartica.
- Zamjena izgubljene ili oštećene kartice: stanje prelazi na novu karticu, stara odmah prestaje važiti.
- Blokiranje i deblokiranje kartica (s razlogom), storniranje pogrešnih knjiženja — kao protuknjiženje, ništa se ne briše.
- Upravljanje kupcima, pozivanje tima, upravljanje uređajima, pregled zapisnika aktivnosti (ovisno o ovlaštenjima).

### Vlasnik / vlasnica

- Pokazatelji: **Outstanding balance** (otvorena obaveza na N kartica), **Revenue this month**, **Redeemed this month**, **Cards sold**.
- Grafikoni: dnevno prodano vs. iskorišteno (7/30/90 dana), mjesečni promet (12 mjeseci), kartice po statusu, nedavne aktivnosti.
- Sve postavke: pravila kartica, profil restorana, e-mailovi za goste, API ključevi.
- Tim, uloge, uređaji i potpuni zapisnik aktivnosti sa sigurnosnim upozorenjima.

### Gost

- Kvalitetna kartica u formatu bankovne kartice s imenom restorana, vrijednošću i imenom osobe koja dobija poklon.
- Provjera stanja vlastitim telefonom: prinesite karticu ili skenirajte QR kod — stanje, status i rok važenja na jeziku restorana (može se isključiti).
- Opcionalni e-mailovi: kupovina, dopuna, istek za 30 dana, nisko stanje.

![Stranica stanja za goste](../../screenshots/public-balance.png)

---

## 5. Šta sadrže paketi

Sve cijene su neto, uz dodatak 20 % PDV-a (Austrija). Mjesečna pretplata može se otkazati svakog mjeseca; uz godišnje plaćanje dva mjeseca su besplatna.

| | **Start** | **Pro** | **Gruppe** (grupa) |
|---|---|---|---|
| Cijena mjesečno | 29 € | 59 € | od 129 € za do 3 lokacije, + 39 € po svakoj dodatnoj lokaciji |
| Cijena godišnje | 290 € | 590 € | individualno |
| Za | Pojedinačni restoran, kafić, bar | Objekti s velikim prometom, mnogo kartica, visoki sigurnosni zahtjevi | Lanci, više lokacija, hoteli s više jedinica |
| Lokacije | 1 | 1 | od 3 |
| Kartice i transakcije | neograničeno (fer korištenje) | neograničeno (fer korištenje) | neograničeno (fer korištenje) |
| Članovi tima i uređaji | neograničeno | neograničeno | neograničeno |
| QR kartice, NTAG213/215/216 | ✓ | ✓ | ✓ |
| Aplikacija za konobare, kontrolna tabla, izvozi | ✓ | ✓ | ✓ |
| E-mailovi za goste, stranica stanja | ✓ | ✓ | ✓ |
| NTAG 424 DNA (zaštita od kopiranja) | — | ✓ | ✓ |
| API pristup (npr. povezivanje s kasom) | — | ✓ | ✓ |
| Postavljanje | video | lično (na daljinu ili na licu mjesta u Beču) | za sve lokacije |
| Podrška | e-mail, odgovor u roku od 1 radnog dana | dodatno telefon, prioritet (4 radna sata) | centralna kontakt osoba, individualni ugovor/SLA |
| Pomoć pri dizajnu kartice | — | ✓ | ✓ |

- **0 % provizije** na prodaju i iskorištavanje kartica.
- **Bez naknade za postavljanje** ako sami postavljate sistem. Opcionalno: postavljanje i obuka tima na licu mjesta, jednokratno 149 €.
- **30 dana besplatnog testiranja**, bez kreditne kartice, sa svim Pro funkcijama.
- **Kartice** (okvirna cijena, ovisno o količini i štampi — obavezujuća ponuda na upit): početni set od 100 štampanih NFC kartica (NTAG215, obostrano u punoj boji, u Vašem dizajnu) 249 €; 250 kartica 499 €; NTAG 424 DNA 4–6 € po kartici. QR kartice sami štampate besplatno.

---

## 6. Tehnologija i sigurnost

| Područje | Rješenje |
|---|---|
| **Kartica** | Čip i QR sadrže samo `https://<domain>/c/<slučajni UUID>` (122 bita slučajnosti). Brojevi kartica su slučajni, nisu redoslijedni, s kontrolnom cifrom. |
| **Knjiženja** | Svaka promjena stanja je atomska (zaključavanje reda u bazi), idempotentna (dvostruki dodiri i ponovljeni mrežni zahtjevi nikad ne knjiže dvaput) i upisana u nepromjenjivi dnevnik. Zbir dnevnika = stanje. Testirano s 20 istovremenih iskorištavanja na jednoj kartici. |
| **Zaštita od kopiranja** | NTAG21x: vezivanje za serijski broj čipa. NTAG 424 DNA: kriptografski potpis (SUN/AES-CMAC) i brojač pri svakom prinošenju — kopije i ponavljanja se odbijaju. |
| **Pristup** | Lozinke najmanje 12 znakova (velika i mala slova, cifra), bcrypt; zaključavanje nakon 10 neuspjelih pokušaja na 15 minuta; sesije vezane za uređaj; opozvani uređaji odmah blokirani. |
| **Odvojenost korisnika** | Svaki restoran vidi samo svoje podatke, što se provodi na više nivoa. |
| **Sljedivost** | Ništa se ne briše. Svaka radnja relevantna za sigurnost ili novac upisuje se u zapisnik aktivnosti s osobom, vremenom i IP adresom. |
| **Prenos** | Samo HTTPS (TLS, HSTS), sigurnosna zaglavlja, CSP, CSRF zaštita; bez kolačića za praćenje u aplikaciji. |
| **Hosting** | Hetzner Online GmbH, podatkovni centri u Njemačkoj (EU). Noćne sigurnosne kopije baze, 14 dana lokalno plus kopija na drugoj lokaciji; dnevni snimci servera. |
| **Kvalitet** | 113 automatizovanih backend testova, test prihvatanja u pregledniku, provjera pristupačnosti prema WCAG 2.1 AA. |
| **Tehnologija** | Laravel 12 / PHP 8.4, MySQL 8.4, Redis, Next.js 15 / TypeScript, Docker, Caddy, GitHub Actions. |

Izmjereno u testu prihvatanja: pretraga kartice oko 0,1 sekunde, cijeli proces iskorištavanja uključujući unos broja kartice oko 0,5 sekundi sistemskog vremena i vremena korisničkog interfejsa. Cilj za stolom, uključujući čovjeka: manje od 5 sekundi.

---

## 7. Šta GiftCard Pro nije

Iskrenost štedi vrijeme objema stranama. Trenutno stanje:

| GiftCard Pro nije … | Šta to znači za Vas | Planirano? |
|---|---|---|
| **… online prodavnica poklon bonova** | Kartice se prodaju u objektu. Još nema prodaje preko Vaše web stranice ni obrade plaćanja. | Da, Q1 2027. |
| **… fiskalna kasa** | GiftCard Pro nije certificiran prema austrijskom RKSV-u i ne izdaje račune. Prodaju i iskorištavanje knjižite u svojoj fiskalnoj kasi. | Povezivanje s kasama u provjeri; API dostupan od paketa Pro |
| **… na njemačkom za osoblje** | Interfejs za osoblje je trenutno na engleskom. Tekstovi za goste (kartica, stranica stanja, e-mailovi) postoje na njemačkom i engleskom. | Da, Q4 2026. |
| **… aplikacija iz App Storea** | Aplikacija za konobare je web aplikacija koju stavljate na početni ekran. Nativna aplikacija „GiftCard Waiter" za Android i iPhone (skeniranje i iskorištavanje) je razvijena, ali još nije objavljena u App Storeu ni na Google Playu. Do tada koristite, kao i do sada, web aplikaciju. | Da, nativna aplikacija razvijena; termin objave otvoren |
| **… kontrolna tabla za više lokacija** | Svaka lokacija je zaseban račun restorana. | Da, Q2 2027. |
| **… podržan u Walletu** | Nema kartica za Apple ili Google Wallet. | Da, Q2 2027. |
| **… višestruke valute** | Samo euro. | CHF, BAM, RSD 2028. |
| **… sistem lojalnosti, CRM, rezervacija ili marketinga** | Namjerno nije dio proizvoda. | Ne |
| **… certificiran** | Nema certifikata ISO 27001, SOC 2 ni PCI DSS. Poklon kartice nisu platne kartice u smislu PCI DSS-a. | Nije planirano |

---

## 8. Sistemski zahtjevi

| Namjena | Zahtjev |
|---|---|
| **Kontrolna tabla** | Aktuelni preglednik (Chrome, Edge, Firefox, Safari) na računaru, tabletu ili telefonu; svijetli i tamni način |
| **Upis NFC kartica** | Android telefon s NFC-om i Chromeom (Web NFC). Alternativno, bilo koji uređaj s aplikacijom za upis NFC-a (npr. NFC Tools) |
| **Očitavanje NFC kartica, Android** | Android telefon s NFC-om i Chromeom |
| **Očitavanje NFC kartica, iPhone** | iPhone XS ili noviji: prinesite karticu gornjem rubu, dodirnite obavještenje |
| **Očitavanje QR koda** | Svaki telefon s kamerom |
| **Bez čipa i kamere** | Unos broja kartice — radi na svakom uređaju s preglednikom |
| **Veza** | Internet veza (WLAN ili mobilna mreža). Bez veze se ništa ne knjiži; aplikacija pri ponavljanju nikad ne knjiži dvaput |
| **Kartice** | NTAG213, NTAG215 (preporučeno), NTAG216, NTAG 424 DNA (Pro) ili kartice samo s QR kodom |
| **Štampa** | Format bankovne kartice ISO ID-1 (85,6 × 54 mm), prednja i zadnja strana |

Napomena: pri očitavanju iPhoneom, QR kodom ili brojem kartice ne prenosi se serijski broj čipa. Za kartice visoke vrijednosti zato preporučujemo NTAG 424 DNA.

---

## 9. Jezici

| Područje | Jezici danas | Planirano |
|---|---|---|
| Interfejs za osoblje (kontrolna tabla, aplikacija za konobare) | Engleski | Njemački Q4 2026; bosanski/hrvatski/srpski 2028. |
| Štampana kartica, stranica stanja | Njemački, engleski (jezik restorana) | BHS s ulaskom na tržište 2028. |
| E-mailovi za goste | Predlošci na njemačkom i engleskom, mogu se uređivati | BHS s ulaskom na tržište 2028. |
| Format brojeva i datuma | de-AT, de-DE, de-CH, en-GB, en-US | — |
| Izvozi | CSV sa tačkom-zarezom i decimalnim zarezom — otvara se direktno u Excelu | — |
| Podrška | Njemački, engleski, bosanski/hrvatski/srpski | — |

U uputstvima navodimo engleske nazive dugmadi doslovno, npr. **„Redeem"** (iskoristi).

---

## 10. Kontakt

- Prodaja: hallo@giftcardpro.at
- Podrška: support@giftcardpro.at
- Web stranica: giftcardpro.at · Aplikacija: app.giftcardpro.at

---

Verzija 1.0 · Stanje: septembar 2026.
