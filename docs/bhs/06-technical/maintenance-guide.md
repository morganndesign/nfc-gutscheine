# Uputstvo za održavanje

*Periodični operativni zadaci za GiftCard Pro – dnevno, sedmično, mjesečno, kvartalno – te vremenski prozori održavanja, obavještenje o održavanju i ažuriranje zavisnosti.*

---

## 1. Principi

- Održavanje se obavlja **van radnog vremena** restorana (vidi odjeljak 7).
- Prije svakog zahvata koji utiče na podatke ili shemu: **ručna sigurnosna kopija** ([Uputstvo za sigurnosne kopije](backup-guide.md), odjeljak 2.2).
- Svako održavanje se kratko dokumentuje: datum, osoba, aktivnost, rezultat. Predložak: `[link na operativni protokol]`.
- Ono što radi automatski ipak se redovno **kontroliše**.
- Ledger, plaćanja i zapisnik aktivnosti nikada se ne mijenjaju SQL-om; ispravke su novi zapisi u aplikaciji.

Naredbe se izvršavaju u Coolify *Terminal* resursa (kontejner **api** za `php artisan …`, **backup** za `mysql`/`mysqldump`) ili, gdje je navedeno, na serveru kao root.

## 2. Šta radi automatski

| Zadatak | Mehanizam | Vrijeme |
|---|---|---|
| Istekle vaučere postaviti na `expired` (stanje ostaje) | Scheduler `vouchers:expire` | dnevno 00:15 (Beč) |
| Provjera integriteta: hash lanci i stanja | Scheduler `giftcard:verify-chains` | dnevno 02:30 (Beč) |
| Uklanjanje neuspjelih poslova starijih od 30 dana | Scheduler `queue:prune-failed --hours=720` | dnevno 03:30 (Beč) |
| Podsjetnici e-mailom prije isteka | Scheduler `vouchers:notify-expiring` | dnevno 10:00 (Beč) |
| Uklanjanje isteklih tokena za reset lozinke | Scheduler `auth:clear-resets` | svakih 15 minuta |
| Provjera dužine reda čekanja | Scheduler `queue:monitor … --max=500` | svakih 5 minuta |
| Sigurnosna kopija baze | servis `backup` | dnevno `BACKUP_TIME` (standard 01:30 UTC) |
| Off-site sinhronizacija | root cron na serveru (`rclone`) | dnevno nakon kopije |
| Snapshot servera | Hetzner Backups | dnevno |
| Obnova TLS certifikata | Coolify proxy (Let's Encrypt), automatski prije isteka | kontinuirano |
| Sigurnosna ažuriranja operativnog sistema | `unattended-upgrades` | dnevno |
| Rotacija logova kontejnera | Docker `json-file`, 5 × 10 MB | kontinuirano |
| Provjera zavisnosti | `composer audit`, `npm audit` u `ci.yml` | pri svakom pushu i pull requestu |

## 3. Dnevno (oko 5 minuta)

- [ ] Uptime monitor bez incidenata; u Coolifyju svih osam servisa *healthy*
- [ ] Nema e-maila upozorenja na `OPS_ALERT_EMAIL` (provjera integriteta, zastoj reda čekanja)
- [ ] Današnja kopija postoji i off-site (log servisa `backup`: „Backup written“; `rclone ls storagebox:giftcard-backups | tail -3`)
- [ ] Sigurnosni događaji zadnjih 24 h: log `api` za „Account locked“; u zapisniku aktivnosti `presentment.failed` i `auth.locked`
- [ ] Neuspjeli poslovi: `php artisan queue:failed`
- [ ] Provjereno sanduče podrške za prijave restorana

Detalji: [Vodič za nadzor](monitoring-guide.md#12-rutina-dežurstva).

## 4. Sedmično (oko 30 minuta, npr. utorkom prijepodne)

| Zadatak | Naredba / mjesto |
|---|---|
| Disk i Docker prostor | na serveru: `df -h`, `docker system df` |
| Uklanjanje nepotrebnih imagea | na serveru: `docker image prune -f` |
| Potreban restart nakon ažuriranja kernela? | `ls /var/run/reboot-required` – ako postoji, restart u prozoru održavanja |
| Noćni poslovi izvršeni | `php artisan schedule:list`; log `scheduler`; rezultat `giftcard:verify-chains` |
| Analiza sigurnosnih događaja sedmice | `presentment.failed`/`presentment.rejected` po restoranu i uređaju (upit u [Vodiču za nadzor](monitoring-guide.md#7-sigurnosni-događaji-u-logu)); kontaktirati upadljive restorane |
| Posljednja CI pokretanja na `main` | GitHub Actions: `composer audit` i `npm audit` zeleni? |
| Otvorena sigurnosna upozorenja zavisnosti | GitHub → Security (ako je aktivirano) |

## 5. Mjesečno (oko 2 sata)

### 5.1 Testno vraćanje

Uvezite aktuelni dump u posebnu bazu i izvršite kontrolne upite – postupak: [Uputstvo za vraćanje podataka, scenarij A](restore-guide.md#3-scenarij-a--istraživanje-u-bazi-za-vraćanje). Dokumentujte rezultat (datoteka, trajanje, kontrolni upiti prazni).

### 5.2 API tokeni koji uskoro ističu

Tokeni za integracije ističu nakon najviše `API_TOKEN_MAX_DAYS` (365) dana. Ako token integracije s kasom neprimjetno istekne, integracija prestaje raditi.

```sql
SELECT r.name AS restaurant, t.name AS token, t.expires_at, t.last_used_at
FROM personal_access_tokens t
JOIN restaurants r ON r.id = t.restaurant_id
WHERE t.revoked_at IS NULL AND t.device_id IS NULL
  AND t.expires_at < NOW() + INTERVAL 30 DAY
ORDER BY t.expires_at;
```

Obavijestite pogođene restorane da na vrijeme pod **Settings → API** kreiraju novi token i opozovu stari. Nekorištene tokene (`last_used_at` prazno ili starije od 90 dana) preporučite za opoziv. Tokeni uređaja aplikacije za konobare (`device_id` postavljen) sami se produžavaju dok se telefon koristi.

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

- Administratore platforme koji više nisu u timu: deaktivirati.
- Restorane upozoriti na neprihvaćene pozivnice (**⋯ → Invite again** u administraciji platforme).
- Restoranima preporučiti da pod **Team** deaktiviraju zaposlene koji su otišli i pod **Devices** opozovu nepoznate uređaje.

### 5.4 Audit platforme

U administraciji platforme pregledajte zapisnik aktivnosti za mjesec: kreiranje, suspendovanje, arhiviranje i brisanje restorana, ponovljene pozivnice, izmjene sistemskih postavki, opozvani tokeni.

### 5.5 Certifikat, prostor, baza

- Provjera trajanja certifikata (Coolify proxy ga obnavlja automatski; ispod 14 dana nešto nije u redu): `echo | openssl s_client -connect app.giftcardpro.at:443 -servername app.giftcardpro.at 2>/dev/null | openssl x509 -noout -enddate`
- MySQL binarni logovi zauzimaju prostor u volumenu `mysql-data`: `SHOW BINARY LOGS;` – kod nedostatka prostora provjerite čuvanje (`binlog_expire_logs_seconds`).
- Pratite veličinu velikih tabela (ledger, plaćanja, zapisnik aktivnosti i predočenja stalno rastu):

```sql
SELECT table_name, ROUND((data_length + index_length) / 1024 / 1024) AS mb, table_rows
FROM information_schema.tables WHERE table_schema = DATABASE()
ORDER BY (data_length + index_length) DESC LIMIT 10;
```

### 5.6 Ažuriranje baznih imagea

Svaki deployment ponovo gradi imageove i pri tome preuzima patch ažuriranja za PHP 8.4, Node 22, Caddy i Alpine. Preporuka: najmanje mjesečno ponovo uvesti (dovoljan je *Redeploy*), inače poznati propusti baznih imagea ostaju otvoreni. Pri tome se ponovo povlače i `mysql:8.4` i `redis:7.4-alpine`. Izvršite u prozoru održavanja – restart MySQL-a i Redisa prekida servis na nekoliko sekundi.

## 6. Kvartalno (oko pola dana)

| Zadatak | Detalji |
|---|---|
| Ažuriranje zavisnosti | Odjeljak 8 |
| Vježba oporavka od potpunog gubitka | [Uputstvo za vraćanje podataka, scenarij C](restore-guide.md#5-scenarij-c--potpuni-gubitak-servera) proći na posebnom serveru, izmjeriti vrijeme (RTO), zatim obrisati server |
| Provjera pristupa | SSH ključevi na serveru, Coolify nalozi, članovi GitHub organizacije i GitHub aplikacija Coolifyja, pristup Hetzner Consoleu i Storage Boxu |
| Tajni podaci | Provjera potpunosti menadžera lozinki (`APP_KEY`, SMTP pristupni podaci, `rclone` konfiguracija); postoje ključ za App Store Connect i Android ključ za potpisivanje |
| Firewall | samo 22 (vlastite IP adrese), 80, 443 |
| Kapacitet | Trend RAM-a, CPU-a i diska za posljednja 3 mjeseca; planirati promjenu servera prije nego što se dostigne 70 % |
| Dokumentacija | Uskladiti ova uputstva sa stvarnim stanjem |
| Čuvanje | Sigurnosne kopije, slanje logova, zapisnik aktivnosti u odnosu na zahtjeve iz [Uputstva za sigurnosne kopije](backup-guide.md#7-čuvanje) i [Vodiča za logovanje](logging-guide.md#9-čuvanje-i-gdpr) |

## 7. Vremenski prozori održavanja i obavještenje o održavanju

### 7.1 Vremenski prozori održavanja

| Vrsta | Vremenski prozor (bečko vrijeme) | Najava |
|---|---|---|
| Deployment (prekid od nekoliko sekundi) | pon–čet prije 11:00 ili 14:30–17:00 | nema (changelog) |
| Održavanje s kratkim prekidom (< 5 min) | uto ili sri 06:00–07:00 | 3 radna dana ranije putem obavještenja o održavanju |
| Održavanje s dužim prekidom | uto ili sri 06:00–08:00 | 7 dana ranije putem obavještenja o održavanju i e-maila svim vlasnicima i vlasnicama |
| Hitno održavanje | odmah | što je ranije moguće |

Ne održavati: od petka do nedjelje, praznicima, u 00:15 (istek vaučera), 02:30 (provjera integriteta), a u vrijeme adventa samo u hitnim slučajevima.

### 7.2 Obavještenje o održavanju u aplikaciji

Platforma ima sistemsku postavku `platform.maintenance_notice`: baner koji se prikazuje **svakoj prijavljenoj osobi**, i vrijednost `maintenance_notice` u `/app/config` za aplikaciju za konobare. Prazno = bez banera.

**Preko interfejsa:** administracija platforme → **System settings** → Maintenance notice → unijeti tekst → sačuvati.

**Preko API-ja:**

```bash
curl -X PUT https://app.giftcardpro.at/api/v1/admin/system-settings \
  -b jar.txt -H "X-XSRF-TOKEN: $XSRF" -H "Accept: application/json" -H "Content-Type: application/json" \
  -d '{"settings":[{"key":"platform.maintenance_notice","value":"Planirano održavanje u utorak, 14. oktobra 2026, 06:00–06:30. U tom periodu GiftCard Pro kratko nije dostupan."}]}'
```

(Sesija administratora platforme u pretraživaču; prijava kao u [API dokumentaciji](api-documentation.md#106-prijava-putem-pretraživača-za-testiranje).)

Formulacija: datum, vrijeme, očekivani uticaj, jedna rečenica. Osoblje restorana čita obavještenje u aplikaciji za konobare – neka bude kratko. Nakon održavanja tekst ponovo obrišite.

### 7.3 Laravel režim održavanja

`php artisan down` stavlja API u režim održavanja (HTTP 503 za sve API pozive **uključujući `/up`** – prethodno pauzirajte uptime monitor). U kontejneru **api**:

```bash
php artisan down --retry=60
# … maintenance …
php artisan up
```

Pošto `APP_MAINTENANCE_DRIVER` u produkciji nije postavljen (standard `file`), režim važi samo za kontejner `api` i završava kada se on ponovo kreira (npr. *Redeploy*). U većini slučajeva dovoljni su obavještenje o održavanju i kratak restart; režim održavanja namijenjen je dužim zahvatima na bazi.

## 8. Ažuriranje zavisnosti

### 8.1 Kontinuirano (CI)

`ci.yml` pri svakom pushu na `main` i svakom pull requestu izvršava `composer audit` i `npm audit --omit=dev --audit-level=high`. Crveno pokretanje blokira izdanje dok se propust ne otkloni.

Pošto CI radi samo pri izmjenama, novootkriveni propusti u nepromijenjenim zavisnostima ne prijavljuju se automatski. Preporuke:

- Sedmično ručno pokrenite CI workflow ili lokalno izvršite `composer audit` i `npm audit`.
- Aktivirajte GitHub Dependabot (Security Updates) za `backend/` (Composer), `dashboard/` i `e2e/` (npm), `waiter-app/` (pub) te Dockerfileove.

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
npm run lint && npm run typecheck && npm test && npm run build && npm audit --omit=dev --audit-level=high

cd ../e2e && npm update
```

- Ažurirajte unutar major verzija (Laravel 12, Next.js 15). Prelazak na novu major verziju je poseban projekat – vidi [Uputstvo za nadogradnju](upgrade-guide.md).
- Kreirajte pull request; CI mora biti zelen na SQLite **i** MySQL-u, uključujući provjeru integriteta.
- Prije izdanja pokrenite test prihvatanja.
- Uvedite kao patch ili minor izdanje i zabilježite u changelogu.

## 9. Oslobađanje prostora na disku

| Uzročnik | Provjera | Mjera |
|---|---|---|
| Stari Docker imageovi i build keš | `docker system df` | `docker image prune -f`, `docker builder prune -f` (Coolify ponovo gradi svaki deployment) |
| Lokalni dumpovi | volumen `mysql-backups` | automatski se brišu nakon `BACKUP_KEEP_DAYS` |
| MySQL binarni logovi | `SHOW BINARY LOGS;` | `PURGE BINARY LOGS BEFORE NOW() - INTERVAL 7 DAY;` (samo ako nisu potrebni za point-in-time recovery) |
| Logovi kontejnera | `du -sh /var/lib/docker/containers` | ograničeni na 50 MB po kontejneru |
| Sistemski journal | `journalctl --disk-usage` | `journalctl --vacuum-time=30d` |

## 10. Godišnje

- Obnoviti SSH ključeve i ključeve Storage Boxa.
- Uskladiti ugovore o obradi podataka i listu podizvršitelja obrade sa stvarnom infrastrukturom.
- Ažurirati kontakte za hitne slučajeve i plan dežurstva.
- Vježba oporavka s potpunim zapisnikom (RPO, RTO, rezultat `giftcard:verify-chains`) kao dokaz za TOM.

---

Verzija 2.0 · Stanje: septembar 2026.
