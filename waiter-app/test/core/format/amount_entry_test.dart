import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/format/format.dart';

AmountEntry typed(String keys) {
  AmountEntry e = AmountEntry.empty;
  for (final String k in keys.split('')) {
    e = e.digit(int.parse(k)).value;
  }
  return e;
}

void main() {
  group('AmountEntry — 03b §2.9', () {
    test(
      'digits shift in from the right: 0,00 → 0,02 → 0,24 → 2,49 → 24,90',
      () {
        final List<int> seen = <int>[];
        AmountEntry e = AmountEntry.empty;
        expect(e.cents, 0);
        for (final int d in <int>[2, 4, 9, 0]) {
          final EntryChange<AmountEntry> c = e.digit(d);
          expect(c.outcome, EntryOutcome.accepted);
          e = c.value;
          seen.add(e.cents);
        }
        expect(seen, <int>[2, 24, 249, 2490]);
        expect(e.digits, '2490');
      },
    );

    test('0 and 00 at amount 0 are a no-op without feedback', () {
      final EntryChange<AmountEntry> zero = AmountEntry.empty.digit(0);
      expect(zero.outcome, EntryOutcome.ignored);
      expect(zero.value, AmountEntry.empty);
      final EntryChange<AmountEntry> dz = AmountEntry.empty.doubleZero();
      expect(dz.outcome, EntryOutcome.ignored);
      expect(dz.value.isEmpty, isTrue);
    });

    test('0 after a digit is accepted', () {
      expect(typed('10').cents, 10);
    });

    test('00 adds two zeros', () {
      final EntryChange<AmountEntry> c = typed('24').doubleZero();
      expect(c.outcome, EntryOutcome.accepted);
      expect(c.value.cents, 2400);
    });

    test('00 with 6 digits typed adds one 0', () {
      final EntryChange<AmountEntry> c = typed('123456').doubleZero();
      expect(c.outcome, EntryOutcome.accepted);
      expect(c.value.digits, '1234560');
      expect(c.value.isFull, isTrue);
    });

    test('8th digit is ignored with the limit nudge (max € 99.999,99)', () {
      final AmountEntry full = typed('9999999');
      expect(full.cents, AmountEntry.maxCents);
      final EntryChange<AmountEntry> c = full.digit(1);
      expect(c.outcome, EntryOutcome.rejectedAtLimit);
      expect(c.value, full);
      expect(full.doubleZero().outcome, EntryOutcome.rejectedAtLimit);
      expect(full.digit(0).outcome, EntryOutcome.rejectedAtLimit);
    });

    test('⌫ removes the last digit (24,90 → 2,49)', () {
      final EntryChange<AmountEntry> c = typed('2490').backspace();
      expect(c.outcome, EntryOutcome.deleted);
      expect(c.value.cents, 249);
    });

    test('⌫ at 0 does nothing', () {
      expect(AmountEntry.empty.backspace().outcome, EntryOutcome.ignored);
    });

    test('long-press ⌫ clears to 0', () {
      final EntryChange<AmountEntry> c = typed('2490').clear();
      expect(c.outcome, EntryOutcome.cleared);
      expect(c.value, AmountEntry.empty);
      expect(AmountEntry.empty.clear().outcome, EntryOutcome.ignored);
    });

    test('QuickAmountChip sets the amount to the balance', () {
      final AmountEntry e = AmountEntry.fromCents(3250);
      expect(e.cents, 3250);
      expect(e.digits, '3250');
      // Typing continues from the chip value (POS shift).
      expect(e.digit(1).value.cents, 32501);
      expect(AmountEntry.fromCents(0), AmountEntry.empty);
      expect(() => AmountEntry.fromCents(-1), throwsRangeError);
      expect(
        () => AmountEntry.fromCents(AmountEntry.maxCents + 1),
        throwsRangeError,
      );
    });

    test('digit outside 0–9 is a programming error', () {
      expect(() => AmountEntry.empty.digit(10), throwsRangeError);
    });

    test('value semantics', () {
      expect(typed('249'), AmountEntry.fromCents(249));
      expect(typed('249').hashCode, AmountEntry.fromCents(249).hashCode);
    });
  });
}
