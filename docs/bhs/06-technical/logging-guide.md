# Vodič za logovanje

> **Napomena (Coolify deployment):** Produkcija od verzije 1.4.2 radi na **Coolify** sa `docker-compose.coolify.yml` (build iz izvornog koda, bez GHCR-a, bez deploy skripti). Komande sa `docker compose --env-file .env.production`, `infra/scripts/…`, `deploy.yml` ili Caddy na hostu u ovom dokumentu su zastarjele. Mjerodavni su [docs/DEPLOYMENT.md](../../DEPLOYMENT.md) (deployment, backup, restore, rad) i [docs/ENVIRONMENT.md](../../ENVIRONMENT.md).

*Izvori logova u GiftCard Pro, nivoi logovanja, razgraničenje od zapisnika aktivnosti i protokola skeniranja, lični podaci, korelacija preko X-Request-Id, pretraga, čuvanje i GDPR.*

---

## 1. Pregled

GiftCard Pro poznaje tri vrste zapisa s različitom svrhom:

| Vrsta | Mjesto pohrane | Svrha | Čuvanje |
|---|---|---|---|
| **Operativni logovi** | Docker logovi kontejnera (stdout/stderr) | traženje grešaka, nadzor, sigurnosne uzbune | kratko (rotacija, vidi odjeljak 3) |
| **Zapisnik aktivnosti (audit log)** | tabela `audit_logs` (samo dodavanje) | sljedivost sigurnosno i novčano relevantnih radnji za restorane i platformu | trajno (ništa se ne briše) |
| **Protokol skeniranja** | tabela `nfc_scans` (samo dodavanje) | svaki upit kartice s rezultatom – prepoznavanje prevara | trajno |

**Ledger** (`gift_card_transactions`) nije log datoteka, nego knjigovodstvena istina: svaka promjena stanja tamo je pohranjena s osobom, uređajem, IP adresom i vremenskom oznakom.

## 2. Izvori logova

| Izvor | Kontejner | Format | Sadržaj |
|---|---|---|---|
| Laravel (API) | `api` | tekst, jedan red po unosu, kontekst kao JSON (standardni Monolog format) | greške i izuzeci, sigurnosna upozorenja, napomene |
| PHP-FPM | `api` | tekst | izlaz workera (`catch_workers_output = yes`), PHP greške (`log_errors = On`); zavisno od baznog imagea dodatno FPM redovi pristupa |
| Queue worker | `queue` | tekst | obrađeni poslovi (`RUNNING`/`DONE`/`FAIL`), greške pri slanju e-maila |
| Scheduler | `scheduler` | tekst | izvršene naredbe noćnih poslova |
| Caddy | `caddy` | **JSON** | access log (svaki zahtjev: metoda, URI, status, trajanje, IP klijenta, user agent, zaglavlja) i vlastite poruke Caddyja (certifikati) |
| Next.js | `web` | tekst | pokretanje, greške na serveru |
| MySQL | `mysql` | tekst | pokretanje, greške, upozorenja |
| Redis | `redis` | tekst | pokretanje, AOF poruke, greške |

Konfiguracija Laravel izlaza (iz `backend/.env.production.example`):

```dotenv
LOG_CHANNEL=stderr
LOG_LEVEL=info
```

Kanal `stderr` piše u `php://stderr`; Docker prikuplja izlaz. Za JSON izlaz može se postaviti standardna Laravel varijabla `LOG_STDERR_FORMATTER=Monolog\Formatter\JsonFormatter` (nije postavljena u predlošku; olakšava mašinsku obradu kod slanja logova).

Lokalno (`backend/.env.example`): `LOG_CHANNEL=stack`, `LOG_STACK=daily`, `LOG_LEVEL=debug` → datoteke `backend/storage/logs/laravel-YYYY-MM-DD.log`, 14 dana (`LOG_DAILY_DAYS`).

## 3. Rotacija logova kontejnera

Svi servisi u `docker-compose.yml` koriste:

```yaml
logging:
  driver: json-file
  options: { max-size: "20m", max-file: "5" }
```

Po kontejneru se čuva najviše 5 datoteka po 20 MB (= 100 MB); stariji unosi se prepisuju. Koliko dana to pokriva zavisi od saobraćaja – kod `caddy` (jedan unos po zahtjevu) najmanje. Kada se kontejner ponovo kreira (npr. pri svakom deploymentu), njegovi logovi počinju iznova; stari tada više nisu dostupni preko `docker compose logs`.

**Posljedica:** logovi kontejnera nisu arhiva. Ono što je potrebno duže nalazi se u zapisniku aktivnosti, u `nfc_scans` ili se mora sačuvati slanjem logova (odjeljak 8).

## 4. Nivoi logovanja

| Nivo | Upotreba u GiftCard Pro |
|---|---|
| `debug` | Samo lokalno. `log` mailer na ovom nivou piše e-mailove (pozivnice, reset linkove) – **u produkciji nikada ne aktivirati**, inače su važeći linkovi u logu. |
| `info` | Standard za produkciju (`LOG_LEVEL=info`) |
| `notice` | Napomene frameworka |
| `warning` | **Sigurnosni događaji**: `Suspicious gift card scan`, `Account locked after repeated failed logins` |
| `error` | Izuzeci, neuspjeli poslovi, nedostupni servisi |
| `critical`, `alert`, `emergency` | Teške greške |

Preporuke:

- Produkcija: `info`. `warning` bi bio moguć, ali jedva štedi obim i skriva kontekst.
- Traženje grešaka u produkciji: `LOG_LEVEL` ne postavljati na `debug` (vidi gore). Umjesto toga ciljano tražiti po `X-Request-Id`.
- Promjena `LOG_LEVEL` djeluje tek nakon ponovnog pokretanja kontejnera (`config:cache` pri pokretanju).

## 5. Šta se gdje bilježi

| Događaj | Operativni log | Zapisnik aktivnosti | `nfc_scans` | Ledger |
|---|---|---|---|---|
| Upit kartice uspješan | – | – | ✓ (`ok`) | – |
| Kartica nije pronađena | – | – | ✓ (`not_found`) | – |
| Strana kartica, razlika UID-a, nevažeći potpis, replay | ✓ `warning` | ✓ (sigurnosni događaj) | ✓ | – |
| Upit ograničen (`throttled`) | ✓ `warning` | – | ✓ | – |
| Iskorištavanje, dopuna, transfer, storno, istek, prodaja | – | ✓ | – | ✓ |
| Blokiranje, deblokiranje, zamjena, aktiviranje kartice | – | ✓ | – | ✓ kod kretanja stanja |
| Prijava, odjava | – | ✓ | – | – |
| Pojedinačna neuspjela prijava | – | – (brojač na korisničkom nalogu) | – | – |
| Zaključavanje naloga | ✓ `warning` | ✓ | – | – |
| Izmjene tima, uređaja, tokena, postavki | – | ✓ | – | – |
| Administrator platforme radi u restoranu | – | ✓ | – | – |
| Izuzetak / greška servera | ✓ `error` | – | – | – |
| Slanje e-maila | log reda čekanja | – | – | – (tabela `notification_logs`) |
| HTTP zahtjev | Caddy ✓ | – | – | – |

### Sadržaj zapisnika aktivnosti

`audit_logs` sadrži: `restaurant_id`, `user_id`, `device_id`, `action` (npr. `gift_card.blocked`), pogođeni objekat, `old_values`, `new_values`, `metadata`, `ip_address`, `user_agent`, `request_id`, `created_at` (mikrosekunde). Restorani ga vide pod **Audit log** (`audit.view`), platforma u administraciji platforme.

### Sadržaj `nfc_scans`

`restaurant_id`, `gift_card_id` (prazno kod nepoznatih ili stranih kartica), `user_id`, `device_id`, `method`, `result` (`ok`, `not_found`, `foreign_restaurant`, `uid_mismatch`, `invalid_signature`, `replay`, `throttled`), `nfc_uid`, `read_counter`, `ip_address`, `user_agent`, `created_at`.

## 6. Lični podaci u logovima

| Zapis | Lični podaci | Zaštitna mjera |
|---|---|---|
| Zapisnik aktivnosti `old_values`/`new_values` | **bez** imena kupaca, e-mail adresa, brojeva telefona, napomena ili imena primalaca – samo činjenica da su izmijenjeni | `AuditLogger` redigira lozinke, tokene i tokene kartica; lična polja se ne kopiraju (test `HardeningTest`) |
| Zapisnik aktivnosti `ip_address`, `user_agent`, `user_id` | IP adrese i identifikacija pretraživača zaposlenih | svrha: sigurnost i sljedivost; pristup samo s `audit.view` |
| `nfc_scans` | IP adresa, user agent, UID čipa | svrha: prepoznavanje prevara |
| Ledger | korisnik, uređaj, IP | obaveza čuvanja (BAO § 132) |
| Laravel log (`warning`) | `user_id`, `ip`, `nfc_uid` | kratko čuvanje zbog rotacije |
| Caddy access log | IP klijenta, user agent, kompletan URI – i `/c/{token}` i `/api/v1/public/cards/{token}` (token kartice) | Caddy standardno zatamnjuje `Cookie`, `Set-Cookie` i `Authorization`; kratko čuvanje zbog rotacije |
| `notification_logs` | e-mail adresa primaoca | uklanja se pri anonimizaciji prema GDPR-u |

Napomene:

- **Tokeni kartica u access logu:** ko čita Caddy log, vidi URL-ove kartica. Token omogućava samo javni prikaz stanja (ako je aktiviran), ne i iskorištavanje. Ipak: pristup logovima servera ograničite na operativni tim i logove pri slanju ne prenosite trećim stranama van EU.
- **Bez podataka gostiju u operativnim logovima:** imena, e-mail adrese i brojevi telefona gostiju ne pojavljuju se u Laravel logovima. Kod vlastitih proširenja nikada ne logujte tijela zahtjeva ili modele s podacima kupaca.
- **Bez lozinki:** nigdje se ne bilježe.

## 7. Korelacija preko `X-Request-Id`

Svaki API zahtjev dobija ID za korelaciju:

1. Klijent šalje `X-Request-Id` (8–64 znaka `[A-Za-z0-9-]`) – u suprotnom server generiše UUID.
2. ID se nalazi u **svakom** Laravel redu loga tog zahtjeva (polje konteksta `request_id`).
3. Pohranjuje se u zapisniku aktivnosti (`audit_logs.request_id`).
4. Vraća se u odgovoru kao zaglavlje `X-Request-Id` – i time se pojavljuje i u Caddy access logu među zaglavljima odgovora.

Postupak kod upita podršci („Iskorištavanje u 20:14 nije uspjelo"):

```bash
# 1. find the request in the Caddy log (time range, path, status)
docker compose --env-file .env.production logs --no-log-prefix --since 2h caddy \
  | jq -c 'select(.request.uri? | test("/redeem")) | {ts, status, uri: .request.uri, rid: .resp_headers["X-Request-Id"]}'

# 2. Laravel entries for this id
docker compose --env-file .env.production logs --since 2h api | grep "<request-id>"
```

```sql
-- 3. audit entries for this id
SELECT created_at, action, user_id, device_id, ip_address FROM audit_logs WHERE request_id = '<request-id>';
```

Integracije (npr. kase) trebaju slati vlastiti `X-Request-Id` i bilježiti ga.

## 8. Pretraga logova

```bash
cd /opt/giftcard-pro
alias dc='docker compose --env-file .env.production'

dc logs -f api queue                          # live
dc logs --since 1h api                        # last hour
dc logs --since 2026-10-14T18:00:00 --until 2026-10-14T19:00:00 api
dc logs --since 24h api | grep -E "ERROR|CRITICAL"
dc logs --since 24h api | grep -E "Suspicious gift card scan|Account locked"
dc logs --since 24h queue | grep FAIL

# Caddy (JSON): all 5xx of the last hour
dc logs --no-log-prefix --since 1h caddy | jq -c 'select(.status? >= 500) | {ts, status, uri: .request.uri, ip: .request.client_ip}'

# Caddy: requests per status
dc logs --no-log-prefix --since 1h caddy | jq -r 'select(.status?) | .status' | sort | uniq -c
```

Instalacija `jq` na serveru: `sudo apt -y install jq`.

### Slanje logova (preporuka)

Za uzbune na osnovu redova loga i čuvanje duže od rotacije šaljite logove kontejnera u centralni sistem, npr. pomoću Vectora ili Promtaila u Loki/Grafana ili u log servis s **lokacijom u EU**. Pri tome važi:

- Sklopite ugovor o obradi podataka po nalogu s pružaocem usluge i uvrstite ga u listu podizvršitelja obrade.
- Čuvanje u ciljnom sistemu konfigurišite prema odjeljku 9.

## 9. Čuvanje i GDPR

| Zapis | Trenutno stanje | Preporuka | Obrazloženje |
|---|---|---|---|
| Logovi kontejnera | rotacija 5 × 20 MB po kontejneru | ostaviti tako | kratkoročno traženje grešaka |
| Centralno prikupljeni logovi (ako su postavljeni) | – | 30 dana, sigurnosni događaji (`warning`) 90 dana | traženje grešaka, dokaz napada |
| Zapisnik aktivnosti | trajno | čuvati trajno; IP adrese nakon [npr. 12 mjeseci] pseudonimizirati (trenutno nema te funkcije – plan za rad sistema) | sljedivost novčano relevantnih radnji, legitimni interes (čl. 6 st. 1 tač. f GDPR) |
| `nfc_scans` | trajno | kao zapisnik aktivnosti | prepoznavanje prevara |
| Ledger | trajno | trajno (najmanje 7 godina, BAO § 132) | zakonska obaveza čuvanja |
| Sigurnosne kopije | 14 dana (vidi [Uputstvo za sigurnosne kopije](backup-guide.md)) | vidi tamo | vraćanje podataka |

Dodatne tačke:

- Rokovi čuvanja pripadaju u evidenciju aktivnosti obrade i u tehničke i organizacione mjere (TOM) uz ugovor o obradi podataka po nalogu s restoranima.
- Zahtjevi za pristup (čl. 15 GDPR) zaposlenih u restoranima odnose se i na IP adrese u zapisniku aktivnosti; restorani su za to voditelji obrade, a GiftCard Pro pomaže kao izvršitelj obrade.
- Nije pravni savjet – provjeriti s advokatom.

---

Verzija 1.0 · Stanje: septembar 2026.
