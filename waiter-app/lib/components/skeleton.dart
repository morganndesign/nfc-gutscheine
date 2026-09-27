import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/theme/theme.dart';
import 'support/delayed_presence.dart';

/// Geist cap height as a fraction of the font size (710 / 1000 units).
const double _capHeightRatio = 0.71;

/// Height of a skeleton text line for [type]: the final text's cap height
/// rounded to an even number (05 §3.6: 10 for `type.body.m`, 12 for
/// `type.body.l`).
double skeletonLineHeight(TypeSpec type) =>
    (type.fontSize * _capHeightRatio / 2).round() * 2;

/// One synchronised shimmer for every skeleton shape below it (05 §3.6,
/// 04 §17.3, 06 M10): a band 40 % of the group's width, angled 20°,
/// travelling leading → trailing in 1.2 s, linear, no pause; each
/// [SkeletonBox] clips the band. Under Reduce Motion the group is static
/// at 60 % opacity (06 M10). Shapes are hidden from assistive technology;
/// [semanticsLabel] is the container's busy label.
class SkeletonGroup extends StatefulWidget {
  /// Creates a group.
  const SkeletonGroup({required this.child, super.key, this.semanticsLabel});

  /// Skeleton shapes laid out like the final content.
  final Widget child;

  /// Busy label of the container.
  final String? semanticsLabel;

  @override
  State<SkeletonGroup> createState() => _SkeletonGroupState();
}

class _SkeletonGroupState extends State<SkeletonGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: Times.skeletonSweep,
  );
  final GlobalKey _groupKey = GlobalKey();

  /// Reduce Motion: static skeleton at 60 % opacity (06 M10).
  static const double _staticOpacity = 0.6;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      excludeSemantics: true,
      child: Opacity(
        opacity: still ? _staticOpacity : 1,
        child: _SweepScope(
          sweep: still ? null : _sweep,
          groupKey: _groupKey,
          child: KeyedSubtree(key: _groupKey, child: widget.child),
        ),
      ),
    );
  }
}

class _SweepScope extends InheritedWidget {
  const _SweepScope({
    required this.sweep,
    required this.groupKey,
    required super.child,
  });

  final Animation<double>? sweep;
  final GlobalKey groupKey;

  @override
  bool updateShouldNotify(_SweepScope old) =>
      old.sweep != sweep || old.groupKey != groupKey;
}

/// A placeholder rectangle with its final radius (`Block`), or a fully
/// rounded text line ([SkeletonBox.line]). Base `color.skeleton.base`,
/// sweep `color.skeleton.highlight`; the BalanceCard skeleton passes the
/// card text colour at 16 % / 8 %.
class SkeletonBox extends StatelessWidget {
  /// A block with [radius].
  const SkeletonBox({
    required this.width,
    required this.height,
    super.key,
    this.radius = Radii.xs,
    this.baseColor,
    this.highlightColor,
  });

  /// A text line for [type] of [width]: cap-height tall, fully rounded.
  SkeletonBox.line({
    required this.width,
    required TypeSpec type,
    super.key,
    this.baseColor,
    this.highlightColor,
  }) : height = skeletonLineHeight(type),
       radius = skeletonLineHeight(type) / 2;

  /// Width in pt (`double.infinity` = available width).
  final double width;

  /// Height in pt.
  final double height;

  /// Corner radius.
  final double radius;

  /// Base colour override.
  final Color? baseColor;

  /// Highlight colour override.
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    final _SweepScope? scope = context
        .dependOnInheritedWidgetOfExactType<_SweepScope>();
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SkeletonPainter(
          base: baseColor ?? c.skeletonBase,
          highlight: highlightColor ?? c.skeletonHighlight,
          radius: radius,
          sweep: scope?.sweep,
          groupBox: () =>
              scope?.groupKey.currentContext?.findRenderObject() as RenderBox?,
          selfBox: () => context.findRenderObject() as RenderBox?,
        ),
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter({
    required this.base,
    required this.highlight,
    required this.radius,
    required this.sweep,
    required this.groupBox,
    required this.selfBox,
  }) : super(repaint: sweep);

  final Color base;
  final Color highlight;
  final double radius;
  final Animation<double>? sweep;
  final RenderBox? Function() groupBox;
  final RenderBox? Function() selfBox;

  /// Band width as a fraction of the group (04 §17.3).
  static const double _band = 0.4;

  /// Band angle from vertical.
  static const double _angle = 20 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(math.min(radius, size.shortestSide / 2)),
    );
    canvas.drawRRect(shape, Paint()..color = base);
    final Animation<double>? anim = sweep;
    final RenderBox? group = groupBox();
    final RenderBox? self = selfBox();
    if (anim == null ||
        group == null ||
        self == null ||
        !group.hasSize ||
        !self.attached ||
        !group.attached) {
      return;
    }
    final double groupWidth = group.size.width;
    final double bandWidth = groupWidth * _band;
    // Travels from x = −40 % to x = 140 % of the group (06 M10).
    final double bandStart = -bandWidth + anim.value * (groupWidth + bandWidth);
    final double selfX = self.localToGlobal(Offset.zero, ancestor: group).dx;
    final double left = bandStart - selfX;
    final Rect bandRect = Rect.fromLTWH(left, 0, bandWidth, size.height);
    final Paint paint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          highlight.withValues(alpha: 0),
          highlight,
          highlight.withValues(alpha: 0),
        ],
        transform: const GradientRotation(_angle),
      ).createShader(bandRect);
    canvas
      ..save()
      ..clipRRect(shape)
      ..drawRect(bandRect.inflate(size.height), paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) =>
      old.base != base ||
      old.highlight != highlight ||
      old.radius != radius ||
      old.sweep != sweep;
}

/// Loading → content hand-off (05 §3.6, 04 §17.1): nothing for 150 ms,
/// then the [skeleton] (identical geometry to [child]) for at least
/// 240 ms, then a `motion.duration.fast` cross-fade to [child].
class SkeletonSwitcher extends StatelessWidget {
  /// Creates the switcher.
  const SkeletonSwitcher({
    required this.loading,
    required this.skeleton,
    required this.child,
    super.key,
  });

  /// Whether content is still loading.
  final bool loading;

  /// The skeleton (usually a [SkeletonGroup]).
  final Widget skeleton;

  /// The content; shown when not loading.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DelayedPresence(
      active: loading,
      builder: (BuildContext context, bool visible) {
        final bool showSkeleton = loading || visible;
        return AnimatedSwitcher(
          duration: Motion.durationFast,
          switchInCurve: Motion.easeStandard,
          switchOutCurve: Motion.easeStandard,
          child: showSkeleton
              ? KeyedSubtree(
                  key: const ValueKey<String>('skeleton'),
                  child: AnimatedOpacity(
                    opacity: visible ? 1 : 0,
                    duration: Motion.durationFast,
                    child: skeleton,
                  ),
                )
              : KeyedSubtree(
                  key: const ValueKey<String>('content'),
                  child: child,
                ),
        );
      },
    );
  }
}
