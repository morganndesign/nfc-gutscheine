import 'package:flutter/foundation.dart';

/// Access layer of the app (02 §4.5: Launching, SignedOut, Onboarding, Locked,
/// Blocked, UpdateRequired; `active` = the loop may run). `startupProblem`:
/// signed out and the server could not be reached at launch — the reason is
/// shown instead of a sign-in form that cannot work.
enum AccessPhase {
  launching,
  startupProblem,
  signedOut,
  onboardingBiometrics,
  onboardingIntro,
  locked,
  active,
  blocked,
  updateRequired,
}

/// S15 full-screen variants (09 §5 `blocked/{variant}`).
enum BlockedKind { forbidden, deviceRevoked, suspended, deactivated }

/// Where the 401 happened decides where the waiter returns after signing in
/// again (A01): lookup context → S05, redeem context → S07 with amount kept.
enum SessionContext { lookup, redeem }

/// Why S02 shows an inline notice after a forced sign-out.
enum SignInNotice {
  /// P13: biometrics changed on the device.
  biometricsChanged,

  /// Q2 default: the account was deactivated (shown with the sign-in error).
  deactivated,

  /// The app was updated: every update signs in again, with the e-mailed code
  /// (decision 2026-10-06).
  appUpdated,
}

/// Outcome of a sign-in attempt on S02 or the S15 session sheet (A02, A07–A09).
@immutable
sealed class SignInOutcome {
  const SignInOutcome();
}

final class SignInSucceeded extends SignInOutcome {
  const SignInSucceeded();
}

/// A07: wrong e-mail or password (password cleared, e-mail kept).
final class SignInInvalid extends SignInOutcome {
  const SignInInvalid();
}

/// A02: the role cannot redeem.
final class SignInNoPermission extends SignInOutcome {
  const SignInNoPermission();
}

/// A08: 429 — button disabled until [until] (monotonic).
final class SignInThrottled extends SignInOutcome {
  const SignInThrottled(this.until);

  final Duration until;
}

/// A09: offline.
final class SignInOffline extends SignInOutcome {
  const SignInOffline();
}

/// A09: 5xx — with the request id for the support code.
final class SignInServerError extends SignInOutcome {
  const SignInServerError({this.requestId = ''});

  final String requestId;
}

/// The account or device is blocked; the session moved to S15.
final class SignInBlocked extends SignInOutcome {
  const SignInBlocked();
}

/// The password was right; a 6-digit code went to [maskedEmail] (decision
/// 2026-10-06). The form shows the code step ([SessionController.pendingCode]).
final class SignInCodeRequired extends SignInOutcome {
  const SignInCodeRequired(this.maskedEmail);

  final String maskedEmail;
}

/// The code was not right; the code step stays (inline error).
final class SignInCodeWrong extends SignInOutcome {
  const SignInCodeWrong();
}

/// The code expired, was used or was wrong 5 times: back to the password.
final class SignInCodeExpired extends SignInOutcome {
  const SignInCodeExpired();
}

/// 15 wrong codes within an hour: the account is locked for 60 minutes.
final class SignInCodeLocked extends SignInOutcome {
  const SignInCodeLocked();
}

/// A sign-in waiting for the code from the e-mail.
@immutable
class PendingSignInCode {
  const PendingSignInCode({required this.login, required this.maskedEmail, required this.email, required this.reauth});

  final String login;
  final String maskedEmail;
  final String email;

  /// Signing in again from the S15 session sheet (the layers underneath stay).
  final bool reauth;
}

/// "Send a new code" on the code step.
enum CodeResendOutcome { sent, wait, expired, offline, failed }

/// Result of enabling or using biometrics (S03/S04, P10–P13).
enum BiometricResult { success, failed, lockedOut, notEnrolled }

/// Result of S15 "Check again" (A03, A05).
enum RecheckOutcome {
  /// The block is gone; the app continues on S05.
  cleared,

  /// The server still refuses — the screen stays (`haptic.warning`).
  stillBlocked,

  /// No connection — the screen shows the offline caption.
  offline,
}
