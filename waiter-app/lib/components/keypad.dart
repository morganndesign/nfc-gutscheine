import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/format/format.dart';
import '../core/platform/feedback_scope.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'support/announce.dart';
import 'support/focus_ring.dart';
import 'support/shape.dart';

/// Bottom-left key of the [Keypad] (05 §2.1 variants).
enum KeypadVariant {
  /// "00" key — amount entry (S07).
  amount,

  /// Empty cell (no key shape, not focusable) — card number (S11).
  cardNumber,
}

/// Returns what an input did so the keypad can give the matching feedback
/// (11 E30–E33): accepted/deleted → `haptic.key`, rejected at the limit →
/// `haptic.warning`, ignored → nothing.
typedef KeypadInput = EntryOutcome Function();

/// Digit input; see [KeypadInput].
typedef KeypadDigitInput = EntryOutcome Function(int digit);

/// Glove-proof numeric entry replacing the system keyboard (05 §2.1).
///
/// - 3 × 4 grid: 1–9, then 00 (or an empty cell), 0, ⌫; keys 72 pt high
///   (64 at compact height, 80 in the tall tablet two-pane), gaps 8, width
///   content width capped at 400.
/// - Input registers on **touch-down**; sliding off does not cancel; no key
///   repeat. Up to two simultaneous touches register in order, a third is
///   ignored; a second touch on the same key within 60 ms is a glove bounce
///   and ignored (07 §4.2).
/// - ⌫ deletes on touch-down; held for 500 ms (`time.longPressClear`) it
///   calls [onClear] and plays `haptic.select`. The digit deleted at
///   touch-down is part of the clear (the select plays when either removed
///   something).
/// - Amount variant announces `keypad.cleared` and `keypad.maxReached`
///   (12 §5.20); the value itself is announced by the AmountDisplay.
/// - Press: `bg.keyPressed` and scale 0.96 (kept under Reduce Motion).
/// - Hardware keyboard: 0–9 and numpad digits, Backspace, Cmd/Ctrl +
///   Backspace clears. Return is left to the screen (never a HoldButton).
/// - [enabled] false (S08): whole keypad at `opacity.disabled`, inert.
class Keypad extends StatefulWidget {
  /// Creates a keypad.
  const Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    super.key,
    this.onDoubleZero,
    this.variant = KeypadVariant.amount,
    this.enabled = true,
    this.autofocus = false,
    this.keyHeight,
  }) : assert(
         variant == KeypadVariant.cardNumber || onDoubleZero != null,
         'The amount keypad needs onDoubleZero',
       );

  /// Digit 0–9.
  final KeypadDigitInput onDigit;

  /// "00" key (amount variant).
  final KeypadInput? onDoubleZero;

  /// ⌫ tap.
  final KeypadInput onBackspace;

  /// ⌫ long press / Cmd-Ctrl + Backspace / accessibility long press.
  final KeypadInput onClear;

  /// Bottom-left key.
  final KeypadVariant variant;

  /// Whether keys accept input.
  final bool enabled;

  /// Whether the keypad takes keyboard focus for hardware-key typing.
  final bool autofocus;

  /// Key height override; `null` uses [keyHeightFor] the window.
  final double? keyHeight;

  /// Tablet two-pane layout starts at this window width (08 §4.2).
  static const double twoPaneMinWidth = 856;

  /// Window height from which two-pane keys grow (08 §4.2).
  static const double tallKeyMinWindowHeight = 800;

  /// Two-pane key height on tall tablet windows (08 §4.2: "80 high if
  /// window height ≥ 800").
  static const double tallKeyHeight = 80;

  /// Key height for the window of [context]: 72 pt, 64 at compact height
  /// (04 §4.3), 80 in the tablet two-pane on windows ≥ 800 pt high.
  static double keyHeightFor(BuildContext context) {
    final WaiterLayout layout = context.layout;
    final bool twoPane =
        layout.widthClass.isTablet && layout.size.width >= twoPaneMinWidth;
    if (twoPane && layout.size.height >= tallKeyMinWindowHeight) {
      return tallKeyHeight;
    }
    return layout.keyHeight;
  }

  /// Two touches on the same key closer than this are one (glove bounce,
  /// 07 §4.2).
  static const Duration bounceWindow = Duration(milliseconds: 60);

  /// Maximum simultaneous touches that register (05 §2.1).
  static const int maxTouches = 2;

  @override
  State<Keypad> createState() => _KeypadState();
}

enum _KeyKind { digit, doubleZero, delete }

class _KeypadState extends State<Keypad> {
  final Set<int> _pointers = <int>{};

  bool _acceptPointer(int pointer) {
    if (!widget.enabled || _pointers.length >= Keypad.maxTouches) {
      return false;
    }
    _pointers.add(pointer);
    return true;
  }

  void _releasePointer(int pointer) => _pointers.remove(pointer);

  void _feedback(EntryOutcome outcome) {
    final bool amount = widget.variant == KeypadVariant.amount;
    final AppLocalizations l10n = AppLocalizations.of(context);
    switch (outcome) {
      case EntryOutcome.accepted:
      case EntryOutcome.deleted:
        context.haptic(HapticToken.key);
      case EntryOutcome.rejectedAtLimit:
        context.haptic(HapticToken.warning);
        if (amount) announce(context, l10n.keypadMaxReached);
      case EntryOutcome.cleared:
        context.haptic(HapticToken.select);
        if (amount) announce(context, l10n.keypadCleared);
      case EntryOutcome.ignored:
      case EntryOutcome.pasteRejected:
        break;
    }
  }

  EntryOutcome _press(_KeyKind kind, int digit) {
    final EntryOutcome outcome = switch (kind) {
      _KeyKind.digit => widget.onDigit(digit),
      _KeyKind.doubleZero => widget.onDoubleZero!(),
      _KeyKind.delete => widget.onBackspace(),
    };
    _feedback(outcome);
    return outcome;
  }

  void _clear({required bool deletedAtDown}) {
    final EntryOutcome outcome = widget.onClear();
    _feedback(
      deletedAtDown && outcome == EntryOutcome.ignored
          ? EntryOutcome.cleared
          : outcome,
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled || event is KeyUpEvent) return KeyEventResult.ignored;
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace) {
      final HardwareKeyboard keyboard = HardwareKeyboard.instance;
      if (keyboard.isControlPressed || keyboard.isMetaPressed) {
        if (event is KeyDownEvent) _clear(deletedAtDown: false);
      } else {
        _press(_KeyKind.delete, 0);
      }
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final int? digit = _digitOf(key);
    if (digit == null) return KeyEventResult.ignored;
    _press(_KeyKind.digit, digit);
    return KeyEventResult.handled;
  }

  static final Map<LogicalKeyboardKey, int> _digits = <LogicalKeyboardKey, int>{
    LogicalKeyboardKey.digit0: 0,
    LogicalKeyboardKey.digit1: 1,
    LogicalKeyboardKey.digit2: 2,
    LogicalKeyboardKey.digit3: 3,
    LogicalKeyboardKey.digit4: 4,
    LogicalKeyboardKey.digit5: 5,
    LogicalKeyboardKey.digit6: 6,
    LogicalKeyboardKey.digit7: 7,
    LogicalKeyboardKey.digit8: 8,
    LogicalKeyboardKey.digit9: 9,
    LogicalKeyboardKey.numpad0: 0,
    LogicalKeyboardKey.numpad1: 1,
    LogicalKeyboardKey.numpad2: 2,
    LogicalKeyboardKey.numpad3: 3,
    LogicalKeyboardKey.numpad4: 4,
    LogicalKeyboardKey.numpad5: 5,
    LogicalKeyboardKey.numpad6: 6,
    LogicalKeyboardKey.numpad7: 7,
    LogicalKeyboardKey.numpad8: 8,
    LogicalKeyboardKey.numpad9: 9,
  };

  static int? _digitOf(LogicalKeyboardKey key) => _digits[key];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double keyHeight = widget.keyHeight ?? Keypad.keyHeightFor(context);

    Widget key(_KeyKind kind, {int digit = 0}) {
      final String label = switch (kind) {
        _KeyKind.digit => '$digit',
        _KeyKind.doubleZero => '00',
        _KeyKind.delete => '',
      };
      return _Key(
        height: keyHeight,
        label: label,
        semanticLabel: switch (kind) {
          _KeyKind.digit => '$digit',
          _KeyKind.doubleZero => l10n.keypadDoubleZero,
          _KeyKind.delete => l10n.keypadDelete,
        },
        semanticHint: kind == _KeyKind.delete ? l10n.keypadDeleteHint : null,
        isDelete: kind == _KeyKind.delete,
        enabled: widget.enabled,
        acceptPointer: _acceptPointer,
        releasePointer: _releasePointer,
        onDown: () => _press(kind, digit),
        onLongPress: kind == _KeyKind.delete
            ? (EntryOutcome atDown) =>
                  _clear(deletedAtDown: atDown == EntryOutcome.deleted)
            : null,
      );
    }

    Widget row(List<Widget> keys) => Row(
      children: <Widget>[
        for (int i = 0; i < keys.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: KeypadTokens.gap),
          Expanded(child: keys[i]),
        ],
      ],
    );

    final List<Widget> rows = <Widget>[
      for (int r = 0; r < 3; r++)
        row(<Widget>[
          for (int c = 1; c <= 3; c++) key(_KeyKind.digit, digit: r * 3 + c),
        ]),
      row(<Widget>[
        if (widget.variant == KeypadVariant.amount)
          key(_KeyKind.doubleZero)
        else
          SizedBox(height: keyHeight),
        key(_KeyKind.digit),
        key(_KeyKind.delete),
      ]),
    ];

    return Focus(
      autofocus: widget.autofocus,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: KeypadTokens.maxWidth),
          child: AnimatedOpacity(
            opacity: widget.enabled ? 1 : Opacities.disabled,
            duration: Motion.durationFast,
            curve: Motion.easeStandard,
            child: IgnorePointer(
              ignoring: !widget.enabled,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int i = 0; i < rows.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: KeypadTokens.gap),
                    rows[i],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Key extends StatefulWidget {
  const _Key({
    required this.height,
    required this.label,
    required this.semanticLabel,
    required this.isDelete,
    required this.enabled,
    required this.acceptPointer,
    required this.releasePointer,
    required this.onDown,
    this.semanticHint,
    this.onLongPress,
  });

  final double height;
  final String label;
  final String semanticLabel;
  final String? semanticHint;
  final bool isDelete;
  final bool enabled;
  final bool Function(int pointer) acceptPointer;
  final void Function(int pointer) releasePointer;
  final EntryOutcome Function() onDown;
  final void Function(EntryOutcome outcomeAtDown)? onLongPress;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> with SingleTickerProviderStateMixin {
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
  final Set<int> _down = <int>{};
  Timer? _longPress;
  Duration? _lastDownAt;
  bool _focused = false;

  @override
  void dispose() {
    _longPress?.cancel();
    _curve.dispose();
    _press.dispose();
    super.dispose();
  }

  void _pointerDown(PointerDownEvent event) {
    if (!widget.acceptPointer(event.pointer)) return;
    final Duration now = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    final Duration? last = _lastDownAt;
    _lastDownAt = now;
    _down.add(event.pointer);
    _press.forward();
    if (last != null && now - last < Keypad.bounceWindow) return;
    _activate();
  }

  void _activate() {
    final EntryOutcome outcome = widget.onDown();
    final void Function(EntryOutcome)? onLong = widget.onLongPress;
    if (onLong != null) {
      _longPress?.cancel();
      _longPress = Timer(Times.longPressClear, () => onLong(outcome));
    }
  }

  void _pointerUp(PointerEvent event) {
    if (!_down.remove(event.pointer)) return;
    widget.releasePointer(event.pointer);
    if (_down.isEmpty) {
      _longPress?.cancel();
      _press.reverse();
    }
  }

  void _keyboardActivate() {
    _press
      ..value = 1
      ..reverse();
    widget.onDown();
  }

  @override
  Widget build(BuildContext context) {
    final WaiterTheme theme = context.waiter;
    final WaiterColors c = theme.colors;
    const BorderRadius radius = BorderRadius.all(
      Radius.circular(KeypadTokens.keyRadius),
    );
    final Widget glyph = widget.isDelete
        ? WaiterIconView(WaiterIcon.delete)
        : ScaledText(
            widget.label,
            type: TypeTokens.key,
            textAlign: TextAlign.center,
          );

    final Widget visual = AnimatedBuilder(
      animation: _curve,
      builder: (BuildContext context, Widget? child) {
        final double t = _curve.value;
        return Transform.scale(
          scale: 1 - (1 - Motion.pressScaleKey) * t,
          child: FocusRing(
            visible: _focused,
            radius: radius,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: Color.lerp(c.bgKey, c.bgKeyPressed, t),
                shape: waiterShape(
                  context,
                  radius,
                  side: innerSide(
                    theme.outlinesControls ? c.borderControl : null,
                  ),
                ),
              ),
              child: child,
            ),
          ),
        );
      },
      child: SizedBox(
        height: widget.height,
        child: Center(child: glyph),
      ),
    );

    return Semantics(
      container: true,
      button: true,
      keyboardKey: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      onTap: widget.enabled ? widget.onDown : null,
      onLongPress: widget.enabled && widget.onLongPress != null
          ? () => widget.onLongPress!(EntryOutcome.ignored)
          : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: widget.enabled,
        onShowFocusHighlight: (bool v) => setState(() => _focused = v),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent _) {
              _keyboardActivate();
              return null;
            },
          ),
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _pointerDown,
          onPointerUp: _pointerUp,
          onPointerCancel: _pointerUp,
          child: visual,
        ),
      ),
    );
  }
}
