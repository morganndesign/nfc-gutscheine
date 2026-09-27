import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../format/business_day.dart';

/// Business day of the restaurant in its own time zone (09 §4.5: the device
/// time zone is irrelevant). Uses the IANA database bundled with the app.
class BusinessCalendar {
  BusinessCalendar() {
    if (!_initialised) {
      tz_data.initializeTimeZones();
      _initialised = true;
    }
  }

  static bool _initialised = false;

  Duration offsetAt(String zone, DateTime instant) {
    final tz.Location location = _location(zone);
    return location.timeZone(instant.toUtc().millisecondsSinceEpoch).offset;
  }

  BusinessDay dayOf(String zone, DateTime instant) => BusinessDay.of(instant.toUtc(), offsetAt(zone, instant));

  /// UTC instant of the next 04:00 rollover after [instant].
  DateTime nextRollover(String zone, DateTime instant) {
    final BusinessDay next = dayOf(zone, instant).next;
    // The offset at 04:00 local: evaluate close to the rollover itself.
    final DateTime guess = next.startUtc(offsetAt(zone, instant));
    return next.startUtc(offsetAt(zone, guess));
  }

  /// Wall-clock time of [instant] in the restaurant zone (Recent rows).
  DateTime local(String zone, DateTime instant) =>
      instant.toUtc().add(offsetAt(zone, instant));

  tz.Location _location(String zone) {
    try {
      return tz.getLocation(zone);
    } on tz.LocationNotFoundException {
      return tz.getLocation('Europe/Vienna');
    }
  }
}
