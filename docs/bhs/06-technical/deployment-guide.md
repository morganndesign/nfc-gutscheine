# Uputstvo za deployment

*Rad GiftCard Pro kao jednog Coolify resursa: arhitektura, preduslovi, prvi deployment korak po korak, šema baze, ažuriranja, provjere, rollback, noćni poslovi, rješavanje problema i skaliranje. Referenca na engleskom: [docs/DEPLOYMENT.md](../../DEPLOYMENT.md).*

---

## 1. Ciljna arhitektura

GiftCard Pro u produkciji radi kao **jedan Coolify resurs**, izgrađen iz ovog repozitorija pomoću [`docker-compose.coolify.yml`](../../../docker-compose.coolify.yml). Coolify klonira repozitorij, gradi svaki image na vašem serveru, pokreće stack i obezbjeđuje HTTPS. Ne postoji registar kontejnera, gotov image niti korak deploya u GitHub Actions.

```
Internet ──HTTPS──▶ Coolify proxy (TLS certificate for your domain)
                      │
                      ▼ HTTP, internal network
                    gateway :80  (Caddy, infra/docker/gateway)
                      ├─ /api/*  /sanctum/*  /up  ──FastCGI──▶ api :9000   (Laravel, php-fpm)
                      └─ everything else  ─────────HTTP────▶ web :3000   (Next.js dashboard and web till)

  worker    queue:work (every e-mail is sent from the queue)
  scheduler schedule:work (nightly expiry, integrity check, reminders…)
  mysql     MySQL 8.4            volume mysql-data
  redis     Redis 7.4 (AOF)      volume redis-data     sessions, cache, locks, queues
  backup    daily mysqldump      volume mysql-backups  (kept 14 days)
```

| Servis | Izgrađen iz | Javan | Healthcheck | Volumen |
|---|---|---|---|---|
| `gateway` | `infra/docker/gateway/` (Caddy) | **da** – jedini servis s domenom | `GET /gateway-health` | — |
| `api` | `backend/Dockerfile` | ne (preko gatewaya) | php-fpm ping | `laravel-storage` |
| `worker` | `backend/Dockerfile` | ne | provjera procesa | `laravel-storage` |
| `scheduler` | `backend/Dockerfile` | ne | provjera procesa | `laravel-storage` |
| `web` | `dashboard/Dockerfile` | ne (preko gatewaya) | `GET /login` | — |
| `mysql` | image `mysql:8.4` | ne | `mysqladmin ping` | `mysql-data` |
| `redis` | image `redis:7.4-alpine` | ne | `redis-cli ping` | `redis-data` |
| `backup` | image `mysql:8.4` | ne | — | `mysql-backups` |

Svi servisi rade s `restart: unless-stopped`. Zašto gateway: proizvod je **jedan origin** – dashboard, web kasa, API i Sanctum kolačići dijele jednu domenu. Gateway obavlja usmjeravanje po putanji unutar stacka; Coolify treba usmjeriti samo jednu domenu na jedan kontejner.

**Redoslijed pokretanja.** Compose datoteka **nema `depends_on`** – Coolify pokreće svih osam kontejnera odjednom. Redoslijed se osigurava u Laravel kontejnerima (`infra/docker/php/entrypoint.sh`): čeka se da MySQL i Redis prihvataju veze (na svježim volumenima do 15 minuta) → pokreću se migracije (Redis zaključavanje dozvoljava da migrira tačno jedan kontejner, ostali čekaju dok ništa ne ostane na čekanju) → `api` unosi referentne podatke (uloge i dozvole, predlošci e-mailova, sistemske postavke) → start. Do tada gateway za API odgovara s 502. Neuspjela migracija zaustavlja kontejner s greškom u logu (resurs → *Logs*).

## 2. Preduslovi

- Server s **Coolifyjem** (Ubuntu 24.04, ≥ 2 vCPU / 4 GB RAM; Hetzner CX32/CPX31 u Falkensteinu ili Nürnbergu za čuvanje podataka u EU). Instalacija: `curl -fsSL https://cdn.coollabs.io/coolify/install.sh | sudo bash`.
- Domena, npr. `app.giftcardpro.at`, s **A zapisom** (i AAAA za IPv6) prema tom serveru.
- Ovaj repozitorij na GitHubu (privatni je u redu).
- SMTP pristupni podaci servisa za e-mail (Postmark, Mailgun, Brevo, …) – potrebni su za pozivnice i linkove za lozinku.

Firewall: otvoriti samo 22 (SSH, ograničeno na vlastite IP adrese), 80 i 443. Nijedan servis stacka ne objavljuje port hosta.

## 3. Prvi deployment – korak po korak

1. **DNS.** Kreirajte `A  app  →  <IPv4 servera>` (i `AAAA` za IPv6). Sačekajte da `dig +short app.giftcardpro.at` vrati IP. Tek tada Coolify može dobiti certifikat.
2. **Povezivanje GitHuba** (jednom po Coolifyju): *Sources* → *+ Add* → *GitHub App* → pratite čarobnjaka i instalirajte aplikaciju na repozitorij.
3. **Kreiranje resursa:** *Projects* → vaš projekat → *+ New* → *Private Repository (with GitHub App)* → izaberite repozitorij i granu (`main`).
   - **Build Pack:** `Docker Compose`
   - **Base Directory:** `/`
   - **Docker Compose Location:** `/docker-compose.coolify.yml`
   - *Continue*. Coolify čita datoteku i prikazuje servise.
4. **Domena:** na stranici *General* resursa, *Domains for gateway* → `https://app.giftcardpro.at`. Svi ostali servisi ostaju bez domene.
5. **Environment Variables** (resurs → *Environment Variables* → *Developer view*):
   - provjerite da `SERVICE_PASSWORD_MYSQL`, `SERVICE_PASSWORD_MYSQLROOT` i `SERVICE_PASSWORD_REDIS` imaju vrijednosti (Coolify ih generiše) i da `SERVICE_URL_GATEWAY` pokazuje `https://app.giftcardpro.at`;
   - dodajte postavke e-maila iz [`.env.production.example`](../../../.env.production.example): `MAIL_MAILER=smtp`, `MAIL_HOST`, `MAIL_PORT`, `MAIL_SCHEME`, `MAIL_USERNAME`, `MAIL_PASSWORD` (opcionalno: `MAIL_FROM_ADDRESS`, `OPS_ALERT_EMAIL`). Sve ostalo ima produkcijske standarde. Detalji: [Varijable okruženja](environment-variables.md).
6. **Deploy.** Prvi build traje 5–10 minuta (PHP ekstenzije, Composer, Next.js). Na kraju je svih osam servisa *healthy* (pri prvom deployu Laravel servisima treba 1–3 minute: MySQL se inicijalizuje, zatim se pokreću migracije).
7. **Prvi administrator platforme:** resurs → *Terminal* → kontejner **api** →
   ```bash
   php artisan platform:create-admin you@giftcardpro.at --name="Your Name"
   ```
   (traži lozinku, najmanje 12 znakova, velika i mala slova i cifra).
8. **Provjera:**
   - `https://app.giftcardpro.at/up` → zelena stranica („Application up“; provjerava bazu i keš)
   - `https://app.giftcardpro.at/api/v1/app/config?platform=android&version=2.0.0` → JSON
   - `https://app.giftcardpro.at` → stranica za prijavu; prijavite se, kreirajte testni restoran, potvrdite da je stigao e-mail dobrodošlice.
9. **Sačuvajte APP_KEY** (generisan pri prvom deployu): *Terminal* → kontejner **api** → `cat storage/app/.app-key`. Pohranite ga u menadžer lozinki i idealno ga unesite kao `APP_KEY` u Environment Variables (tada ključ više ne zavisi od volumena). Na sistemu koji radi nikada ga ne mijenjajte.
10. **Automatski deploy:** resurs → *Advanced* → *Auto Deploy* uključeno (standard s GitHub App). Svaki push na `main` gradi i uvodi novu verziju; migracije se pokreću automatski.

Ni za jedan od ovih koraka ne treba mijenjati ništa u repozitoriju, i nije potrebna `.env` datoteka: sva konfiguracija dolazi iz Environment Variables Coolify resursa.

## 4. Šema baze podataka

Šemu čini sedam migracija, `backend/database/migrations/2026_01_01_000001` … `000007` (vidi [docs/DATABASE.md](../../DATABASE.md)). Laravel kontejneri pri svakom pokretanju izvršavaju migracije na čekanju. Šema se u potpunosti ponovo instalira sljedećim naredbama (briše sve podatke): *Terminal* → kontejner **api** →

```bash
php artisan migrate:fresh --seed --force
php artisan platform:create-admin you@giftcardpro.at --name="Your Name"
php artisan giftcard:verify-chains
```

MySQL radi s `--log-bin-trust-function-creators=1` (postavljeno u `docker-compose.coolify.yml`), kako bi korisnik aplikacije mogao kreirati append-only okidače.

## 5. Ažuriranja i proces izdanja

1. Sve izmjene su na `main`, CI (`.github/workflows/ci.yml`) je zelen: backend (Pint, Larastan, PHPUnit sa SQLite **i** MySQL 8.4, demo podaci na MySQL-u s naknadnom provjerom integriteta, `composer audit`), dashboard (lint, typecheck, testovi, build, `npm audit`), aplikacija za konobare (analiza, testovi, Android i iOS build) i build Coolify stacka.
2. Dopunite `CHANGELOG.md` (šta i zašto), odredite broj verzije prema SemVer – vidi [Uputstvo za nadogradnju](upgrade-guide.md).
3. Push na `main` (ili *Redeploy*). Coolify gradi nove imageove, zatim zamjenjuje kontejnere; prvi novi Laravel kontejner izvršava migracije na čekanju, a `api`/`worker`/`scheduler` tek nakon toga opslužuju zahtjeve. Tokom zamjene kontejnera nastaje prekid od nekoliko sekundi.
4. Uradite provjere nakon deploymenta (odjeljak 8).

Deployment ne pokrećite tokom glavnog radnog vremena restorana (preporuka: prije podne prije 11:00 ili poslije podne između 14:30 i 17:00 po bečkom vremenu) i ne u 00:15 (istek vaučera), 01:30 UTC (backup) ili 04:00 (provjera integriteta).

Novčane transakcije su idempotentne: ako iskorištavanje tokom zamjene kontejnera naiđe na grešku, aplikacija za konobare i web kasa provjeravaju ishod s istim `Idempotency-Key` (`GET /vouchers/{id}/redemptions/{key}`) – nikada se ne knjiži dvaput.

## 6. Backup

Servis `backup` svakog dana u `BACKUP_TIME` (UTC, standard 01:30) upisuje `giftcard_pro_<UTC vremenska oznaka>.sql.gz` u volumen `mysql-backups` i briše dumpove starije od `BACKUP_KEEP_DAYS` (standard 14). Dumpovi su konzistentni (`--single-transaction`) i sadrže append-only okidače (`--triggers`). Kopija van servera obavezna je za stvarne podatke. Detalji: [Uputstvo za backup](backup-guide.md), vraćanje: [Uputstvo za vraćanje](restore-guide.md).

## 7. Rad

| Zadatak | Gdje |
|---|---|
| Logovi servisa | resurs → *Logs* (svi servisi logiraju na stdout/stderr; Laravel s `LOG_CHANNEL=stderr`) |
| Artisan naredba | *Terminal* → **api** → `php artisan …` (npr. `migrate:status`, `schedule:list`, `queue:failed`) |
| Provjera integriteta odmah | *Terminal* → **api** → `php artisan giftcard:verify-chains` (ponovo izračunava svaki hash lanac i svako stanje vaučera) |
| Promjena postavke | *Environment Variables* → *Redeploy* (konfiguracija se kešira pri pokretanju kontejnera) |
| Nadzor | uptime provjera na `https://<domain>/up`; `OPS_ALERT_EMAIL` dobija e-mail kada red čekanja pređe 500 poslova i kada noćna provjera integriteta ne uspije. Neuspjela provjera integriteta je sigurnosni incident: sačuvajte bazu i backupe prije bilo kakve izmjene |
| Logovi bez tajnih podataka | Access i error logovi gatewaya izostavljaju tokene, e-mail parametre upita, kolačiće, `Authorization`, `X-Device-Id` i `Idempotency-Key`; svaki servis rotira svoj Docker log na 10 MB × 5 datoteka |

## 8. Provjere nakon deploymenta

U Coolifyju: svih osam servisa *healthy*, log deploya bez grešaka. Zatim u *Terminal* kontejnera **api**:

```bash
curl -fsS https://app.giftcardpro.at/up        # from anywhere: 200
php artisan about
php artisan migrate:status
php artisan schedule:list
php artisan queue:failed
php artisan giftcard:verify-chains
```

Funkcionalna provjera (oko 5 minuta):

| Provjera | Očekivanje |
|---|---|
| Prijava kao administrator platforme | stranice platforme se učitavaju, nema crvenog e-mail banera |
| Testni restoran: prodaja vaučera (evidentirati plaćanje) i otvaranje lista za štampu | QR kod i vrijednost vidljivi, bez broja vaučera na listu |
| Aplikacija za konobare na testnom uređaju: skeniranje testnog QR koda | skeniranje s odbrojavanjem, tačno stanje |
| Testno iskorištavanje od 0,01 € na internom testnom vaučeru, zatim storno | knjiženje i protuknjiženje u ledgeru |
| `giftcard:verify-chains` | bez nalaza |
| Uptime monitor | zelen |

## 9. Rollback

### 9.1 Vraćanje aplikacije

Resurs → *Deployments* → izaberite raniji deployment → *Redeploy*. Baza se pri tome ne vraća; backup se vraća samo kod stvarnog gubitka podataka ([Uputstvo za vraćanje](restore-guide.md)).

### 9.2 Migracije i rollback

- Migracije se pri rollbacku **ne** poništavaju automatski. Promjena šeme piše se tako da prethodna verzija nastavi raditi s novijom šemom.
- `php artisan migrate:rollback` u produkciji pokrećite samo nakon provjere dotične migracije i nakon svježeg backupa.
- Ledger, plaćanja i zapisnik aktivnosti nikada se ne ispravljaju rollbackom ili SQL-om; ispravke su novi zapisi (storno, ponovna aktivacija).

### 9.3 Kada raditi rollback

| Situacija | Mjera |
|---|---|
| `/up` nakon deploymenta ne vraća 200 | Provjerite logove (resurs → *Logs*, servis `api`); bez brzog rješenja odmah rollback |
| Skeniranja ili iskorištavanja ne uspijevaju (5xx) | Odmah rollback, zatim analiza |
| Pojedinačne greške u interfejsu bez veze s novcem | Izdanje s ispravkom umjesto rollbacka |

## 10. Noćni poslovi

Kontejner `scheduler` izvršava `schedule:work`. Vremena važe u `SCHEDULE_TIMEZONE` (standard `Europe/Vienna`):

| Vrijeme | Posao |
|---|---|
| 00:15 | `vouchers:expire` – aktivni vaučeri čiji je posljednji dan važenja prošao postaju `expired`; stanje ostaje sačuvano, blokirani vaučeri se preskaču |
| 04:00 | `giftcard:verify-chains` – ponovo izračunava svaki hash lanac i svako stanje; kod nalaza e-mail na `OPS_ALERT_EMAIL` |
| 03:30 | `queue:prune-failed --hours=720` – uklanja neuspjele poslove starije od 30 dana |
| 10:00 | `vouchers:notify-expiring` – jedan podsjetnik po vaučeru sa stanjem, `VOUCHER_EXPIRING_NOTICE_DAYS` prije isteka |
| svakih 15 minuta | `auth:clear-resets` |
| svakih 5 minuta | `queue:monitor redis:default,redis:notifications --max=500` |

Dnevni backup baze radi u servisu `backup` u `BACKUP_TIME` (UTC) – vidi [Uputstvo za backup](backup-guide.md). Provjera: `php artisan schedule:list` u kontejneru `api`.

## 11. Staging

Drugi Coolify resurs iz istog repozitorija i iste Compose datoteke, s vlastitom domenom (npr. `https://staging.giftcardpro.at`) i `APP_ENV=staging` u svojim Environment Variables (grana `main` ili grana `staging`). Ima vlastitu bazu, Redis i volumene. Za staging važe ista pravila kao za produkciju (https URL-ovi).

## 12. Rješavanje problema

| Simptom | Uzrok / rješenje |
|---|---|
| `api`/`worker`/`scheduler` se zaustavljaju s „No public URL“ | Gateway nema domenu. Korak 4. |
| `api` javlja „app.url must be the https URL …“ | Domena gatewaya je `http://…` (npr. sslip.io domena koju generiše Coolify). Koristite `https://` domenu; za brzi test bez vlastite domene radi `https://<bilo šta>.<server-ip>.sslip.io`. |
| `api` se zaustavlja s „DB_PASSWORD is empty“ | Coolify nije generisao `SERVICE_PASSWORD_MYSQL` (starije verzije Coolifyja). Postavite `SERVICE_PASSWORD_MYSQL`, `SERVICE_PASSWORD_MYSQLROOT` i `SERVICE_PASSWORD_REDIS` sami (duge nasumične vrijednosti) **prije** prvog deploya, zatim *Redeploy*. |
| Log `api` ponavlja „MySQL not ready: … Access denied“ nakon promjene lozinke | MySQL volumen zadržava lozinku iz prvog pokretanja. Vratite staru vrijednost ili (samo bez podataka) obrišite volumen `mysql-data`. |
| Host odgovara s `503 no available server` i certifikatom `TRAEFIK DEFAULT CERT` | Taj host **nije dodijeljen nijednom servisu**. Cijeli proizvod, uključujući API, isporučuje `gateway` na svojoj domeni (`https://app.giftcardpro.at/api/v1`). Kontejner `api` namjerno nema Traefik oznake ni HTTP server. Dodatni host dodajte pod *Domains for gateway*, odvojeno zarezom (kanonska domena prva), zatim *Redeploy*. Nikada ne dajte domenu servisu `api`. |
| Certifikat se ne izdaje / „nije sigurno“ | DNS još ne pokazuje na server, ili su portovi 80/443 zatvoreni. |
| 419 / petlja prijave u dashboardu | URL u pretraživaču razlikuje se od domene gatewaya (kolačići su vezani za nju). Koristite tačno konfigurisanu domenu. |
| Deployment se zaustavlja s `required variable SERVICE_… is missing a value` | Fail-fast u `docker-compose.coolify.yml`: nijedan kontejner se ne kreira. `SERVICE_URL_GATEWAY` → dajte servisu **gateway** `https://` domenu (korak 4) i ponovo uvedite. `SERVICE_PASSWORD_*` → provjerite u *Environment Variables* i postavite sami samo ako nedostaju. |
| Pozivnice ili e-mailovi za lozinku nikada ne stižu; crveni baner „E-mails are not delivered“ | `MAIL_MAILER` je još `log`. Postavite `MAIL_MAILER=smtp` i vrijednosti `MAIL_*` (korak 5), *Redeploy*, zatim **System settings → Send test e-mail** i **⋯ → Invite again** za vlasnike koji nisu ništa dobili. Svaki pokušaj je u `notification_logs`. |
| Log se zaustavlja nakon *Pulling & building required images* | Coolify skriva izlaz builda: otvorite deployment i uključite debug prikaz. Prvi build na 2 vCPU / 4 GB traje 5–15 min. Kod nedostatka memorije (`dmesg -T \| grep -i oom`) dodajte swap ili koristite veći server. |
| Build ne uspijeva kod `pecl install redis`, `composer install` ili `npm ci` | Privremeni ispad pecl.php.net, GitHuba ili npm-a. *Redeploy*. |

Ostali slučajevi: [docs/DEPLOYMENT.md → Troubleshooting](../../DEPLOYMENT.md#troubleshooting).

## 13. Skaliranje

| Potreba | Korak |
|---|---|
| Više web saobraćaja | Povećajte `pm.max_children` u `infra/docker/php/www.conf`, dajte serveru više CPU-a; aplikacija je bez stanja (sesije, keš, zaključavanja u Redisu). |
| Baza podataka | Premjestite MySQL na upravljanu bazu: postavite `DB_HOST`, `DB_PASSWORD` itd. i uklonite servise `mysql`/`backup`. |
| Izolacija za velike klijente | Isti repozitorij pokrenite kao zaseban Coolify resurs po klijentu (single tenant) – bez izmjene koda. |

Detalji: [Vodič za performanse](performance-guide.md).

---

Verzija 2.0 · Stanje: septembar 2026.
