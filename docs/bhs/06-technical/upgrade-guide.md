# Uputstvo za nadogradnju

*Ažuriranje GiftCard Pro na nova izdanja, verzije aplikacije za konobare, promjena major verzija PHP-a, Node.js-a i MySQL-a, strategija vraćanja (rollback) i pravila verzionisanja.*

---

## 1. Verzionisanje

GiftCard Pro slijedi **Semantic Versioning** (`MAJOR.MINOR.PATCH`). Backend, dashboard i aplikacija za konobare nose istu verziju platforme (npr. `2.0.0`; aplikacija dodatno broj builda, vidi [docs/MOBILE_RELEASE.md](../../MOBILE_RELEASE.md)).

| Dio | Povećava se kod | Posljedice za rad sistema |
|---|---|---|
| **PATCH** | ispravke grešaka, sigurnosna ažuriranja, ažuriranja zavisnosti i baznih imagea bez promjene ponašanja | uvođenje bez pripreme |
| **MINOR** | nove funkcije i poboljšanja, kompatibilni unazad; nove opcionalne varijable okruženja; aditivne migracije | pročitati changelog, provjeriti nove varijable |
| **MAJOR** | nekompatibilne izmjene: uklanjanje ili izmjena API polja/krajnjih tačaka, obavezne varijable okruženja, izmjene koje zahtijevaju ručne korake | posebne napomene u changelogu, najava restoranima s API integracijom |

**API** je dodatno verzionisan u putanji (`/api/v1`). Nekompatibilne izmjene API-ja pojavljuju se pod novom putanjom (`/api/v2`) i unaprijed se najavljuju restoranima s integracijom.

Serverski stack i web aplikacija verzionišu se kao cjelina: Coolify gradi sve imageove jednog deploymenta iz istog commita i uvodi ih zajedno.

## 2. Nadogradnja na novo izdanje (standardni slučaj)

### 2.1 Priprema

1. **Pročitajte changelog.** `CHANGELOG.md` za svaku verziju opisuje *šta* se promijenilo i *zašto*. Posebno obratite pažnju na: rad sistema, sigurnost, novac i ledger, nove postavke, izmijenjene standardne vrijednosti.
2. **Prepoznajte nove varijable okruženja:**

```bash
git diff <current-commit> <new-commit> -- .env.production.example docker-compose.coolify.yml infra/
```

Svaka varijabla ima u Compose stacku funkcionalan standard. Nove vrijednosti koje želite postaviti drugačije unesite **prije** deploymenta u Coolify pod *Environment Variables*.

3. **Pregledajte migracije:** `git diff --stat <current-commit> <new-commit> -- backend/database/migrations/`. Nove migracije provjerite na dugotrajne operacije (npr. indeks na `voucher_transactions` ili `audit_logs`) – takva izdanja uvodite u prozoru održavanja. Migracije nikada ne smiju mijenjati ledger, plaćanja ni zapisnik aktivnosti (append-only okidači).
4. **Izaberite vrijeme:** van radnog vremena (vidi [Uputstvo za održavanje](maintenance-guide.md#71-vremenski-prozori-održavanja)).
5. **Sigurnosna kopija:** ručna kopija ([Uputstvo za sigurnosne kopije](backup-guide.md), odjeljak 2.2). Kod MAJOR izdanja ili opsežnih migracija dodatno napravite **Hetzner snapshot**.

### 2.2 Uvođenje

Merge odnosno push na `main` (ili *Redeploy* u Coolifyju). Coolify

1. gradi nove imageove iz commita,
2. zamjenjuje kontejnere; prvi novi Laravel kontejner izvršava migracije na čekanju pod Redis zaključavanjem, `api` unosi referentne podatke,
3. `api`, `worker` i `scheduler` tek tada opslužuju zahtjeve.

Migracije se time izvršavaju **automatski**. Ručni `php artisan migrate` nije potreban. Pri zamjeni kontejnera nastaje prekid od nekoliko sekundi.

### 2.3 Provjera

- Provjere nakon deploymenta iz [Uputstva za deployment](deployment-guide.md#8-provjere-nakon-deploymenta).
- Kontejner **api**: `php artisan migrate:status` – sve migracije `Ran`.
- Kontejner **api**: `php artisan giftcard:verify-chains` – bez nalaza.
- Uzorak konzistentnosti ledgera (upit 1 iz [Uputstva za vraćanje podataka](restore-guide.md#8-kontrolni-upiti-nakon-vraćanja)).
- Kod izdanja s vidljivim izmjenama: kratko obavijestite restorane (obavještenje o održavanju ili e-mail) – posebno kod izmjena u aplikaciji za konobare, jer je osoblje obučeno.

### 2.4 Preskakanje više verzija

Migracije su kumulativne; skok preko više MINOR verzija je tehnički moguć. Ali:

- Kompatibilnost aplikacije i šeme zagarantovana je samo između **uzastopnih** izdanja. Rollback je siguran samo na izdanje koje je radilo neposredno prije.
- Ako changelog preskočene verzije sadrži ručne korake, izvršite ih navedenim redoslijedom.
- Preporuka: MINOR verzije uvodite jednu po jednu kada neka od njih uklanja kolone.

## 3. Ažuriranje aplikacije za konobare

- Nove verzije objavljuju se preko Google Playa i App Storea (TestFlight za testiranje); postupak u [docs/MOBILE_RELEASE.md](../../MOBILE_RELEASE.md).
- Aplikacija pri pokretanju poziva `GET /app/config`. Ako je njena verzija ispod minimalne (`app.min_version.android`, `app.min_version.ios` u sistemskim postavkama), prikazuje „Update required“ i otvara stranicu u prodavnici.
- Minimalnu verziju podignite tek kada je nova verzija dostupna u **obje** prodavnice: administracija platforme → **System settings**.
- Prvo uvedite backend kada nova verzija aplikacije treba nove krajnje tačke. Tokeni uređaja ostaju važeći pri ažuriranju aplikacije.

## 4. Strategija vraćanja (rollback)

| Situacija | Postupak |
|---|---|
| Greška u aplikaciji, šema nepromijenjena ili samo proširena | Vratite aplikaciju na prethodni deployment: Coolify → *Deployments* → raniji deployment → *Redeploy* ([Uputstvo za deployment](deployment-guide.md#9-rollback)) |
| Migracija nije uspjela (kontejner `api` se ne pokreće) | Provjerite log (resurs → *Logs*, servis `api`). Neuspjela migracija nije označena kao `Ran`. Vratite aplikaciju; ispravite migraciju i uvedite je kao patch izdanje |
| Migracija je pogrešno izmijenila matične podatke | Bez nasumičnog `migrate:rollback`. Analizirajte pogođene podatke u bazi za vraćanje ([Uputstvo za vraćanje podataka, scenarij A](restore-guide.md#3-scenarij-a--istraživanje-u-bazi-za-vraćanje)); u krajnjem slučaju scenarij B s kopijom neposredno prije deploymenta |
| Neuspjela major nadogradnja MySQL-a | Vidi odjeljak 5.3 – put nazad je logički dump |

Osnovna pravila:

- Izmjene šeme pišu se tako da **prethodna** verzija radi s **novom** šemom (prvo dodati, prilagoditi kod, ukloniti tek u sljedećem izdanju). Time je rollback aplikacije moguć bez rollbacka šeme.
- `down()` metode migracija u produkciji se izvršavaju samo nakon provjere i svježe sigurnosne kopije.
- Ledger, plaćanja i zapisnik aktivnosti nikada se ne „čiste“ rollbackom. Knjiženja nastala s novom verzijom ostaju važeća; hash lanci se nastavljaju.

## 5. Nadogradnje platforme (PHP, Node.js, MySQL, Redis, Caddy)

### 5.1 Gdje su verzije određene

| Komponenta | Trenutno | Određeno u |
|---|---|---|
| PHP | 8.4 | `backend/Dockerfile` (`FROM php:8.4-fpm-alpine`), `.github/workflows/ci.yml`, `backend/composer.json` |
| Laravel | 12 | `backend/composer.json` (`"laravel/framework": "^12.0"`) |
| Node.js | 22 LTS | `dashboard/Dockerfile` (`FROM node:22-alpine`), `ci.yml`, `dashboard/package.json` (`engines`) |
| Next.js | 15 | `dashboard/package.json` |
| MySQL | 8.4 LTS | `docker-compose.coolify.yml`, `docker-compose.dev.yml`, `ci.yml` (servis `mysql:8.4`) |
| Redis | 7.4 | `docker-compose.coolify.yml`, `docker-compose.dev.yml` |
| Caddy (gateway) | 2 | `infra/docker/gateway/Dockerfile` (`FROM caddy:2-alpine`) |
| Flutter (aplikacija za konobare) | prema `waiter-app/pubspec.yaml` | `ci.yml`, `.github/workflows/testflight.yml` |

Svaki deployment ponovo gradi imageove i automatski preuzima patch verzije. Promjene minor i major verzija namjerno se mijenjaju zajedno u svim navedenim datotekama, kako bi CI, razvoj i produkcija testirali istu verziju.

### 5.2 PHP ili Node.js

1. Kreirajte granu, podignite verziju u svim datotekama iz 5.1 (npr. `php:8.5-fpm-alpine`).
2. PHP: provjerite ekstenzije u Dockerfileu, `composer update`, obratite pažnju na deprecations u testovima.
3. Node.js: koristite samo LTS verzije; `npm ci`, `npm run build`.
4. CI mora biti potpuno zelen (SQLite, MySQL s provjerom integriteta, Larastan, buildovi, Coolify stack).
5. Test prihvatanja (`e2e/pilot-journey.mjs`) nad novim buildom.
6. Uvesti kao MINOR ili PATCH izdanje (nevidljivo za rad sistema). Rollback kao kod svakog izdanja.

Promjene major verzije Laravela ili Next.js-a (npr. Laravel 13, Next.js 16) su posebni razvojni projekti s vodičem za nadogradnju odgovarajućeg frameworka.

### 5.3 MySQL (promjena major odnosno LTS verzije)

MySQL pri prvom pokretanju novije verzije automatski ažurira direktorij podataka; **povratak na staru verziju s istim direktorijem podataka nije moguć**. Zato:

1. Podignite ciljnu verziju u `docker-compose.dev.yml` i `ci.yml`, CI i lokalni testovi zeleni (uključujući append-only okidače i `giftcard:verify-chains`).
2. Testirajte staging s kopijom produkcijskih podataka (vraćanje iz dumpa) na ciljnoj verziji, uključujući kontrolne upite i test prihvatanja.
3. Produkcija u prozoru održavanja: napravite svjež dump (put nazad) i Hetzner snapshot; režim održavanja (`php artisan down`); podignite verziju imagea `mysql` i `backup` u `docker-compose.coolify.yml` i uvedite; u logu `mysql` sačekajte poruke o nadogradnji i „ready for connections“.
4. `php artisan giftcard:verify-chains`, kontrolni upiti iz [Uputstva za vraćanje podataka](restore-guide.md#8-kontrolni-upiti-nakon-vraćanja), funkcionalna provjera.
5. **Put nazad kod problema:** vratite staru verziju imagea, volumen `mysql-data` zamijenite novim, praznim i uvezite dump iz koraka 3 (scenarij B iz Uputstva za vraćanje podataka) – ili vratite snapshot.

Alternativa s manjim rizikom: postavite staging resurs s ciljnom verzijom, uvezite dump, provjerite i tek onda prebacite produkciju.

### 5.4 Redis i Caddy

- **Redis:** minor ažuriranja unutar 7.x podizanjem taga i ponovnim uvođenjem. Kratak prekid; sesije i red čekanja ostaju sačuvani zahvaljujući AOF-u. Kod promjene major verzije provjerite kompatibilnost AOF datoteke prema release notes; u najgorem slučaju gubitak Redisa je podnošljiv (vidi [Uputstvo za sigurnosne kopije](backup-guide.md#31-redis--šta-znači-gubitak)).
- **Caddy (gateway):** gateway ne terminira TLS (to radi Coolify proxy) i nema certifikate. Kod promjene major verzije provjerite `infra/docker/gateway/Caddyfile` prema release notes, posebno filtere koji uklanjaju tokene i zaglavlja iz logova.

### 5.5 Operativni sistem i Coolify

Sigurnosna ažuriranja instalira `unattended-upgrades`. Sam Coolify ažurirajte preko njegovog interfejsa (prethodno snapshot). Promjena Ubuntu LTS verzije (npr. 24.04 → 26.04) najbolje se izvodi **novom izgradnjom** servera prema [Uputstvu za deployment](deployment-guide.md) i preseljenjem podataka (dump + vraćanje, promjena DNS-a) umjesto nadogradnje na licu mjesta.

## 6. Kontrolna lista za nadogradnju

- [ ] Pročitan changelog ciljne verzije (i preskočenih verzija)
- [ ] Nove varijable okruženja provjerene i po potrebi unesene u Coolify
- [ ] Migracije pregledane; duge operacije → prozor održavanja
- [ ] Postavljeno obavještenje o održavanju (ako se očekuje prekid)
- [ ] Napravljena sigurnosna kopija, kod MAJOR dodatno snapshot
- [ ] Test prihvatanja ciljne verzije prošao
- [ ] Deployment uveden
- [ ] `/up` = 200, `migrate:status` potpun, `giftcard:verify-chains` bez nalaza
- [ ] Funkcionalna provjera (QR skeniranje, testno iskorištavanje, storno)
- [ ] Minimalna verzija aplikacije za konobare podignuta tek kada je nova aplikacija u obje prodavnice
- [ ] Obavještenje o održavanju uklonjeno, restorani obaviješteni o vidljivim izmjenama
- [ ] Nadogradnja dokumentovana u operativnom protokolu

---

Verzija 2.0 · Stanje: septembar 2026.
