import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// Width classes of the app window (08 §1.1; margins 04 §4.2).
enum WidthClass {
  /// < 360 pt: small phones, enlarged display size, narrow split screen.
  compact,

  /// 360–399 pt: iPhone SE / mini / standard, most Android phones.
  standard,

  /// 400–599 pt: Plus / Max, large Android, iPad Slide Over.
  large,

  /// ≥ 600 pt: tablets, unfolded foldables.
  tablet;

  /// Class for a window [width] in pt.
  static WidthClass of(double width) {
    if (width >= LayoutTokens.widthClassTablet) return WidthClass.tablet;
    if (width >= LayoutTokens.widthClassRegular) return WidthClass.large;
    if (width >= LayoutTokens.widthClassStandard) return WidthClass.standard;
    return WidthClass.compact;
  }

  /// Side margin: 20 / 20 / 24 / 32 (04 §4.2, 08 §2).
  double get margin => switch (this) {
    WidthClass.compact || WidthClass.standard => LayoutTokens.marginCompact,
    WidthClass.large => LayoutTokens.marginRegular,
    WidthClass.tablet => LayoutTokens.marginTablet,
  };

  /// Column count of the layout grid (04 §4.2).
  int get columns => this == WidthClass.tablet
      ? LayoutTokens.gridTabletColumns
      : LayoutTokens.gridPhoneColumns;

  /// Gutter of the layout grid (04 §4.2).
  double get gutter => this == WidthClass.tablet
      ? LayoutTokens.gridTabletGutter
      : LayoutTokens.gridPhoneGutter;

  /// Whether this is the tablet class.
  bool get isTablet => this == WidthClass.tablet;
}

/// Height classes (04 §4.3, 08 §1.2): compact below 700 pt.
enum HeightClass {
  /// < 700 pt: keys 64, CTA 56, `BalanceCard / compact`, `type.amount.l`
  /// metrics for the AmountDisplay (08 §1.2).
  compact,

  /// ≥ 700 pt.
  regular;

  /// Class for an available height in pt.
  static HeightClass of(double height) => height < LayoutTokens.compactHeight
      ? HeightClass.compact
      : HeightClass.regular;

  /// Whether this is the compact class.
  bool get isCompact => this == HeightClass.compact;
}

/// Layout metrics of the current window (04 §4, 08 §1–2).
///
/// Classes are computed from the app window, not the physical screen
/// (08 §1). Height excludes the safe-area insets (04 §4.3).
@immutable
class WaiterLayout {
  /// Computes the layout for a window [size] and its safe-area [viewPadding].
  factory WaiterLayout.fromWindow(Size size, EdgeInsets viewPadding) {
    final double available = size.height - viewPadding.top - viewPadding.bottom;
    return WaiterLayout._(
      size: size,
      viewPadding: viewPadding,
      widthClass: WidthClass.of(size.width),
      heightClass: HeightClass.of(available),
      availableHeight: available,
    );
  }

  const WaiterLayout._({
    required this.size,
    required this.viewPadding,
    required this.widthClass,
    required this.heightClass,
    required this.availableHeight,
  });

  /// Layout for the window of [context].
  static WaiterLayout of(BuildContext context) => WaiterLayout.fromWindow(
    MediaQuery.sizeOf(context),
    MediaQuery.viewPaddingOf(context),
  );

  /// Window size in pt.
  final Size size;

  /// Safe-area insets (system bars, notch, home indicator).
  final EdgeInsets viewPadding;

  /// Width class.
  final WidthClass widthClass;

  /// Height class.
  final HeightClass heightClass;

  /// Window height minus the top and bottom safe-area insets.
  final double availableHeight;

  /// Side margin, added inside the safe area (04 §4.2).
  double get margin => widthClass.margin;

  /// Maximum width of single-column content: 560 pt on tablets (04 §4.2),
  /// unbounded on phones.
  double get maxContentWidth =>
      widthClass.isTablet ? LayoutTokens.maxContentTablet : double.infinity;

  /// Width available for content: window minus side insets and margins,
  /// capped at [maxContentWidth].
  double get contentWidth {
    final double inner =
        size.width - viewPadding.left - viewPadding.right - 2 * margin;
    return math.max(0, math.min(inner, maxContentWidth));
  }

  /// Body text measure: 480 pt on tablets (04 §3.5), else [contentWidth].
  double get textMeasure => widthClass.isTablet
      ? math.min(contentWidth, LayoutTokens.textMeasureTablet)
      : contentWidth;

  /// Keypad width: content width, max 400 pt (05 §2.1, 08 §2).
  double get keypadWidth => math.min(contentWidth, LayoutTokens.maxKeypad);

  /// Keypad key height: 72 pt, 64 pt at compact height (04 §4.3).
  double get keyHeight => heightClass.isCompact ? Sizes.keyCompact : Sizes.key;

  /// Large button / CTA height: 64 pt, 56 pt at compact height (04 §4.3).
  double get largeButtonHeight =>
      heightClass.isCompact ? Sizes.buttonLCompact : Sizes.buttonL;

  /// Bottom padding of the CTA block (04 §4.4): 16 pt above a home
  /// indicator / gesture bar, 20 pt on devices without one.
  double get ctaBottomPadding => viewPadding.bottom > 0
      ? LayoutTokens.ctaBottomWithHomeIndicator
      : LayoutTokens.ctaBottomWithoutHomeIndicator;

  /// Height of the ID-1 BalanceCard at [width]: width ÷ 1.586, max 220 pt
  /// on phones (05 §3.1).
  static double idOneCardHeight(double width) => math.min(
    width / BalanceCardTokens.aspectRatio,
    Sizes.balanceCardMaxHeight,
  );

  /// Whether the window is below the 320 × 568 pt minimum (08 §1.3).
  bool get isBelowMinimumWindow =>
      size.width < LayoutTokens.minWindowWidth ||
      size.height < LayoutTokens.minWindowHeight;

  @override
  bool operator ==(Object other) =>
      other is WaiterLayout &&
      other.size == size &&
      other.viewPadding == viewPadding;

  @override
  int get hashCode => Object.hash(size, viewPadding);
}
