import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/theme/theme.dart';

/// Size variants of [Spinner] (05 §3.7).
enum SpinnerSize {
  /// 20 pt, 2-pt stroke — inside controls (brief).
  small(Sizes.spinnerS, Sizes.spinnerSStroke),

  /// 32 pt, 3-pt stroke — S01 and full-screen waits.
  large(Sizes.spinnerL, Sizes.spinnerLStroke);

  const SpinnerSize(this.diameter, this.stroke);

  /// Diameter in pt.
  final double diameter;

  /// Stroke width in pt.
  final double stroke;
}

/// Indeterminate progress (05 §3.7, 04 §17.2, 06 M29): a 270° arc on a
/// full track (current colour at 16 %), one turn per 800 ms, linear,
/// constant arc length. Keeps rotating under Reduce Motion. Hidden from
/// assistive technology — the owner announces the busy state.
///
/// The 150 ms appearance delay belongs to the owner (see the buttons,
/// which use `DelayedPresence`).
class Spinner extends StatefulWidget {
  /// Creates a spinner.
  const Spinner({super.key, this.size = SpinnerSize.small, this.color});

  /// Size variant.
  final SpinnerSize size;

  /// Arc colour; defaults to `fg.primary` (small) / `fg.secondary` (large).
  final Color? color;

  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: Times.spinnerTurn,
  )..repeat();

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color =
        widget.color ??
        (widget.size == SpinnerSize.large
            ? context.colors.fgSecondary
            : context.colors.fgPrimary);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size.diameter,
          child: CustomPaint(
            painter: _SpinnerPainter(
              turn: _turn,
              color: color,
              stroke: widget.size.stroke,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter({
    required this.turn,
    required this.color,
    required this.stroke,
  }) : super(repaint: turn);

  final Animation<double> turn;
  final Color color;
  final double stroke;

  static const double _sweep = 1.5 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = (Offset.zero & size).deflate(stroke / 2);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      paint..color = color.withValues(alpha: Opacities.spinnerTrack),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2 + turn.value * 2 * math.pi,
      _sweep,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) =>
      old.color != color || old.stroke != stroke || old.turn != turn;
}
