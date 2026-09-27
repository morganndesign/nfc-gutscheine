import 'package:flutter/foundation.dart' show immutable;

import '../l10n/ui_language.dart';
import 'restaurant_locale.dart';

/// No-break space U+00A0 between symbol and number (12 §1.4).
const String noBreakSpace = '\u00A0';

/// Number pattern of one money style in 12 §1.4.
@immutable
class _MoneyStyle {
  const _MoneyStyle({
    required this.decimal,
    required this.group,
    required this.symbolLeading,
    required this.spaced,
  });

  final String decimal;
  final String group;
  final bool symbolLeading;
  final bool spaced;
}

const _MoneyStyle _deAT = _MoneyStyle(
  decimal: ',',
  group: '.',
  symbolLeading: true,
  spaced: true,
);
const _MoneyStyle _deDE = _MoneyStyle(
  decimal: ',',
  group: '.',
  symbolLeading: false,
  spaced: true,
);
const _MoneyStyle _deCH = _MoneyStyle(
  decimal: '.',
  group: '’',
  symbolLeading: true,
  spaced: true,
);
const _MoneyStyle _en = _MoneyStyle(
  decimal: '.',
  group: ',',
  symbolLeading: true,
  spaced: false,
);
const _MoneyStyle _bhs = _MoneyStyle(
  decimal: ',',
  group: '.',
  symbolLeading: false,
  spaced: true,
);

/// A formatted amount split into its visual parts, for components that set
/// the symbol separately (AmountDisplay, BalanceCard: symbol at 60 % size
/// with an optical gap instead of the space character, 04 §3.4).
@immutable
class MoneyParts {
  /// Creates the parts; normally obtained from [MoneyFormat.parts].
  const MoneyParts({
    required this.symbol,
    required this.number,
    required this.symbolLeading,
    required this.spaced,
  });

  /// Currency symbol (`€`) or ISO code (`CHF`).
  final String symbol;

  /// Grouped number with two decimals, e.g. `1.234,50`.
  final String number;

  /// Whether the symbol precedes the number.
  final bool symbolLeading;

  /// Whether symbol and number are separated by a no-break space
  /// ("spaced" locales, 04 §3.4) or joined ("tight").
  final bool spaced;

  /// The complete string, e.g. `€ 24,90` (no-break space).
  String get text {
    final String gap = spaced ? noBreakSpace : '';
    return symbolLeading ? '$symbol$gap$number' : '$number$gap$symbol';
  }

  @override
  String toString() => text;

  @override
  bool operator ==(Object other) =>
      other is MoneyParts &&
      other.symbol == symbol &&
      other.number == number &&
      other.symbolLeading == symbolLeading &&
      other.spaced == spaced;

  @override
  int get hashCode => Object.hash(symbol, number, symbolLeading, spaced);
}

/// Money formatting per 12 §1.4 (restaurant locale for DE/EN UI, BHS pattern
/// for BHS UI; 09 §6.5 "Number/date locale").
///
/// | UI  | Restaurant | 24,90     | 1.234,50    |
/// |-----|------------|-----------|-------------|
/// | DE  | de-AT      | € 24,90   | € 1.234,50  |
/// | DE  | de-DE      | 24,90 €   | 1.234,50 €  |
/// | DE  | de-CH      | € 24.90   | € 1’234.50  |
/// | EN  | de-AT      | € 24,90   | € 1.234,50  |
/// | EN  | en-GB/US   | €24.90    | €1,234.50   |
/// | BHS | any        | 24,90 €   | 1.234,50 €  |
///
/// Spaces between symbol and number are U+00A0. Always two decimals. The
/// currency code comes from the API (`currency`, v1: EUR) and is never
/// hard-coded by callers.
abstract final class MoneyFormat {
  /// Formats [cents] as a display string, e.g. `€ 24,90`.
  ///
  /// Throws [ArgumentError] for negative amounts (12 §1.4: negative amounts
  /// never appear in the waiter UI).
  static String format(
    int cents, {
    required String currency,
    required UiLanguage language,
    required RestaurantLocale restaurantLocale,
  }) => parts(
    cents,
    currency: currency,
    language: language,
    restaurantLocale: restaurantLocale,
  ).text;

  /// Formats [cents] into [MoneyParts]; see [format].
  static MoneyParts parts(
    int cents, {
    required String currency,
    required UiLanguage language,
    required RestaurantLocale restaurantLocale,
  }) {
    if (cents < 0) {
      throw ArgumentError.value(
        cents,
        'cents',
        'negative amounts never appear in the waiter UI (12 §1.4)',
      );
    }
    final _MoneyStyle style = _styleFor(language, restaurantLocale);
    final String code = currency.trim().toUpperCase();
    final String symbol = code == 'EUR' ? '€' : code;
    return MoneyParts(
      symbol: symbol,
      number: _number(cents, style),
      symbolLeading: style.symbolLeading,
      // An alphabetic ISO code is never glued to the digits.
      spaced: style.spaced || symbol != '€',
    );
  }

  static _MoneyStyle _styleFor(UiLanguage language, RestaurantLocale locale) {
    if (language == UiLanguage.bhs) {
      return _bhs;
    }
    switch (locale) {
      case RestaurantLocale.deAT:
        return _deAT;
      case RestaurantLocale.deDE:
        return _deDE;
      case RestaurantLocale.deCH:
        return _deCH;
      case RestaurantLocale.enGB:
      case RestaurantLocale.enUS:
        return _en;
    }
  }

  static String _number(int cents, _MoneyStyle style) {
    final String units = (cents ~/ 100).toString();
    final String fraction = (cents % 100).toString().padLeft(2, '0');
    final StringBuffer grouped = StringBuffer();
    for (int i = 0; i < units.length; i++) {
      if (i > 0 && (units.length - i) % 3 == 0) {
        grouped.write(style.group);
      }
      grouped.write(units[i]);
    }
    return '$grouped${style.decimal}$fraction';
  }
}
