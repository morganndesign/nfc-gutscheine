import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/format/format.dart';

void main() {
  final CalendarDate expiry = CalendarDate(2029, 9, 26);

  group('12 §1.5 — date on balance card / problem bodies', () {
    test('DE (de-AT and de-DE/CH): 26.09.2029', () {
      expect(DateTimeFormat.date(expiry, UiLanguage.de), '26.09.2029');
      expect(
        DateTimeFormat.date(CalendarDate(2030, 1, 5), UiLanguage.de),
        '05.01.2030',
      );
    });

    test('EN: 26 Sep 2029 (day–month abbreviation everywhere)', () {
      expect(DateTimeFormat.date(expiry, UiLanguage.en), '26 Sep 2029');
      expect(
        DateTimeFormat.date(CalendarDate(2030, 1, 5), UiLanguage.en),
        '5 Jan 2030',
      );
    });

    test('BHS: 26. 9. 2029.', () {
      expect(DateTimeFormat.date(expiry, UiLanguage.bhs), '26. 9. 2029.');
    });
  });

  group('12 §1.5 — month names written out', () {
    test('DE: Jänner (de-AT), Januar (de-DE/CH), Februar', () {
      expect(
        DateTimeFormat.monthName(1, UiLanguage.de, RestaurantLocale.deAT),
        'Jänner',
      );
      expect(
        DateTimeFormat.monthName(1, UiLanguage.de, RestaurantLocale.deDE),
        'Januar',
      );
      expect(
        DateTimeFormat.monthName(1, UiLanguage.de, RestaurantLocale.deCH),
        'Januar',
      );
      expect(
        DateTimeFormat.monthName(2, UiLanguage.de, RestaurantLocale.deAT),
        'Februar',
      );
    });

    test('EN: January; BHS lower case: januar, februar', () {
      expect(
        DateTimeFormat.monthName(1, UiLanguage.en, RestaurantLocale.enGB),
        'January',
      );
      expect(
        DateTimeFormat.monthName(1, UiLanguage.bhs, RestaurantLocale.deAT),
        'januar',
      );
      expect(
        DateTimeFormat.monthName(2, UiLanguage.bhs, RestaurantLocale.deAT),
        'februar',
      );
    });

    test('long date for screen readers', () {
      expect(
        DateTimeFormat.longDate(expiry, UiLanguage.en, RestaurantLocale.deAT),
        '26 September 2029',
      );
      expect(
        DateTimeFormat.longDate(
          CalendarDate(2029, 1, 26),
          UiLanguage.de,
          RestaurantLocale.deAT,
        ),
        '26. Jänner 2029',
      );
      expect(
        DateTimeFormat.longDate(expiry, UiLanguage.bhs, RestaurantLocale.deAT),
        '26. septembar 2029.',
      );
    });
  });

  group('12 §1.5 — times', () {
    final WallTime evening = WallTime(18, 30);
    final WallTime early = WallTime(4, 0);

    test('rows and details: 18:30; en-US 6:30 pm', () {
      expect(
        DateTimeFormat.time(evening, UiLanguage.de, RestaurantLocale.deAT),
        '18:30',
      );
      expect(
        DateTimeFormat.time(evening, UiLanguage.de, RestaurantLocale.deDE),
        '18:30',
      );
      expect(
        DateTimeFormat.time(evening, UiLanguage.en, RestaurantLocale.enGB),
        '18:30',
      );
      expect(
        DateTimeFormat.time(evening, UiLanguage.en, RestaurantLocale.enUS),
        '6:30 pm',
      );
      expect(
        DateTimeFormat.time(evening, UiLanguage.bhs, RestaurantLocale.enUS),
        '18:30',
      );
      expect(
        DateTimeFormat.time(early, UiLanguage.de, RestaurantLocale.deAT),
        '04:00',
      );
    });

    test('12-hour clock edges', () {
      expect(
        DateTimeFormat.time(
          WallTime(0, 5),
          UiLanguage.en,
          RestaurantLocale.enUS,
        ),
        '12:05 am',
      );
      expect(
        DateTimeFormat.time(
          WallTime(12, 0),
          UiLanguage.en,
          RestaurantLocale.enUS,
        ),
        '12:00 pm',
      );
    });

    test('time in a sentence: 18:30 Uhr · 18:30 / 6:30 pm · 18:30 h', () {
      expect(
        DateTimeFormat.timeInSentence(
          evening,
          UiLanguage.de,
          RestaurantLocale.deAT,
        ),
        '18:30 Uhr',
      );
      expect(
        DateTimeFormat.timeInSentence(
          evening,
          UiLanguage.en,
          RestaurantLocale.enGB,
        ),
        '18:30',
      );
      expect(
        DateTimeFormat.timeInSentence(
          evening,
          UiLanguage.en,
          RestaurantLocale.enUS,
        ),
        '6:30 pm',
      );
      expect(
        DateTimeFormat.timeInSentence(
          evening,
          UiLanguage.bhs,
          RestaurantLocale.deAT,
        ),
        '18:30 h',
      );
    });

    test('business-day reference: seit 04:00 Uhr · since 04:00 · od 04:00 h', () {
      expect(
        'seit ${DateTimeFormat.timeInSentence(early, UiLanguage.de, RestaurantLocale.deAT)}',
        'seit 04:00 Uhr',
      );
      expect(
        'since ${DateTimeFormat.timeInSentence(early, UiLanguage.en, RestaurantLocale.enGB)}',
        'since 04:00',
      );
      expect(
        'od ${DateTimeFormat.timeInSentence(early, UiLanguage.bhs, RestaurantLocale.deAT)}',
        'od 04:00 h',
      );
    });

    test('wall time is taken in the restaurant zone, not the device zone', () {
      final DateTime utc = DateTime.utc(2026, 9, 26, 16, 30);
      expect(
        WallTime.ofInstant(utc, const Duration(hours: 2)),
        WallTime(18, 30),
      );
      expect(
        WallTime.ofInstant(utc.toLocal(), const Duration(hours: 2)),
        WallTime(18, 30),
      );
    });
  });

  group('12 §4.2 {time} countdown', () {
    test('m:ss below one hour', () {
      expect(DateTimeFormat.countdown(const Duration(seconds: 42)), '0:42');
      expect(
        DateTimeFormat.countdown(const Duration(minutes: 4, seconds: 5)),
        '4:05',
      );
      expect(
        DateTimeFormat.countdown(const Duration(minutes: 59, seconds: 59)),
        '59:59',
      );
    });

    test('h:mm:ss from one hour', () {
      expect(DateTimeFormat.countdown(const Duration(hours: 1)), '1:00:00');
      expect(
        DateTimeFormat.countdown(
          const Duration(hours: 2, minutes: 3, seconds: 4),
        ),
        '2:03:04',
      );
    });

    test('partial seconds round up; 0:00 only when over', () {
      expect(
        DateTimeFormat.countdown(const Duration(milliseconds: 41200)),
        '0:42',
      );
      expect(DateTimeFormat.countdown(const Duration(milliseconds: 1)), '0:01');
      expect(DateTimeFormat.countdown(Duration.zero), '0:00');
      expect(DateTimeFormat.countdown(const Duration(seconds: -3)), '0:00');
    });

    test('{seconds} and {minutes} round up', () {
      expect(
        DateTimeFormat.ceilSeconds(const Duration(milliseconds: 41200)),
        42,
      );
      expect(DateTimeFormat.ceilMinutes(const Duration(seconds: 61)), 2);
      expect(DateTimeFormat.ceilMinutes(const Duration(seconds: 60)), 1);
      expect(DateTimeFormat.ceilMinutes(Duration.zero), 0);
    });
  });

  group('CalendarDate', () {
    test('parses the API expires_at', () {
      expect(CalendarDate.parseIso('2029-09-26'), expiry);
      expect(expiry.iso, '2029-09-26');
      expect(() => CalendarDate.parseIso('2029-02-30'), throwsFormatException);
      expect(() => CalendarDate.parseIso('26.09.2029'), throwsFormatException);
    });
  });
}
