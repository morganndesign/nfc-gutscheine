# Uputstvo za deployment

*Postavljanje produkcijskog servera kod Hetznera, DNS, firewall, tajni podaci (secrets), Docker Compose, CI/CD s GitHub Actions, proces izdanja, uvođenje bez prekida, provjere nakon deploymenta i rollback.*

---

## 1. Ciljna arhitektura

Referentna instalacija pokreće cijeli proizvod na **jednom Hetzner Cloud serveru** (CPX31: 4 vCPU / 8 GB RAM) s Docker Composeom. Prema procjeni razvojnog tima to je dovoljno za nekoliko stotina restorana (procjena, vidi [Vodič za performanse](performance-guide.md)).

```
                ┌──────────────── Hetzner host ─────────────────┐
 Internet ──443─▶ caddy ──/api,/sanctum,/up──▶ api (php-fpm)    │
                │   │                          queue, scheduler │
                │   └──────── everything else ─▶ web (Next.js)  │
                │                     mysql 8.4 · redis 7.4     │
                └────────────────────────────────────────────────┘
```

| Servis (Compose) | Image | Zadatak |
|---|---|---|
| `caddy` | `caddy:2.8-alpine` | TLS (Let's Encrypt, automatski), HTTP/3, HSTS, usmjeravanje prema putanji. Jedini servis s objavljenim portovima (80, 443, 443/udp). |
| `api` | `giftcard-pro-api` (`CONTAINER_ROLE=app`) | PHP-FPM na portu 9000 (interno). Pri pokretanju izvršava migracije i referentne seedere. |
| `queue` | `giftcard-pro-api` (`CONTAINER_ROLE=worker`) | `queue:work redis --queue=default,notifications --tries=5` |
| `scheduler` | `giftcard-pro-api` (`CONTAINER_ROLE=scheduler`) | `schedule:work` – noćni poslovi |
| `web` | `giftcard-pro-web` | Next.js standalone server na portu 3000 (interno) |
| `mysql` | `mysql:8.4` | `READ-COMMITTED`, `utf8mb4`, buffer pool 512 MB |
| `redis` | `redis:7.4-alpine` | AOF perzistencija, `noeviction`, lozinka |
| `backup` | `mysql:8.4` (profil `backup`) | Samo na poziv: `infra/scripts/backup.sh` |

Pošto web aplikacija i API koriste isti origin, Sanctum kolačići su first-party kolačići i ne postoji CORS konfiguracija.

## 2. Postavljanje servera

### 2.1 Kreiranje servera

1. U Hetzner Cloud Console kreirajte server **Ubuntu 24.04** na lokaciji **Falkenstein ili Nürnberg** (Njemačka, EU), tip CPX31.
2. Dodajte svoj SSH ključ.
3. Aktivirajte **Backups** (dnevni snapshoti servera od Hetznera).
4. Dodijelite **Cloud Firewall**:

| Smjer | Protokol | Port | Izvor |
|---|---|---|---|
| dolazni | TCP | 22 | samo Vaše fiksne IP adrese |
| dolazni | TCP | 80 | bilo koji (HTTP → HTTPS, ACME challenge) |
| dolazni | TCP | 443 | bilo koji |
| dolazni | UDP | 443 | bilo koji (HTTP/3) |

MySQL (3306) i Redis (6379) u produkciji se **ne** objavljuju; portove ima samo Caddy.

### 2.2 DNS

Za domenu aplikacije (`APP_DOMAIN`, npr. `app.giftcardpro.at`) postavite **A zapis** (IPv4) i **AAAA zapis** (IPv6) prema serveru. Caddy preuzima certifikat tek kada domena pokazuje na server.

> **Važno:** Domena iz `CARD_BASE_URL` upisuje se na svaku NFC karticu i svaki QR kod. Kasnija promjena čini već izdate kartice neupotrebljivim. Prije prve štampe kartica izaberite domenu koja ostaje trajno.

### 2.3 Učvršćivanje i instalacija Dockera

```bash
adduser deploy && usermod -aG sudo deploy
# /etc/ssh/sshd_config: PasswordAuthentication no, PermitRootLogin no
apt update && apt -y upgrade && apt -y install unattended-upgrades fail2ban git
curl -fsSL https://get.docker.com | sh && usermod -aG docker deploy
```

Nakon izmjene `sshd_config` ponovo učitajte SSH servis i u drugoj sesiji provjerite da prijava kao `deploy` s ključem radi, prije nego što zatvorite prvu sesiju.

Za off-site sigurnosne kopije dodatno instalirajte `rclone` i postavite remote `storagebox` (SFTP prema Hetzner Storage Boxu) – vidi [Uputstvo za sigurnosne kopije](backup-guide.md).

## 3. Direktorij aplikacije i tajni podaci

```bash
sudo mkdir -p /opt/giftcard-pro && sudo chown deploy: /opt/giftcard-pro
cd /opt/giftcard-pro
git clone git@github.com:your-org/giftcard-pro.git .
cp .env.production.example .env.production           # compose variables
cp backend/.env.production.example backend/.env.production
```

Postoje **dvije** konfiguracione datoteke:

| Datoteka | Sadržaj |
|---|---|
| `/opt/giftcard-pro/.env.production` | Nivo Composea: `APP_DOMAIN`, `ACME_EMAIL`, `REGISTRY`, `IMAGE_TAG`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`, `DB_ROOT_PASSWORD`, `REDIS_PASSWORD`, opcionalno `WAITER_IOS_APP_IDS`, `WAITER_ANDROID_PACKAGE`, `WAITER_ANDROID_CERT_SHA256` (nativna aplikacija za konobare) |
| `/opt/giftcard-pro/backend/.env.production` | Laravel konfiguracija za `api`, `queue`, `scheduler` i `backup` |

`DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` i `REDIS_PASSWORD` moraju biti identični u **obje** datoteke. U `backend/.env.production` važi `DB_HOST=mysql` i `REDIS_HOST=redis` (nazivi servisa u Compose mreži). Obje datoteke su upisane u `.gitignore` i nikada se ne smiju commitati.

Generisanje tajnih podataka:

```bash
openssl rand -base64 36                               # DB / Redis passwords
echo "base64:$(openssl rand -base64 32)"                                            # APP_KEY
docker run --rm --entrypoint php ghcr.io/your-org/giftcard-pro-api:latest artisan giftcard:nfc-keys   # NTAG 424 keys (optional)
```

> `APP_KEY` i NTAG 424 ključeve sačuvajte u menadžeru lozinki. Ako se `APP_KEY` izgubi, sve osobe se odjavljuju. Ako se izgube NFC ključevi, NTAG 424 DNA kartice se više ne mogu provjeriti.

Provjerite obavezne vrijednosti u `backend/.env.production`: `APP_ENV=production`, `APP_DEBUG=false`, `APP_URL`, `FRONTEND_URL` i `CARD_BASE_URL` s `https://<APP_DOMAIN>`, `SESSION_DOMAIN` i `SANCTUM_STATEFUL_DOMAINS` = `<APP_DOMAIN>`, `SESSION_SECURE_COOKIE=true`, `LOG_CHANNEL=stderr`, `LOG_LEVEL=info`, `SEED_DEMO_DATA=false`, `MAIL_*`. Detalji: [Varijable okruženja](environment-variables.md).

## 4. Prvo pokretanje

```bash
docker login ghcr.io
docker compose --env-file .env.production up -d
docker compose --env-file .env.production exec api php artisan platform:create-admin you@company.com
```

Tok prvog pokretanja:

1. `mysql` i `redis` se pokreću i preko svojih healthcheckova javljaju da su ispravni.
2. `api` izvršava `migrate --force --isolated` i referentne seedere, kešira konfiguraciju, rute, prikaze i događaje, a zatim pokreće PHP-FPM. Healthcheck (`pgrep -f "php-fpm: master"`) postaje zelen tek tada (početni prozor 120 s).
3. `queue` i `scheduler` se pokreću tek kada je `api` ispravan – nikada ne rade nad nemigriranom shemom.
4. Caddy pri prvom HTTPS pozivu traži TLS certifikat.

Provjera:

```bash
docker compose --env-file .env.production ps
curl -fsS https://app.giftcardpro.at/up        # expected: HTTP 200
```

## 5. CI/CD s GitHub Actions

### 5.1 Workflowi

| Workflow | Okidač | Sadržaj |
|---|---|---|
| `ci.yml` | svaki pull request, svaki push na `main` | Backend: Pint, Larastan, PHPUnit sa SQLite **i** MySQL 8.4, `composer audit`. Frontend: ESLint, `tsc`, `next build`, `npm audit --omit=dev --audit-level=high`. Zatim build oba Docker imagea (bez pusha). |
| `deploy.yml` | tag `v*` ili ručno (`workflow_dispatch`) | Builda oba imagea, pusha ih na GHCR s commit SHA-om i `latest` kao tagom, povezuje se putem SSH-a sa serverom i izvršava `infra/scripts/deploy.sh`. Radi u environmentu `production`; paralelni deploymenti se serijalizuju (`concurrency: deploy-production`). |

### 5.2 Konfiguracija repozitorija

| Naziv | Tip | Vrijednost |
|---|---|---|
| `DEPLOY_HOST` | Secret | IP ili hostname servera |
| `DEPLOY_USER` | Secret | `deploy` |
| `DEPLOY_SSH_KEY` | Secret | privatni ključ deploy ključa koji je dozvoljen na serveru |
| `DEPLOY_HOST_FINGERPRINT` | Secret | `ssh-keyscan -t ed25519 host \| ssh-keygen -lf -` |
| `GHCR_READ_TOKEN` | Secret | Personal Access Token s `read:packages` |
| `APP_DOMAIN` | Variable | `app.giftcardpro.at` |
| `production` | Environment | unesite obavezne recenzente za ručno odobrenje |

Korak na serveru u `deploy.yml` izvršava:

```bash
cd /opt/giftcard-pro
git fetch --tags --quiet && git checkout --quiet <commit-sha>
echo "<GHCR_READ_TOKEN>" | docker login ghcr.io -u <owner> --password-stdin
IMAGE_TAG=<commit-sha> APP_DOMAIN=<APP_DOMAIN> ./infra/scripts/deploy.sh
```

Server zato treba pristup za čitanje Git repozitorija (npr. deploy ključ korisnika `deploy`).

## 6. Proces izdanja

1. Sve izmjene su na `main`, `ci.yml` je zelen.
2. Pokrenite test prihvatanja u pretraživaču (`e2e/pilot-journey.mjs`) protiv staging ili lokalnog okruženja – vidi [Uputstvo za instalaciju](installation-guide.md#10-test-prihvatanja-u-pretraživaču-e2e).
3. Dopunite `CHANGELOG.md` (šta i zašto), odredite broj verzije prema SemVer – vidi [Uputstvo za nadogradnju](upgrade-guide.md).
4. Postavite i pushajte tag:

```bash
git tag v1.4.0 && git push --tags
```

5. `deploy.yml` se pokreće; nakon odobrenja recenzenata environmenta `production` izvršava se uvođenje.
6. Izvršite provjere nakon deploymenta (odjeljak 8).

Deploymente ne pokrećite tokom glavnog radnog vremena restorana (preporuka: prijepodne prije 11:00 ili poslijepodne između 14:30 i 17:00 po bečkom vremenu), niti između 00:00 i 00:30 (istek kartica u 00:15) ili u 02:30 (sigurnosna kopija).

## 7. Uvođenje bez prekida

`infra/scripts/deploy.sh` radi u sljedećim koracima:

| Korak | Naredba | Svrha |
|---|---|---|
| 1 | `docker compose … pull api queue scheduler web` | Preuzimanje novih imagea dok stara verzija i dalje radi |
| 2 | `docker compose … up -d --no-deps api` | Novi API kontejner; ulazna tačka izvršava `migrate --force --isolated` i seedere |
| 3 | `exec -T api php artisan migrate:status` | Prekida ako API nije dostupan |
| 4 | `up -d --no-deps queue scheduler web caddy` | Zamjena workera, schedulera, web aplikacije i proxyja |
| 5 | `exec -T api php artisan queue:restart` | Workeri uredno završavaju tekuće poslove i pokreću se s novim kodom |
| 6 | do 30 × `curl -fsS https://${APP_DOMAIN}/up` u razmaku od 2 s | Healthcheck; pri uspjehu `docker image prune -f`, inače izlazni kod 1 |

Principi koji omogućavaju uvođenje bez vidljivog prekida:

- **Migracije kompatibilne unazad (expand → migrate → contract).** Migracija nikada ne smije ukloniti ili preimenovati nešto što prethodna verzija još koristi. Kolone se prvo dodaju (izdanje N), kod se prilagođava (izdanje N), a stare kolone uklanjaju tek u izdanju N+1. Tako stari `web` kontejner nastavlja raditi tokom uvođenja.
- **`migrate --isolated`** postavlja zaključavanje u kešu: dva app kontejnera nikada ne migriraju istovremeno.
- **Healthcheckovi određuju redoslijed.** `queue` i `scheduler` zavise od `api: service_healthy`; API healthcheck postaje zelen tek kada PHP-FPM radi nakon migracije i izgradnje keša.
- **Novčane transakcije su idempotentne.** Ako zahtjev za iskorištavanje tokom zamjene kontejnera naiđe na grešku, aplikacija za konobare ga ponavlja s istim `Idempotency-Key` – nikada se ne knjiži dvaput.

Ograničenje: pri zamjeni kontejnera nastaje kratka pauza od nekoliko sekundi u kojoj Caddy za taj servis može vraćati greške (jedan host, bez replika). Zato deploymente radite van radnog vremena.

## 8. Provjere nakon deploymenta

```bash
cd /opt/giftcard-pro
docker compose --env-file .env.production ps                       # all services "running"/"healthy"
curl -fsS https://app.giftcardpro.at/up                            # 200
docker compose --env-file .env.production exec api php artisan about
docker compose --env-file .env.production exec api php artisan migrate:status
docker compose --env-file .env.production exec scheduler php artisan schedule:list
docker compose --env-file .env.production exec api php artisan queue:failed
docker compose --env-file .env.production logs --since 10m api queue | grep -iE "error|critical|emergency"
```

Funkcionalna provjera (oko 5 minuta):

| Provjera | Očekivanje |
|---|---|
| Prijava kao administrator platforme | Dashboard se učitava, nema poruke o grešci |
| Testni restoran: pretraga kartice, otvaranje detalja kartice | Historija i stanje su tačni |
| Aplikacija za konobare na testnom uređaju: skeniranje testne kartice | Kartica se otvara za manje od 1 s |
| Javna stranica stanja testne kartice | Stanje je vidljivo (ako je aktivirano) |
| Testno iskorištavanje od 0,01 € na internoj testnoj kartici, zatim storno | Knjiženje i protuknjiženje u ledgeru |
| Uptime monitor | zelen |

## 9. Rollback

### 9.1 Vraćanje aplikacije

Imagei ostaju na GHCR-u sa svojim commit SHA-om. Vraćanje na prethodno stanje:

**Varijanta A – preko GitHub Actions:** ručno pokrenite `deploy.yml` (**Run workflow**) i kao ref izaberite prethodni tag (npr. `v1.3.0`). Imagei se buildaju iz tog stanja i uvode.

**Varijanta B – direktno na serveru** (brže, bez ponovnog builda):

```bash
cd /opt/giftcard-pro
git fetch --tags && git checkout <previous-release-sha>
IMAGE_TAG=<previous-release-sha> APP_DOMAIN=app.giftcardpro.at ./infra/scripts/deploy.sh
```


### 9.2 Migracije i rollback

- Migracije se pri rollbacku **ne** poništavaju automatski. Zahvaljujući principu expand/contract prethodna verzija radi s novijom shemom.
- `php artisan migrate:rollback` u produkciji izvršavajte samo nakon provjere dotične migracije i nakon svježe sigurnosne kopije. Migracije koje mijenjaju podatke nikada ne poništavajte bez plana za vraćanje.
- Ako je shema oštećena, važi [Uputstvo za vraćanje podataka](restore-guide.md).

### 9.3 Kada raditi rollback

| Situacija | Mjera |
|---|---|
| `/up` nakon deploymenta ne vraća 200 | Provjerite logove (`docker compose logs api`); bez brzog rješenja odmah rollback |
| Iskorištavanja ne uspijevaju (5xx) | Odmah rollback, zatim analiza |
| Pojedinačne greške u interfejsu bez veze s novcem | Izdanje s ispravkom umjesto rollbacka |

## 10. Noćni poslovi

Kontejner `scheduler` izvršava `schedule:work`. Vremena važe u `SCHEDULE_TIMEZONE` (standard `Europe/Vienna`):

| Vrijeme | Posao |
|---|---|
| 00:15 | `giftcards:expire` – isknjižavanje isteklih kartica (u ledgeru i zapisniku aktivnosti; jedna neispravna kartica ne zaustavlja obradu) |
| 03:30 | `queue:prune-failed --hours=720` – uklanjanje neuspjelih poslova starijih od 30 dana |
| 10:00 | `giftcards:notify-expiring` – e-mailovi podsjetnici, samo za aktivne restorane |
| svakih 15 minuta | `auth:clear-resets` |
| svakih 5 minuta | `queue:monitor redis:default,redis:notifications --max=500` |

Dodatno putem crona korisnika `deploy`: sigurnosna kopija baze u 02:30 i off-site sinhronizacija u 02:45 (vrijeme servera) – vidi [Uputstvo za sigurnosne kopije](backup-guide.md).

## 11. Skaliranje

| Potreba | Korak |
|---|---|
| Više web saobraćaja | Više replika `api` i `web` iza Caddyja (`reverse_proxy` prihvata više upstreamova). Aplikacija je bez stanja – sesije, keš i zaključavanja su u Redisu. |
| Baza podataka | Managed MySQL ili namjenski server; read replika za izvoze i izvještaje |
| Izolacija za velike klijente | Isti imagei posebno po klijentu (single tenant) – bez izmjene koda |

Detalji: [Vodič za performanse](performance-guide.md).

---

Verzija 1.0 · Stanje: septembar 2026.
