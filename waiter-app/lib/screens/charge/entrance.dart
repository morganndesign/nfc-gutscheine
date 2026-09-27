import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';

/// Plays a one-time fade + rise when first built (06 M08 action region,
/// M18 S09 stagger, M25 card-state banner): after [delay], opacity 0 → 1
/// and y +[rise] → 0 over [duration] with `ease.decelerate`. Under Reduce
/// Motion a 160-ms fade without delay or movement. The child is
/// interactive from the first frame (06 M08 "keys are live from frame 1").
class Entrance extends StatefulWidget {
  /// Creates the entrance.
  const Entrance({
    required this.child,
    super.key,
    this.delay = Duration.zero,
    this.duration = Motion.durationBase,
    this.rise = Space.s4,
  });

  /// Content.
  final Widget child;

  /// Start offset after the first build.
  final Duration delay;

  /// Fade/rise duration.
  final Duration duration;

  /// Start offset below the final position in pt.
  final double rise;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Motion.easeDecelerate,
  );
  Timer? _delay;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controller.isDismissed || _delay != null) return;
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _controller
        ..duration = Motion.durationFast
        ..forward();
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _delay = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: _reduced
          ? widget.child
          : AnimatedBuilder(
              animation: _curve,
              builder: (BuildContext context, Widget? child) =>
                  Transform.translate(
                    offset: Offset(0, widget.rise * (1 - _curve.value)),
                    child: child,
                  ),
              child: widget.child,
            ),
    );
  }
}
