# Priručnik za vlasnike

*Sve čime kao vlasnik / vlasnica upravljate u GiftCard Pro: pokazatelji, izvještaji za poreznog savjetnika, pravila, tim, sigurnost, zaštita podataka te mjesečni i godišnji zaključak.*

Korisnički interfejs trenutno je na engleskom. Dugmad i stavke menija napisani su ovdje tačno onako kako ih vidite, a kod prvog pojavljivanja s prijevodom, npr. **„Export CSV“** (izvezi kao CSV). Interfejs na njemačkom planiran je za Q4 2026.

---

## 1. Vaša uloga

Kao **Restaurant Owner** (vlasnik / vlasnica) smijete sve što se tiče Vašeg restorana. Samo Vi upravljate sljedećim:

- **„Settings“** (postavke): pravila za kartice, profil restorana, e-mailovi, API
- **„Team“** (tim): pozivanje osoba, uloge, deaktivacija
- **„Devices“** (uređaji): blokiranje i ponovno odobravanje telefona
- **„Customers“** (kupci): anonimizacija prema GDPR-u

Sve ostalo – prodaju kartica, iskorištavanje, zamjenu, blokiranje, storniranje knjiženja – može obavljati i Vaš menadžer. Koraci za to nalaze se u Priručniku za menadžere.

---

## 2. Dashboard (pregled)

![Dashboard](../../screenshots/owner-dashboard.png)

### Četiri pokazatelja

| Pokazatelj | Značenje | Zašto Vam treba |
|---|---|---|
| **„Outstanding balance“** (otvoreni iznos) | Zbir svih stanja koja gosti još mogu iskoristiti kod Vas. Ispod: **„Open liability on N cards“** (otvorena obaveza na N kartica). | **Vaš najvažniji broj.** To je novac koji ste već naplatili, ali ga još dugujete u obliku hrane i pića. |
| **„Revenue this month“** (promet ovog mjeseca) | prodane kartice plus dopune u tekućem mjesecu, u poređenju s prethodnim mjesecom | Kako se prodaju poklon bonovi? Sezonsko poređenje (advent, Valentinovo, Majčin dan). |
| **„Redeemed this month“** (iskorišteno ovog mjeseca) | iznos koji su gosti ovog mjeseca platili poklon karticama, uključujući današnji iznos | usklađivanje s fiskalnom kasom (način plaćanja „poklon bon“) |
| **„Cards sold“** (prodane kartice) | sve ikad prodane kartice, od toga ovog mjeseca i trenutno u upotrebi | Doseg: koliko je poklon bonova u opticaju? |

#### Zašto je otvoreni iznos tako važan

Svaki prodani poklon bon je obećanje. Dok nije iskorišten, novac imate, ali uslugu još niste pružili. Ko vodi bilans, ovaj iznos u pravilu iskazuje kao **obavezu**; ko vodi evidenciju prihoda i rashoda, trebao bi ga ipak poznavati – npr. kod prodaje ili predaje restorana. Visok otvoreni iznos nakon božićne sezone je normalan: ti gosti dolaze na proljeće.

*Ovo nije porezni savjet – bilansni tretman razjasnite s Vašim poreznim savjetnikom.*

### Grafikoni

- **„Sales & redemptions“** (prodaja i iskorištavanje): dan po dan prodano naspram iskorištenog, 7, 30 ili 90 dana.
- **„Monthly revenue“** (mjesečni promet): prodaja kartica i dopune u posljednjih 12 mjeseci.
- **„Card status“** (status kartica): kartice po statusu – Active (aktivna), Inactive (još nije aktivirana), Redeemed (potpuno iskorištena), Blocked (blokirana), Expired (istekla), Replaced (zamijenjena).
- **„Recent activity“** (posljednja knjiženja): najnovija knjiženja; **„View all“** (prikaži sve) otvara dnevnik knjiženja.

Dashboard radi na računaru, tabletu i telefonu, u svijetlom ili tamnom načinu.

---

## 3. Izvještaji i izvozi za poreznog savjetnika

![Transakcije](../../screenshots/transactions.png)

| Izvoz | Gdje | Sadržaj |
|---|---|---|
| **Dnevnik knjiženja** | **„Transactions“** (transakcije) → filter po datumu → **„Export CSV“** | svako knjiženje: prodaja (Sale), iskorištavanje (Redemption), dopuna (Reload), prijenos (Transfer in/out), storno, istek (Expiration) – s datumom, vremenom, karticom, iznosom, osobom |
| **Lista kartica** | **„Gift cards“** (poklon kartice) → filter → **„Export CSV“** | svaka kartica sa statusom, početnom vrijednošću, trenutnim stanjem, rokom važenja |

Datoteke koriste tačku-zarez kao razdjelnik i austrijski decimalni zarez. Otvaraju se dvoklikom direktno u Excelu.

**Dnevnik knjiženja je nepromjenjiv.** Ništa se ne briše. Greške se ispravljaju protuknjiženjem, a prvobitno knjiženje ostaje vidljivo. Zbir svih knjiženja jedne kartice uvijek daje njeno stanje. Time GiftCard Pro podržava Vašu obavezu čuvanja od sedam godina (§ 132 BAO) – za čuvanje Vaših knjiga odgovorni ste Vi sami; zato redovno izvozite dnevnik.

**GiftCard Pro ne zamjenjuje fiskalnu kasu.** Prodaja i iskorištavanje moraju se dodatno knjižiti u fiskalnoj kasi. Izvozi služe za usklađivanje.

---

## 4. Pravila za kartice

**„Settings“** → **„Gift cards“**. Pravila važe za svako knjiženje, i preko API-ja.

| Postavka | Fabrička postavka | Napomena |
|---|---|---|
| **„Minimum card value“** / **„Maximum card value“** | 5 € / 1.000 € | |
| **„Maximum card balance“** | 2.000 € | ograničava i dopune |
| **„Maximum single redemption“** | bez ograničenja | korisno ako su visoki pojedinačni iznosi neuobičajeni |
| **„Default validity (months)“** | 36 | **preporuka: 0 (bez roka)** – vidi dolje |
| **„Max. redemptions per card per hour“** | 10 | zaštita od prevara; 0 je isključuje (ne preporučuje se) |
| **„Allow reloading“** | uključeno | |
| **„Partial redemption“** | uključeno | isključeno = može se iskoristiti samo cijelo stanje |
| **„Public balance check“** | uključeno | stranica sa stanjem za goste |
| **„Clone protection“** | uključeno | kartica radi samo s čipom na koji je upisana |
| **„Lock tags after writing“** | – | preporučeno: uključeno |
| **„Customer e-mails“** | uključeno | |
| **„Card number prefix“**, **„Brand color“**, **„E-mail footer“** | – | |

### Rok važenja poklon bonova

**Postavite „Default validity (months)“ na 0 (bez roka), osim ako Vaš advokat ne odobri drugi model.** Fabrička postavka od 36 mjeseci na platformi će se ubuduće promijeniti; do tada je morate sami prilagoditi.

> Plaćeni poklon bonovi bez ograničenja zastarijevaju nakon 30 godina (§ 1478 ABGB). Ograničenje na tri godine ili manje u općim uslovima poslovanja prema sudskoj praksi OGH u pravilu je grubo nepovoljno (§ 879 st. 3 ABGB) i ništavo. Dozvoljen je bio npr. rok važenja od jedne godine s naknadnim trogodišnjim periodom za zamjenu ili povrat novca. Besplatni i promotivni bonovi smiju biti vremenski ograničeni. Izvori: WKO „Gutscheine – Befristung“, konsument.at, AK.
>
> Kartice s rokom nakon isteka u 00:15 automatski dobijaju status „Expired“, a preostali iznos se isknjižava. Gost ipak može imati zahtjev.
>
> *Ovo nije pravni savjet – provjerite s Vašim advokatom.*

Promjena važi samo za **nove** kartice. Postojećim karticama s rokom možete pojedinačno produžiti važenje ili ga ukloniti preko **⋯ → „Edit details“** (uredi detalje) → **„Valid until“** (važi do) – dok još nisu istekle. Savjet: redovno sortirajte listu kartica pomoću **„Expiring soonest“** (prve ističu).

---

## 5. Tim i uloge

**„Team“** → **„Invite“** (pozovi) → **„Name“**, **„E-mail“**, **„Role“** → **„Send invitation“**.

| Uloga | Prava |
|---|---|
| **Restaurant Owner** | sve u vlastitom restoranu |
| **Manager** | prodaja, iskorištavanje, dopuna, prijenos, zamjena, blokiranje/deblokiranje kartica, istek, upisivanje NFC-a; pregled, storniranje i izvoz knjiženja; upravljanje kupcima; pregled zapisnika aktivnosti i uređaja |
| **Waiter** | skeniranje i iskorištavanje kartica |

- Link pozivnice važi **72 sata**. Istekao? **⋯ → „Resend invitation“** (ponovo pošalji pozivnicu).
- Zaboravljena lozinka? **⋯ → „Send password reset“** (link za promjenu, važi 60 minuta). Lozinke se nikad ne šalju e-mailom.
- Neko napušta restoran? **⋯ → „Deactivate“** (deaktiviraj) – odmah, bez izuzetka. Ranija knjiženja te osobe ostaju sačuvana s njenim imenom. **„Reactivate“** je vraća.
- Promjena uloge: **⋯ → „Edit“** (uredi).
- Još jednu osobu s pravima vlasnika postavlja podrška za Vas (support@giftcardpro.at).

**Pristupni podaci se nikad ne dijele.** Svako knjiženje nosi ime osobe koja ga je napravila. Dijeljeni pristup tu sljedivost čini bezvrijednom.

---

## 6. Uređaji

**„Devices“** prikazuje svaki telefon, tablet i računar s kojim se neko iz Vašeg tima prijavio ili skenirao kartice.

- **Preimenovanje** (ikona olovke): npr. „Bar iPhone“, „Terasa Android“.
- **„Revoke“** (blokiraj): telefon izgubljen ili ukraden? Uređaj od tog trenutka ne može skenirati ni iskorištavati kartice, postojeće prijave postaju nevažeće.
- **„Restore“** (vrati): ponovo odobrite uređaj kada se pronađe.

Provjerite listu jednom mjesečno. Nepoznat uređaj je razlog da pritisnete **„Revoke“** i promijenite lozinke osobe o kojoj je riječ.

---

## 7. Zapisnik aktivnosti i sigurnosna upozorenja

**„Audit log“** (zapisnik aktivnosti) prikazuje svaku sigurnosno i novčano relevantnu radnju: ko, kada, s kojeg uređaja odnosno IP adrese, prije i poslije. Zapisi se nikad ne mogu promijeniti niti obrisati. Filtrirajte po oblasti: **„Sign-ins“** (prijave), **„Gift cards“**, **„Transactions“**, **„Team“**, **„Devices“**, **„Customers“**, **„Settings“**, **„API tokens“**.

Crveno označeni zapisi su **„Security alert“** (sigurnosna upozorenja):

| Upozorenje | Šta se desilo | Šta radite |
|---|---|---|
| **„Cloned card rejected“** (kopirana kartica odbijena) | Kartica je skenirana s drugim čipom od onog na koji je upisana. | Blokirajte karticu, razgovarajte s gostom i konobarom, po potrebi zamijenite karticu. |
| **„Copied NFC tap rejected“** / **„Invalid NFC signature rejected“** (samo NTAG 424 DNA) | Predočen je već korišten ili krivotvoren kod čipa. | kao gore |
| **„Card of another restaurant scanned“** (kartica drugog restorana) | Skenirana je strana kartica. | Uglavnom bezopasno (gost je zamijenio kartice). Ako se ponavlja: obavijestite podršku. |
| **„Account locked after failed sign-ins“** (račun zaključan) | Nakon 10 pogrešnih pokušaja prijave račun je zaključan 15 minuta. | Pitajte osobu. Ako to nije bila ona: promijenite lozinku, provjerite uređaje. |

Sa **„Show details“** (prikaži detalje) vidite stanje prije i poslije svake promjene.

---

## 8. Podaci o kupcima i GDPR

**„Customers“** prikazuje sve goste koje ste evidentirali pri prodaji kartice – dobrovoljno, s imenom, e-mailom ili brojem telefona. Prodaja kartica bez podataka o kupcu (**„Anonymous“**) moguća je u svakom trenutku.

- Za te podatke **Vi ste voditelj obrade** u smislu GDPR-a (DSGVO); GiftCard Pro ih obrađuje kao izvršitelj obrade (čl. 28 GDPR) prema Vašem nalogu.
- Evidentirajte samo ono što Vam treba: e-mail za potvrde, ime za pronalaženje kod gubitka.
- **Zahtjev gosta za brisanje:** otvorite kupca → **„Anonymize customer“** (anonimiziraj kupca) → potvrdite. Ime, e-mail, broj telefona i bilješke **nepovratno** se uklanjaju. Kartice i stanja ostaju važeći, knjiženja ostaju sačuvana zbog obaveze čuvanja.
- **Zahtjev za pristup podacima:** otvorite kupca – tu vidite sve sačuvane podatke i kartice tog gosta.
- Nadzorni organ u Austriji: Österreichische Datenschutzbehörde (dsb.gv.at).

*Ovo nije pravni savjet – informaciju o zaštiti podataka za goste provjerite s Vašim pravnim savjetnikom.*

---

## 9. E-mailovi gostima

**„Settings“** → **„E-mails“**: četiri predloška na njemačkom i engleskom – **„Card purchased“** (kartica kupljena), **„Card reloaded“** (kartica dopunjena), **„Card expires soon“** (kartica uskoro ističe, 30 dana prije, u 10:00), **„Low balance“** (nisko stanje, ispod 5 €).

E-mailovi idu samo gostima s e-mail adresom i samo ako je **„Customer e-mails“** uključeno. Podnožje (**„E-mail footer“**) treba sadržavati puni naziv firme, adresu, broj u sudskom registru i UID.

---

## 10. Stranica sa stanjem za goste

![Stranica sa stanjem](../../screenshots/public-balance.png)

Gosti prislone karticu na svoj telefon ili skeniraju QR kod i vide: stanje, status, rok važenja i maskirani broj kartice – na jeziku Vašeg restorana (njemački ili engleski). Na samoj kartici nije sačuvan novac, samo nasumičan link.

Isključivanje: **„Settings“** → **„Gift cards“** → **„Public balance check“**. Preporučujemo da ostane uključena – štedi Vašem timu pitanja.

---

## 11. API tokeni (paket Pro)

**„Settings“** → **„API“** → **„New API token“** (novi API token). Njime povezujete npr. fiskalnu kasu ili knjigovodstveni program.

- **„Name“:** za šta je token (npr. „Kasa bar“).
- **„Abilities“** (ovlaštenja): izaberite samo neophodno, npr. skeniranje i iskorištavanje.
- **„Expires“** (ističe): najviše 365 dana.
- Token se prikazuje **samo jednom** (**„Copy your token now“**). Čuvajte ga kao lozinku i dajte ga samo dobavljaču kase odnosno tehničaru.
- Više nije potreban ili je možda postao poznat? Odmah ga opozovite.

Tehnički detalji: API dokumentacija (na upit kod podrške).

---

## 12. Mjesečna rutina (15 minuta, prva sedmica u mjesecu)

1. **Dashboard:** zabilježite otvoreni iznos, promet i iskorištavanja prethodnog mjeseca.
2. **Usklađivanje s fiskalnom kasom:** prodani poklon bonovi i plaćanja poklon bonom u prethodnom mjesecu – slažu li se zbirovi?
3. **„Transactions“** → datum = prethodni mjesec → **„Export CSV“** → poreznom savjetniku.
4. **„Audit log“:** pregledajte crveno označene zapise.
5. **„Devices“:** blokirajte nepoznate ili nekorištene uređaje.
6. **„Team“:** jesu li osobe koje su otišle deaktivirane?
7. **„Gift cards“:** kartice sa statusom **Blocked** – ima li još otvorenih slučajeva? Sortirano sa **„Expiring soonest“**: kartice s rokom koje uskoro ističu?

---

## 13. Godišnja rutina (presječni dan 31. 12. odnosno kraj poslovne godine)

1. Na presječni dan nakon zatvaranja otvorite **„Dashboard“** i zabilježite **„Outstanding balance“** s datumom i vremenom (snimak ekrana).
2. **„Gift cards“** → **„Export CSV“** (sve kartice s trenutnim stanjem) – to je pojedinačni pregled otvorenog iznosa.
3. **„Transactions“** → cijela godina → **„Export CSV“** – kompletan dnevnik knjiženja.
4. Obje datoteke i snimak ekrana pošaljite poreznom savjetniku, zajedno s godišnjim podacima fiskalne kase.
5. Datoteke čuvajte sedam godina (§ 132 BAO).
6. Provjerite pravila za kartice: vrijednosti, rok važenja, ograničenja.
7. Pročistite tim i uređaje.

> **Napomena:** Vrijednost „Outstanding balance“ je trenutno stanje u momentu prikaza. Za bilans Vaš porezni savjetnik odlučuje kako se iskazuju otvoreni poklon bonovi (npr. kao obaveza, po potrebi uz uzimanje u obzir očekivanog neiskorištavanja). GiftCard Pro daje brojeve, ne poreznu ocjenu.
>
> *Ovo nije porezni savjet – uskladite s Vašim poreznim savjetnikom.*

---

## 14. Pomoć

support@giftcardpro.at · paket Start: odgovor u roku od jednog radnog dana · paket Pro: odgovor u roku od 4 radna sata, dodatno telefonom na [Telefon].

Sigurnosni incidenti (npr. sumnja na neovlašten pristup): security@giftcardpro.at

---

Verzija 1.0 · Stanje: septembar 2026.
