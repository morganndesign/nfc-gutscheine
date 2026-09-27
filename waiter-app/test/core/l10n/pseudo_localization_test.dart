import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/l10n/l10n.dart';
import 'package:giftcard_waiter/core/l10n/pseudo_app_localizations.g.dart';
import 'package:giftcard_waiter/core/l10n/pseudo_transform.dart';

void main() {
  group('pseudoLocalize (09 §6.5)', () {
    test('accents letters and expands by at least 40 %', () {
      final String out = pseudoLocalize('Karte scannen');
      expect(out, startsWith('[Ķàŕţé šçàññéñ ~'));
      expect(out, endsWith(']'));
      expect(out.length, greaterThanOrEqualTo(('Karte scannen'.length * 1.4)));
    });

    test('short strings still get a visible marker', () {
      expect(pseudoLocalize('OK'), '[ÖĶ ~]');
      expect(pseudoLocalize(''), '[ ~]');
    });

    test('placeholder values are kept intact', () {
      final String out = pseudoLocalize('${pseudoMarker(0)} einlösen', <String>[
        '€\u00A024,90',
      ]);
      expect(out, startsWith('[€\u00A024,90 éîñļöšéñ '));
    });
  });

  group('PseudoLocalizationsDelegate', () {
    test('wraps the real strings of every locale', () async {
      for (final Locale locale in supportedLocales) {
        final AppLocalizations l = await const PseudoLocalizationsDelegate()
            .load(locale);
        expect(l, isA<PseudoAppLocalizations>());
        expect(l.localeName, locale.languageCode);
        expect(l.appName, startsWith('[ĜîfţÇàŕď Ŵàîţéŕ'));
      }
    });

    test('plurals still select by count; placeholders untouched', () async {
      final AppLocalizations l = await const PseudoLocalizationsDelegate().load(
        const Locale('bs'),
      );
      final String out = l.recentSummary(3, 'Trattoria');
      expect(out, contains('3 îšķöŕîšţàvàñĵà'));
      expect(out, contains('Trattoria'));
    });

    test('is supported exactly where AppLocalizations is', () {
      const PseudoLocalizationsDelegate d = PseudoLocalizationsDelegate();
      expect(d.isSupported(const Locale('de')), isTrue);
      expect(d.isSupported(const Locale('fr')), isFalse);
      expect(d.shouldReload(d), isFalse);
    });
  });
}
