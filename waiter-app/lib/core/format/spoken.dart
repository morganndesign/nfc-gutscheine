import '../l10n/ui_language.dart';

/// Spoken forms for VoiceOver / TalkBack (12 §1.4 "Spoken amounts", 12 §1.10,
/// 07 §5.2). Spoken text follows the **UI language**, never the restaurant
/// locale (07 §9.1); formatted strings are never handed to the TTS parser.
abstract final class Spoken {
  /// Spoken amount (`a11y.spokenAmount`, 12 §1.4 / §5.20) for the value
  /// inserted into `{spokenAmount}`, `{amount}`/`{balance}` of a11y strings.
  ///
  /// | UI  | 24,90         | 1,00      | 21,00      | 0,50       |
  /// |-----|---------------|-----------|------------|------------|
  /// | DE  | 24 Euro 90    | 1 Euro    | 21 Euro    | 50 Cent    |
  /// | EN  | 24 euros 90   | 1 euro    | 21 euros   | 50 cents   |
  /// | BHS | 24 eura 90    | 1 euro    | 21 euro    | 50 centi   |
  ///
  /// Cents are omitted when 0; when the euro part is 0 the cents-only form
  /// is used. Euro digits are not grouped ("1250 euros", 07 §5.2). Cents are
  /// spoken as a number ("24 Euro 5" for 24,05). Zero is "0 Euro" /
  /// "0 euros" / "0 eura" (05 §2.2: empty AmountDisplay reads "0 euro").
  ///
  /// The cents word takes the grammatical plural of the language (07 §5.2:
  /// "amounts use the grammatical plural"): EN "1 cent", BHS "1 cent",
  /// "2 centa", "5 centi"; German "Cent" is invariable.
  ///
  /// Only EUR is specified in v1 (12 §1.4); another [currency] throws
  /// [UnsupportedError].
  static String amount(
    int cents, {
    required UiLanguage language,
    String currency = 'EUR',
  }) {
    if (currency.trim().toUpperCase() != 'EUR') {
      throw UnsupportedError(
        'Spoken amounts are specified for EUR only '
        '(12 §1.4); got "$currency"',
      );
    }
    if (cents < 0) {
      throw ArgumentError.value(cents, 'cents', 'must not be negative');
    }
    final int euros = cents ~/ 100;
    final int rest = cents % 100;
    if (euros == 0 && rest > 0) {
      return '$rest ${_centWord(rest, language)}';
    }
    final String euroPart = '$euros ${_euroWord(euros, language)}';
    return rest == 0 ? euroPart : '$euroPart $rest';
  }

  static String _euroWord(int n, UiLanguage language) {
    switch (language) {
      case UiLanguage.de:
        return 'Euro';
      case UiLanguage.en:
        return n == 1 ? 'euro' : 'euros';
      case UiLanguage.bhs:
        return bhsPluralCategory(n) == BhsPlural.one ? 'euro' : 'eura';
    }
  }

  static String _centWord(int n, UiLanguage language) {
    switch (language) {
      case UiLanguage.de:
        return 'Cent';
      case UiLanguage.en:
        return n == 1 ? 'cent' : 'cents';
      case UiLanguage.bhs:
        switch (bhsPluralCategory(n)) {
          case BhsPlural.one:
            return 'cent';
          case BhsPlural.few:
            return 'centa';
          case BhsPlural.other:
            return 'centi';
        }
    }
  }

  /// Characters separated by spaces so screen readers read them one by one:
  /// `6488` → `6 4 8 8` (12 §1.10 card ending), `7F3A9C` → `7 F 3 A 9 C`
  /// (12 §2.5 support code).
  static String characters(String text) =>
      text.runes.map(String.fromCharCode).join(' ');

  /// A (possibly partial) card number read in groups of four with a pause
  /// between groups (07 §5.2, 05 §2.5): `5285105870` →
  /// `5 2 8 5, 1 0 5 8, 7 0`. Non-digits are ignored.
  static String cardNumber(String digits) {
    final String clean = digits.replaceAll(RegExp('[^0-9]'), '');
    final List<String> groups = <String>[];
    for (int i = 0; i < clean.length; i += 4) {
      final int end = i + 4 < clean.length ? i + 4 : clean.length;
      groups.add(characters(clean.substring(i, end)));
    }
    return groups.join(', ');
  }
}

/// CLDR plural categories of Bosnian / Croatian / Serbian for integers
/// (12 §1.9).
enum BhsPlural {
  /// n mod 10 = 1 and n mod 100 ≠ 11.
  one,

  /// n mod 10 = 2–4 and n mod 100 ∉ 12–14.
  few,

  /// Everything else.
  other,
}

/// Plural category of the integer [n] in BHS (12 §1.9).
BhsPlural bhsPluralCategory(int n) {
  final int abs = n.abs();
  final int mod10 = abs % 10;
  final int mod100 = abs % 100;
  if (mod10 == 1 && mod100 != 11) {
    return BhsPlural.one;
  }
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return BhsPlural.few;
  }
  return BhsPlural.other;
}
