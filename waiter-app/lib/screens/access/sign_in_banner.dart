import 'package:flutter/widgets.dart';

import '../../components/components.dart';
import '../../core/format/format.dart';
import '../../core/state/session_state.dart';
import '../../core/theme/theme.dart';
import '../../l10n/app_localizations.dart';

/// What the StatusBanner slot of a password form shows: S02 (03a §2
/// States) and the S15 session sheet ("errors like S02"). Severities follow
/// the error catalogue (12 §3.3 A02, A07–A09; §2.2).
@immutable
sealed class SignInIssue {
  const SignInIssue();

  /// The issue a failed sign-in shows; `null` when the attempt succeeded or
  /// moved the session to S15.
  static SignInIssue? of(SignInOutcome outcome) => switch (outcome) {
    SignInInvalid() => const SignInInvalidIssue(),
    SignInNoPermission() => const SignInNoPermissionIssue(),
    SignInThrottled(:final Duration until) => SignInThrottledIssue(until),
    SignInOffline() => const SignInOfflineIssue(),
    SignInServerError(:final String requestId) => SignInServerIssue(requestId),
    SignInCodeExpired() => const SignInCodeExpiredIssue(),
    SignInCodeLocked() => const SignInCodeLockedIssue(),
    // The code step shows these itself (inline under the field).
    SignInSucceeded() || SignInBlocked() || SignInCodeRequired() || SignInCodeWrong() => null,
  };
}

/// A07: wrong e-mail or password.
final class SignInInvalidIssue extends SignInIssue {
  const SignInInvalidIssue();
}

/// A02: the role cannot redeem.
final class SignInNoPermissionIssue extends SignInIssue {
  const SignInNoPermissionIssue();
}

/// A08: too many attempts until [until] (monotonic).
final class SignInThrottledIssue extends SignInIssue {
  const SignInThrottledIssue(this.until);

  final Duration until;
}

/// A09: no connection (reported by the OS or by the attempt).
final class SignInOfflineIssue extends SignInIssue {
  const SignInOfflineIssue();
}

/// A09: 5xx or timeout.
final class SignInServerIssue extends SignInIssue {
  const SignInServerIssue(this.requestId);

  /// `X-Request-Id` of the failed attempt; empty when none reached the server.
  final String requestId;
}

/// The e-mailed code expired, was used or was wrong 5 times: sign in again.
final class SignInCodeExpiredIssue extends SignInIssue {
  const SignInCodeExpiredIssue();
}

/// 15 wrong codes within an hour: the account is locked for 60 minutes.
final class SignInCodeLockedIssue extends SignInIssue {
  const SignInCodeLockedIssue();
}

/// An inline notice after a forced sign-out ([SignInNotice]).
final class SignInNoticeIssue extends SignInIssue {
  const SignInNoticeIssue(this.notice);

  final SignInNotice notice;
}

/// The banner slot above the fields: collapsed when [issue] is `null`;
/// otherwise the StatusBanner plus `space.4` below it. Appears with
/// `banner-in` (height grows while fading in) and leaves with `banner-out`;
/// under Reduce Motion the height changes instantly and the banner fades
/// (03a §2 Animations). [remaining] is the live countdown of a
/// [SignInThrottledIssue].
class SignInBannerSlot extends StatelessWidget {
  const SignInBannerSlot({required this.issue, super.key, this.remaining = Duration.zero});

  final SignInIssue? issue;
  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final SignInIssue? current = issue;
    return AnimatedSize(
      duration: reduceMotion ? Duration.zero : Motion.durationBase,
      curve: Motion.easeDecelerate,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: Motion.durationFast,
        switchInCurve: Motion.easeDecelerate,
        switchOutCurve: Motion.easeAccelerate,
        child: current == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                // One key per kind, so a ticking countdown never cross-fades.
                key: ValueKey<Object>(current is SignInNoticeIssue ? current.notice : current.runtimeType),
                padding: const EdgeInsets.only(bottom: Space.s4),
                child: _banner(AppLocalizations.of(context), current),
              ),
      ),
    );
  }

  StatusBanner _banner(AppLocalizations l, SignInIssue issue) => switch (issue) {
    SignInInvalidIssue() => StatusBanner(tone: BannerTone.warning, title: l.signInErrorInvalid),
    SignInNoPermissionIssue() => StatusBanner(tone: BannerTone.danger, title: l.signInErrorNoPermission),
    // The countdown ticks silently; it is announced once on appearance.
    SignInThrottledIssue() => StatusBanner(
      announceTextChanges: false,
      tone: BannerTone.warning,
      title: l.signInErrorThrottled(DateTimeFormat.countdown(remaining)),
    ),
    SignInOfflineIssue() => StatusBanner(tone: BannerTone.info, title: l.offlineTitle, body: l.signInOfflineBody),
    // 12 §2.5: S02 server error carries the support code.
    SignInServerIssue(:final String requestId) => StatusBanner(
      tone: BannerTone.info,
      title: l.signInErrorServer,
      body: requestId.isEmpty ? null : l.commonSupportCode(SupportCode.fromRequestId(requestId)),
    ),
    SignInCodeExpiredIssue() => StatusBanner(tone: BannerTone.warning, title: l.signInCodeExpired),
    SignInCodeLockedIssue() => StatusBanner(tone: BannerTone.danger, title: l.signInCodeLocked),
    SignInNoticeIssue(:final SignInNotice notice) => switch (notice) {
      SignInNotice.biometricsChanged => StatusBanner(tone: BannerTone.info, title: l.unlockChanged),
      // 13 §11 Q2 default: a deactivated account is shown with the
      // sign-in error until the backend sends a dedicated code.
      SignInNotice.deactivated => StatusBanner(tone: BannerTone.warning, title: l.signInErrorInvalid),
      SignInNotice.appUpdated => StatusBanner(tone: BannerTone.info, title: l.signInAppUpdated),
    },
  };
}
