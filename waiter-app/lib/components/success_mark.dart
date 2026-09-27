import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../core/platform/feedback_scope.dart';
import '../core/theme/theme.dart';

/// The drawn check that marks money successfully moved (05 §3.8, 06 M18,
/// 13 · R09 / R22).
///
/// t = 0: `haptic.success` + `sound.success` (11 T3); the halo (a 24-pt
/// `color.success.bg` ring) scales 0.6 → 1 with `motion.spring.card`; the
/// circle stroke (3 pt, `color.success`) draws from 12 o'clock clockwise
/// over 240 ms (`ease.standard`) and its fill fades in over 90 ms at 240.
/// t = 240: the check (stroke 6, `color.fg.onSuccess`, round caps/joins)
/// draws over 200 ms (`ease.decelerate`), short leg then long leg.
/// Reduce Motion: circle and check fade in together over 160 ms; feedback
/// still at t = 0. Never loops. Hidden from assistive technology.
class SuccessMark extends StatefulWidget {
  /// Creates the mark; it plays once when first built.
  const SuccessMark({super.key, this.playFeedback = true});

  /// Whether the mark fires `haptic.success` + `sound.success` at t = 0.
  final bool playFeedback;

  @override
  State<SuccessMark> createState() => _SuccessMarkState();
}

class _SuccessMarkState extends State<SuccessMark>
    with TickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: SuccessMarkTokens.circleDraw + SuccessMarkTokens.checkDraw,
  );
  late final AnimationController _halo = AnimationController.unbounded(
    vsync: this,
    value: _haloStart,
  );
  bool _started = false;

  static const double _haloStart = 0.6;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.playFeedback) {
      context
        ..haptic(HapticToken.success)
        ..sound(SoundToken.success);
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _draw
        ..duration = Motion.durationFast
        ..forward();
      _halo.value = 1;
    } else {
      _draw.forward();
      _halo.animateWith(SpringSimulation(Motion.springCard, _haloStart, 1, 0));
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _halo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: SuccessMarkTokens.size,
        child: CustomPaint(
          painter: _SuccessPainter(
            repaint: Listenable.merge(<Listenable>[_draw, _halo]),
            draw: _draw,
            halo: _halo,
            reduced: reduced,
            success: c.success,
            successBg: c.successBg,
            check: c.fgOnSuccess,
          ),
        ),
      ),
    );
  }
}

class _SuccessPainter extends CustomPainter {
  _SuccessPainter({
    required Listenable repaint,
    required this.draw,
    required this.halo,
    required this.reduced,
    required this.success,
    required this.successBg,
    required this.check,
  }) : super(repaint: repaint);

  final Animation<double> draw;
  final Animation<double> halo;
  final bool reduced;
  final Color success;
  final Color successBg;
  final Color check;

  static const double _circleStroke = 3;
  static const double _haloWidth = 24;

  /// Check points on the 96-pt box (05 §3.8).
  static const List<Offset> _checkPoints = <Offset>[
    Offset(28, 50),
    Offset(42, 64),
    Offset(68, 36),
  ];

  static final int _totalMs =
      (SuccessMarkTokens.circleDraw + SuccessMarkTokens.checkDraw)
          .inMilliseconds;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / SuccessMarkTokens.size;
    final Offset centre = size.center(Offset.zero);
    final double radius = size.width / 2;

    if (reduced) {
      final double o = draw.value;
      canvas.drawCircle(
        centre,
        radius,
        Paint()..color = success.withValues(alpha: o),
      );
      _drawCheck(canvas, scale, 1, check.withValues(alpha: o));
      return;
    }

    final double ms = draw.value * _totalMs;
    final double circleT = Motion.easeStandard.transform(
      (ms / SuccessMarkTokens.circleDraw.inMilliseconds).clamp(0.0, 1.0),
    );
    final double fillT =
        ((ms - SuccessMarkTokens.circleDraw.inMilliseconds) /
                Motion.durationInstant.inMilliseconds)
            .clamp(0.0, 1.0);
    final double checkT = Motion.easeDecelerate.transform(
      ((ms - SuccessMarkTokens.circleDraw.inMilliseconds) /
              SuccessMarkTokens.checkDraw.inMilliseconds)
          .clamp(0.0, 1.0),
    );

    canvas.drawCircle(
      centre,
      (radius + _haloWidth / 2) * halo.value,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _haloWidth * halo.value
        ..color = successBg,
    );
    if (fillT > 0) {
      canvas.drawCircle(
        centre,
        radius,
        Paint()..color = success.withValues(alpha: fillT),
      );
    }
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius - _circleStroke / 2),
      -math.pi / 2,
      circleT * 2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _circleStroke
        ..strokeCap = StrokeCap.round
        ..color = success,
    );
    if (checkT > 0) _drawCheck(canvas, scale, checkT, check);
  }

  void _drawCheck(Canvas canvas, double scale, double t, Color color) {
    final Path full = Path()
      ..moveTo(_checkPoints[0].dx * scale, _checkPoints[0].dy * scale)
      ..lineTo(_checkPoints[1].dx * scale, _checkPoints[1].dy * scale)
      ..lineTo(_checkPoints[2].dx * scale, _checkPoints[2].dy * scale);
    final PathMetric metric = full.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = SuccessMarkTokens.checkStroke * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_SuccessPainter old) =>
      old.reduced != reduced ||
      old.success != success ||
      old.successBg != successBg ||
      old.check != check;
}
