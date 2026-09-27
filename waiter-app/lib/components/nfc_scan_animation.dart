import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../core/theme/theme.dart';

/// Reader state shown by [NfcScanAnimation] (05 §3.4).
enum NfcScanState {
  /// Ready, not listening (iPhone decorative motif): static arcs
  /// 0.80 / 0.56 / 0.32, glow breathing 12 % ↔ 24 %.
  idle,

  /// Android reader mode active: breathing (06 M04, 13 · R07).
  listening,

  /// Tag detected, read in progress: scale 1.06, arcs 1.0, glow 64 %
  /// (06 M05).
  reading,

  /// Read OK: rings converge into the card and fade (06 M06, 13 · R08).
  success,

  /// Read failed: back to rest over 240 ms, no shake; breathing resumes
  /// after 400 ms (06 M05).
  error,

  /// NFC off (S16): static idle arcs in `fg.tertiary`, hollow dot, no glow.
  disabled,
}

/// Values of one frame.
@immutable
class _Rings {
  const _Rings(this.scale, this.inner, this.middle, this.outer, this.glow);

  final double scale;
  final double inner;
  final double middle;
  final double outer;
  final double glow;

  static _Rings lerp(_Rings a, _Rings b, double t) => _Rings(
    lerpDouble(a.scale, b.scale, t)!,
    lerpDouble(a.inner, b.inner, t)!,
    lerpDouble(a.middle, b.middle, t)!,
    lerpDouble(a.outer, b.outer, t)!,
    lerpDouble(a.glow, b.glow, t)!,
  );
}

/// The Ready screen's signature (05 §3.4, 06 M04–M06): three concentric
/// saffron arcs (r 36 / 56 / 76, stroke 3, 100° sweep about 12 o'clock) on
/// a 176 × 120 canvas with an 8-pt emitter dot and a radial glow
/// (radius 96, may overflow the canvas).
///
/// Listening breathes with a 2.4-s period (sine in-out halves, group scale
/// 1.00 ↔ 1.04, the outer arc lagging 120 ms). Reading, success and error
/// retarget from the current values — never snap. Reduce Motion: static
/// rings at rest values; state changes become 160-ms opacity fades (no
/// scale). High contrast uses `color.nfc.arc.hc`. Decorative: hidden from
/// assistive technology. Tickers stop when the app is not visible.
class NfcScanAnimation extends StatefulWidget {
  /// Creates the animation.
  const NfcScanAnimation({required this.state, super.key});

  /// Reader state.
  final NfcScanState state;

  @override
  State<NfcScanAnimation> createState() => _NfcScanAnimationState();
}

class _NfcScanAnimationState extends State<NfcScanAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: NfcScanTokens.breathPeriod,
  );
  late final AnimationController _move = AnimationController(vsync: this);
  _Rings _from = _rest;
  _Rings _to = _rest;
  Curve _curve = Curves.linear;
  bool _transitioning = false;
  Timer? _resume;

  /// 06 M04 rest and peak (Android listening).
  static const _Rings _rest = _Rings(1, 1, 0.72, 0.44, 0.24);
  static const _Rings _peak = _Rings(
    NfcScanTokens.breathScale,
    1,
    1,
    0.8,
    0.48,
  );

  /// 05 §3.4 idle arcs; iPhone glow 12 % ↔ 24 %.
  static const _Rings _idleRest = _Rings(
    1,
    Opacities.nfcIdleInner,
    Opacities.nfcIdleMiddle,
    Opacities.nfcIdleOuter,
    0.12,
  );
  static const double _idleGlowPeak = 0.24;

  /// 06 §2.4: static rings under Reduce Motion.
  static const _Rings _reducedRest = _Rings(1, 1, 0.72, 0.44, 0.32);

  /// 06 M05 reading.
  static const _Rings _reading = _Rings(
    NfcScanTokens.readingScale,
    1,
    1,
    1,
    0.64,
  );

  /// 06 M06 converge end.
  static const _Rings _converged = _Rings(0.6, 0, 0, 0, 0);

  /// Breathing resumes this long after a failed read (06 M05).
  static const Duration _resumeDelay = Duration(milliseconds: 400);

  /// Sine in-out of 06 §2.3 (proposal `motion.ease.breath`).
  static const Cubic _sine = Cubic(0.37, 0, 0.63, 1);

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
  }

  @override
  void didUpdateWidget(NfcScanAnimation old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _enter(widget.state);
  }

  @override
  void dispose() {
    _resume?.cancel();
    _breath.dispose();
    _move.dispose();
    super.dispose();
  }

  bool get _breathing =>
      !_reduced &&
      !_transitioning &&
      (widget.state == NfcScanState.listening ||
          widget.state == NfcScanState.idle);

  void _syncLoop() {
    if (_breathing) {
      if (!_breath.isAnimating) _breath.repeat();
    } else {
      _breath.stop();
    }
  }

  _Rings _restFor(NfcScanState state) {
    if (state == NfcScanState.idle || state == NfcScanState.disabled) {
      return _idleRest;
    }
    return _reduced ? _reducedRest : _rest;
  }

  void _enter(NfcScanState state) {
    _resume?.cancel();
    final _Rings current = _current();
    final bool reduced = _reduced;
    switch (state) {
      case NfcScanState.reading:
        _animate(
          current,
          _reading,
          reduced ? Motion.durationFast : Motion.durationInstant,
          Motion.easeStandard,
        );
      case NfcScanState.success:
        _animate(
          current,
          reduced ? _Rings(current.scale, 0, 0, 0, 0) : _converged,
          reduced ? Motion.durationFast : Motion.durationBase,
          reduced ? Motion.easeStandard : Motion.easeAccelerate,
        );
      case NfcScanState.error:
        _animate(
          current,
          _restFor(NfcScanState.listening),
          reduced ? Motion.durationFast : Motion.durationBase,
          Motion.easeDecelerate,
          then: () => _resume = Timer(_resumeDelay, () {
            if (!mounted) return;
            setState(() => _transitioning = false);
            _syncLoop();
          }),
        );
      case NfcScanState.listening:
      case NfcScanState.idle:
      case NfcScanState.disabled:
        _animate(
          current,
          _restFor(state),
          Motion.durationFast,
          Motion.easeStandard,
          then: () {
            if (!mounted) return;
            setState(() => _transitioning = false);
            _breath.value = 0;
            _syncLoop();
          },
        );
    }
  }

  void _animate(
    _Rings from,
    _Rings to,
    Duration duration,
    Curve curve, {
    VoidCallback? then,
  }) {
    _breath.stop();
    setState(() {
      _from = from;
      _to = to;
      _curve = curve;
      _transitioning = true;
    });
    _move.duration = duration;
    // Runs only when this transition completes; a newer state cancels the
    // ticker and its continuation never fires.
    unawaited(_move.forward(from: 0).then((_) => then?.call()));
  }

  double _phase(double ms) {
    final int period = NfcScanTokens.breathPeriod.inMilliseconds;
    final double t = ((ms % period) + period) % period;
    final double half = period / 2;
    return t < half
        ? _sine.transform(t / half)
        : _sine.transform(1 - (t - half) / half);
  }

  _Rings _current() {
    if (_transitioning) {
      return _Rings.lerp(_from, _to, _curve.transform(_move.value));
    }
    final NfcScanState state = widget.state;
    if (state == NfcScanState.disabled) return _idleRest;
    if (state == NfcScanState.success) return _converged;
    if (state == NfcScanState.reading) return _reading;
    if (state == NfcScanState.idle) {
      if (_reduced) return _idleRest;
      final double v = _phase(_breath.value * _periodMs);
      return _Rings(
        1,
        _idleRest.inner,
        _idleRest.middle,
        _idleRest.outer,
        lerpDouble(_idleRest.glow, _idleGlowPeak, v)!,
      );
    }
    if (_reduced) return _reducedRest;
    final double ms = _breath.value * _periodMs;
    final _Rings wave = _Rings.lerp(_rest, _peak, _phase(ms));
    final double lagged = _phase(ms - NfcScanTokens.outerLag.inMilliseconds);
    return _Rings(
      wave.scale,
      wave.inner,
      wave.middle,
      lerpDouble(_rest.outer, _peak.outer, lagged)!,
      wave.glow,
    );
  }

  static final double _periodMs = NfcScanTokens.breathPeriod.inMilliseconds
      .toDouble();

  @override
  Widget build(BuildContext context) {
    final WaiterTheme theme = context.waiter;
    final bool disabled = widget.state == NfcScanState.disabled;
    final Color color = disabled ? theme.colors.fgTertiary : theme.nfcArc;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          width: Sizes.nfcCanvasWidth,
          height: Sizes.nfcCanvasHeight,
          child: CustomPaint(
            painter: _NfcPainter(
              repaint: Listenable.merge(<Listenable>[_breath, _move]),
              values: _current,
              color: color,
              hollowDot: disabled,
              glow: !disabled,
            ),
          ),
        ),
      ),
    );
  }
}

class _NfcPainter extends CustomPainter {
  _NfcPainter({
    required Listenable repaint,
    required this.values,
    required this.color,
    required this.hollowDot,
    required this.glow,
  }) : super(repaint: repaint);

  final _Rings Function() values;
  final Color color;
  final bool hollowDot;
  final bool glow;

  static const double _sweep = Sizes.nfcArcSweep * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final _Rings v = values();
    final Offset centre = Offset(size.width / 2, NfcScanTokens.centerY);
    if (glow && v.glow > 0) {
      canvas.drawCircle(
        centre,
        NfcScanTokens.glowRadius,
        Paint()
          ..shader =
              RadialGradient(
                colors: <Color>[
                  color.withValues(alpha: v.glow),
                  color.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromCircle(
                  center: centre,
                  radius: NfcScanTokens.glowRadius,
                ),
              ),
      );
    }
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..scale(v.scale)
      ..translate(-centre.dx, -centre.dy);
    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = Sizes.nfcArcStroke
      ..strokeCap = StrokeCap.round;
    const double start = -math.pi / 2 - _sweep / 2;
    final List<(double, double)> arcs = <(double, double)>[
      (Sizes.nfcArcR1, v.inner),
      (Sizes.nfcArcR2, v.middle),
      (Sizes.nfcArcR3, v.outer),
    ];
    for (final (double radius, double opacity) in arcs) {
      if (opacity <= 0) continue;
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        start,
        _sweep,
        false,
        arc..color = color.withValues(alpha: opacity.clamp(0.0, 1.0)),
      );
    }
    canvas.restore();
    const double dotRadius = NfcScanTokens.dot / 2;
    canvas.drawCircle(
      centre,
      hollowDot ? dotRadius - NfcScanTokens.disabledDotStroke / 2 : dotRadius,
      Paint()
        ..color = color.withValues(alpha: v.inner.clamp(0.0, 1.0))
        ..style = hollowDot ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = NfcScanTokens.disabledDotStroke,
    );
  }

  @override
  bool shouldRepaint(_NfcPainter old) =>
      old.color != color || old.hollowDot != hollowDot || old.glow != glow;
}
