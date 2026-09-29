# Vodič za nadzor (monitoring)

*Nadzor GiftCard Pro u produkciji: healthcheck, dostupnost, kontejneri, red čekanja, scheduler, provjera integriteta, pokazatelji, pravila uzbune, dashboardi i rutina dežurstva.*

---

## 1. Ciljevi

Aplikacija za konobare i web kasa koriste se tokom usluživanja. Ispad u petak navečer znači da gosti ne mogu iskoristiti svoj vaučer. Nadzor zato treba:

1. prijaviti ispad u roku od 2 minute,
2. učiniti vidljivim pokušaje zloupotrebe (pogođeni ili kopirani QR kodovi, napadi na lozinke) i svaku manipulaciju finansijske istorije,
3. rano prepoznati postepene probleme (pun disk, rastući red čekanja, nedostajuće sigurnosne kopije), prije ispada.

Ciljana dostupnost prema ponudi: 99,5 % mjesečno (cilj, ne garancija u paketu Start).

## 2. Healthcheck `/up`

| Svojstvo | Vrijednost |
|---|---|
| URL | `https://<APP_DOMAIN>/up` (gateway ga prosljeđuje Laravelu) |
| Uspjeh | HTTP 200 |
| Provjerava | PHP-FPM i Laravel rade, **baza** odgovara, **keš** (Redis) je dostupan |
| Greška | HTTP 500 kada baza ili keš nisu dostupni; 503 u režimu održavanja |
| Koristi se u | provjerama nakon deploymenta, eksternom nadzoru dostupnosti |

`/up` ne provjerava web aplikaciju (Next.js). Zato dodatno nadzirite stranicu za prijavu.

## 3. Nadzor dostupnosti (eksterni)

Koristite eksterni servis (npr. Better Stack, UptimeRobot) koji **ne** radi na istom serveru.

| Monitor | URL | Interval | Očekivanje | Uzbuna nakon |
|---|---|---|---|---|
| API + baza + keš | `https://app.giftcardpro.at/up` | 1 min | status 200 | 2 neuspjeha |
| Web aplikacija | `https://app.giftcardpro.at/login` | 1 min | status 200 | 2 neuspjeha |
| Konfiguracija aplikacije za konobare | `https://app.giftcardpro.at/api/v1/app/config` | 5 min | status 200, JSON | 2 neuspjeha |
| TLS certifikat | `app.giftcardpro.at:443` | dnevno | važi > 14 dana | odmah |
| Heartbeat sigurnosne kopije | heartbeat URL iz [Uputstva za sigurnosne kopije](backup-guide.md#6-nadzor-poslova-kopiranja) | dnevno | signal do 04:00 (vrijeme servera) | izostanak signala |

Preporuka: javna statusna stranica servisa za nadzor pod `[status.giftcardpro.at]` za restorane.

## 4. Ispravnost kontejnera

| Servis | Healthcheck (u `docker-compose.coolify.yml`) | Interval |
|---|---|---|
| `gateway` | `GET /gateway-health` | 15 s |
| `api` | php-fpm ping preko FastCGI, početni prozor 300 s (čekanje na MySQL, migracije) | 15 s |
| `worker` | `pgrep -f queue:work` | 30 s |
| `scheduler` | `pgrep -f schedule:work` | 30 s |
| `web` | `GET /login` | 15 s |
| `mysql` | `mysqladmin ping` | 10 s, 12 pokušaja |
| `redis` | `redis-cli ping` | 10 s, 10 pokušaja |
| `backup` | bez healthchecka (vidi nadzor sigurnosnih kopija) | – |

Svi servisi rade s `restart: unless-stopped`: Docker ponovo pokreće kontejnere koji su se srušili, ali **ne** kontejnere koji su samo označeni kao `unhealthy`.

Provjera: Coolify prikazuje status svakog servisa u resursu. Na serveru (kao root):

```bash
docker ps --filter health=unhealthy
docker stats --no-stream
```

Preporuka: cron posao koji svakih 5 minuta provjerava `docker ps --filter health=unhealthy --format '{{.Names}}'` i uzbunjuje kada izlaz nije prazan.

## 5. Red čekanja (queue)

### 5.1 Šta radi u redu čekanja

Servis `worker` obrađuje Redis redove `default` i `notifications` (`--tries=5`, restart nakon 1 sata ili 1.000 poslova). **Svaki** e-mail šalje se iz reda čekanja: e-mailovi gostima (kupovina, dopuna, podsjetnik o isteku), pozivnice i linkovi za lozinku. Od mail servera koji ne odgovaraju odustaje se nakon `MAIL_TIMEOUT` (10 s) i posao se ponavlja.

### 5.2 Monitor reda čekanja

Scheduler svakih 5 minuta izvršava:

```
queue:monitor redis:default,redis:notifications --max=500
```

Ako u redu ima više od 500 poslova, Laravel pokreće događaj `QueueBusy`.

> **Obavještenje:** listener `AlertOnQueueBacklog` tada upisuje zapis `critical` u log i šalje e-mail na `OPS_ALERT_EMAIL` (prazno: adresa podrške iz sistemskih postavki) – najviše jednom po redu svakih 30 minuta. E-mail se šalje direktno, ne preko reda čekanja, kako bi stigao i kada worker ne radi.

Ručna provjera u kontejneru **api**:

```bash
php artisan queue:monitor redis:default,redis:notifications --max=500
php artisan queue:failed
```

| Nalaz | Značenje | Mjera |
|---|---|---|
| Red > 0 duže vrijeme, raste | Worker je zaglavljen ili ne radi | provjeriti log servisa `worker`, ponovo pokrenuti servis u Coolifyju |
| Mnogo neuspjelih poslova | Poremećeno slanje e-maila (pristupni podaci, limit pružaoca usluge) | otkloniti uzrok, zatim `php artisan queue:retry all` |

Neuspjeli poslovi uklanjaju se dnevno u 03:30 nakon 30 dana (`queue:prune-failed --hours=720`). Svaki pokušaj slanja dodatno je u `notification_logs`.

## 6. Scheduler i provjera integriteta

U kontejneru **api**: `php artisan schedule:list`. Očekivani zapisi (vremena u `SCHEDULE_TIMEZONE`, standard `Europe/Vienna`):

| Naredba | Raspored |
|---|---|
| `vouchers:expire` | dnevno 00:15 |
| `giftcard:verify-chains` | dnevno 02:30 |
| `queue:prune-failed --hours=720` | dnevno 03:30 |
| `vouchers:notify-expiring` | dnevno 10:00 |
| `auth:clear-resets` | svakih 15 minuta |
| `queue:monitor redis:default,redis:notifications --max=500` | svakih 5 minuta |

**Provjera integriteta.** `giftcard:verify-chains` ponovo izračunava svaki hash lanac (ledger, plaćanja, zapisnik aktivnosti po restoranu i platformi) i svako stanje vaučera. Kod odstupanja upisuje `Integrity check failed: financial history or audit log does not verify` kao `critical` u log i šalje e-mail na `OPS_ALERT_EMAIL`. **Neuspjela provjera integriteta je sigurnosni incident** (P1, vidi [Vodič za odgovor na incidente](../07-security/incident-response-guide.md)): sačuvajte bazu i sigurnosne kopije prije bilo kakve izmjene.

Dokaz da je posao isteka izvršen: u zapisniku aktivnosti pojavljuju se zapisi `voucher.expired` s vremenskom oznakom neposredno nakon 00:15 po bečkom vremenu (samo ako su tog dana vaučeri istekli). Stanje pri tome ostaje sačuvano; ne nastaje knjiženje.

```sql
SELECT DATE(created_at) AS day, COUNT(*) FROM audit_logs
WHERE action = 'voucher.expired' AND created_at > NOW() - INTERVAL 7 DAY GROUP BY day;
```

## 7. Sigurnosni događaji u logu

Ove poruke su pogodne za uzbune:

| Poruka u logu | Nivo | Polja konteksta | Okidač |
|---|---|---|---|
| `Account locked after repeated failed logins` | `warning` | `user_id`, `ip`, `attempts` | 10 uzastopnih pogrešnih lozinki (`LOGIN_LOCKOUT_THRESHOLD`) |
| `Integrity check failed: financial history or audit log does not verify` | `critical` | nalazi | noćna ili ručna provjera integriteta |
| `Queue backlog above threshold` | `critical` | `queue`, `size` | više od 500 poslova |

Pretraga: Coolify → *Logs* → servis **api** odnosno **scheduler**, ili na serveru `docker logs --since 24h <api-container> 2>&1 | grep -E "Account locked|Integrity check failed"`.

Neuspjela predočenja (skenirani tekst koji nije važeći vaučer ovog restorana) nalaze se u zapisniku aktivnosti:

```sql
SELECT restaurant_id, device_id, action, COUNT(*) AS n
FROM audit_logs
WHERE created_at > NOW() - INTERVAL 1 DAY AND action IN ('presentment.failed', 'presentment.rejected')
GROUP BY restaurant_id, device_id, action ORDER BY n DESC;
```

Nakon `PRESENTMENT_FAILURE_LIMIT` (10) neuspjelih pokušaja u 5 minuta po restoranu, osobi i uređaju API odgovara s `429 PRESENTMENT_THROTTLED`.

## 8. Pokazatelji

| Pokazatelj | Izvor | Normalan raspon (orijentacija) | Upozorenje |
|---|---|---|---|
| Dostupnost `/up` | nadzor dostupnosti | 100 % | svaki ispad |
| Vrijeme odgovora `/up` | nadzor dostupnosti | < 300 ms | > 1 s tokom 5 min |
| Udio HTTP 5xx | access log gatewaya (JSON, polje `status`) | ~0 | > 1 % tokom 5 min |
| Broj HTTP 429 | access log gatewaya | nizak | nagli porast (napad ili preusko ograničenje) |
| Dužina reda čekanja | `queue:monitor` | 0–nekoliko | > 500 |
| Neuspjeli poslovi | `queue:failed` | 0 | > 0 novih dnevno |
| Provjera integriteta | log `scheduler`, e-mail | bez nalaza | svaki nalaz |
| Neuspjela predočenja | zapisnik aktivnosti | pojedinačna (zaprljani ili pogrešni QR kodovi) | ≥ 10 po satu i uređaju |
| Zaključavanja naloga | log / zapisnik aktivnosti | rijetko | ≥ 3 po satu |
| Disk | `df -h` | < 70 % | > 80 % |
| RAM | `free -m`, `docker stats` | < 75 % | > 90 % |
| Memorija Redisa | `redis-cli INFO memory` | niska | raste; uz `noeviction` puna memorija dovodi do grešaka pri upisu (sesije, red čekanja) |
| MySQL veze | `SHOW STATUS LIKE 'Threads_connected'` | nizak | blizu `max_connections` |
| Starost sigurnosne kopije | log servisa `backup`, heartbeat | < 24 h | > 26 h |
| Trajanje certifikata | nadzor dostupnosti | > 30 dana | < 14 dana |

Orijentacione vrijednosti su procjene za pilot rad i treba ih nakon prvih sedmica prilagoditi stvarnim vrijednostima.

## 9. Pravila uzbune

| Prioritet | Pravilo | Reakcija |
|---|---|---|
| **P1 – odmah** | `/up` ili web aplikacija nedostupni (2 provjere) | dežurstvo odmah, i navečer |
| **P1** | HTTP 5xx > 5 % tokom 5 min | odmah |
| **P1** | kontejner `api`, `mysql` ili `redis` unhealthy | odmah |
| **P1** | provjera integriteta javlja nalaz | odmah, kao sigurnosni incident |
| **P2 – isti dan** | nagomilani `presentment.failed` na jednom uređaju ili u jednom restoranu | obavijestiti restoran, provjeriti uređaj, po potrebi opozvati pod **Devices** |
| **P2** | ≥ 3 `Account locked` po satu, ili više naloga s jedne IP adrese | provjeriti IP, po potrebi blokirati u firewallu |
| **P2** | red čekanja > 500 ili novi neuspjeli poslovi | provjeriti slanje e-maila |
| **P2** | sigurnosna kopija starija od 26 h ili neuspjela off-site sinhronizacija | ručno nadoknaditi kopiju |
| **P2** | disk > 80 % | očistiti (odjeljak 9 [Uputstva za održavanje](maintenance-guide.md#9-oslobađanje-prostora-na-disku)) |
| **P3 – sedmična rutina** | certifikat < 30 dana, `composer audit`/`npm audit` javlja propuste | isplanirati |

Pravila zasnovana na logovima pretpostavljaju slanje logova (vidi [Vodič za logovanje](logging-guide.md#slanje-logova-preporuka)). Bez slanja logova: dnevni cron posao s upitima iz odjeljka 7 koji rezultat šalje e-mailom. Provjera integriteta i zastoj reda čekanja nezavisno od toga uzbunjuju e-mailom.

## 10. Praćenje grešaka (opcionalno)

Za izuzetke sa stack traceom može se dodati Sentry (`sentry/sentry-laravel` u backendu, `@sentry/nextjs` u frontendu). Oba paketa trenutno **nisu** instalirana; integracija je izmjena koda s vlastitim izdanjem. Pri korištenju filtrirajte lične podatke (`send_default_pii` ostaviti isključeno) i izaberite lokaciju podataka u EU.

## 11. Dashboardi (prijedlog)

| Dashboard | Sadržaj |
|---|---|
| **Rad** | dostupnost, vrijeme odgovora `/up`, stopa 5xx, zahtjevi po minuti (gateway), status kontejnera, CPU/RAM/disk |
| **Pozadina** | dužina reda čekanja, neuspjeli poslovi, posljednje izvršavanje noćnih poslova i provjere integriteta, starost sigurnosne kopije |
| **Sigurnost** | neuspjela predočenja po restoranu i uređaju, zaključavanja naloga, odgovori 429, IP adrese s najviše 4xx |
| **Poslovanje** (platforma) | aktivni restorani, prodati vaučeri, iskorištavanja po danu – iz `GET /admin/stats` odnosno SQL-a |

Provedba npr. s Grafana + Loki (slanje logova preko Promtail ili Vector) ili direktno u dashboardu servisa za logove s lokacijom u EU.

## 12. Rutina dežurstva

### 12.1 Dnevno (5 minuta, prijepodne)

- [ ] Nadzor dostupnosti: bez incidenata u posljednja 24 h
- [ ] Coolify: svi servisi `running`/`healthy`
- [ ] Nema e-maila upozorenja na `OPS_ALERT_EMAIL` (provjera integriteta, red čekanja)
- [ ] Današnja sigurnosna kopija postoji, off-site sinhronizovana
- [ ] Sigurnosni događaji iz posljednja 24 h provjereni
- [ ] `queue:failed` prazan

### 12.2 Vrijeme dežurstva

Glavno opterećenje restorana: podne (11:00–14:30) i večer (17:30–23:00), posebno petak, subota i period adventa. U tim periodima jedna osoba mora moći reagovati u roku od 15 minuta. Bez deploymenta i održavanja u tim vremenskim prozorima.

### 12.3 Postupak kod P1

1. Potvrdite uzbunu, zabilježite vrijeme.
2. Provjerite `curl -fsS https://app.giftcardpro.at/up` i status servisa u Coolifyju.
3. Logovi posljednjih minuta: Coolify → *Logs* → `api`, `gateway`, `mysql`, `redis`.
4. Česti uzroci i hitne mjere:

| Simptom | Mjera |
|---|---|
| `mysql` ili `redis` unhealthy | provjeriti disk (`df -h`), ponovo pokrenuti servis |
| `api` unhealthy nakon deploymenta | rollback ([Uputstvo za deployment](deployment-guide.md#9-rollback)) |
| Disk pun | očistiti Docker imagee i build keš (`docker image prune -f`, `docker builder prune -f`), provjeriti stare dumpove |
| Greška certifikata | provjeriti DNS i domenu servisa `gateway` u Coolifyju |
| Provjera integriteta javlja nalaz | ništa ne mijenjati; sačuvati bazu i sigurnosne kopije; [Vodič za odgovor na incidente](../07-security/incident-response-guide.md) |

5. Ako ispad traje duže od 15 minuta: postavite obavještenje o održavanju (ako je API dostupan) i obavijestite restorane e-mailom. Tokom ispada nijedan vaučer se ne može iskoristiti: svako iskorištavanje zahtijeva svježe predočenje vaučera, a broj vaučera nije zamjena za to. Gosti u tom periodu plaćaju na drugi način ili vaučer iskoriste pri sljedećoj posjeti.
6. Nakon incidenta: kratak izvještaj (uzrok, trajanje, uticaj, mjere).

---

Verzija 2.0 · Stanje: septembar 2026.
