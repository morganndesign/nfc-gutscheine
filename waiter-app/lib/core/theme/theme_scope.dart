import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'theme_data.dart';

/// Resolves and applies the app theme from the Menu choice (S14) and the OS
/// accessibility settings (04 §2 theme resolution, §9, §10).
///
/// Place it in `MaterialApp.builder` so it sits below the app's
/// [MediaQuery]:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) =>
///       WaiterThemeScope(mode: themeMode, child: child!),
/// )
/// ```
///
/// - Theme: [mode] (Menu "System / Light / Dark"), else the OS appearance.
/// - High contrast (iOS Increase Contrast / Android High contrast text) and
///   Bold Text are read from the OS and folded into the theme.
/// - Theme switches cross-fade over `motion.duration.base` with
///   `motion.ease.standard`; 160 ms with Reduce Motion (04 §9 rule 2).
/// - The global text scaler is capped at 200 %, the largest per-style cap
///   (04 §3.7); tighter caps are applied by `ScaledText`.
/// - Flutter's own Bold Text override is switched off below this widget,
///   because the one-step weight increase is already in the text styles
///   (04 §10.2) — read `context.waiter.boldText` instead of
///   `MediaQuery.boldTextOf`.
class WaiterThemeScope extends StatelessWidget {
  /// Creates the scope.
  const WaiterThemeScope({required this.mode, required this.child, super.key});

  /// Menu theme choice; [ThemeMode.system] follows the OS appearance.
  final ThemeMode mode;

  /// The app below the theme.
  final Widget child;

  /// Largest per-style text scale cap (body, caption, labels: 200 %).
  static const double maxTextScale = 2.0;

  /// Brightness for [mode] given the OS [platformBrightness].
  static Brightness resolveBrightness(
    ThemeMode mode,
    Brightness platformBrightness,
  ) {
    return switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platformBrightness,
    };
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final Brightness brightness = resolveBrightness(
      mode,
      media.platformBrightness,
    );
    final ThemeData theme = waiterThemeData(
      brightness,
      highContrast: media.highContrast,
      boldText: media.boldText,
    );
    return MediaQuery(
      data: media.copyWith(
        boldText: false,
        textScaler: media.textScaler.clamp(maxScaleFactor: maxTextScale),
      ),
      child: AnimatedTheme(
        data: theme,
        duration: media.disableAnimations
            ? Motion.durationFast
            : Motion.durationBase,
        curve: Motion.easeStandard,
        child: child,
      ),
    );
  }
}
