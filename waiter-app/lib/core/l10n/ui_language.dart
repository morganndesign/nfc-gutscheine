/// The three UI languages of GiftCard Waiter (brief §7, 12 §1.2).
///
/// `bhs` covers Bosnian, Croatian and Serbian (ijekavian, Latin script); it is
/// served from `app_bs.arb` and its generated copies `app_hr.arb` and
/// `app_sr.arb` (09 §6.5).
enum UiLanguage {
  /// German (primary, de-AT).
  de,

  /// English (British spelling).
  en,

  /// Bosnian / Croatian / Serbian (ijekavian, Latin).
  bhs;

  /// Maps an ISO 639-1 language code to a UI language (09 §6.5 "Language
  /// selection"): `de*` → [de], `en*` → [en], `bs`/`hr`/`sr` → [bhs],
  /// anything else (including `null`) → [en].
  static UiLanguage fromLanguageCode(String? languageCode) {
    switch (languageCode?.toLowerCase()) {
      case 'de':
        return UiLanguage.de;
      case 'bs':
      case 'hr':
      case 'sr':
        return UiLanguage.bhs;
      case 'en':
      default:
        return UiLanguage.en;
    }
  }

  /// `Accept-Language` value sent to the API (09 §9.1): `de`, `en`, `bs`.
  String get apiCode => switch (this) {
        UiLanguage.de => 'de',
        UiLanguage.en => 'en',
        UiLanguage.bhs => 'bs',
      };
}
