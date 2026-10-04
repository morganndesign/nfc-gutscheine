import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/import_strings.dart';

Map<String, Object?> readArb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, Object?>;

Iterable<String> messageKeys(Map<String, Object?> arb) =>
    arb.keys.where((String k) => !k.startsWith('@'));

Set<String> placeholdersOf(String message, String where) =>
    IcuParser(message, where).parse().arguments.toSet();

void main() {
  final Map<String, Map<String, Object?>> arbs = <String, Map<String, Object?>>{
    for (final String l in <String>['en', 'de', 'bs', 'hr', 'sr'])
      l: readArb(l),
  };
  final Map<String, Object?> template = arbs['en']!;

  test('outputs are in sync with 12 §5 (import_strings --check)', () {
    final Map<String, String> outputs = buildOutputs(
      File(masterDocPath).readAsStringSync(),
    );
    // Generated Dart is run through `dart format` by the tool; compare it
    // independent of layout.
    String layoutFree(String code) => code
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r',(?=[)\]])'), '');
    for (final MapEntry<String, String> f in outputs.entries) {
      final String actual = File(f.key).readAsStringSync();
      expect(
        f.key.endsWith('.dart') ? layoutFree(actual) : actual,
        f.key.endsWith('.dart') ? layoutFree(f.value) : f.value,
        reason: '${f.key} is stale — run dart run tool/import_strings.dart',
      );
    }
  });

  test('key count: 418 table keys (12 §5.22) = 415 ARB + 3 OS strings', () {
    expect(messageKeys(template).length, 415);
    final Set<String> plistKeys = <String>{};
    final String strings = File(
      'ios/Runner/en.lproj/InfoPlist.strings',
    ).readAsStringSync();
    for (final Match m in RegExp(
      r'^"([A-Za-z]+)" = ',
      multiLine: true,
    ).allMatches(strings)) {
      plistKeys.add(m.group(1)!);
    }
    expect(plistKeys, <String>{
      'NSCameraUsageDescription',
      'NSFaceIDUsageDescription',
      'NFCReaderUsageDescription',
    });
  });

  test('all ARBs have identical key sets', () {
    final Set<String> keys = messageKeys(template).toSet();
    for (final MapEntry<String, Map<String, Object?>> arb in arbs.entries) {
      expect(messageKeys(arb.value).toSet(), keys, reason: arb.key);
      expect(arb.value['@@locale'], arb.key);
    }
  });

  test('placeholders identical across languages and declared in @metadata', () {
    for (final String key in messageKeys(template)) {
      final Set<String> expected = placeholdersOf(
        template[key]! as String,
        'en $key',
      );
      final Map<String, Object?> meta =
          template['@$key']! as Map<String, Object?>;
      final Map<String, Object?> declared =
          (meta['placeholders'] as Map<String, Object?>?) ??
          <String, Object?>{};
      expect(declared.keys.toSet(), expected, reason: key);
      for (final String locale in <String>['de', 'bs', 'hr', 'sr']) {
        expect(
          placeholdersOf(arbs[locale]![key]! as String, '$locale $key'),
          expected,
          reason: '$locale $key',
        );
      }
    }
  });

  test('placeholder types follow 12 §4.2', () {
    const Set<String> ints = <String>{'count', 'seconds', 'minutes', 'n'};
    for (final String key in messageKeys(template)) {
      final Map<String, Object?> meta =
          template['@$key']! as Map<String, Object?>;
      final Map<String, Object?> declared =
          (meta['placeholders'] as Map<String, Object?>?) ??
          <String, Object?>{};
      for (final MapEntry<String, Object?> p in declared.entries) {
        final String type =
            (p.value! as Map<String, Object?>)['type']! as String;
        if (ints.contains(p.key) || p.key == 'euros') {
          expect(type, 'int', reason: '$key.${p.key}');
        } else {
          expect(type, 'String', reason: '$key.${p.key}');
        }
      }
    }
  });

  test('every key keeps its spec key in the description (09 §6.5)', () {
    for (final String key in messageKeys(template)) {
      final Map<String, Object?> meta =
          template['@$key']! as Map<String, Object?>;
      final String description = meta['description']! as String;
      final String specKey = RegExp(
        r'^Spec key: (\S+) ',
      ).firstMatch(description)!.group(1)!;
      expect(arbKeyOf(specKey), key);
    }
    expect(
      (template['@chargeRedeemFull']! as Map<String, Object?>)['description'],
      startsWith('Spec key: charge.redeemFull (12 §5.8) · Max: 26+amt'),
    );
  });

  test('hr and sr are exact copies of bs (09 §6.5)', () {
    for (final String key in messageKeys(template)) {
      expect(arbs['hr']![key], arbs['bs']![key], reason: key);
      expect(arbs['sr']![key], arbs['bs']![key], reason: key);
    }
  });

  test('aliases of 12 §5.22 are not separate keys', () {
    for (final String alias in <String>[
      'lookupStillLooking',
      'a11yKeypadDoubleZero',
      'a11yKeypadDelete',
      'a11yKeypadDeleteHint',
      'problemSupportCode',
      'suspendedRetry',
    ]) {
      expect(template.containsKey(alias), isFalse, reason: alias);
    }
    // Kept as own keys, same text as their master (12 §5.22).
    expect(template['cameraDeniedAction'], template['commonOpenSettings']);
  });

  test('identical strings across languages are only the intended ones', () {
    // Brand name, pure placeholder patterns and words that are the same in
    // the table (12 §1.3: brand/technology words stay untranslated).
    const Map<String, Set<String>> intended = <String, Set<String>>{
      'de': <String>{
        'appName',
        'commonSupportCode',
        'balanceCardMasked',
        'menuVersion',
        'a11yProblem',
        // Technical small print and environment labels (12 §5.2).
        'startupServer',
        'startupDetail',
        'envStaging',
        'envBadgeDevelopment',
        'envBadgeStaging',
      },
      'bs': <String>{
        'appName',
        'signInEmailLabel',
        'balanceCardMasked',
        'a11yProblem',
        'startupServer',
        'envStaging',
        'envBadgeDevelopment',
        'envBadgeStaging',
      },
    };
    for (final MapEntry<String, Set<String>> lang in intended.entries) {
      final Set<String> same = messageKeys(
        template,
      ).where((String k) => arbs[lang.key]![k] == template[k]).toSet();
      expect(same, lang.value, reason: lang.key);
    }
  });

  test('no exclamation marks, ellipsis is "\u00A0…" (12 §1.7)', () {
    for (final MapEntry<String, Map<String, Object?>> arb in arbs.entries) {
      for (final String key in messageKeys(arb.value)) {
        final String text = arb.value[key]! as String;
        expect(text.contains('!'), isFalse, reason: '${arb.key} $key');
        expect(text.contains('...'), isFalse, reason: '${arb.key} $key');
        expect(text.contains(' …'), isFalse, reason: '${arb.key} $key');
      }
    }
  });
}
