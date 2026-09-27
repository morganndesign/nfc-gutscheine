import 'package:flutter/widgets.dart';

import '../../core/theme/theme.dart';

/// Emphasis variants of a token style used by several components.
extension TextEmphasis on TextStyle {
  /// Weight 600 (titles in banners, amounts in rows, initials), one step
  /// heavier under Bold Text (04 §10.2).
  TextStyle semiBold({required bool boldText}) {
    const int base = 600;
    final int weight = boldText ? boldTextWeight(base) : base;
    return copyWith(fontWeight: FontWeight.values[weight ~/ 100 - 1]);
  }

  /// Tabular figures (04 §3.3) for times, totals and support codes.
  TextStyle get tabular =>
      copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]);
}
