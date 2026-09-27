import 'package:flutter/widgets.dart';

import '../../core/theme/theme.dart';

/// Amplitude of one shake request (13 · R18).
enum ShakeAmplitude {
  /// Field error shake (M02) and over-balance shake (M14): ±6 pt.
  error(TextFieldTokens.shake),

  /// Limit-reached nudge (8th amount digit, 17th card digit, M12): ±3 pt.
  nudge(AmountDisplayTokens.limitNudge);

  const ShakeAmplitude(this.points);

  /// Horizontal amplitude in pt.
  final double points;
}

/// Triggers the horizontal "no" shake of a field container (06 M02, M12,
/// M14). Held by the screen; handed to TextField, CardNumberField or
/// AmountDisplay.
class ShakeController extends ChangeNotifier {
  ShakeAmplitude? _pending;
  bool _settle = false;

  /// Runs the ±6 pt error shake.
  void shake() => _request(ShakeAmplitude.error);

  /// Runs the ±3 pt limit-reached nudge.
  void nudge() => _request(ShakeAmplitude.nudge);

  /// Jumps a running shake to x = 0 (typing during the shake, M02 "C").
  void settle() {
    _settle = true;
    notifyListeners();
  }

  void _request(ShakeAmplitude amplitude) {
    _pending = amplitude;
    notifyListeners();
  }

  ShakeAmplitude? _takeRequest() {
    final ShakeAmplitude? value = _pending;
    _pending = null;
    return value;
  }

  bool _takeSettle() {
    final bool value = _settle;
    _settle = false;
    return value;
  }
}

/// Moves [child] horizontally as a unit when its [controller] asks
/// (keyframes of 06 M02: 0 → +A → −A → +A → −A → 0 at 0/30/90/150/210/240 ms,
/// `ease.standard` per segment). Removed under Reduce Motion: colour and
/// text carry the error instead.
class Shake extends StatefulWidget {
  /// Creates a shake wrapper.
  const Shake({required this.controller, required this.child, super.key});

  /// Source of shake requests.
  final ShakeController? controller;

  /// The field container.
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: Motion.durationBase,
  );
  double _amplitude = 0;

  static final Animatable<double> _keyframes =
      TweenSequence<double>(<TweenSequenceItem<double>>[
        _segment(0, 1, 30),
        _segment(1, -1, 60),
        _segment(-1, 1, 60),
        _segment(1, -1, 60),
        _segment(-1, 0, 30),
      ]);

  static TweenSequenceItem<double> _segment(double a, double b, double w) =>
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: a,
          end: b,
        ).chain(CurveTween(curve: Motion.easeStandard)),
        weight: w,
      );

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onRequest);
  }

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_onRequest);
      widget.controller?.addListener(_onRequest);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onRequest);
    _anim.dispose();
    super.dispose();
  }

  void _onRequest() {
    final ShakeController controller = widget.controller!;
    if (controller._takeSettle()) {
      _anim.value = 1;
      return;
    }
    final ShakeAmplitude? request = controller._takeRequest();
    if (request == null || MediaQuery.disableAnimationsOf(context)) return;
    _amplitude = request.points;
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (BuildContext context, Widget? child) {
        final double dx = _anim.isAnimating
            ? _keyframes.evaluate(_anim) * _amplitude
            : 0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}
