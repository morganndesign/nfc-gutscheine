# Uputstvo za sigurnosne kopije

*Šta se u GiftCard Pro sigurnosno kopira, a šta ne, kako se kopiranje postavlja, šifruje, provjerava i nadzire, te koje čuvanje se preporučuje.*

---

## 1. Pregled

Baza podataka je jedini sistem čiji gubitak nije nadoknadiv: sadrži ledger (svako knjiženje svake kartice), statuse kartica, podatke o kupcima i zapisnik aktivnosti. Sve ostalo može se ponovo izgraditi iz Gita, container registryja ili menadžera lozinki.

| Nivo | Šta | Kada | Čuvanje | Mjesto |
|---|---|---|---|---|
| 1 | Logički MySQL dump (`mysqldump`, gzip) | dnevno 02:30 | 14 dana | Server: `/opt/giftcard-pro/backups/` |
| 2 | Off-site kopija dumpova (`rclone sync`) | dnevno 02:45 | odražava nivo 1 (vidi odjeljak 7) | Hetzner Storage Box |
| 3 | Snapshot servera (Hetzner Backups) | dnevno, vremenski prozor određuje Hetzner | Hetzner rotira (do 7 kopija) | Hetzner Cloud |

Svi podaci ostaju u Hetznerovim data centrima u Njemačkoj (EU).

## 2. Šta se kopira

### 2.1 Dump baze podataka

`infra/scripts/backup.sh` radi u Compose servisu `backup` (image `mysql:8.4`, profil `backup`) i koristi pristupne podatke iz `backend/.env.production`:

```sh
mysqldump --single-transaction --quick --routines --triggers \
  -h "${DB_HOST}" -u "${DB_USERNAME}" -p"${DB_PASSWORD}" "${DB_DATABASE}" | gzip -9 > "${FILE}"
find /backups -name 'giftcard_pro_*.sql.gz' -mtime +14 -delete
```

| Svojstvo | Vrijednost |
|---|---|
| Naziv datoteke | `giftcard_pro_<YYYYMMDD>T<HHMMSS>Z.sql.gz` (vremenska oznaka u UTC) |
| Konzistentnost | `--single-transaction`: konzistentno stanje svih InnoDB tabela bez zaključavanja – rad se nastavlja |
| Obim | cijela baza `giftcard_pro` uključujući rutine i okidače |
| Lokalno čuvanje | Datoteke starije od 14 dana brišu se pri sljedećem pokretanju |

Time su obuhvaćene sve tabele: `restaurants`, `restaurant_settings`, `users`, `roles`/`permissions`, `personal_access_tokens`, `devices`, `customers`, `gift_cards`, `gift_card_transactions` (ledger), `nfc_scans`, `audit_logs`, `notification_templates`, `notification_logs`, `system_settings`, `sessions`, `password_reset_tokens`, `failed_jobs`, `cache`, `cache_locks`, `job_batches`.

### 2.2 Postavljanje (cron korisnika `deploy`)

```cron
# crontab -e (deploy user)
30 2 * * * cd /opt/giftcard-pro && docker compose --env-file .env.production --profile backup run --rm backup >> /var/log/giftcard-backup.log 2>&1
45 2 * * * rclone sync /opt/giftcard-pro/backups storagebox:giftcard-backups
```

Priprema:

```bash
sudo touch /var/log/giftcard-backup.log && sudo chown deploy: /var/log/giftcard-backup.log
sudo apt -y install rclone
rclone config          # new remote "storagebox", type sftp, host <user>.your-storagebox.de, port 23, SSH key
rclone lsd storagebox:  # test the connection
```

> **Vremenska zona:** Cron koristi vremensku zonu servera. Hetzner imagei standardno rade u UTC – 02:30 UTC odgovara 03:30 (zimsko vrijeme) odnosno 04:30 (ljetno vrijeme) u Beču. Oboje je van radnog vremena. Ako želite vremena po bečkom vremenu: `sudo timedatectl set-timezone Europe/Vienna`. Poslovi aplikacije ne zavise od toga (`SCHEDULE_TIMEZONE`).

Trenutna sigurnosna kopija, npr. prije ažuriranja:

```bash
cd /opt/giftcard-pro
docker compose --env-file .env.production --profile backup run --rm backup
```

### 2.3 Snapshoti servera

Pri kreiranju servera aktivirajte **Backups** u Hetzner Cloud Console. Hetzner dnevno pravi sliku cijelog diska (uključujući Docker volumene, `.env` datoteke, Redis AOF i lokalne dumpove). Prije većih zahvata (major nadogradnja, ažuriranje operativnog sistema) dodatno ručno napravite **snapshot**.

Snapshoti su konzistentni kao nakon pada sistema, ne transakcijski konzistentni: za bazu je mjerodavan izvor logički dump, a snapshot je rezervni nivo za cijeli server.

## 3. Šta se ne kopira

| Dio | Kopirano? | Posljedica gubitka | Mjera |
|---|---|---|---|
| **Redis** (sesije, keš, redovi čekanja, brojači rate limita, zaključavanja) | Samo u snapshotu servera (AOF), ne u dumpu | Vidi 3.1 | Namjerno; posebna kopija nije potrebna |
| `.env.production`, `backend/.env.production` (tajni podaci) | Samo u snapshotu servera | Bez `APP_KEY` svi se odjavljuju; bez NTAG 424 ključeva NTAG 424 DNA kartice se ne mogu provjeriti | **Voditi u menadžeru lozinki** – obavezno |
| Caddy volumeni (`caddy_data`, `caddy_config`) | Samo u snapshotu servera | Certifikati se automatski ponovo izdaju | nema |
| Docker imagei | na GHCR-u (po commit SHA) | nema | nema |
| Izvorni kod, Caddyfile, Compose datoteka | u Gitu | nema | nema |
| Logovi kontejnera | ne | Nedostaju historijski logovi | po potrebi slanje logova, vidi [Vodič za logovanje](logging-guide.md) |

### 3.1 Redis – šta znači gubitak

Redis sadrži samo prolazne podatke. Ako se Redis izgubi (npr. vraćanje na novi server bez snapshota):

| Sadržaj Redisa | Posljedica | Procjena |
|---|---|---|
| Sesije | Sve osobe se odjavljuju i ponovo prijavljuju. Uređaji ostaju registrovani (tabela `devices`). | bezopasno, jednokratan napor za osoblje |
| Red čekanja (`default`, `notifications`) | Još neposlani e-mailovi kupcima (kupovina, dopuna, podsjetnik, nisko stanje) se gube. Knjiženja nisu pogođena – e-mailovi se stavljaju u red tek nakon commita knjiženja. | malo; gosti mogu provjeriti na stranici stanja |
| Keš | Automatski se ponovo gradi (dozvole, sistemske postavke). | nema |
| Brojači rate limita, brojači zaključavanja prijave | Brojači kreću od 0. Samo zaključavanje naloga (`locked_until`) je u bazi. | nema |
| Zaključavanja (`migrate --isolated`, `withoutOverlapping`) | ponovo se postavljaju | nema |

Konfiguracija `--appendonly yes` i `noeviction` štiti redove čekanja i sesije pri normalnim ponovnim pokretanjima.

## 4. Šifrovanje

Dumpovi su komprimovani gzipom, ali **nisu šifrovani**. Sadrže lične podatke (imena, e-mail adrese, brojeve telefona kupaca, imena primalaca, IP adrese u zapisniku aktivnosti) te hashove lozinki i tokena.

Preporuke:

1. **Off-site pohrana u šifrovanom obliku:** u `rclone` kreirajte remote tipa `crypt` iznad remotea Storage Boxa (npr. `storagebox-crypt:`) i koristite ga u cronu umjesto `storagebox:giftcard-backups`. Lozinku i salt `crypt` remotea sačuvajte u menadžeru lozinki – bez njih vraćanje nije moguće.
2. **Alternativa:** dumpove prije sinhronizacije asimetrično šifrujte s `age` ili `gpg`; privatni ključ nije na serveru.
3. **Prenos:** Storage Boxu pristupajte samo preko SFTP/SSH (port 23) s ključem, a Samba/FTP deaktivirajte u upravljanju Storage Boxom.
4. **Pristup:** direktorij `/opt/giftcard-pro/backups` čitljiv samo za `deploy` (`chmod 700`).
5. **Disk servera:** referentna instalacija ne šifruje disk servera vlastitim ključem; zaštita se zasniva na kontroli pristupa (SSH ključevi, firewall) i data centru. Za dumpove koji napuštaju server zato važi tačka 1.

## 5. Provjera sigurnosnih kopija

### 5.1 Dnevno (može se automatizovati)

```bash
ls -lh /opt/giftcard-pro/backups | tail -n 3               # newest file from today?
gzip -t /opt/giftcard-pro/backups/$(ls -t /opt/giftcard-pro/backups | head -1) && echo OK
tail -n 5 /var/log/giftcard-backup.log                      # "Backup written: …"
rclone ls storagebox:giftcard-backups | tail -n 3           # present off-site?
```

Uvjerljivost: veličina dumpa polako raste. Dump znatno manji od onog od prethodnog dana je znak za uzbunu.

### 5.2 Mjesečno – testno vraćanje

Sigurnosna kopija se smatra ispravnom tek kada je vraćena. Jednom mjesečno je uvezite u posebnu bazu i provjerite – postupak opisuje [Uputstvo za vraćanje podataka](restore-guide.md), scenarij A. Dokumentujte rezultat (datum, datoteka, trajanje, rezultat provjere ledgera).

## 6. Nadzor poslova kopiranja

| Provjera | Metoda | Uzbuna ako |
|---|---|---|
| Dump kreiran | Starost najnovije datoteke u `backups/` | starija od 26 sati |
| Dump čitljiv | `gzip -t` | greška |
| Off-site sinhronizacija | izlazni kod `rclone`, broj datoteka na Storage Boxu | izlazni kod ≠ 0 ili najnovija datoteka nedostaje |
| Prostor na disku | `df -h /opt` | preko 80 % zauzeto |
| Snapshoti servera | Hetzner Cloud Console | posljednja kopija starija od 26 sati |

Preporuka: obje cron linije dopunite „dead man's switchom" (npr. heartbeat servis koji se poziva samo pri uspjehu i alarmira ako signal izostane):

```cron
30 2 * * * cd /opt/giftcard-pro && docker compose --env-file .env.production --profile backup run --rm backup >> /var/log/giftcard-backup.log 2>&1 && curl -fsS -m 10 [heartbeat-url-backup] >/dev/null
45 2 * * * rclone sync /opt/giftcard-pro/backups storagebox:giftcard-backups && curl -fsS -m 10 [heartbeat-url-offsite] >/dev/null
```

## 7. Čuvanje

### 7.1 Trenutno stanje

- Lokalno: 14 dana.
- Off-site: `rclone sync` **odražava** lokalni direktorij – datoteke obrisane lokalno brišu se i na Storage Boxu. Off-site je tako takođe oko 14 dana.
- Snapshoti servera: rotacija od strane Hetznera.

Greška koja se primijeti tek nakon više od 14 dana (npr. pogrešna masovna izmjena) ne može se s trenutnim stanjem rekonstruisati iz sigurnosne kopije. Ledger je doduše nepromjenjiv, ali matični podaci (kupci, postavke) nisu.

### 7.2 Preporuka: djed-otac-sin off-site

| Nivo | Broj | Izvor |
|---|---|---|
| dnevno | 14 | dump tog dana |
| sedmično | 8 | dump od nedjelje |
| mjesečno | 12 | dump od 1. u mjesecu |

Varijante provedbe (preporuka, nije dio repozitorija):

- **Snapshoti Storage Boxa:** u Hetzner upravljanju aktivirajte automatske snapshote Storage Boxa s odgovarajućom rotacijom.
- **Odvojeni direktoriji s `rclone copy`:** pored posla `sync` sedmični i mjesečni posao koji najnoviji dump kopira u `giftcard-backups-weekly/` odnosno `giftcard-backups-monthly/`, uz čišćenje s `rclone delete --min-age`:

```cron
0 4 * * 0  rclone copy "/opt/giftcard-pro/backups/$(ls -t /opt/giftcard-pro/backups | head -1)" storagebox:giftcard-backups-weekly && rclone delete --min-age 56d storagebox:giftcard-backups-weekly
0 4 1 * *  rclone copy "/opt/giftcard-pro/backups/$(ls -t /opt/giftcard-pro/backups | head -1)" storagebox:giftcard-backups-monthly && rclone delete --min-age 365d storagebox:giftcard-backups-monthly
```

(U crontab linijama znak `%` mora se maskirati; gornje linije ga ne sadrže.)

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

Verzija 1.0 · Stanje: septembar 2026.
