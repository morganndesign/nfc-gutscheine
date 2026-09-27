# Vorlage: Changelog und Versionierung

*Wie wir technische Änderungen an GiftCard Pro dokumentieren und Versionsnummern vergeben. Angelehnt an „Keep a Changelog" und „Semantic Versioning", angepasst an unsere Praxis. Für Entwicklung, Betrieb und Produkt.*

---

## 1. Grundsätze

- **Ein Changelog für Menschen, nicht für Maschinen.** Kein Commit-Protokoll, sondern eine lesbare Liste der Änderungen, die für Betrieb, Integrationen oder Restaurants relevant sind.
- **Jede Änderung sagt, was und warum.** Das „Warum" ist Pflicht — so haben es die bisherigen Versionen 1.1.0 und 1.2.0 gehalten, und das behalten wir bei.
- **Neueste Version oben.** Ein Abschnitt **[Unreleased]** sammelt Änderungen bis zur nächsten Version.
- **Datum im ISO-Format** (JJJJ-MM-TT), damit es international eindeutig ist.
- **Sprache:** Das technische `CHANGELOG.md` im Repository wird wie bisher auf Englisch geführt. Kundinnen und Kunden erhalten daraus deutschsprachige [Release Notes](release-notes-template.md) (und BHS).
- **Verifikation gehört dazu.** Jede Version nennt, wie sie geprüft wurde: Tests, Abnahmetest, Barrierefreiheit, Messwerte.

---

## 2. Kategorien

Innerhalb einer Version werden Einträge in dieser Reihenfolge gruppiert. Leere Kategorien entfallen.

| Kategorie (im Changelog) | Deutsch | Verwendung |
|---|---|---|
| **Added** | Hinzugefügt | Neue Funktionen, Endpunkte, Einstellungen |
| **Changed** | Geändert | Geändertes Verhalten, geänderte Texte, Standardwerte, Oberflächen |
| **Fixed** | Behoben | Fehlerbehebungen |
| **Security** | Sicherheit | Behobene Schwachstellen, Härtungen. Immer eigene Kategorie, nie unter „Fixed" verstecken |
| **Deprecated** | Veraltet | Funktionen oder API-Felder, die in einer künftigen Version entfallen — mit Zieldatum und Alternative |
| **Removed** | Entfernt | Entfernte Funktionen oder API-Felder |

**Ergänzung für GiftCard Pro:** Bei größeren Versionen dürfen die Kategorien nach Produktbereich untergliedert werden (z. B. *Waiter app*, *Owner dashboard*, *Card management*), wie in Version 1.2.0. Jeder Eintrag bleibt dann einer Kategorie zugeordnet (Markierung am Zeilenanfang, siehe Beispiel).

Zusätzlich am Ende jeder Version, wenn zutreffend:

- **Upgrade notes** — Migrationen, neue Umgebungsvariablen, Schritte für den Betrieb.
- **Verification** — Anzahl Tests, Abnahmetest, Messwerte.

---

## 3. Versionierung (Semantic Versioning)

Format: **MAJOR.MINOR.PATCH**, z. B. `1.2.0`.

| Stelle | Wird erhöht, wenn … | Beispiele |
|---|---|---|
| **MAJOR** | … eine Änderung bestehende Integrationen brechen kann: API-Felder entfernt oder umbenannt, geändertes Verhalten eines Endpunkts, Änderung des Kartenlinks | `/api/v1` → `/api/v2`; Entfernung eines veralteten Feldes |
| **MINOR** | … neue Funktionen oder sichtbare Änderungen hinzukommen, die abwärtskompatibel sind | Deutsche Oberfläche; neue Kennzahl; neues optionales API-Feld |
| **PATCH** | … nur Fehler behoben oder Kleinigkeiten verbessert werden, ohne neues Verhalten | Falsche Rundung im Export; Layoutfehler auf kleinen Handys |

**Zusatzregeln:**

1. **Kartenlinks sind heilig.** Das Format `https://<domain>/c/<UUID>` auf bereits verkauften Karten wird nie gebrochen. Eine Änderung, die gedruckte oder beschriebene Karten ungültig machen würde, ist ausgeschlossen — unabhängig von der Versionsnummer.
2. **Buchungslogik.** Jede Änderung an Buchungen, Guthabenberechnung oder Journal wird mindestens als MINOR geführt und im Changelog unter *Changed* mit Begründung beschrieben, auch wenn sie technisch nur ein Fix ist.
3. **Standardwerte.** Geänderte Werkseinstellungen (z. B. Standard-Gültigkeit) sind MINOR und müssen klarstellen, ob bestehende Restaurants betroffen sind.
4. **Veraltet vor entfernt.** Ein API-Feld wird mindestens eine MINOR-Version und 90 Tage vorher als *Deprecated* markiert, bevor es in einer MAJOR-Version entfernt wird.
5. **Vorabversionen** tragen einen Zusatz: `1.3.0-beta.1`, `1.3.0-rc.1`. Sie gehen nur an Test- oder Pilotbetriebe.
6. **Tags** im Repository heißen `v1.2.0`.

---

## 4. Schreibregeln

1. **Ein Eintrag = eine Änderung.** Beginnt mit dem Ergebnis in Fettschrift, danach das Warum.
2. **Aus Sicht der Wirkung schreiben.** „Expiry dates follow the restaurant's timezone", nicht „Refactored date handling".
3. **Konkret.** Werte, Grenzen, Bildschirme, Endpunkte nennen: „`card-scan` limit is now 90/min per user per terminal".
4. **Das Warum beschreibt das Problem vorher**, nicht die Technik: „A card in Austria expired 1–2 hours early."
5. **Keine internen Namen von Personen, keine Kundennamen**, keine Ticketnummern ohne Kontext.
6. **Sicherheit:** Schwachstellen erst nach Behebung und Auslieferung beschreiben. Beschreiben, was verhindert wird, nicht wie man es ausnutzt.
7. **Messwerte mit Methode:** „Measured in E2E: card lookup 92 ms".
8. **Links** auf Dokumentation relativ zum Repository: `[User guide](docs/USER_GUIDE.md)`.
9. **Kein Marketing.** Keine Adjektive wie „great", „amazing", „seamless".

---

## 5. Vorlage

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

Tabellen (Change | Why) oder Aufzählungen sind beide zulässig. Innerhalb einer Version einheitlich bleiben.

---

## 6. Beispieleinträge

Die folgenden Einträge zeigen den Stil. Einträge aus 1.1.0 und 1.2.0 sind dem bestehenden Changelog entnommen und den Kategorien zugeordnet. Einträge unter **[Unreleased]** sind **fiktive Beispiele** zur Veranschaulichung, keine Ankündigung; Feldnamen darin sind erfunden.

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

## 7. Ablauf pro Version

1. Während der Entwicklung: Einträge unter **[Unreleased]** im selben Pull Request wie die Änderung.
2. Vor der Veröffentlichung: Versionsnummer nach Abschnitt 3 festlegen, **[Unreleased]** in die neue Version umbenennen, Datum setzen, Verifikation ergänzen.
3. Tag `vX.Y.Z` setzen, ausliefern.
4. Release Notes für Kundinnen und Kunden aus dem Changelog ableiten ([Vorlage](release-notes-template.md)).
5. Bei *Deprecated*- oder *Security*-Einträgen, die Integrationen betreffen: API-Kundinnen und -Kunden (Tarif Pro und Gruppe) zusätzlich per E-Mail informieren.

---

Version 1.0 · Stand: September 2026
