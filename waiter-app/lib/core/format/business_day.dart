import 'package:flutter/foundation.dart' show immutable;

import 'date_time.dart';

/// Business day of the restaurant (12 §1.5, 09 §4.5–§4.6): it starts at
/// **04:00 local time in the restaurant time zone**; Recent is cleared at the
/// rollover. The device time zone is irrelevant.
///
/// Dart has no time-zone database, so the caller supplies the restaurant's
/// UTC offset **valid at the instant being evaluated** (e.g. +1 h for
/// Europe/Vienna in winter, +2 h in summer). Because European DST changes
/// happen at 02:00–03:00 local, the offset at 04:00 is always the post-change
/// offset.
@immutable
class BusinessDay implements Comparable<BusinessDay> {
  const BusinessDay._(this.date);

  /// Local time at which a business day starts (12 §1.5).
  static const Duration rollover = Duration(hours: 4);

  /// The business day containing [instant] for a restaurant whose UTC offset
  /// at that instant is [restaurantUtcOffset]: the local date of
  /// `instant + offset − 4 h`.
  ///
  /// ```dart
  /// // 2026-09-26 01:59Z = 03:59 in Vienna (CEST, +2 h)
  /// BusinessDay.of(DateTime.utc(2026, 9, 26, 1, 59), const Duration(hours: 2))
  ///     .key; // '2026-09-25'
  /// ```
  factory BusinessDay.of(DateTime instant, Duration restaurantUtcOffset) =>
      BusinessDay._(
        CalendarDate.ofInstant(instant, restaurantUtcOffset - rollover),
      );

  /// Calendar date the business day is named after (the day it starts).
  final CalendarDate date;

  /// Stable storage key `YYYY-MM-DD`.
  String get key => date.iso;

  /// The following business day.
  BusinessDay get next {
    final DateTime d = DateTime.utc(date.year, date.month, date.day + 1);
    return BusinessDay._(CalendarDate(d.year, d.month, d.day));
  }

  /// UTC instant at which this business day starts (04:00 local), given the
  /// restaurant's UTC offset at that moment. Used to schedule the rollover:
  /// `BusinessDay.of(now, offsetNow).next.startUtc(offsetAtNextRollover)`.
  DateTime startUtc(Duration restaurantUtcOffsetAtStart) => DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).add(rollover).subtract(restaurantUtcOffsetAtStart);

  @override
  int compareTo(BusinessDay other) => date.compareTo(other.date);

  @override
  bool operator ==(Object other) => other is BusinessDay && other.date == date;

  @override
  int get hashCode => date.hashCode;

  @override
  String toString() => 'BusinessDay($key)';
}
