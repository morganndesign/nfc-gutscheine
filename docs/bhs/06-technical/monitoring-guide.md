# Vodič za nadzor (monitoring)

*Nadzor GiftCard Pro u produkciji: healthcheck, dostupnost, kontejneri, red čekanja, scheduler, pokazatelji, pravila uzbune, dashboardi i rutina dežurstva.*

---

## 1. Ciljevi

Aplikacija za konobare koristi se tokom usluživanja. Ispad u petak navečer znači da gosti ne mogu iskoristiti svoju karticu. Nadzor zato treba:

1. prijaviti ispad u roku od 2 minute,
2. učiniti vidljivim pokušaje prevare (klonirane ili kopirane kartice, napadi na lozinke),
3. rano prepoznati postepene probleme (pun disk, rastući red čekanja, nedostajuće sigurnosne kopije), prije ispada.

Ciljana dostupnost prema ponudi: 99,5 % mjesečno (cilj, ne garancija u paketu Start).

## 2. Healthcheck `/up`

| Svojstvo | Vrijednost |
|---|---|
| URL | `https://<APP_DOMAIN>/up` (Caddy ga prosljeđuje Laravelu) |
| Uspjeh | HTTP 200 |
| Provjerava | PHP-FPM i Laravel rade, **baza** odgovara (`select 1`), **keš** (Redis) se može pisati i čitati |
| Greška | HTTP 500 kada baza ili keš nisu dostupni |
| Koriste ga | `deploy.sh` (nakon svakog deploymenta), eksterni nadzor dostupnosti |

`/up` ne provjerava web aplikaciju (Next.js). Zato dodatno nadzirite početnu stranicu.

## 3. Nadzor dostupnosti (eksterni)

Koristite eksterni servis (npr. Better Stack, UptimeRobot) koji **ne** radi na istom serveru.

| Monitor | URL | Interval | Očekivanje | Uzbuna nakon |
|---|---|---|---|---|
| API + baza + keš | `https://app.giftcardpro.at/up` | 1 min | status 200 | 2 neuspjeha |
| Web aplikacija | `https://app.giftcardpro.at/login` | 1 min | status 200 | 2 neuspjeha |
| TLS certifikat | `app.giftcardpro.at:443` | dnevno | važi > 14 dana | odmah |
| Heartbeat sigurnosne kopije | heartbeat URL iz [Uputstva za sigurnosne kopije](backup-guide.md#6-nadzor-poslova-kopiranja) | dnevno | signal do 03:30 (vrijeme servera) | izostanku signala |

Preporuka: javna statusna stranica servisa za nadzor na `[status.giftcardpro.at]` za restorane.

## 4. Ispravnost kontejnera

| Servis | Healthcheck (u `docker-compose.yml`) | Interval |
|---|---|---|
| `api` | `pgrep -f "php-fpm: master"` (tek nakon migracije i izgradnje keša), početni prozor 120 s | 10 s |
| `queue` | `pgrep -f queue:work` | 30 s |
| `scheduler` | `pgrep -f schedule:work` | 30 s |
| `mysql` | `mysqladmin ping` | 10 s, 10 pokušaja |
| `redis` | `redis-cli ping` | 10 s, 10 pokušaja |
| `caddy`, `web` | bez healthchecka | – |

Svi servisi rade s `restart: unless-stopped`: Docker ponovo pokreće kontejnere koji su pali, ali **ne** kontejnere koji su samo označeni kao `unhealthy`.

Provjera:

```bash
cd /opt/giftcard-pro
docker compose --env-file .env.production ps
docker ps --filter health=unhealthy
docker stats --no-stream
```

Preporuka: cron posao koji svakih 5 minuta provjerava `docker ps --filter health=unhealthy --format '{{.Names}}'` i alarmira ako izlaz nije prazan.

## 5. Red čekanja (queue)

### 5.1 Šta radi u redu čekanja

Queue workeri (`queue`) obrađuju Redis redove `default` i `notifications` (`--tries=5`, ponovno pokretanje nakon 1 sata ili 1.000 poslova). U `notifications` su e-mailovi kupcima (kupovina, dopuna, podsjetnik o isteku, nisko stanje) i pozivnice.

### 5.2 Monitor reda čekanja

Scheduler svakih 5 minuta izvršava:

```
queue:monitor redis:default,redis:notifications --max=500
```

Ako je u redu više od 500 poslova, Laravel pokreće događaj `QueueBusy`.

> **Obavještenje:** listener `AlertOnQueueBacklog` tada upisuje zapis nivoa `critical` u log i šalje e-mail na `OPS_ALERT_EMAIL` (ako je prazno: adresa podrške iz sistemskih postavki) – najviše jednom po redu svakih 30 minuta. E-mail se šalje direktno, ne preko reda, kako bi stigao i kada worker ne radi.

Ručna provjera:

```bash
docker compose --env-file .env.production exec api php artisan queue:monitor redis:default,redis:notifications --max=500
docker compose --env-file .env.production exec api php artisan queue:failed
```

| Nalaz | Značenje | Mjera |
|---|---|---|
| Red > 0 duže vrijeme, raste | Worker je zaglavio ili ne radi | `docker compose … logs queue`, `docker compose … restart queue` |
| Mnogo neuspjelih poslova | Slanje e-maila poremećeno (pristupni podaci, limit pružaoca usluge) | Otkloniti uzrok, zatim `php artisan queue:retry all` |

Neuspjeli poslovi uklanjaju se dnevno u 03:30 nakon 30 dana (`queue:prune-failed --hours=720`).

## 6. Scheduler

```bash
docker compose --env-file .env.production exec scheduler php artisan schedule:list
```

Očekivani unosi (vremena u `SCHEDULE_TIMEZONE`, standard `Europe/Vienna`):

| Naredba | Raspored |
|---|---|
| `giftcards:expire` | dnevno 00:15 |
| `giftcards:notify-expiring` | dnevno 10:00 |
| `queue:prune-failed --hours=720` | dnevno 03:30 |
| `auth:clear-resets` | svakih 15 minuta |
| `queue:monitor redis:default,redis:notifications --max=500` | svakih 5 minuta |

Dokaz da je posao isteka izvršen: u zapisniku aktivnosti odnosno ledgeru pojavljuju se knjiženja tipa `expiration` s vremenskom oznakom neposredno nakon 00:15 po bečkom vremenu (samo ako su tog dana istekle kartice).

```sql
SELECT DATE(created_at) AS day, COUNT(*) FROM gift_card_transactions
WHERE type = 'expiration' AND created_at > NOW() - INTERVAL 7 DAY GROUP BY day;
```

## 7. Sigurnosni događaji u logu

Dvije poruke pišu se na nivou `warning` i pogodne su za uzbune:

| Poruka u logu | Polja konteksta | Okidač |
|---|---|---|
| `Suspicious gift card scan` | `result`, `method`, `restaurant_id`, `user_id`, `device_id`, `ip`, `nfc_uid`, `request_id` | Skeniranje s rezultatom `foreign_restaurant`, `uid_mismatch`, `invalid_signature`, `replay` ili `throttled` (ne kod `ok` i `not_found`) |
| `Account locked after repeated failed logins` | `user_id`, `ip`, `attempts`, `request_id` | 10 uzastopnih pogrešnih lozinki (`LOGIN_LOCKOUT_THRESHOLD`) |

Pretraga:

```bash
docker compose --env-file .env.production logs --since 24h api | grep -E "Suspicious gift card scan|Account locked"
```

Dodatno, tabela `nfc_scans` sadrži svaki upit kartice:

```sql
SELECT restaurant_id, result, COUNT(*) AS n
FROM nfc_scans
WHERE created_at > NOW() - INTERVAL 1 DAY AND result <> 'ok'
GROUP BY restaurant_id, result ORDER BY n DESC;
```

## 8. Pokazatelji

| Pokazatelj | Izvor | Normalan raspon (orijentacija) | Upozorenje |
|---|---|---|---|
| Dostupnost `/up` | monitor dostupnosti | 100 % | svaki ispad |
| Vrijeme odgovora `/up` | monitor dostupnosti | < 300 ms | > 1 s duže od 5 min |
| Udio HTTP 5xx | Caddy access log (JSON, polje `status`) | ~0 | > 1 % duže od 5 min |
| Broj HTTP 429 | Caddy access log | nizak | nagli porast (napad ili preusko ograničenje) |
| Dužina reda čekanja | `queue:monitor` | 0 – nekoliko | > 500 |
| Neuspjeli poslovi | `queue:failed` | 0 | > 0 novih dnevno |
| Sumnjiva skeniranja | log / `nfc_scans` | 0 | ≥ 1 (info), ≥ 5 na sat po restoranu (upozorenje) |
| Zaključavanja naloga | log | rijetko | ≥ 3 na sat |
| Disk | `df -h` | < 70 % | > 80 % |
| RAM | `free -m`, `docker stats` | < 75 % | > 90 % |
| Memorija Redisa | `redis-cli INFO memory` | niska | raste; kod `noeviction` puna memorija dovodi do grešaka pri pisanju (sesije, red čekanja) |
| MySQL konekcije | `SHOW STATUS LIKE 'Threads_connected'` | niske | blizu `max_connections` |
| Starost sigurnosne kopije | datotečni sistem, heartbeat | < 24 h | > 26 h |
| Trajanje certifikata | monitor dostupnosti | > 30 dana | < 14 dana |

Orijentacione vrijednosti su procjene za pilot fazu i treba ih prilagoditi nakon prvih sedmica prema stvarnim vrijednostima.

## 9. Pravila uzbune

| Prioritet | Pravilo | Reakcija |
|---|---|---|
| **P1 – odmah** | `/up` ili web aplikacija nedostupni (2 provjere) | dežurstvo odmah, i navečer |
| **P1** | HTTP 5xx > 5 % duže od 5 min | odmah |
| **P1** | Kontejner `api`, `mysql` ili `redis` unhealthy | odmah |
| **P2 – isti dan** | `Suspicious gift card scan` s `uid_mismatch`, `invalid_signature` ili `replay` | obavijestiti restoran, provjeriti karticu, po potrebi blokirati |
| **P2** | ≥ 3 `Account locked` na sat, ili više naloga s jedne IP adrese | provjeriti IP, po potrebi blokirati u firewallu |
| **P2** | Red > 500 ili novi neuspjeli poslovi | provjeriti slanje e-maila |
| **P2** | Sigurnosna kopija starija od 26 h ili neuspjela off-site sinhronizacija | ručno napraviti kopiju |
| **P2** | Disk > 80 % | očistiti (odjeljak 9 [Uputstva za održavanje](maintenance-guide.md#9-oslobađanje-prostora-na-disku)) |
| **P3 – sedmična rutina** | Certifikat < 30 dana, `composer audit`/`npm audit` prijavljuje ranjivosti | isplanirati |

Pravila zasnovana na logovima (P2 sigurnost) pretpostavljaju slanje logova (vidi [Vodič za logovanje](logging-guide.md#slanje-logova-preporuka)). Bez slanja logova: dnevni cron posao s `grep` upitom iz odjeljka 7 koji rezultat šalje e-mailom.

## 10. Praćenje grešaka (opcionalno)

Za izuzetke sa stack traceom može se dodati Sentry (`sentry/sentry-laravel` u backendu, `@sentry/nextjs` u frontendu). Oba paketa trenutno **nisu** instalirana; integracija je izmjena koda s vlastitim izdanjem. Pri upotrebi filtrirajte lične podatke (`send_default_pii` ostaviti deaktivirano) i izaberite lokaciju podataka u EU.

## 11. Dashboardi (prijedlog)

| Dashboard | Sadržaj |
|---|---|
| **Rad sistema** | dostupnost, vrijeme odgovora `/up`, stopa 5xx, zahtjevi po minuti (Caddy), status kontejnera, CPU/RAM/disk |
| **Pozadina** | dužina reda čekanja, neuspjeli poslovi, posljednje izvršavanje noćnih poslova, starost sigurnosne kopije |
| **Sigurnost** | sumnjiva skeniranja po rezultatu i restoranu, zaključavanja naloga, odgovori 429, IP adrese s najviše 4xx |
| **Poslovanje** (platforma) | aktivni restorani, izdate kartice, iskorištavanja po danu – iz `GET /admin/stats` odnosno SQL-a |

Provedba npr. s Grafana + Loki (slanje logova preko Promtaila ili Vectora) ili direktno u dashboardu log servisa s lokacijom u EU.

## 12. Rutina dežurstva

### 12.1 Dnevno (5 minuta, prijepodne)

- [ ] Monitor dostupnosti: bez incidenata u posljednja 24 h
- [ ] `docker compose … ps`: svi servisi `running`/`healthy`
- [ ] Današnja sigurnosna kopija postoji, off-site sinhronizovana
- [ ] Sigurnosne poruke iz posljednja 24 h provjerene
- [ ] `queue:failed` prazan

### 12.2 Vrijeme dežurstva

Glavno opterećenje restorana: podne (11:00–14:30) i večer (17:30–23:00), posebno petak, subota i period adventa. U tim periodima jedna osoba mora moći reagovati u roku od 15 minuta. Bez deploymenta i održavanja u tim vremenskim prozorima.

### 12.3 Postupak kod P1

1. Potvrdite uzbunu, zabilježite vrijeme.
2. Provjerite `curl -fsS https://app.giftcardpro.at/up` i `docker compose … ps`.
3. Logovi posljednjih minuta: `docker compose … logs --since 15m api caddy mysql redis`.
4. Česti uzroci i hitne mjere:

| Simptom | Mjera |
|---|---|
| `mysql` ili `redis` unhealthy | provjeriti disk (`df -h`), ponovo pokrenuti kontejner |
| `api` unhealthy nakon deploymenta | rollback ([Uputstvo za deployment](deployment-guide.md#9-rollback)) |
| Disk pun | očistiti Docker imagee (`docker image prune -f`), provjeriti stare dumpove |
| Greška certifikata | `docker compose … logs caddy`, provjeriti DNS |

5. Ako ispad traje duže od 15 minuta: postavite obavještenje o održavanju (ako je API dostupan) i obavijestite restorane e-mailom. Restorani tokom ispada bilježe iskorištavanja s brojem kartice i iznosom i nakon toga ih naknadno unose pomoću **Redeem**.
6. Nakon incidenta: kratak izvještaj (uzrok, trajanje, uticaj, mjere).

---

Verzija 1.0 · Stanje: septembar 2026.
