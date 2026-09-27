import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/platform/feedback_scope.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'progress_ring.dart';
import 'spinner.dart';
import 'support/announce.dart';
import 'support/delayed_presence.dart';
import 'support/focus_ring.dart';
import 'support/pressable.dart';
import 'support/shape.dart';
import 'support/text_emphasis.dart';

/// Progress of a committed hold (05 §1.5 states).
enum HoldButtonStatus {
  /// Armed and waiting for a hold.
  idle,

  /// Redeem request in flight: ring becomes a Spinner after 150 ms and
  /// line 2 shows the redeeming caption.
  redeeming,

  /// Redeeming for more than 8 s: line 2 shows `redeem.slow`.
  slow,
}

/// Press-and-hold Redeem for amounts ≥ € 100,00 (05 §1.5, 06 M16,
/// 07 §5.3). A large PrimaryButton variant with a 28-pt ProgressRing at the
/// leading edge and two centred lines (amount label, `charge.hold`).
///
/// **Touch:** progress runs linearly for 600 ms from touch-down with
/// `haptic.holdTick` at 200 / 400 / 600 ms; at 600 ms [onCommit] is called
/// immediately (no release needed). Releasing earlier, sliding more than
/// 12 pt outside, a lost gesture or the app leaving the foreground cancels:
/// the ring drains to 0 in 160 ms. A release before 250 ms teaches: line 2
/// turns 100 % / weight 600 for 1.2 s and `charge.hold` is announced.
/// Second fingers are ignored; the press claims the gesture (no scroll).
///
/// **Assistive technology (07 §5.3):** Path A — the platform's
/// double-tap-and-hold passes the touch through (VoiceOver) or issues a
/// long-press action that commits (TalkBack). Path B — an accessibility
/// activation (or Space with Full Keyboard Access) arms the button:
/// `haptic.select`, a dashed full ring, an announcement; a second
/// activation within 10 s commits; the arm is dropped after 10 s (announced),
/// when accessibility focus leaves or the label changes. Path C — a named
/// custom action commits directly. Enter on a hardware keyboard never
/// activates it.
class HoldButton extends StatefulWidget {
  /// Creates a hold button.
  const HoldButton({
    required this.label,
    required this.semanticLabel,
    required this.redeemingCaption,
    required this.onCommit,
    super.key,
    this.status = HoldButtonStatus.idle,
    this.disabledReason,
  });

  /// Line 1: `charge.redeem` / `charge.redeemFull` with the formatted amount.
  final String label;

  /// Accessible label with the spoken amount ("Redeem 150 euros"); also the
  /// custom action's name (Path C) and the armed announcement (Path B).
  final String semanticLabel;

  /// Line 2 while redeeming (`charge.redeeming` with the amount).
  final String redeemingCaption;

  /// Called once when the hold (or an accessible path) completes. The
  /// caller starts the redeem and creates its Idempotency-Key here.
  /// `null` renders the disabled state (amount > balance, offline).
  final VoidCallback? onCommit;

  /// Redeem progress after the commit.
  final HoldButtonStatus status;

  /// Hint read when disabled.
  final String? disabledReason;

  /// Time an accessible arm stays valid (07 §5.3 Path B).
  static const Duration armWindow = Duration(seconds: 10);

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(vsync: this)
    ..addListener(_onProgress);
  late final AppLifecycleListener _lifecycle;

  bool _holding = false;
  bool _committed = false;
  bool _armed = false;
  bool _teaching = false;
  bool _focused = false;
  double _holdStartValue = 0;
  int _ticksPlayed = 0;
  Timer? _armTimer;
  Timer? _teachTimer;

  bool get _enabled => widget.onCommit != null;
  bool get _busy => widget.status != HoldButtonStatus.idle;
  bool get _interactive => _enabled && !_busy && !_committed;

  static final List<int> _tickTimes = HapticToken.holdTick.spec.stepsMs;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (AppLifecycleState state) {
        if (state != AppLifecycleState.resumed) _cancelHold();
      },
    );
  }

  @override
  void didUpdateWidget(HoldButton old) {
    super.didUpdateWidget(old);
    if (old.label != widget.label || !_enabled) {
      _cancelHold(rebuild: false);
      _armTimer?.cancel();
      _armed = false;
    }
    if (_busy != (old.status != HoldButtonStatus.idle) && !_busy) {
      // Redeem finished without leaving the screen (error): ready again.
      _committed = false;
      _ring.value = 0;
    }
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    _teachTimer?.cancel();
    _lifecycle.dispose();
    _ring.dispose();
    super.dispose();
  }

  void _onDown() {
    if (!_interactive) return;
    _disarm();
    _holding = true;
    _ticksPlayed = 0;
    _holdStartValue = _ring.value;
    _ring.animateTo(
      1,
      duration: Times.hold * (1 - _holdStartValue),
      curve: Curves.linear,
    );
    setState(() {});
  }

  void _onProgress() {
    if (!_holding) return;
    final double span = 1 - _holdStartValue;
    final double elapsedMs = span <= 0
        ? Times.hold.inMilliseconds.toDouble()
        : (_ring.value - _holdStartValue) / span * Times.hold.inMilliseconds;
    while (_ticksPlayed < _tickTimes.length &&
        elapsedMs >= _tickTimes[_ticksPlayed] - 0.5) {
      if (_ticksPlayed < _tickTimes.length - 1) {
        context.haptic(HapticToken.holdTick, step: _ticksPlayed);
      }
      _ticksPlayed++;
    }
    // Commit on the frame the ring reaches 100 % (600 ms after touch-down).
    if (_ring.value >= 1) _commit();
  }

  void _commit() {
    if (_committed || !_enabled) return;
    _holding = false;
    _disarm();
    _ring.value = 1;
    context.haptic(HapticToken.holdTick, step: _tickTimes.length - 1);
    setState(() => _committed = true);
    widget.onCommit!();
  }

  void _onRelease() {
    if (!_holding) return;
    final double heldMs =
        (_ring.value - _holdStartValue) /
        (1 - _holdStartValue).clamp(1e-6, 1) *
        Times.hold.inMilliseconds;
    _cancelHold();
    if (heldMs < HoldButtonTokens.tapTeachThreshold.inMilliseconds) _teach();
  }

  void _cancelHold({bool rebuild = true}) {
    if (!_holding) return;
    _holding = false;
    _ring.animateBack(
      0,
      duration: Motion.durationFast,
      curve: Motion.easeDecelerate,
    );
    if (rebuild && mounted) setState(() {});
  }

  void _teach() {
    final String message = AppLocalizations.of(context).chargeHold;
    announce(context, message);
    _teachTimer?.cancel();
    setState(() => _teaching = true);
    _teachTimer = Timer(HoldButtonTokens.tapTeachDuration, () {
      if (mounted) setState(() => _teaching = false);
    });
  }

  /// Path B: first activation arms, the second (within 10 s) commits.
  void _accessibleActivate() {
    if (!_interactive) return;
    if (_armed) {
      _commit();
      return;
    }
    context.haptic(HapticToken.select);
    announce(context, widget.semanticLabel, assertive: true);
    setState(() => _armed = true);
    _armTimer?.cancel();
    _armTimer = Timer(HoldButton.armWindow, () {
      if (!mounted || !_armed) return;
      _disarm();
      announce(context, AppLocalizations.of(context).redeemNothingBooked);
    });
  }

  void _disarm() {
    _armTimer?.cancel();
    if (_armed && mounted) setState(() => _armed = false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final BorderRadius radius = BorderRadius.circular(ButtonTokens.largeRadius);
    final double height = context.layout.largeButtonHeight;
    final bool pressed = _holding;

    final Color fill = !_enabled
        ? c.bgKey
        : pressed
        ? c.actionPrimaryPressed
        : c.actionPrimary;
    final Color foreground = _enabled ? c.fgOnAccent : c.fgTertiary;

    final String caption = switch (widget.status) {
      HoldButtonStatus.idle => l10n.chargeHold,
      HoldButtonStatus.redeeming => widget.redeemingCaption,
      HoldButtonStatus.slow => l10n.redeemSlow,
    };

    Widget body = DelayedPresence(
      active: _busy,
      builder: (BuildContext context, bool spinnerVisible) {
        final Widget ring = spinnerVisible
            ? Spinner(color: c.holdProgress)
            : AnimatedBuilder(
                animation: _ring,
                builder: (BuildContext context, Widget? _) => ProgressRing.hold(
                  progress: _ring.value,
                  dashed: _armed,
                  trackColor: _enabled
                      ? null
                      : c.fgTertiary.withValues(
                          alpha: HoldButtonTokens.disabledTrackOpacity,
                        ),
                ),
              );
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            PositionedDirectional(
              start: HoldButtonTokens.ringInset,
              top: 0,
              bottom: 0,
              child: Center(
                child: SizedBox.square(
                  dimension: Sizes.ringHold,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: Motion.durationFast,
                      child: KeyedSubtree(
                        key: ValueKey<bool>(spinnerVisible),
                        child: ring,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HoldButtonTokens.labelPaddingHorizontal,
                vertical: Space.s2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ScaledText(
                    widget.label,
                    type: TypeTokens.labelL,
                    color: foreground,
                    textAlign: TextAlign.center,
                  ),
                  if (_enabled) ...<Widget>[
                    const SizedBox(height: HoldButtonTokens.lineGap),
                    _Caption(
                      text: caption,
                      color: foreground,
                      emphasised: _teaching,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );

    body = AnimatedScale(
      scale: pressed && !reduceMotion ? Motion.pressScaleButton : 1,
      duration: pressed ? Motion.durationInstant : Motion.durationFast,
      curve: pressed ? Motion.easeStandard : Motion.easeDecelerate,
      child: FocusRing(
        visible: _focused && _enabled,
        radius: radius,
        child: AnimatedContainer(
          duration: Motion.durationInstant,
          constraints: BoxConstraints(
            minHeight: height,
            minWidth: double.infinity,
          ),
          decoration: ShapeDecoration(
            color: fill,
            shape: waiterShape(context, radius),
          ),
          child: body,
        ),
      ),
    );

    body = RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      gestures: <Type, GestureRecognizerFactory>{
        PressRecognizer: GestureRecognizerFactoryWithHandlers<PressRecognizer>(
          () => PressRecognizer(
            isInside: (Offset global, double slop) =>
                isInsideWithSlop(context, global, slop),
            slop: HoldButtonTokens.slop,
            claimOnDown: true,
            debugOwner: this,
          ),
          (PressRecognizer r) {
            r
              ..onDown = _onDown
              ..onUpInside = _onRelease
              ..onCancel = _cancelHold;
          },
        ),
      },
      child: body,
    );

    body = FocusableActionDetector(
      enabled: _enabled,
      onShowFocusHighlight: (bool v) => setState(() => _focused = v),
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent _) {
            _accessibleActivate();
            return null;
          },
        ),
      },
      child: body,
    );

    return Semantics(
      container: true,
      button: true,
      enabled: _interactive,
      label: widget.semanticLabel,
      value: _busy ? caption : l10n.chargeHold,
      hint: _enabled ? l10n.a11yHoldHint : widget.disabledReason,
      onTap: _interactive ? _accessibleActivate : null,
      onLongPress: _interactive ? _commit : null,
      onDidLoseAccessibilityFocus: _disarm,
      customSemanticsActions: _interactive
          ? <CustomSemanticsAction, VoidCallback>{
              CustomSemanticsAction(label: widget.semanticLabel): _commit,
            }
          : null,
      excludeSemantics: true,
      child: body,
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({
    required this.text,
    required this.color,
    required this.emphasised,
  });

  final String text;
  final Color color;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final WaiterTextStyles styles = context.textStyles;
    return ScaledText.rich(
      (ScaledStyles s) {
        final TextStyle base = s(
          TypeTokens.caption,
          color: emphasised
              ? color
              : color.withValues(alpha: HoldButtonTokens.captionOpacity),
        );
        return TextSpan(
          text: text,
          style: emphasised ? base.semiBold(boldText: styles.boldText) : base,
        );
      },
      type: TypeTokens.caption,
      textAlign: TextAlign.center,
    );
  }
}
