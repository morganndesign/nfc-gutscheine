import 'package:flutter/widgets.dart';

import '../core/theme/theme.dart';
import 'support/announce.dart';
import 'support/pressable.dart';

/// Content of one snackbar (05 §4.1).
@immutable
class SnackbarData {
  /// Creates the content.
  const SnackbarData({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.duration = Times.snackbar,
    this.onDismissed,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'An action needs both a label and a callback',
       );

  /// Message (≤ 48 characters, max 2 lines, never truncated).
  final String message;

  /// One verb ("Switch"); at most one action.
  final String? actionLabel;

  /// Action; activating it dismisses the snackbar.
  final VoidCallback? onAction;

  /// Optional leading `icon.20`.
  final WaiterIcon? icon;

  /// Time before it dismisses itself: `time.snackbar` (4 s) by default;
  /// shorter confirmations may pass their own (e.g. `ready.online`).
  final Duration duration;

  /// Called when the snackbar ends without its action — timeout, swipe,
  /// replacement or [SnackbarController.dismiss] (the safe default of an
  /// ignored offer, 05 §4.1). Not called when the action is activated.
  final VoidCallback? onDismissed;
}

/// Shows app-drawn snackbars (05 §4.1, 06 M23) — not Material's.
///
/// Place one [SnackbarHost] above the Navigator (e.g. in
/// `MaterialApp.builder`) so snackbars sit above sheets (`z.snackbar`) and
/// below dialogs; obtain it with [SnackbarHost.of] / [SnackbarHost.maybeOf].
///
/// - One at a time; a new one replaces the current (out 90 ms + in).
/// - Auto-dismiss after [SnackbarData.duration] (default 4 s,
///   `time.snackbar`); the timer pauses while the
///   snackbar is touched and while [paused] (a `z.system` layer is
///   visible). While a screen reader runs it does not auto-dismiss
///   (07 §5.4).
/// - Enter: 16-pt rise + fade (240 ms decelerate); exit: 8-pt drop + fade
///   (160 ms accelerate); fades only under Reduce Motion. A horizontal
///   swipe past 40 % of its width or faster than 600 pt/s dismisses it.
/// - Bottom edge 12 pt above the CTA block ([ctaClearance] = the CTA
///   block height), else 16 pt above the bottom safe area.
/// - The message and action are announced (07 §5.1: assertive); focus is
///   not moved.
class SnackbarHost extends StatefulWidget {
  /// Creates the host.
  const SnackbarHost({
    required this.child,
    super.key,
    this.paused = false,
    this.ctaClearance = 0,
  });

  /// The app below.
  final Widget child;

  /// Freezes the timer (system sheet, biometric prompt).
  final bool paused;

  /// Height of the screen's bottom CTA block; 0 when there is none.
  final double ctaClearance;

  /// The nearest host; throws when there is none.
  static SnackbarController of(BuildContext context) => maybeOf(context)!;

  /// The nearest host, or `null`.
  static SnackbarController? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<_SnackbarHostState>();

  @override
  State<SnackbarHost> createState() => _SnackbarHostState();
}

/// Shows and dismisses snackbars of a [SnackbarHost].
abstract interface class SnackbarController {
  /// Shows [data], replacing any current snackbar.
  void show(SnackbarData data);

  /// Dismisses the current snackbar (opening a Dialog does this).
  void dismiss();
}

class _SnackbarHostState extends State<SnackbarHost>
    with TickerProviderStateMixin
    implements SnackbarController {
  late final AnimationController _presence = AnimationController(
    vsync: this,
    duration: Motion.durationBase,
    reverseDuration: Motion.durationFast,
  );
  late final AnimationController _timer = AnimationController(
    vsync: this,
    duration: Times.snackbar,
  )..addStatusListener(_onTimeout);
  SnackbarData? _current;
  SnackbarData? _next;
  bool _ending = false;
  bool _touched = false;
  double _swipe = 0;

  /// 06 M23 swipe thresholds.
  static const double _swipeFraction = 0.4;
  static const double _swipeVelocity = 600;

  bool get _screenReader => MediaQuery.accessibleNavigationOf(context);

  @override
  void show(SnackbarData data) {
    if (_current == null) {
      _present(data);
      return;
    }
    _next = data;
    _end(byAction: false, replace: true);
  }

  @override
  void dismiss() {
    _next = null;
    _end(byAction: false, replace: false);
  }

  /// Ends the current snackbar once; [SnackbarData.onDismissed] fires unless
  /// the action ended it.
  void _end({required bool byAction, required bool replace}) {
    final SnackbarData? current = _current;
    if (current == null || _ending) return;
    _ending = true;
    if (!byAction) current.onDismissed?.call();
    _hide(replace: replace);
  }

  void _present(SnackbarData data) {
    setState(() {
      _current = data;
      _swipe = 0;
      _ending = false;
    });
    _presence
      ..duration = MediaQuery.disableAnimationsOf(context)
          ? Motion.durationFast
          : Motion.durationBase
      ..forward(from: 0);
    _timer
      ..duration = data.duration
      ..value = 0;
    _syncTimer();
    final String? action = data.actionLabel;
    announce(
      context,
      action == null ? data.message : '${data.message}. $action',
      assertive: true,
    );
  }

  void _hide({required bool replace}) {
    _timer.stop();
    _presence.reverseDuration = replace
        ? Motion.durationInstant
        : MediaQuery.disableAnimationsOf(context)
        ? Motion.durationInstant
        : Motion.durationFast;
    _presence.reverse().whenCompleteOrCancel(() {
      if (!mounted || _presence.value > 0) return;
      final SnackbarData? next = _next;
      _next = null;
      setState(() => _current = null);
      if (next != null) _present(next);
    });
  }

  void _onTimeout(AnimationStatus status) {
    if (status == AnimationStatus.completed) dismiss();
  }

  void _syncTimer() {
    final bool run =
        _current != null && !_touched && !widget.paused && !_screenReader;
    if (run && !_timer.isAnimating && !_timer.isCompleted) {
      _timer.forward();
    } else if (!run && _timer.isAnimating) {
      _timer.stop();
    }
  }

  @override
  void didUpdateWidget(SnackbarHost old) {
    super.didUpdateWidget(old);
    _syncTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
  }

  @override
  void dispose() {
    _presence.dispose();
    _timer.dispose();
    super.dispose();
  }

  void _touch(bool down) {
    _touched = down;
    _syncTimer();
  }

  void _dragEnd(DragEndDetails details, double width) {
    final double v = details.primaryVelocity ?? 0;
    if (_swipe.abs() > width * _swipeFraction || v.abs() > _swipeVelocity) {
      dismiss();
    } else {
      setState(() => _swipe = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SnackbarData? data = _current;
    final WaiterLayout layout = context.layout;
    final double bottom = widget.ctaClearance > 0
        ? widget.ctaClearance + SnackbarTokens.ctaGap
        : layout.viewPadding.bottom + SnackbarTokens.noCtaBottomGap;
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: <Widget>[
        widget.child,
        if (data != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: layout.contentWidth.clamp(
                    0,
                    SnackbarTokens.maxWidth,
                  ),
                ),
                child: AnimatedBuilder(
                  animation: _presence,
                  builder: (BuildContext context, Widget? child) {
                    final double t = _presence.value;
                    final bool entering =
                        _presence.status == AnimationStatus.forward ||
                        _presence.status == AnimationStatus.completed;
                    final double dy = reduced
                        ? 0
                        : entering
                        ? SnackbarTokens.enterRise *
                              (1 - Motion.easeDecelerate.transform(t))
                        : SnackbarTokens.exitDrop *
                              (1 - Motion.easeAccelerate.transform(t));
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(_swipe, dy),
                        child: child,
                      ),
                    );
                  },
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints box) =>
                        Listener(
                          onPointerDown: (_) => _touch(true),
                          onPointerUp: (_) => _touch(false),
                          onPointerCancel: (_) => _touch(false),
                          child: GestureDetector(
                            onHorizontalDragUpdate: (DragUpdateDetails d) =>
                                setState(() => _swipe += d.delta.dx),
                            onHorizontalDragEnd: (DragEndDetails d) =>
                                _dragEnd(d, box.maxWidth),
                            child: _SnackbarView(
                              data: data,
                              onAction: () {
                                _next = null;
                                _end(byAction: true, replace: false);
                                data.onAction?.call();
                              },
                            ),
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SnackbarView extends StatelessWidget {
  const _SnackbarView({required this.data, required this.onAction});

  final SnackbarData data;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final WaiterTheme theme = context.waiter;
    final WaiterColors c = theme.colors;
    final bool dark = theme.brightness == Brightness.dark;
    final String? action = data.actionLabel;
    final WaiterIcon? icon = data.icon;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: SnackbarTokens.minHeight,
          minWidth: double.infinity,
        ),
        padding: const EdgeInsetsDirectional.only(
          start: SnackbarTokens.paddingHorizontal,
          end: SnackbarTokens.paddingHorizontal / 2,
        ),
        decoration: BoxDecoration(
          color: c.inverseBg,
          borderRadius: BorderRadius.circular(SnackbarTokens.radius),
          border: dark ? Border.all(color: c.borderSubtle, width: 0) : null,
          boxShadow: theme.elevation.level3.shadows,
        ),
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              WaiterIconView(icon, size: IconSize.s20, color: c.inverseFg),
              const SizedBox(width: SnackbarTokens.paddingVertical),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: SnackbarTokens.paddingVertical,
                ),
                child: ScaledText(
                  data.message,
                  type: TypeTokens.bodyM,
                  color: c.inverseFg,
                ),
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(
                width:
                    SnackbarTokens.actionGap -
                    SnackbarTokens.paddingHorizontal / 2,
              ),
              _SnackbarAction(label: action, onPressed: onAction),
            ] else
              const SizedBox(width: SnackbarTokens.paddingHorizontal / 2),
          ],
        ),
      ),
    );
  }
}

/// The action: `type.label` in `color.inverse.action`, 56-pt target
/// overlapping the padding, pressed 8 % white overlay pill.
class _SnackbarAction extends StatelessWidget {
  const _SnackbarAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    const Color white = Color(0xFFFFFFFF);
    return Pressable(
      onPressed: onPressed,
      semanticsLabel: label,
      builder: (BuildContext context, PressVisual visual) => ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: Sizes.targetMin,
          minWidth: Sizes.targetMin,
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: white.withValues(
                alpha: Opacities.pressedOverlay * visual.pressAmount,
              ),
              borderRadius: BorderRadius.circular(Radii.full),
              border: visual.focused
                  ? Border.all(
                      color: c.inverseAction,
                      width: Borders.widthFocus,
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SnackbarTokens.paddingVertical,
                vertical: Space.s2,
              ),
              child: ScaledText(
                label,
                type: TypeTokens.label,
                color: c.inverseAction,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
