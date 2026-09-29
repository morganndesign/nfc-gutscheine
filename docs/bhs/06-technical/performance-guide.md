# Vodič za performanse

*Cilj performansi, procjena kapaciteta, ograničenja broja zahtjeva, indeksi baze i zaključavanje redova, hash lanci, keširanje, skaliranje, kontrolna lista i metode mjerenja za GiftCard Pro.*

---

## 1. Cilj performansi

Najvažniji cilj je poslovni: **iskorištavanje vaučera za stolom, uključujući čovjeka, traje manje od 5 sekundi** – skeniranje QR koda, unos iznosa, gotovo. Predočenje važi 60 sekundi; sam sistem treba potrošiti samo mali dio tog vremena.

Iskorištavanje se sastoji od dva zahtjeva:

1. `POST /presentments` – pronalaženje hasha skenirane tajne, pohrana predočenja (jedan red).
2. `POST /vouchers/{id}/redemptions` – u jednoj transakciji zaključavanje predočenja i vaučera, provjere, dodavanje stavke u ledger i zapisnik aktivnosti, ažuriranje stanja.

## 2. Mjerenje umjesto procjene

Vremena iskorištavanja mjere se testom prihvatanja (odjeljak 9.1) i bilježe po izdanju u zapisniku izdanja. Testovi istovremenosti (`IdempotencyAndConcurrencyTest`, u CI-ju i nad MySQL 8.4) dokazuju da istovremena iskorištavanja istog vaučera nikada ne terete više od stanja i da zbir ledgera odgovara stanju. Vrijednosti iz testnih okruženja s malim opterećenjem pokazuju da je softverski put brz; one nisu izjava o ponašanju pod velikim opterećenjem (vidi odjeljak 3).

## 3. Kapacitet jednog servera

### 3.1 Referentni sistem

| Komponenta | Postavka |
|---|---|
| Server | Hetzner CX32/CPX31: 4 vCPU, 8 GB RAM (minimum za stack: 2 vCPU / 4 GB) |
| PHP-FPM | `pm = dynamic`, `pm.max_children = 24`, `pm.max_requests = 1000`, `request_terminate_timeout = 30s`, OPcache + JIT (`infra/docker/php/`) |
| Queue worker | 1 kontejner, `--max-jobs=1000`, `--max-time=3600` |
| MySQL | 8.4, `innodb-buffer-pool-size=512M`, `READ-COMMITTED` |
| Redis | 7.4, AOF, `noeviction` |
| Gateway | Caddy, kompresija `zstd`/`gzip`; TLS kod Coolify proxyja |

### 3.2 Procjena

Sljedeći proračun je **procjena** i prije rasta izvan pilot rada treba ga potvrditi testom opterećenja.

| Pretpostavka | Vrijednost |
|---|---|
| Vrijeme servera za tipičan API zahtjev | 20–100 ms |
| Istovremeni PHP procesi | 24 |
| Teorijski protok API-ja | oko 240–1.000 zahtjeva/s |
| Zahtjevi po iskorištavanju (predočenje + iskorištavanje + osvježavanje prikaza) | oko 3–5 |
| Iskorištavanja u vršnom periodu po restoranu | 1–2 u minuti (pretpostavka za dobru večer u vrijeme adventa) |

Čak i 500 restorana s 2 iskorištavanja u minuti daje oko 17 iskorištavanja u sekundi, dakle oko 50–85 zahtjeva/s – znatno ispod procijenjenog protoka. Uska grla su prije:

- **Radna memorija**: 24 PHP procesa, MySQL buffer pool od 512 MB, Redis i Next.js dijele memoriju.
- **Izvozi i dashboardi velikih restorana** (agregacije preko mnogo knjiženja).
- **Provjera integriteta** (`giftcard:verify-chains`, 02:30): u potpunosti ponovo izračunava svaki hash lanac; trajanje raste linearno s ledgerom, plaćanjima i zapisnikom aktivnosti.
- **Vršni periodi e-mailova** (npr. podsjetnici u 10:00) – idu preko reda čekanja i ne blokiraju zahtjeve.

## 4. Ograničenja broja zahtjeva

Ograničenja štite od zloupotrebe i istovremeno ograničavaju opterećenje pojedinačnih klijenata:

| Limiter | Granica | Uticaj na performanse |
|---|---|---|
| `api` | 240/min po osobi | ograničava neispravne integracije (beskonačne petlje) |
| `presentment` | 90/min po osobi i uređaju; neuspjela predočenja dodatno 10 u 5 min po restoranu, osobi i uređaju | konobar s dva uređaja nije usporen; gosti iza iste IP adrese se nikada ne računaju |
| `voucher-operation` | 90/min po osobi i uređaju | prodaja, iskorištavanje, dopuna, ishod iskorištavanja |
| `login` | 5/min po e-mailu + IP, 30/min po IP | zaštita od napada na lozinke |
| `password-reset` | 5/min po IP | |
| `app-config` | 60/min po IP | početna konfiguracija aplikacije za konobare |

Brojači se nalaze u Redisu. Integracija s kasom koja redovno dostiže 240/min treba promijeniti način upita (npr. bez upita svih vaučera svake sekunde), umjesto da traži veće ograničenje.

## 5. Baza podataka

### 5.1 Indeksi

| Tabela | Indeksi | Korist |
|---|---|---|
| `vouchers` | `(restaurant_id, voucher_number)` unique, `(restaurant_id, status, created_at)`, `status`, `expires_at` | lista vaučera, pretraga po internom broju, noćni istek |
| `media` | `secret_hash` unique, `(voucher_id, type, status)` | predočenje: jedno traženje u indeksu po skeniranju |
| `presentments` | `(restaurant_id, created_at)` | analiza, čišćenje |
| `voucher_transactions` | `(restaurant_id, idempotency_key)` unique, `presentment_id`, `payment_id`, `related_transaction_id` unique, `(restaurant_id, created_at)`, `(restaurant_id, type, created_at)`, `(voucher_id, created_at)` | idempotentnost, ishod iskorištavanja, istorija, lista knjiženja |
| `payments` | `(restaurant_id, method, created_at)` | analiza po načinu plaćanja |
| `customers` | `(restaurant_id, email)`, `(restaurant_id, last_name)` | pretraga |
| `audit_logs` | `(restaurant_id, created_at)`, `action`, `(auditable_type, auditable_id)` | prikaz zapisnika aktivnosti, sigurnosna analiza |
| Hash lanci | `(chain_scope, chain_seq)` unique u ledgeru, plaćanjima i zapisniku aktivnosti | dodavanje u lanac i provjera lanca |

Svi primarni ključevi su vremenski uređeni UUIDv7 – novi redovi završavaju na kraju indeksa (dobra lokalnost pri upisu).

### 5.2 Zaključavanje redova i hash lanci

Svaka promjena stanja izvršava se u transakciji sa `SELECT … FOR UPDATE`:

- Kod iskorištavanja se zaključavaju **predočenje i jedan vaučer** (redoslijed predočenje → vaučer), ne tabela. Iskorištavanja različitih vaučera rade paralelno.
- Istovremena iskorištavanja **istog** vaučera se serijalizuju – to je namjerno i sprečava dvostruku potrošnju. Nakon zaključavanja idempotency ključ se ponovo provjerava; ponavljanje koje je čekalo dobija prvi rezultat.
- Pri dodavanju u hash lanac zaključava se njegova glava u `chain_heads` (redoslijed plaćanja → ledger → zapisnik aktivnosti). Knjiženja **jednog restorana** se time za vrijeme dodavanja kratko upisuju jedno za drugim; restorani međusobno ne blokiraju jedni druge.
- `READ-COMMITTED` drži zaključavanja kratkim; kod deadlocka transakcija se ponavlja do 3 puta.
- E-mailovi se stavljaju u red tek **nakon** commita (`ShouldDispatchAfterCommit`) – slanje e-maila ne produžava zaključavanje.

### 5.3 Pronalaženje sporih upita

```sql
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 0.5;
SHOW VARIABLES LIKE 'slow_query_log_file';
```

Postavka važi do ponovnog pokretanja MySQL kontejnera. Analiza pomoću `mysqldumpslow` u kontejneru. Nakon analize ponovo deaktivirati.

## 6. Keširanje

| Nivo | Šta | Gdje |
|---|---|---|
| Laravel bootstrap | konfiguracija, rute, viewovi i eventi keširaju se pri svakom pokretanju kontejnera | datotečni sistem kontejnera |
| PHP | OPcache + JIT | radna memorija |
| Dozvole | uloge → dozvole, keširano po ulozi | Redis |
| Sistemske postavke | `system_settings` keširano | Redis |
| HTTP | API odgovori `Cache-Control: no-store, private` (osim `/app/config`: `public, max-age=60`) – namjerno **bez** HTTP keširanja stanja | – |
| Pretraživač | React Query drži podatke servera u klijentu i ciljano ih poništava nakon izmjena | pretraživač |
| Statične datoteke | Next.js resursi s hashom u nazivu datoteke; gateway komprimuje sa `zstd`/`gzip` | pretraživač, gateway |

Stanja se nikada ne keširaju – svako iskorištavanje čita zaključani zapis iz baze.

## 7. Frontend

- Grafikoni dashboarda učitavaju se tek nakon pokazatelja (`next/dynamic`) – pokazatelji se prikazuju prvi.
- Web kasa i aplikacija za konobare odbrojavaju važenje predočenja od prijema (`expires_in`), nezavisno od sata uređaja.
- Nakon iskorištavanja skener je odmah spreman za sljedeći QR kod.
- Interfejs staje bez skrolovanja na male telefone (iPhone SE), što štedi vrijeme rukovanja.

## 8. Skaliranje

| Nivo | Mjera | Kada |
|---|---|---|
| 1 | Veći server (više vCPU/RAM), povećati `pm.max_children` i `innodb-buffer-pool-size` | RAM > 80 % ili CPU u vršnim periodima > 70 % |
| 2 | MySQL premjestiti na poseban server ili upravljani MySQL (postaviti `DB_HOST` itd., ukloniti servise `mysql`/`backup`) | baza se s PHP-om takmiči za resurse |
| 3 | Read replika za izvoze i analize | veliki izvozi utiču na vremena odgovora |
| 4 | Poseban Coolify resurs po velikom klijentu (single tenant) iz istog repozitorija | zahtjev za izolacijom klijenta Gruppe |

Aplikacija je bez stanja; sesije, keš i zaključavanja nalaze se u Redisu. Scheduler smije raditi samo **jednom** (`onOneServer()` je postavljen i koristi Redis zaključavanja). Migracije zahvaljujući Redis zaključavanju rade samo u jednom kontejneru.

## 9. Mjerenje

### 9.1 Test prihvatanja

Test prihvatanja `e2e/pilot-journey.mjs` prolazi kroz prodaju, QR skeniranje i iskorištavanje na telefonu. Pokrenite ga prije svakog izdanja i izmjereno vrijeme iskorištavanja zabilježite u zapisniku izdanja – porast u odnosu na prethodno izdanje je znak upozorenja.

```bash
cd e2e
ADMIN_EMAIL=admin@giftcardpro.test ADMIN_PASSWORD='Password123!' npm test
```

### 9.2 Vremena odgovora u produkciji

```bash
curl -o /dev/null -s -w "connect=%{time_connect}s tls=%{time_appconnect}s total=%{time_total}s\n" https://app.giftcardpro.at/up
```

Access log gatewaya sadrži za svaki zahtjev polje `duration` (sekunde). Na serveru (kao root):

```bash
docker logs --since 1h <gateway-container> 2>&1 \
  | jq -r 'select(.request.uri? | test("^/api/v1/(presentments|vouchers/[^/]+/redemptions)")) | .duration' \
  | sort -n | awk '{a[NR]=$1} END {print "p50="a[int(NR*0.5)]" p95="a[int(NR*0.95)]" n="NR}'
```

### 9.3 Test opterećenja (preporuka)

Testove opterećenja izvodite samo nad **staging okruženjem** iste veličine servera, nikada nad produkcijom (ograničenja broja zahtjeva, nepromjenjive stavke ledgera). Alat npr. k6; scenarij: mnogo uređaja s vlastitim `X-Device-Id` i vlastitim tokenom, po uređaju predočenje testnog QR koda i iskorištavanje s novim `Idempotency-Key`. Nakon testa izvršite `php artisan giftcard:verify-chains` i kontrolne upite iz [Uputstva za vraćanje podataka](restore-guide.md#8-kontrolni-upiti-nakon-vraćanja).

## 10. Kontrolna lista

- [ ] `APP_DEBUG=false`, `APP_ENV=production` (inače znatno sporije)
- [ ] `CACHE_STORE=redis`, `SESSION_DRIVER=redis`, `QUEUE_CONNECTION=redis` (standard u Coolify stacku)
- [ ] Servis `worker` radi (inače čekaju e-mailovi, ne zahtjevi)
- [ ] `/up` odgovara za < 300 ms
- [ ] Test prihvatanja: iskorištavanje < 1 s sistemskog vremena
- [ ] Provjera integriteta završava znatno prije jutra
- [ ] RAM < 75 %, bez korištenja swapa
- [ ] Disk < 70 %
- [ ] Red čekanja ne raste
- [ ] Novi upiti u bazu u pull requestovima provjereni s `EXPLAIN`; novi filteri samo s odgovarajućim indeksom
- [ ] Novi novčani tokovi zaključavaju samo pogođeni vaučer, ne tabele
- [ ] Bez podataka o stanju ili dozvolama u HTTP kešu

---

Verzija 2.0 · Stanje: septembar 2026.
