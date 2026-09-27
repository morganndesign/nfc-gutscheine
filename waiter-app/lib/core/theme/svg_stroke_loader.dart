import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

final RegExp _strokeWidth = RegExp(r'stroke-width="([0-9]*\.?[0-9]+)"');

/// Multiplies every `stroke-width` attribute of [svg] by [scale].
///
/// Icon and illustration masters are drawn with a 1.75 stroke on their own
/// grid; strokes must not scale with the rendered size (04 §11.2, 10 §4.2),
/// so each size gets its own stroke by rewriting the widths before parsing.
/// Mask cut widths and deliberately thicker strokes keep their proportion.
String scaleSvgStrokes(String svg, double scale) {
  if (scale == 1) return svg;
  return svg.replaceAllMapped(_strokeWidth, (Match m) {
    final double value = double.parse(m.group(1)!) * scale;
    return 'stroke-width="${value.toStringAsFixed(4)}"';
  });
}

/// Loads an SVG asset and rescales its strokes (see [scaleSvgStrokes]).
///
/// Cached per asset, stroke scale, theme and colour mapper.
@immutable
class StrokeScaledSvgLoader extends SvgLoader<ByteData> {
  /// Creates a loader for [assetName] with strokes multiplied by
  /// [strokeScale].
  const StrokeScaledSvgLoader(
    this.assetName, {
    required this.strokeScale,
    super.theme,
    super.colorMapper,
  });

  /// Asset path, e.g. `assets/icons/ic_x.svg`.
  final String assetName;

  /// Factor applied to every stroke width.
  final double strokeScale;

  @override
  Future<ByteData?> prepareMessage(BuildContext? context) {
    final AssetBundle bundle = context != null
        ? DefaultAssetBundle.of(context)
        : rootBundle;
    return bundle.load(assetName);
  }

  @override
  String provideSvg(ByteData? message) => scaleSvgStrokes(
    utf8.decode(Uint8List.sublistView(message!), allowMalformed: true),
    strokeScale,
  );

  @override
  bool operator ==(Object other) =>
      other is StrokeScaledSvgLoader &&
      other.assetName == assetName &&
      other.strokeScale == strokeScale &&
      other.theme == theme &&
      other.colorMapper == colorMapper;

  @override
  int get hashCode => Object.hash(assetName, strokeScale, theme, colorMapper);

  @override
  String toString() => 'StrokeScaledSvgLoader($assetName × $strokeScale)';
}
