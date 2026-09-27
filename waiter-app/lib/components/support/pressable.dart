import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/theme.dart';

/// Recognises one press on a control (05 §1.0 "State timing", 04 §13.1).
///
/// - Reports touch-down immediately (the pressed visual appears within one
///   frame, also inside scrollables — no tap delay).
/// - Only the first pointer counts; further fingers are ignored.
/// - A touch that moves more than [slop] outside the bounds cancels.
/// - Touch-up inside activates. When [claimOnDown] is set the recognizer
///   wins the gesture arena at touch-down (HoldButton: a hold must not turn
///   into a scroll).
class PressRecognizer extends OneSequenceGestureRecognizer {
  /// Creates a recognizer.
  PressRecognizer({
    required this.isInside,
    this.slop = ButtonTokens.cancelSlop,
    this.claimOnDown = false,
    super.debugOwner,
  });

  /// Whether a global position lies inside the control grown by [slop].
  final bool Function(Offset globalPosition, double slop) isInside;

  /// Distance outside the bounds that cancels the press.
  final double slop;

  /// Whether to claim the arena at touch-down.
  final bool claimOnDown;

  /// Touch-down.
  VoidCallback? onDown;

  /// Touch-up inside the bounds (after winning the arena).
  VoidCallback? onUpInside;

  /// Press cancelled: moved outside, released outside, lost the arena or
  /// the pointer was cancelled.
  VoidCallback? onCancel;

  int? _pointer;
  bool _upInside = false;
  bool _accepted = false;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      _pointer == null &&
      (event.kind != PointerDeviceKind.mouse ||
          event.buttons == kPrimaryButton) &&
      super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _pointer = event.pointer;
    _upInside = false;
    _accepted = false;
    onDown?.call();
    if (claimOnDown) resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
      if (!isInside(event.position, slop)) _cancel();
    } else if (event is PointerUpEvent) {
      if (isInside(event.position, slop)) {
        _upInside = true;
        if (_accepted) {
          _finishInside();
        } else {
          resolve(GestureDisposition.accepted);
        }
      } else {
        _cancel();
      }
    } else if (event is PointerCancelEvent) {
      _cancel();
    }
  }

  void _finishInside() {
    final int? pointer = _pointer;
    _pointer = null;
    if (pointer != null) stopTrackingPointer(pointer);
    onUpInside?.call();
  }

  void _cancel() {
    final int? pointer = _pointer;
    if (pointer == null) return;
    _pointer = null;
    resolve(GestureDisposition.rejected);
    stopTrackingPointer(pointer);
    onCancel?.call();
  }

  @override
  void acceptGesture(int pointer) {
    _accepted = true;
    if (_upInside && pointer == _pointer) _finishInside();
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer == _pointer) _cancel();
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'press';
}

/// Whether [globalPosition] lies inside the render box of [context] grown
/// by [slop] on every side.
bool isInsideWithSlop(
  BuildContext context,
  Offset globalPosition,
  double slop,
) {
  final RenderBox? box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return false;
  return (Offset.zero & box.size)
      .inflate(slop)
      .contains(box.globalToLocal(globalPosition));
}

/// Visual state handed to a [Pressable] builder.
@immutable
class PressVisual {
  /// Creates a visual state.
  const PressVisual({
    required this.pressed,
    required this.pressAmount,
    required this.hovered,
    required this.focused,
  });

  /// Whether the control is held down (or forced pressed).
  final bool pressed;

  /// Press progress 0 → 1 (90 ms in `ease.standard`, 160 ms out
  /// `ease.decelerate`) for colour interpolation.
  final double pressAmount;

  /// Pointer hover (iPad / pointer devices).
  final bool hovered;

  /// Keyboard / switch focus: draw a `FocusRing` around the visible shape
  /// (05: the 44-pt fill for IconButton and TertiaryButton).
  final bool focused;
}

/// The shared interaction shell of every tappable component: press
/// recognition (05 §1.0), press scale (13 · R20), keyboard and switch
/// focus (the builder draws the `FocusRing`, 13 · R17), Enter/Space
/// activation, hover, and
/// button semantics (07 §5.1). No ripple, no highlight (04 §13).
class Pressable extends StatefulWidget {
  /// Creates the shell.
  const Pressable({
    required this.builder,
    super.key,
    this.onPressed,
    this.pressedScale = 1,
    this.forcePressed = false,
    this.semanticsLabel,
    this.semanticsValue,
    this.semanticsHint,
    this.semanticsToggled,
    this.isLink = false,
    this.focusNode,
    this.inert = false,
  });

  /// Paints the control for a [PressVisual].
  final Widget Function(BuildContext context, PressVisual visual) builder;

  /// Activation on touch-up inside, Enter/Space and accessibility tap.
  /// `null` disables the control (it stays visible to screen readers as
  /// disabled, 05 §1.0).
  final VoidCallback? onPressed;

  /// Scale while pressed: keys 0.96, buttons 0.98, chips 0.97, rows and
  /// IconButtons 1 (13 · R20). Removed under Reduce Motion.
  final double pressedScale;

  /// Keeps the pressed look (a button waiting for its spinner, 05 §1.0).
  final bool forcePressed;

  /// Accessibility label (defaults to the child's semantics).
  final String? semanticsLabel;

  /// Accessibility value.
  final String? semanticsValue;

  /// Accessibility hint.
  final String? semanticsHint;

  /// Toggle state for toggle buttons (torch, password visibility).
  final bool? semanticsToggled;

  /// Role link instead of button ("Forgot password?", 05 §1.3).
  final bool isLink;

  /// Keyboard focus node (the screen's Enter/Return target, 05 §1.1).
  final FocusNode? focusNode;

  /// Temporarily not reacting (loading): exposed as not enabled while the
  /// owner's label/value announces the busy state (05 §1.0 "Loading").
  final bool inert;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: Motion.durationInstant,
    reverseDuration: Motion.durationFast,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _press,
    curve: Motion.easeStandard,
    reverseCurve: Motion.easeDecelerate,
  );
  bool _down = false;
  bool _focused = false;
  bool _hovered = false;

  bool get _enabled => widget.onPressed != null && !widget.inert;

  @override
  void initState() {
    super.initState();
    if (widget.forcePressed) _press.value = 1;
  }

  @override
  void didUpdateWidget(Pressable old) {
    super.didUpdateWidget(old);
    if (!_enabled && _down) _down = false;
    _syncPress();
  }

  @override
  void dispose() {
    _curve.dispose();
    _press.dispose();
    super.dispose();
  }

  void _syncPress() {
    final bool pressed = _down || widget.forcePressed;
    if (pressed && _press.status != AnimationStatus.forward) {
      if (_press.value < 1) _press.forward();
    } else if (!pressed && _press.status != AnimationStatus.reverse) {
      if (_press.value > 0) _press.reverse();
    }
  }

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
    _syncPress();
  }

  void _activate() {
    if (_enabled) widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final bool enabled = _enabled;
    Widget content = AnimatedBuilder(
      animation: _curve,
      builder: (BuildContext context, Widget? _) {
        final double t = _curve.value;
        final double scale = reduceMotion
            ? 1
            : 1 - (1 - widget.pressedScale) * t;
        return Transform.scale(
          scale: scale,
          child: widget.builder(
            context,
            PressVisual(
              pressed: _down || widget.forcePressed,
              pressAmount: t,
              hovered: _hovered,
              focused: _focused && enabled,
            ),
          ),
        );
      },
    );

    content = RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      gestures: <Type, GestureRecognizerFactory>{
        PressRecognizer: GestureRecognizerFactoryWithHandlers<PressRecognizer>(
          () => PressRecognizer(
            isInside: (Offset global, double slop) =>
                isInsideWithSlop(context, global, slop),
            debugOwner: this,
          ),
          (PressRecognizer r) {
            r
              ..onDown = enabled ? () => _setDown(true) : null
              ..onUpInside = enabled
                  ? () {
                      _setDown(false);
                      _activate();
                    }
                  : null
              ..onCancel = () => _setDown(false);
          },
        ),
      },
      child: content,
    );

    content = FocusableActionDetector(
      enabled: enabled,
      focusNode: widget.focusNode,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (bool v) => setState(() => _focused = v),
      onShowHoverHighlight: (bool v) => setState(() => _hovered = v),
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent _) {
            _activate();
            return null;
          },
        ),
      },
      child: content,
    );

    return Semantics(
      container: true,
      button: !widget.isLink,
      link: widget.isLink,
      enabled: enabled,
      toggled: widget.semanticsToggled,
      label: widget.semanticsLabel,
      value: widget.semanticsValue,
      hint: widget.semanticsHint,
      onTap: enabled ? _activate : null,
      excludeSemantics: true,
      child: content,
    );
  }
}
