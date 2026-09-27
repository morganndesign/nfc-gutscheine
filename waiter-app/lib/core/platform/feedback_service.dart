import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../diagnostics/diagnostic_log.dart';
import '../storage/settings_store.dart';
import '../tokens/tokens.dart';
import 'channels.dart';

/// The only way the app produces haptics and sounds (09 §2.5, §7.8; 11).
/// Components and controllers name a token; the platform side maps it.
///
/// Rules applied here (11 §4): keys coalesce to one haptic per 50 ms (T5);
/// two different haptics closer than 80 ms — the later one plays only if it is
/// at least as severe (T6). The Menu switches gate everything (09 §7.8).
class FeedbackService {
  FeedbackService({
    required SettingsStore settings,
    MethodChannel channel = WaiterChannels.feedback,
    DiagnosticLog? log,
    Duration Function()? monotonicNow,
  })  : _settings = settings,
        _channel = channel,
        _log = log,
        _now = monotonicNow ?? _stopwatchNow;

  static final Stopwatch _clock = Stopwatch()..start();
  static Duration _stopwatchNow() => _clock.elapsed;

  final SettingsStore _settings;
  final MethodChannel _channel;
  final DiagnosticLog? _log;
  final Duration Function() _now;

  Duration? _lastAt;
  HapticToken? _last;

  /// Loads the four sounds into the low-latency player (09 §7.8).
  Future<void> preload() => _invoke('preload', <String, Object?>{
        'sounds': SoundToken.values.map((SoundToken s) => s.spec.file).toList(),
      });

  /// Warms up the generator for an expected event (e.g. when Redeem is pressed)
  /// to stay within 30 ms latency.
  void prepare(HapticToken token) {
    if (!_settings.haptics || defaultTargetPlatform != TargetPlatform.iOS) return;
    unawaited(_invoke('prepare', _iosPayload(token, 0)));
  }

  /// Plays [token]. [step] selects the intensity/constant of multi-step tokens
  /// (`haptic.holdTick` 0, 1, 2).
  void haptic(HapticToken token, {int step = 0}) {
    if (!_settings.haptics) return;

    final Duration now = _now();
    final Duration? last = _lastAt;
    if (last != null) {
      final Duration since = now - last;
      if (token == HapticToken.key && _last == HapticToken.key && since < HapticToken.keyCoalesce) return;
      if (token != _last && since < HapticToken.minSpacing && token.spec.severity < (_last?.spec.severity ?? 0)) return;
    }
    _lastAt = now;
    _last = token;

    final Map<String, Object?> payload = defaultTargetPlatform == TargetPlatform.iOS
        ? _iosPayload(token, step)
        : _androidPayload(token, step);
    unawaited(_invoke('haptic', payload));
  }

  /// Plays [token] unless sounds are off in the Menu. The platform also skips
  /// it for the silent switch (iOS) or silent/vibrate ringer mode (Android).
  void sound(SoundToken token) {
    if (!_settings.sound) return;
    unawaited(_invoke('sound', <String, Object?>{'file': token.spec.file}));
  }

  /// Haptic and sound of one event, in the order 11 §4 requires (haptic first).
  void both(HapticToken haptic, SoundToken sound) {
    this.haptic(haptic);
    this.sound(sound);
  }

  Map<String, Object?> _iosPayload(HapticToken token, int step) {
    final IosHapticSpec ios = token.spec.ios;
    final List<double> intensities = ios.intensities;
    return <String, Object?>{
      'generator': ios.generator.name,
      'style': ios.impactStyle?.name,
      'notification': ios.notificationType?.name,
      'intensity': intensities.isEmpty ? 1.0 : intensities[step.clamp(0, intensities.length - 1)],
    };
  }

  Map<String, Object?> _androidPayload(HapticToken token, int step) {
    Map<String, Object?> encode(AndroidHapticSpec spec) {
      final List<AndroidHapticConstant> constants = spec.constants;
      return <String, Object?>{
        'constant': constants.isEmpty ? null : constants[step.clamp(0, constants.length - 1)].platformName,
        // Multi-step constants play only the selected step, without the waveform.
        'waveform': spec.waveform == null || constants.length > 1
            ? null
            : <String, Object?>{'timings': spec.waveform!.timingsMs, 'amplitudes': spec.waveform!.amplitudes},
        'waveformDelayMs': spec.waveformDelayMs,
        'oneShot': spec.oneShot == null
            ? null
            : <String, Object?>{'durationMs': spec.oneShot!.durationMs, 'amplitude': spec.oneShot!.amplitude},
      };
    }

    return <String, Object?>{'api30': encode(token.spec.androidApi30), 'fallback': encode(token.spec.androidFallback)};
  }

  Future<void> _invoke(String method, Map<String, Object?> arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (e) {
      _log?.record('feedback.error', '$method ${e.code}');
    } on MissingPluginException {
      // Widget tests run without the platform side.
    }
  }
}
