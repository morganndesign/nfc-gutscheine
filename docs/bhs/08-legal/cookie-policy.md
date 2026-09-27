# Politika kolačića

> **Ovo je prijevod. Pravno mjerodavna je njemačka verzija.**
>
> **Uzorak/predložak — prije upotrebe dati na provjeru advokatu (odvjetniku) ovlaštenom u Austriji.**
> Nije pravni savjet. Mjesta označena s **[Provjeriti: …]** zahtijevaju posebnu provjeru. Tehnički podaci odgovaraju stanju aplikacije u septembru 2026. i treba ih ažurirati pri svakoj izmjeni aplikacije.

*Područje primjene: kolačići i pohrana u pregledniku (localStorage, sessionStorage) na app.giftcardpro.at (aplikacija, uključujući javnu stranicu za provjeru stanja) i giftcardpro.at (web stranica).*

---

## 1. Ukratko

- Aplikacija GiftCard Pro koristi **isključivo tehnički neophodne** kolačiće i pohranu u pregledniku.
- **Nema** kolačića za analizu, statistiku ili reklamu, **nema** kolačića trećih strana, **nema** praćenja, **nema** eksternih fontova ni skripti.
- Zato **pristanak nije potreban** i ne prikazuje se baner za kolačiće (§ 165 st. 3 TKG 2021).
- Web stranica giftcardpro.at standardno takođe ne koristi kolačiće za praćenje.

## 2. Šta su kolačići i pohrana u pregledniku?

**Kolačići** su male tekstualne datoteke koje web stranica ostavlja u pregledniku i ponovo šalje pri svakom sljedećem pristupu. **localStorage** i **sessionStorage** su prostori za pohranu u pregledniku koje čita samo sama web stranica i koji se ne šalju automatski serveru. sessionStorage se briše zatvaranjem kartice preglednika, localStorage ostaje do brisanja.

Pravno se oboje tretira jednako: pohrana i čitanje informacija na Vašem uređaju prema § 165 st. 3 TKG 2021 (austrijski Zakon o telekomunikacijama) dozvoljeni su bez pristanka samo ako su **strogo neophodni** kako bismo pružili uslugu koju ste izričito zatražili.

## 3. Kolačići aplikacije (app.giftcardpro.at)

| Naziv | Svrha | Trajanje | Vrsta | Pružalac |
|---|---|---|---|---|
| `giftcardpro_session` | Prijava: održava Vas prijavljenim nakon logina i vezuje sesiju za Vaš uređaj. Sadržaj šifrovan, nečitljiv za skripte (`HttpOnly`), samo preko HTTPS-a (`Secure`), `SameSite=Lax`. | ističe nakon **8 sati** neaktivnosti | tehnički neophodan | vlastiti (first party) |
| `XSRF-TOKEN` | Zaštita od Cross-Site-Request-Forgery (CSRF): aplikacija šalje vrijednost pri svakoj izmjeni kako strane web stranice ne bi mogle pokrenuti radnje u Vaše ime. | kao sesija (8 sati neaktivnosti) | tehnički neophodan | vlastiti |
| `remember_web_…` | Samo ako pri prijavi odaberete **Keep me signed in on this device**: održava Vas prijavljenim na ovom uređaju. Šifrovan, `HttpOnly`. | do [400 dana] ili do odjave odnosno promjene lozinke [Provjeriti: potvrditi tehnički podešenu vrijednost] | tehnički neophodan (izričito zatražen) | vlastiti |
| `sidebar_state` | Pamti da li ste bočnu traku na kontrolnoj tabli proširili ili skupili. Postavlja se samo ako promijenite bočnu traku. | 7 dana | tehnički neophodan (postavka prikaza) [Provjeriti] | vlastiti |

## 4. Pohrana aplikacije u pregledniku (localStorage / sessionStorage)

| Ključ | Pohrana | Svrha | Trajanje | Vrsta |
|---|---|---|---|---|
| `gcp.device-id` | localStorage | Nasumični ID uređaja (bez podataka o hardveru, bez fingerprintinga). Služi sigurnosti: uređaji se registruju u računu restorana, mogu se imenovati i u slučaju gubitka blokirati; kopirana sesija ne radi na drugom uređaju. | dok ne izbrišete podatke web stranice | tehnički neophodan |
| `theme` | localStorage | Vaš izbor između svijetlog, tamnog ili sistemskog dizajna. | dok ne izbrišete podatke web stranice | tehnički neophodan (postavka prikaza) |
| `gcp.acting-restaurant` | sessionStorage | Samo za platformske administratore pružaoca usluge: pamti u kojem restoranu se trenutno radi („Open restaurant"). | do zatvaranja kartice preglednika | tehnički neophodan |

**Javna stranica za provjeru stanja:** kada gosti skeniraju svoju karticu vlastitim pametnim telefonom, mogu nastati isti tehnički neophodni unosi (kolačić sesije i CSRF kolačić, ID uređaja). Ne postavljaju se unosi za praćenje ni reklamni unosi. [Provjeriti: tehnički potvrditi koji unosi stvarno nastaju na stranici za provjeru stanja]

**Pravni osnov** za sve unose: § 165 st. 3 TKG 2021 (strogo neophodno, pristanak nije potreban); za povezanu obradu ličnih podataka čl. 6 st. 1 lit. b GDPR (pružanje usluge) i lit. f GDPR (sigurnost).

## 5. Web stranica (giftcardpro.at)

- Web stranica standardno **ne** postavlja kolačiće u svrhu analize, marketinga ili reklame i ne ugrađuje sadržaje trećih strana koji postavljaju kolačiće.
- Ako se koristi mjerenje posjećenosti, onda samo **bez kolačića** i bez pohrane na Vašem uređaju: [naziv alata, pružalac, lokacija servera u EU] ili „nema". [Provjeriti: i mjerenje bez kolačića ocijeniti sa stanovišta zaštite podataka]
- Ugrađene usluge za zakazivanje termina, mape ili video, ako se koriste, učitavaju se tek nakon Vašeg klika („rješenje s dva klika"). [Provjeriti]

## 6. Ako kasnije bude dodan alat za koji je potreban pristanak

Ako ubuduće budemo koristili alat koji nije strogo neophodan (npr. analiza s kolačićima, reklamni pikseli, ugrađeni video zapisi, chat widget treće strane), važi sljedeće:

1. **Prethodno** tražimo Vaš pristanak putem banera za pristanak (čl. 6 st. 1 lit. a GDPR, § 165 st. 3 TKG 2021).
2. Baner na prvom nivou nudi „Prihvati" i „Odbij" kao ravnopravne opcije; ništa nije unaprijed odabrano.
3. Prije pristanka ne postavljaju se odgovarajući kolačići i ne učitavaju se skripte.
4. Pristanak možete u svakom trenutku povući putem stalno dostupnog linka („Postavke kolačića").
5. Ova politika i [Izjava o zaštiti podataka](privacy-policy.md) prethodno se ažuriraju (naziv, svrha, pružalac, trajanje, eventualni prijenos u treće zemlje).

U samoj aplikaciji nisu predviđeni alati za koje je potreban pristanak.

## 7. Upravljanje kolačićima i njihovo brisanje u pregledniku

Kolačiće i podatke web stranica možete u svakom trenutku pregledati i izbrisati u svom pregledniku. Ako izbrišete ili blokirate neophodne unose aplikacije, bit ćete odjavljeni odnosno nećete se moći prijaviti; nakon brisanja ID-a uređaja Vaš uređaj će pri sljedećoj prijavi biti registrovan kao novi uređaj.

- **Google Chrome:** Postavke → Privatnost i sigurnost → kolačići trećih strana odnosno podaci web stranica; ili ikona lokota u adresnoj traci → kolačići i podaci web stranice.
- **Mozilla Firefox:** Postavke → Privatnost i sigurnost → Kolačići i podaci stranica → Upravljaj podacima.
- **Apple Safari (Mac):** Postavke → Privatnost → Upravljaj podacima web stranica.
- **Safari na iPhoneu/iPadu:** Postavke → Aplikacije → Safari → Napredno → Podaci web stranica. [Provjeriti: putanja u meniju zavisno od verzije iOS-a]
- **Microsoft Edge:** Postavke → Kolačići i dozvole web stranica → Upravljanje kolačićima i podacima web stranica.

Nazivi se mogu razlikovati zavisno od verzije i jezika preglednika. Pomoć ćete naći u dokumentaciji svog preglednika.

## 8. Kontakt i izmjene

Pitanja o ovoj politici: **datenschutz@giftcardpro.at**. Ovu politiku ažuriramo čim se promijene korišteni kolačići ili unosi u pohrani. Dodatne informacije o obradi ličnih podataka možete pronaći u našoj [Izjavi o zaštiti podataka](privacy-policy.md).

---

Verzija 1.0 · Stanje: septembar 2026.
