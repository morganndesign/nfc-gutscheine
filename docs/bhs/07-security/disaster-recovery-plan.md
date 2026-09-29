# Plan oporavka od katastrofe (Disaster Recovery)

*Kako GiftCard Pro nakon teških poremećaja ponovo uspostavlja rad – ciljne vrijednosti, uloge, scenariji, postupci korak po korak i komunikacija. Za operativni tim GiftCard Pro; restorani i partneri dobijaju ovaj plan radi informacije. Tehnički detalji: [Uputstvo za deployment](../06-technical/deployment-guide.md), [Uputstvo za sigurnosne kopije](../06-technical/backup-guide.md), [Uputstvo za vraćanje podataka](../06-technical/restore-guide.md).*

---

## 1. Obuhvat

Ovaj plan važi za produkcijsko okruženje GiftCard Pro:

| Komponenta | Opis |
|---|---|
| Server | Hetzner Cloud, Ubuntu 24.04, data centar u Njemačkoj (Falkenstein ili Nürnberg), Coolify |
| Servisi | jedan Coolify resurs iz `docker-compose.coolify.yml`: gateway (Caddy), Laravel API, Next.js web, queue worker, scheduler, MySQL 8.4, Redis, servis za sigurnosne kopije; TLS preko Coolify proxyja |
| Podaci | MySQL baza podataka (vaučeri, hashovi QR kodova, plaćanja, ledger, zapisnik aktivnosti, kupci, korisnici, postavke); ledger, plaćanja i zapisnik aktivnosti su append-only i povezani hash lancima. Redis sadrži samo sesije, keš i redove čekanja |
| Sigurnosne kopije | dnevni MySQL dump u `BACKUP_TIME` (standard 01:30 UTC) u servisu `backup`, 14 dana u volumenu `mysql-backups`; prijenos na Hetzner Storage Box (root cron); dnevni Hetzner snapshotovi servera |
| Kod | GitHub repozitorij; Coolify gradi svaki image iz izvornog koda, svaki deployment je vezan za commit |
| Aplikacija za konobare | GiftCard Waiter preko Google Playa i App Storea; adresa servera određena je pri buildu (`config/production.json`) |
| Tajne | `APP_KEY`, SMTP pristupni podaci, lozinke baze i Redisa koje generiše Coolify, ključevi za potpisivanje aplikacije – u menadžeru lozinki operatera odnosno u Coolifyju i GitHub secrets. Ključevi kartica nikada nisu dio ovog okruženja |
| Domena i DNS | `giftcardpro.at`, `app.giftcardpro.at` kod `[Domain-Registrar / DNS-Anbieter]` |

Nisu predmet ovog plana: uređaji, WLAN i fiskalna kasa restorana. Za njih je odgovoran svaki restoran.

---

## 2. Ciljne vrijednosti

| Pokazatelj | Ciljna vrijednost | Osnova |
|---|---|---|
| **RPO** (maksimalan gubitak podataka) | **≤ 24 sata** | dnevni dumpovi baze podataka i snapshotovi servera |
| **RTO** (oporavak nakon potpunog gubitka servera) | **4 sata (cilj)** | ponovna izgradnja s Coolifyjem iz repozitorija, konfiguracije i posljednjeg dumpa |
| RTO kod greške aplikacije nakon ažuriranja | 30 minuta (cilj) | redeploy prethodnog deploymenta u Coolifyju |
| Dostupnost | 99,5 % mjesečno (cilj) | u paketu Start bez garancije; za paket Gruppe moguć ugovorni SLA |

Vrijednosti su **ciljevi**, a ne zagarantovane osobine, osim ako ugovorom nije drugačije dogovoreno.

**Posljedica RPO-a za restorane:** U najgorem slučaju nakon oporavka nedostaju knjiženja od posljednjeg noćnog dumpa. Budući da svaki restoran prodaju i iskorištavanje dodatno knjiži u svojoj fiskalnoj kasi, nedostajuća knjiženja mogu se utvrditi na osnovu računa iz kase. Odjeljak 6.2 opisuje postupak.

---

## 3. Uloge

| Uloga | Zadatak | Popunjenost |
|---|---|---|
| **Rukovodstvo u vanrednoj situaciji** | odlučuje o proglašenju vanredne situacije, scenariju i komunikaciji | [Ime], osnivačica |
| **Tehnički oporavak** | izvršava runbookove | [Ime / tehnička zamjena] |
| **Komunikacija** | obavještava restorane, odgovara na upite podrške | [Ime] odnosno rukovodstvo |
| **Zamjena** | preuzima ako neka od gore navedenih osoba nije dostupna | [Ime zamjene] |

Budući da je GiftCard Pro mali tim, više uloga može biti kod jedne osobe. Odlučujuće je da **zamjena** (odjeljak 5.8) ima pristup menadžeru lozinki, Hetzneru, Coolifyju, GitHubu i DNS-u i da poznaje ovaj plan.

**Kontakti za hitne slučajeve** (popuniti u offline kopiji ovog plana): rukovodstvo `[Telefon]`, zamjena `[Telefon]`, Hetzner podrška `[Kundennummer]`, registrar domene `[Kundennummer]`, pružalac usluge slanja e-mailova `[Kundennummer]`.

---

## 4. Preduslovi (osigurati unaprijed)

- [ ] Menadžer lozinki sadrži: `APP_KEY`, SMTP pristupne podatke, pristupe za Hetzner, Coolify, Storage Box, GitHub, registrar/DNS, slanje e-mailova, App Store Connect i Google Play.
- [ ] Dvofaktorska autentifikacija za Hetzner, Coolify, GitHub, registrar; kodovi za oporavak čuvaju se offline.
- [ ] Odštampana odnosno offline spremljena kopija ovog plana i kontakata za hitne slučajeve.
- [ ] Najmanje dvije osobe s pristupom menadžeru lozinki.
- [ ] Posljednji uspješan test oporavka (s `giftcard:verify-chains` bez nalaza) nije stariji od tri mjeseca.

---

## 5. Scenariji

### 5.1 Potpuni gubitak servera

*Primjeri: kvar hardvera, slučajno brisanje, server se više ne može pokrenuti.*

1. **Utvrditi:** `/up` nije dostupan, server se u Hetzner konzoli ne može pokrenuti. Obavijestiti rukovodstvo, proglasiti vanrednu situaciju, status restoranima (predložak A).
2. **Odlučiti:** oporavak iz Hetzner snapshota (brže, stanje staro do 24 h) ili ponovna izgradnja s posljednjim dumpom. Ako je posljednji dump noviji od snapshota, nakon vraćanja snapshota dodatno se uvozi.
3. **Varijanta A – snapshot:** u Hetzner konzoli kreirati novi server iz posljednjeg snapshota (isti tip, lokacija u EU), dodijeliti firewall (22 samo s IP adresa operatera, 80, 443).
4. **Varijanta B – ponovna izgradnja** ([Uputstvo za vraćanje podataka, scenarij C](../06-technical/restore-guide.md#5-scenarij-c--potpuni-gubitak-servera)):
   1. Kreirati novi server, pohraniti SSH ključ, dodijeliti firewall, instalirati Coolify.
   2. Kreirati Coolify resurs iz repozitorija kao u [Uputstvu za deployment](../06-technical/deployment-guide.md) – domenu gatewaya, `MAIL_*` i **prvobitni `APP_KEY`** iz menadžera lozinki kao Environment Variables.
   3. *Deploy*; Coolify generiše lozinke baze i Redisa, kontejneri kreiraju praznu šemu.
   4. Posljednji dump sa Storage Boxa preuzeti u volumen `mysql-backups`, režim održavanja (`php artisan down`), uvesti dump u kontejneru **backup**, *Redeploy*.
5. **DNS:** A/AAAA zapise za `app.giftcardpro.at` preusmjeriti na novu IP adresu. Coolify automatski preuzima TLS certifikat.
6. **Provjeriti:** `/up` vraća 200; `php artisan giftcard:verify-chains` bez nalaza; prijava kao administracija platforme; uzorak: skenirati testni QR kod testnog restorana; scheduler i red čekanja rade (`schedule:list`, nadzor reda čekanja).
7. **Naknadni rad:** na novom serveru postaviti off-site sinhronizaciju i jednom je ručno pokrenuti. Obavijestiti restorane o stanju podataka (predložak C), koordinirati naknadni unos (odjeljak 6.2).

### 5.2 Oštećena baza podataka

*Primjeri: MySQL se ne pokreće, nekonzistentne tabele, neispravna migracija, provjera integriteta javlja nalaz.*

1. Zaustaviti upise: režim održavanja (`php artisan down`) odnosno zaustaviti servise `api`, `worker` i `scheduler` u Coolifyju, kako ne bi nastajala nova knjiženja na oštećenim podacima. Obavještenje o održavanju (predložak A).
2. Osigurati stanje: napraviti svjež dump i snapshot volumena `mysql-data` (za analizu, ne prepisivati). Ako provjera integriteta javlja nalaz, dodatno pokrenuti [Vodič za odgovor na incidente](incident-response-guide.md) (playbook 7.7).
3. Pokušaj popravke samo ako su uzrok i obim jasni. Ledger, plaćanja i zapisnik aktivnosti nikada se ne ispravljaju SQL-om. U suprotnom:
4. Posljednji dump prvo uvesti u zasebnu bazu i provjeriti kontrolnim upitima iz [Uputstva za vraćanje podataka](../06-technical/restore-guide.md#8-kontrolni-upiti-nakon-vraćanja) (stanje = zbir knjiženja, svako knjiženje s plaćanjem odnosno predočenjem, uvjerljive količine).
5. Produkcijsku bazu vratiti iz tog dumpa (Uputstvo za vraćanje podataka, scenarij B), *Redeploy*, `php artisan giftcard:verify-chains`, provjeriti kao u 5.1 korak 6.
6. Utvrditi knjiženja između dumpa i ispada (vidi 6.2) i obavijestiti restorane.

### 5.3 Ispad data centra odnosno lokacije

*Primjer: Hetzner lokacija duže vrijeme nije dostupna.*

1. Provjeriti Hetzner statusnu stranicu; kod očekivanog trajanja dužeg od 2 sata ponovna izgradnja na drugoj Hetzner lokaciji u EU (npr. Nürnberg umjesto Falkensteina) prema 5.1 varijanta B.
2. Dump se preuzima sa Storage Boxa. Ako ni on nije dostupan, koristi se najnovije dostupno stanje; RPO tada može biti prekoračen.
3. Promijeniti DNS, provjeriti, obavijestiti.

Napomena: druga, stalno spremna lokacija nije postavljena (vidi listu poboljšanja).

### 5.4 Ransomware ili kompromitacija servera

*Primjeri: šifrovane datoteke, nepoznati procesi, izmijenjena konfiguracija, znaci pristupa trećih lica, prekinut hash lanac.*

1. **Ne** gasiti prije nego što su dokazi osigurani, osim ako se podaci aktivno uništavaju. Server u Hetzner konzoli odvojiti od mreže (firewall: ukloniti sva pravila) i napraviti snapshot za forenziku.
2. Paralelno pokrenuti [Vodič za odgovor na incidente](incident-response-guide.md) (nivo ozbiljnosti SEV-1, provjera zaštite podataka).
3. **Sve tajne tretirati kao kompromitovane:** generisati novi `APP_KEY` (svi korisnici se odjavljuju), nove lozinke baze i Redisa (novi Coolify resurs), obnoviti SMTP lozinku, SSH ključeve, pristup Storage Boxu i vezu Coolifyja s GitHubom. Opozvati sve API tokene i tokene uređaja. QR kodovi vaučera ostaju važeći: server pohranjuje samo hashove, iz kojih se QR kod ne može napraviti.
4. Ponovna izgradnja na **novom** serveru prema 5.1 varijanta B – kompromitovani server nikada dalje ne koristiti.
5. Odabrati dump koji je **prije** trenutka kompromitacije; integritet se potvrđuje s `php artisan giftcard:verify-chains` i poređenjem sa starijim dumpovima. Pažnja: off-site kopija se odražava preko `rclone sync` i kao i server sadrži dumpove posljednjih 14 dana. Na nju se može pisati s produkcijskog servera i stoga nije automatski zaštićena od napadača – Hetzner snapshotove i stanja Storage Boxa odvojeno provjeriti na netaknutost (vidi listu poboljšanja br. 5).
6. Nakon oporavka: reset lozinke za sve administratore platforme, zatražiti od restorana da ponovo kreiraju API tokene; konobari se ponovo prijavljuju u aplikaciju za konobare.

### 5.5 Slučajna promjena podataka

*Primjeri: vaučer greškom blokiran ili istekao, pogrešno iskorištavanje, pogrešna postavka.*

Aplikacija ne briše finansijske podatke, knjiženja se nikada ne prepisuju. Većina grešaka ispravlja se **u aplikaciji**, a ne oporavkom:

| Greška | Ispravka |
|---|---|
| Pogrešno iskorištavanje ili dopuna | storno (protuknjiženje) u historiji vaučera ili pod Transactions |
| Vaučer greškom blokiran | **„Unblock“** |
| Vaučer greškom istekao | **„Reinstate“** (Owner, s razlogom); stanje je pri isteku ostalo sačuvano |
| Korisnik greškom deaktiviran | ponovo aktivirati |
| Uređaj greškom blokiran | **„Restore“** |
| Kupac greškom anonimiziran | nije povratno; lične podatke ponovo unijeti iz dokumentacije restorana |

Samo ako se greška dogodi na nivou baze podataka (npr. neispravan ručni upit operatera nad matičnim podacima): pogođene zapise iz posljednjeg dumpa učitati u zasebnu bazu i ciljano uporediti. **Nikada** ne vraćati cijelu produkcijsku bazu na starije stanje samo da bi se otklonila pojedinačna greška.

### 5.6 Gubitak domene ili DNS-a

*Primjeri: domena nije produžena, DNS pružalac nije dostupan, DNS zapisi izmanipulisani.*

1. Provjeriti status kod registrara; kod isteka odmah produžiti. Kod manipulacije: osigurati račun kod registrara (lozinka, 2FA), ispraviti zapise, aktivirati zaključavanje prijenosa (Transfer Lock).
2. Kod dužeg ispada DNS pružaoca: prebaciti nameservere na zamjenskog pružaoca (podaci o zoni iz dokumentacije).
3. **Važno:** QR kodovi vaučera ne sadrže domenu i ostaju važeći. Aplikacija za konobare je, međutim, fiksno izgrađena s `https://app.giftcardpro.at/api/v1`, a sesije u pregledniku vezane su za tu domenu. Do oporavka domene konobari ne mogu iskorištavati vaučere; zamjenska domena zahtijevala bi novi build aplikacije i novu objavu u prodavnicama. Domena se zato nikada ne smije napustiti.
4. Obavijestiti restorane (predložak A).

### 5.7 Blokada računa kod pružaoca hostinga

*Primjeri: problem s plaćanjem, blokada zbog sumnje na zloupotrebu, gubitak pristupa.*

1. Kontaktirati Hetzner podršku, razjasniti razlog blokade.
2. Ako brzo ukidanje nije moguće: ponovna izgradnja kod **drugog računa odnosno EU pružaoca** s Coolifyjem i sigurnosnim kopijama izvan lokacije. Preduslov: kopija izvan lokacije mora biti dostupna nezavisno od blokiranog računa (vidi listu poboljšanja – trenutno je i Storage Box kod Hetznera).
3. Promijeniti DNS, obavijestiti restorane, ažurirati ugovor o obradi podataka u pogledu novog podizvršitelja obrade i o tome obavijestiti restorane.

### 5.8 Ključna osoba nije dostupna

*Primjeri: bolest, godišnji odmor bez dostupnosti, nesreća.*

1. Zamjena preuzima prema odjeljku 3.
2. Pristup preko menadžera lozinki, kojem zamjena ima pristup prema odjeljku 4.
3. Ova dokumentacija i Uputstvo za deployment omogućavaju ponovnu izgradnju i oporavak bez prethodnog znanja.
4. Restorani se obavještavaju samo ako je pogođeno vrijeme podrške.

---

## 6. Opšti postupci

### 6.1 Oporavak iz dumpa (kratka verzija)

1. Kontejner **api**: `php artisan down`.
2. Kontejner **backup**: `gunzip -c /backups/<giftcard_pro_YYYYMMDDTHHMMSSZ>.sql.gz | mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"`.
3. Resurs → *Redeploy*.
4. Kontejner **api**: `php artisan giftcard:verify-chains`; `curl -fsS https://app.giftcardpro.at/up`.

Detalji i kontrolni upiti: [Uputstvo za vraćanje podataka](../06-technical/restore-guide.md).

### 6.2 Naknadni unos knjiženja između dumpa i ispada

1. Zabilježiti vrijeme dumpa (naziv datoteke, UTC) i vrijeme ispada.
2. Iz zapisnika aplikacije i gatewaya, ako postoje, utvrditi pogođene restorane.
3. Svakom pogođenom restoranu poslati listu vaučera sa stanjem u trenutku dumpa i zamoliti za poređenje s računima iz fiskalne kase.
4. **Prodaje** u izgubljenom periodu ne postoje nakon oporavka; njihov QR kod se više ne prepoznaje. Restoran ponovo prodaje vaučer, evidentira prvobitno plaćanje (npr. kartični terminal s prvobitnim brojem potvrde) i gostu predaje novi list za štampu.
5. **Dopune** restoran ponovo evidentira s prvobitnim plaćanjem i napomenom „Naknadni unos nakon oporavka“.
6. **Iskorištavanja** uvijek zahtijevaju predočenje vaučera. Pogođene vaučere restoran blokira s tom napomenom; kada gost ponovo predoči vaučer, deblokira ga i evidentira nedostajuće iskorištavanje s napomenom. Administracija platforme nikada ne knjiži u ime restorana.

### 6.3 Povratak na prethodni deployment

Svaki deployment vezan je za commit. Kod neispravnog ažuriranja u Coolifyju se ponovo uvodi prethodni deployment (*Deployments* → *Redeploy*). Izmjene šeme pišu se tako da prethodna verzija nastavlja raditi s novijom šemom; baza se pri tome ne vraća.

---

## 7. Predlošci za komunikaciju

### Predložak A – poremećaj (prva informacija)

> **Predmet: GiftCard Pro – poremećaj od [vrijeme]**
>
> Poštovani,
>
> od [vrijeme] GiftCard Pro nije dostupan odnosno dostupan je samo ograničeno. Pogođeno je: [iskorištavanje / prodaja / kontrolna tabla / sve]. Radimo na otklanjanju i ponovo ćemo se javiti najkasnije u [vrijeme].
>
> **Do tada:** vaučeri se u tom periodu ne mogu iskoristiti – svako iskorištavanje zahtijeva provjeru vaučera na našem serveru, a broj vaučera nije zamjena za to. Zamolite goste da plate na drugi način ili da vaučer iskoriste pri sljedećoj posjeti. U tom periodu ne prodajite vaučere.
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
> **Stanje podataka:** [Sva knjiženja su potpuno sačuvana.] **ili** [Podaci su vraćeni na stanje od [datum, vrijeme]. Nedostaju knjiženja između [vrijeme] i [vrijeme]. Za Vaš restoran to se vjerovatno odnosi na [broj] vaučera; listu ćete pronaći u prilogu. Molimo uporedite je s Vašom fiskalnom kasom. Vaučere prodate u tom periodu molimo ponovo prodajte s prvobitnim plaćanjem i gostu predajte novi list za štampu; nedostajuća iskorištavanja evidentirajte kada gost ponovo predoči vaučer. Rado ćemo Vam pomoći.]
>
> Detaljan izvještaj dobićete do [datum].
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
| **Potpuni test oporavka** | **tromjesečno** | preuzeti dump sa Storage Boxa, na zasebnom testnom serveru s Coolifyjem izgraditi kompletno okruženje, `giftcard:verify-chains`, testirati prijavu i QR skeniranje, izmjeriti trajanje | izvještaj s izmjerenim trajanjem u odnosu na RTO |
| **DR vježba** | **godišnje** | odigrati scenarij (npr. 5.1 ili 5.4) uklj. zamjenu, komunikaciju i promjenu DNS-a na testnoj domeni | izvještaj, mjere u listi poboljšanja |
| Pregled plana | godišnje i nakon svake vanredne situacije | provjeriti kontakte, pristupe, komande, ciljne vrijednosti | nova verzija ovog dokumenta |

---

## 9. Lista poboljšanja

| Br. | Mjera | Korist | Status |
|---|---|---|---|
| 1 | Binarne logove (binlogs) MySQL-a stalno sigurnosno kopirati izvan lokacije → oporavak na bilo koji trenutak (PITR) | RPO s 24 h na nekoliko minuta | planirano |
| 2 | Druga lokacija odnosno druga regija s replikom baze podataka | znatno kraći RTO kod ispada lokacije | planirano |
| 3 | Kopija izvan lokacije dodatno kod EU pružaoca nezavisnog od hostinga odnosno na odvojenom računu | zaštita kod blokade računa (5.7) | planirano |
| 4 | Šifrovanje datoteka sigurnosnih kopija prije prijenosa | zaštita backupa kod pristupa memoriji | planirano |
| 5 | Nepromjenjiva stanja sigurnosnih kopija (append-only / verzionisanje) na memoriji izvan lokacije | zaštita od ransomwarea koji šifruje i backupe | planirano |
| 6 | Javna statusna stranica | brže informisanje restorana | planirano |
| 7 | Automatizovani test oporavka s provjerom integriteta u CI-ju | stalan dokaz mogućnosti oporavka | planirano |

---

Verzija 2.0 · Stanje: septembar 2026.
