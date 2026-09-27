# Uputstvo za nadogradnju

> **Napomena (Coolify deployment):** Produkcija od verzije 1.4.2 radi na **Coolify** sa `docker-compose.coolify.yml` (build iz izvornog koda, bez GHCR-a, bez deploy skripti). Komande sa `docker compose --env-file .env.production`, `infra/scripts/…`, `deploy.yml` ili Caddy na hostu u ovom dokumentu su zastarjele. Mjerodavni su [docs/DEPLOYMENT.md](../../DEPLOYMENT.md) (deployment, backup, restore, rad) i [docs/ENVIRONMENT.md](../../ENVIRONMENT.md).

*Ažuriranje GiftCard Pro na nova izdanja, promjena major verzija PHP-a, Node.js-a i MySQL-a, strategija vraćanja (rollback) i pravila verzionisanja.*

---

## 1. Verzionisanje

GiftCard Pro slijedi **Semantic Versioning** (`MAJOR.MINOR.PATCH`), Git tagovi u formatu `vMAJOR.MINOR.PATCH` (npr. `v1.2.0`).

| Dio | Povećava se kod | Primjeri | Posljedice za rad sistema |
|---|---|---|---|
| **PATCH** | ispravke grešaka, sigurnosna ažuriranja, ažuriranja zavisnosti i baznih imagea bez promjene ponašanja | `v1.2.1` | uvođenje bez pripreme |
| **MINOR** | nove funkcije i poboljšanja, kompatibilni unazad; nove opcionalne varijable okruženja; aditivne migracije | `v1.1.0` (hardening), `v1.2.0` (pilot izdanje) | pročitati changelog, provjeriti nove varijable |
| **MAJOR** | nekompatibilne izmjene: uklanjanje ili izmjena API polja/krajnjih tačaka, obavezne varijable okruženja, izmjene koje zahtijevaju ručne korake | `v2.0.0` | posebne napomene za nadogradnju u changelogu, najava restoranima s API integracijom |

**API** je dodatno verzionisan u putanji (`/api/v1`). Nekompatibilne izmjene API-ja pojavljuju se pod novom putanjom (`/api/v2`); `/api/v1` ostaje dostupan tokom najavljenog prelaznog perioda (preporuka: najmanje 6 mjeseci).

Aplikacija se verzioniše kao cjelina: API image i web image jednog izdanja nose isti commit SHA i uvijek se uvode zajedno.

## 2. Nadogradnja na novo izdanje (standardni slučaj)

### 2.1 Priprema

1. **Pročitajte changelog.** `CHANGELOG.md` za svaku verziju opisuje *šta* se promijenilo i *zašto*. Posebno obratite pažnju na: odjeljke o radu sistema („Operations"), sigurnosti, novcu i ledgeru, nove postavke, izmijenjene standardne vrijednosti.
2. **Prepoznajte nove varijable okruženja:**

```bash
cd /opt/giftcard-pro
git fetch --tags
git diff <current-tag> <new-tag> -- backend/.env.production.example .env.production.example docker-compose.yml infra/

# variables present in the template but missing in your own file:
comm -23 <(git show <new-tag>:backend/.env.production.example | grep -o '^[A-Z0-9_]*=' | sort) \
         <(grep -o '^[A-Z0-9_]*=' backend/.env.production | sort)
```

Nove varijable upišite u `backend/.env.production` odnosno `.env.production` **prije** deploymenta.

3. **Pregledajte migracije:** `git diff --stat <current-tag> <new-tag> -- backend/database/migrations/`. Provjerite nove migracije na dugotrajne operacije (npr. indeks na `gift_card_transactions`) – takva izdanja uvodite u prozoru održavanja.
4. **Izaberite vrijeme:** van radnog vremena (vidi [Uputstvo za održavanje](maintenance-guide.md#71-vremenski-prozori-održavanja)).
5. **Sigurnosna kopija:**

```bash
docker compose --env-file .env.production --profile backup run --rm backup
```

Kod MAJOR izdanja ili opsežnih migracija dodatno napravite **Hetzner snapshot**.

### 2.2 Uvođenje

```bash
git tag v1.3.0 && git push --tags        # in the development repository
```

GitHub Actions (`deploy.yml`) gradi imagee, čeka odobrenje u environmentu `production` i izvršava `infra/scripts/deploy.sh`:

1. preuzimanje novih imagea,
2. ponovno pokretanje `api` → `migrate --force --isolated` i referentni seederi,
3. ponovno pokretanje `queue`, `scheduler`, `web`, `caddy`, `queue:restart`,
4. healthcheck `/up` (do 60 sekundi).

Migracije se time izvršavaju **automatski**. Ručni `php artisan migrate` nije potreban.

### 2.3 Provjera

- Provjere nakon deploymenta iz [Uputstva za deployment](deployment-guide.md#8-provjere-nakon-deploymenta).
- `docker compose --env-file .env.production exec api php artisan migrate:status` – sve migracije `Ran`.
- Uzorak konzistentnosti ledgera (upit 1 iz [Uputstva za vraćanje podataka](restore-guide.md#8-kontrolni-upiti-nakon-vraćanja)).
- Kod izdanja s vidljivim izmjenama: kratko obavijestite restorane (obavještenje o održavanju ili e-mail) – posebno kod izmjena u aplikaciji za konobare, jer je osoblje obučeno.

### 2.4 Preskakanje više verzija

Migracije su kumulativne; skok s `v1.1.0` na `v1.3.0` je tehnički moguć. Ali:

- Princip expand/contract garantuje kompatibilnost samo između **uzastopnih** izdanja. Rollback je siguran samo na neposredno prethodno pokrenuto izdanje.
- Ako changelog preskočene verzije sadrži ručne korake, izvršite ih navedenim redoslijedom.
- Preporuka: MINOR verzije uvodite jednu za drugom ako neka od njih sadrži contract migracije (uklanjanje kolona).

## 3. Strategija vraćanja (rollback)

| Situacija | Postupak |
|---|---|
| Greška u aplikaciji, shema nepromijenjena ili samo proširena | Vratiti aplikaciju na prethodno izdanje ([Uputstvo za deployment](deployment-guide.md#9-rollback)): `IMAGE_TAG=<previous-release-sha> ./infra/scripts/deploy.sh` nakon `git checkout <previous-release-sha>` |
| Migracija nije uspjela (kontejner `api` se ne pokreće) | Provjeriti logove (`docker compose … logs api`). Neuspjela migracija nije označena kao `Ran`. Vratiti aplikaciju; ispraviti migraciju i ponovo uvesti kao patch izdanje |
| Migracija je pogrešno izmijenila podatke | Bez `migrate:rollback` naslijepo. Analizirati pogođene podatke u bazi za vraćanje ([Uputstvo za vraćanje podataka, scenarij A](restore-guide.md#3-scenarij-a--istraživanje-u-bazi-za-vraćanje)); u krajnjem slučaju scenarij B sa sigurnosnom kopijom od neposredno prije deploymenta |
| Major nadogradnja MySQL-a nije uspjela | Vidi odjeljak 4.3 – put nazad je logički dump |

Osnovna pravila:

- Migracije se pišu tako da **prethodna** verzija radi s **novom** shemom (expand → migrate → contract). Time je rollback aplikacije moguć bez rollbacka sheme.
- Metode `down()` migracija u produkciji se izvršavaju samo nakon provjere i svježe sigurnosne kopije.
- Ledger se nikada ne „čisti" rollbackom. Knjiženja nastala s novom verzijom ostaju važeća.

## 4. Nadogradnje platforme (PHP, Node.js, MySQL, Redis, Caddy)

### 4.1 Gdje su verzije određene

| Komponenta | Trenutno | Određeno u |
|---|---|---|
| PHP | 8.4 | `backend/Dockerfile` (`FROM php:8.4-fpm-alpine`), `.github/workflows/ci.yml` (`php-version: "8.4"`), `backend/composer.json` (`"php": "^8.2"`) |
| Laravel | 12 | `backend/composer.json` (`"laravel/framework": "^12.0"`) |
| Node.js | 22 LTS | `dashboard/Dockerfile` (`FROM node:22-alpine`), `ci.yml` (`node-version: 22`), `dashboard/package.json` (`engines`) |
| Next.js | 15 | `dashboard/package.json` |
| MySQL | 8.4 LTS | `docker-compose.yml`, `docker-compose.dev.yml`, `ci.yml` (servis `mysql:8.4`) |
| Redis | 7.4 | `docker-compose.yml`, `docker-compose.dev.yml` |
| Caddy | 2.8 | `docker-compose.yml` |

Ponovna izgradnja imagea automatski preuzima patch verzije. Promjene minor i major verzija namjerno se mijenjaju zajedno u svim navedenim datotekama, kako bi CI, razvoj i produkcija testirali istu verziju.

### 4.2 PHP ili Node.js

1. Kreirati branch, povećati verziju u svim datotekama iz 4.1 (npr. `php:8.5-fpm-alpine` i `php-version: "8.5"`).
2. PHP: provjeriti ekstenzije u Dockerfileu (`pdo_mysql intl gd zip bcmath opcache pcntl redis`), `composer update`, pratiti deprecation poruke u testovima.
3. Node.js: koristiti samo LTS verzije; `npm ci`, `npm run build`.
4. CI mora biti potpuno zelen (SQLite, MySQL, Larastan, build).
5. Test prihvatanja (`e2e/pilot-journey.mjs`) nad novim buildom.
6. Uvesti kao MINOR ili PATCH izdanje (nevidljivo za rad sistema). Rollback kao kod svakog izdanja.

Promjene major verzija Laravela ili Next.js-a (npr. Laravel 13, Next.js 16) su posebni razvojni projekti uz vodič za nadogradnju odgovarajućeg frameworka.

### 4.3 MySQL (promjena major odnosno LTS verzije)

MySQL pri prvom pokretanju novije verzije automatski ažurira direktorij podataka; **povratak na staru verziju s istim direktorijem podataka nije moguć**. Zato:

1. Povećati ciljnu verziju u `docker-compose.dev.yml` i `ci.yml`, CI i lokalni testovi zeleni.
2. Testirati staging s kopijom produkcijskih podataka (vraćanje iz dumpa) na ciljnoj verziji, uključujući kontrolne upite i test prihvatanja.
3. Produkcija u prozoru održavanja:

```bash
cd /opt/giftcard-pro
alias dc='docker compose --env-file .env.production'
dc --profile backup run --rm backup                   # fresh dump = way back
# additionally create a Hetzner snapshot
dc stop queue scheduler api
# raise the mysql image version in docker-compose.yml (via release/Git), then:
dc pull mysql
dc up -d mysql
dc logs -f mysql                                      # wait for upgrade messages, "ready for connections"
dc up -d api && dc up -d queue scheduler web caddy
```

4. Kontrolni upiti iz [Uputstva za vraćanje podataka](restore-guide.md#8-kontrolni-upiti-nakon-vraćanja), funkcionalna provjera.
5. **Put nazad kod problema:** vratiti staru verziju imagea, zamijeniti volumen `mysql_data` novim, praznim i uvesti dump iz koraka 3 (scenarij B iz Uputstva za vraćanje podataka) – ili vratiti snapshot.

Alternativa s manjim rizikom: paralelno pokrenuti novi MySQL kontejner s ciljnom verzijom i vlastitim volumenom, uvesti dump, provjeriti i tek tada preusmjeriti.

### 4.4 Redis i Caddy

- **Redis:** minor ažuriranja unutar 7.x podizanjem taga i `dc up -d redis`. Kratak prekid; sesije i red čekanja ostaju sačuvani zahvaljujući AOF-u. Kod promjene major verzije provjeriti kompatibilnost AOF datoteke prema release notes; u najgorem slučaju gubitak Redisa je podnošljiv (vidi [Uputstvo za sigurnosne kopije](backup-guide.md#31-redis--šta-znači-gubitak)).
- **Caddy:** podići tag, `dc up -d caddy`. Certifikati su u volumenu `caddy_data` i ostaju sačuvani. Provjeriti `infra/caddy/Caddyfile` prema release notes.

### 4.5 Operativni sistem

Sigurnosna ažuriranja instalira `unattended-upgrades`. Promjena Ubuntu LTS verzije (npr. 24.04 → 26.04) najbolje se izvodi **ponovnom izgradnjom** servera prema [Uputstvu za deployment](deployment-guide.md) i preseljenjem podataka (dump + vraćanje, promjena DNS-a), umjesto in-place nadogradnje.

## 5. Kontrolna lista za nadogradnju

- [ ] Pročitan changelog ciljne verzije (i preskočenih verzija)
- [ ] Nove varijable okruženja upisane
- [ ] Migracije pregledane; duge operacije → prozor održavanja
- [ ] Obavještenje o održavanju postavljeno (ako se očekuje prekid)
- [ ] Sigurnosna kopija napravljena, kod MAJOR dodatno snapshot
- [ ] Test prihvatanja ciljne verzije prošao
- [ ] Tag postavljen, deployment odobren
- [ ] `/up` = 200, `migrate:status` kompletan, uzorak ledgera prazan
- [ ] Funkcionalna provjera (skeniranje, testno iskorištavanje, storno)
- [ ] Obavještenje o održavanju uklonjeno, restorani obaviješteni kod vidljivih izmjena
- [ ] Nadogradnja dokumentovana u operativnom protokolu

---

Verzija 1.0 · Stanje: septembar 2026.
