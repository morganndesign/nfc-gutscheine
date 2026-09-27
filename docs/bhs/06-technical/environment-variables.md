# Varijable okruženja

> **Napomena (Coolify deployment):** Produkcija od verzije 1.4.2 radi na **Coolify** sa `docker-compose.coolify.yml` (build iz izvornog koda, bez GHCR-a, bez deploy skripti). Komande sa `docker compose --env-file .env.production`, `infra/scripts/…`, `deploy.yml` ili Caddy na hostu u ovom dokumentu su zastarjele. Mjerodavni su [docs/DEPLOYMENT.md](../../DEPLOYMENT.md) (deployment, backup, restore, rad) i [docs/ENVIRONMENT.md](../../ENVIRONMENT.md).

*Sve konfiguracione varijable za GiftCard Pro – API, web aplikacija, Docker Compose, kontejneri i test prihvatanja – sa standardnom vrijednošću, primjerom, opisom i preporukom za produkciju.*

---

## 1. Konfiguracione datoteke

| Datoteka | Upotreba | Predložak |
|---|---|---|
| `backend/.env` | API lokalno | `backend/.env.example` |
| `backend/.env.production` | API u produkciji (kontejneri `api`, `queue`, `scheduler`, `backup`) | `backend/.env.production.example` |
| `.env.production` (pored `docker-compose.yml`) | Nivo Composea u produkciji | `.env.production.example` |
| `dashboard/.env.local` | Web aplikacija lokalno | `dashboard/.env.example` |

**Legenda kolona:**

- **Lokalno** – vrijednost u `backend/.env.example`
- **Produkcija** – vrijednost u `backend/.env.production.example` odnosno preporuka
- „—" znači: nije postavljeno, važi standard iz `backend/config/*.php`

Izmjene u `backend/.env.production` stupaju na snagu tek nakon ponovnog pokretanja kontejnera, jer ulazna tačka pri svakom pokretanju kešira konfiguraciju (`config:cache`):

```bash
docker compose --env-file .env.production up -d --force-recreate api queue scheduler
```

## 2. API (`backend/.env`)

### 2.1 Aplikacija

| Varijabla | Lokalno | Produkcija | Opis i preporuka |
|---|---|---|---|
| `APP_NAME` | `"GiftCard Pro"` | `"GiftCard Pro"` | Naziv u e-mailovima i standard za prefikse kolačića i keša. |
| `APP_ENV` | `local` | `production` | `local`, `testing`, `staging`, `production`. U `local`/`staging` demo podaci se kreiraju automatski. |
| `APP_KEY` | prazno → `php artisan key:generate` | `base64:…` | Ključ za kolačiće, sesije i šifrovane vrijednosti. Generisanje: `php artisan key:generate --show`. **Ne mijenjati bez plana** – sve sesije postaju nevažeće. Sačuvati u menadžeru lozinki. |
| `APP_DEBUG` | `true` | `false` | U produkciji **obavezno** `false` (stack trace otkriva tajne podatke). |
| `APP_URL` | `http://localhost:8000` | `https://app.giftcardpro.at` | Javni origin API-ja; kod standardne instalacije identičan web aplikaciji. |
| `APP_TIMEZONE` | `UTC` | — | Informativno: `config/app.php` vremensku zonu fiksno postavlja na `UTC`. Sve vremenske oznake pohranjuju se u UTC i preračunavaju po restoranu. |
| `SCHEDULE_TIMEZONE` | `Europe/Vienna` | `Europe/Vienna` | Lokalni sat noćnih poslova: istek kartica 00:15, podsjetnici 10:00, čišćenje 03:30. |
| `APP_LOCALE` | `en` | `en` | Jezik aplikacije (interfejs za osoblje trenutno na engleskom). |
| `APP_FALLBACK_LOCALE` | `en` | — (`en`) | Rezervni jezik. |
| `APP_FAKER_LOCALE` | `de_AT` | `de_AT` | Samo za demo podatke i testove. |
| `APP_MAINTENANCE_DRIVER` | `cache` | — (`file`) | Mjesto pohrane režima održavanja (`php artisan down`). S `file` režim važi samo za kontejner u kojem je naredba izvršena (u praksi `api`). |
| `FRONTEND_URL` | `http://localhost:3000` | `https://app.giftcardpro.at` | Osnova za linkove u e-mailovima (reset lozinke, pozivnice). |
| `CARD_BASE_URL` | `http://localhost:3000` | `https://app.giftcardpro.at` | Osnova URL-a na NFC tagovima i QR kodovima: `{CARD_BASE_URL}/c/{token}`. Ako nije postavljena, koristi se `FRONTEND_URL`. **Promjena nakon upisivanja kartica čini ih neupotrebljivim** – izaberite trajnu domenu. |
| `BCRYPT_ROUNDS` | `12` | — (`12`) | Faktor troška za hash lozinki. Zadržati 12. |

### 2.2 Logovanje

| Varijabla | Lokalno | Produkcija | Opis i preporuka |
|---|---|---|---|
| `LOG_CHANNEL` | `stack` | `stderr` | U kontejnerima `stderr` – Docker prikuplja izlaz. |
| `LOG_STACK` | `daily` | — | Kanali kanala `stack`; `daily` piše `storage/logs/laravel-YYYY-MM-DD.log`. |
| `LOG_LEVEL` | `debug` | `info` | `info` u produkciji. Sigurnosna upozorenja (zaključani nalozi, sumnjiva skeniranja) su `warning`. Lokalno `debug`: `log` mailer piše pozivnice i reset linkove na debug nivou (potrebno za E2E test). |

Standardne Laravel varijable iz `config/logging.php` koje nisu u predlošcima, ali se mogu postaviti: `LOG_DAILY_DAYS` (čuvanje za `daily`, standard 14) i `LOG_STDERR_FORMATTER` (npr. `Monolog\Formatter\JsonFormatter` za JSON izlaz na `stderr`). Vidi [Vodič za logovanje](logging-guide.md).

### 2.3 Baza podataka

| Varijabla | Lokalno | Produkcija | Opis i preporuka |
|---|---|---|---|
| `DB_CONNECTION` | `mysql` | `mysql` | `mysql` (produkcija), `mariadb`, `sqlite` (razvoj/testovi). |
| `DB_HOST` | `127.0.0.1` | `mysql` | U Composeu naziv servisa `mysql`. |
| `DB_PORT` | `3306` | `3306` | |
| `DB_DATABASE` | `giftcard_pro` | `giftcard_pro` | Mora odgovarati `DB_DATABASE` u `.env.production` (Compose). |
| `DB_USERNAME` | `giftcard` | `giftcard` | Kao gore. |
| `DB_PASSWORD` | prazno (dev Compose: `secret`) | `change-me-long-random` | Generisati nasumično (`openssl rand -base64 36`); identično s Compose datotekom. |

### 2.4 Redis, keš, redovi čekanja

| Varijabla | Lokalno | Produkcija | Opis i preporuka |
|---|---|---|---|
| `REDIS_CLIENT` | `phpredis` | `phpredis` | PHP ekstenzija `redis`. |
| `REDIS_HOST` | `127.0.0.1` | `redis` | Naziv servisa u Composeu. |
| `REDIS_PASSWORD` | `null` | `change-me-long-random` | Mora odgovarati `REDIS_PASSWORD` iz Compose datoteke (`requirepass`). |
| `REDIS_PORT` | `6379` | `6379` | |
| `CACHE_STORE` | `redis` | `redis` | Nosi i rate limiting, zaključavanja i keš dozvola. |
| `CACHE_PREFIX` | `giftcardpro` | `giftcardpro` | Prefiks ključeva keša. |
| `QUEUE_CONNECTION` | `redis` | `redis` | E-mailovi idu kroz red `notifications`. |
| `QUEUE_FAILED_DRIVER` | `database-uuids` | `database-uuids` | Neuspjeli poslovi s UUID ključem u `failed_jobs`. |
| `BROADCAST_CONNECTION` | `log` | — | Ne koristi se. |
| `FILESYSTEM_DISK` | `local` | — (`local`) | Aplikacija ne pohranjuje uploadove. |

### 2.5 Sesije i autentifikacija

| Varijabla | Lokalno | Produkcija | Opis i preporuka |
|---|---|---|---|
| `SESSION_DRIVER` | `redis` | `redis` | |
| `SESSION_LIFETIME` | `480` | `480` | Minute neaktivnosti do odjave (jedna smjena). Bez navođenja važi Laravel standard 120. |
| `SESSION_ENCRYPT` | `true` | `true` | Šifrovana pohrana sadržaja sesije. |
| `SESSION_PATH` | `/` | — (`/`) | |
| `SESSION_DOMAIN` | `null` | `app.giftcardpro.at` | Host web aplikacije. |
| `SESSION_SECURE_COOKIE` | `false` | `true` | Kolačić samo preko HTTPS-a. U produkciji obavezno `true`. |
| `SESSION_SAME_SITE` | `lax` | `lax` | Dodatna CSRF zaštita. |
| `SESSION_COOKIE` | `giftcardpro_session` | `giftcardpro_session` | Naziv session kolačića (naveden u izjavi o zaštiti podataka – ne mijenjati). |
| `SANCTUM_STATEFUL_DOMAINS` | `localhost:3000,127.0.0.1:3000` | `app.giftcardpro.at` | Hostovi čiji zahtjevi iz pretraživača koriste sesije s kolačićima (odvojeni zarezom, u razvoju s portom). |
| `SANCTUM_TOKEN_PREFIX` | `gcp_` | `gcp_` | Prefiks API tokena – omogućava secret scanning. |

### 2.6 E-mail

| Varijabla | Lokalno | Produkcija | Opis i preporuka |
|---|---|---|---|
| `MAIL_MAILER` | `smtp` | `smtp` | Za E2E test lokalno `log`. |
| `MAIL_HOST` | `127.0.0.1` (Mailpit) | `smtp.postmarkapp.com` | SMTP server pružaoca usluge slanja. |
| `MAIL_PORT` | `1025` | `587` | |
| `MAIL_USERNAME` | `null` | prazno | Pristupni podaci pružaoca usluge slanja. |
| `MAIL_PASSWORD` | `null` | prazno | Kao gore; tretirati kao tajni podatak. |
| `MAIL_FROM_ADDRESS` | `"no-reply@giftcardpro.app"` | `"no-reply@giftcardpro.at"` | Pošiljalac. Za domenu pošiljaoca postaviti SPF, DKIM i DMARC. |
| `MAIL_FROM_NAME` | `"${APP_NAME}"` | `"${APP_NAME}"` | |

### 2.7 Sigurnost

| Varijabla | Standard | Opis i preporuka |
|---|---|---|
| `SCAN_FAILURE_LIMIT` | `10` | Neuspjeli ili sumnjivi upiti kartica po korisniku **i** po IP prije blokiranja upita. |
| `SCAN_FAILURE_DECAY` | `300` | Vremenski prozor u sekundama za gornju vrijednost. |
| `LOGIN_LOCKOUT_THRESHOLD` | `10` | Uzastopne pogrešne lozinke do zaključavanja naloga. |
| `LOGIN_LOCKOUT_MINUTES` | `15` | Trajanje zaključavanja. |
| `API_TOKEN_MAX_DAYS` | `365` | Maksimalno trajanje tokena za integracije. Prazno = 365. |
| `DEVICE_TOKEN_DAYS` | `30` | Trajanje prijave nativne aplikacije za konobare (GiftCard Waiter). Produžava se dok se telefon koristi; ponovo se mora prijaviti samo telefon koji toliko dugo nije korišten. |

Ove vrijednosti su u `.env.example`, ne u `.env.production.example`; u produkciji bez unosa važe iste standardne vrijednosti. Preporuka: zadržati standardne vrijednosti.

### 2.8 NFC (samo NTAG 424 DNA)

| Varijabla | Standard | Opis i preporuka |
|---|---|---|
| `NTAG424_META_READ_KEY` | prazno | AES-128 ključ (32 hex znaka), dešifruje PICC podatke (UID + brojač dodira). |
| `NTAG424_FILE_READ_KEY` | prazno | AES-128 master ključ za SUN CMAC. |
| `NTAG424_DIVERSIFY_KEYS` | `true` | `true`: MAC ključ po čipu = HMAC-SHA256(master, UID)[0..16]. Preporučeno. |

Generisanje: `php artisan giftcard:nfc-keys`. U produkciji postavite jedinstvene, tajne vrijednosti čim se izdaju NTAG 424 DNA kartice, i sačuvajte ih u menadžeru lozinki. Nakon programiranja kartica više ih ne mijenjajte.

### 2.9 Obavještenja

| Varijabla | Standard | Opis |
|---|---|---|
| `CARD_EXPIRING_NOTICE_DAYS` | `30` | E-mail podsjetnik toliko dana prije isteka. |
| `CARD_LOW_BALANCE_THRESHOLD` | `500` | Centi. E-mail „nisko stanje" kada iskorištavanje padne ispod ove granice (5 €). |
| `OPS_ALERT_EMAIL` | *(adresa podrške)* | Prima operativna upozorenja, npr. red s više od 500 poslova na čekanju (najviše jedan e-mail po redu svakih 30 minuta). Prazno: adresa podrške iz sistemskih postavki. |

### 2.10 Ostalo

| Varijabla | Standard | Opis i preporuka |
|---|---|---|
| `SEED_DEMO_DATA` | `false` | `true` kreira demo restoran i van `local`/`staging`. **U produkciji nikada.** |

## 3. Varijable kontejnera (postavljene u `docker-compose.yml`)

| Varijabla | Vrijednosti | Opis |
|---|---|---|
| `CONTAINER_ROLE` | `app`, `worker`, `scheduler` | Uloga API imagea: PHP-FPM, queue worker ili scheduler. |
| `RUN_MIGRATIONS` | `true` | Samo uloga `app`: `migrate --force --isolated` i referentni seederi pri pokretanju. |

Ove vrijednosti se ne održavaju u `.env` datotekama.

## 4. Web aplikacija (`dashboard/.env.local`)

| Varijabla | Lokalno | Opis |
|---|---|---|
| `BACKEND_INTERNAL_URL` | `http://localhost:8000` | Samo razvoj: cilj na koji `next dev` prosljeđuje putanje `/api` i `/sanctum`. U produkciji Caddy usmjerava te putanje na Laravel prije nego što stignu do Next.js-a. |

Web aplikacija **nema tajnih podataka** – komunicira samo s vlastitim originom.

## 5. Compose (`.env.production` pored `docker-compose.yml`)

| Varijabla | Primjer | Opis i preporuka |
|---|---|---|
| `APP_DOMAIN` | `app.giftcardpro.at` | Javni hostname; Caddy za njega preuzima TLS certifikat. Obavezno. |
| `ACME_EMAIL` | `ops@giftcardpro.at` | E-mail za Let's Encrypt nalog (upozorenja o isteku). Obavezno. |
| `REGISTRY` | `ghcr.io/your-org` | Container registry. Standard `ghcr.io/your-org`. |
| `IMAGE_TAG` | `latest` | Tag imagea koji se pokreće. Deploy pipeline postavlja commit SHA; varijable okruženja shella imaju prednost pred datotekom. |
| `DB_DATABASE` | `giftcard_pro` | Baza koju MySQL kontejner kreira pri prvom pokretanju. |
| `DB_USERNAME` | `giftcard` | Korisnik aplikacije. |
| `DB_PASSWORD` | `change-me-long-random` | Obavezno. Identično s `backend/.env.production`. |
| `DB_ROOT_PASSWORD` | `change-me-long-random` | Obavezno. Root lozinka MySQL-a; samo za administraciju i vraćanje podataka. |
| `REDIS_PASSWORD` | `change-me-long-random` | Obavezno. Identično s `backend/.env.production`. |
| `WAITER_IOS_APP_IDS` | `TEAMID.eu.tapredeem.waiter` | ID-jevi nativne aplikacije za konobare za iPhone Universal Links, format `TEAMID.bundle.id` (odvojeni zarezom). Isporučuje se kao `/.well-known/apple-app-site-association`. Prazno = 404. |
| `WAITER_ANDROID_PACKAGE` | `eu.tapredeem.waiter` | Naziv paketa Android aplikacije za konobare za App Links (`/.well-known/assetlinks.json`). |
| `WAITER_ANDROID_CERT_SHA256` | `AB:CD:…` | SHA-256 otisci certifikata za potpisivanje (Play App Signing, za interne buildove dodatno upload ključ), odvojeni zarezom. |

`DB_*` vrijednosti utiču na MySQL kontejner samo pri **prvom** pokretanju s praznim volumenom `mysql_data`. Kasnije promjene lozinki moraju se dodatno izvršiti u samom MySQL-u (`ALTER USER`).

## 6. Test prihvatanja (`e2e/`)

| Varijabla | Standard | Opis |
|---|---|---|
| `BASE_URL` | `http://localhost:3000` | Adresa web aplikacije |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | demo administrator | Pristup administratora platforme |
| `LARAVEL_LOG_DIR` | `../backend/storage/logs/` | Linkovi pozivnica čitaju se iz log mailera |
| `CHROMIUM_PATH` | Chromium iz Playwrighta | Vlastita putanja pretraživača (opcionalno) |

## 7. GitHub Actions

| Naziv | Tip | Opis |
|---|---|---|
| `DEPLOY_HOST` | Secret | IP ili hostname servera |
| `DEPLOY_USER` | Secret | `deploy` |
| `DEPLOY_SSH_KEY` | Secret | Privatni deploy ključ |
| `DEPLOY_HOST_FINGERPRINT` | Secret | Otisak hosta (ed25519) |
| `GHCR_READ_TOKEN` | Secret | PAT s `read:packages` |
| `APP_DOMAIN` | Variable | Domena za healthcheck nakon deploymenta |

## 8. Kontrolna lista za produkciju

- [ ] `APP_ENV=production`, `APP_DEBUG=false`
- [ ] `APP_KEY` postavljen i u menadžeru lozinki
- [ ] `APP_URL`, `FRONTEND_URL`, `CARD_BASE_URL` s `https://` i trajnom domenom
- [ ] `SESSION_SECURE_COOKIE=true`, `SESSION_DOMAIN` i `SANCTUM_STATEFUL_DOMAINS` = domena aplikacije
- [ ] `LOG_CHANNEL=stderr`, `LOG_LEVEL=info`
- [ ] `DB_PASSWORD`, `DB_ROOT_PASSWORD`, `REDIS_PASSWORD` nasumični i usklađeni u obje datoteke
- [ ] `MAIL_*` sa stvarnim pružaocem usluge slanja; postavljeni SPF/DKIM/DMARC
- [ ] `SEED_DEMO_DATA=false`
- [ ] NTAG 424 ključevi postavljeni (ako se koristi NTAG 424 DNA)
- [ ] `WAITER_IOS_APP_IDS`, `WAITER_ANDROID_PACKAGE`, `WAITER_ANDROID_CERT_SHA256` postavljeni prije prve objave nativne aplikacije za konobare u prodavnicama, kako bi linkovi kartica otvarali aplikaciju

---

Verzija 1.0 · Stanje: septembar 2026.
