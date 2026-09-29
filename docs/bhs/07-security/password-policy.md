# Politika lozinki

*Obavezujuća pravila za lozinke, pozivnice, zaključavanje računa i API tokene u GiftCard Pro – za sve korisnike i korisnice restorana te za administraciju platforme.*

---

## 1. Svrha i obuhvat

Ova politika određuje kako se štite pristupi GiftCard Pro. Važi za

- sve korisničke račune restorana (Owner, Manager, Waiter),
- sve račune administracije platforme GiftCard Pro,
- API tokene za integracije.

Odjeljke označene s **[tehnički provedeno]** GiftCard Pro provodi automatski. Odjeljci označeni s **[organizaciono]** su u odgovornosti pojedinih osoba odnosno restorana.

---

## 2. Zahtjevi za lozinke [tehnički provedeno]

| Zahtjev | Vrijednost |
|---|---|
| Minimalna dužina | **12 znakova** |
| Vrste znakova | najmanje jedno **veliko slovo**, jedno **malo slovo** i jedna **cifra** |
| Poznate lozinke | lozinke iz javno poznatih curenja podataka se odbijaju (provjera putem k-anonimnog postupka servisa „Have I Been Pwned"; prenosi se samo prvih pet znakova SHA-1 hash vrijednosti, nikada lozinka) |
| Nova lozinka | pri promjeni se mora razlikovati od dosadašnje i mora se dvaput identično unijeti |
| Spremanje | isključivo kao **bcrypt hash**; sama lozinka se nikada ne sprema i ni GiftCard Pro je ne može vidjeti |

Prisilna, periodična promjena lozinke namjerno **nije** predviđena. Iskustvo pokazuje da vodi ka slabijim lozinkama. Lozinke se mijenjaju kod sumnje (odjeljak 7).

## 3. Preporuke iznad minimalnih zahtjeva [organizaciono]

- Koristite **fraze lozinke** od četiri ili više slučajnih riječi s cifrom, npr. „Burek-Kišobran-Sava-Oblak-9". Dužina je važnija od složenosti.
- **Menadžer lozinki** za vlasnike, vlasnice i menadžere (npr. Bitwarden, 1Password, KeePassXC, ugrađeni menadžer preglednika odnosno operativnog sistema). Slučajno generisane lozinke s najmanje 16 znakova.
- **Jedinstvenost:** Lozinka za GiftCard Pro se ne koristi nigdje drugdje.
- **Bez ličnih veza:** bez naziva restorana, datuma rođenja, naziva ulica.
- **Ne zapisivati** na papiriće, u ladicu kase, na pozadinu telefona ili u chat grupe.

---

## 4. Zaključavanje računa i zaštita od isprobavanja [tehnički provedeno]

| Pravilo | Vrijednost |
|---|---|
| Pokušaji prijave | najviše 5 u minuti po e-mail adresi i IP adresi, 30 u minuti po IP adresi |
| Zaključavanje računa | nakon **10 uzastopnih neuspjelih pokušaja** na **15 minuta** |
| Bilježenje | neuspjeli pokušaji na poznatim računima i zaključavanja pojavljuju se u zapisniku aktivnosti (`auth.failed`, `auth.locked`); zaključavanje dodatno kao upozorenje u zapisniku aplikacije |
| Jedinstven odgovor | pogrešna lozinka, nepoznata adresa i zaključan račun dobijaju **istu** poruku u istom vremenu odgovora (lozinka se uvijek provjerava) – odgovor ne otkriva ni postoji li adresa ni je li račun zaključan |
| Zaboravljena lozinka | najviše 5 zahtjeva u minuti po IP adresi; odgovor je identičan za poznate i nepoznate adrese |

Nakon isteka zaključavanja osoba se može ponovo prijaviti. Ko nije sam izazvao zaključavanje, to prijavljuje vlasniku odnosno vlasnici – to može biti pokušaj napada.

---

## 5. Pozivnice i resetovanje [tehnički provedeno]

| Radnja | Pravilo |
|---|---|
| Novi član tima | dobija e-mailom **jednokratni link pozivnice**, važi **72 sata**, i sam bira lozinku |
| Istekla pozivnica | nova pozivnica generiše novi link; stari više ne radi |
| Zaboravljena lozinka / resetovanje | link e-mailom, važi **60 minuta**, može se koristiti samo jednom |
| Odvojeni postupci | pozivnice i resetovanja koriste odvojena spremišta tokena s vlastitim rokovima važenja; zahtjev „zaboravljena lozinka“ nikada ne može zamijeniti otvorenu pozivnicu, a računi s otvorenom pozivnicom ne dobijaju link za resetovanje |
| Bez tokena u logovima | token se nalazi u fragmentu URL-a (`#token=…`), koji preglednik nikada ne šalje serveru |
| Učinak | resetovanje opoziva sve tokene osobe i završava „Keep me signed in“ |
| Novi vlasnik / nova vlasnica restorana | pri postavljanju ga/je administracija platforme također poziva linkom pozivnice |

---

## 6. Nema prosljeđivanja lozinki [organizaciono i tehnički]

- GiftCard Pro **nikada** ne šalje lozinke e-mailom i **nikada** ne traži lozinku e-mailom, telefonom ili putem chata.
- Lozinke se **ne** prosljeđuju između osoba – ni od vlasnika konobaru. Svaka osoba ima vlastiti račun.
- Podrška GiftCard Pro odvija se bez poznavanja Vaše lozinke.
- Zahtjeve za lozinkama treba tretirati kao pokušaj prevare i prijaviti na security@giftcardpro.at.

---

## 7. Promjena kod sumnje [organizaciono]

Lozinku treba **odmah** promijeniti (**Account** → promjena lozinke) odnosno vlasnik ili vlasnica je treba resetovati ako

- ju je mogao saznati neko drugi,
- je bila spremljena na izgubljenom ili ukradenom uređaju,
- je korištena i za drugi servis pogođen curenjem podataka,
- je otvorena phishing poruka i tamo uneseni podaci,
- zapisnik aktivnosti pokazuje radnje koje osoba nije sama izvršila,
- je došlo do zaključavanja računa koje osoba nije sama izazvala.

Promjena ili resetovanje lozinke opoziva **sve tokene** osobe (aplikacija za konobare i integracije), završava „Keep me signed in“ i automatski odjavljuje **sve druge sesije** [tehnički provedeno].

---

## 8. Sesije [tehnički provedeno]

- Sesije ističu nakon **8 sati neaktivnosti**, osim ako je odabrana opcija „Keep me signed in on this device“. Ona je standardno isključena; tako obnovljena sesija prihvata se samo na aktivnom uređaju koji je osoba već koristila. Tu opciju koristite samo na vlastitim, zaključanim uređajima.
- Svaka sesija je vezana za uređaj na kojem je započeta.
- Prijava u aplikaciji za konobare važi samo na telefonu za koji je izdata i ističe nakon 30 dana bez korištenja.
- Blokirani uređaji i deaktivirani korisnici se odbijaju pri sljedećem zahtjevu.

---

## 9. Dodatna pravila za administraciju platforme [organizaciono]

Računi administracije platforme upravljaju platformom: kreiraju restorane, onemogućavaju ih i arhiviraju te održavaju sistemske postavke. Nikada ne djeluju unutar restorana, nikada ne diraju vaučere i ne mogu kreirati niti koristiti API tokene [tehnički provedeno]. Za njih dodatno važi:

1. Lozinka iz menadžera lozinki, slučajno generisana, najmanje **20 znakova**.
2. Prijava samo s održavanih uređaja sa šifrovanjem diska, zaključavanjem ekrana i aktuelnim ažuriranjima; nikada s tuđih ili dijeljenih uređaja.
3. Računi platforme uvijek se prijavljuju izričito; „Keep me signed in on this device“ za njih ne važi [tehnički provedeno].
4. Pristupi za Hetzner, Coolify, GitHub, registrar domene, slanje e-mailova i menadžer lozinki zaštićeni su dvofaktorskom autentifikacijom.
5. Podrška restoranu odvija se preko samog restorana (vlasnik ili vlasnica dijeli ekran ili opisuje korake); svaka radnja platforme bilježi se u zapisniku aktivnosti cijele platforme.
6. Računi platforme kreiraju se samo preko serverske konzole i nikada se ne dodjeljuju u restoranu.
7. Lista računa administracije platforme provjerava se tromjesečno; računi koji više nisu potrebni odmah se deaktiviraju.
8. Serverske tajne (`APP_KEY`, SMTP pristupni podaci, ključevi za potpisivanje aplikacije za konobare) čuvaju se isključivo u menadžeru lozinki odnosno u Coolifyju i GitHub secrets. Ključevi kartica nikada nisu dio konfiguracije; nalaze se u hardverskom sigurnosnom modulu iza kripto servisa.

---

## 10. API tokeni

| Pravilo | Provedba |
|---|---|
| Kreiranje | samo osobe s dozvolom `api_tokens.manage` (standardno Owner) pod **Settings → API**; nikada administracija platforme [tehnički provedeno] |
| Dozvole | slobodno odabrane abilities, **najviše dozvole osobe koja kreira token** [tehnički provedeno]; odabrati samo neophodno [organizaciono] |
| Trajanje | najviše **365 dana** [tehnički provedeno]; preporučeno kraće trajanje [organizaciono] |
| Prikaz | tekst tokena prikazuje se **samo jednom**; sprema se samo SHA-256 hash [tehnički provedeno] |
| Prepoznatljivost | tokeni počinju s `gcp_` kako bi se mogli pronaći u kodu i dokumentima |
| Praćenje | spremaju se vrijeme i IP adresa posljednje upotrebe |
| Opoziv | moguć u svakom trenutku; automatski kada se osoba koja ga je kreirala deaktivira ili promijeni odnosno resetuje lozinku [tehnički provedeno] |
| Čuvanje | samo u menadžeru lozinki ili direktno u ciljnoj aplikaciji; nikada u e-mailovima, chatovima, tabelama ili repozitorijima koda [organizaciono] |

---

## 11. Odgovornosti

| Uloga | Odgovornost |
|---|---|
| **Svaki korisnik, svaka korisnica** | odabrati vlastitu lozinku prema odjeljcima 2–3, čuvati je u tajnosti, mijenjati je kod sumnje, prijavljivati sumnjive slučajeve |
| **Owner (vlasnik/vlasnica)** | otvoriti račun za svaku osobu, odlaske deaktivirati istog dana, upravljati API tokenima, upoznati tim s politikom |
| **Manager** | paziti na poštivanje u dnevnom radu, upadljivosti prijavljivati Owneru |
| **GiftCard Pro** | tehnička provedba, sigurno spremanje, računi administracije platforme prema odjeljku 9, podrška kod incidenata |

---

## 12. Provođenje

- Tehnička pravila aplikacija provodi automatski; lozinke koje ih ne ispunjavaju se odbijaju.
- Kršenja organizacionih pravila (npr. dijeljeni računi, proslijeđene lozinke) svaki restoran uređuje interno. GiftCard Pro preporučuje da se ova politika uvrsti u radne upute za tim.
- Kod sumnje na zloupotrebu GiftCard Pro može radi zaštite platforme opozvati tokene odnosno onemogućiti restoran i bez odgađanja obavještava pogođeni restoran.
- Ova politika se provjerava godišnje i nakon sigurnosno relevantnih incidenata.

---

Verzija 2.0 · Stanje: septembar 2026.
