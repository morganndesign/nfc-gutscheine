# API dokumentacija

*Kompletna referenca REST API-ja v1 za GiftCard Pro: autentifikacija, zaglavlja, kodovi grešaka, ograničenja broja zahtjeva, sve krajnje tačke i primjeri.*

---

## 1. Osnove

| Svojstvo | Vrijednost |
|---|---|
| Bazni URL | `https://<APP_DOMAIN>/api/v1` (npr. `https://app.giftcardpro.at/api/v1`) |
| Format | isključivo JSON, UTF-8 (izuzeci: CSV izvozi, QR kod kao SVG) |
| Iznosi | uvijek u **najmanjim jedinicama (centima)** kao cijeli broj: `1850` = 18,50 € |
| Vremenske oznake | ISO 8601 u UTC, npr. `2029-09-13T21:59:59+00:00` |
| ID-jevi | UUID |
| Obavezna zaglavlja | `Accept: application/json`; kod zahtjeva s tijelom `Content-Type: application/json` |

API je razdvojen po mandantima: svaki pristup vidi isključivo podatke vlastitog restorana. ID-jevi drugih restorana ponašaju se kao nepostojeći ID-jevi (`404`).

## 2. Autentifikacija

Postoje tri postupka.

### 2.1 Pretraživač (dashboard, aplikacija za konobare u pretraživaču) – Sanctum SPA kolačići

```http
GET  /sanctum/csrf-cookie                     → sets XSRF-TOKEN cookie
POST /api/v1/auth/login                       headers: X-XSRF-TOKEN: <cookie value>
     {"email":"…","password":"…","remember":true}
```

- Session kolačić (`giftcardpro_session`) je `httpOnly`, `Secure` i `SameSite=Lax`; JavaScript ga ne može pročitati.
- Svaki zahtjev koji mijenja stanje mora poslati zaglavlje `X-XSRF-TOKEN` s trenutnom vrijednošću kolačića `XSRF-TOKEN`.
- Zahtjevi moraju dolaziti s hosta upisanog u `SANCTUM_STATEFUL_DOMAINS`. Pošto web aplikacija i API koriste isti origin, nema CORS odobrenja.
- Sesija u pretraživaču vezana je za ID uređaja s kojim je izvršena prijava (vidi `X-Device-Id`).
- Sesije ističu nakon `SESSION_LIFETIME` minuta neaktivnosti (standard 480 = 8 sati). Promjena lozinke odjavljuje sve ostale sesije.

### 2.2 Integracije (kasa, knjigovodstvo) – API tokeni

Tokene kreira vlasnik ili vlasnica pod **Settings → API** (dozvola `api_tokens.manage`). Slanje:

```http
Authorization: Bearer gcp_…
```

Svojstva tokena:

| Svojstvo | Ponašanje |
|---|---|
| Identitet | Djeluje kao osoba koja je kreirala token |
| Abilities | Ograničen na dozvole izabrane pri kreiranju – uvijek podskup dozvola te osobe |
| Trajanje | najviše `API_TOKEN_MAX_DAYS` (standard 365 dana); bez navođenja postavlja se maksimum |
| Prikaz | Tekst tokena (`plain_text_token`) vraća se **samo jednom** pri kreiranju |
| Pohrana | SHA-256 hash; prefiks `gcp_` omogućava secret scanning (npr. GitHub Push Protection) |
| Opoziv | u svakom trenutku preko **Settings → API** ili `POST /api-tokens/{id}/revoke`; deaktiviranjem korisnika opozivaju se i njegovi tokeni |
| Praćenje | `last_used_at`, `last_used_ip` |

API tokeni ne koriste kolačiće i zato im ne treba CSRF token.

**Preporuka za integracije s kasom:** poseban token za svaku kasu samo s potrebnim abilities (npr. `cards.scan`, `cards.view`, `cards.redeem`), trajanje što kraće je praktično, i fiksni `X-Device-Id` za svaku kasu.

### 2.3 Nativna aplikacija za konobare (GiftCard Waiter) – tokeni vezani za uređaj

Nativna aplikacija za Android i iPhone ne prijavljuje se kolačićima, nego preuzima token vezan za uređaj:

```http
POST /api/v1/auth/token
     {"email":"…","password":"…","device_id":"<16–64 chars>","device_name":"Pixel 7","platform":"android"|"ios"}
→ 201 {"data": {"token": "gcp_…", "expires_at": "…", "user": SessionUser}}
```

Token se šalje kao `Authorization: Bearer …`, **uvijek zajedno s istim `X-Device-Id`**. Svojstva:

| Svojstvo | Ponašanje |
|---|---|
| Opseg | Samo skeniranje i iskorištavanje (abilities `cards.scan`, `cards.redeem`); dostupni su isključivo `auth/me`, `auth/logout`, `scan`, `cards/{id}/redeem` i `devices/current` – i za vlasnike i vlasnice |
| Vezanost za uređaj | Važi samo s `X-Device-Id` za koji je izdat; drugi ID → `401` |
| Blokada uređaja | Ako se uređaj opozove pod **Devices**, pristup odmah prestaje (`403 DEVICE_REVOKED`); nakon vraćanja uređaja token ponovo radi |
| Trajanje | Ističe nakon `DEVICE_TOKEN_DAYS` (standard 30) dana bez korištenja i produžava se dok se telefon koristi |
| Zamjena | Ako se ista osoba ponovo prijavi na istom telefonu, dosadašnji token se zamjenjuje; `POST /auth/logout` ga opoziva |
| Prikaz | Tokeni uređaja ne pojavljuju se pod **Settings → API** |

Važe isto zaključavanje naloga (`423 ACCOUNT_LOCKED`), isto ograničenje broja zahtjeva (`login`) i iste provjere naloga kao kod `/auth/login`. Deaktivirani nalog ovdje i kod svakog kasnijeg zahtjeva sa svojim tokenom dobija `401 ACCOUNT_DEACTIVATED`. Administratori platforme i uloge bez dozvole za skeniranje i iskorištavanje dobijaju `403 FORBIDDEN`.

## 3. Zaglavlja

| Zaglavlje | Smjer | Značenje |
|---|---|---|
| `Idempotency-Key` | zahtjev | **Obavezno** za `redeem`, `reload`, `transfer`; opcionalno za `POST /cards`. Vidi 3.1. |
| `X-Device-Id` | zahtjev | Stabilan, nasumičan ID uređaja (16–64 znaka `[A-Za-z0-9-]`; nevažeće vrijednosti se ignorišu). Registruje uređaj; opozvani uređaji dobijaju `403 DEVICE_REVOKED`. Sesija u pretraživaču vezana je za ID uređaja pri prijavi – drugi ID s istim session kolačićem dovodi do `401`. |
| `X-Restaurant-Id` | zahtjev | Samo administratori platforme: rad u kontekstu određenog restorana. |
| `X-Request-Id` | oba | ID za korelaciju (8–64 znaka `[A-Za-z0-9-]`). Vraća se u odgovoru; ako nedostaje ili je nevažeći, server generiše UUID. Pojavljuje se u zapisniku aktivnosti i u logovima aplikacije. |
| `X-XSRF-TOKEN` | zahtjev | Samo sesije u pretraživaču: CSRF zaštita |
| `Retry-After` | odgovor | Kod `429`: sekunde do sljedećeg dozvoljenog pokušaja |

### 3.1 Pravila za Idempotency-Key

- Dužina 8–96 znakova, dozvoljeni su `A–Z`, `a–z`, `0–9`, `-`, `_`, `.`. Dvotačka `:` je rezervisana za interna knjiženja u ledgeru.
- **Novi ključ za svaku logičku operaciju** – najbolje UUID. Isti ključ koristi se za sva ponavljanja te operacije.
- Ponavljanje s istim ključem i identičnim zahtjevom: server vraća originalni rezultat s `"replayed": true` i **ne** knjiži ponovo.
- Isti ključ za **drugi** zahtjev (druga kartica, drugi iznos): `409 IDEMPOTENCY_CONFLICT`.
- Ključ je u ledgeru pohranjen kao jedinstven po restoranu.
- Kod mrežnih grešaka ili isteka vremena: ponovite s **istim** ključem. Kod konačnog odbijanja (4xx, npr. `INSUFFICIENT_BALANCE`) za sljedeći pokušaj generišite **novi** ključ.
- Ako ključ nedostaje ili je nevažeći: `400 IDEMPOTENCY_KEY_REQUIRED`.

## 4. Greške

Svaka greška ima istu strukturu:

```json
{ "message": "The gift card balance is insufficient for this amount.",
  "code": "INSUFFICIENT_BALANCE",
  "context": { "balance": 3150, "requested": 3151 } }
```

Kod grešaka validacije `errors` sadrži poruke po polju. Integracije trebaju reagovati na `code`, ne na `message` (tekst se može promijeniti).

| HTTP | `code` | Kada |
|---|---|---|
| 400 | `IDEMPOTENCY_KEY_REQUIRED` | `Idempotency-Key` nedostaje ili je nevažeći |
| 401 | `UNAUTHENTICATED` | Nema sesije ili tokena, ili su istekli |
| 401 | `ACCOUNT_DEACTIVATED` | Samo nativna aplikacija za konobare (prijava i svaki zahtjev s tokenom uređaja): nalog je deaktiviran |
| 403 | `FORBIDDEN` | Nedostaje dozvola |
| 403 | `TENANT_NOT_RESOLVED` | Administrator platforme poziva krajnju tačku restorana bez `X-Restaurant-Id` |
| 403 | `RESTAURANT_SUSPENDED` | Restoran je suspendovan |
| 403 | `DEVICE_REVOKED` | Uređaj je opozvan |
| 403 | `CARD_FOREIGN_RESTAURANT` | Kartica pripada drugom restoranu |
| 403 | `NFC_UID_MISMATCH` | Čip se razlikuje od vezanog čipa (sumnja na klon) |
| 403 | `NFC_SIGNATURE_INVALID` | NTAG 424 SUN MAC nevažeći ili nedostaje |
| 403 | `NFC_REPLAY_DETECTED` | NTAG 424 brojač dodira ne raste (kopirani URL) |
| 409 | `NFC_TAG_IN_USE` | Čip pripada drugoj upotrebljivoj kartici |
| 409 | `NFC_ATTEMPT_INVALID` | Korak programiranja NFC-a bez odgovarajućeg otvorenog pokušaja |
| 409 | `NFC_CARD_ALREADY_PROGRAMMED` | Stanica za programiranje: kartica je u međuvremenu programirana na drugom uređaju |
| 422 | `NFC_VERIFICATION_FAILED` | Ponovo pročitani tag ne odgovara (`context.reason`: `URL_MISMATCH` ili `TAG_SWAPPED`); ništa nije spremljeno |
| 403 | `ROLE_ASSIGNMENT_FORBIDDEN` | Upravljanje ulogama ili korisnicima iznad vlastitog ranga |
| 404 | `NOT_FOUND`, `CARD_NOT_FOUND` | Nepoznat resurs (ili resurs drugog restorana) |
| 409 | `INVALID_CARD_STATE` | Radnja nije dozvoljena u trenutnom statusu kartice |
| 409 | `IDEMPOTENCY_CONFLICT` | Ključ ponovo korišten za drugi zahtjev |
| 409 | `TRANSACTION_NOT_REVERSIBLE` | Već stornirano ili pogrešan tip knjiženja |
| 419 | `CSRF_TOKEN_MISMATCH` | Ponovo pozovite `/sanctum/csrf-cookie` i ponovite |
| 422 | `VALIDATION_FAILED` | `errors` sadrži poruke po poljima |
| 422 | `INSUFFICIENT_BALANCE`, `INVALID_AMOUNT`, `CARD_BLOCKED`, `CARD_EXPIRED`, `CARD_NOT_REDEEMABLE`, `BALANCE_LIMIT_EXCEEDED`, `RELOAD_NOT_ALLOWED` | Poslovna pravila |
| 423 | `ACCOUNT_LOCKED` | Previše neuspjelih prijava (`retry_after` u sekundama, i u `context`) |
| 429 | `TOO_MANY_REQUESTS`, `SCAN_THROTTLED`, `VELOCITY_LIMIT_EXCEEDED` | Ograničenja broja zahtjeva odnosno ograničenja protiv prevare. `VELOCITY_LIMIT_EXCEEDED` sadrži `context.retry_after` (sekunde dok se u jednosatnom prozoru kartice ne oslobodi mjesto za iskorištavanje) |

## 5. Ograničenja broja zahtjeva (rate limits)

| Limiter | Granica |
|---|---|
| `login` | 5/min po e-mailu + IP, 30/min po IP (prijava u pretraživaču i u nativnoj aplikaciji za konobare) |
| `app-config` | 60/min po IP |
| `password-reset` | 5/min po IP |
| `public-card` | 20/min po IP |
| `card-scan` | 90/min po korisniku **i uređaju** (`X-Device-Id`); neuspjeli ili sumnjivi upiti (nije pronađeno, strana kartica, razlika UID-a, nevažeći SUN potpis, replay) dodatno 10 u 5 minuta po korisniku i po IP (`SCAN_FAILURE_LIMIT`, `SCAN_FAILURE_DECAY`) |
| `card-operation` | 90/min po korisniku i uređaju (`redeem`, `reload`, `transfer`) |
| `api` | 240/min po korisniku (sve autentifikovane krajnje tačke) |

Dodatna poslovna ograničenja po restoranu (Settings → Gift cards): maksimalan broj iskorištavanja po kartici po satu (standard 10, greška `VELOCITY_LIMIT_EXCEEDED`), maksimalno pojedinačno iskorištavanje, maksimalno stanje kartice. Nakon 10 uzastopnih pogrešnih lozinki nalog se zaključava na 15 minuta (`LOGIN_LOCKOUT_THRESHOLD`, `LOGIN_LOCKOUT_MINUTES`).

Kod `429` poštujte zaglavlje `Retry-After` i ne ponavljajte odmah.

## 6. Paginacija

Krajnje tačke za liste prihvataju `page` i `per_page` (najviše 100) i vraćaju:

```json
{ "data": [ … ], "links": { "next": "…" }, "meta": { "current_page": 1, "last_page": 4, "per_page": 25, "total": 88 } }
```

## 7. Krajnje tačke

Dozvole su navedene u uglastim zagradama. `→` prikazuje tijelo odgovora. Sve putanje su relativne u odnosu na `/api/v1`.

### 7.1 Autentifikacija

| Metoda | Putanja | Opis |
|---|---|---|
| POST | `/auth/login` | `{email, password, remember}` → `{data: SessionUser}` (rate limit `login`) |
| POST | `/auth/token` | Prijava nativne aplikacije za konobare (vidi 2.3) → `201 {data: {token, expires_at, user}}` (rate limit `login`) |
| POST | `/auth/logout` | Završava sesiju odnosno opoziva trenutni API token |
| GET | `/auth/me` | Prijavljena osoba uklj. `permissions[]`, postavke restorana i obavještenja platforme (`support_email`, `notice`) |
| PUT | `/auth/profile` | `{name?, locale?}` |
| PUT | `/auth/password` | `{current_password, password, password_confirmation}` – odjavljuje ostale sesije |
| POST | `/auth/forgot-password` | `{email}` – uvijek odgovara s 200 (nije moguće otkriti postoji li nalog) |
| POST | `/auth/reset-password` | `{token, email, password, password_confirmation}` |

### 7.2 Skeniranje – ulazna tačka za konobare `[cards.scan]`

```http
POST /scan
{ "method": "nfc", "token": "https://app.example.com/c/3f2b…a6c", "nfc_uid": "04:A2:3F:1B:6C:80:12" }
```

| Polje | Opis |
|---|---|
| `method` | `nfc` · `qr` · `link` · `manual` · `api` |
| `token` | Sirovi URL ili token s taga odnosno QR koda (SUN parametri `picc`/`cmac` preuzimaju se iz URL-a) |
| `card_number` | Umjesto `token` kod ručnog unosa |
| `nfc_uid` | Serijski broj čipa (Web NFC `serialNumber`) – aktivira prepoznavanje klonova |
| `picc`, `cmac` | NTAG 424 DNA SUN vrijednosti (ako nisu u URL-u) |

```json
→ { "data": { "id": "…", "restaurant_name": "Trattoria Bella Vista", "card_number": "1223 5616 2557 6350",
     "status": "active", "currency": "EUR", "balance": 3390, "expires_at": "2029-09-13T21:59:59+00:00",
     "is_expired": false, "blocked_reason": null, "allow_partial_redemption": true,
     "actions": { "redeem": true, "reload": false, "history": false, "block": false, "activate": false } } }
```

`/scan` **nikada** ne vraća podatke o kupcima. Svaki pokušaj bilježi se u tabeli `nfc_scans`; sumnjivi rezultati dodatno kao `warning` u logu aplikacije.

### 7.3 Kartice

| Metoda | Putanja | Dozvola | Tijelo / napomene |
|---|---|---|---|
| GET | `/cards` | cards.view | `search, status[] (csv), customer_id, created_from/to, expires_from/to, min_balance, max_balance, sort (±created_at, ±balance, ±expires_at, ±card_number, ±last_used_at), page, per_page` |
| GET | `/cards/export` | cards.export | Isti filteri → CSV u streamu (`;`, UTF-8 s BOM, decimalni zarez za njemačke lokalizacije, čitljivi nazivi statusa, zaštićeno od formula injection) |
| POST | `/cards` | cards.create | `{value, expires_at?, customer_id? \| customer{first_name,last_name,email,phone}?, recipient_name?, notes?, activate?=true, nfc_tag_type?}` → `{data: GiftCard, transaction, nfc: {url, tag_type_hint, ndef_template}}`. `Idempotency-Key` opcionalan. |
| GET | `/cards/{id}` | cards.view | |
| PATCH | `/cards/{id}` | cards.update | `{customer_id?, recipient_name?, notes?, expires_at?}` |
| POST | `/cards/{id}/redeem` | cards.redeem | **Idempotency-Key** · `{amount, reference?, note?}` → `201 {data:{card, transaction}, replayed}` |
| POST | `/cards/{id}/reload` | cards.reload | **Idempotency-Key** · `{amount, reference?, note?}` |
| POST | `/cards/{id}/transfer` | cards.transfer | **Idempotency-Key** · `{target_card_id \| target_card_number, amount? (standard: cijelo stanje), note?}` |
| POST | `/cards/{id}/activate` | cards.activate | neaktivna → aktivna |
| POST | `/cards/{id}/block` | cards.block | `{reason}` |
| POST | `/cards/{id}/unblock` | cards.unblock | |
| POST | `/cards/{id}/expire` | cards.expire | `{reason?}` – isknjižava preostalo stanje |
| POST | `/cards/{id}/replace` | cards.replace | `{reason, nfc_tag_type?}` → nova kartica (201) s preostalim stanjem; stara kartica dobija status `replaced` |
| GET | `/cards/{id}/history` | cards.view | Ledger i događaji, najnoviji prvi |
| GET | `/cards/{id}/nfc` | cards.write_nfc | NFC sadržaj (URL, NTAG 424 predložak, pravilo zaključavanja) |
| POST | `/cards/{id}/nfc/check` | cards.write_nfc | Korak programiranja 2: `{attempt_id (uuid), uid, current_url?}` → `status` `available` · `already_programmed` · `refused` (s `reason`, `conflict`, `content`, `expected_url`) |
| POST | `/cards/{id}/nfc` | cards.write_nfc | Evidentiranje taga. `method: web_nfc` → `{attempt_id, tag_type (ntag213/215/216), uid, read_back: {uid, url}}` – čip se sprema samo ako je ponovo pročitani čip isti i nosi tačno link kartice. `manual` · `provisioned` (NTAG 424) · `printed` (QR) – nikad s `uid` |
| POST | `/cards/{id}/nfc/lock` | cards.write_nfc | `{attempt_id}` – provjereni tag je zaključan za pisanje |
| POST | `/cards/{id}/nfc/attempts` | cards.write_nfc | Prijava greške iz preglednika: `{attempt_id, stage, result (failed · refused · cancelled), error_code, …}` |
| GET | `/cards/{id}/nfc/attempts` | cards.write_nfc | Posljednjih 50 pokušaja programiranja kartice |
| GET | `/cards/{id}/qr` | cards.write_nfc | `image/svg+xml` – QR kod URL-a kartice |

**Datum isteka (`expires_at`)** je lokalni datum `YYYY-MM-DD`: kartica važi do 23:59:59 tog dana u vremenskoj zoni restorana. Kod `POST /cards` važi: ako se ključ *izostavi*, primjenjuje se standardna važnost restorana; ako se izričito pošalje `null`, nastaje kartica bez isteka. Prošli datumi → `422`.

**Statusi kartice:** `inactive`, `active`, `redeemed`, `blocked`, `expired`, `replaced`.

### 7.4 Knjiženja (Transactions)

| Metoda | Putanja | Dozvola | Parametri |
|---|---|---|---|
| GET | `/transactions` | transactions.view | `type[] (csv), gift_card_id, user_id, from, to (lokalni datumi restorana), search` |
| GET | `/transactions/export` | transactions.export | CSV s čitljivim nazivima tipova (`Sale`, `Redemption`, `Reload`, `Transfer in/out`, …) |
| GET | `/transactions/{id}` | transactions.view | |
| POST | `/transactions/{id}/reverse` | transactions.reverse | `{reason}` – protuknjiženje za iskorištavanje ili dopunu |

Tipovi knjiženja u ledgeru: `issue`, `redemption`, `reload`, `transfer_out`, `transfer_in`, `expiration`, `reversal`, `adjustment`. Ledger je nepromjenjiv; ispravke se vrše isključivo protuknjiženjem.

### 7.5 Dashboard `[dashboard.view]`

| Metoda | Putanja | Sadržaj |
|---|---|---|
| GET | `/dashboard/stats` | Pokazatelji: `outstanding_balance` + `outstanding_cards` (otvorena obaveza i broj kartica), `monthly_revenue` / `previous_month_revenue`, `monthly_redeemed` / `today_redeemed`, prodate kartice (ukupno / ovaj mjesec / aktivne), `expiring_soon` |
| GET | `/dashboard/charts?days=7\|30\|90` | `daily[] {date, sold, redeemed, transactions}`, `monthly[]` (12 mjeseci), `status_distribution[]` |
| GET | `/dashboard/activity?limit=10` | Posljednja knjiženja |

### 7.6 Kupci

| Metoda | Putanja | Dozvola | Napomena |
|---|---|---|---|
| GET | `/customers` | customers.view | |
| POST | `/customers` | customers.manage | |
| GET | `/customers/{id}` | customers.view | |
| PATCH | `/customers/{id}` | customers.manage | |
| POST | `/customers/{id}/anonymize` | customers.manage | Brisanje prema GDPR-u: uklanja lične podatke, ledger ostaje potpun |

### 7.7 Tim, uloge, uređaji

| Metoda | Putanja | Dozvola | Napomena |
|---|---|---|---|
| GET | `/roles` | users.view | |
| GET | `/users` | users.view | |
| POST | `/users` | users.manage | `{name, email, role: owner\|manager\|waiter, password?}` – bez lozinke šalje se pozivnica (link važi 72 sata) |
| GET | `/users/{id}` | users.view | |
| PATCH | `/users/{id}` | users.manage | |
| POST | `/users/{id}/deactivate` | users.manage | opoziva tokene i sesije |
| POST | `/users/{id}/activate` | users.manage | |
| POST | `/users/{id}/password-reset` | users.manage | šalje reset lozinke; osobama koje se nikada nisu prijavile ponovo šalje pozivnicu |
| GET | `/devices` | devices.view | |
| GET | `/devices/current` | prijavljeni | trenutni uređaj |
| PATCH | `/devices/{id}` | devices.manage | npr. preimenovanje |
| POST | `/devices/{id}/revoke` | devices.manage | trenutno blokiranje uređaja |
| POST | `/devices/{id}/restore` | devices.manage | ponovno odobravanje uređaja |

### 7.8 Postavke `[settings.manage]`

| Metoda | Putanja | Sadržaj |
|---|---|---|
| GET | `/settings` | Postavke restorana i kartica |
| PUT | `/settings/restaurant` | Profil, lokalizacija, vremenska zona |
| PUT | `/settings/cards` | Pravila kartica (vidi tabelu `restaurant_settings`) |
| GET | `/settings/notification-templates` | Važeći predlošci (override restorana ili standard) |
| PUT | `/settings/notification-templates/{key}` | `{locale, subject, body, is_active}` – kreira override restorana. Ključevi: `card_issued`, `card_reloaded`, `card_expiring`, `balance_low` |
| GET | `/api-tokens` | `[api_tokens.manage]` – lista tokena |
| POST | `/api-tokens` | `[api_tokens.manage]` – vraća `plain_text_token` **jednom** |
| POST | `/api-tokens/{id}/revoke` | `[api_tokens.manage]` |
| GET | `/audit-logs` | `[audit.view]` – filteri `action` (prefiks), `user_id`, `auditable_id`, `from`, `to` |

### 7.9 Javno (bez prijave)

| Metoda | Putanja | Sadržaj |
|---|---|---|
| GET | `/public/cards/{token}` | Podaci stranice stanja za goste (maskirani broj kartice, stanje, status, istek, naziv restorana). Može se isključiti po restoranu. 20/min po IP. |
| GET | `/app/config?platform=android\|ios&version=1.2.0` | Početna konfiguracija nativne aplikacije za konobare → `{data: {min_version: {android, ios}, update_required, maintenance_notice, support_email, card_domains}}`. `update_required` je `null` ako nedostaju `platform`/`version`. Minimalne verzije su sistemske postavke (`app.min_version.*`). `Cache-Control: public, max-age=60`; rate limit `app-config`. |

### 7.10 Administracija platforme

| Metoda | Putanja | Dozvola | Sadržaj |
|---|---|---|---|
| GET | `/admin/stats` | platform.restaurants.manage | Pokazatelji platforme |
| GET | `/admin/restaurants` | platform.restaurants.manage | |
| POST | `/admin/restaurants` | platform.restaurants.manage | `{name, …, owner:{name, email, password?}}` – kreira mandanta i pozivnicu za vlasnika ili vlasnicu |
| GET | `/admin/restaurants/{id}` | platform.restaurants.manage | |
| PATCH | `/admin/restaurants/{id}` | platform.restaurants.manage | |
| POST | `/admin/restaurants/{id}/suspend` | platform.restaurants.manage | `{reason}` |
| POST | `/admin/restaurants/{id}/reactivate` | platform.restaurants.manage | |
| GET | `/admin/audit-logs` | platform.audit.view | Zapisnik aktivnosti cijele platforme |
| GET | `/admin/system-settings` | platform.settings.manage | |
| PUT | `/admin/system-settings` | platform.settings.manage | `{settings: [{key, value}]}` – npr. `platform.maintenance_notice`, `platform.support_email`, `platform.default_plan` |

Za krajnje tačke restorana administratori platforme dodatno šalju `X-Restaurant-Id`.

### 7.11 Sistemske krajnje tačke

| Metoda | Putanja | Sadržaj |
|---|---|---|
| GET | `/sanctum/csrf-cookie` | postavlja `XSRF-TOKEN` (samo pretraživač) |
| GET | `/up` | Healthcheck: 200 kada su baza i keš dostupni (van `/api/v1`) |

## 8. Strukture podataka

`dashboard/src/lib/api/types.ts` preslikava svaki resurs polje po polje (`GiftCard`, `ScannedCard`, `Transaction`, `HistoryEntry`, `Customer`, `StaffUser`, `Device`, `Restaurant`, `AuditLog`, `ApiToken`, …). Ta datoteka je mjerodavna referenca tipova.

## 9. Primjeri s curl

Za primjere:

```bash
export BASE=https://app.giftcardpro.at/api/v1
export TOKEN=gcp_…                      # API token from Settings → API
export DEVICE=pos-01-4f9c2a7e1b3d5a     # fixed ID per till (16–64 chars)
```

### 9.1 Pretraga kartice po broju kartice

```bash
curl -X POST $BASE/scan \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" \
  -H "X-Device-Id: $DEVICE" \
  -d '{"method": "api", "card_number": "1223561625576350"}'
```

### 9.2 Iskorištavanje

```bash
curl -X POST https://app.example.com/api/v1/cards/$CARD/redeem \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"amount": 1850, "reference": "Bill 4711"}'
```

Robusno ponavljanje kod mrežnih grešaka – ključ se generiše jednom i ponovo koristi:

```bash
KEY=$(uuidgen)
for i in 1 2 3; do
  curl -fsS -X POST $BASE/cards/$CARD/redeem \
    -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" \
    -H "X-Device-Id: $DEVICE" -H "Idempotency-Key: $KEY" \
    -d '{"amount": 1850, "reference": "Bill 4711"}' && break
  sleep 2
done
```

### 9.3 Dopuna

```bash
curl -X POST $BASE/cards/$CARD/reload \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" \
  -H "X-Device-Id: $DEVICE" -H "Idempotency-Key: $(uuidgen)" \
  -d '{"amount": 2500, "reference": "Bill 4712"}'
```

### 9.4 Storniranje knjiženja

```bash
curl -X POST $BASE/transactions/$TRANSACTION/reverse \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" \
  -d '{"reason": "Wrong amount"}'
```

### 9.5 Izvoz knjiženja za period kao CSV

```bash
curl -G $BASE/transactions/export \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode "from=2026-10-01" --data-urlencode "to=2026-10-31" \
  -o transactions-2026-10.csv
```

### 9.6 Prijava putem pretraživača (za testiranje)

```bash
curl -c jar.txt -b jar.txt https://app.giftcardpro.at/sanctum/csrf-cookie
XSRF=$(grep XSRF-TOKEN jar.txt | awk '{print $7}' | python3 -c 'import sys,urllib.parse;print(urllib.parse.unquote(sys.stdin.read().strip()))')
curl -c jar.txt -b jar.txt -X POST https://app.giftcardpro.at/api/v1/auth/login \
  -H "Accept: application/json" -H "Content-Type: application/json" \
  -H "Referer: https://app.giftcardpro.at" -H "X-XSRF-TOKEN: $XSRF" \
  -d '{"email":"owner@example.at","password":"…","remember":false}'
```

## 10. Napomene za integracije

- **Nije zamjena za fiskalnu kasu.** GiftCard Pro ne izdaje račune. Prodaja i iskorištavanje dodatno se knjiže u fiskalnoj kasi restorana (nije pravni savjet – provjeriti s poreznim savjetnikom).
- Iznose uvijek šaljite u centima; bez brojeva s pomičnim zarezom.
- Za broj računa s kase koristite `reference` – to olakšava usklađivanje.
- Reagujte na `code`; kod `429` poštujte `Retry-After`; kod mrežnih grešaka ponavljajte s istim `Idempotency-Key`.
- Šaljite `X-Request-Id` i bilježite ga u vlastitom sistemu – to ubrzava traženje grešaka u podršci.
- Sigurnosne prijave na `security@giftcardpro.at`.

---

Verzija 1.0 · Stanje: septembar 2026.
