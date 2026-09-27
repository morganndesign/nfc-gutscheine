import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';

/// The fixed rows of S07 (03b §2.4, 13 · R23): everything below the
/// BalanceCard has a fixed height per height class so the card is the only
/// flexible element and the keypad never moves. Heights of text rows follow
/// the OS text scale (07 §6.1); the helper line reserves a second line from
/// 150 % (03b §2.6).
@immutable
class ChargeMetrics {
  const ChargeMetrics._({
    required this.compact,
    required this.amountLine,
    required this.helperLine,
    required this.bottomInset,
  });

  /// Metrics for the window of [context].
  factory ChargeMetrics.of(BuildContext context) {
    final WaiterLayout layout = context.layout;
    final bool compact = layout.heightClass.isCompact;
    final TypeSpec amount = compact ? TypeTokens.amountL : TypeTokens.amountXl;
    final double helperLines =
        MediaQuery.textScalerOf(context).scale(1) >= _twoLineHelperScale
        ? 2
        : 1;
    return ChargeMetrics._(
      compact: compact,
      amountLine: scaledFontSize(context, amount) * amount.height,
      helperLine:
          clampedScaler(
            context,
            TypeTokens.bodyM,
          ).scale(TypeTokens.bodyM.lineHeight) *
          helperLines,
      bottomInset: MediaQuery.paddingOf(context).bottom,
    );
  }

  /// Text scale from which the helper line may wrap (03b §2.6).
  static const double _twoLineHelperScale = 1.5;

  /// Compact height class (< 700 pt available).
  final bool compact;

  /// Line box of the AmountDisplay (`type.amount.xl` 68 / `type.amount.l`
  /// 52 at 100 %).
  final double amountLine;

  /// Reserved helper line (22 at 100 %).
  final double helperLine;

  /// Bottom safe-area inset.
  final double bottomInset;

  /// TopRow → card: `space.1`, compact `space.0`.
  double get topGap => compact ? Space.s0 : Space.s1;

  /// Card → AmountDisplay: `space.3`, compact `space.2`.
  double get cardGap => compact ? Space.s2 : Space.s3;

  /// Helper → assist row: `space.2`, compact `space.1`.
  double get helperGap => compact ? Space.s1 : Space.s2;

  /// Assist row → keypad and keypad → button: `space.3`, compact `space.2`.
  double get rowGap => compact ? Space.s2 : Space.s3;

  /// Assist row (QuickAmountChip visual height).
  double get assistRow => Sizes.chip;

  /// Helper line + gap + assist row: the area a S07 warning banner
  /// occupies (03b §2.17).
  double get messageArea => helperLine + helperGap + assistRow;

  /// AmountDisplay + helper + assist row.
  double get amountBlock => amountLine + messageArea;

  /// Space below the button: `space.2` above a home indicator, `space.4`
  /// without one and at compact height (03b §2.4).
  double get bottomGap => !compact && bottomInset > 0 ? Space.s2 : Space.s4;

  /// Card size for [density] inside [maxWidth] with [availableHeight]:
  /// ID-1 ratio from the available height, capped at [maxHeight]
  /// (05 §3.1); the strip takes the full width at 88 pt.
  static Size cardSize(
    BalanceCardDensity density, {
    required double maxWidth,
    required double availableHeight,
    required double maxHeight,
  }) {
    if (density == BalanceCardDensity.compact) {
      return Size(maxWidth, BalanceCardTokens.compactHeight);
    }
    final double width = math.min(
      maxWidth,
      math.min(availableHeight, maxHeight) * BalanceCardTokens.aspectRatio,
    );
    return Size(width, width / BalanceCardTokens.aspectRatio);
  }

  /// Width of [cardSize] (the S06 card slot shares the geometry).
  static double cardWidth(
    BalanceCardDensity density, {
    required double maxWidth,
    required double availableHeight,
    double maxHeight = Sizes.balanceCardMaxHeight,
  }) => cardSize(
    density,
    maxWidth: maxWidth,
    availableHeight: availableHeight,
    maxHeight: maxHeight,
  ).width;
}

/// Height cap of the ID-1 card: 220 pt on phones, 277 pt in the
/// single-column tablet layout (03b §2.20), 303 pt in the tablet left pane
/// (08 §4.2).
double cardMaxHeight(WaiterLayout layout, {required bool pane}) {
  if (!layout.widthClass.isTablet) return Sizes.balanceCardMaxHeight;
  return pane ? _paneCardMaxHeight : _tabletCardMaxHeight;
}

const double _tabletCardMaxHeight = 277;
const double _paneCardMaxHeight = 303;

/// Tablet landscape two-pane rule of 08 §4.2: window ≥ 856 pt wide and wider
/// than high.
bool isTwoPane(WaiterLayout layout) =>
    layout.widthClass.isTablet &&
    layout.size.width >= _twoPaneMinWidth &&
    layout.size.width > layout.size.height;

/// 08 §4.2 two-pane threshold.
const double _twoPaneMinWidth = 856;

/// 08 §4.2 right pane (amount, keypad, CTA).
const double twoPaneRightWidth = 400;

/// 08 §4.2 left pane bounds and gutter.
const double twoPaneLeftMin = 360;
const double twoPaneLeftMax = 480;
const double twoPaneGutter = Space.s8;

/// 08 §3.1 / §3.2 single-column content width on tablets.
const double tabletColumnWidth = 480;
