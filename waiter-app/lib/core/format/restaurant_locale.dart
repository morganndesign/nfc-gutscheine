/// Restaurant locale from `/auth/me` (brief "Restaurant settings": de-AT,
/// de-DE, de-CH, en-GB, en-US). It decides number, currency and time formats
/// for German and English UI (12 §1.4, §1.5; 09 §6.5).
enum RestaurantLocale {
  /// Austria — `€ 24,90`.
  deAT('de-AT'),

  /// Germany — `24,90 €`.
  deDE('de-DE'),

  /// Switzerland — `€ 24.90`, thousands `’`.
  deCH('de-CH'),

  /// United Kingdom — `€24.90`, 24-hour clock.
  enGB('en-GB'),

  /// United States — `€24.90`, 12-hour clock ("6:30 pm").
  enUS('en-US');

  const RestaurantLocale(this.tag);

  /// BCP 47 tag as delivered by the API.
  final String tag;

  /// Parses a BCP 47 tag (`de-AT`, `de_AT`, any case).
  ///
  /// A tag outside the brief's list falls back by language — `de*` → [deAT]
  /// (the primary market, 12 §1.2), `en*` → [enGB] (12 §1.2: British
  /// English) — and anything else to [deAT].
  static RestaurantLocale parse(String tag) {
    final String normalised = tag.trim().replaceAll('_', '-').toLowerCase();
    for (final RestaurantLocale locale in values) {
      if (locale.tag.toLowerCase() == normalised) {
        return locale;
      }
    }
    if (normalised.startsWith('en')) {
      return RestaurantLocale.enGB;
    }
    return RestaurantLocale.deAT;
  }
}
