# Smjernice brenda za partnere i agencije

*Svrha: Sažete, obavezne smjernice za sve koji rade s brendom GiftCard Pro – agencije, štamparije, prodajne partnere, slobodne dizajnere i restorane kod zajedničkog brendiranja. Detalji su u povezanim pojedinačnim dokumentima.*

> **Napomena o imenu:** „GiftCard Pro" je radni naziv koji se trenutno provjerava ([name-alternatives.md](name-alternatives.md)). Molimo da bez dogovora ne proizvodite trajne reklamne materijale u velikom tiražu (natpise, oznake na vozilima, sajamske štandove).

---

## 1. Pregled

**Ko smo:** GiftCard Pro je sistem poklon kartica za ugostiteljstvo. Restorani izdaju fizičke poklon kartice s NFC čipom i QR kodom; konobari ih iskorištavaju za stolom za manje od 5 sekundi; svaki euro se bilježi u nepromjenjivom dnevniku transakcija. 0 % provizije.

**Misija:** „Restoranima dajemo sistem poklon kartica koji radi jednako dobro kao njihova usluga: brzo, pouzdano i lijepo."

**Ličnost:** miran, precizan, topao, samouvjeren bez buke – kao odličan šef sale.

**Brend u pet pravila:**
1. Mnogo bijelog, tamna slova, jedan topli akcent.
2. Geist za sve.
3. Brojke umjesto pridjeva.
4. Pravi objekti, prave ruke, prirodno svjetlo.
5. Na karticama za goste u prvom planu je restoran, ne mi.

| Tema | Detaljni dokument |
|---|---|
| Vrijednosti, pozicioniranje, arhitektura brenda | [brand-identity.md](brand-identity.md) |
| Jezik, pravila pisanja, mikrotekst | [tone-of-voice.md](tone-of-voice.md) |
| Logotip, slogani | [logo-and-naming.md](logo-and-naming.md) |
| Tipografija, boje, ikone, fotografije, štampa kartica | [visual-identity.md](visual-identity.md) |
| Društvene mreže | [social-media-style-guide.md](social-media-style-guide.md) |

---

## 2. Logotip – sažetak

- **Primarni logotip:** zaobljena kartica (1,586 : 1) u Tinti s tri NFC luka u Šafranu gore desno, pored nje „GiftCard Pro" u fontu Geist Semibold, „Pro" u Kamenu.
- **Varijante:** horizontalna (standard), složena, samo znak, jednobojna, na tamnoj podlozi (kartica kao bijeli obrub).
- **Zaštitna zona:** visina grupe lukova sa svih strana.
- **Minimalna veličina:** horizontalno 96 px / 25 mm; znak 16 px / 5 mm.
- **Podloge:** Bijela, Papir, Tinta, Grafit. Ne na Šafranu, ne na nemirnim fotografijama.
- **Nikad:** iskriviti, promijeniti boju, dodati efekte, ponovo slagati tekst, pisati drugačije.

Datoteke logotipa: `[link na paket logotipa nakon odobrenja]` (SVG, PDF, PNG u svijetloj/tamnoj verziji).

---

## 3. Boje – sažetak

| Naziv | Hex | Uloga |
|---|---|---|
| Tinta | #0F172A | boja brenda, kartice, naslovi |
| Grafit | #18181B | tekst, primarna dugmad |
| Kamen | #71717A | sekundarni tekst |
| Linija | #E4E4E7 | okviri, razdjelnici |
| Papir | #FAFAFA | pozadina |
| Bijela | #FFFFFF | površine |
| Šafran | #E8A33D | akcent, najviše 10 % |
| Žalfija | #047857 | uspjeh |
| Paprika | #B91C1C | greška, blokirano |
| Nebo | #2563EB | samo grafikoni |

**Važno:** Šafran nikad kao tekst na Bijeloj (2,2 : 1). Kamen za tekst samo na Bijeloj ili Papiru (4,8 : 1). CMYK vrijednosti i tamni režim: [visual-identity.md](visual-identity.md), odjeljak 2.

---

## 4. Tipografija – sažetak

- **Geist** (SIL Open Font License) za sve; **Geist Mono** samo za kod i tehničke ID-ove.
- Naslovi Semibold, uzak razmak slova; tekst 16 px / 1,5.
- Brojke uvijek tabelarnim ciframa.
- Rezervni font za štampu/Office: Inter; e-mail potpis: Arial.

---

## 5. Vizuelni jezik – sažetak

- **Fotografije:** pravi austrijski ugostiteljski objekti (gostionica, bečka kafana, Heuriger, bistro, bar), prirodno svjetlo, topli tonovi, mala dubinska oštrina, ruke i trenuci. Bez stock osmijeha, bez namještenih „high-five" poza.
- **Ilustracija:** linije u Grafitu, jedan akcent u Šafranu, bez 3D oblika, bez prelaza boja.
- **Ikone:** Lucide, linija 1,5–2 px, zaobljeni krajevi, mreža 24 px.
- **Snimci ekrana:** samo pravi ekrani aplikacije s uvjerljivim primjerima podataka (npr. „Gasthaus Zum Goldenen Hirschen"), nikad sa stvarnim podacima korisnika. Bez okvira preglednika ili jednostavan okvir s radijusom 12 px i obrubom u Liniji.

---

## 6. Raspored (layout)

### 6.1 Sistem razmaka (8 px)

Svi razmaci su višekratnici od 8 px; 4 px samo za fine razmake unutar komponenti.

| Token | Vrijednost | Tipična upotreba |
|---|---|---|
| space-0.5 | 4 px | ikona do teksta bedža |
| space-1 | 8 px | ikona do oznake, zbijene liste |
| space-1.5 | 12 px | unutrašnji razmak bedževa, polja obrazaca vertikalno |
| space-2 | 16 px | rub stranice na mobilnom, razmak između kartica |
| space-3 | 24 px | unutrašnji razmak kartica, razmak kolona mreže |
| space-4 | 32 px | razmak između grupa |
| space-6 | 48 px | razmak odjeljaka u aplikaciji |
| space-8 | 64 px | razmak odjeljaka na webu (mobilno) |
| space-12 | 96 px | razmak odjeljaka na webu (desktop) |

### 6.2 Web mreža

| Prijelomna tačka | od širine | Kolone | Razmak kolona | Vanjski rub |
|---|---|---|---|---|
| mobilno | 0 px | 4 | 16 px | 16 px |
| tablet | 768 px | 8 | 24 px | 32 px |
| desktop | 1024 px | 12 | 24 px | 48 px |
| široko | 1280 px | 12 | 24 px | centrirano, sadržaj najviše 1200 px |

Tekstualni blokovi najviše 8 od 12 kolona (oko 720 px). Odjeljci web stranice smjenjuju Bijelu i Papir; najviše jedan odjeljak u Tinti po stranici (npr. cijene ili završni poziv).

### 6.3 Radijusi

| Element | Radijus |
|---|---|
| Kartice, paneli, slike | 12–16 px (kartice na kontrolnoj tabli 16 px) |
| Standardna dugmad | 8 px |
| Dugmad u aplikaciji za konobare (velika) | 24 px odnosno potpuno zaobljeno |
| Polja za unos | 8 px |
| Bedževi, filter čipovi | potpuno zaobljeno (pill) |
| Poklon kartica (prikaz) | 3,18 mm odnosno 5,9 % širine kartice |

Sjenke štedljivo: najviše jedna vrlo meka sjenka (0 1 2 rgba(0,0,0,0.05)) na karticama; struktura se gradi Linijom #E4E4E7.

---

## 7. Izgled komponenti

### 7.1 Dugmad

| Vrsta | Svijetlo | Tamno | Visina |
|---|---|---|---|
| Primarno | površina Grafit, bijeli tekst, Semibold | bijela površina, tekst Grafit | 36–40 px (kontrolna tabla), 56–64 px (aplikacija za konobare) |
| Sekundarno | bijela površina, obrub Linija, tekst Grafit | #18181B, obrub #27272A, bijeli tekst | kao primarno |
| Destruktivno | površina Paprika, bijeli tekst | tekst #F87171 na tamnoj površini | kao primarno |
| Tekstualni link | Grafit, podvučeno pri prelasku mišem | Bijela | – |

- Natpis: glagol na početku, najviše tri riječi (iznos se ne računa): „Kreiraj karticu", „Iskoristi 24,90 €".
- Ikona opcionalno lijevo, 16–20 px, razmak 8 px.
- Fokus: prsten od 2 px u Nebu #2563EB s razmakom 2 px – nikad ga ne uklanjati.
- Po prikazu samo jedno primarno dugme.
- Šafran nije boja dugmeta (kontrast i pravilo akcenta). Izuzetak: površine u Tinti u marketingu, tada površina Šafran s tekstom u Tinti.

### 7.2 Kartice (UI kontejneri)

Bijela površina, obrub 1 px u Liniji, radijus 16 px, unutrašnji razmak 24 px. Naslov H4 (18 px Semibold), podnaslov Small u Kamenu. Ključna brojka 28 px Semibold s tabelarnim ciframa, red konteksta 12 px u Kamenu („otvorena obaveza na 4 kartice"). Ikona gore desno, 16–20 px, Kamen.

### 7.3 Bedževi (status)

Pill, 12 px Medium, unutrašnji razmak 4 × 8 px, ikona 12 px lijevo. Pozadina = boja statusa s 10 % neprozirnosti, tekst i obrub u punoj boji statusa.

| Status | Boja | Ikona (Lucide) |
|---|---|---|
| Aktivna | Žalfija | `circle-check` |
| Neaktivna | Kamen | `circle-dashed` |
| Iskorištena | Kamen | `check-check` |
| Blokirana | Paprika | `ban` |
| Istekla | Bakar #B45309 | `clock` |
| Zamijenjena | Nebo | `replace` |

Status nikad samo bojom – uvijek s tekstom.

---

## 8. Zajedničko brendiranje s restoranima

Poklon kartice pripadaju restoranu. Gost treba vidjeti restoran, ne softver.

**Pravila za kartice i materijale za goste:**
1. **Brend restorana na prvom mjestu:** logotip, naziv i boje restorana određuju prednju stranu, provjeru stanja i e-mailove za kupce.
2. **Bez logotipa GiftCard Pro na prednjoj strani.**
3. **Zadnja strana:** opcionalno „Powered by GiftCard Pro" u 5,5 pt, Kamen odnosno 60 % neprozirnosti boje teksta, dolje desno; nikad veće od kontakt podataka restorana. Restoran može odbiti ovu napomenu.
4. **Provjera stanja i e-mailovi:** pošiljalac i dizajn u ime restorana; GiftCard Pro najviše kao malo podnožje.
5. **Boje restorana** se preuzimaju; kontrast teksta i pozadine najmanje 4,5 : 1, QR kod uvijek crno na bijelom.
6. **Bez reklame za GiftCard Pro** na karticama za goste, stolnim stalcima ili računima restorana bez njegove izričite saglasnosti.

**Pravila za reference (restoran u našim materijalima):**
- Navođenje restorana samo uz pisano odobrenje (pilot restorani: saglasnost za navođenje je dio pilot programa, uvijek nakon odobrenja konkretnog materijala).
- Logotip restorana u našim materijalima: jednak ili manji od našeg logotipa, odvojen linijom od 1 px ili zaštitnom zonom, nikad spojen ili stopljen.
- Citati samo doslovno i odobreni: `[Citat nakon odobrenja]`.

**Partneri (npr. štamparija, dobavljač kase):** kombinacija „GiftCard Pro × [partner]" samo uz pisani sporazum; oba logotipa iste visine, optički uravnotežena, znak „×" u Kamenu.

---

## 9. Predlošci

| Predložak | Format | Sadržaj / struktura | Status |
|---|---|---|---|
| Prezentacija | 16 : 9, 1920 × 1080 px | naslovni slajd u Tinti s logotipom na tamnoj podlozi; slajdovi sa sadržajem na Bijeloj, naslov 40 px, tekst 20–24 px, najviše 3 poruke po slajdu; završni slajd s kontaktom | `[predložak nakon odobrenja]` |
| Letak | A5 uspravno, 148 × 210 mm, 3 mm porez | prednja strana: fotografija (motiv 1 ili 3) gore 60 %, slogan, logotip dolje; zadnja strana: tri koristi, cijene od 29 € neto, QR do web stranice, kontakt | `[predložak nakon odobrenja]` |
| Stolni stalak za restorane | A6 uspravno | u dizajnu restorana: „Poklonite večer kod nas." + slika kartice; bez logotipa GiftCard Pro | `[predložak nakon odobrenja]` |
| Predlošci za mreže | 1080 × 1350, 1080 × 1920, 1200 × 627 px | vidi [social-media-style-guide.md](social-media-style-guide.md) | `[predložak nakon odobrenja]` |
| E-mail newsletter | širina 600 px | Bijela, logotip 120 px gore lijevo, jedan naslov, jedno dugme (Grafit), podnožje s impresumom | `[predložak nakon odobrenja]` |
| Predložak kartice | 89,6 × 58 mm s porezom | vidi [visual-identity.md](visual-identity.md), odjeljak 6 | `[predložak nakon odobrenja]` |
| E-mail potpis | vidi ispod | – | obavezno |

### 9.1 E-mail potpis (obavezan raspored)

Čisti tekst ili jednostavan HTML, bez slika osim opcionalnog logotipa, bez banera, bez citata.

```
[Ime Prezime]
[Funkcija] · GiftCard Pro
T +43 1 [Telefon] · hallo@giftcardpro.at
giftcardpro.at

[Firmenname] [Rechtsform] · [Anschrift], 1xxx Wien
Firmenbuch: [Firmenbuchnummer], [Firmenbuchgericht: Handelsgericht Wien] · UID: [UID-Nummer]
```

| Red | Font | Veličina | Boja |
|---|---|---|---|
| Ime | Arial (odnosno Geist, ako je instaliran), podebljano | 14 px | #18181B |
| Funkcija · GiftCard Pro | Arial, normalno | 13 px | #18181B |
| Telefon, e-mail, web | Arial, normalno | 13 px | #18181B; linkovi nepodvučeni, boja #18181B |
| Podaci o firmi | Arial, normalno | 11 px | #71717A |
| Razmak | jedan prazan red između bloka kontakta i bloka firme | – | – |
| Logotip (opcionalno) | PNG, 120 × 24 px (datoteka 240 × 48 px za oštar prikaz), iznad imena, razmak 12 px | – | – |

Podaci o firmi ostaju na njemačkom, jer ispunjavaju obavezne navode za poslovna pisma i e-mailove registrovanih firmi u Austriji (§ 14 UGB) – nije pravni savjet, provjeriti prije upotrebe. Osoblje podrške koristi support@giftcardpro.at umjesto hallo@giftcardpro.at. Sezonski dodatni red (najviše jedan red, tekst, bez slike) samo nakon odobrenja, npr. „Poklon kartice za advent: naručite do sredine novembra."

---

## 10. Postupak odobravanja

| Korak | Ko | Rok |
|---|---|---|
| 1. Brief s ciljem, ciljnom grupom, kanalom, rokom | naručilac | – |
| 2. Nacrt prema ovim smjernicama | agencija/partner | – |
| 3. Slanje kao PDF ili link na hallo@giftcardpro.at, predmet „Odobrenje brenda: [naslov]" | agencija/partner | najmanje 5 radnih dana prije objave/štampe |
| 4. Provjera: logotip, boje, tekst (zabranjena lista, brojke, cijene), prava na fotografije, zajedničko brendiranje | [Ime], osnivačica | 3 radna dana |
| 5. Odobrenje ili ispravke pisano e-mailom | [Ime], osnivačica | – |
| 6. Štampa: probni otisak s usklađivanjem boja i testom QR/NFC prije tiraža | štamparija + [Ime], osnivačica | – |

**Bez odobrenja nije dozvoljeno:** novi slogani, navođenje cijena, obećanja o performansama (brzina, sigurnost, dostupnost), navođenje restorana, poređenje s konkurencijom, sve što ima pravnu ili poreznu vezu.

**Brza provjera prije slanja:**
- [ ] Logotip iz službenog paketa, zaštitna zona poštovana
- [ ] samo boje iz palete, Šafran ≤ 10 %
- [ ] Geist odnosno odobreni rezervni font
- [ ] cijene „neto, plus 20 % austrijskog PDV-a", brojke prema briefingu
- [ ] nema zabranjenih izraza, nema nizova uskličnika
- [ ] prava na fotografije i saglasnosti postoje
- [ ] brend restorana u prvom planu na materijalima za goste

---

## 11. Kontakt

| Tema | Kontakt |
|---|---|
| Odobrenje brenda, paket logotipa, predlošci | hallo@giftcardpro.at |
| Štampa i dizajn kartica | hallo@giftcardpro.at, predmet „Štampa kartica" |
| Mediji | hallo@giftcardpro.at, predmet „Mediji" |
| Odgovorna za brend | [Ime], osnivačica |
| Adresa | [Firmenname] [Rechtsform], [Anschrift], 1xxx Wien |

---

Verzija 1.0 · Stanje: septembar 2026.
