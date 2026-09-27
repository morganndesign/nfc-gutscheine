import 'package:flutter/widgets.dart';

import '../core/theme/theme.dart';

/// Separator between an action and its amount inside one label (12 §1.7):
/// " · " (U+00B7 with spaces) — also the preferred line break.
const String labelAmountSeparator = ' · ';

/// A centred button label that never truncates (05 §1.0, 12 §1.8).
///
/// On one line when it fits; otherwise it breaks at [labelAmountSeparator]
/// (the separator is removed, the amount keeps its own line and is never
/// split thanks to its no-break space). A label without the separator wraps
/// normally.
class ButtonLabel extends StatelessWidget {
  /// Creates a label.
  const ButtonLabel(this.text, {required this.type, this.color, super.key});

  /// Visible label, e.g. `Redeem full balance · € 32,50`.
  final String text;

  /// `type.label.l` (large) or `type.label` (regular).
  final TypeSpec type;

  /// Label colour.
  final Color? color;

  /// The text to paint for [maxWidth] at [fontSize].
  static String fit(
    String text,
    TextStyle style,
    double maxWidth,
    TextDirection direction,
  ) {
    if (!text.contains(labelAmountSeparator) || !maxWidth.isFinite) {
      return text;
    }
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
    )..layout();
    final bool fits = painter.width <= maxWidth;
    painter.dispose();
    return fits ? text : text.replaceFirst(labelAmountSeparator, '\n');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final TextStyle style = context.textStyles.at(
          type,
          scaledFontSize(context, type),
        );
        return ScaledText(
          fit(text, style, constraints.maxWidth, Directionality.of(context)),
          type: type,
          color: color,
          textAlign: TextAlign.center,
        );
      },
    );
  }
}
