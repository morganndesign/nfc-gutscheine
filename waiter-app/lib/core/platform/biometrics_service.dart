import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

import 'system_service.dart';

/// Which biometric the device offers — selects the `.faceId` / `.touchId` /
/// `.android` copy variants (12 §4.1).
enum BiometricKind { faceId, touchId, android, none }

enum BiometricOutcome {
  success,

  /// Cancelled or not recognised (P11) — stay on S03/S04.
  failed,

  /// OS lockout (P12) — offer the password.
  lockedOut,

  /// Nothing enrolled (P10).
  notEnrolled,

  /// Enrolled biometrics changed since they were enabled (P13).
  enrollmentChanged,
}

/// Biometric unlock of the **app UI** (09 §7.6): biometrics with the OS
/// passcode / device credential as fallback. The token is never gated by it.
class BiometricsService {
  BiometricsService({required SystemService system, LocalAuthentication? auth})
      : _system = system,
        _auth = auth ?? LocalAuthentication();

  final SystemService _system;
  final LocalAuthentication _auth;

  Future<BiometricKind> kind({required bool isIos}) async {
    try {
      if (!await _auth.isDeviceSupported()) return BiometricKind.none;
      final List<BiometricType> types = await _auth.getAvailableBiometrics();
      if (types.isEmpty) return BiometricKind.none;
      if (!isIos) return BiometricKind.android;
      return types.contains(BiometricType.face) ? BiometricKind.faceId : BiometricKind.touchId;
    } on LocalAuthException {
      return BiometricKind.none;
    }
  }

  /// Current enrolment fingerprint, stored when biometrics are enabled.
  Future<String?> enrollment() => _system.biometricEnrollment();

  /// Shows the OS prompt. [expectedEnrollment] is the fingerprint stored when
  /// the waiter enabled biometrics; a different value means a new face or
  /// finger was added → password required (P13).
  Future<BiometricOutcome> authenticate({
    required String reason,
    required String androidTitle,
    required String androidSubtitle,
    String? expectedEnrollment,
  }) async {
    if (expectedEnrollment != null) {
      final String? current = await _system.biometricEnrollment();
      if (current != expectedEnrollment) return BiometricOutcome.enrollmentChanged;
    }
    try {
      final bool ok = await _auth.authenticate(
        localizedReason: reason,
        authMessages: <AuthMessages>[
          AndroidAuthMessages(signInTitle: androidTitle, signInHint: androidSubtitle),
          const IOSAuthMessages(),
        ],
        persistAcrossBackgrounding: true,
      );
      return ok ? BiometricOutcome.success : BiometricOutcome.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.noBiometricsEnrolled || LocalAuthExceptionCode.noCredentialsSet => BiometricOutcome.notEnrolled,
        LocalAuthExceptionCode.biometricLockout || LocalAuthExceptionCode.temporaryLockout => BiometricOutcome.lockedOut,
        _ => BiometricOutcome.failed,
      };
    }
  }
}
