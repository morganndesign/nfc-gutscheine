import 'package:flutter/foundation.dart';

import '../core/format/format.dart';

/// Formatting context for components that render money or dates
/// (12 §1.4–§1.5): the card's currency, the UI language and the
/// restaurant locale.
///
/// Components receive amounts as pre-computed cents plus this context and
/// derive every visible and spoken form from it, so the visual string
/// (restaurant locale) and the spoken string (UI language, 07 §5.2) can
/// never disagree.
@immutable
class MoneyContext {
  /// Creates a formatting context.
  const MoneyContext({
    required this.currency,
    required this.language,
    required this.restaurantLocale,
  });

  /// ISO currency code from the API (`currency`, v1: EUR).
  final String currency;

  /// UI language (spoken forms, month names).
  final UiLanguage language;

  /// Restaurant locale (number and currency pattern).
  final RestaurantLocale restaurantLocale;

  /// Visual parts of [cents] (symbol, number, placement, gap).
  MoneyParts parts(int cents) => MoneyFormat.parts(
    cents,
    currency: currency,
    language: language,
    restaurantLocale: restaurantLocale,
  );

  /// Display string of [cents], e.g. `€ 24,90`.
  String format(int cents) => parts(cents).text;

  /// Spoken form of [cents], e.g. `24 euros 90` (07 §5.2).
  String spoken(int cents) =>
      Spoken.amount(cents, language: language, currency: currency);

  /// Visible date, e.g. `26.09.2029` (12 §1.5).
  String date(CalendarDate value) => DateTimeFormat.date(value, language);

  /// Spoken date with the month written out, e.g. `26 September 2029`.
  String longDate(CalendarDate value) =>
      DateTimeFormat.longDate(value, language, restaurantLocale);

  /// Row time, e.g. `14:32` or `2:32 pm` (12 §1.5).
  String time(WallTime value) =>
      DateTimeFormat.time(value, language, restaurantLocale);

  /// Whether times use the 12-hour clock (TransactionRow 64-pt column).
  bool get usesTwelveHourClock =>
      language == UiLanguage.en && restaurantLocale == RestaurantLocale.enUS;

  @override
  bool operator ==(Object other) =>
      other is MoneyContext &&
      other.currency == currency &&
      other.language == language &&
      other.restaurantLocale == restaurantLocale;

  @override
  int get hashCode => Object.hash(currency, language, restaurantLocale);
}
