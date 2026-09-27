import 'package:flutter/widgets.dart';

/// A `border.width.hairline` line: one physical pixel, snapped to the
/// pixel grid (04 §7).
class Hairline extends StatelessWidget {
  /// Creates a horizontal hairline in [color].
  const Hairline({required this.color, super.key});

  /// Line colour.
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 1 / MediaQuery.devicePixelRatioOf(context),
    child: ColoredBox(color: color),
  );
}
