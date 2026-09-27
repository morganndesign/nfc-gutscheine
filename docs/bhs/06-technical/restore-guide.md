# Uputstvo za vraćanje podataka

*Vraćanje podataka u GiftCard Pro korak po korak: istraživanje pojedinačnih zapisa, potpuno vraćanje baze, potpuni gubitak servera, ograničenja point-in-time vraćanja, kontrolni upiti i komunikacija s restoranima.*

---

## 1. Osnovna pravila

1. **Produkcijski ledger se nikada ne prepisuje radi ispravke pojedinačnih grešaka.** Pojedinačna pogrešna knjiženja ispravljaju se u aplikaciji protuknjiženjem (**Reverse**) odnosno novim knjiženjem. Vraćanje cijele baze dozvoljeno je samo kod gubitka ili oštećenja baze.
2. **Prije svakog zahvata napravite aktuelnu sigurnosnu kopiju** – i od oštećenog stanja.
3. **Najprije uvezite u posebnu bazu za vraćanje i provjerite**, zatim odlučite.
4. Svako vraćanje se dokumentuje: vrijeme, korištena datoteka, razlog, odgovorna osoba, rezultat kontrolnih upita.
5. Baze za vraćanje sadrže lične podatke – nakon završetka ih obrišite.

Sve naredbe važe na serveru u direktoriju `/opt/giftcard-pro` kao korisnik `deploy`. Skraćenica za ovo uputstvo:

```bash
cd /opt/giftcard-pro
alias dc='docker compose --env-file .env.production'
```

Root lozinka MySQL-a dostupna je u MySQL kontejneru kao varijabla okruženja `MYSQL_ROOT_PASSWORD`; naredbe u nastavku je koriste kako se lozinka ne bi pojavila u komandnoj liniji hosta.

## 2. Pregled scenarija

| Scenarij | Povod | Produkcija pogođena? | Odjeljak |
|---|---|---|---|
| A | Provjera pojedinačnih zapisa, mjesečno testno vraćanje | ne | 3 |
| B | Baza oštećena, neispravna migracija, slučajna masovna izmjena | da, prekid rada | 4 |
| C | Server izgubljen ili se više ne može pokrenuti | da, prekid rada | 5 |
| D | Vraćanje snapshota servera | da, prekid rada | 6 |

## 3. Scenarij A – istraživanje u bazi za vraćanje

Slučajevi upotrebe: restoran javlja da su podaci o kupcima ili postavke „jučer još bili drugačiji"; dokaz ranijeg stanja kartice; mjesečno testno vraćanje.

### 3.1 Izbor sigurnosne kopije

```bash
ls -lh backups/                                   # local (14 days)
rclone ls storagebox:giftcard-backups             # off-site
# fetch an older file from the Storage Box:
rclone copy storagebox:giftcard-backups/giftcard_pro_20261014T023001Z.sql.gz backups/
```

Vremenske oznake u nazivu datoteke su u UTC.

### 3.2 Uvoz u posebnu bazu

```bash
FILE=backups/giftcard_pro_20261014T023001Z.sql.gz

dc exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS giftcard_pro_restore; CREATE DATABASE giftcard_pro_restore CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"'
gunzip -c "$FILE" | dc exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" giftcard_pro_restore'
```

Produkcijska baza `giftcard_pro` ostaje netaknuta; rad se nastavlja.

### 3.3 Istraživanje

```bash
dc exec mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" giftcard_pro_restore'
```

Primjeri:

```sql
-- card state at backup time
SELECT card_number, status, balance, expires_at, updated_at
FROM gift_cards WHERE card_number = '5285105870986488';

-- customer record in backup vs. production
SELECT r.first_name, r.last_name, r.email, p.first_name, p.last_name, p.email
FROM giftcard_pro_restore.customers r
JOIN giftcard_pro.customers p ON p.id = r.id
WHERE r.id = '<customer-uuid>';

-- transactions of a card that are not in the backup yet
SELECT p.created_at, p.type, p.amount, p.balance_after
FROM giftcard_pro.gift_card_transactions p
LEFT JOIN giftcard_pro_restore.gift_card_transactions r ON r.id = p.id
WHERE p.gift_card_id = '<card-uuid>' AND r.id IS NULL
ORDER BY p.created_at;
```

### 3.4 Ispravka – samo kroz aplikaciju

| Nalaz | Ispravka |
|---|---|
| Pogrešno iskorištavanje ili dopuna | **Reverse** u Transactions odnosno `POST /transactions/{id}/reverse` |
| Stanje treba prebaciti na drugu karticu | **Transfer balance** |
| Podaci o kupcu slučajno prepisani | Pročitati vrijednosti iz baze za vraćanje i ponovo ih unijeti pod Customers → Edit |
| Postavke kartica restorana izmijenjene | Ponovo postaviti vrijednosti pod Settings → Gift cards |

Ne kopirajte redove iz baze za vraćanje u produkciju putem SQL-a. Direktne SQL izmjene zaobilaze ledger, zapisnik aktivnosti i zaključavanje redova.

### 3.5 Čišćenje

```bash
dc exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE giftcard_pro_restore"'
```

Dumpove koji su samo za istraživanje kopirani sa Storage Boxa (npr. iz sedmičnog ili mjesečnog direktorija) u `backups/` nakon toga obrišite – inače ih sljedeći `rclone sync` odražava u dnevni direktorij.

Kod mjesečnog testnog vraćanja prije brisanja izvršite kontrolne upite iz odjeljka 8 nad `giftcard_pro_restore` i dokumentujte rezultat.

## 4. Scenarij B – potpuno vraćanje baze

Povod: produkcijska baza je oštećena ili neupotrebljiva zbog greške, a sam server je ispravan.

**Posljedica:** sve izmjene između vremena dumpa i vraćanja se gube (do 24 sata, vidi odjeljak 7). Prethodno provjerite omogućavaju li binarni logovi precizniji oporavak (odjeljak 7.2).

### 4.1 Tok

1. **Dokumentujte odluku** (ko, zašto, koja sigurnosna kopija).
2. **Obavijestite restorane** (odjeljak 9) i postavite obavještenje o održavanju dok API još radi: administracija platforme → System settings → Maintenance notice.
3. **Zaustavite servise koji pišu:**

```bash
dc stop queue scheduler api
```

Web aplikacija zatim prikazuje greške pri API pozivima; Caddy i `web` nastavljaju raditi.

4. **Sačuvajte trenutno stanje** (i ako je oštećeno):

```bash
dc --profile backup run --rm backup
```

5. **Provjerite čitljivost sigurnosne kopije** i po izboru je najprije uvezite i provjerite kao scenarij A (preporučeno).
6. **Zamijenite bazu:**

```bash
FILE=backups/giftcard_pro_20261014T023001Z.sql.gz
gzip -t "$FILE"

dc exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE giftcard_pro; CREATE DATABASE giftcard_pro CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"'
gunzip -c "$FILE" | dc exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" giftcard_pro'
```

Dozvole korisnika `giftcard` odnose se na naziv baze i ostaju sačuvane.

7. **Kontrolni upiti** iz odjeljka 8.
8. **Pokrenite servise:**

```bash
dc up -d api
dc ps                                   # wait for api "healthy"
dc up -d queue scheduler web caddy
curl -fsS https://app.giftcardpro.at/up
```

Kontejner `api` pri pokretanju izvršava `migrate --isolated`. Ako je dump iz starije verzije, migracije dovode shemu na aktuelno stanje.

9. **Sesije:** sesije su u Redisu i mogu upućivati na podatke kojih nakon vraćanja više nema. Preporuka: odjaviti sve.

```bash
dc exec redis redis-cli -a "$(grep '^REDIS_PASSWORD=' .env.production | cut -d= -f2-)" --no-auth-warning FLUSHALL
dc exec api php artisan queue:restart
```

`FLUSHALL` prazni i red čekanja i keš (posljedice: vidi [Uputstvo za sigurnosne kopije](backup-guide.md#31-redis--šta-znači-gubitak)). Redis lozinka čita se iz `.env.production`, jer je Redis kontejner poznaje samo kao parametar pokretanja.

10. **Naknadni rad prema GDPR-u:** ponovite anonimizacije kupaca izvršene nakon vremena dumpa (lista iz zapisnika aktivnosti sačuvanog oštećenog stanja ili iz zahtjeva restorana).
11. **Uklonite obavještenje o održavanju** i obavijestite restorane.

## 5. Scenarij C – potpuni gubitak servera

Povod: server obrisan, kompromitovan ili se više ne može pokrenuti, nema upotrebljivog snapshota.

> Automatske Hetzner sigurnosne kopije pripadaju serveru. Ako se server obriše, one u pravilu više nisu dostupne – zato je off-site kopija na Storage Boxu mjerodavan izvor. Kod **kompromitovanog** servera ne koristite snapshot tog servera i rotirajte sve tajne podatke (odjeljak 5.4).

### 5.1 Preduslovi

- Pristup Hetzner Cloud Console, DNS-u, GitHubu i Storage Boxu
- Menadžer lozinki sa: sadržajem `.env.production` i `backend/.env.production` (posebno `APP_KEY`, NTAG 424 ključevi), `rclone` pristupom Storage Boxu (i po potrebi `crypt` lozinkom)
- SHA odnosno tag posljednjeg pokrenutog izdanja (GitHub Actions → posljednje uspješno pokretanje `Deploy`)

### 5.2 Izgradnja novog servera

1. Kreirajte server, učvrstite ga i instalirajte Docker prema [Uputstvu za deployment](deployment-guide.md), odjeljci 2 i 3.
2. Klonirajte repozitorij i postavite ga na posljednje pokrenuto izdanje:

```bash
cd /opt/giftcard-pro
git clone git@github.com:your-org/giftcard-pro.git .
git checkout <release-sha>
```

3. Vratite `.env.production` i `backend/.env.production` iz menadžera lozinki. U `.env.production` postavite `IMAGE_TAG=<release-sha>`.
4. DNS: preusmjerite A/AAAA zapise na novu IP adresu (TTL određuje koliko brzo promjena djeluje).

### 5.3 Vraćanje podataka

```bash
sudo apt -y install rclone && rclone config            # remote "storagebox" as before
mkdir -p backups
rclone copy storagebox:giftcard-backups backups/ --max-age 48h
ls -lh backups/

docker login ghcr.io
dc up -d mysql redis                                   # creates empty database and user
dc ps                                                  # wait for mysql "healthy"

FILE=$(ls -t backups/giftcard_pro_*.sql.gz | head -1)
gzip -t "$FILE"
gunzip -c "$FILE" | dc exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" giftcard_pro'
```

Izvršite kontrolne upite iz odjeljka 8, zatim pokrenite sve servise:

```bash
dc up -d
dc ps
curl -fsS https://app.giftcardpro.at/up
dc exec scheduler php artisan schedule:list
```

Caddy pri prvom HTTPS pozivu ponovo izdaje TLS certifikat. Let's Encrypt ograničava broj identičnih certifikata sedmično – izbjegavajte ponovljene reinstalacije u kratkom roku.

Zatim: ponovo postavite cron poslove za sigurnosnu kopiju i off-site sinhronizaciju ([Uputstvo za sigurnosne kopije](backup-guide.md)), aktivirajte Hetzner Backups i firewall, ažurirajte GitHub secrete `DEPLOY_HOST` i `DEPLOY_HOST_FINGERPRINT` za novi server.

### 5.4 Dodatno kod kompromitovanja

- Ponovo generišite `DB_PASSWORD`, `DB_ROOT_PASSWORD`, `REDIS_PASSWORD`, `MAIL_PASSWORD`, deploy SSH ključ i `GHCR_READ_TOKEN`.
- Ponovo generišite `APP_KEY`: sve sesije postaju nevažeće (namjerno).
- Sve API tokene restorana smatrajte kompromitovanim: obavijestite restorane, opozovite tokene i neka kreiraju nove.
- NTAG 424 ključevi: promjena čini već programirane NTAG 424 DNA kartice neprovjerljivim. Odluka zajedno s pogođenim restoranima; po potrebi zamjena kartica.
- Provjerite obaveze prijave prema GDPR-u (odjeljak 9.3).

## 6. Scenarij D – vraćanje snapshota servera

Ako server još postoji i postoji Hetzner backup odnosno snapshot, to je najbrži put: Hetzner Cloud Console → Server → Backups/Snapshots → **Rebuild** odnosno **Restore**.

- Server se u potpunosti vraća na stanje snapshota (baza, Redis, `.env`, certifikati).
- Gubitak podataka: sve od vremena snapshota. Ako postoji noviji logički dump (npr. 02:30 tekućeg dana, a snapshot od prethodnog dana), nakon toga dodatno izvršite scenarij B s novijim dumpom.
- Nakon pokretanja izvršite kontrolne upite iz odjeljka 8 – snapshot je samo konzistentan kao nakon pada sistema; InnoDB pri pokretanju izvršava oporavak.

## 7. Ograničenja point-in-time vraćanja i poboljšanja

### 7.1 Trenutno stanje

- Dnevni dumpovi u 02:30 → **RPO do 24 sata**. Oštećenje u 21:00 bez dodatnih mjera znači gubitak svih knjiženja od 02:30.
- Dumpovi ne sadrže poziciju binarnog loga (`backup.sh` ne koristi `--source-data`).

### 7.2 Korištenje binarnih logova kada je server ispravan

MySQL 8.4 standardno piše binarne logove u direktorij podataka (volumen `mysql_data`). Provjera:

```sql
SHOW VARIABLES LIKE 'log_bin';
SHOW VARIABLES LIKE 'binlog_expire_logs_seconds';
SHOW BINARY LOGS;
```

Ako binarni logovi postoje, nakon uvoza dumpa mogu se ponovo primijeniti izmjene do trenutka neposredno prije greške (samo uz iskustvo u administraciji MySQL-a i najprije u bazi za vraćanje):

```bash
dc exec mysql sh -c 'mysqlbinlog --start-datetime="2026-10-14 02:30:00" --stop-datetime="2026-10-14 20:59:00" /var/lib/mysql/binlog.0000* > /tmp/replay.sql'
```

Pošto dump ne sadrži tačnu poziciju binloga, početno vrijeme se može odrediti samo približno; dvostruka knjiženja doduše odbija jedinstveni `idempotency_key` u ledgeru, ali rezultat ipak pažljivo provjerite kontrolnim upitima. Vremena u `mysqlbinlog` odnose se na vremensku zonu MySQL kontejnera (UTC).

Kod potpunog gubitka servera binarni logovi nestaju zajedno s volumenom.

### 7.3 Preporučena poboljšanja (plan za rad sistema)

| Mjera | Efekat |
|---|---|
| `--source-data=2` u `backup.sh` (zahtijeva dodatna MySQL prava za korisnika sigurnosne kopije) | tačna pozicija binloga u dumpu |
| Kontinuirano kopiranje binarnih logova off-site (npr. `mysqlbinlog --read-from-remote-server --raw --stop-never` u posebnom servisu ili `rclone copy` svakih 5 minuta) | RPO od nekoliko minuta i kod potpunog gubitka |
| Alternativno: managed MySQL s point-in-time recovery | RPO u minutama bez vlastitog održavanja |
| Drugi server kao replika (standby) | kratak RTO kod ispada servera |

## 8. Kontrolni upiti nakon vraćanja

Izvršite ih nad vraćenom bazom (`giftcard_pro` ili `giftcard_pro_restore`).

**1. Konzistentnost ledgera – zbir knjiženja = stanje po kartici (obavezno, rezultat mora biti prazan):**

```sql
SELECT g.id, g.card_number, g.balance, COALESCE(SUM(t.amount), 0) AS ledger_sum
FROM gift_cards g
LEFT JOIN gift_card_transactions t ON t.gift_card_id = g.id
GROUP BY g.id, g.card_number, g.balance
HAVING g.balance <> COALESCE(SUM(t.amount), 0);
```

**2. Posljednje knjiženje svake kartice odgovara stanju (rezultat mora biti prazan):**

```sql
SELECT g.id, g.card_number, g.balance, t.balance_after
FROM gift_cards g
JOIN gift_card_transactions t ON t.id = (
  SELECT t2.id FROM gift_card_transactions t2
  WHERE t2.gift_card_id = g.id
  ORDER BY t2.created_at DESC, t2.id DESC LIMIT 1)
WHERE t.balance_after <> g.balance;
```

**3. Vrijeme stanja podataka:**

```sql
SELECT MAX(created_at) AS last_transaction FROM gift_card_transactions;
SELECT MAX(created_at) AS last_audit FROM audit_logs;
SELECT MAX(created_at) AS last_scan FROM nfc_scans;
```

**4. Otvorena obaveza po restoranu** (uporediti s vrijednošću „Outstanding balance" na dashboardu i s podacima restorana):

```sql
SELECT r.name, COUNT(*) AS cards, SUM(g.balance) / 100 AS outstanding_eur
FROM gift_cards g JOIN restaurants r ON r.id = g.restaurant_id
WHERE g.status IN ('active', 'inactive', 'blocked') AND g.deleted_at IS NULL
GROUP BY r.name ORDER BY r.name;
```

**5. Obim podataka** (poređenje s prethodnim danom odnosno posljednjim testnim vraćanjem):

```sql
SELECT (SELECT COUNT(*) FROM restaurants) AS restaurants,
       (SELECT COUNT(*) FROM users) AS users,
       (SELECT COUNT(*) FROM gift_cards) AS cards,
       (SELECT COUNT(*) FROM gift_card_transactions) AS transactions,
       (SELECT COUNT(*) FROM audit_logs) AS audit_entries;
```

**6. Shema i aplikacija:**

```bash
dc exec api php artisan migrate:status
curl -fsS https://app.giftcardpro.at/up
```

**7. Funkcionalna provjera:** prijava, otvaranje kartice, testno iskorištavanje od 0,01 € na internoj testnoj kartici i storno (vidi [Uputstvo za deployment](deployment-guide.md#8-provjere-nakon-deploymenta)).

Ako upit 1 ili 2 odstupa: vraćanje **ne** odobravajte, bazu ne puštajte u rad, provjerite stariji dump i uključite razvojni tim.

## 9. Komunikacija s restoranima

### 9.1 Principi

- Obavijestite rano, i kada još nije sve jasno. Kratke, činjenične rečenice.
- Navedite konkretan **period** čiji su podaci pogođeni (po bečkom vremenu).
- Jasno recite **šta restoran mora uraditi** – i šta ne.
- Kanali: obavještenje o održavanju u aplikaciji (**Maintenance notice**), e-mail svim vlasnicima i vlasnicama, za Pro i Gruppe klijente dodatno telefonom.

### 9.2 Predložak: ispad s gubitkom podataka

> **Predmet:** GiftCard Pro – vraćanje podataka [datum], molimo provjerite knjiženja od [vrijeme] do [vrijeme]
>
> Poštovani,
>
> dana [datum] GiftCard Pro nije bio dostupan od [vrijeme] do [vrijeme]. Uzrok: [kratak, činjeničan opis]. Podatke smo vratili iz sigurnosne kopije od [datum, vrijeme].
>
> **Šta to znači za Vas:** knjiženja evidentirana u GiftCard Pro između [vrijeme sigurnosne kopije] i [vrijeme ispada] (prodaje, iskorištavanja, dopune) više nisu sadržana.
>
> **Molimo postupite ovako:**
> 1. Otvorite **Transactions** i filtrirajte na [datum].
> 2. Uporedite listu s knjiženjima poklon kartica u Vašoj fiskalnoj kasi za isti period.
> 3. Nedostajuća iskorištavanja evidentirajte na odgovarajućoj kartici pomoću **Redeem** s napomenom „Naknadni unos [datum]" u polju Reference. Nedostajuće prodaje ponovo kreirajte kao **New gift card** – molimo prethodno nas kontaktirajte kako bi već upisana NFC kartica nastavila raditi.
>
> Svi ostali podaci – kartice, stanja, kupci, postavke – su potpuni. Vaši gosti mogu i dalje bez ograničenja koristiti kartice.
>
> Za pitanja smo Vam na raspolaganju na support@giftcardpro.at ili [telefon].
>
> Izvinjavamo se zbog neugodnosti.
>
> [Ime], GiftCard Pro

Napomena: kartica prodata u izgubljenom periodu nakon vraćanja više ne postoji; njen token na NFC čipu je nepoznat. Takve kartice se uz pomoć podrške ponovo izdaju i ponovo upisuju odnosno zamjenjuju.

### 9.3 Povreda zaštite podataka

Ako je vraćanje posljedica sigurnosnog incidenta (npr. neovlašten pristup), dodatno važi:

- GiftCard Pro je za podatke gostiju izvršitelj obrade i mora restorane kao voditelje obrade obavijestiti **bez nepotrebnog odlaganja** (čl. 33 st. 2 GDPR).
- Restorani provjeravaju prijavu austrijskom tijelu za zaštitu podataka (Österreichische Datenschutzbehörde) u roku od 72 sata (čl. 33 st. 1 GDPR).
- Za vlastite podatke klijenata (naloge restorana) GiftCard Pro je sam voditelj obrade.
- Nije pravni savjet – provjeriti s advokatom.

---

Verzija 1.0 · Stanje: septembar 2026.
