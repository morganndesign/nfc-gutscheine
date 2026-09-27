# Sigurnost – česta pitanja

*Kratki, iskreni odgovori na pitanja koja nam vlasnici i vlasnice, porezni savjetnici i IT podrška postavljaju o sigurnosti GiftCard Pro.*

---

## Kartice

### 1. Šta je spremljeno na kartici?

Samo link: `https://app.giftcardpro.at/c/` iza kojeg slijedi slučajni identifikator (UUID v4). Bez stanja, bez imena, bez e-mail adrese. Isti link se nalazi kao QR kod na poleđini. Stanje i historija nalaze se isključivo na serveru.

### 2. Može li neko kopirati karticu?

Link na jednostavnoj NFC kartici može se očitati i upisati na drugi čip. Zato GiftCard Pro dodatno provjerava:

- **Standardne kartice (NTAG213/215/216):** Kartica je vezana za tvornički upisan serijski broj čipa. Kopija na drugom čipu se pri skeniranju Androidom odbija i u zapisniku aktivnosti označava kao sigurnosno upozorenje. Ta provjera ne djeluje kod iPhonea, QR koda i ručnog unosa broja, a postoje i specijalni čipovi s promjenjivim serijskim brojem.
- **NTAG 424 DNA kartice:** Čip pri svakom prislanjanju generiše novi kriptografski potpis s brojačem. Kopije i ponovo korišteni linkovi se odbijaju – na Androidu i iPhoneu.

Za visoke vrijednosti kartica preporučujemo NTAG 424 DNA.

### 3. Može li neko pogoditi broj kartice ili link?

Praktično ne. Identifikator u linku sadrži 122 bita slučajnosti, 16-cifreni broj kartice je slučajan (ne ide redom). Dodatno su neuspjeli upiti ograničeni na 10 u 5 minuta po korisniku i po IP adresi, a svaki pokušaj se bilježi.

### 4. Šta se dešava ako gost izgubi karticu?

Blokirate karticu ili odaberete **„Replace lost card"**. Stanje prelazi na novu karticu s novim identifikatorom; stara kartica od tog trenutka nigdje više ne radi. Ko pronađe staru karticu, ne može s njom ništa učiniti.

### 5. Može li neko prepisati čip na kartici?

Ako je u postavkama aktivno „Lock tags after writing", čip se nakon upisa trajno zaključava za pisanje. NTAG 424 DNA kartice se pri programiranju štite vlastitim ključevima. Čak i prepisani čip mogao bi samo pokazivati na drugi link – stanje se time ne može promijeniti.

### 6. Može li konobar dvostruko teretiti karticu, npr. dvostrukim dodirom?

Ne. Svako iskorištavanje nosi jedinstven ključ idempotentnosti. Ako isti zahtjev stigne dvaput – zbog dvostrukog dodira ili zato što je mreža kratko nestala – knjiži se samo jednom.

### 7. Šta se dešava ako dva konobara istovremeno iskoriste istu karticu?

Baza podataka zaključava karticu za vrijeme svakog knjiženja, iskorištavanja se obrađuju jedno za drugim. Stanje se zbog toga nikada ne može potrošiti dvaput niti pasti ispod nule. To smo interno testirali s 20 istovremenih iskorištavanja jedne kartice.

### 8. Može li se knjiženje naknadno izmijeniti ili obrisati?

Ne. Dnevnik knjiženja je nepromjenjiv. Greške se ispravljaju stornom koje ostaje vidljivo kao protuknjiženje. Stanje uvijek odgovara zbiru svih knjiženja.

---

## Rad i dostupnost

### 9. Šta se dešava kod prekida interneta u restoranu?

Iskorištavanje zahtijeva vezu sa serverom – to je namjerno, jer samo server može pouzdano spriječiti dvostruka knjiženja. Kod prekida WLAN-a aplikacija za konobare radi i preko mobilnih podataka telefona. Ako oboje ne radi, zabilježite broj kartice i iznos i iskorištavanje naknadno proknjižite čim se veza vrati; kod visokih iznosa ili nepoznatih gostiju preporučujemo da iskorištavanje odgodite.

### 10. Šta se dešava ako GiftCard Pro prestane raditi?

Težimo dostupnosti od 99,5 % mjesečno. Kod ispada obavještavamo Vas e-mailom. Naše ciljne vrijednosti za teške ispade: najviše 24 sata gubitka podataka (dnevna sigurnosna kopija) i oporavak u roku od 4 sata. Nedostajuća knjiženja mogu se naknadno unijeti na osnovu računa iz Vaše fiskalne kase. Detalji u [Planu oporavka od katastrofe](disaster-recovery-plan.md).

### 11. Kako se podaci sigurnosno kopiraju?

Svake noći se pravi sigurnosna kopija baze podataka. Kopije se čuvaju 14 dana na serveru i dodatno se kopiraju na zasebnu memoriju (Hetzner Storage Box). Osim toga Hetzner svakodnevno pravi snapshot cijelog servera.

### 12. Mogu li sam/a izvesti svoje podatke?

Da. Kartice i transakcije u svakom trenutku izvozite kao CSV (**„Export CSV"**), s tačka-zarezom i decimalnim zarezom za Excel.

---

## Podaci i zaštita podataka

### 13. Gdje se nalaze podaci?

Kod Hetzner Online GmbH u data centrima u Njemačkoj, dakle u EU. Transakcijske e-mailove šalje pružalac usluge s hostingom u EU (`[E-Mail-Versanddienstleister mit EU-Hosting]`). Svi podizvršitelji obrade navedeni su u ugovoru o obradi podataka po nalogu.

### 14. Koje podatke o gostima sprema GiftCard Pro?

Samo ono što unesete – i to je neobavezno. Kartica se može prodati potpuno anonimno. Ako unosite podatke o kupcima: ime, e-mail, telefon, bilješke, marketinška saglasnost i ime primaoca na kartici.

### 15. Ko u GiftCard Pro može vidjeti moje podatke?

Samo administracija platforme GiftCard Pro, i to isključivo preko funkcije „Open restaurant". Pri tome je jasno vidljiv baner, a svaka radnja se bilježi u zapisniku aktivnosti s osobom koja djeluje. Taj pristup koristimo samo za postavljanje i podršku ili na Vaš zahtjev. Drugi restorani nikada ne vide Vaše podatke.

### 16. Kako se sprječava da drugi restoran vidi moje podatke?

Svaki upit bazi podataka automatski se ograničava na Vaš restoran, a to odvajanje se dodatno provjerava na više nivoa. Identifikatori stranih zapisa ponašaju se kao nepostojeći. Automatizovani testovi to trajno osiguravaju.

### 17. Je li GiftCard Pro usklađen s GDPR-om?

GiftCard Pro je izgrađen prema principima GDPR-a: hosting u EU, minimizacija podataka, bez ličnih podataka u zapisniku aktivnosti, anonimizacija jednim klikom, bez kolačića za praćenje. Za podatke o gostima Vi ste kao restoran voditelj obrade, a GiftCard Pro je Vaš izvršitelj obrade; za to zaključujemo ugovor o obradi podataka po nalogu. Vaše obaveze informisanja prema gostima ostaju kod Vas.

### 18. Šta se dešava ako gost zatraži brisanje svojih podataka?

Pod Customers kod gosta odaberete anonimizaciju. Uklanjaju se svi lični podaci, i imena primalaca na njegovim karticama i njegova e-mail adresa u zapisniku slanja. Knjiženja ostaju sačuvana za knjigovodstvo (obaveza čuvanja prema austrijskom BAO).

### 19. Koristi li aplikacija kolačiće ili praćenje?

Samo tehnički neophodne kolačiće: kolačić sesije i zaštitni kolačić protiv CSRF napada. U memoriji preglednika nalazi se slučajni identifikator uređaja za vezivanje za uređaj. Bez analitike, bez reklama, bez kolačića trećih strana.

### 20. Šta se dešava s mojim podacima nakon kraja ugovora?

Prije toga možete izvesti sve podatke. 30 dana nakon kraja ugovora podaci se brišu, osim ako postoji zakonska obaveza čuvanja.

---

## Računi i pristup

### 21. Kako su zaštićeni računi mog tima?

Lozinke s najmanje 12 znakova (velika i mala slova, cifra); poznate procurile lozinke se odbijaju. Nakon 10 neuspjelih pokušaja račun se zaključava na 15 minuta. Svaka sesija je vezana za uređaj na kojem je započeta. Novi zaposleni sami postavljaju lozinku preko linka u pozivnici; lozinke se nikada ne šalju e-mailom.

### 22. Šta da radim ako je telefon ukraden?

Pod **Devices** odaberite uređaj i **„Revoke"** – od tog trenutka se odbija, čak i s otvorenom sesijom. Nakon toga po potrebi resetujte lozinku osobe.

### 23. Šta konobari mogu vidjeti i raditi?

Standardno samo skenirati i iskoristiti kartice. Ne vide ni kontrolnu tablu ni liste kupaca, izvoze, postavke ili tim. Kompletan pregled pronaći ćete u [Vodiču za kontrolu pristupa](access-control-guide.md).

### 24. Može li menadžer sam sebe učiniti vlasnikom?

Ne. Niko ne može promijeniti vlastitu ulogu. Menadžeri standardno ne mogu upravljati članovima tima; to smiju samo vlasnici i vlasnice. Restoran uvijek zadržava najmanje jednog aktivnog vlasnika ili vlasnicu.

### 25. Koliko je sigurno povezivanje s mojom kasom preko API-ja?

API tokeni imaju samo dozvole koje odaberete pri kreiranju (najviše one Vašeg vlastitog računa), ističu najkasnije nakon 365 dana i mogu se u svakom trenutku opozvati. Prikazuju se samo jednom, a kod nas se spremaju samo kao hash. Vrijeme i IP adresa posljednje upotrebe su vidljivi.

### 26. Hoću li primijetiti ako neko pokuša nešto sumnjivo?

Da. U zapisniku aktivnosti sigurnosna upozorenja su označena crvenom bojom: odbijena kopirana kartica, ponovljeni NFC dodir, kartica stranog restorana, zaključan račun. Preporučujemo da ih pregledate jednom sedmično.

---

## Certifikacija i provjera

### 27. Je li GiftCard Pro certificiran?

Ne. GiftCard Pro trenutno nema certifikat prema ISO 27001 ili SOC 2. PCI DSS nije relevantan jer GiftCard Pro ne obrađuje podatke platnih kartica i ne obrađuje plaćanja – plaća se na Vašoj vlastitoj kasi. Umjesto toga naše zaštitne mjere opisujemo otvoreno i provjerljivo u našoj [Bijeloj knjizi o sigurnosti](security-whitepaper.md).

### 28. Je li GiftCard Pro testirao vanjski pružalac usluga u pogledu sigurnosti?

Do sada nije. Kod je interno temeljito provjeren, uključujući interno provedene testove napada i opterećenja (istovremena iskorištavanja, brute force, lažni identifikatori, pristupi stranim restoranima, ubacivanje koda). Ti slučajevi su trajno osigurani kao automatizovani testovi: 113 backend testova pokreće se pri svakoj promjeni.

### 29. Je li GiftCard Pro fiskalna kasa?

Ne. GiftCard Pro ne izdaje račune i nije certificiran prema RKSV. Prodaju i iskorištavanje poklon kartica knjižite u svojoj fiskalnoj kasi prema uputama svog poreznog savjetnika.

---

## Prijave

### 30. Kako da prijavim sigurnosni propust?

E-mailom na **security@giftcardpro.at** s što tačnijim opisom (šta, gdje, kako se može ponoviti). Prijem potvrđujemo u roku od 2 radna dana. Molimo objavite detalje tek nakon otklanjanja, ne testirajte s podacima drugih restorana i ne ometajte rad.

### 31. Pita li GiftCard Pro ikada za moju lozinku?

Nikada – ni e-mailom, ni telefonom, ni u chatu. Ako neko u ime GiftCard Pro traži Vašu lozinku, radi se o pokušaju prevare. Molimo proslijedite takve poruke na security@giftcardpro.at.

---

Verzija 1.0 · Stanje: septembar 2026.
