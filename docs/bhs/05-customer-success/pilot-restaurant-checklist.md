# Pilot program – kontrolna lista za pilot restorane

*Kontrolna lista iz perspektive Customer Successa za pilot program (oktobar–novembar 2026, 5–10 restorana u Beču): odabir, sporazum, početni sastanak, prva sedmica, pokazatelji uspjeha, intervju za povratne informacije, kriteriji za opće tržišno lansiranje i odobrenje za referencu. Tehničke tačke za puštanje u rad nalaze se u engleskom dokumentu PILOT_CHECKLIST.md.*

---

## 1. Ciljevi pilot programa

1. Dokazati da iskorištavanje kartice za stolom u svakodnevnom radu traje **manje od 5 sekundi** (uključujući čovjeka).
2. Dokazati da se konobari snalaze **bez duge obuke** (modul A: 15 minuta).
3. Pronaći greške, nesporazume i funkcije koje nedostaju prije lansiranja u **novembru 2026** – na vrijeme prije Adventa i Božića.
4. Provjeriti pretpostavke za planiranje (cijene, količine kartica, obim podrške).
5. Uz saglasnost restorana dobiti prve reference.

## 2. Kriteriji za odabir pilot restorana

**Obavezni kriteriji**
- [ ] Restoran u Beču, dostupan za sastanke na licu mjesta.
- [ ] Vlasnik/vlasnica sam/sama odlučuje i učestvuje na početnom i završnom sastanku.
- [ ] Poklon bonovi se već danas prodaju (papir, funkcija kase ili drugi sistem) ili su čvrsto planirani za božićnu sezonu.
- [ ] Dostupan je najmanje jedan Android telefon s NFC-om i Chromeom za upisivanje kartica (ili će biti obezbijeđen); stabilan Wi-Fi u sali.
- [ ] Postoji fiskalna kasa i porezni savjetnik je dostupan (za knjiženje bonova u kasi).
- [ ] Spremnost na razgovore o povratnim informacijama (vidi odjeljak 3).

**Poželjni kriteriji (za uravnoteženu grupu)**
- [ ] Mješavina vrsta objekata: restoran, gostionica, kafana/kafić, bar; po mogućnosti jedan objekat s velikim brojem bonova.
- [ ] Mješavina uređaja: Android i iPhone u servisu.
- [ ] Najmanje jedan restoran s višejezičnim timom (njemački/BHS/engleski), jer je sučelje za zaposlene trenutno na engleskom.
- [ ] Najmanje jedan restoran zainteresovan za NTAG 424 DNA (zaštita od kloniranja, paket Pro).
- [ ] Najmanje jedan restoran koji želi koristiti e-mailove za kupce.

**Kriteriji isključenja za pilot**
- Više lokacija koje očekuju zajedničku kontrolnu tablu (još ne postoji; svaka lokacija je zaseban račun).
- Potreba za online prodajom bonova ili obradom plaćanja (nije dio proizvoda; plan razvoja Q1 2027).
- Očekivanje direktne veze s kasom od prvog dana.

## 3. Pilot sporazum – ključne tačke

| Tačka | Sadržaj |
|---|---|
| Učesnici | prvih 10 restorana u Beču, oktobar–novembar 2026 |
| Obaveze pružatelja | **3 mjeseca besplatno**, zatim **12 mjeseci 50 % popusta** (Start 14,50 € / Pro 29,50 € mjesečno, neto + 20 % PDV); **besplatno postavljanje na licu mjesta** uključujući obuku (inače 149 €); **50 besplatnih kartica** |
| Obaveze restorana | razgovori o povratnim informacijama (početni sastanak, 1. sedmica, 4. sedmica, završni), učešće u kratkim anketama, prijava grešaka; **navođenje kao reference samo uz izričito odobrenje** |
| Izbor paketa | Start ili Pro; promjena u bilo kojem trenutku |
| Trajanje i otkaz | B2B ugovor; mjesečno otkaziv do kraja mjeseca; nakon isteka perioda popusta redovna cijena |
| Podaci | izvoz podataka u bilo kojem trenutku; brisanje 30 dana nakon kraja ugovora (osim zakonske obaveze čuvanja); zaključuje se ugovor o obradi podataka po nalogu |
| Dostupnost | ciljana vrijednost 99,5 % mjesečno, bez garancije |
| Podrška | kao Pro (4 radna sata), plus dnevne provjere u 1. sedmici |

*Ovo je prijevod. Pravno mjerodavna je njemačka verzija. Sporazum je predložak – prije upotrebe dati na provjeru advokatu ovlaštenom u Austriji.*

## 4. Prije početnog sastanka (Customer Success)

- [ ] Potpisani pilot sporazum i ugovor o obradi podataka po nalogu.
- [ ] Završen tehnički dio A kontrolne liste (PILOT_CHECKLIST.md): server, domena, slanje e-mailova, sigurnosne kopije, nadzor.
- [ ] Restoran kreiran u administraciji platforme (**Onboard restaurant**), pozivnica vlasniku/vlasnici poslana i prihvaćena.
- [ ] Dizajn kartice usaglašen, naručeno 50 pilot kartica (NTAG215); testne kartice za svaki model telefona dostupne.
- [ ] Dogovoren termin početnog sastanka (60–90 minuta, izvan vremena servisa); učesnici: vlasnik/vlasnica, menadžer, 1–3 konobara.
- [ ] Porezni savjetnik restorana informisan o knjiženju bonova u fiskalnoj kasi (restoran razjašnjava, mi dajemo informacije).
- [ ] Kontakt osoba u restoranu i dostupnost (telefon, željeno vrijeme) zabilježeni u CRM-u.

## 5. Početni sastanak na licu mjesta (dan 0)

1. [ ] Objasniti ciljeve i tok pilota; razjasniti očekivanja (šta proizvod može, a šta ne: nije fiskalna kasa, nema online prodavnice, sučelje za zaposlene na engleskom).
2. [ ] Zajedno proći **Welcome** panel:
   - [ ] **Card rules:** **„Default validity (months)"** = 0 (razgovarati o pravnoj napomeni, promijeniti tvorničku postavku od 36 mjeseci), minimalna/maksimalna vrijednost, dopuna, djelimično iskorištavanje.
   - [ ] **Restaurant profile:** naziv firme, UID broj, adresa, **Deutsch (Österreich)**, vremenska zona Europe/Vienna.
   - [ ] Boja brenda, podnožje e-maila, e-mailovi za kupce uključeni/isključeni.
   - [ ] Pozvati **Team** – svaka osoba s vlastitim e-mailom.
3. [ ] Prodati testnu karticu od 5 €, upisati je Androidom, provjeriti stranicu sa stanjem na iPhoneu i Androidu.
4. [ ] Na **svakom službenom telefonu**: prijaviti se, instalirati web-aplikaciju na početni ekran, skenirati testnu karticu, iskoristiti 1 €, **„Next card"**; preimenovati uređaj pod **Devices**.
5. [ ] Obuka modul A (konobari), modul B (menadžeri), modul C (vlasnici) – vidi vodič za obuku.
6. [ ] Zajedno: stornirati testno iskorištavanje, blokirati testnu karticu, zamijeniti je.
7. [ ] Postaviti kratko uputstvo kod kase.
8. [ ] Proći knjiženje bona u fiskalnoj kasi (prodaja i iskorištavanje).
9. [ ] Prikupiti početne vrijednosti (odjeljak 7: polazna osnova).
10. [ ] Utvrditi sljedeće termine: dnevne provjere u 1. sedmici, razgovor u 4. sedmici, završni razgovor.

## 6. Prva sedmica – dnevne provjere (5–10 minuta, telefonom ili na licu mjesta)

| Dan | Fokus | Kontrolne tačke |
|---|---|---|
| 1 | Prve stvarne prodaje i iskorištavanja | [ ] Prodane kartice? [ ] Iskorištavanja bez pomoći? [ ] Pojavile se poruke? [ ] Knjiženje u kasi jasno? |
| 2 | Uređaji i prijava | [ ] Svi službeni telefoni prijavljeni i imenovani? [ ] Odjave, zaključani računi? [ ] NFC na Androidu, čitanje na iPhoneu u redu? |
| 3 | Kontrolna tabla s vlasnikom/vlasnicom | [ ] Zajedno pregledani **Outstanding balance** i **Recent activity** [ ] Brojke uvjerljive? |
| 4 | Posebni slučajevi | [ ] Bili potrebni storno, blokada, zamjena? [ ] Pitanja gostiju (stranica sa stanjem, e-mailovi)? |
| 5 | Sigurnost i zaključak sedmice | [ ] **Audit log** provjeren na crvena sigurnosna upozorenja [ ] **Transactions → Export CSV** poslan knjigovodstvu, format u redu? [ ] Prikupljene povratne informacije konobara |

**Za svaku provjeru dokumentovati:** datum, sagovornika, broj prodaja/iskorištavanja od posljednje provjere, probleme (s brojem tiketa), citate, sljedeće korake.

**Pravilo:** sve što zahtijeva više od jednog dodira ili izaziva pitanje evidentira se kao prijedlog za poboljšanje.

## 7. Pokazatelji uspjeha

| Pokazatelj | Mjerenje | Ciljana vrijednost pilota (pretpostavka) |
|---|---|---|
| Prodane kartice | kontrolna tabla **Cards sold**, po restoranu i sedmici | dostignuta ili premašena polazna osnova restorana (papirni bonovi u istom periodu prethodne godine) |
| Vrijednost prodaje | **Revenue this month** | prikuplja se, bez ciljane vrijednosti |
| Vrijeme iskorištavanja za stolom | uzorak štopericom: 10 iskorištavanja po restoranu, od predaje kartice do ekrana uspjeha | medijan < 5 sekundi |
| Vrijeme obuke konobara | trajanje modula A | ≤ 15 minuta |
| Greške u korištenju | broj storna (**„Reversal"**) u odnosu na iskorištavanja | < 2 % |
| Tehničke greške | tiketi P1/P2 | 0 P1; P2 riješen u roku od 1 radnog dana |
| Obim podrške | tiketi i minute po restoranu i sedmici | prikuplja se (osnova za planiranje) |
| Sigurnosna upozorenja | zapisi u **Audit log** | sva razjašnjena |
| Zadovoljstvo vlasnika | **NPS** pitanje na završnom razgovoru (0–10) | ≥ 30 za sve pilot restorane |
| Zadovoljstvo konobara | kratka anketa 1–5 „Koliko je jednostavno iskorištavanje?" | prosjek ≥ 4 |
| Nastavak | restoran ostaje nakon 3 besplatna mjeseca | ≥ 80 % pilot restorana |

Sve ciljane vrijednosti su pretpostavke za planiranje i provjeravaju se tokom pilota.

**NPS pitanje:** „Koliko je vjerovatno da biste GiftCard Pro preporučili prijatelju ugostitelju? (0 = nimalo, 10 = vrlo vjerovatno)" – zatim: „Koji je najvažniji razlog za Vašu ocjenu?"

## 8. Vodič za razgovor o povratnim informacijama (4. sedmica i završni, 30–45 minuta)

**Uvod**
1. Kako ste upravljali poklon bonovima prije GiftCard Pro i šta Vam je pri tome smetalo?
2. Kakav je bio Vaš prvi utisak u prvoj sedmici?

**Servis za stolom**
3. Kako Vaši konobari reaguju na iskorištavanje? Da li je bilo situacija u kojima neko nije znao kako dalje?
4. Koja poruka u aplikaciji je bila nejasna?
5. Koliko dobro radi čitanje kartica s Vašim telefonima (Android, iPhone, QR)?
6. Koliko englesko sučelje smeta Vašem timu?

**Prodaja i gosti**
7. Kako gosti reaguju na karticu u poređenju s papirnim bonom?
8. Da li gosti koriste stranicu sa stanjem ili e-mailove? Da li je bilo pitanja?
9. Kako teče prodaja – ko kreira karticu, koliko to traje?

**Administracija i brojke**
10. Koju brojku na kontrolnoj tabli gledate, a koja Vam nedostaje?
11. Kako je knjigovodstvo odnosno porezni savjetnik reagovao na izvoz?
12. Koliko se tok rada uklapa s Vašom fiskalnom kasom?

**Vrijednost i cijena**
13. Koji problem Vam GiftCard Pro najviše rješava?
14. Kako ocjenjujete redovnu cijenu u odnosu na korist?
15. Šta bi se moralo desiti da nakon pilota ne nastavite?

**Završetak**
16. Kada biste mogli promijeniti jednu stvar – koju?
17. NPS pitanje (vidi odjeljak 7).
18. Smijemo li Vas navesti kao referencu odnosno napisati studiju slučaja? (vidi odjeljak 10)

**Pravila razgovora:** postavljati otvorena pitanja, ne braniti se, tražiti konkretne primjere („Kada je to bilo posljednji put?"), doslovne citate zapisivati i koristiti samo uz odobrenje.

## 9. Kriteriji za „spremno za opće tržišno lansiranje"

Lansiranje u novembru 2026 slijedi kada su ispunjeni **svi** obavezni kriteriji:

**Obavezno**
- [ ] Najmanje 5 pilot restorana je najmanje 2 sedmice prodavalo i iskorištavalo stvarne kartice.
- [ ] Nema otvorene greške prioriteta P1 ili P2.
- [ ] Nije utvrđeno odstupanje između dnevnika transakcija i stanja kartica.
- [ ] Medijan vremena iskorištavanja za stolom < 5 sekundi u svim restoranima.
- [ ] Konobari svih pilot restorana iskorištavaju kartice bez pomoći.
- [ ] Potvrđene sigurnosne kopije uključujući test vraćanja; nadzor aktivan.
- [ ] Objavljeni materijali za uvođenje, baza znanja i videi (najmanje video 2, 3, 5, 6).
- [ ] Standardni ugovori, opći uslovi i ugovor o obradi podataka po nalogu pravno provjereni.
- [ ] Proces podrške (brojevi tiketa, makroi, eskalacija) isproban u praksi.

**Poželjno**
- [ ] NPS ≥ 30; zadovoljstvo konobara ≥ 4.
- [ ] Najmanje 2 odobrene reference.
- [ ] Tri najčešća prijedloga za poboljšanje ocijenjena i planirana (npr. sučelje za zaposlene na njemačkom).

Ako obavezni kriteriji nisu ispunjeni, uprava odlučuje o odgodi ili lansiranju s poznatim ograničenjima; odluka se dokumentuje.

## 10. Odobrenje za referencu i studiju slučaja

- [ ] Referenca samo uz **pisano odobrenje** vlasnika/vlasnice (dovoljan je e-mail), odvojeno po vrsti korištenja:
  - [ ] navođenje naziva i logotipa restorana (web stranica, prezentacije)
  - [ ] citat – samo u odobrenom obliku: `[Citat nakon odobrenja]`
  - [ ] fotografije u restoranu (osobe na fotografijama daju zasebnu saglasnost)
  - [ ] studija slučaja s pokazateljima – samo odobrene brojke
  - [ ] spremnost za pozive zainteresovanih
- [ ] Odobrenje se može povući u bilo kojem trenutku; kod povlačenja uklanjanje u roku od [rok, npr. 14 dana].
- [ ] Prije objave predložiti nacrt na odobrenje.
- [ ] Odobrenja čuvati centralno (datum, obim, osoba).

**Predložak e-maila za odobrenje**
> Poštovani/Poštovana [ime],
> hvala Vam na učešću u pilot programu. Smijemo li [naziv restorana] navesti kao referencu? Konkretno Vas molimo za saglasnost za: [lista vrsta korištenja]. Tekst ćemo Vam predložiti prije objave. Saglasnost možete povući u bilo kojem trenutku.
> Srdačan pozdrav, [ime], GiftCard Pro

## 11. Završetak pilota po restoranu

- [ ] Održan završni razgovor, prikupljen NPS, zapisnik sačuvan.
- [ ] Potvrđen prelazak u redovan rad (paket, 50 % popusta 12 mjeseci nakon 3 besplatna mjeseca, fakturisanje).
- [ ] Otvoreni tiketi riješeni ili s rokom.
- [ ] Poslano pismo zahvale.

---

Verzija 1.0 · Stanje: septembar 2026.
