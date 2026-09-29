# Sigurnost – česta pitanja

*Kratki, iskreni odgovori na pitanja koja nam vlasnici i vlasnice, porezni savjetnici i IT podrška postavljaju o sigurnosti GiftCard Pro.*

---

## Vaučeri

### 1. Šta se nalazi na vaučeru?

QR kod i naziv Vašeg restorana – ništa više. QR kod sadrži nasumičnu 256-bitnu tajnu (`GCPV1.` iza koje slijede 43 znaka). Nije link i ne sadrži ni stanje ni vrijednost, broj vaučera, ime ili e-mail adresu. Stanje i historija nalaze se isključivo na serveru, a server od tajne pohranjuje samo SHA-256 hash.

### 2. Može li neko kopirati ili pogoditi vaučer?

Pogoditi: praktično ne – 256 bita slučajnosti. Dodatno su neuspjela skeniranja ograničena na 10 u 5 minuta po restoranu, osobi i uređaju, a svaki neuspjeli pokušaj je u zapisniku aktivnosti.

Kopirati: ko ima fotografiju QR koda, ima vaučer – kao kod novčanice. Zato listove za štampu tretirajte kao gotovinu. Vaučer se može iskoristiti samo u Vašem restoranu, od strane prijavljene osobe na registrovanom uređaju; svako iskorištavanje je s osobom i uređajem u historiji. Interni broj vaučera nije dokaz ovlaštenja i ne može se koristiti za iskorištavanje.

### 3. Postoje li fizičke kartice s NFC-om?

Fizičke kartice predviđene su kao **NTAG 424 DNA** kartice sa živom autentifikacijom: aplikacija za konobare prosljeđuje komunikaciju čipa kripto servisu, koji drži ključeve kartica u hardverskom sigurnosnom modulu i dokazuje da je pravi čip prisutan u tom trenutku. Dok taj servis ne radi, GiftCard Pro ne čita, ne upisuje i ne programira NFC čipove, a aplikacija nema NFC dozvolu. Obične NFC naljepnice s linkom nikada nisu podržane, jer se mogu kopirati.

### 4. Šta se dešava ako gost izgubi vaučer?

Blokirate vaučer (**„Block“**). Od tog trenutka ne može se nigdje iskoristiti; ko pronađe list za štampu, ne može ništa s njim. Ako se pronađe, ukidate blokadu (**„Unblock“**).

### 5. Kako funkcioniše iskorištavanje – i zašto je sigurno?

1. Konobar skenira QR kod. Server ga provjerava i kreira **predočenje**: važi 60 sekundi, samo za jedno terećenje, vezano za Vaš restoran, taj vaučer, osobu i uređaj.
2. Konobar unosi iznos. Iskorištavanje troši predočenje; drugo iskorištavanje zahtijeva novo skeniranje.

Bez samog vaučera dakle niko ne može teretiti – ni brojem vaučera, ni snimkom ekrana starog skeniranja, ni prijavom druge osobe.

### 6. Može li konobar dvostruko teretiti vaučer, npr. dvostrukim dodirom?

Ne. Svako iskorištavanje nosi jedinstveni ključ idempotentnosti. Ako isti zahtjev stigne dva puta – zbog dvostrukog dodira ili zato što je mreža nakratko nestala – knjiži se samo jednom. Ako odgovor izostane, aplikacija tim ključem pita server je li knjiženo, umjesto da ponovo tereti.

### 7. Šta se dešava ako dva konobara istovremeno iskoriste isti vaučer?

Baza podataka zaključava vaučer za vrijeme svakog knjiženja, a iskorištavanja se obrađuju jedno za drugim. Stanje se time nikada ne može dvaput potrošiti niti pasti ispod nule. Automatizovani testovi to provjeravaju pri svakoj promjeni, i nad MySQL-om.

### 8. Može li se knjiženje naknadno izmijeniti ili obrisati?

Ne. Dnevnik knjiženja, plaćanja i zapisnik aktivnosti su nepromjenjivi: sama baza odbija izmjene i brisanja, a svaki zapis je hash lancem povezan s prethodnim. Svake noći GiftCard Pro ponovo izračunava sve lance i stanja i uzbunjuje kod najmanjeg odstupanja. Greške se ispravljaju stornom, koje ostaje vidljivo kao protuknjiženje. Stanje uvijek odgovara zbiru svih knjiženja.

### 9. Ističe li vaučer?

Samo ako postavite važenje (najmanje 36 mjeseci). Istekli vaučer zadržava stanje, a vlasnik ili vlasnica ga može ponovo aktivirati.

---

## Rad i dostupnost

### 10. Šta se dešava kod prekida interneta u restoranu?

Iskorištavanje zahtijeva vezu sa serverom – to je namjerno, jer samo server može sigurno spriječiti dvostruka knjiženja i provjeriti predočenje. Kod prekida WLAN-a aplikacija za konobare radi i preko mobilnih podataka telefona. Ako oboje otkaže, iskorištavanje nije moguće; ne može se ni naknadno proknjižiti bez vaučera. Gost u tom slučaju plaća na drugi način ili vaučer iskoristi pri sljedećoj posjeti.

### 11. Šta se dešava ako GiftCard Pro prestane raditi?

Težimo dostupnosti od 99,5 % mjesečno. Kod ispada obavještavamo Vas e-mailom. Naše ciljne vrijednosti za teške ispade: najviše 24 sata gubitka podataka (dnevna sigurnosna kopija) i oporavak u roku od 4 sata. Nedostajuća knjiženja mogu se utvrditi na osnovu računa iz Vaše fiskalne kase. Detalji u [Planu oporavka od katastrofe](disaster-recovery-plan.md).

### 12. Kako se podaci sigurnosno kopiraju?

Svake noći se pravi sigurnosna kopija baze podataka, uključujući zaštitne mehanizme finansijske historije. Kopije se čuvaju 14 dana na serveru i dodatno se kopiraju na zasebnu memoriju (Hetzner Storage Box). Osim toga Hetzner svakodnevno pravi snapshot cijelog servera. Nakon svakog vraćanja provjerava se netaknutost svih knjiženja.

### 13. Mogu li sam/a izvesti svoje podatke?

Da. Vaučere i transakcije u svakom trenutku izvozite kao CSV (**„Export CSV“**), s tačka-zarezom i decimalnim zarezom za Excel; transakcije s načinom plaćanja.

---

## Podaci i zaštita podataka

### 14. Gdje se nalaze podaci?

Kod Hetzner Online GmbH u data centrima u Njemačkoj, dakle u EU. Transakcijske e-mailove šalje pružalac usluge s hostingom u EU (`[E-Mail-Versanddienstleister mit EU-Hosting]`). Svi podizvršitelji obrade navedeni su u ugovoru o obradi podataka po nalogu.

### 15. Koje podatke o gostima sprema GiftCard Pro?

Samo ono što unesete – i to je neobavezno. Vaučer se može prodati potpuno anonimno. Ako unosite podatke o kupcima: ime, e-mail, telefon, bilješke, marketinška saglasnost i ime primaoca na vaučeru. E-mailovi gostima nikada ne sadrže stanje, iznos, broj vaučera niti link na vaučer.

### 16. Ko u GiftCard Pro može vidjeti moje podatke?

Administracija platforme GiftCard Pro upravlja restoranima (kreiranje, onemogućavanje, arhiviranje) i za to vidi pokazatelje kao što je broj vaučera – ali **ne** vidi vaučere, knjiženja, podatke kupaca ni članove tima Vašeg restorana. Pristup „u Vaš restoran“ ne postoji; aplikacija ga tehnički odbija. Podrška se odvija tako što nam pokažete ekran ili opišete korake. Drugi restorani nikada ne vide Vaše podatke. Pristup samom serveru ograničen je na nekoliko poimenično poznatih osoba.

### 17. Kako se sprječava da drugi restoran vidi moje podatke?

Svaki upit bazi podataka automatski se ograničava na Vaš restoran, a to odvajanje se dodatno provjerava na više nivoa. Identifikatori stranih zapisa ponašaju se kao nepostojeći; QR kod drugog restorana tretira se kao nepoznat. Automatizovani testovi to trajno osiguravaju.

### 18. Je li GiftCard Pro usklađen s GDPR-om?

GiftCard Pro je izgrađen prema principima GDPR-a: hosting u EU, minimizacija podataka, bez ličnih podataka u zapisniku aktivnosti, anonimizacija jednim klikom, bez kolačića za praćenje. Za podatke o gostima Vi ste kao restoran voditelj obrade, a GiftCard Pro je Vaš izvršitelj obrade; za to zaključujemo ugovor o obradi podataka po nalogu. Vaše obaveze informisanja prema gostima ostaju kod Vas.

### 19. Šta se dešava ako gost zatraži brisanje svojih podataka?

Pod Customers kod gosta odaberete anonimizaciju. Uklanjaju se svi lični podaci, i imena primalaca na njegovim vaučerima i njegova e-mail adresa u zapisniku slanja. Knjiženja ostaju sačuvana za knjigovodstvo (obaveza čuvanja prema austrijskom BAO).

### 20. Koristi li aplikacija kolačiće ili praćenje?

Samo tehnički neophodne kolačiće: kolačić sesije, zaštitni kolačić protiv CSRF napada i – samo ako odaberete „Keep me signed in“ – kolačić za trajnu prijavu. U memoriji preglednika nalazi se slučajni identifikator uređaja za vezivanje za uređaj. Bez analitike, bez reklama, bez kolačića trećih strana.

### 21. Šta se dešava s mojim podacima nakon kraja ugovora?

Prije toga možete izvesti sve podatke. 30 dana nakon kraja ugovora podaci se brišu, osim ako postoji zakonska obaveza čuvanja.

---

## Računi i pristup

### 22. Kako su zaštićeni računi mog tima?

Lozinke s najmanje 12 znakova (velika i mala slova, cifra); poznate procurile lozinke se odbijaju. Nakon 10 neuspjelih pokušaja račun se zaključava na 15 minuta – a da napadač iz odgovora ne može saznati postoji li adresa ili je li zaključana. Svaka sesija je vezana za uređaj na kojem je započeta. Promjena lozinke opoziva sve prijave osobe na drugim uređajima. Novi zaposleni sami postavljaju lozinku preko linka u pozivnici; lozinke se nikada ne šalju e-mailom.

### 23. Šta da radim ako je telefon ukraden?

Pod **Devices** odaberite uređaj i **„Revoke“** – od tog trenutka se odbija, čak i s otvorenom sesijom ili prijavljenom aplikacijom za konobare. Nakon toga po potrebi resetujte lozinku osobe.

### 24. Šta konobari mogu vidjeti i raditi?

Standardno samo iskorištavati vaučere QR skeniranjem. Ne vide ni kontrolnu tablu ni liste kupaca, knjiženja, izvoze, postavke ili tim. Prijava aplikacije za konobare tehnički dopire samo do nekoliko funkcija koje aplikacija treba. Kompletan pregled pronaći ćete u [Vodiču za kontrolu pristupa](access-control-guide.md).

### 25. Može li menadžer sam sebe učiniti vlasnikom?

Ne. Niko ne može promijeniti vlastitu ulogu. Menadžeri standardno ne mogu upravljati članovima tima; to smiju samo vlasnici i vlasnice. Restoran uvijek zadržava najmanje jednog aktivnog vlasnika ili vlasnicu.

### 26. Koliko je sigurno povezivanje s mojom kasom preko API-ja?

API tokeni imaju samo dozvole koje odaberete pri kreiranju (najviše one Vašeg vlastitog računa), ističu najkasnije nakon 365 dana i mogu se u svakom trenutku opozvati. Prikazuju se samo jednom, a kod nas se spremaju samo kao hash. Vrijeme i IP adresa posljednje upotrebe su vidljivi. I kasa za iskorištavanje mora skenirati QR kod vaučera.

### 27. Hoću li primijetiti ako neko pokuša nešto sumnjivo?

Da. U zapisniku aktivnosti nalaze se neuspjela skeniranja (kod koji nije važeći vaučer Vašeg restorana), zaključani računi, besplatni vaučeri i storna. Preporučujemo da ih pregledate jednom sedmično.

---

## Certifikacija i provjera

### 28. Je li GiftCard Pro certificiran?

Ne. GiftCard Pro nema certifikat prema ISO 27001 ili SOC 2. PCI DSS nije relevantan jer GiftCard Pro ne obrađuje podatke platnih kartica i ne obrađuje plaćanja – plaća se na Vašoj vlastitoj kasi; GiftCard Pro samo bilježi način plaćanja. Umjesto toga naše zaštitne mjere opisujemo otvoreno i provjerljivo u našoj [Bijeloj knjizi o sigurnosti](security-whitepaper.md).

### 29. Je li GiftCard Pro testirao vanjski pružalac usluga u pogledu sigurnosti?

Do sada nije. Kod je interno temeljito provjeren, a nalazi tih provjera su otklonjeni. Za svako pravilo koje nešto zabranjuje postoji automatizovani test zloupotrebe koji pokušava zabranjeni put (iskorištavanje bez predočenja, tuđe predočenje, isteklo predočenje, pristupi stranim restoranima, proširenje prava, manipulacija finansijske historije, besplatna prodaja bez dozvole); ti testovi se pokreću pri svakoj promjeni.

### 30. Je li GiftCard Pro fiskalna kasa?

Ne. GiftCard Pro ne izdaje račune i nije certificiran prema RKSV. Prodaju i iskorištavanje vaučera knjižite u svojoj fiskalnoj kasi prema uputama svog poreznog savjetnika.

---

## Prijave

### 31. Kako da prijavim sigurnosni propust?

E-mailom na **security@giftcardpro.at** s što tačnijim opisom (šta, gdje, kako se može ponoviti). Prijem potvrđujemo u roku od 2 radna dana. Molimo objavite detalje tek nakon otklanjanja, ne testirajte s podacima drugih restorana i ne ometajte rad.

### 32. Pita li GiftCard Pro ikada za moju lozinku?

Nikada – ni e-mailom, ni telefonom, ni u chatu. Ako neko u ime GiftCard Pro traži Vašu lozinku, radi se o pokušaju prevare. Molimo proslijedite takve poruke na security@giftcardpro.at.

---

Verzija 2.0 · Stanje: septembar 2026.
