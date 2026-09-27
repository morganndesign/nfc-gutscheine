# Biblioteka koristi

*Svrha: Centralna zbirka svih obećanja o koristima GiftCard Pro, po personi razložena kao korist → funkcija → dokaz, plus 20 kratkih rečenica o koristima za ponovnu upotrebu na sajtu, u prodaji, oglasima i na društvenim mrežama.*

**Pravilo:** Svaka korist mora biti pokrivena postojećom funkcijom i potkrijepljena dokazom iz proizvoda ili glavnog brifa. Ono što ovdje ne piše, ne obećavamo.

---

## 1. Vlasnica / vlasnik

*Odlučuje, 35–60 godina, razmišlja o novcu, obavezama i ugledu lokala. Nema vremena.*

| Korist | Funkcija | Dokaz |
|---|---|---|
| U svakom trenutku znate koliko još dugujete gostima. | KPI „Outstanding balance“ (otvoreni iznos na N kartica) na kontrolnoj tabli | Zbir iz nepromjenjivog dnevnika; zbir transakcija = stanje, uvijek |
| Svaki prodani euro ostaje Vama. | Fiksna mjesečna pretplata, bez udjela u prometu | 0 % provizije u svim paketima; mnogi ponuđači uzimaju 3,9–4,9 % (izvor: medienkraft.at, poređenje sistema za poklon bonove) |
| Troškovi koje možete planirati. | Tri paketa s fiksnom cijenom, otkaz svaki mjesec | Start 29 €, Pro 59 €, Gruppe od 129 € – neto, plus 20 % PDV-a |
| Poklon bon koji Vaš lokal predstavlja u najboljem svjetlu. | Odštampane NFC kartice veličine bankovne kartice u Vašem dizajnu | ISO ID-1, obostrano u punoj boji; početni set 100 kartica okvirno 249 € |
| Manje prevara, manje gubitaka. | Nema stanja na kartici, vezivanje za čip, NTAG 424 DNA, blokiranje, zamjenske kartice | Nasumičan link od 122 bita; kopije se odbijaju; stara kartica odmah nevažeća pri zamjeni |
| Bez promjena na kasi. | Nezavisno od fiskalne kase; API u paketu Pro | Prodaja i naplata knjiže se u kasi kao i do sada |
| Sezona poklona bez dodatnog posla u sali. | Kartica izdata za nekoliko minuta, naplata bez obuke | Izdavanje u jednom formularu; naplata oko 0,5 s sistemskog vremena |
| Vaši podaci pripadaju Vama. | CSV izvoz u svakom trenutku, brisanje podataka 30 dana nakon isteka ugovora | Ugovorna obaveza (uslovi poslovanja) |

**Ključna poruka:** „Vidite svaki otvoreni euro – i zadržavate svaki prodani.“

---

## 2. Menadžer

*Vodi lokal, tim i svakodnevnu kontrolu. Tim, uređaje i postavke vodi vlasnik / vlasnica; menadžer radi s karticama, transakcijama, kupcima i zapisnikom.*

| Korist | Funkcija | Dokaz |
|---|---|---|
| Greške se ispravljaju bez brisanja tragova. | Storno kao protivknjiženje | Ništa se ne briše; dnevnik ostaje potpun |
| Svaka transakcija ima ime. | Historija kartice s vremenom, osobom, uređajem, stanjem nakon toga | Svaka radnja u zapisniku aktivnosti s osobom, vremenom, IP adresom |
| Novi radnici spremni za nekoliko minuta. | Pozivnica e-mailom, vlastita lozinka, uloge (šalje vlasnik / vlasnica) | Link za poziv važi 72 h; konobari vide samo skeniranje i naplatu |
| Izgubljen telefon nije sigurnosni problem. | Upravljanje uređajima s „Revoke“ (pravo vlasnika; menadžer vidi listu uređaja) | Blokirani uređaji odmah gube pristup |
| Izgubljena kartica? Zadovoljan gost za minutu. | „Replace lost card“ | Stanje prelazi na novu karticu, stara odmah nevažeća |
| Pravila postavljena jednom, sistem ih se drži. | Pravila za kartice (postavlja vlasnik): min./max. iznos, max. naplata, djelimična naplata, dopuna, limit po satu | Standard: 5–1.000 € po kartici, max. 2.000 € stanja, 10 naplata/sat |

**Ključna poruka:** „Jasna pravila, jasni tragovi, bez dodatnih pitanja.“

---

## 3. Konobar / konobarica

*Ne treba mu obuka, ruke su mu pune, ne želi pogriješiti.*

| Korist | Funkcija | Dokaz |
|---|---|---|
| Naplata bez razmišljanja. | Tastatura kao na kasi, „Full balance“, veliko dugme „Redeem“ | 2 4 9 0 → 24,90 € |
| Bez čekanja za stolom. | NFC očitavanje na dodir (Android), iPhone preko gornjeg ruba ili QR koda | Pronalaženje kartice oko 0,1 s; cijela naplata oko 0,5 s sistemskog vremena |
| Bez straha od dvostruke naplate. | Idempotentne transakcije | Dvostruki pritisak ili prekid mreže nikad ne knjiži dvaput |
| Odmah znate o čemu se radi. | Jasne poruke: blokirana, zamijenjena, istekla, bez stanja | Zamijenjena: „pitajte gosta za novu karticu“ |
| Radi na vlastitom ili službenom telefonu. | Web aplikacija koja se može dodati na početni ekran | Bez App Storea; radi i na iPhone SE bez skrolanja |

**Ključna poruka:** „Prislonite, upišite, gotovo.“

**Iskrena napomena:** Aplikacija je trenutno na engleskom (njemački od 4. kvartala 2026). Konobarski prikaz koristi malo riječi, i to jednoznačnih.

---

## 4. Gost koji poklanja

*Traži poklon koji ostavlja utisak i djeluje lično.*

| Korist | Funkcija | Dokaz |
|---|---|---|
| Poklon koji se s ponosom predaje. | Odštampana kartica u dizajnu restorana | Prednja strana: lokal, iznos, ime osobe kojoj je poklon namijenjen |
| Lično, a ne anonimno. | Ime primaoca na kartici | Polje „Recipient name“ pri izdavanju |
| Potvrda da je sve u redu. | E-mail gostu pri kupovini (opciono) | Šablon „kartica kupljena“, DE/EN |

**Ključna poruka:** „Poklonite večer, a ne papirić.“

---

## 5. Gost koji dobija poklon

*Želi iskoristiti bez komplikacija i znati koliko mu je ostalo.*

| Korist | Funkcija | Dokaz |
|---|---|---|
| Naplata bez rasprave. | Konobarska aplikacija očita karticu za nekoliko sekundi | Preostalo stanje se odmah prikazuje |
| Stanje provjerava sam, bilo kada. | Javna stranica sa stanjem preko telefona (može se isključiti) | Stanje, status, rok važenja, maskiran broj; DE/EN |
| Uživanje u više navrata. | Djelimična naplata (podesivo) | Preostalo stanje ostaje na kartici |
| Izgubljeno ne znači nestalo. | Zamjenska kartica s prenosom stanja | Stara kartica odmah blokirana |
| Podsjetnik na vrijeme. | E-mail 30 dana prije isteka i kod niskog stanja (ispod 5 €) – ako je e-mail upisan | Šabloni u proizvodu |

**Ključna poruka:** „Prislonite i uživajte.“

---

## 6. Porezni savjetnik / knjigovođa

*Treba uredne, potpune i provjerljive podatke.*

| Korist | Funkcija | Dokaz |
|---|---|---|
| Podaci koji bez dorade idu u Excel. | CSV izvoz s tačkom-zarezom i decimalnim zarezom | Austrijski format brojeva |
| Potpuna, nepromjenjiva evidencija. | Dnevnik u koji se samo dodaje, storno kao protivknjiženje | Ništa se ne briše; podržava čuvanje prema § 132 BAO |
| Jasna obaveza na dan presjeka. | KPI „Outstanding balance“ | Otvoreni iznosi po kartici provjerljivi |
| Pravilno raspoređen PDV. | Transakcije po vrsti (prodaja, dopuna, naplata) | Bon za više namjena (Mehrzweckgutschein): PDV pri iskorištavanju |

**Ključna poruka:** „Svaka transakcija dokumentovana, svaki izvoz odmah čitljiv.“

**Obavezna napomena pri upotrebi:** GiftCard Pro nije fiskalna kasa i ne izdaje fiskalne račune. Nije porezni savjet.

---

## 7. 20 rečenica o koristima za ponovnu upotrebu

Kratko, potkrijepljeno, bez pretjerivanja. Najviše 60 znakova, da stanu u oglase i kratke formate.

1. Poklon kartice jednostavne kao plaćanje karticom.
2. Prislonite. Naplatite. Gotovo.
3. 0 % provizije. Danas i ubuduće.
4. Svaki euro evidentiran.
5. Vidite šta je još otvoreno.
6. Na kartici nema novca. Samo siguran link.
7. Nikad naplaćeno dvaput.
8. Kopirane kartice se prepoznaju.
9. Radi na svakom telefonu. Bez App Storea.
10. Naplata bez obuke.
11. Poklon koji nešto znači.
12. Kartice u Vašem dizajnu.
13. Izgubljena? Stanje na novu karticu i gotovo.
14. Storno kao protivknjiženje. Ništa se ne briše.
15. Izvoz direktno za Excel.
16. Hosting u EU.
17. Neograničeno članova tima i uređaja.
18. Od 29 € mjesečno, otkaz svaki mjesec.
19. 30 dana besplatno, bez kreditne kartice.
20. Razvijeno u Beču, za ugostiteljstvo.

**Upotreba:** rečenice 1–2 kao slogan, 3–8 za vlasnike, 9–10 za osoblje, 11–13 za komunikaciju s gostima, 14–16 za knjigovođe i povjerenje, 17–20 kao red s ponudom.

---

## 8. Šta ne obećavamo

- Nikakve tvrdnje o rastu prometa u procentima – za to još nema podataka.
- Nikakve „izjave klijenata“ prije pisanog odobrenja iz pilot programa.
- Nema „online prodavnice“, „integracije s kasom“ (samo API) ni „certifikata“.
- Ne „garantovano za 5 sekundi“, nego: izmjereno oko 0,5 s sistemskog vremena, cilj ispod 5 s za stolom.

---

Verzija 1.0 · Stanje: septembar 2026.
