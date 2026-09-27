import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:giftcard_waiter/app/app_scope.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/format/format.dart';
import 'package:giftcard_waiter/core/platform/nfc_service.dart';
import 'package:giftcard_waiter/core/state/loop_controller.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';

import 'ios_sheet_texts.dart';

/// S10 — full-screen problems when no card data is available (03b §5,
/// 12 §3.1 L01–L07), rendered with the ProblemScreen template (05 §4.6).
///
/// The loop controller decides the variant ([ProblemState]) and plays the
/// lookup-failure feedback and the throttle-end haptic (11 E25–E27); this
/// page maps the variant to copy, visual and actions. ✕ / Done / back
/// return to Ready through the loop.
class ProblemPage extends StatefulWidget {
  /// Creates the page.
  const ProblemPage({super.key});

  @override
  State<ProblemPage> createState() => _ProblemPageState();
}

class _ProblemPageState extends State<ProblemPage> {
  LoopController? _loopOrNull;
  LoopController get _loop => _loopOrNull!;

  /// The problem on screen; kept while the page leaves.
  ProblemState? _shown;
  bool _leaving = false;

  /// "Try again" is running: the problem stays with its primary action
  /// busy until the result (03b §5.1 "Loading").
  bool _retrying = false;

  /// Throttled: full wait (the ring's 100 %) and the 1-s ticker of the
  /// "Scan again · 0:42" label (03b §5.2, 06 M30).
  Duration? _throttleTotal;
  Timer? _ticker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loopOrNull != null) return;
    final LoopController loop = _loopOrNull = context.services.loop;
    loop.addListener(_onLoop);
    final LoopState state = loop.state;
    if (state is ProblemState) _show(state);
    if (state case LookingUpState(
      origin: LookupOrigin.problem,
      :final ProblemState? problem,
    ) when problem != null) {
      _show(problem);
      _retrying = true;
    }
  }

  @override
  void dispose() {
    _loopOrNull?.removeListener(_onLoop);
    _ticker?.cancel();
    super.dispose();
  }

  void _onLoop() {
    final LoopState next = _loop.state;
    if (next case LookingUpState(origin: LookupOrigin.problem)) {
      setState(() => _retrying = true);
      return;
    }
    _retrying = false;
    if (next is! ProblemState) {
      _ticker?.cancel();
      if (!_leaving) setState(() => _leaving = true);
      return;
    }
    // The controller also notifies at the end of a throttle wait (E27):
    // the button enables in the same frame as the haptic.
    setState(() {
      if (!identical(next, _shown)) _show(next);
    });
  }

  void _show(ProblemState problem) {
    _shown = problem;
    _leaving = false;
    _ticker?.cancel();
    final Duration? until = problem.until;
    if (problem.kind != ProblemKind.throttled || until == null) return;
    final Duration left = until - _loop.now();
    _throttleTotal = left > Duration.zero ? left : Duration.zero;
    if (left > Duration.zero) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
        if (!mounted) return;
        if (_remaining(problem) == Duration.zero) timer.cancel();
        setState(() {});
      });
    }
  }

  Duration _remaining(ProblemState problem) {
    final Duration left = problem.until! - _loop.now();
    return left > Duration.zero ? left : Duration.zero;
  }

  /// "Scan again": iPhone opens the NFC sheet, Android returns to the
  /// listening Ready screen; a device without NFC opens the QR scanner
  /// (03b §5.1 "iPad: S12").
  void _scanAgain() {
    if (_loop.nfcAvailability == NfcAvailability.unsupported) {
      _loop
        ..back()
        ..openQr();
      return;
    }
    unawaited(_loop.scanAgain(iosSheetTextsOf(context)));
  }

  void _close() => _loop.back();

  @override
  Widget build(BuildContext context) {
    final ProblemState? problem = _shown;
    if (problem == null) return ColoredBox(color: context.colors.bgCanvas);
    return IgnorePointer(
      ignoring: _leaving,
      child: KeyedSubtree(
        // A different problem is a new screen (entry motion, announcement).
        key: ObjectKey(problem),
        child: _screen(AppLocalizations.of(context), problem),
      ),
    );
  }

  ProblemScreen _screen(AppLocalizations l10n, ProblemState problem) {
    final ProblemAction tryAgain = ProblemAction(
      l10n.commonTryAgain,
      _loop.retryLookup,
      status: _retrying ? ButtonStatus.loading : null,
    );
    final ProblemAction scanAgain = ProblemAction(
      l10n.commonScanAgain,
      _scanAgain,
    );
    final String? code = problem.supportCode;
    switch (problem.kind) {
      case ProblemKind.notFound:
        return _problem(
          family: ProblemFamily.notFound,
          title: l10n.problemNotFoundTitle,
          body: l10n.problemNotFoundBody,
          primary: scanAgain,
          secondary: ProblemAction(l10n.commonEnterNumber, _loop.openManual),
          code: code,
        );
      case ProblemKind.notFoundManual:
        return _problem(
          family: ProblemFamily.notFound,
          title: l10n.problemNotFoundTitle,
          body: l10n.problemNotFoundBodyManual,
          primary: ProblemAction(l10n.commonEditNumber, _loop.editNumber),
          code: code,
        );
      case ProblemKind.foreign:
        return _problem(
          family: ProblemFamily.foreign,
          title: l10n.problemForeignTitle,
          body: l10n.problemForeignBody,
          primary: ProblemAction(l10n.commonDone, _close),
          code: code,
        );
      case ProblemKind.verify:
        // Calm visual (13 · R03); one fresh read, never QR/manual (L04).
        return _problem(
          family: ProblemFamily.verification,
          title: l10n.problemVerifyTitle,
          body: l10n.problemVerifyBody,
          primary: ProblemAction(l10n.commonDone, _close),
          tertiary: problem.verifyRescanUsed ? null : scanAgain,
          code: code,
          tag: switch (problem.verifyTag) {
            VerifyTag.uid => _tagUid,
            VerifyTag.sig => _tagSig,
            VerifyTag.replay => _tagReplay,
            null => null,
          },
        );
      case ProblemKind.throttled:
        final Duration left = _remaining(problem);
        return _problem(
          family: ProblemFamily.throttled,
          title: l10n.problemThrottledTitle,
          body: l10n.problemThrottledBody,
          // `ill_wait` with the ring below the body (10 §4.4 #4); the ring
          // runs by itself from the wait left when it appeared.
          countdown: ProblemCountdown(
            remaining: _throttleTotal ?? left,
            total: _throttleTotal ?? left,
            finishedAnnouncement: l10n.a11yScanAvailable,
          ),
          primary: left > Duration.zero
              ? ProblemAction(
                  l10n.problemScanAgainIn(DateTimeFormat.countdown(left)),
                  null,
                )
              : scanAgain,
        );
      case ProblemKind.network:
        return _problem(
          family: ProblemFamily.network,
          title: l10n.offlineTitle,
          body: l10n.problemNetworkBody,
          primary: problem.retry == null ? scanAgain : tryAgain,
        );
      case ProblemKind.server:
        return _problem(
          family: ProblemFamily.server,
          title: l10n.problemServerTitle,
          body: l10n.problemServerBody,
          visual: const ProblemVisual.icon(WaiterIcon.serverOff),
          primary: problem.retry == null ? scanAgain : tryAgain,
          code: code,
        );
      case ProblemKind.notGiftCard:
        return _problem(
          family: ProblemFamily.notFound,
          title: l10n.scanNotCard,
          body: l10n.problemNotFoundBody,
          primary: scanAgain,
          secondary: ProblemAction(l10n.commonEnterNumber, _loop.openManual),
        );
    }
  }

  ProblemScreen _problem({
    required ProblemFamily family,
    required String title,
    required String body,
    required ProblemAction primary,
    ProblemVisual? visual,
    ProblemCountdown? countdown,
    ProblemAction? secondary,
    ProblemAction? tertiary,
    String? code,
    String? tag,
  }) {
    return ProblemScreen(
      family: family,
      title: title,
      body: body,
      visual: visual,
      countdown: countdown,
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      onClose: _close,
      supportCode: code,
      requestId: code == null ? null : _shown?.requestId,
      supportCodeTag: tag,
    );
  }

  /// Neutral reason tags after the support code (12 §2.5).
  static const String _tagUid = 'UID';
  static const String _tagSig = 'SIG';
  static const String _tagReplay = 'REPLAY';
}
