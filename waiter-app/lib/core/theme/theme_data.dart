import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'text_styles.dart';
import 'waiter_theme.dart';

/// Builds the app's [ThemeData] (09 §2.5).
///
/// Material roles are mapped only so that system widgets Flutter draws
/// itself (text selection, cursor, scroll behaviour, Cupertino fallbacks)
/// match the tokens. Components never rely on the Material look: they read
/// [WaiterTheme] via `context.waiter`. Ripples and highlight flashes are
/// switched off (04 §1 decision 5).
ThemeData waiterThemeData(
  Brightness brightness, {
  bool highContrast = false,
  bool boldText = false,
}) {
  final WaiterTheme waiter = WaiterTheme.resolve(
    brightness: brightness,
    highContrast: highContrast,
    boldText: boldText,
  );
  final WaiterColors c = waiter.colors;
  final WaiterTextStyles t = waiter.textStyles;

  final ColorScheme scheme = ColorScheme(
    brightness: brightness,
    primary: c.actionPrimary,
    onPrimary: c.fgOnAccent,
    primaryContainer: c.bgKey,
    onPrimaryContainer: c.fgPrimary,
    secondary: c.bgKey,
    onSecondary: c.fgPrimary,
    secondaryContainer: c.bgKeyPressed,
    onSecondaryContainer: c.fgPrimary,
    tertiary: c.accentSaffron,
    onTertiary: c.fgPrimary,
    error: c.danger,
    onError: c.fgOnDanger,
    errorContainer: c.dangerBg,
    onErrorContainer: c.danger,
    surface: c.bgSurface,
    onSurface: c.fgPrimary,
    onSurfaceVariant: c.fgSecondary,
    surfaceDim: c.bgCanvas,
    surfaceBright: c.bgRaised,
    surfaceContainerLowest: c.bgCanvas,
    surfaceContainerLow: c.bgSurface,
    surfaceContainer: c.bgSurface,
    surfaceContainerHigh: c.bgRaised,
    surfaceContainerHighest: c.bgKey,
    outline: c.borderControl,
    outlineVariant: c.borderSubtle,
    shadow: const Color(0xFF000000),
    scrim: c.scrim,
    inverseSurface: c.inverseBg,
    onInverseSurface: c.inverseFg,
    inversePrimary: c.inverseAction,
    surfaceTint: const Color(0x00000000),
  );

  final TextTheme textTheme = TextTheme(
    displayLarge: t.amountXl,
    displayMedium: t.amountL,
    displaySmall: t.balance,
    headlineLarge: t.titleL,
    headlineMedium: t.titleL,
    headlineSmall: t.titleM,
    titleLarge: t.titleM,
    titleMedium: t.labelL,
    titleSmall: t.label,
    bodyLarge: t.bodyL,
    bodyMedium: t.bodyM,
    bodySmall: t.caption,
    labelLarge: t.label,
    labelMedium: t.caption,
    labelSmall: t.overline,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: TypeTokens.bodyL.fontFamily,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    scaffoldBackgroundColor: c.bgCanvas,
    canvasColor: c.bgCanvas,
    cardColor: c.bgSurface,
    dividerColor: c.borderSubtle,
    disabledColor: c.fgTertiary,
    hintColor: c.fgTertiary,
    focusColor: const Color(0x00000000),
    hoverColor: c.stateHover,
    highlightColor: const Color(0x00000000),
    splashColor: const Color(0x00000000),
    splashFactory: NoSplash.splashFactory,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    iconTheme: IconThemeData(color: c.fgPrimary, size: IconSize.s24.size),
    dividerTheme: DividerThemeData(
      color: c.borderSubtle,
      // 0 = one physical pixel (04 §7 border.width.hairline).
      thickness: 0,
      space: 0,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.fgPrimary,
      selectionColor: c.bgKeyPressed,
      selectionHandleColor: c.fgPrimary,
    ),
    cupertinoOverrideTheme: NoDefaultCupertinoThemeData(
      brightness: brightness,
      primaryColor: c.actionPrimary,
      primaryContrastingColor: c.fgOnAccent,
      scaffoldBackgroundColor: c.bgCanvas,
      barBackgroundColor: c.bgCanvas,
    ),
    extensions: <ThemeExtension<dynamic>>[waiter],
  );
}
