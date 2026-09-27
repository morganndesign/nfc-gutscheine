import 'package:flutter/widgets.dart';

import '../core/theme/theme.dart';
import 'support/focus_ring.dart';
import 'support/pressable.dart';

/// Visual variants of [WaiterIconButton] (05 §1.6).
enum IconButtonVariant {
  /// No rest fill; `bg.key` 44-pt circle while pressed; `fg.primary` icon.
  plain,

  /// Over the S12 viewfinder: `color.camera.overlay` 44-pt circle with a
  /// white icon; pressed adds the 8 % pressed overlay; toggled on (torch)
  /// turns saffron with a #0A0A0C icon.
  onCamera,
}

/// An icon-only action — Close, Recent, Menu, Torch, password visibility
/// (05 §1.6). Named `WaiterIconButton` because Material's `IconButton`
/// would collide in screens that import `material.dart`.
///
/// 56 × 56 target, `icon.24` centred, 44-pt fill circle while pressed
/// (no scale), focus ring around the 44-pt circle. [toggled] makes it a
/// toggle button (announced on/off) and swaps to [toggledIcon].
class WaiterIconButton extends StatelessWidget {
  /// Creates an icon button.
  const WaiterIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
    this.variant = IconButtonVariant.plain,
    this.toggled,
    this.toggledIcon,
    this.semanticValue,
  });

  /// Glyph at rest (and when [toggled] is false).
  final WaiterIcon icon;

  /// Glyph when [toggled] is true (`flashlight-off`, `eye-off`).
  final WaiterIcon? toggledIcon;

  /// Accessible label ("Close", "Recent", "Menu", …).
  final String semanticLabel;

  /// Accessible value (e.g. Recent "{n} today").
  final String? semanticValue;

  /// Action; `null` renders the disabled state (`fg.tertiary` icon).
  final VoidCallback? onPressed;

  /// Visual variant.
  final IconButtonVariant variant;

  /// Toggle state; `null` for a plain button.
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    final bool on = toggled ?? false;
    final bool enabled = onPressed != null;
    const BorderRadius circle = BorderRadius.all(
      Radius.circular(IconButtonTokens.fill / 2),
    );
    return Pressable(
      onPressed: onPressed,
      semanticsLabel: semanticLabel,
      semanticsValue: semanticValue,
      semanticsToggled: toggled,
      builder: (BuildContext context, PressVisual visual) {
        final Color rest;
        final Color pressed;
        final Color glyph;
        switch (variant) {
          case IconButtonVariant.plain:
            rest = c.bgKey.withValues(alpha: 0);
            pressed = c.bgKey;
            glyph = enabled ? c.fgPrimary : c.fgTertiary;
          case IconButtonVariant.onCamera:
            rest = on ? c.accentSaffron : c.cameraOverlay;
            pressed = Color.alphaBlend(c.statePressedOverlay, rest);
            glyph = on
                ? BalanceCardTokens.textDark
                : BalanceCardTokens.textLight;
        }
        Color fill = Color.lerp(rest, pressed, visual.pressAmount)!;
        if (visual.hovered && enabled) {
          fill = Color.alphaBlend(c.stateHover, fill);
        }
        return SizedBox.square(
          dimension: IconButtonTokens.target,
          child: Center(
            child: FocusRing(
              visible: visual.focused,
              radius: circle,
              child: Container(
                width: IconButtonTokens.fill,
                height: IconButtonTokens.fill,
                decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: WaiterIconView(
                  on && toggledIcon != null ? toggledIcon! : icon,
                  color: glyph,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
