import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// Corner geometry per platform (04 §5.2): on iOS every radius ≥ 16 pt is a
/// continuous corner (squircle); Android and radii ≤ 12 pt use circular
/// arcs. `radius.full` is always a true semicircle.
OutlinedBorder waiterShape(
  BuildContext context,
  BorderRadius radius, {
  BorderSide side = BorderSide.none,
}) {
  final double largest = <double>[
    radius.topLeft.x,
    radius.topRight.x,
    radius.bottomLeft.x,
    radius.bottomRight.x,
  ].reduce((double a, double b) => a > b ? a : b);
  final bool continuous =
      Theme.of(context).platform == TargetPlatform.iOS &&
      largest >= Radii.continuousMin &&
      largest < Radii.full;
  return continuous
      ? RoundedSuperellipseBorder(borderRadius: radius, side: side)
      : RoundedRectangleBorder(borderRadius: radius, side: side);
}

/// [waiterShape] with the same [radius] on all corners.
OutlinedBorder waiterShapeAll(
  BuildContext context,
  double radius, {
  BorderSide side = BorderSide.none,
}) => waiterShape(context, BorderRadius.circular(radius), side: side);

/// A 1-pt inner outline when [color] is given (high-contrast control
/// outlines, dark-theme surface outlines), else no border.
BorderSide innerSide(Color? color, {double width = Borders.widthDefault}) =>
    color == null ? BorderSide.none : BorderSide(color: color, width: width);

/// Filled shape with an optional inner outline, shadows and gradient,
/// clipped to the same geometry (04 §5.2 "clipping uses the same shape").
class WaiterSurface extends StatelessWidget {
  /// Creates a surface.
  const WaiterSurface({
    required this.radius,
    required this.child,
    super.key,
    this.color,
    this.gradient,
    this.outline,
    this.outlineWidth = Borders.widthDefault,
    this.shadows = const <BoxShadow>[],
    this.clip = false,
  });

  /// Corner radii.
  final BorderRadius radius;

  /// Fill colour.
  final Color? color;

  /// Fill gradient (BalanceCard sheen).
  final Gradient? gradient;

  /// Inner outline colour, `null` for none.
  final Color? outline;

  /// Inner outline width.
  final double outlineWidth;

  /// Shadows (light theme elevation).
  final List<BoxShadow> shadows;

  /// Whether the child is clipped to the shape.
  final bool clip;

  /// Content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final OutlinedBorder shape = waiterShape(context, radius);
    final Widget content = clip
        ? ClipPath(
            clipper: ShapeBorderClipper(
              shape: shape,
              textDirection: Directionality.of(context),
            ),
            child: child,
          )
        : child;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        color: gradient == null ? color : null,
        gradient: gradient,
        shadows: shadows,
      ),
      position: DecorationPosition.background,
      child: outline == null
          ? content
          : DecoratedBox(
              decoration: ShapeDecoration(
                shape: shape.copyWith(
                  side: innerSide(outline, width: outlineWidth),
                ),
              ),
              position: DecorationPosition.foreground,
              child: content,
            ),
    );
  }
}
