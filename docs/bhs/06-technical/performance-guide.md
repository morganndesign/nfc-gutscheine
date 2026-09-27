# Vodič za performanse

*Izmjerene vrijednosti, procjena kapaciteta, ograničenja broja zahtjeva, indeksi baze i zaključavanje redova, keširanje, skaliranje, kontrolna lista i metode mjerenja za GiftCard Pro.*

---

## 1. Cilj performansi

Najvažniji cilj je poslovni: **iskorištavanje kartice za stolom, uključujući čovjeka, traje manje od 5 sekundi** – dodir kartice, unos iznosa, gotovo. Sam sistem treba potrošiti samo mali dio tog vremena.

## 2. Izmjerene vrijednosti

| Mjerenje | Rezultat | Izvor |
|---|---|---|
| Upit kartice (`POST /scan`) | **92 ms** (~0,1 s) | E2E mjerenje, izdanje 1.1.0 |
| Kompletan tok u aplikaciji za konobare (dodir → iznos → iskorištavanje → gotovo) | **545 ms** (~0,5 s) | E2E mjerenje, izdanje 1.1.0 |
| Iskorištavanje od strane konobara uklj. unos broja kartice | **0,48 s** | test prihvatanja `pilot-journey.mjs`, izdanje 1.2.0 |
| JavaScript pri prvom učitavanju dashboarda | **142 kB** (prije 251 kB) | izlaz builda, izdanje 1.2.0 – grafikoni se učitavaju naknadno (`next/dynamic`) |
| 20 istovremenih iskorištavanja na jednoj kartici | uspjelo je tačno onoliko koliko stanje dozvoljava, zbir ledgera = stanje | test konkurentnosti protiv MariaDB |

Vrijednosti potiču iz testnih okruženja s malim opterećenjem. Dokazuju da je softverski put brz; nisu izjava o ponašanju pod velikim opterećenjem (vidi odjeljak 3).

## 3. Kapacitet jednog servera

### 3.1 Referentni sistem

| Komponenta | Postavka |
|---|---|
| Server | Hetzner CPX31: 4 vCPU, 8 GB RAM |
| PHP-FPM | `pm = dynamic`, `pm.max_children = 24`, `pm.max_requests = 1000`, OPcache + JIT |
| Queue worker | 1 kontejner, `--max-jobs=1000`, `--max-time=3600` |
| MySQL | 8.4, `innodb-buffer-pool-size=512M`, `READ-COMMITTED` |
| Redis | 7.4, AOF, `noeviction` |
| Caddy | HTTP/3, kompresija `zstd`/`gzip` |

### 3.2 Procjena

Sljedeći proračun je **procjena** i prije rasta iznad pilot faze treba ga potvrditi testom opterećenja.

| Pretpostavka | Vrijednost |
|---|---|
| Serversko vrijeme tipičnog API zahtjeva | 20–100 ms |
| Istovremeni PHP procesi | 24 |
| Teorijska propusnost API-ja | oko 240–1.000 zahtjeva/s |
| Zahtjevi po iskorištavanju (skeniranje + iskorištavanje + osvježavanje prikaza) | oko 3–5 |
| Vršna iskorištavanja po restoranu | 1–2 u minuti (pretpostavka za dobru večer u vrijeme adventa) |

Čak i 500 restorana s 2 iskorištavanja u minuti daje oko 17 iskorištavanja u sekundi, dakle oko 50–85 zahtjeva/s – znatno ispod procijenjene propusnosti. Izjava razvojnog tima „jedan CPX31 je dovoljan za nekoliko stotina restorana" je time uvjerljiva. Uska grla su prije:

- **Radna memorija**: 24 PHP procesa, MySQL buffer pool 512 MB, Redis i Next.js dijele 8 GB.
- **Izvozi i dashboardi velikih restorana** (agregacije preko mnogo knjiženja).
- **Vrhovi e-mailova** (npr. podsjetnici u 10:00) – idu kroz red čekanja i ne blokiraju zahtjeve.

## 4. Ograničenja broja zahtjeva

Ograničenja štite od zloupotrebe i istovremeno ograničavaju opterećenje pojedinih klijenata:

| Limiter | Granica | Uticaj na performanse |
|---|---|---|
| `api` | 240/min po korisniku | ograničava neispravne integracije (beskonačne petlje) |
| `card-scan` | 90/min po korisniku i uređaju; neuspjeli pokušaji 10 u 5 min po korisniku i IP | konobar s dva uređaja nije usporen |
| `card-operation` | 90/min po korisniku i uređaju | |
| `login` | 5/min po e-mailu + IP, 30/min po IP | zaštita od napada na lozinke |
| `password-reset` | 5/min po IP | |
| `public-card` | 20/min po IP | stranica stanja za goste |

Brojači su u Redisu. Integracija s kasom koja redovno dostiže 240/min treba promijeniti način upita (npr. ne upitivati sve kartice svake sekunde), umjesto da traži veće ograničenje.

## 5. Baza podataka

### 5.1 Indeksi

| Tabela | Indeksi | Korist |
|---|---|---|
| `gift_cards` | `(restaurant_id, card_number)` unique, `(restaurant_id, status, created_at)`, `(restaurant_id, nfc_uid)`, `nfc_uid_active` unique, `public_token` unique, `expires_at`, `status` | skeniranje po tokenu ili broju, lista kartica, provjera klonova, noćni istek |
| `gift_card_transactions` | `idempotency_key` jedinstven po restoranu, strani ključ na karticu | idempotentnost, historija kartice |
| `customers` | `(restaurant_id, email)`, `(restaurant_id, last_name)` | pretraga |
| `nfc_scans` | `created_at`, `(restaurant_id, result, created_at)` | sigurnosna analiza |
| `audit_logs` | `(restaurant_id, created_at)` | prikaz zapisnika aktivnosti |

Svi primarni ključevi su vremenski uređeni UUIDv7 – novi redovi završavaju na kraju indeksa (dobra lokalnost pri pisanju).

### 5.2 Zaključavanje redova

Svaka promjena stanja izvršava se u transakciji sa `SELECT … FROM gift_cards WHERE id = ? FOR UPDATE`:

- Zaključava se **samo ta jedna kartica**, ne tabela. Iskorištavanja različitih kartica teku paralelno.
- Istovremena iskorištavanja **iste** kartice se serijalizuju – to je namjerno i sprečava dvostruku potrošnju.
- `READ-COMMITTED` drži zaključavanja kratko; transferi zaključavaju obje kartice fiksnim redoslijedom (bez deadlocka); kod deadlocka transakcija se ponavlja do 3 puta.
- E-mailovi se stavljaju u red tek **nakon** commita (`ShouldDispatchAfterCommit`) – slanje e-maila ne produžava zaključavanje.

### 5.3 Pronalaženje sporih upita

```sql
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 0.5;
SHOW VARIABLES LIKE 'slow_query_log_file';
```

Postavka važi do ponovnog pokretanja MySQL kontejnera. Analiza pomoću `mysqldumpslow` u kontejneru. Nakon analize ponovo deaktivirajte.

## 6. Keširanje

| Nivo | Šta | Gdje |
|---|---|---|
| Laravel bootstrap | `config:cache`, `route:cache`, `view:cache`, `event:cache` pri svakom pokretanju kontejnera | datotečni sistem kontejnera |
| PHP | OPcache + JIT | radna memorija |
| Dozvole | uloge → dozvole, keširano po ulozi | Redis |
| Sistemske postavke | `system_settings` keširano | Redis |
| HTTP | API odgovori `Cache-Control: no-store, private` – namjerno **bez** HTTP keširanja stanja | – |
| Pretraživač | React Query drži serverske podatke kod klijenta i ciljano ih poništava nakon izmjena | pretraživač |
| Statičke datoteke | Next.js resursi s hashom u nazivu datoteke; Caddy komprimuje sa `zstd`/`gzip` | pretraživač, Caddy |

Stanja se nikada ne keširaju – svako iskorištavanje čita zaključani zapis iz baze.

## 7. Frontend

- Grafikoni dashboarda učitavaju se tek nakon pokazatelja (`next/dynamic`) – pokazatelji se pojavljuju prvi.
- Aplikacija za konobare drži NFC čitač aktivnim i na ekranu uspjeha; sljedeća kartica može se odmah prisloniti.
- Interfejs bez skrolovanja staje na male telefone (iPhone SE), što štedi vrijeme rukovanja.

## 8. Skaliranje

| Nivo | Mjera | Kada |
|---|---|---|
| 1 | Veći server (više vCPU/RAM), povećati `pm.max_children` i `innodb-buffer-pool-size` | RAM > 80 % ili CPU u vrhovima > 70 % |
| 2 | Više replika `api` i `web` iza Caddyja (`reverse_proxy` s više upstreamova). Aplikacija je bez stanja; sesije, keš i zaključavanja su u Redisu. | usko grlo CPU-a kod PHP-a |
| 3 | Izdvojiti MySQL na vlastiti server ili managed MySQL | baza se s PHP-om takmiči za resurse |
| 4 | Read replika za izvoze i izvještaje | veliki izvozi utiču na vremena odgovora |
| 5 | Vlastita instanca po velikom klijentu (single tenant) s istim imageima | zahtjev za izolacijom Gruppe klijenta |

Napomene za nivo 2: scheduler smije raditi samo **jednom** (`onOneServer()` je postavljen i koristi Redis zaključavanja, ali dodatni scheduler kontejner ipak nije potreban). Migracije se zahvaljujući `--isolated` izvršavaju samo u jednom kontejneru.

## 9. Mjerenje

### 9.1 Test prihvatanja

Test prihvatanja `e2e/pilot-journey.mjs` mjeri iskorištavanje od strane konobara i pada ako premaši 5 sekundi. Pokrenite ga prije svakog izdanja i izmjereno vrijeme zabilježite u protokolu izdanja – porast u odnosu na referentnu vrijednost (0,48 s) je znak upozorenja.

```bash
cd e2e
ADMIN_EMAIL=admin@giftcardpro.test ADMIN_PASSWORD='Password123!' npm test
```

### 9.2 Vremena odgovora u produkciji

```bash
curl -o /dev/null -s -w "connect=%{time_connect}s tls=%{time_appconnect}s total=%{time_total}s\n" https://app.giftcardpro.at/up
```

Caddy access log sadrži po zahtjevu polje `duration` (sekunde):

```bash
docker compose --env-file .env.production logs --no-log-prefix --since 1h caddy \
  | jq -r 'select(.request.uri? | startswith("/api/v1/scan")) | .duration' \
  | sort -n | awk '{a[NR]=$1} END {print "p50="a[int(NR*0.5)]" p95="a[int(NR*0.95)]" n="NR}'
```

### 9.3 Test opterećenja (preporuka)

Testove opterećenja izvodite samo protiv **staging okruženja** iste veličine servera, nikada protiv produkcije (ograničenja broja zahtjeva, unosi u ledger). Alat npr. k6; scenarij: mnogo uređaja s vlastitim `X-Device-Id` i API tokenima, po uređaju skeniranje + iskorištavanje s novim `Idempotency-Key`. Nakon testa izvršite provjeru ledgera iz [Uputstva za vraćanje podataka](restore-guide.md#8-kontrolni-upiti-nakon-vraćanja).

## 10. Kontrolna lista

- [ ] `APP_DEBUG=false`, `APP_ENV=production` (inače znatno sporije)
- [ ] `CACHE_STORE=redis`, `SESSION_DRIVER=redis`, `QUEUE_CONNECTION=redis`
- [ ] Kontejner `queue` radi (inače čekaju e-mailovi, ne zahtjevi)
- [ ] `/up` odgovara za < 300 ms
- [ ] Test prihvatanja: iskorištavanje < 1 s sistemskog vremena
- [ ] RAM < 75 %, bez korištenja swapa
- [ ] Disk < 70 %
- [ ] Red čekanja ne raste
- [ ] Novi upiti nad bazom u pull requestovima provjereni s `EXPLAIN`; novi filteri samo s odgovarajućim indeksom
- [ ] Novi novčani tokovi zaključavaju samo pogođene kartice, ne tabele
- [ ] Bez podataka o stanju ili dozvolama u HTTP kešu

---

Verzija 1.0 · Stanje: septembar 2026.
