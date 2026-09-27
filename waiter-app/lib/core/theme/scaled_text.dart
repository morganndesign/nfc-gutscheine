import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'context_ext.dart';
import 'text_styles.dart';

/// The OS text scaler clamped to the cap of [type] (04 §3.7, 09 §3).
///
/// The OS factor (iOS Dynamic Type, Android font scale including Android 14
/// non-linear scaling) is applied first; the result is then capped at
/// `type.maxScale` × base size. [maxScale] can tighten the cap further, e.g.
/// 1.3 for all text inside the BalanceCard (04 §3.7).
TextScaler clampedScaler(
  BuildContext context,
  TypeSpec type, {
  double? maxScale,
}) {
  final double cap = maxScale == null
      ? type.maxScale
      : math.min(type.maxScale, maxScale);
  return MediaQuery.textScalerOf(context).clamp(maxScaleFactor: cap);
}

/// The font size [type] renders at in [context] before any shrink-to-fit.
double scaledFontSize(BuildContext context, TypeSpec type, {double? maxScale}) {
  return clampedScaler(context, type, maxScale: maxScale).scale(type.fontSize);
}

/// Shrink-to-fit (04 §3.7): starting at [startSize], steps the size down in
/// [step] pt until [widthAt] fits [maxWidth], never below [minSize].
///
/// The last step lands exactly on [minSize] when a full step would pass it.
/// At [minSize] the text is used even if it still overflows — amounts are
/// never truncated; the spec guarantees the longest amount fits at 40 pt.
double shrinkToFitSize({
  required double startSize,
  required double minSize,
  required double maxWidth,
  required double Function(double size) widthAt,
  double step = TypeTokens.shrinkStep,
}) {
  assert(step > 0, 'step must be positive');
  double size = startSize;
  if (!maxWidth.isFinite) return size;
  while (size > minSize && widthAt(size) > maxWidth) {
    size = math.max(minSize, size - step);
  }
  return size;
}

/// Builds the spans of a [ScaledText.rich] for a size [factor]
/// (rendered size ÷ base size of the primary token).
///
/// Use `styles(TypeTokens.currencyXl)` etc. so every span scales by the same
/// factor — the currency symbol keeps its 60 % ratio and baseline (04 §3.4).
/// Only [TextSpan]s are supported (the tree is measured for shrink-to-fit).
typedef ScaledSpanBuilder = TextSpan Function(ScaledStyles styles);

/// Style lookup handed to a [ScaledSpanBuilder].
@immutable
class ScaledStyles {
  /// Creates a lookup for [factor].
  const ScaledStyles(this.factor, this._styles);

  /// Rendered size ÷ base size of the primary token.
  final double factor;

  final WaiterTextStyles _styles;

  /// The style of [type] at `type.fontSize × factor`, with tracking
  /// recomputed for that size.
  TextStyle call(TypeSpec type, {Color? color}) =>
      _styles.at(type, type.fontSize * factor, color: color);

  /// A token-relative length (e.g. the currency gap in em) at this factor.
  double scale(double value) => value * factor;
}

/// Text that honours the per-style text-scale clamps of 04 §3.7 and, for
/// amounts, balances and the card number, shrink-to-fit.
///
/// - Caps: body/caption/labels 200 %, titles 150 %, amounts and balance
///   130 %, overline 130 %, key 120 %, card number 130 %.
/// - Shrink-to-fit ([TypeSpec.shrinksToFit]): once capped, the size steps
///   down 2 pt at a time until the text fits its width, minimum 40 pt
///   (amounts) or 20 pt (card number). Such text is never truncated or
///   wrapped: [maxLines] is forced to 1 and no ellipsis is applied.
/// - `type.overline` is rendered uppercase.
/// - Bold Text is already folded into the theme's weights; the text is
///   painted with [RichText], so Flutter's own bold-text override does not
///   apply a second time.
class ScaledText extends StatelessWidget {
  /// Plain text in the style of [type].
  const ScaledText(
    String this.data, {
    required this.type,
    super.key,
    this.color,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.softWrap = true,
    this.maxScale,
    this.semanticsLabel,
  }) : spanBuilder = null;

  /// Mixed-style text (e.g. amount digits plus a 60 % currency symbol)
  /// scaled as one unit by the clamp and shrink-to-fit rules of [type].
  const ScaledText.rich(
    ScaledSpanBuilder this.spanBuilder, {
    required this.type,
    super.key,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.softWrap = true,
    this.maxScale,
    this.semanticsLabel,
  }) : data = null,
       color = null;

  /// Plain text, or `null` for [ScaledText.rich].
  final String? data;

  /// Span builder, or `null` for plain text.
  final ScaledSpanBuilder? spanBuilder;

  /// Primary type token; its clamp and shrink rules apply to the whole text.
  final TypeSpec type;

  /// Text colour; defaults to `color.fg.primary`.
  final Color? color;

  /// Horizontal alignment.
  final TextAlign textAlign;

  /// Maximum number of lines (ignored for shrink-to-fit styles).
  final int? maxLines;

  /// Overflow behaviour (ignored for shrink-to-fit styles).
  final TextOverflow overflow;

  /// Whether the text wraps (ignored for shrink-to-fit styles).
  final bool softWrap;

  /// Additional scale cap, e.g. 1.3 inside the BalanceCard.
  final double? maxScale;

  /// Accessibility label replacing the visual string (e.g. spoken amounts,
  /// 04 §3.8).
  final String? semanticsLabel;

  TextSpan _span(WaiterTextStyles styles, double size) {
    final double factor = size / type.fontSize;
    if (spanBuilder != null) {
      return spanBuilder!(ScaledStyles(factor, styles));
    }
    final String text = type.uppercase ? data!.toUpperCase() : data!;
    return TextSpan(
      text: text,
      style: styles.at(type, size, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final WaiterTextStyles styles = context.textStyles;
    final double start = scaledFontSize(context, type, maxScale: maxScale);
    final TextDirection direction = Directionality.of(context);

    if (!type.shrinksToFit) {
      return _paint(_span(styles, start), maxLines, overflow, softWrap);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double size = shrinkToFitSize(
          startSize: start,
          minSize: math.min(start, type.minSizeAfterShrink!),
          maxWidth: constraints.maxWidth,
          widthAt: (double s) => _measure(_span(styles, s), direction),
        );
        return _paint(_span(styles, size), 1, TextOverflow.visible, false);
      },
    );
  }

  static double _measure(TextSpan span, TextDirection direction) {
    final TextPainter painter = TextPainter(
      text: span,
      textDirection: direction,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
    )..layout();
    final double width = painter.width;
    painter.dispose();
    return width;
  }

  Widget _paint(
    TextSpan span,
    int? lines,
    TextOverflow textOverflow,
    bool wrap,
  ) {
    final Widget text = RichText(
      text: span,
      textAlign: textAlign,
      maxLines: lines,
      overflow: textOverflow,
      softWrap: wrap,
      textScaler: TextScaler.noScaling,
    );
    if (semanticsLabel == null) return text;
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: text,
    );
  }
}
