import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/format/format.dart';
import 'package:giftcard_waiter/core/l10n/l10n.dart';
import 'package:intl/intl.dart';

String nb(String s) => s.replaceAll(' ', '\u00A0');

Future<AppLocalizations> load(String code) =>
    AppLocalizations.delegate.load(Locale(code));

void main() {
  test('loads for de, en, bs, hr, sr', () async {
    final Map<String, String> titles = <String, String>{
      'de': 'Gutschein scannen',
      'en': 'Scan the voucher',
      'bs': 'Skenirajte vaučer',
      'hr': 'Skenirajte vaučer',
      'sr': 'Skenirajte vaučer',
    };
    for (final MapEntry<String, String> e in titles.entries) {
      final AppLocalizations l = await load(e.key);
      expect(l.localeName, e.key);
      expect(l.readyTitle, e.value);
      expect(l.getManager, isNotEmpty);
    }
  });

  group('plurals (12 §1.9)', () {
    test('DE / EN one · other', () async {
      final AppLocalizations de = await load('de');
      final AppLocalizations en = await load('en');
      final String amount = nb('€ 486,40');
      expect(de.recentSummary(1, amount), '1 Einlösung · $amount heute');
      expect(de.recentSummary(5, amount), '5 Einlösungen · $amount heute');
      expect(en.recentSummary(1, amount), '1 redemption · $amount today');
      expect(en.recentSummary(12, amount), '12 redemptions · $amount today');
      expect(en.recentSummary(21, amount), '21 redemptions · $amount today');
    });

    test('BHS one · few · other incl. 11 and 21, in bs, hr and sr', () async {
      final String amount = nb('486,40 €');
      for (final String code in <String>['bs', 'hr', 'sr']) {
        final AppLocalizations l = await load(code);
        expect(l.recentSummary(1, amount), '1 iskorištavanje · $amount danas');
        expect(l.recentSummary(3, amount), '3 iskorištavanja · $amount danas');
        expect(l.recentSummary(5, amount), '5 iskorištavanja · $amount danas');
        expect(
          l.recentSummary(11, amount),
          '11 iskorištavanja · $amount danas',
        );
        expect(
          l.recentSummary(21, amount),
          '21 iskorištavanje · $amount danas',
        );
      }
    });

    test('BHS few category is selected by the runtime plural rules', () {
      for (final String code in <String>['bs', 'hr', 'sr']) {
        String category(int n) => Intl.pluralLogic(
          n,
          locale: code,
          one: 'one',
          few: 'few',
          other: 'other',
        );
        expect(category(3), 'few');
        expect(category(22), 'few');
        expect(category(12), 'other');
        expect(category(21), 'one');
        // Matches the formatter's own rule (used for spoken cents).
        for (int n = 0; n < 250; n++) {
          expect(category(n), bhsPluralCategory(n).name, reason: '$code $n');
        }
      }
    });

    test('a11y.spokenAmount template agrees with Spoken.amount', () async {
      final Map<String, UiLanguage> langs = <String, UiLanguage>{
        'de': UiLanguage.de,
        'en': UiLanguage.en,
        'bs': UiLanguage.bhs,
      };
      for (final MapEntry<String, UiLanguage> e in langs.entries) {
        final AppLocalizations l = await load(e.key);
        for (final int cents in <int>[2490, 101, 2199, 125050, 10390]) {
          expect(
            l.a11ySpokenAmount(cents ~/ 100, '${cents % 100}'),
            Spoken.amount(cents, language: e.value),
            reason: '${e.key} $cents',
          );
        }
      }
    });
  });

  test('typography rules survive the import (12 §1.4, §1.7)', () async {
    final AppLocalizations de = await load('de');
    expect(de.scanLookingUp, 'Gutschein wird geprüft\u00A0…');
    expect(de.balanceCardMasked('6488'), '••••\u00A06488');
    expect(
      de.chargeRateLimited(42),
      'Zu viele Anfragen – wieder möglich in 42\u00A0s',
    );
    expect(
      de.chargeVelocityBodyTime(5),
      'Wieder möglich in 5\u00A0min. Oder einen Manager holen.',
    );
    expect(de.chargeRedeem(nb('€ 24,90')), '${nb('€ 24,90')} einlösen');
  });

  testWidgets('delegates resolve through Localizations', (
    WidgetTester tester,
  ) async {
    late AppLocalizations l;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('hr'),
        delegates: appLocalizationsDelegates,
        child: Builder(
          builder: (BuildContext context) {
            l = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(l.successTitle, 'Iskorišteno');
  });
}
