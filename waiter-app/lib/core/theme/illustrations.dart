import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../tokens/tokens.dart';
import 'context_ext.dart';
import 'layout.dart';
import 'svg_stroke_loader.dart';
import 'waiter_theme.dart';

/// Where an illustration is used; decides its size (10 §4.3).
enum IllustrationUse {
  /// Problem and account screens (S10, S15): 120 pt, 96 pt at compact height.
  problem(IllustrationTokens.problem, IllustrationTokens.problemCompact),

  /// Recent empty state (S13): 96 pt.
  empty(IllustrationTokens.empty, IllustrationTokens.empty),

  /// First-run intro (S17): 160 pt, 120 pt at compact height (13 · R04).
  intro(IllustrationTokens.intro, IllustrationTokens.introCompact);

  const IllustrationUse(this.size, this.compactSize);

  /// Size at regular height (tablets use the same sizes).
  final double size;

  /// Size at compact height (< 700 pt).
  final double compactSize;

  /// Size for [layout].
  double sizeFor(WaiterLayout layout) =>
      layout.heightClass.isCompact ? compactSize : size;
}

/// The illustration inventory (10 §4.4 — authoritative, 13 · R04).
///
/// Files are `assets/illustrations/ill_<subject>.svg`, monoline 1.75 on an
/// artboard of the primary size, with colour roles `line`, `accent` and
/// `knockout` drawn in placeholder colours that [IllustrationView] maps to
/// the active theme.
enum WaiterIllustration {
  /// S10 not found (scan and manual).
  cardNotFound('ill_card_not_found', 120, IllustrationUse.problem),

  /// S10 card from another restaurant.
  wrongRestaurant('ill_wrong_restaurant', 120, IllustrationUse.problem),

  /// S10 verification failed (first and final) — calm (13 · R03).
  verifyFailed('ill_verify_failed', 120, IllustrationUse.problem),

  /// S10 scan throttled, S15 account locked.
  wait('ill_wait', 120, IllustrationUse.problem),

  /// S10 card could not be loaded (network).
  offline('ill_offline', 120, IllustrationUse.problem),

  /// S15 device revoked, restaurant paused, deactivated, no permission.
  cardLocked('ill_card_locked', 120, IllustrationUse.problem),

  /// S13 Recent, empty.
  recentEmpty('ill_recent_empty', 96, IllustrationUse.empty),

  /// S17 card 1 "Tap the card".
  introTap('ill_intro_tap', 160, IllustrationUse.intro),

  /// S17 card 2 "Enter the amount".
  introAmount('ill_intro_amount', 160, IllustrationUse.intro),

  /// S17 card 3 "Redeem. Done.".
  introDone('ill_intro_done', 160, IllustrationUse.intro);

  const WaiterIllustration(this.fileName, this.artboard, this.use);

  /// File name without extension.
  final String fileName;

  /// Master artboard size in units (stroke 1.75 at this size).
  final double artboard;

  /// Where it is used.
  final IllustrationUse use;

  /// Asset path.
  String get assetName => 'assets/illustrations/$fileName.svg';
}

/// Placeholder colours of the illustration masters.
abstract final class IllustrationRoles {
  /// `line` role placeholder.
  static const Color line = Color(0xFF0000FE);

  /// `accent` role placeholder.
  static const Color accent = Color(0xFFFE0000);

  /// `knockout` role placeholder.
  static const Color knockout = Color(0xFF00FE00);
}

@immutable
class _RoleColorMapper extends ColorMapper {
  const _RoleColorMapper(this.line, this.accent, this.knockout);

  final Color line;
  final Color accent;
  final Color knockout;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    final int argb = color.toARGB32();
    if (argb == IllustrationRoles.line.toARGB32()) return line;
    if (argb == IllustrationRoles.accent.toARGB32()) return accent;
    if (argb == IllustrationRoles.knockout.toARGB32()) return knockout;
    return color;
  }

  @override
  bool operator ==(Object other) =>
      other is _RoleColorMapper &&
      other.line == line &&
      other.accent == accent &&
      other.knockout == knockout;

  @override
  int get hashCode => Object.hash(line, accent, knockout);
}

/// Renders a [WaiterIllustration] (10 §4).
///
/// - Roles: `line` → `color.fg.secondary` (`fg.primary` in high contrast),
///   `accent` → `color.accent.saffron`, `knockout` → [knockoutColor]
///   (default `color.bg.canvas`; pass `color.bg.surface` inside sheets).
/// - Stroke stays 1.75 pt at every rendered size, +0.25 pt in high
///   contrast (10 §4.2, §4.5).
/// - Size: [size], else the size of its use for the current height class.
/// - Always decorative: hidden from assistive technology (10 §4.2).
class IllustrationView extends StatelessWidget {
  /// Creates an illustration view.
  const IllustrationView(
    this.illustration, {
    super.key,
    this.size,
    this.knockoutColor,
  });

  /// Which illustration.
  final WaiterIllustration illustration;

  /// Rendered size in pt; defaults per [IllustrationUse].
  final double? size;

  /// Background the illustration sits on.
  final Color? knockoutColor;

  /// Stroke factor for a rendered [dimension] (see [scaleSvgStrokes]).
  static double strokeScaleFor(
    WaiterIllustration illustration,
    double dimension, {
    required bool highContrast,
  }) {
    final double stroke =
        IllustrationTokens.stroke +
        (highContrast ? IllustrationTokens.strokeHcExtra : 0);
    return stroke *
        illustration.artboard /
        dimension /
        IllustrationTokens.stroke;
  }

  @override
  Widget build(BuildContext context) {
    final WaiterTheme theme = context.waiter;
    final double dimension =
        size ?? illustration.use.sizeFor(WaiterLayout.of(context));
    return ExcludeSemantics(
      child: SvgPicture(
        StrokeScaledSvgLoader(
          illustration.assetName,
          strokeScale: strokeScaleFor(
            illustration,
            dimension,
            highContrast: theme.isHighContrast,
          ),
          colorMapper: _RoleColorMapper(
            theme.illustrationLine,
            theme.illustrationAccent,
            knockoutColor ?? theme.colors.bgCanvas,
          ),
        ),
        width: dimension,
        height: dimension,
        excludeFromSemantics: true,
      ),
    );
  }
}
