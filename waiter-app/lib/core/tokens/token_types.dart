/// Value types used by the generated token file (`tokens.g.dart`).
///
/// The token *data* is generated from `tokens/waiter.tokens.json`
/// (09 §2.1); these classes only describe its shape so that the generated
/// constants stay small and readable.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// One `type.*` token (04 §3.2, 09 §3).
///
/// Sizes and line heights are in logical points. [letterSpacingPercent] is
/// the brief's tracking in percent of the font size; the absolute value is
/// derived per size by [letterSpacingAt] (09 §3 "Letter spacing").
@immutable
class TypeSpec {
  /// Creates a typography token.
  const TypeSpec({
    required this.name,
    required this.fontFamily,
    required this.fontWeight,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacingPercent,
    required this.tabularFigures,
    required this.maxScale,
    this.uppercase = false,
    this.minSizeAfterShrink,
  });

  /// Token name, e.g. `type.amount.xl`.
  final String name;

  /// Bundled family name as registered in `pubspec.yaml` (`Geist`,
  /// `GeistMono`).
  final String fontFamily;

  /// Weight on the 100–900 scale before any Bold Text adjustment.
  final int fontWeight;

  /// Base size in pt at 100 % text size.
  final double fontSize;

  /// Fixed line box height in pt at [fontSize].
  final double lineHeight;

  /// Tracking in percent of the font size (e.g. −2.5 for `type.amount.xl`).
  final double letterSpacingPercent;

  /// Whether `tnum` is applied (04 §3.3).
  final bool tabularFigures;

  /// Maximum text scale factor before the style stops growing (04 §3.7).
  final double maxScale;

  /// Whether the text is rendered uppercase (`type.overline`).
  final bool uppercase;

  /// Minimum size for shrink-to-fit, or `null` when the style never shrinks
  /// (04 §3.7: amounts min 40, card number min 20).
  final double? minSizeAfterShrink;

  /// Line height as a ratio of the font size (Flutter `TextStyle.height`).
  double get height => lineHeight / fontSize;

  /// Absolute letter spacing in pt at [size] (tracking % × size).
  double letterSpacingAt(double size) => size * letterSpacingPercent / 100;

  /// Absolute letter spacing at the base [fontSize].
  double get letterSpacing => letterSpacingAt(fontSize);

  /// Whether the style shrinks to fit once the scale cap is reached.
  bool get shrinksToFit => minSizeAfterShrink != null;

  @override
  String toString() => 'TypeSpec($name)';
}

/// A single elevation step for one theme (04 §6).
///
/// Light theme: [shadows] only. Dark theme: no shadows; separation is a
/// lighter [surface] step plus a hairline [outline] (04 §6.2).
@immutable
class ElevationLevel {
  /// Creates an elevation step.
  const ElevationLevel({
    this.shadows = const <BoxShadow>[],
    this.surface,
    this.outline,
  });

  /// Flat: no shadow, no surface change, no outline (`elev.0`).
  static const ElevationLevel none = ElevationLevel();

  /// Shadows to paint (empty in dark theme).
  final List<BoxShadow> shadows;

  /// Surface step colour in dark theme, `null` when the level keeps the
  /// component's own fill.
  final Color? surface;

  /// Hairline outline colour in dark theme, `null` for none.
  final Color? outline;

  /// Linear interpolation for theme cross-fades (04 §9 rule 2).
  ///
  /// A colour that exists on one side only switches at the midpoint, so
  /// both ends reproduce their inputs exactly.
  static ElevationLevel lerp(ElevationLevel a, ElevationLevel b, double t) {
    Color? mix(Color? x, Color? y) =>
        x == null || y == null ? (t < 0.5 ? x : y) : Color.lerp(x, y, t);
    return ElevationLevel(
      shadows: BoxShadow.lerpList(a.shadows, b.shadows, t) ?? const [],
      surface: mix(a.surface, b.surface),
      outline: mix(a.outline, b.outline),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ElevationLevel &&
      listEquals(other.shadows, shadows) &&
      other.surface == surface &&
      other.outline == outline;

  @override
  int get hashCode => Object.hash(Object.hashAll(shadows), surface, outline);
}

/// iOS feedback generator used by a haptic token (11 §5.1).
enum IosHapticGenerator {
  /// `UIImpactFeedbackGenerator`.
  impact,

  /// `UISelectionFeedbackGenerator`.
  selection,

  /// `UINotificationFeedbackGenerator`.
  notification,
}

/// `UIImpactFeedbackGenerator.FeedbackStyle` values used by the app.
enum IosImpactStyle {
  /// `.light`.
  light,

  /// `.medium`.
  medium,

  /// `.rigid`.
  rigid,
}

/// `UINotificationFeedbackGenerator.FeedbackType` values.
enum IosNotificationType {
  /// `.success`.
  success,

  /// `.warning`.
  warning,

  /// `.error`.
  error,
}

/// Android `HapticFeedbackConstants` used by the app (11 §2.1, §5.2).
enum AndroidHapticConstant {
  /// `KEYBOARD_TAP` (API 8).
  keyboardTap('KEYBOARD_TAP'),

  /// `CLOCK_TICK` (API 21).
  clockTick('CLOCK_TICK'),

  /// `CONFIRM` (API 30).
  confirm('CONFIRM'),

  /// `REJECT` (API 30).
  reject('REJECT');

  const AndroidHapticConstant(this.platformName);

  /// Constant name in `android.view.HapticFeedbackConstants`.
  final String platformName;
}

/// An Android vibration waveform: `[off, on, off, on, …]` in ms starting
/// with the initial delay, plus amplitudes 0–255 (11 §2.1 notation).
@immutable
class VibrationWaveform {
  /// Creates a waveform.
  const VibrationWaveform({required this.timingsMs, required this.amplitudes});

  /// Segment durations in ms.
  final List<int> timingsMs;

  /// Segment amplitudes 0–255 (ignored without amplitude control).
  final List<int> amplitudes;
}

/// An Android one-shot vibration (`VibrationEffect.createOneShot`).
@immutable
class VibrationOneShot {
  /// Creates a one-shot vibration.
  const VibrationOneShot({required this.durationMs, required this.amplitude});

  /// Duration in ms.
  final int durationMs;

  /// Amplitude 0–255.
  final int amplitude;
}

/// iOS mapping of a haptic token (11 §5.1).
@immutable
class IosHapticSpec {
  /// Creates an iOS mapping.
  const IosHapticSpec({
    required this.generator,
    this.impactStyle,
    this.notificationType,
    this.intensities = const <double>[],
  });

  /// Generator class.
  final IosHapticGenerator generator;

  /// Impact style when [generator] is [IosHapticGenerator.impact].
  final IosImpactStyle? impactStyle;

  /// Notification type when [generator] is [IosHapticGenerator.notification].
  final IosNotificationType? notificationType;

  /// Impact intensities; one per step for multi-step tokens (hold ticks).
  final List<double> intensities;
}

/// Android mapping of a haptic token for one API range (11 §5.2).
@immutable
class AndroidHapticSpec {
  /// Creates an Android mapping.
  const AndroidHapticSpec({
    this.constants = const <AndroidHapticConstant>[],
    this.waveform,
    this.waveformDelayMs = 0,
    this.oneShot,
  });

  /// View-based constants; one per step for multi-step tokens.
  final List<AndroidHapticConstant> constants;

  /// Waveform to play (after [waveformDelayMs] when [constants] also fire).
  final VibrationWaveform? waveform;

  /// Delay between the constant and the waveform ("+ 40 ms pattern").
  final int waveformDelayMs;

  /// One-shot vibration (API 28–29 fallback for card detected).
  final VibrationOneShot? oneShot;
}

/// Full platform mapping of a `haptic.*` token.
@immutable
class HapticSpec {
  /// Creates a haptic mapping.
  const HapticSpec({
    required this.severity,
    required this.ios,
    required this.androidApi30,
    required this.androidFallback,
    this.stepsMs = const <int>[],
  });

  /// Relative severity used by the 80 ms rule (11 T6): the later,
  /// higher-severity event wins.
  final int severity;

  /// iOS mapping.
  final IosHapticSpec ios;

  /// Android API 30+ mapping.
  final AndroidHapticSpec androidApi30;

  /// Android API 28–29 mapping.
  final AndroidHapticSpec androidFallback;

  /// Step times in ms for multi-step tokens (hold ticks at 200/400/600 ms).
  final List<int> stepsMs;
}

/// Data of a `sound.*` token (11 §2.2, §6).
@immutable
class SoundSpec {
  /// Creates a sound token.
  const SoundSpec({
    required this.file,
    required this.maxDuration,
    required this.loudnessLufsM,
    required this.truePeakDbtp,
  });

  /// Base file name without extension (binding, 11 §6.1).
  final String file;

  /// Maximum length of the file.
  final Duration maxDuration;

  /// Maximum momentary loudness in LUFS-M.
  final double loudnessLufsM;

  /// Maximum true peak in dBTP.
  final double truePeakDbtp;

  /// iOS bundle file (`ios/Runner/Sounds/<file>.caf`).
  String get iosFileName => '$file.caf';

  /// Android raw resource name (`res/raw/<file>.ogg`).
  String get androidResourceName => file;
}
