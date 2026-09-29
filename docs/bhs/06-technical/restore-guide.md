# Uputstvo za vraćanje podataka

*Vraćanje GiftCard Pro korak po korak u Coolify stacku: istraživanje pojedinačnih zapisa, potpuno vraćanje baze, potpuni gubitak servera, ograničenja point-in-time vraćanja, kontrolni upiti i komunikacija s restoranima. Referenca na engleskom: [docs/DEPLOYMENT.md → Backups](../../DEPLOYMENT.md#backups).*

---

## 1. Osnovna pravila

1. **Produkcijski ledger se nikada ne prepisuje radi ispravke pojedinačnih grešaka.** Ledger, plaćanja i zapisnik aktivnosti su append-only (okidači u bazi) i povezani hash lancima. Pojedinačna pogrešna knjiženja ispravljaju se u aplikaciji protuknjiženjem (**Reverse**). Vraćanje cijele baze dozvoljeno je samo kod gubitka ili oštećenja baze.
2. **Prije svakog zahvata napravite aktuelnu sigurnosnu kopiju** – i od oštećenog stanja.
3. **Najprije uvezite u posebnu bazu za vraćanje i provjerite**, zatim odlučite.
4. Svako vraćanje se dokumentuje: vrijeme, korištena datoteka, razlog, odgovorna osoba, rezultat kontrolnih upita i `giftcard:verify-chains`.
5. Baze za vraćanje sadrže lične podatke – nakon završetka ih obrišite.

Sve naredbe se izvršavaju u Coolify *Terminal* resursa, u navedenom kontejneru: **backup** (ima MySQL klijent, dumpove pod `/backups` i root lozinku u `MYSQL_ROOT_PASSWORD`) ili **api** (Artisan). Naredbe koriste varijablu okruženja kako se lozinka ne bi pojavila u komandnoj liniji.

## 2. Pregled scenarija

| Scenarij | Povod | Produkcija pogođena? | Odjeljak |
|---|---|---|---|
| A | Provjera pojedinačnih zapisa, mjesečno testno vraćanje | ne | 3 |
| B | Baza oštećena, neispravna migracija, slučajna masovna izmjena | da, zastoj | 4 |
| C | Server izgubljen ili se više ne pokreće | da, zastoj | 5 |
| D | Vraćanje snapshota servera | da, zastoj | 6 |

## 3. Scenarij A – istraživanje u bazi za vraćanje

Slučajevi upotrebe: restoran javlja da su podaci kupaca ili postavke „juče bili drugačiji“; dokaz ranijeg stanja vaučera; mjesečno testno vraćanje.

### 3.1 Izbor sigurnosne kopije

U kontejneru **backup**:

```bash
ls -lh /backups                                   # local (BACKUP_KEEP_DAYS)
```

Starije datoteke su off-site; na serveru (kao root) ih vratite:

```bash
rclone ls storagebox:giftcard-backups
rclone copy storagebox:giftcard-backups/giftcard_pro_20261014T013001Z.sql.gz /var/lib/docker/volumes/<name>/_data/
```

Vremenske oznake u nazivu datoteke su u UTC.

### 3.2 Uvoz u posebnu bazu

U kontejneru **backup**:

```bash
FILE=/backups/giftcard_pro_20261014T013001Z.sql.gz
mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS restore_test; CREATE DATABASE restore_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
gunzip -c "$FILE" | mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" restore_test
```

Produkcijska baza ostaje netaknuta; rad se nastavlja.

### 3.3 Istraživanje

```bash
mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" restore_test
```

Primjeri:

```sql
-- voucher state at backup time (voucher_number is internal, staff and support only)
SELECT voucher_number, kind, status, balance, expires_at, updated_at
FROM vouchers WHERE voucher_number = '5285105870986488';

-- customer record in backup vs. production
SELECT r.first_name, r.last_name, r.email, p.first_name, p.last_name, p.email
FROM restore_test.customers r
JOIN giftcard_pro.customers p ON p.id = r.id
WHERE r.id = '<customer-uuid>';

-- ledger entries of a voucher that are not in the backup yet
SELECT p.created_at, p.type, p.amount, p.balance_after
FROM giftcard_pro.voucher_transactions p
LEFT JOIN restore_test.voucher_transactions r ON r.id = p.id
WHERE p.voucher_id = '<voucher-uuid>' AND r.id IS NULL
ORDER BY p.created_at;
```

### 3.4 Ispravka – samo kroz aplikaciju

| Nalaz | Ispravka |
|---|---|
| Pogrešno iskorištavanje ili dopuna | **Reverse** u Transactions odnosno `POST /transactions/{id}/reverse` (nova, suprotna stavka) |
| Vaučer greškom istekao | **Reinstate** (vlasnik ili vlasnica, s razlogom) |
| Podaci kupca greškom prepisani | Vrijednosti očitajte iz baze za vraćanje i ponovo unesite pod Customers → Edit |
| Promijenjena pravila vaučera restorana | Vrijednosti ponovo postavite pod Settings → Vouchers |

Ne kopirajte redove iz baze za vraćanje SQL-om u produkciju. Direktne SQL izmjene zaobilaze ledger, hash lance, zapisnik aktivnosti i zaključavanje redova; `UPDATE` i `DELETE` nad ledgerom, plaćanjima i zapisnikom aktivnosti okidači ionako odbijaju.

### 3.5 Čišćenje

```bash
mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE restore_test"
```

Dumpove koji su samo radi istraživanja kopirani sa Storage Boxa u volumen nakon toga obrišite – inače ih sljedeći `rclone sync` odražava u dnevni direktorij.

Kod mjesečnog testnog vraćanja prije brisanja izvršite kontrolne upite iz odjeljka 8 nad `restore_test` i dokumentujte rezultat.

## 4. Scenarij B – potpuno vraćanje baze

Povod: produkcijska baza je oštećena ili neupotrebljiva zbog greške, a sam server je ispravan.

**Posljedica:** sve izmjene između vremena dumpa i vraćanja se gube (do 24 sata, vidi odjeljak 7). Prethodno provjerite omogućavaju li binarni logovi preciznije vraćanje (odjeljak 7.2).

### 4.1 Tok

1. **Dokumentujte odluku** (ko, zašto, koja kopija).
2. **Obavijestite restorane** (odjeljak 9) i postavite obavještenje o održavanju dok API još radi: administracija platforme → System settings → Maintenance notice.
3. **Režim održavanja:** kontejner **api** → `php artisan down` (dashboard i aplikacija prikazuju održavanje).
4. **Sačuvajte trenutno stanje** (i kada je oštećeno) – kontejner **backup**:

```bash
mysqldump -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers --no-tablespaces "$MYSQL_DATABASE" | gzip > /backups/manual_$(date -u +%Y%m%dT%H%M%SZ).sql.gz
```

5. **Provjerite čitljivost kopije** i opcionalno je prvo uvezite i provjerite kao scenarij A (preporučeno).
6. **Zamjena baze** – kontejner **backup**:

```bash
FILE=/backups/giftcard_pro_20261014T013001Z.sql.gz
gzip -t "$FILE"
gunzip -c "$FILE" | mysql -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"
```

Dump za svaku tabelu sadrži `DROP TABLE IF EXISTS` i append-only okidače; dozvole korisnika aplikacije odnose se na naziv baze i ostaju sačuvane.

7. **Resurs → *Redeploy*** (vraća aplikaciju u rad; `php artisan up` tada nije potreban). Pri pokretanju prvi Laravel kontejner izvršava migracije na čekanju.
8. **Provjera integriteta** – kontejner **api**:

```bash
php artisan giftcard:verify-chains      # restored chains and balances must verify
```

Zatim izvršite kontrolne upite iz odjeljka 8.

9. **Sesije:** sesije se nalaze u Redisu i mogu upućivati na podatke kojih nakon vraćanja više nema. Preporuka: odjaviti sve – kontejner **redis** → `redis-cli -a "$REDIS_PASSWORD" --no-auth-warning FLUSHALL`, zatim kontejner **api** → `php artisan queue:restart`. `FLUSHALL` prazni i red čekanja i keš (posljedice: vidi [Uputstvo za sigurnosne kopije](backup-guide.md#31-redis--šta-znači-gubitak)).
10. **Naknadni rad prema GDPR-u:** anonimizacije kupaca izvršene nakon vremena dumpa ponovo izvršite (lista iz zapisnika aktivnosti sačuvanog oštećenog stanja ili iz zahtjeva restorana).
11. **Uklonite obavještenje o održavanju** i obavijestite restorane.

## 5. Scenarij C – potpuni gubitak servera

Povod: server obrisan, kompromitovan ili se više ne pokreće, bez upotrebljivog snapshota.

> Automatske Hetzner kopije pripadaju serveru. Ako se server obriše, one po pravilu više nisu dostupne – zato je off-site kopija na Storage Boxu mjerodavan izvor. Kod **kompromitovanog** servera ne koristite snapshot tog servera i rotirajte sve tajne podatke (odjeljak 5.4).

### 5.1 Preduslovi

- Pristup Hetzner Cloud Consoleu, DNS-u, GitHubu i Storage Boxu
- Menadžer lozinki s: `APP_KEY`, SMTP pristupnim podacima, `rclone` pristupom Storage Boxu (i eventualno `crypt` lozinkom)
- Commit posljednjeg deploymenta koji je radio (Coolify → *Deployments*, ili `main`)

### 5.2 Izgradnja novog servera

1. Postavite server s Coolifyjem prema [Uputstvu za deployment](deployment-guide.md), odjeljci 2 i 3: kreirajte resurs iz repozitorija, domenu gatewaya, a `APP_KEY` iz menadžera lozinki i vrijednosti `MAIL_*` postavite kao Environment Variables.
2. DNS: A/AAAA zapise preusmjerite na novu IP adresu (TTL određuje koliko brzo promjena djeluje).
3. *Deploy*. Laravel kontejneri kreiraju praznu šemu i referentne podatke.

### 5.3 Vraćanje podataka

Na serveru (kao root) preuzmite najnoviji dump u volumen `mysql-backups`:

```bash
apt -y install rclone && rclone config                 # remote "storagebox" as before
docker volume ls | grep mysql-backups
rclone copy storagebox:giftcard-backups /var/lib/docker/volumes/<name>/_data/ --max-age 48h
```

Zatim kao u scenariju B, koraci 3 i 6–9: `php artisan down`, uvoz dumpa u kontejneru **backup**, *Redeploy*, `php artisan giftcard:verify-chains`, kontrolni upiti iz odjeljka 8.

Coolify ponovo izdaje TLS certifikat. Let's Encrypt ograničava broj identičnih certifikata sedmično – izbjegavajte ponovljene nove instalacije u kratkom roku.

Nakon toga: ponovo postavite off-site sinhronizaciju ([Uputstvo za sigurnosne kopije](backup-guide.md)), aktivirajte Hetzner kopije i firewall, provjerite uptime monitor za novi server.

### 5.4 Dodatno kod kompromitovanja

- Ponovo generišite `SERVICE_PASSWORD_MYSQL`, `SERVICE_PASSWORD_MYSQLROOT`, `SERVICE_PASSWORD_REDIS` (novi server, nove vrijednosti), `MAIL_PASSWORD` i SSH ključeve; ponovo autorizujte vezu Coolifyja s GitHub aplikacijom.
- Ponovo generišite `APP_KEY`: sve sesije postaju nevažeće (namjerno).
- Sve API tokene restorana i sve tokene uređaja aplikacije za konobare smatrajte kompromitovanim: opozovite ih pod `/admin/api-tokens`, obavijestite restorane, neka ponovo kreiraju tokene za integracije; konobari se ponovo prijavljuju u aplikaciju.
- QR kodovi vaučera: server pohranjuje samo hashove; napadač s pristupom bazi iz njih ne može napraviti QR kod. Iskorištavanje ionako zahtijeva skeniranje od strane prijavljene osobe na registrovanom uređaju.
- Pokrenite `php artisan giftcard:verify-chains` nad vraćenim stanjem: izmijenjeno knjiženje vidi se kao prekinut lanac.
- Provjerite obaveze prijave prema GDPR-u (odjeljak 9.3).

## 6. Scenarij D – vraćanje snapshota servera

Ako server još postoji i postoji Hetzner kopija odnosno snapshot, to je najbrži put: Hetzner Cloud Console → server → Backups/Snapshots → **Rebuild** odnosno **Restore**.

- Server se u potpunosti vraća na stanje snapshota (Coolify, baza, Redis, volumeni, certifikati).
- Gubitak podataka: sve od trenutka snapshota. Ako postoji noviji logički dump (npr. 01:30 UTC tekućeg dana, snapshot od prethodnog dana), dodatno izvršite scenarij B s novijim dumpom.
- Nakon pokretanja izvršite `php artisan giftcard:verify-chains` i kontrolne upite iz odjeljka 8 – snapshot je konzistentan samo kao nakon pada; InnoDB pri pokretanju izvršava oporavak.

## 7. Ograničenja point-in-time vraćanja i poboljšanja

### 7.1 Trenutno stanje

- Dnevni dumpovi u `BACKUP_TIME` (standard 01:30 UTC) → **RPO do 24 sata**. Oštećenje u 21:00 bez dodatnih mjera znači gubitak svih knjiženja od posljednjeg dumpa.
- Dumpovi ne sadrže poziciju binarnog loga (servis `backup` ne koristi `--source-data`).

### 7.2 Korištenje binarnih logova kada je server ispravan

MySQL 8.4 standardno piše binarne logove u direktorij podataka (volumen `mysql-data`). Provjera:

```sql
SHOW VARIABLES LIKE 'log_bin';
SHOW VARIABLES LIKE 'binlog_expire_logs_seconds';
SHOW BINARY LOGS;
```

Ako binarni logovi postoje, nakon uvoza dumpa mogu se ponovo primijeniti izmjene do neposredno prije greške (samo uz iskustvo u administraciji MySQL-a i prvo u bazi za vraćanje; kontejner **mysql**):

```bash
mysqlbinlog --start-datetime="2026-10-14 01:30:00" --stop-datetime="2026-10-14 20:59:00" /var/lib/mysql/binlog.0000* > /tmp/replay.sql
```

Pošto dump ne sadrži tačnu poziciju binloga, početno vrijeme se može odrediti samo približno. Dvostruka knjiženja odbija jedinstveni `idempotency_key` u ledgeru, a svaku prazninu ili dupliranje u hash lancu javlja `php artisan giftcard:verify-chains`; rezultat ipak pažljivo kontrolišite kontrolnim upitima. Vremena u `mysqlbinlog` odnose se na vremensku zonu MySQL kontejnera (UTC).

Kod potpunog gubitka servera binarni logovi se gube zajedno s volumenom.

### 7.3 Preporučena poboljšanja (plan za rad sistema)

| Mjera | Efekat |
|---|---|
| `--source-data=2` u servisu `backup` | tačna pozicija binloga u dumpu |
| Kontinuirano kopiranje binarnih logova van servera (npr. `mysqlbinlog --read-from-remote-server --raw --stop-never` u posebnom servisu ili `rclone copy` svakih 5 minuta) | RPO od nekoliko minuta i kod potpunog gubitka |
| Alternativa: upravljani MySQL s point-in-time recovery | RPO u rasponu minuta bez vlastitog održavanja |
| Drugi server kao replika (standby) | kratak RTO kod ispada servera |

## 8. Kontrolni upiti nakon vraćanja

Izvršite nad vraćenom bazom (produkcijska baza ili `restore_test`).

**0. Hash lanci i stanja (obavezno, samo produkcijska baza):** kontejner **api** → `php artisan giftcard:verify-chains`. Ponovo izračunava svaki lanac ledgera, plaćanja i zapisnika aktivnosti te svako stanje; svako odstupanje je nalaz.

**1. Konzistentnost ledgera – zbir knjiženja = stanje po vaučeru (obavezno, rezultat mora biti prazan):**

```sql
SELECT v.id, v.voucher_number, v.balance, COALESCE(SUM(t.amount), 0) AS ledger_sum
FROM vouchers v
LEFT JOIN voucher_transactions t ON t.voucher_id = v.id
GROUP BY v.id, v.voucher_number, v.balance
HAVING v.balance <> COALESCE(SUM(t.amount), 0);
```

**2. Posljednje knjiženje svakog vaučera odgovara stanju (rezultat mora biti prazan):**

```sql
SELECT v.id, v.voucher_number, v.balance, t.balance_after
FROM vouchers v
JOIN voucher_transactions t ON t.id = (
  SELECT t2.id FROM voucher_transactions t2
  WHERE t2.voucher_id = v.id
  ORDER BY t2.created_at DESC, t2.id DESC LIMIT 1)
WHERE t.balance_after <> v.balance;
```

**3. Svaka prodaja i dopuna ima plaćanje, svako iskorištavanje skeniranje (rezultat mora biti prazan):**

```sql
SELECT id, type FROM voucher_transactions
WHERE (type IN ('issue', 'reload') AND payment_id IS NULL)
   OR (type = 'redemption' AND presentment_id IS NULL);
```

**4. Vrijeme stanja podataka:**

```sql
SELECT MAX(created_at) AS last_transaction FROM voucher_transactions;
SELECT MAX(created_at) AS last_payment FROM payments;
SELECT MAX(created_at) AS last_audit FROM audit_logs;
```

**5. Otvorena obaveza po restoranu** (uporediti s vrijednošću „Outstanding balance“ u dashboardu i s podacima restorana):

```sql
SELECT r.name, COUNT(*) AS vouchers, SUM(v.balance) / 100 AS outstanding_eur
FROM vouchers v JOIN restaurants r ON r.id = v.restaurant_id
WHERE v.balance > 0
GROUP BY r.name ORDER BY r.name;
```

**6. Obim podataka** (poređenje s prethodnim danom odnosno posljednjim testnim vraćanjem):

```sql
SELECT (SELECT COUNT(*) FROM restaurants) AS restaurants,
       (SELECT COUNT(*) FROM users) AS users,
       (SELECT COUNT(*) FROM vouchers) AS vouchers,
       (SELECT COUNT(*) FROM payments) AS payments,
       (SELECT COUNT(*) FROM voucher_transactions) AS transactions,
       (SELECT COUNT(*) FROM audit_logs) AS audit_entries;
```

**7. Šema i aplikacija:** kontejner **api** → `php artisan migrate:status`; `curl -fsS https://app.giftcardpro.at/up`.

**8. Funkcionalna provjera:** prijava, otvaranje vaučera, testno iskorištavanje od 0,01 € na internom testnom vaučeru i storno (vidi [Uputstvo za deployment](deployment-guide.md#8-provjere-nakon-deploymenta)).

Ako `giftcard:verify-chains` javi nalaz ili upit 1, 2 ili 3 odstupa: vraćanje **ne** odobravajte, bazu ne puštajte u rad, provjerite stariji dump i uključite razvoj.

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
> 2. Uporedite listu s knjiženjima vaučera u Vašoj fiskalnoj kasi za isti period.
> 3. **Nedostajuće prodaje:** odštampani QR kod vaučera prodatog u tom periodu više se ne prepoznaje. Vaučer ponovo prodajte pod **Vouchers → Sell voucher**, kao plaćanje evidentirajte prvobitno plaćanje (npr. kartični terminal s prvobitnim brojem potvrde) i gostu predajte novi list za štampu.
> 4. **Nedostajuća iskorištavanja ili dopune:** iskorištavanje uvijek zahtijeva sam vaučer. Pogođene vaučere blokirajte pomoću **Block** s napomenom „Naknadni unos [datum]“; kada gost ponovo predoči vaučer, deblokirajte ga i evidentirajte nedostajuće knjiženje s tom napomenom u polju Reference. Nedostajuće dopune evidentirajte pomoću **Reload** i prvobitnog plaćanja.
>
> Svi ostali podaci – vaučeri, stanja, kupci, postavke – su potpuni. Vaši gosti mogu i dalje bez ograničenja koristiti svoje vaučere.
>
> Za pitanja smo Vam na raspolaganju na support@giftcardpro.at ili [telefon].
>
> Izvinjavamo se zbog neugodnosti.
>
> [Ime], GiftCard Pro

### 9.3 Povreda zaštite podataka

Ako je vraćanje posljedica sigurnosnog incidenta (npr. neovlašten pristup), dodatno važi:

- GiftCard Pro je za podatke gostiju izvršitelj obrade i mora restorane kao voditelje obrade obavijestiti **bez nepotrebnog odlaganja** (čl. 33 st. 2 GDPR).
- Restorani provjeravaju prijavu austrijskom tijelu za zaštitu podataka (Österreichische Datenschutzbehörde) u roku od 72 sata (čl. 33 st. 1 GDPR).
- Za vlastite podatke klijenata (naloge restorana) GiftCard Pro je sam voditelj obrade.
- Nije pravni savjet – provjeriti s advokatom.

---

Verzija 2.0 · Stanje: septembar 2026.
