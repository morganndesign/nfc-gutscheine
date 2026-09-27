import '../../core/api/models.dart';
import '../../core/platform/biometrics_service.dart';
import '../../core/state/session_controller.dart';
import '../../core/theme/theme.dart';
import '../../l10n/app_localizations.dart';

/// Glyph and strings of the biometric capability variant (03a §3 variant
/// table, §4 `unlock.button.*`; 10 §3 #28–29; 12 §5.4–§5.5, P10).
/// A device without a recognised kind uses the generic Android wording.
extension BiometricCopy on BiometricKind {
  /// `scan-face` for Face ID, `fingerprint` for Touch ID and Android.
  WaiterIcon get glyph => this == BiometricKind.faceId ? WaiterIcon.scanFace : WaiterIcon.fingerprint;

  /// S03 title.
  String title(AppLocalizations l) => switch (this) {
    BiometricKind.faceId => l.biometricsTitleFaceId,
    BiometricKind.touchId => l.biometricsTitleTouchId,
    BiometricKind.android || BiometricKind.none => l.biometricsTitleAndroid,
  };

  /// S03 PrimaryButton.
  String enable(AppLocalizations l) => switch (this) {
    BiometricKind.faceId => l.biometricsEnableFaceId,
    BiometricKind.touchId => l.biometricsEnableTouchId,
    BiometricKind.android || BiometricKind.none => l.biometricsEnableAndroid,
  };

  /// S04 PrimaryButton.
  String unlock(AppLocalizations l) => switch (this) {
    BiometricKind.faceId => l.unlockButtonFaceId,
    BiometricKind.touchId => l.unlockButtonTouchId,
    BiometricKind.android || BiometricKind.none => l.unlockButtonAndroid,
  };

  /// P10: nothing enrolled.
  String notEnrolled(AppLocalizations l) => switch (this) {
    BiometricKind.faceId => l.biometricsNotEnrolledFaceId,
    BiometricKind.touchId => l.biometricsNotEnrolledTouchId,
    BiometricKind.android || BiometricKind.none => l.biometricsNotEnrolledAndroid,
  };
}

/// Texts of the OS prompt (12 §5.4): `biometrics.reason` is the iOS reason
/// and the Android prompt title; the Android subtitle names the restaurant.
BiometricPromptTexts biometricPromptTexts(AppLocalizations l, SessionUser? user) {
  final String? restaurant = user?.restaurant?.name;
  return (
    reason: l.biometricsReason,
    androidTitle: l.biometricsReason,
    androidSubtitle: restaurant == null ? '' : l.biometricsPromptSubtitleAndroid(restaurant),
  );
}
