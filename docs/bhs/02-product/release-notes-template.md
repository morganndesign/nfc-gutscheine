# Predložak: bilješke o izdanju za korisnike

*Kako novosti u GiftCard Pro opisujemo za restorane: struktura, pravila, ton i popunjeni primjer za verziju 1.2.0. Za sve koji pišu ili odobravaju bilješke o izdanju.*

---

## 1. Čemu služe bilješke o izdanju

Tehnički zapisnik promjena (`CHANGELOG.md`, vidi [predložak changeloga](changelog-template.md)) namijenjen je razvoju i operativi. Bilješke o izdanju (release notes) namijenjene su vlasnicima, menadžerima i konobarima. Odgovaraju na tri pitanja:

1. **Šta je novo ili drugačije?**
2. **Šta to znači za moj objekat?**
3. **Moram li nešto uraditi?**

Bilješke o izdanju objavljuju se na web stranici, e-mailom korisnicima (kod minor i major verzija) i u području pomoći.

---

## 2. Struktura

```markdown
# GiftCard Pro <verzija> — <kratak, jasan naslov>

*Objavljeno <datum> · <ciljna grupa u jednoj rečenici>*

## Najvažnije ukratko
<2–4 rečenice: najveća korist na prvom mjestu.>

## Morate li nešto uraditi?
<„Ne. Sve izmjene su automatski aktivne." — ili konkretni koraci s putanjom u aplikaciji.>

## Novo
- **<Korist kao naslov>.** <Šta je to, gdje se nalazi, UI naziv podebljano.>

## Poboljšano
- **<Korist>.** <Prije → sada.>

## Ispravljeno
- **<Šta sada radi ispravno>.** <Kada se greška javljala, ako je relevantno za korisnike.>

## Sigurnost
- <Opisati samo ono što korisnici trebaju znati. Bez detalja o napadu prije otklanjanja.>

## Za Vaš tim
<Opcionalno: šta konobari sljedeće večeri vide drugačije. Za štampu, najviše 5 tačaka.>

## Pitanja?
support@giftcardpro.at

---
Verzija <verzija> · <datum>
```

Odjeljci bez sadržaja se izostavljaju. Redoslijed je fiksan.

---

## 3. Pravila

### Sadržaj

1. **Korist prije funkcije.** Ne „Novi API endpoint `outstanding_cards`", nego „Sada vidite na koliko kartica se nalazi Vaš otvoreni iznos."
2. **Samo ono što korisnici primjećuju.** Interne prepravke, testovi i alati idu u changelog, a ne u bilješke o izdanju.
3. **Konkretne putanje u aplikaciji.** „**Settings → Gift cards → Default validity**", a ne „u postavkama".
4. **UI nazivi doslovno i podebljano**, dok je interfejs na engleskom, s objašnjenjem pri prvom pojavljivanju: **„Redeem"** (iskoristi).
5. **„Morate li nešto uraditi?" uvijek postoji**, čak i kada je odgovor „Ne".
6. **Brojke samo s dokazom.** Izmjerene vrijednosti navoditi onako kako su izmjerene („oko 0,5 sekundi u testu prihvatanja").
7. **Bez obećanja o budućnosti.** Napomene o planiranim funkcijama samo s uputom na plan razvoja i dodatkom „planirano".
8. **Sigurnost:** otklonjene propuste opisati tek kada su otklonjeni u svim okruženjima. Bez uputstva za zloupotrebu.
9. **Pravne teme** (rok važenja, porez) uvijek uz „nije pravni savjet — provjeriti s poreznim savjetnikom/advokatom".

### Jezik i ton

- „Vi", kratke rečenice, aktivni glagoli, neutralan jezik razumljiv u BiH, Hrvatskoj i Srbiji (ijekavica, latinica).
- Smireno i precizno. Bez „Zadovoljstvo nam je obavijestiti Vas", bez „revolucionarno", „game-changer", bez uskličnika.
- Greške imenovati otvoreno: „Na malim telefonima dugme za iskorištavanje nije bilo vidljivo. To je ispravljeno." Bez uljepšavanja, bez dramatizovanja.
- Iznosi „24,90 €" i „1.000 €", datum „9. 11. 2026."
- Dužina: što kraće. Patch verzije: 3–8 redova. Minor verzije: jedna stranica ekrana. Snimke ekrana samo kada prikazuju nešto što je teško opisati.

### Odobravanje

| Korak | Ko |
|---|---|
| Nacrt iz changeloga | Razvoj |
| Prepravka za korisnike | Proizvod |
| Provjera tačnosti (svaku tvrdnju provjeriti u proizvodu) | Podrška |
| Prevod na BHS | Proizvod / prevod |
| Objavljivanje | Proizvod |

---

## 4. Popunjeni primjer: verzija 1.2.0

---

# GiftCard Pro 1.2.0 — spremno za prvu večer

*Objavljeno u septembru 2026. · Za vlasnike, menadžere i konobare*

## Najvažnije ukratko

Svaki ekran prošli smo onako kako ga novi restoran koristi prvog dana — na računaru, tabletu, velikim i malim telefonima. Ono što je bilo zbunjujuće, sporo ili nepotrebno, promijenili smo. Aplikacija za konobare sada staje i na male telefone bez skrolanja, kontrolna tabla prvo prikazuje Vašu otvorenu obavezu, a kartice, stranica stanja i izvozi govore jezikom Vašeg restorana.

## Morate li nešto uraditi?

Ne. Sve izmjene su automatski aktivne.

Naša preporuka, ako to još niste uradili: pod **Settings → Gift cards** postavite zadani rok važenja (**Default validity**) na **0** (bez isteka). Pozadina: u Austriji su ograničenja plaćenih poklon bonova na tri godine ili manje u pravilu ništava. Nije pravni savjet — molimo provjerite s poreznim savjetnikom ili advokatom.

## Novo

- **Područje dobrodošlice za nove restorane.** Kontrolna tabla vodi Vas kroz četiri koraka do početka: provjeriti pravila kartica → pozvati tim → kreirati prvu karticu → otvoriti način za konobare. Nakon prve prodaje nestaje.
- **Razlozi jednim dodirom.** Pri blokiranju (Reported stolen, Reported lost, Suspicious use), zamjeni (Lost, Damaged, Stolen) i storniranju (Wrong amount, Wrong card, Guest cancelled) razlog birate jednim dodirom. To štedi vrijeme, a zapisnik aktivnosti ostaje ujednačen.
- **Kartice i stranica stanja na njemačkom.** Predložak za štampu (Gutschein, Gültig bis, napomena za skeniranje) i stranica stanja za goste u potpunosti se prikazuju na jeziku Vašeg restorana — uključujući status („Gültig", „Vollständig eingelöst").

## Poboljšano

### Aplikacija za konobare

- **Sve na prvi pogled, i na iPhoneu SE.** Stanje, broj kartice i status nalaze se u jednom kompaktnom redu. Iznos, tastatura i dugme **Redeem** staju na male telefone bez skrolanja.
- **Jasne boje kod problema.** Blokirane i zamijenjene kartice prikazuju crveno upozorenje, neaktivne i prazne žuto. Kod zamijenjenih kartica piše „Ask the guest for the new card".
- **Veliko dugme „Next card"** kada se kartica ne može koristiti. Prije je postojao samo mali ✕.
- **Razumljive poruke** umjesto stručnih izraza, npr. „No card with this number. Check the digits and try again."
- **Odgovarajuća uputstva za svaki telefon.** iPhonei pokazuju kako prinijeti karticu gornjem rubu; Android telefoni bez NFC-a napomenu da se uključi NFC i koristi Chrome.

### Kontrolna tabla

- **Brojke koje Vas zanimaju.** **Outstanding balance** (otvorena obaveza, s brojem kartica), **Revenue this month** (s poređenjem s prethodnim mjesecom), **Redeemed this month** (s današnjim iznosom) i **Cards sold**.
- **Iskreniji grafikoni.** Prodaja i iskorištavanja po danu prikazuju se kao stupci umjesto izglađene linije koja je prikazivala prodaju i u danima bez prodaje. Prazni periodi prikazuju „No sales in this period".
- **Brže na telefonu.** Pokazatelji se pojavljuju prvi, a grafikoni se učitavaju nakon njih.

### Kartice i izvozi

- **Lista kartica i dnevnik čitljivi na telefonu**, bez bočnog skrolanja: broj i kupac lijevo, stanje i status desno.
- **Razumljivi iznosi u historiji kartice.** „Total loaded" sada se zove **Reloaded** i prikazuje samo dopune; prodaja se prije računala dvaput.
- **Vrsta knjiženja „Sale"** umjesto „Issued", u aplikaciji i u izvozu.
- **Izvozi za poreznog savjetnika.** Statusi i vrste knjiženja pojavljuju se u CSV-u čitljivo (*Active*, *Sale*) umjesto tehničkih skraćenica.
- **Brojevi kartica uvijek u formatu za štampu** („7666 5628 6896 4312"), i u bilješkama o zamjeni.

### Tim, uređaji, zapisnik aktivnosti

- **Uređaji se zovu kao uređaj**, npr. „iPhone · Safari".
- **Zapisnik aktivnosti jasnim jezikom**, npr. „Card replaced", „Cloned card rejected". Sigurnosna upozorenja označena su crveno sa simbolom štita.
- **Potvrda prije opoziva uređaja**, da niko usred usluge slučajno ne ostane bez pristupa.

### Pristupačnost

- Bolji kontrasti kod zelenih iznosa i upozorenja, označena polja za izbor za čitače ekrana. Svi glavni ekrani ispunjavaju WCAG 2.1 AA u svijetlom i tamnom načinu.

## Ispravljeno

- Na malim telefonima dugme **Redeem** nalazilo se ispod vidljivog područja.
- Android telefoni prikazivali su uputstvo za iPhone.
- Stranica kartice na iPadu bila je nepregledna (dugmad jedno ispod drugog, odsječen status).
- Lista predložaka e-mailova prikazivala je rezervirano mjesto umjesto imena Vašeg restorana.

## Za Vaš tim

- Prinesi karticu, unesi iznos, **Redeem** — dugme je sada uvijek vidljivo.
- **Crveno** znači: ne prihvatati karticu, pozvati menadžera.
- **Žuto** znači: kartica je prazna ili još nije aktivirana.
- Kod „Ask the guest for the new card" gost ima zamjensku karticu.
- Sljedeću karticu možete prinijeti odmah.

## Pitanja?

support@giftcardpro.at

---

Verzija 1.0 · Stanje: septembar 2026.
