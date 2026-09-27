# Najbolje sigurnosne prakse za restorane

*Konkretne mjere kojima štitite svoje poklon kartice, račun svog tima i podatke svojih gostiju – za vlasnike i vlasnice te menadžere.*

GiftCard Pro donosi mnogo zaštitnih mehanizama. Neke od njih morate aktivirati, a druge djeluju samo ako ih Vaš tim primjenjuje u svakodnevnom radu. Ova kontrolna lista je razvrstana po temama; svaka tačka se može provesti za nekoliko minuta.

---

## Na prvi pogled

| Br. | Mjera | Kada |
|---|---|---|
| 1 | Vlastiti račun za svaku osobu | pri postavljanju, pri svakom novom zaposlenju |
| 2 | Jake lozinke, menadžer lozinki | odmah |
| 3 | Zaključavanje ekrana i ažuriranja na svim telefonima | odmah |
| 4 | Izgubljene uređaje odmah blokirati | po potrebi |
| 5 | Uloge po principu najmanjih prava | pri svakom novom zaposlenju, provjeravati tromjesečno |
| 6 | NTAG 424 DNA za visoke vrijednosti | pri narudžbi kartica |
| 7 | Zaključati čipove nakon upisa | pri postavljanju |
| 8 | Ostaviti uključenu zaštitu od kopiranja | pri postavljanju |
| 9 | Postaviti ograničenja protiv zloupotrebe | pri postavljanju |
| 10 | Provjeravati sigurnosna upozorenja u zapisniku aktivnosti | sedmično |
| 11 | Blokirati sumnjive kartice | po potrebi |
| 12 | Oprez u javnim WLAN mrežama | stalno |
| 13 | Odlaske deaktivirati istog dana | po potrebi |
| 14 | API tokene koristiti štedljivo i sigurno | kod integracija |
| 15 | Prazne kartice i podatke za štampu ne ostavljati nezaštićene | stalno |
| 16 | Prepoznati phishing | stalno |

---

## 1. Jedan račun po osobi

- Za svaku osobu otvorite vlastiti račun: **Team → „Invite"** → ime, e-mail, uloga → **„Send invitation"**.
- Nikada ne dijelite račun („Konobar šank" za sve). Samo s ličnim računima zapisnik aktivnosti pokazuje ko je proknjižio koje iskorištavanje – to štiti i Vaše poštene zaposlene.
- Pozvana osoba sama bira lozinku preko linka koji važi 72 sata. Ako je link istekao, koristite **„Resend invitation"**.

## 2. Jake lozinke i menadžer lozinki

- GiftCard Pro zahtijeva najmanje 12 znakova s velikim i malim slovima te cifrom. Poznate lozinke koje su već procurile se odbijaju.
- Preporučite svom timu **fraze lozinke** od više riječi, npr. „Ćevapi-Fenjer-Bicikl-47". Duge su, a ipak se lako pamte.
- Za vlasnike i menadžere: koristite **menadžer lozinki** (npr. Bitwarden, 1Password, KeePassXC ili ugrađeni menadžer Vašeg preglednika ili telefona).
- Lozinku za GiftCard Pro ne koristite nigdje drugdje.
- Detalji: [Politika lozinki](password-policy.md).

## 3. Osigurati telefone i tablete

Aplikacija za konobare radi u pregledniku svakog pametnog telefona. Uređaj je time dio okruženja Vaše kase.

- **Zaključavanje ekrana** PIN-om (najmanje 6 cifara), uzorkom ili biometrijski; automatsko zaključavanje nakon najviše 1–2 minute.
- **Operativni sistem i preglednik održavati ažurnim** (uključiti automatska ažuriranja). Uređaje bez sigurnosnih ažuriranja proizvođača trebalo bi zamijeniti.
- **Imenovati uređaje:** Pod **Devices** svaki uređaj preimenujte simbolom olovke („Šank iPhone", „Terasa Android"). Tada u slučaju gubitka odmah znate koji uređaj morate blokirati.
- Privatni telefoni konobara su mogući. U tom slučaju pismeno dogovorite da su zaključavanje ekrana i ažuriranja aktivni i da se gubitak odmah prijavljuje.

## 4. Izgubljeni ili ukradeni uređaji

1. Otvorite **Devices**, pronađite uređaj, odaberite **„Revoke"** i potvrdite. Uređaj se odbija od sljedećeg zahtjeva – čak i ako je sesija još bila otvorena.
2. Ako uređaj nije bio zaključan ili je lozinka mogla biti spremljena na njemu: resetujte lozinku pogođene osobe (Team → ⋯ → **„Send password reset"**). Promjena lozinke odjavljuje sve druge sesije.
3. U zapisniku aktivnosti provjerite jesu li nakon trenutka gubitka stizala knjiženja s tog uređaja.
4. Ako se uređaj pronađe: **„Restore"**.

Uređaje standardno može blokirati samo uloga Owner. Osigurajte da je u slučaju potrebe uvijek dostupan vlasnik ili vlasnica.

## 5. Uloge po principu najmanjih prava

| Uloga | Za koga | Šta može |
|---|---|---|
| **Waiter** | konobari i konobarice | skenirati i iskoristiti kartice – ništa drugo |
| **Manager** | voditelj objekta, voditelj smjene | prodavati, dopunjavati, blokirati, zamjenjivati, stornirati kartice, izvozi, zapisnik aktivnosti – ali bez tima, postavki i API tokena |
| **Owner** | vlasnici i vlasnice | sve u vlastitom restoranu |

- Ulogu Owner dodijelite samo osobama koje zaista odgovaraju za restoran.
- Ko samo iskorištava kartice, dobija **Waiter**.
- Listu tima provjerite jednom tromjesečno (kontrolna lista u [Vodiču za kontrolu pristupa](access-control-guide.md)).

## 6. NTAG 424 DNA za visoke vrijednosti kartica

- Standardne kartice (NTAG215) zaštićene su vezivanjem za serijski broj čipa. Ta provjera, međutim, radi samo pri skeniranju Androidom; iPhone, QR kod i ručni unos broja ne prenose serijski broj.
- NTAG 424 DNA kartice pri svakom prislanjanju generišu novi kriptografski potpis i praktično se ne mogu kopirati – na Androidu i iPhoneu.
- **Preporuka:** Za kartice od otprilike 100 € ili za poslovne kupce s velikim količinama koristite NTAG 424 DNA (uključeno u paket Pro).

## 7. Zaključati čipove nakon upisa

- **Settings → Gift cards:** uključite „Lock tags after writing".
- Zaključani NTAG21x čip više se ne može prepisati. To sprječava da neko zamijeni link na kartici drugim.
- Pažnja: zaključavanje je trajno. Upis prethodno isprobajte na probnoj kartici.

## 8. Ostaviti uključenu zaštitu od kopiranja

- **Settings → Gift cards:** zaštitu od kopiranja (Clone protection / vezivanje UID-a čipa) ostavite uključenu.
- Pri upisu Androidom čip se nakon upisa ponovo čita i provjerava; tek tada se sprema serijski broj. Kartice upisane drugom NFC aplikacijom (**„Mark as written"**) nisu vezane za čip. Zato kartice upisujte Android telefonom i Chromeom – za mnogo kartica odjednom pod **Gift cards → „Program NFC tags“**.

## 9. Postaviti ograničenja protiv zloupotrebe

Pod **Settings → Gift cards** određujete gornje granice koje ograničavaju moguću štetu:

| Postavka | Standard | Preporuka |
|---|---|---|
| Minimalna / maksimalna vrijednost kartice | 5 € / 1.000 € | prilagoditi Vašoj ponudi |
| Maksimalno stanje kartice | 2.000 € | ne više nego što je potrebno |
| Maksimalan pojedinačni iznos po iskorištavanju | – | npr. najveći realan iznos računa |
| Iskorištavanja po kartici na sat | 10 | dovoljno za većinu restorana; radije smanjiti nego povećati |
| Dozvoli dopunu | uključeno | isključiti ako ne nudite dopune |
| Dozvoli djelimično iskorištavanje | uključeno | isključiti samo ako se kartice uvijek iskorištavaju u cijelosti |
| Javna provjera stanja | uključeno | isključiti ako gosti ne trebaju sami provjeravati stanje |

## 10. Sedmično provjeravati zapisnik aktivnosti

- Jednom sedmično otvorite **Audit log** i filtrirajte sigurnosne događaje. Sigurnosna upozorenja su označena crvenom bojom sa simbolom štita:
  - **Cloned card rejected** – skenirana je kartica s pogrešnim serijskim brojem čipa ili nevažećim potpisom,
  - **ponovljeni NFC dodir** (replay) – stari NTAG 424 DNA link je ponovo korišten,
  - **strana kartica** – skenirana je kartica drugog restorana,
  - **Account locked** – račun je zaključan nakon 10 neuspjelih pokušaja.
- Provjerite upadljive obrasce: storna izvan radnog vremena, mnogo iskorištavanja jedne kartice u kratkom vremenu, knjiženja s nepoznatih uređaja.
- Pojedinačna upozorenja često imaju bezazlene uzroke (greška u kucanju, gost s karticom drugog restorana). Više upozorenja za istu karticu ili isti račun razlog su za djelovanje.

## 11. Sumnjive kartice

1. Otvorite karticu → **⋯ → „Block card"** → odaberite razlog (Reported stolen, Reported lost, Suspicious use). Blokirana kartica se u aplikaciji za konobare prikazuje crveno i ne može se iskoristiti.
2. Pogledajte historiju kartice: kada, gdje i ko je posljednji put iskoristio?
3. Ako kartica dokazano pripada gostu, prenesite stanje pomoću **„Replace lost card"** na novu karticu. Stara kartica se trajno stavlja van upotrebe.
4. Kod više sumnjivih kartica u kratkom vremenu: javite se na security@giftcardpro.at.

Konobari standardno nemaju pravo blokirati kartice. Dogovorite: kartica koja se prikazuje crveno ili djeluje čudno ne prihvata se, a voditelj smjene se odmah obavještava.

## 12. Javne WLAN mreže

- Veza s GiftCard Pro je uvijek šifrovana (HTTPS s HSTS-om). Ipak važi: ne prijavljujte se na tuđim, dijeljenim računarima (hotelski računar, internet kafe).
- Imajte **vlastiti WLAN za goste**, odvojen od WLAN-a za kasu i uređaje osoblja.
- Ako se ipak prijavite na tuđem uređaju: **ne** označavajte „Keep me signed in on this device", nakon toga se odjavite i blokirajte uređaj pod **Devices**.

## 13. Odlasci: deaktivirati istog dana

- Kada neko napusti restoran: **Team → ⋯ → „Deactivate"** – posljednjeg radnog dana, ne kasnije.
- Deaktivacija završava sve sesije, opoziva sve API tokene te osobe i sprječava svaku daljnju prijavu. Historija knjiženja ostaje potpuno sačuvana.
- Ako je osoba koristila privatni telefon, blokirajte i taj uređaj pod **Devices**.
- Pri promjeni uloge (npr. s Manager na Waiter) odmah prilagodite ulogu.

## 14. API tokeni

API tokeni povezuju GiftCard Pro s drugim sistemima (npr. s kasom).

- Odaberite samo onoliko dozvola (abilities) koliko integraciji zaista treba – npr. samo skeniranje i iskorištavanje.
- Odaberite kratko trajanje (moguće je najviše 365 dana) i obnovite prije isteka.
- Token se prikazuje **samo jednom**. Spremite ga u menadžer lozinki ili direktno u ciljnu aplikaciju – ne u e-mailove, chatove ili tabele.
- Tokene koji više nisu potrebni odmah opozovite (**Settings → API → Revoke**).
- Token djeluje u ime osobe koja ga je kreirala. Ako tu osobu deaktivirate, opozivaju se i njeni tokeni. Planirajte to kod promjena osoblja.
- Provjerite „posljednja upotreba" (vrijeme i IP adresu): nepoznata IP adresa je znak upozorenja.

## 15. Kartice i brojevi kartica

- Upisane, ali još neprodane kartice čuvajte sigurno, kao gotovinu.
- **„Activate immediately"** uključite samo ako se kartica prodaje u istom trenutku. Pripremljene kartice ostaju neaktivne dok nisu plaćene.
- Brojeve kartica, listove za štampu i CSV izvoze ne ostavljajte otvoreno, ne pokazujte na društvenim mrežama i ne prosljeđujte trećim osobama. Na reklamnim fotografijama učinite broj i QR kod nečitljivim.
- CSV izvozi sadrže podatke o kupcima: spremajte ih na zaštićenim uređajima i obrišite nakon upotrebe.

## 16. Prepoznati phishing

- **GiftCard Pro Vas nikada ne pita za lozinku** – ni e-mailom, ni telefonom, ni putem chata.
- Pravi e-mailovi od GiftCard Pro sadrže samo linkove na `giftcardpro.at` odnosno `app.giftcardpro.at`. Provjerite adresu u pregledniku prije nego što unesete lozinku.
- Budite oprezni kod vremenskog pritiska („Vaš račun će biti blokiran za 2 sata") i kod priloga.
- Linkovi za pozivnicu i lozinku stižu samo ako ih je neko u Vašem restoranu pokrenuo. Neočekivane e-mailove te vrste ne otvarajte i proslijedite ih na security@giftcardpro.at.
- Naši zaposleni u podršci mogu Vam pomoći bez poznavanja Vaše lozinke.

---

## Sedmična mini rutina (5 minuta)

- [ ] Zapisnik aktivnosti: pregledana crvena sigurnosna upozorenja posljednjih 7 dana
- [ ] Devices: nema nepoznatih uređaja, izgubljeni uređaji su blokirani
- [ ] Team: niko nije aktivan ko više ne radi u restoranu
- [ ] Transakcije: storna u sedmici su razumljiva

## Kontakt

Sumnja na zloupotrebu ili sigurnosni propust: **security@giftcardpro.at**. Opšta pitanja: support@giftcardpro.at.

---

Verzija 1.0 · Stanje: septembar 2026.
