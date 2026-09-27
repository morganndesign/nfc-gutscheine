# Predložak: changelog i verzionisanje

*Kako dokumentujemo tehničke promjene u GiftCard Pro i dodjeljujemo brojeve verzija. Zasnovano na „Keep a Changelog" i „Semantic Versioning", prilagođeno našoj praksi. Za razvoj, operativu i proizvod.*

---

## 1. Osnovna pravila

- **Changelog za ljude, ne za mašine.** Nije zapisnik commitova, nego čitljiva lista promjena relevantnih za operativu, integracije ili restorane.
- **Svaka promjena kaže šta i zašto.** „Zašto" je obavezno — tako su to radile dosadašnje verzije 1.1.0 i 1.2.0, i to zadržavamo.
- **Najnovija verzija na vrhu.** Odjeljak **[Unreleased]** prikuplja promjene do sljedeće verzije.
- **Datum u ISO formatu** (GGGG-MM-DD), kako bi bio međunarodno jednoznačan.
- **Jezik:** tehnički `CHANGELOG.md` u repozitoriju vodi se kao i do sada na engleskom. Korisnici iz njega dobijaju [bilješke o izdanju](release-notes-template.md) na njemačkom (i BHS).
- **Provjera je dio verzije.** Svaka verzija navodi kako je provjerena: testovi, test prihvatanja, pristupačnost, izmjerene vrijednosti.

---

## 2. Kategorije

Unutar verzije unosi se grupišu ovim redoslijedom. Prazne kategorije se izostavljaju.

| Kategorija (u changelogu) | Na BHS | Upotreba |
|---|---|---|
| **Added** | Dodano | Nove funkcije, endpointi, postavke |
| **Changed** | Promijenjeno | Promijenjeno ponašanje, tekstovi, zadane vrijednosti, interfejsi |
| **Fixed** | Ispravljeno | Ispravke grešaka |
| **Security** | Sigurnost | Otklonjene ranjivosti, ojačanja. Uvijek zasebna kategorija, nikad skrivena pod „Fixed" |
| **Deprecated** | Zastarjelo | Funkcije ili API polja koja će u budućoj verziji biti uklonjena — s ciljnim datumom i alternativom |
| **Removed** | Uklonjeno | Uklonjene funkcije ili API polja |

**Dopuna za GiftCard Pro:** kod većih verzija kategorije se smiju dodatno podijeliti po područjima proizvoda (npr. *Waiter app*, *Owner dashboard*, *Card management*), kao u verziji 1.2.0. Svaki unos tada ostaje dodijeljen jednoj kategoriji (oznaka na početku reda, vidi primjer).

Dodatno na kraju svake verzije, ako je primjenjivo:

- **Upgrade notes** — migracije, nove varijable okruženja, koraci za operativu.
- **Verification** — broj testova, test prihvatanja, izmjerene vrijednosti.

---

## 3. Verzionisanje (Semantic Versioning)

Format: **MAJOR.MINOR.PATCH**, npr. `1.2.0`.

| Pozicija | Povećava se kada … | Primjeri |
|---|---|---|
| **MAJOR** | … promjena može pokvariti postojeće integracije: uklonjena ili preimenovana API polja, promijenjeno ponašanje endpointa, promjena linka kartice | `/api/v1` → `/api/v2`; uklanjanje zastarjelog polja |
| **MINOR** | … dolaze nove funkcije ili vidljive promjene koje su kompatibilne unazad | Interfejs na njemačkom; novi pokazatelj; novo opcionalno API polje |
| **PATCH** | … se samo ispravljaju greške ili poboljšavaju sitnice, bez novog ponašanja | Pogrešno zaokruživanje u izvozu; greška u rasporedu na malim telefonima |

**Dodatna pravila:**

1. **Linkovi kartica su nepovredivi.** Format `https://<domain>/c/<UUID>` na već prodanim karticama nikad se ne kvari. Promjena koja bi učinila štampane ili upisane kartice nevažećim je isključena — bez obzira na broj verzije.
2. **Logika knjiženja.** Svaka promjena knjiženja, izračuna stanja ili dnevnika vodi se najmanje kao MINOR i opisuje u changelogu pod *Changed* s obrazloženjem, čak i ako je tehnički samo ispravka.
3. **Zadane vrijednosti.** Promijenjene tvorničke postavke (npr. zadani rok važenja) su MINOR i moraju pojasniti da li se odnose na postojeće restorane.
4. **Prvo zastarjelo, pa uklonjeno.** API polje označava se kao *Deprecated* najmanje jednu MINOR verziju i 90 dana prije nego što se ukloni u MAJOR verziji.
5. **Predverzije** nose dodatak: `1.3.0-beta.1`, `1.3.0-rc.1`. Idu samo testnim ili pilot-restoranima.
6. **Tagovi** u repozitoriju zovu se `v1.2.0`.

---

## 4. Pravila pisanja

1. **Jedan unos = jedna promjena.** Počinje rezultatom podebljano, zatim slijedi zašto.
2. **Pisati iz ugla učinka.** „Expiry dates follow the restaurant's timezone", a ne „Refactored date handling".
3. **Konkretno.** Navesti vrijednosti, granice, ekrane, endpointe: „`card-scan` limit is now 90/min per user per terminal".
4. **„Zašto" opisuje problem prije promjene**, a ne tehniku: „A card in Austria expired 1–2 hours early."
5. **Bez internih imena osoba, bez imena korisnika**, bez brojeva tiketa bez konteksta.
6. **Sigurnost:** ranjivosti opisati tek nakon otklanjanja i isporuke. Opisati šta se sprečava, a ne kako se zloupotrebljava.
7. **Izmjerene vrijednosti s metodom:** „Measured in E2E: card lookup 92 ms".
8. **Linkovi** na dokumentaciju relativno u odnosu na repozitorij: `[User guide](docs/USER_GUIDE.md)`.
9. **Bez marketinga.** Bez pridjeva kao što su „great", „amazing", „seamless".

---

## 5. Predložak

```markdown
# Changelog

All notable changes to GiftCard Pro are documented in this file.
The format is based on Keep a Changelog, and this project adheres to Semantic Versioning.

## [Unreleased]

### Added
- **<Result in bold>.** <Why: the problem before.>

### Changed
### Fixed
### Security
### Deprecated
### Removed

## [1.3.0] - YYYY-MM-DD — <short title>

<One paragraph: what this release is about and what it deliberately does not include.>

### Added
| Change | Why |
|---|---|
| **<Result>** | <Problem before / reason> |

### Changed
| Change | Why |
|---|---|

### Fixed
| Change | Why |
|---|---|

### Security
| Change | Why |
|---|---|

### Upgrade notes
- <Migration, env variable, config step — or "None.">

### Verification
- **Tests:** <n> PHPUnit tests (<n> assertions), green on <databases>.
- **Acceptance test:** <journey>, <measured values>.
- **Accessibility:** axe (WCAG 2.1 AA): <result>.

[Unreleased]: <compare link>
[1.3.0]: <compare link>
```

Dozvoljene su i tabele (Change | Why) i nabrajanja. Unutar jedne verzije ostati dosljedan.

---

## 6. Primjeri unosa

Sljedeći unosi pokazuju stil. Unosi iz 1.1.0 i 1.2.0 preuzeti su iz postojećeg changeloga i razvrstani po kategorijama. Unosi pod **[Unreleased]** su **izmišljeni primjeri** radi ilustracije, a ne najava; nazivi polja u njima su izmišljeni.

```markdown
## [Unreleased]

### Added
- **German staff interface (de-AT).** Dashboard and waiter app follow the user's language setting.
  Why: staff in Austria had to work in an English interface.

### Changed
- **New restaurants start with default validity 0 (no expiry) instead of 36 months.**
  Existing restaurants keep their current setting.
  Why: in Austria, limiting paid vouchers to 3 years or less in general terms is usually invalid.

### Deprecated
- **`example_field` in the card resource.** Use `new_example_field` instead. Removal planned for API v2,
  not before YYYY-MM-DD.

## [1.2.0] - YYYY-MM-DD — Pilot release

### Added
| Change | Why |
|---|---|
| **New API field `outstanding_cards`.** | This is the number behind the liability wording on the dashboard. |
| **Welcome panel for a new restaurant** (card rules → team → first card → waiter mode). Disappears after the first sale. | An empty dashboard gave a new owner no idea where to start. |

### Changed
| Change | Why |
|---|---|
| **Transaction type "Issued" became "Sale"**, in the UI and in exports. | It reads like the other types and matches how owners talk. |
| **Daily sales vs. redemptions is a bar chart** instead of a smoothed line. | The smoothed line suggested sales on days with none. |

### Fixed
| Change | Why |
|---|---|
| **The Redeem button fits on an iPhone SE with the browser bar visible.** | It was pushed below the fold on small phones. |
| **Android phones get Android instructions.** | They showed the iPhone hint before. |

## [1.1.0] - YYYY-MM-DD — Hardening release

### Security
| Change | Why |
|---|---|
| **A session is pinned to the device it signed in on.** | A copied session cookie could otherwise be used from any device, which made revoking a phone useless. |
| **The failed-login counter is incremented atomically.** | Parallel wrong-password requests could overwrite each other and never reach the lockout threshold. |

### Fixed
| Change | Why |
|---|---|
| **Expiry dates follow the restaurant's timezone.** | A card in Austria expired 1–2 hours early, while the restaurant was still open. |
```

---

## 7. Tok rada po verziji

1. Tokom razvoja: unosi pod **[Unreleased]** u istom pull requestu kao i promjena.
2. Prije objavljivanja: odrediti broj verzije prema odjeljku 3, preimenovati **[Unreleased]** u novu verziju, upisati datum, dodati provjeru.
3. Postaviti tag `vX.Y.Z`, isporučiti.
4. Iz changeloga izvesti bilješke o izdanju za korisnike ([predložak](release-notes-template.md)).
5. Kod unosa *Deprecated* ili *Security* koji se tiču integracija: korisnike API-ja (paketi Pro i Gruppe) dodatno obavijestiti e-mailom.

---

Verzija 1.0 · Stanje: septembar 2026.
