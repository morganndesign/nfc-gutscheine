import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'shape.dart';

/// Keyboard / switch focus indicator (04 §13.1, 05 §1.0, 13 · R17).
///
/// A `color.focus.ring` stroke (2 pt, 3 pt in high contrast) drawn
/// **outside** [child] with a 2-pt offset, following the child's corner
/// radius + offset; the light theme adds a 2-pt `color.focus.accent` band
/// outside the ring. Painting never changes layout.
class FocusRing extends StatelessWidget {
  /// Creates a focus ring around [child].
  const FocusRing({
    required this.visible,
    required this.radius,
    required this.child,
    super.key,
  });

  /// Whether the ring is shown (keyboard/switch focus only).
  final bool visible;

  /// Corner radius of [child].
  final BorderRadius radius;

  /// The focused shape.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!visible) return child;
    final WaiterTheme theme = context.waiter;
    return CustomPaint(
      foregroundPainter: _FocusRingPainter(
        shapeFor: (BorderRadius r) => waiterShape(context, r),
        radius: radius,
        ringColor: theme.colors.focusRing,
        ringWidth: theme.focusRingWidth,
        accentColor: theme.colors.focusAccent,
      ),
      child: child,
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter({
    required this.shapeFor,
    required this.radius,
    required this.ringColor,
    required this.ringWidth,
    required this.accentColor,
  });

  final OutlinedBorder Function(BorderRadius radius) shapeFor;
  final BorderRadius radius;
  final Color ringColor;
  final double ringWidth;
  final Color? accentColor;

  void _stroke(Canvas canvas, Size size, double inset, double width, Color c) {
    final double grow = inset + width / 2;
    final Rect rect = (Offset.zero & size).inflate(grow);
    final BorderRadius r = radius + BorderRadius.circular(grow);
    final Path path = shapeFor(r).getOuterPath(rect);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = c
        ..isAntiAlias = true,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    _stroke(canvas, size, FocusTokens.offset, ringWidth, ringColor);
    final Color? accent = accentColor;
    if (accent != null) {
      _stroke(
        canvas,
        size,
        FocusTokens.offset + ringWidth,
        Borders.widthFocus,
        accent,
      );
    }
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.radius != radius ||
      old.ringColor != ringColor ||
      old.ringWidth != ringWidth ||
      old.accentColor != accentColor;
}
