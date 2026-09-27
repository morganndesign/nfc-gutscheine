# Plan oporavka od katastrofe (Disaster Recovery)

*Kako GiftCard Pro nakon teških poremećaja ponovo uspostavlja rad – ciljne vrijednosti, uloge, scenariji, postupci korak po korak i komunikacija. Za operativni tim GiftCard Pro; restorani i partneri dobijaju ovaj plan radi informacije.*

---

## 1. Obuhvat

Ovaj plan važi za produkcijsko okruženje GiftCard Pro:

| Komponenta | Opis |
|---|---|
| Server | Hetzner Cloud, Ubuntu 24.04, data centar u Njemačkoj (Falkenstein ili Nürnberg), Docker Compose |
| Servisi | Caddy (TLS, proxy), Laravel API, Next.js web, queue worker, scheduler, MySQL 8.4, Redis |
| Podaci | MySQL baza podataka (kartice, dnevnik, zapisnik aktivnosti, kupci, korisnici, postavke); Redis sadrži samo sesije, keš i redove čekanja |
| Sigurnosne kopije | noćni MySQL dump u 02:30, 14 dana lokalno; prijenos na Hetzner Storage Box u 02:45; dnevni Hetzner snapshotovi servera |
| Kod i image-i | GitHub repozitorij, container image-i u GitHub Container Registry (GHCR), svaka verzija označena commitom |
| Tajne | `APP_KEY`, lozinke baze podataka i Redisa, NTAG 424 ključevi, ključevi za isporuku – u menadžeru lozinki operatera |
| Domena i DNS | `giftcardpro.at`, `app.giftcardpro.at` kod `[Domain-Registrar / DNS-Anbieter]` |

Nisu predmet ovog plana: uređaji, WLAN i fiskalna kasa restorana. Za njih je odgovoran svaki restoran.

---

## 2. Ciljne vrijednosti

| Pokazatelj | Ciljna vrijednost | Osnova |
|---|---|---|
| **RPO** (maksimalan gubitak podataka) | **≤ 24 sata** | dnevni dumpovi baze podataka i snapshotovi servera |
| **RTO** (oporavak nakon potpunog gubitka servera) | **4 sata (cilj)** | ponovna izgradnja iz image-a, konfiguracije i posljednjeg dumpa |
| RTO kod greške aplikacije nakon ažuriranja | 30 minuta (cilj) | povratak na prethodni image |
| Dostupnost | 99,5 % mjesečno (cilj) | u paketu Start bez garancije; za paket Gruppe moguć ugovorni SLA |

Vrijednosti su **ciljevi**, a ne zagarantovane osobine, osim ako ugovorom nije drugačije dogovoreno.

**Posljedica RPO-a za restorane:** U najgorem slučaju nakon oporavka nedostaju knjiženja od posljednjeg noćnog dumpa. Budući da svaki restoran prodaju i iskorištavanje dodatno knjiži u svojoj fiskalnoj kasi, nedostajuća knjiženja mogu se naknadno unijeti na osnovu računa iz kase. Odjeljak 6.2 opisuje postupak.

---

## 3. Uloge

| Uloga | Zadatak | Popunjenost |
|---|---|---|
| **Rukovodstvo u vanrednoj situaciji** | odlučuje o proglašenju vanredne situacije, scenariju i komunikaciji | [Ime], osnivačica |
| **Tehnički oporavak** | izvršava runbookove | [Ime / tehnička zamjena] |
| **Komunikacija** | obavještava restorane, odgovara na upite podrške | [Ime] odnosno rukovodstvo |
| **Zamjena** | preuzima ako neka od gore navedenih osoba nije dostupna | [Ime zamjene] |

Budući da je GiftCard Pro mali tim, više uloga može biti kod jedne osobe. Odlučujuće je da **zamjena** (odjeljak 5.8) ima pristup menadžeru lozinki, Hetzneru, GitHubu i DNS-u i da poznaje ovaj plan.

**Kontakti za hitne slučajeve** (popuniti u offline kopiji ovog plana): rukovodstvo `[Telefon]`, zamjena `[Telefon]`, Hetzner podrška `[Kundennummer]`, registrar domene `[Kundennummer]`, pružalac usluge slanja e-mailova `[Kundennummer]`.

---

## 4. Preduslovi (osigurati unaprijed)

- [ ] Menadžer lozinki sadrži: `APP_KEY`, sadržaje `.env.production` (API i Compose), NTAG 424 ključeve, pristupe za Hetzner, Storage Box, GitHub, registrar/DNS, slanje e-mailova.
- [ ] Dvofaktorska autentifikacija za Hetzner, GitHub, registrar; kodovi za oporavak čuvaju se offline.
- [ ] Odštampana odnosno offline spremljena kopija ovog plana i kontakata za hitne slučajeve.
- [ ] Najmanje dvije osobe s pristupom menadžeru lozinki.
- [ ] Posljednji uspješan test oporavka nije stariji od tri mjeseca.

---

## 5. Scenariji

### 5.1 Potpuni gubitak servera

*Primjeri: kvar hardvera, slučajno brisanje, server se više ne može pokrenuti.*

1. **Utvrditi:** `/up` nije dostupan, server se u Hetzner konzoli ne može pokrenuti. Obavijestiti rukovodstvo, proglasiti vanrednu situaciju, status restoranima (predložak A).
2. **Odlučiti:** oporavak iz Hetzner snapshota (brže, stanje do 24 h staro) ili ponovna izgradnja s posljednjim dumpom (stanje od 02:30 istog dana). Ako je posljednji dump noviji od snapshota, nakon oporavka iz snapshota dodatno se učitava i dump.
3. **Varijanta A – snapshot:** U Hetzner konzoli kreirati novi server iz posljednjeg snapshota (isti tip, EU lokacija), dodijeliti Cloud Firewall (22 samo s IP adresa operatera, 80, 443).
4. **Varijanta B – ponovna izgradnja:**
   1. Kreirati novi server, dodati SSH ključ, dodijeliti firewall.
   2. Ojačavanje i Docker prema priručniku za isporuku (korisnik `deploy`, bez prijave lozinkom i bez root prijave, `unattended-upgrades`, `fail2ban`, Docker).
   3. Klonirati repozitorij u `/opt/giftcard-pro`, vratiti `.env.production` i `backend/.env.production` iz menadžera lozinki – **s izvornim `APP_KEY`** i izvornim NTAG 424 ključevima.
   4. Preuzeti posljednji dump sa Storage Boxa (`rclone copy storagebox:giftcard-backups/<datoteka> ./backups/`).
   5. Pokrenuti samo MySQL, učitati dump: `gunzip -c backups/<datoteka>.sql.gz | docker compose --env-file .env.production exec -T mysql mysql -u root -p <baza>`.
   6. Pokrenuti sve servise: `docker compose --env-file .env.production up -d`.
5. **DNS:** A/AAAA zapise za `app.giftcardpro.at` preusmjeriti na novu IP adresu. Caddy pri prvom pozivu automatski preuzima TLS certifikat.
6. **Provjeriti:** `/up` vraća 200; prijava kao administracija platforme; uzorak: skenirati karticu testnog restorana; zbir knjiženja u dnevniku po kartici odgovara stanju (provjera konzistentnosti); scheduler i queue rade (`schedule:list`, nadzor redova čekanja).
7. **Naknadni rad:** Na novom serveru postaviti cron poslove za backup i sinhronizaciju izvan lokacije i jednom ih ručno pokrenuti. Obavijestiti restorane o stanju podataka (predložak C), koordinirati naknadno knjiženje (odjeljak 6.2).

### 5.2 Oštećena baza podataka

*Primjeri: MySQL se ne pokreće, nekonzistentne tabele, neispravna migracija.*

1. Zaustaviti pisanje: zaustaviti web, API, worker i scheduler (`docker compose stop web api queue scheduler`), kako ne bi nastajala daljnja knjiženja na oštećenim podacima. Obavještenje o održavanju (predložak A).
2. Osigurati stanje: kopirati volume s podacima odnosno direktorij baze podataka (za analizu, ne prepisivati).
3. Pokušaj popravke samo ako su uzrok i obim jasni. U suprotnom:
4. Kreirati novu, praznu bazu podataka (npr. `giftcard_pro_restore`), učitati posljednji dump, provjera konzistentnosti (stanje = zbir knjiženja po kartici, broj kartica/knjiženja uvjerljiv).
5. Konfiguraciju prebaciti na obnovljenu bazu podataka, pokrenuti servise, provjeriti kao u 5.1 korak 6.
6. Utvrditi knjiženja između dumpa i ispada (vidi 6.2) i obavijestiti restorane.

### 5.3 Ispad data centra odnosno lokacije

*Primjer: Hetzner lokacija duže vrijeme nije dostupna.*

1. Provjeriti statusnu stranicu Hetznera; ako se očekuje trajanje duže od 2 sata, ponovna izgradnja na drugoj EU lokaciji Hetznera (npr. Nürnberg umjesto Falkenstein) prema 5.1 varijanta B.
2. Dump se preuzima sa Storage Boxa. Ako ni on nije dostupan, koristi se najnovije dostupno stanje; RPO tada može biti prekoračen.
3. Preusmjeriti DNS, provjeriti, obavijestiti.

Napomena: druga, stalno spremna lokacija trenutno nije postavljena (vidi listu poboljšanja).

### 5.4 Ransomware ili kompromitacija servera

*Primjeri: šifrovane datoteke, nepoznati procesi, izmijenjena konfiguracija, znaci pristupa trećih lica.*

1. **Ne** gasiti server prije osiguranja dokaza, osim ako se podaci aktivno uništavaju. Server u Hetzner konzoli odvojiti od mreže (firewall: ukloniti sva pravila) i kreirati snapshot za forenziku.
2. Paralelno pokrenuti [Vodič za odgovor na incidente](incident-response-guide.md) (nivo ozbiljnosti SEV-1, provjera zaštite podataka).
3. **Sve tajne tretirati kao kompromitovane:** generisati novi `APP_KEY` (svi korisnici se odjavljuju), nove lozinke za bazu podataka i Redis, novi ključ za isporuku, obnoviti GHCR token i pristup Storage Boxu. NTAG 424 ključeve mijenjati samo ako su dokazano pogođeni (zamjena zahtijeva ponovno programiranje kartica).
4. Ponovna izgradnja na **novom** serveru prema 5.1 varijanta B – kompromitovani server nikada dalje ne koristiti.
5. Odabrati dump koji je nastao **prije** trenutka kompromitacije; integritet se potvrđuje provjerom konzistentnosti i poređenjem sa starijim dumpovima. Pažnja: kopija izvan lokacije se ogleda pomoću `rclone sync` i, kao i server, sadrži dumpove posljednjih 14 dana. S produkcijskog servera je upisiva i stoga nije automatski zaštićena od napadača – Hetzner snapshotove i stanja na Storage Boxu odvojeno provjeriti na neoštećenost (vidi listu poboljšanja br. 5).
6. Nakon oporavka: reset lozinki za sve administratore platforme, pozvati restorane da obnove API tokene.

### 5.5 Slučajna promjena podataka

*Primjeri: kartica greškom blokirana ili istekla, pogrešno iskorištavanje, pogrešna postavka.*

Aplikacija ne briše podatke, knjiženja se ne prepisuju. Većina grešaka ispravlja se **u aplikaciji**, a ne oporavkom:

| Greška | Ispravka |
|---|---|
| Pogrešno iskorištavanje ili dopuna | storno (protuknjiženje) u historiji kartice ili pod Transactions |
| Kartica greškom blokirana | **„Unblock"** |
| Kartica greškom istekla | stanje ponovo učiniti dostupnim putem zamjenske kartice odnosno prijenosa |
| Korisnik greškom deaktiviran | ponovo aktivirati |
| Uređaj greškom blokiran | **„Restore"** |
| Kupac greškom anonimiziran | nepovratno; lične podatke ponovo unijeti iz dokumentacije restorana |

Samo ako se greška dogodi na nivou baze podataka (npr. neispravan ručni upit operatera): pogođene zapise iz posljednjeg dumpa učitati u zasebnu bazu podataka i ciljano uporediti. **Nikada** ne vraćati cijelu produkcijsku bazu podataka na starije stanje samo da bi se ispravila pojedinačna greška.

### 5.6 Gubitak domene ili DNS-a

*Primjeri: domena nije produžena, DNS pružalac nije dostupan, DNS zapisi izmanipulisani.*

1. Kod registrara provjeriti status; kod isteka odmah produžiti. Kod manipulacije: osigurati račun kod registrara (lozinka, 2FA), ispraviti zapise, aktivirati zaključavanje kod registrara (Transfer Lock).
2. Kod dužeg ispada DNS pružaoca: nameservere prebaciti na zamjenskog pružaoca (podaci o zoni iz dokumentacije).
3. **Važno:** Link na svakoj kartici pokazuje na `app.giftcardpro.at`. Domena se nikada ne smije napustiti dok su kartice u opticaju. Do oporavka konobari ne mogu iskorištavati kartice. Zamjenska adresa pomaže samo za unos broja kartice, ne i za već upisane čipove.
4. Obavijestiti restorane (predložak A).

### 5.7 Blokada računa kod pružaoca hostinga

*Primjeri: problem s plaćanjem, blokada zbog sumnje na zloupotrebu, gubitak pristupa.*

1. Kontaktirati Hetzner podršku, razjasniti razlog blokade.
2. Ako brzo ukidanje nije moguće: ponovna izgradnja kod **drugog računa odnosno EU pružaoca** sa sigurnosnim kopijama izvan lokacije. Preduslov: kopija izvan lokacije mora biti dostupna nezavisno od blokiranog računa (vidi listu poboljšanja – trenutno je i Storage Box kod Hetznera).
3. Preusmjeriti DNS, obavijestiti restorane, ažurirati ugovor o obradi podataka po nalogu u pogledu novog podizvršitelja obrade i o tome obavijestiti restorane.

### 5.8 Ključna osoba nije dostupna

*Primjeri: bolest, godišnji odmor bez dostupnosti, nesreća.*

1. Zamjena preuzima prema odjeljku 3.
2. Pristup preko menadžera lozinki, kojem zamjena prema odjeljku 4 ima pristup.
3. Ova dokumentacija i priručnik za isporuku omogućavaju ponovnu izgradnju i oporavak bez prethodnog znanja.
4. Restorani se obavještavaju samo ako je pogođeno vrijeme podrške.

---

## 6. Opšti postupci

### 6.1 Oporavak iz dumpa (kratka verzija)

```bash
cd /opt/giftcard-pro
rclone copy storagebox:giftcard-backups/<giftcard_pro_YYYYMMDDTHHMMSSZ.sql.gz> ./backups/
docker compose --env-file .env.production up -d mysql
gunzip -c backups/<datoteka>.sql.gz | docker compose --env-file .env.production exec -T mysql mysql -u root -p <baza>
docker compose --env-file .env.production up -d
curl -fsS https://app.giftcardpro.at/up
```

### 6.2 Naknadno knjiženje između dumpa i ispada

1. Zabilježiti vrijeme dumpa (naziv datoteke, UTC) i vrijeme ispada.
2. Iz zapisnika aplikacije i proxyja, ako postoje, utvrditi pogođene restorane i kartice.
3. Svakom pogođenom restoranu poslati listu kartica sa stanjem u trenutku dumpa i zamoliti za poređenje s računima iz fiskalne kase.
4. Nedostajuća iskorištavanja, prodaje i dopune restoran knjiži naknadno (ili operater po nalogu i preko „Open restaurant", uz audit) s napomenom „Naknadno knjiženje nakon oporavka".
5. Kartice koje su u tom periodu novo izdane ne postoje nakon oporavka. Treba ih ponovo kreirati; upisani čip treba ponovo upisati (novi identifikator).

### 6.3 Povratak na prethodnu verziju

Container image-i su označeni commitom. Kod neispravnog ažuriranja ponovo se uvodi prethodni image. Migracije baze podataka su kompatibilne unazad (prvo proširiti, zatim prebaciti, zatim očistiti), tako da prethodna verzija nastavlja raditi s novom shemom.

---

## 7. Predlošci za komunikaciju

### Predložak A – poremećaj (prva informacija)

> **Predmet: GiftCard Pro – poremećaj od [vrijeme]**
>
> Poštovani,
>
> od [vrijeme] GiftCard Pro nije dostupan odnosno dostupan je samo ograničeno. Pogođeno je: [iskorištavanje / kontrolna tabla / sve]. Radimo na otklanjanju i ponovo ćemo se javiti najkasnije u [vrijeme].
>
> **Do tada preporučujemo:** Poklon kartice prihvatajte samo ako zabilježite broj kartice i iznos te iskorištavanje naknadno proknjižite nakon oporavka. Označite te slučajeve u fiskalnoj kasi. Kod visokih iznosa ili nepoznatih gostiju preporučujemo da iskorištavanje odgodite za kasniju posjetu.
>
> Aktuelne informacije: [statusna stranica / e-mail]. Pitanja: support@giftcardpro.at, [Telefon].
>
> Srdačan pozdrav
> Vaš tim GiftCard Pro

### Predložak B – novosti tokom poremećaja

> **Predmet: GiftCard Pro – novosti [vrijeme]**
>
> Stanje [vrijeme]: [uzrok, ako je poznat]. [Šta je već obnovljeno]. Očekivani oporavak: [vrijeme]. Sljedeće obavještenje: [vrijeme].

### Predložak C – oporavak završen

> **Predmet: GiftCard Pro ponovo je dostupan**
>
> Poštovani,
>
> GiftCard Pro je od [vrijeme] ponovo potpuno dostupan. Uzrok je bio [kratak opis].
>
> **Stanje podataka:** [Sva knjiženja su potpuno sačuvana.] **ili** [Podaci su vraćeni na stanje od [datum, vrijeme]. Nedostaju knjiženja između [vrijeme] i [vrijeme]. Za Vaš restoran to se vjerovatno odnosi na [broj] kartica; listu ćete pronaći u prilogu. Molimo uporedite je s Vašom fiskalnom kasom i naknadno proknjižite nedostajuće radnje. Rado ćemo Vam pomoći.]
>
> Zabilježena iskorištavanja iz vremena ispada molimo sada naknadno proknjižite. Detaljan izvještaj dobićete do [datum].
>
> Izvinjavamo se zbog neugodnosti.
>
> Srdačan pozdrav
> Vaš tim GiftCard Pro

---

## 8. Testovi i vježbe

| Vježba | Učestalost | Sadržaj | Dokaz |
|---|---|---|---|
| Oporavak na uzorku | mjesečno | posljednji dump učitati u testnu bazu, provjeriti broj redova i konzistentnost | zapis u dnevniku |
| **Potpuni test oporavka** | **tromjesečno** | preuzeti dump sa Storage Boxa, na zasebnom testnom serveru izgraditi kompletno okruženje, testirati prijavu i skeniranje kartice, izmjeriti trajanje | izvještaj s izmjerenim trajanjem u odnosu na RTO |
| **DR vježba** | **godišnje** | odigrati scenarij (npr. 5.1 ili 5.4) uklj. zamjenu, komunikaciju i promjenu DNS-a na testnoj domeni | izvještaj, mjere u listi poboljšanja |
| Pregled plana | godišnje i nakon svake vanredne situacije | provjeriti kontakte, pristupe, komande, ciljne vrijednosti | nova verzija ovog dokumenta |

---

## 9. Lista poboljšanja

| Br. | Mjera | Korist | Status |
|---|---|---|---|
| 1 | Aktivirati binarne logove (binlogs) MySQL-a i stalno ih sigurnosno kopirati izvan lokacije → oporavak na bilo koji trenutak (PITR) | RPO s 24 h na nekoliko minuta | planirano |
| 2 | Druga lokacija odnosno druga regija s replikom baze podataka | znatno kraći RTO kod ispada lokacije | planirano |
| 3 | Kopija izvan lokacije dodatno kod EU pružaoca nezavisnog od hostinga odnosno na odvojenom računu | zaštita kod blokade računa (5.7) | planirano |
| 4 | Šifrovanje datoteka sigurnosnih kopija prije prijenosa | zaštita backupa kod pristupa memoriji | planirano |
| 5 | Nepromjenjiva stanja sigurnosnih kopija (append-only / verzionisanje) na memoriji izvan lokacije | zaštita od ransomwarea koji šifruje i backupe | planirano |
| 6 | Javna statusna stranica | brže informisanje restorana | planirano |
| 7 | Automatizovani test oporavka u CI-ju | stalan dokaz mogućnosti oporavka | planirano |

---

Verzija 1.0 · Stanje: septembar 2026.
