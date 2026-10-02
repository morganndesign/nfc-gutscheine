/// Brand-colour handling for the BalanceCard (04 §8.6, 05 §3.1).
///
/// Pure functions: given the restaurant's `brand_color`, the active theme
/// and whether the card state is desaturated, they return every colour the
/// card needs. The caller logs the non-fatal diagnostic
/// `brand_color_contrast_fallback` once per restaurant per install when
/// [BrandCardColors.isContrastFallback] is true.
library;

import 'dart:math' as math;

import 'dart:ui' show Brightness;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

import '../tokens/tokens.dart';

final RegExp _brandHex = RegExp(r'^#?([0-9a-fA-F]{6})$');

/// Parses `brand_color` (04 §8.6 "Input"): six hex digits with or without
/// `#`, case-insensitive. Anything else (3- or 8-digit hex, names, empty,
/// malformed) is treated as missing and returns `null`.
Color? parseBrandColor(String? raw) {
  if (raw == null) return null;
  final RegExpMatch? match = _brandHex.firstMatch(raw.trim());
  if (match == null) return null;
  return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
}

int _channel(double v) => (v * 255).round().clamp(0, 255);

/// 8-bit sRGB channels of [c].
List<int> _rgb(Color c) => <int>[_channel(c.r), _channel(c.g), _channel(c.b)];

double _linear(int channel) {
  final double c = channel / 255;
  return c <= 0.04045
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

/// WCAG 2.x relative luminance of an opaque colour (04 §8.2).
double relativeLuminance(Color color) {
  final List<int> c = _rgb(color);
  return 0.2126 * _linear(c[0]) +
      0.7152 * _linear(c[1]) +
      0.0722 * _linear(c[2]);
}

/// WCAG contrast ratio between two opaque colours (04 §8.2).
double contrastRatio(Color a, Color b) {
  final double la = relativeLuminance(a);
  final double lb = relativeLuminance(b);
  final double hi = math.max(la, lb);
  final double lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// [foreground] at [opacity] composited over opaque [background], rounded
/// to 8-bit sRGB (how the pixel is actually rendered).
Color compositeOver(Color foreground, double opacity, Color background) {
  final List<int> f = _rgb(foreground);
  final List<int> b = _rgb(background);
  return Color.fromARGB(
    255,
    (f[0] * opacity + b[0] * (1 - opacity)).round(),
    (f[1] * opacity + b[1] * (1 - opacity)).round(),
    (f[2] * opacity + b[2] * (1 - opacity)).round(),
  );
}

/// Mixes [color] [amount] toward [target] in sRGB, rounded to 8 bit — the
/// sheen stops of 04 §8.6 (ink #0F172A → #1D2537 / #0E1627).
Color mixSrgb(Color color, Color target, double amount) {
  final List<int> c = _rgb(color);
  final List<int> t = _rgb(target);
  return Color.fromARGB(
    255,
    (c[0] + (t[0] - c[0]) * amount).round(),
    (c[1] + (t[1] - c[1]) * amount).round(),
    (c[2] + (t[2] - c[2]) * amount).round(),
  );
}

double _cbrt(double v) =>
    v < 0 ? -math.pow(-v, 1 / 3).toDouble() : math.pow(v, 1 / 3).toDouble();

double _encode(double v) {
  final double c = v.clamp(0.0, 1.0);
  return c <= 0.0031308 ? 12.92 * c : 1.055 * math.pow(c, 1 / 2.4) - 0.055;
}

/// Reduces the OKLCH chroma of [color] by [reduction] (0.4 = 40 %), keeping
/// lightness and hue (04 §8.6 desaturated states). Out-of-gamut results are
/// clipped per channel.
Color desaturateOklch(Color color, double reduction) {
  final List<int> c = _rgb(color);
  final double r = _linear(c[0]);
  final double g = _linear(c[1]);
  final double b = _linear(c[2]);

  final double l_ = _cbrt(
    0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
  );
  final double m_ = _cbrt(
    0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
  );
  final double s_ = _cbrt(
    0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b,
  );

  final double lightness =
      0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_;
  final double keep = 1 - reduction;
  final double oa =
      (1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_) * keep;
  final double ob =
      (0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_) * keep;

  final double l2 = math
      .pow(lightness + 0.3963377774 * oa + 0.2158037573 * ob, 3)
      .toDouble();
  final double m2 = math
      .pow(lightness - 0.1055613458 * oa - 0.0638541728 * ob, 3)
      .toDouble();
  final double s2 = math
      .pow(lightness - 0.0894841775 * oa - 1.2914855480 * ob, 3)
      .toDouble();

  return Color.fromARGB(
    255,
    _channel(
      _encode(4.0767416621 * l2 - 3.3077115913 * m2 + 0.2309699292 * s2),
    ),
    _channel(
      _encode(-1.2684380046 * l2 + 2.6097574011 * m2 - 0.3413193965 * s2),
    ),
    _channel(
      _encode(-0.0041960863 * l2 - 0.7034186147 * m2 + 1.7076147010 * s2),
    ),
  );
}

/// Whether a voucher status renders desaturated: blocked and expired do; a
/// zero balance does not (04 §8.6, brief §5).
bool isDesaturatedVoucherStatus(String status) => status == 'blocked' || status == 'expired' || status == 'refunded';

/// Everything the BalanceCard paints, resolved from `brand_color`
/// (04 §8.6, 05 §3.1).
@immutable
class BrandCardColors {
  /// Creates a resolved set.
  const BrandCardColors({
    required this.fill,
    required this.sheenStart,
    required this.sheenEnd,
    required this.text,
    required this.textContrast,
    required this.secondaryText,
    required this.secondaryUsesOpacity,
    required this.nfcGlyph,
    required this.isContrastFallback,
    required this.usedDefault,
    required this.needsLightEdge,
    required this.outline,
    required this.badgeOutline,
  });

  /// Card colour after default/fallback and desaturation.
  final Color fill;

  /// Sheen start stop (top-left): [fill] 6 % toward white.
  final Color sheenStart;

  /// Sheen end stop (bottom-right): [fill] 6 % toward black.
  final Color sheenEnd;

  /// Primary card text (name, balance): #FFFFFF or #0A0A0C.
  final Color text;

  /// Worst-case contrast of [text] against the sheen (≥ 4.5).
  final double textContrast;

  /// Secondary card text (overline, masked number, validity): [text] at
  /// 76 % when that still reaches 4.5 : 1 (and not in high contrast),
  /// otherwise [text].
  final Color secondaryText;

  /// Whether [secondaryText] is [text] at `opacity.cardSecondary`.
  final bool secondaryUsesOpacity;

  /// NFC glyph colour: saffron if ≥ 3 : 1 against both stops, else [text].
  final Color nfcGlyph;

  /// Neither text candidate reached 4.5 : 1; the card fell back to
  /// `color.brand.ink`. Log `brand_color_contrast_fallback` once.
  final bool isContrastFallback;

  /// `brand_color` was missing or malformed; `color.brand.ink` was used.
  final bool usedDefault;

  /// The end stop has < 1.5 : 1 against `color.bg.canvas`: very light card
  /// that needs a 1-px outline in light theme (04 §8.6 step 9).
  final bool needsLightEdge;

  /// 1-px outline colour, or `null` for none: `color.card.borderDark` in
  /// dark theme, `color.border.subtle` for light edges in light theme.
  final Color? outline;

  /// StatusBadge outline on a dark-text card: [text] at 16 % (05 §3.2).
  final Color? badgeOutline;

  /// The card fill gradient, top-left → bottom-right (04 §8.6 "Sheen").
  LinearGradient get sheen => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[sheenStart, sheenEnd],
  );
}

const Color _white = Color(0xFFFFFFFF);
const Color _black = Color(0xFF000000);

class _TextChoice {
  const _TextChoice(this.color, this.contrast, this.worstStop);
  final Color color;
  final double contrast;
  final Color worstStop;
}

/// Steps 2–5 of 04 §8.6: the candidate with the higher worst-case contrast
/// (tie → white), or `null` when neither reaches 4.5 : 1.
_TextChoice? _chooseText(Color start, Color end) {
  const Color light = BalanceCardTokens.textLight;
  const Color dark = BalanceCardTokens.textDark;
  final double a = contrastRatio(light, start);
  final double b = contrastRatio(dark, end);
  final _TextChoice choice = a >= b
      ? _TextChoice(light, a, start)
      : _TextChoice(dark, b, end);
  return choice.contrast >= BalanceCardTokens.minTextContrast ? choice : null;
}

/// Resolves the BalanceCard colours (04 §8.6 steps 1–9, desaturation,
/// shadow and dark-theme rules).
///
/// [desaturated] is true for blocked and expired vouchers (see
/// [isDesaturatedVoucherStatus]).
BrandCardColors resolveBrandCardColors({
  required String? brandColor,
  required WaiterColors colors,
  required WaiterElevation elevation,
  bool desaturated = false,
}) {
  final Color? parsed = parseBrandColor(brandColor);
  final Color original = parsed ?? colors.brandInk;

  Color shade(Color c) =>
      desaturated ? desaturateOklch(c, BalanceCardTokens.desaturation) : c;

  Color fill = shade(original);
  Color start = mixSrgb(fill, _white, BalanceCardTokens.sheenMix);
  Color end = mixSrgb(fill, _black, BalanceCardTokens.sheenMix);
  _TextChoice? choice = _chooseText(start, end);

  bool fallback = false;
  if (choice == null) {
    fallback = true;
    fill = shade(colors.brandInk);
    start = mixSrgb(fill, _white, BalanceCardTokens.sheenMix);
    end = mixSrgb(fill, _black, BalanceCardTokens.sheenMix);
    // Ink reaches ≥ 15 : 1 with white; the fallback always resolves.
    choice =
        _chooseText(start, end) ??
        _TextChoice(
          BalanceCardTokens.textLight,
          contrastRatio(BalanceCardTokens.textLight, start),
          start,
        );
  }

  final Color text = choice.color;

  // Step 7: secondary text at 76 % only if the composite keeps 4.5 : 1;
  // high contrast always uses 100 % (04 §10.1).
  final Color composite = compositeOver(
    text,
    Opacities.cardSecondary,
    choice.worstStop,
  );
  final bool useOpacity =
      !colors.isHighContrast &&
      contrastRatio(composite, choice.worstStop) >=
          BalanceCardTokens.minTextContrast;

  // Step 8: saffron arcs only when ≥ 3 : 1 against both stops.
  final Color saffron = colors.accentSaffron;
  final double glyphContrast = math.min(
    contrastRatio(saffron, start),
    contrastRatio(saffron, end),
  );
  final Color glyph = glyphContrast >= BalanceCardTokens.minGlyphContrast
      ? saffron
      : text;

  // Step 9: light-card edge.
  final bool lightEdge =
      contrastRatio(end, colors.bgCanvas) < BalanceCardTokens.lightEdgeContrast;

  final bool dark = colors.brightness == Brightness.dark;
  final Color? outline = dark
      ? elevation.cardOutline
      : (lightEdge ? colors.borderSubtle : null);

  return BrandCardColors(
    fill: fill,
    sheenStart: start,
    sheenEnd: end,
    text: text,
    textContrast: choice.contrast,
    secondaryText: useOpacity
        ? text.withValues(alpha: Opacities.cardSecondary)
        : text,
    secondaryUsesOpacity: useOpacity,
    nfcGlyph: glyph,
    isContrastFallback: fallback,
    usedDefault: parsed == null,
    needsLightEdge: lightEdge,
    outline: outline,
    badgeOutline: text == BalanceCardTokens.textDark
        ? text.withValues(alpha: StatusBadgeTokens.darkTextOutlineOpacity)
        : null,
  );
}
