import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'text_styles.dart';

/// The app's own theme, carried as a [ThemeExtension] (09 §2.5).
///
/// Components read colours, elevation and text styles from here — never
/// from Material's colour scheme or text theme, which exist only for the
/// few system widgets Flutter draws itself.
@immutable
class WaiterTheme extends ThemeExtension<WaiterTheme> {
  /// Creates a theme from resolved parts.
  const WaiterTheme({
    required this.colors,
    required this.elevation,
    required this.textStyles,
  });

  /// Resolves the theme for a brightness, the high-contrast modifier
  /// (04 §10.1, 09 §2.4) and Bold Text (04 §10.2).
  factory WaiterTheme.resolve({
    required Brightness brightness,
    bool highContrast = false,
    bool boldText = false,
  }) {
    final WaiterColors colors = WaiterColors.resolve(
      brightness,
      highContrast: highContrast,
    );
    return WaiterTheme(
      colors: colors,
      elevation: WaiterElevation.resolve(colors),
      textStyles: WaiterTextStyles(
        boldText: boldText,
        defaultColor: colors.fgPrimary,
      ),
    );
  }

  /// Semantic colours of the active theme.
  final WaiterColors colors;

  /// Shadows (light) or surface steps and outlines (dark).
  final WaiterElevation elevation;

  /// Named text styles.
  final WaiterTextStyles textStyles;

  /// Active brightness.
  Brightness get brightness => colors.brightness;

  /// Whether the high-contrast modifier is active (04 §10.1).
  bool get isHighContrast => colors.isHighContrast;

  /// Whether Bold Text raised all weights by one step (04 §10.2).
  bool get boldText => textStyles.boldText;

  /// Input boundary width: 1 pt, 2 pt in high contrast (04 §10.1).
  double get inputBorderWidth =>
      isHighContrast ? Borders.widthControlHc : Borders.widthDefault;

  /// Focus ring width: 2 pt, 3 pt in high contrast (04 §7, 13 · R17).
  double get focusRingWidth =>
      isHighContrast ? Borders.widthFocusHc : Borders.widthFocus;

  /// Whether SecondaryButton, keypad keys, chips and the avatar gain a
  /// 1-pt `color.border.control` outline (04 §10.1).
  bool get outlinesControls => isHighContrast;

  /// NFC arc colour: saffron, `color.nfc.arc.hc` in high contrast
  /// (04 §10.1, 05 §3.4).
  Color get nfcArc => isHighContrast ? colors.nfcArcHc : colors.accentSaffron;

  /// StatusBanner body style: `type.body.m`, weight 600 in high contrast
  /// (04 §10.1, brief), raised once more by Bold Text.
  TextStyle get statusBannerBody {
    if (!isHighContrast) return textStyles.bodyM;
    return textStyles.bodyM.copyWith(
      fontWeight: boldText ? FontWeight.w700 : FontWeight.w600,
    );
  }

  /// Illustration `line` role colour (10 §4.5): `fg.secondary`, which the
  /// high-contrast modifier already maps to `fg.primary`.
  Color get illustrationLine => colors.fgSecondary;

  /// Illustration `accent` role colour (10 §4.5): saffron, unchanged in
  /// high contrast.
  Color get illustrationAccent => colors.accentSaffron;

  @override
  WaiterTheme copyWith({
    WaiterColors? colors,
    WaiterElevation? elevation,
    WaiterTextStyles? textStyles,
  }) {
    return WaiterTheme(
      colors: colors ?? this.colors,
      elevation: elevation ?? this.elevation,
      textStyles: textStyles ?? this.textStyles,
    );
  }

  @override
  WaiterTheme lerp(covariant WaiterTheme? other, double t) {
    if (other == null) return this;
    return WaiterTheme(
      colors: WaiterColors.lerp(colors, other.colors, t),
      elevation: WaiterElevation.lerp(elevation, other.elevation, t),
      textStyles: WaiterTextStyles.lerp(textStyles, other.textStyles, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WaiterTheme &&
      other.colors == colors &&
      other.elevation == elevation &&
      other.textStyles == textStyles;

  @override
  int get hashCode => Object.hash(colors, elevation, textStyles);
}
