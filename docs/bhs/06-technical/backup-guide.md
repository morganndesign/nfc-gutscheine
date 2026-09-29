# Uputstvo za sigurnosne kopije

*Šta se kod GiftCard Pro kopira, a šta ne, kako kopiranje radi u Coolify stacku, kako se šifruje, provjerava i nadzire, i koje se čuvanje preporučuje. Referenca na engleskom: [docs/DEPLOYMENT.md → Backups](../../DEPLOYMENT.md#backups).*

---

## 1. Pregled

Baza podataka je jedini sistem čiji gubitak nije nadoknadiv: sadrži ledger (svako knjiženje svakog vaučera), plaćanja, statuse vaučera, hashove QR kodova, podatke o kupcima i zapisnik aktivnosti. Sve ostalo može se ponovo izgraditi iz Gita (Coolify gradi svaki image iz izvornog koda) ili menadžera lozinki.

| Nivo | Šta | Kada | Čuvanje | Mjesto |
|---|---|---|---|---|
| 1 | Logički MySQL dump (`mysqldump`, gzip) u servisu `backup` | dnevno u `BACKUP_TIME` (UTC, standard 01:30) | `BACKUP_KEEP_DAYS` (standard 14 dana) | Docker volumen `mysql-backups` na serveru |
| 2 | Off-site kopija dumpova (`rclone sync`, root cron na serveru) | dnevno, nakon nivoa 1 | odražava nivo 1 (vidi odjeljak 7) | npr. Hetzner Storage Box |
| 3 | Snapshot servera (Hetzner Backups) | dnevno, vremenski prozor određuje Hetzner | Hetzner rotira (do 7 kopija) | Hetzner Cloud |

Svi podaci ostaju u Hetznerovim data centrima u Njemačkoj (EU).

## 2. Šta se kopira

### 2.1 Dump baze podataka

Servis `backup` u `docker-compose.coolify.yml` (image `mysql:8.4`) čeka do `BACKUP_TIME` (UTC) i zatim upisuje:

```sh
mysqldump -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --quick --routines --triggers --no-tablespaces "$MYSQL_DATABASE" \
  | gzip -9 > /backups/giftcard_pro_<UTC timestamp>.sql.gz
find /backups -name 'giftcard_pro_*.sql.gz' -mtime +"$BACKUP_KEEP_DAYS" -delete
```

| Svojstvo | Vrijednost |
|---|---|
| Naziv datoteke | `giftcard_pro_<YYYYMMDD>T<HHMMSS>Z.sql.gz` (vremenska oznaka u UTC) |
| Konzistentnost | `--single-transaction`: konzistentno stanje svih InnoDB tabela bez zaključavanja – rad se nastavlja |
| Obim | cijela baza uključujući rutine i **append-only okidače** (`--triggers`) |
| Način upisa | prvo `.part`, preimenuje se tek nakon uspjeha; greška upisuje „Backup FAILED“ u log servisa |
| Lokalno čuvanje | datoteke starije od `BACKUP_KEEP_DAYS` brišu se pri sljedećem pokretanju |

Time su obuhvaćene sve tabele: `restaurants`, `restaurant_settings`, `system_settings`, `roles`, `permissions`, `permission_role`, `users`, `password_reset_tokens`, `invitation_tokens`, `sessions`, `devices`, `personal_access_tokens`, `customers`, `vouchers`, `media`, `presentments`, `payments`, `voucher_transactions` (ledger), `chain_heads`, `audit_logs`, `notification_templates`, `notification_logs`, `cache`, `cache_locks`, `job_batches`, `failed_jobs`. Ledger, plaćanja i zapisnik aktivnosti kopiraju se sa svojim hash lancima; nakon svakog vraćanja `php artisan giftcard:verify-chains` potvrđuje da su potpuni i nepromijenjeni.

### 2.2 Trenutna sigurnosna kopija

Prije zahvata: Coolify → *Terminal* → kontejner **backup** →

```bash
mysqldump -h mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers --no-tablespaces "$MYSQL_DATABASE" | gzip > /backups/manual_$(date -u +%Y%m%dT%H%M%SZ).sql.gz
ls -lh /backups
```

### 2.3 Postavljanje off-site kopije

Volumen se nalazi na istom disku kao baza. Na serveru (kao root):

```bash
docker volume ls | grep mysql-backups          # full volume name
apt -y install rclone
rclone config                                  # new remote "storagebox", type sftp, host <user>.your-storagebox.de, port 23, SSH key
rclone lsd storagebox:                         # test the connection
```

```cron
# crontab -e (root) — after BACKUP_TIME (UTC; Hetzner images run in UTC)
0 3 * * * rclone sync /var/lib/docker/volumes/<name>/_data storagebox:giftcard-backups
```

### 2.4 Snapshoti servera

U Hetzner Cloud Consoleu aktivirajte **Backups**. Hetzner dnevno pravi sliku cijelog diska (uključujući Docker volumene, Redis AOF, `laravel-storage` s generisanim `APP_KEY` i lokalne dumpove). Prije većih zahvata (major nadogradnja, ažuriranje operativnog sistema) dodatno napravite ručni **snapshot**.

Snapshoti su konzistentni kao nakon pada sistema, ne transakcijski konzistentni: za bazu je logički dump mjerodavan izvor, a snapshot rezervna opcija za cijeli server.

## 3. Šta se ne kopira

| Dio | Kopira se? | Posljedica gubitka | Mjera |
|---|---|---|---|
| **Redis** (sesije, keš, redovi čekanja, brojači rate limita, zaključavanja) | Samo u snapshotu servera (AOF), ne u dumpu | Vidi 3.1 | Namjerno; posebna kopija nije potrebna |
| Environment Variables Coolify resursa (tajni podaci) | U Coolifyju; samo u snapshotu servera | Bez `APP_KEY` svi se odjavljuju i šifrovane vrijednosti postaju nečitljive | `APP_KEY` i SMTP pristupne podatke **voditi u menadžeru lozinki** – obavezno |
| Docker imageovi | ne – Coolify ih gradi iz Gita | nema | nema |
| Izvorni kod, Caddyfile, Compose datoteka | u Gitu | nema | nema |
| Logovi kontejnera | ne (rotacija 10 MB × 5) | Nedostaju istorijski logovi | po potrebi slanje logova, vidi [Vodič za logovanje](logging-guide.md) |

Ključevi kartica nisu dio aplikacije niti njenih kopija: ključevi za NTAG 424 DNA kartice nalaze se u hardverskom sigurnosnom modulu iza kripto servisa ([docs/NFC.md](../../NFC.md)).

### 3.1 Redis – šta znači gubitak

Redis sadrži samo prolazne podatke. Ako se Redis izgubi (npr. vraćanje na novi server bez snapshota):

| Sadržaj Redisa | Posljedica | Procjena |
|---|---|---|
| Sesije | Sve osobe u pretraživaču se odjavljuju i ponovo prijavljuju. Uređaji i tokeni aplikacije za konobare ostaju važeći (tabele `devices`, `personal_access_tokens`). | bezopasno, jednokratan napor za osoblje |
| Red čekanja (`default`, `notifications`) | E-mailovi koji još nisu poslani (kupovina, dopuna, podsjetnik o isteku, pozivnice, linkovi za lozinku) se gube. Knjiženja nisu pogođena – e-mailovi se stavljaju u red tek nakon commita knjiženja. | malo; pozivnice ponovo poslati s **Invite again** |
| Keš | Automatski se ponovo gradi (dozvole, sistemske postavke). | nema |
| Brojači rate limita, brojači neuspjelih predočenja | Brojači počinju od 0. Samo zaključavanje naloga (`locked_until`) nalazi se u bazi. | nema |
| Predočenja (presentments) | nalaze se u bazi, ne u Redisu; ionako ističu nakon 60 s | nema |
| Zaključavanja (zaključavanje migracija, `withoutOverlapping`) | ponovo se postavljaju | nema |

Konfiguracija `--appendonly yes` i `--maxmemory-policy noeviction` štiti redove čekanja i sesije pri normalnim ponovnim pokretanjima.

## 4. Šifrovanje

Dumpovi su komprimovani gzipom, ali **nisu šifrovani**. Sadrže lične podatke (imena, e-mail adrese, brojeve telefona kupaca, imena primalaca, IP adrese u zapisniku aktivnosti) te hashove lozinki, tokena i QR tajni (same tajne se nikada ne pohranjuju).

Preporuke:

1. **Off-site pohrana u šifrovanom obliku:** u `rclone` kreirajte remote tipa `crypt` iznad remotea Storage Boxa (npr. `storagebox-crypt:`) i koristite ga u cronu umjesto `storagebox:giftcard-backups`. Lozinku i salt `crypt` remotea sačuvajte u menadžeru lozinki – bez njih vraćanje nije moguće.
2. **Alternativa:** dumpove prije sinhronizacije asimetrično šifrujte s `age` ili `gpg`; privatni ključ nije na serveru.
3. **Prenos:** Storage Boxu pristupajte samo preko SFTP/SSH (port 23) s ključem, a Samba/FTP deaktivirajte u upravljanju Storage Boxom.
4. **Pristup:** direktorij volumena pod `/var/lib/docker/volumes/` čitljiv je samo za root; SSH pristup serveru ograničite na malo osoba.
5. **Disk servera:** referentna instalacija ne šifruje disk servera vlastitim ključem; zaštita se zasniva na kontroli pristupa (SSH ključevi, firewall) i data centru. Za dumpove koji napuštaju server zato važi tačka 1.

## 5. Provjera sigurnosnih kopija

### 5.1 Dnevno (može se automatizovati)

Coolify → *Logs* → servis **backup**: posljednji red glasi „Backup written: /backups/giftcard_pro_…sql.gz“. U kontejneru **backup**:

```bash
ls -lh /backups | tail -n 3                                 # newest file from today?
gzip -t /backups/$(ls -t /backups | head -1) && echo OK
```

Na serveru: `rclone ls storagebox:giftcard-backups | tail -n 3` (postoji li off-site?).

Uvjerljivost: veličina dumpa polako raste (ledger se nikada ne smanjuje). Dump znatno manji od onog od prethodnog dana je znak za uzbunu.

### 5.2 Mjesečno – testno vraćanje

Sigurnosna kopija se smatra ispravnom tek kada je vraćena. Jednom mjesečno je uvezite u posebnu bazu i provjerite – postupak opisuje [Uputstvo za vraćanje podataka](restore-guide.md), scenarij A. Dokumentujte rezultat (datum, datoteka, trajanje, rezultat kontrolnih upita).

## 6. Nadzor poslova kopiranja

| Provjera | Metoda | Uzbuna ako |
|---|---|---|
| Dump kreiran | Starost najnovije datoteke u `/backups`; log servisa `backup` | starija od 26 sati ili „Backup FAILED“ |
| Dump čitljiv | `gzip -t` | greška |
| Off-site sinhronizacija | izlazni kod `rclone`, broj datoteka na Storage Boxu | izlazni kod ≠ 0 ili nedostaje najnovija datoteka |
| Prostor na disku | `df -h /var/lib/docker` | zauzeto preko 80 % |
| Snapshoti servera | Hetzner Cloud Console | posljednja kopija starija od 26 sati |

Preporuka: cron red dopunite „dead man's switchom“ (heartbeat servis koji se poziva samo pri uspjehu i uzbunjuje kada signal izostane):

```cron
0 3 * * * rclone sync /var/lib/docker/volumes/<name>/_data storagebox:giftcard-backups && curl -fsS -m 10 [heartbeat-url-offsite] >/dev/null
```

## 7. Čuvanje

### 7.1 Trenutno stanje

- Lokalno: `BACKUP_KEEP_DAYS` (standard 14 dana).
- Off-site: `rclone sync` **odražava** volumen – datoteke obrisane lokalno brišu se i na Storage Boxu. Off-site se tako također čuva oko 14 dana.
- Snapshoti servera: rotacija od strane Hetznera.

Greška primijećena tek nakon više od 14 dana (npr. pogrešna masovna izmjena matičnih podataka) ne može se s trenutnim stanjem rekonstruisati iz kopije. Ledger, plaćanja i zapisnik aktivnosti su nepromjenjivi; matični podaci (kupci, postavke) nisu.

### 7.2 Preporuka: djed-otac-sin off-site

| Nivo | Broj | Izvor |
|---|---|---|
| dnevno | 14 | dump dana |
| sedmično | 8 | dump od nedjelje |
| mjesečno | 12 | dump od 1. u mjesecu |

Varijante provedbe (preporuka, nije dio repozitorija):

- **Snapshoti Storage Boxa:** u Hetznerovom upravljanju aktivirajte automatske snapshote Storage Boxa s odgovarajućom rotacijom.
- **Odvojeni direktoriji s `rclone copy`:** pored `sync` posla, sedmični i mjesečni posao koji najnoviji dump kopira u `giftcard-backups-weekly/` odnosno `giftcard-backups-monthly/`, uz čišćenje s `rclone delete --min-age`:

```cron
0 4 * * 0  D=/var/lib/docker/volumes/<name>/_data; rclone copy "$D/$(ls -t $D | head -1)" storagebox:giftcard-backups-weekly && rclone delete --min-age 56d storagebox:giftcard-backups-weekly
0 4 1 * *  D=/var/lib/docker/volumes/<name>/_data; rclone copy "$D/$(ls -t $D | head -1)" storagebox:giftcard-backups-monthly && rclone delete --min-age 365d storagebox:giftcard-backups-monthly
```

(U crontab redovima `%` mora biti maskiran; gornji redovi ga ne sadrže.)

### 7.3 Čuvanje i GDPR

- Obaveza čuvanja poslovnih knjiga i evidencija (austrijski BAO § 132, 7 godina) ispunjava se **ledgerom u aktivnoj bazi**, ne sigurnosnim kopijama. Sigurnosne kopije služe za vraćanje podataka.
- Anonimizirani podaci kupaca (brisanje prema GDPR-u) ostaju u starijim kopijama do njihove rotacije. Uz čuvanje od 12 mjeseci taj rok iznosi najviše 12 mjeseci; navesti u informaciji o zaštiti podataka i u evidenciji aktivnosti obrade. Nakon vraćanja podataka anonimizacije izvršene u međuvremenu moraju se ponoviti (vidi [Uputstvo za vraćanje podataka](restore-guide.md)).
- Nije pravni savjet – provjeriti s poreznim savjetnikom/advokatom.

## 8. Ciljevi oporavka

| Pokazatelj | Trenutno stanje | Značenje |
|---|---|---|
| RPO (maksimalan gubitak podataka) | do 24 sata | Dnevni dumpovi; knjiženja od posljednjeg dumpa gube se kod potpunog gubitka bez snapshota |
| RTO (vrijeme oporavka) | Procjena: 1–2 sata za novi server + vraćanje | zavisi od veličine baze i pripreme |

Poboljšanja (binarni log / point-in-time recovery) opisuje [Uputstvo za vraćanje podataka](restore-guide.md#7-ograničenja-point-in-time-vraćanja-i-poboljšanja).

---

Verzija 2.0 · Stanje: septembar 2026.
