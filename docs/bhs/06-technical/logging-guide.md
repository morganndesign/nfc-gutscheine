# Vodič za logovanje

*Izvori logova u GiftCard Pro, nivoi logovanja, razgraničenje od zapisnika aktivnosti i ledgera, lični podaci, korelacija preko X-Request-Id, pretraga, čuvanje i GDPR.*

---

## 1. Pregled

GiftCard Pro poznaje tri vrste zapisa s različitom svrhom:

| Vrsta | Mjesto pohrane | Svrha | Čuvanje |
|---|---|---|---|
| **Operativni logovi** | Docker logovi kontejnera (stdout/stderr), u Coolifyju pod resurs → *Logs* | traženje grešaka, nadzor, sigurnosne uzbune | kratko (rotacija, vidi odjeljak 3) |
| **Zapisnik aktivnosti (audit log)** | tabela `audit_logs` (samo dodavanje, hash lanac po restoranu) | sljedivost sigurnosno i novčano relevantnih radnji za restorane i platformu, uključujući svako neuspjelo predočenje | trajno (ništa se ne mijenja niti briše) |
| **Ledger i plaćanja** | tabele `voucher_transactions`, `payments` (samo dodavanje, hash lanac po restoranu) | knjigovodstvena istina: svaka promjena stanja s osobom, uređajem, IP adresom i vremenskom oznakom; svako plaćanje prodaje ili dopune | trajno |

Okidači u bazi odbijaju `UPDATE` i `DELETE` nad ledgerom, plaćanjima i zapisnikom aktivnosti; `php artisan giftcard:verify-chains` svake noći provjerava da nijedan red nije izmijenjen, obrisan, umetnut ili premješten.

## 2. Izvori logova

| Izvor | Kontejner | Format | Sadržaj |
|---|---|---|---|
| Laravel (API) | `api` | Tekst, jedan red po zapisu, kontekst kao JSON (standardni Monolog format) | Greške i izuzeci, sigurnosna upozorenja, napomene |
| PHP-FPM | `api` | Tekst | Izlaz workera, PHP greške; zahtjevi se prekidaju nakon 30 s (`request_terminate_timeout`) |
| Queue worker | `worker` | Tekst | Obrađeni poslovi (`RUNNING`/`DONE`/`FAIL`), greške pri slanju e-maila |
| Scheduler | `scheduler` | Tekst | Izvršene naredbe noćnih poslova, rezultat provjere integriteta |
| Gateway (Caddy) | `gateway` | **JSON** | Access log (svaki zahtjev: metoda, URI bez osjetljivih parametara upita, status, trajanje, IP klijenta, User-Agent, zaglavlja bez tajni) i vlastite poruke Caddyja |
| Next.js | `web` | Tekst | Pokretanje, greške na serveru |
| MySQL | `mysql` | Tekst | Pokretanje, greške, upozorenja |
| Redis | `redis` | Tekst | Pokretanje, AOF poruke, greške |
| Backup | `backup` | Tekst | „Backup written: …“ odnosno „Backup FAILED“ |

Izlaz Laravela u Coolify stacku fiksno je postavljen na `LOG_CHANNEL=stderr`; `LOG_LEVEL` je `info` (promjenjivo u Coolifyju). Za JSON izlaz može se postaviti standardna Laravel varijabla `LOG_STDERR_FORMATTER=Monolog\Formatter\JsonFormatter` (olakšava mašinsku obradu pri slanju logova).

Lokalno (`backend/.env.example`): `LOG_CHANNEL=stack`, `LOG_STACK=daily`, `LOG_LEVEL=debug` → datoteke `backend/storage/logs/laravel-YYYY-MM-DD.log`, 14 dana (`LOG_DAILY_DAYS`).

## 3. Rotacija logova kontejnera

Svi servisi u `docker-compose.coolify.yml` koriste:

```yaml
logging:
  driver: json-file
  options: { max-size: "10m", max-file: "5" }
```

Po kontejneru se čuva najviše 5 datoteka po 10 MB (= 50 MB); stariji zapisi se prepisuju. Koliko dana to pokriva zavisi od saobraćaja – kod `gatewaya` (jedan zapis po zahtjevu) najmanje. Kada se kontejner ponovo kreira (npr. pri svakom deploymentu), njegovi logovi počinju ispočetka.

**Posljedica:** logovi kontejnera nisu arhiva. Ono što je potrebno duže nalazi se u zapisniku aktivnosti ili se mora sačuvati slanjem logova (odjeljak 8).

## 4. Nivoi logovanja

| Nivo | Upotreba u GiftCard Pro |
|---|---|
| `debug` | Samo lokalno. `log` mailer na ovom nivou piše e-mailove – **u produkciji nikada ne aktivirati**. |
| `info` | Standard za produkciju (`LOG_LEVEL=info`), npr. „Platform test e-mail requested“ |
| `warning` | **Sigurnosni događaj**: `Account locked after repeated failed logins` (s `user_id`, `ip`, `attempts`) |
| `error` | Izuzeci, neuspjeli poslovi, operativna upozorenja koja se nisu mogla poslati |
| `critical` | `Integrity check failed: financial history or audit log does not verify`, `Queue backlog above threshold` |
| `alert`, `emergency` | Teške greške |

Preporuke:

- Produkcija: `info`.
- Traženje grešaka u produkciji: `LOG_LEVEL` ne postavljati na `debug`. Umjesto toga ciljano tražiti po `X-Request-Id`.
- Promjena `LOG_LEVEL` djeluje tek nakon *Redeploy* (konfiguracija se kešira pri pokretanju kontejnera).

## 5. Šta se gdje bilježi

| Događaj | Operativni log | Zapisnik aktivnosti | Ledger / plaćanja |
|---|---|---|---|
| Uspješno predočenje (`POST /presentments`) | – | – (red u `presentments`) | – |
| Neuspjelo predočenje (QR nepoznat, opozvan, strani) | – | ✓ `presentment.failed` | – |
| Odbijeno predočenje (pogrešna metoda, ograničeno) | – | ✓ `presentment.rejected` | – |
| Prodaja, iskorištavanje, dopuna, storno | – | ✓ `voucher.sold`, `voucher.redeemed`, `voucher.reloaded`, `transaction.reversed` | ✓ (prodaja i dopuna s plaćanjem) |
| Blokiranje, deblokiranje, istek, ponovna aktivacija, uređivanje vaučera | – | ✓ `voucher.blocked`, `voucher.unblocked`, `voucher.expired`, `voucher.reinstated`, `voucher.updated` | – (stanje ostaje) |
| Prijava, odjava | – | ✓ `auth.login`, `auth.logout` | – |
| Neuspjela prijava na poznat nalog | – | ✓ `auth.failed`, kod zaključanog naloga `auth.locked_attempt` | – |
| Zaključavanje naloga | ✓ `warning` | ✓ `auth.locked` | – |
| Promjena ili resetovanje lozinke (opoziva pristupe) | – | ✓ `user.password_changed`, `auth.access_revoked` | – |
| Izmjene tima, uređaja, tokena, postavki | – | ✓ | – |
| Administracija platforme (kreiranje, suspendovanje, arhiviranje, brisanje restorana) | – | ✓ `restaurant.*` | – |
| Provjera integriteta ne uspije | ✓ `critical` + e-mail na `OPS_ALERT_EMAIL` | – | – |
| Izuzetak / greška servera | ✓ `error` | – | – |
| Slanje e-maila | log servisa `worker` | – | – (tabela `notification_logs`) |
| HTTP zahtjev | gateway ✓ | – | – |

### Sadržaj zapisnika aktivnosti

`audit_logs` sadrži: `restaurant_id`, `user_id`, `device_id`, `action` (npr. `voucher.blocked`, `presentment.failed`), pogođeni objekat, `old_values`, `new_values`, `metadata`, `ip_address`, `user_agent`, `request_id`, `created_at` (mikrosekunde) te hash lanac (`chain_scope`, `chain_seq`, `prev_hash`, `entry_hash`). Restorani ga vide pod **Audit log** (`audit.view`), platforma u administraciji platforme.

## 6. Lični podaci u logovima

| Zapis | Lični podaci | Zaštitna mjera |
|---|---|---|
| Zapisnik aktivnosti `old_values`/`new_values`/`metadata` | **nema** imena kupaca, e-mail adresa, brojeva telefona, napomena ni imena primalaca – samo činjenica da su izmijenjeni | `AuditLogger` uklanja lozinke, tokene i hashove tajni; lična polja se ne kopiraju |
| Zapisnik aktivnosti `ip_address`, `user_agent`, `user_id` | IP adrese i identifikacija pretraživača zaposlenih | Svrha: sigurnost i sljedivost; pristup samo s `audit.view` |
| Ledger, plaćanja | osoba, uređaj, IP; referenca potvrde | obaveza čuvanja (BAO § 132) |
| Laravel log (`warning`) | `user_id`, `ip` | kratko čuvanje zbog rotacije |
| Access log gatewaya | IP klijenta, User-Agent, URI | Parametri upita `token`, `email`, `e`, `m` i zaglavlja `Cookie`, `Authorization`, `X-Device-Id`, `Idempotency-Key` i `Set-Cookie` se ne bilježe; kratko čuvanje zbog rotacije |
| `notification_logs` | e-mail adresa primalaca | uklanja se pri anonimizaciji prema GDPR-u |

Napomene:

- **Nema tajni u logovima:** tokeni za resetovanje lozinke i pozivnice nalaze se u fragmentu URL-a i nikada ne stižu do servera. Sadržaj QR koda vaučera nije URL i šalje se u tijelu zahtjeva; ne pojavljuje se ni u access logu ni u zapisniku aktivnosti.
- **Nema podataka gostiju u operativnim logovima:** imena, e-mail adrese i brojevi telefona gostiju ne pojavljuju se u Laravel logovima. U vlastitim proširenjima nikada ne logirajte tijela zahtjeva ili modele s podacima kupaca.
- **Nema lozinki:** nigdje se ne bilježe.

## 7. Korelacija preko `X-Request-Id`

Svaki API zahtjev dobija ID za korelaciju:

1. Klijent šalje `X-Request-Id` (8–64 znaka) – inače ga server generiše.
2. ID se nalazi u kontekstu Laravel log redova tog zahtjeva.
3. Pohranjuje se u zapisnik aktivnosti (`audit_logs.request_id`).
4. Vraća se u odgovoru kao zaglavlje `X-Request-Id` – i tako se pojavljuje i u access logu gatewaya među zaglavljima odgovora.

Postupak kod upita podrške („iskorištavanje u 20:14 nije uspjelo“): Coolify → *Logs* → pretražite servis **gateway** odnosno **api** u tom periodu, ili na serveru (kao root; nazive kontejnera saznajte s `docker ps`):

```bash
# 1. find the request in the gateway log (time range, path, status)
docker logs --since 2h <gateway-container> 2>&1 \
  | jq -c 'select(.request.uri? | test("/redemptions")) | {ts, status, uri: .request.uri, rid: .resp_headers["X-Request-Id"]}'

# 2. Laravel entries for this id
docker logs --since 2h <api-container> 2>&1 | grep "<request-id>"
```

```sql
-- 3. audit entries for this id
SELECT created_at, action, user_id, device_id, ip_address FROM audit_logs WHERE request_id = '<request-id>';
```

Da li je iskorištavanje knjiženo uprkos izgubljenom odgovoru odgovara `GET /vouchers/{id}/redemptions/{idempotencyKey}` – aplikacija za konobare i web kasa to same provjeravaju. Integracije (npr. kase) trebaju slati vlastiti `X-Request-Id` i bilježiti ga.

## 8. Pretraga logova

U Coolifyju: resurs → *Logs* → izaberite servis (prikaz uživo i pretraga). Na serveru (kao root):

```bash
docker ps --format '{{.Names}}' | grep -E 'api|worker|gateway'   # container names
docker logs -f <api-container>                                    # live
docker logs --since 1h <api-container>                            # last hour
docker logs --since 24h <api-container> 2>&1 | grep -E "ERROR|CRITICAL"
docker logs --since 24h <api-container> 2>&1 | grep -E "Account locked|Integrity check failed"
docker logs --since 24h <worker-container> 2>&1 | grep FAIL

# gateway (JSON): all 5xx of the last hour
docker logs --since 1h <gateway-container> 2>&1 | jq -c 'select(.status? >= 500) | {ts, status, uri: .request.uri, ip: .request.client_ip}'

# gateway: requests per status
docker logs --since 1h <gateway-container> 2>&1 | jq -r 'select(.status?) | .status' | sort | uniq -c
```

Instalacija `jq` na serveru: `apt -y install jq`. Neuspjela predočenja nisu u operativnom logu, nego u zapisniku aktivnosti (**Audit log**, filter `presentment.`).

### Slanje logova (preporuka)

Za uzbune na osnovu redova loga i čuvanje duže od rotacije, logove kontejnera šaljite u centralni sistem, npr. pomoću Vector ili Promtail u Loki/Grafana ili servisu za logove sa **sjedištem u EU**. Pri tome važi:

- Zaključite ugovor o obradi podataka s pružaocem usluge i uvrstite ga u listu podizvršitelja obrade.
- Čuvanje u ciljnom sistemu konfigurišite prema odjeljku 9.

## 9. Čuvanje i GDPR

| Zapis | Trenutno stanje | Preporuka | Obrazloženje |
|---|---|---|---|
| Logovi kontejnera | rotacija 5 × 10 MB po kontejneru | ostaviti tako | kratkoročno traženje grešaka |
| Centralno prikupljeni logovi (ako su postavljeni) | – | 30 dana, sigurnosni događaji (`warning` i više) 90 dana | traženje grešaka, dokaz napada |
| Zapisnik aktivnosti | trajno, nepromjenjiv | čuvati trajno | sljedivost novčano relevantnih radnji, legitimni interes (čl. 6 st. 1 tač. f GDPR) |
| Ledger i plaćanja | trajno, nepromjenjivi | trajno (najmanje 7 godina, BAO § 132) | zakonska obaveza čuvanja |
| Sigurnosne kopije | `BACKUP_KEEP_DAYS` (vidi [Uputstvo za sigurnosne kopije](backup-guide.md)) | vidi tamo | vraćanje podataka |

Ostale tačke:

- Rokovi čuvanja spadaju u evidenciju aktivnosti obrade i u tehničke i organizacione mjere (TOM) uz ugovor o obradi podataka s restoranima.
- Zahtjevi za pristup (čl. 15 GDPR) zaposlenih u restoranima odnose se i na IP adrese u zapisniku aktivnosti; restorani su za to voditelji obrade, a GiftCard Pro kao izvršitelj obrade pomaže.
- Nije pravni savjet – provjeriti s advokatom.

---

Verzija 2.0 · Stanje: septembar 2026.
