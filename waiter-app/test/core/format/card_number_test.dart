import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/format/format.dart';

String nb(String s) => s.replaceAll(' ', '\u00A0');

void main() {
  group('CardNumber — 12 §1.4', () {
    test('full number in groups of 4 with no-break spaces', () {
      expect(CardNumber.format('5285105870986488'), nb('5285 1058 7098 6488'));
      expect(CardNumber.format('528510'), nb('5285 10'));
      expect(CardNumber.format(''), '');
      expect(() => CardNumber.format('5285 1058'), throwsFormatException);
    });

    test('masked: four U+2022 bullets, no-break space, last four', () {
      expect(CardNumber.masked('6488'), nb('•••• 6488'));
      expect(CardNumber.masked('5285105870986488'), nb('•••• 6488'));
      expect(CardNumber.masked('6488').runes.take(4).toSet(), <int>{0x2022});
    });

    test('lastFour', () {
      expect(CardNumber.lastFour('5285105870986488'), '6488');
      expect(() => CardNumber.lastFour('648'), throwsFormatException);
    });
  });

  group('CardNumber.fromPaste — 03a §7', () {
    test('all non-digits stripped; exactly 16 → number', () {
      expect(CardNumber.fromPaste('5285 1058 7098 6488'), '5285105870986488');
      expect(
        CardNumber.fromPaste('Karte: 5285-1058-7098-6488\n'),
        '5285105870986488',
      );
    });

    test('anything else → null', () {
      expect(CardNumber.fromPaste('5285 1058 7098 648'), isNull);
      expect(CardNumber.fromPaste('5285 1058 7098 64881'), isNull);
      expect(CardNumber.fromPaste('hello'), isNull);
    });
  });

  group('CardNumberEntry — 03a §7', () {
    CardNumberEntry typed(String digits) {
      CardNumberEntry e = CardNumberEntry.empty;
      for (final String d in digits.split('')) {
        e = e.digit(int.parse(d)).value;
      }
      return e;
    }

    test('typing and counter', () {
      final CardNumberEntry e = typed('528510587098');
      expect(e.count, 12);
      expect(e.isComplete, isFalse);
      expect(typed('5285105870986488').isComplete, isTrue);
    });

    test('leading zero is a real digit', () {
      final EntryChange<CardNumberEntry> c = CardNumberEntry.empty.digit(0);
      expect(c.outcome, EntryOutcome.accepted);
      expect(c.value.digits, '0');
    });

    test('17th digit rejected with the limit nudge', () {
      final CardNumberEntry full = typed('5285105870986488');
      expect(full.digit(1).outcome, EntryOutcome.rejectedAtLimit);
      expect(full.digit(1).value, full);
      expect(full.doubleZero().outcome, EntryOutcome.rejectedAtLimit);
    });

    test('00 inserts two zeros, one if only one position is left', () {
      expect(typed('52').doubleZero().value.digits, '5200');
      final EntryChange<CardNumberEntry> c = typed(
        '528510587098648',
      ).doubleZero();
      expect(c.outcome, EntryOutcome.accepted);
      expect(c.value.digits, '5285105870986480');
    });

    test('⌫ deletes one digit, long-press clears all', () {
      expect(typed('528').backspace().value.digits, '52');
      expect(CardNumberEntry.empty.backspace().outcome, EntryOutcome.ignored);
      expect(typed('528').clear().outcome, EntryOutcome.cleared);
      expect(typed('528').clear().value, CardNumberEntry.empty);
    });

    test('paste replaces the field or is rejected unchanged', () {
      final CardNumberEntry e = typed('11');
      final EntryChange<CardNumberEntry> ok = e.paste('5285 1058 7098 6488');
      expect(ok.outcome, EntryOutcome.accepted);
      expect(ok.value.digits, '5285105870986488');
      final EntryChange<CardNumberEntry> bad = e.paste('1234');
      expect(bad.outcome, EntryOutcome.pasteRejected);
      expect(bad.value, e);
    });

    test('restore previous number (S10 → S11)', () {
      expect(CardNumberEntry.of('5285105870986488').isComplete, isTrue);
      expect(
        () => CardNumberEntry.of('52851058709864881'),
        throwsFormatException,
      );
      expect(() => CardNumberEntry.of('52a'), throwsFormatException);
    });
  });
}
