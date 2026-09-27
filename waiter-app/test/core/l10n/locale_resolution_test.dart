import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/l10n/l10n.dart';

void main() {
  group('resolveAppLocale — 09 §6.5 / brief §7', () {
    test('de* → de', () {
      for (final Locale l in const <Locale>[
        Locale('de'),
        Locale('de', 'AT'),
        Locale('de', 'CH'),
        Locale('de', 'DE'),
      ]) {
        expect(resolveAppLocale(l), const Locale('de'), reason: '$l');
      }
    });

    test('en* → en', () {
      for (final Locale l in const <Locale>[
        Locale('en'),
        Locale('en', 'US'),
        Locale('en', 'GB'),
        Locale('en', 'IN'),
      ]) {
        expect(resolveAppLocale(l), const Locale('en'), reason: '$l');
      }
    });

    test('bs / hr / sr in any script or region → bs (BHS Latin)', () {
      for (final Locale l in <Locale>[
        const Locale('bs'),
        const Locale('bs', 'BA'),
        const Locale('hr'),
        const Locale('hr', 'HR'),
        const Locale('hr', 'BA'),
        const Locale('sr'),
        const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'),
        const Locale.fromSubtags(
          languageCode: 'sr',
          scriptCode: 'Cyrl',
          countryCode: 'RS',
        ),
        const Locale.fromSubtags(languageCode: 'bs', scriptCode: 'Cyrl'),
      ]) {
        expect(resolveAppLocale(l), const Locale('bs'), reason: '$l');
        expect(uiLanguageOf(l), UiLanguage.bhs);
      }
    });

    test('anything else → en', () {
      for (final Locale l in const <Locale>[
        Locale('fr', 'FR'),
        Locale('it'),
        Locale('sl'),
        Locale('tr'),
        Locale('me'),
      ]) {
        expect(resolveAppLocale(l), const Locale('en'), reason: '$l');
      }
      expect(resolveAppLocale(null), const Locale('en'));
    });
  });

  group('callbacks', () {
    test('list callback uses the phone language (first entry) only', () {
      expect(
        localeListResolutionCallback(const <Locale>[
          Locale('fr'),
          Locale('de'),
        ], supportedLocales),
        const Locale('en'),
      );
      expect(
        localeListResolutionCallback(const <Locale>[
          Locale('hr', 'HR'),
          Locale('en'),
        ], supportedLocales),
        const Locale('bs'),
      );
      expect(
        localeListResolutionCallback(null, supportedLocales),
        const Locale('en'),
      );
      expect(
        localeListResolutionCallback(const <Locale>[], supportedLocales),
        const Locale('en'),
      );
    });

    test('single-locale callback', () {
      expect(
        localeResolutionCallback(const Locale('de', 'AT'), supportedLocales),
        const Locale('de'),
      );
    });

    test('resolved locales are always supported', () {
      for (final Locale l in appLocaleOf.values) {
        expect(supportedLocales, contains(l));
      }
    });

    test('supportedLocales declares de, en, bs, hr, sr (09 §6.5)', () {
      expect(
        supportedLocales.map((Locale l) => l.toLanguageTag()).toSet(),
        <String>{'de', 'en', 'bs', 'hr', 'sr'},
      );
    });
  });

  group('UiLanguage.fromLanguageCode', () {
    test('mapping', () {
      expect(UiLanguage.fromLanguageCode('DE'), UiLanguage.de);
      expect(UiLanguage.fromLanguageCode('sr'), UiLanguage.bhs);
      expect(UiLanguage.fromLanguageCode('pl'), UiLanguage.en);
      expect(UiLanguage.fromLanguageCode(null), UiLanguage.en);
    });
  });
}
