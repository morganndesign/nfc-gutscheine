# API dokumentacija

*Kompletna referenca REST API-ja v1 za GiftCard Pro: pojmovi, autentifikacija, zaglavlja, kodovi grešaka, ograničenja broja zahtjeva, sve krajnje tačke i primjeri.*

---

## 1. Osnove

| Svojstvo | Vrijednost |
|---|---|
| Bazni URL | `https://<APP_DOMAIN>/api/v1` (npr. `https://app.giftcardpro.at/api/v1`) |
| Format | isključivo JSON, UTF-8 (izuzetak: CSV izvozi) |
| Iznosi | uvijek u **najmanjim jedinicama (centima)** kao striktno cijeli broj: `1850` = 18,50 € |
| Vremenske oznake | ISO 8601 u UTC, npr. `2029-09-13T21:59:59+00:00` |
| ID-jevi | UUID |
| Obavezna zaglavlja | `Accept: application/json`; kod zahtjeva s tijelom `Content-Type: application/json` |

Rute: `backend/routes/api.php`. Resursi: `backend/app/Http/Resources/*`, preslikani polje po polje u `dashboard/src/lib/api/types.ts`.

API je razdvojen po mandantima: svaki pristup vidi isključivo podatke vlastitog restorana. ID-jevi drugih restorana ponašaju se kao nepostojeći ID-jevi (`404`).

## 2. Pojmovi

- **Vaučer (voucher)** – račun koji drži stanje. `kind` je `card` ili `digital`; `status` je `active`, `blocked` ili `expired`. *Prazan* vaučer je `active` vaučer s `balance` 0 (ne postoji poseban status). `voucher_number` je interni 16-cifreni broj za osoblje i podršku. Nikada se ne štampa na vaučer i nikada se ne prihvata kao dokaz ovlaštenja.
- **Medij** – način na koji se vaučer predočava. Trenutno je jedini medij **QR kod za štampu** digitalnog vaučera (`GCPV1.` + 43 base64url znaka = nasumična 256-bitna tajna). Server pohranjuje samo njen SHA-256 hash; sadržaj se vraća jednom, u odgovoru na prodaju.
- **Predočenje (presentment)** – dokaz da je medij vaučera ovdje, sada. Svako terećenje troši jedno predočenje. Jednokratno, važi 60 sekundi, vezano za restoran, vaučer, svrhu, osobu i uređaj.
- **Plaćanje (payment)** – kako je prodaja ili dopuna plaćena: `cash`, `card_terminal`, `bank_transfer`, `complimentary`.
- **Ledger** – `voucher_transactions` (`issue`, `redemption`, `reload`, `reversal`). Ledger, plaćanja i zapisnik aktivnosti se samo dopunjuju (append-only) i povezani su hash lancem.

## 3. Autentifikacija

Postoje tri postupka.

### 3.1 Pretraživač (dashboard, web kasa) – Sanctum SPA kolačići

```http
GET  /sanctum/csrf-cookie                     → sets XSRF-TOKEN cookie
POST /api/v1/auth/login                       headers: X-XSRF-TOKEN: <cookie value>
     {"email":"…","password":"…","remember":false}
```

- Session kolačić je `httpOnly`, `Secure` i `SameSite=Lax`; JavaScript ga ne može pročitati.
- Svaki zahtjev koji mijenja stanje šalje zaglavlje `X-XSRF-TOKEN` s trenutnom vrijednošću kolačića `XSRF-TOKEN`.
- Zahtjevi moraju dolaziti s hosta upisanog u `SANCTUM_STATEFUL_DOMAINS`. Pošto web aplikacija i API koriste isti origin, nema CORS odobrenja.
- Sesija je vezana za `X-Device-Id` koji je prvi poslala; drugi ID s istim session kolačićem odjavljuje sesiju (`401`).
- Sesija obnovljena iz kolačića „Zapamti me“ prihvata se samo na aktivnom uređaju koji je ta osoba već koristila; inače `401` i nova prijava.
- Sesije ističu nakon `SESSION_LIFETIME` minuta neaktivnosti (standard 480 = 8 sati).

### 3.2 Integracije (kasa, knjigovodstvo) – API tokeni

Tokene kreira vlasnik ili vlasnica pod **Settings → API** (dozvola `api_tokens.manage`). Slanje:

```http
Authorization: Bearer gcp_…
```

| Svojstvo | Ponašanje |
|---|---|
| Identitet | Djeluje kao osoba koja je kreirala token |
| Abilities | Ograničen na dozvole izabrane pri kreiranju – uvijek podskup dozvola te osobe |
| Trajanje | najviše `API_TOKEN_MAX_DAYS` (standard 365 dana) |
| Prikaz | Tekst tokena (`plain_text_token`) vraća se **samo jednom** pri kreiranju |
| Pohrana | SHA-256 hash; prefiks `gcp_` omogućava secret scanning (npr. GitHub Push Protection) |
| Opoziv | u svakom trenutku preko **Settings → API** ili `POST /api-tokens/{id}/revoke`; deaktiviranje osobe te promjena ili resetovanje njene lozinke opozivaju njene tokene |
| Praćenje | `last_used_at`, `last_used_ip` |

Administratori platforme ne mogu kreirati niti koristiti tokene. API tokeni ne koriste kolačiće i zato im ne treba CSRF token.

**Preporuka za integracije s kasom:** poseban token za svaku kasu samo s potrebnim abilities (npr. `vouchers.view`, `vouchers.redeem`), trajanje što kraće je praktično, i fiksni `X-Device-Id` za svaku kasu.

### 3.3 Nativna aplikacija za konobare (GiftCard Waiter) – tokeni vezani za uređaj

```http
POST /api/v1/auth/token
     {"email":"…","password":"…","device_id":"<16–64 chars [A-Za-z0-9-]>","device_name":"Pixel 7","platform":"android"|"ios"}
→ 201 {"data": {"token": "gcp_…", "expires_at": "…", "user": SessionUser}}
```

Token se šalje kao `Authorization: Bearer …`, **uvijek zajedno s istim `X-Device-Id`**. Svojstva:

| Svojstvo | Ponašanje |
|---|---|
| Abilities | `vouchers.redeem`; za uloge s `vouchers.sell` (menadžeri, vlasnici) dodatno `vouchers.sell`. Uloga se provjerava i pri svakom zahtjevu; pri dnevnom produženju abilities se usklađuju s ulogom |
| Dostupni zahtjevi | Samo sljedeći parovi metode i putanje (`EnforceDeviceToken`); sve ostalo → `403 FORBIDDEN` |
| Vezanost za uređaj | Važi samo s `X-Device-Id` za koji je izdat; drugi ID → `401 UNAUTHENTICATED` |
| Blokada uređaja | Ako se uređaj opozove pod **Devices**, pristup odmah prestaje (`403 DEVICE_REVOKED`); nakon vraćanja uređaja token ponovo radi |
| Trajanje | Ističe nakon `DEVICE_TOKEN_DAYS` (standard 30) dana bez korištenja i produžava se dok se telefon koristi |
| Zamjena i opoziv | Ako se ista osoba ponovo prijavi na istom telefonu, dosadašnji token se zamjenjuje; `POST /auth/logout` ga opoziva; resetovanje ili promjena lozinke ga opoziva |
| Prikaz | Tokeni uređaja ne pojavljuju se pod **Settings → API**; administratori platforme vide ih pod `/admin/api-tokens` (`kind: device`) |

| Metoda | Putanja |
|---|---|
| GET | `/auth/me` |
| POST | `/auth/logout` |
| GET | `/devices/current` |
| POST | `/presentments` |
| POST | `/vouchers/{voucher}/redemptions` |
| GET | `/vouchers/{voucher}/redemptions/{idempotencyKey}` |
| POST | `/vouchers` (prodaja; potrebno `vouchers.sell`) |

Prijava ima isto zaključavanje naloga, isto ograničenje broja zahtjeva i iste provjere naloga kao `/auth/login`. Deaktivirani nalog ovdje i kod svakog kasnijeg zahtjeva sa svojim tokenom dobija `401 ACCOUNT_DEACTIVATED`. Administratori platforme i uloge bez `vouchers.redeem` dobijaju `403 FORBIDDEN`.

### 3.4 Neuspjela prijava

Pogrešna lozinka, nepoznata adresa i privremeno zaključan nalog dobijaju isti odgovor `422 VALIDATION_FAILED` s istom porukom uz `email`. Lozinka se uvijek hešira, pa je i vrijeme odgovora isto. Nakon `LOGIN_LOCKOUT_THRESHOLD` (10) uzastopnih neuspjelih pokušaja nalog se zaključava na `LOGIN_LOCKOUT_MINUTES` (15) minuta.

## 4. Zaglavlja

| Zaglavlje | Smjer | Značenje |
|---|---|---|
| `Idempotency-Key` | zahtjev | **Obavezno** za `POST /vouchers`, `POST /vouchers/{id}/redemptions` i `POST /vouchers/{id}/reloads`. Vidi 4.1. |
| `X-Device-Id` | zahtjev | Stabilan, nasumičan ID uređaja (16–64 znaka `[A-Za-z0-9-]`). Registruje uređaj u restoranu; opozvani uređaji dobijaju `403 DEVICE_REVOKED`. Obavezan uz token uređaja. |
| `X-Request-Id` | oba | ID za korelaciju (8–64 znaka). Vraća se u odgovoru; ako nedostaje, server ga generiše. Pojavljuje se u zapisniku aktivnosti. |
| `X-XSRF-TOKEN` | zahtjev | Samo sesije u pretraživaču: CSRF zaštita |
| `Retry-After` | odgovor | Kod `429` od ograničivača: sekunde do sljedećeg dozvoljenog pokušaja |

### 4.1 Pravila za Idempotency-Key

- Dužina 8–96 znakova, dozvoljeni su `A–Z`, `a–z`, `0–9`, `-`, `_`, `.`.
- **Novi ključ za svaku logičku operaciju** – najbolje UUID. Isti ključ koristi se za sva ponavljanja te operacije.
- Ponavljanje s istim ključem i identičnim zahtjevom: server vraća originalni rezultat s `"replayed": true` (HTTP 200) i **ne** knjiži ponovo.
- Isti ključ za **drugi** zahtjev (drugi vaučer, drugi iznos): `409 IDEMPOTENCY_CONFLICT`.
- Ključ je u ledgeru pohranjen kao jedinstven po restoranu.
- Ključ koji se kasnije provjerava s `GET /vouchers/{id}/redemptions/{key}` mora odgovarati `[A-Za-z0-9_-]{16,100}` (UUID to ispunjava).
- Kod mrežnih grešaka ili isteka vremena: ishod provjerite s istim ključem (iskorištavanje, vidi 8.3.3) odnosno ponovite s **istim** ključem. Kod konačnog odbijanja (4xx, npr. `INSUFFICIENT_BALANCE`) za sljedeći pokušaj generišite **novi** ključ.
- Ako ključ nedostaje ili je nevažeći: `400 IDEMPOTENCY_KEY_REQUIRED`.

## 5. Greške

Svaka greška ima istu strukturu:

```json
{ "message": "The voucher balance is insufficient for this amount.",
  "code": "INSUFFICIENT_BALANCE",
  "context": { "balance": 3150, "requested": 3151 } }
```

`context` postoji samo kada ima sadržaj. Kod grešaka validacije `errors` sadrži poruke po polju. Integracije reaguju na `code`, ne na `message` (tekst se može promijeniti).

| HTTP | `code` | Kada |
|---|---|---|
| 400 | `IDEMPOTENCY_KEY_REQUIRED` | `Idempotency-Key` nedostaje ili je nevažeći |
| 401 | `UNAUTHENTICATED` | Nema sesije ili tokena, ili su istekli; token uređaja s drugim `X-Device-Id`; sesija korištena s drugog uređaja |
| 401 | `ACCOUNT_DEACTIVATED` | Prijava aplikacije za konobare i svaki zahtjev s tokenom uređaja deaktiviranog naloga |
| 403 | `FORBIDDEN` | Nedostaje dozvola, ili token uređaja izvan dozvoljenih zahtjeva |
| 403 | `TENANT_NOT_RESOLVED` | Krajnja tačka restorana pozvana bez restorana (administratori platforme) |
| 403 | `TENANT_MISMATCH` | Adresiran je zapis drugog restorana |
| 403 | `RESTAURANT_SUSPENDED` | Restoran je suspendovan |
| 403 | `DEVICE_REVOKED` | Uređaj je opozvan |
| 403 | `ROLE_ASSIGNMENT_FORBIDDEN` | Uloga ili token iznad vlastitog ranga odnosno vlastitih dozvola; administrator platforme kreira token |
| 403 | `COMPLIMENTARY_NOT_ALLOWED` | Plaćanje `complimentary` bez `vouchers.sell_complimentary` |
| 404 | `NOT_FOUND` | Nepoznat resurs ili resurs drugog restorana |
| 409 | `IDEMPOTENCY_CONFLICT` | Ključ ponovo korišten za drugi zahtjev |
| 409 | `INVALID_VOUCHER_STATE` | Promjena statusa nije dozvoljena u trenutnom statusu |
| 409 | `TRANSACTION_NOT_REVERSIBLE` | Pogrešan tip knjiženja ili već stornirano |
| 409 | `IMMUTABLE_RECORD` | Pokušaj izmjene nepromjenjivog zapisa |
| 409 | `RESTAURANT_NOT_DELETABLE`, `INVITATION_NOT_POSSIBLE` | Administracija platforme (vidi tamo) |
| 419 | `CSRF_TOKEN_MISMATCH` | Ponovo pozovite `/sanctum/csrf-cookie` i ponovite |
| 422 | `VALIDATION_FAILED` | `errors` sadrži poruke po poljima (i svaka neuspjela prijava) |
| 422 | `MEDIUM_NOT_RECOGNIZED` | Skenirani tekst nije važeći vaučer ovog restorana (nepoznat, opozvan i strani izgledaju isto) |
| 422 | `PRESENTMENT_METHOD_UNAVAILABLE` | Za metodu ne postoji provjera (`live_auth`) |
| 422 | `PRESENTMENT_METHOD_NOT_ALLOWED` | Vrsta vaučera ne može se iskoristiti ovom metodom |
| 422 | `PRESENTMENT_INVALID` | Predočenje ne može pokriti ovo iskorištavanje; `context.reason`: `not_found`, `already_used`, `expired`, `wrong_purpose`, `wrong_voucher`, `other_user`, `other_device`, `method_not_allowed_for_kind`, `medium_revoked` |
| 422 | `VOUCHER_BLOCKED`, `VOUCHER_EXPIRED`, `VOUCHER_NOT_REDEEMABLE` | Status vaučera |
| 422 | `INSUFFICIENT_BALANCE`, `INVALID_AMOUNT`, `BALANCE_LIMIT_EXCEEDED`, `RELOAD_NOT_ALLOWED` | Poslovna pravila |
| 422 | `DEBIT_LIMIT_EXCEEDED` | `context.limit`: `per_transaction` ili `per_voucher_per_day`, `context.max`, kod dnevnog limita i `context.remaining` |
| 422 | `INVITATION_NOT_DELIVERED`, `MAIL_NOT_DELIVERED`, `MAIL_RECIPIENT_REJECTED` | Administracija platforme (vidi tamo) |
| 429 | `TOO_MANY_REQUESTS` | Ograničivač broja zahtjeva (`retry_after`) |
| 429 | `PRESENTMENT_THROTTLED` | Previše neuspjelih predočenja za ovaj restoran, osobu i uređaj (`context.retry_after`) |
| 429 | `VELOCITY_LIMIT_EXCEEDED` | Dostignut broj iskorištavanja po vaučeru po satu (`context.retry_after`: sekunde dok se ne oslobodi mjesto) |

## 6. Ograničenja broja zahtjeva (rate limits)

| Limiter | Granica | Važi za |
|---|---|---|
| `login` | 5/min po e-mailu + IP, 30/min po IP | `/auth/login`, `/auth/token` |
| `password-reset` | 5/min po IP | `/auth/forgot-password`, `/auth/reset-password` |
| `app-config` | 60/min po IP | `/app/config` |
| `presentment` | 90/min po osobi i `X-Device-Id` | `POST /presentments` |
| `voucher-operation` | 90/min po osobi i `X-Device-Id` | prodaja, iskorištavanje, dopuna, ishod iskorištavanja |
| `api` | 240/min po osobi | svaki autentifikovani zahtjev |

Neuspjela predočenja (skenirani tekst ništa ne dokazuje) broje se posebno: nakon `PRESENTMENT_FAILURE_LIMIT` (10) unutar `PRESENTMENT_FAILURE_DECAY` (300 s) po restoranu, osobi i uređaju `POST /presentments` odgovara s `429 PRESENTMENT_THROTTLED`. Skeniranja drugih gostiju iza iste javne IP adrese nikada se ne računaju.

Dodatna poslovna ograničenja po restoranu (**Settings → Vouchers**): maksimalno pojedinačno terećenje, maksimalno terećenje po vaučeru po danu, broj iskorištavanja po vaučeru po satu (standard 10), maksimalno stanje.

Kod `429` poštujte zaglavlje `Retry-After` odnosno `retry_after` i ne ponavljajte odmah.

## 7. Paginacija

Krajnje tačke za liste prihvataju `page` i `per_page` (najviše 100) i vraćaju:

```json
{ "data": [ … ], "links": { … }, "meta": { "current_page": 1, "last_page": 4, "per_page": 25, "total": 88 } }
```

## 8. Krajnje tačke

Dozvole su navedene u uglastim zagradama. Sve putanje su relativne u odnosu na `/api/v1`. Sve krajnje tačke osim *Javno* i prijave zahtijevaju autentifikaciju; krajnje tačke restorana dodatno zahtijevaju restoran (administratori platforme dobijaju `403 TENANT_NOT_RESOLVED`).

### 8.1 Autentifikacija

| Metoda | Putanja | Opis |
|---|---|---|
| POST | `/auth/login` | `{email, password, remember?}` → `{data: SessionUser}` |
| POST | `/auth/token` | Prijava nativne aplikacije za konobare (vidi 3.3) → `201 {data: {token, expires_at, user}}` |
| POST | `/auth/logout` | Završava sesiju odnosno opoziva trenutni token |
| GET | `/auth/me` | `SessionUser`: `id, name, email, locale, role {slug, name}, is_platform_admin, permissions[]` (s tokenom: samo ono što token smije), `restaurant {id, name, slug, currency, timezone, locale, status, settings}`, `platform {support_email, notice}` |
| PUT | `/auth/profile` | `{name?, locale? (en \| de)}` |
| PUT | `/auth/password` | `{current_password, password, password_confirmation}` – opoziva sve tokene i „Zapamti me“ te osobe |
| POST | `/auth/forgot-password` | `{email}` – uvijek isti odgovor `200`; link se šalje iz reda čekanja, samo aktivnim nalozima koji su prihvatili pozivnicu |
| POST | `/auth/reset-password` | `{token, email, password, password_confirmation}` – prihvata i pozivnicu (aktivira nalog); opoziva sve tokene i „Zapamti me“. Svaka greška daje isti `422` |

Linkovi za resetovanje lozinke i pozivnice nose token u fragmentu URL-a (`/reset-password#token=…&email=…`), koji pretraživač nikada ne šalje serveru.

### 8.2 Predočenja `[vouchers.redeem]`

```http
POST /presentments
{ "purpose": "spend", "method": "printable_qr", "credential": "GCPV1.q7Jx…" }
```

| Polje | Opis |
|---|---|
| `purpose` | `spend` |
| `method` | `printable_qr` (provjerava se); `live_auth` je predviđen za fizičke kartice i odgovara s `422 PRESENTMENT_METHOD_UNAVAILABLE` dok za njega ne postoji provjera |
| `credential` | Skenirani tekst QR koda (maks. 512 znakova) |

```json
→ 201 { "data": {
    "id": "…", "purpose": "spend", "method": "printable_qr", "level": "A1",
    "expires_at": "2026-09-29T12:01:00+00:00", "expires_in": 60,
    "voucher": { "id": "…", "kind": "digital", "restaurant_name": "Trattoria Bella Vista",
      "voucher_number": "1223 5616 2557 6350", "status": "active", "currency": "EUR", "balance": 3390,
      "expires_at": null, "is_expired": false, "blocked_reason": null,
      "allow_partial_redemption": true, "max_debit_per_transaction": 25000,
      "actions": { "redeem": true } } } }
```

`expires_in` je broj preostalih sekundi iz perspektive servera; klijenti odbrojavaju od prijema, nezavisno od vlastitog sata. Dio o vaučeru (`PresentedVoucher`) nikada ne sadrži podatke o kupcima. Zaglavlje odgovora `Cache-Control: no-store, private`.

Pravila: predočenje važi 60 sekundi i za jedno terećenje. Vezano je za ovaj restoran, ovaj vaučer, svrhu, osobu i uređaj (predočenje napravljeno bez uređaja može se koristiti samo bez uređaja). Pravila iskorištavanja po vrsti: `digital` vaučer iskorištava se samo QR metodom, `card` vaučer samo s `live_auth`. Neuspjelo predočenje bilježi se u zapisniku aktivnosti (`presentment.failed`) i računa se za zaključavanje.

### 8.3 Vaučeri

| Metoda | Putanja | Dozvola | Tijelo / napomene |
|---|---|---|---|
| GET | `/vouchers` | vouchers.view | `search` (cifre broja vaučera, primalac, napomene, kupac), `status[]` ili lista odvojena zarezom (`active`, `blocked`, `expired`), `kind`, `customer_id`, `created_from/to`, `expires_from/to`, `min_balance`, `max_balance`, `sort` (±`created_at`, ±`balance`, ±`expires_at`, ±`voucher_number`, ±`last_used_at`), `page`, `per_page` |
| GET | `/vouchers/export` | vouchers.export | Isti filteri → CSV u streamu (`;`, UTF-8 s BOM, decimalni zarez za njemačke lokalizacije, čitljivi nazivi statusa, zaštićeno od formula injection) |
| POST | `/vouchers` | vouchers.sell | **Idempotency-Key** · prodaja digitalnog vaučera, vidi 8.3.1 |
| GET | `/vouchers/{id}` | vouchers.view | `Voucher` s `customer`, `issued_by`, `media[]`, `payments[]` |
| PATCH | `/vouchers/{id}` | vouchers.update | `{customer_id?, recipient_name?, notes?}` |
| POST | `/vouchers/{id}/redemptions` | vouchers.redeem | **Idempotency-Key** · vidi 8.3.2 |
| GET | `/vouchers/{id}/redemptions/{idempotencyKey}` | vouchers.redeem | Ishod jednog vlastitog pokušaja iskorištavanja, vidi 8.3.3 |
| POST | `/vouchers/{id}/reloads` | vouchers.reload | **Idempotency-Key** · `{amount, payment: {method, reference?, reason?}, note?}` → `201 {data: {voucher, transaction}, replayed}` |
| POST | `/vouchers/{id}/block` | vouchers.block | `{reason}` (3–500 znakova) |
| POST | `/vouchers/{id}/unblock` | vouchers.unblock | Nazad na `active`, ili na `expired` ako je datum isteka prošao dok je bio blokiran |
| POST | `/vouchers/{id}/expire` | vouchers.expire | `{reason}` – samo `active` vaučeri; **stanje ostaje sačuvano** |
| POST | `/vouchers/{id}/reinstate` | vouchers.reinstate | `{reason, expires_on?}` – samo `expired` vaučeri; `expires_on` (`YYYY-MM-DD`, nakon današnjeg dana) je novi posljednji dan važenja u vremenskoj zoni restorana, bez vrijednosti ili `null` = bez isteka |
| GET | `/vouchers/{id}/history` | vouchers.view | Stavke ledgera i događaji statusa, najnoviji prvi: `{id, kind: transaction \| event, type, label, amount, balance_after, reference, note, payment_method, reversed, user, device, created_at}` |

`Voucher`: `id, kind, voucher_number, voucher_number_formatted, status, currency, initial_value, balance, total_loaded, total_redeemed, expires_at, is_expired, blocked_at, blocked_reason, expired_at, recipient_name, notes, customer, issued_by, media[] {id, type, role, status, created_at, revoked_at}, payments[], last_used_at, created_at, updated_at`. `total_loaded` = prodaja + dopune.

**Istek.** Bez postavke važenja vaučer nema datum isteka. S postavkom (`validity_months`, najmanje 36) posljednji dan važenja određuje se pri prodaji, u vremenskoj zoni restorana. Pri isteku vaučer postaje `expired` i zadržava stanje; vlasnik ili vlasnica ga može ponovo aktivirati.

#### 8.3.1 Prodaja

```http
POST /vouchers
Idempotency-Key: 7b1c…
{ "value": 5000, "form": "printable",
  "payment": { "method": "card_terminal", "reference": "4711" },
  "customer": { "first_name": "Ana", "email": "ana@example.com" },
  "recipient_name": "Ana", "notes": "Rođendan" }
```

| Polje | Opis |
|---|---|
| `value` | Najmanje jedinice; unutar `min_voucher_value` i `max_voucher_balance` restorana |
| `form` | `printable` (digitalni vaučer s QR kodom za štampu) |
| `payment.method` | `cash`, `card_terminal` (zahtijeva `reference`: potvrda s terminala), `bank_transfer` (zahtijeva `reference`), `complimentary` (zahtijeva `reason`, 3–500 znakova, i `vouchers.sell_complimentary`) |
| `customer_id` ili `customer` | Opcionalno: postojeći kupac ili novi (`first_name, last_name, email, phone, marketing_consent`) |
| `recipient_name`, `notes` | Opcionalno |

```json
→ 201 { "data": Voucher, "transaction": Transaction, "payment": Payment,
        "printable": { "payload": "GCPV1.q7Jx…", "qr_svg": "<svg …>" }, "replayed": false }
```

Bez `vouchers.view` (npr. token aplikacije menadžera) `data` je samo `{id, kind, balance, currency}`. `printable.payload` vraća se samo ovdje i ne može se ponovo preuzeti; list za štampu prikazuje QR kod i restoran, nikada broj vaučera niti vrijednost. Ponavljanje s istim ključem vraća istu prodaju (`"replayed": true`, 200). Ako ponavljanje dolazi od iste osobe i s istog uređaja unutar 15 minuta, a vaučer je još aktivan i nekorišten, sadrži novi QR kod, a neviđeni se opoziva; inače je `printable` `null`.

#### 8.3.2 Iskorištavanje

```http
POST /vouchers/{voucher}/redemptions
Idempotency-Key: 3f0e…
{ "amount": 1850, "presentment_id": "…", "reference": "Račun 4711", "note": null }
```

```json
→ 201 { "data": { "voucher": Voucher | PresentedVoucher, "transaction": Transaction }, "replayed": false }
```

Dio o vaučeru je puni `Voucher` za osobe s `vouchers.view`, inače `PresentedVoucher`. U jednoj transakciji baze server zaključava predočenje i red vaučera, ponovo traži idempotency ključ (ponavljanje koje je čekalo na zaključavanje dobija prvi rezultat), troši predočenje, provjerava status, stanje, djelimično iskorištavanje, granice po iskorištavanju i po danu te satni limit, i dodaje stavku u ledger. Odbijeno iskorištavanje ostavlja predočenje nepotrošenim; ono važi do svog isteka.

#### 8.3.3 Ishod iskorištavanja

```http
GET /vouchers/{voucher}/redemptions/{idempotencyKey}
→ 200 { "data": { "status": "not_booked" } }
→ 200 { "data": { "status": "booked", "voucher": PresentedVoucher, "transaction": Transaction } }
```

Kasa čiji je zahtjev ostao bez odgovora pita ovdje umjesto da ponovo pošalje terećenje. Vidljivi su samo vlastiti pokušaji pozivaoca za taj vaučer; pitanje nikada ništa ne knjiži. `not_booked` je konačan tek kada pokušaj na serveru više ne može biti u toku; klijenti čekaju 60 sekundi nakon posljednjeg zahtjeva prije nego što ga smatraju konačnim. `Cache-Control: no-store, private`.

### 8.4 Knjiženja (Transactions)

| Metoda | Putanja | Dozvola | Parametri |
|---|---|---|---|
| GET | `/transactions` | transactions.view | `type[]` ili lista odvojena zarezom (`issue`, `redemption`, `reload`, `reversal`), `voucher_id`, `user_id`, `from`, `to` (lokalni datumi restorana), `search` (referenca ili broj vaučera) |
| GET | `/transactions/export` | transactions.export | CSV s čitljivim nazivima tipova (`Sale`, `Redemption`, `Reload`, `Reversal`) i načinom plaćanja |
| GET | `/transactions/{id}` | transactions.view | |
| POST | `/transactions/{id}/reverse` | transactions.reverse | `{reason}` – nova, suprotna stavka za iskorištavanje ili dopunu; najviše jednom po stavci, unutar granice stanja → `201 {data: Transaction}` |

`Transaction`: `id, type, type_label, amount` (s predznakom), `balance_before, balance_after, currency, reference, note, reversed, reversed_at, reversible, related_transaction_id, payment, voucher {id, kind, voucher_number, status}, user, device, created_at`. `reversed` se izvodi iz stavke storna koja pokazuje na original; nijedna stavka se nikada ne mijenja. `Payment`: `id, method, method_label, amount, currency, reference, reason, created_at`.

### 8.5 Dashboard `[dashboard.view]`

| Metoda | Putanja | Sadržaj |
|---|---|---|
| GET | `/dashboard/stats` | `currency, vouchers_sold, vouchers_sold_this_month, vouchers_active, vouchers_empty, vouchers_blocked, vouchers_expired, outstanding_balance, outstanding_vouchers, today_transactions, today_redeemed, monthly_revenue, previous_month_revenue, monthly_redeemed, expiring_soon` |
| GET | `/dashboard/charts?days=7\|30\|90` | `daily[] {date, sold, redeemed, transactions}`, `monthly[] {month, revenue, redeemed}` (12 mjeseci), `status_distribution[] {status, count, balance}` |
| GET | `/dashboard/activity?limit=10` | Posljednja knjiženja (maks. 50) |

### 8.6 Kupci

| Metoda | Putanja | Dozvola | Napomena |
|---|---|---|---|
| GET | `/customers` | customers.view | `search` |
| POST | `/customers` | customers.manage | `{first_name, last_name?, email?, phone?, notes?, marketing_consent?}` |
| GET | `/customers/{id}` | customers.view | `{data: Customer, vouchers: Voucher[]}` |
| PATCH | `/customers/{id}` | customers.manage | Ista polja; anonimizirani kupci ne mogu se uređivati (`409`) |
| POST | `/customers/{id}/anonymize` | customers.manage | Brisanje prema GDPR-u: uklanja lične podatke, imena primalaca na njihovim vaučerima i e-mail adresu u zapisniku obavještenja; ledger ostaje potpun |

### 8.7 Tim, uloge, uređaji

| Metoda | Putanja | Dozvola | Napomena |
|---|---|---|---|
| GET | `/roles` | users.view | |
| GET | `/users` | users.view | |
| POST | `/users` | users.manage | `{name, email, role: owner\|manager\|waiter, password?, locale?}` – bez lozinke šalje se pozivnica (link važi 72 sata) |
| GET | `/users/{id}` | users.view | |
| PATCH | `/users/{id}` | users.manage | |
| POST | `/users/{id}/deactivate` | users.manage | opoziva tokene i sesije |
| POST | `/users/{id}/activate` | users.manage | |
| POST | `/users/{id}/password-reset` | users.manage | osobama koje se nikada nisu prijavile ponovo šalje pozivnicu |
| GET | `/devices` | devices.view | |
| GET | `/devices/current` | prijavljeni | uređaj ovog zahtjeva ili `null` |
| PATCH | `/devices/{id}` | devices.manage | `{name?, type? (phone, tablet, desktop, pos, integration)}` |
| POST | `/devices/{id}/revoke` | devices.manage | trenutno blokiranje uređaja; završava i „Zapamti me“ njegovih korisnika |
| POST | `/devices/{id}/restore` | devices.manage | ponovno odobravanje uređaja |

### 8.8 Postavke `[settings.manage]`

| Metoda | Putanja | Sadržaj |
|---|---|---|
| GET | `/settings` | Postavke restorana i vaučera (s gornjim granicama platforme) |
| PUT | `/settings/restaurant` | Profil, adresa, `country`, `timezone`, `locale` (`de-AT`, `de-DE`, `de-CH`, `en-GB`, `en-US`) |
| PUT | `/settings/vouchers` | `validity_months` (`null` = bez isteka, inače 36–360), `min_voucher_value`, `max_voucher_balance`, `max_debit_per_transaction`, `max_debit_per_voucher_per_day` (svaka najviše do gornje granice platforme), `max_redemptions_per_voucher_per_hour` (0 = isključeno), `allow_reload`, `allow_partial_redemption`, `send_customer_emails`, `brand_color`, `receipt_footer` |
| GET | `/settings/notification-templates` | Važeći predlošci e-mailova za goste (`voucher_issued`, `voucher_reloaded`, `voucher_expiring`) |
| PUT | `/settings/notification-templates/{key}` | `{subject, body, is_active?, locale? (en \| de)}` – kreira override restorana |

E-mailovi za goste nikada ne sadrže stanje, iznos, broj vaučera niti link na vaučer.

| Metoda | Putanja | Dozvola | Sadržaj |
|---|---|---|---|
| GET / POST | `/api-tokens` | api_tokens.manage | POST `{name, abilities[], expires_at?}` → `{data: ApiToken, plain_text_token}` (prikazuje se **jednom**) |
| POST | `/api-tokens/{id}/revoke` | api_tokens.manage | |
| GET | `/audit-logs` | audit.view | filteri `action` (prefiks), `user_id`, `auditable_id`, `from`, `to` |

### 8.9 Javno (bez prijave)

| Metoda | Putanja | Sadržaj |
|---|---|---|
| GET | `/app/config?platform=android\|ios&version=2.0.0` | Početna konfiguracija aplikacije za konobare → `{data: {min_version: {android, ios}, update_required, maintenance_notice, support_email}}`. `update_required` je `null` bez `platform` i `version`. Minimalne verzije su sistemske postavke (`app.min_version.*`). `Cache-Control: public, max-age=60`; rate limit `app-config` |
| GET | `/up` (van `/api/v1`) | Healthcheck: baza i keš |

Ne postoji javna stranica vaučera niti javna provjera vaučera.

### 8.10 Administracija platforme `[platform.restaurants.manage]`

Administratori platforme upravljaju restoranima; nikada ne djeluju unutar restorana i nikada ne diraju vaučere.

| Metoda | Putanja | Sadržaj |
|---|---|---|
| GET | `/admin/stats` | `restaurants_total, restaurants_active, restaurants_archived, vouchers_total, vouchers_active, transactions_this_month, volume_sold_this_month` |
| GET | `/admin/restaurants?search=&status=active\|suspended\|archived` | Svaki s `owner {…, invitation}` i `archived_at` |
| POST | `/admin/restaurants` | `{name, slug?, …, currency? (EUR, CHF, USD, GBP), owner: {name, email, password?}}` – kreira restoran i nalog vlasnika te šalje pozivnicu → `201 {data, owner}` |
| GET | `/admin/restaurants/{id}` | I arhivirani: `{data, users[], business_data {vouchers, transactions, customers}}` |
| PATCH | `/admin/restaurants/{id}` | Polja profila, `plan`, `currency` |
| POST | `/admin/restaurants/{id}/suspend` `{reason}` · `/reactivate` | „Onemogući“ / „Omogući“ |
| POST | `/admin/restaurants/{id}/archive` `{reason?}` · `/restore` | Arhiviranje = soft delete: skriveno, korisnici i uređaji zaključani, podaci sačuvani |
| DELETE | `/admin/restaurants/{id}` | `{confirm: "<slug>"}` – trajno; `409 RESTAURANT_NOT_DELETABLE` (brojevi u `context`) kada postoje vaučeri, knjiženja ili kupci. Zapisnik aktivnosti ostaje |
| POST | `/admin/restaurants/{id}/invitation` · `/admin/restaurants/{id}/users/{user}/invitation` | `{name?, email?}` – nova pozivnica (prethodni link prestaje važiti; ispravlja pogrešno upisanu adresu). Šalje se iz reda čekanja: `202` dok čeka, `200` kada je poslana, `422 INVITATION_NOT_DELIVERED` kada ju je mail server odbio ili platforma e-mailove samo bilježi u log; `409 INVITATION_NOT_POSSIBLE` za prihvaćene, onemogućene ili arhivirane naloge |
| GET | `/admin/api-tokens?restaurant_id=&active=` | Tokeni svih restorana, integracije i uređaja (`kind`) |
| POST | `/admin/api-tokens/{id}/revoke` | Reakcija na incident |
| GET | `/admin/audit-logs?restaurant_id=&action=` | `[platform.audit.view]`, `action` = prefiks |
| GET / PUT | `/admin/system-settings` | `[platform.settings.manage]` – PUT `{settings: [{key, value}]}` |
| GET | `/admin/mail` | `[platform.settings.manage]` → `{mailer, delivers, from_address, from_name, host, port, problem}` (bez pristupnih podataka) |
| POST | `/admin/mail/test` | `[platform.settings.manage]` `{to?}` – testni e-mail na `to` ili prijavljenu osobu; primalac se prvo provjerava (s `MAIL_VERIFY_DOMAINS` njegova domena mora imati mail server). `422 MAIL_RECIPIENT_REJECTED` (550–553), `422 MAIL_NOT_DELIVERED` za druge greške |

Pozivnice: nalog postoji od početka s nepoznatom nasumičnom lozinkom. E-mail nosi jednokratni token password brokera `invitations` (vlastita tabela `invitation_tokens`, pohranjen kao hash, važi 72 h; nova pozivnica ga zamjenjuje). Izbor lozinke putem `POST /auth/reset-password` aktivira nalog (`user.invitation_accepted` u zapisniku aktivnosti). Svaki pokušaj bilježi se u `notification_logs` (`template_key = staff_invitation`). E-mail koristi jezik restorana kada postoji prevod (`de-*` → `de`, `en-*` → `en`), inače `MAIL_LOCALE` (standard `de`).

### 8.11 Sistemske krajnje tačke

| Metoda | Putanja | Sadržaj |
|---|---|---|
| GET | `/sanctum/csrf-cookie` | postavlja `XSRF-TOKEN` (samo pretraživač) |
| GET | `/up` | Healthcheck: 200 kada su baza i keš dostupni (van `/api/v1`) |

## 9. Strukture podataka

`dashboard/src/lib/api/types.ts` preslikava svaki resurs polje po polje (`Voucher`, `PresentedVoucher`, `Presentment`, `Transaction`, `Payment`, `HistoryEntry`, `Customer`, `StaffUser`, `Device`, `Restaurant`, `AuditLog`, `ApiToken`, …). Ta datoteka je mjerodavna referenca tipova.

## 10. Primjeri s curl

Za primjere:

```bash
export BASE=https://app.giftcardpro.at/api/v1
export TOKEN=gcp_…                      # API token from Settings → API
export DEVICE=pos-01-4f9c2a7e1b3d5a     # fixed ID per till (16–64 chars)
```

### 10.1 Predočenje i iskorištavanje vaučera

```bash
P=$(curl -s -X POST $BASE/presentments \
  -H "Authorization: Bearer $TOKEN" -H "X-Device-Id: $DEVICE" -H "Content-Type: application/json" -H "Accept: application/json" \
  -d "{\"purpose\":\"spend\",\"method\":\"printable_qr\",\"credential\":\"$QR\"}")
VOUCHER=$(echo "$P" | jq -r .data.voucher.id)
KEY=$(uuidgen)
curl -X POST "$BASE/vouchers/$VOUCHER/redemptions" \
  -H "Authorization: Bearer $TOKEN" -H "X-Device-Id: $DEVICE" -H "Content-Type: application/json" -H "Accept: application/json" \
  -H "Idempotency-Key: $KEY" \
  -d "{\"amount\": 1850, \"presentment_id\": \"$(echo "$P" | jq -r .data.id)\", \"reference\": \"Bill 4711\"}"
```

### 10.2 Provjera ishoda nakon izgubljenog odgovora

Terećenje se ne šalje ponovo; umjesto toga pita se s istim ključem:

```bash
curl -s "$BASE/vouchers/$VOUCHER/redemptions/$KEY" \
  -H "Authorization: Bearer $TOKEN" -H "X-Device-Id: $DEVICE" -H "Accept: application/json"
# → {"data":{"status":"booked", …}}  or  {"data":{"status":"not_booked"}}
```

### 10.3 Dopuna

```bash
curl -X POST $BASE/vouchers/$VOUCHER/reloads \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" \
  -H "X-Device-Id: $DEVICE" -H "Idempotency-Key: $(uuidgen)" \
  -d '{"amount": 2500, "payment": {"method": "cash"}}'
```

### 10.4 Storniranje knjiženja

```bash
curl -X POST $BASE/transactions/$TRANSACTION/reverse \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" \
  -d '{"reason": "Wrong amount"}'
```

### 10.5 Izvoz knjiženja za period kao CSV

```bash
curl -G $BASE/transactions/export \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode "from=2026-10-01" --data-urlencode "to=2026-10-31" \
  -o transactions-2026-10.csv
```

### 10.6 Prijava putem pretraživača (za testiranje)

```bash
curl -c jar.txt -b jar.txt https://app.giftcardpro.at/sanctum/csrf-cookie
XSRF=$(grep XSRF-TOKEN jar.txt | awk '{print $7}' | python3 -c 'import sys,urllib.parse;print(urllib.parse.unquote(sys.stdin.read().strip()))')
curl -c jar.txt -b jar.txt -X POST https://app.giftcardpro.at/api/v1/auth/login \
  -H "Accept: application/json" -H "Content-Type: application/json" \
  -H "Referer: https://app.giftcardpro.at" -H "X-XSRF-TOKEN: $XSRF" \
  -d '{"email":"owner@example.at","password":"…","remember":false}'
```

## 11. Napomene za integracije

- **Nije zamjena za fiskalnu kasu.** GiftCard Pro ne izdaje račune. Prodaja i iskorištavanje dodatno se knjiže u fiskalnoj kasi restorana (nije pravni savjet – provjeriti s poreznim savjetnikom).
- Iskorištavanje uvijek zahtijeva svježe predočenje vaučera (`POST /presentments`); broj vaučera nije dokaz ovlaštenja.
- Iznose uvijek šaljite u centima; bez brojeva s pomičnim zarezom.
- Za broj računa s kase koristite `reference` – to olakšava usklađivanje.
- Reagujte na `code`; kod `429` poštujte `Retry-After`; kod nepoznatog ishoda iskorištavanja pitajte `GET /vouchers/{id}/redemptions/{key}` umjesto ponovnog terećenja.
- Šaljite `X-Request-Id` i bilježite ga u vlastitom sistemu – to ubrzava traženje grešaka u podršci.
- Sigurnosne prijave na `security@giftcardpro.at`.

---

Verzija 2.0 · Stanje: septembar 2026.
