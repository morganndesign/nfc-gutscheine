import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'layout.dart';
import 'text_styles.dart';
import 'waiter_theme.dart';

/// Shorthands for reading the app theme (09 §2.5).
extension WaiterThemeContext on BuildContext {
  /// The active [WaiterTheme]. Throws if no Waiter theme is installed —
  /// every screen is built below `waiterThemeData` / `WaiterThemeScope`.
  WaiterTheme get waiter {
    final WaiterTheme? theme = Theme.of(this).extension<WaiterTheme>();
    if (theme == null) {
      throw FlutterError(
        'No WaiterTheme found. Build the app with waiterThemeData() or '
        'wrap it in WaiterThemeScope.',
      );
    }
    return theme;
  }

  /// Semantic colours of the active theme.
  WaiterColors get colors => waiter.colors;

  /// Named text styles of the active theme.
  WaiterTextStyles get textStyles => waiter.textStyles;

  /// Elevation of the active theme.
  WaiterElevation get elevation => waiter.elevation;

  /// Size classes and margins of the current window (04 §4, 08 §1).
  WaiterLayout get layout => WaiterLayout.of(this);
}
