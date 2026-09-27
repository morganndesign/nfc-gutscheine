import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../components/components.dart';
import '../../core/theme/theme.dart';
import '../charge/charge_metrics.dart';

/// Where S07 Charge places its BalanceCard, computed from S07's own row
/// metrics (03b §2.4, 08 §3.2 / §4.2, 13 · R23), so the S05 looking-up
/// skeleton occupies exactly that slot and the hand-over is a morph, not a
/// jump (03a §6.4, §6.15).
@immutable
class ChargeCardSlot {
  const ChargeCardSlot._({
    required this.top,
    required this.width,
    required this.density,
    this.start,
  });

  /// Computes the slot for the window of [context]; [top] is measured from
  /// the bottom edge of the TopBar.
  factory ChargeCardSlot.of(BuildContext context) {
    final WaiterLayout layout = context.layout;
    final ChargeMetrics metrics = ChargeMetrics.of(context);

    if (isTwoPane(layout)) {
      // Tablet landscape: the card fills the left pane, vertically centred.
      final double inner =
          layout.size.width - layout.viewPadding.horizontal - 2 * layout.margin;
      final double pane = (inner - twoPaneGutter - twoPaneRightWidth).clamp(
        twoPaneLeftMin,
        twoPaneLeftMax,
      );
      return ChargeCardSlot._(
        top: 0,
        width: pane,
        density: BalanceCardDensity.full,
        start:
            (layout.size.width - pane - twoPaneGutter - twoPaneRightWidth) / 2,
      );
    }

    final double columnWidth = layout.widthClass.isTablet
        ? math.min(layout.contentWidth, tabletColumnWidth)
        : layout.contentWidth;
    final double keypad = 4 * layout.keyHeight + 3 * KeypadTokens.gap;
    final double fixed =
        TopBarTokens.height +
        metrics.topGap +
        metrics.cardGap +
        metrics.amountBlock +
        metrics.rowGap +
        keypad +
        metrics.rowGap +
        layout.largeButtonHeight +
        metrics.bottomGap;
    final double available = math.max(0, layout.availableHeight - fixed);
    final BalanceCardDensity density = BalanceCardDensity.choose(
      context,
      availableHeight: available,
    );
    final double width = ChargeMetrics.cardWidth(
      density,
      maxWidth: columnWidth,
      availableHeight: available,
    );
    final double height = density == BalanceCardDensity.compact
        ? BalanceCardTokens.compactHeight
        : WaiterLayout.idOneCardHeight(width);
    // The card is bottom-anchored on S07: leftover space goes above it.
    return ChargeCardSlot._(
      top: metrics.topGap + math.max(0, available - height),
      width: width,
      density: density,
    );
  }

  /// Distance from the bottom of the TopBar to the card's top edge.
  final double top;

  /// Card width (the ID-1 height follows from it; the strip is 88 pt).
  final double width;

  /// Full ID-1 card or the compact strip (13 · R11).
  final BalanceCardDensity density;

  /// Leading offset in the tablet two-pane layout (card vertically
  /// centred); `null` = centred column.
  final double? start;
}
