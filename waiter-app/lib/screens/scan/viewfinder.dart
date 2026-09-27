import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/theme/theme.dart';

/// Length of each corner bracket and its stroke (03a §8).
const double bracketLength = 32;
const double bracketStroke = 4;

/// The S12 viewfinder overlay (03a §8; "illustrated overlay, not a
/// component"): `color.scrim` everywhere outside a `radius.xl` window, and
/// four corner brackets around [brackets] — the window while searching, the
/// code's bounds once detected.
class ViewfinderPainter extends CustomPainter {
  /// Creates the painter.
  const ViewfinderPainter({
    required this.window,
    required this.brackets,
    required this.scrim,
    required this.bracketColor,
  });

  /// The clear window.
  final Rect window;

  /// Where the brackets are drawn.
  final Rect brackets;

  /// Scrim colour outside the window.
  final Color scrim;

  /// Saffron (searching / detected) or warning (not a card).
  final Color bracketColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Path outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(
        RRect.fromRectAndRadius(window, const Radius.circular(Radii.xl)),
      );
    canvas.drawPath(outside, Paint()..color = scrim);

    final double r = math.min(Radii.xl, brackets.shortestSide / 4);
    final double len = math.max(
      r,
      math.min(bracketLength, brackets.shortestSide / 2),
    );
    final Paint stroke = Paint()
      ..color = bracketColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = bracketStroke
      ..strokeCap = StrokeCap.round;
    final Rect b = brackets;
    final Path corners = Path()
      // Top left.
      ..moveTo(b.left, b.top + len)
      ..lineTo(b.left, b.top + r)
      ..arcToPoint(Offset(b.left + r, b.top), radius: Radius.circular(r))
      ..lineTo(b.left + len, b.top)
      // Top right.
      ..moveTo(b.right - len, b.top)
      ..lineTo(b.right - r, b.top)
      ..arcToPoint(Offset(b.right, b.top + r), radius: Radius.circular(r))
      ..lineTo(b.right, b.top + len)
      // Bottom right.
      ..moveTo(b.right, b.bottom - len)
      ..lineTo(b.right, b.bottom - r)
      ..arcToPoint(Offset(b.right - r, b.bottom), radius: Radius.circular(r))
      ..lineTo(b.right - len, b.bottom)
      // Bottom left.
      ..moveTo(b.left + len, b.bottom)
      ..lineTo(b.left + r, b.bottom)
      ..arcToPoint(Offset(b.left, b.bottom - r), radius: Radius.circular(r))
      ..lineTo(b.left, b.bottom - len);
    canvas.drawPath(corners, stroke);
  }

  @override
  bool shouldRepaint(ViewfinderPainter old) =>
      old.window != window ||
      old.brackets != brackets ||
      old.scrim != scrim ||
      old.bracketColor != bracketColor;
}
