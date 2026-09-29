# Uputstvo za instalaciju

*Lokalno razvojno okruženje, preduslovi za produkcijski rad, šema baze, prvi administrator platforme, prvi restoran, demo podaci i testovi za GiftCard Pro. Referenca na engleskom: [docs/INSTALLATION.md](../../INSTALLATION.md).*

---

## 1. Pregled

GiftCard Pro se sastoji od tri aplikacije i pozadinskih servisa:

| Komponenta | Tehnologija | Zadatak |
|---|---|---|
| API | Laravel 12 / PHP 8.4 | Poslovna logika, predočenja, ledger, autentifikacija, pozadinski poslovi |
| Web aplikacija | Next.js 15 / TypeScript | Dashboard, web kasa (`/waiter`), list za štampu vaučera |
| Aplikacija za konobare (GiftCard Waiter) | Flutter, Android i iPhone | QR skeniranje → predočenje → iskorištavanje; prodaja za menadžere i vlasnike |
| Baza podataka | MySQL 8.4 | Mandanti, vaučeri, plaćanja, ledger, zapisnik aktivnosti |
| Redis | 7.x | Sesije, keš, redovi čekanja, ograničenja broja zahtjeva, zaključavanja |
| Mailpit | samo razvoj | Hvata sve e-mailove (web interfejs na portu 8025) |

U razvoju API i web aplikacija rade nativno (hot reload); samo MySQL, Redis i Mailpit rade u Dockeru. U produkciji sve radi kao Coolify resurs – vidi [Uputstvo za deployment](deployment-guide.md). Naredbe korak po korak za svaku komponentu nalaze se i u [RUNNING_THE_PROJECT.md](../../../RUNNING_THE_PROJECT.md).

## 2. Preduslovi

### 2.1 Lokalni razvoj

| Komponenta | Verzija |
|---|---|
| PHP | 8.4 s ekstenzijama `intl`, `pdo_mysql`, `pdo_sqlite`, `gd`, `zip`, `bcmath`, `redis` (ili `predis`) |
| Composer | 2.x |
| Node.js | 22 LTS |
| MySQL | 8.4 |
| Redis | 7.x |
| Docker | 24+ s Compose pluginom (za pozadinske servise) |

Ko radi samo s Dockerom, treba isključivo Docker 24+ s Compose pluginom.

### 2.2 Produkcijski rad

| Oblast | Zahtjev |
|---|---|
| Server | Server s Coolifyjem, Ubuntu 24.04, ≥ 2 vCPU / 4 GB RAM (Hetzner CX32/CPX31 u Falkensteinu ili Nürnbergu, EU) |
| Mreža | Firewall: port 22 (samo vlastite IP adrese), 80, 443 |
| DNS | A/AAAA zapis za domenu aplikacije (npr. `app.giftcardpro.at`) prema serveru |
| Izvorni kod | Repozitorij na GitHubu; Coolify gradi svaki image na serveru |
| E-mail | SMTP pristup pružaoca usluge slanja (predložak: Postmark, `smtp.postmarkapp.com:587`) – `[pružalac usluge slanja e-maila s hostingom u EU]` |
| Pohrana van servera | npr. Hetzner Storage Box (za `rclone`) |
| Menadžer lozinki | Za `APP_KEY` i lozinke koje generiše Coolify |

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
| Mailpit | SMTP 1025, web 8025 | http://localhost:8025 – svaki e-mail aplikacije završava ovdje |

MySQL radi s `--log-bin-trust-function-creators=1`, što je potrebno append-only okidačima.

### 3.2 API (Laravel)

```bash
cd backend
cp .env.example .env
composer install
php artisan key:generate
```

U `.env` postavite `DB_PASSWORD=secret` za dev Compose datoteku. E-mail ne treba postavke: `MAIL_MAILER=failover` šalje na Mailpit kada radi, a inače piše u log.

Zatim kreirajte bazu i pokrenite servise:

```bash
php artisan migrate --seed      # schema + roles/permissions + e-mail templates + settings + demo data (local only)
php artisan serve               # http://localhost:8000
php artisan queue:work          # second terminal: every e-mail is sent from the queue
php artisan schedule:work       # optional: nightly expiry, integrity check and reminders
```

> **Režim bez zavisnosti:** s `DB_CONNECTION=sqlite`, `SESSION_DRIVER=database`, `CACHE_STORE=database` i `QUEUE_CONNECTION=sync` te praznom datotekom `database/database.sqlite` API radi bez MySQL-a i Redisa. Zaključavanje redova pod SQLite-om nema efekta – za sve što se tiče novca ili istovremenosti koristite MySQL.

### 3.3 Web aplikacija (Next.js)

```bash
cd dashboard
cp .env.example .env.local      # BACKEND_INTERNAL_URL=http://localhost:8000
npm install
npm run dev                     # http://localhost:3000
```

Dev server prosljeđuje `/api/*` i `/sanctum/*` Laravelu. Pretraživač tako komunicira s jednim originom, a Sanctum session kolačići rade tačno kao na serveru. Aplikacija je dostupna na **http://localhost:3000** (ne na portu 8000). Skeniranje QR kodova u web kasi zahtijeva kameru i sigurnu stranicu (`https://…` ili `http://localhost`).

### 3.4 Aplikacija za konobare (Flutter)

Aplikacija čita svoje okruženje pri buildu iz `waiter-app/config/<okruženje>.json`; za razvoj `config/development.json` pokazuje na vaš računar. Naredbe i detalji: [waiter-app/README.md](../../../waiter-app/README.md) i [Varijable okruženja](environment-variables.md#4-aplikacija-za-konobare-waiter-appconfigokruženjejson).

### 3.5 Kratka verzija

```bash
docker compose -f docker-compose.dev.yml up -d        # MySQL, Redis, Mailpit

cd backend
cp .env.example .env && composer install && php artisan key:generate
php artisan migrate --seed                             # includes the demo restaurants
php artisan serve                                      # http://localhost:8000

cd ../dashboard
cp .env.example .env.local && npm install
npm run dev                                            # http://localhost:3000
```

## 4. Demo podaci

`php artisan migrate --seed` u okruženjima `local`, `testing` i `staging` automatski kreira demo restorane. U drugim okruženjima samo sa `SEED_DEMO_DATA=true` – **u produkciji nikada** (Coolify stack ga fiksno postavlja na `false`).

Demo pristupi (lozinka za sve `Password123!`):

| E-mail | Uloga |
|---|---|
| `admin@giftcardpro.test` | Administrator platforme |
| `owner@bellavista.test` | Vlasnik/vlasnica – Trattoria Bella Vista |
| `manager@bellavista.test` | Menadžer |
| `waiter@bellavista.test` | Konobar (otvara direktno web kasu) |
| `owner@goldenerhirsch.test` | Vlasnik/vlasnica drugog restorana (za demonstraciju razdvajanja mandanata) |

## 5. Šema baze podataka

Šemu čini sedam migracija, `backend/database/migrations/2026_01_01_000001` … `000007` (vidi [docs/DATABASE.md](../../DATABASE.md)). Prazna baza postavlja se s `php artisan migrate --seed`; postojeća baza u potpunosti se briše i ponovo gradi sljedećom naredbom:

```bash
php artisan migrate:fresh --seed        # drops every table, creates the schema, seeds reference data
```

Referentni podaci (uloge i dozvole, predlošci e-mailova za goste, sistemske postavke) unose se idempotentno; Laravel kontejneri ih unose pri svakom pokretanju. Nakon `migrate:fresh` na serveru ponovo kreirajte administratora platforme (`php artisan platform:create-admin`).

Za lokalni start kao u produkciji, bez demo podataka, kreirajte samo šemu i referentne podatke:

```bash
php artisan migrate --force && php artisan db:seed --class='Database\Seeders\RolesAndPermissionsSeeder' \
  && php artisan db:seed --class='Database\Seeders\NotificationTemplateSeeder' && php artisan db:seed --class='Database\Seeders\SystemSettingsSeeder'
php artisan platform:create-admin you@company.com --name="Your Name"
```

## 6. Prvi administrator platforme

Demo podaci se u produkciji nikada ne kreiraju. Nalog operatera kreira se interaktivno (na serveru: Coolify → *Terminal* → kontejner **api**):

```bash
php artisan platform:create-admin you@company.com --name="Your Name"
```

Zatim:

1. Prijavite se kao administrator platforme i otvorite **System settings → E-mail delivery**: stranica prikazuje mailer i SMTP server. Pritisnite **Send test e-mail** (standardno na vlastitu adresu ili na uneseno sanduče). Crveni baner na stranicama platforme znači da se e-mailovi samo upisuju u log (`MAIL_MAILER=log`).
2. Otvorite **Restaurants → Onboard restaurant** i kreirajte restoran.
3. Vlasnik ili vlasnica dobija e-mail dobrodošlice s linkom za postavljanje lozinke (važi 72 sata). Lista prikazuje stanje pozivnice svakog vlasnika (na čekanju, istekla, nije dostavljena).
4. Ako je link istekao ili je adresa pogrešno upisana: **⋯ → Invite again** (adresa se tu može ispraviti).

## 7. Prvi restoran

Pri prvoj prijavi vlasnika ili vlasnice dashboard prikazuje panel **Welcome** s četiri koraka, od kojih svaki vodi na odgovarajuću stranicu:

1. **Provjera pravila vaučera** (Settings → Vouchers): vrijednosti, granice, važenje, dopune, djelimično iskorištavanje, e-mailovi kupcima. Bez postavke važenja vaučeri nemaju datum isteka; postavljeno važenje iznosi najmanje 36 mjeseci (nije pravni savjet – provjeriti s advokatom).
2. **Pozivanje tima** (Team): menadžeri i konobari dobijaju vlastitu pozivnicu koja važi 72 sata.
3. **Prodaja prvog vaučera** (Vouchers → Sell voucher): evidentirajte plaćanje i odštampajte QR kod.
4. **Instalacija aplikacije za konobare**: konobari se prijavljuju u GiftCard Waiter na telefonima restorana (ili koriste **Redeem** u pretraživaču).

Za obuku osoblja koristite jednostrani [User Guide](../../USER_GUIDE.md); za prvi dan [kontrolnu listu za pilot](../../PILOT_CHECKLIST.md).

## 8. NFC

GiftCard Pro trenutno ne čita, ne upisuje i ne programira NFC tagove; vaučeri se iskorištavaju skeniranjem odštampanog QR koda. Fizičke kartice predviđene su kao NTAG 424 DNA sa živom autentifikacijom preko kripto servisa; njihovi ključevi nalaze se u hardverskom sigurnosnom modulu, nikada u konfiguraciji. Detalji: [docs/NFC.md](../../NFC.md).

## 9. Pokretanje testova

### 9.1 Backend i frontend

```bash
cd backend && php artisan test          # SQLite in memory
cd dashboard && npm run lint && npm run typecheck && npm test && npm run build
```

Pojedinačna grupa testova:

```bash
php artisan test --filter=VoucherLifecycleTest
```

Testovi zloupotrebe (svaka zabranjena radnja se pokušava, i svaka uklonjena putanja) nalaze se u `backend/tests/Feature/Abuse/`.

Statička analiza i stil koda (moraju biti bez grešaka):

```bash
vendor/bin/phpstan analyse      # Larastan
vendor/bin/pint --test
```

### 9.2 Testovi protiv MySQL-a

SQLite ne provjerava stvarno zaključavanje redova. Za testove sa stvarnim zaključavanjem vidi [docs/DEVELOPMENT.md](../../DEVELOPMENT.md#testing-against-mysql). CI pipeline pri svakom pushu pokreće testove i sa SQLite i sa MySQL 8.4, zatim kreira demo podatke na MySQL-u i provjerava sve hash lance i stanja s `php artisan giftcard:verify-chains`.

## 10. Test prihvatanja u pretraživaču (E2E)

`e2e/pilot-journey.mjs` prolazi kroz prvi dan novog restorana u stvarnim pretraživačima (desktop za vlasnika, telefon za konobara) i pada pri svakom neispravnom koraku, svakoj grešci u konzoli i svakom kršenju pristupačnosti:

1. administrator platforme kreira restoran
2. vlasnik/vlasnica prihvata pozivnicu
3. poziva konobara
4. prodaje vaučer za štampu (gotovina)
5. konobar skenira QR kod na telefonu i iskorištava vaučer
6. vlasnik/vlasnica dopunjuje i blokira vaučer
7. sljedeće skeniranje konobara prikazuje ga blokiranim
8. izvoz ledgera
9. axe provjera pristupačnosti (WCAG 2.1 AA)

Kamera telefona se simulira: test web kasi daje tačno onaj QR sadržaj koji se štampa.

**Preduslovi:** API s `MAIL_MAILER=log` i `LOG_LEVEL=debug` (linkovi pozivnica čitaju se iz Laravel loga), web aplikacija na portu 3000, postoji administrator platforme.

```bash
cd e2e
npm install && npx playwright install chromium
ADMIN_EMAIL=admin@giftcardpro.test ADMIN_PASSWORD='Password123!' npm test
```

Ostali tokovi: `npm run test:waiter-api` (API aplikacije za konobare) i `npm run test:admin` (administracija platforme). Svako pokretanje kreira novi restoran s jedinstvenim adresama i zato se može pokretati proizvoljno često nad istom bazom. **Test pokrenite prije svakog izdanja.**

## 11. Česti problemi

| Simptom | Uzrok i rješenje |
|---|---|
| `419 CSRF_TOKEN_MISMATCH` pri prijavi | Aplikacija otvorena preko porta 8000 umjesto 3000, ili host nedostaje u `SANCTUM_STATEFUL_DOMAINS`. Uvijek koristite http://localhost:3000. |
| E-mailovi ne stižu | `php artisan queue:work` ne radi, ili Mailpit ne radi (tada su e-mailovi u logu). |
| `SQLSTATE[HY000] [1045]` | Nedostaje `DB_PASSWORD=secret` u `backend/.env`. |
| Migracija ne uspijeva pri kreiranju okidača | MySQL pokrenut bez `--log-bin-trust-function-creators=1`. Koristite `docker-compose.dev.yml`. |
| QR skener web kase se ne pokreće | Kamera zahtijeva sigurnu stranicu (`https://…` ili `http://localhost`) i dozvolu za kameru u pretraživaču. |
| Noćni poslovi se ne izvršavaju | Pokrenite `php artisan schedule:work`; vremena važe u `SCHEDULE_TIMEZONE` (standard `Europe/Vienna`). |

## Dalje

- [Uputstvo za deployment](deployment-guide.md)
- [Varijable okruženja](environment-variables.md)
- [API dokumentacija](api-documentation.md)

---

Verzija 2.0 · Stanje: septembar 2026.
