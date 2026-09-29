import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:giftcard_waiter/app/app_scope.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/format/format.dart';
import 'package:giftcard_waiter/core/state/loop_controller.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';
import 'package:giftcard_waiter/screens/card_texts.dart';

/// S10 — full-screen problems when a scanned QR gave no voucher (03b §5,
/// 12 §3.1), rendered with the ProblemScreen template (05 §4.6).
///
/// The loop controller decides the variant ([ProblemState]) and plays the
/// throttle-end haptic (11 E27); this
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
    if (state case PresentingState(
      origin: PresentOrigin.problem,
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
    if (next case PresentingState(origin: PresentOrigin.problem)) {
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
      _loop.retryPresent,
      status: _retrying ? ButtonStatus.loading : null,
    );
    final ProblemAction scanAgain = ProblemAction(l10n.commonScanAgain, _loop.scanAgain);
    final ProblemAction tapAgain = ProblemAction(l10n.commonTapAgain, () => _loop.openCardTap(texts: cardTexts(l10n)));
    final String? code = problem.supportCode;
    switch (problem.kind) {
      case ProblemKind.notRecognized:
        return _problem(
          family: ProblemFamily.notFound,
          title: l10n.problemNotRecognizedTitle,
          body: l10n.problemNotRecognizedBody,
          primary: scanAgain,
          secondary: ProblemAction(l10n.commonDone, _close),
          code: code,
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
              ? ProblemAction(l10n.problemScanAgainIn(DateTimeFormat.countdown(left)), null)
              : scanAgain,
        );
      case ProblemKind.network:
        return _problem(
          family: ProblemFamily.network,
          title: l10n.offlineTitle,
          body: l10n.problemNetworkBody,
          primary: problem.retry != null || problem.retryCard ? tryAgain : scanAgain,
        );
      case ProblemKind.server:
        return _problem(
          family: ProblemFamily.server,
          title: l10n.problemServerTitle,
          body: l10n.problemServerBody,
          visual: const ProblemVisual.icon(WaiterIcon.serverOff),
          primary: problem.retry != null || problem.retryCard ? tryAgain : scanAgain,
          code: code,
        );
      case ProblemKind.cardNotRecognized:
        return _problem(
          family: ProblemFamily.notFound,
          title: l10n.problemCardNotRecognizedTitle,
          body: l10n.problemCardNotRecognizedBody,
          primary: ProblemAction(l10n.commonDone, _close),
          code: code,
        );
      case ProblemKind.cardNotUsable:
        return _problem(
          family: ProblemFamily.verification,
          title: l10n.problemCardNotUsableTitle,
          body: switch (problem.cardState) {
            'available' || 'bound' => l10n.problemCardNotUsableNotActive,
            'suspended' => l10n.problemCardNotUsableSuspended,
            'other_restaurant' => l10n.problemCardNotUsableOtherRestaurant,
            _ => l10n.problemCardNotUsableInvalid,
          },
          primary: ProblemAction(l10n.commonDone, _close),
          code: code,
        );
      case ProblemKind.cardMoved:
        return _problem(
          family: ProblemFamily.verification,
          title: l10n.problemCardMovedTitle,
          body: l10n.problemCardMovedBody,
          primary: tapAgain,
          secondary: ProblemAction(l10n.commonDone, _close),
        );
      case ProblemKind.nfcOff:
        return _problem(
          family: ProblemFamily.account,
          title: l10n.problemNfcOffTitle,
          body: l10n.problemNfcOffBody,
          primary: tapAgain,
          secondary: ProblemAction(l10n.commonDone, _close),
        );
      case ProblemKind.nfcUnsupported:
        return _problem(
          family: ProblemFamily.account,
          title: l10n.problemNfcUnsupportedTitle,
          body: l10n.problemNfcUnsupportedBody,
          primary: ProblemAction(l10n.commonDone, _close),
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
    String? code,
  }) {
    return ProblemScreen(
      family: family,
      title: title,
      body: body,
      visual: visual,
      countdown: countdown,
      primary: primary,
      secondary: secondary,
      onClose: _close,
      supportCode: code,
      requestId: code == null ? null : _shown?.requestId,
    );
  }
}
