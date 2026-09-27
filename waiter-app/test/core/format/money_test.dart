import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/format/format.dart';

/// Replaces spaces by U+00A0 (12 §1.4: no-break space symbol ↔ number).
String nb(String s) => s.replaceAll(' ', '\u00A0');

String fmt(int cents, UiLanguage ui, RestaurantLocale rl) => MoneyFormat.format(
  cents,
  currency: 'EUR',
  language: ui,
  restaurantLocale: rl,
);

void main() {
  group('12 §1.4 table — every row, every column', () {
    // UI, restaurant locale, 24,90, 1.234,50, 0,00, 99.999,99
    final List<(UiLanguage, RestaurantLocale, List<String>)> rows =
        <(UiLanguage, RestaurantLocale, List<String>)>[
          (
            UiLanguage.de,
            RestaurantLocale.deAT,
            <String>['€ 24,90', '€ 1.234,50', '€ 0,00', '€ 99.999,99'],
          ),
          (
            UiLanguage.de,
            RestaurantLocale.deDE,
            <String>['24,90 €', '1.234,50 €', '0,00 €', '99.999,99 €'],
          ),
          (
            UiLanguage.de,
            RestaurantLocale.deCH,
            <String>['€ 24.90', '€ 1’234.50', '€ 0.00', '€ 99’999.99'],
          ),
          (
            UiLanguage.en,
            RestaurantLocale.deAT,
            <String>['€ 24,90', '€ 1.234,50', '€ 0,00', '€ 99.999,99'],
          ),
          (
            UiLanguage.en,
            RestaurantLocale.enGB,
            <String>['€24.90', '€1,234.50', '€0.00', '€99,999.99'],
          ),
          (
            UiLanguage.en,
            RestaurantLocale.enUS,
            <String>['€24.90', '€1,234.50', '€0.00', '€99,999.99'],
          ),
        ];
    const List<int> amounts = <int>[2490, 123450, 0, 9999999];

    for (final (UiLanguage ui, RestaurantLocale rl, List<String> expected)
        in rows) {
      test('${ui.name} UI · ${rl.tag}', () {
        for (int i = 0; i < amounts.length; i++) {
          expect(fmt(amounts[i], ui, rl), nb(expected[i]));
        }
      });
    }

    test('BHS UI · any restaurant locale → 24,90 €', () {
      for (final RestaurantLocale rl in RestaurantLocale.values) {
        expect(fmt(2490, UiLanguage.bhs, rl), nb('24,90 €'));
        expect(fmt(123450, UiLanguage.bhs, rl), nb('1.234,50 €'));
        expect(fmt(0, UiLanguage.bhs, rl), nb('0,00 €'));
        expect(fmt(9999999, UiLanguage.bhs, rl), nb('99.999,99 €'));
      }
    });
  });

  group('12 §1.4 bullet rules', () {
    test('always two decimals, also for whole euros', () {
      expect(fmt(500, UiLanguage.de, RestaurantLocale.deAT), nb('€ 5,00'));
      expect(fmt(5, UiLanguage.en, RestaurantLocale.enGB), '€0.05');
      expect(fmt(50, UiLanguage.de, RestaurantLocale.deDE), nb('0,50 €'));
    });

    test('symbol ↔ number space is U+00A0, never U+0020', () {
      final String s = fmt(2490, UiLanguage.de, RestaurantLocale.deAT);
      expect(s.codeUnitAt(1), 0x00A0);
      expect(s.contains(' '), isFalse);
    });

    test('grouping beyond the 7-digit limit (balances)', () {
      expect(
        fmt(123456789, UiLanguage.de, RestaurantLocale.deAT),
        nb('€ 1.234.567,89'),
      );
      expect(fmt(100000, UiLanguage.en, RestaurantLocale.enUS), '€1,000.00');
      expect(fmt(99999, UiLanguage.de, RestaurantLocale.deAT), nb('€ 999,99'));
    });

    test('negative amounts are rejected (never shown)', () {
      expect(
        () => fmt(-1, UiLanguage.de, RestaurantLocale.deAT),
        throwsArgumentError,
      );
    });

    test('currency comes from the API and is not hard-coded', () {
      expect(
        MoneyFormat.format(
          2490,
          currency: 'eur',
          language: UiLanguage.de,
          restaurantLocale: RestaurantLocale.deAT,
        ),
        nb('€ 24,90'),
      );
      // 04 §3.4: de-CH with currency CHF → "CHF 24.90".
      expect(
        MoneyFormat.format(
          123450,
          currency: 'CHF',
          language: UiLanguage.de,
          restaurantLocale: RestaurantLocale.deCH,
        ),
        nb('CHF 1’234.50'),
      );
      // An ISO code is never glued to the digits, even in tight locales.
      expect(
        MoneyFormat.format(
          2490,
          currency: 'CHF',
          language: UiLanguage.en,
          restaurantLocale: RestaurantLocale.enGB,
        ),
        nb('CHF 24.90'),
      );
    });
  });

  group('MoneyParts (AmountDisplay / BalanceCard, 04 §3.4)', () {
    test('de-AT leading, spaced', () {
      final MoneyParts p = MoneyFormat.parts(
        2490,
        currency: 'EUR',
        language: UiLanguage.de,
        restaurantLocale: RestaurantLocale.deAT,
      );
      expect(p.symbol, '€');
      expect(p.number, '24,90');
      expect(p.symbolLeading, isTrue);
      expect(p.spaced, isTrue);
      expect(p.toString(), nb('€ 24,90'));
    });

    test('de-DE trailing, spaced', () {
      final MoneyParts p = MoneyFormat.parts(
        2490,
        currency: 'EUR',
        language: UiLanguage.de,
        restaurantLocale: RestaurantLocale.deDE,
      );
      expect(p.symbolLeading, isFalse);
      expect(p.spaced, isTrue);
    });

    test('en-GB leading, tight', () {
      final MoneyParts p = MoneyFormat.parts(
        2490,
        currency: 'EUR',
        language: UiLanguage.en,
        restaurantLocale: RestaurantLocale.enGB,
      );
      expect(p.symbolLeading, isTrue);
      expect(p.spaced, isFalse);
      expect(p.text, '€24.90');
      expect(
        p,
        const MoneyParts(
          symbol: '€',
          number: '24.90',
          symbolLeading: true,
          spaced: false,
        ),
      );
    });
  });

  group('RestaurantLocale.parse', () {
    test('brief list, separators and case', () {
      expect(RestaurantLocale.parse('de-AT'), RestaurantLocale.deAT);
      expect(RestaurantLocale.parse('de_DE'), RestaurantLocale.deDE);
      expect(RestaurantLocale.parse('DE-ch'), RestaurantLocale.deCH);
      expect(RestaurantLocale.parse('en-GB'), RestaurantLocale.enGB);
      expect(RestaurantLocale.parse(' en_us '), RestaurantLocale.enUS);
    });

    test('unknown tags fall back by language', () {
      expect(RestaurantLocale.parse('de-LU'), RestaurantLocale.deAT);
      expect(RestaurantLocale.parse('en-IE'), RestaurantLocale.enGB);
      expect(RestaurantLocale.parse('it-IT'), RestaurantLocale.deAT);
    });
  });
}
