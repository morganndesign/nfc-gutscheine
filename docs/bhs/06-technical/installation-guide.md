# Uputstvo za instalaciju

*Lokalno razvojno okruženje, preduslovi za produkcijski rad, prvi administrator platforme, prazna platforma, demo podaci i testovi za GiftCard Pro.*

---

## 1. Pregled

GiftCard Pro se sastoji od dvije aplikacije i tri pozadinska servisa:

| Komponenta | Tehnologija | Zadatak |
|---|---|---|
| API | Laravel 12 / PHP 8.4 | Poslovna logika, ledger, autentifikacija, pozadinski poslovi |
| Web aplikacija | Next.js 15 / TypeScript | Dashboard, aplikacija za konobare, stranica stanja za goste, prikaz za štampu |
| Baza podataka | MySQL 8.4 (radi i MariaDB 10.11+) | Mandanti (restorani), kartice, ledger, zapisnik aktivnosti (audit log) |
| Redis | 7.x | Sesije, keš, redovi čekanja (queues), ograničenja broja zahtjeva, zaključavanja |
| Mailpit | samo razvoj | Hvata sve e-mailove (web interfejs na portu 8025) |

U razvoju API i web aplikacija rade nativno (hot reload); samo MySQL, Redis i Mailpit rade u Dockeru. U produkciji sve radi u Docker Composeu – vidi [Uputstvo za deployment](deployment-guide.md).

## 2. Preduslovi

### 2.1 Lokalni razvoj

| Komponenta | Verzija |
|---|---|
| PHP | 8.4 s ekstenzijama `intl`, `pdo_mysql`, `gd`, `zip`, `bcmath`, `redis` (ili `predis`) |
| Composer | 2.x |
| Node.js | 22 LTS |
| MySQL | 8.4 (moguće i MariaDB 10.11+) |
| Redis | 7.x |
| Docker | 24+ s Compose pluginom (za pozadinske servise) |

Ako radite isključivo s Dockerom, potreban Vam je samo Docker 24+ s Compose pluginom.

### 2.2 Produkcijski rad

| Oblast | Zahtjev |
|---|---|
| Server | Jedan Hetzner Cloud server, referenca: CPX31 (4 vCPU / 8 GB RAM), Ubuntu 24.04, lokacija Falkenstein ili Nürnberg (EU) |
| Softver | Docker (preko `get.docker.com`), Compose plugin, `git`, `unattended-upgrades`, `fail2ban`, `rclone` (za off-site sigurnosne kopije) |
| Mreža | Hetzner Cloud Firewall: port 22 (samo Vaše IP adrese), 80, 443 (TCP i UDP za HTTP/3) |
| DNS | A/AAAA zapis za domenu aplikacije (npr. `app.giftcardpro.at`) prema serveru |
| Registry | Pristup GitHub Container Registryju (`ghcr.io`) s tokenom s pravom `read:packages` |
| E-mail | SMTP pristup pružaoca usluge slanja (predložak: Postmark, `smtp.postmarkapp.com:587`) – `[E-Mail-Versanddienstleister mit EU-Hosting]` |
| Off-site prostor | Hetzner Storage Box (za `rclone`) |
| Menadžer lozinki | Za `APP_KEY`, lozinke baze i Redisa te NTAG 424 ključeve |

Kompletnu instalaciju servera opisuje [Uputstvo za deployment](deployment-guide.md).

## 3. Lokalna instalacija

### 3.1 Pokretanje pozadinskih servisa

```bash
docker compose -f docker-compose.dev.yml up -d
```

Time se pokreću:

| Servis | Port | Pristupni podaci |
|---|---|---|
| MySQL 8.4 | 3306 | Baza `giftcard_pro`, korisnik `giftcard`, lozinka `secret` (root: `root`) |
| Redis 7.4 | 6379 | bez lozinke |
| Mailpit | SMTP 1025, web 8025 | http://localhost:8025 – ovdje stiže svaki e-mail aplikacije |

### 3.2 API (Laravel)

```bash
cd backend
cp .env.example .env
composer install
php artisan key:generate
```

U `.env` prilagodite:

| Varijabla | Vrijednost za dev Compose datoteku |
|---|---|
| `DB_PASSWORD` | `secret` |
| `MAIL_HOST` | `127.0.0.1` |
| `MAIL_PORT` | `1025` |

Zatim kreirajte bazu i pokrenite servise:

```bash
php artisan migrate --seed      # schema + roles/permissions + e-mail templates + demo data (local only)
php artisan serve               # http://localhost:8000
php artisan queue:work          # in a second terminal (e-mails)
php artisan schedule:work       # optional: nightly expiration & reminders
```

> **Način rada bez zavisnosti:** S `DB_CONNECTION=sqlite`, `SESSION_DRIVER=database`, `CACHE_STORE=database` i `QUEUE_CONNECTION=sync` te praznom datotekom `database/database.sqlite` API radi bez MySQL-a i Redisa. Zaključavanje redova pod SQLite nema efekta – za sve osim čistog rada na interfejsu koristite MySQL.

### 3.3 Web aplikacija (Next.js)

```bash
cd dashboard
cp .env.example .env.local      # BACKEND_INTERNAL_URL=http://localhost:8000
npm install
npm run dev                     # http://localhost:3000
```

Dev server prosljeđuje `/api/*` i `/sanctum/*` Laravelu. Pretraživač tako komunicira s jednim jedinim originom, a Sanctum session kolačići rade isto kao u produkciji. Aplikacija je dostupna na **http://localhost:3000** (ne na portu 8000).

### 3.4 Kratka verzija

```bash
docker compose -f docker-compose.dev.yml up -d        # MySQL, Redis, Mailpit

cd backend
cp .env.example .env && composer install && php artisan key:generate
php artisan migrate --seed                             # includes the demo restaurant
php artisan serve                                      # http://localhost:8000

cd ../dashboard
cp .env.example .env.local && npm install
npm run dev                                            # http://localhost:3000
```

## 4. Demo podaci

`php artisan migrate --seed` u okruženjima `local` i `staging` automatski kreira demo restoran. U drugim okruženjima samo uz `SEED_DEMO_DATA=true` – **u produkciji nikada**.

Demo pristupi (lozinka za sve `Password123!`):

| E-mail | Uloga |
|---|---|
| `admin@giftcardpro.test` | Administrator platforme |
| `owner@bellavista.test` | Vlasnik / vlasnica – Trattoria Bella Vista |
| `manager@bellavista.test` | Menadžer |
| `waiter@bellavista.test` | Konobar / konobarica (direktno otvara aplikaciju za konobare) |
| `owner@goldenerhirsch.test` | Vlasnik drugog restorana (za demonstraciju razdvajanja mandanata) |

Resetovanje i ponovno punjenje lokalne baze:

```bash
php artisan migrate:fresh --seed
```

## 5. Instalacija s praznom platformom

Da biste lokalno, kao u produkciji, krenuli bez demo podataka, kreiraju se samo schema i referentni podaci (uloge, dozvole, e-mail predlošci, sistemske postavke):

```bash
php artisan migrate --force && php artisan db:seed --class='Database\Seeders\RolesAndPermissionsSeeder' \
  && php artisan db:seed --class='Database\Seeders\NotificationTemplateSeeder' && php artisan db:seed --class='Database\Seeders\SystemSettingsSeeder'
php artisan platform:create-admin you@company.com --name="Your Name"
```

U produkciji to automatski radi ulazna tačka kontejnera (`infra/docker/php/entrypoint.sh`) pri svakom pokretanju kontejnera `api`: `migrate --force --isolated`, zatim tri referentna seedera. Seederi su idempotentni.

## 6. Prvi administrator platforme

Demo podaci se u produkciji nikada ne kreiraju. Nalog operatera kreira se interaktivno:

```bash
# local
php artisan platform:create-admin you@company.com --name="Your Name"

# production (inside the running API container)
docker compose --env-file .env.production exec api php artisan platform:create-admin you@company.com
```

Zatim:

1. Prijavite se kao administrator platforme.
2. Otvorite **Restaurants → Onboard restaurant** i kreirajte restoran.
3. Vlasnik ili vlasnica dobija e-mail dobrodošlice s linkom za postavljanje lozinke (važi 72 sata).
4. Ako je link istekao: otvorite restoran (**Open restaurant**) → **Team** → **Resend invitation**.

## 7. Prvi restoran

Pri prvoj prijavi vlasnika ili vlasnice dashboard prikazuje panel **Welcome** s četiri koraka, od kojih svaki vodi na odgovarajuću stranicu:

1. **Provjera pravila kartica** (Settings → Gift cards): minimalna/maksimalna vrijednost, standardna važnost, dopune, djelimično iskorištavanje, e-mailovi kupcima. Preporuka: **postavite Default validity na 0 (bez isteka)**, dok pravni savjetnik restorana ne odobri drugi model – fabrička postavka od 36 mjeseci je u Austriji pravno problematična (nije pravni savjet – provjeriti s poreznim savjetnikom/advokatom).
2. **Pozivanje tima** (Team → Invite): menadžeri i konobari dobijaju vlastitu pozivnicu koja važi 72 sata.
3. **Izdavanje prve poklon kartice** (Gift cards → New gift card), zatim upisivanje NFC taga ili štampanje kartice.
4. **Otvaranje režima za konobare na telefonima** (prijava kao konobar – aplikacija za konobare se otvara automatski).

Panel nestaje nakon prve prodaje kartice.

## 8. NFC ključevi (samo za NTAG 424 DNA)

```bash
php artisan giftcard:nfc-keys
```

Oba ispisana ključa upišite u `NTAG424_META_READ_KEY` i `NTAG424_FILE_READ_KEY` i sačuvajte u menadžeru lozinki. Bez tih ključeva već programirane NTAG 424 DNA kartice više se ne mogu provjeriti. Za NTAG213/215/216 i QR kartice ključevi nisu potrebni.

## 9. Pokretanje testova

### 9.1 Backend i frontend

```bash
cd backend && php artisan test          # 113 tests, SQLite in-memory (fast)
cd dashboard && npm run lint && npm run typecheck && npm run build
```

Pojedinačni test suite:

```bash
php artisan test --filter=GiftCardLifecycleTest
```

Statička analiza i stil koda (moraju proći bez grešaka):

```bash
vendor/bin/phpstan analyse      # Larastan, Level 8
vendor/bin/pint --test
```

### 9.2 Testovi protiv MySQL-a

SQLite ne provjerava stvarno zaključavanje redova. Za testove sa stvarnim zaključavanjem:

```bash
docker compose -f docker-compose.dev.yml up -d mysql
mysql -h127.0.0.1 -uroot -proot -e "CREATE DATABASE giftcard_test"
sed -e 's#<env name="DB_CONNECTION" value="sqlite"/>#<env name="DB_CONNECTION" value="mysql"/><env name="DB_HOST" value="127.0.0.1"/><env name="DB_USERNAME" value="root"/><env name="DB_PASSWORD" value="root"/>#' \
    -e 's#<env name="DB_DATABASE" value=":memory:"/>#<env name="DB_DATABASE" value="giftcard_test"/>#' phpunit.xml > phpunit.mysql.xml
php artisan test --configuration=phpunit.mysql.xml
```

CI pipeline pri svakom pushu pokreće testove i sa SQLite i sa MySQL 8.4.

## 10. Test prihvatanja u pretraživaču (E2E)

`e2e/pilot-journey.mjs` prolazi kroz prvi dan novog restorana u stvarnim pretraživačima (desktop za vlasnika, Pixel 7 za konobara) i pada pri svakom neispravnom koraku, svakoj grešci u konzoli i svakom kršenju pristupačnosti:

1. administrator platforme kreira restoran
2. vlasnik/vlasnica prihvata pozivnicu
3. poziva konobara
4. prodaje karticu
5. konobar iskorištava karticu na telefonu (mora ostati ispod 5 sekundi)
6. vlasnik/vlasnica dopunjuje i zamjenjuje „izgubljenu" karticu
7. stara kartica se odbija
8. CSV izvoz (decimalni zarez)
9. axe provjera pristupačnosti (WCAG 2.1 AA)

**Preduslovi:** API s `MAIL_MAILER=log` i `LOG_LEVEL=debug` (linkovi pozivnica čitaju se iz log mailera), web aplikacija na portu 3000, postoji administrator platforme.

```bash
cd e2e
npm install && npx playwright install chromium
ADMIN_EMAIL=admin@giftcardpro.test ADMIN_PASSWORD='Password123!' npm test
```

| Varijabla | Standard |
|---|---|
| `BASE_URL` | `http://localhost:3000` |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | demo administrator |
| `LARAVEL_LOG_DIR` | `../backend/storage/logs/` |
| `CHROMIUM_PATH` | Chromium iz Playwrighta |

Svako pokretanje kreira novi restoran s jedinstvenim adresama, pa se test može pokretati proizvoljno često nad istom bazom. **Pokrenite test prije svakog izdanja.** Referentna vrijednost iz verzije 1.2.0: iskorištavanje kartice od strane konobara za 0,48 s, uključujući unos broja kartice.

## 11. Česti problemi

| Simptom | Uzrok i rješenje |
|---|---|
| `419 CSRF_TOKEN_MISMATCH` pri prijavi | Aplikacija otvorena na portu 8000 umjesto 3000, ili host nedostaje u `SANCTUM_STATEFUL_DOMAINS`. Uvijek koristite http://localhost:3000. |
| E-mailovi ne stižu | `php artisan queue:work` nije pokrenut, ili `MAIL_HOST`/`MAIL_PORT` ne pokazuju na Mailpit. |
| `SQLSTATE[HY000] [1045]` | U `backend/.env` nedostaje `DB_PASSWORD=secret`. |
| Web NFC lokalno ne radi | Web NFC zahtijeva HTTPS (ili `localhost`) i Chrome na Androidu. Za stvarne NFC testove koristite HTTPS okruženje. |
| Noćni poslovi se ne izvršavaju | Pokrenite `php artisan schedule:work`; vremena važe u `SCHEDULE_TIMEZONE` (standard `Europe/Vienna`). |

## Dalje

- [Uputstvo za deployment](deployment-guide.md)
- [Varijable okruženja](environment-variables.md)
- [API dokumentacija](api-documentation.md)

---

Verzija 1.0 · Stanje: septembar 2026.
