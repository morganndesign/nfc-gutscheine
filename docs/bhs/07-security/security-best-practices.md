# Najbolje sigurnosne prakse za restorane

*Konkretne mjere kojima štitite svoje vaučere, račun svog tima i podatke svojih gostiju – za vlasnike i vlasnice te menadžere.*

GiftCard Pro donosi mnogo zaštitnih mehanizama. Neke od njih podešavate sami, a druge djeluju samo ako ih Vaš tim primjenjuje u svakodnevnom radu. Ova kontrolna lista je razvrstana po temama; svaka tačka se može provesti za nekoliko minuta.

---

## Na prvi pogled

| Br. | Mjera | Kada |
|---|---|---|
| 1 | Vlastiti račun za svaku osobu | pri postavljanju, pri svakom novom zaposlenju |
| 2 | Jake lozinke, menadžer lozinki | odmah |
| 3 | Zaključavanje ekrana i ažuriranja na svim telefonima | odmah |
| 4 | Izgubljene uređaje odmah blokirati | po potrebi |
| 5 | Uloge po principu najmanjih prava | pri svakom novom zaposlenju, provjeravati tromjesečno |
| 6 | Iskorištavati samo skeniranjem | stalno |
| 7 | Svaku prodaju evidentirati s pravim plaćanjem | pri svakoj prodaji i dopuni |
| 8 | Listove za štampu čuvati kao gotovinu | stalno |
| 9 | Postaviti ograničenja protiv zloupotrebe | pri postavljanju |
| 10 | Provjeravati zapisnik aktivnosti | sedmično |
| 11 | Blokirati sumnjive vaučere | po potrebi |
| 12 | Oprez u javnim WLAN mrežama | stalno |
| 13 | Odlaske deaktivirati istog dana | po potrebi |
| 14 | API tokene koristiti štedljivo i sigurno | kod integracija |
| 15 | Štititi izvoze i interne brojeve | stalno |
| 16 | Prepoznati phishing | stalno |

---

## 1. Jedan račun po osobi

- Za svaku osobu otvorite vlastiti račun: **Team → „Invite“** → ime, e-mail, uloga → **„Send invitation“**.
- Nikada ne dijelite račun („Konobar šank“ za sve). Samo s ličnim računima zapisnik aktivnosti pokazuje ko je proknjižio koje iskorištavanje – to štiti i Vaše poštene zaposlene.
- Pozvana osoba sama bira lozinku preko linka koji važi 72 sata. Ako je link istekao, ponovo pošaljite pozivnicu.

## 2. Jake lozinke i menadžer lozinki

- GiftCard Pro zahtijeva najmanje 12 znakova s velikim i malim slovima te cifrom. Poznate lozinke koje su već procurile se odbijaju.
- Preporučite svom timu **fraze lozinke** od više riječi, npr. „Ćevapi-Fenjer-Bicikl-47“. Duge su, a ipak se lako pamte.
- Za vlasnike i menadžere: koristite **menadžer lozinki** (npr. Bitwarden, 1Password, KeePassXC ili ugrađeni menadžer Vašeg preglednika ili telefona).
- Lozinku za GiftCard Pro ne koristite nigdje drugdje.
- Detalji: [Politika lozinki](password-policy.md).

## 3. Osigurati telefone i tablete

Aplikacija za konobare GiftCard Waiter (Android i iPhone) odnosno web kasa u pregledniku radi na telefonima Vašeg tima. Uređaj je time dio okruženja Vaše kase.

- **Zaključavanje ekrana** PIN-om (najmanje 6 cifara), uzorkom ili biometrijski; automatsko zaključavanje nakon najviše 1–2 minute.
- **Operativni sistem, aplikaciju i preglednik održavati ažurnim** (uključiti automatska ažuriranja). Uređaje bez sigurnosnih ažuriranja proizvođača trebalo bi zamijeniti.
- **Imenovati uređaje:** Pod **Devices** svaki uređaj preimenujte simbolom olovke („Šank iPhone“, „Terasa Android“). Tada u slučaju gubitka odmah znate koji uređaj morate blokirati.
- Privatni telefoni konobara su mogući. U tom slučaju pismeno dogovorite da su zaključavanje ekrana i ažuriranja aktivni i da se gubitak odmah prijavljuje.

## 4. Izgubljeni ili ukradeni uređaji

1. Otvorite **Devices**, pronađite uređaj, odaberite **„Revoke“** i potvrdite. Uređaj se odbija od sljedećeg zahtjeva – čak i ako je sesija ili prijava aplikacije za konobare još bila otvorena.
2. Ako uređaj nije bio zaključan ili je lozinka mogla biti spremljena na njemu: resetujte lozinku pogođene osobe (Team → ⋯ → **„Send password reset“**). Resetovanje opoziva sve tokene osobe i odjavljuje sve druge sesije.
3. U zapisniku aktivnosti provjerite jesu li nakon trenutka gubitka stizala knjiženja s tog uređaja.
4. Ako se uređaj pronađe: **„Restore“**.

Uređaje standardno može blokirati samo uloga Owner. Osigurajte da je u slučaju potrebe uvijek dostupan vlasnik ili vlasnica.

## 5. Uloge po principu najmanjih prava

| Uloga | Za koga | Šta može |
|---|---|---|
| **Waiter** | konobari i konobarice | iskorištavati vaučere QR skeniranjem – ništa drugo |
| **Manager** | voditelj objekta, voditelj smjene | prodavati, dopunjavati, blokirati vaučere, stornirati, izvozi, zapisnik aktivnosti – ali bez tima, postavki, API tokena, isteka i besplatnih vaučera |
| **Owner** | vlasnici i vlasnice | sve u vlastitom restoranu |

- Ulogu Owner dodijelite samo osobama koje zaista odgovaraju za restoran.
- Ko samo iskorištava vaučere, dobija **Waiter**.
- Listu tima provjerite jednom tromjesečno (kontrolna lista u [Vodiču za kontrolu pristupa](access-control-guide.md)).

## 6. Iskorištavati samo skeniranjem

- Vaučer se iskorištava **samo** skeniranjem njegovog QR koda – u aplikaciji za konobare ili pod **Redeem** u pregledniku. Skeniranje stvara predočenje koje važi 60 sekundi i dozvoljava tačno jedno iskorištavanje.
- Interni broj vaučera **nije** sredstvo plaćanja. Ne nalazi se na listu za štampu i ne može se unijeti za iskorištavanje. Ko želi „iskoristiti“ broj telefonom ili fotografijom, biva odbijen.
- Ako aplikacija prikaže „nije prepoznato“, QR kod nije važeći vaučer Vašeg restorana (nepoznat, opozvan ili iz drugog restorana). Ne pokušavajte više puta – nakon 10 neuspjelih pokušaja u 5 minuta GiftCard Pro kratko blokira uređaj.
- Ako nakon iskorištavanja odgovor izostane, aplikacija prikazuje „ishod nejasan“ i pita server. **Ne** teretite ponovo dok ishod nije poznat.
- Fizičke kartice predviđene su kao NTAG 424 DNA kartice sa živom provjerom; do tada GiftCard Pro ima samo digitalne vaučere s QR kodom.

## 7. Svaku prodaju evidentirati s pravim plaćanjem

- Svaka prodaja i dopuna zahtijeva način plaćanja: **gotovina**, **kartični terminal** (s brojem potvrde), **bankovni transfer** (s referencom) ili **besplatno** (samo Owner, s obrazloženjem).
- Prodaju i iskorištavanje dodatno evidentirajte u fiskalnoj kasi. Plaćanja u GiftCard Pro olakšavaju usklađivanje.
- Besplatne vaučere redovno provjeravajte u zapisniku aktivnosti.

## 8. Listove za štampu čuvati kao gotovinu

- QR kod na listu za štampu **jeste** vaučer: ko ga da skenirati, može iskoristiti stanje. List za štampu ne prikazuje ni vrijednost ni broj vaučera.
- Listove za štampu odmah predajte gostu; ne ostavljajte ih otvoreno, ne fotografišite ih, ne pokazujte ih na društvenim mrežama.
- QR kod se prikazuje samo jednom – pri prodaji – i ne može se ponovo preuzeti. Ako se odgovor na prodaju izgubi, ponavljanje iste prodaje unutar 15 minuta na istom uređaju daje novi QR kod dok je vaučer nekorišten; neviđeni stari postaje nevažeći.
- Ako gost prijavi gubitak lista za štampu: odmah blokirajte vaučer (odjeljak 11).

## 9. Postaviti ograničenja protiv zloupotrebe

Pod **Settings → Vouchers** postavljate gornje granice koje ograničavaju moguću štetu:

| Postavka | Standard | Preporuka |
|---|---|---|
| Minimalna vrijednost vaučera | 5 € | prilagoditi svojoj ponudi |
| Maksimalno stanje | 500 € | ne više nego što je potrebno |
| Maksimalan iznos po iskorištavanju | 250 € | najveći realan iznos računa |
| Maksimalan iznos po vaučeru i danu | 500 € | ne više nego što je potrebno |
| Iskorištavanja po vaučeru i satu | 10 | dovoljno za većinu restorana; radije smanjiti nego povećati |
| Dozvoliti dopunu | uključeno | isključiti ako ne nudite dopune |
| Dozvoliti djelimično iskorištavanje | uključeno | isključiti samo ako se vaučeri uvijek trebaju potpuno iskoristiti |
| Važenje | bez isteka | ako uopšte, najmanje 36 mjeseci; istekli vaučer zadržava stanje |

Platforma postavlja gornje granice koje nijedan restoran ne može prekoračiti.

## 10. Sedmično provjeravati zapisnik aktivnosti

- Jednom sedmično otvorite **Audit log** i obratite pažnju na:
  - **neuspjela predočenja** (`presentment.failed`) – skenirani kod nije bio važeći vaučer Vašeg restorana; nagomilano na jednom uređaju to je znak upozorenja,
  - **zaključavanja računa** (`auth.locked`) – račun je zaključan nakon 10 neuspjelih pokušaja,
  - **besplatne vaučere, storna, istek i ponovne aktivacije** – razumljivi i obrazloženi?
- Provjerite upadljive obrasce: storna izvan radnog vremena, mnogo iskorištavanja jednog vaučera u kratkom vremenu, knjiženja s nepoznatih uređaja.
- Pojedinačna upozorenja često imaju bezazlene uzroke (zaprljan QR kod, vaučer drugog restorana). Više upozorenja za isti uređaj ili isti račun razlog su za djelovanje.
- Historija je nepromjenjiva: niko – ni GiftCard Pro – ne može naknadno mijenjati ili brisati knjiženja ili zapise aktivnosti; noćna provjera bi primijetila svaku izmjenu.

## 11. Sumnjivi vaučeri

1. Otvorite vaučer → **„Block“** → navedite razlog (npr. prijavljen gubitak, sumnjiva upotreba). Blokirani vaučer se ne može iskoristiti.
2. Pogledajte historiju: kada, na kojem uređaju i ko je posljednji put iskoristio?
3. Ako je sumnja otklonjena: **„Unblock“**.
4. Kod više sumnjivih vaučera u kratkom vremenu: javite se na security@giftcardpro.at.

Konobari standardno nemaju pravo blokirati vaučere. Dogovorite: vaučer koji se prikazuje kao blokiran ili djeluje čudno ne prihvata se, a voditelj smjene se odmah obavještava.

## 12. Javne WLAN mreže

- Veza s GiftCard Pro je uvijek šifrovana (HTTPS s HSTS-om). Ipak važi: ne prijavljujte se na tuđim, dijeljenim računarima (hotelski računar, internet kafe).
- Imajte **vlastiti WLAN za goste**, odvojen od WLAN-a za kasu i uređaje osoblja.
- Ako se ipak prijavite na tuđem uređaju: **ne** označavajte „Keep me signed in on this device“, nakon toga se odjavite i blokirajte uređaj pod **Devices**.

## 13. Odlasci: deaktivirati istog dana

- Kada neko napusti restoran: **Team → ⋯ → „Deactivate“** – posljednjeg radnog dana, ne kasnije.
- Deaktivacija završava sve sesije, opoziva sve tokene te osobe (i prijavu u aplikaciji za konobare) i sprječava svaku daljnju prijavu. Historija knjiženja ostaje potpuno sačuvana.
- Ako je osoba koristila privatni telefon, blokirajte i taj uređaj pod **Devices**.
- Pri promjeni uloge (npr. s Manager na Waiter) odmah prilagodite ulogu.

## 14. API tokeni

API tokeni povezuju GiftCard Pro s drugim sistemima (npr. s kasom).

- Odaberite samo onoliko dozvola (abilities) koliko integraciji zaista treba – npr. samo pregled i iskorištavanje.
- Odaberite kratko trajanje (moguće je najviše 365 dana) i obnovite prije isteka.
- Token se prikazuje **samo jednom**. Spremite ga u menadžer lozinki ili direktno u ciljnu aplikaciju – ne u e-mailove, chatove ili tabele.
- Tokene koji više nisu potrebni odmah opozovite (**Settings → API → Revoke**).
- Token djeluje u ime osobe koja ga je kreirala. Ako tu osobu deaktivirate ili ona promijeni lozinku, opozivaju se i njeni tokeni. Planirajte to kod promjena osoblja.
- Provjerite „posljednja upotreba“ (vrijeme i IP adresu): nepoznata IP adresa je znak upozorenja.

## 15. Štititi izvoze i interne brojeve

- Brojevi vaučera su interni (za osoblje i podršku). Nisu sredstvo plaćanja, ali ipak ne spadaju na društvene mreže niti trećim osobama.
- CSV izvozi sadrže podatke o kupcima: spremajte ih na zaštićenim uređajima i obrišite nakon upotrebe.
- E-mailovi za goste nikada ne sadrže stanje, iznos, broj vaučera niti link na vaučer. E-mail koji navodno dolazi od GiftCard Pro i prikazuje stanje ili poziva na „preuzimanje“ vaučera je lažan.

## 16. Prepoznati phishing

- **GiftCard Pro Vas nikada ne pita za lozinku** – ni e-mailom, ni telefonom, ni putem chata.
- Pravi e-mailovi od GiftCard Pro sadrže samo linkove na `giftcardpro.at` odnosno `app.giftcardpro.at`. Provjerite adresu u pregledniku prije nego što unesete lozinku.
- Budite oprezni kod vremenskog pritiska („Vaš račun će biti blokiran za 2 sata“) i kod priloga.
- Linkovi za pozivnicu i lozinku stižu samo ako ih je neko u Vašem restoranu pokrenuo. Neočekivane e-mailove te vrste ne otvarajte i proslijedite ih na security@giftcardpro.at.
- Naši zaposleni u podršci mogu Vam pomoći bez poznavanja Vaše lozinke.

---

## Sedmična mini rutina (5 minuta)

- [ ] Zapisnik aktivnosti: pregledana neuspjela predočenja, zaključavanja računa i besplatni vaučeri posljednjih 7 dana
- [ ] Devices: nema nepoznatih uređaja, izgubljeni uređaji su blokirani
- [ ] Team: niko nije aktivan ko više ne radi u restoranu
- [ ] Transakcije: storna u sedmici su razumljiva, plaćanja odgovaraju fiskalnoj kasi

## Kontakt

Sumnja na zloupotrebu ili sigurnosni propust: **security@giftcardpro.at**. Opšta pitanja: support@giftcardpro.at.

---

Verzija 2.0 · Stanje: septembar 2026.
