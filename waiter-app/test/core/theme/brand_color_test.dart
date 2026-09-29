import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/theme/brand_color.dart';
import 'package:giftcard_waiter/core/tokens/tokens.dart';

/// 04 §8.6 brand colour handling, including every worked example.
void main() {
  const Color white = Color(0xFFFFFFFF);
  const Color dark = Color(0xFF0A0A0C);
  const WaiterColors light = WaiterColors.light;
  final WaiterElevation lightElev = WaiterElevation.resolve(light);

  BrandCardColors resolve(
    String? hex, {
    WaiterColors colors = WaiterColors.light,
    bool desaturated = false,
  }) {
    return resolveBrandCardColors(
      brandColor: hex,
      colors: colors,
      elevation: WaiterElevation.resolve(colors),
      desaturated: desaturated,
    );
  }

  double round2(double v) => (v * 100).roundToDouble() / 100;

  group('parseBrandColor', () {
    test('accepts 6-digit hex with or without #, any case', () {
      expect(parseBrandColor('#0F172A'), const Color(0xFF0F172A));
      expect(parseBrandColor('0f172a'), const Color(0xFF0F172A));
      expect(parseBrandColor(' #7f1d1d '), const Color(0xFF7F1D1D));
    });

    test('treats other forms as missing', () {
      for (final String? raw in <String?>[
        null,
        '',
        '#FFF',
        'FFF',
        '#FF0F172A',
        'navy',
        '#0F172G',
        'rgb(1,2,3)',
      ]) {
        expect(parseBrandColor(raw), isNull, reason: '$raw');
      }
    });

    test('missing colour renders the ink card', () {
      final BrandCardColors c = resolve('navy');
      expect(c.usedDefault, isTrue);
      expect(c.isContrastFallback, isFalse);
      expect(c.fill, light.brandInk);
    });
  });

  test('sheen stops for ink: #1D2537 → #0E1627', () {
    final BrandCardColors c = resolve('#0F172A');
    expect(c.sheenStart, const Color(0xFF1D2537));
    expect(c.sheenEnd, const Color(0xFF0E1627));
    expect(c.sheen.colors, <Color>[c.sheenStart, c.sheenEnd]);
  });

  group('worked examples (04 §8.6 table)', () {
    // hex, text, worst-case contrast, secondary at 76 %, saffron glyph,
    // light edge.
    final List<(String, Color, double, bool, bool, bool)> rows =
        <(String, Color, double, bool, bool, bool)>[
          ('#0F172A', white, 15.31, true, true, false),
          ('#7F1D1D', white, 8.71, true, true, false),
          ('#14532D', white, 7.79, true, true, false),
          ('#1E3A8A', white, 8.78, true, true, false),
          ('#2563EB', white, 4.68, false, false, false),
          ('#C2410C', white, 4.72, false, false, false),
          ('#DC2626', white, 4.54, false, false, false),
          ('#0D9488', dark, 4.73, false, false, false),
          ('#E8A33D', dark, 8.10, true, false, false),
          ('#F5F0E6', dark, 15.29, true, false, true),
          ('#FFFFFF', dark, 17.36, true, false, true),
        ];
    for (final (
          String hex,
          Color text,
          double contrast,
          bool secondary76,
          bool saffronGlyph,
          bool edge,
        )
        in rows) {
      test(hex, () {
        final BrandCardColors c = resolve(hex);
        expect(c.isContrastFallback, isFalse);
        expect(c.text, text);
        expect(round2(c.textContrast), contrast);
        expect(c.secondaryUsesOpacity, secondary76);
        expect(
          c.secondaryText,
          secondary76 ? text.withValues(alpha: 0.76) : text,
        );
        expect(c.nfcGlyph, saffronGlyph ? light.accentSaffron : text);
        expect(c.needsLightEdge, edge);
        expect(c.outline, edge ? light.borderSubtle : null);
      });
    }

    for (final String hex in <String>['#6B7280', '#808080']) {
      test('$hex falls back to ink', () {
        final BrandCardColors c = resolve(hex);
        expect(c.isContrastFallback, isTrue);
        expect(c.fill, light.brandInk);
        expect(c.text, white);
        expect(c.textContrast, greaterThanOrEqualTo(4.5));
        // The glow uses ink for the fallback case.
        expect(c.shadows, lightElev.cardBrand(light.brandInk));
      });
    }
  });

  test('glow uses the original brand colour at 28 % (light only)', () {
    final BrandCardColors c = resolve('#7F1D1D');
    expect(c.shadows, lightElev.cardBrand(const Color(0xFF7F1D1D)));
    expect(c.shadows.single.color.a, closeTo(0.28, 1e-6));
  });

  group('desaturated states (blocked, expired)', () {
    test('a borderline colour that fails after desaturation falls back', () {
      final BrandCardColors c = resolve('#DC2626', desaturated: true);
      expect(c.isContrastFallback, isTrue);
      expect(c.fill, desaturateOklch(light.brandInk, 0.4));
      expect(c.text, white);
    });

    test('status mapping', () {
      expect(isDesaturatedVoucherStatus('blocked'), isTrue);
      expect(isDesaturatedVoucherStatus('expired'), isTrue);
      expect(isDesaturatedVoucherStatus('active'), isFalse);
    });

    test('chroma −40 % keeps lightness and hue, grey stays grey', () {
      const Color red = Color(0xFFDC2626);
      final Color muted = desaturateOklch(red, 0.4);
      expect(muted, isNot(red));
      expect(relativeLuminance(muted), closeTo(relativeLuminance(red), 0.03));
      // Red stays the dominant channel (hue kept).
      expect(muted.r, greaterThan(muted.g));
      expect(muted.r, greaterThan(muted.b));
      expect(
        desaturateOklch(const Color(0xFF808080), 0.4),
        const Color(0xFF808080),
      );
    });

    test('recomputes text and swaps glow for elev.2', () {
      final BrandCardColors c = resolve('#7F1D1D', desaturated: true);
      expect(c.isContrastFallback, isFalse);
      expect(c.fill, desaturateOklch(const Color(0xFF7F1D1D), 0.4));
      expect(c.textContrast, greaterThanOrEqualTo(4.5));
      expect(c.shadows, lightElev.level2.shadows);
    });
  });

  test('dark theme: same card colour, outline, no shadow', () {
    final BrandCardColors lightCard = resolve('#1E3A8A');
    final BrandCardColors darkCard = resolve(
      '#1E3A8A',
      colors: WaiterColors.dark,
    );
    expect(darkCard.fill, lightCard.fill);
    expect(darkCard.text, lightCard.text);
    expect(darkCard.shadows, isEmpty);
    expect(darkCard.outline, const Color(0xFF26262B));
    // Saffron is evaluated with the dark-theme token.
    expect(darkCard.nfcGlyph, WaiterColors.dark.accentSaffron);
  });

  test('high contrast: secondary card text at 100 %', () {
    final BrandCardColors c = resolve(
      '#0F172A',
      colors: WaiterColors.lightHighContrast,
    );
    expect(c.secondaryUsesOpacity, isFalse);
    expect(c.secondaryText, white);
  });

  test('badge outline only on dark-text cards', () {
    expect(resolve('#0F172A').badgeOutline, isNull);
    final Color? outline = resolve('#F5F0E6').badgeOutline;
    expect(outline, dark.withValues(alpha: 0.16));
  });
}
