# Rješavanje problema GiftCard Pro

*Simptom → uzrok → rješenje: prijava, NFC, QR kod, poruke o kartici, veza, uređaji, e-mailovi, izvozi, kontrolna tabla i štampanje.*

---

**Kako koristiti ovaj vodič:** potražite poruku koju aplikacija prikazuje (engleski originalni tekst podebljano) ili simptom. Sučelje za zaposlene je trenutno na engleskom; značenje je navedeno uz svaku poruku. Ako nijedno rješenje ne pomogne, pišite na support@giftcardpro.at (podaci vidi Vodič za podršku, odjeljak 5).

**Osnovno pravilo za konobare:** u slučaju sumnje karticu ne iskorištavati i pozvati menadžera. Transakcija se kasnije uvijek može naknadno proknjižiti.

---

## 1. Prijava i korisnički račun

| Simptom / poruka | Uzrok | Rješenje |
|---|---|---|
| **„Too many failed attempts. Try again in 15 minutes."** (previše neuspješnih pokušaja) | Nakon 10 pogrešnih unosa lozinke račun se zaključava na 15 minuta. | Sačekati 15 minuta, zatim se ponovo prijaviti. Lozinka nepoznata → **„Forgot password?"**. Tim u tom periodu vidi račun kao **„Locked"**. |
| **„Too many requests. Please slow down."** (previše zahtjeva) | Više od 5 pokušaja prijave u minuti. | Sačekati jednu minutu. |
| Prijava ne uspijeva, a lozinka je sigurno tačna | Greška u e-mail adresi, račun deaktiviran ili restoran pauziran | Provjeriti e-mail (velika/mala slova nisu bitna). Vlasnik/vlasnica provjerava pod **Team** da li je osoba **„Active"**. Poruka **„This restaurant account is suspended. Please contact support."** → kontaktirati podršku. |
| Link iz pozivnice ne radi, poruka poput **„This password reset token is invalid."** | Link stariji od **72 sata** ili već iskorišten | Vlasnik/vlasnica: **Team → ⋯ → „Resend invitation"** (ponovo pošalji pozivnicu). Uvijek koristiti najnoviji link. |
| Link iz **„Forgot password?"** ne radi | Link stariji od **60 minuta**, već iskorišten ili je zatražen noviji link | Zatražiti novi link i odmah ga iskoristiti. |
| Nema e-maila nakon **„Forgot password?"** | Iz sigurnosnih razloga potvrda uvijek glasi isto – i kada adresa ne postoji. | Koristiti tačnu adresu, provjeriti neželjenu poštu. Vlasnik/vlasnica može poslati link pod **Team → ⋯ → „Send password reset"**. |
| Lozinka nije prihvaćena | Minimalni zahtjevi nisu ispunjeni | Najmanje 12 znakova, velika i mala slova i jedna cifra. |
| Nakon promjene lozinke odjava na drugim uređajima | Namjerno: promjena lozinke odjavljuje sve ostale sesije. | Ponovo se prijaviti na ostalim uređajima. |
| **„This session belongs to another device. Please sign in again."** (sesija pripada drugom uređaju) | Sesije su vezane za uređaj; podaci preglednika su obrisani, kopirani ili je uređaj promijenjen. | Ponovo se prijaviti. Uređaj se pri tome ponovo registruje. |
| **„Your session has expired. Please reload the page."** (sesija je istekla) | Stranica je dugo bila otvorena, sigurnosni token je zastario | Ponovo učitati stranicu. |
| Odjava nakon nekoliko sati nekorištenja | Sesije ističu nakon 8 sati neaktivnosti. | Pri prijavi aktivirati **„Keep me signed in on this device"** (samo na službenim telefonima restorana). |

---

## 2. NFC – Android

| Simptom / poruka | Uzrok | Rješenje |
|---|---|---|
| **„NFC is turned off or not available. Enable NFC in the phone settings."** | NFC je isključen. | Postavke → Veze → uključiti NFC. Nazad u aplikaciju, **„Scan card"**. |
| **„To tap cards, switch on NFC and open this page in Chrome. Until then, scan the QR code."** | Drugi preglednik (Samsung Internet, Firefox …) ili NFC isključen | Otvoriti aplikaciju u **Chromeu**, najbolje preko ikone na početnom ekranu instalirane iz Chromea. |
| **„NFC permission was denied. Allow NFC for this site in the browser settings."** | Dozvola za NFC na stranici je odbijena | Chrome → ikona lokota pored adrese → Dozvole → NFC → Dozvoli. Ponovo učitati stranicu. |
| **„NFC is not supported on this device."** | Uređaj nema NFC čip | Koristiti **„Scan QR code"** ili **„Card number"**; za servis planirati uređaj s NFC-om. |
| Ništa se ne dešava pri prislanjanju | **„Scan card"** još nije pritisnut ili pogrešno mjesto | Jednom pritisnuti **„Scan card"**. Karticu ravno prisloniti uz gornji dio poleđine (položaj NFC čipa razlikuje se po modelu), oko 1 sekunde, po potrebi skinuti futrolu. |
| **„The tag was removed too early. Please hold it still and try again."** / **„The card could not be read. Hold it still against the back of the phone."** | Kartica je prekratko ili pomjerana držana | Držati mirno dok telefon ne zavibrira. |
| **„This tag does not contain a gift card."** (čip ne sadrži poklon karticu) | Prazna kartica, strani NFC čip (npr. bankovna kartica, pristupna kartica) ili pogrešno upisana kartica | Koristiti pravu karticu. Vlastita kartica prazna → u kontrolnoj tabli **⋯ → „Write NFC tag"** ponovo upisati. |
| **„This NFC tag is already linked to another active card."** (pri upisivanju) | Ovaj čip je već povezan s drugom aktivnom karticom. | Koristiti novu, praznu karticu. |
| Kartica se ne može upisati | Čip je trajno zaključan (**„Lock tag after writing"**) ili oštećen | Koristiti novu karticu. Zaključani čipovi ne mogu se prepisati – to je namjerno. |

## 3. NFC – iPhone

| Simptom | Uzrok | Rješenje |
|---|---|---|
| Nema obavijesti pri prislanjanju | iPhone stariji od XS, ekran isključen ili zaključan, otvorena aplikacija kamere odnosno Wallet, uključen način rada u avionu | Otključati iPhone, karticu prisloniti uz **gornju ivicu poleđine**. Stariji modeli: **„Scan QR code"**. |
| Obavijest se pojavi, ali otvara stranicu sa stanjem za goste | Na iPhoneu niko nije prijavljen u GiftCard Pro (ili u drugom pregledniku). | U istom pregledniku (Safari odnosno web-aplikacija) prijaviti se kao konobar. Prijavljene osobe dolaze direktno u način rada za konobare s otvorenom karticom. |
| Nema reakcije kod jedne kartice, ostale rade | Kartica nije upisana (prazna) | U kontrolnoj tabli provjeriti da li pod **„NFC tag"** stoji datum upisivanja; ako ne, upisati. |
| Obavijest s drugim sadržajem (npr. strana web stranica) | Čip je prepisan (nije bio zaključan) | Ne prihvatiti karticu, pozvati menadžera. Zamijeniti karticu, ubuduće uključiti **„Lock tags after writing"**. |

**Napomena:** iPhone ne može sam upisivati kartice. Za upisivanje koristiti Android telefon s Chromeom ili aplikaciju za upisivanje NFC-a (kopirati URL iz dijaloga, zatim **„Mark as written"**).

## 4. QR kod i kamera

| Simptom / poruka | Uzrok | Rješenje |
|---|---|---|
| **„Camera access was denied."** | Pristup kameri odbijen | Postavke preglednika → stranica → kamera → dozvoli. iPhone: Postavke → Safari → Kamera → Pitaj/Dozvoli. Ponovo učitati stranicu. |
| **„Camera unavailable."** | Kameru koristi druga aplikacija | Zatvoriti druge aplikacije (kamera, video poziv). |
| **„QR scanning is not supported on this device."** | Preglednik ne podržava ugrađeni QR skener | Skenirati kod običnom aplikacijom kamere (otvara karticu) ili koristiti **„Card number"**. |
| QR kod se ne prepoznaje | Loše osvjetljenje, izgreban kod, premala štampa | Približiti/udaljiti, poboljšati svjetlo. Štampati uvijek u **100 %** (vidi odjeljak 10). |

---

## 5. Poruke o kartici

| Poruka | Značenje | Rješenje |
|---|---|---|
| **„No card with this number. Check the digits and try again."** | Ukucani broj ne postoji (kontrolna cifra ne odgovara ili je kartica nepoznata). | Uporediti cifre u blokovima po četiri, ponovo ukucati. |
| **„This is not one of our gift cards."** | Skenirani link ne pripada nijednoj kartici ovog restorana. | Ne prihvatiti. Kartica drugog restorana ili nevažeća. |
| **„This gift card was issued by a different restaurant and cannot be used here."** | Kartica drugog restorana (i druge lokacije iste grupe – svaka lokacija je zaseban račun) | Ne prihvatiti. Uputiti gosta na restoran koji je izdao karticu. |
| **„This card is blocked"** (crveno, eventualno s razlogom) | Kartica blokirana (npr. **„Reported lost"**, **„Reported stolen"**, **„Suspicious use"**) | Ne prihvatiti, pozvati menadžera. Menadžer provjerava historiju, deblokira (**„Unblock"**) ili zamjenjuje. |
| **„This card was replaced and is no longer valid. Ask the guest for the new card."** (crveno) | Kartica je zamijenjena zamjenskom; stanje je na novoj kartici. | Pitati za novu karticu. Ako je gost nema, pozvati menadžera – na stranici kartice stoji **„This card was replaced by …"** s linkom na novu karticu. |
| **„This card has expired."** | Rok važenja je prošao; preostalo stanje automatski je otpisano u 00:15. | Ne iskorištavati, pozvati menadžera. Gost pravno ipak može imati pravo (vidi pravnu napomenu dolje). |
| **„This card is not activated yet."** (žuto) | Kartica je kreirana bez **„Activate immediately"**. | Menadžer: otvoriti karticu → **⋯ → „Activate"**. |
| **„This card has no balance left."** (žuto) | Stanje 0 € | Obavijestiti gosta; po potrebi dopuniti ako je dozvoljeno. |
| **„More than the balance. Redeem € X and collect the rest otherwise."** | Uneseni iznos je veći od stanja | **„Full balance"**, iskoristiti, ostatak naplatiti drugačije. |
| **„This restaurant only allows redeeming the full balance."** | Djelimično iskorištavanje je isključeno. | Iskoristiti samo cijelo stanje, ili vlasnik/vlasnica uključuje **„Partial redemption"**. |
| **„The amount exceeds the maximum allowed for a single redemption."** | Prekoračen maksimalni iznos po iskorištavanju | Menadžer provjerava; vlasnik/vlasnica prilagođava **„Maximum single redemption"**. |
| **„The resulting balance would exceed the maximum allowed card balance."** | Nakon dopune stanje bi bilo veće od dozvoljenog (standard 2.000 €). | Dopuniti manji iznos. |
| **„Reloading gift cards is disabled for this restaurant."** | Dopuna je isključena | Provjeriti postavku **„Allow reloading"**. |
| **„The NFC chip does not match the registered card. The card may be cloned."** | Serijski broj čipa ne odgovara kartici → sumnja na kopiju | Ne prihvatiti. Menadžer blokira karticu, provjerava **„Audit log"** (crveno sigurnosno upozorenje). Obavijestiti podršku. |
| **„This NFC read was already used. Please tap the card again."** / **„The secure NFC signature could not be verified."** | NTAG 424 DNA: kopirani link ili nepotpuno čitanje | Ponovo prisloniti karticu. Ako se poruka ponavlja: ne prihvatiti, pozvati menadžera. |

**Pravna napomena o isteku:** plaćeni poklon bonovi u Austriji se u pravilu mogu iskoristiti 30 godina; kratka ograničenja često su nevažeća. Kod opravdanog zahtjeva menadžer izdaje novu karticu ili prenosi iznos. Preporuka: **„Default validity (months)"** postaviti na 0. *Nije pravni savjet – provjerite s poreznim savjetnikom odnosno advokatom.*

---

## 6. Veza

| Poruka | Značenje | Rješenje |
|---|---|---|
| **„No connection to the server. Check the internet connection and try again."** | Telefon ne dostiže server (nema Wi-Fi-ja, slab mobilni signal). **Ništa nije proknjiženo.** | Provjeriti Wi-Fi odnosno mobilne podatke, zatim ponovo pritisnuti isto dugme. **Ponavljanje je sigurno:** svako iskorištavanje nosi jedinstveni ključ; server ga nikada ne knjiži dvaput, čak ni ako je prvi zahtjev ipak stigao. Za kontrolu: historija kartice. |
| **„Something went wrong. Please try again."** | Neočekivana greška | Pokušati ponovo. Ako se ponavlja, snimak ekrana i vrijeme poslati podršci. |
| Aplikacija se uopće ne učitava, ni na jednom uređaju | Mogući prekid ili održavanje | Provjeriti baner u aplikaciji odnosno e-mail, kontaktirati podršku (P1). U međuvremenu poklon kartice zabilježiti s brojem kartice, iznosom i vremenom i kasnije proknjižiti. |

## 7. Sigurnosna ograničenja (rate limits)

| Poruka | Uzrok | Rješenje |
|---|---|---|
| **„Too many failed card lookups. Please wait a moment and try again."** | Više od 10 neuspješnih ili sumnjivih provjera kartice u 5 minuta (zaštita od pogađanja brojeva) | Sačekati nekoliko minuta. Ako se neuspješne provjere gomilaju, razjasniti uzrok (pogrešne kartice, greške pri kucanju). |
| **„Too many redemptions on this card in a short period. Please contact a manager."** | Ograničenje protiv prevare: više iskorištavanja po kartici i satu nego što je dozvoljeno (standard 10) | Menadžer provjerava historiju kartice. Po potrebi vlasnik/vlasnica prilagođava **„Max. redemptions per card per hour"**. |
| **„Too many requests. Please slow down."** | Opće ograničenje broja zahtjeva | Kratko sačekati, zatim nastaviti. |

## 8. Uređaji

| Poruka / simptom | Uzrok | Rješenje |
|---|---|---|
| **„This device has been revoked. Please contact your manager."** (greška 403) | Uređaj je blokiran pod **Devices** (**„Revoke"**). | Ako je uređaj pronađen odnosno greškom blokiran: vlasnik/vlasnica → **Devices → „Restore"**. Inače koristiti drugi uređaj. |
| Uređaj se pojavljuje dvaput u **Devices** | Podaci preglednika obrisani ili korišten drugi preglednik → nova oznaka uređaja | Stari uređaj blokirati, novi smisleno preimenovati (ikona olovke, npr. „Bar iPhone"). |
| Konobar vidi samo način rada za konobare | Namjerno: uloga **„Waiter"** smije samo skenirati i iskorištavati. | Dodatna prava samo putem uloge **„Manager"**. |

## 9. E-mailovi

| Simptom | Uzrok | Rješenje |
|---|---|---|
| Gost ne dobija potvrdu kupovine ili dopune | **„Customer e-mails"** isključeno, kod kupca nema e-maila (anonimna kartica), greška pri kucanju ili neželjena pošta | Provjeriti postavku, provjeriti/ispraviti podatke pod **Customers**, zamoliti gosta da pogleda neželjenu poštu. |
| Gost ne dobija obavijest o isteku | Kartica bez datuma isteka (tada nema obavijesti) ili vidi gore | Podsjetnici se šalju 30 dana prije isteka u 10:00. |
| Nema e-maila o niskom stanju | Stanje nije ispod 5 € ili vidi gore | – |
| Pozivnica ne stiže | Neželjena pošta, pogrešna adresa, filter e-pošte firme | Provjeriti neželjenu poštu; adresu ispraviti pod **Team → ⋯ → „Edit"** i **„Resend invitation"**. |
| E-mail prikazuje pogrešne podatke o firmi | Podnožje e-maila odnosno predlošci nisu prilagođeni | **Settings → Gift cards → „E-mail footer"**, **Settings → E-mails** (predlošci DE i EN). |

## 10. Izvoz, kontrolna tabla, štampanje

| Simptom | Uzrok | Rješenje |
|---|---|---|
| CSV u Excelu: sve u jednoj koloni | Excel s engleskim regionalnim postavkama očekuje zarez umjesto tačke-zareza. | Excel → **Podaci → Iz teksta/CSV-a** → separator „tačka-zarez", kodiranje UTF-8. |
| CSV: iznosi kao datum ili tekst (npr. „12.50") | Restoran je podešen na engleski format brojeva. | **Settings → Restaurant → „Language & number format"** postaviti na **Deutsch (Österreich)** i ponovo izvesti. |
| Pogrešno prikazana slova s kvačicama/umlauti | Datoteka otvorena programom bez prepoznavanja UTF-8 | Uvesti putem **Podaci → Iz teksta/CSV-a** s UTF-8. |
| **„Outstanding balance"** ≠ **„Revenue this month"** | Različiti pokazatelji: otvoreno stanje svih kartica (obaveza) naspram prodaje + dopuna u tekućem mjesecu | Nije greška. Vidi bazu znanja „Izvoz za poreznog savjetnika". |
| **„Outstanding balance"** preko noći smanjen bez iskorištavanja | Kartice su istekle u 00:15; preostalo stanje je otpisano. | Filtrirati dnevnik transakcija po tipu „Expiration". Provjeriti postavku roka važenja. |
| Dnevne vrijednosti se ne slažu s kasom | Pogrešna vremenska zona ili prodaja nije proknjižena u oba sistema | **Settings → Restaurant → „Time zone"** = Europe/Vienna; uskladiti knjiženja u kasi. |
| Storno se pojavljuje kao dodatni red | Namjerno: storna su protuknjiženja, ništa se ne briše. | – |
| Odštampana kartica prevelika ili premala | Štampač skalira („Prilagodi stranici") | U dijalogu za štampu izabrati **skaliranje 100 %** odnosno „Stvarna veličina", zatim izrezati po ivicama. Rezultat: 85,6 × 54 mm. |
| Štampa bez boja/pozadine | Preglednik ne štampa pozadinsku grafiku | U dijalogu za štampu uključiti „Pozadinska grafika". |

---

Verzija 1.0 · Stanje: septembar 2026.
