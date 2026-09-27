# Facebook oglasi (Meta)

*Svrha: Ciljevi kampanje, publike, šest varijanti oglasa sa kreativnim briefovima, budžet i plan testiranja za Facebook oglašavanje GiftCard Pro u Austriji (prvo Beč). Formati specifični za Instagram opisani su u `instagram-ads.md`.*

*Ova verzija je namijenjena BHS publici: vlasnicima i menadžerima restorana u Austriji koji govore bosanski, hrvatski ili srpski. Njemačke kampanje su opisane u njemačkoj verziji; struktura i brojke su iste.*

---

## 1. Ograničenja znakova i formati

| Polje | Preporuka | Napomena |
|---|---|---|
| Primarni tekst | **≤ 125 znakova** | Duži tekst se u feedu nakon oko 125 znakova skraćuje sa „Prikaži više". |
| Naslov | **≤ 40 znakova** | Na mobilnom se često skraćuje već nakon oko 27 znakova — suštinu staviti na početak. |
| Opis | **≤ 30 znakova** | Ne prikazuje se na svim pozicijama; nikad ga ne koristiti za važne informacije. |
| Slika | 1080 × 1350 (4:5) ili 1080 × 1080 (1:1) | Tekst na slici ispod 20 % površine. |
| Video | 4:5 za feed, 9:16 za Stories/Reels | Titlovi uvijek utisnuti, zvuk opcionalan. |

Svi brojevi znakova ispod su prebrojani (uključujući razmake).

---

## 2. Ciljevi kampanje i faze

| Faza | Period | Meta cilj | Svrha | Pokazatelj uspjeha |
|---|---|---|---|---|
| 1 Prepoznatljivost | 12. 10. – 8. 11. 2026. | **Interakcija → pregledi videa** | Prikazati video lansiranja ugostiteljima u Beču, izgraditi publiku za retargeting (bez piksela) | Trošak po ThruPlay, pregledi 50 % videa |
| 2 Upiti | 19. 10. – 30. 11. 2026. | **Leadovi → instant formular** | Upiti za pilot i demo | Trošak po leadu, udio kvalifikovanih leadova |
| 3 Probni periodi | od 3. 11. 2026. | **Leadovi → web stranica** (konverzija „Pokrenut probni period") | Pokretanje probnog perioda | Trošak po probnom periodu |
| 4 Sezona | januar i april 2027. | kao faza 3 | Valentinovo, Majčin dan kao povod | Trošak po probnom periodu |

**Faza 3 samo uz banner za saglasnost na web stranici.** Meta piksel i Conversions API zahtijevaju saglasnost (§ 165 st. 3 TKG 2021, GDPR). Bez saglasnosti nema piksela. Aplikacija (app.giftcardpro.at) ostaje bez praćenja. *Nije pravni savjet.*

**Instant formular (faza 2):**

- Polja: ime, prezime, e-mail, telefon, naziv restorana, bečki okrug (izbor), „Kako danas vodite poklon bonove?" (papir / Excel / kasa / drugi sistem / još nemamo).
- Vrsta formulara: **Veća namjera** (korak potvrde prije slanja).
- **Vlastita kvačica za saglasnost:** „Slažem se da me GiftCard Pro u vezi sa mojim upitom kontaktira e-mailom i telefonom. Opoziv u svakom trenutku." Bez kvačice samo jedan povratni poziv u vezi sa samim upitom, bez sekvence.
- Link na izjavu o zaštiti podataka.
- Leadove lično kontaktirati u roku od 4 radna sata — na BHS jeziku.

---

## 3. Publike

### 3.1 Osnovna publika (početak)

| Postavka | Vrijednost |
|---|---|
| Lokacija | Beč (+ 10 km), opcija „Osobe koje žive na ovoj lokaciji" |
| Starost | 28–65 |
| Jezik | hrvatski, srpski, bosanski |
| Detaljno ciljanje — interesovanja | ugostiteljstvo, hotelijerstvo, upravljanje restoranom, kafić, barmen, ketering, mala preduzeća |
| Detaljno ciljanje — zanimanja | vlasnik restorana, ugostitelj, menadžer restorana, direktor, šef sale, F&B menadžer, šef kuhinje (i njemački nazivi: Gastronom, Wirt, Restaurantleiter) |
| Ponašanje | vlasnici malih preduzeća (ako je dostupno) |
| Isključenja | postojeći korisnici (lista korisnika, samo uz pravni osnov), zaposleni u GiftCard Pro |

*Meta je više puta smanjivala opcije detaljnog ciljanja. Zanimanja i pojedina interesovanja provjeriti u Ads Manageru prije početka; opcije koje nedostaju izbrisati, ne zamjenjivati neodgovarajućim.*

**Očekivana veličina:** vrlo mala (procjenu provjeriti u Ads Manageru). Ako je publika ispod oko 5.000 osoba, ukloniti detaljno ciljanje i zadržati samo lokaciju + jezik, ili detaljno ciljanje koristiti kao prijedlog za **Advantage+ publiku**.

### 3.2 Retargeting (moguć bez piksela)

| Publika | Izvor | Trajanje |
|---|---|---|
| Pregledi videa ≥ 50 % | Video lansiranja (faza 1) | 60 dana |
| Interakcija sa Facebook stranicom | Stranica GiftCard Pro | 90 dana |
| Interakcija sa Instagram profilom | Profil GiftCard Pro | 90 dana |
| Instant formular otvoren, nije poslan | Faza 2 | 30 dana |

### 3.3 Retargeting (uz saglasnost)

| Publika | Izvor | Trajanje |
|---|---|---|
| Posjeta /bhs/cijene ili /bhs/pilot | Piksel (samo nakon saglasnosti) | 30 dana |
| Pokrenut probni period, nije izabran paket | Conversions API (samo nakon saglasnosti) | 30 dana |

### 3.4 Lookalike publike (kasnije)

- **Uslov:** najmanje 100 osoba u izvornoj publici iz Austrije (Meta minimum) i razjašnjen pravni osnov za učitavanje liste korisnika (obrada po nalogu, informisanje osoba).
- **Izvor:** restorani koji plaćaju (kontakt osobe), najranije od oko 100 korisnika — prema planu (pretpostavka) tokom 2027.
- **Do tada:** testirati lookalike na osnovu pregleda videa ≥ 75 % (1 %, Austrija).

---

## 4. Šest varijanti oglasa

### V1 — „Prislonite. Naplatite. Gotovo." (brzina)

| Polje | Tekst | Znakova |
|---|---|---|
| Primarni tekst | Prislonite karticu, ukucajte iznos, gotovo. Poklon bon naplaćen za stolom za manje od 5 sekundi. Probajte 30 dana besplatno. | 124 |
| Naslov | Prislonite. Naplatite. Gotovo. | 30 |
| Opis | Bez kreditne kartice | 20 |
| Dugme CTA | „Registruj se" | |

**Kreativni brief:** video 4:5, 12 s. Scena 1 (0–3 s): ruka stavlja karticu u boji Tinte na drveni sto, pored računa. Scena 2 (3–7 s): konobarica prislanja karticu uz Android telefon, kuca „2 4 9 0". Scena 3 (7–10 s): ekran uspjeha sa preostalim stanjem (`waiter-success.png` kao umetak). Scena 4 (10–12 s): logo, „30 dana besplatno". Titlovi na BHS jeziku utisnuti. Pravi restoran, dnevno ili toplo večernje svjetlo, bez lica okrenutih u kameru.

### V2 — „0 % provizije" (poštenje)

| Polje | Tekst | Znakova |
|---|---|---|
| Primarni tekst | Mnogi sistemi zarađuju na svakom prodanom poklon bonu. Mi ne: fiksna cijena od 29 € mjesečno, 0 % provizije. | 108 |
| Naslov | Poklon kartice bez provizije | 28 |
| Opis | Start 29 € / mjesec neto | 24 |
| Dugme CTA | „Saznaj više" | |

**Kreativni brief:** jedna slika 1:1. Bijela pozadina, krupno u boji Tinte: „Poklon bon 100 €. 100 € za Vas." Ispod sitnije u boji Stein: „0 % provizije · od 29 € / mjesec neto". Dolje desno kartica sa lukovima u boji Safran. Bez fotografije, bez ljudi. Varijanta B: isto kao fotografija — kartica na tacni za račun.

### V3 — „Otvoreni iznosi" (kontrola)

| Polje | Tekst | Znakova |
|---|---|---|
| Primarni tekst | Koliko je iznosa na poklon bonovima u Vašem restoranu još otvoreno? GiftCard Pro to pokazuje na prvi pogled. | 108 |
| Naslov | Svaki euro sa poklon bona na oku | 32 |
| Opis | Izvoz za knjigovođu | 19 |
| Dugme CTA | „Zakaži termin" | |

**Kreativni brief:** karusel, 3 kartice 1:1. Kartica 1: fotografija knjige poklon bonova sa rukom pisanim unosima, tekst „Danas". Kartica 2: screenshot `owner-dashboard.png` u okviru laptopa, KPI „Outstanding balance" sa okvirom u boji Safran, tekst „Sa GiftCard Pro". Kartica 3: screenshot `transactions.png`, tekst „Izvoz za Excel".

### V4 — „Poklon koji izgleda kao poklon" (vrijednost)

| Polje | Tekst | Znakova |
|---|---|---|
| Primarni tekst | Papirni bon kaže „na brzinu kupljeno". Kartica u dizajnu Vašeg restorana kaže „izabrano baš za tebe". | 101 |
| Naslov | Poklon kartice u Vašem dizajnu | 30 |
| Opis | 100 NFC kartica od 249 € | 24 |
| Dugme CTA | „Zatraži ponudu" | |

**Kreativni brief:** jedna slika 4:5. Dvije ruke predaju karticu preko postavljenog stola, svjetlo svijeća, mala dubinska oštrina. Na kartici čitljivo: naziv primjera restorana `[primjer restorana]`, iznos, „Za Anu". Bez teksta na slici. Napomena u komentaru ili na odredišnoj stranici: „Okvirna cijena, zavisi od količine i štampe — obavezujuća ponuda na upit."

### V5 — „Pilot Beč" (samo do 30. 11. 2026.)

| Polje | Tekst | Znakova |
|---|---|---|
| Primarni tekst | 10 pilot mjesta za bečke restorane: 3 mjeseca gratis, zatim 12 mjeseci 50 % jeftinije. Postavljanje i 50 kartica uključeno. | 123 |
| Naslov | Zatražite pilot mjesto u Beču | 29 |
| Opis | Samo do kraja novembra | 22 |
| Dugme CTA | „Registruj se" (instant formular) | |

**Kreativni brief:** video 4:5, 15 s, osnivačica za šankom (sa strane, ne frontalno u kameru) izgovara na BHS jeziku jednu rečenicu: „Tražimo deset bečkih restorana koji će s nama uvesti GiftCard Pro prije adventa." Zatim tri prednosti kao natpisi. Titlovi utisnuti. Broj slobodnih mjesta prikazati samo ako je aktuelan.

### V6 — „Advent" (sezona)

| Polje | Tekst | Znakova |
|---|---|---|
| Primarni tekst | Advent je najjače vrijeme za poklon bonove. Počnite sada, da Vaše kartice budu u restoranu prije 29. novembra. | 110 |
| Naslov | Spremni prije adventa | 21 |
| Opis | 30 dana besplatno | 17 |
| Dugme CTA | „Registruj se" | |

**Kreativni brief:** jedna slika 4:5. Adventski vijenac na stolu u gostionici, pored mala hrpa kartica sa trakom, toplo svjetlo. Gore lijevo sitno bijelim slovima: „Od 29. novembra". Trajanje 2.–25. 11. 2026. Za Valentinovo i Majčin dan ponovo koristiti sa novim motivom i datumom.

---

## 5. Budžet

*Pretpostavke — nakon dvije sedmice prilagoditi prema trošku po leadu.*

| Faza | Period | Dnevni budžet BHS | Ukupno (oko) |
|---|---|---|---|
| 1 Prepoznatljivost (V1 kao video) | 12. 10. – 8. 11. 2026. | 2 € | 55 € |
| 2 Upiti (V5, V3) | 19. 10. – 30. 11. 2026. | 3 € | 130 € |
| 3 Probni periodi (V1, V2, V4, V6) | 3. 11. – 15. 12. 2026. | 3 € | 130 € |
| Mirna faza | 16. 12. 2026. – 6. 1. 2027. | 0 € | 0 € |
| Valentinovo, Majčin dan | po 4 sedmice | 3 € | po oko 85 € |

- BHS oglasi su dodatak njemačkim kampanjama i dio marketinškog budžeta od 1.000–2.000 € mjesečno (pretpostavka).
- Pozicije: Facebook feed, Instagram feed, Instagram Stories, Instagram Reels. Isključiti Audience Network i Messenger.
- **Frekvencija:** u maloj publici brzo raste. Od frekvencije 4 u 7 dana promijeniti motiv.
- **Ciljani trošak po leadu (faza 2):** ispod 40 € (pretpostavka).

---

## 6. Plan A/B testiranja

Mali budžeti rijetko daju statistički sigurne rezultate. Zato: malo testova jedan za drugim, uvijek samo jedna varijabla, najmanje 7 dana, odluka prema trošku po leadu **i** kvalitetu leadova (je li održan razgovor?).

| Test | Period | Varijabla | Varijante | Pokazatelj | Odluka |
|---|---|---|---|---|---|
| T1 | 19.–28. 10. 2026. | Poruka | V3 kontrola vs. V5 pilot | Trošak po leadu | Pobjednik dobija 70 % budžeta |
| T2 | 3.–12. 11. 2026. | Poruka | V1 brzina vs. V2 provizija vs. V4 vrijednost | Trošak po probnom periodu | Dvije najbolje dalje |
| T3 | 13.–22. 11. 2026. | Format | Pobjednik iz T2 kao video vs. slika | Trošak po probnom periodu | Format za sezonu 2027. |
| T4 | januar 2027. | Publika | Detaljno ciljanje vs. samo jezik + lokacija | Trošak po probnom periodu, udio ugostitelja među leadovima | Standard za 2027. |

**Dodatni test za BHS:** isti oglas na BHS jeziku vs. na njemačkom, oba ciljana na BHS jezičku publiku. Pitanje: da li maternji jezik povećava stopu odgovora? Kod BHS publike očekujemo (pretpostavka) višu stopu interakcije, ali to treba provjeriti.

**Alat:** Meta funkcija „A/B test" (odvojene publike). Kod premalog dosega umjesto toga dinamički kreativni testovi unutar jedne grupe oglasa i ocjena po oglasu.

**Zapisnik:** svaki test sa hipotezom, periodom, budžetom, rezultatom i odlukom upisati u zajedničku tabelu.

---

## 7. Lista za odobrenje prije svakog oglasa

- [ ] Sve tvrdnje odgovaraju proizvodu (ne tvrditi funkcije online prodavnice, kase ili walleta).
- [ ] Cijene neto, „plus 20 % PDV-a" vidljivo na odredišnoj stranici.
- [ ] Cijene kartica označene kao okvirne.
- [ ] Bez citata ili logotipa korisnika bez pisanog odobrenja.
- [ ] Najviše jedan emoji — u ovim predlošcima nijedan.
- [ ] Pilot oglasi planirani sa datumom završetka.
- [ ] Piksel aktivan samo nakon saglasnosti.
- [ ] Leadovi na BHS jeziku dobijaju odgovor na BHS jeziku.

---

Verzija 1.0 · Stanje: septembar 2026.
