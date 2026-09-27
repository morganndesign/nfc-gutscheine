import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/format/format.dart';

const Duration cet = Duration(hours: 1); // Europe/Vienna, winter
const Duration cest = Duration(hours: 2); // Europe/Vienna, summer

void main() {
  group('BusinessDay — 04:00 rollover (12 §1.5, 09 §4.5–4.6)', () {
    test('03:59 local belongs to the previous day, 04:00 starts a new one', () {
      // 2026-09-26 03:59 CEST = 01:59Z
      expect(
        BusinessDay.of(DateTime.utc(2026, 9, 26, 1, 59), cest).key,
        '2026-09-25',
      );
      // 2026-09-26 04:00 CEST = 02:00Z
      expect(
        BusinessDay.of(DateTime.utc(2026, 9, 26, 2), cest).key,
        '2026-09-26',
      );
    });

    test('late evening and after midnight are the same business day', () {
      final BusinessDay evening = BusinessDay.of(
        DateTime.utc(2026, 1, 15, 22, 30),
        cet,
      ); // 23:30
      final BusinessDay night = BusinessDay.of(
        DateTime.utc(2026, 1, 16, 1, 30),
        cet,
      ); // 02:30
      expect(evening, night);
      expect(evening.key, '2026-01-15');
    });

    test('DST start (2026-03-29, 02:00 → 03:00): offset at 04:00 is +2 h', () {
      // 03:59 CEST = 01:59Z → still 28 March.
      expect(
        BusinessDay.of(DateTime.utc(2026, 3, 29, 1, 59), cest).key,
        '2026-03-28',
      );
      // 04:00 CEST = 02:00Z → 29 March.
      expect(
        BusinessDay.of(DateTime.utc(2026, 3, 29, 2), cest).key,
        '2026-03-29',
      );
      // 01:30 CET (before the change) = 00:30Z → 28 March.
      expect(
        BusinessDay.of(DateTime.utc(2026, 3, 29, 0, 30), cet).key,
        '2026-03-28',
      );
      expect(
        BusinessDay.of(DateTime.utc(2026, 3, 28, 12), cet).next.startUtc(cest),
        DateTime.utc(2026, 3, 29, 2),
      );
    });

    test('DST end (2026-10-25, 03:00 → 02:00): offset at 04:00 is +1 h', () {
      // 03:59 CET = 02:59Z → still 24 October.
      expect(
        BusinessDay.of(DateTime.utc(2026, 10, 25, 2, 59), cet).key,
        '2026-10-24',
      );
      // 04:00 CET = 03:00Z → 25 October.
      expect(
        BusinessDay.of(DateTime.utc(2026, 10, 25, 3), cet).key,
        '2026-10-25',
      );
      // The same instant with the (wrong) summer offset would already roll
      // over — the caller must pass the offset valid at the instant.
      expect(
        BusinessDay.of(DateTime.utc(2026, 10, 25, 2, 59), cest).key,
        '2026-10-25',
      );
      expect(
        BusinessDay.of(DateTime.utc(2026, 10, 24, 12), cest).next.startUtc(cet),
        DateTime.utc(2026, 10, 25, 3),
      );
    });

    test('device zone is irrelevant (local DateTime input)', () {
      final DateTime utc = DateTime.utc(2026, 9, 26, 1, 59);
      expect(BusinessDay.of(utc.toLocal(), cest), BusinessDay.of(utc, cest));
    });

    test('negative offsets, month and year boundaries', () {
      // New York (−5 h): 2026-01-01 03:00 local = 08:00Z → 2025-12-31.
      expect(
        BusinessDay.of(
          DateTime.utc(2026, 1, 1, 8),
          const Duration(hours: -5),
        ).key,
        '2025-12-31',
      );
      expect(
        BusinessDay.of(DateTime.utc(2026, 2, 28, 12), cet).next.key,
        '2026-03-01',
      );
    });

    test('ordering', () {
      final BusinessDay a = BusinessDay.of(DateTime.utc(2026, 9, 25, 12), cest);
      final BusinessDay b = BusinessDay.of(DateTime.utc(2026, 9, 26, 12), cest);
      expect(a.compareTo(b), lessThan(0));
      expect(a.next, b);
    });
  });
}
