import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/format/format.dart';

/// Rebuilds exactly when the displayed whole second changes until a deadline
/// on the monotonic clock (03a §2 "countdown labels update every second",
/// §10.4 "countdown uses the monotonic clock, not wall time").
///
/// [builder] receives the time left (never negative); [onFinished] runs once,
/// after the frame in which the time left reached zero.
class MonotonicCountdown extends StatefulWidget {
  const MonotonicCountdown({required this.until, required this.now, required this.builder, super.key, this.onFinished});

  /// Deadline on the monotonic clock.
  final Duration until;

  /// The monotonic clock (`services.loop.now`).
  final Duration Function() now;

  /// Builds the content for the time left.
  final Widget Function(BuildContext context, Duration remaining) builder;

  /// Called once when the countdown reaches zero.
  final VoidCallback? onFinished;

  @override
  State<MonotonicCountdown> createState() => _MonotonicCountdownState();
}

class _MonotonicCountdownState extends State<MonotonicCountdown> {
  Timer? _timer;
  bool _finished = false;

  Duration get _remaining {
    final Duration left = widget.until - widget.now();
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(MonotonicCountdown old) {
    super.didUpdateWidget(old);
    if (old.until != widget.until) {
      _finished = false;
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    final Duration left = _remaining;
    if (left == Duration.zero) {
      if (_finished) return;
      _finished = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished?.call();
      });
      return;
    }
    // Wake up when the ceiled second shown changes.
    final int shown = DateTimeFormat.ceilSeconds(left);
    _timer = Timer(left - Duration(seconds: shown - 1), _tick);
  }

  void _tick() {
    if (!mounted) return;
    setState(_schedule);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _remaining);
}
