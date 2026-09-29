# Varijable okruženja

*Sve konfiguracione varijable za GiftCard Pro – API, web aplikacija, aplikacija za konobare i Coolify stack – sa standardnom vrijednošću, primjerom, opisom i preporukom za produkciju. Referenca na engleskom: [docs/ENVIRONMENT.md](../../ENVIRONMENT.md).*

---

## 1. Okruženja – jedna strategija za svaku komponentu

Svaka komponenta uzima svoje adrese iz **jednog izvora po okruženju**; nijedna adresa servera nije upisana u kod. Kod sadrži samo lokalne razvojne standarde (`localhost`), i svaka komponenta odbija da radi u stagingu ili produkciji s takvim standardom.

| | Razvoj (vaš računar) | Staging | Produkcija |
|---|---|---|---|
| **Backend** (`backend/`) | `backend/.env` iz `.env.example` · `APP_ENV=local` | Coolify resurs *Environment Variables* (`APP_ENV=staging`, vlastita domena) – referenca: `.env.production.example` | Coolify resurs *Environment Variables* – referenca: `.env.production.example` |
| **Serverski stack** | `docker-compose.dev.yml` (MySQL, Redis, Mailpit; bez varijabli) | `docker-compose.coolify.yml` (ista datoteka) | `docker-compose.coolify.yml` |
| **Web aplikacija** (`dashboard/`) | `dashboard/.env.local` iz `.env.example` (`BACKEND_INTERNAL_URL`) | ništa – isti origin, gateway usmjerava `/api` | ništa – isti origin, gateway usmjerava `/api` |
| **Aplikacija za konobare** (`waiter-app/`) | `config/development.json` (+ vaš `development.local.json`) · `APP_ENV=development` | `config/staging.json` · `APP_ENV=staging` | `config/production.json` · `APP_ENV=production` |

Backend i web aplikacija čitaju postavke **u vrijeme izvršavanja**; aplikacija za konobare čita svoju datoteku **pri buildu** (telefon nema serverske datoteke), pa build aplikacije pripada tačno jednom okruženju.

| Rizik | Zaštita |
|---|---|
| Produkcijska aplikacija komunicira s razvojnim ili staging serverom | Buildovi s `APP_ENV=production` prihvataju samo https i ne mogu promijeniti server u aplikaciji (sačuvana izmjena se ignoriše); `tool/release.sh` odbija konfiguracionu datoteku čiji `APP_ENV` ne odgovara traženom okruženju. |
| Razvojna aplikacija slučajno komunicira s produkcijom | `config/development.json` pokazuje na vaš računar. Build bez konfiguracione datoteke zaustavlja se na „App not set up correctly“ (nema standardne adrese). |
| Prijava jednog servera šalje se drugom | Aplikacija pamti kojem serveru prijava pripada i odbacuje je kada se server razlikuje (bitno na iPhoneu, gdje sva okruženja dijele isti bundle id). |
| Staging/produkcijski API ispisuje `localhost` linkove | API odbija start kada je `APP_ENV` `staging`/`production`, a `APP_URL` ili `FRONTEND_URL` nedostaje, nije https, placeholder je, `localhost`/`127.0.0.1`/`10.0.2.2` ili `*.test`/`*.local` (`App\Support\EnvironmentGuard`). |
| Produkcijska web aplikacija prosljeđuje `/api` na razvojnu mašinu | `BACKEND_INTERNAL_URL` nema standard; postavlja se samo u razvoju (`next dev` se zaustavlja s porukom kada nedostaje). |

Unutar jednog okruženja držite usklađeno: `API_BASE_URL` aplikacije = `APP_URL` + `/api/v1`.

## 2. API (`backend/.env`)

**Kolone:** **Lokalno** – vrijednost u `backend/.env.example`; **Produkcija** – vrijednost u Coolify stacku odnosno preporuka; „—“ znači: nije postavljeno, važi standard iz `backend/config/*.php`.

Izmjene stupaju na snagu tek nakon *Redeploy*, jer kontejneri pri pokretanju keširaju konfiguraciju.

### 2.1 Aplikacija

| Varijabla | Lokalno | Produkcija | Opis i preporuka |
|---|---|---|---|
| `APP_NAME` | `"GiftCard Pro"` | `"GiftCard Pro"` | Naziv u e-mailovima. |
| `APP_ENV` | `local` | `production` | `local`, `testing`, `staging`, `production`. Demo podaci se kreiraju u `local`, `testing` i `staging`. |
| `APP_KEY` | prazno → `php artisan key:generate` | `base64:…` | Ključ za kolačiće, sesije i šifrovane vrijednosti (`php artisan key:generate --show`). Promjena odjavljuje sve i čini šifrovane vrijednosti nečitljivim. Sačuvati u menadžeru lozinki. |
| `APP_DEBUG` | `true` | `false` | Izvan razvoja **obavezno** `false`. |
| `APP_URL` | `http://localhost:8000` | `https://app.giftcardpro.at` | Javni origin API-ja (isti kao web aplikacija). |
| `FRONTEND_URL` | `http://localhost:3000` | `https://app.giftcardpro.at` | Osnova linkova za pozivnice i reset lozinke. |
| `BCRYPT_ROUNDS` | `12` | — (`12`) | Faktor troška za hash lozinki. |
| `APP_TIMEZONE` | `UTC` | — | Zadržati `UTC`: vremenske oznake pohranjuju se u UTC i preračunavaju po restoranu. |
| `SCHEDULE_TIMEZONE` | `Europe/Vienna` | `Europe/Vienna` | Lokalni sat noćnih poslova: istek 00:15, provjera integriteta 02:30, čišćenje 03:30, podsjetnici o isteku 10:00. |
| `APP_LOCALE` | `en` | `en` | Jezik aplikacije. |
| `APP_FALLBACK_LOCALE` | `en` | — (`en`) | Rezervni jezik. |
| `APP_FAKER_LOCALE` | `de_AT` | — | Samo za demo podatke i testove. |
| `APP_MAINTENANCE_DRIVER` | `cache` | — (`file`) | Mjesto pohrane režima održavanja (`php artisan down`). |

### 2.2 Logovanje

| Varijabla | Lokalno | Produkcija | Opis i preporuka |
|---|---|---|---|
| `LOG_CHANNEL` | `stack` | `stderr` | U kontejnerima `stderr` (fiksno postavljeno u Compose stacku). |
| `LOG_STACK` | `daily` | — | Kanali kanala `stack`; `daily` piše `storage/logs/laravel-YYYY-MM-DD.log`. |
| `LOG_LEVEL` | `debug` | `info` | `info` u produkciji (zaključani nalozi bilježe se kao `warning`, neuspjela provjera integriteta kao `critical`). Lokalno `debug`: `log` mailer piše e-mailove na debug nivou. |

Vidi [Vodič za logovanje](logging-guide.md).

### 2.3 Baza podataka, keš, redovi čekanja

| Varijabla | Lokalno | Produkcija | Opis i preporuka |
|---|---|---|---|
| `DB_CONNECTION` | `mysql` | `mysql` | `mysql` (produkcija), `sqlite` (razvoj, testovi). Append-only okidači postoje za MySQL/MariaDB i SQLite. |
| `DB_HOST` / `DB_PORT` | `127.0.0.1` / `3306` | `mysql` / `3306` | U stacku naziv servisa `mysql`. |
| `DB_DATABASE` / `DB_USERNAME` | `giftcard_pro` / `giftcard` | `giftcard_pro` / `giftcard` | U Coolifyju promjenjivo samo prije prvog deploya. |
| `DB_PASSWORD` | prazno (dev Compose: `secret`) | iz `SERVICE_PASSWORD_MYSQL` | Coolify generiše lozinku. |
| `REDIS_HOST` / `REDIS_PORT` / `REDIS_PASSWORD` / `REDIS_CLIENT` | `127.0.0.1` / `6379` / `null` / `phpredis` | `redis` / `6379` / iz `SERVICE_PASSWORD_REDIS` / `phpredis` | Redis za keš, sesije, redove čekanja i ograničenja broja zahtjeva. |
| `CACHE_STORE` | `redis` | `redis` | Nosi i ograničenje broja zahtjeva i zaključavanje nakon neuspjelih skeniranja. |
| `CACHE_PREFIX` | `giftcardpro` | — | Prefiks ključeva keša. |
| `QUEUE_CONNECTION` | `redis` | `redis` | Svaki e-mail šalje se iz reda čekanja (`default`, `notifications`). |
| `QUEUE_FAILED_DRIVER` | `database-uuids` | `database-uuids` | Neuspjeli poslovi s UUID ključem. |

### 2.4 Sesije i autentifikacija

| Varijabla | Lokalno | Produkcija | Opis i preporuka |
|---|---|---|---|
| `SESSION_DRIVER` | `redis` | `redis` | |
| `SESSION_LIFETIME` | `480` | `480` | Minute neaktivnosti do odjave (cijela smjena). |
| `SESSION_ENCRYPT` | `true` | `true` | Sadržaj sesije pohranjuje se šifrovano. |
| `SESSION_SECURE_COOKIE` | `false` | `true` | Kolačić samo preko HTTPS-a. Na serverima obavezno `true`. |
| `SESSION_SAME_SITE` | `lax` | `lax` | |
| `SESSION_DOMAIN` | `null` | `app.giftcardpro.at` | Host web aplikacije. |
| `SESSION_COOKIE` | `giftcardpro_session` | — | Naziv session kolačića. |
| `SANCTUM_STATEFUL_DOMAINS` | `localhost:3000,127.0.0.1:3000` | `app.giftcardpro.at` | Hostovi čiji zahtjevi iz pretraživača koriste sesije s kolačićima (odvojeno zarezom, u razvoju s portom). |
| `SANCTUM_TOKEN_PREFIX` | `gcp_` | `gcp_` | Prefiks tokena – omogućava secret scanning. |

### 2.5 Sigurnost

| Varijabla | Standard | Opis i preporuka |
|---|---|---|
| `PRESENTMENT_FAILURE_LIMIT` | `10` | Neuspjela skeniranja vaučera po restoranu, osobi i uređaju prije kratkog zaključavanja (`429 PRESENTMENT_THROTTLED`). |
| `PRESENTMENT_FAILURE_DECAY` | `300` | Vremenski prozor u sekundama za gornju vrijednost. |
| `LOGIN_LOCKOUT_THRESHOLD` | `10` | Uzastopne pogrešne lozinke do zaključavanja naloga. |
| `LOGIN_LOCKOUT_MINUTES` | `15` | Trajanje zaključavanja. |
| `API_TOKEN_MAX_DAYS` | `365` | Maksimalno trajanje tokena za integracije. |
| `DEVICE_TOKEN_DAYS` | `30` | Trajanje prijave u aplikaciji za konobare; produžava se dok se telefon koristi. |

Fiksno u `config/giftcard.php`: važenje skeniranja 60 s, prozor ponavljanja prodaje 15 min, dužina idempotency ključa ≤ 96. Preporuka: zadržati standardne vrijednosti.

### 2.6 Granice vaučera (gornje granice platforme)

| Varijabla | Standard | Opis |
|---|---|---|
| `LIMIT_MAX_VOUCHER_BALANCE` | `50000` | Najveći `max_voucher_balance` koji restoran smije postaviti (centi). |
| `LIMIT_MAX_DEBIT_PER_TRANSACTION` | `25000` | Najveći `max_debit_per_transaction`. |
| `LIMIT_MAX_DEBIT_PER_VOUCHER_PER_DAY` | `50000` | Najveći `max_debit_per_voucher_per_day`. |

Važenje u restoranu iznosi najmanje 36 mjeseci (`min_validity_months`, fiksno).

### 2.7 E-mail i obavještenja

| Varijabla | Standard | Opis |
|---|---|---|
| `MAIL_MAILER` | `failover` (razvoj), `log` (Coolify standard) | `smtp` za stvarnu dostavu. S `log` e-mailovi se samo upisuju u log, a administracija platforme prikazuje crveni baner. |
| `MAIL_HOST`, `MAIL_PORT`, `MAIL_SCHEME`, `MAIL_USERNAME`, `MAIL_PASSWORD` | | SMTP server (`MAIL_SCHEME`: `smtp` = STARTTLS na 587, `smtps` = TLS na 465). Pristupne podatke tretirati kao tajnu. |
| `MAIL_FROM_ADDRESS`, `MAIL_FROM_NAME` | `no-reply@<domain>`, `GiftCard Pro` | Pošiljalac. Za domenu pošiljaoca postaviti SPF, DKIM i DMARC. |
| `MAIL_TIMEOUT` | `10` | Sekunde prije odustajanja od sporog mail servera (posao se ponavlja). |
| `MAIL_LOCALE` | `de` | Jezik e-mailova s pozivnicom kada za jezik restorana nema prevoda. |
| `MAIL_VERIFY_DOMAINS` | `true` | *Send test e-mail* odbija domenu primaoca bez mail servera. |
| `VOUCHER_EXPIRING_NOTICE_DAYS` | `30` | Podsjetnik o isteku toliko dana prije posljednjeg dana važenja. |
| `OPS_ALERT_EMAIL` | *(adresa podrške)* | Operativna upozorenja: red čekanja s više od 500 poslova, neuspjela provjera integriteta. |

### 2.8 Samo razvoj

| Varijabla | Opis |
|---|---|
| `CRYPTO_PROVIDER` | `local` (zadano): ključevi u jednoj šifrovanoj datoteci ključeva. Svako korištenje ključa ide preko `App\Crypto\CryptoProvider`; HSM pružalac ga zamjenjuje bez promjene koda. |
| `CRYPTO_KEYSTORE_PATH` | Datoteka ključeva (zadano `storage/app/private/crypto/keystore.json`), u kontejneru trajni volumen; praviti rezervnu kopiju. |
| `CRYPTO_KEYSTORE_KEY` | Glavni ključ datoteke ključeva: `base64:` + 32 nasumična bajta (`openssl rand -base64 32`). Jedini ključ u okruženju; čuvati odvojeno od datoteke ključeva. Promjena: `CRYPTO_KEYSTORE_NEW_KEY` + `php artisan crypto:keystore:rekey`. |
| `SEED_DEMO_DATA` | `true` kreira demo restorane i izvan `local`/`testing`/`staging`. Coolify stack ga fiksno postavlja na `false`. |

## 3. Web aplikacija (`dashboard/.env.local`)

| Varijabla | Lokalno | Opis |
|---|---|---|
| `BACKEND_INTERNAL_URL` | `http://localhost:8000` | Samo razvoj: kamo `next dev` prosljeđuje `/api` i `/sanctum`. Na serverima gateway (Caddy, `infra/docker/gateway`) usmjerava ove putanje na Laravel prije nego što stignu do Next.js-a. |

Web aplikacija **nema tajnih podataka** – komunicira samo sa svojim originom.

## 4. Aplikacija za konobare (`waiter-app/config/<okruženje>.json`)

| Ključ | Opis |
|---|---|
| `APP_ENV` | `development`, `staging`, `production`. http je dozvoljen samo u razvoju; razvoj i staging imaju vlastiti Android application id i oznaku u uglu. |
| `API_BASE_URL` | Korijen API-ja, završava na `/api/v1`. |
| `APP_STORE_URL` | Stranica u App Storeu koju otvara „Update required“ (iOS produkcija). |
| `PLAY_STORE_URL` | Opcionalno; standard je Play stranica paketa. |

## 5. Produkcija i staging (Coolify)

Serverski stack je `docker-compose.coolify.yml`; njegove varijable postavljaju se u Coolifyju (resurs → *Environment Variables*). **Svaka varijabla ima funkcionalan standard** – komentarisana lista je [`.env.production.example`](../../../.env.production.example). Gore navedene Laravel varijable kojih tamo nema fiksno su postavljene u Compose datoteci (Redis sesije, sigurni kolačići, `LOG_CHANNEL=stderr`, `SEED_DEMO_DATA=false`) ili zadržavaju standard iz `config/giftcard.php`.

| Postavlja | Varijable |
|---|---|
| Coolify, automatski | `SERVICE_URL_GATEWAY` / `SERVICE_FQDN_GATEWAY` (domena servisa `gateway` → `APP_URL`, `FRONTEND_URL`, `SESSION_DOMAIN`, `SANCTUM_STATEFUL_DOMAINS`, standard za `MAIL_FROM_ADDRESS`, izvedeno u `infra/docker/php/entrypoint.sh`), `SERVICE_PASSWORD_MYSQL`, `SERVICE_PASSWORD_MYSQLROOT`, `SERVICE_PASSWORD_REDIS` |
| Prvi deploy, automatski | `APP_KEY` (čuva se u volumenu `laravel-storage`, osim ako sami ne postavite `APP_KEY`) |
| Vi (potrebno za stvarni rad) | `MAIL_MAILER=smtp` i vrijednosti `MAIL_*` |
| Vi (opcionalno) | `APP_ENV` (`staging`), `APP_URL`, `APP_LOCALE`, `OPS_ALERT_EMAIL`, `MAIL_LOCALE`, `MAIL_TIMEOUT`, `SCHEDULE_TIMEZONE`, `LOG_LEVEL`, `BACKUP_TIME`, `BACKUP_KEEP_DAYS`, `DB_DATABASE`/`DB_USERNAME` (samo prije prvog deploya) |

Servisu `web` nisu potrebne varijable. Ključevi kartica nikada nisu u varijablama okruženja.

## 6. Kontrolna lista za produkciju

- [ ] Domena gatewaya postavljena s `https://` (iz nje slijede `APP_URL`, `FRONTEND_URL`, `SESSION_DOMAIN`, `SANCTUM_STATEFUL_DOMAINS`)
- [ ] `SERVICE_PASSWORD_MYSQL`, `SERVICE_PASSWORD_MYSQLROOT`, `SERVICE_PASSWORD_REDIS` generisao Coolify
- [ ] `APP_KEY` sačuvan (menadžer lozinki) i idealno postavljen kao varijabla
- [ ] `MAIL_MAILER=smtp` i `MAIL_*` sa stvarnim pružaocem usluge slanja; postavljeni SPF/DKIM/DMARC; testni e-mail uspješan
- [ ] `OPS_ALERT_EMAIL` dolazi do nekoga ko reaguje na operativna upozorenja
- [ ] Aplikacija za konobare buildovana s `config/production.json`; `API_BASE_URL` = `APP_URL` + `/api/v1`

---

Verzija 2.0 · Stanje: septembar 2026.
