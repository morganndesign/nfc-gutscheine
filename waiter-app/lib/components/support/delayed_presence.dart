import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/theme/theme.dart';

/// The loading-indicator timing rule shared by Spinner and Skeleton
/// (04 §17.1–17.3, 05 §3.6–3.7): nothing for the first 150 ms
/// (`time.feedbackDelay`), and once shown the indicator stays at least
/// 240 ms (`time.minIndicator`) so it never flickers.
///
/// [builder] receives whether the indicator is currently visible.
class DelayedPresence extends StatefulWidget {
  /// Creates the timing wrapper.
  const DelayedPresence({
    required this.active,
    required this.builder,
    super.key,
    this.delay = Times.feedbackDelay,
    this.minimum = Times.minIndicator,
  });

  /// Whether the wait is in progress.
  final bool active;

  /// Builds the content for the visible flag.
  final Widget Function(BuildContext context, bool visible) builder;

  /// Delay before the indicator appears.
  final Duration delay;

  /// Minimum time on screen once it appeared.
  final Duration minimum;

  @override
  State<DelayedPresence> createState() => _DelayedPresenceState();
}

class _DelayedPresenceState extends State<DelayedPresence> {
  Timer? _showTimer;
  Timer? _minimumTimer;
  bool _visible = false;
  bool _minimumReached = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _scheduleShow();
  }

  @override
  void didUpdateWidget(DelayedPresence old) {
    super.didUpdateWidget(old);
    if (widget.active == old.active) return;
    if (widget.active) {
      if (!_visible) _scheduleShow();
    } else {
      _showTimer?.cancel();
      if (_visible && _minimumReached) _hide();
    }
  }

  void _scheduleShow() {
    _showTimer?.cancel();
    _showTimer = Timer(widget.delay, () {
      if (!mounted) return;
      _minimumReached = false;
      _minimumTimer?.cancel();
      _minimumTimer = Timer(widget.minimum, () {
        _minimumReached = true;
        if (!widget.active) _hide();
      });
      setState(() => _visible = true);
    });
  }

  void _hide() {
    if (!mounted) return;
    setState(() => _visible = false);
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _minimumTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _visible);
}
