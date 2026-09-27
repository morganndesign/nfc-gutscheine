# Česta pitanja o GiftCard Pro

*Odgovori na pitanja koja vlasnici, menadžeri i porezni savjetnici najčešće postavljaju. Iskreno, i kada nešto (još) ne radi.*

---

## Općenito

**1. Šta je GiftCard Pro?**
Sistem poklon kartica za ugostiteljstvo. Prodajete kvalitetne poklon kartice s NFC čipom i QR kodom, Vaši konobari ih za stolom iskorištavaju telefonom za nekoliko sekundi, a Vi u svakom trenutku vidite koliko je novca od poklon bonova još otvoreno.

**2. Za koje objekte je GiftCard Pro prikladan?**
Za restorane, gostionice, kafane, barove, vinske kuće i hotelske restorane — od pojedinačnog objekta do grupe s više lokacija. Jedini preduslov je da želite prodavati poklon bonove i da Vaš tim koristi pametni telefon.

**3. Treba li mi dodatni hardver?**
Ne, osim samih kartica. Aplikacija za konobare radi na postojećim pametnim telefonima, a kontrolna tabla u svakom pregledniku. Android telefon s NFC-om je praktičan za upis čipova i očitavanje kartica jednim dodirom.

**4. Koliko brzo mogu početi?**
Postavljanje obično traje jedno popodne: odrediti pravila kartica, pozvati tim, kreirati prvu karticu, otvoriti način za konobare. Područje **Welcome** na kontrolnoj tabli vodi Vas kroz ove korake. Za štampane kartice dodatno računajte vrijeme štampe i isporuke.

**5. Da li je interfejs na mom jeziku?**
Još ne. Interfejs za osoblje (kontrolna tabla i aplikacija za konobare) je trenutno na engleskom. Sve što vide gosti — štampana kartica, stranica stanja, e-mailovi — postoji na njemačkom i engleskom. Interfejs za osoblje na njemačkom planiran je za Q4 2026 i ima najviši prioritet; bosanski/hrvatski/srpski planiran je za 2028. Aplikacija za konobare radi s malo velikih dugmadi, a naša uputstva objašnjavaju svaki naziv.

**6. Postoji li GiftCard Pro kao aplikacija u App Storeu?**
Još ne. Nativna aplikacija „GiftCard Waiter" za Android i iPhone je razvijena, ali još nije objavljena u App Storeu ni na Google Playu. Služi isključivo za skeniranje i iskorištavanje. Do objave koristite, kao i do sada, aplikaciju za konobare kao web aplikaciju koju stavljate na početni ekran. Ponaša se kao aplikacija, ne treba instalaciju preko prodavnice i uvijek je ažurna.

---

## Kartice i NFC

**7. Šta je pohranjeno na kartici?**
Samo link oblika `https://<domain>/c/<slučajna oznaka>`. Bez stanja, bez imena, bez broja kartice u čipu. Sve ostalo nalazi se na serveru.

**8. Koje kartice mogu koristiti?**
NFC kartice s čipom NTAG213, NTAG215 (preporučeno) ili NTAG216, a u paketu Pro i NTAG 424 DNA. Osim toga, kartice samo s QR kodom, bez čipa, koje sami štampate pomoću predloška.

**9. Gdje mogu nabaviti kartice i koliko koštaju?**
Isporučujemo štampane kartice u Vašem dizajnu, obostrano u punoj boji. Okvirne cijene: početni set od 100 NFC kartica (NTAG215) 249 €, 250 kartica 499 €, NTAG 424 DNA 4–6 € po kartici. Okvirne cijene zavise od količine i štampe — obavezujuća ponuda na upit. Možete koristiti i vlastite standardne NFC kartice.

**10. Kako link dospijeva na čip?**
Android telefonom i Chromeom dodirnete **Write NFC tag** i prinesete karticu telefonu — gotovo. Bez Androida kopirate prikazanu adresu u aplikaciju za upis NFC-a (npr. NFC Tools), upišete čip i kliknete **Mark as written**.

**11. Mogu li kartice koristiti i bez NFC-a?**
Da. Svaka kartica ima QR kod i 16-cifreni broj kartice. Kartice samo s QR kodom besplatno sami štampate u formatu bankovne kartice.

**12. Koji telefoni mogu očitati kartice?**
Android telefoni s NFC-om i Chromeom očitavaju karticu direktno u aplikaciji za konobare. iPhonei od modela XS očitavaju karticu kada se prinese gornjem rubu; obavještenje otvara karticu. Svaki telefon s kamerom može skenirati QR kod. Broj kartice može se unijeti na svakom uređaju.

**13. Može li se kartica kopirati?**
Link neko može kopirati — ali on ne sadrži novac. Kod NTAG21x kartica veže se serijski broj čipa: kopija na drugom čipu odbija se pri skeniranju Androidom i prijavljuje u zapisniku aktivnosti. Kod očitavanja iPhoneom, QR kodom ili brojem ne prenosi se serijski broj. Za kartice visoke vrijednosti zato preporučujemo NTAG 424 DNA (Pro): ovi čipovi pri svakom prinošenju stvaraju kriptografski potpis, a kopije i ponavljanja se odbijaju.

**14. Šta ako gost izgubi karticu?**
Ako je kartica dodijeljena kupcu ili gost zna broj kartice, zamijenite je pomoću **⋯ → Replace lost card**. Stanje prelazi na novu karticu, a stara odmah prestaje raditi. Kod anonimno prodanih kartica bez broja to nije moguće — kao i kod gotovine.

**15. Mogu li sam osmisliti dizajn kartice?**
Da. Štampane kartice proizvode se u Vašem dizajnu. U paketu Pro pomažemo pri dizajnu kartice. Predložak za QR kartice prikazuje naziv restorana, vrijednost i primaoca poklona na prednjoj strani, a QR kod, broj i rok važenja na zadnjoj.

![Predložak za štampu](../../screenshots/print-card.png)

---

## Iskorištavanje

**16. Kako izgleda iskorištavanje za stolom?**
Prinijeti ili skenirati karticu, unijeti iznos na tastaturi (`2 4 9 0` → 24,90 €) ili izabrati **Full balance**, zatim pritisnuti **Redeem 24,90 €**. Ekran potvrde prikazuje preostalo stanje za gosta. Cilj: manje od pet sekundi, uključujući čovjeka.

**17. Može li gost iskoristiti bon u više dijelova?**
Da, djelimično iskorištavanje je moguće. Možete ga isključiti u postavkama; tada se uvijek iskorištava cijelo stanje.

**18. Šta ako je račun veći od stanja?**
Aplikacija prikazuje napomenu. Konobar iskoristi cijelo stanje, a ostatak naplati gotovinom ili karticom.

**19. Šta ako nestane interneta?**
Bez veze se ništa ne knjiži, i aplikacija to prikazuje. Čim se veza vrati, konobar ponovo pritisne dugme. Knjiženje se nikad ne izvršava dvaput, ni pri ponavljanju.

**20. Mogu li dva konobara istovremeno iskoristiti istu karticu?**
Mogu pokušati, ali stanje se nikad ne prekoračuje. Svako knjiženje nakratko zaključava karticu u bazi. To smo testirali s 20 istovremenih iskorištavanja na jednoj kartici.

**21. Konobar je iskoristio pogrešan iznos. Šta uraditi?**
Pod **Transactions** ili u historiji kartice stornirajte knjiženje pomoću **Reverse** i izaberite razlog (Wrong amount, Wrong card, Guest cancelled). Ispravka se upisuje kao protuknjiženje; ništa se ne briše.

**22. Mogu li dopunjavati kartice?**
Da, pomoću **Reload** na stranici kartice. Dopuna se može isključiti u postavkama.

**23. Šta konobar vidi kod blokirane ili zamijenjene kartice?**
Crveno upozorenje i veliko dugme **Next card**. Kod zamijenjene kartice dodatno piše „Ask the guest for the new card". Neaktivne i prazne kartice prikazuju žuto upozorenje, a istekle kartice vlastitu poruku.

---

## Gosti

**24. Kako gost provjerava stanje?**
Prinese karticu svom telefonu ili skenira QR kod. Otvara se stranica na jeziku Vašeg restorana sa stanjem, statusom, rokom važenja i maskiranim brojem kartice. Ovu stranicu možete isključiti u postavkama.

**25. Dobijaju li gosti e-mailove?**
Samo ako unesete e-mail adresu i funkcija je uključena: pri kupovini, pri dopuni, 30 dana prije isteka i kod stanja ispod 5 €. Predloške na njemačkom i engleskom možete uređivati.

**26. Moram li bilježiti podatke kupca?**
Ne. Kartice se mogu prodavati anonimno. S kontakt podacima, međutim, lakše zamjenjujete izgubljenu karticu i šaljete potvrde.

**27. Može li gost pohraniti karticu u Apple Wallet ili Google Wallet?**
Još ne. Wallet kartice planirane su za Q2 2027.

---

## Sigurnost i prevare

**28. Kako se sprečava pogađanje brojeva kartica?**
Brojevi kartica su slučajni i nisu redoslijedni, a linkovi sadrže slučajnu 122-bitnu oznaku. Neuspjele pretrage kartica se usporavaju, a nakon previše neuspjelih pokušaja slijedi blokada.

**29. Šta ako se izgubi službeni telefon?**
Pod **Devices** kliknite **Revoke**. Telefon od tog trenutka više ne može skenirati ni iskorištavati kartice. Sesije su vezane za uređaj; kopirana sesija ne radi ni na jednom drugom uređaju.

**30. Vidim li ko je napravio koje knjiženje?**
Da. Svako knjiženje stoji u historiji s osobom, vremenom, uređajem i stanjem nakon toga. **Audit log** dodatno prikazuje sve sigurnosno relevantne radnje s IP adresom; upozorenja kao što je kopirana kartica označena su crveno. Zato svaka osoba treba imati vlastiti pristup.

**31. Postoji li granica za prevare?**
Da. Zadano je moguće najviše 10 iskorištavanja po kartici i satu. Dodatno možete odrediti maksimalno pojedinačno iskorištavanje i maksimalno stanje kartice.

**32. Da li je GiftCard Pro certificiran (ISO 27001, SOC 2, PCI DSS)?**
Ne. Nemamo takve certifikate i to ne tvrdimo. PCI DSS se odnosi na platne kartice; poklon kartice to nisu. Provedene sigurnosne mjere otvoreno opisujemo u našoj sigurnosnoj dokumentaciji.

---

## Zaštita podataka

**33. Gdje se čuvaju podaci?**
Kod Hetzner Online GmbH u podatkovnim centrima u Njemačkoj (EU). Sigurnosne kopije baze prave se svake noći i čuvaju 14 dana lokalno i dodatno na drugoj lokaciji.

**34. Ko je odgovoran u smislu zaštite podataka?**
Za podatke Vaših gostiju Vaš restoran je voditelj obrade, a mi smo izvršitelj obrade prema čl. 28 GDPR-a. Za to zaključujemo ugovor o obradi podataka po nalogu. Za podatke Vašeg korisničkog računa kod nas odgovorni smo sami.

**35. Koristi li aplikacija kolačiće?**
Samo tehnički neophodne: kolačić sesije i kolačić za zaštitu od lažnih zahtjeva (CSRF). Uz to slučajna oznaka uređaja u memoriji preglednika za vezivanje uređaja. Bez analitičkih, oglasnih ili kolačića trećih strana.

**36. Gost traži brisanje svojih podataka. Šta uraditi?**
Otvorite kupca i izaberite anonimizaciju. Ime, e-mail i telefon se uklanjaju, a knjiženja ostaju sačuvana zbog obaveze čuvanja.

---

## Pravo i porezi

> **Nije pravni savjet.** Sljedeći odgovori su opće napomene za Austriju (ugovor podliježe austrijskom pravu). Svoj slučaj razjasnite s poreznim savjetnikom ili advokatom.

**37. Koliko dugo poklon bon mora važiti?**
Plaćeni poklon bonovi bez ograničenja važe 30 godina (§ 1478 ABGB). Prema sudskoj praksi austrijskog Vrhovnog suda (OGH), ograničenje na tri godine ili manje u općim uslovima poslovanja u pravilu je grubo nepovoljno i ništavo (§ 879 st. 3 ABGB). Zato preporučujemo da zadani rok važenja (**Default validity**) pri postavljanju postavite na **0** (bez isteka) — tvornička postavka je trenutno 36 mjeseci. Od Q4 2026 „neograničeno" postaje tvornička postavka za nove restorane. Izvor: WKO „Gutscheine – Befristung".

**38. Šta ako kartica ipak istekne?**
GiftCard Pro preostalo stanje knjiži kao istek. Gost ipak može imati pravni zahtjev. Stanje možete ponovo učiniti dostupnim zamjenskom karticom ili prenosom.

**39. Kada nastaje PDV?**
Od 2019. razlikuju se jednonamjenski i višenamjenski vaučeri. Restoranski poklon bonovi na određeni iznos koji se mogu iskoristiti za hranu (10 %) i pića (20 %) u Austriji su u pravilu višenamjenski vaučeri: PDV nastaje pri iskorištavanju, a ne pri prodaji. Izvor: WKO „Umsatzsteuerliche Behandlung von Gutscheinen".

**40. Zamjenjuje li GiftCard Pro moju fiskalnu kasu?**
Ne. GiftCard Pro nije fiskalna kasa, nije certificiran prema austrijskom RKSV-u i ne izdaje račune. Prodaju i iskorištavanje knjižite u svojoj fiskalnoj kasi prema uputama poreznog savjetnika.

**41. Šta mi pokazuje otvorena obaveza?**
Pokazatelj **Outstanding balance** je zbir svih stanja koja gosti još mogu iskoristiti. Za obveznike dvojnog knjigovodstva to je obaveza; kod jednostavnog knjigovodstva (Einnahmen-Ausgaben-Rechnung) prodaja se u pravilu evidentira već pri prilivu. Koji tretman važi za Vas, razjašnjava porezni savjetnik.

**42. Koliko dugo se čuvaju knjiženja?**
Knjiženja se nikad ne brišu. Time možete ispuniti obavezu čuvanja od 7 godina (§ 132 BAO). Nakon isteka ugovora imate 30 dana za izvoz; nakon toga se podaci brišu, osim ako postoji zakonska obaveza čuvanja.

---

## Cijene i ugovor

**43. Koliko košta GiftCard Pro?**
Start 29 € mjesečno (290 € godišnje), Pro 59 € mjesečno (590 € godišnje), Gruppe od 129 € mjesečno za do tri lokacije plus 39 € po svakoj dodatnoj lokaciji. Sve cijene su neto, uz dodatak 20 % PDV-a (Austrija). Uz godišnje plaćanje dva mjeseca su besplatna.

**44. Naplaćujete li proviziju?**
Ne. 0 % provizije na prodaju i iskorištavanje kartica — danas i kod planirane online prodaje.

**45. Postoji li naknada za postavljanje?**
Ne, ako sami postavljate sistem. Opcionalno postavljamo sistem na licu mjesta i obučavamo Vaš tim, jednokratno 149 € (za pilot-restorane besplatno).

**46. Mogu li testirati GiftCard Pro?**
Da, 30 dana besplatno, bez kreditne kartice, sa svim Pro funkcijama.

**47. Šta je pilot-program?**
Za prvih 10 restorana u Beču (oktobar–novembar 2026.): 3 mjeseca besplatno, zatim 12 mjeseci 50 % popusta (Start 14,50 €, Pro 29,50 €), besplatno postavljanje na licu mjesta i 50 kartica besplatno. Zauzvrat Vas molimo za redovne razgovore o iskustvima i — nakon Vašeg odobrenja — dozvolu da Vas navedemo kao referencu.

**48. Kako mogu otkazati?**
Mjesečni paketi mogu se otkazati do kraja mjeseca, godišnji do kraja ugovornog perioda. GiftCard Pro namijenjen je isključivo preduzećima.

**49. Kako se vrši obračun?**
Trenutno mjesečnim ili godišnjim računom, plaćanjem SEPA direktnim zaduženjem ili bankovnom doznakom. Od Q4 2026 obračun se vrši automatski preko Stripea.

**50. Mogu li prodavati poklon bonove online?**
Još ne. Danas kartice prodajete u restoranu i naplaćujete na vlastitoj fiskalnoj kasi. Online prodaja preko Vaše web stranice — s online plaćanjem, PDF bonom i po želji karticom poštom — planirana je za Q1 2027. Ni tada ne naplaćujemo proviziju; plaćaju se samo naknade pružaoca platnih usluga.

---

## Tehnika

**51. Mogu li GiftCard Pro povezati sa svojom kasom?**
U paketu Pro postoji API s ograničenim API ključevima (važe do 365 dana, mogu se opozvati u svakom trenutku). Pomoću njega dobavljač kase ili pružalac usluga može pretraživati i iskorištavati kartice. Gotove integracije s ready2order, orderbird i SumUp POS su u provjeri (Q1 2027).

**52. Mogu li upravljati s više lokacija?**
Da, svaka lokacija je trenutno zaseban račun restorana. Zajednička kontrolna tabla za grupe planirana je za Q2 2027.

**53. Kolika je dostupnost usluge?**
Naš cilj je dostupnost od 99,5 % mjesečno. U paketu Start to je cilj, a ne garancija; u paketu Gruppe može se ugovoriti SLA.

**54. Koje valute su podržane?**
Trenutno samo euro. Švicarski franak, konvertibilna marka i srpski dinar planirani su za 2028. Hrvatska već koristi euro.

**55. Kako otvoriti izvoze u Excelu?**
Kliknite **Export CSV** pod **Gift cards** ili **Transactions**. Datoteka koristi tačku-zarez i decimalni zarez i otvara se direktno u njemačkoj verziji Excela. Kod drugih jezičkih postavki Excela možda će biti potreban uvoz s odabirom separatora.

---

## Podrška

**56. Kako mogu kontaktirati podršku?**
E-mailom na support@giftcardpro.at. U paketu Start odgovaramo u roku od jednog radnog dana, a u paketu Pro dodatno telefonom i s prioritetom (u roku od 4 radna sata). U paketu Gruppe postoji centralna kontakt osoba.

**57. Na kojim jezicima je dostupna podrška?**
Na njemačkom i engleskom; odgovaramo i na upite na bosanskom, hrvatskom ili srpskom.

**58. Da li mi neko pomaže pri postavljanju?**
U paketu Start postoji video postavljanje. U paketu Pro sistem postavljamo lično s Vama — na daljinu ili na licu mjesta u Beču. Postavljanje na licu mjesta s obukom tima možete dodati u svakom paketu za jednokratnih 149 €.

**59. Kako mogu prijaviti sigurnosni propust?**
E-mailom na security@giftcardpro.at, s kratkim opisom kako se problem može reproducirati. Molimo Vas da detalje objavite tek kada problem otklonimo.

---

Verzija 1.0 · Stanje: septembar 2026.
