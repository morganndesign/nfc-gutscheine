import 'package:flutter/foundation.dart' show immutable;

import '../l10n/ui_language.dart';
import 'restaurant_locale.dart';

/// A calendar date without time or zone, e.g. `expires_at` (`YYYY-MM-DD`,
/// a local date in the restaurant time zone — API "Expiry semantics").
@immutable
class CalendarDate implements Comparable<CalendarDate> {
  /// Creates a date; throws [RangeError] for an impossible date.
  CalendarDate(this.year, this.month, this.day) {
    RangeError.checkValueInInterval(month, 1, 12, 'month');
    final int days = DateTime.utc(year, month + 1, 0).day;
    RangeError.checkValueInInterval(day, 1, days, 'day');
  }

  /// Parses `YYYY-MM-DD` (throws [FormatException]).
  factory CalendarDate.parseIso(String text) {
    final RegExpMatch? m = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})$',
    ).firstMatch(text.trim());
    if (m == null) {
      throw FormatException('expected YYYY-MM-DD', text);
    }
    try {
      return CalendarDate(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    } on RangeError {
      throw FormatException('not a calendar date', text);
    }
  }

  /// Local date of [instant] at [utcOffset] (restaurant time zone).
  factory CalendarDate.ofInstant(DateTime instant, Duration utcOffset) {
    final DateTime local = instant.toUtc().add(utcOffset);
    return CalendarDate(local.year, local.month, local.day);
  }

  /// Year.
  final int year;

  /// Month 1–12.
  final int month;

  /// Day of month.
  final int day;

  /// ISO form `YYYY-MM-DD`.
  String get iso =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(CalendarDate other) => iso.compareTo(other.iso);

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => iso;
}

/// A local wall-clock time in the restaurant time zone (12 §1.5).
@immutable
class WallTime {
  /// Creates a time; throws [RangeError] outside 0:00–23:59.
  WallTime(this.hour, this.minute) {
    RangeError.checkValueInInterval(hour, 0, 23, 'hour');
    RangeError.checkValueInInterval(minute, 0, 59, 'minute');
  }

  /// Wall time of [instant] at [utcOffset] (restaurant time zone; the
  /// device zone is irrelevant, 09 §4.5).
  factory WallTime.ofInstant(DateTime instant, Duration utcOffset) {
    final DateTime local = instant.toUtc().add(utcOffset);
    return WallTime(local.hour, local.minute);
  }

  /// Hour 0–23.
  final int hour;

  /// Minute 0–59.
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is WallTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => '$hour:$minute';
}

/// Date and time formats of 12 §1.5. All values are in the restaurant time
/// zone; no relative dates in v1.
abstract final class DateTimeFormat {
  static const List<String> _enAbbrev = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<String> _enMonths = <String>[
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const List<String> _deMonths = <String>[
    'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', //
    'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
  ];

  static const List<String> _bhsMonths = <String>[
    'januar', 'februar', 'mart', 'april', 'maj', 'juni', //
    'juli', 'august', 'septembar', 'oktobar', 'novembar', 'decembar',
  ];

  /// Date on the balance card and in problem bodies (`{date}`, 12 §1.5):
  /// DE `26.09.2029` · EN `26 Sep 2029` · BHS `26. 9. 2029.`
  ///
  /// English always uses day–month abbreviation (never `09/10`), whatever
  /// the restaurant locale.
  static String date(CalendarDate date, UiLanguage language) {
    switch (language) {
      case UiLanguage.de:
        return '${_two(date.day)}.${_two(date.month)}.${date.year}';
      case UiLanguage.en:
        return '${date.day} ${_enAbbrev[date.month - 1]} ${date.year}';
      case UiLanguage.bhs:
        return '${date.day}. ${date.month}. ${date.year}.';
    }
  }

  /// Month name written out (12 §1.5 "Month names"): de-AT `Jänner`, other
  /// German `Januar`; EN `January`; BHS lower case `januar`.
  static String monthName(
    int month,
    UiLanguage language,
    RestaurantLocale restaurantLocale,
  ) {
    RangeError.checkValueInInterval(month, 1, 12, 'month');
    switch (language) {
      case UiLanguage.de:
        if (month == 1 && restaurantLocale == RestaurantLocale.deAT) {
          return 'Jänner';
        }
        return _deMonths[month - 1];
      case UiLanguage.en:
        return _enMonths[month - 1];
      case UiLanguage.bhs:
        return _bhsMonths[month - 1];
    }
  }

  /// Date with the month written out, for screen readers (07 §9.3: "spoken
  /// as full date in UI language"; 03b §2.10: "valid until 26 September
  /// 2029"): DE `26. September 2029` · EN `26 September 2029` ·
  /// BHS `26. septembar 2029.`
  static String longDate(
    CalendarDate date,
    UiLanguage language,
    RestaurantLocale restaurantLocale,
  ) {
    final String month = monthName(date.month, language, restaurantLocale);
    switch (language) {
      case UiLanguage.de:
        return '${date.day}. $month ${date.year}';
      case UiLanguage.en:
        return '${date.day} $month ${date.year}';
      case UiLanguage.bhs:
        return '${date.day}. $month ${date.year}.';
    }
  }

  /// Time in rows and details (12 §1.5): `18:30`; English UI with an en-US
  /// restaurant uses the 12-hour clock `6:30 pm`.
  static String time(
    WallTime time,
    UiLanguage language,
    RestaurantLocale restaurantLocale,
  ) {
    if (language == UiLanguage.en &&
        restaurantLocale == RestaurantLocale.enUS) {
      final int h12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
      final String suffix = time.hour < 12 ? 'am' : 'pm';
      return '$h12:${_two(time.minute)} $suffix';
    }
    return '${_two(time.hour)}:${_two(time.minute)}';
  }

  /// Time inside a sentence (12 §1.5): DE `18:30 Uhr` · EN `18:30` /
  /// `6:30 pm` · BHS `18:30 h`.
  static String timeInSentence(
    WallTime time,
    UiLanguage language,
    RestaurantLocale restaurantLocale,
  ) {
    final String base = DateTimeFormat.time(time, language, restaurantLocale);
    switch (language) {
      case UiLanguage.de:
        return '$base Uhr';
      case UiLanguage.en:
        return base;
      case UiLanguage.bhs:
        return '$base h';
    }
  }

  /// Countdown for `{time}` (12 §4.2): `m:ss` below one hour, `h:mm:ss`
  /// from one hour — `0:42`, `4:05`, `1:00:00`. Partial seconds round up, so
  /// `0:00` appears only when the wait is over; negative → `0:00`.
  static String countdown(Duration remaining) {
    final int total = ceilSeconds(remaining);
    final int h = total ~/ 3600;
    final int m = (total % 3600) ~/ 60;
    final int s = total % 60;
    return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '$m:${_two(s)}';
  }

  /// Whole seconds for `{seconds}` (12 §1.4 "{seconds} s"), rounded up;
  /// never negative.
  static int ceilSeconds(Duration remaining) {
    if (remaining <= Duration.zero) {
      return 0;
    }
    final int micros = remaining.inMicroseconds;
    return (micros + Duration.microsecondsPerSecond - 1) ~/
        Duration.microsecondsPerSecond;
  }

  /// Whole minutes for `{minutes}` (12 §1.4 "{minutes} min"), rounded up;
  /// never negative.
  static int ceilMinutes(Duration remaining) =>
      (ceilSeconds(remaining) + 59) ~/ 60;

  static String _two(int n) => n.toString().padLeft(2, '0');
}
