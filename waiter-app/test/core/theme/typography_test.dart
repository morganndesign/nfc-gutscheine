import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/theme/text_styles.dart';
import 'package:giftcard_waiter/core/tokens/tokens.dart';

/// Minimal TrueType reader for the font tests (cmap lookup, GSUB features,
/// vertical metrics).
class _Font {
  _Font(this.data) {
    final int tables = data.getUint16(4);
    for (int i = 0; i < tables; i++) {
      final int rec = 12 + 16 * i;
      final String tag = String.fromCharCodes(<int>[
        for (int k = 0; k < 4; k++) data.getUint8(rec + k),
      ]);
      _tables[tag] = data.getUint32(rec + 8);
    }
  }

  final ByteData data;
  final Map<String, int> _tables = <String, int>{};

  int table(String tag) => _tables[tag]!;

  /// Whether the cmap maps [codePoint] to a real glyph (format 4 or 12).
  bool hasGlyph(int codePoint) {
    final int cmap = table('cmap');
    final int count = data.getUint16(cmap + 2);
    for (int i = 0; i < count; i++) {
      final int rec = cmap + 4 + 8 * i;
      final int platform = data.getUint16(rec);
      final int sub = cmap + data.getUint32(rec + 4);
      final int format = data.getUint16(sub);
      if (platform == 3 && format == 12) {
        final int groups = data.getUint32(sub + 12);
        for (int g = 0; g < groups; g++) {
          final int at = sub + 16 + 12 * g;
          if (codePoint >= data.getUint32(at) &&
              codePoint <= data.getUint32(at + 4)) {
            return true;
          }
        }
        return false;
      }
    }
    for (int i = 0; i < count; i++) {
      final int rec = cmap + 4 + 8 * i;
      final int sub = cmap + data.getUint32(rec + 4);
      if (data.getUint16(rec) != 3 || data.getUint16(sub) != 4) continue;
      if (codePoint > 0xFFFF) return false;
      final int segs = data.getUint16(sub + 6) ~/ 2;
      final int ends = sub + 14;
      final int starts = ends + 2 * segs + 2;
      final int deltas = starts + 2 * segs;
      final int offsets = deltas + 2 * segs;
      for (int s = 0; s < segs; s++) {
        final int end = data.getUint16(ends + 2 * s);
        if (codePoint > end) continue;
        final int start = data.getUint16(starts + 2 * s);
        if (codePoint < start) return false;
        final int delta = data.getInt16(deltas + 2 * s);
        final int rangeOffset = data.getUint16(offsets + 2 * s);
        final int glyph;
        if (rangeOffset == 0) {
          glyph = (codePoint + delta) & 0xFFFF;
        } else {
          final int at =
              offsets + 2 * s + rangeOffset + 2 * (codePoint - start);
          final int raw = data.getUint16(at);
          glyph = raw == 0 ? 0 : (raw + delta) & 0xFFFF;
        }
        return glyph != 0;
      }
      return false;
    }
    return false;
  }

  Set<String> get gsubFeatures {
    final int? gsub = _tables['GSUB'];
    if (gsub == null) return <String>{};
    final int list = gsub + data.getUint16(gsub + 6);
    final int count = data.getUint16(list);
    return <String>{
      for (int i = 0; i < count; i++)
        String.fromCharCodes(<int>[
          for (int k = 0; k < 4; k++) data.getUint8(list + 2 + 6 * i + k),
        ]),
    };
  }

  int get unitsPerEm => data.getUint16(table('head') + 18);
  int get ascender => data.getInt16(table('hhea') + 4);
  int get descender => data.getInt16(table('hhea') + 6);
  int get capHeight => data.getInt16(table('OS/2') + 88);
}

const List<String> _fontFiles = <String>[
  'assets/fonts/Geist-Regular.ttf',
  'assets/fonts/Geist-Medium.ttf',
  'assets/fonts/Geist-SemiBold.ttf',
  'assets/fonts/Geist-Bold.ttf',
  'assets/fonts/GeistMono-Medium.ttf',
];

/// Glyphs that must render without fallback: 09 §11.1 G6 test string,
/// 10 §2.4 list and 04 §3.1 (ẞ, £, U+00A0, U+2212, U+2022).
const String _coverage =
    'Ää Öö Üü ß Čč Ćć Šš Žž Đđ € 1.234,50 • · – … „x“ '
    'ẞ £ CHF ‚ ‘ ’ ×   − • … 0123456789';

Future<void> _loadFonts() async {
  final FontLoader geist = FontLoader('Geist');
  for (final String f in _fontFiles.take(4)) {
    geist.addFont(rootBundle.load(f));
  }
  await geist.load();
  final FontLoader mono = FontLoader('GeistMono')
    ..addFont(rootBundle.load(_fontFiles.last));
  await mono.load();
}

double _width(String text, TextStyle style) {
  final TextPainter p = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final double w = p.width;
  p.dispose();
  return w;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  group('bundled fonts (09 §3, 10 §2.4)', () {
    for (final String file in _fontFiles) {
      test('$file covers the required glyphs and tnum', () async {
        final _Font font = _Font(await rootBundle.load(file));
        final List<String> missing = <String>[
          for (final int cp in _coverage.runes.toSet())
            if (cp != 0x20 && !font.hasGlyph(cp))
              'U+${cp.toRadixString(16).toUpperCase().padLeft(4, '0')}',
        ];
        expect(missing, isEmpty);
        if (!file.contains('Mono')) {
          expect(font.gsubFeatures, contains('tnum'));
        }
      });
    }

    test('even leading centres the cap height (04 §3.2)', () async {
      for (final String file in _fontFiles) {
        final _Font f = _Font(await rootBundle.load(file));
        // Centre of the glyph box (ascender..descender) == cap-height centre.
        expect(
          (f.ascender + f.descender) / 2,
          closeTo(f.capHeight / 2, f.unitsPerEm * 0.005),
          reason: file,
        );
      }
    });
  });

  group('tabular figures (09 §3)', () {
    test('"1111" and "0000" have identical widths at type.amount.xl', () {
      final TextStyle style = textStyleFor(TypeTokens.amountXl);
      expect(_width('1111', style), _width('0000', style));
      // Without tnum Geist's "1" is narrower, so the test is meaningful.
      final TextStyle proportional = style.copyWith(
        fontFeatures: const <FontFeature>[],
      );
      expect(
        _width('1111', proportional),
        lessThan(_width('0000', proportional)),
      );
    });

    test('digits never shift in keys, captions and balances', () {
      for (final TypeSpec t in <TypeSpec>[
        TypeTokens.key,
        TypeTokens.caption,
        TypeTokens.balance,
        TypeTokens.label,
      ]) {
        final TextStyle s = textStyleFor(t, boldText: true);
        expect(_width('1111', s), _width('8888', s), reason: t.name);
      }
    });
  });

  group('text styles', () {
    test('style fields follow the tokens', () {
      final TextStyle s = textStyleFor(TypeTokens.amountXl);
      expect(s.fontFamily, 'Geist');
      expect(s.fontSize, 64);
      expect(s.fontWeight, FontWeight.w600);
      expect(s.height, closeTo(68 / 64, 1e-12));
      expect(s.letterSpacing, closeTo(-1.6, 1e-12));
      expect(s.leadingDistribution, TextLeadingDistribution.even);
      expect(s.fontFeatures, contains(const FontFeature.tabularFigures()));
      final TextStyle shrunk = textStyleFor(TypeTokens.amountXl, fontSize: 40);
      expect(shrunk.letterSpacing, closeTo(-1.0, 1e-12));
      expect(shrunk.height, s.height);
    });

    test('Bold Text raises weights one step (04 §10.2)', () {
      expect(boldTextWeight(400), 500);
      expect(boldTextWeight(500), 600);
      expect(boldTextWeight(600), 700);
      expect(boldTextWeight(700), 700);
      final WaiterTextStyles bold = WaiterTextStyles(
        boldText: true,
        defaultColor: WaiterColors.light.fgPrimary,
      );
      expect(bold.bodyL.fontWeight, FontWeight.w500);
      expect(bold.caption.fontWeight, FontWeight.w600);
      expect(bold.titleL.fontWeight, FontWeight.w700);
      expect(bold.bodyL.fontSize, 17);
      expect(bold.bodyL.letterSpacing, 0);
    });

    test('of() and at() resolve every token', () {
      final WaiterTextStyles s = WaiterTextStyles(
        boldText: false,
        defaultColor: WaiterColors.dark.fgPrimary,
      );
      for (final TypeSpec t in TypeTokens.all) {
        expect(s.of(t).fontSize, t.fontSize, reason: t.name);
        expect(s.of(t).color, WaiterColors.dark.fgPrimary, reason: t.name);
        expect(s.at(t, 50).fontSize, 50, reason: t.name);
      }
      expect(s.cardNumber.fontFamily, 'GeistMono');
    });
  });

  test('glyph data is loaded from the declared assets', () async {
    final ByteData data = await rootBundle.load(_fontFiles.first);
    expect(data.lengthInBytes, greaterThan(50000));
    expect(Uint8List.sublistView(data, 0, 4), <int>[0, 1, 0, 0]);
  });
}
