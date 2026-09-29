import 'package:flutter_test/flutter_test.dart';

import '../../../tool/import_strings.dart';

/// Builds a minimal master document with the given §5.1 rows and a key
/// count; all other sections hold one valid row each.
String doc(List<String> rows, {int? count, String aliasRow = ''}) {
  final StringBuffer out = StringBuffer('## 5. Master string table\n\n');
  const String header =
      '| Key | DE | EN | BHS | Max | Notes |\n|---|---|---|---|---|---|';
  int total = rows.length;
  out
    ..writeln('### 5.1 App and common\n')
    ..writeln(header);
  rows.forEach(out.writeln);
  for (int s = 2; s <= 20; s++) {
    out
      ..writeln('\n### 5.$s Section\n')
      ..writeln(header)
      ..writeln('| `s$s.key` | Hallo | Hello | Zdravo | 12 | 12 |');
    total++;
  }
  out
    ..writeln('\n### 5.21 OS usage strings\n')
    ..writeln('| Key | DE | EN | BHS | Notes |\n|---|---|---|---|---|')
    ..writeln('| `camera.purpose` | Kamera DE. | Camera EN. | Kamera BHS. | 03a |')
    ..writeln(
      '| `faceId.purpose` | Face ID. | Face ID EN. | Face ID BHS. | 12 |',
    )
    ..writeln('| `nfc.purpose` | NFC DE. | NFC EN. | NFC BHS. | Phase 4 |');
  total += 3;
  out
    ..writeln('\n### 5.22 Key count and alias register\n')
    ..writeln('The table holds **${count ?? total} keys** (§5.1–5.21).\n')
    ..writeln('| Alias (document) | Master key |\n|---|---|')
    ..writeln(
      aliasRow.isEmpty
          ? '| `lookup.stillLooking` (03b) | `s2.key` |'
          : aliasRow,
    )
    ..writeln('\n## 6. Next');
  return out.toString();
}

Matcher throwsImport(String fragment) => throwsA(
  isA<ImportError>().having(
    (ImportError e) => e.message,
    'message',
    contains(fragment),
  ),
);

void main() {
  test('valid document produces ARBs, InfoPlist.strings and pseudo class', () {
    final Map<String, String> out = buildOutputs(
      doc(<String>[
        r'| `charge.redeemFull` | Alles · {amount} | All \| {amount} | Sve · {amount} | 26+amt | **B** · [link](x.md) |',
        '| `recent.summary` | {count, plural, one {# Einlösung} other {# Einlösungen}} | {count, plural, one {# redemption} other {# redemptions}} | {count, plural, one {# iskorištavanje} few {# iskorištavanja} other {# iskorištavanja}} | 40 | 03b |',
      ]),
    );
    expect(out.keys, contains('lib/l10n/app_en.arb'));
    expect(out.keys, contains('lib/l10n/app_sr.arb'));
    expect(out.keys, contains('ios/Runner/sr-Latn.lproj/InfoPlist.strings'));
    final String en = out['lib/l10n/app_en.arb']!;
    expect(en, contains('"chargeRedeemFull": "All | {amount}"'));
    expect(
      en,
      contains(
        'Spec key: charge.redeemFull (12 §5.1) · Max: 26+amt · '
        'Notes: B · link',
      ),
    );
    expect(en, contains('"type": "int"'));
    expect(
      out['ios/Runner/de.lproj/InfoPlist.strings'],
      contains('"NSCameraUsageDescription" = "Kamera DE.";'),
    );
    expect(
      out['lib/core/l10n/pseudo_app_localizations.g.dart'],
      contains('String recentSummary(int count)'),
    );
  });

  test('arbKeyOf follows 09 §6.5', () {
    expect(arbKeyOf('charge.redeemFull'), 'chargeRedeemFull');
    expect(arbKeyOf('ios.sheet.alert'), 'iosSheetAlert');
    expect(arbKeyOf('getManager'), 'getManager');
    expect(arbKeyOf('intro.1.title.android'), 'intro1TitleAndroid');
  });

  test('normalisation: no-break space before … and in countdowns', () {
    expect(normaliseMessage('Wird geprüft …'), 'Wird geprüft\u00A0…');
    expect(normaliseMessage('in {seconds} s'), 'in {seconds}\u00A0s');
    expect(normaliseMessage('in {minutes} min.'), 'in {minutes}\u00A0min.');
    expect(normaliseMessage('•••• {last4}'), '••••\u00A0{last4}');
  });

  group('fails loudly', () {
    test('malformed row (cell count)', () {
      expect(
        () => buildOutputs(doc(<String>['| `a.b` | A | B | C | 12 |'])),
        throwsImport('malformed row'),
      );
    });

    test('duplicate key', () {
      expect(
        () => buildOutputs(
          doc(<String>[
            '| `a.b` | A | B | C | 12 | 12 |',
            '| `a.b` | A | B | C | 12 | 12 |',
          ]),
        ),
        throwsImport('duplicate key'),
      );
    });

    test('two spec keys mapping to one identifier', () {
      expect(
        () => buildOutputs(
          doc(<String>[
            '| `a.bC` | A | B | C | 12 | 12 |',
            '| `a.b.c` | A | B | C | 12 | 12 |',
          ]),
        ),
        throwsImport('both map to'),
      );
    });

    test('missing language cell', () {
      expect(
        () => buildOutputs(doc(<String>['| `a.b` | A |  | C | 12 | 12 |'])),
        throwsImport('missing language cell'),
      );
    });

    test('placeholder mismatch across languages', () {
      expect(
        () => buildOutputs(
          doc(<String>['| `a.b` | {amount} | {amt} | {amount} | 12 | 12 |']),
        ),
        throwsImport('placeholder mismatch'),
      );
    });

    test('wrong plural categories for BHS', () {
      expect(
        () => buildOutputs(
          doc(<String>[
            '| `a.b` | {n, plural, one {x} other {y}} | {n, plural, one {x} other {y}} | {n, plural, one {x} other {y}} | 12 | 12 |',
          ]),
        ),
        throwsImport('plural "n" must use exactly'),
      );
    });

    test('invalid ICU', () {
      expect(
        () => buildOutputs(
          doc(<String>['| `a.b` | {amount | {amount} | {amount} | 12 | 12 |']),
        ),
        throwsImport('invalid ICU'),
      );
    });

    test('key count differs from §5.22', () {
      expect(
        () => buildOutputs(
          doc(<String>['| `a.b` | A | B | C | 12 | 12 |'], count: 272),
        ),
        throwsImport('key count mismatch'),
      );
    });

    test('alias implemented as a key', () {
      expect(
        () => buildOutputs(
          doc(<String>['| `lookup.stillLooking` | A | B | C | 12 | 12 |']),
        ),
        throwsImport('must not be implemented'),
      );
    });

    test('alias kept as its own key is allowed', () {
      expect(
        buildOutputs(
          doc(
            <String>['| `camera.denied.action` | A | B | C | 12 | 12 |'],
            aliasRow:
                '| `camera.denied.action` (03a) — kept as its own key, same '
                'text as | `s2.key` |',
          ),
        ),
        isNotEmpty,
      );
    });

    test('markdown or exclamation mark inside a message', () {
      expect(
        () =>
            buildOutputs(doc(<String>['| `a.b` | **A** | B | C | 12 | 12 |'])),
        throwsImport('markdown'),
      );
      expect(
        () => buildOutputs(doc(<String>['| `a.b` | A! | B | C | 12 | 12 |'])),
        throwsImport('exclamation'),
      );
    });
  });
}
