# Uputstvo za održavanje

*Periodični operativni zadaci za GiftCard Pro – dnevno, sedmično, mjesečno, kvartalno – te vremenski prozori održavanja, obavještenje o održavanju i ažuriranje zavisnosti.*

---

## 1. Principi

- Održavanje se obavlja **van radnog vremena** restorana (vidi odjeljak 7).
- Prije svakog zahvata koji utiče na podatke ili shemu: **ručna sigurnosna kopija** (`docker compose --env-file .env.production --profile backup run --rm backup`).
- Svako održavanje se kratko dokumentuje: datum, osoba, aktivnost, rezultat. Predložak: `[link na operativni protokol]`.
- Ono što radi automatski ipak se redovno **kontroliše**.

Skraćenica za sve naredbe (na serveru kao `deploy`):

```bash
cd /opt/giftcard-pro
alias dc='docker compose --env-file .env.production'
```

## 2. Šta radi automatski

| Zadatak | Mehanizam | Vrijeme |
|---|---|---|
| Isknjižavanje isteklih kartica | scheduler `giftcards:expire` | dnevno 00:15 (Beč) |
| E-mailovi podsjetnici prije isteka | scheduler `giftcards:notify-expiring` | dnevno 10:00 (Beč) |
| Uklanjanje neuspjelih poslova starijih od 30 dana | scheduler `queue:prune-failed --hours=720` | dnevno 03:30 (Beč) |
| Uklanjanje isteklih tokena za reset lozinke | scheduler `auth:clear-resets` | svakih 15 minuta |
| Provjera dužine reda čekanja | scheduler `queue:monitor … --max=500` | svakih 5 minuta |
| Sigurnosna kopija baze | cron `deploy` | dnevno 02:30 (vrijeme servera) |
| Off-site sinhronizacija | cron `deploy` | dnevno 02:45 (vrijeme servera) |
| Snapshot servera | Hetzner Backups | dnevno |
| Obnova TLS certifikata | Caddy (Let's Encrypt), automatski prije isteka | kontinuirano |
| Sigurnosna ažuriranja operativnog sistema | `unattended-upgrades` | dnevno |
| Rotacija logova kontejnera | Docker `json-file`, 5 × 20 MB | kontinuirano |
| Provjera zavisnosti | `composer audit`, `npm audit` u `ci.yml` | pri svakom pushu i pull requestu |

## 3. Dnevno (oko 5 minuta)

- [ ] Monitor dostupnosti bez incidenata; kontejneri ispravni: `dc ps`
- [ ] Današnja sigurnosna kopija postoji i off-site je: `ls -lh backups | tail -3`, `rclone ls storagebox:giftcard-backups | tail -3`
- [ ] Sigurnosni događaji iz posljednja 24 h: `dc logs --since 24h api | grep -E "Suspicious gift card scan|Account locked"`
- [ ] Neuspjeli poslovi: `dc exec api php artisan queue:failed`
- [ ] Provjeren sandučić podrške za prijave restorana

Detalji: [Vodič za nadzor](monitoring-guide.md#12-rutina-dežurstva).

## 4. Sedmično (oko 30 minuta, npr. utorkom prijepodne)

| Zadatak | Naredba / mjesto |
|---|---|
| Disk i Docker prostor | `df -h`, `docker system df` |
| Uklanjanje nepotrebnih imagea | `docker image prune -f` (dešava se i nakon svakog deploymenta) |
| Potreban restart nakon ažuriranja kernela? | `ls /var/run/reboot-required` – ako postoji, restart u prozoru održavanja |
| Noćni poslovi izvršeni | `dc exec scheduler php artisan schedule:list`; knjiženja `expiration` u ledgeru (vidi Vodič za nadzor) |
| Analiza sigurnosnih događaja u sedmici | `nfc_scans` po rezultatu i restoranu (upit u [Vodiču za nadzor](monitoring-guide.md#7-sigurnosni-događaji-u-logu)); kontaktirati upadljive restorane |
| Posljednja CI pokretanja na `main` | GitHub Actions: `composer audit` i `npm audit` zeleni? |
| Otvorena sigurnosna upozorenja zavisnosti | GitHub → Security (ako je aktivirano) |

## 5. Mjesečno (oko 2 sata)

### 5.1 Testno vraćanje

Uvezite aktuelni dump u posebnu bazu i izvršite kontrolne upite – postupak: [Uputstvo za vraćanje podataka, scenarij A](restore-guide.md#3-scenarij-a--istraživanje-u-bazi-za-vraćanje). Dokumentujte rezultat (datoteka, trajanje, provjera ledgera prazna).

### 5.2 API tokeni koji uskoro ističu

API tokeni ističu nakon najviše 365 dana. Ako token integracije s kasom neprimjetno istekne, integracija prestaje raditi.

```sql
SELECT r.name AS restaurant, t.name AS token, t.expires_at, t.last_used_at
FROM personal_access_tokens t
JOIN restaurants r ON r.id = t.restaurant_id
WHERE t.revoked_at IS NULL
  AND t.expires_at < NOW() + INTERVAL 30 DAY
ORDER BY t.expires_at;
```

Obavijestite pogođene restorane kako bi na vrijeme pod **Settings → API** kreirali novi token i opozvali stari. Nekorištene tokene (`last_used_at` prazno ili starije od 90 dana) preporučite za opoziv.

### 5.3 Pregled korisnika i uređaja

```sql
-- invitations not accepted for more than 7 days
SELECT r.name, u.name, u.email, u.created_at
FROM users u LEFT JOIN restaurants r ON r.id = u.restaurant_id
WHERE u.last_login_at IS NULL AND u.created_at < NOW() - INTERVAL 7 DAY AND u.deleted_at IS NULL;

-- currently locked accounts
SELECT u.email, u.locked_until, u.failed_login_attempts FROM users u WHERE u.locked_until > NOW();

-- platform administrators (should be named persons only)
SELECT u.name, u.email, u.last_login_at FROM users u WHERE u.restaurant_id IS NULL AND u.deleted_at IS NULL;
```

- Administratore platforme koji više nisu u timu: deaktivirajte.
- Ukažite restoranima na neprihvaćene pozivnice (**Resend invitation**).
- Preporučite restoranima da pod **Team** deaktiviraju zaposlene koji su otišli i pod **Devices** opozovu nepoznate uređaje.

### 5.4 Audit platforme

U administraciji platforme pregledajte zapisnik aktivnosti za mjesec: sesije „Open restaurant" administratora platforme (je li razlog poznat?), suspendovanja i reaktivacije restorana, izmjene sistemskih postavki.

### 5.5 Certifikat, prostor, baza

- Provjerite trajanje certifikata (Caddy ga obnavlja automatski; kod < 14 dana nešto nije u redu): `echo | openssl s_client -connect app.giftcardpro.at:443 -servername app.giftcardpro.at 2>/dev/null | openssl x509 -noout -enddate`
- MySQL binarni logovi zauzimaju prostor u volumenu `mysql_data`: `SHOW BINARY LOGS;` – kod nedostatka prostora provjerite čuvanje (`binlog_expire_logs_seconds`).
- Pratite veličinu velikih tabela:

```sql
SELECT table_name, ROUND((data_length + index_length) / 1024 / 1024) AS mb, table_rows
FROM information_schema.tables WHERE table_schema = 'giftcard_pro'
ORDER BY (data_length + index_length) DESC LIMIT 10;
```

### 5.6 Ažuriranje baznih imagea

Novo izdanje (i bez izmjene koda, npr. patch verzija) ponovo gradi imagee i pri tome preuzima patch ažuriranja PHP 8.4, Node 22 i Alpinea. Preporuka: najmanje jedno izdanje mjesečno, inače poznate ranjivosti baznih imagea ostaju otvorene. Imagei `mysql:8.4`, `redis:7.4-alpine` i `caddy:2.8-alpine` ažuriraju se pomoću:

```bash
dc pull mysql redis caddy
dc up -d mysql redis caddy
```

Izvršite u prozoru održavanja – ponovno pokretanje MySQL-a i Redisa prekida servis na nekoliko sekundi.

## 6. Kvartalno (oko pola dana)

| Zadatak | Detalji |
|---|---|
| Ažuriranje zavisnosti | Odjeljak 8 |
| Vježba oporavka od potpunog gubitka | [Uputstvo za vraćanje podataka, scenarij C](restore-guide.md#5-scenarij-c--potpuni-gubitak-servera) proći u posebnom Hetzner projektu, izmjeriti vrijeme (RTO), zatim obrisati server |
| Provjera pristupa | SSH ključevi u `~deploy/.ssh/authorized_keys`, članovi GitHub organizacije, recenzenti environmenta `production`, pristup Hetzner Consoli i Storage Boxu |
| Tajni podaci | Obnoviti `GHCR_READ_TOKEN` (datum isteka PAT-a), provjeriti potpunost menadžera lozinki (`APP_KEY`, NTAG 424 ključevi, sadržaj `.env`, `rclone` konfiguracija) |
| Firewall | Hetzner Cloud Firewall: samo 22 (vlastite IP adrese), 80, 443 |
| Kapacitet | Trend RAM-a, CPU-a i diska u posljednja 3 mjeseca; planirati promjenu servera prije dostizanja 70 % |
| Dokumentacija | Uskladiti ova uputstva sa stvarnim stanjem |
| Čuvanje | Sigurnosne kopije, slanje logova, zapisnik aktivnosti prema zahtjevima iz [Uputstva za sigurnosne kopije](backup-guide.md#7-čuvanje) i [Vodiča za logovanje](logging-guide.md#9-čuvanje-i-gdpr) |

## 7. Vremenski prozori održavanja i obavještenje o održavanju

### 7.1 Vremenski prozori održavanja

| Vrsta | Vremenski prozor (bečko vrijeme) | Najava |
|---|---|---|
| Deployment bez ispada | pon–čet prije 11:00 ili 14:30–17:00 | nema (changelog) |
| Održavanje s kratkim prekidom (< 5 min) | uto ili sri 06:00–07:00 | 3 radna dana ranije putem obavještenja o održavanju |
| Održavanje s dužim prekidom | uto ili sri 06:00–08:00 | 7 dana ranije putem obavještenja o održavanju i e-maila svim vlasnicima i vlasnicama |
| Hitno održavanje | odmah | što je ranije moguće |

Ne održavati: od petka do nedjelje, praznicima, između 00:00 i 00:30 (istek kartica), a u vrijeme adventa samo u hitnim slučajevima.

### 7.2 Obavještenje o održavanju u aplikaciji

Platforma ima sistemsku postavku `platform.maintenance_notice`: baner koji se prikazuje **svakoj prijavljenoj osobi**. Prazno = bez banera.

**Preko interfejsa:** administracija platforme → **System settings** → Maintenance notice → unijeti tekst → sačuvati.

**Preko API-ja:**

```bash
curl -X PUT https://app.giftcardpro.at/api/v1/admin/system-settings \
  -b jar.txt -H "X-XSRF-TOKEN: $XSRF" -H "Accept: application/json" -H "Content-Type: application/json" \
  -d '{"settings":[{"key":"platform.maintenance_notice","value":"Geplante Wartung am Dienstag, 14. Oktober 2026, 06:00–06:30 Uhr. In dieser Zeit ist GiftCard Pro kurz nicht erreichbar."}]}'
```

(Sesija administratora platforme u pretraživaču; prijava kao u [API dokumentaciji](api-documentation.md#96-prijava-putem-pretraživača-za-testiranje). Tekst obavještenja pišite na jeziku restorana – u primjeru na njemačkom za austrijske restorane.)

Formulacija: datum, vrijeme, očekivani uticaj, jedna rečenica. Osoblje restorana čita obavještenje u aplikaciji za konobare – neka bude kratko. Nakon održavanja ponovo ispraznite tekst.

### 7.3 Laravel režim održavanja

`php artisan down` stavlja API u režim održavanja (HTTP 503 za sve API pozive **uključujući `/up`** – prethodno pauzirajte monitor dostupnosti):

```bash
dc exec api php artisan down --retry=60
# … maintenance …
dc exec api php artisan up
```

Pošto `APP_MAINTENANCE_DRIVER` u produkciji nije postavljen (standard `file`), režim važi samo za kontejner `api` i završava se kada se on ponovo kreira. U većini slučajeva dovoljni su obavještenje o održavanju i kratko ponovno pokretanje; režim održavanja namijenjen je dužim zahvatima na bazi.

## 8. Ažuriranje zavisnosti

### 8.1 Kontinuirano (CI)

`ci.yml` pri svakom pushu na `main` i svakom pull requestu izvršava `composer audit` i `npm audit --omit=dev --audit-level=high`. Crveno pokretanje blokira izdanje dok se ranjivost ne otkloni.

Pošto CI radi samo kod izmjena, novootkrivene ranjivosti u nepromijenjenim zavisnostima ne prijavljuju se automatski. Preporuke:

- Sedmično ručno pokrenuti CI workflow ili lokalno izvršiti `composer audit` i `npm audit`.
- Aktivirati GitHub Dependabot (Security Updates) za `backend/` (Composer), `dashboard/` i `e2e/` (npm) te Dockerfileove (trenutno nije postavljeno).

### 8.2 Kvartalno ažuriranje

```bash
git checkout -b chore/dependencies-2026-q4

cd backend
composer outdated --direct
composer update --with-all-dependencies
php artisan test && vendor/bin/phpstan analyse && vendor/bin/pint --test

cd ../dashboard
npm outdated
npm update
npm run lint && npm run typecheck && npm run build && npm audit --omit=dev --audit-level=high

cd ../e2e && npm update
```

- Ažurirati unutar major verzija (Laravel 12, Next.js 15). Promjene major verzija su posebni projekti – vidi [Uputstvo za nadogradnju](upgrade-guide.md).
- Kreirati pull request; CI mora biti zelen na SQLite **i** MySQL.
- Prije izdanja pokrenuti test prihvatanja.
- Uvesti kao patch ili minor izdanje i zabilježiti u changelogu.

## 9. Oslobađanje prostora na disku

| Uzročnik | Provjera | Mjera |
|---|---|---|
| Stari Docker imagei | `docker system df` | `docker image prune -f` (odnosno `docker image prune -a` za sve nekorištene imagee – nakon toga su imagei za rollback samo na GHCR-u) |
| Lokalni dumpovi | `du -sh backups` | automatski se brišu nakon 14 dana |
| MySQL binarni logovi | `SHOW BINARY LOGS;` | `PURGE BINARY LOGS BEFORE NOW() - INTERVAL 7 DAY;` (samo ako nisu potrebni za point-in-time recovery) |
| Logovi kontejnera | `du -sh /var/lib/docker/containers` | ograničeno na 100 MB po kontejneru |
| Sistemski žurnal | `journalctl --disk-usage` | `sudo journalctl --vacuum-time=30d` |
| Log sigurnosne kopije | `ls -lh /var/log/giftcard-backup.log` | dodati logrotate pravilo |

## 10. Godišnje

- Obnoviti deploy SSH ključeve i ključeve Storage Boxa.
- Uskladiti ugovore o obradi podataka po nalogu i listu podizvršitelja obrade sa stvarnom infrastrukturom.
- Ažurirati kontakte za hitne slučajeve i plan dežurstva.
- Vježba oporavka s kompletnim protokolom (RPO, RTO) kao dokaz za TOM.

---

Verzija 1.0 · Stanje: septembar 2026.
