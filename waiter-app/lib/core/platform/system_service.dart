import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'channels.dart';

/// Hardware facts for `User-Agent` and the device name sent at sign-in.
@immutable
class DeviceFacts {
  const DeviceFacts({required this.platform, required this.osVersion, required this.model, required this.isTablet});

  /// `android` or `ios` (as `POST /auth/token` expects).
  final String platform;
  final String osVersion;

  /// Marketing name where known ("Pixel 7", "iPhone 15").
  final String model;
  final bool isTablet;
}

/// Small native helpers that no candidate package covers exactly (09 §7.5,
/// §7.6): device facts, app settings, biometric enrolment fingerprint.
class SystemService {
  SystemService({MethodChannel channel = WaiterChannels.system}) : _channel = channel;

  final MethodChannel _channel;

  Future<DeviceFacts> deviceFacts() async {
    final Map<Object?, Object?> m =
        await _channel.invokeMapMethod<Object?, Object?>('deviceFacts') ?? const <Object?, Object?>{};
    return DeviceFacts(
      platform: m['platform'] as String? ?? (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'),
      osVersion: m['osVersion'] as String? ?? '',
      model: m['model'] as String? ?? '',
      isTablet: m['isTablet'] == true,
    );
  }

  /// Opens the app's page in the system settings (camera denied, S16).
  Future<void> openAppSettings() => _channel.invokeMethod<void>('openAppSettings');

  /// An opaque value that changes when the enrolled biometric set changes
  /// (iOS: evaluated policy domain state; Android: a Keystore key invalidated
  /// by new enrolment). Null when no biometrics are enrolled (09 §7.5).
  Future<String?> biometricEnrollment() => _channel.invokeMethod<String>('biometricEnrollment');

  /// Resets the Android enrolment key after the waiter signed in with the
  /// password again (P13).
  Future<void> resetBiometricEnrollment() => _channel.invokeMethod<void>('resetBiometricEnrollment');
}
