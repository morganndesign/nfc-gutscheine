import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/format/format.dart';
import '../core/theme/theme.dart';
import 'support/announce.dart';

/// Determinate circular progress (05 §3.5, 04 §18): a full-circle track
/// plus a progress arc from 12 o'clock, clockwise (in RTL too — a clock
/// direction), 3-pt round caps. Linear in time; unchanged under Reduce
/// Motion.
///
/// - [ProgressRing.hold]: 28 pt inside the HoldButton, fills 0 → 1; hidden
///   from assistive technology (the button speaks for it).
/// - [ProgressRing.countdown]: 48 pt, starts full and empties as time runs
///   out, whole seconds (ceil) in the centre; fades out at 0 and announces
///   [finishedAnnouncement].
class ProgressRing extends StatefulWidget {
  /// The hold ring (`color.hold.track` / `color.hold.progress`, 13 · R05).
  const ProgressRing.hold({
    required double this.progress,
    super.key,
    this.trackColor,
    this.progressColor,
    this.dashed = false,
  }) : remaining = null,
       total = null,
       finishedAnnouncement = null,
       onFinished = null,
       semanticsLabel = null;

  /// The countdown ring for `retry_after` waits (S10 throttled, S15
  /// locked). [remaining] is the time left when this widget is built; the
  /// ring then runs down by itself every frame.
  const ProgressRing.countdown({
    required Duration this.remaining,
    required Duration this.total,
    super.key,
    this.finishedAnnouncement,
    this.onFinished,
    this.semanticsLabel,
  }) : progress = null,
       trackColor = null,
       progressColor = null,
       dashed = false;

  /// Hold progress 0 → 1.
  final double? progress;

  /// Track colour override (disabled HoldButton: `fg.tertiary` at 24 %).
  final Color? trackColor;

  /// Progress colour override.
  final Color? progressColor;

  /// Draws the full ring as a dashed outline (HoldButton armed, 07 §5.3).
  final bool dashed;

  /// Time left at build.
  final Duration? remaining;

  /// Full wait (the ring's 100 %).
  final Duration? total;

  /// Announced politely when the countdown reaches 0 (`a11y.scanAvailable`,
  /// `locked.over`, `a11y.redeemAvailable`).
  final String? finishedAnnouncement;

  /// Called once when the countdown reaches 0.
  final VoidCallback? onFinished;

  /// Accessibility label of the countdown ("progress indicator" role); the
  /// value is the remaining time as `m:ss`.
  final String? semanticsLabel;

  bool get _isCountdown => remaining != null;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with TickerProviderStateMixin {
  AnimationController? _clock;
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: Motion.durationFast,
    value: 1,
  );
  int _shownSeconds = 0;

  @override
  void initState() {
    super.initState();
    if (widget._isCountdown) _startCountdown();
  }

  @override
  void didUpdateWidget(ProgressRing old) {
    super.didUpdateWidget(old);
    if (widget._isCountdown &&
        (old.remaining != widget.remaining || old.total != widget.total)) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    final Duration total = widget.total!;
    final Duration remaining = widget.remaining! > total
        ? total
        : widget.remaining!;
    final AnimationController clock = _clock ??=
        AnimationController(vsync: this)
          ..addListener(_tick)
          ..addStatusListener(_status);
    clock.duration = total;
    final double start = total.inMicroseconds == 0
        ? 0
        : remaining.inMicroseconds / total.inMicroseconds;
    _shownSeconds = DateTimeFormat.ceilSeconds(remaining);
    if (start <= 0) {
      clock.value = 0;
      _fade.value = 0;
      return;
    }
    _fade.value = 1;
    clock
      ..value = start
      ..animateBack(0, duration: remaining, curve: Curves.linear);
  }

  void _tick() {
    final int seconds = DateTimeFormat.ceilSeconds(
      widget.total! * _clock!.value,
    );
    if (seconds != _shownSeconds) setState(() => _shownSeconds = seconds);
  }

  void _status(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || !mounted) return;
    _fade.reverse();
    final String? message = widget.finishedAnnouncement;
    if (message != null) announce(context, message);
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _clock?.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    if (!widget._isCountdown) {
      return ExcludeSemantics(
        child: SizedBox.square(
          dimension: Sizes.ringHold,
          child: CustomPaint(
            painter: RingPainter(
              progress: widget.progress!.clamp(0.0, 1.0),
              trackColor: widget.trackColor ?? c.holdTrack,
              progressColor: widget.progressColor ?? c.holdProgress,
              stroke: Sizes.ringHoldStroke,
              dashed: widget.dashed,
            ),
          ),
        ),
      );
    }
    final AnimationController clock = _clock!;
    return Semantics(
      label: widget.semanticsLabel,
      value: DateTimeFormat.countdown(Duration(seconds: _shownSeconds)),
      child: FadeTransition(
        opacity: _fade,
        child: SizedBox.square(
          dimension: Sizes.ringCountdown,
          child: CustomPaint(
            painter: RingPainter(
              progress: clock.value,
              repaint: clock,
              progressOf: () => clock.value,
              trackColor: c.borderSubtle,
              progressColor: c.fgPrimary,
              stroke: Sizes.ringCountdownStroke,
            ),
            child: Center(
              child: ExcludeSemantics(
                child: ScaledText(
                  '$_shownSeconds',
                  type: TypeTokens.label,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a ring: full-circle track plus an arc from 12 o'clock clockwise.
class RingPainter extends CustomPainter {
  /// Creates the painter. When [progressOf] is given it is read at paint
  /// time (driven by [repaint]); otherwise [progress] is used.
  RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.stroke,
    this.dashed = false,
    this.progressOf,
    super.repaint,
  });

  /// Progress 0 → 1.
  final double progress;

  /// Live progress source.
  final double Function()? progressOf;

  /// Track colour.
  final Color trackColor;

  /// Arc colour.
  final Color progressColor;

  /// Stroke width.
  final double stroke;

  /// Dashed full ring (armed state).
  final bool dashed;

  static const int _dashes = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = (Offset.zero & size).deflate(stroke / 2);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = trackColor);
    paint.color = progressColor;
    if (dashed) {
      const double step = 2 * math.pi / _dashes;
      for (int i = 0; i < _dashes; i++) {
        canvas.drawArc(rect, -math.pi / 2 + i * step, step / 2, false, paint);
      }
      return;
    }
    final double value = (progressOf?.call() ?? progress).clamp(0.0, 1.0);
    if (value <= 0) return;
    canvas.drawArc(rect, -math.pi / 2, value * 2 * math.pi, false, paint);
  }

  @override
  bool shouldRepaint(RingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor ||
      old.stroke != stroke ||
      old.dashed != dashed;
}
