import 'package:flutter/widgets.dart';

import '../core/theme/theme.dart';

/// The quiet 4-s auto-return visual of S09 (05 §3.9, 06 M19).
///
/// A 2-pt `color.fg.tertiary` line (no track), full width edge to edge,
/// shrinking linearly toward the leading edge over [duration]; at 0 it
/// calls [onFinished]. It pauses while [paused] (a `z.system` layer is
/// visible) and while the app is not in the foreground, and resumes with
/// the remaining time. Remove it to cancel (tap, new card, back). Kept
/// under Reduce Motion (a progress indicator). Hidden from assistive
/// technology.
class CountdownHairline extends StatefulWidget {
  /// Creates the hairline; it starts when first built.
  const CountdownHairline({
    super.key,
    this.duration = Times.successReturn,
    this.paused = false,
    this.onFinished,
  });

  /// Full run: 4 s, or the extended duration while a screen reader or
  /// Switch Control runs (07 §8.4: 10 s).
  final Duration duration;

  /// Freezes the countdown.
  final bool paused;

  /// Called once when the line reaches 0.
  final VoidCallback? onFinished;

  @override
  State<CountdownHairline> createState() => _CountdownHairlineState();
}

class _CountdownHairlineState extends State<CountdownHairline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _remaining = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  late final AppLifecycleListener _lifecycle;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _remaining.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.dismissed) widget.onFinished?.call();
    });
    _lifecycle = AppLifecycleListener(
      onStateChange: (AppLifecycleState state) {
        _foreground = state == AppLifecycleState.resumed;
        _sync();
      },
    );
    _sync();
  }

  @override
  void didUpdateWidget(CountdownHairline old) {
    super.didUpdateWidget(old);
    if (old.duration != widget.duration) _remaining.duration = widget.duration;
    _sync();
  }

  void _sync() {
    final bool run = _foreground && !widget.paused;
    if (run && !_remaining.isAnimating && _remaining.value > 0) {
      _remaining.reverse();
    } else if (!run && _remaining.isAnimating) {
      _remaining.stop();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _remaining.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: double.infinity,
        height: Sizes.hairlineCountdown,
        child: AnimatedBuilder(
          animation: _remaining,
          builder: (BuildContext context, Widget? line) => FractionallySizedBox(
            widthFactor: _remaining.value,
            alignment: AlignmentDirectional.centerStart,
            child: line,
          ),
          child: ColoredBox(color: context.colors.fgTertiary),
        ),
      ),
    );
  }
}
