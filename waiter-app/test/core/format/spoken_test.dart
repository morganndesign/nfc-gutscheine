import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/format/format.dart';

void main() {
  group('Spoken.amount — 12 §1.4 spoken table', () {
    final Map<UiLanguage, List<String>> table = <UiLanguage, List<String>>{
      // 24,90 · 1,00 · 21,00 · 0,50
      UiLanguage.de: <String>['24 Euro 90', '1 Euro', '21 Euro', '50 Cent'],
      UiLanguage.en: <String>['24 euros 90', '1 euro', '21 euros', '50 cents'],
      UiLanguage.bhs: <String>['24 eura 90', '1 euro', '21 euro', '50 centi'],
    };
    const List<int> amounts = <int>[2490, 100, 2100, 50];

    for (final MapEntry<UiLanguage, List<String>> row in table.entries) {
      test(row.key.name, () {
        for (int i = 0; i < amounts.length; i++) {
          expect(Spoken.amount(amounts[i], language: row.key), row.value[i]);
        }
      });
    }
  });

  group('Spoken.amount — 07 §5.2 mirror and edge cases', () {
    test('thousands are not grouped (07 §5.2: "1250 euros")', () {
      expect(Spoken.amount(125000, language: UiLanguage.en), '1250 euros');
      expect(Spoken.amount(125000, language: UiLanguage.de), '1250 Euro');
      expect(Spoken.amount(125000, language: UiLanguage.bhs), '1250 eura');
    });

    test('zero reads "0 euro" (05 §2.2 empty AmountDisplay)', () {
      expect(Spoken.amount(0, language: UiLanguage.de), '0 Euro');
      expect(Spoken.amount(0, language: UiLanguage.en), '0 euros');
      expect(Spoken.amount(0, language: UiLanguage.bhs), '0 eura');
    });

    test('BHS euro plural: one / few / other (12 §1.9)', () {
      expect(Spoken.amount(2200, language: UiLanguage.bhs), '22 eura');
      expect(Spoken.amount(1100, language: UiLanguage.bhs), '11 eura');
      expect(Spoken.amount(10100, language: UiLanguage.bhs), '101 euro');
      expect(Spoken.amount(11100, language: UiLanguage.bhs), '111 eura');
    });

    test('cents-only form uses the grammatical plural (07 §5.2)', () {
      expect(Spoken.amount(1, language: UiLanguage.de), '1 Cent');
      expect(Spoken.amount(1, language: UiLanguage.en), '1 cent');
      expect(Spoken.amount(1, language: UiLanguage.bhs), '1 cent');
      expect(Spoken.amount(3, language: UiLanguage.bhs), '3 centa');
      expect(Spoken.amount(12, language: UiLanguage.bhs), '12 centi');
      expect(Spoken.amount(21, language: UiLanguage.bhs), '21 cent');
    });

    test('cents are spoken as a number, without leading zero', () {
      expect(Spoken.amount(2405, language: UiLanguage.de), '24 Euro 5');
    });

    test('non-EUR and negative amounts are rejected', () {
      expect(
        () => Spoken.amount(100, language: UiLanguage.de, currency: 'CHF'),
        throwsUnsupportedError,
      );
      expect(
        () => Spoken.amount(-1, language: UiLanguage.de),
        throwsArgumentError,
      );
    });
  });

  group('Spoken characters and card numbers', () {
    test('card ending read digit by digit (12 §1.10)', () {
      expect(Spoken.characters('6488'), '6 4 8 8');
    });

    test('full and partial card number in groups (07 §5.2, 05 §2.5)', () {
      expect(
        Spoken.cardNumber('5285105870986488'),
        '5 2 8 5, 1 0 5 8, 7 0 9 8, 6 4 8 8',
      );
      expect(Spoken.cardNumber('5285105870'), '5 2 8 5, 1 0 5 8, 7 0');
      expect(Spoken.cardNumber(''), '');
    });
  });

  group('bhsPluralCategory (12 §1.9)', () {
    test('examples of the table', () {
      expect(bhsPluralCategory(1), BhsPlural.one);
      expect(bhsPluralCategory(3), BhsPlural.few);
      expect(bhsPluralCategory(5), BhsPlural.other);
      expect(bhsPluralCategory(11), BhsPlural.other);
      expect(bhsPluralCategory(21), BhsPlural.one);
    });

    test('12–14 are other, 22–24 few, 0 other', () {
      for (final int n in <int>[12, 13, 14, 112, 0, 10, 15, 100]) {
        expect(bhsPluralCategory(n), BhsPlural.other, reason: '$n');
      }
      for (final int n in <int>[2, 4, 22, 24, 102, 1003]) {
        expect(bhsPluralCategory(n), BhsPlural.few, reason: '$n');
      }
    });
  });
}
